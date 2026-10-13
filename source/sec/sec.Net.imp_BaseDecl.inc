procedure TOnStateStruct.Init;
begin
  On_C := nil;
  On_M := nil;
  On_P := nil;
end;

procedure TOnResult_Bridge_Templet.DoConsoleEvent(Sender: TPeerIO; Result_: SystemString);
begin

end;

procedure TOnResult_Bridge_Templet.DoConsoleParamEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString);
begin

end;

procedure TOnResult_Bridge_Templet.DoConsoleFailedEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString);
begin

end;

procedure TOnResult_Bridge_Templet.DoStreamEvent(Sender: TPeerIO; Result_: TDFE);
begin

end;

procedure TOnResult_Bridge_Templet.DoStreamParamEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE);
begin

end;

procedure TOnResult_Bridge_Templet.DoStreamFailedEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE);
begin

end;

procedure TOnResult_Bridge_Templet.DoCompleteBufferStreamEvent(Sender: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE);
begin

end;

constructor TOnResult_Bridge.Create;
begin
  inherited Create;
end;

destructor TOnResult_Bridge.Destroy;
begin
  inherited Destroy;
end;

procedure TProgress_Bridge.DoFree(Sender: TZNet_Progress);
begin
  ProgressInstance := nil;
end;

constructor TProgress_Bridge.Create(Framework_: TZNet);
begin
  inherited Create;
  Framework := Framework_;
  ProgressInstance := Framework.AddProgresss;
  ProgressInstance.OnFree := DoFree;
  ProgressInstance.OnProgress_M := Progress;
end;

destructor TProgress_Bridge.Destroy;
begin
  if ProgressInstance <> nil then
    begin
      ProgressInstance.ResetEvent;
      ProgressInstance.NextProgressDoFree := True;
      ProgressInstance := nil;
    end;
  inherited Destroy;
end;

procedure TProgress_Bridge.Progress(Sender: TZNet_Progress);
begin

end;

constructor TState_Param_Bridge.Create;
begin
  inherited Create;
  OnNotifyC := nil;
  OnNotifyM := nil;
  OnNotifyP := nil;
  Param1 := nil;
  Param2 := nil;
  OnStateMethod := DoStateResult;
end;

destructor TState_Param_Bridge.Destroy;
begin
  inherited Destroy;
end;

procedure TState_Param_Bridge.DoStateResult(const State: Boolean);
begin
  if Assigned(OnNotifyC) then
      OnNotifyC(Param1, Param2, State)
  else if Assigned(OnNotifyM) then
      OnNotifyM(Param1, Param2, State)
  else if Assigned(OnNotifyP) then
      OnNotifyP(Param1, Param2, State);
  DelayFreeObj(1.0, self);
end;

procedure TCustom_Event_Bridge.DoFree(Sender: TZNet_Progress);
begin
  ProgressInstance := nil;
end;

constructor TCustom_Event_Bridge.Create(IO_: TPeerIO);
begin
  inherited Create;
  if IO_ <> nil then
    begin
      Framework_ := IO_.OwnerFramework;
      ID_ := IO_.ID;
      ProgressInstance := IO_.OwnerFramework.AddProgresss;
      ProgressInstance.OnFree := DoFree;
      ProgressInstance.OnProgress_M := Progress;
    end
  else
    begin
      Framework_ := nil;
      ID_ := 0;
      ProgressInstance := nil;
    end;
end;

destructor TCustom_Event_Bridge.Destroy;
begin
  if ProgressInstance <> nil then
    begin
      ProgressInstance.ResetEvent;
      ProgressInstance.NextProgressDoFree := True;
      ProgressInstance := nil;
    end;
  inherited Destroy;
end;

function TCustom_Event_Bridge.CheckIO: Boolean;
begin
  try
      Result := (Framework_ <> nil) and (Framework_.ExistsID(ID_));
  except
      Result := False;
  end;
end;

function TCustom_Event_Bridge.IO: TPeerIO;
begin
  if not CheckIO then
      Result := nil
  else
      Result := Framework_.PeerIO_HashPool[ID_] as TPeerIO;
end;

procedure TCustom_Event_Bridge.Progress(Sender: TZNet_Progress);
begin
end;

procedure TStream_Event_Bridge.Init(IO_: TPeerIO; AutoPause_: Boolean);
begin
  if not IO_.ReceiveCommandRuning then
      RaiseInfo('Need in Stream Event.');
  AutoPause := AutoPause_;
  if AutoPause then
      IO_.Pause;
  Framework_ := IO_.OwnerFramework;
  ID_ := IO_.ID;
  LCMD_ := IO_.CurrentCommand;
  OnResultC := nil;
  OnResultM := nil;
  OnResultP := nil;
  if not IO_.OwnerFramework.QuietMode then
      IO_.Print('Create CMD "%s" Bridge Event.', [LCMD_]);
  AutoFree := AutoPause_;
  ProgressInstance := IO_.OwnerFramework.AddProgresss;
  ProgressInstance.OnFree := DoFree;
  ProgressInstance.OnProgress_M := Progress;
end;

procedure TStream_Event_Bridge.DoFree(Sender: TZNet_Progress);
begin
  ProgressInstance := nil;
end;

constructor TStream_Event_Bridge.Create(IO_: TPeerIO; AutoPause_: Boolean);
begin
  inherited Create;
  Init(IO_, AutoPause_);
end;

constructor TStream_Event_Bridge.Create(IO_: TPeerIO);
begin
  inherited Create;
  Init(IO_, True);
end;

destructor TStream_Event_Bridge.Destroy;
begin
  if ProgressInstance <> nil then
    begin
      ProgressInstance.ResetEvent;
      ProgressInstance.NextProgressDoFree := True;
      ProgressInstance := nil;
    end;
  inherited Destroy;
end;

procedure TStream_Event_Bridge.Pause;
var
  IO_: TPeerIO;
begin
  if Framework_.ExistsID(ID_) then
    begin
      IO_ := TPeerIO(Framework_.PeerIO_HashPool[ID_]);
      IO_.Pause;
    end;
end;

procedure TStream_Event_Bridge.Play(ResultData_: TDFE);
var
  IO_: TPeerIO;
begin
  if Framework_.ExistsID(ID_) then
    begin
      IO_ := TPeerIO(Framework_.PeerIO_HashPool[ID_]);
      IO_.OutDataFrame.Append(ResultData_);
      IO_.Resume;
    end;
  if AutoFree then
      DelayFreeObject(1.0, self);
end;

procedure TStream_Event_Bridge.DoStreamParamEvent(Sender_: TPeerIO; Param1_: Pointer; Param2_: TObject; SendData_, ResultData_: TDFE);
begin
  DoStreamEvent(Sender_, ResultData_);
end;

procedure TStream_Event_Bridge.DoStreamFailed(Sender_: TPeerIO; Param1: Pointer; Param2: TObject; SendData_: TDFE);
var
  de: TDFE;
begin
  de := TDFE.Create;
  DoStreamEvent(Sender_, de);
  DisposeObject(de);
end;

procedure TStream_Event_Bridge.DoStreamEvent(Sender_: TPeerIO; ResultData_: TDFE);
var
  IO_: TPeerIO;
begin
  if Framework_.ExistsID(ID_) then
    begin
      IO_ := TPeerIO(Framework_.PeerIO_HashPool[ID_]);
      if Assigned(OnResultC) then
          OnResultC(self, IO_, Sender_, ResultData_)
      else if Assigned(OnResultM) then
          OnResultM(self, IO_, Sender_, ResultData_)
      else if Assigned(OnResultP) then
          OnResultP(self, IO_, Sender_, ResultData_);
      if AutoPause then
        begin
          IO_.OutDataFrame.Append(ResultData_);
          IO_.Resume;
        end;
      if not IO_.OwnerFramework.QuietMode then
          IO_.Print('Finish CMD "%s" Bridge Event.', [LCMD_]);
    end
  else
      DoStatus('Loss CMD "%s" Bridge Event..', [LCMD_]);

  if AutoFree then
      DelayFreeObject(1.0, self);
end;

procedure TStream_Event_Bridge.Progress(Sender: TZNet_Progress);
begin

end;

procedure TConsole_Event_Bridge.Init(IO_: TPeerIO; AutoPause_: Boolean);
begin
  if not IO_.ReceiveCommandRuning then
      RaiseInfo('Need in Stream Event.');
  AutoPause := AutoPause_;
  if AutoPause then
      IO_.Pause;
  Framework_ := IO_.OwnerFramework;
  ID_ := IO_.ID;
  LCMD_ := IO_.CurrentCommand;
  OnResultC := nil;
  OnResultM := nil;
  OnResultP := nil;
  if not IO_.OwnerFramework.QuietMode then
      IO_.Print('Create CMD "%s" Bridge Event.', [LCMD_]);
  AutoFree := AutoPause_;
  ProgressInstance := IO_.OwnerFramework.AddProgresss;
  ProgressInstance.OnFree := DoFree;
  ProgressInstance.OnProgress_M := Progress;
end;

procedure TConsole_Event_Bridge.DoFree(Sender: TZNet_Progress);
begin
  ProgressInstance := nil;
end;

constructor TConsole_Event_Bridge.Create(IO_: TPeerIO; AutoPause_: Boolean);
begin
  inherited Create;
  Init(IO_, AutoPause_);
end;

constructor TConsole_Event_Bridge.Create(IO_: TPeerIO);
begin
  inherited Create;
  Init(IO_, True);
end;

destructor TConsole_Event_Bridge.Destroy;
begin
  if ProgressInstance <> nil then
    begin
      ProgressInstance.ResetEvent;
      ProgressInstance.NextProgressDoFree := True;
      ProgressInstance := nil;
    end;
  inherited Destroy;
end;

procedure TConsole_Event_Bridge.Pause;
var
  IO_: TPeerIO;
begin
  if Framework_.ExistsID(ID_) then
    begin
      IO_ := TPeerIO(Framework_.PeerIO_HashPool[ID_]);
      IO_.Pause;
    end;
end;

procedure TConsole_Event_Bridge.Play(ResultData_: SystemString);
var
  IO_: TPeerIO;
begin
  if Framework_.ExistsID(ID_) then
    begin
      IO_ := TPeerIO(Framework_.PeerIO_HashPool[ID_]);
      IO_.OutText := IO_.OutText + ResultData_;
      IO_.Resume;
    end;
  if AutoFree then
      DelayFreeObject(1.0, self);
end;

procedure TConsole_Event_Bridge.DoConsoleParamEvent(Sender_: TPeerIO; Param1_: Pointer; Param2_: TObject; SendData_, ResultData_: SystemString);
begin
  DoConsoleEvent(Sender_, ResultData_);
end;

procedure TConsole_Event_Bridge.DoStreamFailed(Sender_: TPeerIO; Param1: Pointer; Param2: TObject; SendData_: SystemString);
begin
  DoConsoleEvent(Sender_, '');
end;

procedure TConsole_Event_Bridge.DoConsoleEvent(Sender_: TPeerIO; ResultData_: SystemString);
var
  IO_: TPeerIO;
begin
  if Framework_.ExistsID(ID_) then
    begin
      IO_ := TPeerIO(Framework_.PeerIO_HashPool[ID_]);
      if Assigned(OnResultC) then
          OnResultC(self, IO_, Sender_, ResultData_)
      else if Assigned(OnResultM) then
          OnResultM(self, IO_, Sender_, ResultData_)
      else if Assigned(OnResultP) then
          OnResultP(self, IO_, Sender_, ResultData_);
      if AutoPause then
        begin
          IO_.OutText := IO_.OutText + ResultData_;
          IO_.Resume;
        end;
      if not IO_.OwnerFramework.QuietMode then
          IO_.Print('Finish CMD "%s" Bridge Event.', [LCMD_]);
    end
  else
      DoStatus('Loss CMD "%s" Bridge Event..', [LCMD_]);

  if AutoFree then
      DelayFreeObject(1.0, self);
end;

procedure TConsole_Event_Bridge.Progress(Sender: TZNet_Progress);
begin

end;

procedure TCustom_CompleteBuffer_Stream_Bridge.DoFree(Sender: TZNet_Progress);
begin
  ProgressInstance := nil;
end;

constructor TCustom_CompleteBuffer_Stream_Bridge.Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge);
begin
  inherited Create;
  if Bridge_ <> nil then
    begin
      Bridge := Bridge_;
      ProgressInstance := Bridge.R_Framework.AddProgresss;
      ProgressInstance.OnFree := DoFree;
      ProgressInstance.OnProgress_M := Progress;
    end
  else
    begin
      Bridge := nil;
      ProgressInstance := nil;
    end;
end;

destructor TCustom_CompleteBuffer_Stream_Bridge.Destroy;
begin
  if ProgressInstance <> nil then
    begin
      ProgressInstance.ResetEvent;
      ProgressInstance.NextProgressDoFree := True;
      ProgressInstance := nil;
    end;
  inherited Destroy;
end;

function TCustom_CompleteBuffer_Stream_Bridge.CheckIO: Boolean;
begin
  try
      Result := (Bridge <> nil) and (Bridge.R_Framework <> nil) and (Bridge.R_Framework.ExistsID(Bridge.R_ID));
  except
      Result := False;
  end;
end;

function TCustom_CompleteBuffer_Stream_Bridge.IO: TPeerIO;
begin
  try
      Result := Bridge.R_Framework.PeerIO_HashPool[Bridge.R_ID];
  except
      Result := nil;
  end;
end;

procedure TCustom_CompleteBuffer_Stream_Bridge.Progress(Sender: TZNet_Progress);
begin

end;

procedure TCompleteBuffer_Stream_Event_Bridge.Init(Bridge_: TCommandCompleteBuffer_NoWait_Bridge; AutoPause_: Boolean);
begin
  Bridge := Bridge_;
  LCMD_ := Bridge_.Cmd;
  AutoPause := AutoPause_;
  if AutoPause then
      Bridge.Pause;
  Framework_ := Bridge.R_Framework;
  OnResultC := nil;
  OnResultM := nil;
  OnResultP := nil;
  if not Framework_.QuietMode then
      Framework_.PrintParam('Create Complete Buffer CMD "%s" Bridge Event.', LCMD_);
  AutoFree := AutoPause_;
  ProgressInstance := Framework_.AddProgresss;
  ProgressInstance.OnFree := DoFree;
  ProgressInstance.OnProgress_M := Progress;
end;

procedure TCompleteBuffer_Stream_Event_Bridge.DoFree(Sender: TZNet_Progress);
begin
  ProgressInstance := nil;
end;

constructor TCompleteBuffer_Stream_Event_Bridge.Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge; AutoPause_: Boolean);
begin
  inherited Create;
  Init(Bridge_, AutoPause_);
end;

constructor TCompleteBuffer_Stream_Event_Bridge.Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge);
begin
  inherited Create;
  Init(Bridge_, True);
end;

destructor TCompleteBuffer_Stream_Event_Bridge.Destroy;
begin
  if ProgressInstance <> nil then
    begin
      ProgressInstance.ResetEvent;
      ProgressInstance.NextProgressDoFree := True;
      ProgressInstance := nil;
    end;
  inherited Destroy;
end;

procedure TCompleteBuffer_Stream_Event_Bridge.Pause;
begin
  Bridge.Pause;
end;

procedure TCompleteBuffer_Stream_Event_Bridge.Play(ResultData_: TDFE);
begin
  Bridge.OutData.SwapInstance(ResultData_);
  Bridge.Resume;
  if AutoFree then
      DelayFreeObject(1.0, self);
end;

procedure TCompleteBuffer_Stream_Event_Bridge.DoStreamEvent(Sender_: TPeerIO; ResultData_: TDFE);
begin
  if Assigned(OnResultC) then
      OnResultC(self, Bridge, Sender_, ResultData_)
  else if Assigned(OnResultM) then
      OnResultM(self, Bridge, Sender_, ResultData_)
  else if Assigned(OnResultP) then
      OnResultP(self, Bridge, Sender_, ResultData_);
  if not Bridge.R_Framework.QuietMode then
      Bridge.R_Framework.PrintParam('Finish CMD "%s" Bridge Event.', LCMD_);
  if AutoPause then
    begin
      Bridge.OutData.SwapInstance(ResultData_);
      Bridge.Resume;
    end;
  if AutoFree then
      DelayFreeObject(1.0, self);
end;

procedure TCompleteBuffer_Stream_Event_Bridge.Progress(Sender: TZNet_Progress);
begin

end;

procedure TP2PVM_CloneConnectEventBridge.DoAsyncConnectState(const State: Boolean);
begin
  if not State then
      DisposeObjectAndNil(NewClient);

  try
    if Assigned(OnResultC) then
        OnResultC(NewClient)
    else if Assigned(OnResultM) then
        OnResultM(NewClient)
    else if Assigned(OnResultP) then
        OnResultP(NewClient);
  except
  end;

  DelayFreeObj(1.0, self);
end;

constructor TP2PVM_CloneConnectEventBridge.Create(Source_: TZNet_WithP2PVM_Client);
begin
  inherited Create;
  Source := Source_;
  NewClient := nil;
  OnResultC := nil;
  OnResultM := nil;
  OnResultP := nil;
end;

destructor TP2PVM_CloneConnectEventBridge.Destroy;
begin
  inherited Destroy;
end;

procedure TDoubleTunnel_IO_ID_List.Add_DT_ID(R, S: Cardinal);
var
  tmp: TDoubleTunnel_IO_ID;
begin
  tmp.R := R;
  tmp.S := S;
  Add(tmp);
end;

