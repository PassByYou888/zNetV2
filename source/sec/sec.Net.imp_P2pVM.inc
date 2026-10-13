procedure TZNet_P2PVM.Hook_SendByteBuffer(const Sender: TPeerIO; const buff: PByte; siz: NativeInt);
var
  p: PP2PVMFragmentPacket;
begin
  if siz <= 0 then
      exit;

  if FAuthed then
    begin
      p := Build_P2PVM_Packet(siz, 0, 0, ZNet_Def_p2pVM_OwnerIOFragmentData, buff);
      p^.Build_P2PVM_Send_Buffer(FSendStream);
      FreeP2PVMPacket(p);
    end
  else
    begin
      FSendStream.WritePtr(buff, siz);
    end;
end;

procedure TZNet_P2PVM.Hook_SaveReceiveBuffer(const Sender: TPeerIO; const buff: Pointer; siz: Int64);
begin
  if siz <= 0 then
      exit;

  FReceiveStream.Position := FReceiveStream.Size;
  FReceiveStream.WritePtr(buff, siz);
end;

procedure TZNet_P2PVM.Hook_ProcessReceiveBuffer(const Sender: TPeerIO);
  function Extract_P2PVM_Receive_Buffer(var fPk: TP2PVMFragmentPacket; const Stream: TMem64): Integer;
  begin
    Result := 0;
    if Stream.Size < 13 then
      begin
        fPk.Init;
        exit;
      end;
    if Stream.Size < PCardinal(Stream.PositionAsPtr(0))^ + 13 then
      begin
        fPk.Init;
        exit;
      end;
    fPk.BuffSiz := PCardinal(Stream.PositionAsPtr(0))^;
    fPk.FrameworkID := PCardinal(Stream.PositionAsPtr(4))^;
    fPk.p2pID := PCardinal(Stream.PositionAsPtr(8))^;
    fPk.pkType := PByte(Stream.PositionAsPtr(12))^;
    if fPk.BuffSiz > 0 then
        fPk.buff := Stream.PositionAsPtr(13)
    else
        fPk.buff := nil;
    Result := fPk.BuffSiz + 13;
  end;

var
  i: Integer;
  LP: PP2PVMListen;
  p64: Int64;
  sourStream: TMem64;
  fPk: TP2PVMFragmentPacket;
  rPos: Integer;
begin
  if FReceiveStream.Size <= 0 then
      exit;

  if FOwner_IO <> nil then
    begin
      FOwner_IO.UpdateLastCommunicationTime;
      FOwner_IO.LastCommunicationTick_Received := FOwner_IO.FLastCommunicationTick;
      FOwner_IO.LastCommunicationTick_KeepAlive := FOwner_IO.LastCommunicationTick_Received;
    end;

  { p2p auth }
  if not FAuthed then
    begin
      if (FAuthWaiting) and (FReceiveStream.Size >= Length(FOwner_IO.FP2PVM_Auth_Token)) and
        (CompareMemory(@FOwner_IO.FP2PVM_Auth_Token[0], FReceiveStream.Memory, Length(FOwner_IO.FP2PVM_Auth_Token))) then
        begin
          FSendStream.Clear;

          if not FAuthSending then
              AuthVM;

          FAuthWaiting := False;
          FAuthed := True;
          FAuthSending := False;

          { sync listen state }
          for i := 0 to FFrameworkListenPool.Count - 1 do
            begin
              LP := FFrameworkListenPool[i];
              SendListenState(LP^.FrameworkID, LP^.ListenHost, LP^.ListenPort, LP^.Listening);
            end;

          { send auth successed token }
          AuthSuccessed;

          { fill fragment buffer }
          p64 := Length(FOwner_IO.FP2PVM_Auth_Token);
          sourStream := TMem64.Create;
          FReceiveStream.Position := p64;
          if FReceiveStream.Size - FReceiveStream.Position > 0 then
              sourStream.CopyFrom(FReceiveStream, FReceiveStream.Size - FReceiveStream.Position);
          DisposeObject(FReceiveStream);
          FReceiveStream := sourStream;

          if not FQuietMode then
              FOwner_IO.Print('VM Authentication Success');
        end
      else if FAuthWaiting then
          exit
      else
        begin
          { safe process fragment }
          if FReceiveStream.Size >= Length(FOwner_IO.FP2PVM_Auth_Token) then
            begin
              FOwner_IO.OwnerFramework.Framework_Internal_Save_Receive_Buffer(FOwner_IO, FReceiveStream.Memory, FReceiveStream.Size);
              FReceiveStream.Clear;
              FOwner_IO.OwnerFramework.Framework_Internal_Process_Receive_Buffer(FOwner_IO);
            end;
          exit;
        end;
    end;

  if FReceiveStream.Size < 13 then
      exit;

  sourStream := TMem64.Create;
  p64 := 0;
  sourStream.SetPointerWithProtectedMode(FReceiveStream.PositionAsPtr(p64), FReceiveStream.Size - p64);

  while sourStream.Size > 0 do
    begin
      fPk.Init;
      rPos := Extract_P2PVM_Receive_Buffer(fPk, sourStream);
      if rPos > 0 then
        begin
          { decrypt p2pVM packet data }
          if fPk.BuffSiz > 0 then
              FOwner_IO.FP2PVM_Cipher.Decrypt(fPk.buff, fPk.BuffSiz);
          { protocol support }
          if fPk.pkType = ZNet_Def_p2pVM_echoing then
              ReceivedEchoing(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_echo then
              ReceivedEcho(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_AuthSuccessed then
            begin
              if Assigned(OnAuthSuccessOnesNotify) then
                begin
                  try
                      OnAuthSuccessOnesNotify(self);
                  except
                  end;
                  OnAuthSuccessOnesNotify := nil;
                end;
            end
          else if fPk.pkType = ZNet_Def_p2pVM_Listen then
              ReceivedListen(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_ListenState then
              ReceivedListenState(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_Connecting then
              ReceivedConnecting(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_ConnectedReponse then
              ReceivedConnectedReponse(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_Disconnect then
              ReceivedDisconnect(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_LogicFragmentData then
              ReceivedLogicFragmentData(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else if fPk.pkType = ZNet_Def_p2pVM_OwnerIOFragmentData then
              ReceivedOwnerIOFragmentData(fPk.FrameworkID, fPk.p2pID, fPk.buff, fPk.BuffSiz)
          else
            begin
              FOwner_IO.PrintError('VM protocol header errror');
              DoStatus(@fPk, SizeOf(fPk), 40);
            end;

          { fill buffer }
          inc(p64, rPos);
          if FReceiveStream.Size - p64 >= 13 then
              sourStream.SetPointerWithProtectedMode(FReceiveStream.PositionAsPtr(p64), FReceiveStream.Size - p64)
          else
              Break;
        end
      else
          Break;
    end;

  DisposeObject(sourStream);

  if p64 > 0 then
    begin
      sourStream := TMem64.CustomCreate(64 * 1024);
      FReceiveStream.Position := p64;
      if FReceiveStream.Size - FReceiveStream.Position > 0 then
          sourStream.CopyFrom(FReceiveStream, FReceiveStream.Size - FReceiveStream.Position);
      DisposeObject(FReceiveStream);
      FReceiveStream := sourStream;
    end;
end;

procedure TZNet_P2PVM.Hook_ClientDestroy(const Sender: TPeerIO);
begin
  CloseP2PVMTunnel;
  Sender.OwnerFramework.Framework_Internal_IO_Destroy(Sender);
end;

procedure TZNet_P2PVM.SendVMBuffer(const buff: Pointer; const siz: NativeInt);
begin
  FOwner_IO.WriteBufferOpen;
  FOwner_IO.OwnerFramework.Framework_Internal_Send_Byte_Buffer(FOwner_IO, buff, siz);
  FOwner_IO.WriteBufferFlush;
  FOwner_IO.WriteBufferClose;
end;

procedure TZNet_P2PVM.ReceivedEchoing(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
begin
  echoBuffer(buff, siz);
end;

procedure TZNet_P2PVM.ReceivedEcho(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
type
  TBuf = array [0 .. 7] of Byte;
  PBuf = ^TBuf;
var
  p: PBuf;
  u64ptr: UInt64;
  echoPtr: PP2PVM_ECHO;
  i: Integer;
begin
  if siz <> SizeOf(TBuf) then
    begin
      FOwner_IO.PrintError('echoing protocol with buffer error!');
      if buff <> nil then
        if not FQuietMode then
            DoStatus(buff, siz, 40);
      exit;
    end;
  p := @buff^;
  u64ptr := PUInt64(@p^[0])^;
  echoPtr := Pointer(u64ptr);
  if echoPtr = nil then
      exit;

  i := 0;
  while i < FWaitEchoList.Count do
    begin
      if FWaitEchoList[i] = echoPtr then
        begin
          FWaitEchoList.Delete(i);
          try
            if Assigned(echoPtr^.OnEcho_C) then
                echoPtr^.OnEcho_C(True)
            else if Assigned(echoPtr^.OnEcho_M) then
                echoPtr^.OnEcho_M(True)
            else if Assigned(echoPtr^.OnEcho_P) then
                echoPtr^.OnEcho_P(True);
          except
          end;

          try
              Dispose(echoPtr);
          except
          end;
        end
      else
          inc(i);
    end;
end;

procedure TZNet_P2PVM.ReceivedListen(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
type
  TBuf = array [0 .. 18] of Byte;
  PBuf = ^TBuf;
var
  p: PBuf;
  IPV6: TIPV6;
  Port: Word;
  Listening: Boolean;
  LP: PP2PVMListen;
begin
  if siz <> SizeOf(TBuf) then
    begin
      FOwner_IO.PrintError('listen protocol with buffer error!');
      if buff <> nil then
        if not FQuietMode then
            DoStatus(buff, siz, 40);
      exit;
    end;
  p := @buff^;
  IPV6 := PIPV6(@p^[0])^;
  Port := PWORD(@p^[16])^;
  Listening := PBoolean(@p^[18])^;

  if p2pID <> 0 then
    begin
      FOwner_IO.PrintError('listen protocol error! IO ID:%d', [p2pID]);
      exit;
    end;

  LP := FindListen(IPV6, Port);
  if Listening then
    begin
      if LP = nil then
        begin
          New(LP);
          LP^.FrameworkID := FrameworkID;
          LP^.ListenHost := IPV6;
          LP^.ListenPort := Port;
          LP^.Listening := True;
          FFrameworkListenPool.Add(LP);
          SendListenState(FrameworkID, IPV6, Port, True);
        end
      else
        begin
          LP^.Listening := True;
          SendListenState(FrameworkID, IPV6, Port, True);
        end;
    end
  else
    begin
      DeleteListen(IPV6, Port);
      SendListenState(FrameworkID, IPV6, Port, False);
    end;
end;

procedure TZNet_P2PVM.ReceivedListenState(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
type
  TBuf = array [0 .. 18] of Byte;
  PBuf = ^TBuf;
var
  c: TZNet;
  p: PBuf;
  IPV6: TIPV6;
  Port: Word;
  Listening: Boolean;
  LP: PP2PVMListen;
begin
  if siz <> SizeOf(TBuf) then
    begin
      FOwner_IO.PrintError('Virtual listen state protocol with buffer error!');
      if buff <> nil then
        if not FQuietMode then
            DoStatus(buff, siz, 40);
      exit;
    end;
  p := @buff^;
  IPV6 := PIPV6(@p^[0])^;
  Port := PWORD(@p^[16])^;
  Listening := PBoolean(@p^[18])^;

  if p2pID <> 0 then
    begin
      FOwner_IO.PrintError('Virtual listen state protocol error! IO ID:%d', [p2pID]);
      exit;
    end;

  LP := FindListen(IPV6, Port);
  if Listening then
    begin
      if LP = nil then
        begin
          New(LP);
          LP^.FrameworkID := FrameworkID;
          LP^.ListenHost := IPV6;
          LP^.ListenPort := Port;
          LP^.Listening := True;
          FFrameworkListenPool.Add(LP);
        end
      else
        begin
          LP^.Listening := True;
        end;
      if not FQuietMode then
          FOwner_IO.Print('Virtual Remote Listen state Activted "%s port:%d"', [IPv6ToStr(IPV6).Text, Port]);
    end
  else
    begin
      DeleteListen(IPV6, Port);
      if not FQuietMode then
          FOwner_IO.Print('Virtual Remote Listen state Close "%s port:%d"', [IPv6ToStr(IPV6).Text, Port]);
    end;

  c := TZNet(FFrameworkPool[FrameworkID]);
  if c is TZNet_WithP2PVM_Server then
    begin
      TZNet_WithP2PVM_Server(c).ListenState(self, IPV6, Port, Listening);
      SendListenState(TZNet_WithP2PVM_Server(c).FFrameworkWithVM_ID, IPV6, Port, Listening);
    end;
end;

procedure TZNet_P2PVM.ReceivedConnecting(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
type
  TBuf = array [0 .. 25] of Byte;
  PBuf = ^TBuf;
var
  c: TZNet;
  p: PBuf;
  Remote_frameworkID: Cardinal;
  Remote_p2pID: Cardinal;
  IPV6: TIPV6;
  Port: Word;
  Allowed: Boolean;
begin
  if siz <> SizeOf(TBuf) then
    begin
      FOwner_IO.PrintError('connect request with buffer error!');
      if buff <> nil then
          DoStatus(buff, siz, 40);
      exit;
    end;
  p := @buff^;
  Remote_frameworkID := PCardinal(@p^[0])^;
  Remote_p2pID := PCardinal(@p^[4])^;
  IPV6 := PIPV6(@p^[8])^;
  Port := PWORD(@p^[24])^;

  if p2pID <> 0 then
    begin
      SendDisconnect(Remote_frameworkID, Remote_p2pID);
      FOwner_IO.PrintError('connect request with protocol error! IO ID:%d', [p2pID]);
      exit;
    end;

  c := TZNet(FFrameworkPool[FrameworkID]);
  if c is TZNet_WithP2PVM_Server then
    begin
      Allowed := True;
      TZNet_WithP2PVM_Server(c).Connecting(self, Remote_frameworkID, FrameworkID, IPV6, Port, Allowed);

      if not Allowed then
        begin
          SendDisconnect(Remote_frameworkID, 0);
          exit;
        end;
    end
  else
    begin
      SendDisconnect(Remote_frameworkID, Remote_p2pID);
    end;
end;

procedure TZNet_P2PVM.ReceivedConnectedReponse(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
type
  TBuf = array [0 .. 7] of Byte;
  PBuf = ^TBuf;
var
  c: TZNet;
  p: PBuf;
  Remote_frameworkID: Cardinal;
  Remote_p2pID: Cardinal;
begin
  if siz <> SizeOf(TBuf) then
    begin
      FOwner_IO.PrintError('connect request with buffer error!');
      if buff <> nil then
          DoStatus(buff, siz, 40);
      exit;
    end;

  c := TZNet(FFrameworkPool[FrameworkID]);
  if c is TZNet_WithP2PVM_Client then
    begin
      p := @buff^;
      Remote_frameworkID := PCardinal(@p^[0])^;
      Remote_p2pID := PCardinal(@p^[4])^;

      { trigger connect reponse }
      TZNet_WithP2PVM_Client(c).VMConnectSuccessed(self, Remote_frameworkID, Remote_p2pID, FrameworkID);

      if not FQuietMode then
          FOwner_IO.Print('connecting reponse from frameworkID: %d p2pID: %d', [Remote_frameworkID, Remote_p2pID]);
    end;
end;

procedure TZNet_P2PVM.ReceivedDisconnect(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
var
  c: TZNet;
  LocalVMc: TP2PVM_PeerIO;
begin
  c := TZNet(FFrameworkPool[FrameworkID]);
  if c is TZNet_WithP2PVM_Client then
    begin
      if TZNet_WithP2PVM_Client(c).FVMClientIO <> nil then
          TZNet_WithP2PVM_Client(c).FVMClientIO.FDestroySyncRemote := False;
      TZNet_WithP2PVM_Client(c).VMDisconnect(self);
    end
  else if c is TZNet_WithP2PVM_Server then
    begin
      LocalVMc := TP2PVM_PeerIO(c.FPeerIO_HashPool[p2pID]);
      if LocalVMc = nil then
        begin
          if not FQuietMode then
              FOwner_IO.Print('disconnect protocol no p2pID:%d', [p2pID]);
          exit;
        end;
      LocalVMc.FDestroySyncRemote := False;
      LocalVMc.Disconnect;
    end
  else if not FQuietMode then
      FOwner_IO.Print('disconnect protocol no frameworkID: %d', [FrameworkID]);
end;

procedure TZNet_P2PVM.ReceivedLogicFragmentData(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
var
  c: TZNet;
  LocalVMc: TPeerIO;
begin
  AtomInc(FOwner_IO.OwnerFramework.Statistics[TStatisticsType.stReceiveSize], siz);
  c := TZNet(FFrameworkPool[FrameworkID]);
  if c is TZNet_WithP2PVM_Server then
    begin
      LocalVMc := c.FPeerIO_HashPool[p2pID];
      if LocalVMc <> nil then
        begin
          LocalVMc.Write_Physics_Fragment(buff, siz);
        end
      else
        begin
          FOwner_IO.PrintError('fragment Data p2pID error: p2pID:%d buffer size:%d', [p2pID, siz]);
          DoStatus(buff, umlMin(siz, 164), 40);
        end;
    end
  else if c is TZNet_WithP2PVM_Client then
    begin
      LocalVMc := TZNet_WithP2PVM_Client(c).FVMClientIO;
      if LocalVMc <> nil then
        begin
          LocalVMc.Write_Physics_Fragment(buff, siz);
        end
      else
        begin
          FOwner_IO.PrintError('LocalVM [%d] error: no interface', [FrameworkID]);
        end;
    end
  else
    begin
      FOwner_IO.PrintError('fragment Data frameworkID error: frameworkID:%d buffer size:%d', [FrameworkID, siz]);
      DoStatus(buff, umlMin(siz, 164), 40);
    end;
end;

procedure TZNet_P2PVM.ReceivedOwnerIOFragmentData(const FrameworkID, p2pID: Cardinal; const buff: PByte; const siz: Cardinal);
begin
  if FOwner_IO = nil then
      exit;
  FOwner_IO.OwnerFramework.Framework_Internal_Save_Receive_Buffer(FOwner_IO, buff, siz);
  FOwner_IO.OwnerFramework.Framework_Internal_Process_Receive_Buffer(FOwner_IO);
end;

procedure TZNet_P2PVM.DoProcessPerClientFragmentSend(P_IO: TPeerIO);
var
  p: PP2PVMFragmentPacket;
begin
  if TP2PVM_PeerIO(P_IO).FLinkVM <> self then
      exit;

  if TP2PVM_PeerIO(P_IO).FSendQueue.Num > 0 then
    begin
      p := TP2PVM_PeerIO(P_IO).FSendQueue.current^.data;
      TP2PVM_PeerIO(P_IO).FSendQueue.Next;
      p^.Build_P2PVM_Send_Buffer(FSendStream);
      FreeP2PVMPacket(p);
    end;
end;

procedure TZNet_P2PVM.DoPerClientClose(P_IO: TPeerIO);
begin
  if TP2PVM_PeerIO(P_IO).FLinkVM = self then
    begin
      P_IO.Disconnect;
    end;
end;

constructor TZNet_P2PVM.Create(HashPoolSize: Integer);
begin
  inherited Create;
  FOwner_IO := nil;
  FAuthWaiting := False;
  FAuthed := False;
  FAuthSending := False;
  FFrameworkPool := TUInt32HashObjectList.CustomCreate(HashPoolSize);
  FFrameworkPool.AutoFreeData := False;
  FFrameworkPool.AccessOptimization := False;
  FFrameworkListenPool := TP2PVM_Listen_List.Create;
  FMaxVMFragmentSize := ZNet_Def_P2PVM_MaxVMFragmentSize;
  FProgress_Send_Size := ZNet_Def_P2PVM_Progress_Send_Size;
  FQuietMode := {$IFDEF Communication_QuietMode}True{$ELSE Communication_QuietMode}False{$ENDIF Communication_QuietMode};
  FReceiveStream := TMem64.CustomCreate(64 * 1024);
  FSendStream := TMem64.CustomCreate(64 * 1024);
  FWaitEchoList := TP2PVM_ECHO_List.Create;
  FVMID := 0;
  OnAuthSuccessOnesNotify := nil;
end;

destructor TZNet_P2PVM.Destroy;
var
  L: TCore_List;
  i: Integer;
  p: PUInt32HashListObjectStruct;
  OnEchoPtr: PP2PVM_ECHO;
begin
  // safe remove LinkVM
  L := TCore_List.Create;
  FFrameworkPool.GetListData(L);
  try
    for i := 0 to L.Count - 1 do
      begin
        p := L[i];
        if p^.data is TZNet_WithP2PVM_Server then
            TZNet_WithP2PVM_Server(p^.data).FLinkVMPool.Delete(FVMID)
        else if p^.data is TZNet_WithP2PVM_Client then
          begin
            TZNet_WithP2PVM_Client(p^.data).FLinkVM := nil;
            TZNet_WithP2PVM_Client(p^.data).Disconnect;
          end;
      end;
  except
  end;
  DisposeObject(L);
  FFrameworkPool.Clear;

  // remove echo data
  try
    for i := 0 to FWaitEchoList.Count - 1 do
      begin
        OnEchoPtr := FWaitEchoList[i];
        Dispose(OnEchoPtr);
      end;
  except
  end;
  FWaitEchoList.Clear;

  // close Owner-IO
  if FOwner_IO <> nil then
      CloseP2PVMTunnel;

  // clear listen
  ClearListen;

  // free
  DisposeObject(FWaitEchoList);
  DisposeObject(FReceiveStream);
  DisposeObject(FSendStream);
  DisposeObject(FFrameworkPool);
  DisposeObject(FFrameworkListenPool);
  inherited Destroy;
end;

function TZNet_P2PVM.Build_P2PVM_Packet(BuffSiz, FrameworkID, p2pID: Cardinal; pkType: Byte; buff: PByte): PP2PVMFragmentPacket;
var
  p: PP2PVMFragmentPacket;
begin
  New(p);
  p^.BuffSiz := BuffSiz;
  p^.FrameworkID := FrameworkID;
  p^.p2pID := p2pID;
  p^.pkType := pkType;
  if (buff <> nil) and (p^.BuffSiz > 0) then
    begin
      p^.buff := System.GetMemory(p^.BuffSiz);
      CopyPtr(buff, p^.buff, p^.BuffSiz);
      { encrypt p2pVM packet data }
      if p^.BuffSiz > 0 then
          FOwner_IO.FP2PVM_Cipher.Encrypt(p^.buff, p^.BuffSiz);
    end
  else
      p^.buff := nil;

  Result := p;
end;

class procedure TZNet_P2PVM.FreeP2PVMPacket(p: PP2PVMFragmentPacket);
begin
  if (p^.buff <> nil) and (p^.BuffSiz > 0) then
      System.FreeMemory(p^.buff);
  Dispose(p);
end;

procedure TZNet_P2PVM.Progress;
var
  i: Integer;
  p: PUInt32HashListObjectStruct;
  lsiz: Int64;
  OnEchoPtr: PP2PVM_ECHO;
begin
  if FOwner_IO = nil then
      exit;

  if FOwner_IO.Disable_Progress then
      exit;

  { echo and keepalive simulate }
  i := 0;
  while i < FWaitEchoList.Count do
    begin
      OnEchoPtr := FWaitEchoList[i];
      if OnEchoPtr^.TimeOut_ < GetTimeTick then
        begin
          FWaitEchoList.Delete(i);

          try
            if Assigned(OnEchoPtr^.OnEcho_C) then
                OnEchoPtr^.OnEcho_C(False)
            else if Assigned(OnEchoPtr^.OnEcho_M) then
                OnEchoPtr^.OnEcho_M(False)
            else if Assigned(OnEchoPtr^.OnEcho_P) then
                OnEchoPtr^.OnEcho_P(False);
          except
          end;

          try
              Dispose(OnEchoPtr);
          except
          end;
        end
      else
          inc(i);
    end;

  if (FOwner_IO = nil) or FOwner_IO.Disable_Progress or (not FOwner_IO.WriteBuffer_is_NULL) then
      exit;

  { real send buffer }
  try
    if FSendStream.Size > 0 then
      begin
        SendVMBuffer(FSendStream.Memory, FSendStream.Size);
        FSendStream.Clear;
      end;
  except
  end;

  if not FAuthed then
      exit;

  { fragment Packet }
  while True do
    begin
      repeat
        lsiz := FSendStream.Size;
        if (FFrameworkPool.Count > 0) then
          begin
            i := 0;
            p := FFrameworkPool.FirstPtr;
            while i < FFrameworkPool.Count do
              begin
                TZNet(p^.data).FastProgressPeerIOM(DoProcessPerClientFragmentSend);
                inc(i);
                p := p^.Next;
              end;
          end;
      until (FSendStream.Size = lsiz) or (FSendStream.Size >= lsiz + FProgress_Send_Size);

      if FSendStream.Size > 0 then
        begin
          SendVMBuffer(FSendStream.Memory, FSendStream.Size);
          FSendStream.Clear;
        end
      else
          Break;
    end;
end;

procedure TZNet_P2PVM.ProgressZNet_C(const OnBackcall: TZNet_List_C);
var
  i: Integer;
  p: PUInt32HashListObjectStruct;
begin
  if (FFrameworkPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      i := 0;
      p := FFrameworkPool.FirstPtr;
      while i < FFrameworkPool.Count do
        begin
          try
              OnBackcall(TZNet(p^.data));
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TZNet_P2PVM.ProgressZNet_M(const OnBackcall: TZNet_List_M);
var
  i: Integer;
  p: PUInt32HashListObjectStruct;
begin
  if (FFrameworkPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      i := 0;
      p := FFrameworkPool.FirstPtr;
      while i < FFrameworkPool.Count do
        begin
          try
              OnBackcall(TZNet(p^.data));
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TZNet_P2PVM.ProgressZNet_P(const OnBackcall: TZNet_List_P);
var
  i: Integer;
  p: PUInt32HashListObjectStruct;
begin
  if (FFrameworkPool.Count > 0) and (Assigned(OnBackcall)) then
    begin
      i := 0;
      p := FFrameworkPool.FirstPtr;
      while i < FFrameworkPool.Count do
        begin
          try
              OnBackcall(TZNet(p^.data));
          except
          end;
          inc(i);
          p := p^.Next;
        end;
    end;
end;

procedure TZNet_P2PVM.OpenP2PVMTunnel(c: TPeerIO);
begin
  FOwner_IO := c;
  FAuthWaiting := False;
  FAuthed := False;
  FAuthSending := False;
  FReceiveStream.Clear;
  FSendStream.Clear;

  { install tunnel driver }
  try
    FOwner_IO.On_Internal_Send_Byte_Buffer := Hook_SendByteBuffer;
    FOwner_IO.On_Internal_Save_Receive_Buffer := Hook_SaveReceiveBuffer;
    FOwner_IO.On_Internal_Process_Receive_Buffer := Hook_ProcessReceiveBuffer;
    FOwner_IO.OnDestroy := Hook_ClientDestroy;
  except
  end;

  if not FQuietMode then
      FOwner_IO.Print('Open VM P2P Tunnel ' + FOwner_IO.PeerIP);
end;

procedure TZNet_P2PVM.CloseP2PVMTunnel;
var
  i: Integer;
  OnEchoPtr: PP2PVM_ECHO;
  p: PUInt32HashListObjectStruct;
begin
  for i := 0 to FWaitEchoList.Count - 1 do
    begin
      OnEchoPtr := FWaitEchoList[i];
      Dispose(OnEchoPtr);
    end;
  FWaitEchoList.Clear;

  OnAuthSuccessOnesNotify := nil;

  if (FFrameworkPool.Count > 0) then
    begin
      i := 0;
      p := FFrameworkPool.FirstPtr;
      while i < FFrameworkPool.Count do
        begin
          if p^.data is TZNet_WithP2PVM_Server then
            begin
              TZNet_WithP2PVM_Server(p^.data).ProgressPeerIOM(DoPerClientClose);
              TZNet_WithP2PVM_Server(p^.data).FLinkVMPool.Delete(FVMID);
            end
          else if p^.data is TZNet_WithP2PVM_Client then
            begin
              TZNet_WithP2PVM_Client(p^.data).ProgressPeerIOM(DoPerClientClose);
              TZNet_WithP2PVM_Client(p^.data).FLinkVM := nil;
            end;
          inc(i);
          p := p^.Next;
        end;
    end;

  FAuthWaiting := False;
  FAuthed := False;
  FAuthSending := False;
  FReceiveStream.Clear;
  FSendStream.Clear;

  if FOwner_IO = nil then
      exit;

  try
    FOwner_IO.On_Internal_Send_Byte_Buffer := FOwner_IO.OwnerFramework.Framework_Internal_Send_Byte_Buffer;
    FOwner_IO.On_Internal_Save_Receive_Buffer := FOwner_IO.OwnerFramework.Framework_Internal_Save_Receive_Buffer;
    FOwner_IO.On_Internal_Process_Receive_Buffer := FOwner_IO.OwnerFramework.Framework_Internal_Process_Receive_Buffer;
    FOwner_IO.OnDestroy := FOwner_IO.OwnerFramework.Framework_Internal_IO_Destroy;
  except
  end;

  if not FQuietMode then
      FOwner_IO.Print('Close VM P2P Tunnel ' + FOwner_IO.PeerIP);

  FOwner_IO := nil;
end;

procedure TZNet_P2PVM.InstallLogicFramework(Inst: TZNet);
var
  i: Integer;
  LP: PP2PVMListen;
begin
  Owner_IO.DoP2PVM_InstallLogicFramework(Inst);

  if (Inst is TZNet_CustomStableServer) then
    begin
      InstallLogicFramework(TZNet_CustomStableServer(Inst).OwnerIOServer);
      exit;
    end;
  if (Inst is TZNet_CustomStableClient) then
    begin
      InstallLogicFramework(TZNet_CustomStableClient(Inst).OwnerIOClient);
      exit;
    end;

  if Inst is TZNet_WithP2PVM_Server then
    begin
      if TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID <> 0 then
        begin
          if FFrameworkPool.Exists(TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID) then
              exit;
        end
      else
        begin
          if FFrameworkPool.Count > 0 then
              TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID := FFrameworkPool.LastPtr^.u32
          else
              TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID := 1;
          while FFrameworkPool.Exists(TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID) do
              inc(TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID);
        end;

      TZNet_WithP2PVM_Server(Inst).FLinkVMPool.Add(FVMID, self, True);
      FFrameworkPool.Add(TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID, Inst, True);
      for i := 0 to TZNet_WithP2PVM_Server(Inst).ListenCount - 1 do
        begin
          LP := TZNet_WithP2PVM_Server(Inst).GetListen(i);
          SendListen(TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID, LP^.ListenHost, LP^.ListenPort, LP^.Listening);
        end;
    end
  else if Inst is TZNet_WithP2PVM_Client then
    begin
      if TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID <> 0 then
        begin
          if FFrameworkPool.Exists(TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID) then
              exit;
        end
      else
        begin
          if FFrameworkPool.Count > 0 then
              TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID := FFrameworkPool.LastPtr^.u32
          else
              TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID := 1;
          while FFrameworkPool.Exists(TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID) do
              inc(TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID);
        end;

      TZNet_WithP2PVM_Client(Inst).FLinkVM := self;
      FFrameworkPool.Add(TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID, Inst, True);
    end
  else
      RaiseInfo('illegal p2pVM.');
end;

procedure TZNet_P2PVM.UninstallLogicFramework(Inst: TZNet);
var
  i: Integer;
  LP: PP2PVMListen;
begin
  Owner_IO.DoP2PVM_UninstallLogicFramework(Inst);

  if (Inst is TZNet_CustomStableServer) then
    begin
      UninstallLogicFramework(TZNet_CustomStableServer(Inst).OwnerIOServer);
      exit;
    end;
  if (Inst is TZNet_CustomStableClient) then
    begin
      UninstallLogicFramework(TZNet_CustomStableClient(Inst).OwnerIOClient);
      exit;
    end;

  if Inst is TZNet_WithP2PVM_Server then
    begin
      TZNet_WithP2PVM_Server(Inst).FLinkVMPool.Delete(FVMID);
      FFrameworkPool.Delete(TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID);

      i := 0;
      while i < FFrameworkListenPool.Count do
        begin
          LP := FFrameworkListenPool[i];
          if LP^.FrameworkID = TZNet_WithP2PVM_Server(Inst).FFrameworkWithVM_ID then
            begin
              Dispose(LP);
              FFrameworkListenPool.Delete(i);
            end
          else
              inc(i);
        end;
    end
  else if Inst is TZNet_WithP2PVM_Client then
    begin
      TZNet_WithP2PVM_Client(Inst).Disconnect;
      TZNet_WithP2PVM_Client(Inst).FLinkVM := nil;
      FFrameworkPool.Delete(TZNet_WithP2PVM_Client(Inst).FFrameworkWithVM_ID);
    end
  else
      RaiseInfo('illegal p2pVM.');
end;

procedure TZNet_P2PVM.AuthWaiting;
begin
  if FOwner_IO = nil then
      exit;
  FAuthWaiting := True;
end;

procedure TZNet_P2PVM.AuthVM;
begin
  if FOwner_IO = nil then
      exit;
  if not FAuthed then
    if not FAuthSending then
      begin
        FSendStream.WritePtr(@FOwner_IO.FP2PVM_Auth_Token[0], Length(FOwner_IO.FP2PVM_Auth_Token));
        FAuthSending := True;
        FAuthWaiting := True;
      end;
end;

procedure TZNet_P2PVM.AuthSuccessed;
var
  p: PP2PVMFragmentPacket;
begin
  p := Build_P2PVM_Packet(0, 0, 0, ZNet_Def_p2pVM_AuthSuccessed, nil);

  FSendStream.Position := FSendStream.Size;
  p^.Build_P2PVM_Send_Buffer(FSendStream);
  FreeP2PVMPacket(p);
end;

procedure TZNet_P2PVM.echoing(const OnEchoPtr: PP2PVM_ECHO; TimeOut_: TTimeTick);
var
  u64ptr: UInt64;
  p: PP2PVMFragmentPacket;
  i: Integer;
begin
  if (FOwner_IO = nil) or (not WasAuthed) then
    begin
      if OnEchoPtr <> nil then
        begin
          i := 0;
          while i < FWaitEchoList.Count do
            begin
              if FWaitEchoList[i] = OnEchoPtr then
                  FWaitEchoList.Delete(i)
              else
                  inc(i);
            end;

          try
            if Assigned(OnEchoPtr^.OnEcho_C) then
                OnEchoPtr^.OnEcho_C(False)
            else if Assigned(OnEchoPtr^.OnEcho_M) then
                OnEchoPtr^.OnEcho_M(False)
            else if Assigned(OnEchoPtr^.OnEcho_P) then
                OnEchoPtr^.OnEcho_P(False);
          except
          end;

          Dispose(OnEchoPtr);
        end;
      exit;
    end;

  u64ptr := UInt64(OnEchoPtr);
  p := Build_P2PVM_Packet(8, 0, 0, ZNet_Def_p2pVM_echoing, @u64ptr);

  FSendStream.Position := FSendStream.Size;
  p^.Build_P2PVM_Send_Buffer(FSendStream);
  FreeP2PVMPacket(p);

  FWaitEchoList.Add(OnEchoPtr);
end;

procedure TZNet_P2PVM.echoingC(const OnResult: TOnState_C; TimeOut_: TTimeTick);
var
  p: PP2PVM_ECHO;
begin
  New(p);
  p^.OnEcho_C := OnResult;
  p^.OnEcho_M := nil;
  p^.OnEcho_P := nil;
  p^.TimeOut_ := GetTimeTick + TimeOut_;
  echoing(p, TimeOut_);
end;

procedure TZNet_P2PVM.echoingM(const OnResult: TOnState_M; TimeOut_: TTimeTick);
var
  p: PP2PVM_ECHO;
begin
  New(p);
  p^.OnEcho_C := nil;
  p^.OnEcho_M := OnResult;
  p^.OnEcho_P := nil;
  p^.TimeOut_ := GetTimeTick + TimeOut_;
  echoing(p, TimeOut_);
end;

procedure TZNet_P2PVM.echoingP(const OnResult: TOnState_P; TimeOut_: TTimeTick);
var
  p: PP2PVM_ECHO;
begin
  New(p);
  p^.OnEcho_C := nil;
  p^.OnEcho_M := nil;
  p^.OnEcho_P := OnResult;
  p^.TimeOut_ := GetTimeTick + TimeOut_;
  echoing(p, TimeOut_);
end;

procedure TZNet_P2PVM.echoBuffer(const buff: Pointer; const siz: NativeInt);
var
  p: PP2PVMFragmentPacket;
begin
  if (FOwner_IO = nil) or (not WasAuthed) then
      exit;
  p := Build_P2PVM_Packet(siz, 0, 0, ZNet_Def_p2pVM_echo, buff);

  FSendStream.Position := FSendStream.Size;
  p^.Build_P2PVM_Send_Buffer(FSendStream);
  FreeP2PVMPacket(p);
end;

procedure TZNet_P2PVM.SendListen(const FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; const Listening: Boolean);
var
  LP: PP2PVMListen;
  c: TZNet;
  RBuf: array [0 .. 18] of Byte;
  p: PP2PVMFragmentPacket;
begin
  if (FOwner_IO = nil) or (not WasAuthed) then
    begin
      LP := FindListen(IPV6, Port);
      if Listening then
        begin
          if LP = nil then
            begin
              New(LP);
              LP^.FrameworkID := FrameworkID;
              LP^.ListenHost := IPV6;
              LP^.ListenPort := Port;
              LP^.Listening := True;
              FFrameworkListenPool.Add(LP);
            end
          else
              LP^.Listening := True;
        end
      else
          DeleteListen(IPV6, Port);

      c := TZNet(FFrameworkPool[FrameworkID]);
      if c is TZNet_WithP2PVM_Server then
        begin
          TZNet_WithP2PVM_Server(c).ListenState(self, IPV6, Port, Listening);
          SendListenState(TZNet_WithP2PVM_Server(c).FFrameworkWithVM_ID, IPV6, Port, Listening);
        end;
    end
  else
    begin
      PIPV6(@RBuf[0])^ := IPV6;
      PWORD(@RBuf[16])^ := Port;
      PBoolean(@RBuf[18])^ := Listening;
      p := Build_P2PVM_Packet(SizeOf(RBuf), FrameworkID, 0, ZNet_Def_p2pVM_Listen, @RBuf[0]);

      FSendStream.Position := FSendStream.Size;
      p^.Build_P2PVM_Send_Buffer(FSendStream);
      FreeP2PVMPacket(p);
    end;
end;

procedure TZNet_P2PVM.SendListenState(const FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; const Listening: Boolean);
var
  RBuf: array [0 .. 18] of Byte;
  p: PP2PVMFragmentPacket;
begin
  if (FOwner_IO = nil) or (not WasAuthed) then
      exit;
  PIPV6(@RBuf[0])^ := IPV6;
  PWORD(@RBuf[16])^ := Port;
  PBoolean(@RBuf[18])^ := Listening;
  p := Build_P2PVM_Packet(SizeOf(RBuf), FrameworkID, 0, ZNet_Def_p2pVM_ListenState, @RBuf[0]);

  FSendStream.Position := FSendStream.Size;
  p^.Build_P2PVM_Send_Buffer(FSendStream);
  FreeP2PVMPacket(p);
end;

procedure TZNet_P2PVM.SendConnecting(const Remote_frameworkID, FrameworkID, p2pID: Cardinal; const IPV6: TIPV6; const Port: Word);
var
  RBuf: array [0 .. 25] of Byte;
  p: PP2PVMFragmentPacket;
begin
  if (FOwner_IO = nil) or (not WasAuthed) then
      exit;
  PCardinal(@RBuf[0])^ := FrameworkID;
  PCardinal(@RBuf[4])^ := p2pID;
  PIPV6(@RBuf[8])^ := IPV6;
  PWORD(@RBuf[24])^ := Port;

  p := Build_P2PVM_Packet(SizeOf(RBuf), Remote_frameworkID, 0, ZNet_Def_p2pVM_Connecting, @RBuf[0]);

  FSendStream.Position := FSendStream.Size;
  p^.Build_P2PVM_Send_Buffer(FSendStream);
  FreeP2PVMPacket(p);
end;

procedure TZNet_P2PVM.SendConnectedReponse(const Remote_frameworkID, Remote_p2pID, FrameworkID, p2pID: Cardinal);
var
  RBuf: array [0 .. 7] of Byte;
  p: PP2PVMFragmentPacket;
begin
  if (FOwner_IO = nil) or (not WasAuthed) then
      exit;
  PCardinal(@RBuf[0])^ := FrameworkID;
  PCardinal(@RBuf[4])^ := p2pID;

  p := Build_P2PVM_Packet(SizeOf(RBuf), Remote_frameworkID, Remote_p2pID, ZNet_Def_p2pVM_ConnectedReponse, @RBuf[0]);

  FSendStream.Position := FSendStream.Size;
  p^.Build_P2PVM_Send_Buffer(FSendStream);
  FreeP2PVMPacket(p);
end;

procedure TZNet_P2PVM.SendDisconnect(const Remote_frameworkID, Remote_p2pID: Cardinal);
var
  p: PP2PVMFragmentPacket;
begin
  if (FOwner_IO = nil) or (not WasAuthed) then
      exit;
  p := Build_P2PVM_Packet(0, Remote_frameworkID, Remote_p2pID, ZNet_Def_p2pVM_Disconnect, nil);

  FSendStream.Position := FSendStream.Size;
  p^.Build_P2PVM_Send_Buffer(FSendStream);
  FreeP2PVMPacket(p);
end;

function TZNet_P2PVM.ListenCount: Integer;
begin
  Result := FFrameworkListenPool.Count;
end;

function TZNet_P2PVM.GetListen(const index: Integer): PP2PVMListen;
begin
  Result := FFrameworkListenPool[index];
end;

function TZNet_P2PVM.FindListen(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
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

function TZNet_P2PVM.FindListening(const IPV6: TIPV6; const Port: Word): PP2PVMListen;
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

procedure TZNet_P2PVM.DeleteListen(const IPV6: TIPV6; const Port: Word);
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

procedure TZNet_P2PVM.ClearListen;
var
  i: Integer;
begin
  for i := 0 to FFrameworkListenPool.Count - 1 do
      Dispose(PP2PVMListen(FFrameworkListenPool[i]));
  FFrameworkListenPool.Clear;
end;

