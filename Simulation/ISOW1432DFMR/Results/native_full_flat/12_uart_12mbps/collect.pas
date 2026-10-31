procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021466dc70244c4cb2e4df6d591f8b59\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021466dc70244c4cb2e4df6d591f8b59\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021466dc70244c4cb2e4df6d591f8b59\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021466dc70244c4cb2e4df6d591f8b59\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021466dc70244c4cb2e4df6d591f8b59\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021466dc70244c4cb2e4df6d591f8b59\status.txt');
 S.Free;
end;
