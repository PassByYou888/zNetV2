procedure Init_ZNet_Instance_Pool;
begin
  ZNet_Instance_Pool := TZNet_Instance_Pool.Create;
end;

procedure Free_ZNet_Instance_Pool;
begin
  while ZNet_Instance_Pool.Num > 0 do
      DisposeObjectAndNil(ZNet_Instance_Pool.First^.data);
  DisposeObjectAndNil(ZNet_Instance_Pool);
end;

