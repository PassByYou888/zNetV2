procedure THPC_StreamNotify.Run(Sender: TCompute);
var
  tk: TTimeTick;
begin
  tk := GetTimeTick();
  TCompute.Set_Thread_Info(PFormat('%s cmd:%s', [ClassName, Cmd]));
  Thread := Sender;
  try
    if Assigned(On_C) then
        On_C(self, InData)
    else if Assigned(On_M) then
        On_M(self, InData)
    else if Assigned(On_P) then
        On_P(self, InData);
  except
  end;
  Framework.CmdMaxExecuteConsumeStatistics.SetMax(Cmd + ':HPC Thread', GetTimeTick - tk);
  AtomDec(Framework.FCMD_Thread_Runing_Num);
  DelayFreeObj(1.0, self);
end;

constructor THPC_StreamNotify.Create;
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
  InData := nil; // fixed memory leak. by.qq600585, 2023-9-30
end;

destructor THPC_StreamNotify.Destroy;
begin
  Do_Free_Instance_Ptr();
  DisposeObject(InData);
  inherited Destroy;
end;

function THPC_StreamNotify.IsOnline: Boolean;
begin
  Result := (Framework <> nil) and (Framework.ExistsID(WorkID));
end;

function THPC_StreamNotify.IO: TPeerIO;
begin
  Result := nil;
  if Framework <> nil then
      Result := Framework.FPeerIO_HashPool[WorkID];
end;

procedure RunHPC_StreamNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_C);
var
  t: THPC_StreamNotify;
begin
  t := THPC_StreamNotify.Create;

  t.On_C := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := TDFE.Create;
  if InData <> nil then
      t.InData.SwapInstance(InData);
  t.InData.R.index := 0;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_StreamNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_C);
begin
  RunHPC_StreamNotifyC(Sender, UserData, UserObject, NULL, InData, OnRun);
end;

procedure RunHPC_StreamNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_M);
var
  t: THPC_StreamNotify;
begin
  t := THPC_StreamNotify.Create;

  t.On_M := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := TDFE.Create;
  if InData <> nil then
      t.InData.SwapInstance(InData);
  t.InData.R.index := 0;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_StreamNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_M);
begin
  RunHPC_StreamNotifyM(Sender, UserData, UserObject, NULL, InData, OnRun);
end;

procedure RunHPC_StreamNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_P);
var
  t: THPC_StreamNotify;
begin
  t := THPC_StreamNotify.Create;

  t.On_P := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := TDFE.Create;
  if InData <> nil then
      t.InData.SwapInstance(InData);
  t.InData.R.index := 0;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_StreamNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: TDFE; const OnRun: TOnHPC_StreamNotify_P);
begin
  RunHPC_StreamNotifyP(Sender, UserData, UserObject, NULL, InData, OnRun);
end;


