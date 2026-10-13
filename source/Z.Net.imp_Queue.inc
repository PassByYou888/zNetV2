procedure DisposeQueueData(const v: PQueueData);
begin
  if v = nil then
      exit;
  if v^.DoneAutoFree then
    begin
      try
        if v^.StreamData <> nil then
            DisposeObject(v^.StreamData);

        if v^.BigStream <> nil then
            DisposeObject(v^.BigStream);

        if v^.Buffer <> nil then
            System.FreeMemory(v^.Buffer);

        if v^.Buffer_Swap_Memory <> nil then
            DisposeObject(v^.Buffer_Swap_Memory);
      except
      end;
    end;

  Dispose(v);
end;

procedure InitQueueData(var v: TQueueData);
begin
  v.IP := '';
  v.State := qsUnknow;
  v.IO_ID := 0;
  v.Cmd := '';
  v.Cipher := TCipherSecurity.csNone;
  v.ConsoleData := '';
  v.OnConsoleM := nil;
  v.OnConsoleParamM := nil;
  v.OnConsoleFailedM := nil;
  v.OnConsoleP := nil;
  v.OnConsoleParamP := nil;
  v.OnConsoleFailedP := nil;
  v.StreamData := nil;
  v.OnStreamM := nil;
  v.OnStreamParamM := nil;
  v.OnStreamFailedM := nil;
  v.OnStreamP := nil;
  v.OnStreamParamP := nil;
  v.OnStreamFailedP := nil;
  v.BigStreamStartPos := 0;
  v.BigStream := nil;
  v.Buffer := nil;
  v.BufferSize := 0;
  v.Buffer_Swap_Memory := nil;
  v.DoneAutoFree := True;
  v.Param1 := nil;
  v.Param2 := nil;
end;

function NewQueueData(IO: TPeerIO): PQueueData;
begin
  New(Result);
  InitQueueData(Result^);
  Result^.IP := IO.GetPeerIP;
  Result^.IO_ID := IO.ID;
end;


type
  TWaitSendConsoleCmdIntf = class(TCore_Object_Intermediate)
  public
    NewResult: SystemString;
    Done: Boolean;
    Failed: Boolean;
    constructor Create;
    procedure DoConsoleFailed(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString);
    procedure DoConsoleParam(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString);
  end;

  TWaitSendStreamCmdIntf = class(TCore_Object_Intermediate)
  public
    NewResult: TDFE;
    Done: Boolean;
    Failed: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure DoStreamFailed(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE);
    procedure DoStreamParam(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE);
  end;

constructor TWaitSendConsoleCmdIntf.Create;
begin
  inherited Create;
  NewResult := '';
  Done := False;
  Failed := False;
end;

procedure TWaitSendConsoleCmdIntf.DoConsoleFailed(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString);
begin
  Done := True;
  Failed := True;
end;

procedure TWaitSendConsoleCmdIntf.DoConsoleParam(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString);
begin
  NewResult := Result_;
  Done := True;
  Failed := False;
end;

constructor TWaitSendStreamCmdIntf.Create;
begin
  inherited Create;
  NewResult := TDFE.Create;
  Done := False;
  Failed := False;
end;

destructor TWaitSendStreamCmdIntf.Destroy;
begin
  DisposeObject(NewResult);
  inherited Destroy;
end;

procedure TWaitSendStreamCmdIntf.DoStreamFailed(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE);
begin
  Done := True;
  Failed := True;
end;

procedure TWaitSendStreamCmdIntf.DoStreamParam(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE);
begin
  NewResult.Assign(Result_);
  Done := True;
  Failed := False;
end;


