procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\2ea3d4140a7a4aed97a22b5da6d8325a\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\2ea3d4140a7a4aed97a22b5da6d8325a\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\2ea3d4140a7a4aed97a22b5da6d8325a\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\2ea3d4140a7a4aed97a22b5da6d8325a\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\2ea3d4140a7a4aed97a22b5da6d8325a\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\2ea3d4140a7a4aed97a22b5da6d8325a\status.txt');
 S.Free;
end;
