
procedure THPC_CompleteBuffer.Run(Sender: TCompute);
var
  tk: TTimeTick;
begin
  tk := GetTimeTick();
  TCompute.Set_Thread_Info(PFormat('%s cmd:%s', [ClassName, Cmd]));
  Thread := Sender;
  try
    if Assigned(On_C) then
        On_C(self, InData.Memory, InData.Size)
    else if Assigned(On_M) then
        On_M(self, InData.Memory, InData.Size)
    else if Assigned(On_P) then
        On_P(self, InData.Memory, InData.Size);
  except
  end;
  Framework.CmdMaxExecuteConsumeStatistics.SetMax(Cmd + ':HPC Thread', GetTimeTick - tk);
  AtomDec(Framework.FCMD_Thread_Runing_Num);
  DelayFreeObj(1.0, self);
end;

constructor THPC_CompleteBuffer.Create;
begin
  inherited Create;
  Thread := nil;
  On_C := nil;
  On_M := nil;
  On_P := nil;
  Framework := nil;
  Cmd := '';
  TriggerTime := GetTimeTick();
  WorkID := 0;
  Send_Tunnel := nil;
  Send_Tunnel_ID := 0;
  UserData := nil;
  UserObject := nil;
  UserVariant := NULL;
  InData := nil;
end;

destructor THPC_CompleteBuffer.Destroy;
begin
  Do_Free_Instance_Ptr();
  DisposeObject(InData);
  inherited Destroy;
end;

function THPC_CompleteBuffer.IsOnline: Boolean;
begin
  Result := (Framework <> nil) and (Framework.ExistsID(WorkID));
end;

function THPC_CompleteBuffer.IO: TPeerIO;
begin
  Result := nil;
  if Framework <> nil then
      Result := Framework.FPeerIO_HashPool[WorkID];
end;

procedure RunHPC_CompleteBufferC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_C);
var
  t: THPC_CompleteBuffer;
begin
  t := THPC_CompleteBuffer.Create;

  t.On_C := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CompleteBufferCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := Sender.CompleteBuffer_Current_Trigger.Swap_To_New_Instance;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_CompleteBufferC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_C);
begin
  RunHPC_CompleteBufferC(Sender, UserData, UserObject, NULL, InData, DataSize, OnRun);
end;

procedure RunHPC_CompleteBufferM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_M);
var
  t: THPC_CompleteBuffer;
begin
  t := THPC_CompleteBuffer.Create;

  t.On_M := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CompleteBufferCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := Sender.CompleteBuffer_Current_Trigger.Swap_To_New_Instance;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_CompleteBufferM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_M);
begin
  RunHPC_CompleteBufferM(Sender, UserData, UserObject, NULL, InData, DataSize, OnRun);
end;

procedure RunHPC_CompleteBufferP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_P);
var
  t: THPC_CompleteBuffer;
begin
  t := THPC_CompleteBuffer.Create;

  t.On_P := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CompleteBufferCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := Sender.CompleteBuffer_Current_Trigger.Swap_To_New_Instance;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_CompleteBufferP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: PByte; const DataSize: NativeInt; const OnRun: TOnHPC_CompleteBuffer_P);
begin
  RunHPC_CompleteBufferP(Sender, UserData, UserObject, NULL, InData, DataSize, OnRun);
end;

