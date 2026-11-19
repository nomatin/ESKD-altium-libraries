{ SPDX-FileCopyrightText: 2026 nomatin }
{ SPDX-License-Identifier: GPL-3.0-only }
{ Minimal SchDoc generator for component.spice fixtures. }

function CleanValue(V : WideString) : WideString;
begin
  Result := StringReplace(V, #13, ' ', 0);
  Result := StringReplace(Result, #10, ' ', 0);
  Result := StringReplace(Result, #9, ' ', 0);
end;

procedure AddError(S : TStringList; Stage, Code, Msg : WideString);
begin
  S.Add('stage_' + Stage + '=FAIL');
  S.Add('error_stage=' + Stage);
  S.Add('error_code=' + Code);
  S.Add('error_message=' + CleanValue(Msg));
end;

function FieldAt(Line : WideString; Index : Integer) : WideString;
var I, N, P : Integer; Ch : WideString;
begin
  Result := '';
  N := 0;
  P := 1;
  for I := 1 to Length(Line) + 1 do begin
    if I > Length(Line) then Ch := '|'
    else Ch := Copy(Line, I, 1);
    if Ch = '|' then begin
      if N = Index then begin
        Result := Copy(Line, P, I - P);
        Exit;
      end;
      Inc(N);
      P := I + 1;
    end;
  end;
end;

function CountComponents(Doc : ISch_Document) : Integer;
var It : ISch_Iterator; O : Variant;
begin
  Result := 0;
  It := Doc.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(eSchComponent));
  try
    O := It.FirstSchObject;
    while O <> Nil do begin Inc(Result); O := It.NextSchObject; end;
  finally Doc.SchIterator_Destroy(It); end;
end;

function CountWires(Doc : ISch_Document) : Integer;
var It : ISch_Iterator; O : Variant;
begin
  Result := 0;
  It := Doc.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(eWire));
  try
    O := It.FirstSchObject;
    while O <> Nil do begin Inc(Result); O := It.NextSchObject; end;
  finally Doc.SchIterator_Destroy(It); end;
end;

function CountNetLabels(Doc : ISch_Document) : Integer;
var It : ISch_Iterator; O : Variant;
begin
  Result := 0;
  It := Doc.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(eNetLabel));
  It.SetState_IterationDepth(eIterateFirstLevel);
  try
    O := It.FirstSchObject;
    while O <> Nil do begin Inc(Result); O := It.NextSchObject; end;
  finally Doc.SchIterator_Destroy(It); end;
end;

function FindComponentByUniqueId(Doc : ISch_Document; Uid : WideString) : ISch_Component;
var It : ISch_Iterator; O : Variant;
begin
  Result := Nil;
  It := Doc.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(eSchComponent));
  try
    O := It.FirstSchObject;
    while O <> Nil do begin
      if CompareText(O.UniqueId, Uid) = 0 then begin Result := O; O := Nil; end
      else O := It.NextSchObject;
    end;
  finally Doc.SchIterator_Destroy(It); end;
end;

function FindComponentAt(Doc : ISch_Document; X, Y : Integer) : ISch_Component;
var It : ISch_Iterator; O : Variant;
begin
  Result := Nil;
  It := Doc.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(eSchComponent));
  try
    O := It.FirstSchObject;
    while O <> Nil do begin
      if (CoordToMils(O.Location.X) = X) and (CoordToMils(O.Location.Y) = Y) then begin
        Result := O; O := Nil;
      end else O := It.NextSchObject;
    end;
  finally Doc.SchIterator_Destroy(It); end;
end;

function FindPinByDesignator(Comp : ISch_Component; Desig : WideString) : Variant;
var It : ISch_Iterator; P : Variant;
begin
  Result := Nil;
  It := Comp.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(ePin));
  It.SetState_IterationDepth(eIterateFirstLevel);
  try
    P := It.FirstSchObject;
    while P <> Nil do begin
      if CompareText(P.GetState_Designator, Desig) = 0 then begin
        Result := P; P := Nil;
      end else P := It.NextSchObject;
    end;
  finally Comp.SchIterator_Destroy(It); end;
end;

function PinHotX(X, Ori, Len : Integer) : Integer;
begin
  Result := X;
  if (Ori mod 4) = 0 then Result := X + Len;
  if (Ori mod 4) = 2 then Result := X - Len;
end;

function PinHotY(Y, Ori, Len : Integer) : Integer;
begin
  Result := Y;
  if (Ori mod 4) = 1 then Result := Y + Len;
  if (Ori mod 4) = 3 then Result := Y - Len;
end;

function HotX(Pin : Variant) : Integer;
begin
  Result := PinHotX(CoordToMils(Pin.Location.X), Ord(Pin.GetState_Orientation),
    CoordToMils(Pin.GetState_PinLength));
end;

function HotY(Pin : Variant) : Integer;
begin
  Result := PinHotY(CoordToMils(Pin.Location.Y), Ord(Pin.GetState_Orientation),
    CoordToMils(Pin.GetState_PinLength));
end;

procedure SetDesignator(Doc : ISch_Document; Comp : ISch_Component; Value : WideString);
begin
  SchServer.ProcessControl.PreProcess(Doc, '');
  try
    SchServer.RobotManager.SendMessage(Comp.I_ObjectAddress, c_BroadCast,
      SCHM_BeginModify, c_NoEventData);
    Comp.Designator.Text := Value;
    SchServer.RobotManager.SendMessage(Comp.I_ObjectAddress, c_BroadCast,
      SCHM_EndModify, c_NoEventData);
  finally SchServer.ProcessControl.PostProcess(Doc, ''); end;
end;

function GetParamText(Comp : ISch_Component; Name : WideString) : WideString;
var It : ISch_Iterator; P : Variant;
begin
  Result := '';
  It := Comp.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(eParameter));
  try
    P := It.FirstSchObject;
    while P <> Nil do begin
      if CompareText(P.GetState_Name, Name) = 0 then begin
        Result := P.GetState_Text;
        P := Nil;
      end else P := It.NextSchObject;
    end;
  finally Comp.SchIterator_Destroy(It); end;
end;

function SetParamText(Doc : ISch_Document; Comp : ISch_Component;
  Name, Value : WideString) : Boolean;
var It : ISch_Iterator; P : Variant;
begin
  Result := False;
  It := Comp.SchIterator_Create;
  It.AddFilter_ObjectSet(MkSet(eParameter));
  try
    P := It.FirstSchObject;
    while P <> Nil do begin
      if CompareText(P.GetState_Name, Name) = 0 then begin
        SchServer.ProcessControl.PreProcess(Doc, '');
        try
          SchServer.RobotManager.SendMessage(P.I_ObjectAddress, c_BroadCast,
            SCHM_BeginModify, c_NoEventData);
          P.SetState_Text(Value);
          SchServer.RobotManager.SendMessage(P.I_ObjectAddress, c_BroadCast,
            SCHM_EndModify, c_NoEventData);
        finally SchServer.ProcessControl.PostProcess(Doc, ''); end;
        Result := True;
        P := Nil;
      end else P := It.NextSchObject;
    end;
  finally Comp.SchIterator_Destroy(It); end;
end;

procedure AddLabel(Doc : ISch_Document; X, Y : Integer; T : WideString;
  Journal : TStringList);
var L : Variant;
begin
  L := SchServer.SchObjectFactory(eNetLabel, eCreate_Default);
  L.SetState_Location(Point(MilsToCoord(X), MilsToCoord(Y)));
  L.SetState_Text(T);
  SchServer.ProcessControl.PreProcess(Doc, '');
  try
    Doc.RegisterSchObjectInContainer(L);
    SchServer.RobotManager.SendMessage(Doc.I_ObjectAddress, c_BroadCast,
      SCHM_PrimitiveRegistration, L.I_ObjectAddress);
  finally SchServer.ProcessControl.PostProcess(Doc, ''); end;
  Journal.Add('LABEL=' + L.GetState_UniqueId);
  L := Nil;
end;

function ConnectPin(Doc : ISch_Document; Comp : ISch_Component;
  Desig, Net : WideString; Journal : TStringList) : Boolean;
var P : Variant;
begin
  Result := False;
  P := FindPinByDesignator(Comp, Desig);
  if P = Nil then Exit;
  AddLabel(Doc, HotX(P), HotY(P), Net, Journal);
  Result := True;
end;

procedure DeleteByUniqueId(Doc : ISch_Document; Uid : WideString);
var It : ISch_Iterator; O : Variant;
begin
  It := Doc.SchIterator_Create;
  It.SetState_IterationDepth(eIterateFirstLevel);
  try
    O := It.FirstSchObject;
    while O <> Nil do begin
      if CompareText(O.GetState_UniqueId, Uid) = 0 then begin
        SchServer.ProcessControl.PreProcess(Doc, '');
        try
          Doc.RemoveSchObject(O);
          SchServer.RobotManager.SendMessage(Doc.I_ObjectAddress, c_BroadCast,
            SCHM_PrimitiveRegistration, O.I_ObjectAddress);
        finally SchServer.ProcessControl.PostProcess(Doc, ''); end;
        O := Nil;
      end else O := It.NextSchObject;
    end;
  finally Doc.SchIterator_Destroy(It); end;
end;

procedure DeleteComponentExact(Doc : ISch_Document; Uid : WideString);
var C : ISch_Component;
begin
  C := FindComponentByUniqueId(Doc, Uid);
  if C <> Nil then begin
    SchServer.ProcessControl.PreProcess(Doc, '');
    try
      Doc.RemoveSchObject(C);
      SchServer.RobotManager.SendMessage(Doc.I_ObjectAddress, c_BroadCast,
        SCHM_PrimitiveRegistration, C.I_ObjectAddress);
    finally SchServer.ProcessControl.PostProcess(Doc, ''); end;
  end;
end;

function CleanupCreatedObjects(Doc : ISch_Document; Journal : TStringList;
  S : TStringList) : Boolean;
var I : Integer; Uid : WideString; Ok : Boolean;
begin
  Result := False;
  for I := 0 to Journal.Count - 1 do begin
    Uid := Copy(Journal[I], Pos('=', Journal[I]) + 1, 99);
    if Pos('DUT=', Journal[I]) = 1 then DeleteComponentExact(Doc, Uid);
    if Pos('FIXTURE=', Journal[I]) = 1 then DeleteComponentExact(Doc, Uid);
    if Pos('LABEL=', Journal[I]) = 1 then DeleteByUniqueId(Doc, Uid);
  end;
  Ok := (CountComponents(Doc) = 0) and (CountWires(Doc) = 0) and
        (CountNetLabels(Doc) = 0);
  S.Add('components_final=' + IntToStr(CountComponents(Doc)));
  S.Add('wires_final=' + IntToStr(CountWires(Doc)));
  S.Add('netlabels_final=' + IntToStr(CountNetLabels(Doc)));
  if Ok then S.Add('stage_schematic_cleanup=PASS')
  else begin
    S.Add('stage_schematic_cleanup=FAIL');
    S.Add('cleanup_error=SCHEMATIC_CLEANUP_FAILED');
  end;
  Result := Ok;
end;

procedure LoadPinMap(Path : WideString; Desig, Net : TStringList);
var L : TStringList; I : Integer; Line : WideString;
begin
  L := TStringList.Create;
  try
    L.LoadFromFile(Path);
    for I := 0 to L.Count - 1 do begin
      Line := L[I];
      if Length(Line) > 0 then begin
        Desig.Add(FieldAt(Line, 0));
        Net.Add(FieldAt(Line, 1));
      end;
    end;
  finally L.Free; end;
end;

procedure LoadElements(Path : WideString; Typ, Name, N1, N2, Value,
  AcMag, AcPhase : TStringList);
var L : TStringList; I : Integer; Line : WideString;
begin
  L := TStringList.Create;
  try
    L.LoadFromFile(Path);
    for I := 0 to L.Count - 1 do begin
      Line := L[I];
      if Length(Line) > 0 then begin
        Typ.Add(FieldAt(Line, 0));
        Name.Add(FieldAt(Line, 1));
        N1.Add(FieldAt(Line, 2));
        N2.Add(FieldAt(Line, 3));
        Value.Add(FieldAt(Line, 4));
        AcMag.Add(FieldAt(Line, 5));
        AcPhase.Add(FieldAt(Line, 6));
      end;
    end;
  finally L.Free; end;
end;

function FindIntLibPath(M : IIntegratedLibraryManager) : WideString;
var I : Integer; P : WideString;
begin
  Result := '';
  for I := 0 to M.AvailableLibraryCount - 1 do begin
    P := M.AvailableLibraryPath(I);
    if Pos('Simulation Generic Components.IntLib', P) > 0 then Result := P;
  end;
end;

function PlaceElement(Doc : ISch_Document; M : IIntegratedLibraryManager;
  IntLibPath, Typ, Name, Value, AcMag, AcPhase : WideString;
  X, Y : Integer; Journal : TStringList; var Comp : ISch_Component) : Boolean;
var LibRef, Params : WideString; Ok : Boolean;
begin
  Result := False;
  Comp := Nil;
  if Typ = 'V' then LibRef := 'VSRC'
  else if Typ = 'I' then LibRef := 'ISRC'
  else if Typ = 'R' then LibRef := 'Resistor'
  else if Typ = 'C' then LibRef := 'Capacitor'
  else if Typ = 'L' then LibRef := 'Inductor'
  else Exit;
  Params := 'Orientation=0|Location.X=' + IntToStr(MilsToCoord(X)) +
    '|Location.Y=' + IntToStr(MilsToCoord(Y));
  Ok := M.PlaceLibraryComponent(LibRef, IntLibPath, Params);
  if not Ok then Exit;
  Comp := FindComponentAt(Doc, X, Y);
  if Comp = Nil then Exit;
  SetDesignator(Doc, Comp, Name);
  if (Typ = 'V') or (Typ = 'I') then begin
    if Value = '' then SetParamText(Doc, Comp, 'Value', '0')
    else SetParamText(Doc, Comp, 'Value', Value);
    if AcMag <> '' then SetParamText(Doc, Comp, 'AC Magnitude', AcMag)
    else SetParamText(Doc, Comp, 'AC Magnitude', '0');
    if AcPhase <> '' then SetParamText(Doc, Comp, 'AC Phase', AcPhase)
    else SetParamText(Doc, Comp, 'AC Phase', '0');
  end else begin
    if Value <> '' then SetParamText(Doc, Comp, 'Value', Value);
  end;
  Journal.Add('FIXTURE=' + Comp.UniqueId);
  Result := True;
end;

procedure RunExperiment;
var
  S, Journal : TStringList;
  PinDesig, PinName, PinHotXs, PinHotYs, PinElec, PinHidden : TStringList;
  MapDesig, MapNet : TStringList;
  ElTyp, ElName, ElN1, ElN2, ElValue, ElAcMag, ElAcPhase : TStringList;
  ElUid, ElDesig, ElX, ElY : TStringList;
  D : IDocument;
  Doc : ISch_Document;
  Comp, C : ISch_Component;
  It, Child : ISch_Iterator;
  O, P, Pin : Variant;
  M : IIntegratedLibraryManager;
  LibPath, LibName, TableName, TargetId, DutDesignator, ProjPath, DocPath,
  NsxPath, SdfPath, RunDir, PinMapPath, ElementPlanPath, IntLibPath : WideString;
  I, J, K, PinCount, MapCount, ElCount, Before, After, ModelIndex : Integer;
  X, Y, Col, Row : Integer;
  Workspace : IWorkspace;
  ProjectObj : IProject;
  LogicalDoc : IDocument;
  Net : INet;
  NetPin : INetItem;
  SimModelFound : Boolean;
  SimModelName, SimPortMap, Tmp, Desig, Expected, Actual : WideString;
  Failed, Ok : Boolean;
  AssignedNets : TStringList;
  ActualDutNet, ActualFixNet : TStringList;
  PinIndex, FixIndex : Integer;
  Detail : WideString;
begin
  RunDir := 'C:\Users\Nomatin\projects\Spice Tester\temp\dblib_runs\20261118_021700_c29b86';
  ProjPath := 'C:\Users\Nomatin\projects\Spice Tester\temp\dblib_runs\20261118_021700_c29b86\Test_20261118_021700_c29b86.PrjPcb';
  DocPath := 'C:\Users\Nomatin\projects\Spice Tester\temp\dblib_runs\20261118_021700_c29b86\Test_20261118_021700_c29b86.SchDoc';
  NsxPath := 'C:\Users\Nomatin\projects\Spice Tester\temp\dblib_runs\20261118_021700_c29b86\Project Outputs for Test_20261118_021700_c29b86\Test_20261118_021700_c29b86.nsx';
  SdfPath := 'C:\Users\Nomatin\projects\Spice Tester\temp\dblib_runs\20261118_021700_c29b86\Simulation\Test_20261118_021700_c29b86.sdf';
  LibPath := 'C:\Users\Nomatin\Documents\Altium\MY_LIB\MY_LIB\MY_LIB_IEC.DbLib';
  LibName := 'MY_LIB_IEC.DbLib';
  TableName := #73#69#67#32#84#114#97#110#115#105#115#116#111#114#115#36;
  TargetId := 'VT0001';
  DutDesignator := 'X1';
  PinMapPath := 'C:\Users\Nomatin\projects\Spice Tester\temp\dblib_runs\20261118_021700_c29b86\pin_map.txt';
  ElementPlanPath := 'C:\Users\Nomatin\projects\Spice Tester\temp\dblib_runs\20261118_021700_c29b86\elements.txt';

  S := TStringList.Create;
  Journal := TStringList.Create;
  PinDesig := TStringList.Create; PinName := TStringList.Create;
  PinHotXs := TStringList.Create; PinHotYs := TStringList.Create;
  PinElec := TStringList.Create; PinHidden := TStringList.Create;
  MapDesig := TStringList.Create; MapNet := TStringList.Create;
  ElTyp := TStringList.Create; ElName := TStringList.Create;
  ElN1 := TStringList.Create; ElN2 := TStringList.Create;
  ElValue := TStringList.Create; ElAcMag := TStringList.Create;
  ElAcPhase := TStringList.Create;
  ElUid := TStringList.Create; ElDesig := TStringList.Create;
  ElX := TStringList.Create; ElY := TStringList.Create;
  AssignedNets := TStringList.Create;
  ActualDutNet := TStringList.Create; ActualFixNet := TStringList.Create;
  Failed := False;
  SimModelFound := False;
  SimModelName := '';
  SimPortMap := '';
  Comp := Nil; Doc := Nil; D := Nil;

  S.Add('stage_library_lookup=NOT_RUN');
  S.Add('stage_component_placement=NOT_RUN');
  S.Add('stage_simulation_model=NOT_RUN');
  S.Add('stage_connectivity=NOT_RUN');
  S.Add('stage_netlist_generation=NOT_RUN');
  S.Add('stage_simulation=NOT_RUN');
  S.Add('stage_schematic_cleanup=NOT_RUN');

  try
    S.Add('STARTED');
    S.SaveToFile(RunDir + '\started.txt');
    S.Add('library_path=' + LibPath);
    S.Add('library_name=' + LibName);
    S.Add('table_name=' + TableName);
    S.Add('database_keys=' + TargetId);
    S.Add('designator=' + DutDesignator);

    ResetParameters;
    AddStringParameter('ObjectKind', 'Project');
    AddStringParameter('FileName', ProjPath);
    RunProcess('WorkspaceManager:OpenObject');
    ResetParameters;
    AddStringParameter('ObjectKind', 'Document');
    AddStringParameter('FileName', DocPath);
    RunProcess('WorkspaceManager:OpenObject');
    D := Client.GetDocumentByPath(DocPath);
    Doc := SchServer.GetSchDocumentByPath(DocPath);
    if (D = Nil) or (Doc = Nil) then begin
      AddError(S, 'library_lookup', 'SCHEMATIC_NOT_OPENED',
        'Test project or schematic could not be opened');
      Failed := True;
    end;

    M := IntegratedLibraryManager;
    IntLibPath := FindIntLibPath(M);
    if IntLibPath = '' then begin
      AddError(S, 'component_placement', 'FIXTURE_INTLIB_NOT_FOUND',
        'Simulation Generic Components.IntLib is not installed');
      Failed := True;
    end;

    if not Failed then begin
      Client.ShowDocument(D);
      Doc := SchServer.GetSchDocumentByPath(DocPath);
      Comp := SchServer.LoadComponentFromDatabaseLibrary(LibPath, TableName, TargetId);
      if Comp = Nil then begin
        S.Add('stage_library_lookup=FAIL');
        AddError(S, 'library_lookup', 'COMPONENT_NOT_FOUND',
          'DbLib loader returned nil for page/id');
        Failed := True;
      end else begin
        S.Add('stage_library_lookup=PASS');
        S.Add('part_count_no_part0=' + IntToStr(Comp.GetState_PartCountNoPart0));
        S.Add('multipart_flag=' + BoolToStr(Comp.IsMultiPartComponent, True));
        S.Add('current_part_id=' + IntToStr(Comp.GetState_CurrentPartID));
        if Comp.IsMultiPartComponent then begin
          AddError(S, 'component_placement', 'MULTIPART_UNSUPPORTED',
            'Multi-part components are not supported in this generator');
          Failed := True;
        end;
      end;
    end;

    if not Failed then begin
      Comp.MoveToXY(MilsToCoord(8000), MilsToCoord(4000));
      Comp.SetState_Orientation(0);
      SchServer.ProcessControl.PreProcess(Doc, '');
      try
        Doc.RegisterSchObjectInContainer(Comp);
        SchServer.RobotManager.SendMessage(Doc.I_ObjectAddress, c_BroadCast,
          SCHM_PrimitiveRegistration, Comp.I_ObjectAddress);
      finally SchServer.ProcessControl.PostProcess(Doc, ''); end;
      Doc.GraphicallyInvalidate;
      if DutDesignator <> '' then SetDesignator(Doc, Comp, DutDesignator);
      S.Add('designator_readback=' + Comp.Designator.Text);
      Journal.Add('DUT=' + Comp.UniqueId);
      S.Add('unique_id=' + Comp.UniqueId);
      S.Add('lib_reference=' + Comp.LibReference);
      S.Add('database_library_name=' + Comp.DatabaseLibraryName);
      S.Add('database_table_name=' + Comp.DatabaseTableName);
      S.Add('database_keys=' + Comp.GetState_DatabaseLibraryKeys('[[/]]'));
      S.Add('design_item_id=' + Comp.DesignItemId);
      S.Add('x_mil=' + IntToStr(CoordToMils(Comp.Location.X)));
      S.Add('y_mil=' + IntToStr(CoordToMils(Comp.Location.Y)));

      Child := Comp.SchIterator_Create;
      Child.AddFilter_ObjectSet(MkSet(eParameter));
      try
        P := Child.FirstSchObject;
        while P <> Nil do begin
          S.Add('parameter.' + P.GetState_Name + '=' + CleanValue(P.GetState_Text));
          P := Child.NextSchObject;
        end;
      finally Comp.SchIterator_Destroy(Child); end;

      Child := Comp.SchIterator_Create;
      Child.AddFilter_ObjectSet(MkSet(eImplementation));
      ModelIndex := 0;
      try
        O := Child.FirstSchObject;
        while O <> Nil do begin
          if O.GetState_ModelType = 'SIM' then begin
            if (not SimModelFound) or O.GetState_IsCurrent then begin
              SimModelFound := True;
              SimModelName := O.GetState_ModelName;
              SimPortMap := CleanValue(O.GetState_MapAsString);
            end;
          end;
          S.Add('implementation.' + IntToStr(ModelIndex) + '=' +
            O.GetState_ModelName + '|' + O.GetState_ModelType +
            '|current=' + IntToStr(Ord(O.GetState_IsCurrent)) +
            '|database=' + IntToStr(Ord(O.GetState_DatabaseModel)) +
            '|files=' + IntToStr(O.GetState_DatafileLinkCount));
          S.Add('implementation.map.' + IntToStr(ModelIndex) + '=' +
            CleanValue(O.GetState_MapAsString));
          S.Add('implementation.description.' + IntToStr(ModelIndex) + '=' +
            CleanValue(O.GetState_Description));
          Inc(ModelIndex);
          O := Child.NextSchObject;
        end;
      finally Comp.SchIterator_Destroy(Child); end;
      S.Add('sim_model_found=' + BoolToStr(SimModelFound, True));
      S.Add('sim_model_name=' + SimModelName);
      S.Add('sim_port_map=' + SimPortMap);

      PinCount := 0;
      Child := Comp.SchIterator_Create;
      Child.AddFilter_ObjectSet(MkSet(ePin));
      Child.SetState_IterationDepth(eIterateFirstLevel);
      try
        Pin := Child.FirstSchObject;
        while Pin <> Nil do begin
          Desig := Pin.GetState_Designator;
          X := HotX(Pin);
          Y := HotY(Pin);
          J := 0;
          PinIndex := -1;
          while J < PinCount do begin
            if CompareText(PinDesig[J], Desig) = 0 then PinIndex := J;
            Inc(J);
          end;
          if PinIndex >= 0 then begin
            if (PinHotXs[PinIndex] <> IntToStr(X)) or
               (PinHotYs[PinIndex] <> IntToStr(Y)) then begin
              AddError(S, 'component_placement', 'COMPONENT_PIN_AMBIGUOUS',
                'Pin designator occurs at different locations: ' + Desig);
              Failed := True;
            end;
          end else begin
            J := 0;
            while J < PinCount do begin
              if (PinHotXs[J] = IntToStr(X)) and (PinHotYs[J] = IntToStr(Y)) then begin
                AddError(S, 'component_placement', 'COMPONENT_PIN_AMBIGUOUS',
                  'Different pins share the same hotspot: ' + Desig);
                Failed := True;
              end;
              Inc(J);
            end;
            Inc(PinCount);
            PinDesig.Add(Desig);
            PinName.Add(Pin.GetState_Name);
            PinHotXs.Add(IntToStr(X));
            PinHotYs.Add(IntToStr(Y));
            PinElec.Add(IntToStr(Ord(Pin.GetState_Electrical)));
            PinHidden.Add(BoolToStr(Pin.GetState_IsHidden, True));
            S.Add('pin.' + IntToStr(PinCount) + '.designator=' + Desig);
            S.Add('pin.' + IntToStr(PinCount) + '.name=' + Pin.GetState_Name);
            S.Add('pin.' + IntToStr(PinCount) + '.electrical=' +
              IntToStr(Ord(Pin.GetState_Electrical)));
            S.Add('pin.' + IntToStr(PinCount) + '.hidden=' +
              BoolToStr(Pin.GetState_IsHidden, True));
            S.Add('pin.' + IntToStr(PinCount) + '.hotspot=' +
              IntToStr(X) + '|' + IntToStr(Y));
          end;
          Pin := Child.NextSchObject;
        end;
      finally Comp.SchIterator_Destroy(Child); end;
      S.Add('pin_count=' + IntToStr(PinCount));
      if PinCount = 0 then begin
        AddError(S, 'component_placement', 'COMPONENT_NO_PINS',
          'Loaded component has no pins');
        Failed := True;
      end;

      I := 0;
      while (I < PinCount) and (not Failed) do begin
        J := I + 1;
        while J < PinCount do begin
          if CompareText(PinDesig[I], PinDesig[J]) = 0 then begin
            AddError(S, 'component_placement', 'COMPONENT_PIN_AMBIGUOUS',
              'Duplicate pin designator: ' + PinDesig[I]);
            Failed := True;
            J := PinCount;
          end else Inc(J);
        end;
        Inc(I);
      end;

      if not SimModelFound then begin
        AddError(S, 'simulation_model', 'COMPONENT_SIM_MODEL_MISSING',
          'Component has no SIM implementation');
        Failed := True;
      end else if SimPortMap = '' then begin
        AddError(S, 'simulation_model', 'COMPONENT_SIM_PORT_MAP_INVALID',
          'SIM implementation has no port map');
        Failed := True;
      end else
        S.Add('stage_simulation_model=PASS');
    end;

    if not Failed then begin
      S.Add('stage_component_placement=PASS');
      LoadPinMap(PinMapPath, MapDesig, MapNet);
      MapCount := MapDesig.Count;
      S.Add('pin_map_count=' + IntToStr(MapCount));
      for I := 0 to MapCount - 1 do begin
        S.Add('pin_map.' + IntToStr(I) + '.designator=' + MapDesig[I]);
        S.Add('pin_map.' + IntToStr(I) + '.net=' + MapNet[I]);
        J := 0;
        PinIndex := -1;
        while J < PinCount do begin
          if CompareText(PinDesig[J], MapDesig[I]) = 0 then PinIndex := J;
          Inc(J);
        end;
        if PinIndex < 0 then begin
          AddError(S, 'component_placement', 'COMPONENT_PIN_NOT_FOUND',
            'Pin from component.pins is absent from the symbol: ' + MapDesig[I]);
          S.Add('pin_error.pin=' + MapDesig[I]);
          S.Add('pin_error.expected=' + MapNet[I]);
          S.Add('pin_error.reason=pin_not_found');
          Failed := True;
        end;
        if MapNet[I] <> '<NULL>' then AssignedNets.Add(MapNet[I]);
      end;
      for I := 0 to PinCount - 1 do begin
        J := 0;
        Ok := False;
        while J < MapCount do begin
          if CompareText(MapDesig[J], PinDesig[I]) = 0 then Ok := True;
          Inc(J);
        end;
        if not Ok then begin
          AddError(S, 'component_placement', 'COMPONENT_PIN_UNASSIGNED',
            'Pin has no explicit entry in component.pins: ' + PinDesig[I]);
          S.Add('pin_error.pin=' + PinDesig[I]);
          S.Add('pin_error.expected=<unassigned>');
          S.Add('pin_error.reason=pin_unassigned');
          Failed := True;
        end;
      end;
    end;

    if not Failed then begin
      for I := 0 to PinCount - 1 do begin
        J := 0;
        Actual := '<NULL>';
        while J < MapCount do begin
          if CompareText(MapDesig[J], PinDesig[I]) = 0 then Actual := MapNet[J];
          Inc(J);
        end;
        if (Actual <> '<NULL>') and (Actual <> '') then begin
          if not ConnectPin(Doc, Comp, PinDesig[I], Actual, Journal) then begin
            AddError(S, 'connectivity', 'COMPONENT_PIN_CONNECTION_FAILED',
              'Could not place Net Label on DUT pin ' + PinDesig[I]);
            S.Add('pin_error.pin=' + PinDesig[I]);
            S.Add('pin_error.expected=' + Actual);
            S.Add('pin_error.reason=label_not_placed');
            Failed := True;
          end;
        end;
      end;
    end;

    if not Failed then begin
      LoadElements(ElementPlanPath, ElTyp, ElName, ElN1, ElN2, ElValue,
        ElAcMag, ElAcPhase);
      ElCount := ElTyp.Count;
      S.Add('fixture_count=' + IntToStr(ElCount));
      for I := 0 to ElCount - 1 do begin
        Col := I mod 4;
        Row := I div 4;
        X := 1500 + Col * 1400;
        Y := 1500 + Row * 1200;
        C := Nil;
        if not PlaceElement(Doc, M, IntLibPath, ElTyp[I], ElName[I],
          ElValue[I], ElAcMag[I], ElAcPhase[I], X, Y, Journal, C) then begin
          AddError(S, 'component_placement', 'FIXTURE_PLACEMENT_FAILED',
            'Could not place fixture element ' + ElName[I]);
          Failed := True;
        end else begin
          ElUid.Add(C.UniqueId);
          ElDesig.Add(ElName[I]);
          ElX.Add(IntToStr(CoordToMils(C.Location.X)));
          ElY.Add(IntToStr(CoordToMils(C.Location.Y)));
          S.Add('fixture.' + IntToStr(I) + '.type=' + ElTyp[I]);
          S.Add('fixture.' + IntToStr(I) + '.name=' + ElName[I]);
          S.Add('fixture.' + IntToStr(I) + '.designator=' + ElName[I]);
          S.Add('fixture.' + IntToStr(I) + '.x=' + IntToStr(X));
          S.Add('fixture.' + IntToStr(I) + '.y=' + IntToStr(Y));
          S.Add('fixture.' + IntToStr(I) + '.value=' + ElValue[I]);
          S.Add('fixture.' + IntToStr(I) + '.ac_magnitude=' + ElAcMag[I]);
          S.Add('fixture.' + IntToStr(I) + '.ac_phase=' + ElAcPhase[I]);
          S.Add('fixture.' + IntToStr(I) + '.designator_readback=' + C.Designator.Text);
          S.Add('fixture.' + IntToStr(I) + '.value_readback=' + GetParamText(C, 'Value'));
          S.Add('fixture.' + IntToStr(I) + '.ac_magnitude_readback=' +
            GetParamText(C, 'AC Magnitude'));
          S.Add('fixture.' + IntToStr(I) + '.x_readback=' +
            IntToStr(CoordToMils(C.Location.X)));
          S.Add('fixture.' + IntToStr(I) + '.y_readback=' +
            IntToStr(CoordToMils(C.Location.Y)));
          if not ConnectPin(Doc, C, '1', ElN1[I], Journal) then begin
            AddError(S, 'connectivity', 'COMPONENT_PIN_CONNECTION_FAILED',
              'Could not connect fixture ' + ElName[I] + ' pin 1 to ' + ElN1[I]);
            Failed := True;
          end;
          if not ConnectPin(Doc, C, '2', ElN2[I], Journal) then begin
            AddError(S, 'connectivity', 'COMPONENT_PIN_CONNECTION_FAILED',
              'Could not connect fixture ' + ElName[I] + ' pin 2 to ' + ElN2[I]);
            Failed := True;
          end;
        end;
      end;
    end;

    if not Failed then begin
      Workspace := GetWorkspace;
      ProjectObj := Workspace.DM_GetProjectFromPath(ProjPath);
      if ProjectObj = Nil then begin
        AddError(S, 'connectivity', 'PROJECT_NOT_FOUND',
          'Project object is not available for compilation');
        Failed := True;
      end else begin
        S.Add('compile_result=' + BoolToStr(ProjectObj.DM_Compile, True));
        S.Add('violation_count=' + IntToStr(ProjectObj.DM_ViolationCount));
        for I := 0 to PinCount - 1 do ActualDutNet.Add('<NULL>');
        for I := 0 to ElCount - 1 do begin
          ActualFixNet.Add('<NULL>');
          ActualFixNet.Add('<NULL>');
        end;
        for I := 0 to ProjectObj.DM_LogicalDocumentCount - 1 do begin
          LogicalDoc := ProjectObj.DM_LogicalDocuments(I);
          if CompareText(LogicalDoc.DM_FullPath, DocPath) = 0 then begin
            S.Add('net_count=' + IntToStr(LogicalDoc.DM_NetCount));
            for J := 0 to LogicalDoc.DM_NetCount - 1 do begin
              Net := LogicalDoc.DM_Nets(J);
              if Net <> Nil then begin
                S.Add('net.' + IntToStr(J) + '.name=' + Net.DM_NetName +
                  '|pins=' + IntToStr(Net.DM_PinCount));
                for K := 0 to Net.DM_PinCount - 1 do begin
                  NetPin := Net.DM_Pins(K);
                  if NetPin <> Nil then begin
                    S.Add('net.' + IntToStr(J) + '.pin=' +
                      NetPin.DM_LogicalPartDesignator + '|' +
                      NetPin.DM_PinNumber + '|uid=' + NetPin.DM_PartUniqueId);
                    if Pos(Comp.UniqueId, NetPin.DM_PartUniqueId) > 0 then begin
                      for PinIndex := 0 to PinCount - 1 do begin
                        if CompareText(PinDesig[PinIndex], NetPin.DM_PinNumber) = 0 then
                          ActualDutNet[PinIndex] := Net.DM_NetName;
                      end;
                    end;
                    for FixIndex := 0 to ElCount - 1 do begin
                      if Pos(ElUid[FixIndex], NetPin.DM_PartUniqueId) > 0 then begin
                        if NetPin.DM_PinNumber = '1' then
                          ActualFixNet[FixIndex * 2] := Net.DM_NetName;
                        if NetPin.DM_PinNumber = '2' then
                          ActualFixNet[FixIndex * 2 + 1] := Net.DM_NetName;
                      end;
                    end;
                  end;
                end;
              end;
            end;
          end;
        end;

        for I := 0 to PinCount - 1 do begin
          J := 0;
          Expected := '<NULL>';
          while J < MapCount do begin
            if CompareText(MapDesig[J], PinDesig[I]) = 0 then Expected := MapNet[J];
            Inc(J);
          end;
          Actual := ActualDutNet[I];
          if Expected = '<NULL>' then begin
            if (Actual <> '<NULL>') and (AssignedNets.IndexOf(Actual) >= 0) then begin
              S.Add('pin_error.pin=' + PinDesig[I]);
              S.Add('pin_error.expected=<NULL>');
              S.Add('pin_error.actual=' + Actual);
              S.Add('pin_error.reason=unconnected_pin_merged');
              AddError(S, 'connectivity', 'COMPONENT_PIN_CONNECTION_FAILED',
                'Unconnected DUT pin is on a named net: ' + PinDesig[I]);
              Failed := True;
            end;
          end else if CompareText(Expected, Actual) <> 0 then begin
            S.Add('pin_error.pin=' + PinDesig[I]);
            S.Add('pin_error.expected=' + Expected);
            S.Add('pin_error.actual=' + Actual);
            S.Add('pin_error.reason=compiled_net_mismatch');
            AddError(S, 'connectivity', 'COMPONENT_PIN_CONNECTION_FAILED',
              'DUT pin ' + PinDesig[I] + ' is on ' + Actual +
              ' instead of ' + Expected);
            Failed := True;
          end;
        end;

        for I := 0 to ElCount - 1 do begin
          if CompareText(ActualFixNet[I * 2], ElN1[I]) <> 0 then begin
            AddError(S, 'connectivity', 'COMPONENT_PIN_CONNECTION_FAILED',
              'Fixture ' + ElName[I] + ' pin 1 is on ' +
              ActualFixNet[I * 2] + ' instead of ' + ElN1[I]);
            Failed := True;
          end;
          if CompareText(ActualFixNet[I * 2 + 1], ElN2[I]) <> 0 then begin
            AddError(S, 'connectivity', 'COMPONENT_PIN_CONNECTION_FAILED',
              'Fixture ' + ElName[I] + ' pin 2 is on ' +
              ActualFixNet[I * 2 + 1] + ' instead of ' + ElN2[I]);
            Failed := True;
          end;
        end;

        if not Failed then S.Add('stage_connectivity=PASS');
      end;
    end;

    if not Failed then begin
      if D.DoFileSave('') then S.Add('schematic_saved_before_sim=1');
      Client.ShowDocument(D);
      Doc := SchServer.GetSchDocumentByPath(DocPath);
      RunProcess('ADVSIM:RunSimulator');
      if FileExists(NsxPath) then begin
        S.Add('stage_netlist_generation=PASS');
        S.Add('nsx_path=' + NsxPath);
      end else begin
        AddError(S, 'netlist_generation', 'NSX_NOT_GENERATED',
          'Altium did not generate the expected NSX');
        Failed := True;
      end;
    end;

    if not Failed then begin
      ResetParameters;
      AddStringParameter('ObjectKind', 'Document');
      AddStringParameter('FileName', NsxPath);
      RunProcess('WorkspaceManager:OpenObject');
      D := Client.GetDocumentByPath(NsxPath);
      if D = Nil then begin
        AddError(S, 'simulation', 'NSX_NOT_OPENED',
          'Altium-generated NSX could not be opened');
        Failed := True;
      end else begin
        Client.ShowDocument(D);
        RunProcess('ADVSIM:RunSimulator');
        if Client.CurrentView <> Nil then begin
          S.Add('current_after_sim=' + Client.CurrentView.OwnerDocument.FileName);
          Client.CurrentView.OwnerDocument.DoFileSave('');
        end;
        if FileExists(SdfPath) then begin
          S.Add('stage_simulation=PASS');
          S.Add('sdf_path=' + SdfPath);
        end else begin
          AddError(S, 'simulation', 'SDF_NOT_SAVED',
            'MixedSim did not produce the expected SDF');
          Failed := True;
        end;
      end;
    end;
  except
    AddError(S, 'altium', 'ALTIUM_SCRIPT_EXCEPTION',
      'Unhandled exception in DbLib fixture script');
    Failed := True;
  end;

  try
    if D <> Nil then begin
      D := Client.GetDocumentByPath(DocPath);
      if D <> Nil then Client.ShowDocument(D);
      Doc := SchServer.GetSchDocumentByPath(DocPath);
    end;
    if Doc = Nil then begin
      S.Add('stage_schematic_cleanup=NOT_APPLICABLE');
      S.Add('schematic_saved_after_cleanup=0');
    end else begin
      if not CleanupCreatedObjects(Doc, Journal, S) then Failed := True;
      if D = Nil then begin
        D := Client.GetDocumentByPath(DocPath);
        if D <> Nil then Client.ShowDocument(D);
      end;
      if D <> Nil then begin
        if D.DoFileSave('') then S.Add('schematic_saved_after_cleanup=1')
        else begin
          S.Add('schematic_saved_after_cleanup=0');
          S.Add('stage_schematic_cleanup=FAIL');
          S.Add('cleanup_error=SCHEMATIC_CLEANUP_FAILED');
          Failed := True;
        end;
      end else begin
        S.Add('schematic_saved_after_cleanup=0');
        S.Add('stage_schematic_cleanup=FAIL');
        S.Add('cleanup_error=SCHEMATIC_CLEANUP_FAILED');
        Failed := True;
      end;
    end;
  except
    S.Add('stage_schematic_cleanup=FAIL');
    S.Add('cleanup_error=SCHEMATIC_CLEANUP_FAILED');
    S.Add('schematic_saved_after_cleanup=0');
    Failed := True;
  end;

  if Failed then begin
    S.Add('script_failed=1');
    S.Add('STATUS=ERROR');
  end else begin
    S.Add('script_failed=0');
    S.Add('STATUS=OK');
  end;
  S.SaveToFile(RunDir + '\status.txt');
  S.Free; Journal.Free;
  PinDesig.Free; PinName.Free; PinHotXs.Free; PinHotYs.Free;
  PinElec.Free; PinHidden.Free; MapDesig.Free; MapNet.Free;
  ElTyp.Free; ElName.Free; ElN1.Free; ElN2.Free; ElValue.Free;
  ElAcMag.Free; ElAcPhase.Free; ElUid.Free; ElDesig.Free;
  ElX.Free; ElY.Free; AssignedNets.Free; ActualDutNet.Free;
  ActualFixNet.Free;
end;
