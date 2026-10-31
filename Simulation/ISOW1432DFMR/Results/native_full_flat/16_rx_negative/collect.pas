procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\cd314e3622bc4e1d9332e06a1b5ad639\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\cd314e3622bc4e1d9332e06a1b5ad639\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\cd314e3622bc4e1d9332e06a1b5ad639\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\cd314e3622bc4e1d9332e06a1b5ad639\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\cd314e3622bc4e1d9332e06a1b5ad639\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\cd314e3622bc4e1d9332e06a1b5ad639\status.txt');
 S.Free;
end;
