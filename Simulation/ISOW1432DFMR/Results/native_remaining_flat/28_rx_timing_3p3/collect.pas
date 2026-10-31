procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d50a5002b6f24e55921ec8dfbbc4bc2f\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d50a5002b6f24e55921ec8dfbbc4bc2f\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d50a5002b6f24e55921ec8dfbbc4bc2f\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d50a5002b6f24e55921ec8dfbbc4bc2f\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d50a5002b6f24e55921ec8dfbbc4bc2f\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d50a5002b6f24e55921ec8dfbbc4bc2f\status.txt');
 S.Free;
end;
