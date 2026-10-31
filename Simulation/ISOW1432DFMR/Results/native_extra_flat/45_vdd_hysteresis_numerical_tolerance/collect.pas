procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\c4db35607a7e476c803d79f47e4fee4d\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\c4db35607a7e476c803d79f47e4fee4d\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\c4db35607a7e476c803d79f47e4fee4d\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\c4db35607a7e476c803d79f47e4fee4d\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\c4db35607a7e476c803d79f47e4fee4d\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\c4db35607a7e476c803d79f47e4fee4d\status.txt');
 S.Free;
end;
