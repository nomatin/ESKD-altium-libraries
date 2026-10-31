procedure RunTests;
var S, D;
begin
 S := TStringList.Create;
 try
  S.Add('STARTED');
  S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\904964b7668c4d1a97a66d6b4531df87\started.txt');
  ResetParameters;
  AddStringParameter('ObjectKind', 'Document');
  AddStringParameter('FileName', 'C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\904964b7668c4d1a97a66d6b4531df87\test.nsx');
  RunProcess('WorkspaceManager:OpenObject');
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\904964b7668c4d1a97a66d6b4531df87\test.nsx');
  if D = Nil then begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SIM_NOT_RUN');
  end else begin
   Client.ShowDocument(D);
   RunProcess('ADVSIM:RunSimulator');
   D := Client.CurrentView.OwnerDocument;
   if LowerCase(D.FileName) <> LowerCase('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\904964b7668c4d1a97a66d6b4531df87\test.sdf') then begin
    S.Add('STATUS=ERROR'); S.Add('CODE=SIM_NOT_RUN');
   end else begin
    if D.DoFileSave('') then begin
     S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
    end else begin
     S.Add('STATUS=SAVE_PENDING'); S.Add('CODE=SDF_NOT_SAVED');
    end;
   end;
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SIM_NOT_RUN');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\904964b7668c4d1a97a66d6b4531df87\status.tmp');
 RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\904964b7668c4d1a97a66d6b4531df87\status.tmp', 'C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\904964b7668c4d1a97a66d6b4531df87\status.txt');
 S.Free;
end;
