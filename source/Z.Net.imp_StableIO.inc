constructor TStableServer_OwnerIO_UserDefine.Create(Owner_: TPeerIO);
begin
  inherited Create(Owner_);
  BindStableIO := nil;
end;

destructor TStableServer_OwnerIO_UserDefine.Destroy;
begin
  if BindStableIO <> nil then
    begin
      BindStableIO.BindOwnerIO := nil;
      if not BindStableIO.Activted then
          BindStableIO.DelayClose(2.0);
      BindStableIO := nil;
    end;
  inherited Destroy;
end;

procedure TStableServer_PeerIO.CreateAfter;
begin
  inherited CreateAfter;
  Activted := False;
  DestroyRecycleOwnerIO := True;
  Connection_Token := 0;
  Internal_Bind_Owner_IO := nil;
  OfflineTick := GetTimeTick;
end;

destructor TStableServer_PeerIO.Destroy;
begin
  if (DestroyRecycleOwnerIO) and (BindOwnerIO <> nil) then
    begin
      TStableServer_OwnerIO_UserDefine(BindOwnerIO.UserDefine).BindStableIO := nil;
      BindOwnerIO.DelayClose;
      BindOwnerIO := nil;
    end;

  inherited Destroy;
end;

function TStableServer_PeerIO.Connected: Boolean;
begin
  Result := True;
end;

procedure TStableServer_PeerIO.Disconnect;
begin
  DelayFree();
end;

procedure TStableServer_PeerIO.Write_IO_Buffer(const buff: PByte; const Size: NativeInt);
begin
  if BindOwnerIO = nil then
      AtomDec(OwnerFramework.Statistics[TStatisticsType.stSendSize], Size)
  else
      BindOwnerIO.Write_IO_Buffer(buff, Size);
end;

procedure TStableServer_PeerIO.WriteBufferOpen;
begin
  if BindOwnerIO <> nil then
      BindOwnerIO.WriteBufferOpen;
end;

procedure TStableServer_PeerIO.WriteBufferFlush;
begin
  if BindOwnerIO <> nil then
      BindOwnerIO.WriteBufferFlush;
end;

procedure TStableServer_PeerIO.WriteBufferClose;
begin
  if BindOwnerIO <> nil then
      BindOwnerIO.WriteBufferClose;
end;

function TStableServer_PeerIO.GetPeerIP: SystemString;
begin
  if BindOwnerIO <> nil then
      Result := BindOwnerIO.GetPeerIP
  else
      Result := 'StableIO - offline';
end;

function TStableServer_PeerIO.WriteBuffer_is_NULL: Boolean;
begin
  if (BindOwnerIO <> nil) and (not BindOwnerIO.Disable_Progress) then
      Result := BindOwnerIO.WriteBuffer_is_NULL
  else
      Result := False;
end;

function TStableServer_PeerIO.WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean;
begin
  if (BindOwnerIO <> nil) and (not BindOwnerIO.Disable_Progress) then
      Result := BindOwnerIO.WriteBuffer_State(WriteBuffer_Queue_Num, WriteBuffer_Size)
  else
      Result := inherited WriteBuffer_State(WriteBuffer_Queue_Num, WriteBuffer_Size);
end;

procedure TStableServer_PeerIO.Progress;
var
  t, offline_t: TTimeTick;
begin
  if (Activted) then
    begin
      t := GetTimeTick;

      if (BindOwnerIO = nil) then
        begin
          offline_t := TZNet_CustomStableServer(OwnerFramework).OfflineTimeout;
          if (offline_t > 0) and (t - OfflineTick > offline_t) then
            begin
              DelayClose;
              exit;
            end;
        end
      else
          OfflineTick := t;
    end;

  inherited Progress;
  Process_Send_Buffer();
end;

procedure TZNet_CustomStableServer.ServerCustomProtocolReceiveBufferNotify(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
var
  io_def: TStableServer_OwnerIO_UserDefine;
begin
  io_def := Sender.UserDefine as TStableServer_OwnerIO_UserDefine;
  FillDone := (io_def.BindStableIO <> nil);
  if FillDone then
    begin
      io_def.BindStableIO.Write_Physics_Fragment(Buffer, Size);
    end;
end;

procedure TZNet_CustomStableServer.SetOwnerIOServer(const Value: TZNet_Server);
begin
  if FOwnerIOServer <> nil then
    begin
      FOwnerIOServer.FOnServerCustomProtocolReceiveBufferNotify := nil;
      FOwnerIOServer.Protocol := TCommunicationProtocol.cpZServer;
      FOwnerIOServer.UserDefineClass := TPeer_IO_User_Define;
      FOwnerIOServer.QuietMode := False;

      UnRegisted(C_BuildStableIO);
      UnRegisted(C_OpenStableIO);
    end;

  FOwnerIOServer := Value;

  if FOwnerIOServer <> nil then
    begin
      FOwnerIOServer.FOnServerCustomProtocolReceiveBufferNotify := ServerCustomProtocolReceiveBufferNotify;
      FOwnerIOServer.Protocol := TCommunicationProtocol.cpCustom;
      FOwnerIOServer.UserDefineClass := TStableServer_OwnerIO_UserDefine;
      FOwnerIOServer.SyncOnResult := True;
      FOwnerIOServer.SyncOnCompleteBuffer := True;
      FOwnerIOServer.QuietMode := False;
      FOwnerIOServer.TimeOutIDLE := 60 * 1000;

      FOwnerIOServer.RegisterStream(C_BuildStableIO).OnExecute := cmd_BuildStableIO;
      FOwnerIOServer.RegisterStream(C_OpenStableIO).OnExecute := cmd_OpenStableIO;
    end;
end;

procedure TZNet_CustomStableServer.cmd_BuildStableIO(Sender: TPeerIO; InData, OutData: TDFE);
var
  io_def: TStableServer_OwnerIO_UserDefine;
  S_IO: TStableServer_PeerIO;
begin
  io_def := Sender.UserDefine as TStableServer_OwnerIO_UserDefine;
  S_IO := TStableServer_PeerIO.Create(self, nil);
  S_IO.Activted := True;
  S_IO.FSequencePacketActivted := True;
  S_IO.FSequencePacketSignal := True;
  S_IO.SequencePacketLimitOwnerIOMemory := FLimitSequencePacketMemoryUsage;
  S_IO.DestroyRecycleOwnerIO := True;
  S_IO.BindOwnerIO := Sender;
  S_IO.Connection_Token := Connection_Token_Counter;
  inc(Connection_Token_Counter);
  io_def.BindStableIO := S_IO;

  OutData.WriteBool(True);
  OutData.WriteCardinal(S_IO.Connection_Token);
  OutData.WriteCardinal(S_IO.FID);
  OutData.WriteByte(Byte(S_IO.FSendDataCipherSecurity));
  OutData.WriteArrayByte.SetBuff(@S_IO.FCipherKey[0], Length(S_IO.FCipherKey));
end;

procedure TZNet_CustomStableServer.cmd_OpenStableIO(Sender: TPeerIO; InData, OutData: TDFE);
var
  io_def: TStableServer_OwnerIO_UserDefine;
  connToken: Cardinal;
  arry: TDF_ArrayByte;
  connKey: TBytes;
  IO_Array: TIO_Array;
  IO_ID: Cardinal;
  io_temp, io_picked: TStableServer_PeerIO;
begin
  io_def := Sender.UserDefine as TStableServer_OwnerIO_UserDefine;

  io_picked := nil;
  connToken := InData.Reader.ReadCardinal;
  arry := InData.Reader.ReadArrayByte;
  SetLength(connKey, arry.Count);
  arry.GetBuff(@connKey[0]);

  GetIO_Array(IO_Array);
  for IO_ID in IO_Array do
    begin
      io_temp := TStableServer_PeerIO(PeerIO[IO_ID]);
      if (io_temp <> nil) and (io_temp.Activted) and
        (io_temp.Connection_Token = connToken) and (TCipher.CompareKey(connKey, io_temp.FCipherKey)) then
        begin
          io_picked := io_temp;
          Break;
        end;
    end;

  if io_picked = nil then
    begin
      OutData.WriteBool(False);
      OutData.WriteString(PFormat('illegal Request Token: maybe you cant use StableIO again after server is restarted.', []));
      exit;
    end;

  io_picked.BindOwnerIO := Sender;
  io_picked.Activted := True;
  io_picked.DestroyRecycleOwnerIO := True;
  io_picked.UserDefine.WorkPlatform := io_def.WorkPlatform;
  io_def.BindStableIO := io_picked;
  io_picked.ResetSequencePacketBuffer;
  io_picked.SequencePacketVerifyTick := GetTimeTick;
  io_picked.OfflineTick := GetTimeTick;

  OutData.WriteBool(True);
  OutData.WriteCardinal(io_picked.Connection_Token);
  OutData.WriteCardinal(io_picked.ID);
  OutData.WriteByte(Byte(io_picked.FSendDataCipherSecurity));
  OutData.WriteArrayByte.SetBuff(@io_picked.FCipherKey[0], Length(io_picked.FCipherKey));
end;

procedure TZNet_CustomStableServer.cmd_CloseStableIO(Sender: TPeerIO; InData: SystemString);
var
  S_IO: TStableServer_PeerIO;
begin
  S_IO := Sender as TStableServer_PeerIO;
  S_IO.Disconnect;
end;

constructor TZNet_CustomStableServer.Create;
begin
  inherited Create;
  EnabledAtomicLockAndMultiThread := False;
  PhysicsFragmentSwapSpaceTechnology := False;
  SwitchMaxSecurity;

  RegisterConsoleNotify(C_CloseStableIO).OnExecute := cmd_CloseStableIO;

  Connection_Token_Counter := 1;
  FOwnerIOServer := nil;
  FOfflineTimeout := 1000 * 60 * 5;
  FLimitSequencePacketMemoryUsage := 0;
  FAutoFreeOwnerIOServer := False;
  FAutoProgressOwnerIOServer := True;
  CustomStableServerProgressing := False;

  name := 'StableServer';
end;

destructor TZNet_CustomStableServer.Destroy;
var
  phyServ: TZNet_Server;
begin
  UnRegisted(C_CloseStableIO);

  while Count > 0 do
      DisposeObject(FirstIO);

  StopService;
  phyServ := FOwnerIOServer;
  SetOwnerIOServer(nil);
  if FAutoFreeOwnerIOServer and (phyServ <> nil) then
      DisposeObject(phyServ);
  inherited Destroy;
end;

function TZNet_CustomStableServer.StartService(Host: SystemString; Port: Word): Boolean;
begin
  Result := False;
  if FOwnerIOServer <> nil then
      Result := FOwnerIOServer.StartService(Host, Port);
end;

procedure TZNet_CustomStableServer.StopService;
begin
  if FOwnerIOServer <> nil then
      FOwnerIOServer.StopService;
end;

procedure TZNet_CustomStableServer.Progress;
begin
  if not FProgressEnabled then
      exit;
  if CustomStableServerProgressing then
      exit;

  CustomStableServerProgressing := True;
  if (FOwnerIOServer <> nil) and (FAutoProgressOwnerIOServer) then
      FOwnerIOServer.Progress;
  inherited Progress;
  CustomStableServerProgressing := False;
end;

function TZNet_CustomStableServer.WaitSendConsoleCmd(P_IO: TPeerIO;
  const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;
begin
  Result := '';
  RaiseInfo('WaitSend no Suppport');
end;

procedure TZNet_CustomStableServer.WaitSendStreamCmd(P_IO: TPeerIO;
  const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);
begin
  RaiseInfo('WaitSend no Suppport');
end;

procedure TStableClient_PeerIO.CreateAfter;
begin
  inherited CreateAfter;
  Activted := False;
  WaitConnecting := False;
  OwnerIO_LastConnectTick := GetTimeTick;
  Connection_Token := 0;
  BindOwnerIO := nil;
end;

destructor TStableClient_PeerIO.Destroy;
begin
  TZNet_CustomStableClient(OwnerFramework).DoDisconnect(self);

  if (BindOwnerIO <> nil) then
      BindOwnerIO.DelayClose;

  inherited Destroy;
end;

function TStableClient_PeerIO.Connected: Boolean;
begin
  Result := True;
end;

procedure TStableClient_PeerIO.Disconnect;
begin
  if (BindOwnerIO <> nil) then
      BindOwnerIO.Disconnect;

  TZNet_CustomStableClient(OwnerFramework).Disconnect;
end;

procedure TStableClient_PeerIO.Write_IO_Buffer(const buff: PByte; const Size: NativeInt);
begin
  if (BindOwnerIO = nil) or (not Activted) or (WaitConnecting) then
    begin
      AtomDec(OwnerFramework.Statistics[TStatisticsType.stSendSize], Size);
      exit;
    end;

  BindOwnerIO.Write_IO_Buffer(buff, Size);
end;

procedure TStableClient_PeerIO.WriteBufferOpen;
begin
  if BindOwnerIO <> nil then
      BindOwnerIO.WriteBufferOpen;
end;

procedure TStableClient_PeerIO.WriteBufferFlush;
begin
  if (BindOwnerIO = nil) or (not Activted) or (WaitConnecting) then
      exit;
  BindOwnerIO.WriteBufferFlush;
end;

procedure TStableClient_PeerIO.WriteBufferClose;
begin
  if (BindOwnerIO = nil) or (not Activted) or (WaitConnecting) then
      exit;
  BindOwnerIO.WriteBufferClose;
end;

function TStableClient_PeerIO.GetPeerIP: SystemString;
begin
  if (BindOwnerIO = nil) or (not Activted) or (WaitConnecting) then
      Result := 'offline'
  else
      Result := BindOwnerIO.GetPeerIP;
end;

function TStableClient_PeerIO.WriteBuffer_is_NULL: Boolean;
begin
  if (BindOwnerIO = nil) or (not Activted) or (WaitConnecting) or (BindOwnerIO.Disable_Progress) then
      Result := False
  else
      Result := BindOwnerIO.WriteBuffer_is_NULL;
end;

function TStableClient_PeerIO.WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean;
begin
  if (BindOwnerIO = nil) or (not Activted) or (WaitConnecting) or (BindOwnerIO.Disable_Progress) then
      Result := inherited WriteBuffer_State(WriteBuffer_Queue_Num, WriteBuffer_Size)
  else
      Result := BindOwnerIO.WriteBuffer_State(WriteBuffer_Queue_Num, WriteBuffer_Size);
end;

procedure TStableClient_PeerIO.Progress;
begin
  Process_Send_Buffer();
  inherited Progress;
end;

procedure TZNet_CustomStableClient.ClientCustomProtocolReceiveBufferNotify(Sender: TZNet_Client; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
begin
  KeepAliveChecking := False;

  FillDone := FStableClientIO.Activted and (not FStableClientIO.WaitConnecting) and (FStableClientIO.BindOwnerIO <> nil);
  if FillDone then
    begin
      FStableClientIO.Write_Physics_Fragment(Buffer, Size);
    end;
end;

procedure TZNet_CustomStableClient.SetOwnerIOClient(const Value: TZNet_Client);
begin
  if FOwnerIOClient <> nil then
    begin
      Disconnect;
      FOwnerIOClient.FOnClientCustomProtocolReceiveBufferNotify := nil;
      FOwnerIOClient.Protocol := TCommunicationProtocol.cpZServer;
      FOwnerIOClient.TimeOutIDLE := 0;
      FOwnerIOClient.QuietMode := False;
    end;

  FOwnerIOClient := Value;

  if FOwnerIOClient <> nil then
    begin
      FOwnerIOClient.FOnClientCustomProtocolReceiveBufferNotify := ClientCustomProtocolReceiveBufferNotify;
      FOwnerIOClient.Protocol := TCommunicationProtocol.cpCustom;
      FOwnerIOClient.TimeOutIDLE := 0;
      FOwnerIOClient.QuietMode := False;
    end;
end;

procedure TZNet_CustomStableClient.BuildStableIO_Result(Sender: TPeerIO; Result_: TDFE);
var
  r_token, R_ID: Cardinal;
  cSec: TCipherSecurity;
  arry: TDF_ArrayByte;
  i: Integer;
  k: TCipherKeyBuffer;
begin
  if Result_.Reader.ReadBool then
    begin
      r_token := Result_.Reader.ReadCardinal;
      R_ID := Result_.Reader.ReadCardinal;
      cSec := TCipherSecurity(Result_.Reader.ReadByte);
      arry := Result_.Reader.ReadArrayByte;
      SetLength(k, arry.Count);
      for i := 0 to arry.Count - 1 do
          k[i] := arry[i];

      { connection token }
      FStableClientIO.Connection_Token := r_token;
      { bind physics IO }
      FStableClientIO.BindOwnerIO := Sender;
      { remote id }
      FStableClientIO.ID := R_ID;
      { Encrypt }
      FStableClientIO.FSendDataCipherSecurity := cSec;
      FStableClientIO.FCipherKey := TCipher.CopyKey(k);
      { switch state }
      FStableClientIO.Activted := True;
      FStableClientIO.WaitConnecting := False;
      { replace encrypt for physics IO }
      Sender.FSendDataCipherSecurity := cSec;
      Sender.FCipherKey := TCipher.CopyKey(k);
      { open sequence packet model }
      FStableClientIO.FSequencePacketActivted := True;
      FStableClientIO.FSequencePacketSignal := True;
      FStableClientIO.SequencePacketLimitOwnerIOMemory := FLimitSequencePacketMemoryUsage;

      { triger }
      TriggerDoConnectFinished;
      DoConnected(FStableClientIO);
      FStableClientIO.LastCommunicationTick_Received := GetTimeTick;
      FStableClientIO.LastCommunicationTick_KeepAlive := FStableClientIO.LastCommunicationTick_Received;

      if not FOwnerIOClient.QuietMode then
          FOwnerIOClient.ClientIO.Print('StableIO connection %s port:%d Success.', [FConnection_Addr, FConnection_Port]);
    end
  else
    begin
      Sender.PrintError(Result_.Reader.ReadString);
      TriggerDoConnectFailed;
    end;
end;

procedure TZNet_CustomStableClient.AsyncConnectResult(const cState: Boolean);
var
  d: TDFE;
begin
  if cState then
    begin
      d := TDFE.Create;
      FOwnerIOClient.SendStreamCmdM(C_BuildStableIO, d, BuildStableIO_Result);
      DisposeObject(d);
    end
  else
    begin
      FStableClientIO.WaitConnecting := False;

      if FAutomatedConnection then
          PostProgress.PostExecuteM(1.0, PostConnection)
      else
          TriggerDoConnectFailed;
    end;
end;

procedure TZNet_CustomStableClient.PostConnection(Sender: TN_Post_Execute);
begin
  if FStableClientIO.WaitConnecting then
      exit;

  FStableClientIO.WaitConnecting := True;
  FOwnerIOClient.AsyncConnectM(FConnection_Addr, FConnection_Port, AsyncConnectResult);
end;

procedure TZNet_CustomStableClient.OpenStableIO_Result(Sender: TPeerIO; Result_: TDFE);
var
  r_token, R_ID: Cardinal;
  cSec: TCipherSecurity;
  arry: TDF_ArrayByte;
  k: TCipherKeyBuffer;
begin
  if Result_.Reader.ReadBool then
    begin
      r_token := Result_.Reader.ReadCardinal;
      R_ID := Result_.Reader.ReadCardinal;
      cSec := TCipherSecurity(Result_.Reader.ReadByte);
      arry := Result_.Reader.ReadArrayByte;
      SetLength(k, arry.Count);
      arry.GetBuff(@k[0]);

      { connection token }
      FStableClientIO.Connection_Token := r_token;
      { bind physics IO }
      FStableClientIO.BindOwnerIO := Sender;
      { remote id }
      FStableClientIO.ID := R_ID;
      { Encrypt }
      FStableClientIO.FSendDataCipherSecurity := cSec;
      FStableClientIO.FCipherKey := TCipher.CopyKey(k);
      { remote inited }
      FStableClientIO.RemoteExecutedForConnectInit := True;
      { switch state }
      FStableClientIO.Activted := True;
      FStableClientIO.WaitConnecting := False;
      { replace encrypt for physics IO }
      Sender.FSendDataCipherSecurity := cSec;
      Sender.FCipherKey := TCipher.CopyKey(k);
      { sequence packet model }
      FStableClientIO.FSequencePacketActivted := True;
      FStableClientIO.FSequencePacketSignal := True;
      FStableClientIO.SequencePacketLimitOwnerIOMemory := FLimitSequencePacketMemoryUsage;
      FStableClientIO.ResetSequencePacketBuffer;
      FStableClientIO.SequencePacketVerifyTick := GetTimeTick;
      if not FStableClientIO.OwnerFramework.QuietMode then
          FStableClientIO.Print('StableIO calibrate session.', []);
    end
  else
    begin
      Sender.PrintError(Result_.Reader.ReadString);

      FStableClientIO.WaitConnecting := False;

      FStableClientIO.Activted := False;
      FStableClientIO.BindOwnerIO := nil;

      FOnAsyncConnectNotify_C := nil;
      FOnAsyncConnectNotify_M := nil;
      FOnAsyncConnectNotify_P := nil;
      FStableClientIO.DelayClose();

      if AutomatedConnection then
          PostProgress.PostExecuteM(1.0, PostConnection);
    end;
end;

procedure TZNet_CustomStableClient.AsyncReconnectionResult(const cState: Boolean);
var
  d: TDFE;
begin
  if not FStableClientIO.WaitConnecting then
      exit;

  if cState then
    begin
      d := TDFE.Create;
      d.WriteCardinal(FStableClientIO.Connection_Token);
      d.WriteArrayByte.SetBuff(@FStableClientIO.FCipherKey[0], Length(FStableClientIO.FCipherKey));
      FOwnerIOClient.SendStreamCmdM(C_OpenStableIO, d, OpenStableIO_Result);
      DisposeObject(d);
    end
  else
    begin
      FStableClientIO.WaitConnecting := False;
    end;
end;

procedure TZNet_CustomStableClient.PostReconnection(Sender: TN_Post_Execute);
begin
  if not FStableClientIO.Activted then
      exit;
  if FOwnerIOClient = nil then
      exit;
  if not FStableClientIO.WaitConnecting then
      exit;

  FOwnerIOClient.AsyncConnectM(FConnection_Addr, FConnection_Port, AsyncReconnectionResult);
end;

procedure TZNet_CustomStableClient.Reconnection;
begin
  if not FStableClientIO.Activted then
      exit;
  if FOwnerIOClient = nil then
      exit;
  if FStableClientIO.WaitConnecting then
      exit;

  FStableClientIO.WaitConnecting := True;
  FStableClientIO.OwnerIO_LastConnectTick := GetTimeTick;
  FStableClientIO.BindOwnerIO := nil;

  FOnAsyncConnectNotify_C := nil;
  FOnAsyncConnectNotify_M := nil;
  FOnAsyncConnectNotify_P := nil;
  PostProgress.PostExecuteM(1.0, PostReconnection);
end;

function TZNet_CustomStableClient.GetStopCommunicationTimeTick: TTimeTick;
begin
  if KeepAliveChecking then
      Result := GetTimeTick - SaveLastCommunicationTick_Received
  else
      Result := GetTimeTick - FStableClientIO.LastCommunicationTick_Received;
end;

constructor TZNet_CustomStableClient.Create;
begin
  inherited Create;
  EnabledAtomicLockAndMultiThread := False;
  PhysicsFragmentSwapSpaceTechnology := False;
  FIgnoreProcessConnectedAndDisconnect := True;

  FOwnerIOClient := nil;
  FStableClientIO := TStableClient_PeerIO.Create(self, nil);

  FConnection_Addr := '';
  FConnection_Port := 0;
  FAutomatedConnection := True;
  FLimitSequencePacketMemoryUsage := 0;
  FAutoFreeOwnerIOClient := False;
  FAutoProgressOwnerIOClient := True;
  CustomStableClientProgressing := False;
  KeepAliveChecking := False;
  SaveLastCommunicationTick_Received := FStableClientIO.LastCommunicationTick_Received;

  FOnAsyncConnectNotify_C := nil;
  FOnAsyncConnectNotify_M := nil;
  FOnAsyncConnectNotify_P := nil;
  name := 'StableClient';
end;

destructor TZNet_CustomStableClient.Destroy;
var
  phyCli: TZNet_Client;
begin
  Disconnect;

  phyCli := FOwnerIOClient;
  SetOwnerIOClient(nil);
  if (phyCli <> nil) and (FAutoFreeOwnerIOClient) then
      DisposeObject(phyCli);
  inherited Destroy;
end;

procedure TZNet_CustomStableClient.TriggerDoConnectFailed;
begin
  inherited TriggerDoConnectFailed;

  try
    if Assigned(FOnAsyncConnectNotify_C) then
        FOnAsyncConnectNotify_C(False)
    else if Assigned(FOnAsyncConnectNotify_M) then
        FOnAsyncConnectNotify_M(False)
    else if Assigned(FOnAsyncConnectNotify_P) then
        FOnAsyncConnectNotify_P(False);
  except
  end;

  FOnAsyncConnectNotify_C := nil;
  FOnAsyncConnectNotify_M := nil;
  FOnAsyncConnectNotify_P := nil;
end;

procedure TZNet_CustomStableClient.TriggerDoConnectFinished;
begin
  inherited TriggerDoConnectFinished;

  try
    if Assigned(FOnAsyncConnectNotify_C) then
        FOnAsyncConnectNotify_C(True)
    else if Assigned(FOnAsyncConnectNotify_M) then
        FOnAsyncConnectNotify_M(True)
    else if Assigned(FOnAsyncConnectNotify_P) then
        FOnAsyncConnectNotify_P(True);
  except
  end;

  FOnAsyncConnectNotify_C := nil;
  FOnAsyncConnectNotify_M := nil;
  FOnAsyncConnectNotify_P := nil;
end;

procedure TZNet_CustomStableClient.AsyncConnectC(addr: SystemString; Port: Word; const OnResult: TOnState_C);
begin
  Disconnect;

  FStableClientIO.Activted := False;
  FStableClientIO.BindOwnerIO := nil;

  FConnection_Addr := addr;
  FConnection_Port := Port;

  if FOwnerIOClient = nil then
    begin
      if Assigned(OnResult) then
          OnResult(False);
      exit;
    end;

  FOnAsyncConnectNotify_C := OnResult;
  FOnAsyncConnectNotify_M := nil;
  FOnAsyncConnectNotify_P := nil;
  PostProgress.PostExecuteM(0.0, PostConnection);
end;

procedure TZNet_CustomStableClient.AsyncConnectM(addr: SystemString; Port: Word; const OnResult: TOnState_M);
begin
  Disconnect;

  FStableClientIO.Activted := False;
  FStableClientIO.BindOwnerIO := nil;

  FConnection_Addr := addr;
  FConnection_Port := Port;

  if FOwnerIOClient = nil then
    begin
      if Assigned(OnResult) then
          OnResult(False);
      exit;
    end;

  FOnAsyncConnectNotify_C := nil;
  FOnAsyncConnectNotify_M := OnResult;
  FOnAsyncConnectNotify_P := nil;
  PostProgress.PostExecuteM(0.0, PostConnection);
end;

procedure TZNet_CustomStableClient.AsyncConnectP(addr: SystemString; Port: Word; const OnResult: TOnState_P);
begin
  Disconnect;

  FStableClientIO.Activted := False;
  FStableClientIO.BindOwnerIO := nil;

  FConnection_Addr := addr;
  FConnection_Port := Port;

  if FOwnerIOClient = nil then
    begin
      if Assigned(OnResult) then
          OnResult(False);
      exit;
    end;

  FOnAsyncConnectNotify_C := nil;
  FOnAsyncConnectNotify_M := nil;
  FOnAsyncConnectNotify_P := OnResult;

  PostProgress.PostExecuteM(0.0, PostConnection);
end;

function TZNet_CustomStableClient.Connect(addr: SystemString; Port: Word): Boolean;
var
  t: TTimeTick;
begin
  Disconnect;

  FStableClientIO.Activted := False;
  FStableClientIO.BindOwnerIO := nil;

  FConnection_Addr := addr;
  FConnection_Port := Port;

  Result := False;

  if FOwnerIOClient = nil then
      exit;

  if FOwnerIOClient.Connect(addr, Port) then
    begin
      AsyncConnectResult(True);

      t := GetTimeTick;
      while (not FStableClientIO.Activted) and (GetTimeTick - t < 5000) do
          Progress;
      Result := FStableClientIO.Activted;
    end;
end;

function TZNet_CustomStableClient.Connected: Boolean;
begin
  Result := FStableClientIO.Activted;
end;

procedure TZNet_CustomStableClient.Disconnect;
var
  tk: TTimeTick;
begin
  KeepAliveChecking := False;
  if (FOwnerIOClient <> nil) and (FOwnerIOClient.Connected) and (FStableClientIO.Activted) then
    begin
      FStableClientIO.FSequencePacketSignal := False;
      while FStableClientIO.IOBusy do
          ProgressWaitSend(FStableClientIO);
      FStableClientIO.SendConsoleNotifyCmd(C_CloseStableIO);
      FStableClientIO.Progress;
      tk := GetTimeTick() + 1000;
      while FOwnerIOClient.Connected and (not FOwnerIOClient.ClientIO.WriteBuffer_is_NULL) and (GetTimeTick() < tk) do
          FOwnerIOClient.ProgressWaitSend(FOwnerIOClient.ClientIO);
      FStableClientIO.FSequencePacketSignal := True;
    end;

  DisposeObject(FStableClientIO);
  FStableClientIO := TStableClient_PeerIO.Create(self, nil);
end;

function TZNet_CustomStableClient.ClientIO: TPeerIO;
begin
  Result := FStableClientIO;
end;

procedure TZNet_CustomStableClient.Progress;
var
  t: TTimeTick;
begin
  if CustomStableClientProgressing then
      exit;

  CustomStableClientProgressing := True;
  if (FOwnerIOClient <> nil) and (FAutoProgressOwnerIOClient) then
    begin
      FOwnerIOClient.Progress;
    end;
  inherited Progress;

  if FOwnerIOClient <> nil then
    if (FStableClientIO.Activted) and (FStableClientIO.IsSequencePacketModel) then
      begin
        t := GetTimeTick;
        if FStableClientIO.WaitConnecting then
          begin
            if t - FStableClientIO.OwnerIO_LastConnectTick > 5000 then
              begin
                KeepAliveChecking := False;
                FStableClientIO.WaitConnecting := False;
                FOwnerIOClient.Disconnect;
                Reconnection;
              end;
          end
        else if not FOwnerIOClient.Connected then
          begin
            KeepAliveChecking := False;
            Reconnection;
          end
        else if (FStableClientIO.FSequencePacketSignal) and (t - FStableClientIO.LastCommunicationTick_Received > 5000) then
          begin
            if (KeepAliveChecking) then
              begin
                FStableClientIO.LastCommunicationTick_Received := SaveLastCommunicationTick_Received;
                FStableClientIO.LastCommunicationTick_KeepAlive := FStableClientIO.LastCommunicationTick_Received;
                Reconnection;
                KeepAliveChecking := False;
              end
            else
              begin
                FStableClientIO.SendSequencePacketKeepAlive(nil, 0);
                SaveLastCommunicationTick_Received := FStableClientIO.LastCommunicationTick_Received;
                FStableClientIO.LastCommunicationTick_Received := GetTimeTick;
                FStableClientIO.LastCommunicationTick_KeepAlive := FStableClientIO.LastCommunicationTick_Received;
                KeepAliveChecking := True;
              end;
          end;
      end;

  CustomStableClientProgressing := False;
end;
