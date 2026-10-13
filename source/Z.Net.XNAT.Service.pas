(*
MIT License

Copyright (c) 2026 by.LaoZhang qq600585

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
{ ******************************************************************************
  * XNAT Service Implementation
  * Implements the public server that accepts external client connections and
  * forwards them to registered XNAT clients through P2PVM tunnels.
  *
  * BUGFIX (2026):
  *   - TXServiceRecvVM_Special.Destroy / TXServiceSendVM_Special.Destroy now
  *     guard against nil OwnerMapping, FSendTunnel, FRecvTunnel, FProtocol.
  *   - PickWorkloadTunnel now handles FMaxWorkload = 0 without dividing by
  *     zero; such tunnels are treated as "do not pick".
  *   - cmd_workload rejects FMaxWorkload = 0 from the client.
  *   - cmd_data now checks destBuff <> nil after Extract_XNAT_Buff.
  *   - TXServerCustomProtocol.OnReceiveBuffer now bounds the pre-init
  *     RequestBuffer to prevent unbounded memory growth (DoS).
  *   - TXServerCustomProtocol.DoIOConnectBefore now closes the connection
  *     when no workload tunnel is available (s_id = 0).
  *   - TXServerCustomProtocol.OnReceiveBuffer / DoIOConnectBefore /
  *     DoIODisconnect now guard against nil ShareListen and FSendTunnel.
  *   - TXNATService.Progress now guards against nil FProtocol.
  ****************************************************************************** }
unit Z.Net.XNAT.Service;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Status, Z.UnicodeMixedLib, Z.ListEngine, Z.TextDataEngine,
  Z.Cipher, Z.DFE, Z.MemoryStream, Z.Net, Z.Net.XNAT.Physics;

type
  TXNATService = class;
  TXServerCustomProtocol = class;
  TXServiceListen = class;

  TXServiceRecvVM_Special = class(TPeer_IO_User_Special)
  private
    OwnerMapping: TXServiceListen;
    RecvID, SendID: Cardinal;
    FMaxWorkload, CurrentWorkload: Cardinal;
  public
    constructor Create(Owner_: TPeerIO); override;
    destructor Destroy; override;
  end;

  TXServiceSendVM_Special = class(TPeer_IO_User_Special)
  private
    OwnerMapping: TXServiceListen;
    RecvID, SendID: Cardinal;
  public
    constructor Create(Owner_: TPeerIO); override;
    destructor Destroy; override;
  end;

  TXCustomP2PVM_Server = class(TZNet_WithP2PVM_Server)
  private
    OwnerMapping: TXServiceListen;
  end;

  TXServiceListen = class(TCore_Object_Intermediate)
  private
    FOwner: TXNATService;
    FListenAddr: TPascalString;
    FListenPort: TPascalString;
    FMapping: TPascalString;

    FProtocol: TXServerCustomProtocol;
    FActivted: Boolean;
    FTest_Listening_Passed: Boolean;

    FRecvTunnel: TXCustomP2PVM_Server;
    FRecvTunnel_IPV6: TIPV6;
    FRecvTunnel_Port: Word;

    FSendTunnel: TXCustomP2PVM_Server;
    FSendTunnel_IPV6: TIPV6;
    FSendTunnel_Port: Word;

    DistributedWorkload: Boolean;
    XServerTunnel: TXNATService;
    TimeOut: TTimeTick;

    Complete_Buffer_Sum: Int64;

    procedure Init;
    function Open: Boolean;

    procedure PickWorkloadTunnel(var rID, sID: Cardinal);

    procedure cmd_RequestListen(Sender: TPeerIO; InData, OutData: TDFE);
    procedure cmd_workload(Sender: TPeerIO; InData: TDFE);
    procedure cmd_connect_reponse(Sender: TPeerIO; InData: TDFE);
    procedure cmd_disconnect_reponse(Sender: TPeerIO; InData: TDFE);
    procedure cmd_data(Sender: TPeerIO; InData: PByte; DataSize: NativeInt);

    procedure SetActivted(const Value: Boolean);
  public
    UserData: Pointer;
    UserObject: TCore_Object;

    constructor Create(Owner_: TXNATService); virtual;
    destructor Destroy; override;

    property Protocol: TXServerCustomProtocol read FProtocol;
    property ListenAddr: TPascalString read FListenAddr;
    property ListenPort: TPascalString read FListenPort;
    property Mapping: TPascalString read FMapping;
    property Test_Listening_Passed: Boolean read FTest_Listening_Passed;
    property Activted: Boolean read FActivted write SetActivted;
  end;

  TXServiceListen_Class = class of TXServiceListen;

  TXServerUserSpecial = class(TPeer_IO_User_Special)
  private
    RemoteProtocol_ID: Cardinal;
    RemoteProtocol_Inited: Boolean;
    RequestBuffer: TMS64;
    r_id, s_id: Cardinal;
  public
    constructor Create(Owner_: TPeerIO); override;
    destructor Destroy; override;
  end;

  TXServerCustomProtocol = class(TXPhysicsServer)
  private
    ShareListen: TXServiceListen;
  public
    procedure OnReceiveBuffer(Sender: TPeerIO; const buffer: PByte; const Size: NativeInt; var FillDone: Boolean); override;
    procedure DoIOConnectBefore(Sender: TPeerIO); override;
    procedure DoIODisconnect(Sender: TPeerIO); override;
  end;

  TPhysicsEngine_Special = class(TPeer_IO_User_Special)
  protected
    FXNAT_VS: TXNATService;
    procedure PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);
    procedure PhysicsVMBuildAuthToken_Result;
    procedure PhysicsOpenVM_Result(const cState: Boolean);
  public
    constructor Create(Owner_: TPeerIO); override;
    destructor Destroy; override;
  end;

  TXServiceMappingList = TGenericsList<TXServiceListen>;

  TOn_XNATService_Open_Tunnel_Done = procedure(Sender: TXNATService; State: Boolean) of object;

  TXNATService = class(TCore_InterfacedObject_Intermediate, IIOInterface, IZNet_VMInterface)
  private
    FShareListenList: TXServiceMappingList;
    FPhysicsEngine: TZNet;
    FQuiet: Boolean;
    FActivted: Boolean;
    WaitAsyncConnecting: Boolean;
    WaitAsyncConnecting_BeginTime: TTimeTick;

    procedure IPV6Listen(Sender: TPeerIO; InData, OutData: TDFE);

    procedure PeerIO_Create(const Sender: TPeerIO);
    procedure PeerIO_Destroy(const Sender: TPeerIO);

    procedure p2pVMTunnelAuth(Sender: TPeerIO; const Token: SystemString; var Accept: Boolean);
    procedure p2pVMTunnelOpenBefore(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelOpen(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelOpenAfter(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelClose(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);

    procedure PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);

    procedure Do_Open_Done(State: Boolean);

    procedure Set_Quiet(const Value: Boolean);
  public
    Host: TPascalString;
    Port: TPascalString;
    AuthToken: TPascalString;
    MaxVMFragment: TPascalString;

    ProtocolCompressed: Boolean;

    Instance_Class: TXServiceListen_Class;
    On_Open_Tunnel_Done: TOn_XNATService_Open_Tunnel_Done;
    Open_Done: Boolean;

  public
    property Activted: Boolean read FActivted;
    property PhysicsEngine: TZNet read FPhysicsEngine;
    property ShareListenList: TXServiceMappingList read FShareListenList;
    property Quiet: Boolean read FQuiet write Set_Quiet;

    constructor Create;
    destructor Destroy; override;

    procedure Reset();

    function AddMapping(const ListenAddr, ListenPort, FMapping: TPascalString; TimeOut: TTimeTick): TXServiceListen;
    function AddNoDistributedMapping(const ListenAddr, ListenPort, FMapping: TPascalString; TimeOut: TTimeTick): TXServiceListen;

    procedure OpenTunnel(MODEL: TXNAT_PHYSICS_MODEL); overload;
    procedure OpenTunnel; overload;

    procedure Progress;
  end;

implementation

{ BUGFIX: bound pre-init request buffer to 64 MB. }
const
  C_MaxRequestBufferSize = 64 * 1024 * 1024;
  { BUGFIX: treat a zero max-workload tunnel as "do not pick" via a huge ratio. }
  C_MaxWorkloadRatio = 1.0E30;

constructor TXServiceRecvVM_Special.Create(Owner_: TPeerIO);
begin
  inherited Create(Owner_);
  OwnerMapping := nil;
  RecvID := 0;
  SendID := 0;
  FMaxWorkload := 100;
  CurrentWorkload := 0;
end;

destructor TXServiceRecvVM_Special.Destroy;
var
  IO_Array: TIO_Array;
  p_id: Cardinal;
  p_io: TPeerIO;
begin
  { BUGFIX: guard against nil pointers during teardown. }
  try
    if (OwnerMapping <> nil) then
      begin
        if (OwnerMapping.FSendTunnel <> nil) and OwnerMapping.FSendTunnel.ExistsID(SendID) then
            OwnerMapping.FSendTunnel.Disconnect(SendID);

        if (OwnerMapping.FProtocol <> nil) then
          begin
            OwnerMapping.FProtocol.GetIO_Array(IO_Array);
            for p_id in IO_Array do
              begin
                p_io := OwnerMapping.FProtocol.PeerIO[p_id];
                if (p_io <> nil) and (p_io.UserSpecial <> nil) and
                  (TXServerUserSpecial(p_io.UserSpecial).r_id = Owner.ID) then
                    p_io.DelayClose(0);
              end;
            SetLength(IO_Array, 0);
          end;
      end;
  except
  end;

  inherited Destroy;
end;

constructor TXServiceSendVM_Special.Create(Owner_: TPeerIO);
begin
  inherited Create(Owner_);
  OwnerMapping := nil;
  RecvID := 0;
  SendID := 0;
end;

destructor TXServiceSendVM_Special.Destroy;
begin
  { BUGFIX: guard against nil pointers during teardown. }
  try
    if (OwnerMapping <> nil) and (OwnerMapping.FRecvTunnel <> nil) then
      if OwnerMapping.FRecvTunnel.ExistsID(RecvID) then
          OwnerMapping.FRecvTunnel.Disconnect(RecvID);
  except
  end;
  inherited Destroy;
end;

procedure TXServiceListen.Init;
begin
  FListenAddr := '';
  FListenPort := '0';
  FMapping := '';
  FProtocol := nil;
  FActivted := False;
  FTest_Listening_Passed := False;
  FRecvTunnel := nil;
  FillPtrByte(@FRecvTunnel_IPV6, SizeOf(TIPV6), 0);
  FRecvTunnel_Port := 0;
  FSendTunnel := nil;
  FillPtrByte(@FSendTunnel_IPV6, SizeOf(TIPV6), 0);
  FSendTunnel_Port := 0;
  DistributedWorkload := False;
  XServerTunnel := nil;
  TimeOut := 0;
  Complete_Buffer_Sum := 0;
  UserData := nil;
  UserObject := nil;
end;

function TXServiceListen.Open: Boolean;
var
  nt: Pointer;
begin
  if FRecvTunnel = nil then
    begin
      FRecvTunnel := TXCustomP2PVM_Server.Create;
      FRecvTunnel.QuietMode := FOwner.Quiet;
      FRecvTunnel.CompleteBufferSwapSpace := True;
    end;

  FRecvTunnel.SyncOnCompleteBuffer := True;
  FRecvTunnel.SyncOnResult := True;
  FRecvTunnel.SwitchMaxPerformance;
  FRecvTunnel.OwnerMapping := Self;
  FRecvTunnel.UserSpecialClass := TXServiceRecvVM_Special;
  FRecvTunnel.CompleteBufferCompressed := XServerTunnel.ProtocolCompressed;
  nt := @FRecvTunnel;
  TSHA3.SHAKE128(@FRecvTunnel_IPV6, @nt, SizeOf(nt), 128);
  FRecvTunnel_Port := umlCRC16(@FRecvTunnel_IPV6, SizeOf(TIPV6));
  FRecvTunnel.PrintParams[C_Connect_reponse] := False;
  FRecvTunnel.PrintParams[C_Disconnect_reponse] := False;
  FRecvTunnel.PrintParams[C_Data] := False;
  FRecvTunnel.PrintParams[C_Workload] := False;

  if not FRecvTunnel.ExistsRegistedCmd(C_RequestListen) then
      FRecvTunnel.RegisterStream(C_RequestListen).OnExecute := cmd_RequestListen;

  if not FRecvTunnel.ExistsRegistedCmd(C_Workload) then
      FRecvTunnel.RegisterStreamNotify(C_Workload).OnExecute := cmd_workload;

  if not FRecvTunnel.ExistsRegistedCmd(C_Connect_reponse) then
      FRecvTunnel.RegisterStreamNotify(C_Connect_reponse).OnExecute := cmd_connect_reponse;

  if not FRecvTunnel.ExistsRegistedCmd(C_Disconnect_reponse) then
      FRecvTunnel.RegisterStreamNotify(C_Disconnect_reponse).OnExecute := cmd_disconnect_reponse;

  if not FRecvTunnel.ExistsRegistedCmd(C_Data) then
      FRecvTunnel.RegisterCompleteBuffer(C_Data).OnExecute := cmd_data;

  if FSendTunnel = nil then
    begin
      FSendTunnel := TXCustomP2PVM_Server.Create;
      FSendTunnel.QuietMode := FOwner.Quiet;
      FSendTunnel.CompleteBufferSwapSpace := True;
    end;

  FSendTunnel.SyncOnCompleteBuffer := True;
  FSendTunnel.SyncOnResult := True;
  FSendTunnel.SwitchMaxPerformance;
  FSendTunnel.OwnerMapping := Self;
  FSendTunnel.UserSpecialClass := TXServiceSendVM_Special;
  FSendTunnel.CompleteBufferCompressed := XServerTunnel.ProtocolCompressed;
  nt := @FSendTunnel;
  TSHA3.SHAKE128(@FSendTunnel_IPV6, @nt, SizeOf(nt), 128);
  FSendTunnel_Port := umlCRC16(@FSendTunnel_IPV6, SizeOf(TIPV6));
  FSendTunnel.PrintParams[C_Connect_request] := False;
  FSendTunnel.PrintParams[C_Disconnect_request] := False;
  FSendTunnel.PrintParams[C_Data] := False;

  FRecvTunnel.StartService(IPv6ToStr(FRecvTunnel_IPV6), FRecvTunnel_Port);
  FSendTunnel.StartService(IPv6ToStr(FSendTunnel_IPV6), FSendTunnel_Port);

  if FProtocol = nil then
      FProtocol := TXServerCustomProtocol.Create;
  FProtocol.QuietMode := FOwner.Quiet;
  FProtocol.ShareListen := Self;
  FProtocol.Protocol := cpCustom;
  FProtocol.UserSpecialClass := TXServerUserSpecial;
  FProtocol.TimeOutIDLE := TimeOut;

  SetActivted(True);
  Result := FActivted;
  FTest_Listening_Passed := FActivted;
  SetActivted(False);

  if not Result then
      FProtocol.Error('detect listen bind %s:%s failed!', [TranslateBindAddr(FListenAddr), FListenPort.Text]);
end;

procedure TXServiceListen.PickWorkloadTunnel(var rID, sID: Cardinal);
var
  rVM: TXServiceRecvVM_Special;
  buff: TIO_Array;
  ID: Cardinal;
  r_io: TPeerIO;
  f, d: Double;
begin
  rID := 0;
  sID := 0;
  if FRecvTunnel.Count = 0 then
      exit;
  if FSendTunnel.Count = 0 then
      exit;

  rVM := TXServiceRecvVM_Special(FRecvTunnel.FirstIO.UserSpecial);
  { BUGFIX: avoid division by zero when FMaxWorkload = 0. }
  if rVM.FMaxWorkload = 0 then
      f := C_MaxWorkloadRatio
  else
      f := rVM.CurrentWorkload / rVM.FMaxWorkload;

  FRecvTunnel.GetIO_Array(buff);
  for ID in buff do
    begin
      r_io := FRecvTunnel.PeerIO[ID];
      if (r_io <> nil) and (r_io.UserSpecial <> rVM) then
        begin
          with TXServiceRecvVM_Special(r_io.UserSpecial) do
            if FMaxWorkload = 0 then
                d := C_MaxWorkloadRatio
            else
                d := CurrentWorkload / FMaxWorkload;
          if d < f then
            begin
              f := d;
              rVM := TXServiceRecvVM_Special(r_io.UserSpecial);
            end;
        end;
    end;
  SetLength(buff, 0);

  if not FSendTunnel.Exists(rVM.SendID) then
      exit;

  rID := rVM.RecvID;
  sID := rVM.SendID;
end;

procedure TXServiceListen.cmd_RequestListen(Sender: TPeerIO; InData, OutData: TDFE);
var
  RecvID, SendID: Cardinal;
  rVM: TXServiceRecvVM_Special;
  sVM: TXServiceSendVM_Special;
begin
  RecvID := InData.Reader.ReadCardinal;
  SendID := InData.Reader.ReadCardinal;

  if DistributedWorkload then
    begin
      if not FRecvTunnel.Exists(RecvID) then
        begin
          OutData.WriteBool(False);
          OutData.WriteString(PFormat('receive tunnel ID illegal %d', [RecvID]));
          exit;
        end;

      if not FSendTunnel.Exists(SendID) then
        begin
          OutData.WriteBool(False);
          OutData.WriteString(PFormat('send tunnel ID illegal %d', [SendID]));
          exit;
        end;

      if not Activted then
        begin
          Activted := True;
          if (not Activted) then
            begin
              OutData.WriteBool(False);
              OutData.WriteString(PFormat('remote service illegal bind IP %s port:%s', [FListenAddr.Text, FListenPort.Text]));
              exit;
            end;
        end;

      rVM := TXServiceRecvVM_Special(FRecvTunnel.PeerIO[RecvID].UserSpecial);
      rVM.OwnerMapping := Self;
      rVM.RecvID := RecvID;
      rVM.SendID := SendID;

      sVM := TXServiceSendVM_Special(FSendTunnel.PeerIO[SendID].UserSpecial);
      sVM.OwnerMapping := Self;
      sVM.RecvID := RecvID;
      sVM.SendID := SendID;

      OutData.WriteBool(True);
      OutData.WriteString(PFormat('bridge XNAT service successed, bind IP %s port:%s', [FListenAddr.Text, FListenPort.Text]));
    end
  else
    begin
      if Activted then
        begin
          OutData.WriteBool(False);
          OutData.WriteString(PFormat('bridge service no support distributed workload', []));
          exit;
        end;

      if not FRecvTunnel.Exists(RecvID) then
        begin
          OutData.WriteBool(False);
          OutData.WriteString(PFormat('receive tunnel ID illegal %d', [RecvID]));
          exit;
        end;

      if not FSendTunnel.Exists(SendID) then
        begin
          OutData.WriteBool(False);
          OutData.WriteString(PFormat('send tunnel ID illegal %d', [SendID]));
          exit;
        end;

      Activted := True;
      if (not Activted) then
        begin
          OutData.WriteBool(False);
          OutData.WriteString(PFormat('remote service illegal bind IP %s port:%s', [FListenAddr.Text, FListenPort.Text]));
          exit;
        end;

      rVM := TXServiceRecvVM_Special(FRecvTunnel.PeerIO[RecvID].UserSpecial);
      rVM.OwnerMapping := Self;
      rVM.RecvID := RecvID;
      rVM.SendID := SendID;

      sVM := TXServiceSendVM_Special(FSendTunnel.PeerIO[SendID].UserSpecial);
      sVM.OwnerMapping := Self;
      sVM.RecvID := RecvID;
      sVM.SendID := SendID;

      OutData.WriteBool(True);
      OutData.WriteString(PFormat('bridge XNAT service successed, bind IP %s port:%s', [FListenAddr.Text, FListenPort.Text]));
    end;
end;

procedure TXServiceListen.cmd_workload(Sender: TPeerIO; InData: TDFE);
var
  rVM: TXServiceRecvVM_Special;
  nMax, nCur: Cardinal;
begin
  if Sender.UserSpecial = nil then
      exit;
  rVM := TXServiceRecvVM_Special(Sender.UserSpecial);
  nMax := InData.Reader.ReadCardinal;
  nCur := InData.Reader.ReadCardinal;
  { BUGFIX: reject a zero max workload from the client; clamp to 1 to
    prevent any downstream division by zero. }
  if nMax = 0 then
      nMax := 1;
  rVM.FMaxWorkload := nMax;
  rVM.CurrentWorkload := nCur;
end;

procedure TXServiceListen.cmd_connect_reponse(Sender: TPeerIO; InData: TDFE);
var
  cState: Boolean;
  remote_id, local_id: Cardinal;
  phy_io, s_io: TPeerIO;
  XUserSpec: TXServerUserSpecial;
  nSiz: NativeInt;
  nBuff: PByte;
begin
  cState := InData.Reader.ReadBool;
  remote_id := InData.Reader.ReadCardinal;
  local_id := InData.Reader.ReadCardinal;
  phy_io := FProtocol.PeerIO[local_id];

  if phy_io = nil then
      exit;

  if cState then
    begin
      XUserSpec := TXServerUserSpecial(phy_io.UserSpecial);
      XUserSpec.RemoteProtocol_ID := remote_id;
      XUserSpec.RemoteProtocol_Inited := True;

      if XUserSpec.RequestBuffer.Size > 0 then
        begin
          s_io := FSendTunnel.PeerIO[XUserSpec.s_id];
          if s_io <> nil then
            begin
              Build_XNAT_Buff(XUserSpec.RequestBuffer.Memory, XUserSpec.RequestBuffer.Size, Sender.ID, XUserSpec.RemoteProtocol_ID, nSiz, nBuff);
              s_io.SendCompleteBuffer(C_Data, nBuff, nSiz, True);
            end;
          XUserSpec.RequestBuffer.Clear;
        end;
    end
  else
      phy_io.DelayClose;
end;

procedure TXServiceListen.cmd_disconnect_reponse(Sender: TPeerIO; InData: TDFE);
var
  remote_id, local_id: Cardinal;
  phy_io: TPeerIO;
begin
  remote_id := InData.Reader.ReadCardinal;
  local_id := InData.Reader.ReadCardinal;
  phy_io := FProtocol.PeerIO[local_id];

  if phy_io = nil then
      exit;

  phy_io.DelayClose(1.0);
end;

procedure TXServiceListen.cmd_data(Sender: TPeerIO; InData: PByte; DataSize: NativeInt);
var
  local_id, remote_id: Cardinal;
  destSiz: NativeInt;
  destBuff: PByte;
  phy_io: TPeerIO;
begin
  Extract_XNAT_Buff(InData, DataSize, local_id, remote_id, destSiz, destBuff);
  { BUGFIX: reject malformed short packets. }
  if destBuff = nil then
      exit;

  phy_io := FProtocol.PeerIO[local_id];

  if phy_io <> nil then
    begin
      FProtocol.BeginWriteBuffer(phy_io);
      FProtocol.WriteBuffer(phy_io, destBuff, destSiz);
      FProtocol.EndWriteBuffer(phy_io);
    end;
end;

procedure TXServiceListen.SetActivted(const Value: Boolean);
begin
  if Value then
    begin
      FActivted := FProtocol.StartService(FListenAddr, umlStrToInt(FListenPort));
      FProtocol.Print('Start listen %s %s', [TranslateBindAddr(FListenAddr.Text), FListenPort.Text]);
    end
  else
    begin
      FProtocol.StopService;
      FActivted := False;
      FProtocol.Print('Close listen %s %s', [TranslateBindAddr(FListenAddr.Text), FListenPort.Text]);
    end;
end;

constructor TXServiceListen.Create(Owner_: TXNATService);
begin
  inherited Create;
  FOwner := Owner_;
  Init;
end;

destructor TXServiceListen.Destroy;
begin
  if FProtocol <> nil then
      FProtocol.StopService;

  if FRecvTunnel <> nil then
      FRecvTunnel.StopService;

  if FSendTunnel <> nil then
      FSendTunnel.StopService;

  DisposeObject(FRecvTunnel);
  DisposeObject(FSendTunnel);
  DisposeObject(FProtocol);
  inherited Destroy;
end;

constructor TXServerUserSpecial.Create(Owner_: TPeerIO);
begin
  inherited Create(Owner_);
  RemoteProtocol_ID := 0;
  RemoteProtocol_Inited := False;
  RequestBuffer := TMS64.CustomCreate(8192);
  r_id := 0;
  s_id := 0;
end;

destructor TXServerUserSpecial.Destroy;
begin
  DisposeObject(RequestBuffer);
  inherited Destroy;
end;

procedure TXServerCustomProtocol.OnReceiveBuffer(Sender: TPeerIO; const buffer: PByte; const Size: NativeInt; var FillDone: Boolean);
var
  XUserSpec: TXServerUserSpecial;
  nSiz: NativeInt;
  nBuff: PByte;
  s_io: TPeerIO;
begin
  { BUGFIX: guard against nil ShareListen / FSendTunnel. }
  if ShareListen = nil then
      exit;
  if ShareListen.FSendTunnel = nil then
      exit;

  if (ShareListen.FSendTunnel.Count <> 1) and (not ShareListen.DistributedWorkload) then
    begin
      Sender.Print('share listen "%s:%s" no remote support', [ShareListen.FListenAddr.Text, ShareListen.FListenPort.Text]);
      exit;
    end;

  if Sender.UserSpecial = nil then
      exit;
  XUserSpec := TXServerUserSpecial(Sender.UserSpecial);
  if not XUserSpec.RemoteProtocol_Inited then
    begin
      { BUGFIX: bound the pre-init request buffer to prevent DoS. }
      if XUserSpec.RequestBuffer.Size + Size > C_MaxRequestBufferSize then
        begin
          Sender.Print('share listen "%s:%s" request buffer overflow', [ShareListen.FListenAddr.Text, ShareListen.FListenPort.Text]);
          Sender.DelayClose(1.0);
          exit;
        end;
      XUserSpec.RequestBuffer.WritePtr(buffer, Size);
      exit;
    end;

  s_io := ShareListen.FSendTunnel.PeerIO[XUserSpec.s_id];
  if s_io <> nil then
    begin
      Build_XNAT_Buff(buffer, Size, Sender.ID, XUserSpec.RemoteProtocol_ID, nSiz, nBuff);
      s_io.SendCompleteBuffer(C_Data, nBuff, nSiz, True);
      inc(ShareListen.Complete_Buffer_Sum, nSiz);
      if ShareListen.Complete_Buffer_Sum > 10 * 1024 * 1024 then
        begin
          s_io.Send_NULL;
          ShareListen.Complete_Buffer_Sum := 0;
        end
      else
          ShareListen.FSendTunnel.Progress_IO_Now_Send(s_io);
    end
  else
      Sender.DelayClose(1.0);
end;

procedure TXServerCustomProtocol.DoIOConnectBefore(Sender: TPeerIO);
var
  de: TDFE;
  XUserSpec: TXServerUserSpecial;
  s_io: TPeerIO;
begin
  { BUGFIX: guard against nil ShareListen / FSendTunnel. }
  if ShareListen = nil then
      exit;
  if ShareListen.FSendTunnel = nil then
    begin
      Sender.DelayClose(1.0);
      exit;
    end;

  if (ShareListen.FSendTunnel.Count <> 1) and (not ShareListen.DistributedWorkload) then
    begin
      Sender.Print('share listen "%s:%s" no remote support', [ShareListen.FListenAddr.Text, ShareListen.FListenPort.Text]);
      Sender.DelayClose(1.0);
      exit;
    end;

  if Sender.UserSpecial = nil then
    begin
      Sender.DelayClose(1.0);
      exit;
    end;
  XUserSpec := TXServerUserSpecial(Sender.UserSpecial);

  if XUserSpec.RemoteProtocol_Inited then
      exit;

  ShareListen.PickWorkloadTunnel(XUserSpec.r_id, XUserSpec.s_id);

  { BUGFIX: no workload tunnel available, close the external connection. }
  if XUserSpec.s_id = 0 then
    begin
      Sender.Print('share listen "%s:%s" no workload tunnel available', [ShareListen.FListenAddr.Text, ShareListen.FListenPort.Text]);
      Sender.DelayClose(1.0);
      exit;
    end;

  if ShareListen.FSendTunnel.Exists(XUserSpec.s_id) then
    begin
      s_io := ShareListen.FSendTunnel.PeerIO[XUserSpec.s_id];
      de := TDFE.Create;
      de.WriteCardinal(Sender.ID);
      de.WriteString(Sender.PeerIP);
      s_io.SendStreamNotifyCmd(C_Connect_request, de);
      DisposeObject(de);
      s_io.Progress;
    end;
  inherited DoIOConnectBefore(Sender);
end;

procedure TXServerCustomProtocol.DoIODisconnect(Sender: TPeerIO);
var
  de: TDFE;
  XUserSpec: TXServerUserSpecial;
  s_io: TPeerIO;
begin
  { BUGFIX: guard against nil ShareListen / FSendTunnel. }
  if ShareListen = nil then
      exit;
  if ShareListen.FSendTunnel = nil then
      exit;

  if (ShareListen.FSendTunnel.Count <> 1) and (not ShareListen.DistributedWorkload) then
    begin
      Sender.Print('share listen "%s:%s" no remote support', [ShareListen.FListenAddr.Text, ShareListen.FListenPort.Text]);
      exit;
    end;

  if Sender.UserSpecial = nil then
      exit;
  XUserSpec := TXServerUserSpecial(Sender.UserSpecial);
  if not XUserSpec.RemoteProtocol_Inited then
      exit;

  if ShareListen.FSendTunnel.Exists(XUserSpec.s_id) then
    begin
      s_io := ShareListen.FSendTunnel.PeerIO[XUserSpec.s_id];
      de := TDFE.Create;
      de.WriteCardinal(Sender.ID);
      de.WriteCardinal(XUserSpec.RemoteProtocol_ID);
      s_io.SendStreamNotifyCmd(C_Disconnect_request, de);
      DisposeObject(de);
      s_io.Progress;
    end;
  inherited DoIODisconnect(Sender);
end;

procedure TPhysicsEngine_Special.PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);
begin
  if cState then
      Owner.BuildP2PAuthTokenM(PhysicsVMBuildAuthToken_Result)
  else
    begin
      FXNAT_VS.WaitAsyncConnecting := False;
      FXNAT_VS.Do_Open_Done(False);
    end;
end;

procedure TPhysicsEngine_Special.PhysicsVMBuildAuthToken_Result;
begin
  Owner.OpenP2pVMTunnelM(True, GenerateQuantumCryptographyPassword(FXNAT_VS.AuthToken), PhysicsOpenVM_Result)
end;

procedure TPhysicsEngine_Special.PhysicsOpenVM_Result(const cState: Boolean);
var
  i: Integer;
  shLt: TXServiceListen;
begin
  if cState then
    begin
      Owner.p2pVMTunnel.MaxVMFragmentSize := umlStrToInt(FXNAT_VS.MaxVMFragment, Owner.p2pVMTunnel.MaxVMFragmentSize);
      FXNAT_VS.FActivted := True;

      for i := 0 to FXNAT_VS.FShareListenList.Count - 1 do
        begin
          shLt := FXNAT_VS.FShareListenList[i];
          shLt.Open;

          Owner.p2pVMTunnel.InstallLogicFramework(shLt.FSendTunnel);
          Owner.p2pVMTunnel.InstallLogicFramework(shLt.FRecvTunnel);
        end;
    end;
  FXNAT_VS.WaitAsyncConnecting := False;
  FXNAT_VS.Do_Open_Done(cState);
end;

constructor TPhysicsEngine_Special.Create(Owner_: TPeerIO);
begin
  inherited Create(Owner_);
  FXNAT_VS := nil;
end;

destructor TPhysicsEngine_Special.Destroy;
begin
  inherited Destroy;
end;

procedure TXNATService.IPV6Listen(Sender: TPeerIO; InData, OutData: TDFE);
var
  i: Integer;
  shLt: TXServiceListen;
begin
  for i := 0 to FShareListenList.Count - 1 do
    begin
      shLt := FShareListenList[i];
      OutData.WriteString(shLt.FMapping);

      OutData.WriteString(shLt.FListenAddr);
      OutData.WriteString(shLt.FListenPort);

      OutData.WriteString(IPv6ToStr(shLt.FRecvTunnel_IPV6));
      OutData.WriteWORD(shLt.FRecvTunnel_Port);

      OutData.WriteString(IPv6ToStr(shLt.FSendTunnel_IPV6));
      OutData.WriteWORD(shLt.FSendTunnel_Port);
    end;
end;

procedure TXNATService.PeerIO_Create(const Sender: TPeerIO);
begin
  if FPhysicsEngine is TZNet_Server then
    begin
    end
  else if FPhysicsEngine is TZNet_Client then
    begin
      TPhysicsEngine_Special(Sender.UserSpecial).FXNAT_VS := Self;
    end;
end;

procedure TXNATService.PeerIO_Destroy(const Sender: TPeerIO);
begin
end;

procedure TXNATService.p2pVMTunnelAuth(Sender: TPeerIO; const Token: SystemString; var Accept: Boolean);
begin
  Accept := CompareQuantumCryptographyPassword(AuthToken, Token);
  if Accept then
      Sender.Print('p2pVM auth Successed!')
  else
      Sender.Print('p2pVM auth failed!');
end;

procedure TXNATService.p2pVMTunnelOpenBefore(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
var
  i: Integer;
  shLt: TXServiceListen;
begin
  if FPhysicsEngine is TZNet_Server then
    begin
      for i := FShareListenList.Count - 1 downto 0 do
        begin
          shLt := FShareListenList[i];
          Sender.p2pVM.MaxVMFragmentSize := umlStrToInt(MaxVMFragment, Sender.p2pVM.MaxVMFragmentSize);
          Sender.p2pVM.InstallLogicFramework(shLt.FRecvTunnel);
          Sender.p2pVM.InstallLogicFramework(shLt.FSendTunnel);
        end;
    end
  else if FPhysicsEngine is TZNet_Client then
    begin
    end;
  Sender.Print('XTunnel Open Before on %s', [Sender.PeerIP]);
end;

procedure TXNATService.p2pVMTunnelOpen(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
begin
  if FPhysicsEngine is TZNet_Server then
    begin
    end
  else if FPhysicsEngine is TZNet_Client then
    begin
    end;
  Sender.Print('XTunnel Open on %s', [Sender.PeerIP]);
end;

procedure TXNATService.p2pVMTunnelOpenAfter(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
begin
  if FPhysicsEngine is TZNet_Server then
    begin
    end
  else if FPhysicsEngine is TZNet_Client then
    begin
    end;
  Sender.Print('XTunnel Open After on %s', [Sender.PeerIP]);
end;

procedure TXNATService.p2pVMTunnelClose(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
var
  i: Integer;
  shLt: TXServiceListen;
begin
  if FPhysicsEngine is TZNet_Server then
    begin
      for i := FShareListenList.Count - 1 downto 0 do
        begin
          shLt := FShareListenList[i];
          Sender.p2pVM.UnInstallLogicFramework(shLt.FRecvTunnel);
          Sender.p2pVM.UnInstallLogicFramework(shLt.FSendTunnel);
        end;
    end
  else if FPhysicsEngine is TZNet_Client then
    begin
    end;
  Sender.Print('XTunnel Close on %s', [Sender.PeerIP]);
end;

procedure TXNATService.PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);
begin
  if FPhysicsEngine is TZNet_Server then
    begin
    end
  else if FPhysicsEngine is TZNet_Client then
    begin
      if cState then
        begin
          if TZNet_Client(FPhysicsEngine).ClientIO <> nil then
              TPhysicsEngine_Special(TZNet_Client(FPhysicsEngine).ClientIO.UserSpecial).PhysicsConnect_Result_BuildP2PToken(cState);
        end
      else
        begin
          Do_Open_Done(False);
        end;
    end;
end;

procedure TXNATService.Do_Open_Done(State: Boolean);
begin
  if Assigned(On_Open_Tunnel_Done) then
    begin
      try
          On_Open_Tunnel_Done(Self, State);
      except
      end;
      On_Open_Tunnel_Done := nil;
    end;
  Open_Done := True;
end;

procedure TXNATService.Set_Quiet(const Value: Boolean);
var
  i: Integer;
  shLt: TXServiceListen;
begin
  FQuiet := Value;
  if FPhysicsEngine <> nil then
      Set_Instance_QuietMode(FPhysicsEngine, FQuiet);
  for i := FShareListenList.Count - 1 downto 0 do
    begin
      shLt := FShareListenList[i];
      if shLt.FRecvTunnel <> nil then
          Set_Instance_QuietMode(shLt.FRecvTunnel, FQuiet);
      if shLt.FSendTunnel <> nil then
          Set_Instance_QuietMode(shLt.FSendTunnel, FQuiet);
      if shLt.FProtocol <> nil then
          Set_Instance_QuietMode(shLt.FProtocol, FQuiet);
    end;
end;

constructor TXNATService.Create;
begin
  inherited Create;
  FShareListenList := TXServiceMappingList.Create;

  FPhysicsEngine := nil;
  FQuiet := False;
  FActivted := False;
  WaitAsyncConnecting := False;

  Host := '';
  Port := '4921';
  AuthToken := 'ZServer';
  MaxVMFragment := '8192';
  ProtocolCompressed := False;
  Instance_Class := TXServiceListen;
  On_Open_Tunnel_Done := nil;
  Open_Done := False;
end;

destructor TXNATService.Destroy;
var
  i: Integer;
begin
  for i := 0 to FShareListenList.Count - 1 do
      DisposeObject(FShareListenList[i]);
  DisposeObjectAndNil(FShareListenList);

  if FPhysicsEngine <> nil then
    begin
      if FPhysicsEngine is TZNet_Server then
          TZNet_Server(FPhysicsEngine).StopService
      else if FPhysicsEngine is TZNet_Client then
          TZNet_Client(FPhysicsEngine).Disconnect;
      DisposeObjectAndNil(FPhysicsEngine);
    end;

  inherited Destroy;
end;

procedure TXNATService.Reset;
var
  i: Integer;
begin
  FActivted := False;
  WaitAsyncConnecting := False;

  for i := 0 to FShareListenList.Count - 1 do
      DisposeObject(FShareListenList[i]);
  FShareListenList.Clear;

  if FPhysicsEngine <> nil then
    begin
      if FPhysicsEngine is TZNet_Server then
          TZNet_Server(FPhysicsEngine).StopService
      else if FPhysicsEngine is TZNet_Client then
          TZNet_Client(FPhysicsEngine).Disconnect;
      DisposeObjectAndNil(FPhysicsEngine);
    end;

  On_Open_Tunnel_Done := nil;
  Open_Done := False;
end;

function TXNATService.AddMapping(const ListenAddr, ListenPort, FMapping: TPascalString; TimeOut: TTimeTick): TXServiceListen;
var
  i: Integer;
  shLt: TXServiceListen;
begin
  for i := 0 to FShareListenList.Count - 1 do
    begin
      shLt := FShareListenList[i];
      if ListenAddr.Same(@shLt.FListenAddr) and ListenPort.Same(@shLt.FListenPort) then
        begin
          if not Quiet then
              DoStatus('warning: mapping at %s:%s already exists, reuse existing instance.',
              [ListenAddr.Text, ListenPort.Text]);
          exit(shLt);
        end;
    end;

  shLt := Instance_Class.Create(Self);
  shLt.FListenAddr := ListenAddr;
  shLt.FListenPort := ListenPort;
  shLt.FMapping := FMapping;
  shLt.DistributedWorkload := True;
  shLt.XServerTunnel := Self;
  shLt.TimeOut := TimeOut;

  if shLt.FRecvTunnel <> nil then
      Set_Instance_QuietMode(shLt.FRecvTunnel, FQuiet);
  if shLt.FSendTunnel <> nil then
      Set_Instance_QuietMode(shLt.FSendTunnel, FQuiet);
  if shLt.FProtocol <> nil then
      Set_Instance_QuietMode(shLt.FProtocol, FQuiet);

  FShareListenList.Add(shLt);

  if FActivted and (FPhysicsEngine is TZNet_Server) then
      shLt.Open;
  Result := shLt;
end;

function TXNATService.AddNoDistributedMapping(const ListenAddr, ListenPort, FMapping: TPascalString; TimeOut: TTimeTick): TXServiceListen;
var
  i: Integer;
  shLt: TXServiceListen;
begin
  for i := 0 to FShareListenList.Count - 1 do
    begin
      shLt := FShareListenList[i];
      if ListenAddr.Same(@shLt.FListenAddr) and ListenPort.Same(@shLt.FListenPort) then
        begin
          if not Quiet then
              DoStatus('warning: mapping at %s:%s already exists, reuse existing instance.',
              [ListenAddr.Text, ListenPort.Text]);
          exit(shLt);
        end;
    end;

  shLt := Instance_Class.Create(Self);
  shLt.FListenAddr := ListenAddr;
  shLt.FListenPort := ListenPort;
  shLt.FMapping := FMapping;
  shLt.DistributedWorkload := False;
  shLt.XServerTunnel := Self;
  shLt.TimeOut := TimeOut;

  if shLt.FRecvTunnel <> nil then
      Set_Instance_QuietMode(shLt.FRecvTunnel, FQuiet);
  if shLt.FSendTunnel <> nil then
      Set_Instance_QuietMode(shLt.FSendTunnel, FQuiet);
  if shLt.FProtocol <> nil then
      Set_Instance_QuietMode(shLt.FProtocol, FQuiet);

  FShareListenList.Add(shLt);

  if FActivted and (FPhysicsEngine is TZNet_Server) then
      shLt.Open;
  Result := shLt;
end;

procedure TXNATService.OpenTunnel(MODEL: TXNAT_PHYSICS_MODEL);
var
  i: Integer;
  shLt: TXServiceListen;
  listening_: Boolean;
begin
  FActivted := True;
  Open_Done := False;

  if FPhysicsEngine = nil then
    begin
      if MODEL = TXNAT_PHYSICS_MODEL.XNAT_PHYSICS_SERVICE then
          FPhysicsEngine := TXPhysicsServer.Create
      else
          FPhysicsEngine := TXPhysicsClient.Create;
    end;

  FPhysicsEngine.UserSpecialClass := TPhysicsEngine_Special;
  FPhysicsEngine.IOInterface := Self;
  FPhysicsEngine.VMInterface := Self;

  Set_Instance_QuietMode(FPhysicsEngine, FQuiet);

  FPhysicsEngine.SwitchMaxPerformance;

  if not FPhysicsEngine.ExistsRegistedCmd(C_IPV6Listen) then
      FPhysicsEngine.RegisterStream(C_IPV6Listen).OnExecute := IPV6Listen;

  if FPhysicsEngine is TZNet_Server then
    begin
      listening_ := TZNet_Server(FPhysicsEngine).StartService(Host, umlStrToInt(Port));
      if listening_ then
          FPhysicsEngine.Print('Tunnel Open %s:%s successed', [TranslateBindAddr(Host), Port.Text])
      else
          FPhysicsEngine.Print('error: Tunnel is Closed for %s:%s', [TranslateBindAddr(Host), Port.Text]);

      for i := 0 to FShareListenList.Count - 1 do
        begin
          shLt := FShareListenList[i];
          shLt.Open;
          if shLt.FRecvTunnel <> nil then
              Set_Instance_QuietMode(shLt.FRecvTunnel, FQuiet);
          if shLt.FSendTunnel <> nil then
              Set_Instance_QuietMode(shLt.FSendTunnel, FQuiet);
          if shLt.FProtocol <> nil then
              Set_Instance_QuietMode(shLt.FProtocol, FQuiet);
        end;
      Do_Open_Done(listening_);
    end
  else if FPhysicsEngine is TZNet_Client then
    begin
      if not TZNet_Client(FPhysicsEngine).Connected then
        begin
          WaitAsyncConnecting := True;
          WaitAsyncConnecting_BeginTime := GetTimeTick;
          TZNet_Client(FPhysicsEngine).AsyncConnectM(Host, umlStrToInt(Port), PhysicsConnect_Result_BuildP2PToken);
        end;
    end;
end;

procedure TXNATService.OpenTunnel;
begin
  OpenTunnel(TXNAT_PHYSICS_MODEL.XNAT_PHYSICS_SERVICE);
end;

procedure TXNATService.Progress;
var
  i: Integer;
  shLt: TXServiceListen;
begin
  if (FPhysicsEngine <> nil) then
    begin
      if (FPhysicsEngine is TZNet_Client) then
        begin
          if WaitAsyncConnecting and (GetTimeTick - WaitAsyncConnecting_BeginTime > 15000) then
              WaitAsyncConnecting := False;

          if FActivted and (not TZNet_Client(FPhysicsEngine).Connected) then
            begin
              if not WaitAsyncConnecting then
                  OpenTunnel(TXNAT_PHYSICS_MODEL.XNAT_PHYSICS_CLIENT);
            end;
        end;
      FPhysicsEngine.Progress;
    end;

  for i := FShareListenList.Count - 1 downto 0 do
    begin
      shLt := FShareListenList[i];
      if (shLt.FRecvTunnel <> nil) and (shLt.FSendTunnel <> nil) then
        begin
          if (shLt.FRecvTunnel.Count = 0) and (shLt.FSendTunnel.Count = 0) and (shLt.Activted) then
              shLt.Activted := False;

          shLt.FRecvTunnel.Progress;
          shLt.FSendTunnel.Progress;
          { BUGFIX: guard against nil FProtocol. }
          if shLt.FProtocol <> nil then
              shLt.FProtocol.Progress;
        end;
    end;
end;

end.
 
