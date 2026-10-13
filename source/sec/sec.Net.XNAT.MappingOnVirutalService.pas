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
  * XNAT Virtual Service - Server-Side Mapping Abstraction
  * This unit provides a higher-level server-side API where each mapping is
  * represented as an independent virtual server (TXNAT_MappingOnVirutalService)
  * that behaves like a standard TZNet_Server.
  *
  * BUGFIX (2026):
  *   - Introduced FRemoteID_Hash in TXNAT_MappingOnVirutalService to map
  *     the remote physics IO ID (assigned by the XNAT service) to the local
  *     virtual IO. Without this map, cmd_data and cmd_disconnect_request
  *     could not locate the correct virtual IO because the PeerIO pool is
  *     indexed by the virtual IO ID, not by the remote physics IO ID.
  *   - AddMappingService now detects duplicate mapping names and reuses
  *     the existing instance instead of raising an exception from
  *     HashMapping.Add.
  *   - TXNAT_VS_Mapping.Destroy now clears HashMapping before disposing
  *     the mapping list, so no dangling pointer can be observed.
  *   - TXNAT_MappingOnVirutalService_IO.Destroy now unregisters itself
  *     from FRemoteID_Hash.
  ****************************************************************************** }
unit sec.Net.XNAT.MappingOnVirutalService;

{$DEFINE FPC_DELPHI_MODE}
{$I ..\Z.Define.inc}

interface

uses
{$IFDEF FPC}
  sec.FPC.GenericList,
{$ENDIF FPC}
  sec.Core, sec.PascalStrings, sec.UPascalStrings, sec.Status, sec.UnicodeMixedLib, sec.ListEngine, sec.TextDataEngine,
  sec.Cipher, sec.DFE, sec.MemoryStream, sec.Net, sec.Notify,
  sec.HashList.Templet, sec.Net.XNAT.Physics;

type
  TXNAT_VS_Mapping = class;
  TXNAT_MappingOnVirutalService = class;

  { Special TPeerIO subclass used by TXNAT_MappingOnVirutalService to represent an incoming client connection. }
  TXNAT_MappingOnVirutalService_IO = class(TPeerIO)
  protected
    FRemote_ID: Cardinal; { Remote protocol ID assigned by the XNAT client. }
    FRemote_IP: SystemString; { IP address of the remote client. }
    FSendingStream: TMS64; { Internal buffer for outgoing data. }
  public
    procedure CreateAfter; override;
    destructor Destroy; override;

    function OwnerVS: TXNAT_MappingOnVirutalService;

    function Connected: Boolean; override;
    procedure Disconnect; override;
    procedure Write_IO_Buffer(const buff: PByte; const Size: nativeInt); override;
    procedure WriteBufferOpen; override;
    procedure WriteBufferFlush; override;
    procedure WriteBufferClose; override;
    function GetPeerIP: SystemString; override;
    function WriteBuffer_is_NULL: Boolean; override;
    procedure Progress; override;
  end;

  { A virtual service mapped to a remote XNAT service. }
  TXNAT_MappingOnVirutalService = class(TZNet_Server)
  private
    FOwner: TXNAT_VS_Mapping;
    FMapping: TPascalString;

    FRecvTunnel: TZNet_WithP2PVM_Client;
    FRecvTunnel_IPV6: TPascalString;
    FRecvTunnel_Port: Word;

    FSendTunnel: TZNet_WithP2PVM_Client;
    FSendTunnel_IPV6: TPascalString;
    FSendTunnel_Port: Word;

    FMaxWorkload: Cardinal;
    FLastUpdateWorkload: Cardinal;
    FLastUpdateTime: TTimeTick;
    FRemote_ListenAddr, FRemote_ListenPort: TPascalString;
    FXNAT_VS: TXNAT_VS_Mapping;

    { FIX: map from remote physics IO ID (assigned by the XNAT service)
      to the local virtual IO. Used by cmd_data and cmd_disconnect_request. }
    FRemoteID_Hash: TUInt32HashObjectList;

    procedure Init;
    procedure SendTunnel_ConnectResult(const cState: Boolean);
    procedure RecvTunnel_ConnectResult(const cState: Boolean);

    procedure RequestListen_Result(Sender: TPeerIO; Result_: TDFE);
    procedure delay_RequestListen(Sender: TN_Post_Execute);

    procedure Open;

    procedure cmd_connect_request(Sender: TPeerIO; InData: TDFE);
    procedure cmd_disconnect_request(Sender: TPeerIO; InData: TDFE);
    procedure cmd_data(Sender: TPeerIO; InData: PByte; DataSize: nativeInt);

  public
    constructor Create(Owner_: TXNAT_VS_Mapping); virtual;
    destructor Destroy; override;

    property XNAT_VS: TXNAT_VS_Mapping read FXNAT_VS;

    procedure UpdateWorkload(force: Boolean); virtual;

    function StartService(Host: SystemString; Port: Word): Boolean; override;
    procedure StopService; override;
    procedure Progress; override;
    function WaitSendConsoleCmd(p_io: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; override;
    procedure WaitSendStreamCmd(p_io: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); override;
  end;

  TXNAT_MappingOnVirutalService_Class = class of TXNAT_MappingOnVirutalService;

  TPhysicsEngine_Special = class(TPeer_IO_User_Special)
  protected
    FXNAT_VS: TXNAT_VS_Mapping;
    procedure PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);
    procedure PhysicsVMBuildAuthToken_Result;
    procedure PhysicsOpenVM_Result(const cState: Boolean);
    procedure IPV6Listen_Result(Sender: TPeerIO; Result_: TDFE);
  public
    constructor Create(Owner_: TPeerIO); override;
    destructor Destroy; override;
  end;

  TXVirutalServiceMappingList = TGenericsList<TXNAT_MappingOnVirutalService>;
  TXVirutalServiceHashMapping = TGeneric_String_Object_Hash<TXNAT_MappingOnVirutalService>;
  TXNAT_VS_Mapping_List_Decl = TGenericsList<TXNAT_VS_Mapping>;
  TOn_VS_Ready = procedure(Sender: TXNAT_VS_Mapping; vs: TXNAT_MappingOnVirutalService; state: Boolean; info: SystemString) of object;

  { Main manager for virtual services. }
  TXNAT_VS_Mapping = class(TCore_InterfacedObject_Intermediate, IIOInterface, IZNet_VMInterface)
  private
    MappingList: TXVirutalServiceMappingList;
    HashMapping: TXVirutalServiceHashMapping;
    Activted: Boolean;
    WaitAsyncConnecting: Boolean;
    WaitAsyncConnecting_BeginTime: TTimeTick;
    PhysicsEngine: TZNet;
    FQuiet: Boolean;
    Progressing: Boolean;

    procedure PeerIO_Create(const Sender: TPeerIO);
    procedure PeerIO_Destroy(const Sender: TPeerIO);

    procedure p2pVMTunnelAuth(Sender: TPeerIO; const Token: SystemString; var Accept: Boolean);
    procedure p2pVMTunnelOpenBefore(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelOpen(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelOpenAfter(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
    procedure p2pVMTunnelClose(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);

    procedure PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);

    procedure Set_Quiet(const Value: Boolean);

    procedure Do_VS_State(vs: TXNAT_MappingOnVirutalService; state: Boolean; info: SystemString);

  public
    Host: TPascalString;
    Port: TPascalString;
    AuthToken: TPascalString;
    MaxVMFragment: TPascalString;

    ProtocolCompressed: Boolean;

    Instance_Class: TXNAT_MappingOnVirutalService_Class;
    On_VS_Ready: TOn_VS_Ready;

    property Quiet: Boolean read FQuiet write Set_Quiet;

    constructor Create;
    destructor Destroy; override;

    function AddMappingService(const FMapping: TPascalString; FMaxWorkload: Cardinal): TXNAT_MappingOnVirutalService;
    function AddMappingServer(const FMapping: TPascalString; FMaxWorkload: Cardinal): TXNAT_MappingOnVirutalService;

    procedure OpenTunnel(MODEL: TXNAT_PHYSICS_MODEL); overload;
    procedure OpenTunnel; overload;

    procedure Progress;

    function GetCount: Integer;
    property Count: Integer read GetCount;
    function GetServices(const index: Integer): TXNAT_MappingOnVirutalService;
    property Services[const index: Integer]: TXNAT_MappingOnVirutalService read GetServices; default;
    function GetServicesOnMapping(const FMapping: SystemString): TXNAT_MappingOnVirutalService;
    property ServicesOnMapping[const FMapping: SystemString]: TXNAT_MappingOnVirutalService read GetServicesOnMapping;
  end;

implementation

procedure TXNAT_MappingOnVirutalService_IO.CreateAfter;
begin
  inherited CreateAfter;
  FSendingStream := TMS64.Create;
  FSendingStream.Delta := 2048;
  FRemote_ID := 0;
  FRemote_IP := '';
end;

destructor TXNAT_MappingOnVirutalService_IO.Destroy;
var
  vs: TXNAT_MappingOnVirutalService;
begin
  { BUGFIX: unregister from FRemoteID_Hash before destroying. }
  vs := OwnerVS;
  if vs <> nil then
      vs.FRemoteID_Hash.Delete(FRemote_ID);
  DisposeObject(FSendingStream);
  inherited Destroy;
end;

function TXNAT_MappingOnVirutalService_IO.OwnerVS: TXNAT_MappingOnVirutalService;
begin
  Result := OwnerFramework as TXNAT_MappingOnVirutalService;
end;

function TXNAT_MappingOnVirutalService_IO.Connected: Boolean;
begin
  Result := True;
end;

procedure TXNAT_MappingOnVirutalService_IO.Disconnect;
var
  de: TDFE;
begin
  de := TDFE.Create;
  de.WriteCardinal(ID);
  de.WriteCardinal(FRemote_ID);
  OwnerVS.FSendTunnel.SendStreamNotifyCmd(C_Disconnect_reponse, de);
  DisposeObject(de);
  DelayFree(5.0);
end;

procedure TXNAT_MappingOnVirutalService_IO.Write_IO_Buffer(const buff: PByte; const Size: nativeInt);
begin
  FSendingStream.WritePtr(buff, Size);
end;

procedure TXNAT_MappingOnVirutalService_IO.WriteBufferOpen;
begin
  FSendingStream.Clear;
end;

procedure TXNAT_MappingOnVirutalService_IO.WriteBufferFlush;
var
  nSiz: nativeInt;
  nBuff: PByte;
begin
  if FSendingStream.Size > 0 then
    begin
      Build_XNAT_Buff(FSendingStream.Memory, FSendingStream.Size, ID, FRemote_ID, nSiz, nBuff);
      OwnerVS.FSendTunnel.SendCompleteBuffer(C_Data, nBuff, nSiz, True);
      FSendingStream.Clear;
    end;
end;

procedure TXNAT_MappingOnVirutalService_IO.WriteBufferClose;
begin
  WriteBufferFlush;
end;

function TXNAT_MappingOnVirutalService_IO.GetPeerIP: SystemString;
begin
  Result := FRemote_IP;
end;

function TXNAT_MappingOnVirutalService_IO.WriteBuffer_is_NULL: Boolean;
begin
  Result := True;
end;

procedure TXNAT_MappingOnVirutalService_IO.Progress;
begin
  inherited Progress;
  Process_Send_Buffer();
end;

procedure TXNAT_MappingOnVirutalService.Init;
begin
  FMapping := '';
  FRecvTunnel := nil;
  FRecvTunnel_IPV6 := '';
  FRecvTunnel_Port := 0;
  FSendTunnel := nil;
  FSendTunnel_IPV6 := '';
  FSendTunnel_Port := 0;

  FMaxWorkload := 100;
  FLastUpdateWorkload := 0;
  FLastUpdateTime := GetTimeTick();

  FRemote_ListenAddr := '';
  FRemote_ListenPort := '0';
  FXNAT_VS := nil;

  { BUGFIX: create the mapping from remote physics IO ID to local virtual IO. }
  FRemoteID_Hash := TUInt32HashObjectList.Create;
end;

procedure TXNAT_MappingOnVirutalService.SendTunnel_ConnectResult(const cState: Boolean);
begin
  if cState then
    begin
      FSendTunnel.Print('[%s] Send Tunnel connect success.', [FMapping.Text]);
      if not FRecvTunnel.Connected then
          FRecvTunnel.AsyncConnectM(FRecvTunnel_IPV6, FRecvTunnel_Port, RecvTunnel_ConnectResult)
      else
          RecvTunnel_ConnectResult(True);
    end
  else
    begin
      FSendTunnel.Print('error: [%s] Send Tunnel connect failed!', [FMapping.Text]);
      FOwner.Do_VS_State(self, cState, PFormat('error: [%s] Send Tunnel connect failed!', [FMapping.Text]));
    end;
end;

procedure TXNAT_MappingOnVirutalService.RecvTunnel_ConnectResult(const cState: Boolean);
begin
  if cState then
    begin
      FRecvTunnel.Print('[%s] Receive Tunnel connect success.', [FMapping.Text]);
      FSendTunnel.ProgressPost.PostExecuteM(0, delay_RequestListen);
    end
  else
    begin
      FRecvTunnel.Print('error: [%s] Receive Tunnel connect failed!', [FMapping.Text]);
      FOwner.Do_VS_State(self, cState, PFormat('error: [%s] Receive Tunnel connect failed!', [FMapping.Text]));
    end;
end;

procedure TXNAT_MappingOnVirutalService.RequestListen_Result(Sender: TPeerIO; Result_: TDFE);
begin
  if Result_.Reader.ReadBool then
    begin
      FSendTunnel.Print('success: remote host:%s port:%s mapping to local Service', [FXNAT_VS.Host.Text, FRemote_ListenPort.Text]);
      UpdateWorkload(True);
      FOwner.Do_VS_State(self, True, PFormat('success: remote host:%s port:%s mapping to local Service', [FXNAT_VS.Host.Text, FRemote_ListenPort.Text]));
    end
  else
    begin
      FSendTunnel.Print('failed: remote host:%s port:%s listen error!', [FXNAT_VS.Host.Text, FRemote_ListenPort.Text]);
      FOwner.Do_VS_State(self, False, PFormat('failed: remote host:%s port:%s listen error!', [FXNAT_VS.Host.Text, FRemote_ListenPort.Text]));
    end;
end;

procedure TXNAT_MappingOnVirutalService.delay_RequestListen(Sender: TN_Post_Execute);
var
  de: TDFE;
begin
  de := TDFE.Create;
  de.WriteCardinal(FSendTunnel.RemoteID);
  de.WriteCardinal(FRecvTunnel.RemoteID);
  FSendTunnel.SendStreamCmdM(C_RequestListen, de, RequestListen_Result);
  DisposeObject(de);
end;

procedure TXNAT_MappingOnVirutalService.Open;
var
  io_array: TIO_Array;
  p_id: Cardinal;
  p_io: TPeerIO;
begin
  if FRecvTunnel = nil then
    begin
      FRecvTunnel := TZNet_WithP2PVM_Client.Create;
      FRecvTunnel.QuietMode := FOwner.Quiet;
      FRecvTunnel.SyncOnCompleteBuffer := True;
      FRecvTunnel.SyncOnResult := True;
      FRecvTunnel.SwitchMaxPerformance;
      FRecvTunnel.CompleteBufferCompressed := FXNAT_VS.ProtocolCompressed;
      FRecvTunnel.CompleteBufferSwapSpace := True;
      if not FRecvTunnel.ExistsRegistedCmd(C_Connect_request) then
          FRecvTunnel.RegisterStreamNotify(C_Connect_request).OnExecute := cmd_connect_request;
      if not FRecvTunnel.ExistsRegistedCmd(C_Disconnect_request) then
          FRecvTunnel.RegisterStreamNotify(C_Disconnect_request).OnExecute := cmd_disconnect_request;
      if not FRecvTunnel.ExistsRegistedCmd(C_Data) then
          FRecvTunnel.RegisterCompleteBuffer(C_Data).OnExecute := cmd_data;
      FRecvTunnel.PrintParams[C_Connect_request] := False;
      FRecvTunnel.PrintParams[C_Disconnect_request] := False;
      FRecvTunnel.PrintParams[C_Data] := False;
    end;
  if FSendTunnel = nil then
    begin
      FSendTunnel := TZNet_WithP2PVM_Client.Create;
      FSendTunnel.QuietMode := FOwner.Quiet;
      FSendTunnel.SyncOnCompleteBuffer := True;
      FSendTunnel.SyncOnResult := True;
      FSendTunnel.SwitchMaxPerformance;
      FSendTunnel.CompleteBufferCompressed := FXNAT_VS.ProtocolCompressed;
      FSendTunnel.CompleteBufferSwapSpace := True;
      FSendTunnel.PrintParams[C_Connect_reponse] := False;
      FSendTunnel.PrintParams[C_Disconnect_reponse] := False;
      FSendTunnel.PrintParams[C_Data] := False;
      FSendTunnel.PrintParams[C_Workload] := False;
    end;

  FXNAT_VS.PhysicsEngine.GetIO_Array(io_array);
  for p_id in io_array do
    begin
      p_io := TPeerIO(FXNAT_VS.PhysicsEngine.PeerIO_HashPool[p_id]);
      if p_io <> nil then
        begin
          p_io.p2pVMTunnel.UninstallLogicFramework(FSendTunnel);
          p_io.p2pVMTunnel.UninstallLogicFramework(FRecvTunnel);

          p_io.p2pVMTunnel.InstallLogicFramework(FSendTunnel);
          p_io.p2pVMTunnel.InstallLogicFramework(FRecvTunnel);
        end;
    end;
  SetLength(io_array, 0);

  if not FSendTunnel.Connected then
      FSendTunnel.AsyncConnectM(FSendTunnel_IPV6, FSendTunnel_Port, SendTunnel_ConnectResult)
  else
      SendTunnel_ConnectResult(True);
end;

procedure TXNAT_MappingOnVirutalService.cmd_connect_request(Sender: TPeerIO; InData: TDFE);
var
  Remote_ID: Cardinal;
  x_io: TXNAT_MappingOnVirutalService_IO;
  de: TDFE;
begin
  Remote_ID := InData.Reader.ReadCardinal;
  x_io := TXNAT_MappingOnVirutalService_IO.Create(self, FXNAT_VS);
  x_io.FRemote_ID := Remote_ID;
  x_io.FRemote_IP := InData.Reader.ReadString;

  { BUGFIX: register the mapping from remote physics IO ID to the local virtual IO
    so that later cmd_data / cmd_disconnect_request can find it. }
  if FRemoteID_Hash.Exists(Remote_ID) then
      FRemoteID_Hash.Delete(Remote_ID);
  FRemoteID_Hash.Add(Remote_ID, x_io, True);

  de := TDFE.Create;
  de.WriteBool(True);
  de.WriteCardinal(x_io.ID);
  de.WriteCardinal(x_io.FRemote_ID);
  FSendTunnel.SendStreamNotifyCmd(C_Connect_reponse, de);
  DisposeObject(de);
end;

procedure TXNAT_MappingOnVirutalService.cmd_disconnect_request(Sender: TPeerIO; InData: TDFE);
var
  local_id, Remote_ID: Cardinal;
  p_io: TPeerIO;
begin
  Remote_ID := InData.Reader.ReadCardinal;
  local_id := InData.Reader.ReadCardinal;

  { BUGFIX: look up the virtual IO by remote physics IO ID, not by the
    remote client's local protocol ID. }
  p_io := TPeerIO(FRemoteID_Hash[Remote_ID]);
  if p_io <> nil then
      DisposeObject(p_io);
end;

procedure TXNAT_MappingOnVirutalService.cmd_data(Sender: TPeerIO; InData: PByte; DataSize: nativeInt);
var
  local_id, Remote_ID: Cardinal;
  destSiz: nativeInt;
  destBuff: PByte;
  x_io: TXNAT_MappingOnVirutalService_IO;
begin
  Extract_XNAT_Buff(InData, DataSize, local_id, Remote_ID, destSiz, destBuff);
  if destBuff = nil then
      exit;

  { BUGFIX: look up the virtual IO by remote physics IO ID (first cardinal). }
  x_io := TXNAT_MappingOnVirutalService_IO(FRemoteID_Hash[local_id]);
  if x_io <> nil then
      x_io.Write_Physics_Fragment(destBuff, destSiz);
end;

constructor TXNAT_MappingOnVirutalService.Create(Owner_: TXNAT_VS_Mapping);
begin
  inherited Create;
  FOwner := Owner_;
  Init;
end;

destructor TXNAT_MappingOnVirutalService.Destroy;
begin
  if FSendTunnel <> nil then
    begin
      FSendTunnel.Disconnect;
      DisposeObject(FSendTunnel);
    end;

  if FRecvTunnel <> nil then
    begin
      FRecvTunnel.Disconnect;
      DisposeObject(FRecvTunnel);
    end;

  { BUGFIX: release the remote ID map. }
  if FRemoteID_Hash <> nil then
      DisposeObject(FRemoteID_Hash);

  inherited Destroy;
end;

procedure TXNAT_MappingOnVirutalService.UpdateWorkload(force: Boolean);
var
  de: TDFE;
begin
  if FSendTunnel = nil then
      exit;
  if FRecvTunnel = nil then
      exit;
  if not FSendTunnel.Connected then
      exit;
  if (not force) then
    if (Count = FLastUpdateWorkload) or (GetTimeTick() - FLastUpdateTime < 1000) then
        exit;

  de := TDFE.Create;
  de.WriteCardinal(FMaxWorkload);
  de.WriteCardinal(Count);
  FSendTunnel.SendStreamNotifyCmd(C_Workload, de);
  DisposeObject(de);

  FLastUpdateWorkload := Count;
  FLastUpdateTime := GetTimeTick();
end;

function TXNAT_MappingOnVirutalService.StartService(Host: SystemString; Port: Word): Boolean;
begin
  Result := True;
end;

procedure TXNAT_MappingOnVirutalService.StopService;
begin
end;

procedure TXNAT_MappingOnVirutalService.Progress;
begin
  if (FXNAT_VS <> nil) and (not FXNAT_VS.Progressing) then
    begin
      FXNAT_VS.Progress;
      exit;
    end;

  inherited Progress;

  if FSendTunnel <> nil then
      FSendTunnel.Progress;
  if FRecvTunnel <> nil then
      FRecvTunnel.Progress;
end;

function TXNAT_MappingOnVirutalService.WaitSendConsoleCmd(p_io: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;
begin
  Result := '';
  RaiseInfo('WaitSend no Suppport');
end;

procedure TXNAT_MappingOnVirutalService.WaitSendStreamCmd(p_io: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);
begin
  RaiseInfo('WaitSend no Suppport');
end;

procedure TPhysicsEngine_Special.PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);
begin
  if cState then
      Owner.BuildP2PAuthTokenM(PhysicsVMBuildAuthToken_Result)
  else
      FXNAT_VS.WaitAsyncConnecting := False;
end;

procedure TPhysicsEngine_Special.PhysicsVMBuildAuthToken_Result;
begin
  Owner.OpenP2pVMTunnelM(True, GenerateQuantumCryptographyPassword(FXNAT_VS.AuthToken), PhysicsOpenVM_Result)
end;

procedure TPhysicsEngine_Special.PhysicsOpenVM_Result(const cState: Boolean);
begin
  if cState then
    begin
      Owner.p2pVMTunnel.MaxVMFragmentSize := umlStrToInt(FXNAT_VS.MaxVMFragment, Owner.p2pVMTunnel.MaxVMFragmentSize);
      Owner.SendStreamCmdM(C_IPV6Listen, nil, IPV6Listen_Result);
    end
  else
      FXNAT_VS.WaitAsyncConnecting := False;
end;

procedure TPhysicsEngine_Special.IPV6Listen_Result(Sender: TPeerIO; Result_: TDFE);
var
  FMapping: TPascalString;
  FRemote_ListenAddr, FRemote_ListenPort: TPascalString;
  FRecvTunnel_IPV6: TPascalString;
  FRecvTunnel_Port: Word;
  FSendTunnel_IPV6: TPascalString;
  FSendTunnel_Port: Word;
  tunMp: TXNAT_MappingOnVirutalService;
begin
  while Result_.Reader.NotEnd do
    begin
      FMapping := Result_.Reader.ReadString;
      FRemote_ListenAddr := Result_.Reader.ReadString;
      FRemote_ListenPort := Result_.Reader.ReadString;
      FSendTunnel_IPV6 := Result_.Reader.ReadString;
      FSendTunnel_Port := Result_.Reader.ReadWord;
      FRecvTunnel_IPV6 := Result_.Reader.ReadString;
      FRecvTunnel_Port := Result_.Reader.ReadWord;
      tunMp := FXNAT_VS.HashMapping[FMapping];
      if tunMp <> nil then
        begin
          tunMp.FRecvTunnel_IPV6 := FRecvTunnel_IPV6;
          tunMp.FRecvTunnel_Port := FRecvTunnel_Port;
          tunMp.FSendTunnel_IPV6 := FSendTunnel_IPV6;
          tunMp.FSendTunnel_Port := FSendTunnel_Port;
          tunMp.FRemote_ListenAddr := FRemote_ListenAddr;
          tunMp.FRemote_ListenPort := FRemote_ListenPort;
          tunMp.Open;
        end;
    end;
  FXNAT_VS.Activted := True;
  FXNAT_VS.WaitAsyncConnecting := False;
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

procedure TXNAT_VS_Mapping.PeerIO_Create(const Sender: TPeerIO);
begin
  TPhysicsEngine_Special(Sender.UserSpecial).FXNAT_VS := self;
end;

procedure TXNAT_VS_Mapping.PeerIO_Destroy(const Sender: TPeerIO);
begin
end;

procedure TXNAT_VS_Mapping.p2pVMTunnelAuth(Sender: TPeerIO; const Token: SystemString; var Accept: Boolean);
begin
  Accept := CompareQuantumCryptographyPassword(AuthToken, Token);
  if Accept then
      Sender.Print('p2pVM auth Successed!')
  else
      Sender.Print('p2pVM auth failed!');
end;

procedure TXNAT_VS_Mapping.p2pVMTunnelOpenBefore(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
begin
  Sender.Print('XTunnel Open Before on %s', [Sender.PeerIP]);
end;

procedure TXNAT_VS_Mapping.p2pVMTunnelOpen(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
begin
  Sender.Print('XTunnel Open on %s', [Sender.PeerIP]);
end;

procedure TXNAT_VS_Mapping.p2pVMTunnelOpenAfter(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
begin
  if PhysicsEngine is TZNet_Server then
      Sender.SendStreamCmdM(C_IPV6Listen, nil, TPhysicsEngine_Special(Sender.UserSpecial).IPV6Listen_Result);
  Sender.Print('XTunnel Open After on %s', [Sender.PeerIP]);
end;

procedure TXNAT_VS_Mapping.p2pVMTunnelClose(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
begin
  Sender.Print('XTunnel Close on %s', [Sender.PeerIP]);
end;

procedure TXNAT_VS_Mapping.PhysicsConnect_Result_BuildP2PToken(const cState: Boolean);
begin
  TPhysicsEngine_Special(TZNet_Client(PhysicsEngine).ClientIO.UserSpecial).PhysicsConnect_Result_BuildP2PToken(cState);
end;

procedure TXNAT_VS_Mapping.Set_Quiet(const Value: Boolean);
var
  i: Integer;
  tunMp: TXNAT_MappingOnVirutalService;
begin
  FQuiet := Value;
  i := 0;
  while i < MappingList.Count do
    begin
      tunMp := MappingList[i];
      if tunMp.FRecvTunnel <> nil then
          Set_Instance_QuietMode(tunMp.FRecvTunnel, FQuiet);

      if tunMp.FSendTunnel <> nil then
          Set_Instance_QuietMode(tunMp.FSendTunnel, FQuiet);
      inc(i);
    end;
end;

procedure TXNAT_VS_Mapping.Do_VS_State(vs: TXNAT_MappingOnVirutalService; state: Boolean; info: SystemString);
begin
  if Assigned(On_VS_Ready) then
    begin
      On_VS_Ready(self, vs, state, info);
      On_VS_Ready := nil;
    end;
end;

constructor TXNAT_VS_Mapping.Create;
begin
  inherited Create;
  Host := '';
  Port := '4921';
  AuthToken := '';
  MaxVMFragment := '8192';
  ProtocolCompressed := False;
  MappingList := TXVirutalServiceMappingList.Create;
  HashMapping := TXVirutalServiceHashMapping.Create(False, 64, nil);
  Activted := False;
  WaitAsyncConnecting := False;
  PhysicsEngine := nil;
  Instance_Class := TXNAT_MappingOnVirutalService;
  On_VS_Ready := nil;
  FQuiet := False;
  Progressing := False;
end;

destructor TXNAT_VS_Mapping.Destroy;
var
  i: Integer;
begin
  { BUGFIX: clear hash map first to avoid dangling references during teardown. }
  if HashMapping <> nil then
      HashMapping.Clear;

  for i := MappingList.Count - 1 downto 0 do
      DisposeObject(MappingList[i]);
  DisposeObject(MappingList);
  DisposeObject(HashMapping);

  if PhysicsEngine <> nil then
    begin
      if PhysicsEngine is TZNet_Client then
          TZNet_Client(PhysicsEngine).Disconnect;
    end;

  DisposeObject(PhysicsEngine);
  inherited Destroy;
end;

function TXNAT_VS_Mapping.AddMappingService(const FMapping: TPascalString; FMaxWorkload: Cardinal): TXNAT_MappingOnVirutalService;
begin
  { BUGFIX: detect duplicate mapping name and reuse the existing instance. }
  if HashMapping.Exists(FMapping) then
    begin
      Result := HashMapping[FMapping];
      if not Quiet then
          DoStatus('warning: mapping "%s" already exists, reuse existing instance.', [FMapping.Text]);
      exit;
    end;

  Result := Instance_Class.Create(self);
  Result.FMapping := FMapping;
  Result.FMaxWorkload := FMaxWorkload;
  Result.FXNAT_VS := self;
  MappingList.Add(Result);
  HashMapping.Add(Result.FMapping, Result);
end;

function TXNAT_VS_Mapping.AddMappingServer(const FMapping: TPascalString; FMaxWorkload: Cardinal): TXNAT_MappingOnVirutalService;
begin
  Result := AddMappingService(FMapping, FMaxWorkload);
end;

procedure TXNAT_VS_Mapping.OpenTunnel(MODEL: TXNAT_PHYSICS_MODEL);
begin
  Activted := True;

  if PhysicsEngine = nil then
    begin
      if MODEL = TXNAT_PHYSICS_MODEL.XNAT_PHYSICS_SERVICE then
          PhysicsEngine := TXPhysicsServer.Create
      else
          PhysicsEngine := TXPhysicsClient.Create;
      PhysicsEngine.QuietMode := Quiet;
    end;

  PhysicsEngine.UserSpecialClass := TPhysicsEngine_Special;
  PhysicsEngine.IOInterface := self;
  PhysicsEngine.VMInterface := self;

  PhysicsEngine.SwitchMaxSecurity;

  if PhysicsEngine is TZNet_Server then
    begin
      if TZNet_Server(PhysicsEngine).StartService(Host, umlStrToInt(Port)) then
          PhysicsEngine.Print('Tunnel Open %s:%s successed', [TranslateBindAddr(Host), Port.Text])
      else
          PhysicsEngine.Print('error: Tunnel is Closed for %s:%s', [TranslateBindAddr(Host), Port.Text]);
    end
  else if PhysicsEngine is TZNet_Client then
    begin
      if not TZNet_Client(PhysicsEngine).Connected then
        begin
          WaitAsyncConnecting := True;
          WaitAsyncConnecting_BeginTime := GetTimeTick;
          TZNet_Client(PhysicsEngine).AsyncConnectM(Host, umlStrToInt(Port), PhysicsConnect_Result_BuildP2PToken);
        end;
    end;
end;

procedure TXNAT_VS_Mapping.OpenTunnel;
begin
  OpenTunnel(TXNAT_PHYSICS_MODEL.XNAT_PHYSICS_CLIENT);
end;

procedure TXNAT_VS_Mapping.Progress;
var
  i: Integer;
  tunMp: TXNAT_MappingOnVirutalService;
begin
  if Progressing then
      exit;

  Progressing := True;

  if (PhysicsEngine <> nil) then
    begin
      if (PhysicsEngine is TZNet_Client) then
        begin
          if WaitAsyncConnecting and (GetTimeTick - WaitAsyncConnecting_BeginTime > 15000) then
              WaitAsyncConnecting := False;

          if Activted and (not TZNet_Client(PhysicsEngine).Connected) then
            begin
              if not WaitAsyncConnecting then
                  OpenTunnel(TXNAT_PHYSICS_MODEL.XNAT_PHYSICS_CLIENT);
            end;
        end;
      PhysicsEngine.Progress;
    end;

  i := 0;
  while i < MappingList.Count do
    begin
      tunMp := MappingList[i];
      tunMp.UpdateWorkload(False);
      tunMp.Progress;
      inc(i);
    end;

  Progressing := False;
end;

function TXNAT_VS_Mapping.GetCount: Integer;
begin
  Result := MappingList.Count;
end;

function TXNAT_VS_Mapping.GetServices(const index: Integer): TXNAT_MappingOnVirutalService;
begin
  Result := MappingList[index];
end;

function TXNAT_VS_Mapping.GetServicesOnMapping(const FMapping: SystemString): TXNAT_MappingOnVirutalService;
begin
  Result := HashMapping[FMapping];
end;

end.
