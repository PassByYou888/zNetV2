procedure TAutomatedP2PVMServiceBind.AddService(Service: TZNet_WithP2PVM_Server; IPV6: SystemString; Port: Word);
var
  p: PAutomatedP2PVMServiceData;
begin
  New(p);
  p^.Service := Service;
  p^.Service.StartService(IPV6, Port);
  Add(p);
end;

procedure TAutomatedP2PVMServiceBind.AddService(Service: TZNet_WithP2PVM_Server);
var
  p: PAutomatedP2PVMServiceData;
begin
  New(p);
  p^.Service := Service;
  Add(p);
end;

procedure TAutomatedP2PVMServiceBind.RemoveService(Service: TZNet_WithP2PVM_Server);
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    if Items[i]^.Service = Service then
      begin
        Dispose(Items[i]);
        Delete(i);
      end;
end;

procedure TAutomatedP2PVMServiceBind.Clean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
      Dispose(Items[i]);
  Clear;
end;

function TAutomatedP2PVMServiceBind.FoundService(Service: TZNet_WithP2PVM_Server): PAutomatedP2PVMServiceData;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i]^.Service = Service then
      begin
        Result := Items[i];
        exit;
      end;
end;

procedure TAutomatedP2PVMClientBind.AddClient(Client: TZNet_WithP2PVM_Client; IPV6: SystemString; Port: Word);
var
  p: PAutomatedP2PVMClientData;
begin
  New(p);
  p^.Client := Client;
  p^.IPV6 := IPV6;
  p^.Port := Port;
  p^.RequestConnecting := False;
  Add(p);
end;

procedure TAutomatedP2PVMClientBind.RemoveClient(Client: TZNet_WithP2PVM_Client);
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    if Items[i]^.Client = Client then
      begin
        Dispose(Items[i]);
        Delete(i);
      end;
end;

procedure TAutomatedP2PVMClientBind.Clean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
      Dispose(Items[i]);
  Clear;
end;

function TAutomatedP2PVMClientBind.FoundClient(Client: TZNet_WithP2PVM_Client): PAutomatedP2PVMClientData;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i]^.Client = Client then
      begin
        Result := Items[i];
        exit;
      end;
end;

procedure TZNet_Progress_Pool.DoFree(var data: TZNet_Progress);
begin
  if data = nil then
      exit;
  data.FPool_Ptr := nil;
  DisposeObjectAndNil(data);
end;

constructor TZNet_Progress.Create(OwnerFramework_: TZNet);
begin
  inherited Create;
  FOwnerFramework := OwnerFramework_;
  ResetEvent();
  NextProgressDoFree := False;
end;

destructor TZNet_Progress.Destroy;
var
  i: Integer;
begin
  i := 0;
  try
    if FPool_Ptr <> nil then
      begin
        FPool_Ptr^.data := nil;
        OwnerFramework.FProgress_Pool.Remove_P(FPool_Ptr);
      end;
    if Assigned(OnFree) then
        OnFree(self);
  except
  end;

  inherited Destroy;
end;

procedure TZNet_Progress.Progress;
begin
  try
    if Assigned(OnProgress_C) then
        OnProgress_C(self)
    else if Assigned(OnProgress_M) then
        OnProgress_M(self)
    else if Assigned(OnProgress_P) then
        OnProgress_P(self);
  except
  end;
end;

procedure TZNet_Progress.ResetEvent;
begin
  OnFree := nil;
  OnProgress_C := nil;
  OnProgress_M := nil;
  OnProgress_P := nil;
end;

procedure TZNet_Instance_Pool.Print_Status;
  procedure do_print_io_info(prefix_: SystemString; Net: TZNet);
  var
    p2p_info: SystemString;
    p2p_VM_Num: NativeInt;
    L: TCore_List;
    p: PUInt32HashListObjectStruct;
    i: Integer;
  begin
    if Net.IOPool.Num > 0 then
      with Net.IOPool.Repeat_ do
        repeat
          if Queue^.data^.data.Second.P2PVM = nil then
              p2p_VM_Num := 0
          else
              p2p_VM_Num := Queue^.data^.data.Second.P2PVM.FrameworkPool.Count;
          DoStatus(prefix_ + 'io:%d ip:%s p2pVM:%d', [Queue^.data^.data.Primary, Queue^.data^.data.Second.GetPeerIP, p2p_VM_Num]);
          if Queue^.data^.data.Second.P2PVM <> nil then
            begin
              L := TCore_List.Create;
              Queue^.data^.data.Second.P2PVM.FrameworkPool.GetListData(L);
              for i := 0 to L.Count - 1 do
                begin
                  p := L[i];
                  if (p <> nil) and (p^.data <> nil) and (p^.data is TZNet) then
                    begin
                      DoStatus(prefix_ + #9'pspVM:%s <%s> IO:%d', [p^.data.ClassName, TZNet(p^.data).name, TZNet(p^.data).IOPool.Num]);
                    end;
                end;
              DisposeObject(L);
            end;
        until not Next;
  end;

begin
  Lock;
  try
    if Num > 0 then
      begin
        with Repeat_ do
          repeat
            DoStatus('%s <%s> IO:%d, PPS:%f PCPU:%dms',
              [Queue^.data.ClassName, Queue^.data.name, Queue^.data.IOPool.Num, Queue^.data.Progress_CPS.CPS, Queue^.data.Progress_CPS.CPU_Time]);
            do_print_io_info(#9, Queue^.data);
          until not Next;
      end;
  finally
      UnLock;
  end;
end;

procedure TZNet_Instance_Pool.Print_Service_Statistics_Info;
  procedure do_print_statistics_info(prefix_: SystemString; Net: TZNet);
  var
    st: TStatisticsType;
  begin
    for st := low(TStatisticsType) to high(TStatisticsType) do
        DoStatus(prefix_ + '%s (state) = %d (Num)', [GetEnumName(TypeInfo(TStatisticsType), Ord(st)), Net.Statistics[st]]);

    if Net.CmdRecvStatistics.Num > 0 then
      begin
        Net.CmdRecvStatistics.Critical__.Lock;
        try
          with Net.CmdRecvStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + '%s (received cmd) = %d (Num)', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdRecvStatistics.Critical__.UnLock;
        end
      end;

    if Net.CmdSendStatistics.Num > 0 then
      begin
        Net.CmdSendStatistics.Critical__.Lock;
        try
          with Net.CmdSendStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + '%s (send cmd) = %d (Num)', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdSendStatistics.Critical__.UnLock;
        end
      end;
  end;

begin
  Lock;
  try
    if Num > 0 then
      begin
        with Repeat_ do
          repeat
            if Queue^.data is TZNet_Server then
              begin
                DoStatus('%s <%s> connected:%d, PPS:%f, PCPU:%dms, statistics:',
                  [Queue^.data.ClassName, Queue^.data.name, Queue^.data.IOPool.Num, Queue^.data.Progress_CPS.CPS, Queue^.data.Progress_CPS.CPU_Time]);
                do_print_statistics_info(#9, Queue^.data);
              end;
          until not Next;
      end;
  finally
      UnLock;
  end;
end;

procedure TZNet_Instance_Pool.Print_Service_CMD_Info;
  procedure do_print_cmd_info(prefix_: SystemString; Net: TZNet);
  begin
    if Net.CmdMaxExecuteConsumeStatistics.Num > 0 then
      begin
        Net.CmdMaxExecuteConsumeStatistics.Critical__.Lock;
        try
          with Net.CmdMaxExecuteConsumeStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + 'received cmd "%s": time %dms', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdMaxExecuteConsumeStatistics.Critical__.UnLock;
        end;
      end;
    if Net.CmdSendStatistics.Num > 0 then
      begin
        Net.CmdSendStatistics.Critical__.Lock;
        try
          with Net.CmdSendStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + 'send cmd "%s" =%d', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdSendStatistics.Critical__.UnLock;
        end;
      end;
  end;

begin
  Lock;
  try
    if Num > 0 then
      begin
        with Repeat_ do
          repeat
            if Queue^.data is TZNet_Server then
              begin
                DoStatus('%s <%s> connected: %d', [Queue^.data.ClassName, Queue^.data.name, Queue^.data.IOPool.Num]);
                do_print_cmd_info(#9, Queue^.data);
              end;
          until not Next;
      end;
  finally
      UnLock;
  end;
end;

procedure TZNet_Instance_Pool.Print_Client_Statistics_Info;
  procedure do_print_statistics_info(prefix_: SystemString; Net: TZNet);
  var
    st: TStatisticsType;
  begin
    for st := low(TStatisticsType) to high(TStatisticsType) do
        DoStatus(prefix_ + '%s (state) = %d (Num)', [GetEnumName(TypeInfo(TStatisticsType), Ord(st)), Net.Statistics[st]]);

    if Net.CmdRecvStatistics.Num > 0 then
      begin
        Net.CmdRecvStatistics.Critical__.Lock;
        try
          with Net.CmdRecvStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + '%s (received cmd) = %d (Num)', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdRecvStatistics.Critical__.UnLock;
        end
      end;

    if Net.CmdSendStatistics.Num > 0 then
      begin
        Net.CmdSendStatistics.Critical__.Lock;
        try
          with Net.CmdSendStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + '%s (send cmd) = %d (Num)', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdSendStatistics.Critical__.UnLock;
        end
      end;
  end;

var
  addr: SystemString;
begin
  Lock;
  try
    if Num > 0 then
      begin
        with Repeat_ do
          repeat
            if Queue^.data is TZNet_Client then
              begin
                if (TZNet_Client(Queue^.data).ClientIO <> nil) and (TZNet_Client(Queue^.data).Connected) then
                    addr := TZNet_Client(Queue^.data).ClientIO.GetPeerIP
                else
                    addr := '';
                DoStatus('%s <%s> connected:"%s", PPS:%f, PCPU:%dms, statistics:',
                  [Queue^.data.ClassName, Queue^.data.name, addr, Queue^.data.Progress_CPS.CPS, Queue^.data.Progress_CPS.CPU_Time]);
                do_print_statistics_info(#9, Queue^.data);
              end;
          until not Next;
      end;
  finally
      UnLock;
  end;
end;

procedure TZNet_Instance_Pool.Print_Client_CMD_Info;
  procedure do_print_cmd_info(prefix_: SystemString; Net: TZNet);
  begin
    if Net.CmdMaxExecuteConsumeStatistics.Num > 0 then
      begin
        Net.CmdMaxExecuteConsumeStatistics.Critical__.Lock;
        try
          with Net.CmdMaxExecuteConsumeStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + '"%s": time %dms', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdMaxExecuteConsumeStatistics.Critical__.UnLock;
        end;
      end;
    if Net.CmdSendStatistics.Num > 0 then
      begin
        Net.CmdSendStatistics.Critical__.Lock;
        try
          with Net.CmdSendStatistics.Repeat_ do
            repeat
                DoStatus(prefix_ + 'send cmd "%s" =%d', [Queue^.data^.data.Primary, Queue^.data^.data.Second]);
            until not Next;
        finally
            Net.CmdSendStatistics.Critical__.UnLock;
        end;
      end;
  end;

var
  addr: SystemString;
begin
  Lock;
  try
    if Num > 0 then
      begin
        with Repeat_ do
          repeat
            if Queue^.data is TZNet_Client then
              begin
                if (TZNet_Client(Queue^.data).ClientIO <> nil) and (TZNet_Client(Queue^.data).Connected) then
                    addr := TZNet_Client(Queue^.data).ClientIO.GetPeerIP
                else
                    addr := '';
                DoStatus('%s <%s> connected: "%s"', [Queue^.data.ClassName, Queue^.data.name, addr]);
                do_print_cmd_info(#9, Queue^.data);
              end;
          until not Next;
      end;
  finally
      UnLock;
  end;
end;

procedure TCommand_Tick_Hash_Pool.SetMax(Key_: SystemString; Value_: TTimeTick);
var
  p: TCommand_Tick_Hash_Pool.PValue;
begin
  p := Get_Or_Create_Value_Ptr(Key_, 0);
  if Value_ > p^ then
      p^ := Value_;
end;

procedure TCommand_Tick_Hash_Pool.SetMax(Source: TCommand_Tick_Hash_Pool);
var
  __repeat__: TCommand_Tick_Hash_Pool.TRepeat___;
begin
  if Source.Num <= 0 then
      exit;
  __repeat__ := Source.Repeat_;
  repeat
      SetMax(__repeat__.Queue^.data^.data.Primary, __repeat__.Queue^.data^.data.Second);
  until not __repeat__.Next;
end;

procedure TCommand_Tick_Hash_Pool.GetKeyList(output: TPascalStringList);
var
  __repeat__: TCommand_Tick_Hash_Pool.TRepeat___;
begin
  if Num <= 0 then
      exit;
  __repeat__ := Repeat_;
  repeat
      output.Add(__repeat__.Queue^.data^.data.Primary);
  until not __repeat__.Next;
end;

procedure TCommand_Num_Hash_Pool.IncValue(Key_: SystemString; Value_: Integer);
var
  p: TCommand_Num_Hash_Pool.PValue;
begin
  p := Get_Or_Create_Value_Ptr(Key_, 0);
  inc(p^, Value_);
end;

procedure TCommand_Num_Hash_Pool.IncValue(Source: TCommand_Num_Hash_Pool);
var
  __repeat__: TCommand_Num_Hash_Pool.TRepeat___;
begin
  if Source.Num <= 0 then
      exit;
  __repeat__ := Source.Repeat_;
  repeat
      IncValue(__repeat__.Queue^.data^.data.Primary, __repeat__.Queue^.data^.data.Second);
  until not __repeat__.Next;
end;

procedure TCommand_Num_Hash_Pool.GetKeyList(output: TPascalStringList);
var
  __repeat__: TCommand_Num_Hash_Pool.TRepeat___;
begin
  if Num <= 0 then
      exit;
  __repeat__ := Repeat_;
  repeat
      output.Add(__repeat__.Queue^.data^.data.Primary);
  until not __repeat__.Next;
end;

procedure TCommand_Hash_Pool.DoFree(var Key: SystemString; var Value: TCommand_base);
begin
  DisposeObjectAndNil(Value);
  inherited DoFree(Key, Value);
end;

procedure TZNet.DoPrint(const v: SystemString);
var
  n1, n2: SystemString;
begin
  if not FQuietMode then
    begin
      if FPrefixName <> '' then
          n1 := FPrefixName
      else
          n1 := '';
      if FName <> '' then
        begin
          if n1 <> '' then
              n1 := n1 + '.';
          n2 := FName + ' ';
        end
      else
          n2 := '';
      DoStatus(n1 + n2 + v, ZNet_Def_DoStatusID);
    end;
end;

procedure TZNet.DoError(const v: SystemString);
var
  n1, n2: SystemString;
begin
  if FPrefixName <> '' then
      n1 := FPrefixName
  else
      n1 := '';
  if FName <> '' then
    begin
      if n1 <> '' then
          n1 := n1 + '.';
      n2 := FName + ' ';
    end
  else
      n2 := '';
  DoStatus(n1 + n2 + v, ZNet_Def_DoStatusID);
end;

procedure TZNet.DoWarning(const v: SystemString);
var
  n1, n2: SystemString;
begin
  if FPrefixName <> '' then
      n1 := FPrefixName
  else
      n1 := '';
  if FName <> '' then
    begin
      if n1 <> '' then
          n1 := n1 + '.';
      n2 := FName + ' ';
    end
  else
      n2 := '';
  DoStatus(n1 + n2 + v, ZNet_Def_DoStatusID);
end;

function TZNet.GetIdleTimeOut: TTimeTick;
begin
  Result := FIdleTimeOut;
end;

procedure TZNet.SetIdleTimeOut(const Value: TTimeTick);
begin
  FIdleTimeOut := Value;
end;

function TZNet.CanExecuteCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean;
begin
  Result := True;
  if Assigned(FOnExecuteCommand) then
    begin
      try
          FOnExecuteCommand(Sender, Cmd, Result);
      except
      end;
    end;
  if Result then
      AtomInc(Statistics[TStatisticsType.stCommandExecute_Sum]);
end;

function TZNet.CanSendCommand(Sender: TPeerIO; const Cmd: SystemString): Boolean;
begin
  Result := True;
  if Assigned(FOnSendCommand) then
    begin
      try
          FOnSendCommand(Sender, Cmd, Result);
      except
      end;
    end;
  if Result then
      AtomInc(Statistics[TStatisticsType.stCommand_Send_Sum]);
end;

function TZNet.CanRegCommand(Sender: TZNet; const Cmd: SystemString): Boolean;
begin
  Result := True;
  AtomInc(Statistics[TStatisticsType.stCommand_Reg_Sum]);
end;

procedure TZNet.DelayClose(Sender: TN_Post_Execute);
var
  IO_ID: Cardinal;
  c_IO: TPeerIO;
begin
  IO_ID := Sender.Data3;
  c_IO := FPeerIO_HashPool[IO_ID];
  if c_IO <> nil then
    begin
      c_IO.Disconnect;
    end;
end;

procedure TZNet.DelayFree(Sender: TN_Post_Execute);
var
  IO_ID: Cardinal;
  c_IO: TPeerIO;
begin
  IO_ID := Sender.Data3;
  c_IO := FPeerIO_HashPool[IO_ID];
  if c_IO <> nil then
      DisposeObject(c_IO);
end;

procedure TZNet.DelayExecuteOnResultState(Sender: TN_Post_Execute);
var
  P_IO: TPeerIO;
  nQueue: PQueueData;
begin
  P_IO := FPeerIO_HashPool[Sender.Data4];
  nQueue := PQueueData(Sender.Data5);

  if P_IO <> nil then
    begin
      DoExecuteResult(P_IO, nQueue, Sender.Data3, Sender.DataEng);
    end;

  DisposeQueueData(nQueue);
end;

procedure TZNet.DelayExecuteOnCompleteBufferState(Sender: TN_Post_Execute);
var
  P_IO: TPeerIO;
  Cmd: SystemString;
  CompleteBuff: TMS64;
begin
  P_IO := FPeerIO_HashPool[Sender.Data3];
  Cmd := Sender.Data4;

  if P_IO <> nil then
    begin
      CompleteBuff := TMS64(Sender.Data1);
      if not QuietMode then
          P_IO.PrintCommand('execute complete buffer(delay): %s', Cmd);

      P_IO.FCompleteBuffer_Current_Trigger := CompleteBuff;
      ExecuteCompleteBuffer(P_IO, Cmd, CompleteBuff.Memory, CompleteBuff.Size);
      DisposeObject(CompleteBuff);

      CmdRecvStatistics.IncValue(Cmd, 1);
    end;
end;

procedure TZNet.IDLE_Trace_Execute(Sender: TN_Post_Execute);
var
  p: PIDLE_Trace;
  p_id: Cardinal;
  P_IO: TPeerIO;
begin
  p := Sender.Data5;
  p_id := p^.ID;

  P_IO := FPeerIO_HashPool[p_id];

  if P_IO <> nil then
    begin
      if P_IO.IOBusy then
        begin
          with ProgressEngine.PostExecuteM(False, 0.1, IDLE_Trace_Execute) do
            begin
              Data4 := p_id;
              Data5 := p;
              Ready();
            end;
        end
      else
        begin
          if Assigned(p^.OnNotifyC) then
              p^.OnNotifyC(p^.data)
          else if Assigned(p^.OnNotifyM) then
              p^.OnNotifyM(p^.data)
          else if Assigned(p^.OnNotifyP) then
              p^.OnNotifyP(p^.data);
          Dispose(p);
        end;
    end
  else
    begin
      Dispose(p);
    end;
end;

procedure TZNet.cmd_Complete_Buffer_Stream_Reponse(Sender: TPeerIO; InData: PByte; DataSize: NativeInt);
var
  u64: UInt64;
  p: PCommandCompleteBuffer_NoWait_Stream_Data;
  In_DFE: TDFE;
  P_IO: TPeerIO;
begin
  u64 := PUInt64(InData)^;
  p := PCommandCompleteBuffer_NoWait_Stream_Data(u64);
  P_IO := FPeerIO_HashPool[p^.ID];

  if P_IO <> nil then
    begin
      In_DFE := TDFE.Create;
      In_DFE.DecodeFromMemory(GetOffset(InData, 8), DataSize - 8, True);
      try
        if Assigned(p^.OnStreamM) then
            p^.OnStreamM(P_IO, In_DFE)
        else if Assigned(p^.OnStreamP) then
            p^.OnStreamP(P_IO, In_DFE);
      except
      end;
      DisposeObject(In_DFE);
    end;

  Dispose(p);
end;

function TZNet.MakeID: Cardinal;
begin
  repeat
    Result := FIDSeed;
    AtomInc(FIDSeed);
  until not FPeerIO_HashPool.Exists_Key(Result);
end;

procedure TZNet.FillCustomBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
begin
end;

procedure TZNet.Framework_Internal_Send_Byte_Buffer(const Sender: TPeerIO; const buff: PByte; siz: NativeInt);
var
  p: PByte;
begin
  if siz <= 0 then
      exit;

  AtomInc(Statistics[TStatisticsType.stSendSize], siz);

  p := buff;

  { fill fragment }
  while siz > FSendFlushSize do
    begin
      Sender.Write_IO_Buffer(p, FSendFlushSize);
      inc(p, FSendFlushSize);
      dec(siz, FSendFlushSize);
    end;

  if siz > 0 then
    begin
      Sender.Write_IO_Buffer(p, siz);
    end;

  Sender.UpdateLastCommunicationTime;
  Sender.LastCommunicationTick_Sending := Sender.FLastCommunicationTick;
end;

procedure TZNet.Framework_Internal_Save_Receive_Buffer(const Sender: TPeerIO; const buff: Pointer; siz: Int64);
begin
  if siz > 0 then
    begin
      Sender.Internal_Save_Receive_Buffer(buff, siz);
    end;
end;

procedure TZNet.Framework_Internal_Process_Receive_Buffer(const Sender: TPeerIO);
var
  FillDone: Boolean;
begin
  if FProtocol = cpCustom then
    begin
      if Sender.FReceivedBuffer.Size > 0 then
        begin
          FillDone := True;
          FillCustomBuffer(Sender, Sender.FReceivedBuffer.Memory, Sender.FReceivedBuffer.Size, FillDone);

          if FillDone then
              Sender.FReceivedBuffer.Clear
          else
              Sender.Internal_Process_Receive_Buffer();
        end;
    end
  else
      Sender.Internal_Process_Receive_Buffer();
end;

procedure TZNet.Framework_Internal_Process_Send_Buffer(const Sender: TPeerIO);
begin
  Sender.Internal_Process_Send_Buffer();
end;

procedure TZNet.Framework_Internal_IO_Create(const Sender: TPeerIO);
begin
  if FIOInterface <> nil then
      FIOInterface.PeerIO_Create(Sender);
end;

procedure TZNet.Framework_Internal_IO_Destroy(const Sender: TPeerIO);
begin
  if FIOInterface <> nil then
      FIOInterface.PeerIO_Destroy(Sender);
end;

procedure TZNet.Build_P2PAuth_Token_Result_On_IO_IDLE(Sender: TCore_Object);
var
  P_IO: TPeerIO;
begin
  P_IO := TPeerIO(Sender);

  try
    if Assigned(P_IO.OnVMBuildAuthModelResult_C) then
        P_IO.OnVMBuildAuthModelResult_C()
    else if Assigned(P_IO.OnVMBuildAuthModelResult_M) then
        P_IO.OnVMBuildAuthModelResult_M()
    else if Assigned(P_IO.OnVMBuildAuthModelResult_P) then
        P_IO.OnVMBuildAuthModelResult_P()
    else if Assigned(P_IO.OnVMBuildAuthModelResultIO_C) then
        P_IO.OnVMBuildAuthModelResultIO_C(P_IO)
    else if Assigned(P_IO.OnVMBuildAuthModelResultIO_M) then
        P_IO.OnVMBuildAuthModelResultIO_M(P_IO)
    else if Assigned(P_IO.OnVMBuildAuthModelResultIO_P) then
        P_IO.OnVMBuildAuthModelResultIO_P(P_IO);
  except
  end;

  P_IO.OnVMBuildAuthModelResult_C := nil;
  P_IO.OnVMBuildAuthModelResult_M := nil;
  P_IO.OnVMBuildAuthModelResult_P := nil;
  P_IO.OnVMBuildAuthModelResultIO_C := nil;
  P_IO.OnVMBuildAuthModelResultIO_M := nil;
  P_IO.OnVMBuildAuthModelResultIO_P := nil;
end;

procedure TZNet.Do_CMD_Result_BuildP2PAuthToken(Sender: TPeerIO; Result_: TDFE);
var
  i: Integer;
  arr32: TDF_ArrayInteger;
  CS: TCipherSecurity;
  arr8: TDF_ArrayByte;
begin
  { read auth buffer }
  arr32 := Result_.R.ReadArrayInteger;
  SetLength(Sender.FP2PVM_Auth_Token, arr32.Count * 4);
  for i := 0 to arr32.Count - 1 do
      PInteger(@Sender.FP2PVM_Auth_Token[i * 4])^ := arr32[i];

  { read p2pVM cipher style }
  CS := TCipherSecurity(Result_.R.ReadByte);

  { read p2pVM cipher key }
  arr8 := Result_.R.ReadArrayByte;
  SetLength(Sender.FP2PVM_Cipher_Key, arr8.Count);
  arr8.GetBuff(@Sender.FP2PVM_Cipher_Key[0]);

  { build p2pVM cipher instance }
  Sender.FP2PVM_Cipher := CreateCipherClassFromBuffer(CS, Sender.FP2PVM_Cipher_Key);

  Sender.IO_IDLE_TraceM(Sender, Build_P2PAuth_Token_Result_On_IO_IDLE);
end;

procedure TZNet.CMD_BuildP2PAuthToken(Sender: TPeerIO; InData, OutData: TDFE);
var
  i: Integer;
  seed: Integer;
  arry32: TDF_ArrayInteger;
  CS: TCipherSecurity;
begin
  Sender.ResetSequencePacketBuffer;
  Sender.FSequencePacketSignal := False;

  { build auth buffer }
  seed := InData.Reader.ReadInteger;
  arry32 := OutData.WriteArrayInteger;
  for i := ZNet_Def_VMAuthSize - 1 downto 0 do
      arry32.Add(TMISC.Ran03(seed));
  SetLength(Sender.FP2PVM_Auth_Token, arry32.Count * 4);
  for i := 0 to arry32.Count - 1 do
      PInteger(@Sender.FP2PVM_Auth_Token[i * 4])^ := arry32[i];

  { build p2pVM cipher style }
  if FEncrypt_P2PVM_Packet then
      CS := TCipher.Random_Select_Cipher([csRC6, csSerpent, csMars, csRijndael, csTwoFish, csAES128])
  else
      CS := csNone;
  OutData.WriteByte(Byte(CS));

  { build p2pVM cipher key }
  SetLength(Sender.FP2PVM_Cipher_Key, 256);
  TMT19937.Rand32(MaxInt, @Sender.FP2PVM_Cipher_Key[0], 256 div 4);
  OutData.WriteArrayByte.SetBuff(@Sender.FP2PVM_Cipher_Key[0], 256);

  { build p2pVM cipher instance }
  Sender.FP2PVM_Cipher := CreateCipherClassFromBuffer(CS, Sender.FP2PVM_Cipher_Key);
end;

procedure TZNet.CMD_InitP2PTunnel(Sender: TPeerIO; InData: SystemString);
var
  Accept: Boolean;
begin
  if Sender.FP2PVMTunnel <> nil then
      exit;

  Accept := False;
  p2pVMTunnelAuth(Sender, InData, Accept);
  if not Accept then
      exit;

  Sender.ResetSequencePacketBuffer;
  Sender.FSequencePacketSignal := False;

  Sender.OpenP2PVMTunnel(16, False, '');
  Sender.P2PVMTunnel.AuthVM;
  p2pVMTunnelOpenBefore(Sender, Sender.P2PVMTunnel);
end;

procedure TZNet.CMD_CloseP2PTunnel(Sender: TPeerIO; InData: SystemString);
begin
  Sender.Internal_Close_P2PVMTunnel;
  Sender.ResetSequencePacketBuffer;
end;

procedure TZNet.VMAuthSuccessAfterDelayExecute(Sender: TN_Post_Execute);
var
  P_IO: TPeerIO;
begin
  P_IO := FPeerIO_HashPool[Sender.Data3];
  if P_IO = nil then
      exit;

  try
    if Assigned(P_IO.OnVMAuthResult_C) then
        P_IO.OnVMAuthResult_C(True)
    else if Assigned(P_IO.OnVMAuthResult_M) then
        P_IO.OnVMAuthResult_M(True)
    else if Assigned(P_IO.OnVMAuthResult_P) then
        P_IO.OnVMAuthResult_P(True)
    else if Assigned(P_IO.OnVMAuthResultIO_C) then
        P_IO.OnVMAuthResultIO_C(P_IO, True)
    else if Assigned(P_IO.OnVMAuthResultIO_M) then
        P_IO.OnVMAuthResultIO_M(P_IO, True)
    else if Assigned(P_IO.OnVMAuthResultIO_P) then
        P_IO.OnVMAuthResultIO_P(P_IO, True);
  except
  end;

  P_IO.OnVMAuthResult_C := nil;
  P_IO.OnVMAuthResult_M := nil;
  P_IO.OnVMAuthResult_P := nil;
  P_IO.OnVMAuthResultIO_C := nil;
  P_IO.OnVMAuthResultIO_M := nil;
  P_IO.OnVMAuthResultIO_P := nil;
  p2pVMTunnelOpenAfter(P_IO, P_IO.P2PVMTunnel);
end;

procedure TZNet.VMAuthSuccessDelayExecute(Sender: TN_Post_Execute);
var
  P_IO: TPeerIO;
begin
  P_IO := FPeerIO_HashPool[Sender.Data3];
  if P_IO = nil then
      exit;

  with ProgressPost.PostExecuteM(False, 0.5, VMAuthSuccessAfterDelayExecute) do
    begin
      Data3 := P_IO.FID;
      Ready();
    end;
  p2pVMTunnelOpen(P_IO, P_IO.P2PVMTunnel);
end;

procedure TZNet.VMAuthFailedDelayExecute(Sender: TN_Post_Execute);
var
  P_IO: TPeerIO;
begin
  P_IO := FPeerIO_HashPool[Sender.Data3];
  if P_IO = nil then
      exit;

  try
    if Assigned(P_IO.OnVMAuthResult_C) then
        P_IO.OnVMAuthResult_C(False)
    else if Assigned(P_IO.OnVMAuthResult_M) then
        P_IO.OnVMAuthResult_M(False)
    else if Assigned(P_IO.OnVMAuthResult_P) then
        P_IO.OnVMAuthResult_P(False)
    else if Assigned(P_IO.OnVMAuthResultIO_C) then
        P_IO.OnVMAuthResultIO_C(P_IO, False)
    else if Assigned(P_IO.OnVMAuthResultIO_M) then
        P_IO.OnVMAuthResultIO_M(P_IO, False)
    else if Assigned(P_IO.OnVMAuthResultIO_P) then
        P_IO.OnVMAuthResultIO_P(P_IO, False);
  except
  end;

  P_IO.OnVMAuthResult_C := nil;
  P_IO.OnVMAuthResult_M := nil;
  P_IO.OnVMAuthResult_P := nil;
  P_IO.OnVMAuthResultIO_C := nil;
  P_IO.OnVMAuthResultIO_M := nil;
  P_IO.OnVMAuthResultIO_P := nil;
end;

procedure TZNet.CMD_NULL(Sender: TPeerIO; InData: SystemString; var OutData: SystemString);
begin
end;

function TZNet.ExecuteConsole(Sender: TPeerIO; const Cmd: SystemString; const InData: SystemString; var OutData: SystemString): Boolean;
var
  cmd_instance_: TCommand_base;
begin
  Result := False;
  if not CanExecuteCommand(Sender, Cmd) then
      exit;
  cmd_instance_ := FCommand_Hash_Pool[Cmd];
  if cmd_instance_ = nil then
    begin
      ErrorParam('no exists console cmd: %s', Cmd);
      exit;
    end;
  if not cmd_instance_.InheritsFrom(TCommandConsole) then
    begin
      if cmd_instance_.InheritsFrom(TCommandConsoleNotify) then // compatible fixed, by.qq600585
        begin
          Result := TCommandConsoleNotify(cmd_instance_).Execute(Sender, InData);
          if not Result then
              ErrorParam('exception from cmd: %s', Cmd);
        end
      else ErrorParam('Illegal interface in cmd: %s', Cmd);
      exit;
    end;
  Result := TCommandConsole(cmd_instance_).Execute(Sender, InData, OutData);
  if not Result then
      ErrorParam('exception from cmd: %s', Cmd);
end;

function TZNet.ExecuteStream(Sender: TPeerIO; const Cmd: SystemString; InData, OutData: TDFE): Boolean;
var
  cmd_instance_: TCommand_base;
begin
  Result := False;
  if not CanExecuteCommand(Sender, Cmd) then
      exit;
  cmd_instance_ := FCommand_Hash_Pool[Cmd];
  if cmd_instance_ = nil then
    begin
      ErrorParam('no exists stream cmd: %s', Cmd);
      exit;
    end;
  if not cmd_instance_.InheritsFrom(TCommandStream) then
    begin
      ErrorParam('Illegal interface in cmd: %s', Cmd);
      exit;
    end;
  InData.Reader.index := 0;
  Result := TCommandStream(cmd_instance_).Execute(Sender, InData, OutData);
  if not Result then
      ErrorParam('exception from cmd: %s', Cmd);
end;

function TZNet.ExecuteStreamNotify(Sender: TPeerIO; const Cmd: SystemString; InData: TDFE): Boolean;
var
  cmd_instance_: TCommand_base;
begin
  Result := False;
  if not CanExecuteCommand(Sender, Cmd) then
      exit;
  cmd_instance_ := FCommand_Hash_Pool[Cmd];
  if cmd_instance_ = nil then
    begin
      ErrorParam('no exists direct stream cmd: %s', Cmd);
      exit;
    end;
  if not cmd_instance_.InheritsFrom(TCommandStreamNotify) then
    begin
      ErrorParam('Illegal interface in cmd: %s', Cmd);
      exit;
    end;
  InData.Reader.index := 0;
  Result := TCommandStreamNotify(cmd_instance_).Execute(Sender, InData);
  if not Result then
      ErrorParam('exception from cmd: %s', Cmd);
end;

function TZNet.ExecuteConsoleNotify(Sender: TPeerIO; const Cmd: SystemString; const InData: SystemString): Boolean;
var
  cmd_instance_: TCommand_base;
  tmp: SystemString;
begin
  Result := False;
  if not CanExecuteCommand(Sender, Cmd) then
      exit;
  cmd_instance_ := FCommand_Hash_Pool[Cmd];
  if cmd_instance_ = nil then
    begin
      ErrorParam('no exists direct console cmd: %s', Cmd);
      exit;
    end;
  if not cmd_instance_.InheritsFrom(TCommandConsoleNotify) then
    begin
      if cmd_instance_.InheritsFrom(TCommandConsole) then // compatible fixed, by.qq600585
        begin
          tmp := '';
          Result := TCommandConsole(cmd_instance_).Execute(Sender, InData, tmp);
          if not Result then
              ErrorParam('exception from cmd: %s', Cmd);
        end
      else ErrorParam('Illegal interface in cmd: %s', Cmd);
      exit;
    end;
  Result := TCommandConsoleNotify(cmd_instance_).Execute(Sender, InData);
  if not Result then
      ErrorParam('exception from cmd: %s', Cmd);
end;

function TZNet.ExecuteBigStream(Sender: TPeerIO; const Cmd: SystemString; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64): Boolean;
var
  cmd_instance_: TCommand_base;
begin
  Result := False;
  if not CanExecuteCommand(Sender, Cmd) then
      exit;
  cmd_instance_ := FCommand_Hash_Pool[Cmd];
  if cmd_instance_ = nil then
    begin
      ErrorParam('no exists Big Stream cmd: %s', Cmd);
      exit;
    end;
  if not cmd_instance_.InheritsFrom(TCommandBigStream) then
    begin
      ErrorParam('Illegal interface in cmd: %s', Cmd);
      exit;
    end;
  Result := TCommandBigStream(cmd_instance_).Execute(Sender, InData, BigStreamTotal, BigStreamCompleteSize);
  if not Result then
      ErrorParam('exception from cmd: %s', Cmd);
end;

function TZNet.ExecuteCompleteBuffer(Sender: TPeerIO; const Cmd: SystemString; InData: PByte; DataSize: NativeInt): Boolean;
var
  cmd_instance_: TCommand_base;
  tmp: TDFE;
begin
  Result := False;
  if not CanExecuteCommand(Sender, Cmd) then
      exit;
  cmd_instance_ := FCommand_Hash_Pool[Cmd];
  if cmd_instance_ = nil then
    begin
      ErrorParam('no exists complete buffer cmd: %s', Cmd);
      exit;
    end;
  if cmd_instance_.InheritsFrom(TCommandCompleteBuffer) then
    begin
      Result := TCommandCompleteBuffer(cmd_instance_).Execute(Sender, InData, DataSize);
      if not Result then
          ErrorParam('exception from cmd: %s', Cmd);
    end
  else if cmd_instance_.InheritsFrom(TCommandCompleteBuffer_StreamNotify) then
    begin
      Result := TCommandCompleteBuffer_StreamNotify(cmd_instance_).Execute(Sender, InData, DataSize);
      if not Result then
          ErrorParam('exception from cmd: %s', Cmd);
    end
  else if cmd_instance_.InheritsFrom(TCommandCompleteBuffer_NoWait_Stream) then
    begin
      Result := TCommandCompleteBuffer_NoWait_Stream(cmd_instance_).Execute(Sender, InData, DataSize);
      if not Result then
          ErrorParam('exception from cmd: %s', Cmd);
    end
  else if cmd_instance_.InheritsFrom(TCommandCompleteBuffer_NoWait_Bridge_Stream) then
    begin
      Result := TCommandCompleteBuffer_NoWait_Bridge_Stream(cmd_instance_).Execute(Sender, InData, DataSize);
      if not Result then
          ErrorParam('exception from cmd: %s', Cmd);
    end
  else if cmd_instance_.InheritsFrom(TCommandStreamNotify) then
    begin
      tmp := TDFE.Create;
      try
        tmp.DecodeFromMemory(InData, DataSize, True);
        Result := TCommandStreamNotify(cmd_instance_).Execute(Sender, tmp);
      except
          Result := False;
      end;
      DisposeObject(tmp);
      if not Result then
          ErrorParam('exception from cmd: %s', Cmd);
    end
  else if cmd_instance_.InheritsFrom(TCommandStream) then
    begin
      Result := TCommandStream(cmd_instance_).Execute_Complete_Stream(Sender, InData, DataSize);
      if not Result then
          ErrorParam('exception from cmd: %s', Cmd);
    end
  else
      ErrorParam('Illegal interface in cmd: %s', Cmd);
end;

procedure TZNet.InitAutomatedP2PVM;
begin
  FAutomatedP2PVMServiceBind := TAutomatedP2PVMServiceBind.Create;
  FAutomatedP2PVMService := True;
  FAutomatedP2PVMClientBind := TAutomatedP2PVMClientBind.Create;
  FAutomatedP2PVMClient := True;
  FAutomatedP2PVMClientDelayBoot := 0.5;
  FAutomatedP2PVMAuthToken := 'AutomatedP2PVM for ZServer';
  FOnAutomatedP2PVMClientConnectionDone_C := nil;
  FOnAutomatedP2PVMClientConnectionDone_M := nil;
  FOnAutomatedP2PVMClientConnectionDone_P := nil;
end;

procedure TZNet.FreeAutomatedP2PVM;
begin
  FAutomatedP2PVMServiceBind.Clean;
  DisposeObject(FAutomatedP2PVMServiceBind);
  FAutomatedP2PVMClientBind.Clean;
  DisposeObject(FAutomatedP2PVMClientBind);
end;

procedure TZNet.DoAutomatedP2PVMClient_DelayRequest(Sender: TN_Post_Execute);
var
  IO_ID: Cardinal;
begin
  IO_ID := Sender.Data3;
  DoAutomatedP2PVMClient_Request(IO_ID);
end;

procedure TZNet.DoAutomatedP2PVMClient_Request(IO_ID: Cardinal);
var
  P_IO: TPeerIO;
begin
  P_IO := FPeerIO_HashPool[IO_ID];
  if P_IO = nil then
    begin
      Error('AutomatedP2PVMClient_Request request fialed: loss IO');
      exit;
    end;
  if P_IO.OwnerFramework <> self then
      RaiseInfo('illegal.');

  if FAutomatedP2PVMClient then
    begin
      if P_IO.p2pVMTunnelReadyOk then
          AutomatedP2PVMClient_OpenP2PVMTunnelResult(P_IO, True)
      else
          P_IO.BuildP2PAuthTokenIO_M(AutomatedP2PVMClient_BuildP2PAuthTokenResult);
    end
  else
      Error('AutomatedP2PVMClient is false, on do AutomatedP2PVMClient_Request dont work.');
end;

procedure TZNet.AutomatedP2PVMClient_BuildP2PAuthTokenResult(P_IO: TPeerIO);
begin
  if P_IO <> nil then
      P_IO.OpenP2PVMTunnelIO_M(True, GenerateQuantumCryptographyPassword(FAutomatedP2PVMAuthToken), AutomatedP2PVMClient_OpenP2PVMTunnelResult);
end;

procedure TZNet.AutomatedP2PVMClient_OpenP2PVMTunnelResult(P_IO: TPeerIO; VMauthState: Boolean);
var
  p: PAutomatedP2PVMClientData;
  i: Integer;
  IsRequestConnecting_: Boolean;
begin
  if not VMauthState then
    begin
      Error('Automated P2PVM Auth failed!');
      if P_IO <> nil then
          P_IO.DelayClose(1.0);
      exit;
    end;

  for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
      P_IO.P2PVMTunnel.InstallLogicFramework(FAutomatedP2PVMClientBind[i]^.Client);

  for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
    begin
      p := FAutomatedP2PVMClientBind[i];
      if (not p^.Client.Connected) and (not p^.RequestConnecting) then
        begin
          p^.Client.AsyncConnectM(p^.IPV6, p^.Port, p, P_IO, AutomatedP2PVMClient_ConnectionResult);
          p^.RequestConnecting := True;
        end;
    end;

  { check all connection done. }
  IsRequestConnecting_ := False;
  for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
    begin
      p := FAutomatedP2PVMClientBind[i];
      if (p^.RequestConnecting) or (not p^.Client.Connected) then
          IsRequestConnecting_ := True;
    end;

  if not IsRequestConnecting_ then
      AutomatedP2PVMClient_Done(P_IO);
end;

procedure TZNet.AutomatedP2PVMClient_ConnectionResult(Param1: Pointer; Param2: TObject; const ConnectionState: Boolean);
var
  P_IO: TPeerIO;
  p: PAutomatedP2PVMClientData;
  i: Integer;
  IsRequestConnecting_: Boolean;
begin
  p := Param1;
  p^.RequestConnecting := False;
  if not ConnectionState then
    begin
      Error('Automated P2PVM connection failed.');
      exit;
    end;

  P_IO := TPeerIO(Param2);
  for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
    begin
      p := FAutomatedP2PVMClientBind[i];
      if (not p^.Client.Connected) and (not p^.RequestConnecting) then
        begin
          p^.Client.AsyncConnectM(p^.IPV6, p^.Port, p, P_IO, AutomatedP2PVMClient_ConnectionResult);
          p^.RequestConnecting := True;
        end;
    end;

  { check all connection done. }
  IsRequestConnecting_ := False;
  for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
    begin
      p := FAutomatedP2PVMClientBind[i];
      if (p^.RequestConnecting) or (not p^.Client.Connected) then
          IsRequestConnecting_ := True;
    end;

  if not IsRequestConnecting_ then
      AutomatedP2PVMClient_Done(P_IO);
end;

procedure TZNet.AutomatedP2PVMClient_Delay_Done(Sender: TN_Post_Execute);
var
  P_IO: TPeerIO;
begin
  P_IO := FPeerIO_HashPool[Sender.Data3];
  if P_IO = nil then
    begin
      PrintError('Async Loss IO.');
      exit;
    end;

  if not QuietMode then
      Print('Automated P2PVM client connection done.');
  try
    if Assigned(FOnAutomatedP2PVMClientConnectionDone_C) then
        FOnAutomatedP2PVMClientConnectionDone_C(self, P_IO)
    else if Assigned(FOnAutomatedP2PVMClientConnectionDone_M) then
        FOnAutomatedP2PVMClientConnectionDone_M(self, P_IO)
    else if Assigned(FOnAutomatedP2PVMClientConnectionDone_P) then
        FOnAutomatedP2PVMClientConnectionDone_P(self, P_IO);
  except
  end;
  FOnAutomatedP2PVMClientConnectionDone_C := nil;
  FOnAutomatedP2PVMClientConnectionDone_M := nil;
  FOnAutomatedP2PVMClientConnectionDone_P := nil;

  try
    if Assigned(P_IO.FOnAutomatedP2PVMClientConnectionDone_C) then
        P_IO.FOnAutomatedP2PVMClientConnectionDone_C(P_IO, AutomatedP2PVMClientConnectionDone(P_IO))
    else if Assigned(P_IO.FOnAutomatedP2PVMClientConnectionDone_M) then
        P_IO.FOnAutomatedP2PVMClientConnectionDone_M(P_IO, AutomatedP2PVMClientConnectionDone(P_IO))
    else if Assigned(P_IO.FOnAutomatedP2PVMClientConnectionDone_P) then
        P_IO.FOnAutomatedP2PVMClientConnectionDone_P(P_IO, AutomatedP2PVMClientConnectionDone(P_IO));
  except
  end;

  P_IO.FOnAutomatedP2PVMClientConnectionDone_C := nil;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_M := nil;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_P := nil;
end;

procedure TZNet.AutomatedP2PVMClient_Done(P_IO: TPeerIO);
begin
  with FPostProgress.PostExecuteM(False, 0, AutomatedP2PVMClient_Delay_Done) do
    begin
      Data3 := P_IO.ID;
      Ready();
    end;
end;

procedure TZNet.InitLargeScaleIOPool;
begin
  FProgress_LargeScale_IO_Pool := TIO_Order.Create;
  FProgressMaxDelay := ZNet_Progress_Max_Delay;
end;

procedure TZNet.FreeLargeScaleIOPool;
begin
  DisposeObject(FProgress_LargeScale_IO_Pool);
end;

procedure TZNet.ProgressLargeScaleIOPool;
var
  tk: TTimeTick;
  P_IO: TPeerIO;
begin
  FSend_Queue_Swap_Pool.Lock;
  try
    if FPeerIO_HashPool.Num <= 0 then
      begin
        while FSend_Queue_Swap_Pool.Num > 0 do
          begin
            PrintError('loss send queue dest ip %s cmd %s', [FSend_Queue_Swap_Pool.First^.data^.IP, FSend_Queue_Swap_Pool.First^.data^.Cmd]);
            DisposeQueueData(FSend_Queue_Swap_Pool.First^.data);
            FSend_Queue_Swap_Pool.Next;
          end;
        exit;
      end;

    tk := GetTimeTick();
    if (FProgress_LargeScale_IO_Pool.Num <= 0) or (FProgressMaxDelay = 0) then
      begin
        { queue swap technology }
        while (FSend_Queue_Swap_Pool.Num > 0) do
          begin
            if self is TZNet_Client then
              begin
                if TZNet_Client(self).ClientIO <> nil then
                    TZNet_Client(self).ClientIO.PostQueueData(FSend_Queue_Swap_Pool.First^.data)
                else
                  begin
                    PrintError('loss send queue cmd %s', [FSend_Queue_Swap_Pool.First^.data^.Cmd]);
                    DisposeQueueData(FSend_Queue_Swap_Pool.First^.data);
                  end;
              end
            else if self is TZNet_Server then
              begin
                P_IO := FPeerIO_HashPool[FSend_Queue_Swap_Pool.First^.data^.IO_ID];
                if P_IO <> nil then
                    P_IO.PostQueueData(FSend_Queue_Swap_Pool.First^.data)
                else
                  begin
                    PrintError('loss send queue dest ip %s cmd %s', [FSend_Queue_Swap_Pool.First^.data^.IP, FSend_Queue_Swap_Pool.First^.data^.Cmd]);
                    DisposeQueueData(FSend_Queue_Swap_Pool.First^.data);
                  end;
              end
            else
              begin
                PrintError('illegal ZNet class: %s, loss send queue dest ip %s cmd %s', [ClassName, FSend_Queue_Swap_Pool.First^.data^.IP, FSend_Queue_Swap_Pool.First^.data^.Cmd]);
                DisposeQueueData(FSend_Queue_Swap_Pool.First^.data);
              end;
            FSend_Queue_Swap_Pool.Next;
          end;

        GetIO_Order(FProgress_LargeScale_IO_Pool);
      end;
  finally
      FSend_Queue_Swap_Pool.UnLock;
  end;

  while FProgress_LargeScale_IO_Pool.Num > 0 do
    begin
      P_IO := FPeerIO_HashPool[FProgress_LargeScale_IO_Pool.First^.data];
      FProgress_LargeScale_IO_Pool.Next;

      if P_IO <> nil then
        begin
          try
              P_IO.Progress;
          except
          end;
        end;

      if (FProgressMaxDelay > 0) and (GetTimeTick() - tk > FProgressMaxDelay) then
          Break;
    end;
end;

constructor TZNet.Create(HashPoolSize: Integer);
var
  st: TStatisticsType;
  tmp_uid: TUID___;
begin
  inherited Create;
  FCritical := TCritical.Create(ClassName + '.FCritical');
  FSend_Critical := TCritical.Create(ClassName + '.FSend_Critical');
  FZNet_Instance_Ptr__ := ZNet_Instance_Pool.Add(self);
  FCommand_Hash_Pool := TCommand_Hash_Pool.Create(1024, nil);
  FIDSeed := 1;
  FProgress_CPS.Reset;
  FPeerIO_HashPool := TPeer_IO_Hash_Pool.Create(HashPoolSize, nil);
  FProgress_Pool := TZNet_Progress_Pool.Create;
  FOnExecuteCommand := nil;
  FOnSendCommand := nil;
  FIdleTimeOut := 0;
  FFastEncrypt := True;
  FUsedParallelEncrypt := True;
  FSyncOnResult := True;
  FSyncOnCompleteBuffer := True;
  FBigStreamMemorySwapSpace := ZNet_Def_BigStream_Memory_SwapSpace_Activted;
  FBigStreamSwapSpaceTriggerSize := ZNet_Def_BigStream_SwapSpace_Trigger;

  FEnabledAtomicLockAndMultiThread := True;
  FTimeOutKeepAlive := True;
  FQuietMode := {$IFDEF Communication_QuietMode}True{$ELSE Communication_QuietMode}False{$ENDIF Communication_QuietMode};
  SetLength(FCipherSecurityArray, 0);
  FPhysicsFragmentSwapSpaceTechnology := ZNet_Def_Physics_Fragment_Cache_Activted;
  FPhysicsFragmentSwapSpaceTrigger := ZNet_Def_Physics_Fragment_Cache_Trigger;

  FSend_Queue_Swap_Pool := TQueueData_Pool.Create;
  FSend_Queue_Swap_Pool.Get_Critical__;
  FSendFlushSize := ZNet_Def_SendFlushSize;
  FSendDataCompressed := False;
  FCompleteBufferCompressed := False;
  FHashSecurity := THashSecurity.hsNone;
  FPer_Progress_Loop_Limit := ZNet_Def_Per_Progress_Loop_Limit;
  FExtract_Physics_Fragment_Max_Size := ZNet_Def_Extract_Physics_Fragment_Max_Size;
  FMaxCompleteBufferSize := ZNet_Def_MaxCompleteBufferSize;
  FCompleteBufferCompressionCondition := ZNet_Def_CompleteBufferCompressionCondition;
  FCompleteBufferSwapSpace := ZNet_Def_CompleteBuffer_SwapSpace_Activted;
  FCompleteBufferSwapSpaceTriggerSize := ZNet_Def_CompleteBuffer_SwapSpace_Trigger;
  FAutomaticWaitRemoteReponse := False;
{$IFDEF Encrypt_P2PVM_Packet}
  FEncrypt_P2PVM_Packet := True;
{$ELSE Encrypt_P2PVM_Packet}
  FEncrypt_P2PVM_Packet := False;
{$ENDIF Encrypt_P2PVM_Packet}
  FPeerIOUserDefineClass := TPeer_IO_User_Define;
  FPeerIOUserSpecialClass := TPeer_IO_User_Special;

  FPostProgress := TN_Progress_ToolWithCadencer.Create;

  FFrameworkIsServer := True;
  FFrameworkIsClient := True;
  FFrameworkInfo := ClassName;

  FProgressRuning := False;
  FProgressEnabled := True;
  FProgressWaitRuning := False;
  FOnProgress := nil;

  FCMD_Thread_Runing_Num := 0;

  FIOInterface := nil;
  FVMInterface := nil;
  FOnBigStreamInterface := nil;

  FProtocol := cpZServer;
  FSequencePacketActivted := {$IFDEF UsedSequencePacket}True{$ELSE UsedSequencePacket}False{$ENDIF UsedSequencePacket};

  FPrefixName := '';
  FName := '';

  tmp_uid := Generate_Global_UID();
  FInitedTimeMD5 := umlMD5(@tmp_uid[0], SizeOf(TUID___));

  FDoubleChannelFramework := nil;
  FCustomUserData := nil;
  FCustomUserObject := nil;

  InitAutomatedP2PVM();

  InitLargeScaleIOPool();

  for st := low(TStatisticsType) to high(TStatisticsType) do
      Statistics[st] := 0;
  CmdRecvStatistics := TCommand_Num_Hash_Pool.Create(128, 0);
  CmdSendStatistics := TCommand_Num_Hash_Pool.Create(128, 0);
  CmdMaxExecuteConsumeStatistics := TCommand_Tick_Hash_Pool.Create(128, 0);

  RegisterStream(C_BuildP2PAuthToken).OnExecute := CMD_BuildP2PAuthToken;
  RegisterConsoleNotify(C_InitP2PTunnel).OnExecute := CMD_InitP2PTunnel;
  RegisterConsoleNotify(C_CloseP2PTunnel).OnExecute := CMD_CloseP2PTunnel;
  RegisterConsole(C_NULL).OnExecute := CMD_NULL;
  RegisterCompleteBuffer(C_Complete_Buffer_Stream_Reponse).OnExecute := cmd_Complete_Buffer_Stream_Reponse;

  FPrintParams := TPrint_Param_Hash_Pool.Create(100, False);
  FPrintParams.Add(C_CipherModel, False, False);
  FPrintParams.Add(C_Wait, False, False);
  FPrintParams.Add(C_NULL, False, False);
  FPrintParams.Add(C_Complete_Buffer_Stream_Reponse, False, False);

  SwitchDefaultPerformance;

  CreateAfter;
end;

procedure TZNet.CreateAfter;
begin
end;

destructor TZNet.Destroy;
var
  LPeerIOArray: array of TPeerIO;
  LPtr: TPeer_IO_Hash_Pool.PPair_Pool_Value__;
  LIdx, i: Integer;
begin
  try
    if FZNet_Instance_Ptr__ <> nil then
        ZNet_Instance_Pool.Remove_P(FZNet_Instance_Ptr__);

    FSend_Queue_Swap_Pool.Lock;
    try
      while FSend_Queue_Swap_Pool.Num > 0 do
        begin
          DisposeQueueData(FSend_Queue_Swap_Pool.First^.data);
          FSend_Queue_Swap_Pool.Next;
        end;
    finally
        FSend_Queue_Swap_Pool.UnLock;
    end;

    DisposeObject(FSend_Queue_Swap_Pool);
    DisposeObject(FProgress_Pool);
    FreeAutomatedP2PVM();
    SetLength(FCipherSecurityArray, 0);
    DeleteRegistedCMD(C_BuildP2PAuthToken);
    DeleteRegistedCMD(C_InitP2PTunnel);
    DeleteRegistedCMD(C_CloseP2PTunnel);
    DeleteRegistedCMD(C_NULL);
    DeleteRegistedCMD(C_Complete_Buffer_Stream_Reponse);

    DisposeObject(FCommand_Hash_Pool);

    (*
      * Root-cause fix: release every TPeerIO still registered in
      * FPeerIO_HashPool before the container itself is freed.
      *
      * TPeerIO instances are normally released asynchronously through the
      * DelayClose / DelayFree queue, which is drained by TZNet.Progress.
      * When a TZNet instance is destroyed while that queue still holds
      * pending tasks (a very common case: C4 physics tunnels and services
      * are disposed by C40Clean without ever driving a final Progress
      * loop), the TPeerIO objects remain in FPeerIO_HashPool.
      *
      * DisposeObject(FPeerIO_HashPool) only frees the container. The pool
      * does not own its values (no OnFree handler is installed), so every
      * TPeerIO that is still registered here would leak together with its
      * entire sub-tree:
      *
      *   - TMS64 (IOSendBuffer, SequencePacketSendBuffer, FReceivedBuffer,
      *            FReceivedBuffer_Busy, FCompleteBufferReceivedStream,
      *            FResultDataBuffer, FInDataFrame, FOutDataFrame,
      *            FResult_DFE)
      *   - TCritical (FReceived_Physics_Critical, FSend_Queue_Critical)
      *   - TDFE, TDFE_Reader, TDFE_DataList, TDF_Integer, TDF_Byte,
      *     TDF_ArrayInteger, TDF_ArrayByte
      *   - TCipher_Tool_Base (FDecryptInstance, FEncryptInstance)
      *   - TZNet_P2PVM (with its TP2PVM_Listen_List, TP2PVM_ECHO list,
      *                  and internal TMem64 / TCore_List buffers)
      *   - TPhysics_Fragment_Pool, TQueueData_Order,
      *     TBigStreamBatch, TBigStreamBatchPostData_List,
      *     TPeer_IO_User_Define, TPeer_IO_User_Special
      *   - Every TBigList / TBig_Hash_Pair_Pool reachable from the above.
      *
      * Two-phase teardown:
      *
      *   Phase 1 - snapshot. We walk FPeerIO_HashPool and copy every
      *     TPeerIO pointer into a local array. The pool is not modified
      *     during this walk, so the iterator remains valid.
      *
      *   Phase 2 - release. We iterate the local array and call
      *     DisposeObject on each entry. TPeerIO.Destroy removes its own
      *     entry from FPeerIO_HashPool, which mutates the pool, but we
      *     no longer touch the pool iterator, so this is safe.
      *
      * A single pass is enough: TPeerIO.Destroy does not register new
      * TPeerIO instances into FPeerIO_HashPool.
    *)
    if FPeerIO_HashPool.Count > 0 then
      begin
        SetLength(LPeerIOArray, FPeerIO_HashPool.Count);
        LIdx := 0;
        with FPeerIO_HashPool.Repeat_ do
          repeat
            LPtr := Queue^.data;
            if (LPtr <> nil) and (LPtr^.data.Second <> nil) then
              begin
                LPeerIOArray[LIdx] := LPtr^.data.Second;
                inc(LIdx);
              end;
          until not Next;
        SetLength(LPeerIOArray, LIdx);

        for i := 0 to LIdx - 1 do
          begin
            try
                DisposeObject(LPeerIOArray[i]);
            except
            end;
          end;
        SetLength(LPeerIOArray, 0);
      end;

    DisposeObject(FPeerIO_HashPool);
    DisposeObject(FPrintParams);
    DisposeObject(FPostProgress);
    DisposeObject([CmdRecvStatistics, CmdSendStatistics, CmdMaxExecuteConsumeStatistics]);
    FreeLargeScaleIOPool();
    FIOInterface := nil;
    FVMInterface := nil;
    FOnBigStreamInterface := nil;
    DisposeObject(FSend_Critical);
    DisposeObject(FCritical);
  except
  end;
  inherited Destroy;
end;

procedure TZNet.Post_Queue_Data_To_Swap_Queue(p: PQueueData);
begin
  FSend_Queue_Swap_Pool.Lock;
  FSend_Queue_Swap_Pool.Add(p);
  FSend_Queue_Swap_Pool.UnLock;
end;

function TZNet.AddProgresss(Progress_: TZNet_Progress_Class): TZNet_Progress;
begin
  Result := TZNet_Progress_Class.Create(self);
  Result.FPool_Ptr := FProgress_Pool.Add(Result);
end;

function TZNet.AddProgresss: TZNet_Progress;
begin
  Result := TZNet_Progress.Create(self);
  Result.FPool_Ptr := FProgress_Pool.Add(Result);
end;

procedure TZNet.BeginWriteCustomBuffer(P_IO: TPeerIO);
begin
  P_IO.BeginWriteCustomBuffer;
end;

procedure TZNet.EndWriteCustomBuffer(P_IO: TPeerIO);
begin
  P_IO.EndWriteCustomBuffer;
end;

procedure TZNet.WriteCustomBuffer(P_IO: TPeerIO; const Buffer: PByte; const Size: NativeInt);
begin
  P_IO.WriteCustomBuffer(Buffer, Size);
end;

procedure TZNet.p2pVMTunnelAuth(Sender: TPeerIO; const Token: SystemString; var Accept: Boolean);
begin
  if FVMInterface <> nil then
      FVMInterface.p2pVMTunnelAuth(Sender, Token, Accept);
  if (not Accept) and (FAutomatedP2PVMService) then
      Accept := CompareQuantumCryptographyPassword(FAutomatedP2PVMAuthToken, Token);
end;

procedure TZNet.p2pVMTunnelOpenBefore(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
var
  i: Integer;
begin
  if FVMInterface <> nil then
      FVMInterface.p2pVMTunnelOpenBefore(Sender, P2PVMTunnel);

  if FAutomatedP2PVMService then
    for i := 0 to FAutomatedP2PVMServiceBind.Count - 1 do
        P2PVMTunnel.InstallLogicFramework(FAutomatedP2PVMServiceBind[i]^.Service);
end;

procedure TZNet.p2pVMTunnelOpen(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
begin
  if FVMInterface <> nil then
      FVMInterface.p2pVMTunnelOpen(Sender, P2PVMTunnel);
end;

procedure TZNet.p2pVMTunnelOpenAfter(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
begin
  Sender.ResetSequencePacketBuffer;
  Sender.FSequencePacketSignal := True;
  Sender.SequencePacketVerifyTick := GetTimeTick;
  if FVMInterface <> nil then
      FVMInterface.p2pVMTunnelOpenAfter(Sender, P2PVMTunnel);
end;

procedure TZNet.p2pVMTunnelClose(Sender: TPeerIO; P2PVMTunnel: TZNet_P2PVM);
begin
  if FVMInterface <> nil then
      FVMInterface.p2pVMTunnelClose(Sender, P2PVMTunnel);
end;

function TZNet.AutomatedP2PVMClientConnectionDone(P_IO: TPeerIO): Boolean;
var
  i: Integer;
  p: PAutomatedP2PVMClientData;
begin
  Result := False;
  if P_IO = nil then
      exit;
  if not P_IO.p2pVMTunnelReadyOk then
      exit;
  { check all connection done. }
  for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
    begin
      p := FAutomatedP2PVMClientBind[i];
      if (p^.RequestConnecting) or (not p^.Client.Connected) then
          exit;
    end;
  Result := True;
end;

function TZNet.AutomatedP2PVMClientConnectionDone(): Boolean;
begin
  if FFrameworkIsClient and (TZNet_Client(self).ClientIO <> nil) then
      Result := AutomatedP2PVMClientConnectionDone(TZNet_Client(self).ClientIO)
  else
      Result := False;
end;

procedure TZNet.AutomatedP2PVM_Open(P_IO: TPeerIO);
begin
  with FPostProgress.PostExecuteM(False, FAutomatedP2PVMClientDelayBoot, DoAutomatedP2PVMClient_DelayRequest) do
    begin
      Data3 := P_IO.ID;
      Ready();
    end;
end;

procedure TZNet.AutomatedP2PVM_Open();
begin
  if FFrameworkIsClient and (TZNet_Client(self).ClientIO <> nil) then
      AutomatedP2PVM_Open(TZNet_Client(self).ClientIO);
end;

procedure TZNet.AutomatedP2PVM_Open_C(P_IO: TPeerIO; const OnResult: TOnIOState_C);
begin
  P_IO.FOnAutomatedP2PVMClientConnectionDone_C := OnResult;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_M := nil;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_P := nil;
  AutomatedP2PVM_Open(P_IO);
end;

procedure TZNet.AutomatedP2PVM_Open_M(P_IO: TPeerIO; const OnResult: TOnIOState_M);
begin
  P_IO.FOnAutomatedP2PVMClientConnectionDone_C := nil;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_M := OnResult;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_P := nil;
  AutomatedP2PVM_Open(P_IO);
end;

procedure TZNet.AutomatedP2PVM_Open_P(P_IO: TPeerIO; const OnResult: TOnIOState_P);
begin
  P_IO.FOnAutomatedP2PVMClientConnectionDone_C := nil;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_M := nil;
  P_IO.FOnAutomatedP2PVMClientConnectionDone_P := OnResult;
  AutomatedP2PVM_Open(P_IO);
end;

procedure TZNet.AutomatedP2PVM_Close(P_IO: TPeerIO);
var
  i: Integer;
  p: PAutomatedP2PVMClientData;
begin
  if P_IO = nil then
      exit;

  if FAutomatedP2PVMClient then
    for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
      begin
        p := FAutomatedP2PVMClientBind[i];
        if p^.Client.Connected then
          begin
            p^.Client.Disconnect;
            P_IO.P2PVMTunnel.UninstallLogicFramework(p^.Client);
          end;
      end;
  P_IO.CloseP2PVMTunnel;
end;

procedure TZNet.AutomatedP2PVM_Close();
begin
  if FFrameworkIsClient and (TZNet_Client(self).ClientIO <> nil) then
      AutomatedP2PVM_Close(TZNet_Client(self).ClientIO);
end;

function TZNet.p2pVMTunnelReadyOk(P_IO: TPeerIO): Boolean;
begin
  Result := (P_IO <> nil) and P_IO.p2pVMTunnelReadyOk;
end;

function TZNet.p2pVMTunnelReadyOk(): Boolean;
begin
  if FFrameworkIsClient and (TZNet_Client(self).ClientIO <> nil) then
      Result := p2pVMTunnelReadyOk(TZNet_Client(self).ClientIO)
  else
      Result := False;
end;

procedure TZNet.SwitchMaxPerformance;
begin
  FFastEncrypt := True;
  FUsedParallelEncrypt := False;
  FHashSecurity := THashSecurity.hsNone;
  FSendDataCompressed := False;
  FCompleteBufferCompressed := False;
  SetLength(FCipherSecurityArray, 1);
  FCipherSecurityArray[0] := csNone;
end;

procedure TZNet.SwitchMaxSecurity;
const
  C_CipherSecurity: array [0 .. 7] of TCipherSecurity = (csRC6, csSerpent, csMars, csRijndael, csTwoFish, csAES128, csAES192, csAES256);
var
  i: Integer;
begin
  FFastEncrypt := False;
  FUsedParallelEncrypt := True;
  FHashSecurity := THashSecurity.hsFastMD5;
  FSendDataCompressed := True;
  FCompleteBufferCompressed := False;
  SetLength(FCipherSecurityArray, Length(C_CipherSecurity));
  for i := low(C_CipherSecurity) to high(C_CipherSecurity) do
      FCipherSecurityArray[i] := C_CipherSecurity[i];
end;

procedure TZNet.SwitchDefaultPerformance;
const
  C_CipherSecurity: array [0 .. 14] of TCipherSecurity =
    (csDES64, csDES128, csDES192, csBlowfish, csLBC, csLQC, csXXTea512, csRC6, csSerpent, csMars, csRijndael, csTwoFish, csAES128, csAES192, csAES256);
var
  i: Integer;
begin
  FFastEncrypt := True;
  FUsedParallelEncrypt := True;
  FHashSecurity := THashSecurity.hsNone;
  FSendDataCompressed := False;
  FCompleteBufferCompressed := False;
  SetLength(FCipherSecurityArray, Length(C_CipherSecurity));
  for i := low(C_CipherSecurity) to high(C_CipherSecurity) do
      FCipherSecurityArray[i] := C_CipherSecurity[i];
end;

procedure TZNet.LockSend;
begin
  if FEnabledAtomicLockAndMultiThread then
      FSend_Critical.Lock;
end;

procedure TZNet.UnLockSend;
begin
  if FEnabledAtomicLockAndMultiThread then
      FSend_Critical.UnLock;
end;

procedure TZNet.Lock_All_IO;
begin
  if FEnabledAtomicLockAndMultiThread then
      FCritical.Lock;
end;

procedure TZNet.UnLock_All_IO;
begin
  if FEnabledAtomicLockAndMultiThread then
      FCritical.UnLock;
end;

function TZNet.IOBusy(): Boolean;
begin
  Result := False;
  if FPeerIO_HashPool.Count <= 0 then
      exit;

  with FPeerIO_HashPool.Repeat_ do
    repeat
      if Queue^.data^.data.Second.IOBusy() then
        begin
          Result := True;
          exit;
        end;
    until not Next;
end;

procedure TZNet.Enabled_Progress;
var
  i: Integer;
begin
  FProgressEnabled := True;
  for i := AutomatedP2PVMServiceBind.Count - 1 downto 0 do
      AutomatedP2PVMServiceBind[i].Service.Enabled_Progress;
  for i := AutomatedP2PVMClientBind.Count - 1 downto 0 do
      AutomatedP2PVMClientBind[i].Client.Enabled_Progress;
end;

procedure TZNet.Disable_Progress;
var
  i: Integer;
begin
  FProgressEnabled := False;
  for i := AutomatedP2PVMServiceBind.Count - 1 downto 0 do
      AutomatedP2PVMServiceBind[i].Service.Disable_Progress;
  for i := AutomatedP2PVMClientBind.Count - 1 downto 0 do
      AutomatedP2PVMClientBind[i].Client.Disable_Progress;
end;

procedure TZNet.Progress;
var
  i: Integer;
begin
  if FProgressRuning then // anti dead loop
      exit;
  if not FProgressEnabled then // enabled progress
      exit;

  { anti Dead loop }
  FProgressRuning := True;

  FProgress_CPS.Begin_Caller;

  try
    if Assigned(ProgressBackgroundProc) then
        ProgressBackgroundProc()
    else if Assigned(ProgressBackgroundMethod) then
        ProgressBackgroundMethod();
  except
  end;

  { large-scale Progress }
  ProgressLargeScaleIOPool();

  { AutomatedP2PVMService }
  try
    if FAutomatedP2PVMService and (FAutomatedP2PVMServiceBind.Count > 0) then
      for i := 0 to FAutomatedP2PVMServiceBind.Count - 1 do
          FAutomatedP2PVMServiceBind[i]^.Service.Progress;
  except
  end;

  { AutomatedP2PVMClient }
  try
    if FAutomatedP2PVMClient and (FAutomatedP2PVMClientBind.Count > 0) then
      for i := 0 to FAutomatedP2PVMClientBind.Count - 1 do
          FAutomatedP2PVMClientBind[i]^.Client.Progress;
  except
  end;

  try
      ProgressPost.Progress;
  except
  end;

  try
    if Assigned(FOnProgress) then
        FOnProgress(self);
  except
  end;

  { progress event pool }
  try
    if FProgress_Pool.Num > 0 then
      begin
        with FProgress_Pool.Repeat_ do
          repeat
            Queue^.data.Progress;
            if Queue^.data.NextProgressDoFree then
                FProgress_Pool.Push_To_Recycle_Pool(Queue);
          until not Next;
        FProgress_Pool.Free_Recycle_Pool;
      end;
  except
  end;

  FProgress_CPS.End_Caller;

  { anti Dead loop }
  FProgressRuning := False;
end;

procedure TZNet.Progress_IO_Now_Send(IO_: TPeerIO);
begin
  FSend_Queue_Swap_Pool.Lock;
  try
    if FSend_Queue_Swap_Pool.Num > 0 then
      begin
        with FSend_Queue_Swap_Pool.Repeat_ do
          repeat
            if Queue^.data^.IO_ID = IO_.ID then
              begin
                IO_.PostQueueData(Queue^.data);
                Discard();
              end;
          until not Next;
      end;
  finally
      FSend_Queue_Swap_Pool.UnLock;
  end;
end;

procedure TZNet.ProgressPeerIOC(const OnBackcall: TPeerIOList_C);
var
  IO_Array: TIO_Array;
  pframeworkID: Cardinal;
  c: TPeerIO;
begin
  if (FPeerIO_HashPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      GetIO_Array(IO_Array);
      for pframeworkID in IO_Array do
        begin
          c := FPeerIO_HashPool[pframeworkID];
          if c <> nil then
            begin
              try
                  OnBackcall(c);
              except
              end;
            end;
        end;
    end;
end;

procedure TZNet.ProgressPeerIOM(const OnBackcall: TPeerIOList_M);
var
  IO_Array: TIO_Array;
  pframeworkID: Cardinal;
  c: TPeerIO;
begin
  if (FPeerIO_HashPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      GetIO_Array(IO_Array);
      for pframeworkID in IO_Array do
        begin
          c := FPeerIO_HashPool[pframeworkID];
          if c <> nil then
            begin
              try
                  OnBackcall(c);
              except
              end;
            end;
        end;
    end;
end;

procedure TZNet.ProgressPeerIOP(const OnBackcall: TPeerIOList_P);
var
  IO_Array: TIO_Array;
  pframeworkID: Cardinal;
  c: TPeerIO;
begin
  if (FPeerIO_HashPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      GetIO_Array(IO_Array);
      for pframeworkID in IO_Array do
        begin
          c := FPeerIO_HashPool[pframeworkID];
          if c <> nil then
            begin
              try
                  OnBackcall(c);
              except
              end;
            end;
        end;
    end;
end;

procedure TZNet.FastProgressPeerIOC(const OnBackcall: TPeerIOList_C);
begin
  if (FPeerIO_HashPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      with FPeerIO_HashPool.Repeat_ do
        repeat
            OnBackcall(Queue^.data^.data.Second);
        until not Next;
    end;
end;

procedure TZNet.FastProgressPeerIOM(const OnBackcall: TPeerIOList_M);
begin
  if (FPeerIO_HashPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      with FPeerIO_HashPool.Repeat_ do
        repeat
            OnBackcall(Queue^.data^.data.Second);
        until not Next;
    end;
end;

procedure TZNet.FastProgressPeerIOP(const OnBackcall: TPeerIOList_P);
begin
  if (FPeerIO_HashPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      with FPeerIO_HashPool.Repeat_ do
        repeat
            OnBackcall(Queue^.data^.data.Second);
        until not Next;
    end;
end;

procedure TZNet.GetIO_Array(out IO_Array: TIO_Array);
begin
  Lock_All_IO;
  try
    SetLength(IO_Array, FPeerIO_HashPool.Count);
    if FPeerIO_HashPool.Count > 0 then
      with FPeerIO_HashPool.Repeat_ do
        repeat
            IO_Array[I__] := Queue^.data^.data.Primary;
        until not Next;
  finally
      UnLock_All_IO;
  end;
end;

procedure TZNet.GetIO_Order(Order_: TIO_Order);
begin
  Order_.Clear;
  Lock_All_IO;
  try
    if FPeerIO_HashPool.Count > 0 then
      with FPeerIO_HashPool.Repeat_ do
        repeat
            Order_.Push(Queue^.data^.data.Primary);
        until not Next;
  finally
      UnLock_All_IO;
  end;
end;

procedure TZNet.ProgressWaitSend(P_IO: TPeerIO);
var
  state_: Boolean;
begin
  if FProgressWaitRuning then
      exit;
  if not FProgressEnabled then
      exit;
  if P_IO = nil then
      exit;
  if FProgressWaitRuning then
    begin
      P_IO.PrintError('ProgressWaitSend: dead loop');
      P_IO.Disconnect; // anti dead loop.
      try
        { progress local instance }
        Progress;
        { progress global instance }
        if ZNet_Instance_Pool.Num > 0 then
          with ZNet_Instance_Pool.Repeat_ do
            repeat
              try
                if (Queue^.data <> self) and (Queue^.data <> nil) then
                    Queue^.data.Progress;
              except
              end;
            until not Next;
      except
      end;
      exit;
    end;

  FProgressWaitRuning := True;

  try
    { progress local instance }
    Progress;
    { progress global instance }
    if ZNet_Instance_Pool.Num > 0 then
      with ZNet_Instance_Pool.Repeat_ do
        repeat
          try
            if (Queue^.data <> self) and (Queue^.data <> nil) then
                Queue^.data.Progress;
          except
          end;
        until not Next;
  except
  end;

  { check thread synchronize }
  try
      Check_Soft_Thread_Synchronize(0);
  except
  end;

  FProgressWaitRuning := False;
end;

function TZNet.ProgressWaitSend(IO_ID: Cardinal): Boolean;
var
  P_IO: TPeerIO;
begin
  Result := False;
  P_IO := FPeerIO_HashPool[IO_ID];
  if P_IO <> nil then
    begin
      ProgressWaitSend(P_IO);
      Result := True;
    end;
end;

procedure TZNet.Print(const v: SystemString; const Args: array of const);
begin
  try
      Print(PFormat(v, Args));
  except
      Error('print error. ' + v);
  end;
end;

procedure TZNet.Print(const v: SystemString);
begin
  DoPrint(v);
end;

procedure TZNet.PrintParam(const v, Args: SystemString);
begin
  try
    if (not IsSystemCMD(Args)) and FPrintParams.Get_Default_Value(Args, True) then
        Print(PFormat(v, [Args]));
  except
      Error('print error. ' + v);
  end;
end;

procedure TZNet.Error(const v: SystemString; const Args: array of const);
begin
  try
      Error(PFormat(v, Args));
  except
      Error('print error. ' + v);
  end;
end;

procedure TZNet.Error(const v: SystemString);
begin
  DoError(v);
end;

procedure TZNet.ErrorParam(const v, Args: SystemString);
begin
  DoError(PFormat(v, [Args]));
end;

procedure TZNet.PrintError(const v: SystemString; const Args: array of const);
begin
  try
      Error(PFormat(v, Args));
  except
      Error('print error. ' + v);
  end;
end;

procedure TZNet.PrintError(const v: SystemString);
begin
  DoError(v);
end;

procedure TZNet.PrintErrorParam(const v, Args: SystemString);
begin
  DoError(PFormat(v, [Args]));
end;

procedure TZNet.Warning(const v: SystemString);
begin
  DoWarning(v);
end;

procedure TZNet.WarningParam(const v, Args: SystemString);
begin
  DoWarning(PFormat(v, [Args]));
end;

procedure TZNet.PrintWarning(const v: SystemString);
begin
  DoWarning(v);
end;

procedure TZNet.PrintWarningParam(const v, Args: SystemString);
begin
  DoWarning(PFormat(v, [Args]));
end;

procedure TZNet.PrintRegistedCMD;
begin
  PrintRegistedCMD('', True);
end;

procedure TZNet.PrintRegistedCMD(prefix: SystemString; incl_internalCMD: Boolean);
begin
  if FCommand_Hash_Pool.Num > 0 then
    with FCommand_Hash_Pool.Queue_Pool.Repeat_ do
      repeat
        if incl_internalCMD or (not umlMultipleMatch('__@*', Queue^.data^.data.Primary)) then
            Print(prefix + Queue^.data^.data.Second.ClassName + ': ' + Queue^.data^.data.Primary);
      until not Next;
end;

procedure TZNet.PrintRegistedCMD(prefix: SystemString);
begin
  PrintRegistedCMD(prefix, True);
end;

function TZNet.RemoveRegistedCMD(const Cmd: SystemString): Boolean;
begin
  Result := FCommand_Hash_Pool.Exists(Cmd);
  FCommand_Hash_Pool.Delete(Cmd);
end;

function TZNet.DeleteRegistedCMD(const Cmd: SystemString): Boolean;
begin
  Result := RemoveRegistedCMD(Cmd);
end;

function TZNet.UnRegisted(const Cmd: SystemString): Boolean;
begin
  Result := RemoveRegistedCMD(Cmd);
end;

function TZNet.ExistsRegistedCmd(const Cmd: SystemString): Boolean;
begin
  Result := FCommand_Hash_Pool.Exists(Cmd);
end;

function TZNet.RegisterConsole(const Cmd: SystemString): TCommandConsole;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandConsole.Create;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterStream(const Cmd: SystemString): TCommandStream;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandStream.Create;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterStreamNotify(const Cmd: SystemString): TCommandStreamNotify;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandStreamNotify.Create;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterConsoleNotify(const Cmd: SystemString): TCommandConsoleNotify;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandConsoleNotify.Create;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterBigStream(const Cmd: SystemString): TCommandBigStream;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandBigStream.Create;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterCompleteBuffer(const Cmd: SystemString): TCommandCompleteBuffer;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandCompleteBuffer.Create;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterCompleteBuffer_StreamNotify(const Cmd: SystemString): TCommandCompleteBuffer_StreamNotify;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandCompleteBuffer_StreamNotify.Create;
  Result.Sync_Decrypt := True;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterCompleteBuffer_Asynchronous_StreamNotify(const Cmd: SystemString): TCommandCompleteBuffer_StreamNotify;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandCompleteBuffer_StreamNotify.Create;
  Result.Sync_Decrypt := False;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterCompleteBuffer_NoWait_Stream(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Stream;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandCompleteBuffer_NoWait_Stream.Create;
  Result.FExecute_In_Thread := False;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterCompleteBuffer_NoWait_Stream_Thread(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Stream;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandCompleteBuffer_NoWait_Stream.Create;
  Result.FExecute_In_Thread := True;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.RegisterCompleteBuffer_NoWait_Bridge_Stream(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Bridge_Stream;
begin
  if not CanRegCommand(self, Cmd) then
    begin
      RaiseInfo(PFormat('Illegal Register', []));
      Result := nil;
      exit;
    end;

  if FCommand_Hash_Pool.Exists(Cmd) then
    begin
      RaiseInfo(PFormat('exists cmd: %s', [Cmd]));
      Result := nil;
      exit;
    end;

  Result := TCommandCompleteBuffer_NoWait_Bridge_Stream.Create;
  FCommand_Hash_Pool.Add(Cmd, Result, False);

  CmdRecvStatistics.IncValue(Cmd, 0);
  CmdMaxExecuteConsumeStatistics[Cmd] := 0;
end;

function TZNet.FirstIO: TPeerIO;
begin
  Result := nil;
  if FPeerIO_HashPool.Queue_Pool.First <> nil then
      Result := FPeerIO_HashPool.Queue_Pool.First^.data^.data.Second;
end;

function TZNet.LastIO: TPeerIO;
begin
  Result := nil;
  if FPeerIO_HashPool.Queue_Pool.Last <> nil then
      Result := FPeerIO_HashPool.Queue_Pool.Last^.data^.data.Second;
end;

function TZNet.ExistsID(IO_ID: Cardinal): Boolean;
begin
  Result := FPeerIO_HashPool.Exists_Key(IO_ID);
end;

function TZNet.GetRandomCipherSecurity: TCipherSecurity;
begin
  if Length(FCipherSecurityArray) > 0 then
      Result := TCipher.Random_Select_Cipher(FCipherSecurityArray)
  else
      Result := csNone;
end;

procedure TZNet.CopyParamFrom(Source: TZNet);
begin
  FastEncrypt := Source.FastEncrypt;
  UsedParallelEncrypt := Source.UsedParallelEncrypt;
  SyncOnResult := Source.SyncOnResult;
  SyncOnCompleteBuffer := Source.SyncOnCompleteBuffer;
  BigStreamMemorySwapSpace := Source.BigStreamMemorySwapSpace;
  BigStreamSwapSpaceTriggerSize := Source.BigStreamSwapSpaceTriggerSize;
  EnabledAtomicLockAndMultiThread := Source.EnabledAtomicLockAndMultiThread;
  TimeOut := Source.TimeOut;
  QuietMode := Source.QuietMode;
  PhysicsFragmentSwapSpaceTechnology := Source.PhysicsFragmentSwapSpaceTechnology;
  PhysicsFragmentSwapSpaceTrigger := Source.PhysicsFragmentSwapSpaceTrigger;
  SendDataCompressed := Source.SendDataCompressed;
  CompleteBufferCompressed := Source.CompleteBufferCompressed;
  Per_Progress_Loop_Limit := Source.Per_Progress_Loop_Limit;
  Extract_Physics_Fragment_Max_Size := Source.Extract_Physics_Fragment_Max_Size;
  MaxCompleteBufferSize := Source.MaxCompleteBufferSize;
  CompleteBufferCompressionCondition := Source.CompleteBufferCompressionCondition;
  CompleteBufferSwapSpace := Source.CompleteBufferSwapSpace;
  CompleteBufferSwapSpaceTriggerSize := Source.CompleteBufferSwapSpaceTriggerSize;
  AutomaticWaitRemoteReponse := Source.AutomaticWaitRemoteReponse;
  Encrypt_P2PVM_Packet := Source.Encrypt_P2PVM_Packet;
  ProgressMaxDelay := Source.ProgressMaxDelay;
  SendFlushSize := Source.SendFlushSize;

  PrefixName := Source.PrefixName;
  name := Source.name;
end;

procedure TZNet.CopyParamTo(Dest: TZNet);
begin
  Dest.CopyParamFrom(self);
end;

procedure TZNet.SetPeerIOUserDefineClass(const Value: TPeer_IO_User_Define_Class);
begin
  { safe }
  if FPeerIOUserDefineClass <> nil then
    if (not Value.InheritsFrom(FPeerIOUserDefineClass)) and (Value <> TPeer_IO_User_Define) then
        RaiseInfo('%s no inherited from %s', [Value.ClassName, FPeerIOUserDefineClass.ClassName]);
  { update }
  FPeerIOUserDefineClass := Value;
end;

procedure TZNet.SetPeerIOUserSpecialClass(const Value: TPeer_IO_User_Special_Class);
begin
  { safe }
  if FPeerIOUserSpecialClass <> nil then
    if (not Value.InheritsFrom(FPeerIOUserSpecialClass)) and (Value <> TPeer_IO_User_Special) then
        RaiseInfo('%s no inherited from %s', [Value.ClassName, FPeerIOUserSpecialClass.ClassName]);
  { update }
  FPeerIOUserSpecialClass := Value;
end;
