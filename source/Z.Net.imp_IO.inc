function TPeerIO.Connected: Boolean;
begin
  Result := False;
end;

procedure TPeerIO.Disconnect;
begin
  CheckAndTriggerFailedWaitResult();
end;

procedure TPeerIO.Write_IO_Buffer(const buff: PByte; const Size: NativeInt);
begin
end;

procedure TPeerIO.WriteBufferOpen;
begin
end;

procedure TPeerIO.WriteBufferFlush;
begin
end;

procedure TPeerIO.WriteBufferClose;
begin
end;

function TPeerIO.GetPeerIP: SystemString;
begin
  Result := 'offline';
end;

function TPeerIO.WriteBuffer_is_NULL: Boolean;
begin
  Result := True;
end;

function TPeerIO.WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean;
begin
  WriteBuffer_Queue_Num := 0;
  WriteBuffer_Size := 0;
  Result := False;
end;

procedure TPeerIO.InitSequencePacketModel(const hashSize, MemoryDelta: Integer);
begin
  FSequencePacketActivted := OwnerFramework.FSequencePacketActivted;
  FSequencePacketSignal := True;

  SequenceNumberOnSendCounter := 0;
  SequenceNumberOnReceivedCounter := 0;

  SendingSequencePacketHistory := TSequence_Packet_Hash_Pool.Create(hashSize, nil);
  SendingSequencePacketHistory.OnFree := Send_Free_OnPtr;
  SendingSequencePacketHistory.OnAdd := Send_Add_OnPtr;

  SequencePacketReceivedPool := TSequence_Packet_Hash_Pool.Create(hashSize, nil);
  SequencePacketReceivedPool.OnFree := Received_Free_OnPtr;
  SequencePacketReceivedPool.OnAdd := Received_Add_OnPtr;

  SendingSequencePacketHistoryMemory := 0;
  SequencePacketReceivedPoolMemory := 0;

  IOSendBuffer := TMS64.CustomCreate(MemoryDelta);
  SequencePacketSendBuffer := TMS64.CustomCreate(MemoryDelta);
  SequencePacketReceivedBuffer := TMS64.CustomCreate(MemoryDelta);

  FSequencePacketMTU := ZNet_Def_SequencePacketMTU;

  FSequencePacketLimitPhysicsMemory := 0;
  SequencePacketCloseDone := False;

  SequencePacketVerifyTick := GetTimeTick;
end;

procedure TPeerIO.FreeSequencePacketModel;
begin
  DisposeObject(SendingSequencePacketHistory);
  SendingSequencePacketHistory := nil;

  DisposeObject(SequencePacketReceivedPool);
  SequencePacketReceivedPool := nil;

  DisposeObject(IOSendBuffer);
  IOSendBuffer := nil;

  DisposeObject(SequencePacketSendBuffer);
  SequencePacketSendBuffer := nil;

  DisposeObject(SequencePacketReceivedBuffer);
  SequencePacketReceivedBuffer := nil;
end;

procedure TPeerIO.ResetSequencePacketBuffer;
begin
  IOSendBuffer.Clear;
  SequencePacketSendBuffer.Clear;
  SequencePacketReceivedBuffer.Clear;
end;

procedure TPeerIO.ProcessSequencePacketModel;
var
  p: PSequencePacket;
  siz: NativeInt;
begin
  if not IsSequencePacketModel then
      exit;

  if SequencePacketCloseDone then
      exit;

  if FDisable_Progress then
      exit;

  if (FSequencePacketLimitPhysicsMemory <> 0) and
    (SendingSequencePacketHistoryMemory + SequencePacketReceivedPoolMemory > FSequencePacketLimitPhysicsMemory) then
    begin
      PrintError('memory exceeds security limit for Sequence Packet signal buffer.');
      SequencePacketCloseDone := True;
      DelayClose;
      exit;
    end;

  if (FSequencePacketSignal)
    and (SendingSequencePacketHistory.Count > 0)
    and (WriteBuffer_is_NULL)
    and (GetTimeTick - SequencePacketVerifyTick > 1000) then
    begin
      IOSendBuffer.Position := IOSendBuffer.Size;

      siz := 0;
      with SendingSequencePacketHistory.Repeat_ do
        begin
          repeat
            p := Queue^.data^.data.Second;
            if (GetTimeTick - p^.tick > 3000) then
              begin
                WriteSequencePacket(p);
                p^.tick := GetTimeTick;
                inc(siz, p^.Size);
              end;
          until (not Next) or (siz > 1024 * 1024);
        end;

      SequencePacketVerifyTick := GetTimeTick;
    end;

  FlushIOSendBuffer;
end;

function TPeerIO.GetSequencePacketState: SystemString;
begin
  Result := PFormat('History: %s (block: %d) Received Pool: %s (block: %d) Total Memory: %s',
    [umlSizeToStr(SendingSequencePacketHistoryMemory).Text,
      SendingSequencePacketHistory.Count,
      umlSizeToStr(SequencePacketReceivedPoolMemory).Text,
      SequencePacketReceivedPool.Count,
      umlSizeToStr(SendingSequencePacketHistoryMemory + SequencePacketReceivedPoolMemory).Text
      ]);
end;

function TPeerIO.GetSequencePacketUsagePhysicsMemory: Int64;
begin
  Result := SendingSequencePacketHistoryMemory + SequencePacketReceivedPoolMemory;
end;

function TPeerIO.ComputeSequencePacketHash(const p: PByte; const Count: nativeUInt): TMD5;
begin
  Result := umlMD5(p, Count);
end;

function TPeerIO.IsSequencePacketModel: Boolean;
begin
  Result := (FSequencePacketActivted) and (OwnerFramework.Protocol = TCommunicationProtocol.cpZServer);
end;

procedure TPeerIO.FlushIOSendBuffer;
begin
  if (IOSendBuffer.Size > 0) then
    begin
      WriteBufferOpen;
      On_Internal_Send_Byte_Buffer(self, IOSendBuffer.Memory, IOSendBuffer.Size);
      IOSendBuffer.Clear;
      WriteBufferFlush;
      WriteBufferClose;
    end;
end;

procedure TPeerIO.SendSequencePacketBegin;
begin
  SequencePacketSendBuffer.Clear;
end;

procedure TPeerIO.SendSequencePacket(const buff: PByte; siz: NativeInt);
begin
  SequencePacketSendBuffer.WritePtr(buff, siz);
end;

procedure TPeerIO.SendSequencePacketEnd;
var
  pBuff: PByte;
  p: PSequencePacket;
  siz: NativeInt;
  FlushBuffSize: Word;
begin
  if SequencePacketSendBuffer.Size <= 0 then
      exit;

  if not IsSequencePacketModel then
    begin
      WriteBufferOpen;
      On_Internal_Send_Byte_Buffer(self, SequencePacketSendBuffer.Memory, SequencePacketSendBuffer.Size);
      SequencePacketSendBuffer.Clear;
      WriteBufferFlush;
      WriteBufferClose;
      exit;
    end;

  FlushBuffSize := umlMax(FSequencePacketMTU, 1024) - (ZNet_Def_Sequence_Packet_HeadSize + 1);

  siz := SequencePacketSendBuffer.Size;
  pBuff := SequencePacketSendBuffer.Memory;

  IOSendBuffer.Position := IOSendBuffer.Size;

  { fragment build to sending }
  while siz > FlushBuffSize do
    begin
      New(p);
      p^.SequenceNumber := SequenceNumberOnSendCounter;
      p^.data := TMS64.Create;
      p^.data.Size := FlushBuffSize;
      p^.Size := p^.data.Size;
      CopyPtr(pBuff, p^.data.Memory, p^.data.Size);
      p^.hash := ComputeSequencePacketHash(p^.data.Memory, p^.data.Size);
      p^.tick := GetTimeTick;

      inc(pBuff, FlushBuffSize);
      dec(siz, FlushBuffSize);

      WriteSequencePacket(p);
      inc(SequenceNumberOnSendCounter);

      if FSequencePacketSignal then
          SendingSequencePacketHistory.Add(p^.SequenceNumber, p, False)
      else
        begin
          DisposeObject(p^.data);
          Dispose(p);
        end;
    end;

  if siz > 0 then
    begin
      New(p);
      p^.SequenceNumber := SequenceNumberOnSendCounter;
      p^.data := TMS64.Create;
      p^.data.Size := siz;
      p^.Size := p^.data.Size;
      CopyPtr(pBuff, p^.data.Memory, p^.data.Size);
      p^.hash := ComputeSequencePacketHash(p^.data.Memory, p^.data.Size);
      p^.tick := GetTimeTick;

      WriteSequencePacket(p);
      inc(SequenceNumberOnSendCounter);

      if FSequencePacketSignal then
          SendingSequencePacketHistory.Add(p^.SequenceNumber, p, False)
      else
        begin
          DisposeObject(p^.data);
          Dispose(p);
        end;
    end;
  SequencePacketSendBuffer.Clear;

  FlushIOSendBuffer;
end;

procedure TPeerIO.SendSequencePacketKeepAlive(p: Pointer; siz: Word);
begin
  if FSequencePacketSignal and IsSequencePacketModel then
    begin
      IOSendBuffer.Position := IOSendBuffer.Size;

      IOSendBuffer.WriteUInt8(ZNet_Def_Sequence_KeepAlive);
      IOSendBuffer.WriteUInt16(siz);
      if siz > 0 then
          IOSendBuffer.WritePtr(p, siz);
    end;
end;

procedure TPeerIO.DoSequencePacketEchoKeepAlive(p: Pointer; siz: Word);
begin
end;

procedure TPeerIO.WriteSequencePacket(p: PSequencePacket);
begin
  if FSequencePacketSignal then
      IOSendBuffer.WriteUInt8(ZNet_Def_Sequence_Packet)
  else
      IOSendBuffer.WriteUInt8(ZNet_Def_Sequence_QuietPacket);
  IOSendBuffer.WriteUInt16(p^.Size);
  IOSendBuffer.WriteUInt32(p^.SequenceNumber);
  IOSendBuffer.WriteMD5(p^.hash);
  IOSendBuffer.WritePtr(p^.data.Memory, p^.data.Size);
end;

procedure TPeerIO.ResendSequencePacket(SequenceNumber: Cardinal);
var
  p: PSequencePacket;
begin
  p := SendingSequencePacketHistory[SequenceNumber];
  if p <> nil then
    begin
      WriteSequencePacket(p);
      p^.tick := GetTimeTick();
    end
  else
      PrintError('resend error, invalid Sequence Packet ' + IntToHex(SequenceNumber, 8));
end;

function TPeerIO.FillSequencePacketTo(const buff: Pointer; siz: Int64; ExtractDest: TMS64): Boolean;
var
  ErrorState: Boolean;
  p: PSequencePacket;
  head: Byte;
  echoSiz: Word;
  ResendNumber, DoneNumber: Cardinal;
  fastSwap, n: TMS64;
  hashMatched: Boolean;
begin
  Result := True;

  if not IsSequencePacketModel then
    begin
      ExtractDest.Position := ExtractDest.Size;
      if (buff <> nil) and (siz > 0) then
          ExtractDest.WritePtr(buff, siz);
      exit;
    end;

{$IFDEF OverflowCheck}{$Q-}{$ENDIF}
{$IFDEF RangeCheck}{$R-}{$ENDIF}
  SequencePacketReceivedBuffer.Position := SequencePacketReceivedBuffer.Size;
  if (buff <> nil) and (siz > 0) then
      SequencePacketReceivedBuffer.WritePtr(buff, siz);

  fastSwap := TMS64.Create;
  fastSwap.SetPointerWithProtectedMode(SequencePacketReceivedBuffer.Memory, SequencePacketReceivedBuffer.Size);

  IOSendBuffer.Position := IOSendBuffer.Size;
  ExtractDest.Position := ExtractDest.Size;

  ErrorState := False;
  New(p);

  while fastSwap.Size > 0 do
    begin
      if fastSwap.Position + 1 > fastSwap.Size then
          Break;

      head := fastSwap.ReadUInt8;

      if head = ZNet_Def_Sequence_KeepAlive then
        begin
          if fastSwap.Position + 2 > fastSwap.Size then
              Break;
          echoSiz := fastSwap.ReadUInt16;
          if fastSwap.Position + echoSiz > fastSwap.Size then
              Break;

          if FSequencePacketSignal then
            begin
              IOSendBuffer.WriteUInt8(ZNet_Def_Sequence_EchoKeepAlive);
              IOSendBuffer.WriteUInt16(echoSiz);
              if echoSiz > 0 then
                  IOSendBuffer.CopyFrom(fastSwap, echoSiz);
            end
          else
              fastSwap.Position := fastSwap.Position + echoSiz;
        end
      else if head = ZNet_Def_Sequence_EchoKeepAlive then
        begin
          if fastSwap.Position + 2 > fastSwap.Size then
              Break;
          echoSiz := fastSwap.ReadUInt16;
          if fastSwap.Position + echoSiz > fastSwap.Size then
              Break;

          DoSequencePacketEchoKeepAlive(fastSwap.PositionAsPtr(), echoSiz);
          if echoSiz > 0 then
              fastSwap.Position := fastSwap.Position + echoSiz;
        end
      else if head = ZNet_Def_Sequence_RequestResend then
        begin
          if fastSwap.Position + 4 > fastSwap.Size then
              Break;
          ResendNumber := fastSwap.ReadUInt32;
          { resend Packet }
          if FSequencePacketSignal then
              ResendSequencePacket(ResendNumber);
          AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketRequestResend]);
        end
      else if head = ZNet_Def_Sequence_EchoPacket then
        begin
          if fastSwap.Position + 4 > fastSwap.Size then
              Break;
          DoneNumber := fastSwap.ReadUInt32;
          { recycle Packet }
          SendingSequencePacketHistory.Delete(DoneNumber);
          AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketEcho]);
        end
      else if head in [ZNet_Def_Sequence_QuietPacket, ZNet_Def_Sequence_Packet] then
        begin
          if fastSwap.Position + ZNet_Def_Sequence_Packet_HeadSize > fastSwap.Size then
              Break;

          p^.Size := fastSwap.ReadUInt16;
          p^.SequenceNumber := fastSwap.ReadUInt32;
          p^.hash := fastSwap.ReadMD5;

          if fastSwap.Position + p^.Size > fastSwap.Size then
              Break;

          hashMatched := umlMD5Compare(p^.hash, NULL_MD5) or
            umlMD5Compare(p^.hash, ComputeSequencePacketHash(fastSwap.PositionAsPtr(), p^.Size));

          if hashMatched then
            begin
              if (FSequencePacketSignal) and (head = ZNet_Def_Sequence_Packet) then
                begin
                  IOSendBuffer.WriteUInt8(ZNet_Def_Sequence_EchoPacket);
                  IOSendBuffer.WriteUInt32(p^.SequenceNumber);
                end;

              AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketReceived]);

              if p^.SequenceNumber = SequenceNumberOnReceivedCounter then
                begin
                  ExtractDest.CopyFrom(fastSwap, p^.Size);
                  SequencePacketReceivedPool.Delete(p^.SequenceNumber);
                  inc(SequenceNumberOnReceivedCounter);
                  AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketMatched]);
                end
              else if (FSequencePacketSignal) and ((p^.SequenceNumber > SequenceNumberOnReceivedCounter) or
                  (Cardinal(p^.SequenceNumber + Cardinal($7FFFFFFF)) > Cardinal(SequenceNumberOnReceivedCounter + Cardinal($7FFFFFFF)))) then
                begin
                  p^.data := TMS64.Create;
                  p^.data.CopyFrom(fastSwap, p^.Size);
                  p^.tick := GetTimeTick;
                  SequencePacketReceivedPool.Add(p^.SequenceNumber, p, True);

                  New(p);
                  AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketPlan]);
                end
              else
                begin
                  AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketDiscard]);
                  AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketDiscardSize], p^.Size);
                  fastSwap.Position := fastSwap.Position + p^.Size;
                end;
            end
          else
            begin
              fastSwap.Position := fastSwap.Position + p^.Size;
              if FSequencePacketSignal then
                begin
                  IOSendBuffer.WriteUInt8(ZNet_Def_Sequence_RequestResend);
                  IOSendBuffer.WriteUInt32(p^.SequenceNumber);
                end;
            end;
        end
      else
        begin
          if FRemoteExecutedForConnectInit then // fixed safe check, by.qq600585
            begin
              PrintError('sequence packet: error head');
              DoStatus('error buffer: ', buff, umlMin(siz, 200), 60);
            end;
          ErrorState := True;
          Break;
        end;

      n := TMS64.Create;
      n.SetPointerWithProtectedMode(fastSwap.PositionAsPtr(), fastSwap.Size - fastSwap.Position);
      DisposeObject(fastSwap);
      fastSwap := n;
    end;
  Dispose(p);

  if ErrorState then
    begin
      DisposeObject(fastSwap);
      Result := False;
      exit;
    end;

  { strip buffer }
  n := TMS64.CustomCreate(SequencePacketReceivedBuffer.Delta);
  if fastSwap.Size > 0 then
    begin
      n.WritePtr(fastSwap.Memory, fastSwap.Size);
      n.Position := 0;
    end;
  DisposeObject(SequencePacketReceivedBuffer);
  SequencePacketReceivedBuffer := n;
  DisposeObject(fastSwap);

  { extract buffer }
  while SequencePacketReceivedPool.Count > 0 do
    begin
      p := SequencePacketReceivedPool[SequenceNumberOnReceivedCounter];
      if p = nil then
        begin
          if FSequencePacketSignal then
            begin
              IOSendBuffer.WriteUInt8(ZNet_Def_Sequence_RequestResend);
              IOSendBuffer.WriteUInt32(SequenceNumberOnReceivedCounter);
            end;
          Break;
        end;
      ExtractDest.WritePtr(p^.data.Memory, p^.Size);
      SequencePacketReceivedPool.Delete(SequenceNumberOnReceivedCounter);
      inc(SequenceNumberOnReceivedCounter);
    end;
{$IFDEF OverflowCheck}{$Q+}{$ENDIF}
{$IFDEF RangeCheck}{$R+}{$ENDIF}
end;

procedure TPeerIO.Send_Free_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket);
begin
  AtomDec(OwnerFramework.Statistics[TStatisticsType.stSequencePacketMemoryOnSending], p^.Size);
  dec(SendingSequencePacketHistoryMemory, p^.Size);
  if SendingSequencePacketHistoryMemory < 0 then
      PrintError('SendingSequencePacketHistoryMemory overflow');
  DisposeObject(p^.data);
  Dispose(p);
end;

procedure TPeerIO.Send_Add_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket);
begin
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketMemoryOnSending], p^.Size);
  inc(SendingSequencePacketHistoryMemory, p^.Size);
  if SendingSequencePacketHistoryMemory < 0 then
      PrintError('SendingSequencePacketHistoryMemory overflow');
end;

procedure TPeerIO.Received_Free_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket);
begin
  AtomDec(OwnerFramework.Statistics[TStatisticsType.stSequencePacketMemoryOnReceived], p^.Size);
  dec(SequencePacketReceivedPoolMemory, p^.Size);
  if SequencePacketReceivedPoolMemory < 0 then
      PrintError('SequencePacketReceivedPoolMemory overflow');

  DisposeObject(p^.data);
  Dispose(p);
end;

procedure TPeerIO.Received_Add_OnPtr(var Sequence_ID_: Cardinal; var p: PSequencePacket);
begin
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stSequencePacketMemoryOnReceived], p^.Size);
  inc(SequencePacketReceivedPoolMemory, p^.Size);
  if SequencePacketReceivedPoolMemory < 0 then
      PrintError('SequencePacketReceivedPoolMemory overflow');
end;

procedure TPeerIO.P2PVMAuthSuccess(Sender: TZNet_P2PVM);
begin
  with OwnerFramework.ProgressPost.PostExecuteM(False, 0, OwnerFramework.VMAuthSuccessDelayExecute) do
    begin
      Data3 := ID;
      Ready();
    end;
end;

function TPeerIO.GetUserVariants: THashVariantList;
begin
  if FUserVariants = nil then
      FUserVariants := THashVariantList.Create;

  Result := FUserVariants;
end;

function TPeerIO.GetUserObjects: THashObjectList;
begin
  if FUserObjects = nil then
      FUserObjects := THashObjectList.Create(False);

  Result := FUserObjects;
end;

function TPeerIO.GetUserAutoFreeObjects: THashObjectList;
begin
  if FUserAutoFreeObjects = nil then
      FUserAutoFreeObjects := THashObjectList.Create(True);

  Result := FUserAutoFreeObjects;
end;

procedure TPeerIO.BeginSend;
begin
  if BeginSendState then
      PrintError('illegal BeginSend!');
  BeginSendState := True;
  SendSequencePacketBegin;
end;

procedure TPeerIO.Send(const buff: PByte; siz: NativeInt);
begin
  SendSequencePacket(buff, siz);
end;

procedure TPeerIO.EndSend;
begin
  if not BeginSendState then
      PrintError('illegal EndSend!');
  BeginSendState := False;
  SendSequencePacketEnd;
end;

procedure TPeerIO.SendInteger(v: Integer);
begin
  Send(@v, C_Integer_Size);
end;

procedure TPeerIO.SendCardinal(v: Cardinal);
begin
  Send(@v, C_Cardinal_Size);
end;

procedure TPeerIO.SendInt64(v: Int64);
begin
  Send(@v, C_Int64_Size);
end;

procedure TPeerIO.SendByte(v: Byte);
begin
  Send(@v, C_Byte_Size);
end;

procedure TPeerIO.SendWord(v: Word);
begin
  Send(@v, C_Word_Size);
end;

procedure TPeerIO.SendVerifyCode(buff: Pointer; siz: NativeInt);
var
  headBuff: array [0 .. 2] of Byte;
  Code: TBytes;
begin
  GenerateHashCode(OwnerFramework.FHashSecurity, buff, siz, Code);
  headBuff[0] := Byte(OwnerFramework.FHashSecurity);
  PWORD(@headBuff[1])^ := Length(Code);
  Send(@headBuff[0], 3);
  if Length(Code) > 0 then
      Send(@Code[0], Length(Code));
end;

procedure TPeerIO.SendEncryptBuffer(buff: PByte; siz: NativeInt; CS: TCipherSecurity);
begin
  SendByte(Byte(CS));
  Encrypt(CS, buff, siz, FCipherKey, True);
  Send(buff, siz);
end;

procedure TPeerIO.SendEncryptMemoryStream(Stream: TMS64; CS: TCipherSecurity);
begin
  SendEncryptBuffer(Stream.Memory, Stream.Size, CS);
end;

procedure TPeerIO.Internal_Send_Console_Buff(buff: TMS64; CS: TCipherSecurity);
begin
  BeginSend;
  SendCardinal(FHeadToken);
  SendByte(Byte(FConsoleToken));
  SendCardinal(Cardinal(buff.Size));

  SendVerifyCode(buff.Memory, buff.Size);
  SendEncryptMemoryStream(buff, CS);
  SendCardinal(FTailToken);
  EndSend;
end;

procedure TPeerIO.Internal_Send_Stream_Buff(buff: TMS64; CS: TCipherSecurity);
begin
  BeginSend;
  SendCardinal(FHeadToken);
  SendByte(Byte(FStreamToken));
  SendCardinal(Cardinal(buff.Size));

  SendVerifyCode(buff.Memory, buff.Size);
  SendEncryptMemoryStream(buff, CS);
  SendCardinal(FTailToken);
  EndSend;
end;

procedure TPeerIO.Internal_Send_ConsoleNotify_Buff(buff: TMS64; CS: TCipherSecurity);
begin
  BeginSend;
  SendCardinal(FHeadToken);
  SendByte(Byte(FConsoleNotifyToken));
  SendCardinal(Cardinal(buff.Size));

  SendVerifyCode(buff.Memory, buff.Size);
  SendEncryptMemoryStream(buff, CS);
  SendCardinal(FTailToken);
  EndSend;
end;

procedure TPeerIO.Internal_Send_StreamNotify_Buff(buff: TMS64; CS: TCipherSecurity);
begin
  BeginSend;
  SendCardinal(FHeadToken);
  SendByte(Byte(FStreamNotifyToken));
  SendCardinal(Cardinal(buff.Size));

  SendVerifyCode(buff.Memory, buff.Size);
  SendEncryptMemoryStream(buff, CS);
  SendCardinal(FTailToken);
  EndSend;
end;

procedure TPeerIO.Internal_Send_Big_Stream_Header(const Cmd: SystemString; streamSiz: Int64);
var
  buff: TBytes;
begin
  BeginSend;
  SendCardinal(FHeadToken);
  SendByte(FBigStreamToken);
  SendInt64(streamSiz);
  buff := TPascalString(Cmd).Bytes;
  SendCardinal(Cardinal(Length(buff)));
  Send(@buff[0], Length(buff));
  SetLength(buff, 0);
  SendCardinal(FTailToken);
  EndSend;
end;

procedure TPeerIO.Internal_Send_BigStream_Buff(var Queue: TQueueData);
var
  StartPos, EndPos: Int64;
  tmpPos: Int64;
  j: Int64;
  Num: Int64;
  Rest: Int64;
  BigStream_Chunk: PByte;
begin
  Internal_Send_Big_Stream_Header(Queue.Cmd, Queue.BigStream.Size - Queue.BigStreamStartPos);

  StartPos := Queue.BigStreamStartPos;
  EndPos := Queue.BigStream.Size;
  tmpPos := StartPos;
  { Calculate number of full chunks that will fit into the buffer }
  Num := (EndPos - StartPos) div ZNet_Def_BigStream_ChunkSize;
  { Calculate remaining bytes }
  Rest := (EndPos - StartPos) mod ZNet_Def_BigStream_ChunkSize;
  { init buffer }
  BigStream_Chunk := GetMemory(ZNet_Def_BigStream_ChunkSize);
  try
    { Process full chunks }
    j := 0;
    while j < Num do
      begin
        if not Connected then
            exit;

        Queue.BigStream.Position := tmpPos;
        Queue.BigStream.read(BigStream_Chunk^, ZNet_Def_BigStream_ChunkSize);
        inc(tmpPos, ZNet_Def_BigStream_ChunkSize);

        SendBigStreamMiniPacket(BigStream_Chunk, ZNet_Def_BigStream_ChunkSize);

        { peer fragment > C_BigStream_ChunkSize }
        if Queue.BigStream.Size - tmpPos > ZNet_Def_BigStream_ChunkSize then
          begin
            FBigStreamSending := Queue.BigStream;
            FBigStreamSendCurrentPos := tmpPos;
            FBigStreamSendDoneTimeFree := Queue.DoneAutoFree;
            Queue.BigStream := nil;
            FreeMemory(BigStream_Chunk);

            if Assigned(OwnerFramework.FOnBigStreamInterface) then
              begin
                OwnerFramework.FOnBigStreamInterface.BeginStream(self, FBigStreamSending.Size);
                OwnerFramework.FOnBigStreamInterface.Process(self, FBigStreamSending.Size, FBigStreamSendCurrentPos);
              end;

            exit;
          end;
        inc(j);
      end;

    { Process remaining bytes }
    if Rest > 0 then
      begin
        Queue.BigStream.Position := tmpPos;
        Queue.BigStream.read(BigStream_Chunk^, Rest);
        tmpPos := tmpPos + Rest;
        SendBigStreamMiniPacket(BigStream_Chunk, Rest);
      end;
  finally
      FreeMemory(BigStream_Chunk);
  end;
end;

procedure TPeerIO.Internal_Send_Complete_Buffer_Header(const Cmd: SystemString; BuffSiz, compSiz: Cardinal);
var
  buff: TBytes;
begin
  SendCardinal(FHeadToken);
  SendByte(FCompleteBufferToken);
  SendCardinal(BuffSiz);
  SendCardinal(compSiz);
  buff := TPascalString(Cmd).Bytes;
  SendCardinal(Cardinal(Length(buff)));
  Send(@buff[0], Length(buff));
  SetLength(buff, 0);
  SendCardinal(FTailToken);
end;

procedure TPeerIO.Internal_Send_CompleteBuffer_Buff(var Queue: TQueueData);
var
  Sour, Dest: TMS64;
begin
  BeginSend;
  if OwnerFramework.FCompleteBufferCompressed and (Queue.BufferSize > OwnerFramework.FCompleteBufferCompressionCondition) then
    begin
      Sour := TMS64.Create;
      if (Queue.Buffer <> nil) and (Queue.Buffer_Swap_Memory = nil) then
          Sour.SetPointerWithProtectedMode(Queue.Buffer, Queue.BufferSize)
      else if (Queue.Buffer = nil) and (Queue.Buffer_Swap_Memory <> nil) then
        begin
          Queue.Buffer_Swap_Memory.Prepare;
          Sour.SwapInstance(Queue.Buffer_Swap_Memory);
          DisposeObject(Queue.Buffer_Swap_Memory);
          Queue.Buffer_Swap_Memory := nil;
        end
      else
          PrintError('illegal CompleteBuffer Queue.');

      Dest := TMS64.Create;
      ParallelCompressMemory(scmZLIB_Fast, Sour, Dest);
      DisposeObject(Sour);
      Internal_Send_Complete_Buffer_Header(Queue.Cmd, Queue.BufferSize, Dest.Size);
      Send(Dest.Memory, Dest.Size);
      DisposeObject(Dest);
    end
  else
    begin
      Internal_Send_Complete_Buffer_Header(Queue.Cmd, Queue.BufferSize, 0);
      if (Queue.Buffer <> nil) and (Queue.Buffer_Swap_Memory = nil) then
          Send(Queue.Buffer, Queue.BufferSize)
      else if (Queue.Buffer = nil) and (Queue.Buffer_Swap_Memory <> nil) then
        begin
          Queue.Buffer_Swap_Memory.Prepare;
          Send(Queue.Buffer_Swap_Memory.Memory, Queue.BufferSize);
          DisposeObject(Queue.Buffer_Swap_Memory);
          Queue.Buffer_Swap_Memory := nil;
        end
      else
          PrintError('illegal CompleteBuffer Queue.');
    end;
  EndSend;
end;

procedure TPeerIO.Internal_Send_BigStream_Fragment_Signal;
begin
  BeginSend;
  SendCardinal(FHeadToken);
  SendByte(FBigStreamReceiveFragmentSignal);
  SendCardinal(FTailToken);
  EndSend;
end;

procedure TPeerIO.Internal_Send_BigStream_Done_Signal;
begin
  BeginSend;
  SendCardinal(FHeadToken);
  SendByte(FBigStreamReceiveDoneSignal);
  SendCardinal(FTailToken);
  EndSend;
end;

procedure TPeerIO.SendBigStreamMiniPacket(buff: PByte; Size: NativeInt);
var
  head: TBigStreamFragmentHead;
  sourStream, destStream: TMS64;
begin
  BeginSend;

  if OwnerFramework.SendDataCompressed then
    begin
      sourStream := TMS64.Create;
      sourStream.SetPointerWithProtectedMode(buff, Size);
      destStream := TMS64.CustomCreate(8192);
      ParallelCompressMemory(scmZLIB_Fast, sourStream, destStream);

      head.Size := destStream.Size;
      head.Compressed := True;

      Send(@head, SizeOf(head));
      Send(destStream.Memory, destStream.Size);

      DisposeObject(sourStream);
      DisposeObject(destStream);
    end
  else
    begin
      head.Size := Size;
      head.Compressed := False;

      Send(@head, SizeOf(head));
      Send(buff, Size);
    end;

  EndSend;
end;

procedure TPeerIO.Internal_Send_Result_Data;
begin
  if FResultDataBuffer.Size > 0 then
    begin
      BeginSend;
      Send(FResultDataBuffer.Memory, FResultDataBuffer.Size);
      FResultDataBuffer.Clear;
      EndSend;
    end;
end;

procedure TPeerIO.Internal_Send_Console_Cmd;
var
  d: TDFE;
  EnSiz: Int64;
  Stream: TMS64;
begin
  d := TDFE.Create;

  d.WriteString(FSyncPick^.Cmd);
  d.WriteString(FSyncPick^.ConsoleData);

  EnSiz := d.ComputeEncodeSize;
  Stream := TMS64.CustomCreate(umlClamp(EnSiz, 8192, 64 * 1024));

  if OwnerFramework.FSendDataCompressed then
    begin
      if EnSiz > 1024 * 1024 then
          d.EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB_Max, Stream, True)
      else
          d.EncodeAsZLib(Stream, True, False);
    end
  else if OwnerFramework.FFastEncrypt then
    begin
      // fast send, fixed by.qq600585
      d.FastEncode32To(Stream, EnSiz);
    end
  else
    begin
      // fast send, fixed by.qq600585
      d.EncodeTo(Stream, True, False);
    end;

  Internal_Send_Console_Buff(Stream, FSyncPick^.Cipher);

  DisposeObject(d);
  DisposeObject(Stream);

  if OwnerFramework.FSendDataCompressed then
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stCompress]);
end;

procedure TPeerIO.Internal_Send_Stream_Cmd;
var
  d: TDFE;
  EnSiz: Int64;
  Stream: TMS64;
begin
  d := TDFE.Create;

  d.WriteString(FSyncPick^.Cmd);
  d.WriteStream(FSyncPick^.StreamData);

  EnSiz := d.ComputeEncodeSize;
  Stream := TMS64.CustomCreate(umlClamp(EnSiz, 8192, 64 * 1024));

  if OwnerFramework.FSendDataCompressed then
    begin
      if EnSiz > 1024 * 1024 then
          d.EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB_Max, Stream, True)
      else
          d.EncodeAsZLib(Stream, True, False);
    end
  else if OwnerFramework.FFastEncrypt then
    begin
      // fast send, fixed by.qq600585
      d.FastEncode32To(Stream, EnSiz);
    end
  else
    begin
      // fast send, fixed by.qq600585
      d.EncodeTo(Stream, True, False);
    end;

  Internal_Send_Stream_Buff(Stream, FSyncPick^.Cipher);

  DisposeObject(d);
  DisposeObject(Stream);

  if OwnerFramework.FSendDataCompressed then
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stCompress]);
end;

procedure TPeerIO.Internal_Send_ConsoleNotify_Cmd;
var
  d: TDFE;
  EnSiz: Int64;
  Stream: TMS64;
begin
  d := TDFE.Create;

  d.WriteString(FSyncPick^.Cmd);
  d.WriteString(FSyncPick^.ConsoleData);

  EnSiz := d.ComputeEncodeSize;
  Stream := TMS64.CustomCreate(umlClamp(EnSiz, 8192, 64 * 1024));

  if OwnerFramework.FSendDataCompressed then
    begin
      if EnSiz > 1024 * 1024 then
          d.EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB_Max, Stream, True)
      else
          d.EncodeAsZLib(Stream, True, False);
    end
  else if OwnerFramework.FFastEncrypt then
    begin
      // fast send, fixed by.qq600585
      d.FastEncode32To(Stream, EnSiz);
    end
  else
    begin
      // fast send, fixed by.qq600585
      d.EncodeTo(Stream, True, False);
    end;

  Internal_Send_ConsoleNotify_Buff(Stream, FSyncPick^.Cipher);

  DisposeObject(d);
  DisposeObject(Stream);

  if OwnerFramework.FSendDataCompressed then
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stCompress]);
end;

procedure TPeerIO.Internal_Send_StreamNotify_Cmd;
var
  d: TDFE;
  EnSiz: Int64;
  Stream: TMS64;
begin
  d := TDFE.Create;

  d.WriteString(FSyncPick^.Cmd);
  d.WriteStream(FSyncPick^.StreamData);

  EnSiz := d.ComputeEncodeSize;
  Stream := TMS64.CustomCreate(umlClamp(EnSiz, 8192, 64 * 1024));

  if OwnerFramework.FSendDataCompressed then
    begin
      if EnSiz > 1024 * 1024 then
          d.EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB_Max, Stream, True)
      else
          d.EncodeAsZLib(Stream, True, False);
    end
  else if OwnerFramework.FFastEncrypt then
    begin
      // fast send, fixed by.qq600585
      d.FastEncode32To(Stream, EnSiz);
    end
  else
    begin
      // fast send, fixed by.qq600585
      d.EncodeTo(Stream, True, False);
    end;

  Internal_Send_StreamNotify_Buff(Stream, FSyncPick^.Cipher);

  DisposeObject(d);
  DisposeObject(Stream);

  if OwnerFramework.FSendDataCompressed then
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stCompress]);
end;

procedure TPeerIO.Internal_Send_BigStream_Cmd;
begin
  Internal_Send_BigStream_Buff(FSyncPick^);
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stExecBigStream]);
end;

procedure TPeerIO.Internal_Send_CompleteBuffer_Cmd;
begin
  Internal_Send_CompleteBuffer_Buff(FSyncPick^);
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stExecCompleteBuffer]);
end;

procedure TPeerIO.Internal_Execute_Console;
var
  Tick_: TTimeTick;
begin
  FReceiveCommandRuning := True;
  if not OwnerFramework.QuietMode then
      PrintCommand('execute console: %s', FInCmd);

  Tick_ := GetTimeTick;
  OwnerFramework.ExecuteConsole(self, FInCmd, FInText, FOutText);
  FReceiveCommandRuning := False;

  OwnerFramework.CmdMaxExecuteConsumeStatistics.SetMax(FInCmd, GetTimeTick - Tick_);

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stExecConsole]);
  OwnerFramework.CmdRecvStatistics.IncValue(FInCmd, 1);
end;

procedure TPeerIO.Internal_Execute_Stream;
var
  Tick_: TTimeTick;
begin
  FReceiveCommandRuning := True;
  if not OwnerFramework.QuietMode then
      PrintCommand('execute stream: %s', FInCmd);

  Tick_ := GetTimeTick;
  OwnerFramework.ExecuteStream(self, FInCmd, FInDataFrame, FOutDataFrame);
  FReceiveCommandRuning := False;

  OwnerFramework.CmdMaxExecuteConsumeStatistics.SetMax(FInCmd, GetTimeTick - Tick_);

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stExecStream]);
  OwnerFramework.CmdRecvStatistics.IncValue(FInCmd, 1);
end;

procedure TPeerIO.Internal_Execute_ConsoleNotify;
var
  Tick_: TTimeTick;
begin
  FReceiveCommandRuning := True;
  if not OwnerFramework.QuietMode then
      PrintCommand('execute direct console: %s', FInCmd);

  Tick_ := GetTimeTick;
  OwnerFramework.ExecuteConsoleNotify(self, FInCmd, FInText);
  FReceiveCommandRuning := False;

  OwnerFramework.CmdMaxExecuteConsumeStatistics.SetMax(FInCmd, GetTimeTick - Tick_);

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stExecDirestConsole]);
  OwnerFramework.CmdRecvStatistics.IncValue(FInCmd, 1);
end;

procedure TPeerIO.Internal_Execute_StreamNotify;
var
  Tick_: TTimeTick;
begin
  FReceiveCommandRuning := True;
  if not OwnerFramework.QuietMode then
      PrintCommand('execute direct stream: %s', FInCmd);

  Tick_ := GetTimeTick;
  OwnerFramework.ExecuteStreamNotify(self, FInCmd, FInDataFrame);
  FReceiveCommandRuning := False;

  OwnerFramework.CmdMaxExecuteConsumeStatistics.SetMax(FInCmd, GetTimeTick - Tick_);

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stExecDirestStream]);
  OwnerFramework.CmdRecvStatistics.IncValue(FInCmd, 1);
end;

procedure TPeerIO.SendConsoleResult;
var
  buff: TBytes;
begin
  BeginSend;
  buff := TPascalString(FOutText).Bytes;

  { safe check. fixed by qq600585,2022-4-19 }
  if Length(buff) = 0 then
    begin
      SetLength(buff, 1);
      buff[0] := 0;
    end;

  SendCardinal(FHeadToken);
  SendInteger(Length(buff));

  SendVerifyCode(@buff[0], Length(buff));

  SendEncryptBuffer(@buff[0], Length(buff), FReceiveDataCipherSecurity);
  SendCardinal(FTailToken);

  EndSend;

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stResponse]);
end;

procedure TPeerIO.SendStreamResult;
var
  EnSiz: Int64;
  m64: TMS64;
begin
  BeginSend;
  EnSiz := FOutDataFrame.ComputeEncodeSize;
  m64 := TMS64.CustomCreate(umlClamp(EnSiz, 8192, 64 * 1024));

  if OwnerFramework.FSendDataCompressed then
    begin
      if EnSiz > 1024 * 1024 then
          FOutDataFrame.EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB_Max, m64, True)
      else
          FOutDataFrame.EncodeAsZLib(m64, True, False);
    end
  else if OwnerFramework.FFastEncrypt then
    begin
      // fast send, fixed by.qq600585
      FOutDataFrame.FastEncode32To(m64, EnSiz);
    end
  else
    begin
      // fast send, fixed by.qq600585
      FOutDataFrame.EncodeTo(m64, True, False);
    end;

  SendCardinal(FHeadToken);
  SendInteger(m64.Size);

  SendVerifyCode(m64.Memory, m64.Size);

  SendEncryptBuffer(m64.Memory, m64.Size, FReceiveDataCipherSecurity);
  SendCardinal(FTailToken);
  DisposeObject(m64);
  EndSend;
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stResponse]);
end;

procedure TPeerIO.ExecuteDataFrame(CommDataType: Byte; DFE_: TDFE);
begin
  FInCmd := DFE_.Reader.ReadString;

  if CommDataType = FConsoleToken then
    begin
      FInText := DFE_.Reader.ReadString;
      FOutText := '';

      FCanPauseResultSend := True;
      FReceiveTriggerRuning := True;
      Internal_Execute_Console();
      FReceiveTriggerRuning := False;
      FCanPauseResultSend := False;

      if FPause_Result_Send then
        begin
          if not OwnerFramework.QuietMode then
              PrintCommand('pause console cmd %s Result', FInCmd);
          FCurrentPauseResultSend_CommDataType := CommDataType;
          exit;
        end;
      if not Connected then
          exit;

      if not OwnerFramework.QuietMode then
          PrintCommand('send console cmd %s Result data', FInCmd);
      SendConsoleResult();
    end
  else if CommDataType = FStreamToken then
    begin
      FInDataFrame.Clear;
      FOutDataFrame.Clear;
      DFE_.Reader.ReadDataFrame(FInDataFrame);

      FCanPauseResultSend := True;
      FReceiveTriggerRuning := True;
      Internal_Execute_Stream();
      FReceiveTriggerRuning := False;
      FCanPauseResultSend := False;

      if FPause_Result_Send then
        begin
          if not OwnerFramework.QuietMode then
              PrintCommand('pause stream cmd %s Result', FInCmd);
          FCurrentPauseResultSend_CommDataType := CommDataType;
          exit;
        end;

      if not Connected then
          exit;

      if not OwnerFramework.QuietMode then
          PrintCommand('send stream cmd %s Result data', FInCmd);
      SendStreamResult();
    end
  else if CommDataType = FConsoleNotifyToken then
    begin
      FInText := DFE_.Reader.ReadString;

      FReceiveTriggerRuning := True;
      Internal_Execute_ConsoleNotify();
      FReceiveTriggerRuning := False;
    end
  else if CommDataType = FStreamNotifyToken then
    begin
      FInDataFrame.Clear;
      FOutDataFrame.Clear;
      DFE_.Reader.ReadDataFrame(FInDataFrame);

      FReceiveTriggerRuning := True;
      Internal_Execute_StreamNotify();
      FReceiveTriggerRuning := False;
    end;
end;

procedure TPeerIO.Internal_Execute_BigStream;
var
  d: TTimeTick;
begin
  FReceiveCommandRuning := True;
  d := GetTimeTick;
  OwnerFramework.ExecuteBigStream(self, FBigStreamCmd, FSyncBigStreamReceive, FBigStreamTotal, FBigStreamCompleted);
  FReceiveCommandRuning := False;
  OwnerFramework.CmdMaxExecuteConsumeStatistics.SetMax(FInCmd, GetTimeTick - d);

  if FBigStreamTotal = FBigStreamCompleted then
    begin
      Internal_Send_BigStream_Done_Signal();
      { do stream state }
      if Assigned(OwnerFramework.FOnBigStreamInterface) then
          OwnerFramework.FOnBigStreamInterface.EndStream(self, FBigStreamTotal);

      OwnerFramework.CmdRecvStatistics.IncValue(FBigStreamCmd, 1);
      if not OwnerFramework.QuietMode then
          PrintCommand('Big Stream complete: %s', FBigStreamCmd);
    end
  else
    begin
      { do stream state }
      if Assigned(OwnerFramework.FOnBigStreamInterface) then
          OwnerFramework.FOnBigStreamInterface.Process(self, FBigStreamTotal, FBigStreamCompleted);
    end;
end;

function TPeerIO.ReceivedBigStreamFragment(Source_: TMS64): Int64;
var
  head: TBigStreamFragmentHead;
  np: Int64;
  buff, destBuff: TMS64;
  leftSize: Int64;
begin
  Result := -1; // Default return: incomplete fragment
  if (Source_.Size - Source_.Position < SizeOf(head)) then
      exit; // Not enough data to read fragment header
  Source_.ReadPtr(@head, SizeOf(head)); // Read fragment header (size + compression flag)

  if (Source_.Size - Source_.Position < head.Size) then
    begin
      FBigStream_Current_Received := FBigStreamCompleted + (Source_.Size - Source_.Position); // Partial fragment received, update progress

      if (not head.Compressed) and (FBigStreamCompleted + head.Size < FBigStreamTotal) then
        if (Source_.Size - Source_.Position > head.Size div 2) then
          if not FBigStreamFragmentSignal_SendedState then
            begin
              Internal_Send_BigStream_Fragment_Signal; // Request next fragment from sender
              FBigStreamFragmentSignal_SendedState := True;
            end;
      exit;
    end;

  np := Source_.Position + head.Size; // Calculate new position after consuming this fragment
  { change stripped state }
  Result := np; // Return bytes consumed from input buffer

  buff := TMS64.Create; // Create temporary stream to hold fragment payload
  buff.Mapping(Source_.PositionAsPtr, head.Size); // Zero-copy map fragment data
  buff.Position := 0;

  if head.Compressed then // If fragment was compressed on sender side
    begin
      destBuff := TMS64.CustomCreate(8192); // Target buffer for decompressed data
      ParallelDecompressStream(buff, destBuff); // Decompress using parallel engine
      DisposeObject(buff); // Free compressed buffer
      buff := destBuff; // Switch to decompressed data
      buff.Position := 0;
    end;

  leftSize := FBigStreamTotal - FBigStreamCompleted; // Remaining bytes to complete the full stream

  if leftSize > buff.Size then // Fragment does not complete the stream
    begin
      { fragment }
      if not FBigStreamFragmentSignal_SendedState then
        begin
          Internal_Send_BigStream_Fragment_Signal; // Request next fragment from sender
          FBigStreamFragmentSignal_SendedState := True;
        end;

      FBigStreamCompleted := FBigStreamCompleted + buff.Size; // Accumulate received bytes
      FBigStream_Current_Received := FBigStreamCompleted; // Update progress
      FSyncBigStreamReceive := buff; // Pass buffer to execution handler

      Internal_Execute_BigStream(); // Invoke user callback with current progress
      FBigStreamFragmentSignal_SendedState := False;
    end
  else // This fragment completes the entire stream
    begin
      { done }
      FBigStreamCompleted := FBigStreamTotal; // Mark as fully received
      FBigStream_Current_Received := FBigStreamCompleted;
      FSyncBigStreamReceive := buff; // Pass final buffer
      Internal_Execute_BigStream(); // Call user callback for completion
      FBigStreamTotal := 0; // Reset stream state
      FBigStreamCompleted := 0;
      FBigStream_Current_Received := 0;
      FBigStreamFragmentSignal_SendedState := False;
      FBigStreamCmd := '';
      FBigStreamReceiveProcessing := False; // No longer receiving a big stream
    end;

  FSyncBigStreamReceive := nil; // Clear reference to avoid double-free
  DisposeObject(buff); // Free the fragment buffer (now consumed)
end;

procedure TPeerIO.Internal_Execute_CompleteBuffer;
var
  d: TTimeTick;
begin
  if OwnerFramework.FSyncOnCompleteBuffer then
    begin
      FReceiveCommandRuning := True;
      d := GetTimeTick;

      if not OwnerFramework.QuietMode then
          PrintCommand('execute complete buffer: %s', FCompleteBufferCmd);

      FCompleteBuffer_Current_Trigger := FCompleteBufferReceivedStream;
      OwnerFramework.ExecuteCompleteBuffer(self, FCompleteBufferCmd, FCompleteBuffer_Current_Trigger.Memory, FCompleteBuffer_Current_Trigger.Size);

      FReceiveCommandRuning := False;
      OwnerFramework.CmdMaxExecuteConsumeStatistics.SetMax(FCompleteBufferCmd, GetTimeTick - d);

      OwnerFramework.CmdRecvStatistics.IncValue(FCompleteBufferCmd, 1);
    end
  else
    begin
      FCompleteBufferReceivedStream.Position := 0;
      with OwnerFramework.ProgressPost.PostExecute(False) do
        begin
          Data3 := FID;
          Data4 := FCompleteBufferCmd;
          Data1 := FCompleteBufferReceivedStream;
          OnExecute_M := OwnerFramework.DelayExecuteOnCompleteBufferState;
          Ready();
        end;

      FCompleteBufferReceivedStream := TMS64.Create
    end;
end;

function TPeerIO.FillCompleteBufferBuffer(Source_: TMS64): Int64;
var
  leftSize: Cardinal;
  Dest: TMS64;
begin
  leftSize := FCompleteBufferTotal - FCompleteBufferCompleted;
  if leftSize > Source_.Size then
    begin
      FCompleteBufferCompleted := FCompleteBufferCompleted + Source_.Size;
      Source_.Position := 0;
      FCompleteBufferReceivedStream.Position := FCompleteBufferReceivedStream.Size;
      FCompleteBufferReceivedStream.WritePtr(Source_.Memory, Source_.Size);
      { change stripped state }
      Result := Source_.Size;
    end
  else
    begin
      Source_.Position := 0;
      FCompleteBufferReceivedStream.Position := FCompleteBufferReceivedStream.Size;
      FCompleteBufferReceivedStream.WritePtr(Source_.Memory, leftSize);
      FCompleteBufferReceivedStream.Position := 0;

      { change stripped state }
      Result := leftSize;

      if FCompleteBufferCompressedSize > 0 then
        begin
          Dest := TMS64.CustomCreate(FCompleteBufferReceivedStream.Delta);
          ParallelDecompressStream(FCompleteBufferReceivedStream, Dest);
          DisposeObject(FCompleteBufferReceivedStream);
          Dest.Position := 0;
          FCompleteBufferReceivedStream := Dest;
        end;

      Internal_Execute_CompleteBuffer();
      FCompleteBufferReceivedStream.Clear;

      FCompleteBufferTotal := 0;
      FCompleteBufferCompressedSize := 0;
      FCompleteBufferCompleted := 0;
      FCompleteBufferCmd := '';
      FCompleteBufferReceiveProcessing := False;
    end;
end;

procedure TPeerIO.Internal_ExecuteResult;
begin
  if FCurrentQueueData = nil then
      exit;

  if (OwnerFramework.FSyncOnResult) then
    begin
      DoExecuteResult(self, FCurrentQueueData, FResult_Text, FResult_DFE);
      exit;
    end;

  with OwnerFramework.ProgressPost.PostExecute(False) do
    begin
      DataEng.Assign(FResult_DFE);
      Data4 := FID;
      Data5 := FCurrentQueueData;
      Data3 := FResult_Text;
      OnExecute_M := OwnerFramework.DelayExecuteOnResultState;
      Ready();
    end;
  FCurrentQueueData := nil;
end;

function TPeerIO.FillWaitOnResultBuffer(Source_: TMS64): Int64;
var
  dHead, dTail: Cardinal;
  dSize: Integer;
  dHashSecurity: Byte;
  dHashSiz: Word;
  dHash: TBytes;
  dCipherSecurity: Byte;
  buff: TBytes;
begin
  Result := -1;
  if not FWaitOnResult then
      exit;
  if FCurrentQueueData = nil then
      exit;

  Source_.Position := 0;

  { 0: head token }
  if (Source_.Size - Source_.Position < C_Cardinal_Size) then
      exit;
  Source_.read(dHead, C_Cardinal_Size);
  if dHead <> FHeadToken then
    begin
      PrintError('Header Illegal');
      DelayClose();
      exit;
    end;

  { 1: data len }
  if (Source_.Size - Source_.Position < C_Integer_Size) then
      exit;
  Source_.read(dSize, C_Integer_Size);

  { 2:verify code header }
  if (Source_.Size - Source_.Position < 3) then
      exit;
  Source_.read(dHashSecurity, C_Byte_Size);
  Source_.read(dHashSiz, C_Word_Size);

  { 3:verify code body }
  if (Source_.Size - Source_.Position < dHashSiz) then
      exit;
  SetLength(dHash, dHashSiz);
  if Length(dHash) > 0 then
      Source_.read(dHash[0], dHashSiz);

  { 4: use Encrypt state }
  if (Source_.Size - Source_.Position < C_Byte_Size) then
      exit;
  Source_.read(dCipherSecurity, C_Byte_Size);

  { 5:process buff and tail token }
  if (Source_.Size - Source_.Position < dSize + C_Cardinal_Size) then
      exit;
  SetLength(buff, dSize);
  if Length(buff) > 0 then
      Source_.read(buff[0], dSize);

  { 6: tail token }
  Source_.read(dTail, C_Cardinal_Size);
  if dTail <> FTailToken then
    begin
      PrintError('tail token error!');
      DelayClose();
      exit;
    end;

  FReceiveDataCipherSecurity := TCipherSecurity(dCipherSecurity);

  // decrypt reponse
  try
    if Length(buff) > 0 then
      begin
        Encrypt(FReceiveDataCipherSecurity, @buff[0], dSize, FCipherKey, False);
        if not VerifyHashCode(THashSecurity(dHashSecurity), @buff[0], dSize, dHash) then
          begin
            PrintError('verify data error!');
            DelayClose();
            exit;
          end;
      end;
  except
    PrintError('Encrypt error!');
    DelayClose();
    exit;
  end;

  { change stripped state }
  Result := Source_.Position;

  { trigger }
  if (FCurrentQueueData^.State = TQueueState.qsSendConsoleCMD) then // safe check. fixed by.qq600585 2023-9-8
    begin
      { safe check. fixed by qq600585,2022-4-19 }
      if (Length(buff) = 0) or ((Length(buff) = 1) and (buff[0] = 0)) then
        begin
          FResult_Text := '';
        end
      else
        begin
          try
            FResult_Text := umlStringOf(buff).Text;
            SetLength(buff, 0);
            FResult_DFE.Clear;
          except
            PrintError('WaitOnResultBuffer console data error!');
            DelayClose();
            exit;
          end;
        end;
      Internal_ExecuteResult();
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stResponse]);
    end
  else if (FCurrentQueueData^.State = TQueueState.qsSendStreamCMD) then // safe check. fixed by.qq600585 2023-9-8
    begin
      FResult_DFE.Clear;
      try
        FResult_DFE.DecodeFromBytes(buff, True);
        SetLength(buff, 0);
        FResult_Text := '';
      except
        PrintError('WaitOnResultBuffer stream error!');
        DelayClose();
        exit;
      end;
      Internal_ExecuteResult();
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stResponse]);
    end;

  SetLength(buff, 0);
  FWaitOnResult := False;

  if FCurrentQueueData <> nil then
    begin
      DisposeQueueData(FCurrentQueueData);
      FCurrentQueueData := nil;
    end;
end;

procedure TPeerIO.Internal_Save_Receive_Buffer(const buff: Pointer; siz: Int64);
begin
  if not Connected then
      exit;
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stReceiveSize], siz);

  if FReceiveProcessing or FAllSendProcessing then
      FReceivedAbort := not FillSequencePacketTo(buff, siz, FReceivedBuffer_Busy)
  else
    begin
      FReceivedBuffer.Position := FReceivedBuffer.Size;
      if FReceivedBuffer_Busy.Size > 0 then
        begin
          FReceivedBuffer.WritePtr(FReceivedBuffer_Busy.Memory, FReceivedBuffer_Busy.Size);
          FReceivedBuffer_Busy.Clear;
        end;
      FReceivedAbort := not FillSequencePacketTo(buff, siz, FReceivedBuffer);
    end;
end;

function TPeerIO.Internal_Process_Receive_Buffer(): Integer;
var
  Mapped_Received_Buffer: TMS64;
  Mapped_Position: Int64;
  rPos: Int64;
  rState: Boolean;
  dHead, dTail: Cardinal;
  dID: Byte;
  dSize: Cardinal;
  dHashSecurity: Byte;
  dHashSiz: Word;
  dHash: TBytes;
  dCipherSecurity: Byte;
  tmpStream: TMS64;
  d: TDFE;
  buff: TBytes;
  Total: Int64;
  sourSiz, compSiz: Cardinal;
  BreakAndDisconnect: Boolean;

  { continue send }
  BigStream_Chunk: PByte;
  BigStream_RealChunkSize: Integer;
  BigStream_SendDone: Boolean;
begin
  Result := 0;
  if FReceivedAbort then
    begin
      DelayClose;
      exit;
    end; // Abort flag set: close connection and exit.
  if FAllSendProcessing or
    FReceiveProcessing or
    FPause_Result_Send or
    (FResultDataBuffer.Size > 0) or
    FReceiveTriggerRuning then
    begin
      exit;
    end; // Prevent re‑entry while other operations are in progress.

  FReceiveProcessing := True; // Mark receive processing as active.

  BreakAndDisconnect := False;
  Mapped_Received_Buffer := TMS64.Create;

  if (FReceivedBuffer.Size > 0) or (FReceivedBuffer_Busy.Size > 0) then
    begin
      if FReceivedBuffer_Busy.Size > 0 then
        begin
          FReceivedBuffer.Position := FReceivedBuffer.Size;
          FReceivedBuffer.WritePtr(FReceivedBuffer_Busy.Memory, FReceivedBuffer_Busy.Size);
          FReceivedBuffer_Busy.Clear;
        end;
    end; // Merge busy buffer into main receive buffer.
  Mapped_Position := 0;
  Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position); // Zero‑copy map of current receive buffer.

  try
    while ((OwnerFramework.FPer_Progress_Loop_Limit <= 0) or (Result < OwnerFramework.FPer_Progress_Loop_Limit)) and (Mapped_Received_Buffer.Size > 0) and Connected do
      begin
        inc(Result); // Count commands processed in this cycle.

        Mapped_Received_Buffer.Position := 0;

        if FWaitOnResult then
          begin
            rPos := FillWaitOnResultBuffer(Mapped_Received_Buffer);
            rState := rPos > 0;

            if rState then
              begin
                inc(Mapped_Position, rPos);
                Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);
                Continue;
              end
            else
                Break;
          end; // Handle pending result response first.

        if FBigStreamReceiveProcessing then
          begin
            rPos := ReceivedBigStreamFragment(Mapped_Received_Buffer);
            rState := rPos > 0;

            if rState then
              begin
                inc(Mapped_Position, rPos);
                Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);
                Continue;
              end
            else
                Break;
          end; // Process big‑stream fragments if active.

        if FCompleteBufferReceiveProcessing then
          begin
            rPos := FillCompleteBufferBuffer(Mapped_Received_Buffer);
            rState := rPos > 0;

            if rState then
              begin
                inc(Mapped_Position, rPos);
                Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);
                Continue;
              end
            else
                Break;
          end; // Assemble complete‑buffer if active.

        { 0: head token }
        if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < C_Cardinal_Size + C_Byte_Size) then
            Break; // Not enough data for header.
        Mapped_Received_Buffer.read(dHead, C_Cardinal_Size);
        if dHead <> FHeadToken then
          begin
            BreakAndDisconnect := True;
            Break;
          end; // Invalid header: disconnect.
        { 1: data type }
        Mapped_Received_Buffer.read(dID, C_Byte_Size); // Read command type token.

        { done signal }
        if dID = FBigStreamReceiveDoneSignal then
          begin
            { 2: process tail token }
            Mapped_Received_Buffer.read(dTail, C_Cardinal_Size);
            if dTail <> FTailToken then
              begin
                PrintError('tail error!');
                BreakAndDisconnect := True;
                Break;
              end; // Verify tail token.

            { stripped stream }
            inc(Mapped_Position, Mapped_Received_Buffer.Position);
            Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);

            { done }
            FWaitBigStreamReceiveDoneSignal := False; // Big‑stream send done flag cleared.
          end
        else if dID = FBigStreamReceiveFragmentSignal then
          begin
            { 2: process tail token }
            Mapped_Received_Buffer.read(dTail, C_Cardinal_Size);
            if dTail <> FTailToken then
              begin
                PrintError('tail error!');
                BreakAndDisconnect := True;
                Break;
              end; // Verify tail.

            { stripped stream }
            inc(Mapped_Position, Mapped_Received_Buffer.Position);
            Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);

            { save }
            if (FBigStreamSending <> nil) then // If we are actively sending a big‑stream, send next chunk.
              begin
                BigStream_RealChunkSize := ZNet_Def_BigStream_ChunkSize;

                BigStream_SendDone := FBigStreamSending.Size - FBigStreamSendCurrentPos <= BigStream_RealChunkSize;

                if BigStream_SendDone then
                    BigStream_RealChunkSize := FBigStreamSending.Size - FBigStreamSendCurrentPos;

                BigStream_Chunk := GetMemory(BigStream_RealChunkSize);

                try
                  FBigStreamSending.Position := FBigStreamSendCurrentPos;
                  FBigStreamSending.read(BigStream_Chunk^, BigStream_RealChunkSize);
                except
                  FreeMemory(BigStream_Chunk);
                  PrintError('BigStream IO read error!');
                  BreakAndDisconnect := True;
                  Break;
                end; // Read next chunk from source stream.

                try
                  SendBigStreamMiniPacket(BigStream_Chunk, BigStream_RealChunkSize);
                  FreeMemory(BigStream_Chunk);
                  AtomInc(FBigStreamSendCurrentPos, BigStream_RealChunkSize);
                except
                  PrintError('BigStream send error!');
                  BreakAndDisconnect := True;
                  Break;
                end; // Send the chunk and advance position.

                if BigStream_SendDone then
                  begin
                    if Assigned(OwnerFramework.FOnBigStreamInterface) then
                        OwnerFramework.FOnBigStreamInterface.EndStream(self, FBigStreamSending.Size);

                    if FBigStreamSendDoneTimeFree then
                        DisposeObject(FBigStreamSending);
                    FBigStreamSending := nil;
                    FBigStreamSendCurrentPos := -1;
                    FBigStreamSendDoneTimeFree := False;
                  end // Transfer complete: cleanup.
                else
                  begin
                    if Assigned(OwnerFramework.FOnBigStreamInterface) then
                        OwnerFramework.FOnBigStreamInterface.Process(self, FBigStreamSending.Size, FBigStreamSendCurrentPos);
                  end; // Notify progress.
              end;
          end
        else if FWaitBigStreamReceiveDoneSignal then
          begin
            PrintError('BigStream error: FWaitBigStreamReceiveDoneSignal is True');
            BreakAndDisconnect := True;
            Break;
          end // Unexpected state: disconnect.
        else if dID = FBigStreamToken then // New big‑stream header received.
          begin
            { 2:stream size }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < C_Int64_Size) then
                Break;
            Mapped_Received_Buffer.read(Total, C_Int64_Size); // Total stream size.

            { 3:command len }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < C_Cardinal_Size) then
                Break;
            Mapped_Received_Buffer.read(dSize, C_Cardinal_Size); // Command name length.

            { 4:command and tial token }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < dSize + C_Cardinal_Size) then
                Break;
            SetLength(buff, dSize);
            if dSize > 0 then
                Mapped_Received_Buffer.read(buff[0], dSize); // Read command name.

            { 5: process tail token }
            Mapped_Received_Buffer.read(dTail, C_Cardinal_Size);
            if dTail <> FTailToken then
              begin
                PrintError('tail error!');
                BreakAndDisconnect := True;
                Break;
              end; // Verify tail.

            FBigStreamTotal := Total;
            FBigStreamCompleted := 0;
            FBigStream_Current_Received := 0;
            FBigStreamFragmentSignal_SendedState := False;
            FBigStreamCmd := umlStringOf(buff).Text;
            FBigStreamReceiveProcessing := True; // Start receiving big‑stream.
            SetLength(buff, 0);

            { stripped stream }
            inc(Mapped_Position, Mapped_Received_Buffer.Position);
            Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);

            { do stream state }
            if Assigned(OwnerFramework.FOnBigStreamInterface) then
                OwnerFramework.FOnBigStreamInterface.BeginStream(self, FBigStreamTotal);

            AtomInc(OwnerFramework.Statistics[TStatisticsType.stReceiveBigStream]);
          end
        else if dID = FCompleteBufferToken then // Complete‑buffer header.
          begin
            { 2:complete buff size }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < C_Cardinal_Size * 3) then
                Break;
            Mapped_Received_Buffer.read(sourSiz, C_Cardinal_Size); // Original size.
            Mapped_Received_Buffer.read(compSiz, C_Cardinal_Size); // Compressed size (0 if none).
            Mapped_Received_Buffer.read(dSize, C_Cardinal_Size); // Command name length.

            { 3:command and tial token }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < dSize + C_Cardinal_Size) then
                Break;
            SetLength(buff, dSize);
            if Length(buff) > 0 then
                Mapped_Received_Buffer.read(buff[0], dSize); // Read command name.

            { 4: process tail token }
            Mapped_Received_Buffer.read(dTail, C_Cardinal_Size);
            if dTail <> FTailToken then
              begin
                PrintError('tail error!');
                BreakAndDisconnect := True;
                Break;
              end; // Verify tail.

            if (OwnerFramework.FMaxCompleteBufferSize > 0) and (sourSiz > OwnerFramework.FMaxCompleteBufferSize) then
              begin
                PrintError('Oversize of CompleteBuffer cmd: ' + umlStringOf(buff).Text);
                BreakAndDisconnect := True;
                Break;
              end; // Security check: reject oversized buffers.

            if compSiz > 0 then
                FCompleteBufferTotal := compSiz
            else
                FCompleteBufferTotal := sourSiz; // Total data to receive.
            FCompleteBufferCompressedSize := compSiz;
            FCompleteBufferCompleted := 0;
            FCompleteBufferCmd := umlStringOf(buff).Text;
            FCompleteBufferReceiveProcessing := True; // Start complete‑buffer assembly.
            FCompleteBufferReceivedStream.Clear;
            FCompleteBufferReceivedStream.Delta := umlMax(FCompleteBufferTotal, 1024 * 64);
            SetLength(buff, 0);

            { stripped stream }
            inc(Mapped_Position, Mapped_Received_Buffer.Position);
            Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);

            AtomInc(OwnerFramework.Statistics[TStatisticsType.stReceiveCompleteBuffer]);
          end
        else if dID in [FConsoleToken, FStreamToken, FConsoleNotifyToken, FStreamNotifyToken] then // Regular command.
          begin
            { 2: size }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < C_Cardinal_Size) then
                Break;
            Mapped_Received_Buffer.read(dSize, C_Cardinal_Size); // Payload size.

            { 3:verify code header }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < 3) then
                Break;
            Mapped_Received_Buffer.read(dHashSecurity, C_Byte_Size); // Hash algorithm.
            Mapped_Received_Buffer.read(dHashSiz, C_Word_Size); // Hash length.

            { 4:verify code body }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < dHashSiz) then
                Break;
            SetLength(dHash, dHashSiz);
            if Length(dHash) > 0 then
                Mapped_Received_Buffer.read(dHash[0], dHashSiz); // Hash data.

            { 5: Encrypt style }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < C_Byte_Size) then
                Break;
            Mapped_Received_Buffer.read(dCipherSecurity, C_Byte_Size); // Cipher used.

            { 6: process stream }
            if (Mapped_Received_Buffer.Size - Mapped_Received_Buffer.Position < dSize + C_Cardinal_Size) then
                Break;
            tmpStream := TMS64.Create;
            tmpStream.SetPointerWithProtectedMode(Mapped_Received_Buffer.PositionAsPtr, dSize); // Zero‑copy map payload.
            Mapped_Received_Buffer.Position := Mapped_Received_Buffer.Position + dSize;

            { 7: process tail token }
            Mapped_Received_Buffer.read(dTail, C_Cardinal_Size);
            if dTail <> FTailToken then
              begin
                PrintError('tail error!');
                BreakAndDisconnect := True;
                Break;
              end; // Verify tail.

            FReceiveDataCipherSecurity := TCipherSecurity(dCipherSecurity);

            try
                Encrypt(FReceiveDataCipherSecurity, tmpStream.Memory, tmpStream.Size, FCipherKey, False);
            except
              PrintError('Encrypt error!');
              DisposeObject(tmpStream);
              BreakAndDisconnect := True;
              Break;
            end; // Decrypt payload.

            if not VerifyHashCode(THashSecurity(dHashSecurity), tmpStream.Memory, tmpStream.Size, dHash) then
              begin
                PrintError('verify error!');
                DisposeObject(tmpStream);
                BreakAndDisconnect := True;
                Break;
              end; // Verify integrity.

            d := TDFE.Create;
            tmpStream.Position := 0;
            try
              if d.DecodeFrom(tmpStream, True) < 0 then
                begin
                  PrintError('decrypt error!');
                  DisposeObject(tmpStream);
                  DisposeObject(d);
                  BreakAndDisconnect := True;
                  Break;
                end;
            except
              PrintError('decrypt error!');
              DisposeObject(tmpStream);
              DisposeObject(d);
              BreakAndDisconnect := True;
              Break;
            end; // Deserialise DFE.
            DisposeObject(tmpStream);

            { stripped stream }
            inc(Mapped_Position, Mapped_Received_Buffer.Position);
            Mapped_Received_Buffer.Mapping(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);

            try
                ExecuteDataFrame(dID, d); // Dispatch to command handler.
            except
              PrintError('Execute error!');
              DisposeObject(d);
              BreakAndDisconnect := True;
              Break;
            end;
            DisposeObject(d);

            AtomInc(OwnerFramework.Statistics[TStatisticsType.stRequest]); // Count request.
          end
        else
          begin
            BreakAndDisconnect := True;
            Break;
          end; // Unknown token: disconnect.
      end;
  finally
    { rebuild stream }
    DisposeObject(Mapped_Received_Buffer);
    if Mapped_Position > 0 then
      begin
        tmpStream := TMS64.CustomCreate(FReceivedBuffer.Delta);
        if FReceivedBuffer.Size - Mapped_Position > 0 then
            tmpStream.WritePtr(FReceivedBuffer.PositionAsPtr(Mapped_Position), FReceivedBuffer.Size - Mapped_Position);
        DisposeObject(FReceivedBuffer);
        FReceivedBuffer := tmpStream;
      end; // Trim consumed data from receive buffer.

    FReceivedBuffer.Position := FReceivedBuffer.Size;
    FReceiveProcessing := False; // Clear processing flag.

    FLast_Process_Receive_Buffer_CPU_Is_Full := (OwnerFramework.FPer_Progress_Loop_Limit > 0) and (Result >= OwnerFramework.FPer_Progress_Loop_Limit);

    if not BreakAndDisconnect then
      begin
        Process_Send_Buffer(); // After receive, attempt to send queued data.
      end
    else
        DelayClose() // On error, close connection.
  end;
end;

procedure TPeerIO.Internal_Process_Send_Buffer();
var
  p: PQueueData;
begin
  if FAllSendProcessing or
    FReceiveProcessing or
    FWaitOnResult or
    FBigStreamReceiveProcessing or
    (FBigStreamSending <> nil) or
    FReceiveTriggerRuning or
    FWaitBigStreamReceiveDoneSignal then
    begin
      exit;
    end;

  FAllSendProcessing := True;

  if FResultDataBuffer.Size > 0 then
    begin
      Internal_Send_Result_Data();
      FAllSendProcessing := False;
      exit;
    end;

  FSend_Queue_Critical.Lock;
  try
    while FSend_Queue_Pool.Num > 0 do
      begin
        if not Connected then
            Break;
        if FWaitOnResult then
            Break;
        p := FSend_Queue_Pool.current^.data;
        FCurrentQueueData := p;
        case p^.State of
          qsSendConsoleCMD:
            begin
              AtomInc(OwnerFramework.Statistics[TStatisticsType.stConsole]);
              FSyncPick := p;
              FWaitOnResult := True;
              Internal_Send_Console_Cmd();
              FSyncPick := nil;
              FSend_Queue_Pool.Next;
              Break;
            end;
          qsSendStreamCMD:
            begin
              AtomInc(OwnerFramework.Statistics[TStatisticsType.stStream]);
              FSyncPick := p;
              FWaitOnResult := True;
              Internal_Send_Stream_Cmd();
              FSyncPick := nil;
              FSend_Queue_Pool.Next;
              Break;
            end;
          qsSendConsoleNotifyCMD:
            begin
              AtomInc(OwnerFramework.Statistics[TStatisticsType.stDirestConsole]);
              FSyncPick := p;
              Internal_Send_ConsoleNotify_Cmd();
              FSyncPick := nil;
              DisposeQueueData(p);
              FSend_Queue_Pool.Next;
            end;
          qsSendStreamNotifyCMD:
            begin
              AtomInc(OwnerFramework.Statistics[TStatisticsType.stDirestStream]);
              FSyncPick := p;
              Internal_Send_StreamNotify_Cmd();
              FSyncPick := nil;
              DisposeQueueData(p);
              FSend_Queue_Pool.Next;
            end;
          qsSendBigStream:
            begin
              AtomInc(OwnerFramework.Statistics[TStatisticsType.stSendBigStream]);
              FSyncPick := p;
              FWaitBigStreamReceiveDoneSignal := True;
              Internal_Send_BigStream_Cmd();
              FSyncPick := nil;
              DisposeQueueData(p);
              FSend_Queue_Pool.Next;
              Break;
            end;
          qsSendCompleteBuffer:
            begin
              AtomInc(OwnerFramework.Statistics[TStatisticsType.stSendCompleteBuffer]);
              FSyncPick := p;
              Internal_Send_CompleteBuffer_Cmd();
              FSyncPick := nil;
              DisposeQueueData(p);
              FSend_Queue_Pool.Next;
            end;
          else PrintError('IO Queue state error.');
        end;
      end;
  finally
    FAllSendProcessing := False;
    FSend_Queue_Critical.UnLock;
  end;
end;

procedure TPeerIO.CheckAndTriggerFailedWaitResult;
var
  tmp: TDFE;
begin
  if (FCurrentQueueData <> nil) and (FWaitOnResult) then
    begin
      try
        if FCurrentQueueData^.State = qsSendConsoleCMD then
          begin
            if Assigned(FCurrentQueueData^.OnConsoleFailedM) then
                FCurrentQueueData^.OnConsoleFailedM(self, FCurrentQueueData^.Param1, FCurrentQueueData^.Param2, FCurrentQueueData^.ConsoleData)
            else if Assigned(FCurrentQueueData^.OnConsoleFailedP) then
                FCurrentQueueData^.OnConsoleFailedP(self, FCurrentQueueData^.Param1, FCurrentQueueData^.Param2, FCurrentQueueData^.ConsoleData);
          end
        else if FCurrentQueueData^.State = qsSendStreamCMD then
          begin
            tmp := TDFE.Create;
            FCurrentQueueData^.StreamData.Position := 0;
            tmp.DecodeFrom(FCurrentQueueData^.StreamData, True);
            if Assigned(FCurrentQueueData^.OnStreamFailedM) then
                FCurrentQueueData^.OnStreamFailedM(self, FCurrentQueueData^.Param1, FCurrentQueueData^.Param2, tmp)
            else if Assigned(FCurrentQueueData^.OnStreamFailedP) then
                FCurrentQueueData^.OnStreamFailedP(self, FCurrentQueueData^.Param1, FCurrentQueueData^.Param2, tmp);
            DisposeObject(tmp);
          end;
        DisposeQueueData(FCurrentQueueData);
      except
      end;
      FCurrentQueueData := nil;
    end;
end;

procedure TPeerIO.Internal_Close_P2PVMTunnel;
begin
  if FP2PVMTunnel <> nil then
    begin
      OwnerFramework.p2pVMTunnelClose(self, FP2PVMTunnel);
      FP2PVMTunnel.CloseP2PVMTunnel;
      DisposeObjectAndNil(FP2PVMTunnel);
    end;
  SetLength(FP2PVM_Auth_Token, 0);
  SetLength(FP2PVM_Cipher_Key, 0);
  DisposeObjectAndNil(FP2PVM_Cipher);
end;

constructor TPeerIO.Create(OwnerFramework_: TZNet; IOInterface_: TCore_Object);
var
  kref: TInt64;
begin
  inherited Create;

  FOwnerFramework := OwnerFramework_;
  FIOInterface := IOInterface_;

  OwnerFramework.Lock_All_IO;

  FDisable_Progress := False;

  FID := OwnerFramework_.MakeID;
  FIO_Create_TimeTick := GetTimeTick();

  FHeadToken := ZNet_Def_DataHeadToken;
  FTailToken := ZNet_Def_DataTailToken;

  FConsoleToken := ZNet_Def_DefaultConsoleToken;
  FStreamToken := ZNet_Def_DefaultStreamToken;
  FConsoleNotifyToken := ZNet_Def_DefaultConsoleNotifyToken;
  FStreamNotifyToken := ZNet_Def_DefaultStreamNotifyToken;
  FBigStreamToken := ZNet_Def_DefaultBigStreamToken;
  FBigStreamReceiveFragmentSignal := ZNet_Def_DefaultBigStreamReceiveFragmentSignal;
  FBigStreamReceiveDoneSignal := ZNet_Def_DefaultBigStreamReceiveDoneSignal;
  FCompleteBufferToken := ZNet_Def_DefaultCompleteBufferToken;

  FReceived_Physics_Critical := TCritical.Create(ClassName + '.FReceived_Physics_Critical');
  FReceived_Physics_Fragment_Pool := TPhysics_Fragment_Pool.Create;

  FLast_Process_Receive_Buffer_CPU_Is_Full := False;
  FReceivedAbort := False;
  FReceivedBuffer := TMS64.CustomCreate(8192);
  FReceivedBuffer_Busy := TMS64.CustomCreate(8192);

  FBigStreamReceiveProcessing := False;
  FBigStreamTotal := 0;
  FBigStreamCompleted := 0;
  FBigStream_Current_Received := 0;
  FBigStreamFragmentSignal_SendedState := False;
  FBigStreamCmd := '';
  FSyncBigStreamReceive := nil;
  FBigStreamSending := nil;
  FBigStreamSendCurrentPos := -1;
  FBigStreamSendDoneTimeFree := False;
  FWaitBigStreamReceiveDoneSignal := False;

  FCompleteBufferReceiveProcessing := False;
  FCompleteBufferTotal := 0;
  FCompleteBufferCompressedSize := 0;
  FCompleteBufferCompleted := 0;
  FCompleteBufferCmd := '';
  FCompleteBufferReceivedStream := TMS64.CustomCreate(umlMin(OwnerFramework.FMaxCompleteBufferSize, 64 * 1024));
  FCompleteBuffer_Current_Trigger := nil;

  FCurrentQueueData := nil;
  FWaitOnResult := False;
  FPause_Result_Send := False;
  FReceiveTriggerRuning := False;
  FReceiveDataCipherSecurity := TCipherSecurity.csNone;
  FResultDataBuffer := TMS64.Create;
  FSendDataCipherSecurity := OwnerFramework.RandomCipherSecurity;
  FCanPauseResultSend := False;

  FSend_Queue_Critical := TCritical.Create(ClassName + '.FSend_Queue_Critical');
  FSend_Queue_Pool := TQueueData_Order.Create;

  UpdateLastCommunicationTime;
  LastCommunicationTick_Received := FLastCommunicationTick;
  LastCommunicationTick_KeepAlive := LastCommunicationTick_Received;
  LastCommunicationTick_Sending := FLastCommunicationTick;

  { generate random key }
  TMISC.GenerateRandomKey(kref, C_Int64_Size);
  TCipher.GenerateKey(FSendDataCipherSecurity, @kref, C_Int64_Size, FCipherKey);
  FDecryptInstance := nil;
  FEncryptInstance := nil;

  FRemoteExecutedForConnectInit := False;

  FAllSendProcessing := False;
  FReceiveProcessing := False;

  FInCmd := '';
  FInText := '';
  FOutText := '';
  FInDataFrame := TDFE.Create;
  FOutDataFrame := TDFE.Create;
  FResult_Text := '';
  FResult_DFE := TDFE.Create;
  FSyncPick := nil;

  FWaitSendBusy := False;
  FReceiveCommandRuning := False;
  FReceiveResultRuning := False;

  FProgressRunning := False;
  FTimeOutProcessDone := False;
  FLast_IO_Is_IDLE := True;
  FLast_IO_IDLE_Time := FIO_Create_TimeTick;

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stConnected]);

  InitSequencePacketModel(64, $FFFF);

  FP2PVMTunnel := nil;
  SetLength(FP2PVM_Auth_Token, 0);
  SetLength(FP2PVM_Cipher_Key, 0);
  FP2PVM_Cipher := nil;

  On_Internal_Send_Byte_Buffer := OwnerFramework.Framework_Internal_Send_Byte_Buffer;
  On_Internal_Save_Receive_Buffer := OwnerFramework.Framework_Internal_Save_Receive_Buffer;
  On_Internal_Process_Receive_Buffer := OwnerFramework.Framework_Internal_Process_Receive_Buffer;
  On_Internal_Process_Send_Buffer := OwnerFramework.Framework_Internal_Process_Send_Buffer;
  OnCreate := OwnerFramework.Framework_Internal_IO_Create;
  OnDestroy := OwnerFramework.Framework_Internal_IO_Destroy;

  OnVMBuildAuthModelResult_C := nil;
  OnVMBuildAuthModelResult_M := nil;
  OnVMBuildAuthModelResult_P := nil;
  OnVMBuildAuthModelResultIO_C := nil;
  OnVMBuildAuthModelResultIO_M := nil;
  OnVMBuildAuthModelResultIO_P := nil;
  OnVMAuthResult_C := nil;
  OnVMAuthResult_M := nil;
  OnVMAuthResult_P := nil;
  OnVMAuthResultIO_C := nil;
  OnVMAuthResultIO_M := nil;
  OnVMAuthResultIO_P := nil;

  FOnAutomatedP2PVMClientConnectionDone_C := nil;
  FOnAutomatedP2PVMClientConnectionDone_M := nil;
  FOnAutomatedP2PVMClientConnectionDone_P := nil;

  FUserData := nil;
  FUserValue := NULL;
  FUserVariants := nil;
  FUserObjects := nil;
  FUserAutoFreeObjects := nil;

  FUser_Define := OwnerFramework.FPeerIOUserDefineClass.Create(self);
  FUser_Special := OwnerFramework.FPeerIOUserSpecialClass.Create(self);
  BeginSendState := False;

  OnCreate(self);
  CreateAfter;

  OwnerFramework.FPeerIO_HashPool.Add(FID, self, False);
  OwnerFramework.UnLock_All_IO;
end;

procedure TPeerIO.CreateAfter;
begin
end;

destructor TPeerIO.Destroy;
var
  i: Integer;
begin
  CheckAndTriggerFailedWaitResult();

  try
      OnDestroy(self);
  except
  end;

  FreeSequencePacketModel();
  Internal_Close_P2PVMTunnel;

  if (FBigStreamSending <> nil) and (FBigStreamSendDoneTimeFree) then
    begin
      DisposeObject(FBigStreamSending);
      FBigStreamSending := nil;
    end;

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stDisconnect]);

  OwnerFramework.Lock_All_IO;
  OwnerFramework.FPeerIO_HashPool.Delete(FID);
  OwnerFramework.UnLock_All_IO;

  FSend_Queue_Critical.Lock;
  while FSend_Queue_Pool.Num > 0 do
    begin
      DisposeQueueData(FSend_Queue_Pool.current^.data);
      FSend_Queue_Pool.Next;
    end;
  FSend_Queue_Critical.UnLock;

  if (FUser_Define.FBusy) or (FUser_Define.FBusyNum > 0) then
    begin
      FUser_Define.FOwner := nil;
      TCompute.RunM_NP(FUser_Define.DelayFreeOnBusy);
    end
  else
      DisposeObject(FUser_Define);

  if (FUser_Special.FBusy) or (FUser_Special.FBusyNum > 0) then
    begin
      FUser_Special.FOwner := nil;
      TCompute.RunM_NP(FUser_Special.DelayFreeOnBusy);
    end
  else
      DisposeObject(FUser_Special);

  { free buffer }
  DisposeObject(FSend_Queue_Pool);
  DisposeObject(FSend_Queue_Critical);
  DisposeObject(FReceived_Physics_Critical);
  DisposeObject(FReceived_Physics_Fragment_Pool);
  DisposeObject(FReceivedBuffer);
  DisposeObject(FReceivedBuffer_Busy);
  DisposeObject(FCompleteBufferReceivedStream);
  DisposeObject(FResultDataBuffer);
  DisposeObject(FInDataFrame);
  DisposeObject(FOutDataFrame);
  DisposeObject(FResult_DFE);

  { free cipher instance }
  DisposeObjectAndNil(FDecryptInstance);
  DisposeObjectAndNil(FEncryptInstance);

  if FUserVariants <> nil then
      DisposeObject(FUserVariants);
  if FUserObjects <> nil then
      DisposeObject(FUserObjects);
  if FUserAutoFreeObjects <> nil then
      DisposeObject(FUserAutoFreeObjects);
  inherited Destroy;
end;

function TPeerIO.IOBusy: Boolean;
var
  io_idle_: Boolean;
begin
  FReceived_Physics_Critical.Lock;
  try
    Result :=
      (IOSendBuffer.Size > 0) or
      (SendingSequencePacketHistory.Count > 0) or
      (SequencePacketReceivedPool.Count > 0) or
      (FSend_Queue_Pool.Num > 0) or
      (FReceivedBuffer.Size > 0) or
      (FReceivedBuffer_Busy.Size > 0) or
      (FWaitOnResult) or
      (FBigStreamReceiveProcessing) or
      (FCompleteBufferReceiveProcessing) or
      (FPause_Result_Send) or
      (FReceiveTriggerRuning) or
      (FReceived_Physics_Fragment_Pool.Num > 0);

    if not Result then
      if FOwnerFramework.InheritsFrom(TZNet_Client) then
        begin
          FOwnerFramework.FSend_Queue_Swap_Pool.Lock;
          Result := FOwnerFramework.FSend_Queue_Swap_Pool.Num > 0;
          FOwnerFramework.FSend_Queue_Swap_Pool.UnLock;
        end;

    { update io state }
    io_idle_ := not Result;
    if io_idle_ and (io_idle_ <> FLast_IO_Is_IDLE) then
        FLast_IO_IDLE_Time := GetTimeTick;
    FLast_IO_Is_IDLE := io_idle_;
  finally
      FReceived_Physics_Critical.UnLock;
  end;
end;

procedure TPeerIO.IO_IDLE_TraceC(data: TCore_Object; OnNotify: TOnDataNotify_C);
var
  p: PIDLE_Trace;
begin
  if not IOBusy then
    begin
      OnNotify(data);
      exit;
    end;

  New(p);
  p^.ID := ID;
  p^.data := data;
  p^.OnNotifyC := OnNotify;
  p^.OnNotifyM := nil;
  p^.OnNotifyP := nil;
  with OwnerFramework.ProgressEngine.PostExecuteM(False, 0.1, OwnerFramework.IDLE_Trace_Execute) do
    begin
      Data5 := p;
      Ready();
    end;
end;

procedure TPeerIO.IO_IDLE_TraceM(data: TCore_Object; OnNotify: TOnDataNotify_M);
var
  p: PIDLE_Trace;
begin
  if not IOBusy then
    begin
      OnNotify(data);
      exit;
    end;

  New(p);
  p^.ID := ID;
  p^.data := data;
  p^.OnNotifyC := nil;
  p^.OnNotifyM := OnNotify;
  p^.OnNotifyP := nil;
  with OwnerFramework.ProgressEngine.PostExecuteM(False, 0.1, OwnerFramework.IDLE_Trace_Execute) do
    begin
      Data5 := p;
      Ready();
    end;
end;

procedure TPeerIO.IO_IDLE_TraceP(data: TCore_Object; OnNotify: TOnDataNotify_P);
var
  p: PIDLE_Trace;
begin
  if not IOBusy then
    begin
      OnNotify(data);
      exit;
    end;

  New(p);
  p^.ID := ID;
  p^.data := data;
  p^.OnNotifyC := nil;
  p^.OnNotifyM := nil;
  p^.OnNotifyP := OnNotify;
  with OwnerFramework.ProgressEngine.PostExecuteM(False, 0.1, OwnerFramework.IDLE_Trace_Execute) do
    begin
      Data5 := p;
      Ready();
    end;
end;

function TPeerIO.Is_Double_Tunnel: Boolean;
begin
  Result := False;
  if OwnerFramework = nil then
      exit;

  if OwnerFramework.DoubleChannelFramework is TDTService_NoAuth then
      Result := True
  else if OwnerFramework.DoubleChannelFramework is TDTClient_NoAuth then
      Result := True
  else if OwnerFramework.DoubleChannelFramework is TDTService_VirtualAuth then
      Result := True
  else if OwnerFramework.DoubleChannelFramework is TDTClient_VirtualAuth then
      Result := True
  else if OwnerFramework.DoubleChannelFramework is TDTService then
      Result := True
  else if OwnerFramework.DoubleChannelFramework is TDTClient then
      Result := True;
end;

function TPeerIO.Is_Recveive_Tunnel: Boolean;
begin
  Result := False;
  if OwnerFramework = nil then
      exit;

  if OwnerFramework.DoubleChannelFramework is TDTService_NoAuth then
      Result := TDTService_NoAuth(OwnerFramework.DoubleChannelFramework).RecvTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTClient_NoAuth then
      Result := TDTClient_NoAuth(OwnerFramework.DoubleChannelFramework).RecvTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTService_VirtualAuth then
      Result := TDTService_VirtualAuth(OwnerFramework.DoubleChannelFramework).RecvTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTClient_VirtualAuth then
      Result := TDTClient_VirtualAuth(OwnerFramework.DoubleChannelFramework).RecvTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTService then
      Result := TDTService(OwnerFramework.DoubleChannelFramework).RecvTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTClient then
      Result := TDTClient(OwnerFramework.DoubleChannelFramework).RecvTunnel = OwnerFramework;
end;

function TPeerIO.Is_Send_Tunnel: Boolean;
begin
  Result := False;
  if OwnerFramework = nil then
      exit;

  if OwnerFramework.DoubleChannelFramework is TDTService_NoAuth then
      Result := TDTService_NoAuth(OwnerFramework.DoubleChannelFramework).SendTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTClient_NoAuth then
      Result := TDTClient_NoAuth(OwnerFramework.DoubleChannelFramework).SendTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTService_VirtualAuth then
      Result := TDTService_VirtualAuth(OwnerFramework.DoubleChannelFramework).SendTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTClient_VirtualAuth then
      Result := TDTClient_VirtualAuth(OwnerFramework.DoubleChannelFramework).SendTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTService then
      Result := TDTService(OwnerFramework.DoubleChannelFramework).SendTunnel = OwnerFramework
  else if OwnerFramework.DoubleChannelFramework is TDTClient then
      Result := TDTClient(OwnerFramework.DoubleChannelFramework).SendTunnel = OwnerFramework;
end;

function TPeerIO.Is_Link_OK: Boolean;
begin
  Result := False;
  if OwnerFramework = nil then
      exit;

  if UserDefine is TService_RecvTunnel_UserDefine_NoAuth then
    begin
      Result := TService_RecvTunnel_UserDefine_NoAuth(UserDefine).LinkOk;
    end
  else if UserDefine is TClient_RecvTunnel_NoAuth then
    begin
      if OwnerFramework.DoubleChannelFramework is TDTClient_NoAuth then
          Result := TDTClient_NoAuth(OwnerFramework.DoubleChannelFramework).LinkOk;
    end
  else if UserDefine is TService_RecvTunnel_UserDefine_VirtualAuth then
    begin
      Result := TService_RecvTunnel_UserDefine_VirtualAuth(UserDefine).LinkOk;
    end
  else if UserDefine is TClient_RecvTunnel_VirtualAuth then
    begin
      if OwnerFramework.DoubleChannelFramework is TDTClient_VirtualAuth then
          Result := TDTClient_VirtualAuth(OwnerFramework.DoubleChannelFramework).LinkOk;
    end
  else if UserDefine is TService_RecvTunnel_UserDefine then
    begin
      Result := TService_RecvTunnel_UserDefine(UserDefine).LinkOk;
    end
  else if UserDefine is TClient_RecvTunnel then
    begin
      if OwnerFramework.DoubleChannelFramework is TDTClient then
          Result := TDTClient(OwnerFramework.DoubleChannelFramework).LinkOk;
    end;
end;

function TPeerIO.Get_Send_Tunnel_IO: TPeerIO;
var
  Send_Tunnel: TZNet;
  Send_Tunnel_ID: Cardinal;
begin
  Result := nil;
  if not Get_Link_OK_Send_Tunnel(self, Send_Tunnel, Send_Tunnel_ID) then
      exit;
  Result := Send_Tunnel.PeerIO_HashPool[Send_Tunnel_ID];
end;

function TPeerIO.Get_Send_Tunnel(var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean;
begin
  Result := Get_Link_OK_Send_Tunnel(self, Send_Tunnel, Send_Tunnel_ID);
end;

function TPeerIO.Get_Recv_Tunnel_IO: TPeerIO;
var
  Recv_Tunnel: TZNet;
  Recv_Tunnel_ID: Cardinal;
begin
  Result := nil;
  if not Get_Link_OK_Recv_Tunnel(self, Recv_Tunnel, Recv_Tunnel_ID) then
      exit;
  Result := Recv_Tunnel.PeerIO_HashPool[Recv_Tunnel_ID];
end;

function TPeerIO.Get_Recv_Tunnel(var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean;
begin
  Result := Get_Link_OK_Recv_Tunnel(self, Recv_Tunnel, Recv_Tunnel_ID);
end;

function TPeerIO.p2pVMTunnelReadyOk: Boolean;
begin
  Result := (FP2PVMTunnel <> nil) and (FP2PVMTunnel.WasAuthed);
end;

procedure TPeerIO.BuildP2PAuthToken;
var
  d: TDFE;
begin
  ResetSequencePacketBuffer;
  FSequencePacketSignal := False;

  d := TDFE.Create;
  d.WriteInteger(umlRandomRange64(-MaxInt, MaxInt));
  SendStreamCmdM(C_BuildP2PAuthToken, d, OwnerFramework.Do_CMD_Result_BuildP2PAuthToken);
  DisposeObject(d);
  Internal_Process_Send_Buffer();

  OnVMBuildAuthModelResult_C := nil;
  OnVMBuildAuthModelResult_M := nil;
  OnVMBuildAuthModelResult_P := nil;
  OnVMBuildAuthModelResultIO_C := nil;
  OnVMBuildAuthModelResultIO_M := nil;
  OnVMBuildAuthModelResultIO_P := nil;
end;

procedure TPeerIO.BuildP2PAuthTokenC(const OnResult: TOnNotify_C);
begin
  BuildP2PAuthToken;
  OnVMBuildAuthModelResult_C := OnResult;
end;

procedure TPeerIO.BuildP2PAuthTokenM(const OnResult: TOnNotify_M);
begin
  BuildP2PAuthToken;
  OnVMBuildAuthModelResult_M := OnResult;
end;

procedure TPeerIO.BuildP2PAuthTokenP(const OnResult: TOnNotify_P);
begin
  BuildP2PAuthToken;
  OnVMBuildAuthModelResult_P := OnResult;
end;

procedure TPeerIO.BuildP2PAuthTokenIO_C(const OnResult: TOnIONotify_C);
begin
  BuildP2PAuthToken;
  OnVMBuildAuthModelResultIO_C := OnResult;
end;

procedure TPeerIO.BuildP2PAuthTokenIO_M(const OnResult: TOnIONotify_M);
begin
  BuildP2PAuthToken;
  OnVMBuildAuthModelResultIO_M := OnResult;
end;

procedure TPeerIO.BuildP2PAuthTokenIO_P(const OnResult: TOnIONotify_P);
begin
  BuildP2PAuthToken;
  OnVMBuildAuthModelResultIO_P := OnResult;
end;

procedure TPeerIO.DoP2PVM_Created(Sender: TZNet_P2PVM);
begin
end;

procedure TPeerIO.DoP2PVM_InstallLogicFramework(Inst: TZNet);
begin
end;

procedure TPeerIO.DoP2PVM_UninstallLogicFramework(Inst: TZNet);
begin
end;

procedure TPeerIO.OpenP2PVMTunnel(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString);
begin
  if FP2PVMTunnel = nil then
    begin
      ResetSequencePacketBuffer;
      FSequencePacketSignal := False;

      OnVMAuthResult_C := nil;
      OnVMAuthResult_M := nil;
      OnVMAuthResult_P := nil;
      OnVMAuthResultIO_C := nil;
      OnVMAuthResultIO_M := nil;
      OnVMAuthResultIO_P := nil;

      if SendRemoteRequest then
        begin
          if IOBusy then
            begin
              PrintError('OpenP2PVMTunnel failed: IO Busy.');
              exit;
            end;
          SendConsoleNotifyCmd(C_InitP2PTunnel, AuthToken);
          Process_Send_Buffer();
        end;

      FP2PVMTunnel := TZNet_P2PVM.Create(vmHashPoolSize);
      FP2PVMTunnel.QuietMode := OwnerFramework.QuietMode;
      FP2PVMTunnel.FVMID := FID;
      DoP2PVM_Created(FP2PVMTunnel);

      FP2PVMTunnel.OpenP2PVMTunnel(self);
      FP2PVMTunnel.AuthWaiting;

      FP2PVMTunnel.OnAuthSuccessOnesNotify := P2PVMAuthSuccess;
    end;
end;

procedure TPeerIO.OpenP2PVMTunnel(SendRemoteRequest: Boolean; const AuthToken: SystemString);
begin
  if OwnerFramework.FFrameworkIsClient then
      OpenP2PVMTunnel(16384, SendRemoteRequest, AuthToken)
  else
      OpenP2PVMTunnel(64, SendRemoteRequest, AuthToken);
end;

procedure TPeerIO.OpenP2PVMTunnelC(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_C);
begin
  OpenP2PVMTunnel(SendRemoteRequest, AuthToken);
  OnVMAuthResult_C := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelM(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_M);
begin
  OpenP2PVMTunnel(SendRemoteRequest, AuthToken);
  OnVMAuthResult_M := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelP(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_P);
begin
  OpenP2PVMTunnel(SendRemoteRequest, AuthToken);
  OnVMAuthResult_P := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelC(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_C);
begin
  OpenP2PVMTunnel(vmHashPoolSize, SendRemoteRequest, AuthToken);
  OnVMAuthResult_C := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelM(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_M);
begin
  OpenP2PVMTunnel(vmHashPoolSize, SendRemoteRequest, AuthToken);
  OnVMAuthResult_M := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelP(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_P);
begin
  OpenP2PVMTunnel(vmHashPoolSize, SendRemoteRequest, AuthToken);
  OnVMAuthResult_P := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelIO_C(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_C);
begin
  OpenP2PVMTunnel(SendRemoteRequest, AuthToken);
  OnVMAuthResultIO_C := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelIO_M(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_M);
begin
  OpenP2PVMTunnel(SendRemoteRequest, AuthToken);
  OnVMAuthResultIO_M := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelIO_P(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_P);
begin
  OpenP2PVMTunnel(SendRemoteRequest, AuthToken);
  OnVMAuthResultIO_P := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelIO_C(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_C);
begin
  OpenP2PVMTunnel(vmHashPoolSize, SendRemoteRequest, AuthToken);
  OnVMAuthResultIO_C := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelIO_M(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_M);
begin
  OpenP2PVMTunnel(vmHashPoolSize, SendRemoteRequest, AuthToken);
  OnVMAuthResultIO_M := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnelIO_P(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnIOState_P);
begin
  OpenP2PVMTunnel(vmHashPoolSize, SendRemoteRequest, AuthToken);
  OnVMAuthResultIO_P := OnResult;
  with OwnerFramework.ProgressPost.PostExecuteM(False, 10.0, OwnerFramework.VMAuthFailedDelayExecute) do
    begin
      Data3 := FID;
      Ready();
    end;
end;

procedure TPeerIO.OpenP2PVMTunnel;
begin
  OpenP2PVMTunnel(False, '');
end;

procedure TPeerIO.CloseP2PVMTunnel;
begin
  if IOBusy then
    begin
      PrintError('CloseP2PVMTunnel failed: IO Busy.');
      exit;
    end;
  SendConsoleNotifyCmd(C_CloseP2PTunnel, '');
  Process_Send_Buffer();
end;

procedure TPeerIO.Print(const v: SystemString);
var
  n: SystemString;
begin
  if not OwnerFramework.QuietMode then
    begin
      n := GetPeerIP;
      if n <> '' then
          OwnerFramework.DoPrint(PFormat('%s %s', [n, v]))
      else
          OwnerFramework.DoPrint(PFormat('%s', [v]));
    end;
end;

procedure TPeerIO.Print(const v: SystemString; const Args: array of const);
begin
  if not OwnerFramework.QuietMode then
      Print(PFormat(v, Args));
end;

procedure TPeerIO.PrintCommand(const v, Args: SystemString);
begin
  if OwnerFramework.QuietMode then
      exit;
  try
    if (not IsSystemCMD(Args)) and OwnerFramework.FPrintParams.Get_Default_Value(Args, True) then
        Print(PFormat(v, [Args]));
  except
      Print(PFormat(v, [Args]));
  end;
end;

procedure TPeerIO.PrintParam(const v, Args: SystemString);
begin
  if OwnerFramework.QuietMode then
      exit;
  try
    if (not IsSystemCMD(Args)) and OwnerFramework.FPrintParams.Get_Default_Value(Args, True) then
        Print(PFormat(v, [Args]));
  except
      Print(PFormat(v, [Args]));
  end;
end;

procedure TPeerIO.PrintError(const v: SystemString);
var
  n: SystemString;
begin
  n := GetPeerIP;
  if n <> '' then
      OwnerFramework.DoError(PFormat('error: %s %s', [n, v]))
  else
      OwnerFramework.DoError(PFormat('error: %s', [v]));
end;

procedure TPeerIO.PrintError(const v: SystemString; const Args: array of const);
begin
  PrintError(PFormat(v, Args));
end;

procedure TPeerIO.PrintWarning(const v: SystemString);
var
  n: SystemString;
begin
  n := GetPeerIP;
  if n <> '' then
      OwnerFramework.DoWarning(PFormat('Warning: %s %s', [n, v]))
  else
      OwnerFramework.DoWarning(PFormat('Warning: %s', [v]));
end;

procedure TPeerIO.PrintWarning(const v: SystemString; const Args: array of const);
begin
  PrintWarning(PFormat(v, Args));
end;

procedure TPeerIO.Progress;
begin
  if FDisable_Progress then
      exit;

  { anti dead loop }
  if FProgressRunning then
      exit;

  FProgressRunning := True;

  IOBusy();

  { send buffer }
  Process_Send_Buffer;

  { optimize physics model }
  try
    if not FLast_Process_Receive_Buffer_CPU_Is_Full then
        Extract_Physics_Fragment_To_Receive_Buffer;
    Process_Receive_Buffer;
  except
  end;

  { sequence packet model }
  try
      ProcessSequencePacketModel();
  except
  end;

  if FP2PVMTunnel <> nil then
    begin
      try
          FP2PVMTunnel.Progress;
      except
      end;
    end;

  try
      FUser_Define.Progress;
  except
  end;

  try
      FUser_Special.Progress;
  except
  end;

  if (not FTimeOutProcessDone) and (OwnerFramework.FIdleTimeOut > 0) and (StopCommunicationTime > OwnerFramework.FIdleTimeOut) then
    begin
      PrintWarning('IO "%s" Timeout %ss do Close', [ClassName, umlFloatToStr(StopCommunicationTime / 1000).Text]);
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stTimeOutDisconnect]);
      FTimeOutProcessDone := True;
      DelayClose(1.0);
    end;

  if (not FTimeOutProcessDone) and (OwnerFramework.FTimeOutKeepAlive) and (IsSequencePacketModel) and (FSequencePacketSignal) and
    ((OwnerFramework.Protocol = TCommunicationProtocol.cpZServer) and (FRemoteExecutedForConnectInit)) and
    (GetTimeTick() - LastCommunicationTick_KeepAlive > 1000) and (WriteBuffer_is_NULL) then
    begin
      SendSequencePacketKeepAlive(nil, 0);
      FlushIOSendBuffer;
      LastCommunicationTick_KeepAlive := GetTimeTick();
    end;

  { anti dead loop }
  FProgressRunning := False;
end;

procedure TPeerIO.DelayClose;
begin
  DelayClose(0);
end;

procedure TPeerIO.DelayClose(const t: Double);
begin
{$IFDEF DEBUG}
  PrintWarning('IO "%s" Delay do Close', [ClassName]);
{$ENDIF DEBUG}
  with OwnerFramework.ProgressPost.PostExecuteM(False, t, OwnerFramework.DelayClose) do
    begin
      Data3 := ID;
      Ready();
    end;
  FDisable_Progress := True;
end;

procedure TPeerIO.DelayFree;
begin
  DelayFree(0);
end;

procedure TPeerIO.DelayFree(const t: Double);
begin
{$IFDEF DEBUG}
  PrintWarning('IO "%s" Delay do Free', [ClassName]);
{$ENDIF DEBUG}
  with OwnerFramework.ProgressPost.PostExecuteM(False, t, OwnerFramework.DelayFree) do
    begin
      Data3 := ID;
      Ready();
    end;
  FDisable_Progress := True;
end;

procedure TPeerIO.Write_Physics_Fragment(const p: Pointer; siz: Int64);
var
  m64: TMem64;
begin
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stPhysicsFragmentCache], siz);
  FReceived_Physics_Critical.Lock;
  if OwnerFramework.FPhysicsFragmentSwapSpaceTechnology and (FReceived_Physics_Fragment_Pool.Num > OwnerFramework.FPhysicsFragmentSwapSpaceTrigger) then
      m64 := TZDB2_Swap_Space_Technology.RunTime_Pool.Create_Memory(p, siz, True)
  else
      m64 := TMem64.Create;
  m64.WritePtr(p, siz);
  FReceived_Physics_Fragment_Pool.Push(m64);
  FReceived_Physics_Critical.UnLock;
  UpdateLastCommunicationTime;
end;

function TPeerIO.Extract_Physics_Fragment_To_Receive_Buffer(): Int64;
begin
  Result := 0;
  FReceived_Physics_Critical.Lock;
  if FReceived_Physics_Fragment_Pool.Num > 0 then
    begin
      repeat
        if OwnerFramework.FPhysicsFragmentSwapSpaceTechnology and (FReceived_Physics_Fragment_Pool.First^.data is TZDB2_Swap_Space_Technology_Memory) then
            TZDB2_Swap_Space_Technology_Memory(FReceived_Physics_Fragment_Pool.First^.data).Prepare;
        if FReceived_Physics_Fragment_Pool.First^.data.Size > 0 then
          begin
            try
                On_Internal_Save_Receive_Buffer(self, FReceived_Physics_Fragment_Pool.First^.data.Memory, FReceived_Physics_Fragment_Pool.First^.data.Size);
            except
                Break; // loop to next time attempt
            end;
            AtomDec(OwnerFramework.Statistics[TStatisticsType.stPhysicsFragmentCache], FReceived_Physics_Fragment_Pool.First^.data.Size);
          end;
        inc(Result, FReceived_Physics_Fragment_Pool.First^.data.Size);
        FReceived_Physics_Fragment_Pool.Next;
      until (Result > OwnerFramework.FExtract_Physics_Fragment_Max_Size) or (FReceived_Physics_Fragment_Pool.Num <= 0);
      UpdateLastCommunicationTime;
      LastCommunicationTick_Received := FLastCommunicationTick;
      LastCommunicationTick_KeepAlive := LastCommunicationTick_Received;
    end;
  FReceived_Physics_Critical.UnLock;
end;

procedure TPeerIO.Process_Receive_Buffer();
begin
  On_Internal_Process_Receive_Buffer(self);
end;

procedure TPeerIO.Process_Send_Buffer();
begin
  On_Internal_Process_Send_Buffer(self);
end;

procedure TPeerIO.PostQueueData(p: PQueueData);
begin
  OwnerFramework.CmdSendStatistics.IncValue(p^.Cmd, 1);
  FSend_Queue_Critical.Lock;
  FSend_Queue_Pool.Push(p);
  FSend_Queue_Critical.UnLock;
end;

procedure TPeerIO.BeginWriteCustomBuffer;
begin
  WriteBufferOpen;
end;

procedure TPeerIO.EndWriteCustomBuffer;
begin
  WriteBufferFlush;
  WriteBufferClose;
end;

procedure TPeerIO.WriteCustomBuffer(const Buffer: PByte; const Size: NativeInt);
begin
  On_Internal_Send_Byte_Buffer(self, Buffer, Size);
end;

procedure TPeerIO.WriteCustomBuffer(const Buffer: TMS64);
begin
  WriteCustomBuffer(Buffer.Memory, Buffer.Size);
end;

procedure TPeerIO.WriteCustomBuffer(const Buffer: TMem64);
begin
  WriteCustomBuffer(Buffer.Memory, Buffer.Size);
end;

procedure TPeerIO.WriteCustomBuffer(const Buffer: TMS64; const doneFreeBuffer: Boolean);
begin
  WriteCustomBuffer(Buffer);
  if doneFreeBuffer then
      DisposeObject(Buffer);
end;

procedure TPeerIO.WriteCustomBuffer(const Buffer: TMem64; const doneFreeBuffer: Boolean);
begin
  WriteCustomBuffer(Buffer);
  if doneFreeBuffer then
      DisposeObject(Buffer);
end;

procedure TPeerIO.Pause;
begin
  if FCanPauseResultSend then
    begin
      FPause_Result_Send := True;
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stPause]);
    end
  else
      RaiseInfo('No Supported.');
end;

procedure TPeerIO.PauseResultSend;
begin
  Pause;
end;

procedure TPeerIO.BreakResultSend;
begin
  Pause;
end;

procedure TPeerIO.SkipResultSend;
begin
  Pause;
end;

procedure TPeerIO.NoResultSend;
begin
  Pause;
end;

procedure TPeerIO.StopResultSend;
begin
  Pause;
end;

procedure TPeerIO.Resume;
var
  headBuff: array [0 .. 2] of Byte;
  console_buff: TBytes;
  buff: TMS64;
  EnSiz: Int64;
  dHead, dTail: Cardinal;
  Len: Integer;
  Code: TBytes;
  bCipherSecurity: Byte;
begin
  if not FPause_Result_Send then
      exit;
  if FResultDataBuffer.Size > 0 then
      exit;

  AtomInc(OwnerFramework.Statistics[TStatisticsType.stContinue]);

  if FCurrentPauseResultSend_CommDataType in [FConsoleToken, FStreamToken] then
    begin
      buff := TMS64.Create;

      if FCurrentPauseResultSend_CommDataType = FConsoleToken then
        begin
          console_buff := TPascalString(FOutText).Bytes;
          { safe check. fixed by qq600585,2022-4-19 }
          if Length(console_buff) = 0 then
            begin
              SetLength(console_buff, 1);
              console_buff[0] := 0;
            end;
          buff.WritePtr(@console_buff[0], Length(console_buff));
        end
      else if OwnerFramework.FSendDataCompressed then
        begin
          if FOutDataFrame.ComputeEncodeSize > 1024 * 1024 then
              FOutDataFrame.EncodeAsSelectCompressor(TSelectCompressionMethod.scmZLIB_Max, buff, True)
          else
              FOutDataFrame.EncodeAsZLib(buff, True, False);
        end
      else if OwnerFramework.FFastEncrypt then
        begin
          EnSiz := FOutDataFrame.ComputeEncodeSize;
          // fast send, fixed by.qq600585
          FOutDataFrame.FastEncode32To(buff, EnSiz);
        end
      else
        begin
          // fast send, fixed by.qq600585
          FOutDataFrame.EncodeTo(buff, True, False);
        end;

      dHead := FHeadToken;
      dTail := FTailToken;
      Len := buff.Size;

      { generate hash source }
      GenerateHashCode(OwnerFramework.FHashSecurity, buff.Memory, buff.Size, Code);
      headBuff[0] := Byte(OwnerFramework.FHashSecurity);
      PWORD(@headBuff[1])^ := Length(Code);

      { generate encrypt data body }
      bCipherSecurity := Byte(FReceiveDataCipherSecurity);
      Encrypt(FReceiveDataCipherSecurity, buff.Memory, buff.Size, FCipherKey, True);

      { result data header }
      FResultDataBuffer.WritePtr(@dHead, C_Cardinal_Size);
      FResultDataBuffer.WritePtr(@Len, C_Integer_Size);

      { verify code }
      FResultDataBuffer.WritePtr(@headBuff[0], 3);
      if Length(Code) > 0 then
          FResultDataBuffer.WritePtr(@Code[0], Length(Code));

      { data body }
      FResultDataBuffer.WritePtr(@bCipherSecurity, C_Byte_Size);
      FResultDataBuffer.WritePtr(buff.Memory, Len);

      { data tail }
      FResultDataBuffer.WritePtr(@dTail, C_Cardinal_Size);

      DisposeObject(buff);

      AtomInc(OwnerFramework.Statistics[TStatisticsType.stResponse]);
    end;
  FPause_Result_Send := False;
end;

procedure TPeerIO.ContinueResultSend;
begin
  Resume;
end;

procedure TPeerIO.Continue_Send_Result;
begin
  Resume;
end;

procedure TPeerIO.ResumeResultSend;
begin
  Resume;
end;

procedure TPeerIO.NowResultSend;
begin
  Resume;
end;

function TPeerIO.ResultSendIsPaused: Boolean;
begin
  Result := FPause_Result_Send;
end;

function TPeerIO.GetBigStreamReceiveState(var Total, Complete: Int64): Boolean;
begin
  Result := FBigStreamReceiveProcessing;
  Total := FBigStreamTotal;
  Complete := FBigStream_Current_Received;
end;

function TPeerIO.GetBigStreamSendingState(var Total, Complete: Int64): Boolean;
begin
  if FBigStreamSending <> nil then
    begin
      Total := FBigStreamSending.Size;
      Result := True;
    end
  else
    begin
      Total := 0;
      Result := False;
    end;
  Complete := FBigStreamSendCurrentPos;
end;

function TPeerIO.GetBigStreamBatch: TBigStreamBatch;
begin
  Result := FUser_Define.FBigStreamBatch;
end;

function TPeerIO.Get_Last_IO_IDLE_Time: TTimeTick;
begin
  if not IOBusy() then
      Result := FLast_IO_IDLE_Time
  else
      Result := GetTimeTick();
end;

procedure TPeerIO.SetID(const Value: Cardinal);
begin
  if OwnerFramework is TZNet_Server then
    begin
      if Value = FID then
          exit;
      if not OwnerFramework.FPeerIO_HashPool.Exists_Key(FID) then
          PrintError('old ID illegal');
      if OwnerFramework.FPeerIO_HashPool.Exists_Key(Value) then
          PrintError('new ID illegal');
      OwnerFramework.Lock_All_IO;
      try
        OwnerFramework.FPeerIO_HashPool.Delete(FID);
        FID := Value;
        OwnerFramework.FPeerIO_HashPool.Add(FID, self, False);
      finally
          OwnerFramework.UnLock_All_IO;
      end;
    end
  else
    begin
      OwnerFramework.FPeerIO_HashPool.Delete(FID);
      FID := Value;
      OwnerFramework.FPeerIO_HashPool.Add(FID, self, True);
    end;
end;

function TPeerIO.CipherKeyPtr: PCipherKeyBuffer;
begin
  Result := @FCipherKey;
end;

procedure TPeerIO.GenerateHashCode(const hs: THashSecurity; buff: Pointer; siz: Integer; var output: TBytes);
begin
  TCipher.GenerateHashByte(hs, buff, siz, output);
  AtomInc(OwnerFramework.Statistics[TStatisticsType.stGenerateHash]);
end;

function TPeerIO.VerifyHashCode(const hs: THashSecurity; buff: Pointer; siz: Integer; var Code: TBytes): Boolean;
var
  buffCode: TBytes;
begin
  try
    GenerateHashCode(hs, buff, siz, buffCode);
    Result := TCipher.CompareHash(buffCode, Code);
  except
      Result := False;
  end;
end;

procedure TPeerIO.Encrypt(CS: TCipherSecurity; DataPtr: Pointer; Size: Cardinal; var k: TCipherKeyBuffer; enc: Boolean);
begin
  if Size = 0 then
      exit;

  if OwnerFramework.FFastEncrypt then
    begin
      if enc then
        begin
          if FEncryptInstance <> nil then
            if (FEncryptInstance.CipherSecurity <> CS) or (not TCipher.CompareKey(FEncryptInstance.LastGenerateKey, k)) then
                DisposeObjectAndNil(FEncryptInstance);
          if FEncryptInstance = nil then
            begin
              FEncryptInstance := CreateCipherClassFromBuffer(CS, k);
              FEncryptInstance.CBC := True;
              FEncryptInstance.ProcessTail := True;
            end;
          FEncryptInstance.Encrypt(DataPtr, Size);
        end
      else
        begin
          if FDecryptInstance <> nil then
            if (FDecryptInstance.CipherSecurity <> CS) or (not TCipher.CompareKey(FDecryptInstance.LastGenerateKey, k)) then
                DisposeObjectAndNil(FDecryptInstance);
          if FDecryptInstance = nil then
            begin
              FDecryptInstance := CreateCipherClassFromBuffer(CS, k);
              FDecryptInstance.CBC := True;
              FDecryptInstance.ProcessTail := True;
            end;
          FDecryptInstance.Decrypt(DataPtr, Size);
        end;
    end
  else if OwnerFramework.FUsedParallelEncrypt then
      SequEncryptCBC(CS, DataPtr, Size, k, enc, True)
  else
      SequEncryptCBCWithDirect(CS, DataPtr, Size, k, enc, True);

  if CS <> TCipherSecurity.csNone then
      AtomInc(OwnerFramework.Statistics[TStatisticsType.stEncrypt]);
end;

function TPeerIO.NoneCommunicationTime: TTimeTick;
begin
  Result := GetTimeTick - LastCommunicationTick_Received;
end;

procedure TPeerIO.UpdateLastCommunicationTime;
begin
  FLastCommunicationTick := GetTimeTick;
end;

procedure TPeerIO.SendConsoleCmd(const Cmd, ConsoleData: SystemString);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleCmd(self, Cmd, ConsoleData)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleCmd(Cmd, ConsoleData);
end;

procedure TPeerIO.SendConsoleCmdM(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleCmdM(self, Cmd, ConsoleData, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleCmdM(Cmd, ConsoleData, OnResult);
end;

procedure TPeerIO.SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleCmdM(self, Cmd, ConsoleData, Param1, Param2, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleCmdM(Cmd, ConsoleData, Param1, Param2, OnResult);
end;

procedure TPeerIO.SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleCmdM(self, Cmd, ConsoleData, Param1, Param2, OnResult, OnFailed)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleCmdM(Cmd, ConsoleData, Param1, Param2, OnResult, OnFailed);
end;

procedure TPeerIO.SendStreamCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmd(self, Cmd, StreamData, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmd(Cmd, StreamData, DoneAutoFree);
end;

procedure TPeerIO.SendStreamCmd(const Cmd: SystemString; StreamData: TDFE);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmd(self, Cmd, StreamData)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmd(Cmd, StreamData);
end;

procedure TPeerIO.SendStreamCmdM(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdM(self, Cmd, StreamData, OnResult, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdM(Cmd, StreamData, OnResult, DoneAutoFree);
end;

procedure TPeerIO.SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdM(self, Cmd, StreamData, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdM(Cmd, StreamData, OnResult);
end;

procedure TPeerIO.SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdM(self, Cmd, StreamData, Param1, Param2, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdM(Cmd, StreamData, Param1, Param2, OnResult);
end;

procedure TPeerIO.SendStreamCmdM(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdM(self, Cmd, StreamData, Param1, Param2, OnResult, OnFailed)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdM(Cmd, StreamData, Param1, Param2, OnResult, OnFailed);
end;

procedure TPeerIO.SendConsoleCmdP(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_P);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleCmdP(self, Cmd, ConsoleData, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleCmdP(Cmd, ConsoleData, OnResult);
end;

procedure TPeerIO.SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleCmdP(self, Cmd, ConsoleData, Param1, Param2, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleCmdP(Cmd, ConsoleData, Param1, Param2, OnResult);
end;

procedure TPeerIO.SendConsoleCmdP(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_P; const OnFailed: TOnConsoleFailed_P);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleCmdP(self, Cmd, ConsoleData, Param1, Param2, OnResult, OnFailed)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleCmdP(Cmd, ConsoleData, Param1, Param2, OnResult, OnFailed);
end;

procedure TPeerIO.SendStreamCmdP(const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_P; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdP(self, Cmd, StreamData, OnResult, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdP(Cmd, StreamData, OnResult, DoneAutoFree);
end;

procedure TPeerIO.SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_P);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdP(self, Cmd, StreamData, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdP(Cmd, StreamData, OnResult);
end;

procedure TPeerIO.SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdP(self, Cmd, StreamData, Param1, Param2, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdP(Cmd, StreamData, Param1, Param2, OnResult);
end;

procedure TPeerIO.SendStreamCmdP(const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_P; const OnFailed: TOnStreamFailed_P);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamCmdP(self, Cmd, StreamData, Param1, Param2, OnResult, OnFailed)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamCmdP(Cmd, StreamData, Param1, Param2, OnResult, OnFailed);
end;

procedure TPeerIO.SendConsoleNotifyCmd(const Cmd, ConsoleData: SystemString);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleNotifyCmd(self, Cmd, ConsoleData)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleNotifyCmd(Cmd, ConsoleData);
end;

procedure TPeerIO.SendConsoleNotifyCmd(const Cmd: SystemString);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendConsoleNotifyCmd(self, Cmd)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendConsoleNotifyCmd(Cmd);
end;

procedure TPeerIO.SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamNotifyCmd(self, Cmd, StreamData, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamNotifyCmd(Cmd, StreamData, DoneAutoFree);
end;

procedure TPeerIO.SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamNotifyCmd(self, Cmd, StreamData)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamNotifyCmd(Cmd, StreamData);
end;

procedure TPeerIO.SendStreamNotifyCmd(const Cmd: SystemString);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendStreamNotifyCmd(self, Cmd)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendStreamNotifyCmd(Cmd);
end;

function TPeerIO.WaitSendConsoleCmd(Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      Result := TZNet_Server(OwnerFramework).WaitSendConsoleCmd(self, Cmd, ConsoleData, TimeOut_)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      Result := TZNet_Client(OwnerFramework).WaitSendConsoleCmd(Cmd, ConsoleData, TimeOut_)
  else
      Result := '';
end;

procedure TPeerIO.WaitSendStreamCmd(const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).WaitSendStreamCmd(self, Cmd, StreamData, Result_, TimeOut_)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).WaitSendStreamCmd(Cmd, StreamData, Result_, TimeOut_);
end;

procedure TPeerIO.SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendBigStream(self, Cmd, BigStream, StartPos, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendBigStream(Cmd, BigStream, StartPos, DoneAutoFree);
end;

procedure TPeerIO.SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendBigStream(self, Cmd, BigStream, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendBigStream(Cmd, BigStream, DoneAutoFree);
end;

procedure TPeerIO.SendCompleteBuffer(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendCompleteBuffer(self, Cmd, buff, BuffSize, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendCompleteBuffer(Cmd, buff, BuffSize, DoneAutoFree);
end;

procedure TPeerIO.SendCompleteBuffer(const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendCompleteBuffer(self, Cmd, buff, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendCompleteBuffer(Cmd, buff, DoneAutoFree);
end;

procedure TPeerIO.SendCompleteBuffer(const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendCompleteBuffer(self, Cmd, buff, DoneAutoFree)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendCompleteBuffer(Cmd, buff, DoneAutoFree);
end;

procedure TPeerIO.SendCompleteBuffer(const Cmd: SystemString; buff: TDFE);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendCompleteBuffer(self, Cmd, buff)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendCompleteBuffer(Cmd, buff);
end;

procedure TPeerIO.SendCompleteBuffer_StreamNotify(const Cmd: SystemString; buff: TDFE);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendCompleteBuffer_StreamNotify(self, Cmd, buff)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendCompleteBuffer_StreamNotify(Cmd, buff);
end;

procedure TPeerIO.SendCompleteBuffer_NoWait_StreamM(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendCompleteBuffer_NoWait_StreamM(self, Cmd, buff, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendCompleteBuffer_NoWait_StreamM(Cmd, buff, OnResult);
end;

procedure TPeerIO.SendCompleteBuffer_NoWait_StreamP(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P);
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendCompleteBuffer_NoWait_StreamP(self, Cmd, buff, OnResult)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendCompleteBuffer_NoWait_StreamP(Cmd, buff, OnResult);
end;

procedure TPeerIO.Send_NULL();
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).Send_NULL(self)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).Send_NULL;
end;

procedure TPeerIO.SendNULL();
begin
  if OwnerFramework.InheritsFrom(TZNet_Server) then
      TZNet_Server(OwnerFramework).SendNULL(self)
  else if OwnerFramework.InheritsFrom(TZNet_Client) then
      TZNet_Client(OwnerFramework).SendNULL;
end;
