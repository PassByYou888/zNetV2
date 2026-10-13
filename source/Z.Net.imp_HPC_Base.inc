procedure THPC_Instance_Pool.DoFree(var data: THPC_Base);
begin
  if data <> nil then
    begin
      if data.Instance_Ptr <> nil then
          data.Instance_Ptr^.data := nil;
      data.Instance_Ptr := nil;
    end;
end;

constructor THPC_Base.Create;
begin
  inherited Create;
  if HPC_Instance_Pool <> nil then
      Instance_Ptr := HPC_Instance_Pool.Add(self)
  else
      Instance_Ptr := nil;
end;

procedure THPC_Base.Do_Free_Instance_Ptr;
var
  p: THPC_Instance_Pool.PQueueStruct;
begin
  if Instance_Ptr <> nil then
    begin
      Instance_Ptr^.data := nil;
      p := Instance_Ptr;
      Instance_Ptr := nil;
      if HPC_Instance_Pool <> nil then
          HPC_Instance_Pool.Remove_P(p);
    end;
end;

destructor THPC_Base.Destroy;
begin
  Do_Free_Instance_Ptr();
  inherited Destroy;
end;

