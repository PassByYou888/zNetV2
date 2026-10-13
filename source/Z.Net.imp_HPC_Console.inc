procedure THPC_Console.Run(Sender: TCompute);
var
  tk: TTimeTick;
begin
  tk := GetTimeTick();
  TCompute.Set_Thread_Info(PFormat('%s cmd:%s', [ClassName, Cmd]));
  Thread := Sender;
  try
    if Assigned(On_C) then
        On_C(self, InData, OutData)
    else if Assigned(On_M) then
        On_M(self, InData, OutData)
    else if Assigned(On_P) then
        On_P(self, InData, OutData);
  except
  end;

  Framework.CmdMaxExecuteConsumeStatistics.SetMax(Cmd + ':HPC Thread', GetTimeTick - tk);
  with Framework.PostProgress.PostExecuteM_NP(False, 0, RunDone) do
    begin
      Auto_Free_Pool.Add(self);
      Ready;
    end;
  AtomDec(Framework.FCMD_Thread_Runing_Num);
end;

procedure THPC_Console.RunDone();
var
  P_IO: TPeerIO;
begin
  try
    if Framework <> nil then
      begin
        P_IO := Framework.FPeerIO_HashPool[WorkID];
        if P_IO <> nil then
          begin
            try
              if Assigned(OnDone_C) then
                  OnDone_C(self, P_IO, InData, OutData)
              else if Assigned(OnDone_M) then
                  OnDone_M(self, P_IO, InData, OutData)
              else if Assigned(OnDone_P) then
                  OnDone_P(self, P_IO, InData, OutData);
            except
            end;

            P_IO.OutText := P_IO.OutText + OutData;
            P_IO.Resume;
          end;
      end;
  except
  end;
end;

constructor THPC_Console.Create;
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
  OutData := '';
  OnDone_C := nil;
  OnDone_M := nil;
  OnDone_P := nil;
end;

destructor THPC_Console.Destroy;
begin
  Do_Free_Instance_Ptr();
  inherited Destroy;
end;

function THPC_Console.IsOnline: Boolean;
begin
  Result := (Framework <> nil) and (Framework.ExistsID(WorkID));
end;

function THPC_Console.IO: TPeerIO;
begin
  Result := nil;
  if Framework <> nil then
      Result := Framework.FPeerIO_HashPool[WorkID];
end;

procedure RunHPC_ConsoleC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_C);
var
  t: THPC_Console;
begin
  Sender.Pause;
  t := THPC_Console.Create;

  t.On_C := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := InData;
  t.OutData := OutData;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_ConsoleC(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_C);
begin
  RunHPC_ConsoleC(Sender, UserData, UserObject, NULL, InData, OutData, OnRun);
end;

procedure RunHPC_ConsoleM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_M);
var
  t: THPC_Console;
begin
  Sender.Pause;
  t := THPC_Console.Create;

  t.On_M := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := InData;
  t.OutData := OutData;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_ConsoleM(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_M);
begin
  RunHPC_ConsoleM(Sender, UserData, UserObject, NULL, InData, OutData, OnRun);
end;

procedure RunHPC_ConsoleP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_P);
var
  t: THPC_Console;
begin
  Sender.Pause;
  t := THPC_Console.Create;

  t.On_P := OnRun;

  t.Framework := Sender.OwnerFramework;
  t.Cmd := Sender.CurrentCmd;
  t.WorkID := Sender.ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := InData;
  t.OutData := OutData;

  Get_Link_OK_Send_Tunnel(Sender, t.Send_Tunnel, t.Send_Tunnel_ID);

  AtomInc(Sender.OwnerFramework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_ConsoleP(Sender: TPeerIO;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: SystemString; const OnRun: TOnHPC_Console_P);
begin
  RunHPC_ConsoleP(Sender, UserData, UserObject, NULL, InData, OutData, OnRun);
end;

