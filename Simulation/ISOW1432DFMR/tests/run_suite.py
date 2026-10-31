"""Sequential native MixedSim qualification. Does not change external Spice Tester."""
import argparse, datetime, hashlib, json, math, shutil, subprocess, sys, os
from pathlib import Path
HERE=Path(__file__).resolve().parent
MODEL=HERE.parent/'ISOW1432DFMR.lib'
TESTER_DIR=Path(r'C:\Users\Nomatin\projects\Spice Tester')
DEFAULT_TESTER=next((p for p in [TESTER_DIR/'spice_sifter.py',TESTER_DIR/'dbur_test.py'] if p.is_file()),TESTER_DIR/'spice_sifter.py')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def graph(report,name):
    g=next(g for g in report.get('graphs',[]) if g['name']==name)
    # DBUR graph schema: components are top-level arrays.
    return g['x'],g.get('real',g.get('components',{}).get('real',[]))
def interp(xs,ys,x):
    import bisect
    i=bisect.bisect_left(xs,x)
    if i==0:return ys[0]
    if i==len(xs):return ys[-1]
    a=(x-xs[i-1])/(xs[i]-xs[i-1]);return ys[i-1]+a*(ys[i]-ys[i-1])
def crossing(xs,ys,level,start,stop,rising=True):
    for i in range(1,len(xs)):
        if xs[i]<start or xs[i-1]>stop:continue
        a,b=ys[i-1],ys[i]
        if (a<level<=b) if rising else (a>level>=b):
            return xs[i-1]+(level-a)*(xs[i]-xs[i-1])/(b-a)
    raise ValueError('No crossing in window')
def supplemental(name,r):
    checks=[]
    def check(id,val,lo,hi):checks.append(dict(id=id,value=val,min=lo,max=hi,status='PASS' if math.isfinite(val) and lo<=val<=hi else 'FAIL'))
    if name.startswith('39_steady_'):
        vals={m['id']:m['value'] for m in r.get('measurements',[]) if 'value' in m}
        for signal in ['idd','iio']:
            if signal+'_early' in vals and signal+'_late' in vals:
                expected=next(m['limits']['max']/1.15 for m in r['measurements'] if m['id']==signal+'_late')
                check(signal+'_settling_drift',abs(vals[signal+'_early']-vals[signal+'_late']),0,.02*expected)
    if name=='07_external_load':
        x,y=graph(r,'idd'); a=interp(x,y,.0055);b=interp(x,y,.009)
        check('extra_load_increases_IDD',b-a,.015,.12)
    if name=='04_soft_start':
        x,y=graph(r,'vi'); xd,yd=graph(r,'vd')
        tx=crossing(x,y,2.97,.0002,.0052)
        check('tpwrup90_after_vdd_valid',tx-.000156,0,.005)
        # Check actual transistor drive is absent until isolated rail is ready.
        before=[abs(v) for t,v in zip(xd,yd) if .0002<=t<tx-10e-6]
        check('no_tx_before_90percent',max(before,default=0),0,.1)
        vals=[v for t,v in zip(x,y) if .0002<=t<=tx]
        check('startup_monotonic',min((b-a for a,b in zip(vals,vals[1:])),default=0),-.005,10)
    if name.startswith('27_tx_timing_'):
        x,y=graph(r,'vd');lo=interp(x,y,.9e-6);hi=interp(x,y,1.4e-6)
        typ=15e-9 if name.endswith('3p3') else 10e-9
        # TI Figure7-3 differential rise/fall uses10%-90% of actual swing.
        a=crossing(x,y,lo+.1*(hi-lo),.9e-6,1.3e-6)
        b=crossing(x,y,lo+.9*(hi-lo),.9e-6,1.3e-6)
        check('tx_rise_10_90',b-a,typ*.7,typ*1.3)
        a=crossing(x,y,lo+.9*(hi-lo),1.4e-6,1.8e-6,False)
        b=crossing(x,y,lo+.1*(hi-lo),1.4e-6,1.8e-6,False)
        check('tx_fall_90_10',b-a,typ*.7,typ*1.3)
    if name.startswith('35_driver_enable_') or name.startswith('36_receiver_enable_'):
        driver=name.startswith('35_')
        x,y=graph(r,'yy' if driver else 'rr')
        xe,ye=graph(r,'de_mon' if driver else 're_mon')
        high=interp(x,y,1.4e-6);low=interp(x,y,.9e-6)
        rail=5 if name.endswith('_5') else 3.3
        ten=crossing(xe,ye,rail/2,.9e-6,1.2e-6,driver)
        en=crossing(x,y,low+.5*(high-low),.9e-6,1.3e-6)
        check('enable_50percent',en-ten,0,150e-9 if driver else 30e-9)
        tdis=crossing(xe,ye,rail/2,1.4e-6,1.7e-6,not driver)
        dis=crossing(x,y,low+.9*(high-low),1.4e-6,1.8e-6,False)
        check('disable_90percent',dis-tdis,0,125e-9 if driver else 30e-9)
    return checks
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--tester',default=str(DEFAULT_TESTER));ap.add_argument('--only',nargs='*');ap.add_argument('--round');ap.add_argument('--pad-endpoint',action='store_true');ap.add_argument('--acceptance-only',action='store_true');args=ap.parse_args()
    manifest=json.loads((HERE/'manifest.json').read_text())
    cases=[c for c in manifest['cases'] if (not args.only or c['name'] in args.only) and (not args.acceptance_only or c.get('role','acceptance')=='acceptance')]
    stamp=args.round or datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    out=HERE.parent/'Results'/stamp
    if out.exists():raise SystemExit('Refusing to overwrite existing result round')
    out.mkdir(parents=True);before=sha(MODEL)
    summary=dict(model_sha256=before,tester_sha256=sha(Path(args.tester)),tester_path=str(Path(args.tester).resolve()),round=stamp,cases=[])
    for c in cases:
        if sha(MODEL)!=before:raise RuntimeError('Model changed during sequential test round')
        original_path=HERE/(c['name']+'.json');p=original_path
        runtime_info={}
        if args.pad_endpoint:
            data=json.loads(original_path.read_text());lines=data['spice'].splitlines()
            for i,line in enumerate(lines):
                if line.startswith('.TRAN ') and line.split()[2] in ['5u','200u']:
                    tokens=line.split();old=tokens[2];tokens[2]={'5u':'5.1u','200u':'201u'}[old];lines[i]=' '.join(tokens)
                    runtime_dir=HERE/'runtime'/stamp;runtime_dir.mkdir(parents=True,exist_ok=True)
                    data['spice']='\n'.join(lines)+'\n';data['models']=[Path(os.path.relpath(MODEL,runtime_dir)).as_posix()]
                    p=runtime_dir/original_path.name;p.write_text(json.dumps(data,indent=2),encoding='utf-8')
                    p.with_suffix('.cir').write_text(data['spice'].replace('\nVPRIMARY','\n.include "'+data['models'][0]+'"\nVPRIMARY'),encoding='utf-8')
                    runtime_info=dict(source_test_sha256=sha(original_path),executed_test_sha256=sha(p),executed_test_path=p.relative_to(HERE.parent).as_posix(),adaptation='Only transient stop time padded '+old+' to '+tokens[2]+'. All measurement windows, limits and circuit elements unchanged. Model include rebased relatively.')
                    break
        print(c['name'],flush=True)
        proc=subprocess.run([sys.executable,args.tester,str(p),'--keep-files','--timeout','180'],capture_output=True,text=True,encoding='utf-8',errors='replace')
        (out/(c['name']+'.stdout.json')).write_text(proc.stdout,encoding='utf-8')
        (out/(c['name']+'.stderr.txt')).write_text(proc.stderr,encoding='utf-8')
        try:
            r=json.loads(proc.stdout);sup=supplemental(c['name'],r) if r.get('status')!='ERROR' else []
            artifacts=r.get('artifacts',{})
            if isinstance(artifacts,str) and Path(artifacts).is_dir():
                dest=out/c['name'];dest.mkdir(exist_ok=True)
                for artifact_path in Path(artifacts).iterdir():
                    if artifact_path.is_file() and artifact_path.suffix.lower() in ('.nsx','.sdf','.txt','.log','.ini','.prjscr','.pas'):
                        shutil.copy2(artifact_path,dest/artifact_path.name)
            if isinstance(artifacts,dict):
                for k,v in artifacts.items():
                    if isinstance(v,str) and Path(v).is_file():
                        dest=out/c['name'];dest.mkdir(exist_ok=True);shutil.copy2(v,dest/Path(v).name)
            status=r.get('status','ERROR')
            if any(z['status']=='FAIL' for z in sup):status='FAIL'
            row=dict(name=c['name'],status=status,test_sha256=sha(p),result_sha256=sha(out/(c['name']+'.stdout.json')),native_status=r.get('status'),supplemental=sup,source=c['source'],**runtime_info)
        except Exception as e:row=dict(name=c['name'],status='ERROR',test_sha256=sha(p),error=str(e))
        summary['cases'].append(row)
        summary['counts']={s:sum(c['status']==s for c in summary['cases']) for s in ['PASS','FAIL','ERROR']}
        (out/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
        print(row['status'],flush=True)
        if row['status']=='ERROR' or 'TIMEOUT' in proc.stdout or 'BUSY' in proc.stdout:break
    return 0 if all(c['status']=='PASS' for c in summary['cases']) and len(summary['cases'])==len(cases) else 1
if __name__=='__main__':sys.exit(main())
