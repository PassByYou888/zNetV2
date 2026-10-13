
procedure THPC_ConsoleNotify.Run(Sender: TCompute);
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

constructor THPC_ConsoleNotify.Create;
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
  InData := '';
end;

destructor THPC_ConsoleNotify.Destroy;
begin
  Do_Free_Instance_Ptr();
  inherited Destroy;
end;

function THPC_ConsoleNotify.IsOnline: Boolean;
begin
  Result := (Framework <> nil) and (Framework.ExistsID(WorkID));
end;

function THPC_ConsoleNotify.IO: TPeerIO;
begin
  Result := nil;
  if Framework <> nil then
      Result := Framework.FPeerIO_HashPool[WorkID];
end;

procedure RunHPC_ConsoleNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_C);
var
  t: THPC_ConsoleNotify;
begin
  t := THPC_ConsoleNotify.Create;

  t.On_C := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := InData;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_ConsoleNotifyC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_C);
begin
  RunHPC_ConsoleNotifyC(Sender, UserData, UserObject, NULL, InData, OnRun);
end;

procedure RunHPC_ConsoleNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_M);
var
  t: THPC_ConsoleNotify;
begin
  t := THPC_ConsoleNotify.Create;

  t.On_M := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := InData;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_ConsoleNotifyM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_M);
begin
  RunHPC_ConsoleNotifyM(Sender, UserData, UserObject, NULL, InData, OnRun);
end;

procedure RunHPC_ConsoleNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_P);
var
  t: THPC_ConsoleNotify;
begin
  t := THPC_ConsoleNotify.Create;

  t.On_P := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := InData;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_ConsoleNotifyP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData: SystemString; const OnRun: TOnHPC_ConsoleNotify_P);
begin
  RunHPC_ConsoleNotifyP(Sender, UserData, UserObject, NULL, InData, OnRun);
end;

