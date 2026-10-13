constructor TCommandStream.Create;
begin
  inherited Create;

  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
end;

destructor TCommandStream.Destroy;
begin
  inherited Destroy;
end;

function TCommandStream.Execute(Sender: TPeerIO; InData, OutData: TDFE): Boolean;
begin
  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Sender, InData, OutData)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Sender, InData, OutData)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Sender, InData, OutData)
    else
        Result := False;
  except
      Result := False;
  end;
end;

function TCommandStream.Execute_Complete_Stream(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
var
  UserData: UInt64;
  InDFE, OutDFE: TDFE;
  m64: TMS64;
  S_IO: TPeerIO;
begin
  InDFE := TDFE.Create;
  OutDFE := TDFE.Create;
  UserData := PUInt64(InData)^;
  InDFE.DecodeFromMemory(GetOffset(InData, 8), DataSize - 8, True);

  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Sender, InDFE, OutDFE)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Sender, InDFE, OutDFE)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Sender, InDFE, OutDFE)
    else
        Result := False;
  except
      Result := False;
  end;

  m64 := TMS64.Create;
  m64.WriteUInt64(UserData);
  OutDFE.FastEncodeTo(m64);

  if Sender.Is_Double_Tunnel and Sender.Is_Recveive_Tunnel then
    begin
      S_IO := Sender.Get_Send_Tunnel_IO;
      if S_IO <> nil then
          S_IO.SendCompleteBuffer(C_Complete_Buffer_Stream_Reponse, m64, True)
      else
          DisposeObject(m64);
    end;

  DisposeObject(InDFE);
  DisposeObject(OutDFE);
end;

constructor TCommandConsole.Create;
begin
  inherited Create;

  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
end;

destructor TCommandConsole.Destroy;
begin
  inherited Destroy;
end;

function TCommandConsole.Execute(Sender: TPeerIO; InData: SystemString; var OutData: SystemString): Boolean;
begin
  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Sender, InData, OutData)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Sender, InData, OutData)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Sender, InData, OutData)
    else
        Result := False;
  except
      Result := False;
  end;
end;

constructor TCommandStreamNotify.Create;
begin
  inherited Create;

  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
end;

destructor TCommandStreamNotify.Destroy;
begin
  inherited Destroy;
end;

function TCommandStreamNotify.Execute(Sender: TPeerIO; InData: TDFE): Boolean;
begin
  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Sender, InData)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Sender, InData)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Sender, InData)
    else
        Result := False;
  except
      Result := False;
  end;
end;

constructor TCommandConsoleNotify.Create;
begin
  inherited Create;

  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
end;

destructor TCommandConsoleNotify.Destroy;
begin
  inherited Destroy;
end;

function TCommandConsoleNotify.Execute(Sender: TPeerIO; InData: SystemString): Boolean;
begin
  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Sender, InData)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Sender, InData)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Sender, InData)
    else
        Result := False;
  except
      Result := False;
  end;
end;

constructor TCommandBigStream.Create;
begin
  inherited Create;

  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
end;

destructor TCommandBigStream.Destroy;
begin
  inherited Destroy;
end;

function TCommandBigStream.Execute(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64): Boolean;
begin
  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Sender, InData, BigStreamTotal, BigStreamCompleteSize)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Sender, InData, BigStreamTotal, BigStreamCompleteSize)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Sender, InData, BigStreamTotal, BigStreamCompleteSize)
    else
        Result := False;
  except
      Result := False;
  end;
end;

constructor TCommandCompleteBuffer.Create;
begin
  inherited Create;

  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
end;

destructor TCommandCompleteBuffer.Destroy;
begin
  inherited Destroy;
end;

function TCommandCompleteBuffer.Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
begin
  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Sender, InData, DataSize)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Sender, InData, DataSize)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Sender, InData, DataSize)
    else
        Result := False;
  except
      Result := False;
  end;
end;

procedure TCommandCompleteBuffer_StreamNotify_Thread.Do_Run_Decrypt_Thread(thSender: TCompute);
begin
  if Framework.ExistsID(ID) then
    begin
      with Framework.PostExecute.PostExecute(False) do
        begin
          DataEng.DecodeFrom(buff, True);
          Auto_Free_Pool.Add(self);
          OnExecute_M := Do_Post_Run;
          Ready;
        end;
    end
  else
    begin
      DelayFreeObj(1.0, self);
    end;
  AtomDec(Owner.FDecript_Activted_Thread_Num);
end;

procedure TCommandCompleteBuffer_StreamNotify_Thread.Do_Post_Run(Sender: TN_Post_Execute);
var
  IO_: TPeerIO;
begin
  IO_ := Framework.IOPool[ID];
  if IO_ <> nil then
    begin
      try
        if Assigned(Owner.FOnExecute_C) then
            Owner.FOnExecute_C(IO_, Sender.DataEng)
        else if Assigned(Owner.FOnExecute_M) then
            Owner.FOnExecute_M(IO_, Sender.DataEng)
        else if Assigned(Owner.FOnExecute_P) then
            Owner.FOnExecute_P(IO_, Sender.DataEng);
      except
      end;
    end;
end;

constructor TCommandCompleteBuffer_StreamNotify_Thread.Create;
begin
  inherited Create;
  Owner := nil;
  Framework := nil;
  ID := 0;
  buff := nil;
end;

destructor TCommandCompleteBuffer_StreamNotify_Thread.Destroy;
begin
  DisposeObjectAndNil(buff);
  inherited Destroy;
end;

constructor TCommandCompleteBuffer_StreamNotify.Create;
begin
  inherited Create;
  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
  FSync_Decrypt := True;
  FDecript_Activted_Thread_Num := 0;
end;

destructor TCommandCompleteBuffer_StreamNotify.Destroy;
begin
  while FDecript_Activted_Thread_Num > 0 do
      TCompute.Sleep(1);
  inherited Destroy;
end;

function TCommandCompleteBuffer_StreamNotify.Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
var
  tmp: TDFE;
  Bridge: TCommandCompleteBuffer_StreamNotify_Thread;
begin
  if FSync_Decrypt then
    begin
      tmp := TDFE.Create;
      tmp.DecodeFromMemory(InData, DataSize);

      Result := True;
      try
        if Assigned(FOnExecute_C) then
            FOnExecute_C(Sender, tmp)
        else if Assigned(FOnExecute_M) then
            FOnExecute_M(Sender, tmp)
        else if Assigned(FOnExecute_P) then
            FOnExecute_P(Sender, tmp)
        else
            Result := False;
      except
          Result := False;
      end;

      DisposeObject(tmp);
    end
  else
    begin
      AtomInc(FDecript_Activted_Thread_Num);
      Bridge := TCommandCompleteBuffer_StreamNotify_Thread.Create;
      Bridge.Owner := self;
      Bridge.Framework := Sender.OwnerFramework;
      Bridge.ID := Sender.ID;
      Bridge.buff := Sender.CompleteBuffer_Current_Trigger.Swap_To_New_Instance;
      TCompute.RunM(nil, Bridge, Bridge.Do_Run_Decrypt_Thread);
      Result := True;
    end;
end;

procedure TCommandCompleteBuffer_NoWait_Stream_Data.Init;
begin
  ID := 0;
  OnStreamM := nil;
  OnStreamP := nil;
end;

procedure TCommandCompleteBuffer_NoWait_Stream_Execute_Thread.Do_Execute_Thread(thSender: TCompute);
var
  UserData: UInt64;
  InDFE, OutDFE: TDFE;
  m64: TMS64;
begin
  InDFE := TDFE.Create;
  OutDFE := TDFE.Create;
  try
    UserData := PUInt64(buff.PosAsPtr(0))^;
    InDFE.DecodeFromMemory(buff.PosAsPtr(8), buff.Size - 8, True);

    try
      if Assigned(Owner.FOnExecute_C) then
          Owner.FOnExecute_C(R_Framework.PeerIO_HashPool[R_ID], InDFE, OutDFE)
      else if Assigned(Owner.FOnExecute_M) then
          Owner.FOnExecute_M(R_Framework.PeerIO_HashPool[R_ID], InDFE, OutDFE)
      else if Assigned(Owner.FOnExecute_P) then
          Owner.FOnExecute_P(R_Framework.PeerIO_HashPool[R_ID], InDFE, OutDFE)
    except
    end;

    m64 := TMS64.Create;
    m64.WriteUInt64(UserData);
    OutDFE.FastEncodeTo(m64);

    if S_Framework is TZNet_Server then
        TZNet_Server(S_Framework).SendCompleteBuffer(S_ID, C_Complete_Buffer_Stream_Reponse, m64, True)
    else if S_Framework is TZNet_Client then
        TZNet_Client(S_Framework).SendCompleteBuffer(C_Complete_Buffer_Stream_Reponse, m64, True);
  except
  end;
  DisposeObject(InDFE);
  DisposeObject(OutDFE);

  DelayFreeObj(1.0, self);
  AtomDec(Owner.FExecute_Activted_Thread_Num);
end;

constructor TCommandCompleteBuffer_NoWait_Stream_Execute_Thread.Create;
begin
  inherited Create;
  Owner := nil;
  R_Framework := nil;
  R_ID := 0;
  S_Framework := nil;
  S_ID := 0;
  buff := nil;
end;

destructor TCommandCompleteBuffer_NoWait_Stream_Execute_Thread.Destroy;
begin
  DisposeObjectAndNil(buff);
  inherited Destroy;
end;

constructor TCommandCompleteBuffer_NoWait_Stream.Create;
begin
  inherited Create;
  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
  FExecute_In_Thread := False;
  FExecute_Activted_Thread_Num := 0;
end;

destructor TCommandCompleteBuffer_NoWait_Stream.Destroy;
begin
  while FExecute_Activted_Thread_Num > 0 do
      TCompute.Sleep(1);
  inherited Destroy;
end;

function TCommandCompleteBuffer_NoWait_Stream.Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
var
  th: TCommandCompleteBuffer_NoWait_Stream_Execute_Thread;
  UserData: UInt64;
  InDFE, OutDFE: TDFE;
  m64: TMS64;
  S_IO: TPeerIO;
begin
  if FExecute_In_Thread then
    begin
      Result := False;
      if Sender.Is_Double_Tunnel and Sender.Is_Recveive_Tunnel then
        begin
          th := TCommandCompleteBuffer_NoWait_Stream_Execute_Thread.Create;
          th.Owner := self;
          th.R_Framework := Sender.OwnerFramework;
          th.R_ID := Sender.ID;
          if Sender.Get_Send_Tunnel(th.S_Framework, th.S_ID) then
            begin
              th.buff := Sender.CompleteBuffer_Current_Trigger.Swap_To_New_Instance;
              AtomInc(FExecute_Activted_Thread_Num);
              TCompute.RunM(nil, th, th.Do_Execute_Thread);
              Result := True;
            end
          else
            begin
              DisposeObject(th);
            end;
        end;
    end
  else
    begin
      InDFE := TDFE.Create;
      OutDFE := TDFE.Create;
      UserData := PUInt64(InData)^;
      InDFE.DecodeFromMemory(GetOffset(InData, 8), DataSize - 8, True);

      Result := True;
      try
        if Assigned(FOnExecute_C) then
            FOnExecute_C(Sender, InDFE, OutDFE)
        else if Assigned(FOnExecute_M) then
            FOnExecute_M(Sender, InDFE, OutDFE)
        else if Assigned(FOnExecute_P) then
            FOnExecute_P(Sender, InDFE, OutDFE)
        else
            Result := False;
      except
          Result := False;
      end;

      m64 := TMS64.Create;
      m64.WriteUInt64(UserData);
      OutDFE.FastEncodeTo(m64);

      if Sender.Is_Double_Tunnel and Sender.Is_Recveive_Tunnel then
        begin
          S_IO := Sender.Get_Send_Tunnel_IO;
          if S_IO <> nil then
              S_IO.SendCompleteBuffer(C_Complete_Buffer_Stream_Reponse, m64, True)
          else
              DisposeObject(m64);
        end;

      DisposeObject(InDFE);
      DisposeObject(OutDFE);
    end;
end;

constructor TCommandCompleteBuffer_NoWait_Bridge_Stream.Create;
begin
  inherited Create;
  FOnExecute_C := nil;
  FOnExecute_M := nil;
  FOnExecute_P := nil;
end;

destructor TCommandCompleteBuffer_NoWait_Bridge_Stream.Destroy;
begin
  inherited Destroy;
end;

function TCommandCompleteBuffer_NoWait_Bridge_Stream.Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;
var
  Bridge: TCommandCompleteBuffer_NoWait_Bridge;
begin
  Result := False;

  Bridge := TCommandCompleteBuffer_NoWait_Bridge.Create;
  Bridge.Owner := self;
  Bridge.Cmd := Sender.CompleteBufferCmd;
  Bridge.R_Framework := Sender.OwnerFramework;
  Bridge.R_ID := Sender.ID;
  if not Sender.Get_Send_Tunnel(Bridge.S_Framework, Bridge.S_ID) then
    begin
      DisposeObject(Bridge);
      exit;
    end;

  Bridge.UserData := PUInt64(InData)^;
  Bridge.InData.DecodeFromMemory(GetOffset(InData, 8), DataSize - 8, True);

  Result := True;
  try
    if Assigned(FOnExecute_C) then
        FOnExecute_C(Bridge, Bridge.InData, Bridge.OutData)
    else if Assigned(FOnExecute_M) then
        FOnExecute_M(Bridge, Bridge.InData, Bridge.OutData)
    else if Assigned(FOnExecute_P) then
        FOnExecute_P(Bridge, Bridge.InData, Bridge.OutData)
    else
        Result := False;
  except
      Result := False;
  end;

  if not Bridge.Pause_Result_Send then
      Bridge.Resume;
end;

constructor TCommandCompleteBuffer_NoWait_Bridge.Create;
begin
  inherited Create;
  Pause_Result_Send := False;
  Owner := nil;
  R_Framework := nil;
  R_ID := 0;
  S_Framework := nil;
  S_ID := 0;
  UserData := 0;
  InData := TDFE.Create;
  OutData := TDFE.Create;
end;

destructor TCommandCompleteBuffer_NoWait_Bridge.Destroy;
begin
  DisposeObject(InData);
  DisposeObject(OutData);
  inherited Destroy;
end;

function TCommandCompleteBuffer_NoWait_Bridge.R_IO: TPeerIO;
begin
  Result := R_Framework.PeerIO_HashPool[R_ID];
end;

function TCommandCompleteBuffer_NoWait_Bridge.S_IO: TPeerIO;
begin
  Result := S_Framework.PeerIO_HashPool[S_ID];
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.Pause;
begin
  Pause_Result_Send := True;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.PauseResultSend;
begin
  Pause;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.BreakResultSend;
begin
  Pause;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.SkipResultSend;
begin
  Pause;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.NoResultSend;
begin
  Pause;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.StopResultSend;
begin
  Pause;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.Resume;
var
  m64: TMS64;
begin
  m64 := TMS64.Create;
  m64.WriteUInt64(UserData);
  OutData.FastEncodeTo(m64);

  if S_Framework is TZNet_Server then
      TZNet_Server(S_Framework).SendCompleteBuffer(S_ID, C_Complete_Buffer_Stream_Reponse, m64, True)
  else if S_Framework is TZNet_Client then
      TZNet_Client(S_Framework).SendCompleteBuffer(C_Complete_Buffer_Stream_Reponse, m64, True);

  DelayFreeObj(1.0, self);
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.ContinueResultSend;
begin
  Resume;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.Continue_Send_Result;
begin
  Resume;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.ResumeResultSend;
begin
  Resume;
end;

procedure TCommandCompleteBuffer_NoWait_Bridge.NowResultSend;
begin
  Resume;
end;

