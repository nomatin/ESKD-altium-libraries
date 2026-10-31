"""Plot saved native results without rerunning or altering the simulations."""
from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE=Path(__file__).resolve().parent
def report(round_name,case):
    return json.loads((HERE/round_name/(case+'.stdout.json')).read_text(encoding='utf-8'))
def wave(r,name):
    g=next(g for g in r['graphs'] if g['name']==name)
    return g['x'],g['real']
def plot_wave(ax,r,name,label,scale=1):
    x,y=wave(r,name);ax.plot([v*scale for v in x],y,label=label,lw=1.5)

plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
fig,axs=plt.subplots(2,2,figsize=(11,7.2),layout='constrained')
fig.suptitle('ISOW1432DFMR — native Altium MixedSim 24.4.1.13',fontsize=15)
ax=axs[0,0];r=report('native_full_flat','04_soft_start')
plot_wave(ax,r,'vi','VISOOUT',1e3);plot_wave(ax,r,'vd','Y − Z',1e3)
ax.axhline(2.97,color='gray',ls=':',lw=1,label='90% of 3.3 V')
ax.set(title='Soft-start, external 10 µF',xlabel='Time (ms)',ylabel='Voltage (V)');ax.legend(fontsize=8)
ax=axs[0,1];r=report('native_smoke_flat','27_tx_timing_3p3')
plot_wave(ax,r,'vd','Y − Z',1e6)
# The input is in the raw saved result; exported graphs may omit it.
ax.axvline(1.0005,color='gray',ls=':',label='D input 50% crossing')
ax.set(title='TX, 3.3 V mode, 54 Ω || 50 pF',xlabel='Time (µs)',ylabel='Differential voltage (V)',xlim=(.98,1.12));ax.legend(fontsize=8)
ax=axs[1,0];r=report('native_remaining_flat','28_rx_timing_3p3')
plot_wave(ax,r,'rr','R',1e6)
ax.axvline(1.0005,color='gray',ls=':',label='Input VID crossing')
ax.set(title='RX, 3.3 V, 15 pF',xlabel='Time (µs)',ylabel='Logic voltage (V)',xlim=(.98,1.15));ax.legend(fontsize=8)
ax=axs[1,1]
names=['39_steady_24_current_tx_3v3','39_steady_24_current_tx_5v','39_steady_25_current_rx','39_steady_26_current_loopback']
targets=[87,146,15,90];values=[]
for name in names:
    r=report('native_remaining_flat',name)
    ms=r.get('measurements',[])
    values.append(next(m['value'] for m in ms if m['id']=='idd_late')*1000)
pos=list(range(len(names)))
ax.bar(pos,values,color='#24749b',width=.55,label='Native steady-state')
ax.errorbar(pos,targets,yerr=[v*.15 for v in targets],fmt='o',color='#ad522b',capsize=6,label='TI typical ±15% model target')
for x,y in zip(pos,values):ax.text(x,y+3,f'{y:.2f}',ha='center',fontsize=8)
ax.set_xticks(pos,['TX 3.3 V','TX 5 V','RX 3.3 V','TX+RX 3.3 V'])
ax.set(title='IDD, VDD = VIO = 5 V, 12 Mbit/s',ylabel='Current (mA)',ylim=(0,185));ax.legend(fontsize=8,loc='upper left')
for ax in axs.flat:ax.grid(alpha=.15)
fig.savefig(HERE/'validation_overview.png',dpi=160)
