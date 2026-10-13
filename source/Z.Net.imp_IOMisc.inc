procedure TBigStreamBatchPostData.Init;
begin
  Source := nil;
  CompletedBackcallPtr := 0;
  RemoteMD5 := NullMD5;
  SourceMD5 := NullMD5;
  index := -1;
  DBStorePos := 0;
end;

procedure TBigStreamBatchPostData.Encode(d: TDFE);
begin
  d.WriteMD5(RemoteMD5);
  d.WriteMD5(SourceMD5);
  d.WriteInteger(index);
  d.WriteInt64(DBStorePos);
end;

procedure TBigStreamBatchPostData.Decode(d: TDFE);
begin
  Source := nil;
  CompletedBackcallPtr := 0;
  RemoteMD5 := d.Reader.ReadMD5;
  SourceMD5 := d.Reader.ReadMD5;
  index := d.Reader.ReadInteger;
  DBStorePos := d.Reader.ReadInt64;
end;

function TBigStreamBatch.GetItems(const index: Integer): PBigStreamBatchPostData;
begin
  Result := FList[index];
end;

constructor TBigStreamBatch.Create(Owner_: TPeerIO);
begin
  inherited Create;
  FOwner := Owner_;
  FList := TBigStreamBatchPostData_List.Create;
end;

destructor TBigStreamBatch.Destroy;
begin
  Clear;
  DisposeObject(FList);
  inherited Destroy;
end;

procedure TBigStreamBatch.Clear;
var
  i: Integer;
  p: PBigStreamBatchPostData;
begin
  for i := 0 to FList.Count - 1 do
    begin
      p := PBigStreamBatchPostData(FList[i]);
      DisposeObject(p^.Source);
      Dispose(p);
    end;

  FList.Clear;
end;

function TBigStreamBatch.Count: Integer;
begin
  Result := FList.Count;
end;

function TBigStreamBatch.NewPostData: PBigStreamBatchPostData;
begin
  New(Result);
  Result^.Init;
  Result^.Source := TMS64.Create;
  Result^.index := FList.Add(Result);
end;

function TBigStreamBatch.First: PBigStreamBatchPostData;
begin
  Result := FList[0];
end;

function TBigStreamBatch.Last: PBigStreamBatchPostData;
begin
  Result := FList[FList.Count - 1];
end;

procedure TBigStreamBatch.DeleteLast;
begin
  if FList.Count > 0 then
      Delete(FList.Count - 1);
end;

procedure TBigStreamBatch.Delete(const index: Integer);
var
  p: PBigStreamBatchPostData;
  i: Integer;
begin
  p := FList[index];
  DisposeObject(p^.Source);
  Dispose(p);
  FList.Delete(index);

  for i := 0 to FList.Count - 1 do
    begin
      p := PBigStreamBatchPostData(FList[i]);
      p^.index := i;
    end;
end;

procedure TPeer_IO_User_Define.DelayFreeOnBusy;
begin
  FOwner := nil;
  while FBusy or (FBusyNum > 0) do
      TCompute.Sleep(100);

  DelayFreeObj(1.0, self);
end;

constructor TPeer_IO_User_Define.Create(Owner_: TPeerIO);
begin
  inherited Create;
  FOwner := Owner_;
  FWorkPlatform := TExecutePlatform.epUnknow;
  FBigStreamBatch := TBigStreamBatch.Create(Owner);
  FBusy := False;
end;

destructor TPeer_IO_User_Define.Destroy;
begin
  DisposeObject(FBigStreamBatch);
  inherited Destroy;
end;

procedure TPeer_IO_User_Define.Progress;
begin
end;

function TPeer_IO_User_Define.BusyNum: PInteger;
begin
  Result := @FBusyNum;
end;

procedure TPeer_IO_User_Special.DelayFreeOnBusy;
begin
  FOwner := nil;
  while FBusy or (FBusyNum > 0) do
      TCompute.Sleep(100);
  DelayFreeObj(1.0, self);
end;

constructor TPeer_IO_User_Special.Create(Owner_: TPeerIO);
begin
  inherited Create;
  FOwner := Owner_;
  FBusy := False;
end;

destructor TPeer_IO_User_Special.Destroy;
begin
  inherited Destroy;
end;

procedure TPeer_IO_User_Special.Progress;
begin
end;

function TPeer_IO_User_Special.BusyNum: PInteger;
begin
  Result := @FBusyNum;
end;

procedure TPhysics_Fragment_Pool.DoFree(var data: TMem64);
begin
  DisposeObjectAndNil(data);
end;

