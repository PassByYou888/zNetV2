function TZNet_Server.CanExecuteCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean;
begin
  if IsSystemCMD(Cmd) then
      Result := True
  else
      Result := inherited CanExecuteCommand(Sender, Cmd);
end;

function TZNet_Server.CanSendCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean;
begin
  Result := inherited CanSendCommand(Sender, Cmd);
end;

function TZNet_Server.CanRegCommand(Sender: TZNet; const Cmd: SystemString): Boolean;
begin
  if IsSystemCMD(Cmd) then
      Result := True
  else
      Result := inherited CanRegCommand(Sender, Cmd);
end;

procedure TZNet_Server.Command_CipherModel(Sender: TPeerIO; InData, OutData: TDFE);
var
  tmp: TUID___;
  uidArr: TDF_ArrayByte; { FIX: local holder for safe length checking }
begin
  tmp := Null_UID(); { FIX: ensure tmp is always initialized, even when InData is empty }
  try
    if not InData.Reader.IsEnd then
      begin
        Sender.UserDefine.FWorkPlatform := TExecutePlatform(InData.Reader.ReadInteger);
        if not InData.Reader.IsEnd then
          begin
            { FIX: previous code accessed Buffer__ without validating Count, which could
              crash on an empty / short array. Read once into a local and check length. }
            uidArr := InData.Reader.ReadArrayByte;
            if uidArr.Count >= SizeOf(TUID___) then
                tmp := Generate_Global_UID(PUID___(uidArr.Buffer__.Memory)^)
            else
                tmp := Generate_Global_UID();
          end
        else
            tmp := Generate_Global_UID();
      end;
  except
  end;

  OutData.WriteCardinal(Sender.ID);
  OutData.WriteByte(Byte(Sender.FSendDataCipherSecurity));
  OutData.WriteArrayByte.SetBuff(@Sender.FCipherKey[0], Length(Sender.FCipherKey));
  OutData.WriteMD5(FInitedTimeMD5);
  { service state }
  OutData.WriteBool(UsedParallelEncrypt);
  OutData.WriteBool(SyncOnResult);
  OutData.WriteBool(SyncOnCompleteBuffer);
  OutData.WriteBool(EnabledAtomicLockAndMultiThread);
  OutData.WriteBool(TimeOutKeepAlive);
  OutData.WriteBool(QuietMode);
  OutData.WriteUInt64(IdleTimeOut);
  OutData.WriteBool(SendDataCompressed);
  OutData.WriteBool(CompleteBufferCompressed);
  OutData.WriteCardinal(MaxCompleteBufferSize);
  OutData.WriteUInt64(ProgressMaxDelay);
  OutData.WriteArrayByte.Buffer__.WritePtr(@tmp[0], SizeOf(TUID___));

  Sender.FRemoteExecutedForConnectInit := True;

  DoIOConnectAfter(Sender);

  if FAutomatedP2PVMClient and (FAutomatedP2PVMClientBind.Count > 0) then
      AutomatedP2PVM_Open(Sender);
end;

procedure TZNet_Server.Command_Wait(Sender: TPeerIO; InData: SystemString; var OutData: SystemString);
begin
  OutData := IntToHex(GetTimeTick, SizeOf(TTimeTick) * 2);
end;

procedure TZNet_Server.Framework_Internal_IO_Create(const Sender: TPeerIO);
begin
  DoIOConnectBefore(Sender);
  inherited Framework_Internal_IO_Create(Sender);
  if FProtocol = cpCustom then
      DoIOConnectAfter(Sender);
end;

procedure TZNet_Server.Framework_Internal_IO_Destroy(const Sender: TPeerIO);
begin
  DoIODisconnect(Sender);
  inherited Framework_Internal_IO_Destroy(Sender);
end;

procedure TZNet_Server.FillCustomBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
begin
  if (Protocol = cpCustom) then
    begin
      if Assigned(FOnServerCustomProtocolReceiveBufferNotify) then
        begin
          FOnServerCustomProtocolReceiveBufferNotify(Sender, Buffer, Size, FillDone);
          if FillDone then
              exit;
        end;
      OnReceiveBuffer(Sender, Buffer, Size, FillDone);
    end;
end;

constructor TZNet_Server.Create;
begin
  CreateCustomHashPool(10 * 10000);
end;

constructor TZNet_Server.CreateCustomHashPool(HashPoolSize: Integer);
begin
  inherited Create(HashPoolSize);
  FOnServerCustomProtocolReceiveBufferNotify := nil;

  FStableIOProgressing := False;
  FStableIO := nil;

  FSyncOnResult := True;
  FSyncOnCompleteBuffer := True;

  RegisterStream(C_CipherModel).OnExecute := Command_CipherModel;
  RegisterConsole(C_Wait).OnExecute := Command_Wait;

  FFrameworkIsServer := True;
  FFrameworkIsClient := False;

  name := '';
end;

destructor TZNet_Server.Destroy;
var
  tk: TTimeTick;
begin
  if (FStableIO <> nil) and (not FStableIO.AutoFreeOwnerIOServer) then
    begin
      FStableIO.OwnerIOServer := nil;
      DisposeObject(FStableIO);
      FStableIO := nil;
    end;

  tk := GetTimeTick();
  while (FCMD_Thread_Runing_Num > 0) and (GetTimeTick() - tk < 5000) do // fixed long wait, by.qq600585,
      Check_Soft_Thread_Synchronize(100, False);

  DeleteRegistedCMD(C_CipherModel);
  DeleteRegistedCMD(C_Wait);
  inherited Destroy;
end;

procedure TZNet_Server.Progress;
begin
  inherited Progress;

  if (FStableIO <> nil) and (not FStableIOProgressing) then
    begin
      FStableIOProgressing := True;
      FStableIO.Progress;
      FStableIOProgressing := False;
    end;
end;

function TZNet_Server.StableIO: TZNet_StableServer;
begin
  if FStableIO = nil then
    begin
      FStableIO := TZNet_StableServer.Create;
      FStableIO.AutoFreeOwnerIOServer := False;
      FStableIO.AutoProgressOwnerIOServer := True;
      FStableIO.OwnerIOServer := self;
    end;

  Result := FStableIO;
end;

procedure TZNet_Server.Disconnect(ID: Cardinal);
begin
  Disconnect(ID, 0);
end;

procedure TZNet_Server.Disconnect(ID: Cardinal; delay: Double);
var
  io_cli: TPeerIO;
begin
  io_cli := PeerIO[ID];
  if io_cli <> nil then
      io_cli.DelayClose(delay);
end;

procedure TZNet_Server.OnReceiveBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
begin
end;

procedure TZNet_Server.BeginWriteBuffer(P_IO: TPeerIO);
begin
  BeginWriteCustomBuffer(P_IO);
end;

procedure TZNet_Server.EndWriteBuffer(P_IO: TPeerIO);
begin
  EndWriteCustomBuffer(P_IO);
end;

procedure TZNet_Server.WriteBuffer(P_IO: TPeerIO; const Buffer: PByte; const Size: NativeInt);
begin
  WriteCustomBuffer(P_IO, Buffer, Size);
end;

procedure TZNet_Server.WriteBuffer(P_IO: TPeerIO; const Buffer: TMS64);
begin
  WriteBuffer(P_IO, Buffer.Memory, Buffer.Size);
end;

procedure TZNet_Server.WriteBuffer(P_IO: TPeerIO; const Buffer: TMem64);
begin
  WriteBuffer(P_IO, Buffer.Memory, Buffer.Size);
end;

procedure TZNet_Server.WriteBuffer(P_IO: TPeerIO; const Buffer: TMS64; const doneFreeBuffer: Boolean);
begin
  WriteBuffer(P_IO, Buffer);
  if doneFreeBuffer then
      DisposeObject(Buffer);
end;

procedure TZNet_Server.WriteBuffer(P_IO: TPeerIO; const Buffer: TMem64; const doneFreeBuffer: Boolean);
begin
  WriteBuffer(P_IO, Buffer);
  if doneFreeBuffer then
      DisposeObject(Buffer);
end;

procedure TZNet_Server.StopService;
begin
end;

function TZNet_Server.StartService(Host: SystemString; Port: Word): Boolean;
begin
  Result := False;
end;

procedure TZNet_Server.DoIOConnectBefore(Sender: TPeerIO);
begin
end;

procedure TZNet_Server.DoIOConnectAfter(Sender: TPeerIO);
begin
end;

procedure TZNet_Server.DoIODisconnect(Sender: TPeerIO);
begin
end;

procedure TZNet_Server.SendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;
  if not QuietMode then
      P_IO.PrintCommand('Send Console cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;
  if not QuietMode then
      P_IO.PrintCommand('Send Console cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleM := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Console cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamM := OnResult;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Console cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamM := OnResult;
  p^.OnConsoleFailedM := OnFailed;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendConsoleCmdP(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Console cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleP := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendConsoleCmdP(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Console cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamP := OnResult;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendConsoleCmdP(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Console cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  p^.OnConsoleParamP := OnResult;
  p^.OnConsoleFailedP := OnFailed;
  p^.Param1 := Param1;
  p^.Param2 := Param2;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendConsoleCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString);
begin
  SendConsoleCmd(PeerIO[IO_ID], Cmd, ConsoleData);
end;

procedure TZNet_Server.SendConsoleCmdM(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M);
begin
  SendConsoleCmdM(PeerIO[IO_ID], Cmd, ConsoleData, OnResult);
end;

procedure TZNet_Server.SendConsoleCmdM(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M);
begin
  SendConsoleCmdM(PeerIO[IO_ID], Cmd, ConsoleData, Param1, Param2, OnResult);
end;

procedure TZNet_Server.SendConsoleCmdM(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M);
begin
  SendConsoleCmdM(PeerIO[IO_ID], Cmd, ConsoleData, Param1, Param2, OnResult, OnFailed);
end;

procedure TZNet_Server.SendConsoleCmdP(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P);
begin
  SendConsoleCmdP(PeerIO[IO_ID], Cmd, ConsoleData, OnResult);
end;

procedure TZNet_Server.SendConsoleCmdP(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P);
begin
  SendConsoleCmdP(PeerIO[IO_ID], Cmd, ConsoleData, Param1, Param2, OnResult);
end;

procedure TZNet_Server.SendConsoleCmdP(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P);
begin
  SendConsoleCmdP(PeerIO[IO_ID], Cmd, ConsoleData, Param1, Param2, OnResult, OnFailed);
end;

procedure TZNet_Server.SendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(P_IO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(P_IO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  p^.OnStreamM := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamM := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
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

procedure TZNet_Server.SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
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

procedure TZNet_Server.SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(P_IO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  p^.OnStreamP := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  p^.OnStreamP := OnResult;
  Post_Queue_Data_To_Swap_Queue(p);
end;

procedure TZNet_Server.SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
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

procedure TZNet_Server.SendStreamCmdP(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send Stream cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
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

procedure TZNet_Server.SendStreamCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
begin
  SendStreamCmd(PeerIO[IO_ID], Cmd, StreamData, DoneAutoFree);
end;

procedure TZNet_Server.SendStreamCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE);
begin
  SendStreamCmd(PeerIO[IO_ID], Cmd, StreamData);
end;

procedure TZNet_Server.SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean);
begin
  SendStreamCmdM(PeerIO[IO_ID], Cmd, StreamData, OnResult, DoneAutoFree);
end;

procedure TZNet_Server.SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M);
begin
  SendStreamCmdM(PeerIO[IO_ID], Cmd, StreamData, OnResult);
end;

procedure TZNet_Server.SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M);
begin
  SendStreamCmdM(PeerIO[IO_ID], Cmd, StreamData, Param1, Param2, OnResult);
end;

procedure TZNet_Server.SendStreamCmdM(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M);
begin
  SendStreamCmdM(PeerIO[IO_ID], Cmd, StreamData, Param1, Param2, OnResult, OnFailed);
end;

procedure TZNet_Server.SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean);
begin
  SendStreamCmdP(PeerIO[IO_ID], Cmd, StreamData, OnResult, DoneAutoFree);
end;

procedure TZNet_Server.SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P);
begin
  SendStreamCmdP(PeerIO[IO_ID], Cmd, StreamData, OnResult);
end;

procedure TZNet_Server.SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P);
begin
  SendStreamCmdP(PeerIO[IO_ID], Cmd, StreamData, Param1, Param2, OnResult);
end;

procedure TZNet_Server.SendStreamCmdP(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P);
begin
  SendStreamCmdP(PeerIO[IO_ID], Cmd, StreamData, Param1, Param2, OnResult, OnFailed);
end;

procedure TZNet_Server.SendConsoleNotifyCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;
  if not QuietMode then
      P_IO.PrintCommand('Send ConsoleNotify cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendConsoleNotifyCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.ConsoleData := ConsoleData;
  Post_Queue_Data_To_Swap_Queue(p);
  if FAutomaticWaitRemoteReponse then
      Send_NULL(P_IO);
end;

procedure TZNet_Server.SendConsoleNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString);
begin
  SendConsoleNotifyCmd(P_IO, Cmd, '');
end;

procedure TZNet_Server.SendConsoleNotifyCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString);
begin
  SendConsoleNotifyCmd(PeerIO[IO_ID], Cmd, ConsoleData);
end;

procedure TZNet_Server.SendConsoleNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString);
begin
  SendConsoleNotifyCmd(PeerIO[IO_ID], Cmd, '');
end;

procedure TZNet_Server.SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not CanSendCommand(P_IO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(StreamData);
      exit;
    end;
  if not QuietMode then
      P_IO.PrintCommand('Send StreamNotify cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamNotifyCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := DoneAutoFree;
  p^.StreamData := StreamData;
  Post_Queue_Data_To_Swap_Queue(p);
  if FAutomaticWaitRemoteReponse then
      Send_NULL(P_IO);
end;

procedure TZNet_Server.SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Send StreamNotify cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendStreamNotifyCMD;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.DoneAutoFree := True;
  p^.StreamData := TMS64.Create;
  if StreamData <> nil then
      StreamData.FastEncodeTo(p^.StreamData)
  else
      TDFE.BuildEmptyStream(p^.StreamData);
  Post_Queue_Data_To_Swap_Queue(p);
  if FAutomaticWaitRemoteReponse then
      Send_NULL(P_IO);
end;

procedure TZNet_Server.SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString);
var
  d: TDFE;
begin
  d := TDFE.Create;
  SendStreamNotifyCmd(P_IO, Cmd, d);
  DisposeObject(d);
end;

procedure TZNet_Server.SendStreamNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
begin
  SendStreamNotifyCmd(PeerIO[IO_ID], Cmd, StreamData, DoneAutoFree);
end;

procedure TZNet_Server.SendStreamNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData: TDFE);
begin
  SendStreamNotifyCmd(PeerIO[IO_ID], Cmd, StreamData);
end;

procedure TZNet_Server.SendStreamNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString);
begin
  SendStreamNotifyCmd(PeerIO[IO_ID], Cmd);
end;

procedure TZNet_Server.SendBigStream(P_IO: TPeerIO; const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) then
    begin
      if DoneAutoFree then
          DisposeObject(BigStream);
      exit;
    end;
  if not CanSendCommand(P_IO, Cmd) then
    begin
      if DoneAutoFree then
          DisposeObject(BigStream);
      exit;
    end;
  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendBigStream;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;
  p^.BigStreamStartPos := StartPos;

  LockSend;
  try
    if FBigStreamMemorySwapSpace and DoneAutoFree and P_IO.IOBusy and (BigStream.Size > FBigStreamSwapSpaceTriggerSize)
      and ((BigStream is TMS64) or (BigStream is TMemoryStream)) then
      begin
        if not QuietMode then
            P_IO.PrintCommand('swap space technology cache for "%s"', Cmd);
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
      P_IO.PrintCommand('Send BigStream cmd: %s', Cmd);
end;

procedure TZNet_Server.SendBigStream(P_IO: TPeerIO; const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean);
begin
  SendBigStream(P_IO, Cmd, BigStream, 0, DoneAutoFree);
end;

procedure TZNet_Server.SendBigStream(IO_ID: Cardinal; const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean);
begin
  SendBigStream(PeerIO[IO_ID], Cmd, BigStream, StartPos, DoneAutoFree);
end;

procedure TZNet_Server.SendBigStream(IO_ID: Cardinal; const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean);
begin
  SendBigStream(PeerIO[IO_ID], Cmd, BigStream, DoneAutoFree);
end;

procedure TZNet_Server.SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean);
var
  p: PQueueData;
begin
  { init queue data }
  if (P_IO = nil) or (not P_IO.Connected) or (P_IO.Disable_Progress) then
    begin
      if DoneAutoFree then
          System.FreeMemory(buff);
      exit;
    end;
  if not CanSendCommand(P_IO, Cmd) then
    begin
      if DoneAutoFree then
          System.FreeMemory(buff);
      exit;
    end;
  if not QuietMode then
      P_IO.PrintCommand('Send complete buffer cmd: %s', Cmd);

  p := NewQueueData(P_IO);
  p^.State := TQueueState.qsSendCompleteBuffer;
  p^.Cmd := Cmd;
  p^.Cipher := P_IO.FSendDataCipherSecurity;

  LockSend;
  try
    { FIX: previous code used 'BuffSize.Size' which is invalid for NativeInt. }
    if FCompleteBufferSwapSpace and DoneAutoFree
      and ((FCompleteBufferSwapSpaceTriggerSize <= 0) or (BuffSize > FCompleteBufferSwapSpaceTriggerSize))
      and P_IO.IOBusy() then
      begin
        if not QuietMode then
            P_IO.PrintCommand('ZDB2 swap space technology cache for "%s"', Cmd);
        P_IO.FReceived_Physics_Critical.Lock;
        p^.Buffer_Swap_Memory := TZDB2_Swap_Space_Technology.RunTime_Pool.Create_Memory(buff, BuffSize, False);
        P_IO.FReceived_Physics_Critical.UnLock;
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
  if FAutomaticWaitRemoteReponse then
      Send_NULL(P_IO);
end;

procedure TZNet_Server.SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean);
begin
  SendCompleteBuffer(P_IO, Cmd, buff.Memory, buff.Size, DoneAutoFree);
  if DoneAutoFree then
    begin
      buff.DiscardMemory;
      DisposeObject(buff);
    end;
end;

procedure TZNet_Server.SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean);
begin
  SendCompleteBuffer(P_IO, Cmd, buff.Memory, buff.Size, DoneAutoFree);
  if DoneAutoFree then
    begin
      buff.DiscardMemory;
      DisposeObject(buff);
    end;
end;

procedure TZNet_Server.SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE);
begin
  SendCompleteBuffer_StreamNotify(P_IO, Cmd, buff);
end;

procedure TZNet_Server.SendCompleteBuffer_StreamNotify(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE);
var
  tmp: TMS64;
begin
  tmp := TMS64.CustomCreate(64 * 1024);
  buff.FastEncodeTo(tmp);
  SendCompleteBuffer(P_IO, Cmd, tmp, True);
end;

procedure TZNet_Server.SendCompleteBuffer_NoWait_StreamM(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M);
var
  p: PCommandCompleteBuffer_NoWait_Stream_Data;
  m64: TMS64;
begin
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;
  if not P_IO.Is_Double_Tunnel then
    begin
      P_IO.PrintError('cmd %s only work in double tunnel', [Cmd]);
      exit;
    end;
  if not P_IO.Is_Send_Tunnel then
    begin
      P_IO.PrintError('cmd %s only work in send tunnel', [Cmd]);
      exit;
    end;
  if not QuietMode then
      P_IO.PrintCommand('Send complete buffer cmd: %s', Cmd);

  New(p);
  p^.Init;
  p^.ID := P_IO.ID;
  p^.OnStreamM := OnResult;

  m64 := TMS64.CustomCreate(64 * 1024);
  m64.WriteUInt64(UInt64(p));
  buff.FastEncodeTo(m64);

  SendCompleteBuffer(P_IO, Cmd, m64, True);
end;

procedure TZNet_Server.SendCompleteBuffer_NoWait_StreamP(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P);
var
  p: PCommandCompleteBuffer_NoWait_Stream_Data;
  m64: TMS64;
begin
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;
  if not P_IO.Is_Double_Tunnel then
    begin
      P_IO.PrintError('cmd %s only work in double tunnel', [Cmd]);
      exit;
    end;
  if not P_IO.Is_Send_Tunnel then
    begin
      P_IO.PrintError('cmd %s only work in send tunnel', [Cmd]);
      exit;
    end;
  if not QuietMode then
      P_IO.PrintCommand('Send complete buffer cmd: %s', Cmd);

  New(p);
  p^.Init;
  p^.ID := P_IO.ID;
  p^.OnStreamP := OnResult;

  m64 := TMS64.CustomCreate(64 * 1024);
  m64.WriteUInt64(UInt64(p));
  buff.FastEncodeTo(m64);

  SendCompleteBuffer(P_IO, Cmd, m64, True);
end;

procedure TZNet_Server.SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean);
begin
  SendCompleteBuffer(PeerIO[IO_ID], Cmd, buff, BuffSize, DoneAutoFree);
end;

procedure TZNet_Server.SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean);
begin
  SendCompleteBuffer(IO_ID, Cmd, buff.Memory, buff.Size, DoneAutoFree);
  if DoneAutoFree then
    begin
      buff.DiscardMemory;
      DisposeObject(buff);
    end;
end;

procedure TZNet_Server.SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean);
begin
  SendCompleteBuffer(IO_ID, Cmd, buff.Memory, buff.Size, DoneAutoFree);
  if DoneAutoFree then
    begin
      buff.DiscardMemory;
      DisposeObject(buff);
    end;
end;

procedure TZNet_Server.SendCompleteBuffer(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE);
var
  tmp: TMS64;
begin
  tmp := TMS64.CustomCreate(64 * 1024);
  buff.FastEncodeTo(tmp);
  SendCompleteBuffer(IO_ID, Cmd, tmp, True);
end;

procedure TZNet_Server.SendCompleteBuffer_NoWait_StreamM(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M);
begin
  SendCompleteBuffer_NoWait_StreamM(PeerIO[IO_ID], Cmd, buff, OnResult);
end;

procedure TZNet_Server.SendCompleteBuffer_NoWait_StreamP(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P);
begin
  SendCompleteBuffer_NoWait_StreamP(PeerIO[IO_ID], Cmd, buff, OnResult);
end;

procedure TZNet_Server.SendCompleteBuffer_StreamNotify(IO_ID: Cardinal; const Cmd: SystemString; buff: TDFE);
begin
  SendCompleteBuffer_StreamNotify(PeerIO[IO_ID], Cmd, buff);
end;

procedure TZNet_Server.Send_NULL(P_IO: TPeerIO);
begin
  SendConsoleCmd(P_IO, C_NULL, '');
end;

procedure TZNet_Server.SendNULL(P_IO: TPeerIO);
begin
  SendConsoleCmd(P_IO, C_NULL, '');
end;

function TZNet_Server.WaitSendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;
var
  waitIntf: TWaitSendConsoleCmdIntf;
  timetick: TTimeTick;
  IO_ID: Cardinal;
begin
  Result := '';
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Begin Wait Console cmd: %s', Cmd);

  IO_ID := P_IO.ID;

  timetick := GetTimeTick + TimeOut_;

  while ExistsID(IO_ID) and (P_IO.WaitOnResult or P_IO.BigStreamReceiveing or P_IO.FWaitSendBusy) do
    begin
      ProgressWaitSend(P_IO);
      if not Exists(P_IO) then
          exit;
      if (TimeOut_ > 0) and (GetTimeTick > timetick) then
          exit;
    end;

  if not ExistsID(IO_ID) then
      exit;

  P_IO.FWaitSendBusy := True;

  try
    waitIntf := TWaitSendConsoleCmdIntf.Create;
    waitIntf.Done := False;
    waitIntf.NewResult := '';
    SendConsoleCmdM(P_IO, Cmd, ConsoleData, nil, nil, waitIntf.DoConsoleParam, waitIntf.DoConsoleFailed);
    while ExistsID(IO_ID) and (not waitIntf.Done) do
      begin
        ProgressWaitSend(IO_ID);
        TCompute.Sleep(1);
        if (TimeOut_ > 0) and (GetTimeTick > timetick) then
            Break;
      end;
    if not waitIntf.Failed then
        Result := waitIntf.NewResult
    else
        Result := '';

    { FIX: when waitIntf.Done = False (timeout path), previously the waitIntf object
      was leaked. Also we cannot DisposeObject immediately because a late response
      callback may still reference it and cause use-after-free. Defer the free. }
    if waitIntf.Done then
        DisposeObject(waitIntf)
    else
        DelayFreeObject(60.0, waitIntf);

    if not QuietMode then
      if ExistsID(IO_ID) then
          P_IO.PrintCommand('End Wait Console cmd: %s', Cmd);
  except
      Result := '';
  end;

  if ExistsID(IO_ID) then
      P_IO.FWaitSendBusy := False;
end;

procedure TZNet_Server.WaitSendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);
var
  waitIntf: TWaitSendStreamCmdIntf;
  timetick: TTimeTick;
  IO_ID: Cardinal;
begin
  if (P_IO = nil) or (not P_IO.Connected) then
      exit;
  if not CanSendCommand(P_IO, Cmd) then
      exit;

  if not QuietMode then
      P_IO.PrintCommand('Begin Wait Stream cmd: %s', Cmd);

  IO_ID := P_IO.ID;

  timetick := GetTimeTick + TimeOut_;

  while ExistsID(IO_ID) and (P_IO.WaitOnResult or P_IO.BigStreamReceiveing or P_IO.FWaitSendBusy) do
    begin
      ProgressWaitSend(P_IO);
      if not Exists(P_IO) then
          exit;
      if (TimeOut_ > 0) and (GetTimeTick > timetick) then
          exit;
    end;

  if not ExistsID(IO_ID) then
      exit;

  P_IO.FWaitSendBusy := True;

  try
    waitIntf := TWaitSendStreamCmdIntf.Create;
    waitIntf.Done := False;
    SendStreamCmdM(P_IO, Cmd, StreamData, nil, nil, waitIntf.DoStreamParam, waitIntf.DoStreamFailed);
    while ExistsID(IO_ID) and (not waitIntf.Done) do
      begin
        ProgressWaitSend(IO_ID);
        TCompute.Sleep(1);
        if (TimeOut_ > 0) and (GetTimeTick > timetick) then
            Break;
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

    if not QuietMode then
      if ExistsID(IO_ID) then
          P_IO.PrintCommand('End Wait Stream cmd: %s', Cmd);
  except
  end;

  if ExistsID(IO_ID) then
      P_IO.FWaitSendBusy := False;
end;

function TZNet_Server.WaitSendConsoleCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;
begin
  Result := WaitSendConsoleCmd(PeerIO[IO_ID], Cmd, ConsoleData, TimeOut_);
end;

procedure TZNet_Server.WaitSendStreamCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);
begin
  WaitSendStreamCmd(PeerIO[IO_ID], Cmd, StreamData, Result_, TimeOut_);
end;

procedure TZNet_Server.Send_NULL(IO_ID: Cardinal);
begin
  Send_NULL(PeerIO[IO_ID]);
end;

procedure TZNet_Server.BroadcastConsoleNotifyCmd(const Cmd, ConsoleData: SystemString);
var
  IO_ID: Cardinal;
  IO_Array: TIO_Array;
  P_IO: TPeerIO;
begin
  GetIO_Array(IO_Array);
  for IO_ID in IO_Array do
    begin
      P_IO := PeerIO[IO_ID];
      if P_IO <> nil then
          SendConsoleNotifyCmd(P_IO, Cmd, ConsoleData);
    end;
end;

procedure TZNet_Server.BroadcastStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE);
var
  IO_ID: Cardinal;
  IO_Array: TIO_Array;
  P_IO: TPeerIO;
begin
  GetIO_Array(IO_Array);
  for IO_ID in IO_Array do
    begin
      P_IO := PeerIO[IO_ID];
      if P_IO <> nil then
          SendStreamNotifyCmd(P_IO, Cmd, StreamData);
    end;
end;

procedure TZNet_Server.BroadcastCompleteBufferCmd(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt);
var
  IO_ID: Cardinal;
  IO_Array: TIO_Array;
  m64: TMem64;
begin
  GetIO_Array(IO_Array);
  for IO_ID in IO_Array do
    begin
      m64 := TMem64.Create;
      m64.WritePtr(buff, BuffSize);
      SendCompleteBuffer(IO_ID, Cmd, m64, True);
    end;
end;

procedure TZNet_Server.BroadcastCompleteBufferCmd(const Cmd: SystemString; StreamData: TDFE);
var
  IO_ID: Cardinal;
  IO_Array: TIO_Array;
begin
  GetIO_Array(IO_Array);
  for IO_ID in IO_Array do
      SendCompleteBuffer(IO_ID, Cmd, StreamData);
end;

function TZNet_Server.GetCount: Integer;
begin
  Result := FPeerIO_HashPool.Count;
end;

function TZNet_Server.Exists(P_IO: TPeerIO): Boolean;
begin
  Result := FPeerIO_HashPool.Exists_Value(P_IO);
end;

function TZNet_Server.Exists(P_IO: TPeer_IO_User_Define): Boolean;
begin
  Result := Exists(P_IO.Owner);
end;

function TZNet_Server.Exists(P_IO: TPeer_IO_User_Special): Boolean;
begin
  Result := Exists(P_IO.Owner);
end;

function TZNet_Server.Exists(IO_ID: Cardinal): Boolean;
begin
  Result := FPeerIO_HashPool.Exists_Key(IO_ID);
end;

function TZNet_Server.GetPeerIO(ID: Cardinal): TPeerIO;
begin
  Result := FPeerIO_HashPool[ID];
end;
