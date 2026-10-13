function IsSystemCMD(const Cmd: U_String): Boolean;
begin
  Result := Cmd.Same(C_CipherModel, C_BuildP2PAuthToken, C_InitP2PTunnel, C_CloseP2PTunnel, C_Wait) or
    Cmd.Same(C_NULL, C_Complete_Buffer_Stream_Reponse, C_BuildStableIO, C_OpenStableIO, C_CloseStableIO);
end;

function StrToIPv4(const S: U_String; var Success: Boolean): TIPV4;
var
  n: U_String;
  i: Integer;
  dotCount: Integer;
  NumVal: Integer;
  Len: Integer;
  CH: SystemChar;
begin
  FillPtrByte(@Result[0], SizeOf(Result), 0);
  Success := False;
  n := umlDeleteChar(S, [#32, #0, #9, #13, #10]);
  Len := n.Len;
  if Len < 6 then
      exit;
  dotCount := 0;
  NumVal := -1;
  for i := 1 to Len do
    begin
      CH := n[i];
      if CharIn(CH, c0to9) then
        begin
          if NumVal < 0 then
              NumVal := Ord(CH) - Ord('0')
          else
              NumVal := NumVal * 10 + Ord(CH) - Ord('0');
          if NumVal > 255 then
              exit;
        end
      else if CH = '.' then
        begin
          if (NumVal > -1) and (dotCount < 3) then
              Result[dotCount] := NumVal
          else
              exit;
          inc(dotCount);
          NumVal := -1;
        end
      else
          exit;
    end;

  if (NumVal > -1) and (dotCount = 3) then
    begin
      Result[dotCount] := NumVal;
      Success := True;
    end;
end;

function IPv4ToStr(const IPv4Addr_: TIPV4): U_String;
begin
  Result.Text := IntToStr(IPv4Addr_[0]) + '.' + IntToStr(IPv4Addr_[1]) + '.' + IntToStr(IPv4Addr_[2]) + '.' + IntToStr(IPv4Addr_[3]);
end;

function StrToIPv6(const S: U_String; var Success: Boolean; var ScopeID: Cardinal): TIPV6;
const
  Colon = ':';
  Percent = '%';
var
  n: U_String;
  ColonCnt: Integer;
  i: Integer;
  NumVal: Integer;
  CH: SystemChar;
  SLen: Integer;
  OmitPos: Integer;
  OmitCnt: Integer;
  PartCnt: Byte;
  ScopeFlag: Boolean;
begin
  FillPtrByte(@Result[0], SizeOf(Result), 0);
  Success := False;
  n := umlDeleteChar(S, [#32, #0, #9, #13, #10]);
  SLen := n.Len;
  if (SLen < 1) or (SLen > (4 * 8) + 7) then
      exit;
  ColonCnt := 0;
  for i := 1 to SLen do
    if (n[i] = Colon) then
        inc(ColonCnt);
  if ColonCnt > 7 then
      exit;
  OmitPos := n.GetPos('::') - 1;
  if OmitPos > -1 then
      OmitCnt := 8 - ColonCnt
  else
    begin
      OmitCnt := 0; { Make the compiler happy }
      if (n.First = Colon) or (n.Last = Colon) then
          exit;
    end;
  NumVal := -1;
  ColonCnt := 0;
  PartCnt := 0;
  i := 0;
  ScopeID := 0;
  ScopeFlag := False;
  while i < SLen do
    begin
      CH := n.buff[i];

      if CH = Percent then
        begin
          if ScopeFlag then
              exit
          else
              ScopeFlag := True;

          PartCnt := 0;
          if NumVal > -1 then
            begin
              Result[ColonCnt] := NumVal;
              NumVal := -1;
            end;
        end
      else if CH = Colon then
        begin
          if ScopeFlag then
              exit;
          PartCnt := 0;
          if NumVal > -1 then
            begin
              Result[ColonCnt] := NumVal;
              NumVal := -1;
            end;
          if (OmitPos = i) then
            begin
              inc(ColonCnt, OmitCnt);
              inc(i);
            end;
          inc(ColonCnt);
          if ColonCnt > 7 then
              exit;
        end
      else if CharIn(CH, c0to9) then
        begin
          inc(PartCnt);
          if NumVal < 0 then
              NumVal := (Ord(CH) - Ord('0'))
          else if ScopeFlag then
              NumVal := NumVal * 10 + (Ord(CH) - Ord('0'))
          else
              NumVal := NumVal * 16 + (Ord(CH) - Ord('0'));
          if (NumVal > high(Word)) or (PartCnt > 4) then
              exit;
        end
      else if CharIn(CH, cAtoZ) then
        begin
          if ScopeFlag then
              exit;
          inc(PartCnt);
          if NumVal < 0 then
              NumVal := ((Ord(CH) and 15) + 9)
          else
              NumVal := NumVal * 16 + ((Ord(CH) and 15) + 9);
          if (NumVal > high(Word)) or (PartCnt > 4) then
              exit;
        end
      else
          exit;

      inc(i);
    end;

  if (NumVal > -1) and (ColonCnt > 1) then
    begin
      if not ScopeFlag then
        begin
          Result[ColonCnt] := NumVal;
        end
      else
          ScopeID := NumVal;
    end;
  Success := ColonCnt > 1;
end;

function StrToIPv6(const S: U_String; var Success: Boolean): TIPV6;
var
  SI: Cardinal;
begin
  Result := StrToIPv6(S, Success, SI);
end;

function IPv6ToStr(const IPv6Addr: TIPV6): U_String;
var
  i: Integer;
  Zeros1, Zeros2: set of Byte;
  Zeros1Cnt, Zeros2Cnt: Byte;
  OmitFlag: Boolean;
  ipv: SystemString;
begin
  ipv := '';
  Zeros1 := [];
  Zeros2 := [];
  Zeros1Cnt := 0;
  Zeros2Cnt := 0;
  for i := low(IPv6Addr) to high(IPv6Addr) do
    begin
      if IPv6Addr[i] = 0 then
        begin
          Include(Zeros1, i);
          inc(Zeros1Cnt);
        end
      else if Zeros1Cnt > Zeros2Cnt then
        begin
          Zeros2Cnt := Zeros1Cnt;
          Zeros2 := Zeros1;
          Zeros1 := [];
          Zeros1Cnt := 0;
        end;
    end;
  if Zeros1Cnt > Zeros2Cnt then
    begin
      Zeros2 := Zeros1;
      Zeros2Cnt := Zeros1Cnt;
    end;

  if Zeros2Cnt = 0 then
    begin
      for i := low(IPv6Addr) to high(IPv6Addr) do
        begin
          if i = 0 then
              ipv := IntToHex(IPv6Addr[i], 1)
          else
              ipv := ipv + ':' + IntToHex(IPv6Addr[i], 1);
        end;
    end
  else
    begin
      OmitFlag := False;
      for i := low(IPv6Addr) to high(IPv6Addr) do
        begin
          if not(i in Zeros2) then
            begin
              if OmitFlag then
                begin
                  if ipv = '' then
                      ipv := '::'
                  else
                      ipv := ipv + ':';
                  OmitFlag := False;
                end;
              if i < high(IPv6Addr) then
                  ipv := ipv + IntToHex(IPv6Addr[i], 1) + ':'
              else
                  ipv := ipv + IntToHex(IPv6Addr[i], 1);
            end
          else
              OmitFlag := True;
        end;
      if OmitFlag then
        begin
          if ipv = '' then
              ipv := '::'
          else
              ipv := ipv + ':';
        end;
      if ipv = '' then
          ipv := '::';
    end;
  Result.Text := LowerCase(ipv);
end;

function IsIPv4(const S: U_String): Boolean;
var
  n: U_String;
  i: Integer;
  DotCnt: Integer;
  NumVal: Integer;
  CH: SystemChar;
begin
  n := umlDeleteChar(S, [#32, #0, #9, #13, #10]);
  Result := False;
  DotCnt := 0;
  NumVal := -1;
  for i := 1 to n.Len do
    begin
      CH := n[i];
      if CharIn(CH, c0to9) then
        begin
          if NumVal = -1 then
              NumVal := Ord(CH) - Ord('0')
          else
              NumVal := NumVal * 10 + Ord(CH) - Ord('0');
          if NumVal > 255 then
              exit;
        end
      else if CH = '.' then
        begin
          inc(DotCnt);
          if (DotCnt > 3) or (NumVal = -1) then
              exit;
          NumVal := -1;
        end
      else
          exit;
    end;

  Result := DotCnt = 3;
end;

function IsIPV6(const S: U_String): Boolean;
var
  ScopeID: Cardinal;
begin
  StrToIPv6(S, Result, ScopeID);
end;

function MakeRandomIPV6(): TIPV6;
var
  tmp: array [0 .. 31] of Byte;
begin
  PTimeTick(@tmp[0])^ := GetTimeTick();
  PInt64(@tmp[8])^ := MT19937Rand64($7FFFFFFFFFFFFFFF);
  PDouble(@tmp[16])^ := umlNow();
  PInt64(@tmp[24])^ := AtomInc(ZNet_Def_IPV6_Seed);
  PMD5(@Result)^ := umlMD5(@tmp[0], 32);
end;

function Null_UID(): TUID___;
begin
  FillPtr(@Result, SizeOf(TUID___), 0);
end;

function Is_Null_UID(UID: TUID___): Boolean;
begin
  Result := CompareMemoryIs0(@UID[0], SizeOf(TUID___));
end;

function Generate_Global_UID(): TUID___;
type
  TData___ = packed record
    SysTime__: TDateTime;
    Tick__: TTimeTick;
    Seed__: Int64;
  end;
var
  data: TData___;
begin
  data.SysTime__ := umlNow();
  data.Tick__ := GetTimeTick();
  data.Seed__ := AtomInc(ZNet_Global_UID_Seed);
  TSHA3.SHA256(Result, @data, SizeOf(data));
end;

function Generate_Global_UID(UID: TUID___): TUID___;
type
  TData___ = packed record
    UID__: TUID___;
    SysTime__: TDateTime;
    Tick__: TTimeTick;
    Seed__: Int64;
  end;
var
  data: TData___;
begin
  data.UID__ := UID;
  data.SysTime__ := umlNow();
  data.Tick__ := GetTimeTick();
  data.Seed__ := AtomInc(ZNet_Global_UID_Seed);
  TSHA3.SHA256(Result, @data, SizeOf(data));
end;

function Generate_Global_UID(UID1, UID2: TUID___): TUID___;
type
  TData___ = packed record
    UID1__: TUID___;
    UID2__: TUID___;
    SysTime__: TDateTime;
    Tick__: TTimeTick;
    Seed__: Int64;
  end;
var
  data: TData___;
begin
  data.UID1__ := UID1;
  data.UID2__ := UID2;
  data.SysTime__ := umlNow();
  data.Tick__ := GetTimeTick();
  data.Seed__ := AtomInc(ZNet_Global_UID_Seed);
  TSHA3.SHA256(Result, @data, SizeOf(data));
end;

function Generate_Global_UID(UID1, UID2, UID3: TUID___): TUID___;
type
  TData___ = packed record
    UID1__: TUID___;
    UID2__: TUID___;
    UID3__: TUID___;
    SysTime__: TDateTime;
    Tick__: TTimeTick;
    Seed__: Int64;
  end;
var
  data: TData___;
begin
  data.UID1__ := UID1;
  data.UID2__ := UID2;
  data.UID3__ := UID3;
  data.SysTime__ := umlNow();
  data.Tick__ := GetTimeTick();
  data.Seed__ := AtomInc(ZNet_Global_UID_Seed);
  TSHA3.SHA256(Result, @data, SizeOf(data));
end;

function Generate_Global_UID(UID1, UID2, UID3, UID4: TUID___): TUID___;
type
  TData___ = packed record
    UID1__: TUID___;
    UID2__: TUID___;
    UID3__: TUID___;
    UID4__: TUID___;
    SysTime__: TDateTime;
    Tick__: TTimeTick;
    Seed__: Int64;
  end;
var
  data: TData___;
begin
  data.UID1__ := UID1;
  data.UID2__ := UID2;
  data.UID3__ := UID3;
  data.UID4__ := UID4;
  data.SysTime__ := umlNow();
  data.Tick__ := GetTimeTick();
  data.Seed__ := AtomInc(ZNet_Global_UID_Seed);
  TSHA3.SHA256(Result, @data, SizeOf(data));
end;

function Generate_Global_UID(buff: TBytes): TUID___;
type
  TData___ = packed record
    SysTime__: TDateTime;
    Tick__: TTimeTick;
    Seed__: Int64;
  end;
var
  data: TData___;
  m64: TMem64;
begin
  data.SysTime__ := umlNow();
  data.Tick__ := GetTimeTick();
  data.Seed__ := AtomInc(ZNet_Global_UID_Seed);

  m64 := TMem64.Create;
  m64.WriteBytes(buff);
  m64.WritePtr(@data, SizeOf(data));

  TSHA3.SHA256(Result, m64.Memory, m64.Size);

  DisposeObject(m64);
end;

function IsLocalNetworkIPV4(const S: U_String): Boolean;
var
  n: U_String;
begin
  Result := False;
  n := S.DeleteChar(#32#0#9#13#10);
  if not IsIPv4(n) then
      exit;
  Result := umlMultipleMatch(['192.168.*.*', '10.*.*.*',
      '172.16.*.*', '172.17.*.*', '172.18.*.*', '172.19.*.*', '172.2?.*.*', '172.30.*.*', '172.31.*.*'], n);
end;

function IsLoopbackIPV4(const S: U_String): Boolean;
var
  n: U_String;
begin
  Result := False;
  n := S.DeleteChar(#32#0#9#13#10);
  Result := umlMultipleMatch(['127.0.0.1', 'localhost'], n);
end;

function IsLoopbackIPV6(const S: U_String): Boolean;
var
  n: U_String;
begin
  Result := False;
  n := S.DeleteChar(#32#0#9#13#10);
  Result := umlMultipleMatch(['::1', '::1/*'], n);
end;

function CompareIPV4(const IP1, IP2: TIPV4): Boolean;
begin
  Result := PCardinal(@IP1[0])^ = PCardinal(@IP2[0])^;
end;

function CompareIPV6(const IP1, IP2: TIPV6): Boolean;
begin
  Result := (PUInt64(@IP1[0])^ = PUInt64(@IP2[0])^) and (PUInt64(@IP1[4])^ = PUInt64(@IP2[4])^);
end;

function TranslateBindAddr(addr: SystemString): SystemString;
begin
  addr := umlTrimSpace(addr);
  if addr = '' then
      Result := 'IPv4+IPv6'
  else if addr = '127.0.0.1' then
      Result := 'Local IPv4'
  else if addr = '::1' then
      Result := 'Local IPv6'
  else if addr = '0.0.0.0' then
      Result := 'All IPv4'
  else if addr = '::' then
      Result := 'All IPv6'
  else if IsIPv4(addr) then
      Result := PFormat('Custom IPv4(%s)', [addr])
  else if IsIPV6(addr) then
      Result := PFormat('Custom IPv6(%s)', [addr])
  else
      Result := addr;
end;

procedure ExtractHostAddress(var Host: U_String; var Port: Word);
begin
  Host := Host.TrimChar(#32#10#13#9);
  if Host.GetCharCount(':') = 1 then
    begin
      Port := umlStrToInt(umlGetLastStr(Host, ':'), Port);
      Host := umlDeleteLastStr(Host, ':');
    end
  else if umlMultipleMatch(False, '[*]:*', Host) then
    begin
      Port := umlStrToInt(umlGetLastStr(Host, ':'), Port);
      Host := umlGetFirstStr(Host, '[]');
    end
  else if IsIPV6(Host) and (Host.GetCharCount('|') = 1) then
    begin
      Port := umlStrToInt(umlGetLastStr(Host, '|'), Port);
      Host := umlDeleteLastStr(Host, '|');
    end;
end;

procedure ExtractHostAddress(var Host, Port: U_String);
begin
  Host := Host.TrimChar(#32#10#13#9);
  if Host.GetCharCount(':') = 1 then
    begin
      Port := umlGetLastStr(Host, ':');
      Host := umlDeleteLastStr(Host, ':');
    end
  else if umlMultipleMatch(False, '[*]:*', Host) then
    begin
      Port := umlGetLastStr(Host, ':');
      Host := umlGetFirstStr(Host, '[]');
    end
  else if IsIPV6(Host) and (Host.GetCharCount('|') = 1) then
    begin
      Port := umlGetLastStr(Host, '|');
      Host := umlDeleteLastStr(Host, '|');
    end;
end;

function Build_Host_URL(Host, Port: SystemString): SystemString;
begin
  if IsIPV6(Host) then
      Result := Format('[%s]:%s', [Host, Port])
  else
      Result := Format('%s:%s', [Host, Port]);
end;

function Build_Host_URL(Host: SystemString; Port: Word): SystemString;
begin
  if IsIPV6(Host) then
      Result := Format('[%s]:%d', [Host, Port])
  else
      Result := Format('%s:%d', [Host, Port]);
end;

function Get_Link_OK_Send_Tunnel(IO_: TPeerIO; var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean;
begin
  Result := False;
  if IO_ = nil then
      exit;
  if IO_.UserDefine = nil then
      exit;
  if IO_.UserDefine is TService_RecvTunnel_UserDefine_NoAuth then
    begin
      if not TService_RecvTunnel_UserDefine_NoAuth(IO_.UserDefine).LinkOk then
          exit;
      Send_Tunnel := TService_RecvTunnel_UserDefine_NoAuth(IO_.UserDefine).SendTunnel.Owner.OwnerFramework;
      Send_Tunnel_ID := TService_RecvTunnel_UserDefine_NoAuth(IO_.UserDefine).SendTunnelID;
      Result := True;
    end
  else if IO_.UserDefine is TClient_RecvTunnel_NoAuth then
    begin
      if TClient_RecvTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework is TDTClient_NoAuth then
        if TDTClient_NoAuth(TClient_RecvTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel.ClientIO <> nil then
          begin
            Send_Tunnel := TDTClient_NoAuth(TClient_RecvTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel;
            Send_Tunnel_ID := TDTClient_NoAuth(TClient_RecvTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel.ClientIO.ID;
            Result := True;
          end;
    end
  else if IO_.UserDefine is TService_RecvTunnel_UserDefine_VirtualAuth then
    begin
      if not TService_RecvTunnel_UserDefine_VirtualAuth(IO_.UserDefine).LinkOk then
          exit;
      Send_Tunnel := TService_RecvTunnel_UserDefine_VirtualAuth(IO_.UserDefine).SendTunnel.Owner.OwnerFramework;
      Send_Tunnel_ID := TService_RecvTunnel_UserDefine_VirtualAuth(IO_.UserDefine).SendTunnelID;
      Result := True;
    end
  else if IO_.UserDefine is TClient_RecvTunnel_VirtualAuth then
    begin
      if TClient_RecvTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework is TDTClient_VirtualAuth then
        if TDTClient_VirtualAuth(TClient_RecvTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel.ClientIO <> nil then
          begin
            Send_Tunnel := TDTClient_VirtualAuth(TClient_RecvTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel;
            Send_Tunnel_ID := TDTClient_VirtualAuth(TClient_RecvTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel.ClientIO.ID;
            Result := True;
          end;
    end
  else if IO_.UserDefine is TService_RecvTunnel_UserDefine then
    begin
      if not TService_RecvTunnel_UserDefine(IO_.UserDefine).LinkOk then
          exit;
      Send_Tunnel := TService_RecvTunnel_UserDefine(IO_.UserDefine).SendTunnel.Owner.OwnerFramework;
      Send_Tunnel_ID := TService_RecvTunnel_UserDefine(IO_.UserDefine).SendTunnelID;
      Result := True;
    end
  else if IO_.UserDefine is TClient_RecvTunnel then
    begin
      if TClient_RecvTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework is TDTClient then
        if TDTClient(TClient_RecvTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel.ClientIO <> nil then
          begin
            Send_Tunnel := TDTClient(TClient_RecvTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel;
            Send_Tunnel_ID := TDTClient(TClient_RecvTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).SendTunnel.ClientIO.ID;
            Result := True;
          end;
    end;
end;

function Get_Link_OK_Send_Tunnel(Framework_: TZNet; ID_: Cardinal; var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean;
begin
  Result := Get_Link_OK_Send_Tunnel(Framework_.PeerIO_HashPool[ID_], Send_Tunnel, Send_Tunnel_ID);
end;

function Get_Link_OK_Recv_Tunnel(IO_: TPeerIO; var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean;
begin
  Result := False;
  if IO_ = nil then
      exit;
  if IO_.UserDefine = nil then
      exit;
  if IO_.UserDefine is TService_SendTunnel_UserDefine_NoAuth then
    begin
      if not TService_SendTunnel_UserDefine_NoAuth(IO_.UserDefine).LinkOk then
          exit;
      Recv_Tunnel := TService_SendTunnel_UserDefine_NoAuth(IO_.UserDefine).RecvTunnel.Owner.OwnerFramework;
      Recv_Tunnel_ID := TService_SendTunnel_UserDefine_NoAuth(IO_.UserDefine).RecvTunnelID;
      Result := True;
    end
  else if IO_.UserDefine is TClient_SendTunnel_NoAuth then
    begin
      if TClient_SendTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework is TDTClient_NoAuth then
        if TDTClient_NoAuth(TClient_SendTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel.ClientIO <> nil then
          begin
            Recv_Tunnel := TDTClient_NoAuth(TClient_SendTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel;
            Recv_Tunnel_ID := TDTClient_NoAuth(TClient_SendTunnel_NoAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel.ClientIO.ID;
            Result := True;
          end;
    end
  else if IO_.UserDefine is TService_SendTunnel_UserDefine_VirtualAuth then
    begin
      if not TService_SendTunnel_UserDefine_VirtualAuth(IO_.UserDefine).LinkOk then
          exit;
      Recv_Tunnel := TService_SendTunnel_UserDefine_VirtualAuth(IO_.UserDefine).RecvTunnel.Owner.OwnerFramework;
      Recv_Tunnel_ID := TService_SendTunnel_UserDefine_VirtualAuth(IO_.UserDefine).RecvTunnelID;
      Result := True;
    end
  else if IO_.UserDefine is TClient_SendTunnel_VirtualAuth then
    begin
      if TClient_SendTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework is TDTClient_VirtualAuth then
        if TDTClient_VirtualAuth(TClient_SendTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel.ClientIO <> nil then
          begin
            Recv_Tunnel := TDTClient_VirtualAuth(TClient_SendTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel;
            Recv_Tunnel_ID := TDTClient_VirtualAuth(TClient_SendTunnel_VirtualAuth(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel.ClientIO.ID;
            Result := True;
          end;
    end
  else if IO_.UserDefine is TService_SendTunnel_UserDefine then
    begin
      if not TService_SendTunnel_UserDefine(IO_.UserDefine).LinkOk then
          exit;
      Recv_Tunnel := TService_SendTunnel_UserDefine(IO_.UserDefine).RecvTunnel.Owner.OwnerFramework;
      Recv_Tunnel_ID := TService_SendTunnel_UserDefine(IO_.UserDefine).RecvTunnelID;
      Result := True;
    end
  else if IO_.UserDefine is TClient_SendTunnel then
    begin
      if TClient_SendTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework is TDTClient then
        if TDTClient(TClient_SendTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel.ClientIO <> nil then
          begin
            Recv_Tunnel := TDTClient(TClient_SendTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel;
            Recv_Tunnel_ID := TDTClient(TClient_SendTunnel(IO_.UserDefine).Owner.OwnerFramework.DoubleChannelFramework).RecvTunnel.ClientIO.ID;
            Result := True;
          end;
    end;
end;

function Get_Link_OK_Recv_Tunnel(Framework_: TZNet; ID_: Cardinal; var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean;
begin
  Result := Get_Link_OK_Recv_Tunnel(Framework_.PeerIO_HashPool[ID_], Recv_Tunnel, Recv_Tunnel_ID);
end;

procedure DoExecuteResult(IO: TPeerIO; const QueuePtr: PQueueData; const Result_Text: SystemString; Result_DF: TDFE);
var
  InData: TDFE;
begin
  if QueuePtr = nil then
      exit;

  IO.FReceiveResultRuning := True;

  try
    if Assigned(QueuePtr^.OnConsoleM) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('console on result: %s', QueuePtr^.Cmd);
        try
            QueuePtr^.OnConsoleM(IO, Result_Text);
        except
        end;
      end
    else if Assigned(QueuePtr^.OnConsoleParamM) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('console on param result: %s', QueuePtr^.Cmd);
        try
            QueuePtr^.OnConsoleParamM(IO, QueuePtr^.Param1, QueuePtr^.Param2, QueuePtr^.ConsoleData, Result_Text);
        except
        end;
      end
    else if Assigned(QueuePtr^.OnConsoleP) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('console on result(proc): %s', QueuePtr^.Cmd);
        try
            QueuePtr^.OnConsoleP(IO, Result_Text);
        except
        end;
      end
    else if Assigned(QueuePtr^.OnConsoleParamP) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('console on param result(proc): %s', QueuePtr^.Cmd);
        try
            QueuePtr^.OnConsoleParamP(IO, QueuePtr^.Param1, QueuePtr^.Param2, QueuePtr^.ConsoleData, Result_Text);
        except
        end;
      end
    else if Assigned(QueuePtr^.OnStreamM) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('stream on result: %s', QueuePtr^.Cmd);
        try
          Result_DF.Reader.index := 0;
          QueuePtr^.OnStreamM(IO, Result_DF);
        except
        end;
      end
    else if Assigned(QueuePtr^.OnStreamParamM) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('stream on param result: %s', QueuePtr^.Cmd);
        try
          Result_DF.Reader.index := 0;
          InData := TDFE.Create;
          QueuePtr^.StreamData.Position := 0;
          InData.DecodeFrom(QueuePtr^.StreamData, True);
          QueuePtr^.OnStreamParamM(IO, QueuePtr^.Param1, QueuePtr^.Param2, InData, Result_DF);
          DisposeObject(InData);
        except
        end;
      end
    else if Assigned(QueuePtr^.OnStreamP) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('stream on result(proc): %s', QueuePtr^.Cmd);
        try
          Result_DF.Reader.index := 0;
          QueuePtr^.OnStreamP(IO, Result_DF);
        except
        end;
      end
    else if Assigned(QueuePtr^.OnStreamParamP) then
      begin
        if not IO.OwnerFramework.QuietMode then
            IO.PrintCommand('stream on result(parameter + proc): %s', QueuePtr^.Cmd);
        try
          Result_DF.Reader.index := 0;
          InData := TDFE.Create;
          QueuePtr^.StreamData.Position := 0;
          InData.DecodeFrom(QueuePtr^.StreamData, True);
          QueuePtr^.OnStreamParamP(IO, QueuePtr^.Param1, QueuePtr^.Param2, InData, Result_DF);
          DisposeObject(InData);
        except
        end;
      end;
  except
  end;
  IO.FReceiveResultRuning := False;
end;

procedure Set_Instance_QuietMode(Inst: TZNet; QuietMode_: Boolean);
var
  p2p_: TZNet_WithP2PVM_Client;
  i: Integer;
begin
  Inst.QuietMode := QuietMode_;
  if Inst is TZNet_Server then
    begin
    end
  else if Inst is TZNet_WithP2PVM_Client then
    begin
      p2p_ := TZNet_WithP2PVM_Client(Inst);
      for i := 0 to p2p_.ClonePool.Count - 1 do
          Set_Instance_QuietMode(p2p_.ClonePool[i], QuietMode_);
    end;
end;
