procedure TP2PVMFragmentPacket.Init;
begin
  BuffSiz := 0;
  FrameworkID := 0;
  p2pID := 0;
  pkType := 0;
  buff := nil;
end;

procedure TP2PVMFragmentPacket.Build_P2PVM_Send_Buffer(Stream: TMem64);
begin
  Stream.WritePtr(@BuffSiz, 4);
  Stream.WritePtr(@FrameworkID, 4);
  Stream.WritePtr(@p2pID, 4);
  Stream.WritePtr(@pkType, 1);
  if BuffSiz > 0 then
      Stream.WritePtr(buff, BuffSiz);
end;

procedure TP2PVM_PeerIO.CreateAfter;
begin
  inherited CreateAfter;
  FLinkVM := nil;
  FRealSendBuff := TMem64.CustomCreate(64 * 1024);
  FSendQueue := TP2P_VM_Fragment_Packet_Pool.Create;
  FRemote_frameworkID := 0;
  FRemote_p2pID := 0;
  FillPtrByte(@FIP, SizeOf(FIP), 0);
  FPort := 0;
  FDestroySyncRemote := True;

  if not OwnerFramework.FQuietMode then
      OwnerFramework.Print('VM-IO Create %d', [ID]);
end;

destructor TP2PVM_PeerIO.Destroy;
var
  i: Integer;
  c_: TZNet_WithP2PVM_Client;
  LID: Cardinal;
begin
  LID := 0;
  if Connected then
    begin
      if (FDestroySyncRemote) and (FLinkVM <> nil) then
          FLinkVM.SendDisconnect(Remote_frameworkID, Remote_p2pID);

      LID := ID;
      if not OwnerFramework.FQuietMode then
          OwnerFramework.Print('VMClientIO %d disconnect', [LID]);
      if OwnerFramework is TZNet_WithP2PVM_Client then
        begin
          c_ := TZNet_WithP2PVM_Client(OwnerFramework);
          c_.DoDisconnect(self);
          c_.FVMClientIO := nil;
          c_.FVMConnected := False;
        end;
    end;

  while FSendQueue.Num > 0 do
    begin
      TZNet_P2PVM.FreeP2PVMPacket(FSendQueue.current^.data);
      FSendQueue.Next;
    end;
  DisposeObject(FSendQueue);
  DisposeObject(FRealSendBuff);

  if not OwnerFramework.FQuietMode then
      OwnerFramework.Print('VM-IO Destroy %d', [LID]);
  inherited Destroy;
end;

function TP2PVM_PeerIO.Connected: Boolean;
begin
  if FLinkVM = nil then
      Result := False
  else if OwnerFramework is TZNet_WithP2PVM_Server then
      Result := (FLinkVM.FOwner_IO <> nil)
  else if OwnerFramework is TZNet_WithP2PVM_Client then
      Result := TZNet_WithP2PVM_Client(OwnerFramework).Connected
  else
      Result := False;
end;

procedure TP2PVM_PeerIO.Disconnect;
begin
  Free;
end;

procedure TP2PVM_PeerIO.Write_IO_Buffer(const buff: PByte; const Size: NativeInt);
begin
  if Size <= 0 then
      exit;
  FRealSendBuff.Position := FRealSendBuff.Size;
  FRealSendBuff.WritePtr(buff, Size);
end;

procedure TP2PVM_PeerIO.WriteBufferOpen;
begin
  FRealSendBuff.Clear;
end;

procedure TP2PVM_PeerIO.WriteBufferFlush;
var
  p: PByte;
  siz: Int64;
begin
  if FRealSendBuff.Size <= 0 then
      exit;

  if (FLinkVM <> nil) and (Connected) then
    begin
      p := FRealSendBuff.Memory;
      siz := FRealSendBuff.Size;

      { send fragment }
      while siz > FLinkVM.FMaxVMFragmentSize do
        begin
          FSendQueue.Push(FLinkVM.Build_P2PVM_Packet(FLinkVM.FMaxVMFragmentSize, FRemote_frameworkID, FRemote_p2pID, ZNet_Def_p2pVM_LogicFragmentData, p));
          inc(p, FLinkVM.FMaxVMFragmentSize);
          dec(siz, FLinkVM.FMaxVMFragmentSize);
        end;

      if siz > 0 then
          FSendQueue.Push(FLinkVM.Build_P2PVM_Packet(siz, FRemote_frameworkID, FRemote_p2pID, ZNet_Def_p2pVM_LogicFragmentData, p));
    end;

  FRealSendBuff.Clear;
end;

procedure TP2PVM_PeerIO.WriteBufferClose;
begin
  WriteBufferFlush;
end;

function TP2PVM_PeerIO.GetPeerIP: SystemString;
begin
  Result := IPv6ToStr(FIP).Text;
  if (FLinkVM <> nil) and (FLinkVM.FOwner_IO <> nil) then
      Result := FLinkVM.FOwner_IO.PeerIP + '-Virtual(' + Result + ')';
end;

function TP2PVM_PeerIO.WriteBuffer_is_NULL: Boolean;
begin
  Result := (FRealSendBuff.Size <= 0) and (FSendQueue.Num <= 0);
end;

function TP2PVM_PeerIO.WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean;
var
  p: TP2P_VM_Fragment_Packet_Pool.POrderStruct;
  i: NativeInt;
begin
  Result := not WriteBuffer_is_NULL;
  WriteBuffer_Queue_Num := FSendQueue.Num;
  WriteBuffer_Size := 0;

  if FSendQueue.Num > 0 then
    begin
      i := FSendQueue.Num;
      p := FSendQueue.First;
      while True do
        begin
          inc(WriteBuffer_Size, p^.data^.BuffSiz);
          dec(i);
          if i > 0 then
              p := p^.Next
          else
              Break;
        end;
    end;
end;

procedure TP2PVM_PeerIO.Progress;
begin
  inherited Progress;
  Process_Send_Buffer();
end;

