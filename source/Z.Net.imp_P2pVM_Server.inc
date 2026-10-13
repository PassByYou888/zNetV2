procedure TZNet_WithP2PVM_Server.Connecting(SenderVM: TZNet_P2PVM;
  const Remote_frameworkID, FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; var Allowed: Boolean);
var
  p: PP2PVMListen;
  LocalVMc: TP2PVM_PeerIO;
begin
  if FLinkVMPool.Count = 0 then
    begin
      Allowed := False;
      exit;
    end;

  p := SenderVM.FindListen(IPV6, Port);
  Allowed := (p <> nil) and (p^.FrameworkID = FrameworkID);

  if Allowed then
    begin
      { build io }
      LocalVMc := TP2PVM_PeerIO.Create(self, nil);
      LocalVMc.FLinkVM := SenderVM;
      LocalVMc.FRemote_frameworkID := Remote_frameworkID;
      LocalVMc.FRemote_p2pID := 0;
      LocalVMc.FIP := IPV6;
      LocalVMc.FPort := Port;

      { connected reponse }
      SenderVM.SendConnectedReponse(LocalVMc.FRemote_frameworkID, LocalVMc.FRemote_p2pID, FrameworkID, LocalVMc.ID);

      if not FQuietMode then
          Print('Virtual connecting with "%s port:%d"', [IPv6ToStr(IPV6).Text, Port]);
    end;
end;

procedure TZNet_WithP2PVM_Server.ListenState(SenderVM: TZNet_P2PVM; const IPV6: TIPV6; const Port: Word; const State: Boolean);
begin
  if not FQuietMode then
    begin
      if State then
          Print('Virtual Addr: "%s Port:%d" Listen is open', [IPv6ToStr(IPV6).Text, Port])
      else
          Print('Virtual Addr: "%s Port:%d" Listen close!', [IPv6ToStr(IPV6).Text, Port]);
    end;
end;

procedure TZNet_WithP2PVM_Server.ProgressDisconnectClient(P_IO: TPeerIO);
begin
  DisposeObject(P_IO);
end;

function TZNet_WithP2PVM_Server.ListenCount: Integer;
begin
  Result := FFrameworkListenPool.Count;
end;

function TZNet_WithP2PVM_Server.GetListen(const index: Integer): PP2PVMListen;
begin
  Result := FFrameworkListenPool[index];
end;

function TZNet_WithP2PVM_Server.FindListen(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
var
  i: Integer;
  p: PP2PVMListen;
begin
  for i := 0 to FFrameworkListenPool.Count - 1 do
    begin
      p := FFrameworkListenPool[i];
      if (p^.ListenPort = Port) and (CompareIPV6(p^.ListenHost, IPV6)) then
        begin
          Result := p;
          exit;
        end;
    end;
  Result := nil;
end;

function TZNet_WithP2PVM_Server.FindListening(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
var
  i: Integer;
  p: PP2PVMListen;
begin
  for i := 0 to FFrameworkListenPool.Count - 1 do
    begin
      p := FFrameworkListenPool[i];
      if (p^.Listening) and (p^.ListenPort = Port) and (CompareIPV6(p^.ListenHost, IPV6)) then
        begin
          Result := p;
          exit;
        end;
    end;
  Result := nil;
end;

procedure TZNet_WithP2PVM_Server.DeleteListen(const IPV6: TIPV6; const Port: Word);
var
  i: Integer;
  p: PP2PVMListen;
begin
  i := 0;
  while i < FFrameworkListenPool.Count do
    begin
      p := FFrameworkListenPool[i];
      if (p^.ListenPort = Port) and (CompareIPV6(p^.ListenHost, IPV6)) then
        begin
          Dispose(p);
          FFrameworkListenPool.Delete(i);
        end
      else
          inc(i);
    end;
end;

procedure TZNet_WithP2PVM_Server.ClearListen;
var
  i: Integer;
begin
  for i := 0 to FFrameworkListenPool.Count - 1 do
      Dispose(PP2PVMListen(FFrameworkListenPool[i]));
  FFrameworkListenPool.Clear;
end;

constructor TZNet_WithP2PVM_Server.Create;
begin
  CustomCreate(20 * 10000, 0);
end;

constructor TZNet_WithP2PVM_Server.CustomCreate(HashPoolSize: Integer; FrameworkID: Cardinal);
begin
  inherited CreateCustomHashPool(HashPoolSize);
  EnabledAtomicLockAndMultiThread := False;
  SequencePacketActivted := {$IFDEF UsedSequencePacketOnP2PVM}True{$ELSE UsedSequencePacketOnP2PVM}False{$ENDIF UsedSequencePacketOnP2PVM};

  FFrameworkListenPool := TCore_List.Create;
  FLinkVMPool := TUInt32HashObjectList.Create;
  FFrameworkWithVM_ID := FrameworkID;
  StopService;
  name := 'VMServer';
end;

destructor TZNet_WithP2PVM_Server.Destroy;
var
  i: Integer;
  L: TCore_List;
  p: PUInt32HashListObjectStruct;
begin
  CloseAllClient;
  ClearListen;

  if (FLinkVMPool.Count > 0) then
    begin
      L := TCore_List.Create;
      try
        FLinkVMPool.GetListData(L);
        for i := 0 to L.Count - 1 do
          begin
            p := L[i];
            (TZNet_P2PVM(p^.data)).UninstallLogicFramework(self);
          end;
      except
      end;
      DisposeObject(L);
    end;

  DisposeObject(FLinkVMPool);
  DisposeObject(FFrameworkListenPool);
  inherited Destroy;
end;

procedure TZNet_WithP2PVM_Server.Progress;
begin
  inherited Progress;
end;

procedure TZNet_WithP2PVM_Server.CloseAllClient;
begin
  ProgressPeerIOM(ProgressDisconnectClient);
end;

procedure TZNet_WithP2PVM_Server.ProgressStopServiceWithPerVM(SenderVM: TZNet_P2PVM);
var
  i: Integer;
  p: PP2PVMListen;
  lst: TCore_List;
begin
  lst := TCore_List.Create;

  for i := 0 to SenderVM.ListenCount - 1 do
    begin
      p := SenderVM.GetListen(i);
      if SenderVM.FFrameworkPool[p^.FrameworkID] = self then
          lst.Add(p);
    end;

  for i := 0 to lst.Count - 1 do
    begin
      p := lst[i];
      SenderVM.SendListen(p^.FrameworkID, p^.ListenHost, p^.ListenPort, False);
    end;
  DisposeObject(lst);
end;

procedure TZNet_WithP2PVM_Server.StopService;
var
  i: Integer;
  p: PUInt32HashListObjectStruct;
begin
  if (FLinkVMPool.Count > 0) then
    begin
      i := 0;
      p := FLinkVMPool.FirstPtr;
      while i < FLinkVMPool.Count do
        begin
          try
              ProgressStopServiceWithPerVM(TZNet_P2PVM(p^.data));
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end;

  ClearListen;

  CloseAllClient;
end;

function TZNet_WithP2PVM_Server.StartService(Host_: SystemString; Port: Word): Boolean;
var
  IPV6: TIPV6;
  SI: Cardinal;
  i: Integer;
  p: PUInt32HashListObjectStruct;
  LP: PP2PVMListen;
begin
  Result := False;

  if umlTrimSpace(Host_).L = 0 then
      IPV6 := MakeRandomIPV6()
  else
    begin
      IPV6 := StrToIPv6(Host_, Result, SI);
      if not Result then
          exit;
    end;

  LP := FindListen(IPV6, Port);
  if LP = nil then
    begin
      New(LP);
      LP^.FrameworkID := FFrameworkWithVM_ID;
      LP^.ListenHost := IPV6;
      LP^.ListenPort := Port;
      LP^.Listening := True;
      FFrameworkListenPool.Add(LP);
    end
  else
      LP^.Listening := True;

  if (FLinkVMPool.Count > 0) then
    begin
      i := 0;
      p := FLinkVMPool.FirstPtr;
      while i < FLinkVMPool.Count do
        begin
          try
              TZNet_P2PVM(p^.data).SendListen(FFrameworkWithVM_ID, IPV6, Port, True);
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end
  else
    begin
      ListenState(nil, IPV6, Port, True);
    end;
  Result := True;
end;

function TZNet_WithP2PVM_Server.WaitSendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;
begin
  Result := '';
  RaiseInfo('WaitSend no Suppport VM server');
end;

procedure TZNet_WithP2PVM_Server.WaitSendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);
begin
  RaiseInfo('WaitSend no Suppport VM server');
end;

