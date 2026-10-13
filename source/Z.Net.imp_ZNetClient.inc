procedure TZNet_ServerState.Reset;
begin
  UsedParallelEncrypt := False;
  SyncOnResult := False;
  SyncOnCompleteBuffer := False;
  EnabledAtomicLockAndMultiThread := False;
  TimeOutKeepAlive := False;
  QuietMode := False;
  IdleTimeOut := 0;
  SendDataCompressed := False;
  CompleteBufferCompressed := False;
  MaxCompleteBufferSize := 0;
  ProgressMaxDelay := 0;
  UID := Null_UID();
end;

function TZNet_Client.CanExecuteCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean;
begin
  Result := inherited CanExecuteCommand(Sender, Cmd);
end;

function TZNet_Client.CanSendCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean;
begin
  if IsSystemCMD(Cmd) then
      Result := True
  else
      Result := inherited CanSendCommand(Sender, Cmd);
end;

function TZNet_Client.CanRegCommand(Sender: TZNet; const Cmd: SystemString): Boolean;
begin
  Result := inherited CanRegCommand(Sender, Cmd);
end;

procedure TZNet_Client.FillCustomBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
begin
  if (Protocol = cpCustom) then
    begin
      if Assigned(FOnClientCustomProtocolReceiveBufferNotify) then
        begin
          FOnClientCustomProtocolReceiveBufferNotify(self, Buffer, Size, FillDone);
          if FillDone then
              exit;
        end;
      OnReceiveBuffer(Buffer, Size, FillDone);
    end;
end;

procedure TZNet_Client.ConsoleResult_Wait(Sender: TPeerIO; Result_: SystemString);
begin
  if FWaiting then
    begin
      FWaiting := False;
      FWaitingTimeOut := 0;
      try
        if Assigned(FOnWaitResult_C) then
            FOnWaitResult_C(True)
        else if Assigned(FOnWaitResult_M) then
            FOnWaitResult_M(True)
        else if Assigned(FOnWaitResult_P) then
            FOnWaitResult_P(True);
      except
      end;
      FOnWaitResult_C := nil;
      FOnWaitResult_M := nil;
      FOnWaitResult_P := nil;
    end;
end;

function TZNet_Client.GetWaitTimeout(const t: TTimeTick): TTimeTick;
begin
  if t = 0 then
      Result := 1000 * 60 * 30
  else
      Result := t;
end;

procedure TZNet_Client.Do_IO_IDLE_FreeSelf(Data_: TCore_Object);
begin
  if self is TZNet_WithP2PVM_Client then
      TZNet_WithP2PVM_Client(self).P2PVM_Clone_NextProgressDoFreeSelf := True
  else
      DelayFreeObject(1.0, self, Data_);
end;

constructor TZNet_Client.Create;
begin
  inherited Create(1);
  FMaxCompleteBufferSize := 0; { 0 = infinity }
  FOnClientCustomProtocolReceiveBufferNotify := nil;
  FStableIOProgressing := False;
  FStableIO := nil;
  FOnInterface := nil;
  FConnectInitWaiting := False;
  FConnectInitWaitingTimeout := 0;
  FWaiting := False;
  FWaitingTimeOut := 0;
  FAsyncConnectTimeout := 60 * 1000;
  FOnCipherModelDone := nil;
  FServerState.Reset();
  FIgnoreProcessConnectedAndDisconnect := False;
  FLastConnectIsSuccessed := False;
  FRequestTime := 0;
  FReponseTime := 0;
  FOnWaitResult_C := nil;
  FOnWaitResult_M := nil;
  FOnWaitResult_P := nil;
  FFrameworkIsServer := False;
  FFrameworkIsClient := True;
  name := '';
end;

destructor TZNet_Client.Destroy;
begin
  try
    if (FStableIO <> nil) and (not FStableIO.AutoFreeOwnerIOClient) then
      begin
        DisposeObject(FStableIO);
        FStableIO := nil;
      end;
    FOnInterface := nil;
  except
  end;
  inherited Destroy;
end;

procedure TZNet_Client.DelayFreeSelf;
begin
  DelayFreeObject(1.0, self, nil);
end;

procedure TZNet_Client.Do_CipherModel_Result(Sender: TPeerIO; Result_: TDFE);
var
  arr: TDF_ArrayByte;
  uidArr: TDF_ArrayByte; { FIX: local holder for safe UID length checking }
begin
  if Result_.Count > 0 then
    begin
      FReponseTime := GetTimeTick - FRequestTime;
      { index 0: my remote id }
      Sender.ID := Result_.Reader.ReadCardinal;
      { index 1: Encrypt }
      Sender.SendCipherSecurity := TCipherSecurity(Result_.Reader.ReadByte);
      { index 2: Encrypt CipherKey }
      arr := Result_.Reader.ReadArrayByte;
      SetLength(Sender.FCipherKey, arr.Count);
      { FIX: avoid out-of-bounds @FCipherKey[0] when arr.Count = 0 }
      if arr.Count > 0 then
          arr.GetBuff(@Sender.FCipherKey[0]);
      { index 3: remote inited time md5 }
      FServerState.Reset();
      if Result_.Reader.IsEnd then
        begin
          Warning('protocol version upgrade ZNet from https://github.com/PassByYou888/ZNetV2');
        end
      else
        begin
          FInitedTimeMD5 := Result_.Reader.ReadMD5();
          if Result_.Reader.IsEnd then
            begin
              Warning('protocol version upgrade ZNet from https://github.com/PassByYou888/ZNetV2');
            end
          else
            begin
              FServerState.UsedParallelEncrypt := Result_.Reader.ReadBool();
              FServerState.SyncOnResult := Result_.Reader.ReadBool();
              FServerState.SyncOnCompleteBuffer := Result_.Reader.ReadBool();
              FServerState.EnabledAtomicLockAndMultiThread := Result_.Reader.ReadBool();
              FServerState.TimeOutKeepAlive := Result_.Reader.ReadBool();
              FServerState.QuietMode := Result_.Reader.ReadBool();
              FServerState.IdleTimeOut := Result_.Reader.ReadUInt64();
              FServerState.SendDataCompressed := Result_.Reader.ReadBool();
              FServerState.CompleteBufferCompressed := Result_.Reader.ReadBool();
              FServerState.MaxCompleteBufferSize := Result_.Reader.ReadCardinal();
              FServerState.ProgressMaxDelay := Result_.Reader.ReadUInt64();
              if Result_.Reader.IsEnd then
                begin
                  Warning('protocol version upgrade ZNet from https://github.com/PassByYou888/ZNetV2');
                end
              else
                begin
                  { FIX: validate UID array length before reading to avoid out-of-bounds
                    access on malformed / truncated server responses. }
                  uidArr := Result_.Reader.ReadArrayByte;
                  if uidArr.Count >= SizeOf(TUID___) then
                    begin
                      FServerState.UID := PUID___(uidArr.Buffer__.Memory)^;
                      ZNet_UID.V := Generate_Global_UID(FServerState.UID);
                    end
                  else ZNet_UID.V := Generate_Global_UID(ZNet_UID.V);
                end;
            end;
        end;
      Sender.RemoteExecutedForConnectInit := True;
      if FConnectInitWaiting then
          TriggerDoConnectFinished;
      CipherModelDone;
      if (FAutomatedP2PVMClient and (FAutomatedP2PVMClientBind.Count > 0)) or
        (FAutomatedP2PVMService and (FAutomatedP2PVMServiceBind.Count > 0)) then
          AutomatedP2PVM_Open(Sender);
    end
  else
    begin
      if FConnectInitWaiting then
          TriggerDoConnectFailed;
    end;
  FConnectInitWaiting := False;
end;

procedure TZNet_Client.DoConnected(Sender: TPeerIO);
var
  d: TDFE;
  tmp: TUID___;
begin
  FLastConnectIsSuccessed := True;
  if FIgnoreProcessConnectedAndDisconnect then
    begin
      if FOnInterface <> nil then
        begin
          try
              FOnInterface.ClientConnected(self);
          except
          end;
        end;
      Sender.RemoteExecutedForConnectInit := True;
      CipherModelDone;
      FConnectInitWaiting := False;
    end
  else
    begin
      FConnectInitWaiting := True;
      if Protocol = cpZServer then
        begin
          FConnectInitWaitingTimeout := GetTimeTick + FAsyncConnectTimeout;
          ClientIO.SendCipherSecurity := TCipherSecurity.csNone;
          FServerState.Reset();
          d := TDFE.Create;
          d.WriteInteger(Integer(CurrentPlatform));
          tmp := Generate_Global_UID(ZNet_UID.V);
          d.WriteArrayByte.Buffer__.WritePtr(@tmp[0], SizeOf(TUID___));
          SendStreamCmdM(C_CipherModel, d, Do_CipherModel_Result);
          DisposeObject(d);
          if FOnInterface <> nil then
            begin
              try
                  FOnInterface.ClientConnected(self);
              except
              end;
            end;
          FRequestTime := GetTimeTick;
        end
      else
        begin
          ClientIO.SendCipherSecurity := TCipherSecurity.csNone;
          if FOnInterface <> nil then
            begin
              try
                  FOnInterface.ClientConnected(self);
              except
              end;
            end;
          Sender.RemoteExecutedForConnectInit := True;
          TriggerDoConnectFinished;
          CipherModelDone;
          FConnectInitWaiting := False;
        end;
    end;
end;

procedure TZNet_Client.DoDisconnect(Sender: TPeerIO);
begin
  if not FIgnoreProcessConnectedAndDisconnect then
    begin
      FPeerIO_HashPool.Delete(Sender.FID);
      Sender.FID := 0;
      Sender.FRemoteExecutedForConnectInit := False;
    end;
  if (FLastConnectIsSuccessed) and (FOnInterface <> nil) then
      FOnInterface.ClientDisconnect(self);
  FLastConnectIsSuccessed := False;
  FServerState.Reset();
end;

function TZNet_Client.GetP2PVMTunnel: TZNet_P2PVM;
begin
  if ClientIO <> nil then
      Result := ClientIO.P2PVM
  else
      Result := nil;
end;

procedure TZNet_Client.IO_IDLE_TraceC(data: TCore_Object; const OnNotify: TOnDataNotify_C);
begin
  if ClientIO = nil then
      OnNotify(data)
  else
      ClientIO.IO_IDLE_TraceC(data, OnNotify);
end;

procedure TZNet_Client.IO_IDLE_TraceM(data: TCore_Object; const OnNotify: TOnDataNotify_M);
begin
  if ClientIO = nil then
      OnNotify(data)
  else
      ClientIO.IO_IDLE_TraceM(data, OnNotify);
end;

procedure TZNet_Client.IO_IDLE_TraceP(data: TCore_Object; const OnNotify: TOnDataNotify_P);
begin
  if ClientIO = nil then
      OnNotify(data)
  else
      ClientIO.IO_IDLE_TraceP(data, OnNotify);
end;

procedure TZNet_Client.IO_IDLE_Trace_And_FreeSelf(Additional_Object_: TCore_Object);
begin
  IO_IDLE_TraceM(Additional_Object_, Do_IO_IDLE_FreeSelf);
end;

procedure TZNet_Client.OnReceiveBuffer(const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
begin
end;

procedure TZNet_Client.BeginWriteBuffer();
begin
  BeginWriteCustomBuffer(ClientIO);
end;

procedure TZNet_Client.EndWriteBuffer();
begin
  EndWriteCustomBuffer(ClientIO);
end;

procedure TZNet_Client.WriteBuffer(const Buffer: PByte; const Size: NativeInt);
begin
  WriteCustomBuffer(ClientIO, Buffer, Size);
end;

procedure TZNet_Client.WriteBuffer(const Buffer: TMS64);
begin
  WriteBuffer(Buffer.Memory, Buffer.Size);
end;

procedure TZNet_Client.WriteBuffer(const Buffer: TMem64);
begin
  WriteBuffer(Buffer.Memory, Buffer.Size);
end;

procedure TZNet_Client.WriteBuffer(const Buffer: TMS64; const doneFreeBuffer: Boolean);
begin
  WriteBuffer(Buffer);
  if doneFreeBuffer then
      DisposeObject(Buffer);
end;

procedure TZNet_Client.WriteBuffer(const Buffer: TMem64; const doneFreeBuffer: Boolean);
begin
  WriteBuffer(Buffer);
  if doneFreeBuffer then
      DisposeObject(Buffer);
end;

function TZNet_Client.ServerState: PZNet_ServerState;
begin
  Result := @FServerState;
end;

procedure TZNet_Client.Progress;
begin
  inherited Progress;
  if not FProgressEnabled then
      exit;
  if (FConnectInitWaiting) and (GetTimeTick > FConnectInitWaitingTimeout) then
    begin
      FConnectInitWaiting := False;
      try
          TriggerDoConnectFailed;
      except
      end;
      try
        if Connected then
            Disconnect;
      except
      end;
    end;
  if (FWaiting) and ((GetTimeTick > FWaitingTimeOut) or (not Connected)) then
    begin
      FWaiting := False;
      FWaitingTimeOut := 0;
      try
        if Assigned(FOnWaitResult_C) then
            FOnWaitResult_C(False)
        else if Assigned(FOnWaitResult_M) then
            FOnWaitResult_M(False)
        else if Assigned(FOnWaitResult_P) then
            FOnWaitResult_P(False);
      except
      end;
      FOnWaitResult_C := nil;
      FOnWaitResult_M := nil;
      FOnWaitResult_P := nil;
    end;
  if (FStableIO <> nil) and (not FStableIOProgressing) then
    begin
      FStableIOProgressing := True;
      FStableIO.Progress;
      FStableIOProgressing := False;
    end;
end;

function TZNet_Client.StableIO: TZNet_StableClient;
begin
  if FStableIO = nil then
    begin
      FStableIO := TZNet_StableClient.Create;
      FStableIO.AutoFreeOwnerIOClient := False;
      FStableIO.AutoProgressOwnerIOClient := True;
      FStableIO.OwnerIOClient := self;
    end;
  Result := FStableIO;
end;

procedure TZNet_Client.TriggerDoDisconnect;
begin
  DoDisconnect(ClientIO);
end;

function TZNet_Client.Connected: Boolean;
begin
  Result := False;
end;

function TZNet_Client.ClientIO: TPeerIO;
begin
  Result := nil;
end;

procedure TZNet_Client.TriggerDoConnectFailed;
begin
  FConnectInitWaiting := False;
end;

procedure TZNet_Client.TriggerDoConnectFinished;
begin
  FConnectInitWaiting := False;
end;

procedure TZNet_Client.CipherModelDone;
begin
  try
    if Assigned(FOnCipherModelDone) then
        FOnCipherModelDone(self);
  except
  end;
end;

procedure TZNet_Client.AsyncConnectC(addr: SystemString; Port: Word; const OnResult: TOnState_C);
var
  R: Boolean;
begin
  R := Connect(addr, Port);
  if Assigned(OnResult) then
      OnResult(R);
end;

procedure TZNet_Client.AsyncConnectM(addr: SystemString; Port: Word; const OnResult: TOnState_M);
var
  R: Boolean;
begin
  R := Connect(addr, Port);
  if Assigned(OnResult) then
      OnResult(R);
end;

procedure TZNet_Client.AsyncConnectP(addr: SystemString; Port: Word; const OnResult: TOnState_P);
var
  R: Boolean;
begin
  R := Connect(addr, Port);
  if Assigned(OnResult) then
      OnResult(R);
end;

procedure TZNet_Client.AsyncConnectC(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_C);
var
  ParamBridge: TState_Param_Bridge;
begin
  ParamBridge := TState_Param_Bridge.Create;
  ParamBridge.Param1 := Param1;
  ParamBridge.Param2 := Param2;
  ParamBridge.OnNotifyC := OnResult;
  AsyncConnectM(addr, Port, ParamBridge.OnStateMethod);
end;

procedure TZNet_Client.AsyncConnectM(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_M);
var
  ParamBridge: TState_Param_Bridge;
begin
  ParamBridge := TState_Param_Bridge.Create;
  ParamBridge.Param1 := Param1;
  ParamBridge.Param2 := Param2;
  ParamBridge.OnNotifyM := OnResult;
  AsyncConnectM(addr, Port, ParamBridge.OnStateMethod);
end;

procedure TZNet_Client.AsyncConnectP(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_P);
var
  ParamBridge: TState_Param_Bridge;
begin
  ParamBridge := TState_Param_Bridge.Create;
  ParamBridge.Param1 := Param1;
  ParamBridge.Param2 := Param2;
  ParamBridge.OnNotifyP := OnResult;
  AsyncConnectM(addr, Port, ParamBridge.OnStateMethod);
end;

function TZNet_Client.Connect(addr: SystemString; Port: Word): Boolean;
begin
  Result := False;
end;

procedure TZNet_Client.Disconnect;
begin
end;

procedure TZNet_Client.DelayCloseIO;
begin
  try
    if ClientIO <> nil then
        ClientIO.DelayClose;
  except
  end;
end;

procedure TZNet_Client.DelayCloseIO(const t: Double);
begin
  try
    if ClientIO <> nil then
        ClientIO.DelayClose(t);
  except
  end;
end;

function TZNet_Client.Wait(TimeOut_: TTimeTick): SystemString;
begin
  Result := '';
  if (ClientIO = nil) then
      exit;
  if (not Connected) then
      exit;
  Result := WaitSendConsoleCmd(C_Wait, '', GetWaitTimeout(TimeOut_));
end;

function TZNet_Client.WaitC(TimeOut_: TTimeTick; const OnResult: TOnState_C): Boolean;
begin
  Result := False;
  if (ClientIO = nil) then
      exit;
  if (FWaiting) then
      exit;
  if (not Connected) then
    begin
      if Assigned(OnResult) then
          OnResult(False);
      exit;
    end;
  FWaiting := True;
  FWaitingTimeOut := GetTimeTick + GetWaitTimeout(TimeOut_);
  FOnWaitResult_C := OnResult;
  FOnWaitResult_M := nil;
  FOnWaitResult_P := nil;
  SendConsoleCmdM(C_Wait, '', ConsoleResult_Wait);
  Result := True;
end;

function TZNet_Client.WaitM(TimeOut_: TTimeTick; const OnResult: TOnState_M): Boolean;
begin
  Result := False;
  if (ClientIO = nil) then
      exit;
  if (FWaiting) then
      exit;
  if (not Connected) then
    begin
      if Assigned(OnResult) then
          OnResult(False);
      exit;
    end;
  FWaiting := True;
  FWaitingTimeOut := GetTimeTick + GetWaitTimeout(TimeOut_);
  FOnWaitResult_C := nil;
  FOnWaitResult_M := OnResult;
  FOnWaitResult_P := nil;
  SendConsoleCmdM(C_Wait, '', ConsoleResult_Wait);
  Result := True;
end;

function TZNet_Client.WaitP(TimeOut_: TTimeTick; const OnResult: TOnState_P): Boolean;
begin
  Result := False;
  if (ClientIO = nil) then
      exit;
  if (FWaiting) then
      exit;
  if (not Connected) then
    begin
      if Assigned(OnResult) then
          OnResult(False);
      exit;
    end;
  FWaiting := True;
  FWaitingTimeOut := GetTimeTick + GetWaitTimeout(TimeOut_);
  FOnWaitResult_C := nil;
  FOnWaitResult_M := nil;
  FOnWaitResult_P := OnResult;
  SendConsoleCmdM(C_Wait, '', ConsoleResult_Wait);
  Result := True;
end;

function TZNet_Client.WaitSendBusy: Boolean;
begin
  Result := (ClientIO <> nil) and (ClientIO.WaitSendBusy);
end;

function TZNet_Client.LastQueueData: PQueueData;
begin
  Result := nil;
  if ClientIO = nil then
      exit;
  ClientIO.FSend_Queue_Critical.Lock;
  if ClientIO.FSend_Queue_Pool.Num > 0 then
      Result := PQueueData(ClientIO.FSend_Queue_Pool.Last^.data);
  ClientIO.FSend_Queue_Critical.UnLock;
end;

function TZNet_Client.LastQueueCmd: SystemString;
var
  p: PQueueData;
begin
  p := LastQueueData;
  if p <> nil then
      Result := p^.Cmd
  else
      Result := '';
end;

function TZNet_Client.QueueCmdCount: Integer;
begin
  Result := 0;
  if ClientIO = nil then
      exit;
  ClientIO.FSend_Queue_Critical.Lock;
  Result := ClientIO.FSend_Queue_Pool.Num;
  ClientIO.FSend_Queue_Critical.UnLock;
end;

function TZNet_Client.Last_IO_IDLE_Time: TTimeTick;
begin
  if ClientIO = nil then
      Result := GetTimeTick()
  else
      Result := ClientIO.Last_IO_IDLE_Time;
end;

function TZNet_Client.Client_ID: Cardinal;
begin
  if ClientIO = nil then
      Result := 0
  else
      Result := ClientIO.ID;
end;

procedure TZNet_Client.SendConsoleCmd(const Cmd, ConsoleData: SystemString);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Console cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendConsoleCmdM(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Console cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleM := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Console cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamM := OnResult;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Console cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamM := OnResult;
  p^.OnConsoleFailedM := OnFailed;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendConsoleCmdP(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Console cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleP := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Console cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamP := OnResult;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Console cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamP := OnResult;
  p^.OnConsoleFailedP := OnFailed;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  if ClientIO = nil then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not Connected then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmd(const Cmd: SystemString; StreamData: TDFE);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdM(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  if ClientIO = nil then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not Connected then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  p^.OnStreamM := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamM := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamParamM := OnResult;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamParamM := OnResult;
  p^.OnStreamFailedM := OnFailed;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdP(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  if ClientIO = nil then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not Connected then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  p^.OnStreamP := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamP := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamParamP := OnResult;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send Stream cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamParamP := OnResult;
  p^.OnStreamFailedP := OnFailed;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Client.SendConsoleNotifyCmd(const Cmd, ConsoleData: SystemString);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send ConsoleNotify cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendConsoleNotifyCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  Post_Queue_Data_To_Swap_Queue(p);
  if FAutomaticWaitRemoteReponse then
      Send_NULL();
end;

procedure TZNet_Client.SendConsoleNotifyCmd(const Cmd: SystemString);
begin
  SendConsoleNotifyCmd(Cmd, '');
end;

procedure TZNet_Client.SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  if ClientIO = nil then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not Connected then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not QuietMode then
      ClientIO.PrintCommand('Send StreamNotify cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamNotifyCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  Post_Queue_Data_To_Swap_Queue(p);
  if FAutomaticWaitRemoteReponse then
      Send_NULL();
end;

procedure TZNet_Client.SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE);
var
  p: PQueueData;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Send StreamNotify cmd: %s', Cmd);
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendStreamNotifyCMD;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  Post_Queue_Data_To_Swap_Queue(p);
  if FAutomaticWaitRemoteReponse then
      Send_NULL();
end;

procedure TZNet_Client.SendStreamNotifyCmd(const Cmd: SystemString);
var
  d: TDFE;
begin
  d := TDFE.Create;
  SendStreamNotifyCmd(Cmd, d);
  DisposeObject(d);
end;

procedure TZNet_Client.SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  if ClientIO = nil then
    begin
      if DoneAutoFree then
          DisposeObject(BigStream);
      exit;
    end;
  if not Connected then
    begin
      if DoneAutoFree then
          DisposeObject(BigStream);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(BigStream);
      exit;
    end;
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendBigStream;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  p^.BigStreamStartPos := StartPos;
  LockSend;
  try
    if FBigStreamMemorySwapSpace and DoneAutoFree and IOBusy and (BigStream.Size > FBigStreamSwapSpaceTriggerSize)
      and ((BigStream is TMS64) or (BigStream is TMemoryStream)) then
      begin
        if not QuietMode then
            ClientIO.PrintCommand('swap space technology cache for "%s"', Cmd);
        p^.BigStream := TFile_Swap_Space_Stream.Create_BigStream(BigStream, BigStream_Swap_Space_Pool__);
        if p^.BigStream <> nil then
          begin
            if DoneAutoFree then
                DisposeObject(BigStream);
            p^.DoneAutoFree := True;
          end
        else
          begin
            p^.BigStream := BigStream;
            p^.DoneAutoFree := DoneAutoFree;
          end;
      end
    else
      begin
        p^.BigStream := BigStream;
        p^.DoneAutoFree := DoneAutoFree;
      end;
  finally
      UnLockSend;
  end;
  Post_Queue_Data_To_Swap_Queue(p);
  if not QuietMode then
      ClientIO.PrintCommand('Send BigStream cmd: %s', Cmd);
end;

procedure TZNet_Client.SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean);
begin
  SendBigStream(Cmd, BigStream, 0, DoneAutoFree);
end;

procedure TZNet_Client.SendCompleteBuffer(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  if (ClientIO = nil) or (ClientIO.Disable_Progress) then
    begin
      PrintErrorParam('IO error', Cmd);
      if DoneAutoFree then
          System.FreeMemory(buff);
      exit;
    end;
  if not Connected then
    begin
      PrintErrorParam('not connect', Cmd);
      if DoneAutoFree then
          System.FreeMemory(buff);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      PrintErrorParam('Illegal cmd', Cmd);
      if DoneAutoFree then
          System.FreeMemory(buff);
      exit;
    end;
  { init queue data }
  p := NewQueueData(ClientIO);
  p^.State := TQueueState.qsSendCompleteBuffer;
  p^.Cmd := Cmd;
  p^.Cipher := ClientIO.FSendDataCipherSecurity;
  LockSend;
  try
    { FIX: previous code used 'BuffSize.Size' which is invalid for NativeInt. }
    if FCompleteBufferSwapSpace and DoneAutoFree
      and ((FCompleteBufferSwapSpaceTriggerSize <= 0) or (BuffSize > FCompleteBufferSwapSpaceTriggerSize))
      and IOBusy() then
      begin
        if not QuietMode then
            ClientIO.PrintCommand('ZDB2 swap space technology cache for "%s"', Cmd);
        ClientIO.FReceived_Physics_Critical.Lock;
        p^.Buffer_Swap_Memory := TZDB2_Swap_Space_Technology.RunTime_Pool.Create_Memory(buff, BuffSize, False);
        ClientIO.FReceived_Physics_Critical.UnLock;
        if p^.Buffer_Swap_Memory <> nil then
          begin
            System.FreeMemory(buff);
            p^.Buffer := nil;
          end
        else
          begin
            p^.Buffer := buff;
            p^.Buffer_Swap_Memory := nil;
          end;
      end
    else
      begin
        p^.Buffer := buff;
        p^.Buffer_Swap_Memory := nil;
      end;
  finally
      UnLockSend;
  end;
  p^.BufferSize := BuffSize;
  p^.DoneAutoFree := DoneAutoFree;
  Post_Queue_Data_To_Swap_Queue(p);
  if not QuietMode then
      ClientIO.PrintCommand('Send complete buffer cmd: %s', Cmd);
  if FAutomaticWaitRemoteReponse then
      Send_NULL();
end;

procedure TZNet_Client.SendCompleteBuffer(const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean);
begin
  SendCompleteBuffer(Cmd, buff.Memory, buff.Size, DoneAutoFree);
  if DoneAutoFree then
    begin
      buff.DiscardMemory;
      DisposeObject(buff);
    end;
end;

procedure TZNet_Client.SendCompleteBuffer(const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean);
begin
  SendCompleteBuffer(Cmd, buff.Memory, buff.Size, DoneAutoFree);
  if DoneAutoFree then
    begin
      buff.DiscardMemory;
      DisposeObject(buff);
    end;
end;

procedure TZNet_Client.SendCompleteBuffer(const Cmd: SystemString; buff: TDFE);
begin
  SendCompleteBuffer_StreamNotify(Cmd, buff);
end;

procedure TZNet_Client.SendCompleteBuffer_StreamNotify(const Cmd: SystemString; buff: TDFE);
var
  tmp: TMS64;
begin
  tmp := TMS64.CustomCreate(64 * 1024);
  buff.FastEncodeTo(tmp);
  SendCompleteBuffer(Cmd, tmp, True);
end;

procedure TZNet_Client.SendCompleteBuffer_NoWait_StreamM(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M);
var
  p: PCommandCompleteBuffer_NoWait_Stream_Data;
  m64: TMS64;
begin
  if ClientIO = nil then
    begin
      PrintErrorParam('IO is NULL', Cmd);
      exit;
    end;
  if not Connected then
    begin
      PrintErrorParam('no connected', Cmd);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      PrintErrorParam('Illegal cmd', Cmd);
      exit;
    end;
  if not ClientIO.Is_Double_Tunnel then
    begin
      ClientIO.PrintError('cmd %s only work in double tunnel', [Cmd]);
      exit;
    end;
  if not ClientIO.Is_Send_Tunnel then
    begin
      ClientIO.PrintError('cmd %s only work in send tunnel', [Cmd]);
      exit;
    end;
  New(p);
  p^.Init;
  p^.ID := ClientIO.ID;
  p^.OnStreamM := OnResult;
  m64 := TMS64.CustomCreate(64 * 1024);
  m64.WriteUInt64(UInt64(p));
  buff.FastEncodeTo(m64);
  SendCompleteBuffer(Cmd, m64, True);
end;

procedure TZNet_Client.SendCompleteBuffer_NoWait_StreamP(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P);
var
  p: PCommandCompleteBuffer_NoWait_Stream_Data;
  m64: TMS64;
begin
  if ClientIO = nil then
    begin
      PrintErrorParam('IO is NULL', Cmd);
      exit;
    end;
  if not Connected then
    begin
      PrintErrorParam('no connected', Cmd);
      exit;
    end;
  if not CanSendCommand(ClientIO, Cmd) then
    begin
      PrintErrorParam('Illegal cmd', Cmd);
      exit;
    end;
  if not ClientIO.Is_Double_Tunnel then
    begin
      ClientIO.PrintError('cmd %s only work in double tunnel', [Cmd]);
      exit;
    end;
  if not ClientIO.Is_Send_Tunnel then
    begin
      ClientIO.PrintError('cmd %s only work in send tunnel', [Cmd]);
      exit;
    end;
  New(p);
  p^.Init;
  p^.ID := ClientIO.ID;
  p^.OnStreamP := OnResult;
  m64 := TMS64.CustomCreate(64 * 1024);
  m64.WriteUInt64(UInt64(p));
  buff.FastEncodeTo(m64);
  SendCompleteBuffer(Cmd, m64, True);
end;

procedure TZNet_Client.Send_NULL;
begin
  SendConsoleCmd(C_NULL, '');
end;

procedure TZNet_Client.SendNULL;
begin
  SendConsoleCmd(C_NULL, '');
end;

function TZNet_Client.WaitSendConsoleCmd(const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;
var
  waitIntf: TWaitSendConsoleCmdIntf;
  timetick: TTimeTick;
  IO_ID: Cardinal;
begin
  Result := '';
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Begin Wait console cmd: %s', Cmd);
  IO_ID := ClientIO.ID;
  timetick := GetTimeTick + TimeOut_;
  while ExistsID(IO_ID) and (ClientIO.WaitOnResult or ClientIO.BigStreamReceiveing or ClientIO.FWaitSendBusy) do
    begin
      ProgressWaitSend(ClientIO);
      if not Connected then
          exit;
      if (TimeOut_ > 0) and (GetTimeTick > timetick) then
          exit;
    end;
  if not ExistsID(IO_ID) then
      exit;
  ClientIO.FWaitSendBusy := True;
  try
    waitIntf := TWaitSendConsoleCmdIntf.Create;
    waitIntf.Done := False;
    waitIntf.NewResult := '';
    SendConsoleCmdM(Cmd, ConsoleData, nil, nil, waitIntf.DoConsoleParam, waitIntf.DoConsoleFailed);
    while ExistsID(IO_ID) and (not waitIntf.Done) do
      begin
        TCompute.Sleep(1);
        ProgressWaitSend(IO_ID);
        if not Connected then
            Break;
        if (TimeOut_ > 0) and (GetTimeTick > timetick) then
            Break;
      end;
    if ExistsID(IO_ID) and (not waitIntf.Failed) and waitIntf.Done then
        Result := waitIntf.NewResult
    else
        Result := '';
    try
      if not QuietMode then
        if ExistsID(IO_ID) then
            ClientIO.PrintCommand('End Wait console cmd: %s', Cmd);
    except
    end;
    { FIX: when waitIntf.Done = False (timeout path), previously the waitIntf object
      was leaked. Defer the free to allow late response callbacks to complete safely. }
    if waitIntf.Done then
        DisposeObject(waitIntf)
    else
        DelayFreeObject(60.0, waitIntf);
  except
      Result := '';
  end;
  if ExistsID(IO_ID) and Connected then
      ClientIO.FWaitSendBusy := False;
end;

procedure TZNet_Client.WaitSendStreamCmd(const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);
var
  waitIntf: TWaitSendStreamCmdIntf;
  timetick: TTimeTick;
  IO_ID: Cardinal;
begin
  if ClientIO = nil then
      exit;
  if not Connected then
      exit;
  if not CanSendCommand(ClientIO, Cmd) then
      exit;
  if not QuietMode then
      ClientIO.PrintCommand('Begin Wait Stream cmd: %s', Cmd);
  IO_ID := ClientIO.ID;
  timetick := GetTimeTick + TimeOut_;
  while ExistsID(IO_ID) and (ClientIO.WaitOnResult or ClientIO.BigStreamReceiveing or ClientIO.FWaitSendBusy) do
    begin
      ProgressWaitSend(ClientIO);
      if not Connected then
          exit;
      if (TimeOut_ > 0) and (GetTimeTick > timetick) then
          exit;
    end;
  if not ExistsID(IO_ID) then
      exit;
  ClientIO.FWaitSendBusy := True;
  try
    waitIntf := TWaitSendStreamCmdIntf.Create;
    waitIntf.Done := False;
    SendStreamCmdM(Cmd, StreamData, nil, nil, waitIntf.DoStreamParam, waitIntf.DoStreamFailed);
    while ExistsID(IO_ID) and (not waitIntf.Done) do
      begin
        TCompute.Sleep(1);
        ProgressWaitSend(IO_ID);
        if not Connected then
            Break;
        if (TimeOut_ > 0) and (GetTimeTick > timetick) then
            Break;
      end;
    try
      if not QuietMode then
        if ExistsID(IO_ID) then
            ClientIO.PrintCommand('End Wait Stream cmd: %s', Cmd);
    except
    end;
    if waitIntf.Done then
      begin
        if (Result_ <> nil) and (not waitIntf.Failed) then
          begin
            Result_.Assign(waitIntf.NewResult);
            Result_.Reader.index := 0;
          end;
        DisposeObject(waitIntf);
      end
    else
      { FIX: defer free on timeout to avoid leak while keeping late callbacks safe. }
        DelayFreeObject(60.0, waitIntf);
  except
  end;
  if ExistsID(IO_ID) and Connected then
      ClientIO.FWaitSendBusy := False;
end;

function TZNet_Client.RemoteID: Cardinal;
begin
  if ClientIO <> nil then
      Result := ClientIO.FID
  else
      Result := 0;
end;

function TZNet_Client.RemoteKey: TCipherKeyBuffer;
begin
  { FIX: guard against nil ClientIO, which previously caused access violation. }
  if ClientIO <> nil then
      Result := ClientIO.CipherKey
  else
      SetLength(Result, 0);
end;

function TZNet_Client.RemoteInited: Boolean;
begin
  if ClientIO <> nil then
      Result := ClientIO.FRemoteExecutedForConnectInit
  else
      Result := False;
end;
