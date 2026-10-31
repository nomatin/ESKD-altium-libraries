procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\bc7a04e7bbd84606aeb2fa6f95d3bd55\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\bc7a04e7bbd84606aeb2fa6f95d3bd55\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\bc7a04e7bbd84606aeb2fa6f95d3bd55\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\bc7a04e7bbd84606aeb2fa6f95d3bd55\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\bc7a04e7bbd84606aeb2fa6f95d3bd55\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\bc7a04e7bbd84606aeb2fa6f95d3bd55\status.txt');
 S.Free;
end;
