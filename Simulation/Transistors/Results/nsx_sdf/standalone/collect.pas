procedure RunTests;
var D, S;
begin
 S := TStringList.Create;
 try
  D := Client.GetDocumentByPath('C:\Users\Nomatin\AppData\Local\Temp\SpiceSifter\89d2ef668965426580982fd725407fc3\test.sdf');
  if D <> Nil then D.DoFileSave('');
  if FileExists('C:\Users\Nomatin\AppData\Local\Temp\SpiceSifter\89d2ef668965426580982fd725407fc3\test.sdf') then begin
   S.Add('STATUS=OK'); S.Add('SDF_PATH=' + D.FileName);
  end else begin
   S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
  end;
 except
  S.Add('STATUS=ERROR'); S.Add('CODE=SDF_NOT_SAVED');
 end;
 S.SaveToFile('C:\Users\Nomatin\AppData\Local\Temp\SpiceSifter\89d2ef668965426580982fd725407fc3\collect.tmp');
 DeleteFile('C:\Users\Nomatin\AppData\Local\Temp\SpiceSifter\89d2ef668965426580982fd725407fc3\status.txt'); RenameFile('C:\Users\Nomatin\AppData\Local\Temp\SpiceSifter\89d2ef668965426580982fd725407fc3\collect.tmp','C:\Users\Nomatin\AppData\Local\Temp\SpiceSifter\89d2ef668965426580982fd725407fc3\status.txt');
 S.Free;
end;
