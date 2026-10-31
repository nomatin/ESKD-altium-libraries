procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d9d1e597d9a84afd8e858a66771d84ac\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d9d1e597d9a84afd8e858a66771d84ac\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d9d1e597d9a84afd8e858a66771d84ac\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d9d1e597d9a84afd8e858a66771d84ac\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d9d1e597d9a84afd8e858a66771d84ac\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\d9d1e597d9a84afd8e858a66771d84ac\status.txt');
 S.Free;
end;
