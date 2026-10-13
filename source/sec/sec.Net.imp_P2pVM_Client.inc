
procedure TZNet_WithP2PVM_Client.Framework_Internal_IO_Create(const Sender: TPeerIO);
begin
  inherited Framework_Internal_IO_Create(Sender);
end;

procedure TZNet_WithP2PVM_Client.Framework_Internal_IO_Destroy(const Sender: TPeerIO);
begin
  FVMClientIO := nil;
  FVMConnected := False;
  inherited Framework_Internal_IO_Destroy(Sender);
end;

procedure TZNet_WithP2PVM_Client.VMConnectSuccessed(SenderVM: TZNet_P2PVM; Remote_frameworkID, Remote_p2pID, FrameworkID: Cardinal);
begin
  FVMClientIO.FRemote_frameworkID := Remote_frameworkID;
  FVMClientIO.FRemote_p2pID := Remote_p2pID;

  FVMConnected := True;
  DoConnected(FVMClientIO);
end;

procedure TZNet_WithP2PVM_Client.VMDisconnect(SenderVM: TZNet_P2PVM);
begin
  FVMConnected := False;
  TriggerDoConnectFailed;
  if FVMClientIO <> nil then
      FVMClientIO.Disconnect;
end;

constructor TZNet_WithP2PVM_Client.Create;
begin
  CustomCreate(0);
end;

constructor TZNet_WithP2PVM_Client.CustomCreate(FrameworkID: Cardinal);
begin
  inherited Create;
  EnabledAtomicLockAndMultiThread := False;
  SequencePacketActivted := {$IFDEF UsedSequencePacketOnP2PVM}True{$ELSE UsedSequencePacketOnP2PVM}False{$ENDIF UsedSequencePacketOnP2PVM};
  FLinkVM := nil;
  FFrameworkWithVM_ID := FrameworkID;
  FVMClientIO := nil;
  FVMConnected := False;
  FP2PVM_ClonePool := TZNet_WithP2PVM_Client_Clone_Pool.Create;
  FP2PVM_ClonePool_Ptr := nil;
  FP2PVM_CloneOwner := nil;
  FP2PVM_Clone_NextProgressDoFreeSelf := False;
  FP2PVM_ProgressWaitSend_Busy := False;
  FOnP2PVMAsyncConnectNotify_C := nil;
  FOnP2PVMAsyncConnectNotify_M := nil;
  FOnP2PVMAsyncConnectNotify_P := nil;
  name := 'VMClientIO';
end;

destructor TZNet_WithP2PVM_Client.Destroy;
begin
  try
    if (FP2PVM_CloneOwner <> nil) and (FP2PVM_ClonePool_Ptr <> nil) then
        FP2PVM_CloneOwner.FP2PVM_ClonePool.Remove_P(FP2PVM_ClonePool_Ptr);

    FP2PVM_CloneOwner := nil;
    FP2PVM_ClonePool_Ptr := nil;

    while FP2PVM_ClonePool.Num > 0 do
      begin
        FP2PVM_ClonePool.First^.data.FP2PVM_CloneOwner := nil;
        FP2PVM_ClonePool.First^.data.FP2PVM_ClonePool_Ptr := nil;
        DisposeObjectAndNil(FP2PVM_ClonePool.First^.data);
        FP2PVM_ClonePool.Next;
      end;
  except
  end;

  if FVMClientIO <> nil then
      DisposeObjectAndNil(FVMClientIO);
  if FLinkVM <> nil then
      FLinkVM.UninstallLogicFramework(self);
  DisposeObjectAndNil(FP2PVM_ClonePool);
  inherited Destroy;
end;

function TZNet_WithP2PVM_Client.CloneConnectC(OnResult: TOnP2PVM_CloneConnectEvent_C): TP2PVM_CloneConnectEventBridge;
var
  Bridge_: TP2PVM_CloneConnectEventBridge;
begin
  Result := nil;
  if not Assigned(OnResult) then
      exit;
  if (FLinkVM = nil) or (not Connected) then
      exit;
  Bridge_ := TP2PVM_CloneConnectEventBridge.Create(self);
  Bridge_.NewClient := TZNet_WithP2PVM_Client.Create;
  { copy parameter }
  Bridge_.NewClient.CopyParamFrom(self);
  Bridge_.NewClient.name := Bridge_.NewClient.name + '.Clone';
  { init event }
  Bridge_.OnResultC := OnResult;
  Bridge_.NewClient.FP2PVM_CloneOwner := self;
  LinkVM.InstallLogicFramework(Bridge_.NewClient);
  Bridge_.NewClient.FP2PVM_ClonePool_Ptr := FP2PVM_ClonePool.Add(Bridge_.NewClient);
  Bridge_.NewClient.AsyncConnectM(IPv6ToStr(FVMClientIO.FIP), FVMClientIO.FPort, Bridge_.DoAsyncConnectState);
  Result := Bridge_;
end;

function TZNet_WithP2PVM_Client.CloneConnectM(OnResult: TOnP2PVM_CloneConnectEvent_M): TP2PVM_CloneConnectEventBridge;
var
  Bridge_: TP2PVM_CloneConnectEventBridge;
begin
  Result := nil;
  if not Assigned(OnResult) then
      exit;
  if (FLinkVM = nil) or (not Connected) then
      exit;
  Bridge_ := TP2PVM_CloneConnectEventBridge.Create(self);
  Bridge_.NewClient := TZNet_WithP2PVM_Client.Create;
  { copy parameter }
  Bridge_.NewClient.CopyParamFrom(self);
  Bridge_.NewClient.name := name + '.Clone';
  { init event }
  Bridge_.OnResultM := OnResult;
  Bridge_.NewClient.FP2PVM_CloneOwner := self;
  LinkVM.InstallLogicFramework(Bridge_.NewClient);
  Bridge_.NewClient.FP2PVM_ClonePool_Ptr := FP2PVM_ClonePool.Add(Bridge_.NewClient);
  Bridge_.NewClient.AsyncConnectM(IPv6ToStr(FVMClientIO.FIP), FVMClientIO.FPort, Bridge_.DoAsyncConnectState);
  Result := Bridge_;
end;

function TZNet_WithP2PVM_Client.CloneConnectP(OnResult: TOnP2PVM_CloneConnectEvent_P): TP2PVM_CloneConnectEventBridge;
var
  Bridge_: TP2PVM_CloneConnectEventBridge;
begin
  Result := nil;
  if not Assigned(OnResult) then
      exit;
  if (FLinkVM = nil) or (not Connected) then
      exit;
  Bridge_ := TP2PVM_CloneConnectEventBridge.Create(self);
  Bridge_.NewClient := TZNet_WithP2PVM_Client.Create;
  { copy parameter }
  Bridge_.NewClient.CopyParamFrom(self);
  Bridge_.NewClient.name := Bridge_.NewClient.name + '.Clone';
  { init event }
  Bridge_.OnResultP := OnResult;
  Bridge_.NewClient.FP2PVM_CloneOwner := self;
  LinkVM.InstallLogicFramework(Bridge_.NewClient);
  Bridge_.NewClient.FP2PVM_ClonePool_Ptr := FP2PVM_ClonePool.Add(Bridge_.NewClient);
  Bridge_.NewClient.AsyncConnectM(IPv6ToStr(FVMClientIO.FIP), FVMClientIO.FPort, Bridge_.DoAsyncConnectState);
  Result := Bridge_;
end;

procedure TZNet_WithP2PVM_Client.TriggerDoConnectFailed;
begin
  inherited TriggerDoConnectFailed;

  try
    if Assigned(FOnP2PVMAsyncConnectNotify_C) then
        FOnP2PVMAsyncConnectNotify_C(False)
    else if Assigned(FOnP2PVMAsyncConnectNotify_M) then
        FOnP2PVMAsyncConnectNotify_M(False)
    else if Assigned(FOnP2PVMAsyncConnectNotify_P) then
        FOnP2PVMAsyncConnectNotify_P(False);
  except
  end;

  FOnP2PVMAsyncConnectNotify_C := nil;
  FOnP2PVMAsyncConnectNotify_M := nil;
  FOnP2PVMAsyncConnectNotify_P := nil;
end;

procedure TZNet_WithP2PVM_Client.TriggerDoConnectFinished;
begin
  inherited TriggerDoConnectFinished;

  try
    if Assigned(FOnP2PVMAsyncConnectNotify_C) then
        FOnP2PVMAsyncConnectNotify_C(True)
    else if Assigned(FOnP2PVMAsyncConnectNotify_M) then
        FOnP2PVMAsyncConnectNotify_M(True)
    else if Assigned(FOnP2PVMAsyncConnectNotify_P) then
        FOnP2PVMAsyncConnectNotify_P(True);
  except
  end;

  FOnP2PVMAsyncConnectNotify_C := nil;
  FOnP2PVMAsyncConnectNotify_M := nil;
  FOnP2PVMAsyncConnectNotify_P := nil;
end;

function TZNet_WithP2PVM_Client.Connected: Boolean;
begin
  Result := (FVMConnected) and (FVMClientIO <> nil);
end;

function TZNet_WithP2PVM_Client.ClientIO: TPeerIO;
begin
  Result := FVMClientIO;
end;

procedure TZNet_WithP2PVM_Client.Progress;
var
  __repeat__: TZNet_WithP2PVM_Client_Clone_Pool.TRepeat___;
begin
  inherited Progress;
  if not FProgressEnabled then
      exit;
  if FP2PVM_ClonePool.Num > 0 then
    begin
      __repeat__ := FP2PVM_ClonePool.Repeat_();
      repeat
        if __repeat__.Queue^.data.FP2PVM_Clone_NextProgressDoFreeSelf then
          begin
            __repeat__.Queue^.data.FP2PVM_CloneOwner := nil;
            __repeat__.Queue^.data.FP2PVM_ClonePool_Ptr := nil;
            FP2PVM_ClonePool.Push_To_Recycle_Pool(__repeat__.Queue);
            PostProgress.PostDelayFreeObject(0.1, __repeat__.Queue^.data);
          end
        else
            __repeat__.Queue^.data.Progress;
      until not __repeat__.Next;
      FP2PVM_ClonePool.Free_Recycle_Pool;
    end;
end;

procedure TZNet_WithP2PVM_Client.AsyncConnect(addr: SystemString; Port: Word);
var
  R: Boolean;
  IPV6: TIPV6;
  p: PP2PVMListen;
begin
  Disconnect;
  if FLinkVM = nil then
      RaiseInfo('no vm reference');
  FVMClientIO := TP2PVM_PeerIO.Create(self, nil);
  FVMClientIO.FLinkVM := FLinkVM;

  FVMConnected := False;

  FOnP2PVMAsyncConnectNotify_C := nil;
  FOnP2PVMAsyncConnectNotify_M := nil;
  FOnP2PVMAsyncConnectNotify_P := nil;
  if (FLinkVM = nil) or (FLinkVM.FOwner_IO = nil) then
    begin
      Error('no VM connect');
      TriggerDoConnectFailed;
      exit;
    end;

  if not FLinkVM.WasAuthed then
    begin
      Error('VM no auth');
      TriggerDoConnectFailed;
      exit;
    end;

  IPV6 := StrToIPv6(addr, R);

  if not R then
    begin
      Error('ipv6 format error! %s', [addr]);
      TriggerDoConnectFailed;
      exit;
    end;

  p := FLinkVM.FindListen(IPV6, Port);
  if p = nil then
    begin
      Error('no remote listen %s port:%d', [IPv6ToStr(IPV6).Text, Port]);
      TriggerDoConnectFailed;
      exit;
    end;

  FVMClientIO.FIP := IPV6;
  FVMClientIO.FPort := Port;

  FLinkVM.SendConnecting(p^.FrameworkID, FFrameworkWithVM_ID, FVMClientIO.ID, IPV6, Port);
end;

procedure TZNet_WithP2PVM_Client.AsyncConnectC(addr: SystemString; Port: Word; const OnResult: TOnState_C);
var
  R: Boolean;
  IPV6: TIPV6;
  p: PP2PVMListen;
begin
  Disconnect;
  if FLinkVM = nil then
      RaiseInfo('no vm reference');
  FVMClientIO := TP2PVM_PeerIO.Create(self, nil);
  FVMClientIO.FLinkVM := FLinkVM;

  FVMConnected := False;

  FOnP2PVMAsyncConnectNotify_C := OnResult;
  FOnP2PVMAsyncConnectNotify_M := nil;
  FOnP2PVMAsyncConnectNotify_P := nil;
  if (FLinkVM = nil) or (FLinkVM.FOwner_IO = nil) then
    begin
      Error('no VM connect');
      TriggerDoConnectFailed;
      exit;
    end;

  if not FLinkVM.WasAuthed then
    begin
      Error('VM no auth');
      TriggerDoConnectFailed;
      exit;
    end;

  IPV6 := StrToIPv6(addr, R);

  if not R then
    begin
      Error('ipv6 format error! %s', [addr]);
      TriggerDoConnectFailed;
      exit;
    end;

  p := FLinkVM.FindListen(IPV6, Port);
  if p = nil then
    begin
      Error('no remote listen %s port:%d', [IPv6ToStr(IPV6).Text, Port]);
      TriggerDoConnectFailed;
      exit;
    end;

  FVMClientIO.FIP := IPV6;
  FVMClientIO.FPort := Port;

  FLinkVM.SendConnecting(p^.FrameworkID, FFrameworkWithVM_ID, FVMClientIO.ID, IPV6, Port);
end;

procedure TZNet_WithP2PVM_Client.AsyncConnectM(addr: SystemString; Port: Word; const OnResult: TOnState_M);
var
  R: Boolean;
  IPV6: TIPV6;
  p: PP2PVMListen;
begin
  Disconnect;
  if FLinkVM = nil then
      RaiseInfo('no vm reference');
  FVMClientIO := TP2PVM_PeerIO.Create(self, nil);
  FVMClientIO.FLinkVM := FLinkVM;

  FVMConnected := False;

  FOnP2PVMAsyncConnectNotify_C := nil;
  FOnP2PVMAsyncConnectNotify_M := OnResult;
  FOnP2PVMAsyncConnectNotify_P := nil;

  if (FLinkVM = nil) or (FLinkVM.FOwner_IO = nil) then
    begin
      Error('no VM connect');
      TriggerDoConnectFailed;
      exit;
    end;

  if not FLinkVM.WasAuthed then
    begin
      Error('VM no auth');
      TriggerDoConnectFailed;
      exit;
    end;

  IPV6 := StrToIPv6(addr, R);

  if not R then
    begin
      Error('ipv6 format error! %s', [addr]);
      TriggerDoConnectFailed;
      exit;
    end;

  p := FLinkVM.FindListen(IPV6, Port);
  if p = nil then
    begin
      Error('no remote listen %s port:%d', [IPv6ToStr(IPV6).Text, Port]);
      TriggerDoConnectFailed;
      exit;
    end;

  FVMClientIO.FIP := IPV6;
  FVMClientIO.FPort := Port;

  FLinkVM.SendConnecting(p^.FrameworkID, FFrameworkWithVM_ID, FVMClientIO.ID, IPV6, Port);
end;

procedure TZNet_WithP2PVM_Client.AsyncConnectP(addr: SystemString; Port: Word; const OnResult: TOnState_P);
var
  R: Boolean;
  IPV6: TIPV6;
  p: PP2PVMListen;
begin
  Disconnect;
  if FLinkVM = nil then
      RaiseInfo('no vm reference');
  FVMClientIO := TP2PVM_PeerIO.Create(self, nil);
  FVMClientIO.FLinkVM := FLinkVM;

  FVMConnected := False;

  FOnP2PVMAsyncConnectNotify_C := nil;
  FOnP2PVMAsyncConnectNotify_M := nil;
  FOnP2PVMAsyncConnectNotify_P := OnResult;

  if (FLinkVM = nil) or (FLinkVM.FOwner_IO = nil) then
    begin
      Error('no VM connect');
      TriggerDoConnectFailed;
      exit;
    end;

  if not FLinkVM.WasAuthed then
    begin
      Error('VM no auth');
      TriggerDoConnectFailed;
      exit;
    end;

  IPV6 := StrToIPv6(addr, R);

  if not R then
    begin
      Error('ipv6 format error! %s', [addr]);
      TriggerDoConnectFailed;
      exit;
    end;

  p := FLinkVM.FindListen(IPV6, Port);
  if p = nil then
    begin
      Error('no remote listen %s port:%d', [IPv6ToStr(IPV6).Text, Port]);
      TriggerDoConnectFailed;
      exit;
    end;

  FVMClientIO.FIP := IPV6;
  FVMClientIO.FPort := Port;

  FLinkVM.SendConnecting(p^.FrameworkID, FFrameworkWithVM_ID, FVMClientIO.ID, IPV6, Port);
end;

function TZNet_WithP2PVM_Client.Connect(addr: SystemString; Port: Word): Boolean;
var
  IPV6: TIPV6;
  p: PP2PVMListen;
  t: TTimeTick;
begin
  Disconnect;
  if FLinkVM = nil then
      RaiseInfo('no vm reference');
  FVMClientIO := TP2PVM_PeerIO.Create(self, nil);
  FVMClientIO.FLinkVM := FLinkVM;

  Result := False;

  FVMConnected := False;
  FOnP2PVMAsyncConnectNotify_C := nil;
  FOnP2PVMAsyncConnectNotify_M := nil;
  FOnP2PVMAsyncConnectNotify_P := nil;
  if (FLinkVM = nil) or (FLinkVM.FOwner_IO = nil) then
    begin
      Error('no VM connect');
      exit;
    end;

  if not FLinkVM.WasAuthed then
    begin
      Error('VM no auth');
      exit;
    end;

  IPV6 := StrToIPv6(addr, Result);

  if not Result then
    begin
      Error('ipv6 format error! %s', [addr]);
      exit;
    end;

  p := FLinkVM.FindListen(IPV6, Port);
  if p = nil then
    begin
      Error('no remote listen %s port:%d', [IPv6ToStr(IPV6).Text, Port]);
      exit;
    end;

  FVMClientIO.FIP := IPV6;
  FVMClientIO.FPort := Port;
  FLinkVM.SendConnecting(p^.FrameworkID, FFrameworkWithVM_ID, FVMClientIO.ID, IPV6, Port);

  t := GetTimeTick + 1000;
  while not FVMConnected do
    begin
      ProgressWaitSend(FVMClientIO);
      if GetTimeTick > t then
          Break;
    end;

  t := GetTimeTick + 2000;
  while (FVMConnected) and (not RemoteInited) do
    begin
      ProgressWaitSend(FVMClientIO);
      if GetTimeTick > t then
          Break;
    end;

  Result := (FVMConnected) and (RemoteInited);
end;

procedure TZNet_WithP2PVM_Client.AsyncConnectC(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_C);
var
  ParamBridge: TState_Param_Bridge;
begin
  ParamBridge := TState_Param_Bridge.Create;
  ParamBridge.Param1 := Param1;
  ParamBridge.Param2 := Param2;
  ParamBridge.OnNotifyC := OnResult;
  AsyncConnectM(addr, Port, ParamBridge.OnStateMethod);
end;

procedure TZNet_WithP2PVM_Client.AsyncConnectM(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_M);
var
  ParamBridge: TState_Param_Bridge;
begin
  ParamBridge := TState_Param_Bridge.Create;
  ParamBridge.Param1 := Param1;
  ParamBridge.Param2 := Param2;
  ParamBridge.OnNotifyM := OnResult;
  AsyncConnectM(addr, Port, ParamBridge.OnStateMethod);
end;

procedure TZNet_WithP2PVM_Client.AsyncConnectP(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_P);
var
  ParamBridge: TState_Param_Bridge;
begin
  ParamBridge := TState_Param_Bridge.Create;
  ParamBridge.Param1 := Param1;
  ParamBridge.Param2 := Param2;
  ParamBridge.OnNotifyP := OnResult;
  AsyncConnectM(addr, Port, ParamBridge.OnStateMethod);
end;

procedure TZNet_WithP2PVM_Client.Disconnect;
var
  __repeat__: TZNet_WithP2PVM_Client_Clone_Pool.TRepeat___;
begin
  if FP2PVM_ClonePool.Num > 0 then
    begin
      __repeat__ := FP2PVM_ClonePool.Repeat_();
      repeat
          __repeat__.Queue^.data.Disconnect;
      until not __repeat__.Next;
    end;

  if FVMClientIO <> nil then
      FVMClientIO.Disconnect;
end;

procedure TZNet_WithP2PVM_Client.DoBackCall_Progress(Sender: TZNet);
begin
  Sender.Progress;
end;

procedure TZNet_WithP2PVM_Client.ProgressWaitSend(P_IO: TPeerIO);
begin
  if FP2PVM_ProgressWaitSend_Busy then
      exit;

  FP2PVM_ProgressWaitSend_Busy := True;
  try
    if FLinkVM <> nil then
      begin
        if FLinkVM.FOwner_IO <> nil then
            FLinkVM.FOwner_IO.OwnerFramework.ProgressWaitSend(FLinkVM.FOwner_IO);
        FLinkVM.Progress;
        FLinkVM.ProgressZNet_M(DoBackCall_Progress);
      end;
    inherited ProgressWaitSend(P_IO);
  finally
      FP2PVM_ProgressWaitSend_Busy := False;
  end;
end;

