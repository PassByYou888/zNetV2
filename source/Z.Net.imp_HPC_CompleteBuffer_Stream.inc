
procedure THPC_CompleteBuffer_Stream.Run(Sender: TCompute);
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
  Bridge.OutData.SwapInstance(OutData);
  Bridge.Resume;
  Framework.CmdMaxExecuteConsumeStatistics.SetMax(Cmd + ':HPC Thread', GetTimeTick - tk);
  AtomDec(Framework.FCMD_Thread_Runing_Num);
  DelayFreeObj(1.0, self);
end;

constructor THPC_CompleteBuffer_Stream.Create;
begin
  inherited Create;
  Thread := nil;
  On_C := nil;
  On_M := nil;
  On_P := nil;
  Bridge := nil;
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
  OutData := nil; // fixed memory leak. by.qq600585, 2023-9-30
end;

destructor THPC_CompleteBuffer_Stream.Destroy;
begin
  Do_Free_Instance_Ptr();
  DisposeObject(InData);
  DisposeObject(OutData);
  inherited Destroy;
end;

function THPC_CompleteBuffer_Stream.IsOnline: Boolean;
begin
  Result := (Framework <> nil) and (Framework.ExistsID(WorkID));
end;

function THPC_CompleteBuffer_Stream.IO: TPeerIO;
begin
  Result := nil;
  if Framework <> nil then
      Result := Framework.FPeerIO_HashPool[WorkID];
end;

procedure RunHPC_CompleteBuffer_StreamC(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_C);
var
  t: THPC_CompleteBuffer_Stream;
begin
  Sender.Pause;
  t := THPC_CompleteBuffer_Stream.Create;

  t.On_C := OnRun;

  t.Bridge := Sender;
  t.Framework := Sender.R_Framework;
  t.Cmd := Sender.Cmd;
  t.WorkID := Sender.R_ID;
  t.Send_Tunnel := Sender.S_Framework;
  t.Send_Tunnel_ID := Sender.S_ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := TDFE.Create;
  if InData <> nil then
      t.InData.SwapInstance(InData);
  t.InData.R.index := 0;
  t.OutData := TDFE.Create;
  if OutData <> nil then
      t.OutData.SwapInstance(OutData);
  t.OutData.R.index := 0;

  AtomInc(t.Framework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_CompleteBuffer_StreamC(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_C);
begin
  RunHPC_CompleteBuffer_StreamC(Sender, UserData, UserObject, NULL, InData, OutData, OnRun);
end;

procedure RunHPC_CompleteBuffer_StreamM(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_M);
var
  t: THPC_CompleteBuffer_Stream;
begin
  Sender.Pause;
  t := THPC_CompleteBuffer_Stream.Create;

  t.On_M := OnRun;

  t.Bridge := Sender;
  t.Framework := Sender.R_Framework;
  t.Cmd := Sender.Cmd;
  t.WorkID := Sender.R_ID;
  t.Send_Tunnel := Sender.S_Framework;
  t.Send_Tunnel_ID := Sender.S_ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := TDFE.Create;
  if InData <> nil then
      t.InData.SwapInstance(InData);
  t.InData.R.index := 0;
  t.OutData := TDFE.Create;
  if OutData <> nil then
      t.OutData.SwapInstance(OutData);
  t.OutData.R.index := 0;

  AtomInc(t.Framework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_CompleteBuffer_StreamM(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_M);
begin
  RunHPC_CompleteBuffer_StreamM(Sender, UserData, UserObject, NULL, InData, OutData, OnRun);
end;

procedure RunHPC_CompleteBuffer_StreamP(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_P);
var
  t: THPC_CompleteBuffer_Stream;
begin
  Sender.Pause;
  t := THPC_CompleteBuffer_Stream.Create;

  t.On_P := OnRun;

  t.Bridge := Sender;
  t.Framework := Sender.R_Framework;
  t.Cmd := Sender.Cmd;
  t.WorkID := Sender.R_ID;
  t.Send_Tunnel := Sender.S_Framework;
  t.Send_Tunnel_ID := Sender.S_ID;
  t.UserData := UserData;
  t.UserObject := UserObject;
  t.UserVariant := UserVariant;
  t.InData := TDFE.Create;
  if InData <> nil then
      t.InData.SwapInstance(InData);
  t.InData.R.index := 0;
  t.OutData := TDFE.Create;
  if OutData <> nil then
      t.OutData.SwapInstance(OutData);
  t.OutData.R.index := 0;

  AtomInc(t.Framework.FCMD_Thread_Runing_Num);

  TCompute.RunM(UserData, UserObject, t.Run);
end;

procedure RunHPC_CompleteBuffer_StreamP(Sender: TCommandCompleteBuffer_NoWait_Bridge;
  const UserData: Pointer; const UserObject: TCore_Object;
  const InData, OutData: TDFE; const OnRun: TOnHPC_CompleteBuffer_Stream_P);
begin
  RunHPC_CompleteBuffer_StreamP(Sender, UserData, UserObject, NULL, InData, OutData, OnRun);
end;

