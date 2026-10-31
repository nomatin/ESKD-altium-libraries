procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\08a5619a6eef45a185be8b6f03dcb071\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\08a5619a6eef45a185be8b6f03dcb071\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\08a5619a6eef45a185be8b6f03dcb071\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\08a5619a6eef45a185be8b6f03dcb071\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\08a5619a6eef45a185be8b6f03dcb071\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\08a5619a6eef45a185be8b6f03dcb071\status.txt');
 S.Free;
end;
