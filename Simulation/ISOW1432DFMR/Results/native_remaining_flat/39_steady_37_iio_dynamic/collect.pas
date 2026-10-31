procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\e07666d4c3c64fa0a8f419ab3f338a90\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\e07666d4c3c64fa0a8f419ab3f338a90\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\e07666d4c3c64fa0a8f419ab3f338a90\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\e07666d4c3c64fa0a8f419ab3f338a90\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\e07666d4c3c64fa0a8f419ab3f338a90\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\e07666d4c3c64fa0a8f419ab3f338a90\status.txt');
 S.Free;
end;
