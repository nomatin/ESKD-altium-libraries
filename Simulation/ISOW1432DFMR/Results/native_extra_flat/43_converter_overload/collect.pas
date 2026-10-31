procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\be940dfe0ff44a99aa0ee3a3286807ab\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\be940dfe0ff44a99aa0ee3a3286807ab\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\be940dfe0ff44a99aa0ee3a3286807ab\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\be940dfe0ff44a99aa0ee3a3286807ab\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\be940dfe0ff44a99aa0ee3a3286807ab\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\DBUR-Test\be940dfe0ff44a99aa0ee3a3286807ab\status.txt');
 S.Free;
end;
