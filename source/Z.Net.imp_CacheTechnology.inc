var
  BigStream_Swap_Space_Pool__: TFile_Swap_Space_Pool;

procedure Init_SwapSpace_Tech;
begin
  BigStream_Swap_Space_Pool__ := TFile_Swap_Space_Pool.Create;

{$IFDEF MSWINDOWS}
  BigStream_Swap_Space_Pool__.WorkPath := umlGetFilePath(ParamStr(0));
{$ELSE MSWINDOWS}
  BigStream_Swap_Space_Pool__.WorkPath := umlCurrentPath;
{$ENDIF MSWINDOWS}
  TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool___ := nil;
  TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool_Cipher___ := nil;
end;

procedure Free_SwapSpace_Tech;
begin
  DisposeObjectAndNil(BigStream_Swap_Space_Pool__);
  DisposeObjectAndNil(TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool___);
  DisposeObjectAndNil(TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool_Cipher___);
end;

procedure TZDB2_Swap_Space_Technology.DoNoSpace(Trigger: TZDB2_Core_Space; Siz_: Int64; var retry: Boolean);
begin
  retry := AppendSpace(ZNet_Def_Swap_Space_Technology_Delta, ZNet_Def_Swap_Space_Technology_Block);
end;

constructor TZDB2_Swap_Space_Technology.Create();
var
  p: PIOHnd;
  path_: U_String;
  prefix: U_String;
  i: Integer;
begin
  Critical := TCritical.Create('TZDB2_Swap_Space_Technology.Critical');
{$IFDEF MSWINDOWS}
  path_ := umlGetFilePath(ParamStr(0));
  prefix := umlChangeFileExt(umlGetFileName(ParamStr(0)), '');
{$ELSE MSWINDOWS}
  path_ := BigStream_Swap_Space_Pool__.WorkPath;
  prefix := 'ZNet_Space_Technology_' + umlDecodeTimeToStr(umlNow);
{$ENDIF MSWINDOWS}
  if TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool_Cipher___ = nil then
      TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool_Cipher___ := TZDB2_Cipher.Create(TCipherSecurity.csRijndael, prefix, 1, True, False);

  tmp_swap_space_file := umlCombineFileName(path_, prefix + '.~tmp');
  i := 1;
  while umlFileExists(tmp_swap_space_file) do
    begin
      tmp_swap_space_file := umlCombineFileName(path_, prefix + PFormat('(%d).~tmp', [i]));
      inc(i);
    end;

  New(p);
  InitIOHnd(p^);
  umlFileCreate(tmp_swap_space_file, p^);
  inherited Create(p);
  if ZNet_Def_Swap_Space_Technology_Security_Model then
      Cipher := TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool_Cipher___;
  Mode := smNormal;
  AutoCloseIOHnd := True;
  AutoFreeIOHnd := True;
  OnNoSpace := DoNoSpace;
end;

destructor TZDB2_Swap_Space_Technology.Destroy;
var
  tmp: U_String;
begin
  DisposeObject(Critical);
  tmp := tmp_swap_space_file;
  try
    inherited Destroy;
    umlDeleteFile(tmp);
  except
  end;
end;

function TZDB2_Swap_Space_Technology.Create_Memory(buff: PByte; BuffSiz: NativeInt; BuffProtected_: Boolean): TZDB2_Swap_Space_Technology_Memory;
var
  tmp: TMem64;
  ID_: Integer;
begin
  tmp := TMem64.Create;
  tmp.Mapping(buff, BuffSiz);
  Critical.Lock;
  if WriteData(tmp, ID_, BuffProtected_) then
      Result := TZDB2_Swap_Space_Technology_Memory.Create(self, ID_)
  else
      Result := nil;
  Critical.UnLock;
  DisposeObject(tmp);
end;

class function TZDB2_Swap_Space_Technology.RunTime_Pool(): TZDB2_Swap_Space_Technology;
begin
  if TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool___ = nil then
      TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool___ := TZDB2_Swap_Space_Technology.Create;
  Result := TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool___;
end;

constructor TZDB2_Swap_Space_Technology_Memory.Create();
begin
  Create(nil, -1);
end;

constructor TZDB2_Swap_Space_Technology_Memory.Create(Owner_: TZDB2_Swap_Space_Technology; ID_: Integer);
begin
  inherited Create;
  FOwner := Owner_;
  FID := ID_;
end;

destructor TZDB2_Swap_Space_Technology_Memory.Destroy;
begin
  if (FOwner <> nil) and (FID >= 0) then
    begin
      FOwner.Critical.Lock;
      FOwner.RemoveData(FID, True);
      FOwner.Critical.UnLock;
      if FOwner.State^.FreeSpace >= FOwner.State^.Physics then
          DisposeObjectAndNil(TZDB2_Swap_Space_Technology.ZDB2_Swap_Space_Pool___);
    end;
  inherited Destroy;
end;

function TZDB2_Swap_Space_Technology_Memory.Prepare: Boolean;
begin
  Result := False;
  if (FOwner <> nil) and (FID >= 0) then
    begin
      FOwner.Critical.Lock;
      Result := FOwner.ReadData(self, FID);
      FOwner.Critical.UnLock;
    end
end;

constructor TFile_Swap_Space_Pool.Create;
begin
  inherited Create;
  WorkPath := umlCurrentPath;
end;

destructor TFile_Swap_Space_Pool.Destroy;
begin
  inherited Destroy;
end;

procedure TFile_Swap_Space_Pool.DoFree(var data: TFile_Swap_Space_Stream);
begin
  if data = nil then
      exit;
  data.FOwnerSwapSpace := nil;
  data.FPoolPtr := nil;
  DisposeObjectAndNil(data);
end;

function TFile_Swap_Space_Pool.CompareData(const Data_1, Data_2: TFile_Swap_Space_Stream): Boolean;
begin
  Result := Data_1 = Data_2;
end;

class function TFile_Swap_Space_Pool.RunTime_Pool(): TFile_Swap_Space_Pool;
begin
  Result := BigStream_Swap_Space_Pool__;
end;

class function TFile_Swap_Space_Stream.Create_BigStream(stream_: TCore_Stream; OwnerSwapSpace_: TFile_Swap_Space_Pool): TFile_Swap_Space_Stream;
var
  MD5Name: U_String;
  tmpFileName: U_String;
  i: Integer;
begin
  Result := nil;
  if not umlDirectoryExists(OwnerSwapSpace_.WorkPath) then
      exit;
  try
    MD5Name := umlStreamMD5String(stream_);
    tmpFileName := umlCombineFileName(OwnerSwapSpace_.WorkPath, 'ZNet_' + MD5Name.Text + '.~tmp');
    i := 1;
    while umlFileExists(tmpFileName) do
      begin
        tmpFileName := umlCombineFileName(OwnerSwapSpace_.WorkPath, 'ZNet_' + MD5Name.Text + PFormat('(%d).~tmp', [i]));
        inc(i);
      end;
    Result := TFile_Swap_Space_Stream.Create(tmpFileName, fmCreate);
    MD5Name := '';
    tmpFileName := '';
    stream_.Position := 0;
    Result.CopyFrom(stream_, stream_.Size);
    Result.Position := 0;
    Result.FOwnerSwapSpace := OwnerSwapSpace_;
    Result.FPoolPtr := OwnerSwapSpace_.Add(Result);
  except
      Result := nil;
  end;
end;

destructor TFile_Swap_Space_Stream.Destroy;
var
  tmpFileName: U_String;
begin
  try
    tmpFileName := FileName;
    if (FOwnerSwapSpace <> nil) and (FPoolPtr <> nil) then
      begin
        FPoolPtr^.data := nil;
        FOwnerSwapSpace.Remove_P(FPoolPtr);
      end;
    inherited Destroy;
    umlDeleteFile(tmpFileName);
  except
  end;
end;

