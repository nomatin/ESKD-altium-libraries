procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\a6b774c8810f4acdba23c16bd067e086\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\a6b774c8810f4acdba23c16bd067e086\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\a6b774c8810f4acdba23c16bd067e086\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\a6b774c8810f4acdba23c16bd067e086\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\a6b774c8810f4acdba23c16bd067e086\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\a6b774c8810f4acdba23c16bd067e086\status.txt');
 S.Free;
end;
