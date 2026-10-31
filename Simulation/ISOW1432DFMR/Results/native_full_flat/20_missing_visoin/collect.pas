procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021e03df5d144e2b9ac5fdd37612f965\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021e03df5d144e2b9ac5fdd37612f965\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021e03df5d144e2b9ac5fdd37612f965\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021e03df5d144e2b9ac5fdd37612f965\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021e03df5d144e2b9ac5fdd37612f965\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\021e03df5d144e2b9ac5fdd37612f965\status.txt');
 S.Free;
end;
