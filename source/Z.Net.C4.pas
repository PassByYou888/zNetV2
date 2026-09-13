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
unit Z.Net.C4;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF FPC}
  Z.FPC.GenericList,
{$ELSE FPC}
  System.IOUtils,
{$ENDIF FPC}
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Status, Z.UnicodeMixedLib, Z.ListEngine, Z.Parsing,
  Z.Geometry2D, Z.DFE, Z.Json, Z.Notify, Z.Cipher, Z.MemoryStream, Z.HashList.Templet, Z.Int128,
  Z.Expression, Z.OpCode,
  Z.ZDB2, Z.ZDB2.Thread.Queue, Z.ZDB2.Thread,
  Z.Net, Z.Net.PhysicsIO,
  Z.Net.DoubleTunnelIO, Z.Net.DoubleTunnelIO.VirtualAuth, Z.Net.DoubleTunnelIO.NoAuth,
  Z.Net.DataStoreService, Z.Net.DataStoreService.VirtualAuth, Z.Net.DataStoreService.NoAuth,
  Z.Net.Client.IPC, Z.Net.Server.IPC,
  Z.Instance.Tool;

const
  C_C4_Edition = '4.01';

type
  TC40_PhysicsService = class;
  TC40_PhysicsServicePool = class;
  TC40_PhysicsTunnel = class;
  TC40_PhysicsTunnelPool = class;
  TC40_Info = class;
  TC40_Info_Array = array of TC40_Info;
  TC40_InfoList = class;
  TC40_Custom_Service = class;
  TC40_Custom_ServicePool = class;
  TC40_Custom_Client = class;
  TC40_Custom_ClientPool = class;
  TC40_Dispatch_Service = class;
  TC40_Dispatch_Client = class;
  TC40_Base_NoAuth_Service = class;
  TC40_Base_NoAuth_Client = class;
  TC40_Base_DataStoreNoAuth_Service = class;
  TC40_Base_DataStoreNoAuth_Client = class;
  TC40_Base_VirtualAuth_Service = class;
  TC40_Base_VirtualAuth_Client = class;
  TC40_Base_DataStoreVirtualAuth_Service = class;
  TC40_Base_DataStoreVirtualAuth_Client = class;

{$REGION 'PhysicsService'}
  { Array of dependency strings, each specifying a service type and optional parameters. }
  TC40_DependNetworkString = U_StringArray;

  {
    * Represents a single dependency entry: a service type and its associated parameters.
    * Used to define which services a physics tunnel or service should depend on.
  }
  TC40_DependNetworkInfo = record
    Typ: U_String;   { Service type identifier, e.g., 'FileServer'. }
    Param: U_String; { Optional parameter string, e.g., 'RootPath=/data'. }
  end;

  TC40_DependNetworkInfoArray = array of TC40_DependNetworkInfo;
  TC40_DependNetworkInfoList = class(TGenericsList<TC40_DependNetworkInfo>);

  {
    * Interface for receiving lifecycle events from the physics service layer.
    * Implement this interface to be notified when a physics service starts, stops,
    * establishes a link with a client, or when a user-defined service is built.
    * This is the primary way to react to low-level network events.
  }
  IC40_PhysicsService_Event = interface
    {
      * Called when a new custom service is being built within this physics service.
      * @param Sender The physics service that is building the network.
      * @param Custom_Service_ The new custom service instance being created.
    }
    procedure C40_PhysicsService_Build_Network(Sender: TC40_PhysicsService; Custom_Service_: TC40_Custom_Service);
    {
      * Called after the physics service has successfully started listening.
      * @param Sender The physics service that has started.
    }
    procedure C40_PhysicsService_Start(Sender: TC40_PhysicsService);
    {
      * Called after the physics service has stopped listening.
      * @param Sender The physics service that has stopped.
    }
    procedure C40_PhysicsService_Stop(Sender: TC40_PhysicsService);
    {
      * Called when a logical link (e.g., a double tunnel) has been successfully established.
      * @param Sender The physics service that owns the link.
      * @param Custom_Service_ The custom service instance that is now linked.
      * @param Trigger_ The object that triggered the link event.
    }
    procedure C40_PhysicsService_LinkSuccess(Sender: TC40_PhysicsService; Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);
    {
      * Called when a user-defined service disconnects or is removed.
      * @param Sender The physics service that owns the service.
      * @param Custom_Service_ The custom service instance that is disconnecting.
      * @param Trigger_ The object that triggered the disconnect event.
    }
    procedure C40_PhysicsService_UserOut(Sender: TC40_PhysicsService; Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);
  end;

  {
    * Represents a physical network server endpoint.
    * It manages a TZNet_Server instance and acts as a container for
    * TC40_Custom_Service instances. This class is responsible for listening for
    * incoming physical connections and hosting the top-level network services.
    *
    * @example:
    *   // Create a physics service that listens on all interfaces, port 9810,
    *   // but advertises its internal IP to clients.
    *   var
    *     svc: TC40_PhysicsService;
    *   begin
    *     svc := TC40_PhysicsService.Create('0.0.0.0', '192.168.1.100', 9810, TPhysicsServer.Create);
    *     svc.StartService;  // Start listening
    *   end;
  }
  TC40_PhysicsService = class(TCore_InterfacedObject_Intermediate)
  private
    FActivted: Boolean; { Indicates if the service is currently active and listening. }
    FLastDeadConnectionCheckTime_: TTimeTick; { Timestamp for periodic dead connection cleanup. }
    procedure cmd_QueryInfo(Sender: TPeerIO; InData, OutData: TDFE); { Handles 'QueryInfo' command from clients. }
  public
    ListeningAddr: U_String; { The IP address or IPC path the service is listening on. }
    PhysicsAddr: U_String;   { The public-facing IP address advertised to clients. }
    PhysicsPort: Word;       { The port the service is listening on. }
    PhysicsTunnel: TZNet_Server; { The underlying Z.Net server instance. }
    AutoFreePhysicsTunnel: Boolean; { If true, the PhysicsTunnel is freed when this object is destroyed. }
    DependNetworkServicePool: TC40_Custom_ServicePool; { Pool of custom services built on this physics service. }
    OnEvent: IC40_PhysicsService_Event; { Event interface for lifecycle notifications. }

    {
      * Creates a new physics service with a specific listening and advertised address.
      * @param ListeningAddr_ The local address to bind to (e.g., '0.0.0.0').
      * @param PhysicsAddr_ The public address to advertise to clients.
      * @param PhysicsPort_ The port to listen on.
      * @param PhysicsTunnel_ The TZNet_Server instance to use for the underlying network.
    }
    constructor Create(ListeningAddr_, PhysicsAddr_: U_String; PhysicsPort_: Word; PhysicsTunnel_: TZNet_Server); overload;
    {
      * Creates a new physics service with the same address for listening and advertising.
      * @param PhysicsAddr_ The address to bind and advertise.
      * @param PhysicsPort_ The port.
      * @param PhysicsTunnel_ The underlying server instance.
    }
    constructor Create(PhysicsAddr_: U_String; PhysicsPort_: Word; PhysicsTunnel_: TZNet_Server); overload;
    destructor Destroy; override;

    procedure Progress; virtual; { Drives the internal network engine – call regularly. }

    {
      * Returns true if the underlying network tunnel is an IPC (Inter-Process Communication) tunnel.
      * IPC tunnels are used for local communication and have different timeout/security handling.
    }
    function IPC_Mode: Boolean;

    {
      * Builds the nested dependency network by instantiating the required custom services.
      * @param Depend_ An array of service types and parameters to instantiate.
      * @returns True if all dependencies were successfully built, False otherwise.
      * @example:
      *   var deps: TC40_DependNetworkInfoArray;
      *   SetLength(deps, 1);
      *   deps[0].Typ := 'MyService';
      *   deps[0].Param := 'Param1=Value';
      *   PhysicsService.BuildDependNetwork(deps); // Instantiates and starts MyService
    }
    function BuildDependNetwork(const Depend_: TC40_DependNetworkInfoArray): Boolean; overload; virtual;
    function BuildDependNetwork(const Depend_: TC40_DependNetworkString): Boolean; overload;
    function BuildDependNetwork(const Depend_: U_String): Boolean; overload;

    property Activted: Boolean read FActivted; { True if the service is running and accepting connections. }

    procedure StartService; virtual; { Starts the underlying TZNet_Server and begins listening. }
    procedure StopService; virtual;  { Stops the underlying server and cleans up the listening socket. }
    procedure DoLinkSuccess(Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object); { Forward LinkSuccess to OnEvent. }
    procedure DoUserOut(Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object); { Forward UserOut to OnEvent. }
  end;

  TC40_PhysicsServicePool = class(TGenericsList<TC40_PhysicsService>)
  public
    procedure Progress; { Drives progress for all physics services in the pool. }
    procedure Enabled_Progress; { Enables progress for all contained physics services. }
    procedure Disable_Progress; { Disables progress for all contained physics services. }
    function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean; { Checks if a service with the given physics address exists. }
    function ExistsListenAddr(ListenAddr: U_String; Port: Word): Boolean; { Checks if a service is listening on the given address/port. }
    procedure GetRS(var recv, send: Int64); { Returns total received and sent bytes across all services. }
  end;
{$ENDREGION 'PhysicsService'}
{$REGION 'PhysicsTunnel'}

  TDCT40_OnQueryResultC = procedure(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
  TDCT40_OnQueryResultM = procedure(Sender: TC40_PhysicsTunnel; L: TC40_InfoList) of object;
{$IFDEF FPC}
  TDCT40_OnQueryResultP = procedure(Sender: TC40_PhysicsTunnel; L: TC40_InfoList) is nested;
{$ELSE FPC}
  TDCT40_OnQueryResultP = reference to procedure(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
{$ENDIF FPC}

  TDCT40_QueryResultData = class(TCore_Object_Intermediate)
  private
    procedure DoStreamParam(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE);
    procedure DoStreamFailed(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE);
    procedure DoRun;
  public
    C40_PhysicsTunnel: TC40_PhysicsTunnel;
    L: TC40_InfoList;
    OnResultC: TDCT40_OnQueryResultC;
    OnResultM: TDCT40_OnQueryResultM;
    OnResultP: TDCT40_OnQueryResultP;
    constructor Create;
    destructor Destroy; override;
  end;

  TDCT40_QueryResultAndDependProcessor = class(TCore_Object_Intermediate)
  private
    procedure DCT40_OnCheckDepend(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
    procedure DCT40_OnAutoP2PVMConnectionDone(Sender: TZNet; P_IO: TPeerIO);
    procedure DCT40_OnBuildDependNetwork(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
    procedure DoRun(const state: Boolean);
  public
    C40_PhysicsTunnel: TC40_PhysicsTunnel;
    On_C: TOnState_C;
    On_M: TOnState_M;
    On_P: TOnState_P;
    constructor Create;
    destructor Destroy; override;
  end;

  IC40_PhysicsTunnel_Event = interface
    procedure C40_PhysicsTunnel_Connected(Sender: TC40_PhysicsTunnel);
    procedure C40_PhysicsTunnel_Disconnect(Sender: TC40_PhysicsTunnel);
    procedure C40_PhysicsTunnel_Build_Network(Sender: TC40_PhysicsTunnel; Custom_Client_: TC40_Custom_Client);
    procedure C40_PhysicsTunnel_Client_Connected(Sender: TC40_PhysicsTunnel; Custom_Client_: TC40_Custom_Client);
  end;

  {
    * Represents a physical network client endpoint.
    * It manages a TZNet_Client instance and acts as a container for
    * TC40_Custom_Client instances. It handles the connection lifecycle to a
    * remote physics service and the management of its dependent clients.
    *
    * @example:
    *   // Create a tunnel to a physics service at 192.168.1.100:9810
    *   var
    *     tunnel: TC40_PhysicsTunnel;
    *   begin
    *     tunnel := TC40_PhysicsTunnel.Create('192.168.1.100', 9810);
    *     tunnel.ResetDepend('DP@');  // Depend on dispatch service
    *     tunnel.BuildDependNetwork;  // Connect and build dependencies
    *   end;
  }
  TC40_PhysicsTunnel = class(TCore_InterfacedObject_Intermediate, IZNet_ClientInterface)
  private
    FLast_Delay_Connecting_Time: TTimeTick;
    FIsConnecting: Boolean;
    FWait_Build_Depend_Network: Boolean;
    FNetwork_Already_Inited: Boolean;
    FOfflineTime: TTimeTick;
    procedure DoDelayConnect();
    procedure DoConnectOnResult(const state: Boolean);
    procedure DoConnectAndQuery(Param1: Pointer; Param2: TObject; const state: Boolean);
    procedure DoConnectAndCheckDepend(Param1: Pointer; Param2: TObject; const state: Boolean);
    procedure DoConnectAndBuildDependNetwork(Param1: Pointer; Param2: TObject; const state: Boolean);
  private
    procedure Do_Connect_Event;
    procedure Do_Disconnect_Event;
    procedure ClientConnected(Sender: TZNet_Client); virtual;
    procedure ClientDisconnect(Sender: TZNet_Client); virtual;
    procedure Do_Notify_All_Disconnect;
  public
    PhysicsAddr: U_String;   { The remote address this tunnel connects to. }
    PhysicsPort: Word;       { The remote port. }
    PhysicsTunnel: TZNet_Client; { The underlying Z.Net client instance. }
    DependNetworkInfoArray: TC40_DependNetworkInfoArray; { The list of services this tunnel depends on. }
    DependNetworkClientPool: TC40_Custom_ClientPool; { Pool of custom clients built for dependencies. }
    OnEvent: IC40_PhysicsTunnel_Event; { Event interface for tunnel lifecycle events. }

    constructor Create(Addr_: U_String; Port_: Word);
    destructor Destroy; override;

    procedure Progress; virtual;

    function IPC_Mode: Boolean; { Returns True if the tunnel uses IPC. }
    function IsLocalNetwork: Boolean; { Returns True if the tunnel is on a local network (e.g., 192.168.*). }
    function IsLoopbackNetwork: Boolean; { Returns True if the tunnel is loopback (127.0.0.1 or ::1). }

    {
      * Resets the dependency network for this tunnel.
      * This defines which services this tunnel should automatically connect to.
      * @param Depend_ An array of service types and parameters.
      * @returns True if all specified service types are registered, False otherwise.
    }
    function ResetDepend(const Depend_: TC40_DependNetworkInfoArray): Boolean; overload;
    function ResetDepend(const Depend_: TC40_DependNetworkString): Boolean; overload;
    function ResetDepend(const Depend_: U_String): Boolean; overload;

    function CheckDepend(): Boolean; { Checks if all dependencies are satisfied by the remote service. }
    function CheckDependC(OnResult: TOnState_C): Boolean; { Asynchronous check with C-style callback. }
    function CheckDependM(OnResult: TOnState_M): Boolean; { Asynchronous check with method callback. }
    function CheckDependP(OnResult: TOnState_P): Boolean; { Asynchronous check with nested callback. }

    {
      * Builds the dependency network.
      * This initiates the process of connecting to the remote physics service,
      * querying for available services, and instantiating the local TC40_Custom_Client
      * instances for each matched dependency.
      * @returns True if the build process started successfully.
    }
    function BuildDependNetwork(): Boolean;
    function BuildDependNetworkC(OnResult: TOnState_C): Boolean;
    function BuildDependNetworkM(OnResult: TOnState_M): Boolean;
    function BuildDependNetworkP(OnResult: TOnState_P): Boolean;

    {
      * Queries the remote physics service for its available service information.
      * Results are returned via a callback.
    }
    procedure QueryInfoC(OnResult: TDCT40_OnQueryResultC);
    procedure QueryInfoM(OnResult: TDCT40_OnQueryResultM);
    procedure QueryInfoP(OnResult: TDCT40_OnQueryResultP);

    function DependNetworkIsConnected: Boolean; { Returns True if all dependency clients are connected. }

    procedure DoNetworkOnline(Custom_Client_: TC40_Custom_Client); { Notifies OnEvent that a client is online. }
  end;

  TSearchServiceAndBuildConnection_Bridge = class;

  TC40_First_BuildDependNetwork_Fault_Fixed_Bridge = class(TCore_Object_Intermediate)
  public
    Fault_Fixed_Bridge_Begin_Time: TTimeTick;
    Tunnel: TC40_PhysicsTunnel;
    constructor Create(Tunnel_: TC40_PhysicsTunnel);
    procedure Do_Delay_Next_BuildDependNetwork();
    procedure Do_First_BuildDependNetwork(const state: Boolean);
  end;

  TC40_PhysicsTunnelPool = class(TGenericsList<TC40_PhysicsTunnel>)
  public
    Auto_Repair_First_BuildDependNetwork_Fault: Boolean; { If true, automatically retry first build failure. }
    constructor Create;
    procedure GetRS(var recv, send: Int64);
    function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
    function CreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word;
      const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel;
    function GetPhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word): TC40_PhysicsTunnel;
    function GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word): TC40_PhysicsTunnel; overload;
    function GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word;
      const Depend_: TC40_DependNetworkInfoArray; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;
    function GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word;
      const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;
    function GetOrCreatePhysicsTunnel(dispInfo: TC40_Info): TC40_PhysicsTunnel; overload;
    function GetOrCreatePhysicsTunnel(dispInfo: TC40_Info;
      const Depend_: TC40_DependNetworkInfoArray; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;
    function GetOrCreatePhysicsTunnel(dispInfo: TC40_Info;
      const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;
    procedure Progress;
    procedure Enabled_Progress;
    procedure Disable_Progress;
    function SearchServiceAndBuildConnection(PhysicsAddr: U_String; PhysicsPort: Word; FullConnection_: Boolean;
      const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge; overload;
    function SearchServiceAndBuildConnection(PhysicsAddr: U_String; PhysicsPort: Word;
      const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge; overload;
    function SearchServiceAndOptimizeConnection(PhysicsAddr: U_String; PhysicsPort: Word;
      const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge; overload;
  end;

  TC40_Custom_ClientPool_Wait_Data = record
    ServiceTyp_: U_String;
    Client_: TC40_Custom_Client;
  end;

  TC40_Custom_ClientPool_Wait_States = array of TC40_Custom_ClientPool_Wait_Data;
  TOn_C40_Custom_Client_EventC = procedure(States: TC40_Custom_ClientPool_Wait_States);
  TOn_C40_Custom_Client_EventM = procedure(States: TC40_Custom_ClientPool_Wait_States) of object;
{$IFDEF FPC}
  TOn_C40_Custom_Client_EventP = procedure(States: TC40_Custom_ClientPool_Wait_States) is nested;
{$ELSE FPC}
  TOn_C40_Custom_Client_EventP = reference to procedure(States: TC40_Custom_ClientPool_Wait_States);
{$ENDIF FPC}

  TC40_Custom_ClientPool_Wait = class(TCore_Object_Intermediate)
  private
    procedure DoRun;
  public
    States_: TC40_Custom_ClientPool_Wait_States;
    Pool_: TC40_Custom_ClientPool;
    On_C: TOn_C40_Custom_Client_EventC;
    On_M: TOn_C40_Custom_Client_EventM;
    On_P: TOn_C40_Custom_Client_EventP;
    constructor Create(dependNetwork_: U_String);
    destructor Destroy; override;
  end;

  TOnSearchServiceAndBuildConnection_C = procedure(Done_ClientPool: TC40_Custom_ClientPool);
  TOnSearchServiceAndBuildConnection_M = procedure(Done_ClientPool: TC40_Custom_ClientPool) of object;
{$IFDEF FPC}
  TOnSearchServiceAndBuildConnection_P = procedure(Done_ClientPool: TC40_Custom_ClientPool) is nested;
{$ELSE FPC}
  TOnSearchServiceAndBuildConnection_P = reference to procedure(Done_ClientPool: TC40_Custom_ClientPool);
{$ENDIF FPC}

  TSearchServiceAndBuildConnection_Bridge = class(TCore_Object_Intermediate)
  public
    PhysicsPool_: TC40_PhysicsTunnelPool;
    FullConnection_: Boolean;
    ServiceTyp: U_String;
    OnEvent_: IC40_PhysicsTunnel_Event;
    Done_ClientPool: TC40_Custom_ClientPool;
    TaskNum: Integer;
    OnDone_C: TOnSearchServiceAndBuildConnection_C;
    OnDone_M: TOnSearchServiceAndBuildConnection_M;
    OnDone_P: TOnSearchServiceAndBuildConnection_P;
    constructor Create;
    destructor Destroy; override;
    procedure Do_SearchService_Event(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
    procedure Do_Done_Client(States_: TC40_Custom_ClientPool_Wait_States);
  end;
{$ENDREGION 'PhysicsTunnel'}
{$REGION 'infoDefine'}

  {
    * Represents metadata for a logical service.
    * This includes its type, physical address, P2PVM tunnel addresses,
    * and workload information. It is used for service discovery and load balancing.
  }
  TC40_Info = class(TCore_Object_Intermediate)
  private
    Ignored: Boolean; { If true, this service should be ignored by the dispatch system. }
    procedure MakeHash; { Computes a unique hash from address and P2PVM info. }
  public
    OnlyInstance: Boolean;        { If true, only one instance of this service type can exist. }
    ServiceTyp: U_String;         { The logical service type (e.g., 'FileServer'). }
    PhysicsAddr: U_String;        { The physical IP address of the service. }
    PhysicsPort: Word;            { The physical port. }
    p2pVM_RecvTunnel_Addr: U_String; { IPv6 address for the P2PVM receive tunnel. }
    p2pVM_RecvTunnel_Port: Word;    { Port for the P2PVM receive tunnel. }
    p2pVM_SendTunnel_Addr: U_String; { IPv6 address for the P2PVM send tunnel. }
    p2pVM_SendTunnel_Port: Word;    { Port for the P2PVM send tunnel. }
    Workload: Integer;              { Current workload (e.g., number of connections). }
    MaxWorkload: Integer;           { Maximum workload capacity. }
    Hash: TMD5;                     { A unique hash for this service info. }

    property p2pVM_ClientRecvTunnel_Addr: U_String read p2pVM_SendTunnel_Addr; { For client, receive tunnel is remote send tunnel. }
    property p2pVM_ClientRecvTunnel_Port: Word read p2pVM_SendTunnel_Port;
    property p2pVM_ClientSendTunnel_Addr: U_String read p2pVM_RecvTunnel_Addr; { For client, send tunnel is remote receive tunnel. }
    property p2pVM_ClientSendTunnel_Port: Word read p2pVM_RecvTunnel_Port;

    constructor Create;
    destructor Destroy; override;
    procedure Assign(source: TC40_Info); { Copies all fields from source. }
    function Clone: TC40_Info; { Returns a new TC40_Info with the same values. }
    procedure Load(stream: TCore_Stream); { Deserializes from a stream. }
    procedure Save(stream: TCore_Stream); { Serializes to a stream. }
    function Same(Data_: TC40_Info): Boolean; { True if all fields match. }
    function SameServiceTyp(Data_: TC40_Info): Boolean; { True if ServiceTyp matches. }
    function SamePhysicsAddr(PhysicsAddr_: U_String): Boolean; overload; { True if PhysicsAddr matches. }
    function SamePhysicsAddr(Arry_: TArrayPascalString): Boolean; overload; { True if PhysicsAddr matches any in array. }
    function SamePhysicsAddr(PhysicsAddr_: U_String; PhysicsPort_: Word): Boolean; overload; { True if both address and port match. }
    function SamePhysicsAddr(Data_: TC40_Info): Boolean; overload; { True if PhysicsAddr and Port match. }
    function SamePhysicsAddr(Data_: TC40_PhysicsTunnel): Boolean; overload; { Compare with a tunnel. }
    function SamePhysicsAddr(Data_: TC40_PhysicsService): Boolean; overload; { Compare with a service. }
    function SameP2PVMAddr(Data_: TC40_Info): Boolean; { True if both P2PVM addresses match. }
    function FoundServiceTyp(Arry_: TC40_DependNetworkInfoArray): Boolean; overload; { True if ServiceTyp is in the dependency array. }
    function FoundServiceTyp(servTyp_: U_String): Boolean; overload; { True if ServiceTyp matches the given string. }
    function ReadyC40Client: Boolean; { True if a client class is registered for this ServiceTyp. }
    function GetOrCreateC40Client(PhysicsTunnel_: TC40_PhysicsTunnel; Param_: U_String): TC40_Custom_Client; { Creates a client instance for this service info. }
  end;

  TC40_InfoList = class(TGenericsList<TC40_Info>)
  public
    AutoFree: Boolean; { If true, items are automatically freed when removed. }
    constructor Create(AutoFree_: Boolean);
    destructor Destroy; override;
    procedure Remove(obj: TC40_Info);
    procedure Delete(index: Integer);
    procedure Clear;
    class procedure SortWorkLoad(L_: TC40_InfoList); { Sorts by workload ratio (ascending). }
    function GetInfoArray: TC40_Info_Array; { Returns a dynamic array of all items. }
    function IsOnlyInstance(ServiceTyp: U_String): Boolean; { Checks if the service type is marked as only instance. }
    function GetServiceTypNum(ServiceTyp: U_String): Integer; { Returns number of entries matching ServiceTyp. }
    function SearchMinWorkload(arry: TC40_DependNetworkInfoArray): TC40_Info_Array; overload; { Returns the minimum workload info for each dependency. }
    function SearchMinWorkload(ServiceTyp: U_String): TC40_Info_Array; overload;
    function SearchService(arry: TC40_DependNetworkInfoArray; full_: Boolean): TC40_Info_Array; overload; { Searches for services matching any dependency. If full_=False, only one per dependency. }
    function SearchService(arry: TC40_DependNetworkInfoArray): TC40_Info_Array; overload; { Full search (all matches). }
    function SearchService(ServiceTyp: U_String): TC40_Info_Array; overload;
    function ExistsService(arry: TC40_DependNetworkInfoArray): Boolean; overload; { True if any service matches any dependency. }
    function ExistsService(ServiceTyp: U_String): Boolean; overload;
    function FindSame(Data_: TC40_Info): TC40_Info; { Finds an entry with identical fields. }
    function FindHash(Hash: TMD5): TC40_Info; { Finds an entry by its hash. }
    function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean; { True if any entry has the given address/port. }
    procedure RemovePhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word); { Removes all entries with the given address/port. }
    function OverwriteInfo(Data_: TC40_Info): Boolean; { Updates an existing entry or adds a clone if not found. }
    function MergeAndUpdateWorkload(source: TC40_InfoList): Boolean; { Merges entries from source, updating workloads. }
    function MergeFromDF(D: TDFE): Boolean; { Merges entries from a DFE stream. }
    procedure SaveToDF(D: TDFE); { Saves all non-ignored entries to a DFE stream. }
  end;
{$ENDREGION 'infoDefine'}
{$REGION 'Help_Console_Command'}

  TOn_C4_Help_Console_Command_C = procedure(var OP_Param: TOpParam);
  TOn_C4_Help_Console_Command_M = procedure(var OP_Param: TOpParam) of object;
{$IFDEF FPC}
  TOn_C4_Help_Console_Command_P = procedure(var OP_Param: TOpParam) is nested;
{$ELSE FPC}
  TOn_C4_Help_Console_Command_P = reference to procedure(var OP_Param: TOpParam);
{$ENDIF FPC}

  TC4_Help_Console_Command_Data = class(TCore_Object_Intermediate)
  public
    Cmd: SystemString; { Command name. }
    Desc: SystemString; { Command description. }
    OnEvent_C: TOn_C4_Help_Console_Command_C; { C-style event handler. }
    OnEvent_M: TOn_C4_Help_Console_Command_M; { Method event handler. }
    OnEvent_P: TOn_C4_Help_Console_Command_P; { Nested event handler. }
    constructor Create;
    destructor Destroy; override;
    procedure DoExecute(var OP_Param: TOpParam); { Invokes the appropriate event handler. }
  end;

  TC4_Help_Console_Command_Decl = class(TBigList<TC4_Help_Console_Command_Data>);

  TC4_Help_Console_Command = class(TC4_Help_Console_Command_Decl)
  public
    procedure DoFree(var Data: TC4_Help_Console_Command_Data); override; { Frees a command data item. }
  end;
{$ENDREGION 'Help_Console_Command'}
{$REGION 'p2p_Custom_Service_Templet'}

  {
    * The base class for all user-defined services in the C4 framework.
    * This is a template that, when instantiated, registers itself with its
    * parent TC40_PhysicsService and makes its metadata available for discovery.
    * Inherit from this class to implement your own business logic.
    *
    * @example:
    *   type
    *     TMyFileService = class(TC40_Custom_Service)
    *     protected
    *       procedure cmd_GetFile(Sender: TPeerIO; InData: TDFE; OutData: TDFE);
    *     end;
    *
    *   procedure TMyFileService.cmd_GetFile(Sender: TPeerIO; InData: TDFE; OutData: TDFE);
    *   begin
    *     // File serving logic here
    *     OutData.WriteString('File content');
    *   end;
    *
    *   // In the service creation logic:
    *   MyFileService := TMyFileService.Create(PhysicsService, 'FileServer', 'RootPath=/data');
    *   MyFileService.Service.RecvTunnel.RegisterStream('GetFile').OnExecute := MyFileService.cmd_GetFile;
  }
  TC40_Custom_Service = class(TCore_InterfacedObject_Intermediate)
  private
    FLastSafeCheckTime: TTimeTick; { Timestamp of last SafeCheck call. }
  private
    FCycle_Order_Default: Int64; { Default order for cycle anchor. }
    FCycle_Anchor: TString_Num64_Analysis_Tool; { Used for load balancing via cycle order. }
    FCycle_Anchor_Temp: Int64; { Temporary anchor value. }
    procedure Init_Cycle_Anchor; { Initializes the cycle anchor. }
    procedure Free_Cycle_Anchor; { Frees the cycle anchor. }
    procedure Inc_Cycle_Anchor(TaskName: U_String); { Increments the anchor value for a task. }
    procedure Ready_Cycle_Anchor(TaskName: U_String); { Reads the current anchor value. }
  public
    Param: U_String;               { The raw parameter string for this service. }
    Param_File: U_String;          { The configuration file path loaded for this service. }
    ParamList: THashStringList;    { Parsed key-value parameters from Param and Param_File. }
    SafeCheckTime: TTimeTick;      { Interval for calling SafeCheck. }
    Alias_or_Hash___: U_String;    { A user-friendly alias for this service. }
    enablePerServiceDirectory: Boolean; { If true, service data is stored in a dedicated directory. }
    Tag: Integer;                  { A user-defined integer tag for grouping/filtering. }
    ServiceInfo: TC40_Info;        { The published metadata for this service. }
    C40PhysicsService: TC40_PhysicsService; { The parent physics service. }
    ConsoleCommand: TC4_Help_Console_Command; { Console commands registered by this service. }

    property PhysicsService: TC40_PhysicsService read C40PhysicsService;

    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); virtual;
    destructor Destroy; override;

    procedure SafeCheck; virtual; { Called periodically for self-validation/cleanup. }
    procedure Progress; virtual; { Called on every main loop iteration for driving service logic. }

    procedure SetWorkload(Workload_, MaxWorkload_: Integer); { Updates the workload values in ServiceInfo. }
    procedure UpdateToGlobalDispatch; { Publishes this service's info to the global dispatch service. }

    function GetHash: TMD5; { Returns the hash of ServiceInfo. }
    property Hash: TMD5 read GetHash;
    function GetAliasOrHash: U_String; { Returns Alias_or_Hash___ if non-empty, else the hash string. }
    property AliasOrHash: U_String read GetAliasOrHash write Alias_or_Hash___;

    function Get_P2PVM_Service(var recv_, send_: TZNet_WithP2PVM_Server): Boolean; { Retrieves the P2PVM server tunnels. }
    function Get_DB_FileName_Config(source_: U_String): U_String; { Returns a config value from ParamList. }
    function Where_C4_File(fileName, ServiceTyp: U_String): U_String; overload; { Locates a file in C4 root or service-specific directory. }
    function Where_C4_File(fileName: U_String): U_String; overload;

    function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data; { Registers a console command for this service. }

    procedure DoLinkSuccess(Trigger_: TCore_Object); { Forwards link success to physics service. }
    procedure DoUserOut(Trigger_: TCore_Object); { Forwards user out to physics service. }
  end;

  TC40_Custom_Service_Class = class of TC40_Custom_Service;
  TC40_Custom_Service_Array = array of TC40_Custom_Service;

  TC40_Custom_ServicePool = class(TGenericsList<TC40_Custom_Service>)
  private
    FIPV6_Seed: Word; { Seed for generating IPv6 addresses. }
  public
    Enabled_Auto_Sort_for_Select_And_Next_Cycle_Anchor: Boolean; { If true, sorts before selecting. }
    constructor Create;
    procedure Progress; { Calls Progress on all services. }
    procedure Sort_Cycle_Anchor(TaskName: U_String); { Sorts services by their cycle anchor for the given task. }
    function Select_And_Next_Cycle_Anchor(TaskName: U_String): TC40_Custom_Service; { Selects the service with smallest anchor and increments it. }

    procedure MakeP2PVM_IPv6_Port(var ip6, Port: U_String); { Generates a unique IPv6 address and port for P2PVM. }
    function MakeAlias(preset_: U_String): U_String; { Creates a unique alias based on preset. }
    function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean; { Checks if any service has the given address/port. }
    function ExistsOnlyInstance(ServiceTyp: U_String): Boolean; { Checks if any service of the type is marked OnlyInstance. }

    function FindHash(hash_: TMD5): TC40_Custom_Service; { Finds a service by hash. }
    function FindAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Service; { Finds by alias or hash string. }
    function FindTag(Tag: Integer): TC40_Custom_Service; { Finds a service by tag. }
    function GetServiceFromHash(Hash: TMD5): TC40_Custom_Service; { Alias for FindHash. }
    function GetServiceFromAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Service; { Alias for FindAliasOrHash. }

    function GetC40Array(is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload; { Returns array of services, optionally filtering IPC mode. }
    function GetC40Array: TC40_Custom_Service_Array; overload;
    function GetFromServiceTyp(ServiceTyp: U_String; is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload; { Filters by ServiceTyp and IPC mode. }
    function GetFromServiceTyp(ServiceTyp: U_String): TC40_Custom_Service_Array; overload;
    function GetFromPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word; is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload;
    function GetFromPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): TC40_Custom_Service_Array; overload;
    function GetFromClass(Class_: TC40_Custom_Service_Class; is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload; { Filters by class type. }
    function GetFromClass(Class_: TC40_Custom_Service_Class): TC40_Custom_Service_Array; overload;
  end;
{$ENDREGION 'p2p_Custom_Service_Templet'}
{$REGION 'p2p_Custom_Client_Templet'}

  TOn_Client_Offline = procedure(Sender: TC40_Custom_Client) of object;

  {
    * The base class for all user-defined clients in the C4 framework.
    * Inherit from this class to create a client that connects to a specific
    * service type and manages the communication state.
    *
    * @example:
    *   type
    *     TMyFileClient = class(TC40_Custom_Client)
    *     public
    *       function GetFile(const FileName: string): TStream;
    *     end;
    *
    *   function TMyFileClient.GetFile(const FileName: string): TStream;
    *   var
    *     D: TDFE;
    *   begin
    *     Result := nil;
    *     D := TDFE.Create;
    *     D.WriteString(FileName);
    *     // Wait for the response stream.
    *     WaitSendStreamCmd('GetFile', D, ResultD, 5000);
    *     // ResultD contains the response stream.
    *     DisposeObject(D);
    *   end;
  }
  TC40_Custom_Client = class(TCore_InterfacedObject_Intermediate)
  private
    FLastSafeCheckTime: TTimeTick;
  private
    FCycle_Order_Default: Int64;
    FCycle_Anchor: TString_Num64_Analysis_Tool;
    FCycle_Anchor_Temp: Int64;
    procedure Init_Cycle_Anchor;
    procedure Free_Cycle_Anchor;
    procedure Inc_Cycle_Anchor(TaskName: U_String);
    procedure Ready_Cycle_Anchor(TaskName: U_String);
  public
    Param: U_String;
    Param_File: U_String;
    ParamList: THashStringList;
    SafeCheckTime: TTimeTick;
    Alias_or_Hash___: U_String;
    Tag: Integer;
    ClientInfo: TC40_Info;
    C40PhysicsTunnel: TC40_PhysicsTunnel;
    ConsoleCommand: TC4_Help_Console_Command;
    On_Client_Offline: TOn_Client_Offline;

    property PhysicsTunnel: TC40_PhysicsTunnel read C40PhysicsTunnel;

    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); virtual;
    destructor Destroy; override;

    procedure SafeCheck; virtual;
    procedure Progress; virtual;

    procedure Connect; virtual; { Initiates the connection process. }
    function Connected: Boolean; virtual; { Returns true if the client is fully connected to its service. }
    procedure Disconnect; virtual; { Terminates the client connection. }

    function GetHash: TMD5;
    property Hash: TMD5 read GetHash;
    function GetAliasOrHash: U_String;
    property AliasOrHash: U_String read GetAliasOrHash write Alias_or_Hash___;

    function Get_P2PVM_Tunnel(var recv_, send_: TZNet_WithP2PVM_Client): Boolean; { Retrieves the P2PVM client tunnels. }
    function Get_DB_FileName_Config(source_: U_String): U_String; { Returns config value. }
    function Where_C4_File(fileName: U_String): U_String; { Locates a file in C4 root. }
    function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data; { Registers a console command. }
    function IsLocal: Boolean; { True if the client is on local/loopback network. }

    procedure DoNetworkOnline; virtual;   { Called when the client has successfully connected. }
    procedure DoNetworkOffline; virtual;  { Called when the client has been disconnected. }
  end;

  TC40_Custom_Client_Class = class of TC40_Custom_Client;
  TC40_Custom_Client_Array = array of TC40_Custom_Client;

  TC40_Custom_ClientPool = class(TGenericsList<TC40_Custom_Client>)
  public
    Enabled_Auto_Sort_for_Select_And_Next_Cycle_Anchor: Boolean;
    constructor Create;
    procedure Progress;
    procedure Sort_Cycle_Anchor(TaskName: U_String);
    function Select_And_Next_Cycle_Anchor(TaskName: U_String): TC40_Custom_Client;

    function MakeAlias(preset_: U_String): U_String;
    function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
    function ExistsServiceInfo(info_: TC40_Info): Boolean;
    function ExistsServiceTyp(ServiceTyp: U_String): Boolean;
    function FindPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
    function FindServiceInfo(info_: TC40_Info): Boolean;
    function FindServiceTyp(ServiceTyp: U_String): Boolean;

    function FindHash(hash_: TMD5; isConnected: Boolean): TC40_Custom_Client; overload;
    function FindHash(hash_: TMD5): TC40_Custom_Client; overload;
    function FindAliasOrHash(AliasOrhash_: U_String; isConnected: Boolean): TC40_Custom_Client; overload;
    function FindAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Client; overload;
    function FindTag(Tag: Integer): TC40_Custom_Client;
    function ExistsClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
    function ExistsConnectedClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
    function ExistsConnectedServiceTyp(ServiceTyp: U_String): TC40_Custom_Client;
    function ExistsConnectedServiceTypAndClass(ServiceTyp: U_String; Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
    function FindClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
    function FindConnectedClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
    function FindConnectedServiceTyp(ServiceTyp: U_String): TC40_Custom_Client;
    function FindConnectedServiceTypAndClass(ServiceTyp: U_String; Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
    function GetClientFromHash(Hash: TMD5): TC40_Custom_Client;

    function GetC40Array(is_ipc_mode: Boolean): TC40_Custom_Client_Array; overload;
    function GetC40Array: TC40_Custom_Client_Array; overload;
    function SearchServiceTyp(ServiceTyp: U_String; isConnected: Boolean): TC40_Custom_Client_Array; overload;
    function SearchServiceTyp(ServiceTyp: U_String): TC40_Custom_Client_Array; overload;
    function SearchPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word; isConnected: Boolean): TC40_Custom_Client_Array; overload;
    function SearchPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): TC40_Custom_Client_Array; overload;

    function SearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode, is_local_network: Boolean): TC40_Custom_Client_Array; overload;
    function SearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode: Boolean): TC40_Custom_Client_Array; overload;
    function SearchClass(Class_: TC40_Custom_Client_Class; isConnected: Boolean): TC40_Custom_Client_Array; overload;
    function SearchClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client_Array; overload;

    function FastFindClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
    function FastSearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode, is_local_network: Boolean): TC40_Custom_Client_Array; overload;
    function FastSearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode: Boolean): TC40_Custom_Client_Array; overload;
    function FastSearchClass(Class_: TC40_Custom_Client_Class; isConnected: Boolean): TC40_Custom_Client_Array; overload;
    function FastSearchClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client_Array; overload;

    procedure WaitConnectedDoneC(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventC);
    procedure WaitConnectedDoneM(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventM);
    procedure WaitConnectedDoneP(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventP);
  end;
{$ENDREGION 'p2p_Custom_Client_Templet'}
{$REGION 'Auto_Deployment'}

  {
    * Generic class for automatically deploying a client of type T_.
    * It waits until the required dependency network is ready, then
    * instantiates and provides the client instance.
    *
    * @example:
    *   var
    *     MyClient: TMyClient;
    *   begin
    *     TC40_Auto_Deployment_Client<TMyClient>.Create_M2('MyService', DoOnClientReady);
    *   end;
    *
    *   procedure DoOnClientReady(var Sender: TMyClient);
    *   begin
    *     // Sender is connected and ready to use.
    *   end;
  }
  TC40_Auto_Deployment_Client<T_: class> = class(TCore_Object_Intermediate)
  public type
    PT_ = ^T_;
    TOn_Ready_C = procedure(var Sender: T_);
    TOn_Ready_M = procedure(var Sender: T_) of object;
{$IFDEF FPC}
    TOn_Ready_P = procedure(var Sender: T_) is nested;
{$ELSE FPC}
    TOn_Ready_P = reference to procedure(var Sender: T_);
{$ENDIF FPC}
  private
    FClient_Second: T_; { Temporary storage when no pointer provided. }
    FClient_Ptr: PT_; { Pointer to the client variable to set. }
    FDependNetwork: U_String; { Dependency string to wait for. }
    FOn_Ready_C: TOn_Ready_C;
    FOn_Ready_M: TOn_Ready_M;
    FOn_Ready_P: TOn_Ready_P;
    procedure Do_Deployment_Ready(States: TC40_Custom_ClientPool_Wait_States); { Called when dependencies are ready. }
  public
    constructor Create_Ptr(dependNetwork_: U_String; Client_: PT_); { Provide a pointer to a client variable. }
    constructor Create(dependNetwork_: U_String; var Client: T_); overload; { Pass client variable by reference. }
    constructor Create(var Client: T_); overload; { Auto-detect dependency from registered type. }
    constructor Create_C(OnReady: TOn_Ready_C); { Creates with C-style callback, auto-detects dependency. }
    constructor Create_M(OnReady: TOn_Ready_M);
    constructor Create_P(OnReady: TOn_Ready_P);
    constructor Create_C2(dependNetwork_: U_String; OnReady: TOn_Ready_C); { With explicit dependency. }
    constructor Create_M2(dependNetwork_: U_String; OnReady: TOn_Ready_M);
    constructor Create_P2(dependNetwork_: U_String; OnReady: TOn_Ready_P);
    destructor Destroy; override;
    property On_Ready: TOn_Ready_M read FOn_Ready_M write FOn_Ready_M;
    property On_Ready_C: TOn_Ready_C read FOn_Ready_C write FOn_Ready_C;
    property On_Ready_M: TOn_Ready_M read FOn_Ready_M write FOn_Ready_M;
    property On_Ready_P: TOn_Ready_P read FOn_Ready_P write FOn_Ready_P;
  end;

  TC40_Auto_Deploy_Client<T_: class> = class(TC40_Auto_Deployment_Client<T_>);
  TC40_Auto_Deploy<T_: class> = class(TC40_Auto_Deployment_Client<T_>);
  TC40_Deploy<T_: class> = class(TC40_Auto_Deployment_Client<T_>);
{$ENDREGION 'Auto_Deployment'}
{$REGION 'DispatchService'}

  TOnRemovePhysicsNetwork = class(TCore_Object_Intermediate)
  public
    PhysicsAddr: U_String;
    PhysicsPort: Word;
    constructor Create;
    procedure DoRun; virtual; { Calls C40RemovePhysics for the stored address/port. }
  end;

  TOnServiceInfoChange = procedure(Sender: TCore_Object; Service_Info_Pool: TC40_InfoList) of object;

  {
    * The dispatch service acts as a service registry and load balancer.
    * It collects service information from all local TC40_Custom_Service instances
    * and distributes this information to all connected TC40_Dispatch_Client instances.
    * Clients use this information to discover and load-balance connections.
  }
  TC40_Dispatch_Service = class(TC40_Custom_Service)
  private
    FOnServiceInfoChange: TOnServiceInfoChange;
    FWaiting_UpdateServerInfoToAllClient: Boolean;
    FWaiting_UpdateServerInfoToAllClient_TimeTick: TTimeTick;
    DelayCheck_Working: Boolean;
    procedure cmd_UpdateServiceInfo(Sender: TPeerIO; InData: TDFE);
    procedure cmd_UpdateServiceState(Sender: TPeerIO; InData: TDFE);
    procedure cmd_IgnoreChange(Sender: TPeerIO; InData: TDFE);
    procedure cmd_RequestUpdate(Sender: TPeerIO; InData: TDFE);
    procedure cmd_RemovePhysicsNetwork(Sender: TPeerIO; InData: TDFE);
    procedure Prepare_UpdateServerInfoToAllClient;
    procedure UpdateServerInfoToAllClient;
    procedure DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
    procedure DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
    procedure DoDelayCheckLocalServiceInfo;
  public
    Service: TDT_P2PVM_NoAuth_Custom_Service;
    Service_Info_Pool: TC40_InfoList;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure IgnoreChangeToAllClient(Hash__: TMD5; Ignored: Boolean); { Broadcasts ignore change to all clients. }
    procedure UpdateServiceStateToAllClient; { Broadcasts current workload states to all clients. }
    property OnServiceInfoChange: TOnServiceInfoChange read FOnServiceInfoChange write FOnServiceInfoChange;
  end;
{$ENDREGION 'DispatchService'}
{$REGION 'DispatchClient'}

  {
    * The dispatch client is a special TC40_Custom_Client that connects to a
    * TC40_Dispatch_Service. It receives and maintains a local copy of the
    * global service registry (Service_Info_Pool). This enables the client
    * and its parent tunnel to perform service discovery and load balancing.
  }
  TC40_Dispatch_Client = class(TC40_Custom_Client)
  private
    FOnServiceInfoChange: TOnServiceInfoChange;
    DelayCheck_Working: Boolean;
    procedure cmd_UpdateServiceInfo(Sender: TPeerIO; InData: TDFE);
    procedure cmd_UpdateServiceState(Sender: TPeerIO; InData: TDFE);
    procedure cmd_IgnoreChange(Sender: TPeerIO; InData: TDFE);
    procedure cmd_RemovePhysicsNetwork(Sender: TPeerIO; InData: TDFE);
    procedure Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client);
    procedure DoDelayCheckLocalServiceInfo;
  public
    Client: TDT_P2PVM_NoAuth_Custom_Client;
    Service_Info_Pool: TC40_InfoList;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    procedure PostLocalServiceInfo(forcePost_: Boolean); { Sends local service info to dispatch service. }
    procedure RequestUpdate(); { Requests a full update from dispatch service. }
    procedure IgnoreChangeToService(Hash__: TMD5; Ignored: Boolean); { Sends ignore change request to dispatch. }
    procedure UpdateLocalServiceState; { Sends local workload states to dispatch. }
    procedure RemovePhysicsNetwork(PhysicsAddr: U_String; PhysicsPort: Word); { Requests removal of a physics network. }
    property OnServiceInfoChange: TOnServiceInfoChange read FOnServiceInfoChange write FOnServiceInfoChange;
  end;
{$ENDREGION 'DispatchClient'}
{$REGION 'RegistedData'}

  TC40_RegistedData = record
    ServiceTyp: U_String;
    ServiceClass: TC40_Custom_Service_Class;
    ClientClass: TC40_Custom_Client_Class;
  end;

  PC40_RegistedData = ^TC40_RegistedData;

  TC40_RegistedDataList = class(TGenericsList<PC40_RegistedData>)
  public
    destructor Destroy; override;
    procedure Clean; { Frees all registered data. }
    procedure Print; { Outputs registration information to status. }
  end;
{$ENDREGION 'RegistedData'}
{$REGION 'DTC40NULLModel'}

  { Base service that uses NoAuth double-tunnel but does not override any behavior. }
  TC40_Base_NULL_Service = class(TC40_Custom_Service)
  protected
    procedure DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); virtual;
    procedure DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); virtual;
  public
    Service: TDT_P2PVM_NoAuth_Custom_Service;
    DTNoAuthService: TDTService_NoAuth;
    property DTNoAuth: TDTService_NoAuth read DTNoAuthService;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
  end;

  TC40_Base_NULL_Client = class(TC40_Custom_Client)
  protected
    procedure Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client); virtual;
  public
    Client: TDT_P2PVM_NoAuth_Custom_Client;
    DTNoAuthClient: TDTClient_NoAuth;
    property DTNoAuth: TDTClient_NoAuth read DTNoAuthClient;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
  end;
{$ENDREGION 'DTC40NULLModel'}
{$REGION 'DTC40NoAuthModel'}

  { Service using NoAuth double-tunnel with link and user-out events. }
  TC40_Base_NoAuth_Service = class(TC40_Custom_Service)
  protected
    procedure DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); virtual;
    procedure DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); virtual;
  public
    Service: TDT_P2PVM_NoAuth_Custom_Service;
    DTNoAuthService: TDTService_NoAuth;
    property DTNoAuth: TDTService_NoAuth read DTNoAuthService;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
  end;

  TC40_Base_NoAuth_Client = class(TC40_Custom_Client)
  protected
    procedure Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client); virtual;
  public
    Client: TDT_P2PVM_NoAuth_Custom_Client;
    DTNoAuthClient: TDTClient_NoAuth;
    property DTNoAuth: TDTClient_NoAuth read DTNoAuthClient;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
  end;

  TC40_Base_DataStoreNoAuth_Service = class(TC40_Custom_Service)
  protected
    procedure DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); virtual;
    procedure DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); virtual;
  public
    Service: TDT_P2PVM_NoAuth_Custom_Service;
    DTNoAuthService: TDataStoreService_NoAuth;
    property DTNoAuth: TDataStoreService_NoAuth read DTNoAuthService;
    property DT_DataStore_NoAuth: TDataStoreService_NoAuth read DTNoAuthService;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
  end;

  TC40_Base_DataStoreNoAuth_Client = class(TC40_Custom_Client)
  protected
    procedure Do_DT_P2PVM_DataStoreNoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client); virtual;
  public
    Client: TDT_P2PVM_NoAuth_Custom_Client;
    DTNoAuthClient: TDataStoreClient_NoAuth;
    property DTNoAuth: TDataStoreClient_NoAuth read DTNoAuthClient;
    property DT_DataStore_NoAuth: TDataStoreClient_NoAuth read DTNoAuthClient;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
  end;
{$ENDREGION 'DTC40NoAuthModel'}
{$REGION 'DTC40VirtualAuthModel'}

  { Service using VirtualAuth double-tunnel with registration and authentication callbacks. }
  TC40_Base_VirtualAuth_Service = class(TC40_Custom_Service)
  protected
    procedure DoUserReg_Event(Sender: TDTService_VirtualAuth; RegIO: TVirtualRegIO); virtual;
    procedure DoUserAuth_Event(Sender: TDTService_VirtualAuth; AuthIO: TVirtualAuthIO); virtual;
    procedure DoLinkSuccess_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth); virtual;
    procedure DoUserOut_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth); virtual;
  public
    Service: TDT_P2PVM_VirtualAuth_Custom_Service;
    DTVirtualAuthService: TDTService_VirtualAuth;
    property DTVirtualAuth: TDTService_VirtualAuth read DTVirtualAuthService;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
  end;

  TC40_Base_VirtualAuth_Client = class(TC40_Custom_Client)
  protected
    procedure Do_DT_P2PVM_VirtualAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_VirtualAuth_Custom_Client); virtual;
  public
    Client: TDT_P2PVM_VirtualAuth_Custom_Client;
    DTVirtualAuthClient: TDTClient_VirtualAuth;
    UserName: U_String;
    Password: U_String;
    NoDTLink: Boolean;
    property DTVirtualAuth: TDTClient_VirtualAuth read DTVirtualAuthClient;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    function LoginIsSuccessed: Boolean; { Returns True if the user is logged in. }
  end;

  TC40_Base_DataStoreVirtualAuth_Service = class(TC40_Custom_Service)
  protected
    procedure DoUserReg_Event(Sender: TDTService_VirtualAuth; RegIO: TVirtualRegIO); virtual;
    procedure DoUserAuth_Event(Sender: TDTService_VirtualAuth; AuthIO: TVirtualAuthIO); virtual;
    procedure DoLinkSuccess_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth); virtual;
    procedure DoUserOut_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth); virtual;
  public
    Service: TDT_P2PVM_VirtualAuth_Custom_Service;
    DTVirtualAuthService: TDataStoreService_VirtualAuth;
    property DTVirtualAuth: TDataStoreService_VirtualAuth read DTVirtualAuthService;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
  end;

  TC40_Base_DataStoreVirtualAuth_Client = class(TC40_Custom_Client)
  protected
    procedure Do_DT_P2PVM_VirtualAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_VirtualAuth_Custom_Client); virtual;
  public
    Client: TDT_P2PVM_VirtualAuth_Custom_Client;
    DTVirtualAuthClient: TDataStoreClient_VirtualAuth;
    UserName: U_String;
    Password: U_String;
    NoDTLink: Boolean;
    property DTVirtualAuth: TDataStoreClient_VirtualAuth read DTVirtualAuthClient;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    function LoginIsSuccessed: Boolean;
  end;
{$ENDREGION 'DTC40VirtualAuthModel'}
{$REGION 'DTC40BuildInAuthModel'}

  { Service using built-in authentication (TDTService). }
  TC40_Base_Service = class(TC40_Custom_Service)
  protected
    procedure DoLinkSuccess_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine); virtual;
    procedure DoUserOut_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine); virtual;
  public
    Service: TDT_P2PVM_Custom_Service;
    DTService: TDTService;
    property DT: TDTService read DTService;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure SafeCheck; override;
    procedure Progress; override;
  end;

  TC40_Base_Client = class(TC40_Custom_Client)
  protected
    procedure Do_DT_P2PVM_Custom_Client_TunnelLink(Sender: TDT_P2PVM_Custom_Client); virtual;
  public
    Client: TDT_P2PVM_Custom_Client;
    DTClient: TDTClient;
    UserName: U_String;
    Password: U_String;
    NoDTLink: Boolean;
    property DT: TDTClient read DTClient;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    function LoginIsSuccessed: Boolean;
  end;

  TC40_Base_DataStore_Service = class(TC40_Custom_Service)
  protected
    procedure DoLinkSuccess_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine); virtual;
    procedure DoUserOut_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine); virtual;
  public
    Service: TDT_P2PVM_Custom_Service;
    DTService: TDataStoreService;
    property DT: TDataStoreService read DTService;
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
    destructor Destroy; override;
    procedure SafeCheck; override;
    procedure Progress; override;
  end;

  TC40_Base_DataStore_Client = class(TC40_Custom_Client)
  protected
    procedure Do_DT_P2PVM_Custom_Client_TunnelLink(Sender: TDT_P2PVM_Custom_Client); virtual;
  public
    Client: TDT_P2PVM_Custom_Client;
    DTClient: TDataStoreClient;
    UserName: U_String;
    Password: U_String;
    NoDTLink: Boolean;
    property DT: TDataStoreClient read DTClient;
    constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;
    destructor Destroy; override;
    procedure Progress; override;
    procedure Connect; override;
    function Connected: Boolean; override;
    procedure Disconnect; override;
    function LoginIsSuccessed: Boolean;
  end;
{$ENDREGION 'DTC40BuildInAuthModel'}
{$REGION 'VM_Templet_Define'}

  TC40_Custom_VM_Service = class;
  TC40_Custom_VM_Client = class;

  { Base class for virtual-machine services (standalone, not tied to physics service). }
  TC40_Custom_VM_Service = class(TCore_InterfacedObject_Intermediate)
  private
    FLastSafeCheckTime: TTimeTick;
  public
    Param: U_String;
    ParamList: THashStringList;
    SafeCheckTime: TTimeTick;
    IPC_Mode: Boolean;
    enablePerServiceDirectory: Boolean;
    ConsoleCommand: TC4_Help_Console_Command;
    constructor Create(Param_: U_String); virtual;
    destructor Destroy; override;
    procedure SafeCheck; virtual;
    procedure Progress; virtual;
    procedure StartService(ListenAddr, ListenPort, Auth: SystemString); virtual;
    procedure StopService; virtual;
    function Get_DB_FileName_Config(source_: U_String): U_String;
    function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;
    procedure DoLinkSuccess(Trigger_: TCore_Object); virtual;
    procedure DoUserOut(Trigger_: TCore_Object); virtual;
  end;

  TC40_Custom_VM_Service_Pool = class(TGenericsList<TC40_Custom_VM_Service>)
  public
    procedure Progress;
  end;

  TOn_VM_Client_Event = procedure(Sender: TC40_Custom_VM_Client) of object;

  { Base class for virtual-machine clients. }
  TC40_Custom_VM_Client = class(TCore_InterfacedObject_Intermediate)
  private
    FLastSafeCheckTime: TTimeTick;
  public
    Param: U_String;
    ParamList: THashStringList;
    SafeCheckTime: TTimeTick;
    IPC_Mode: Boolean;
    ConsoleCommand: TC4_Help_Console_Command;
    On_Client_Online: TOn_VM_Client_Event;
    On_Client_Offline: TOn_VM_Client_Event;
    constructor Create(Param_: U_String); virtual;
    destructor Destroy; override;
    procedure SafeCheck; virtual;
    procedure Progress; virtual;
    function Connected: Boolean; virtual;
    procedure Disconnect; virtual;
    function Get_DB_FileName_Config(source_: U_String): U_String;
    function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;
    procedure DoNetworkOnline; virtual;
    procedure DoNetworkOffline; virtual;
  end;

  TC40_Custom_VM_Client_Pool_Decl = TGenericsList<TC40_Custom_VM_Client>;

  TC40_Custom_VM_Client_Pool = class(TC40_Custom_VM_Client_Pool_Decl)
  public
    procedure Progress;
  end;
{$ENDREGION 'VM_Templet_Define'}
{$REGION 'C40-Console'}

  {
    * Interactive console help for C4 framework.
    * Provides commands to inspect services, tunnels, registrations, instance states,
    * HPC threads, ZNet instances, ZDB2 engines, and more.
    * Can be used for debugging and administration.
  }
  TC40_Console_Help = class(TCore_Object_Intermediate)
  private
    Last_Instance_State: TInstance_State_Tool; { For comparing instance state snapshots. }
    function Do_Build_Instance_State(var OP_Param: TOpParam): Variant; { Saves current instance state. }
    function Do_Compare_Instance_State(var OP_Param: TOpParam): Variant; { Compares current state with saved snapshot. }
  private
    procedure UpdateServiceInfo; overload; { Prints summary of all physics services. }
    procedure UpdateServiceInfo(phy_serv: TC40_PhysicsService); overload; { Prints detailed info of a specific service. }
    procedure UpdateTunnelInfo; overload; { Prints summary of all physics tunnels. }
    procedure UpdateTunnelInfo(phy_tunnel: TC40_PhysicsTunnel); overload; { Prints detailed info of a specific tunnel. }
  protected
    function Do_Help(var OP_Param: TOpParam): Variant; { Displays available commands. }
    function Do_Exit(var OP_Param: TOpParam): Variant; { Exits the console. }
    function Do_Service(var OP_Param: TOpParam): Variant; { Shows service info. }
    function Do_Tunnel(var OP_Param: TOpParam): Variant; { Shows tunnel info. }
    function Do_Reg(var OP_Param: TOpParam): Variant; { Shows registered C4 types. }
    function Do_KillNet(var OP_Param: TOpParam): Variant; { Removes a physics network. }
    function Do_C4_Clean(var OP_Param: TOpParam): Variant; { Cleans all C4 objects. }
    function Do_SetQuiet(var OP_Param: TOpParam): Variant; { Sets quiet mode. }
    function Do_Save_All_C4Service_Config(var OP_Param: TOpParam): Variant; { Saves all service configs. }
    function Do_Save_All_C4Client_Config(var OP_Param: TOpParam): Variant; { Saves all client configs. }
    function Do_Instance_Info(var OP_Param: TOpParam): Variant; { Prints instance tracking info. }
    function Do_Instance_Info_Sort_Update(var OP_Param: TOpParam): Variant; { Sorts by update count. }
    function Do_Instance_Info_Sort_Time(var OP_Param: TOpParam): Variant; { Sorts by update time. }
    function Do_HPC_Thread_Info(var OP_Param: TOpParam): Variant; { Shows HPC thread status. }
    function Do_ZNet_Instance_Info(var OP_Param: TOpParam): Variant; { Shows ZNet instance pool status. }
    function Do_Enabled_Delay_Free_Info(var OP_Param: TOpParam): Variant; { Toggles delay-free tracking. }
    function Do_Enabled_Intermediate_Instance_Info(var OP_Param: TOpParam): Variant; { Toggles intermediate instance tracking. }
    function Do_Service_Cmd_Info(var OP_Param: TOpParam): Variant; { Shows service command statistics. }
    function Do_Client_Cmd_Info(var OP_Param: TOpParam): Variant; { Shows client command statistics. }
    function Do_Service_Statistics_Info(var OP_Param: TOpParam): Variant; { Shows service statistics. }
    function Do_Client_Statistics_Info(var OP_Param: TOpParam): Variant; { Shows client statistics. }
    function Do_ZDB2_Info(var OP_Param: TOpParam): Variant; { Shows ZDB2 thread engine info. }
    function Do_ZDB2_Flush(var OP_Param: TOpParam): Variant; { Flushes all ZDB2 engines. }
    function Do_Custom_Console_Cmd(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant; { Dispatches custom console commands. }
  public
    opRT: TOpCustomRunTime; { Runtime for evaluating expressions. }
    HelpTextStyle: TTextStyle; { Text style for expression parsing. }
    IsExit: Boolean; { True when user requests exit. }
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Update_opRT; virtual; { Registers all help commands in opRT. }
    procedure Run_HelpCmd(exp_: U_String); { Executes a help command string. }
  end;
{$ENDREGION 'C40-Console'}
{$REGION 'Var'}

var
  C40_QuietMode: Boolean; { Global quiet mode for all C4 components. }
  C40_SafeCheckTime: TTimeTick; { Default interval for SafeCheck calls. }
  C40_PhysicsReconnectionDelayTime: Double; { Delay before reconnecting a physics tunnel (seconds). }
  C40_UpdateServiceInfoDelayTime: TTimeTick; { Delay between service info updates. }
  C40_PhysicsServiceTimeout: TTimeTick; { Timeout for physics service idle connections. }
  C40_PhysicsTunnelTimeout: TTimeTick; { Timeout for physics tunnel connections. }
  C40_KillDeadPhysicsConnectionTimeout: TTimeTick; { Timeout before killing dead physics connections. }
  C40_KillIDCFaultTimeout: TTimeTick; { Timeout for killing IDC faulted tunnels. }
  C40_EnablePerServiceDirectory: Boolean; { Default for per-service directories. }
  C40_RootPath: U_String; { Root path for C4 storage. }
  C40_Password: SystemString; { Global password for P2PVM authentication. }
  C40_PhysicsClientClass: TZNet_ClientClass; { Default client class for physics tunnels. }
  C40_Registed: TC40_RegistedDataList; { Global registry of C4 service/client types. }
  C40_PhysicsServicePool: TC40_PhysicsServicePool; { Global pool of physics services. }
  C40_ServicePool: TC40_Custom_ServicePool; { Global pool of custom services. }
  C40_PhysicsTunnelPool: TC40_PhysicsTunnelPool; { Global pool of physics tunnels. }
  C40_ClientPool: TC40_Custom_ClientPool; { Global pool of custom clients. }
  C40_VM_Service_Pool: TC40_Custom_VM_Service_Pool; { Global pool of VM services. }
  C40_VM_Client_Pool: TC40_Custom_VM_Client_Pool; { Global pool of VM clients. }
  C40_Cycle_Order_Seed: Int64 = 0; { Seed for cycle anchor generation. }
  C40_DefaultConfig: THashStringList; { Default configuration. }
  Ignore_Command_Line: TPascalStringList; { Command lines to ignore. }
{$ENDREGION 'Var'}
{$REGION 'API'}

procedure C40Progress(sleep_: TTimeTick); overload; { Drives all C4 progress with optional sleep. }
procedure C40Progress; overload; { Drives all C4 progress with 1ms sleep. }
function C40_Online_DP: TC40_Dispatch_Client; { Returns the first connected dispatch client. }
procedure C40SetQuietMode(QuietMode_: Boolean); { Sets global quiet mode and propagates to all components. }
procedure C40WriteConfig(HS: THashStringList); { Writes current C4 settings to a hash string list. }
procedure C40ReadConfig(HS: THashStringList); { Reads C4 settings from a hash string list. }
procedure C40ResetDefaultConfig; { Resets C4 settings to default. }
procedure C40Clean; { Cleans all C4 objects (services, clients, tunnels, etc.). }
procedure C40Clean_Service; { Cleans only service-side objects. }
procedure C40Clean_Client; { Cleans only client-side objects. }
procedure C40PrintRegistation; { Prints all registered service/client types. }
function C40ExistsPhysicsNetwork(PhysicsAddr: U_String; PhysicsPort: Word): Boolean; { Checks if any physics network exists at address/port. }
function C40_Get_Physics_Connected_Num(): Integer; { Returns total number of active physics connections. }
function C40_Get_Physics_Netowork_Is_Inited_Num(): Integer; { Returns number of physics networks that have been initialized. }
procedure C40RemovePhysics(PhysicsAddr: U_String; PhysicsPort: Word;
  Remove_P2PVM_Client_, Remove_Physics_Client_, RemoveP2PVM_Service_, Remove_Physcis_Service_: Boolean); overload; { Removes physics network components. }
procedure C40RemovePhysics(Tunnel_: TC40_PhysicsTunnel); overload; { Removes a physics tunnel and associated clients. }
procedure C40RemovePhysics(Service_: TC40_PhysicsService); overload; { Removes a physics service and associated objects. }
procedure C40CheckAndKillDeadPhysicsTunnel(); { Checks and removes dead physics tunnels. }
function RegisterC40(ServiceTyp: U_String; ServiceClass: TC40_Custom_Service_Class; ClientClass: TC40_Custom_Client_Class): Boolean; { Registers a service type with its classes. }
function FindRegistedC40(ServiceTyp: U_String): PC40_RegistedData; { Finds registered data for a service type. }
function GetRegisterClientTypFromClass(ClientClass: TC40_Custom_Client_Class): U_String; overload; { Returns service type(s) for a client class. }
function GetRegisterServiceTypFromClass(ClientClass: TC40_Custom_Client_Class): U_String; overload;
function GetRegisterServiceTypFromClass(ServiceClass: TC40_Custom_Service_Class): U_String; overload;
function Compare_C40_ServiceTyp(typ1, typ2: U_String): Boolean; overload; { True if two service type strings have overlapping dependencies. }
function Compare_C40_ServiceTyp(typ1, typ2, typ3: U_String): Boolean; overload; { True if all three have overlapping dependencies. }
function ExtractDependInfo(info: TC40_DependNetworkInfoList): TC40_DependNetworkInfoArray; overload; { Converts a list to an array. }
function ExtractDependInfo(info: U_String): TC40_DependNetworkInfoArray; overload; { Parses a dependency string. }
function ExtractDependInfo(arry: TC40_DependNetworkString): TC40_DependNetworkInfoArray; overload;
function ExtractDependInfoToL(info: U_String): TC40_DependNetworkInfoList; overload; { Parses to a list. }
function ExtractDependInfoToL(arry: TC40_DependNetworkString): TC40_DependNetworkInfoList; overload;
procedure ResetDependInfoBuff(var arry: TC40_DependNetworkInfoArray); { Clears an array. }
function Is_IPC_Addr(ListenAddr_Or_PhysicsAddr: U_String): Boolean; { True if the address is an IPC address (starts with 'ipc:'). }
function Get_Physics_Server_Class(ListenAddr, PhysicsAddr: U_String): TZNet_ServerClass; { Returns the appropriate server class (IPC or Physics). }
function Get_Physics_Client_Class(PhysicsAddr: U_String): TZNet_ClientClass; { Returns the appropriate client class. }

{$ENDREGION 'API'}

implementation

var
  C40Progress_Working: Boolean = False;
  Hooked_OnCheckThreadSynchronize: TOn_Check_Thread_Synchronize;

procedure DoCheckThreadSynchronize();
begin
  if Assigned(Hooked_OnCheckThreadSynchronize) then
    begin
      try
          Hooked_OnCheckThreadSynchronize();
      except
      end;
    end;
  C40Progress();
end;

procedure C40Progress(sleep_: TTimeTick);
var
  state_: Boolean;
begin
  if C40Progress_Working then
      exit;
  C40Progress_Working := True;
  Check_Soft_Thread_Synchronize(sleep_, True);
  state_ := Enabled_Check_Thread_Synchronize_System;
  Enabled_Check_Thread_Synchronize_System := False;
  try
    C40_PhysicsServicePool.Progress;
    C40_PhysicsServicePool.Disable_Progress;
    C40_ServicePool.Progress;
    C40_PhysicsTunnelPool.Progress;
    C40_PhysicsTunnelPool.Disable_Progress;
    C40_ClientPool.Progress;
    C40_VM_Service_Pool.Progress;
    C40_VM_Client_Pool.Progress;
    C40_PhysicsServicePool.Enabled_Progress;
    C40_PhysicsTunnelPool.Enabled_Progress;
    C40CheckAndKillDeadPhysicsTunnel();
  except
  end;
  Enabled_Check_Thread_Synchronize_System := state_;
  C40Progress_Working := False;
end;

procedure C40Progress;
begin
  C40Progress(1);
end;

function C40_Online_DP: TC40_Dispatch_Client;
var
  arry: TC40_Custom_Client_Array;
begin
  arry := C40_ClientPool.SearchClass(TC40_Dispatch_Client, True);
  if length(arry) > 0 then
      Result := arry[0] as TC40_Dispatch_Client
  else
      Result := nil;
  SetLength(arry, 0);
end;

procedure C40SetQuietMode(QuietMode_: Boolean);
  procedure Do_SetQuietMode(Inst: TZNet);
  begin
    Set_Instance_QuietMode(Inst, QuietMode_);
  end;

var
  i: Integer;
  cc: TC40_Custom_Client;
  cs: TC40_Custom_Service;
begin
  C40_QuietMode := QuietMode_;
  for i := 0 to C40_ClientPool.Count - 1 do
    begin
      cc := C40_ClientPool[i];
      if cc is TC40_Dispatch_Client then
        begin
          Do_SetQuietMode(TC40_Dispatch_Client(cc).Client.RecvTunnel);
          Do_SetQuietMode(TC40_Dispatch_Client(cc).Client.SendTunnel);
        end
      else if cc is TC40_Base_NoAuth_Client then
        begin
          Do_SetQuietMode(TC40_Base_NoAuth_Client(cc).Client.RecvTunnel);
          Do_SetQuietMode(TC40_Base_NoAuth_Client(cc).Client.SendTunnel);
        end
      else if cc is TC40_Base_DataStoreNoAuth_Client then
        begin
          Do_SetQuietMode(TC40_Base_DataStoreNoAuth_Client(cc).Client.RecvTunnel);
          Do_SetQuietMode(TC40_Base_DataStoreNoAuth_Client(cc).Client.SendTunnel);
        end
      else if cc is TC40_Base_VirtualAuth_Client then
        begin
          Do_SetQuietMode(TC40_Base_VirtualAuth_Client(cc).Client.RecvTunnel);
          Do_SetQuietMode(TC40_Base_VirtualAuth_Client(cc).Client.SendTunnel);
        end
      else if cc is TC40_Base_DataStoreVirtualAuth_Client then
        begin
          Do_SetQuietMode(TC40_Base_DataStoreVirtualAuth_Client(cc).Client.RecvTunnel);
          Do_SetQuietMode(TC40_Base_DataStoreVirtualAuth_Client(cc).Client.SendTunnel);
        end
      else if cc is TC40_Base_Client then
        begin
          Do_SetQuietMode(TC40_Base_Client(cc).Client.RecvTunnel);
          Do_SetQuietMode(TC40_Base_Client(cc).Client.SendTunnel);
        end
      else if cc is TC40_Base_DataStore_Client then
        begin
          Do_SetQuietMode(TC40_Base_DataStore_Client(cc).Client.RecvTunnel);
          Do_SetQuietMode(TC40_Base_DataStore_Client(cc).Client.SendTunnel);
        end
      else
          DoStatus('C40SetQuietMode no support: %s', [cc.ClassName]);
    end;
  for i := 0 to C40_ServicePool.Count - 1 do
    begin
      cs := C40_ServicePool[i];
      if cs is TC40_Dispatch_Service then
        begin
          Do_SetQuietMode(TC40_Dispatch_Service(cs).Service.RecvTunnel);
          Do_SetQuietMode(TC40_Dispatch_Service(cs).Service.SendTunnel);
        end
      else if cs is TC40_Base_NoAuth_Service then
        begin
          Do_SetQuietMode(TC40_Base_NoAuth_Service(cs).Service.RecvTunnel);
          Do_SetQuietMode(TC40_Base_NoAuth_Service(cs).Service.SendTunnel);
        end
      else if cs is TC40_Base_DataStoreNoAuth_Service then
        begin
          Do_SetQuietMode(TC40_Base_DataStoreNoAuth_Service(cs).Service.RecvTunnel);
          Do_SetQuietMode(TC40_Base_DataStoreNoAuth_Service(cs).Service.SendTunnel);
        end
      else if cs is TC40_Base_VirtualAuth_Service then
        begin
          Do_SetQuietMode(TC40_Base_VirtualAuth_Service(cs).Service.RecvTunnel);
          Do_SetQuietMode(TC40_Base_VirtualAuth_Service(cs).Service.SendTunnel);
        end
      else if cs is TC40_Base_DataStoreVirtualAuth_Service then
        begin
          Do_SetQuietMode(TC40_Base_DataStoreVirtualAuth_Service(cs).Service.RecvTunnel);
          Do_SetQuietMode(TC40_Base_DataStoreVirtualAuth_Service(cs).Service.SendTunnel);
        end
      else if cs is TC40_Base_Service then
        begin
          Do_SetQuietMode(TC40_Base_Service(cs).Service.RecvTunnel);
          Do_SetQuietMode(TC40_Base_Service(cs).Service.SendTunnel);
        end
      else if cs is TC40_Base_DataStore_Service then
        begin
          Do_SetQuietMode(TC40_Base_DataStore_Service(cs).Service.RecvTunnel);
          Do_SetQuietMode(TC40_Base_DataStore_Service(cs).Service.SendTunnel);
        end
      else
          DoStatus('C40SetQuietMode no support: %s', [cs.ClassName]);
    end;
  for i := 0 to C40_PhysicsTunnelPool.Count - 1 do
      Do_SetQuietMode(C40_PhysicsTunnelPool[i].PhysicsTunnel);
  for i := 0 to C40_PhysicsServicePool.Count - 1 do
      Do_SetQuietMode(C40_PhysicsServicePool[i].PhysicsTunnel);
end;

procedure C40WriteConfig(HS: THashStringList);
begin
  HS.SetDefaultValue('Quiet', umlBoolToStr(C40_QuietMode));
  HS.SetDefaultValue('SafeCheckTime', umlIntToStr(C40_SafeCheckTime));
  HS.SetDefaultValue('PhysicsReconnectionDelayTime', umlFloatToStr(C40_PhysicsReconnectionDelayTime));
  HS.SetDefaultValue('UpdateServiceInfoDelayTime', umlIntToStr(C40_UpdateServiceInfoDelayTime));
  HS.SetDefaultValue('PhysicsServiceTimeout', umlIntToStr(C40_PhysicsServiceTimeout));
  HS.SetDefaultValue('PhysicsTunnelTimeout', umlIntToStr(C40_PhysicsTunnelTimeout));
  HS.SetDefaultValue('KillIDCFaultTimeout', umlIntToStr(C40_KillIDCFaultTimeout));
  HS.SetDefaultValue('EnablePerServiceDirectory', umlBoolToStr(C40_EnablePerServiceDirectory));
end;

procedure C40ReadConfig(HS: THashStringList);
begin
  C40SetQuietMode(EStrToBool(HS.GetDefaultValue('Quiet', umlBoolToStr(C40_QuietMode))));
  C40_SafeCheckTime := EStrToInt(HS.GetDefaultValue('SafeCheckTime', umlIntToStr(C40_SafeCheckTime)));
  C40_PhysicsReconnectionDelayTime := EStrToDouble(HS.GetDefaultValue('PhysicsReconnectionDelayTime', umlFloatToStr(C40_PhysicsReconnectionDelayTime)));
  C40_UpdateServiceInfoDelayTime := EStrToInt(HS.GetDefaultValue('UpdateServiceInfoDelayTime', umlIntToStr(C40_UpdateServiceInfoDelayTime)));
  C40_PhysicsServiceTimeout := EStrToInt(HS.GetDefaultValue('PhysicsServiceTimeout', umlIntToStr(C40_PhysicsServiceTimeout)));
  C40_PhysicsTunnelTimeout := EStrToInt(HS.GetDefaultValue('PhysicsTunnelTimeout', umlIntToStr(C40_PhysicsTunnelTimeout)));
  C40_KillIDCFaultTimeout := EStrToInt(HS.GetDefaultValue('KillIDCFaultTimeout', umlIntToStr(C40_KillIDCFaultTimeout)));
  C40_EnablePerServiceDirectory := EStrToBool(HS.GetDefaultValue('EnablePerServiceDirectory', umlBoolToStr(C40_EnablePerServiceDirectory)));
end;

procedure C40ResetDefaultConfig;
begin
  C40ReadConfig(C40_DefaultConfig);
end;

procedure C40Clean;
var
  bak: TOn_Check_Thread_Synchronize;
  i: Integer;
begin
  bak := OnCheckThreadSynchronize;
  OnCheckThreadSynchronize := nil;
  try
    for i := 0 to C40_PhysicsTunnelPool.Count - 1 do
        C40_PhysicsTunnelPool[i].PhysicsTunnel.Disconnect;
    for i := 0 to C40_PhysicsServicePool.Count - 1 do
        C40_PhysicsServicePool[i].StopService;
    for i := 0 to C40_VM_Client_Pool.Count - 1 do
        C40_VM_Client_Pool[i].Disconnect;
    for i := 0 to C40_VM_Service_Pool.Count - 1 do
        C40_VM_Service_Pool[i].StopService;
    while C40_ClientPool.Count > 0 do
        DisposeObject(C40_ClientPool[0]);
    while C40_ServicePool.Count > 0 do
        DisposeObject(C40_ServicePool[0]);
    C40_ServicePool.FIPV6_Seed := 1;
    while C40_PhysicsTunnelPool.Count > 0 do
        DisposeObject(C40_PhysicsTunnelPool[0]);
    while C40_PhysicsServicePool.Count > 0 do
        DisposeObject(C40_PhysicsServicePool[0]);
    while C40_VM_Client_Pool.Count > 0 do
        DisposeObject(C40_VM_Client_Pool[0]);
    while C40_VM_Service_Pool.Count > 0 do
        DisposeObject(C40_VM_Service_Pool[0]);
  finally
      OnCheckThreadSynchronize := bak;
  end;
end;

procedure C40Clean_Service;
var
  bak: TOn_Check_Thread_Synchronize;
  i: Integer;
begin
  bak := OnCheckThreadSynchronize;
  OnCheckThreadSynchronize := nil;
  try
    for i := 0 to C40_PhysicsServicePool.Count - 1 do
        C40_PhysicsServicePool[i].StopService;
    for i := 0 to C40_VM_Service_Pool.Count - 1 do
        C40_VM_Service_Pool[i].StopService;
    while C40_ServicePool.Count > 0 do
        DisposeObject(C40_ServicePool[0]);
    C40_ServicePool.FIPV6_Seed := 1;
    while C40_PhysicsServicePool.Count > 0 do
        DisposeObject(C40_PhysicsServicePool[0]);
    while C40_VM_Service_Pool.Count > 0 do
        DisposeObject(C40_VM_Service_Pool[0]);
  finally
      OnCheckThreadSynchronize := bak;
  end;
end;

procedure C40Clean_Client;
var
  bak: TOn_Check_Thread_Synchronize;
  i: Integer;
begin
  bak := OnCheckThreadSynchronize;
  OnCheckThreadSynchronize := nil;
  try
    for i := 0 to C40_PhysicsTunnelPool.Count - 1 do
        C40_PhysicsTunnelPool[i].PhysicsTunnel.Disconnect;
    for i := 0 to C40_VM_Client_Pool.Count - 1 do
        C40_VM_Client_Pool[i].Disconnect;
    while C40_ClientPool.Count > 0 do
        DisposeObject(C40_ClientPool[0]);
    while C40_PhysicsTunnelPool.Count > 0 do
        DisposeObject(C40_PhysicsTunnelPool[0]);
    while C40_VM_Client_Pool.Count > 0 do
        DisposeObject(C40_VM_Client_Pool[0]);
  finally
      OnCheckThreadSynchronize := bak;
  end;
end;

procedure C40PrintRegistation;
begin
  C40_Registed.Print;
end;

function C40ExistsPhysicsNetwork(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
begin
  Result := True;
  if
    C40_PhysicsServicePool.ExistsPhysicsAddr(PhysicsAddr, PhysicsPort) or
    C40_ServicePool.ExistsPhysicsAddr(PhysicsAddr, PhysicsPort) or
    C40_PhysicsTunnelPool.ExistsPhysicsAddr(PhysicsAddr, PhysicsPort) or
    C40_ClientPool.ExistsPhysicsAddr(PhysicsAddr, PhysicsPort) then
      exit;
  Result := False;
end;

function C40_Get_Physics_Connected_Num(): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to C40_PhysicsServicePool.Count - 1 do
      inc(Result, C40_PhysicsServicePool[i].PhysicsTunnel.Count);
  inc(Result, C40_Get_Physics_Netowork_Is_Inited_Num);
end;

function C40_Get_Physics_Netowork_Is_Inited_Num(): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to C40_PhysicsTunnelPool.Count - 1 do
    if C40_PhysicsTunnelPool[i].FNetwork_Already_Inited then
        inc(Result, 1);
end;

procedure C40RemovePhysics(PhysicsAddr: U_String; PhysicsPort: Word;
  Remove_P2PVM_Client_, Remove_Physics_Client_, RemoveP2PVM_Service_, Remove_Physcis_Service_: Boolean);
var
  i: Integer;
begin
  if Remove_P2PVM_Client_ then
    begin
      try
        i := 0;
        while i < C40_ClientPool.Count do
          if PhysicsAddr.Same(@C40_ClientPool[i].ClientInfo.PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = C40_ClientPool[i].ClientInfo.PhysicsPort)) then
            begin
              DisposeObject(C40_ClientPool[i]);
              i := 0;
            end
          else
              inc(i);
      except
      end;
    end;
  for i := 0 to C40_ClientPool.Count - 1 do
    if C40_ClientPool[i] is TC40_Dispatch_Client then
        TC40_Dispatch_Client(C40_ClientPool[i]).Service_Info_Pool.RemovePhysicsAddr(PhysicsAddr, PhysicsPort);
  if Remove_Physics_Client_ then
    begin
      try
        i := 0;
        while i < C40_PhysicsTunnelPool.Count do
          begin
            if PhysicsAddr.Same(@C40_PhysicsTunnelPool[i].PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = C40_PhysicsTunnelPool[i].PhysicsPort)) then
              begin
                DisposeObject(C40_PhysicsTunnelPool[i]);
                i := 0;
              end
            else
                inc(i);
          end;
      except
      end;
    end;
  if RemoveP2PVM_Service_ then
    begin
      try
        i := 0;
        while i < C40_ServicePool.Count do
          if PhysicsAddr.Same(@C40_ServicePool[i].ServiceInfo.PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = C40_ServicePool[i].ServiceInfo.PhysicsPort)) then
            begin
              DisposeObject(C40_ServicePool[i]);
              i := 0;
            end
          else
              inc(i);
      except
      end;
    end;
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i] is TC40_Dispatch_Service then
        TC40_Dispatch_Service(C40_ServicePool[i]).Service_Info_Pool.RemovePhysicsAddr(PhysicsAddr, PhysicsPort);
  if Remove_Physcis_Service_ then
    begin
      try
        i := 0;
        while i < C40_PhysicsServicePool.Count do
          begin
            if PhysicsAddr.Same(@C40_PhysicsServicePool[i].PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = C40_PhysicsServicePool[i].PhysicsPort)) then
              begin
                DisposeObject(C40_PhysicsServicePool[i]);
                i := 0;
              end
            else
                inc(i);
          end;
      except
      end;
    end;
end;

procedure C40RemovePhysics(Tunnel_: TC40_PhysicsTunnel);
begin
  C40RemovePhysics(Tunnel_.PhysicsAddr, Tunnel_.PhysicsPort, True, True, False, False);
end;

procedure C40RemovePhysics(Service_: TC40_PhysicsService);
begin
  C40RemovePhysics(Service_.PhysicsAddr, Service_.PhysicsPort, True, True, True, True);
end;

procedure C40CheckAndKillDeadPhysicsTunnel();
var
  i: Integer;
  tmp: TC40_PhysicsTunnel;
begin
  i := 0;
  while i < C40_PhysicsTunnelPool.Count do
    begin
      tmp := C40_PhysicsTunnelPool[i];
      if (not tmp.PhysicsTunnel.RemoteInited) and (not tmp.FNetwork_Already_Inited) and
        (tmp.FOfflineTime > 0) and (GetTimeTick - tmp.FOfflineTime > C40_KillDeadPhysicsConnectionTimeout) then
        begin
          C40RemovePhysics(tmp);
          i := 0;
        end
      else if (not tmp.PhysicsTunnel.RemoteInited) and (tmp.FNetwork_Already_Inited) and
        (tmp.FOfflineTime > 0) and ((C40_KillIDCFaultTimeout > 0) and (GetTimeTick - tmp.FOfflineTime > C40_KillIDCFaultTimeout)) then
        begin
          C40RemovePhysics(tmp);
          i := 0;
        end
      else
          inc(i);
    end;
end;

function RegisterC40(ServiceTyp: U_String; ServiceClass: TC40_Custom_Service_Class; ClientClass: TC40_Custom_Client_Class): Boolean;
var
  i: Integer;
  p: PC40_RegistedData;
begin
  Result := False;
  p := nil;
  for i := 0 to C40_Registed.Count - 1 do
    if ServiceTyp.Same(@C40_Registed[i]^.ServiceTyp) then
      begin
        p := C40_Registed[i];
        break;
      end;
  if p = nil then
    begin
      new(p);
      p^.ServiceTyp := ServiceTyp;
      p^.ServiceClass := nil;
      p^.ClientClass := nil;
      C40_Registed.Add(p);
    end;
  if ServiceClass <> nil then
      p^.ServiceClass := ServiceClass;
  if ClientClass <> nil then
      p^.ClientClass := ClientClass;
  Result := True;
end;

function FindRegistedC40(ServiceTyp: U_String): PC40_RegistedData;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to C40_Registed.Count - 1 do
    if ServiceTyp.Same(@C40_Registed[i]^.ServiceTyp) then
      begin
        Result := C40_Registed[i];
        exit;
      end;
end;

function GetRegisterClientTypFromClass(ClientClass: TC40_Custom_Client_Class): U_String;
var
  i: Integer;
  p: PC40_RegistedData;
begin
  Result := '';
  for i := 0 to C40_Registed.Count - 1 do
    begin
      p := C40_Registed[i];
      if p^.ClientClass.InheritsFrom(ClientClass) then
        begin
          if Result.L > 0 then
              Result.Append('|');
          Result.Append(p^.ServiceTyp);
        end;
    end;
end;

function GetRegisterServiceTypFromClass(ClientClass: TC40_Custom_Client_Class): U_String;
begin
  Result := GetRegisterClientTypFromClass(ClientClass);
end;

function GetRegisterServiceTypFromClass(ServiceClass: TC40_Custom_Service_Class): U_String;
var
  i: Integer;
  p: PC40_RegistedData;
begin
  Result := '';
  for i := 0 to C40_Registed.Count - 1 do
    begin
      p := C40_Registed[i];
      if p^.ServiceClass.InheritsFrom(ServiceClass) then
        begin
          if Result.L > 0 then
              Result.Append('|');
          Result.Append(p^.ServiceTyp);
        end;
    end;
end;

function Compare_C40_ServiceTyp(typ1, typ2: U_String): Boolean;
var
  arry_1, arry_2: TC40_DependNetworkInfoArray;
  i, j: Integer;
begin
  Result := False;
  arry_1 := ExtractDependInfo(typ1);
  arry_2 := ExtractDependInfo(typ2);
  try
    for i := 0 to length(arry_1) - 1 do
      for j := 0 to length(arry_2) - 1 do
        if arry_1[i].Typ.Same(@arry_2[j].Typ) then
          begin
            Result := True;
            exit;
          end;
  finally
    ResetDependInfoBuff(arry_1);
    ResetDependInfoBuff(arry_2);
  end;
end;

function Compare_C40_ServiceTyp(typ1, typ2, typ3: U_String): Boolean;
begin
  Result :=
    Compare_C40_ServiceTyp(typ1, typ2) and
    Compare_C40_ServiceTyp(typ1, typ3) and
    Compare_C40_ServiceTyp(typ2, typ3);
end;

function ExtractDependInfo(info: TC40_DependNetworkInfoList): TC40_DependNetworkInfoArray;
var
  i: Integer;
begin
  SetLength(Result, info.Count);
  for i := 0 to info.Count - 1 do
      Result[i] := info[i];
end;

function ExtractDependInfo(info: U_String): TC40_DependNetworkInfoArray;
var
  tmp: TC40_DependNetworkString;
begin
  umlGetSplitArray(info, tmp, '|<>');
  Result := ExtractDependInfo(tmp);
  SetLength(tmp, 0);
end;

function ExtractDependInfo(arry: TC40_DependNetworkString): TC40_DependNetworkInfoArray;
var
  i: Integer;
  info_: TC40_DependNetworkInfo;
begin
  SetLength(Result, length(arry));
  for i := 0 to length(arry) - 1 do
    begin
      info_.Typ := umlTrimSpace(umlGetFirstStr(arry[i], '@'));
      info_.Param := umlTrimSpace(umlDeleteFirstStr(arry[i], '@'));
      Result[i] := info_;
    end;
end;

function ExtractDependInfoToL(info: U_String): TC40_DependNetworkInfoList;
var
  tmp: TC40_DependNetworkString;
begin
  umlGetSplitArray(info, tmp, '|<>');
  Result := ExtractDependInfoToL(tmp);
  SetLength(tmp, 0);
end;

function ExtractDependInfoToL(arry: TC40_DependNetworkString): TC40_DependNetworkInfoList;
var
  i: Integer;
  info_: TC40_DependNetworkInfo;
begin
  Result := TC40_DependNetworkInfoList.Create;
  for i := 0 to length(arry) - 1 do
    begin
      info_.Typ := umlTrimSpace(umlGetFirstStr(arry[i], '@'));
      info_.Param := umlTrimSpace(umlDeleteFirstStr(arry[i], '@'));
      Result.Add(info_);
    end;
end;

procedure ResetDependInfoBuff(var arry: TC40_DependNetworkInfoArray);
var
  i: Integer;
begin
  for i := low(arry) to high(arry) do
    begin
      arry[i].Typ := '';
      arry[i].Param := '';
    end;
  SetLength(arry, 0);
end;

function Is_IPC_Addr(ListenAddr_Or_PhysicsAddr: U_String): Boolean;
begin
  Result := umlMultipleMatch('ipc:*', umlTrimSpace(ListenAddr_Or_PhysicsAddr));
end;

function Get_Physics_Server_Class(ListenAddr, PhysicsAddr: U_String): TZNet_ServerClass;
begin
  if Is_IPC_Addr(ListenAddr) or Is_IPC_Addr(PhysicsAddr) then
      Result := TZNet_Server_IPC
  else
      Result := TPhysicsServer;
end;

function Get_Physics_Client_Class(PhysicsAddr: U_String): TZNet_ClientClass;
begin
  if Is_IPC_Addr(PhysicsAddr) then
      Result := TZNet_Client_IPC
  else
      Result := C40_PhysicsClientClass;
end;

procedure TC40_PhysicsService.cmd_QueryInfo(Sender: TPeerIO; InData, OutData: TDFE);
var
  i: Integer;
  L: TC40_InfoList;
  r_physics_addr: U_String;
  r_physics_port: Word;
begin
  if InData.Count >= 2 then
    begin
      r_physics_addr := InData.R.ReadString;
      r_physics_port := InData.R.ReadWord;
    end
  else
    begin
      r_physics_addr := PhysicsAddr;
      r_physics_port := PhysicsPort;
    end;
  L := TC40_InfoList.Create(True);
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i].C40PhysicsService.Activted then
      begin
        if L.FindSame(C40_ServicePool[i].ServiceInfo) = nil then
            L.Add(C40_ServicePool[i].ServiceInfo.Clone);
        if C40_ServicePool[i] is TC40_Dispatch_Service then
            L.MergeAndUpdateWorkload(TC40_Dispatch_Service(C40_ServicePool[i]).Service_Info_Pool);
      end;
  for i := 0 to C40_ClientPool.Count - 1 do
    if C40_ClientPool[i] is TC40_Dispatch_Client then
        L.MergeAndUpdateWorkload(TC40_Dispatch_Client(C40_ClientPool[i]).Service_Info_Pool);
  if not r_physics_addr.Same(PhysicsAddr) then
    begin
      for i := L.Count - 1 downto 0 do
        if L[i].SamePhysicsAddr([PhysicsAddr, '0.0.0.0', 'localhost', '127.0.0.1', '::', '::1', '']) then
            L[i].PhysicsAddr := r_physics_addr
        else
            L.Delete(i);
    end;
  L.SaveToDF(OutData);
  DisposeObject(L);
end;

constructor TC40_PhysicsService.Create(ListeningAddr_, PhysicsAddr_: U_String; PhysicsPort_: Word; PhysicsTunnel_: TZNet_Server);
var
  Listen_, Host_, Port_: U_String;
begin
  inherited Create;
  FActivted := False;
  Listen_ := ListeningAddr_;
  Host_ := PhysicsAddr_;
  Port_ := umlIntToStr(PhysicsPort_);
  if (not Is_IPC_Addr(Host_.Text)) and (not Is_IPC_Addr(Listen_.Text)) then
    begin
      ExtractHostAddress(Host_, Port_);
      ExtractHostAddress(Listen_, Port_);
    end;
  ListeningAddr := umlTrimSpace(Listen_);
  PhysicsAddr := umlTrimSpace(Host_);
  PhysicsPort := EStrToInt(Port_);
  PhysicsTunnel := PhysicsTunnel_;
  PhysicsTunnel.AutomatedP2PVMAuthToken := C40_Password;
  PhysicsTunnel.TimeOutKeepAlive := True;
  if not IPC_Mode then
    begin
      PhysicsTunnel.IdleTimeOut := C40_PhysicsServiceTimeout;
    end;
  PhysicsTunnel.RegisterStream('QueryInfo').OnExecute := cmd_QueryInfo;
  PhysicsTunnel.PrintParams['QueryInfo'] := False;
  PhysicsTunnel.QuietMode := C40_QuietMode;
  AutoFreePhysicsTunnel := False;
  DependNetworkServicePool := TC40_Custom_ServicePool.Create;
  OnEvent := nil;
  C40_PhysicsServicePool.Add(Self);
  FLastDeadConnectionCheckTime_ := GetTimeTick;
end;

constructor TC40_PhysicsService.Create(PhysicsAddr_: U_String; PhysicsPort_: Word; PhysicsTunnel_: TZNet_Server);
begin
  Create(PhysicsAddr_, PhysicsAddr_, PhysicsPort_, PhysicsTunnel_);
end;

destructor TC40_PhysicsService.Destroy;
begin
  try
      StopService;
  except
  end;
  try
      OnEvent := nil;
  except
  end;
  C40_PhysicsServicePool.Remove(Self);
  PhysicsTunnel.DeleteRegistedCMD('QueryInfo');
  DisposeObject(DependNetworkServicePool);
  if AutoFreePhysicsTunnel then
      DisposeObject(PhysicsTunnel);
  inherited Destroy;
end;

procedure TC40_PhysicsService.Progress;
var
  arry: TIO_Array;
  ID_: Cardinal;
  IO_: TPeerIO;
begin
  if GetTimeTick - FLastDeadConnectionCheckTime_ > 1000 then
    begin
      PhysicsTunnel.GetIO_Array(arry);
      for ID_ in arry do
        begin
          IO_ := PhysicsTunnel.PeerIO[ID_];
          if (IO_ <> nil) and (not IO_.p2pVMTunnelReadyOk)
            and (GetTimeTick - IO_.IO_Create_TimeTick > C40_KillDeadPhysicsConnectionTimeout) then
              IO_.Disconnect;
        end;
      FLastDeadConnectionCheckTime_ := GetTimeTick;
    end;
  PhysicsTunnel.Progress;
end;

function TC40_PhysicsService.IPC_Mode: Boolean;
begin
  Result := PhysicsTunnel is TZNet_Server_IPC;
end;

function TC40_PhysicsService.BuildDependNetwork(const Depend_: TC40_DependNetworkInfoArray): Boolean;
var
  i: Integer;
  p: PC40_RegistedData;
  tmp: TC40_Custom_Service;
begin
  Result := False;
  for i := 0 to length(Depend_) - 1 do
    begin
      p := FindRegistedC40(Depend_[i].Typ);
      if p = nil then
        begin
          PhysicsTunnel.Print('no found Registed service "%s"', [Depend_[i].Typ.Text]);
          exit;
        end;
      tmp := p^.ServiceClass.Create(Self, p^.ServiceTyp, Depend_[i].Param);
      PhysicsTunnel.Print('Build Depend service "%s" instance class "%s"', [tmp.ServiceInfo.ServiceTyp.Text, tmp.ClassName]);
      PhysicsTunnel.Print('service %s p2pVM Received tunnel ip %s port: %d', [tmp.ServiceInfo.ServiceTyp.Text, tmp.ServiceInfo.p2pVM_RecvTunnel_Addr.Text, tmp.ServiceInfo.p2pVM_RecvTunnel_Port]);
      PhysicsTunnel.Print('service %s p2pVM Send tunnel ip %s port: %d', [tmp.ServiceInfo.ServiceTyp.Text, tmp.ServiceInfo.p2pVM_SendTunnel_Addr.Text, tmp.ServiceInfo.p2pVM_SendTunnel_Port]);
      if Assigned(OnEvent) then
          OnEvent.C40_PhysicsService_Build_Network(Self, tmp);
    end;
  Result := True;
end;

function TC40_PhysicsService.BuildDependNetwork(const Depend_: TC40_DependNetworkString): Boolean;
var
  tmp: TC40_DependNetworkInfoArray;
begin
  tmp := ExtractDependInfo(Depend_);
  Result := BuildDependNetwork(tmp);
  ResetDependInfoBuff(tmp);
end;

function TC40_PhysicsService.BuildDependNetwork(const Depend_: U_String): Boolean;
var
  tmp: TC40_DependNetworkInfoArray;
begin
  tmp := ExtractDependInfo(Depend_);
  Result := BuildDependNetwork(tmp);
  ResetDependInfoBuff(tmp);
end;

procedure TC40_PhysicsService.StartService;
begin
  try
      FActivted := PhysicsTunnel.StartService(ListeningAddr, PhysicsPort);
  except
      FActivted := False;
  end;
  if FActivted then
    begin
      PhysicsTunnel.Print('Physics Service Listening successed, internet addr: %s port: %d', [ListeningAddr.Text, PhysicsPort]);
      if Assigned(OnEvent) then
          OnEvent.C40_PhysicsService_Start(Self);
    end
  else
      PhysicsTunnel.Print('Physics Service Listening failed, internet addr: %s port: %d', [ListeningAddr.Text, PhysicsPort]);
end;

procedure TC40_PhysicsService.StopService;
begin
  if not FActivted then
      exit;
  try
      PhysicsTunnel.StopService;
  except
  end;
  FActivted := False;
  PhysicsTunnel.Print('Physics Service Listening Stop.', []);
  if Assigned(OnEvent) then
      OnEvent.C40_PhysicsService_Stop(Self);
  FActivted := False;
end;

procedure TC40_PhysicsService.DoLinkSuccess(Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);
begin
  if Assigned(OnEvent) then
      OnEvent.C40_PhysicsService_LinkSuccess(Self, Custom_Service_, Trigger_);
end;

procedure TC40_PhysicsService.DoUserOut(Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);
begin
  if Assigned(OnEvent) then
      OnEvent.C40_PhysicsService_UserOut(Self, Custom_Service_, Trigger_);
end;

procedure TC40_PhysicsServicePool.Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    begin
      try
          Items[i].Progress;
      except
      end;
    end;
end;

procedure TC40_PhysicsServicePool.Enabled_Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
      Items[i].PhysicsTunnel.Enabled_Progress;
end;

procedure TC40_PhysicsServicePool.Disable_Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
      Items[i].PhysicsTunnel.Disable_Progress;
end;

function TC40_PhysicsServicePool.ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if PhysicsAddr.Same(@Items[i].PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].PhysicsPort)) then
        exit;
  Result := False;
end;

function TC40_PhysicsServicePool.ExistsListenAddr(ListenAddr: U_String; Port: Word): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if ListenAddr.Same(@Items[i].ListeningAddr) and ((Port = 0) or (Port = Items[i].PhysicsPort)) then
        exit;
  Result := False;
end;

procedure TC40_PhysicsServicePool.GetRS(var recv, send: Int64);
var
  i: Integer;
  s: TC40_PhysicsService;
begin
  for i := 0 to Count - 1 do
    begin
      s := Items[i];
      inc(recv, s.PhysicsTunnel.Statistics[stReceiveSize]);
      inc(send, s.PhysicsTunnel.Statistics[stSendSize]);
    end;
end;

procedure TDCT40_QueryResultData.DoStreamParam(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE);
begin
  L.MergeFromDF(Result_);
  DoRun;
end;

procedure TDCT40_QueryResultData.DoStreamFailed(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE);
begin
  DoRun;
end;

procedure TDCT40_QueryResultData.DoRun;
begin
  try
    if Assigned(OnResultC) then
        OnResultC(C40_PhysicsTunnel, L)
    else if Assigned(OnResultM) then
        OnResultM(C40_PhysicsTunnel, L)
    else if Assigned(OnResultP) then
        OnResultP(C40_PhysicsTunnel, L);
  except
  end;
  DelayFreeObj(1.0, Self);
end;

constructor TDCT40_QueryResultData.Create;
begin
  inherited Create;
  C40_PhysicsTunnel := nil;
  L := TC40_InfoList.Create(True);
  OnResultC := nil;
  OnResultM := nil;
  OnResultP := nil;
end;

destructor TDCT40_QueryResultData.Destroy;
begin
  DisposeObject(L);
  inherited Destroy;
end;

procedure TDCT40_QueryResultAndDependProcessor.DCT40_OnCheckDepend(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
var
  i: Integer;
  state: Boolean;
begin
  state := True;
  for i := 0 to length(Sender.DependNetworkInfoArray) - 1 do
    begin
      if L.ExistsService(Sender.DependNetworkInfoArray[i].Typ) then
        begin
          Sender.PhysicsTunnel.Print('Check addr %s port:%d service "%s" passed.', [Sender.PhysicsAddr.Text, Sender.PhysicsPort, Sender.DependNetworkInfoArray[i].Typ.Text]);
        end
      else
        begin
          Sender.PhysicsTunnel.Print('failed! Check addr %s port:%d no found service "%s".', [Sender.PhysicsAddr.Text, Sender.PhysicsPort, Sender.DependNetworkInfoArray[i].Typ.Text]);
          state := False;
        end;
    end;
  DoRun(state);
end;

procedure TDCT40_QueryResultAndDependProcessor.DCT40_OnAutoP2PVMConnectionDone(Sender: TZNet; P_IO: TPeerIO);
var
  i: Integer;
begin
  Sender.AutomatedP2PVMClient := True;
  for i := 0 to C40_PhysicsTunnel.DependNetworkClientPool.Count - 1 do
    with C40_PhysicsTunnel.DependNetworkClientPool[i] do
      if not Connected then
          Connect;
  C40_PhysicsTunnel.FWait_Build_Depend_Network := False;
  C40_PhysicsTunnel.FNetwork_Already_Inited := True;
  C40_PhysicsTunnel.FOfflineTime := 0;
  DoRun(True);
end;

procedure TDCT40_QueryResultAndDependProcessor.DCT40_OnBuildDependNetwork(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
var
  i, j: Integer;
  found_: Integer;
  tmp: TC40_Custom_Client;
begin
  found_ := 0;
  for i := 0 to length(Sender.DependNetworkInfoArray) - 1 do
    if L.ExistsService(Sender.DependNetworkInfoArray[i].Typ) then
        inc(found_);
  if found_ = 0 then
    begin
      DoRun(False);
      exit;
    end;
  found_ := 0;
  for i := 0 to length(Sender.DependNetworkInfoArray) - 1 do
    for j := 0 to L.Count - 1 do
      begin
        if L[j].SamePhysicsAddr(Sender) and L[j].ServiceTyp.Same(@Sender.DependNetworkInfoArray[i].Typ) and
          (not Sender.DependNetworkClientPool.ExistsServiceInfo(L[j])) then
          begin
            tmp := L[j].GetOrCreateC40Client(Sender, Sender.DependNetworkInfoArray[i].Param);
            if tmp <> nil then
              begin
                Sender.PhysicsTunnel.Print('build "%s" network done.', [L[j].ServiceTyp.Text]);
                Sender.PhysicsTunnel.Print('"%s" network physics address "%s" physics port "%d" DCT40 Class:%s',
                  [L[j].ServiceTyp.Text, Sender.PhysicsAddr.Text, Sender.PhysicsPort, tmp.ClassName]);
                Sender.PhysicsTunnel.Print('"%s" network p2pVM Received Tunnel IPV6 "%s" Port:%d',
                  [L[j].ServiceTyp.Text, L[j].p2pVM_RecvTunnel_Addr.Text, L[j].PhysicsPort]);
                Sender.PhysicsTunnel.Print('"%s" network p2pVM Send Tunnel IPV6 "%s" Port:%d',
                  [L[j].ServiceTyp.Text, L[j].p2pVM_SendTunnel_Addr.Text, L[j].PhysicsPort]);
                if Assigned(C40_PhysicsTunnel.OnEvent) then
                    C40_PhysicsTunnel.OnEvent.C40_PhysicsTunnel_Build_Network(C40_PhysicsTunnel, tmp);
                inc(found_);
              end
            else
              begin
                Sender.PhysicsTunnel.Print('build "%s" network error.', [L[j].ServiceTyp.Text]);
              end;
          end;
      end;
  if found_ > 0 then
    begin
      Sender.PhysicsTunnel.OnAutomatedP2PVMClientConnectionDone_M := DCT40_OnAutoP2PVMConnectionDone;
      Sender.PhysicsTunnel.AutomatedP2PVM_Open(Sender.PhysicsTunnel.ClientIO);
    end;
end;

procedure TDCT40_QueryResultAndDependProcessor.DoRun(const state: Boolean);
begin
  if Assigned(On_C) then
      On_C(state)
  else if Assigned(On_M) then
      On_M(state)
  else if Assigned(On_P) then
      On_P(state);
  DelayFreeObj(1.0, Self);
end;

constructor TDCT40_QueryResultAndDependProcessor.Create;
begin
  inherited Create;
  C40_PhysicsTunnel := nil;
  On_C := nil;
  On_M := nil;
  On_P := nil;
end;

destructor TDCT40_QueryResultAndDependProcessor.Destroy;
begin
  inherited Destroy;
end;

procedure TC40_PhysicsTunnel.DoDelayConnect;
begin
  if PhysicsTunnel.RemoteInited then
    begin
      FIsConnecting := False;
      exit;
    end;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, DoConnectOnResult);
end;

procedure TC40_PhysicsTunnel.DoConnectOnResult(const state: Boolean);
begin
  if not FNetwork_Already_Inited then
    begin
      if state then
        begin
          PhysicsTunnel.Print('Physics Tunnel connection successed, internet addr: %s port: %d', [PhysicsAddr.Text, PhysicsPort]);
        end
      else
        begin
          FWait_Build_Depend_Network := False;
          PhysicsTunnel.Print('Physics Tunnel connection failed, internet addr: %s port: %d', [PhysicsAddr.Text, PhysicsPort]);
        end;
    end;
  FIsConnecting := False;
end;

procedure TC40_PhysicsTunnel.DoConnectAndQuery(Param1: Pointer; Param2: TObject; const state: Boolean);
var
  tmp: TDCT40_QueryResultData;
  D: TDFE;
begin
  DoConnectOnResult(state);
  tmp := TDCT40_QueryResultData(Param2);
  if state then
    begin
      D := TDFE.Create;
      D.WriteString(PhysicsAddr);
      D.WriteWORD(PhysicsPort);
      PhysicsTunnel.SendStreamCmdM('QueryInfo', D, nil, nil, tmp.DoStreamParam, tmp.DoStreamFailed);
      DisposeObject(D);
    end
  else
    begin
      try
          tmp.DoRun;
      except
      end;
    end;
end;

procedure TC40_PhysicsTunnel.DoConnectAndCheckDepend(Param1: Pointer; Param2: TObject; const state: Boolean);
var
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  DoConnectOnResult(state);
  tmp := TDCT40_QueryResultAndDependProcessor(Param2);
  if state then
    begin
      QueryInfoM(tmp.DCT40_OnCheckDepend);
    end
  else
    begin
      try
          tmp.DoRun(state);
      except
      end;
    end;
end;

procedure TC40_PhysicsTunnel.DoConnectAndBuildDependNetwork(Param1: Pointer; Param2: TObject; const state: Boolean);
var
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  DoConnectOnResult(state);
  tmp := TDCT40_QueryResultAndDependProcessor(Param2);
  if state then
    begin
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
    end
  else
    begin
      try
          tmp.DoRun(state);
      except
      end;
    end;
end;

procedure TC40_PhysicsTunnel.Do_Connect_Event;
begin
  try
    if Assigned(OnEvent) then
        OnEvent.C40_PhysicsTunnel_Connected(Self);
  except
  end;
end;

procedure TC40_PhysicsTunnel.Do_Disconnect_Event;
begin
  try
    if Assigned(OnEvent) then
        OnEvent.C40_PhysicsTunnel_Disconnect(Self);
  except
  end;
  Do_Notify_All_Disconnect;
end;

procedure TC40_PhysicsTunnel.ClientConnected(Sender: TZNet_Client);
begin
  Main_Thread_Sync_Tool.Synchronize_M(Do_Connect_Event);
end;

procedure TC40_PhysicsTunnel.ClientDisconnect(Sender: TZNet_Client);
begin
  Main_Thread_Sync_Tool.Synchronize_M(Do_Disconnect_Event);
end;

procedure TC40_PhysicsTunnel.Do_Notify_All_Disconnect;
var
  i: Integer;
begin
  try
    for i := 0 to DependNetworkClientPool.Count - 1 do
        DependNetworkClientPool[i].DoNetworkOffline;
  except
  end;
end;

constructor TC40_PhysicsTunnel.Create(Addr_: U_String; Port_: Word);
var
  i: Integer;
begin
  inherited Create;
  FLast_Delay_Connecting_Time := 0;
  FIsConnecting := False;
  FWait_Build_Depend_Network := False;
  FNetwork_Already_Inited := False;
  FOfflineTime := GetTimeTick;
  PhysicsAddr := umlTrimSpace(Addr_);
  PhysicsPort := Port_;
  PhysicsTunnel := Get_Physics_Client_Class(Addr_).Create;
  PhysicsTunnel.AutomatedP2PVMAuthToken := C40_Password;
  PhysicsTunnel.SyncOnResult := False;
  PhysicsTunnel.SyncOnCompleteBuffer := True;
  PhysicsTunnel.TimeOutKeepAlive := True;
  if not IPC_Mode then
    begin
      PhysicsTunnel.IdleTimeOut := C40_PhysicsTunnelTimeout;
      PhysicsTunnel.SwitchDefaultPerformance;
    end;
  PhysicsTunnel.OnInterface := Self;
  PhysicsTunnel.PrintParams['QueryInfo'] := False;
  PhysicsTunnel.QuietMode := C40_QuietMode;
  SetLength(DependNetworkInfoArray, 0);
  DependNetworkClientPool := TC40_Custom_ClientPool.Create;
  OnEvent := nil;
  C40_PhysicsTunnelPool.Add(Self);
end;

destructor TC40_PhysicsTunnel.Destroy;
var
  i: Integer;
begin
  try
    PhysicsTunnel.OnInterface := nil;
    if PhysicsTunnel.Connected then
      begin
        PhysicsTunnel.Disconnect;
        Do_Notify_All_Disconnect();
      end;
  except
  end;
  try
      OnEvent := nil;
  except
  end;
  i := 0;
  while i < C40_ClientPool.Count do
    begin
      if C40_ClientPool[i].C40PhysicsTunnel = Self then
          DisposeObject(C40_ClientPool[i])
      else
          inc(i);
    end;
  C40_PhysicsTunnelPool.Remove(Self);
  PhysicsAddr := '';
  SetLength(DependNetworkInfoArray, 0);
  DisposeObject(DependNetworkClientPool);
  DisposeObject(PhysicsTunnel);
  inherited Destroy;
end;

procedure TC40_PhysicsTunnel.Progress;
begin
  PhysicsTunnel.Progress;
  if FIsConnecting then
    begin
      if GetTimeTick - FLast_Delay_Connecting_Time > C40_PhysicsTunnelTimeout then
        begin
          FIsConnecting := False;
          FLast_Delay_Connecting_Time := GetTimeTick;
        end;
    end;
  if FNetwork_Already_Inited and (not FIsConnecting) and (not PhysicsTunnel.RemoteInited) then
    begin
      FIsConnecting := True;
      FLast_Delay_Connecting_Time := GetTimeTick;
      PhysicsTunnel.PostProgress.PostExecuteM_NP(C40_PhysicsReconnectionDelayTime, DoDelayConnect);
    end
  else if FNetwork_Already_Inited and (not FIsConnecting) and PhysicsTunnel.RemoteInited then
      FOfflineTime := GetTimeTick;
  if (FOfflineTime = 0) and (not PhysicsTunnel.RemoteInited) then
      FOfflineTime := GetTimeTick;
end;

function TC40_PhysicsTunnel.IPC_Mode: Boolean;
begin
  Result := PhysicsTunnel is TZNet_Client_IPC;
end;

function TC40_PhysicsTunnel.IsLocalNetwork: Boolean;
begin
  Result := False;
  if IPC_Mode then
      exit;
  Result := Z.Net.IsLocalNetworkIPV4(PhysicsAddr);
end;

function TC40_PhysicsTunnel.IsLoopbackNetwork: Boolean;
begin
  Result := False;
  if IPC_Mode then
      exit;
  Result := Z.Net.IsLoopbackIPV4(PhysicsAddr) or Z.Net.IsLoopbackIPV6(PhysicsAddr);
end;

function TC40_PhysicsTunnel.ResetDepend(const Depend_: TC40_DependNetworkInfoArray): Boolean;
var
  i: Integer;
begin
  SetLength(DependNetworkInfoArray, length(Depend_));
  for i := 0 to length(Depend_) - 1 do
      DependNetworkInfoArray[i] := Depend_[i];
  Result := False;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
        exit;
  Result := True;
end;

function TC40_PhysicsTunnel.ResetDepend(const Depend_: TC40_DependNetworkString): Boolean;
var
  tmp: TC40_DependNetworkInfoArray;
begin
  tmp := ExtractDependInfo(Depend_);
  Result := ResetDepend(tmp);
  ResetDependInfoBuff(tmp);
end;

function TC40_PhysicsTunnel.ResetDepend(const Depend_: U_String): Boolean;
var
  tmp: TC40_DependNetworkInfoArray;
begin
  tmp := ExtractDependInfo(Depend_);
  Result := ResetDepend(tmp);
  ResetDependInfoBuff(tmp);
end;

function TC40_PhysicsTunnel.CheckDepend(): Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnCheckDepend);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndCheckDepend);
end;

function TC40_PhysicsTunnel.CheckDependC(OnResult: TOnState_C): Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        if Assigned(OnResult) then
            OnResult(False);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.On_C := OnResult;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnCheckDepend);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndCheckDepend);
end;

function TC40_PhysicsTunnel.CheckDependM(OnResult: TOnState_M): Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        if Assigned(OnResult) then
            OnResult(False);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.On_M := OnResult;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnCheckDepend);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndCheckDepend);
end;

function TC40_PhysicsTunnel.CheckDependP(OnResult: TOnState_P): Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        if Assigned(OnResult) then
            OnResult(False);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.On_P := OnResult;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnCheckDepend);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndCheckDepend);
end;

function TC40_PhysicsTunnel.BuildDependNetwork: Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  if FWait_Build_Depend_Network then
      exit;
  if FNetwork_Already_Inited then
      exit;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  FWait_Build_Depend_Network := True;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndBuildDependNetwork);
end;

function TC40_PhysicsTunnel.BuildDependNetworkC(OnResult: TOnState_C): Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  if FWait_Build_Depend_Network then
      exit;
  if FNetwork_Already_Inited then
    begin
      FWait_Build_Depend_Network := True;
      tmp := TDCT40_QueryResultAndDependProcessor.Create;
      tmp.C40_PhysicsTunnel := Self;
      tmp.On_C := OnResult;
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
      PhysicsTunnel.AutomatedP2PVM_Open();
      exit;
    end;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        if Assigned(OnResult) then
            OnResult(False);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.On_C := OnResult;
  FWait_Build_Depend_Network := True;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndBuildDependNetwork);
end;

function TC40_PhysicsTunnel.BuildDependNetworkM(OnResult: TOnState_M): Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  if FWait_Build_Depend_Network then
      exit;
  if FNetwork_Already_Inited then
    begin
      FWait_Build_Depend_Network := True;
      tmp := TDCT40_QueryResultAndDependProcessor.Create;
      tmp.C40_PhysicsTunnel := Self;
      tmp.On_M := OnResult;
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
      PhysicsTunnel.AutomatedP2PVM_Open();
      exit;
    end;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        if Assigned(OnResult) then
            OnResult(False);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.On_M := OnResult;
  FWait_Build_Depend_Network := True;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndBuildDependNetwork);
end;

function TC40_PhysicsTunnel.BuildDependNetworkP(OnResult: TOnState_P): Boolean;
var
  i: Integer;
  tmp: TDCT40_QueryResultAndDependProcessor;
begin
  Result := False;
  if FIsConnecting then
      exit;
  if FWait_Build_Depend_Network then
      exit;
  if FNetwork_Already_Inited then
    begin
      FWait_Build_Depend_Network := True;
      tmp := TDCT40_QueryResultAndDependProcessor.Create;
      tmp.C40_PhysicsTunnel := Self;
      tmp.On_P := OnResult;
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
      PhysicsTunnel.AutomatedP2PVM_Open();
      exit;
    end;
  Result := True;
  for i := 0 to length(DependNetworkInfoArray) - 1 do
    if FindRegistedC40(DependNetworkInfoArray[i].Typ) = nil then
      begin
        PhysicsTunnel.Print('no registed "%s"', [DependNetworkInfoArray[i].Typ.Text]);
        if Assigned(OnResult) then
            OnResult(False);
        exit;
      end;
  tmp := TDCT40_QueryResultAndDependProcessor.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.On_P := OnResult;
  FWait_Build_Depend_Network := True;
  if PhysicsTunnel.RemoteInited then
    begin
      QueryInfoM(tmp.DCT40_OnBuildDependNetwork);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndBuildDependNetwork);
end;

procedure TC40_PhysicsTunnel.QueryInfoC(OnResult: TDCT40_OnQueryResultC);
var
  tmp: TDCT40_QueryResultData;
  D: TDFE;
begin
  tmp := TDCT40_QueryResultData.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.OnResultC := OnResult;
  if PhysicsTunnel.RemoteInited then
    begin
      D := TDFE.Create;
      D.WriteString(PhysicsAddr);
      D.WriteWORD(PhysicsPort);
      PhysicsTunnel.SendStreamCmdM('QueryInfo', D, nil, nil, tmp.DoStreamParam, tmp.DoStreamFailed);
      DisposeObject(D);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndQuery);
end;

procedure TC40_PhysicsTunnel.QueryInfoM(OnResult: TDCT40_OnQueryResultM);
var
  tmp: TDCT40_QueryResultData;
  D: TDFE;
begin
  tmp := TDCT40_QueryResultData.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.OnResultM := OnResult;
  if PhysicsTunnel.RemoteInited then
    begin
      D := TDFE.Create;
      D.WriteString(PhysicsAddr);
      D.WriteWORD(PhysicsPort);
      PhysicsTunnel.SendStreamCmdM('QueryInfo', D, nil, nil, tmp.DoStreamParam, tmp.DoStreamFailed);
      DisposeObject(D);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndQuery);
end;

procedure TC40_PhysicsTunnel.QueryInfoP(OnResult: TDCT40_OnQueryResultP);
var
  tmp: TDCT40_QueryResultData;
  D: TDFE;
begin
  tmp := TDCT40_QueryResultData.Create;
  tmp.C40_PhysicsTunnel := Self;
  tmp.OnResultP := OnResult;
  if PhysicsTunnel.RemoteInited then
    begin
      D := TDFE.Create;
      D.WriteString(PhysicsAddr);
      D.WriteWORD(PhysicsPort);
      PhysicsTunnel.SendStreamCmdM('QueryInfo', D, nil, nil, tmp.DoStreamParam, tmp.DoStreamFailed);
      DisposeObject(D);
      exit;
    end;
  FIsConnecting := True;
  PhysicsTunnel.AutomatedP2PVMService := False;
  PhysicsTunnel.AutomatedP2PVMClient := False;
  PhysicsTunnel.AsyncConnectM(PhysicsAddr, PhysicsPort, nil, tmp, DoConnectAndQuery);
end;

function TC40_PhysicsTunnel.DependNetworkIsConnected: Boolean;
var
  i: Integer;
begin
  Result := False;
  if FIsConnecting then
      exit;
  if not PhysicsTunnel.RemoteInited then
      exit;
  if not FNetwork_Already_Inited then
      exit;
  for i := 0 to DependNetworkClientPool.Count - 1 do
    if not DependNetworkClientPool[i].Connected then
        exit;
  Result := True;
end;

procedure TC40_PhysicsTunnel.DoNetworkOnline(Custom_Client_: TC40_Custom_Client);
begin
  if Assigned(OnEvent) then
      OnEvent.C40_PhysicsTunnel_Client_Connected(Self, Custom_Client_);
end;

constructor TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Tunnel_: TC40_PhysicsTunnel);
begin
  inherited Create;
  Fault_Fixed_Bridge_Begin_Time := GetTimeTick();
  Tunnel := Tunnel_;
end;

procedure TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Do_Delay_Next_BuildDependNetwork;
begin
  if (C40_KillIDCFaultTimeout > 0) and (GetTimeTick - Fault_Fixed_Bridge_Begin_Time > C40_KillIDCFaultTimeout) then
    begin
      DelayFreeObj(1.0, Self);
      exit;
    end;
  if (C40_PhysicsTunnelPool = nil) or (C40_PhysicsTunnelPool.IndexOf(Tunnel) < 0) then
    begin
      DelayFreeObj(1.0, Self);
      exit;
    end;
  Tunnel.FOfflineTime := GetTimeTick();
  if Tunnel.FIsConnecting then
      SystemPostProgress.PostExecuteM_NP(5.0, Do_Delay_Next_BuildDependNetwork)
  else if not Tunnel.FNetwork_Already_Inited then
      Tunnel.BuildDependNetworkM(Do_First_BuildDependNetwork)
  else
      DelayFreeObj(1.0, Self);
end;

procedure TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Do_First_BuildDependNetwork(const state: Boolean);
begin
  if (C40_PhysicsTunnelPool = nil) or (C40_PhysicsTunnelPool.IndexOf(Tunnel) < 0) then
    begin
      DelayFreeObj(1.0, Self);
      exit;
    end;
  if state then
    begin
      DelayFreeObj(1.0, Self);
      exit;
    end;
  if Tunnel.FNetwork_Already_Inited then
    begin
      DelayFreeObj(1.0, Self);
      exit;
    end;
  Tunnel.FOfflineTime := GetTimeTick();
  SystemPostProgress.PostExecuteM_NP(5.0, Do_Delay_Next_BuildDependNetwork);
end;

constructor TC40_PhysicsTunnelPool.Create;
begin
  inherited Create;
{$IFDEF ZNet_C4_Auto_Repair_First_BuildDependNetwork_Fault}
  Auto_Repair_First_BuildDependNetwork_Fault := True;
{$ELSE ZNet_C4_Auto_Repair_First_BuildDependNetwork_Fault}
  Auto_Repair_First_BuildDependNetwork_Fault := False;
{$ENDIF ZNet_C4_Auto_Repair_First_BuildDependNetwork_Fault}
end;

procedure TC40_PhysicsTunnelPool.GetRS(var recv, send: Int64);
var
  i: Integer;
  c: TC40_PhysicsTunnel;
begin
  for i := 0 to Count - 1 do
    begin
      c := Items[i];
      inc(recv, c.PhysicsTunnel.Statistics[stReceiveSize]);
      inc(send, c.PhysicsTunnel.Statistics[stSendSize]);
    end;
end;

function TC40_PhysicsTunnelPool.ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if PhysicsAddr.Same(@Items[i].PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].PhysicsPort)) then
        exit;
  Result := False;
end;

function TC40_PhysicsTunnelPool.CreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word;
  const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel;
begin
  Result := TC40_PhysicsTunnel.Create(PhysicsAddr, PhysicsPort);
  Result.OnEvent := OnEvent_;
  Result.ResetDepend(Depend_);
  if Auto_Repair_First_BuildDependNetwork_Fault then
      Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
  else
      Result.BuildDependNetwork();
end;

function TC40_PhysicsTunnelPool.GetPhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word): TC40_PhysicsTunnel;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if PhysicsAddr.Same(@Items[i].PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].PhysicsPort)) then
      begin
        Result := Items[i];
        exit;
      end;
end;

function TC40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word): TC40_PhysicsTunnel;
begin
  Result := GetPhysicsTunnel(PhysicsAddr, PhysicsPort);
  if Result = nil then
      Result := TC40_PhysicsTunnel.Create(PhysicsAddr, PhysicsPort);
end;

function TC40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word;
  const Depend_: TC40_DependNetworkInfoArray; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel;
begin
  Result := GetPhysicsTunnel(PhysicsAddr, PhysicsPort);
  if (Result = nil) then
    begin
      Result := TC40_PhysicsTunnel.Create(PhysicsAddr, PhysicsPort);
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end
  else if (not Result.FIsConnecting) and (not Result.FNetwork_Already_Inited) then
    begin
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end;
end;

function TC40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word;
  const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel;
begin
  Result := GetPhysicsTunnel(PhysicsAddr, PhysicsPort);
  if Result = nil then
    begin
      Result := TC40_PhysicsTunnel.Create(PhysicsAddr, PhysicsPort);
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end
  else if (not Result.FIsConnecting) and (not Result.FNetwork_Already_Inited) then
    begin
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end;
end;

function TC40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(dispInfo: TC40_Info): TC40_PhysicsTunnel;
begin
  Result := GetPhysicsTunnel(dispInfo.PhysicsAddr, dispInfo.PhysicsPort);
  if Result = nil then
    begin
      Result := TC40_PhysicsTunnel.Create(dispInfo.PhysicsAddr, dispInfo.PhysicsPort);
    end;
end;

function TC40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(dispInfo: TC40_Info;
  const Depend_: TC40_DependNetworkInfoArray; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel;
begin
  Result := GetPhysicsTunnel(dispInfo.PhysicsAddr, dispInfo.PhysicsPort);
  if Result = nil then
    begin
      Result := TC40_PhysicsTunnel.Create(dispInfo.PhysicsAddr, dispInfo.PhysicsPort);
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end
  else if (not Result.FIsConnecting) and (not Result.FNetwork_Already_Inited) then
    begin
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end;
end;

function TC40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(dispInfo: TC40_Info;
  const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel;
begin
  Result := GetPhysicsTunnel(dispInfo.PhysicsAddr, dispInfo.PhysicsPort);
  if Result = nil then
    begin
      Result := TC40_PhysicsTunnel.Create(dispInfo.PhysicsAddr, dispInfo.PhysicsPort);
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end
  else if (not Result.FIsConnecting) and (not Result.FNetwork_Already_Inited) then
    begin
      Result.OnEvent := OnEvent_;
      Result.ResetDepend(Depend_);
      if Auto_Repair_First_BuildDependNetwork_Fault then
          Result.BuildDependNetworkM(TC40_First_BuildDependNetwork_Fault_Fixed_Bridge.Create(Result).Do_First_BuildDependNetwork)
      else
          Result.BuildDependNetwork();
    end;
end;

procedure TC40_PhysicsTunnelPool.Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    begin
      try
          Items[i].Progress;
      except
      end;
    end;
end;

procedure TC40_PhysicsTunnelPool.Enabled_Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
      Items[i].PhysicsTunnel.Enabled_Progress;
end;

procedure TC40_PhysicsTunnelPool.Disable_Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
      Items[i].PhysicsTunnel.Disable_Progress;
end;

function TC40_PhysicsTunnelPool.SearchServiceAndBuildConnection(PhysicsAddr: U_String; PhysicsPort: Word; FullConnection_: Boolean;
  const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge;
var
  Tunnel_: TC40_PhysicsTunnel;
begin
  Result := TSearchServiceAndBuildConnection_Bridge.Create;
  Result.PhysicsPool_ := Self;
  Result.FullConnection_ := FullConnection_;
  Result.ServiceTyp := ServiceTyp;
  Result.OnEvent_ := OnEvent_;
  Tunnel_ := GetOrCreatePhysicsTunnel(PhysicsAddr, PhysicsPort);
  Tunnel_.QueryInfoM(Result.Do_SearchService_Event);
end;

function TC40_PhysicsTunnelPool.SearchServiceAndBuildConnection(PhysicsAddr: U_String; PhysicsPort: Word;
  const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge;
var
  Tunnel_: TC40_PhysicsTunnel;
begin
  Result := TSearchServiceAndBuildConnection_Bridge.Create;
  Result.PhysicsPool_ := Self;
  Result.FullConnection_ := True;
  Result.ServiceTyp := ServiceTyp;
  Result.OnEvent_ := OnEvent_;
  Tunnel_ := GetOrCreatePhysicsTunnel(PhysicsAddr, PhysicsPort);
  Tunnel_.QueryInfoM(Result.Do_SearchService_Event);
end;

function TC40_PhysicsTunnelPool.SearchServiceAndOptimizeConnection(PhysicsAddr: U_String; PhysicsPort: Word;
  const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge;
var
  Tunnel_: TC40_PhysicsTunnel;
begin
  Result := TSearchServiceAndBuildConnection_Bridge.Create;
  Result.PhysicsPool_ := Self;
  Result.FullConnection_ := False;
  Result.ServiceTyp := ServiceTyp;
  Result.OnEvent_ := OnEvent_;
  Tunnel_ := GetOrCreatePhysicsTunnel(PhysicsAddr, PhysicsPort);
  Tunnel_.QueryInfoM(Result.Do_SearchService_Event);
end;

procedure TC40_Custom_ClientPool_Wait.DoRun;
var
  error_: Boolean;
  function ExistsClientFromStatesDone(c_: TC40_Custom_Client): Boolean;
  var
    i: Integer;
  begin
    Result := True;
    try
      for i := 0 to length(States_) - 1 do
        if States_[i].Client_ = c_ then
            exit;
    except
        error_ := True;
    end;
    Result := False;
  end;
  function MatchServiceTypForPool(var d_: TC40_Custom_ClientPool_Wait_Data): Boolean;
  var
    i: Integer;
  begin
    Result := True;
    try
      for i := 0 to Pool_.Count - 1 do
        begin
          if Pool_[i].Connected and d_.ServiceTyp_.Same(@Pool_[i].ClientInfo.ServiceTyp) and (not ExistsClientFromStatesDone(Pool_[i])) then
            begin
              d_.Client_ := Pool_[i];
              exit;
            end;
        end;
    except
        error_ := True;
    end;
    Result := False;
  end;
  function IsAllDone: Boolean;
  var
    i: Integer;
  begin
    Result := False;
    try
      for i := 0 to length(States_) - 1 do
        if States_[i].Client_ = nil then
            exit;
    except
        error_ := True;
    end;
    Result := True;
  end;

var
  i: Integer;
begin
  error_ := False;
  for i := 0 to length(States_) - 1 do
      MatchServiceTypForPool(States_[i]);
  if error_ then
    begin
      DoStatus('TC40_Custom_ClientPool_Wait error!');
      DelayFreeObject(0.5, Self, nil);
    end
  else if IsAllDone then
    begin
      try
        if Assigned(On_C) then
            On_C(States_)
        else if Assigned(On_M) then
            On_M(States_)
        else if Assigned(On_P) then
            On_P(States_);
      except
      end;
      DelayFreeObject(0.5, Self, nil);
    end
  else
      SystemPostProgress.PostExecuteM_NP(0.1, DoRun);
end;

constructor TC40_Custom_ClientPool_Wait.Create(dependNetwork_: U_String);
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
begin
  inherited Create;
  Arry_ := ExtractDependInfo(dependNetwork_);
  SetLength(States_, length(Arry_));
  for i := 0 to length(Arry_) - 1 do
    begin
      States_[i].ServiceTyp_ := Arry_[i].Typ;
      States_[i].Client_ := nil;
    end;
  ResetDependInfoBuff(Arry_);
  Pool_ := nil;
  On_C := nil;
  On_M := nil;
  On_P := nil;
end;

destructor TC40_Custom_ClientPool_Wait.Destroy;
begin
  SetLength(States_, 0);
  Pool_ := nil;
  On_C := nil;
  On_M := nil;
  On_P := nil;
  inherited Destroy;
end;

constructor TSearchServiceAndBuildConnection_Bridge.Create;
begin
  inherited Create;
  PhysicsPool_ := nil;
  FullConnection_ := True;
  ServiceTyp := '';
  OnEvent_ := nil;
  Done_ClientPool := TC40_Custom_ClientPool.Create;
  TaskNum := 0;
  OnDone_C := nil;
  OnDone_M := nil;
  OnDone_P := nil;
end;

destructor TSearchServiceAndBuildConnection_Bridge.Destroy;
begin
  DisposeObject(Done_ClientPool);
  inherited Destroy;
end;

procedure TSearchServiceAndBuildConnection_Bridge.Do_SearchService_Event(Sender: TC40_PhysicsTunnel; L: TC40_InfoList);
var
  arry: TC40_Info_Array;
  i, j: Integer;
  tmp: TC40_PhysicsTunnel;
begin
  if FullConnection_ then
    begin
      arry := L.SearchService(ServiceTyp);
      for i := low(arry) to high(arry) do
        if arry[i].FoundServiceTyp(ServiceTyp) then
          begin
            tmp := PhysicsPool_.GetOrCreatePhysicsTunnel(arry[i], ServiceTyp, OnEvent_);
            tmp.DependNetworkClientPool.WaitConnectedDoneM(arry[i].ServiceTyp, Do_Done_Client);
            inc(TaskNum);
          end;
      SetLength(arry, 0);
    end
  else
    begin
      arry := L.SearchMinWorkload(ServiceTyp);
      for i := low(arry) to high(arry) do
        if arry[i].FoundServiceTyp(ServiceTyp) then
          begin
            tmp := PhysicsPool_.GetOrCreatePhysicsTunnel(arry[i], ServiceTyp, OnEvent_);
            tmp.DependNetworkClientPool.WaitConnectedDoneM(arry[i].ServiceTyp, Do_Done_Client);
            inc(TaskNum);
          end;
      SetLength(arry, 0);
    end;
  if TaskNum <= 0 then
    begin
      try
        if Assigned(OnDone_C) then
            OnDone_C(Done_ClientPool)
        else if Assigned(OnDone_M) then
            OnDone_M(Done_ClientPool)
        else if Assigned(OnDone_P) then
            OnDone_P(Done_ClientPool);
      except
      end;
      DelayFreeObj(1.0, Self);
    end;
end;

procedure TSearchServiceAndBuildConnection_Bridge.Do_Done_Client(States_: TC40_Custom_ClientPool_Wait_States);
var
  i: Integer;
begin
  for i := low(States_) to high(States_) do
      Done_ClientPool.Add(States_[i].Client_);
  dec(TaskNum);
  if TaskNum <= 0 then
    begin
      try
        if Assigned(OnDone_C) then
            OnDone_C(Done_ClientPool)
        else if Assigned(OnDone_M) then
            OnDone_M(Done_ClientPool)
        else if Assigned(OnDone_P) then
            OnDone_P(Done_ClientPool);
      except
      end;
      DelayFreeObj(1.0, Self);
    end;
end;

procedure TC40_Info.MakeHash;
var
  n: U_String;
  buff: TBytes;
begin
  n := umlTrimSpace(PhysicsAddr) + '_' + umlIntToStr(PhysicsPort) + '_' + umlTrimSpace(p2pVM_RecvTunnel_Addr) + '_' + umlTrimSpace(p2pVM_SendTunnel_Addr);
  n := n.LowerText;
  buff := n.Bytes;
  n := '';
  Hash := umlMD5(@buff[0], length(buff));
  SetLength(buff, 0);
end;

constructor TC40_Info.Create;
begin
  inherited Create;
  Ignored := False;
  OnlyInstance := False;
  ServiceTyp := '';
  PhysicsAddr := '';
  PhysicsPort := 0;
  p2pVM_RecvTunnel_Addr := '';
  p2pVM_RecvTunnel_Port := 0;
  p2pVM_SendTunnel_Addr := '';
  p2pVM_SendTunnel_Port := 0;
  Workload := 0;
  MaxWorkload := 0;
  Hash := NullMD5;
end;

destructor TC40_Info.Destroy;
begin
  ServiceTyp := '';
  PhysicsAddr := '';
  p2pVM_RecvTunnel_Addr := '';
  p2pVM_SendTunnel_Addr := '';
  inherited Destroy;
end;

procedure TC40_Info.Assign(source: TC40_Info);
begin
  Ignored := source.Ignored;
  OnlyInstance := source.OnlyInstance;
  ServiceTyp := source.ServiceTyp;
  PhysicsAddr := source.PhysicsAddr;
  PhysicsPort := source.PhysicsPort;
  p2pVM_RecvTunnel_Addr := source.p2pVM_RecvTunnel_Addr;
  p2pVM_RecvTunnel_Port := source.p2pVM_RecvTunnel_Port;
  p2pVM_SendTunnel_Addr := source.p2pVM_SendTunnel_Addr;
  p2pVM_SendTunnel_Port := source.p2pVM_SendTunnel_Port;
  Workload := source.Workload;
  MaxWorkload := source.MaxWorkload;
  Hash := source.Hash;
end;

function TC40_Info.Clone: TC40_Info;
begin
  Result := TC40_Info.Create;
  Result.Assign(Self);
end;

procedure TC40_Info.Load(stream: TCore_Stream);
var
  D: TDFE;
begin
  D := TDFE.Create;
  D.LoadFromStream(stream);
  OnlyInstance := D.R.ReadBool;
  ServiceTyp := D.R.ReadString;
  PhysicsAddr := D.R.ReadString;
  PhysicsPort := D.R.ReadWord;
  p2pVM_RecvTunnel_Addr := D.R.ReadString;
  p2pVM_RecvTunnel_Port := D.R.ReadWord;
  p2pVM_SendTunnel_Addr := D.R.ReadString;
  p2pVM_SendTunnel_Port := D.R.ReadWord;
  Workload := D.R.ReadInteger;
  MaxWorkload := D.R.ReadInteger;
  Hash := D.R.ReadMD5;
  DisposeObject(D);
end;

procedure TC40_Info.Save(stream: TCore_Stream);
var
  D: TDFE;
begin
  D := TDFE.Create;
  D.WriteBool(OnlyInstance);
  D.WriteString(ServiceTyp);
  D.WriteString(PhysicsAddr);
  D.WriteWORD(PhysicsPort);
  D.WriteString(p2pVM_RecvTunnel_Addr);
  D.WriteWORD(p2pVM_RecvTunnel_Port);
  D.WriteString(p2pVM_SendTunnel_Addr);
  D.WriteWORD(p2pVM_SendTunnel_Port);
  D.WriteInteger(Workload);
  D.WriteInteger(MaxWorkload);
  D.WriteMD5(Hash);
  D.FastEncodeTo(stream);
  DisposeObject(D);
end;

function TC40_Info.Same(Data_: TC40_Info): Boolean;
begin
  Result := False;
  if not ServiceTyp.Same(@Data_.ServiceTyp) then
      exit;
  if not PhysicsAddr.Same(@Data_.PhysicsAddr) then
      exit;
  if PhysicsPort <> Data_.PhysicsPort then
      exit;
  if not p2pVM_RecvTunnel_Addr.Same(@Data_.p2pVM_RecvTunnel_Addr) then
      exit;
  if p2pVM_RecvTunnel_Port <> Data_.p2pVM_RecvTunnel_Port then
      exit;
  if not p2pVM_SendTunnel_Addr.Same(@Data_.p2pVM_SendTunnel_Addr) then
      exit;
  if p2pVM_SendTunnel_Port <> Data_.p2pVM_SendTunnel_Port then
      exit;
  Result := True;
end;

function TC40_Info.SameServiceTyp(Data_: TC40_Info): Boolean;
begin
  Result := ServiceTyp.Same(@Data_.ServiceTyp);
end;

function TC40_Info.SamePhysicsAddr(PhysicsAddr_: U_String): Boolean;
begin
  Result := PhysicsAddr.Same(@PhysicsAddr_);
end;

function TC40_Info.SamePhysicsAddr(Arry_: TArrayPascalString): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to length(Arry_) - 1 do
    if PhysicsAddr.Same(@Arry_[i]) then
      begin
        Result := True;
        exit;
      end;
end;

function TC40_Info.SamePhysicsAddr(PhysicsAddr_: U_String; PhysicsPort_: Word): Boolean;
begin
  Result := False;
  if not PhysicsAddr.Same(@PhysicsAddr_) then
      exit;
  if PhysicsPort <> PhysicsPort_ then
      exit;
  Result := True;
end;

function TC40_Info.SamePhysicsAddr(Data_: TC40_Info): Boolean;
begin
  Result := False;
  if not PhysicsAddr.Same(@Data_.PhysicsAddr) then
      exit;
  if PhysicsPort <> Data_.PhysicsPort then
      exit;
  Result := True;
end;

function TC40_Info.SamePhysicsAddr(Data_: TC40_PhysicsTunnel): Boolean;
begin
  Result := False;
  if not PhysicsAddr.Same(@Data_.PhysicsAddr) then
      exit;
  if PhysicsPort <> Data_.PhysicsPort then
      exit;
  Result := True;
end;

function TC40_Info.SamePhysicsAddr(Data_: TC40_PhysicsService): Boolean;
begin
  Result := False;
  if not PhysicsAddr.Same(@Data_.PhysicsAddr) then
      exit;
  if PhysicsPort <> Data_.PhysicsPort then
      exit;
  Result := True;
end;

function TC40_Info.SameP2PVMAddr(Data_: TC40_Info): Boolean;
begin
  Result := False;
  if not p2pVM_RecvTunnel_Addr.Same(@Data_.p2pVM_RecvTunnel_Addr) then
      exit;
  if p2pVM_RecvTunnel_Port <> Data_.p2pVM_RecvTunnel_Port then
      exit;
  if not p2pVM_SendTunnel_Addr.Same(@Data_.p2pVM_SendTunnel_Addr) then
      exit;
  if p2pVM_SendTunnel_Port <> Data_.p2pVM_SendTunnel_Port then
      exit;
  Result := True;
end;

function TC40_Info.FoundServiceTyp(Arry_: TC40_DependNetworkInfoArray): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := low(Arry_) to high(Arry_) do
    if ServiceTyp.Same(@Arry_[i].Typ) then
      begin
        Result := True;
        exit;
      end;
end;

function TC40_Info.FoundServiceTyp(servTyp_: U_String): Boolean;
var
  Arry_: TC40_DependNetworkInfoArray;
begin
  Arry_ := ExtractDependInfo(servTyp_);
  Result := FoundServiceTyp(Arry_);
  ResetDependInfoBuff(Arry_);
end;

function TC40_Info.ReadyC40Client: Boolean;
var
  p: PC40_RegistedData;
begin
  p := FindRegistedC40(ServiceTyp);
  Result := (p <> nil) and (p^.ClientClass <> nil);
end;

function TC40_Info.GetOrCreateC40Client(PhysicsTunnel_: TC40_PhysicsTunnel; Param_: U_String): TC40_Custom_Client;
var
  p: PC40_RegistedData;
  i: Integer;
begin
  Result := nil;
  for i := 0 to PhysicsTunnel_.DependNetworkClientPool.Count - 1 do
    if Same(PhysicsTunnel_.DependNetworkClientPool[i].ClientInfo) then
      begin
        Result := C40_ClientPool[i];
        exit;
      end;
  p := FindRegistedC40(ServiceTyp);
  if p <> nil then
      Result := p^.ClientClass.Create(PhysicsTunnel_, Self, Param_);
end;

constructor TC40_InfoList.Create(AutoFree_: Boolean);
begin
  inherited Create;
  AutoFree := AutoFree_;
end;

destructor TC40_InfoList.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TC40_InfoList.Remove(obj: TC40_Info);
begin
  if AutoFree then
      DisposeObject(obj);
  inherited Remove(obj);
end;

procedure TC40_InfoList.Delete(index: Integer);
begin
  if AutoFree then
      DisposeObject(Items[index]);
  inherited Delete(index);
end;

procedure TC40_InfoList.Clear;
var
  i: Integer;
begin
  if AutoFree then
    for i := 0 to Count - 1 do
        DisposeObject(Items[i]);
  inherited Clear;
end;

class procedure TC40_InfoList.SortWorkLoad(L_: TC40_InfoList);
  function Compare_(Left, Right: TC40_Info): ShortInt;
  begin
    Result := CompareFloat(Left.Workload / Left.MaxWorkload, Right.Workload / Right.MaxWorkload);
    if Result = 0 then
        Result := CompareGeoInt(Right.MaxWorkload, Left.MaxWorkload);
  end;
  procedure fastSort_(Arry_: TC40_InfoList; L, R: Integer);
  var
    i, j: Integer;
    p: TC40_Info;
  begin
    repeat
      i := L;
      j := R;
      p := Arry_[(L + R) shr 1];
      repeat
        while Compare_(Arry_[i], p) < 0 do
            inc(i);
        while Compare_(Arry_[j], p) > 0 do
            dec(j);
        if i <= j then
          begin
            if i <> j then
                Arry_.Exchange(i, j);
            inc(i);
            dec(j);
          end;
      until i > j;
      if L < j then
          fastSort_(Arry_, L, j);
      L := i;
    until i >= R;
  end;

begin
  if L_.Count > 1 then
      fastSort_(L_, 0, L_.Count - 1);
end;

function TC40_InfoList.GetInfoArray: TC40_Info_Array;
var
  i: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to Count - 1 do
      Result[i] := Items[i];
end;

function TC40_InfoList.IsOnlyInstance(ServiceTyp: U_String): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Count - 1 do
    if umlMultipleMatch(True, ServiceTyp, Items[i].ServiceTyp) and Items[i].OnlyInstance then
      begin
        Result := True;
        exit;
      end;
end;

function TC40_InfoList.GetServiceTypNum(ServiceTyp: U_String): Integer;
var
  arry: TC40_Info_Array;
begin
  arry := SearchService(ServiceTyp);
  Result := length(arry);
  SetLength(arry, 0);
end;

function TC40_InfoList.SearchMinWorkload(arry: TC40_DependNetworkInfoArray): TC40_Info_Array;
  function Do_SearchService_(serv_: U_String): TC40_InfoList;
  var
    i: Integer;
  begin
    Result := TC40_InfoList.Create(False);
    for i := 0 to Count - 1 do
      if serv_.Same(@Items[i].ServiceTyp) then
          Result.Add(Items[i]);
    TC40_InfoList.SortWorkLoad(Result);
  end;

var
  i: Integer;
  tmp, L: TC40_InfoList;
begin
  L := TC40_InfoList.Create(False);
  for i := low(arry) to high(arry) do
    begin
      tmp := Do_SearchService_(arry[i].Typ);
      if tmp.Count > 0 then
          L.Add(tmp.First);
      DisposeObject(tmp);
    end;
  Result := L.GetInfoArray;
  DisposeObject(L);
end;

function TC40_InfoList.SearchMinWorkload(ServiceTyp: U_String): TC40_Info_Array;
var
  tmp: TC40_DependNetworkInfoArray;
begin
  tmp := ExtractDependInfo(ServiceTyp);
  Result := SearchMinWorkload(tmp);
  ResetDependInfoBuff(tmp);
end;

function TC40_InfoList.SearchService(arry: TC40_DependNetworkInfoArray; full_: Boolean): TC40_Info_Array;
var
  L: TC40_InfoList;
  i, j: Integer;
begin
  L := TC40_InfoList.Create(False);
  for i := 0 to Count - 1 do
    begin
      for j := low(arry) to high(arry) do
        if arry[j].Typ.Same(@Items[i].ServiceTyp) then
          begin
            L.Add(Items[i]);
            if not full_ then
                break;
          end;
    end;
  TC40_InfoList.SortWorkLoad(L);
  Result := L.GetInfoArray;
  DisposeObject(L);
end;

function TC40_InfoList.SearchService(arry: TC40_DependNetworkInfoArray): TC40_Info_Array;
begin
  Result := SearchService(arry, True);
end;

function TC40_InfoList.SearchService(ServiceTyp: U_String): TC40_Info_Array;
var
  tmp: TC40_DependNetworkInfoArray;
begin
  tmp := ExtractDependInfo(ServiceTyp);
  Result := SearchService(tmp);
  ResetDependInfoBuff(tmp);
end;

function TC40_InfoList.ExistsService(arry: TC40_DependNetworkInfoArray): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if Items[i].FoundServiceTyp(arry) then
        exit;
  Result := False;
end;

function TC40_InfoList.ExistsService(ServiceTyp: U_String): Boolean;
var
  tmp: TC40_DependNetworkInfoArray;
begin
  tmp := ExtractDependInfo(ServiceTyp);
  Result := ExistsService(tmp);
  ResetDependInfoBuff(tmp);
end;

function TC40_InfoList.FindSame(Data_: TC40_Info): TC40_Info;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].Same(Data_) then
      begin
        Result := Items[i];
        exit;
      end;
end;

function TC40_InfoList.FindHash(Hash: TMD5): TC40_Info;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if umlCompareMD5(Hash, Items[i].Hash) then
      begin
        Result := Items[i];
        exit;
      end;
end;

function TC40_InfoList.ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if PhysicsAddr.Same(@Items[i].PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].PhysicsPort)) then
        exit;
  Result := False;
end;

procedure TC40_InfoList.RemovePhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word);
var
  i: Integer;
begin
  i := 0;
  while i < Count do
    if PhysicsAddr.Same(@Items[i].PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].PhysicsPort)) then
        Delete(i)
    else
        inc(i);
end;

function TC40_InfoList.OverwriteInfo(Data_: TC40_Info): Boolean;
var
  found_: TC40_Info;
begin
  Result := False;
  found_ := FindSame(Data_);
  if found_ <> nil then
    begin
      if found_ <> Data_ then
          found_.Assign(Data_);
    end
  else
    begin
      if AutoFree then
        begin
          Add(Data_.Clone);
          Result := True;
        end
      else
          DoStatus('autofree is false = memory leak.');
    end;
end;

function TC40_InfoList.MergeAndUpdateWorkload(source: TC40_InfoList): Boolean;
var
  i: Integer;
  found_: TC40_Info;
begin
  Result := False;
  for i := 0 to source.Count - 1 do
    begin
      found_ := FindSame(source[i]);
      if found_ = nil then
        begin
          if AutoFree then
              Add(source[i].Clone)
          else
              Add(source[i]);
          Result := True;
        end
      else if AutoFree then
        begin
          found_.Workload := umlMax(found_.Workload, source[i].Workload);
          found_.MaxWorkload := umlMax(found_.MaxWorkload, source[i].MaxWorkload);
        end;
    end;
end;

function TC40_InfoList.MergeFromDF(D: TDFE): Boolean;
var
  i: Integer;
  m64: TMS64;
  tmp, found_: TC40_Info;
  arry: TC40_Info_Array;
  ReadyNewInfo_: Boolean;
begin
  Result := False;
  while D.R.NotEnd do
    begin
      m64 := TMS64.Create;
      D.R.ReadStream(m64);
      m64.Position := 0;
      tmp := TC40_Info.Create;
      tmp.Load(m64);
      DisposeObject(m64);
      found_ := FindSame(tmp);
      if found_ <> nil then
        begin
          DisposeObject(tmp);
        end
      else
        begin
          ReadyNewInfo_ := True;
          if not AutoFree then
              DoStatus('autofree is false = memory leak.');
          if (tmp.OnlyInstance) then
            begin
              arry := SearchService(tmp.ServiceTyp);
              if length(arry) > 0 then
                begin
                  ReadyNewInfo_ := False;
                  DoStatus('"%s" is only instance.', [tmp.ServiceTyp.Text]);
                end;
            end;
          if ReadyNewInfo_ then
            begin
              Add(tmp);
              Result := True;
            end;
        end;
    end;
end;

procedure TC40_InfoList.SaveToDF(D: TDFE);
var
  i: Integer;
  m64: TMS64;
begin
  m64 := TMS64.Create;
  for i := 0 to Count - 1 do
    if not Items[i].Ignored then
      begin
        Items[i].Save(m64);
        D.WriteStream(m64);
        m64.Clear;
      end;
  DisposeObject(m64);
end;

constructor TC4_Help_Console_Command_Data.Create;
begin
  inherited Create;
  Cmd := '';
  Desc := '';
  OnEvent_C := nil;
  OnEvent_M := nil;
  OnEvent_P := nil;
end;

destructor TC4_Help_Console_Command_Data.Destroy;
begin
  Cmd := '';
  Desc := '';
  OnEvent_C := nil;
  OnEvent_M := nil;
  OnEvent_P := nil;
  inherited Destroy;
end;

procedure TC4_Help_Console_Command_Data.DoExecute(var OP_Param: TOpParam);
begin
  try
    if Assigned(OnEvent_C) then
        OnEvent_C(OP_Param)
    else if Assigned(OnEvent_M) then
        OnEvent_M(OP_Param)
    else if Assigned(OnEvent_P) then
        OnEvent_P(OP_Param);
  except
  end;
end;

procedure TC4_Help_Console_Command.DoFree(var Data: TC4_Help_Console_Command_Data);
begin
  DisposeObjectAndNil(Data);
end;

procedure TC40_Custom_Service.Init_Cycle_Anchor;
begin
  FCycle_Order_Default := AtomInc(C40_Cycle_Order_Seed);
  FCycle_Anchor := TString_Num64_Analysis_Tool.Create($10, FCycle_Order_Default);
  FCycle_Anchor_Temp := 0;
end;

procedure TC40_Custom_Service.Free_Cycle_Anchor;
begin
  DisposeObject(FCycle_Anchor);
end;

procedure TC40_Custom_Service.Inc_Cycle_Anchor(TaskName: U_String);
begin
  FCycle_Anchor.IncValue(TaskName, 1);
end;

procedure TC40_Custom_Service.Ready_Cycle_Anchor(TaskName: U_String);
begin
  FCycle_Anchor_Temp := FCycle_Anchor[TaskName];
end;

constructor TC40_Custom_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
var
  P2PVM_Recv_Name_, P2PVM_Recv_IP6_, P2PVM_Recv_Port_: U_String;
  P2PVM_Send_Name_, P2PVM_Send_IP6_, P2PVM_Send_Port_: U_String;
  tmp: TPascalStringList;
begin
  inherited Create;
  Param := Param_;
  Param_File := '';
  C40PhysicsService := PhysicsService_;
  ParamList := THashStringList.Create;
  ParamList.AutoUpdateDefaultValue := True;
  try
    tmp := TPascalStringList.Create;
    umlSeparatorText(Param, tmp, ',;' + #13#10);
    ParamList.ImportFromStrings(tmp);
    DisposeObject(tmp);
  except
  end;
  Param_File := Where_C4_File(ParamList.GetDefaultValue('Param_File', PFormat('S_%s.conf', [ServiceTyp.Text])), ServiceTyp);
  if umlFileExists(Param_File) then
    begin
      DoStatus('(%s) "%s" found configure file: %s', [ClassName, ServiceTyp.Text, Param_File.Text]);
      ParamList.LoadFromFile(Param_File);
    end;
  FLastSafeCheckTime := GetTimeTick;
  SafeCheckTime := EStrToInt64(ParamList.GetDefaultValue('SafeCheckTime', umlIntToStr(C40_SafeCheckTime)), C40_SafeCheckTime);
  Alias_or_Hash___ := ParamList.GetDefaultValue('Alias', C40_ServicePool.MakeAlias(ServiceTyp));
  enablePerServiceDirectory := C40_EnablePerServiceDirectory;
  enablePerServiceDirectory := EStrToBool(ParamList.GetDefaultValue('enablePerServiceDirectory', if_(enablePerServiceDirectory, 'True', 'False')), enablePerServiceDirectory);
  Tag := 0;
  Tag := EStrToInt(ParamList.GetDefaultValue('Tag', umlIntToStr(Tag)), Tag);
  P2PVM_Recv_Name_ := ServiceTyp + 'R';
  C40_ServicePool.MakeP2PVM_IPv6_Port(P2PVM_Recv_IP6_, P2PVM_Recv_Port_);
  P2PVM_Send_Name_ := ServiceTyp + 'S';
  C40_ServicePool.MakeP2PVM_IPv6_Port(P2PVM_Send_IP6_, P2PVM_Send_Port_);
  ServiceInfo := TC40_Info.Create;
  ServiceInfo.Ignored := EStrToBool(ParamList.GetDefaultValue('Ignored', if_(ServiceInfo.Ignored, 'True', 'False')), ServiceInfo.Ignored);
  ServiceInfo.OnlyInstance := EStrToBool(ParamList.GetDefaultValue('OnlyInstance', if_(ServiceInfo.OnlyInstance, 'True', 'False')), ServiceInfo.OnlyInstance);
  ServiceInfo.ServiceTyp := ServiceTyp;
  ServiceInfo.PhysicsAddr := C40PhysicsService.PhysicsAddr;
  ServiceInfo.PhysicsPort := C40PhysicsService.PhysicsPort;
  ServiceInfo.p2pVM_RecvTunnel_Addr := P2PVM_Recv_IP6_;
  ServiceInfo.p2pVM_RecvTunnel_Port := umlStrToInt(P2PVM_Recv_Port_);
  ServiceInfo.p2pVM_SendTunnel_Addr := P2PVM_Send_IP6_;
  ServiceInfo.p2pVM_SendTunnel_Port := umlStrToInt(P2PVM_Send_Port_);
  SetWorkload(0, 100);
  ServiceInfo.MakeHash;
  C40_ServicePool.Add(Self);
  C40PhysicsService.DependNetworkServicePool.Add(Self);
  ConsoleCommand := TC4_Help_Console_Command.Create;
  Init_Cycle_Anchor();
end;

destructor TC40_Custom_Service.Destroy;
begin
  Free_Cycle_Anchor();
  DisposeObject(ConsoleCommand);
  C40PhysicsService.DependNetworkServicePool.Remove(Self);
  C40_ServicePool.Remove(Self);
  DisposeObject(ServiceInfo);
  DisposeObject(ParamList);
  inherited Destroy;
end;

procedure TC40_Custom_Service.SafeCheck;
begin
end;

procedure TC40_Custom_Service.Progress;
begin
  if GetTimeTick - FLastSafeCheckTime > SafeCheckTime then
    begin
      try
          SafeCheck;
      except
      end;
      FLastSafeCheckTime := GetTimeTick;
    end;
end;

procedure TC40_Custom_Service.SetWorkload(Workload_, MaxWorkload_: Integer);
begin
  ServiceInfo.Workload := Workload_;
  ServiceInfo.MaxWorkload := MaxWorkload_;
end;

procedure TC40_Custom_Service.UpdateToGlobalDispatch;
var
  i: Integer;
  dps: TC40_Dispatch_Service;
  dpc: TC40_Dispatch_Client;
begin
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i] is TC40_Dispatch_Service then
      if C40_ServicePool[i] <> Self then
        begin
          dps := TC40_Dispatch_Service(C40_ServicePool[i]);
          if dps.Service_Info_Pool.OverwriteInfo(ServiceInfo) then
              dps.Prepare_UpdateServerInfoToAllClient;
        end;
  for i := 0 to C40_ClientPool.Count - 1 do
    if C40_ClientPool[i] is TC40_Dispatch_Client then
      begin
        dpc := TC40_Dispatch_Client(C40_ClientPool[i]);
        if dpc.Service_Info_Pool.OverwriteInfo(ServiceInfo) and dpc.Connected then
            dpc.PostLocalServiceInfo(True);
      end;
end;

function TC40_Custom_Service.GetHash: TMD5;
begin
  Result := ServiceInfo.Hash;
end;

function TC40_Custom_Service.GetAliasOrHash: U_String;
begin
  Result := umlTrimSpace(Alias_or_Hash___);
  if Result.L = 0 then
      Result := umlMD5ToStr(Hash);
end;

function TC40_Custom_Service.Get_P2PVM_Service(var recv_, send_: TZNet_WithP2PVM_Server): Boolean;
begin
  Result := False;
  recv_ := nil;
  send_ := nil;
  if Self is TC40_Dispatch_Service then
    begin
      recv_ := TC40_Dispatch_Service(Self).Service.RecvTunnel;
      send_ := TC40_Dispatch_Service(Self).Service.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_NoAuth_Service then
    begin
      recv_ := TC40_Base_NoAuth_Service(Self).Service.RecvTunnel;
      send_ := TC40_Base_NoAuth_Service(Self).Service.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_DataStoreNoAuth_Service then
    begin
      recv_ := TC40_Base_DataStoreNoAuth_Service(Self).Service.RecvTunnel;
      send_ := TC40_Base_DataStoreNoAuth_Service(Self).Service.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_VirtualAuth_Service then
    begin
      recv_ := TC40_Base_VirtualAuth_Service(Self).Service.RecvTunnel;
      send_ := TC40_Base_VirtualAuth_Service(Self).Service.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_DataStoreVirtualAuth_Service then
    begin
      recv_ := TC40_Base_DataStoreVirtualAuth_Service(Self).Service.RecvTunnel;
      send_ := TC40_Base_DataStoreVirtualAuth_Service(Self).Service.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_Service then
    begin
      recv_ := TC40_Base_Service(Self).Service.RecvTunnel;
      send_ := TC40_Base_Service(Self).Service.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_DataStore_Service then
    begin
      recv_ := TC40_Base_DataStore_Service(Self).Service.RecvTunnel;
      send_ := TC40_Base_DataStore_Service(Self).Service.SendTunnel;
      Result := True;
    end;
end;

function TC40_Custom_Service.Get_DB_FileName_Config(source_: U_String): U_String;
begin
  Result := ParamList.GetDefaultValue(source_, source_);
end;

function TC40_Custom_Service.Where_C4_File(fileName, ServiceTyp: U_String): U_String;
var
  tmp: U_String;
begin
  Result := '';
  if fileName = '' then
      exit;
  tmp := umlCombineFileName(umlCurrentPath, fileName);
  if umlFileExists(tmp) then
    begin
      Result := tmp;
      exit;
    end;
  tmp := umlCombineFileName(umlCombinePath(C40_RootPath, ServiceTyp.Text), fileName);
  if umlFileExists(tmp) then
    begin
      Result := tmp;
      exit;
    end;
  tmp := umlCombineFileName(C40_RootPath, fileName);
  if umlFileExists(tmp) then
    begin
      Result := tmp;
      exit;
    end;
end;

function TC40_Custom_Service.Where_C4_File(fileName: U_String): U_String;
begin
  Result := Where_C4_File(fileName, ServiceInfo.ServiceTyp);
end;

function TC40_Custom_Service.Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;
begin
  Result := TC4_Help_Console_Command_Data.Create;
  Result.Cmd := Cmd;
  Result.Desc := Desc;
  ConsoleCommand.Add(Result);
end;

procedure TC40_Custom_Service.DoLinkSuccess(Trigger_: TCore_Object);
begin
  C40PhysicsService.DoLinkSuccess(Self, Trigger_);
end;

procedure TC40_Custom_Service.DoUserOut(Trigger_: TCore_Object);
begin
  C40PhysicsService.DoUserOut(Self, Trigger_);
end;

constructor TC40_Custom_ServicePool.Create;
begin
  inherited Create;
  FIPV6_Seed := 1;
  Enabled_Auto_Sort_for_Select_And_Next_Cycle_Anchor := True;
end;

procedure TC40_Custom_ServicePool.Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    begin
      try
          Items[i].Progress;
      except
      end;
    end;
end;

procedure TC40_Custom_ServicePool.Sort_Cycle_Anchor(TaskName: U_String);

  function Compare_(L, R: TC40_Custom_Service): Integer;
  begin
    Result := CompareInt64(L.FCycle_Anchor_Temp, R.FCycle_Anchor_Temp);
  end;

  procedure fastSort_(L, R: Integer);
  var
    i, j: Integer;
    p: TC40_Custom_Service;
  begin
    repeat
      i := L;
      j := R;
      p := Items[(L + R) shr 1];
      repeat
        while Compare_(Items[i], p) < 0 do
            inc(i);
        while Compare_(Items[j], p) > 0 do
            dec(j);
        if i <= j then
          begin
            if i <> j then
                Exchange(i, j);
            inc(i);
            dec(j);
          end;
      until i > j;
      if L < j then
          fastSort_(L, j);
      L := i;
    until i >= R;
  end;

var
  i: Integer;
begin
  if Count > 1 then
    begin
      for i := 0 to Count - 1 do
          Items[i].Ready_Cycle_Anchor(TaskName);
      fastSort_(0, Count - 1);
    end;
end;

function TC40_Custom_ServicePool.Select_And_Next_Cycle_Anchor(TaskName: U_String): TC40_Custom_Service;
begin
  if Enabled_Auto_Sort_for_Select_And_Next_Cycle_Anchor then
    if Count > 1 then
      begin
        Sort_Cycle_Anchor(TaskName);
        Result.Inc_Cycle_Anchor(TaskName);
      end;
  if Count > 0 then
      Result := Items[0]
  else
      Result := nil;
end;

procedure TC40_Custom_ServicePool.MakeP2PVM_IPv6_Port(var ip6, Port: U_String);
var
  tmp: TIPV6;
  i: Integer;
begin
  for i := 0 to 7 do
      tmp[i] := FIPV6_Seed;
  Port := umlIntToStr(FIPV6_Seed);
  inc(FIPV6_Seed);
  ip6 := IPV6ToStr(tmp);
end;

function TC40_Custom_ServicePool.MakeAlias(preset_: U_String): U_String;
var
  i: Integer;
begin
  if FindAliasOrHash(preset_) = nil then
      Result := preset_
  else
    begin
      i := 1;
      repeat
        Result := PFormat('%s_%d', [preset_.Text, i]);
        inc(i);
      until FindAliasOrHash(Result) = nil;
    end;
end;

function TC40_Custom_ServicePool.ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if PhysicsAddr.Same(@Items[i].ServiceInfo.PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].ServiceInfo.PhysicsPort)) then
        exit;
  Result := False;
end;

function TC40_Custom_ServicePool.ExistsOnlyInstance(ServiceTyp: U_String): Boolean;
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
begin
  Result := False;
  Arry_ := ExtractDependInfo(ServiceTyp);
  for i := 0 to Count - 1 do
    if Items[i].ServiceInfo.OnlyInstance and Items[i].ServiceInfo.FoundServiceTyp(Arry_) then
      begin
        Result := True;
        break;
      end;
  ResetDependInfoBuff(Arry_);
end;

function TC40_Custom_ServicePool.FindHash(hash_: TMD5): TC40_Custom_Service;
var
  i: Integer;
  L: TC40_Custom_ServicePool;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if umlCompareMD5(hash_, Items[i].ServiceInfo.Hash) then
        L.Add(Items[i]);
  Result := L.Select_And_Next_Cycle_Anchor('FindHash');
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.FindAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Service;
var
  i: Integer;
  L: TC40_Custom_ServicePool;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if AliasOrhash_.Same(Items[i].AliasOrHash) then
        L.Add(Items[i]);
  Result := L.Select_And_Next_Cycle_Anchor('FindAliasOrHash');
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.FindTag(Tag: Integer): TC40_Custom_Service;
var
  i: Integer;
  L: TC40_Custom_ServicePool;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if Tag = Items[i].Tag then
        L.Add(Items[i]);
  Result := L.Select_And_Next_Cycle_Anchor('FindTag');
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.GetServiceFromHash(Hash: TMD5): TC40_Custom_Service;
var
  i: Integer;
  L: TC40_Custom_ServicePool;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if umlCompareMD5(Hash, Items[i].ServiceInfo.Hash) then
        L.Add(Items[i]);
  Result := L.Select_And_Next_Cycle_Anchor('GetServiceFromHash');
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.GetServiceFromAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Service;
var
  i: Integer;
  L: TC40_Custom_ServicePool;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if AliasOrhash_.Same(Items[i].AliasOrHash) then
        L.Add(Items[i]);
  Result := L.Select_And_Next_Cycle_Anchor('GetServiceFromAliasOrHash');
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.GetC40Array(is_ipc_mode: Boolean): TC40_Custom_Service_Array;
var
  L: TC40_Custom_ServicePool;
  i: Integer;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if (not is_ipc_mode) or (Items[i].C40PhysicsService.IPC_Mode = is_ipc_mode) then
        L.Add(Items[i]);
  L.Select_And_Next_Cycle_Anchor('GetC40Array');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.GetC40Array: TC40_Custom_Service_Array;
var
  i: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to Count - 1 do
      Result[i] := Items[i];
end;

function TC40_Custom_ServicePool.GetFromServiceTyp(ServiceTyp: U_String; is_ipc_mode: Boolean): TC40_Custom_Service_Array;
var
  Arry_: TC40_DependNetworkInfoArray;
  L: TC40_Custom_ServicePool;
  i: Integer;
begin
  Arry_ := ExtractDependInfo(ServiceTyp);
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if ((not is_ipc_mode) or (Items[i].C40PhysicsService.IPC_Mode = is_ipc_mode)) and Items[i].ServiceInfo.FoundServiceTyp(Arry_) then
        L.Add(Items[i]);
  L.Select_And_Next_Cycle_Anchor('GetFromServiceTyp');
  Result := L.GetC40Array;
  DisposeObject(L);
  ResetDependInfoBuff(Arry_);
end;

function TC40_Custom_ServicePool.GetFromServiceTyp(ServiceTyp: U_String): TC40_Custom_Service_Array;
var
  Arry_: TC40_DependNetworkInfoArray;
  L: TC40_Custom_ServicePool;
  i: Integer;
begin
  Arry_ := ExtractDependInfo(ServiceTyp);
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if Items[i].ServiceInfo.FoundServiceTyp(Arry_) then
        L.Add(Items[i]);

  L.Select_And_Next_Cycle_Anchor('GetFromServiceTyp');
  Result := L.GetC40Array;
  DisposeObject(L);
  ResetDependInfoBuff(Arry_);
end;

function TC40_Custom_ServicePool.GetFromPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word; is_ipc_mode: Boolean): TC40_Custom_Service_Array;
var
  L: TC40_Custom_ServicePool;
  i: Integer;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if (not is_ipc_mode) or (Items[i].C40PhysicsService.IPC_Mode = is_ipc_mode) then
      if ((PhysicsPort = 0) or (PhysicsPort = Items[i].ServiceInfo.PhysicsPort)) and PhysicsAddr.Same(@Items[i].ServiceInfo.PhysicsAddr) then
          L.Add(Items[i]);

  L.Select_And_Next_Cycle_Anchor('GetFromPhysicsAddr');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.GetFromPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): TC40_Custom_Service_Array;
var
  L: TC40_Custom_ServicePool;
  i: Integer;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if ((PhysicsPort = 0) or (PhysicsPort = Items[i].ServiceInfo.PhysicsPort)) and PhysicsAddr.Same(@Items[i].ServiceInfo.PhysicsAddr) then
        L.Add(Items[i]);

  L.Select_And_Next_Cycle_Anchor('GetFromPhysicsAddr');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.GetFromClass(Class_: TC40_Custom_Service_Class; is_ipc_mode: Boolean): TC40_Custom_Service_Array;
var
  L: TC40_Custom_ServicePool;
  i: Integer;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) and ((not is_ipc_mode) or (Items[i].C40PhysicsService.IPC_Mode = is_ipc_mode)) then
        L.Add(Items[i]);

  L.Select_And_Next_Cycle_Anchor('GetFromClass');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ServicePool.GetFromClass(Class_: TC40_Custom_Service_Class): TC40_Custom_Service_Array;
var
  L: TC40_Custom_ServicePool;
  i: Integer;
begin
  L := TC40_Custom_ServicePool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
        L.Add(Items[i]);

  L.Select_And_Next_Cycle_Anchor('GetFromClass');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

procedure TC40_Custom_Client.Init_Cycle_Anchor;
begin
  FCycle_Order_Default := AtomInc(C40_Cycle_Order_Seed);
  FCycle_Anchor := TString_Num64_Analysis_Tool.Create($10, FCycle_Order_Default);
  FCycle_Anchor_Temp := 0;
end;

procedure TC40_Custom_Client.Free_Cycle_Anchor;
begin
  DisposeObject(FCycle_Anchor);
end;

procedure TC40_Custom_Client.Inc_Cycle_Anchor(TaskName: U_String);
begin
  FCycle_Anchor.IncValue(TaskName, 1);
end;

procedure TC40_Custom_Client.Ready_Cycle_Anchor(TaskName: U_String);
begin
  FCycle_Anchor_Temp := FCycle_Anchor[TaskName];
end;

constructor TC40_Custom_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
var
  tmp: TPascalStringList;
begin
  inherited Create;
  Param := Param_;
  ClientInfo := TC40_Info.Create;
  ClientInfo.Assign(source_);
  ParamList := THashStringList.Create;
  ParamList.AutoUpdateDefaultValue := True;
  try
    tmp := TPascalStringList.Create;
    umlSeparatorText(Param, tmp, ',;' + #13#10);
    ParamList.ImportFromStrings(tmp);
    DisposeObject(tmp);
  except
  end;
  Param_File := Where_C4_File(ParamList.GetDefaultValue('Param_File', PFormat('C_%s.conf', [ClientInfo.ServiceTyp.Text])));
  if umlFileExists(Param_File) then
    begin
      DoStatus('(%s) "%s" found configure file: %s', [ClassName, ClientInfo.ServiceTyp.Text, Param_File.Text]);
      ParamList.LoadFromFile(Param_File);
    end;
  FLastSafeCheckTime := GetTimeTick;
  SafeCheckTime := EStrToInt64(ParamList.GetDefaultValue('SafeCheckTime', umlIntToStr(C40_SafeCheckTime)), C40_SafeCheckTime);
  Alias_or_Hash___ := ParamList.GetDefaultValue('Alias', C40_ClientPool.MakeAlias(source_.ServiceTyp));
  Tag := 0;
  Tag := EStrToInt(ParamList.GetDefaultValue('Tag', umlIntToStr(Tag)), Tag);
  if PhysicsTunnel_ = nil then
      C40PhysicsTunnel := C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(ClientInfo)
  else
      C40PhysicsTunnel := PhysicsTunnel_;
  C40PhysicsTunnel.DependNetworkClientPool.Add(Self);
  C40_ClientPool.Add(Self);
  ConsoleCommand := TC4_Help_Console_Command.Create;
  On_Client_Offline := nil;

  Init_Cycle_Anchor();
end;

destructor TC40_Custom_Client.Destroy;
begin
  Free_Cycle_Anchor();
  DisposeObject(ConsoleCommand);
  C40_ClientPool.Remove(Self);
  C40PhysicsTunnel.DependNetworkClientPool.Remove(Self);
  DisposeObject(ClientInfo);
  DisposeObject(ParamList);
  inherited Destroy;
end;

procedure TC40_Custom_Client.SafeCheck;
begin
end;

procedure TC40_Custom_Client.Progress;
begin
  if GetTimeTick - FLastSafeCheckTime > SafeCheckTime then
    begin
      try
          SafeCheck;
      except
      end;
      FLastSafeCheckTime := GetTimeTick;
    end;
end;

procedure TC40_Custom_Client.Connect;
begin
end;

function TC40_Custom_Client.Connected: Boolean;
begin
  Result := False;
end;

procedure TC40_Custom_Client.Disconnect;
begin
end;

function TC40_Custom_Client.GetHash: TMD5;
begin
  Result := ClientInfo.Hash;
end;

function TC40_Custom_Client.GetAliasOrHash: U_String;
begin
  Result := umlTrimSpace(Alias_or_Hash___);
  if Result.L = 0 then
      Result := umlMD5ToStr(Hash);
end;

function TC40_Custom_Client.Get_P2PVM_Tunnel(var recv_, send_: TZNet_WithP2PVM_Client): Boolean;
begin
  Result := False;
  recv_ := nil;
  send_ := nil;
  if Self is TC40_Dispatch_Client then
    begin
      recv_ := TC40_Dispatch_Client(Self).Client.RecvTunnel;
      send_ := TC40_Dispatch_Client(Self).Client.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_NoAuth_Client then
    begin
      recv_ := TC40_Base_NoAuth_Client(Self).Client.RecvTunnel;
      send_ := TC40_Base_NoAuth_Client(Self).Client.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_DataStoreNoAuth_Client then
    begin
      recv_ := TC40_Base_DataStoreNoAuth_Client(Self).Client.RecvTunnel;
      send_ := TC40_Base_DataStoreNoAuth_Client(Self).Client.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_VirtualAuth_Client then
    begin
      recv_ := TC40_Base_VirtualAuth_Client(Self).Client.RecvTunnel;
      send_ := TC40_Base_VirtualAuth_Client(Self).Client.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_DataStoreVirtualAuth_Client then
    begin
      recv_ := TC40_Base_DataStoreVirtualAuth_Client(Self).Client.RecvTunnel;
      send_ := TC40_Base_DataStoreVirtualAuth_Client(Self).Client.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_Client then
    begin
      recv_ := TC40_Base_Client(Self).Client.RecvTunnel;
      send_ := TC40_Base_Client(Self).Client.SendTunnel;
      Result := True;
    end
  else if Self is TC40_Base_DataStore_Client then
    begin
      recv_ := TC40_Base_DataStore_Client(Self).Client.RecvTunnel;
      send_ := TC40_Base_DataStore_Client(Self).Client.SendTunnel;
      Result := True;
    end;
end;

function TC40_Custom_Client.Get_DB_FileName_Config(source_: U_String): U_String;
begin
  Result := ParamList.GetDefaultValue(source_, source_);
end;

function TC40_Custom_Client.Where_C4_File(fileName: U_String): U_String;
var
  tmp: U_String;
begin
  Result := '';
  if fileName = '' then
      exit;
  tmp := umlCombineFileName(umlCurrentPath, fileName);
  if umlFileExists(tmp) then
    begin
      Result := tmp;
      exit;
    end;
  tmp := umlCombineFileName(umlCombinePath(C40_RootPath, ClientInfo.ServiceTyp.Text), fileName);
  if umlFileExists(tmp) then
    begin
      Result := tmp;
      exit;
    end;
  tmp := umlCombineFileName(C40_RootPath, fileName);
  if umlFileExists(tmp) then
    begin
      Result := tmp;
      exit;
    end;
end;

function TC40_Custom_Client.Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;
begin
  Result := TC4_Help_Console_Command_Data.Create;
  Result.Cmd := Cmd;
  Result.Desc := Desc;
  ConsoleCommand.Add(Result);
end;

function TC40_Custom_Client.IsLocal: Boolean;
begin
  Result := C40PhysicsTunnel.IPC_Mode() or C40PhysicsTunnel.IsLoopbackNetwork() or C40PhysicsTunnel.IsLocalNetwork();
end;

procedure TC40_Custom_Client.DoNetworkOnline;
begin
  C40PhysicsTunnel.DoNetworkOnline(Self);
end;

procedure TC40_Custom_Client.DoNetworkOffline;
begin
  try
    if Assigned(On_Client_Offline) then
        On_Client_Offline(Self);
  except
  end;
end;

constructor TC40_Custom_ClientPool.Create;
begin
  inherited Create;
  Enabled_Auto_Sort_for_Select_And_Next_Cycle_Anchor := True;
end;

procedure TC40_Custom_ClientPool.Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    begin
      try
          Items[i].Progress;
      except
      end;
    end;
end;

procedure TC40_Custom_ClientPool.Sort_Cycle_Anchor(TaskName: U_String);

  function Compare_(L, R: TC40_Custom_Client): Integer;
  begin
    Result := CompareInt64(L.FCycle_Anchor_Temp, R.FCycle_Anchor_Temp);
  end;

  procedure fastSort_(L, R: Integer);
  var
    i, j: Integer;
    p: TC40_Custom_Client;
  begin
    repeat
      i := L;
      j := R;
      p := Items[(L + R) shr 1];
      repeat
        while Compare_(Items[i], p) < 0 do
            inc(i);
        while Compare_(Items[j], p) > 0 do
            dec(j);
        if i <= j then
          begin
            if i <> j then
                Exchange(i, j);
            inc(i);
            dec(j);
          end;
      until i > j;
      if L < j then
          fastSort_(L, j);
      L := i;
    until i >= R;
  end;

var
  i: Integer;
begin
  if Count > 1 then
    begin
      for i := 0 to Count - 1 do
          Items[i].Ready_Cycle_Anchor(TaskName);
      fastSort_(0, Count - 1);
    end;
end;

function TC40_Custom_ClientPool.Select_And_Next_Cycle_Anchor(TaskName: U_String): TC40_Custom_Client;
begin
  if Enabled_Auto_Sort_for_Select_And_Next_Cycle_Anchor then
    if Count > 1 then
      begin
        Sort_Cycle_Anchor(TaskName);
        Result.Inc_Cycle_Anchor(TaskName);
      end;
  if Count > 0 then
      Result := Items[0]
  else
      Result := nil;
end;

function TC40_Custom_ClientPool.MakeAlias(preset_: U_String): U_String;
var
  i: Integer;
begin
  if FindAliasOrHash(preset_) = nil then
      Result := preset_
  else
    begin
      i := 1;
      repeat
        Result := PFormat('%s_%d', [preset_.Text, i]);
        inc(i);
      until FindAliasOrHash(Result) = nil;
    end;
end;

function TC40_Custom_ClientPool.ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if PhysicsAddr.Same(@Items[i].ClientInfo.PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].ClientInfo.PhysicsPort)) then
        exit;
  Result := False;
end;

function TC40_Custom_ClientPool.ExistsServiceInfo(info_: TC40_Info): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if info_.Same(Items[i].ClientInfo) then
        exit;
  Result := False;
end;

function TC40_Custom_ClientPool.ExistsServiceTyp(ServiceTyp: U_String): Boolean;
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
begin
  Arry_ := ExtractDependInfo(ServiceTyp);
  Result := False;
  for i := 0 to Count - 1 do
    if Items[i].ClientInfo.FoundServiceTyp(Arry_) then
      begin
        Result := True;
        break;
      end;
  ResetDependInfoBuff(Arry_);
end;

function TC40_Custom_ClientPool.FindPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if PhysicsAddr.Same(@Items[i].ClientInfo.PhysicsAddr) and ((PhysicsPort = 0) or (PhysicsPort = Items[i].ClientInfo.PhysicsPort)) then
        exit;
  Result := False;
end;

function TC40_Custom_ClientPool.FindServiceInfo(info_: TC40_Info): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to Count - 1 do
    if info_.Same(Items[i].ClientInfo) then
        exit;
  Result := False;
end;

function TC40_Custom_ClientPool.FindServiceTyp(ServiceTyp: U_String): Boolean;
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
begin
  Arry_ := ExtractDependInfo(ServiceTyp);
  Result := False;
  for i := 0 to Count - 1 do
    if Items[i].ClientInfo.FoundServiceTyp(Arry_) then
      begin
        Result := True;
        break;
      end;
  ResetDependInfoBuff(Arry_);
end;

function TC40_Custom_ClientPool.FindHash(hash_: TMD5; isConnected: Boolean): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if umlCompareMD5(hash_, Items[i].ClientInfo.Hash) and ((not isConnected) or (isConnected and Items[i].Connected)) then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('FindHash');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.FindHash(hash_: TMD5): TC40_Custom_Client;
begin
  Result := FindHash(hash_, False);
end;

function TC40_Custom_ClientPool.FindAliasOrHash(AliasOrhash_: U_String; isConnected: Boolean): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if AliasOrhash_.Same(Items[i].AliasOrHash) and ((not isConnected) or (isConnected and Items[i].Connected)) then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('FindAliasOrHash');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.FindAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Client;
begin
  Result := FindAliasOrHash(AliasOrhash_, False);
end;

function TC40_Custom_ClientPool.FindTag(Tag: Integer): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if Tag = Items[i].Tag then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('FindTag');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.ExistsClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('ExistsClass');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.ExistsConnectedClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) and Items[i].Connected then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('ExistsConnectedClass');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.ExistsConnectedServiceTyp(ServiceTyp: U_String): TC40_Custom_Client;
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;
  Arry_ := ExtractDependInfo(ServiceTyp);

  try
    for i := 0 to Count - 1 do
      if Items[i].Connected and Items[i].ClientInfo.FoundServiceTyp(Arry_) then
          L.Add(Items[i]);

    Result := L.Select_And_Next_Cycle_Anchor('ExistsConnectedServiceTyp');
    DisposeObject(L);
  finally
      ResetDependInfoBuff(Arry_);
  end;
end;

function TC40_Custom_ClientPool.ExistsConnectedServiceTypAndClass(ServiceTyp: U_String; Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;
  Arry_ := ExtractDependInfo(ServiceTyp);
  try
    for i := 0 to Count - 1 do
      if Items[i].InheritsFrom(Class_) and Items[i].Connected and Items[i].ClientInfo.FoundServiceTyp(Arry_) then
          L.Add(Items[i]);

    Result := L.Select_And_Next_Cycle_Anchor('ExistsConnectedServiceTypAndClass');
    DisposeObject(L);
  finally
      ResetDependInfoBuff(Arry_);
  end;
end;

function TC40_Custom_ClientPool.FindClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('FindClass');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.FindConnectedClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) and Items[i].Connected then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('FindConnectedClass');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.FindConnectedServiceTyp(ServiceTyp: U_String): TC40_Custom_Client;
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  Arry_ := ExtractDependInfo(ServiceTyp);
  try
    for i := 0 to Count - 1 do
      if Items[i].Connected and Items[i].ClientInfo.FoundServiceTyp(Arry_) then
          L.Add(Items[i]);

    Result := L.Select_And_Next_Cycle_Anchor('FindConnectedServiceTyp');
    DisposeObject(L);
  finally
      ResetDependInfoBuff(Arry_);
  end;
end;

function TC40_Custom_ClientPool.FindConnectedServiceTypAndClass(ServiceTyp: U_String; Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
var
  Arry_: TC40_DependNetworkInfoArray;
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;
  Arry_ := ExtractDependInfo(ServiceTyp);

  try
    for i := 0 to Count - 1 do
      if Items[i].InheritsFrom(Class_) and Items[i].Connected and Items[i].ClientInfo.FoundServiceTyp(Arry_) then
          L.Add(Items[i]);

    Result := L.Select_And_Next_Cycle_Anchor('FindConnectedServiceTypAndClass');
    DisposeObject(L);
  finally
      ResetDependInfoBuff(Arry_);
  end;
end;

function TC40_Custom_ClientPool.GetClientFromHash(Hash: TMD5): TC40_Custom_Client;
var
  i: Integer;
  L: TC40_Custom_ClientPool;
begin
  L := TC40_Custom_ClientPool.Create;

  for i := 0 to Count - 1 do
    if umlCompareMD5(Hash, Items[i].ClientInfo.Hash) then
        L.Add(Items[i]);

  Result := L.Select_And_Next_Cycle_Anchor('GetClientFromHash');
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.GetC40Array(is_ipc_mode: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if ((not is_ipc_mode) or (Items[i].C40PhysicsTunnel.IPC_Mode and is_ipc_mode)) then
        L.Add(Items[i]);

  L.Select_And_Next_Cycle_Anchor('GetC40Array');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.GetC40Array: TC40_Custom_Client_Array;
var
  i: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to Count - 1 do
      Result[i] := Items[i];
end;

function TC40_Custom_ClientPool.SearchServiceTyp(ServiceTyp: U_String; isConnected: Boolean): TC40_Custom_Client_Array;
var
  Arry_: TC40_DependNetworkInfoArray;
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  Arry_ := ExtractDependInfo(ServiceTyp);
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if Items[i].ClientInfo.FoundServiceTyp(Arry_) then
      if (not isConnected) or (isConnected and Items[i].Connected) then
          L.Add(Items[i]);
  L.Select_And_Next_Cycle_Anchor('SearchServiceTyp');
  Result := L.GetC40Array;
  DisposeObject(L);
  ResetDependInfoBuff(Arry_);
end;

function TC40_Custom_ClientPool.SearchServiceTyp(ServiceTyp: U_String): TC40_Custom_Client_Array;
begin
  Result := SearchServiceTyp(ServiceTyp, False);
end;

function TC40_Custom_ClientPool.SearchPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word; isConnected: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if ((PhysicsPort = 0) or (PhysicsPort = Items[i].ClientInfo.PhysicsPort)) and PhysicsAddr.Same(@Items[i].ClientInfo.PhysicsAddr) then
      if (not isConnected) or (isConnected and Items[i].Connected) then
          L.Add(Items[i]);
  L.Select_And_Next_Cycle_Anchor('SearchPhysicsAddr');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.SearchPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): TC40_Custom_Client_Array;
begin
  Result := SearchPhysicsAddr(PhysicsAddr, PhysicsPort, False);
end;

function TC40_Custom_ClientPool.SearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode, is_local_network: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
      if (not is_ipc_mode) or (Items[i].C40PhysicsTunnel.IPC_Mode and is_ipc_mode) then
        if (not is_local_network) or (Items[i].C40PhysicsTunnel.IsLocalNetwork and is_local_network) then
          if (not isConnected) or (isConnected and Items[i].Connected) then
              L.Add(Items[i]);
  L.Select_And_Next_Cycle_Anchor('SearchClass');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.SearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) and ((not is_ipc_mode) or (Items[i].C40PhysicsTunnel.IPC_Mode and is_ipc_mode)) then
      if (not isConnected) or (isConnected and Items[i].Connected) then
          L.Add(Items[i]);
  L.Select_And_Next_Cycle_Anchor('SearchClass');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.SearchClass(Class_: TC40_Custom_Client_Class; isConnected: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
      if (not isConnected) or (isConnected and Items[i].Connected) then
          L.Add(Items[i]);
  L.Select_And_Next_Cycle_Anchor('SearchClass');
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.SearchClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client_Array;
begin
  Result := SearchClass(Class_, False);
end;

function TC40_Custom_ClientPool.FastFindClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
      begin
        Result := Items[i];
        exit;
      end;
end;

function TC40_Custom_ClientPool.FastSearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode, is_local_network: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
      if (not is_ipc_mode) or (Items[i].C40PhysicsTunnel.IPC_Mode and is_ipc_mode) then
        if (not is_local_network) or (Items[i].C40PhysicsTunnel.IsLocalNetwork and is_local_network) then
          if (not isConnected) or (isConnected and Items[i].Connected) then
              L.Add(Items[i]);
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.FastSearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) and ((not is_ipc_mode) or (Items[i].C40PhysicsTunnel.IPC_Mode and is_ipc_mode)) then
      if (not isConnected) or (isConnected and Items[i].Connected) then
          L.Add(Items[i]);
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.FastSearchClass(Class_: TC40_Custom_Client_Class; isConnected: Boolean): TC40_Custom_Client_Array;
var
  L: TC40_Custom_ClientPool;
  i: Integer;
begin
  L := TC40_Custom_ClientPool.Create;
  for i := 0 to Count - 1 do
    if Items[i].InheritsFrom(Class_) then
      if (not isConnected) or (isConnected and Items[i].Connected) then
          L.Add(Items[i]);
  Result := L.GetC40Array;
  DisposeObject(L);
end;

function TC40_Custom_ClientPool.FastSearchClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client_Array;
begin
  Result := FastSearchClass(Class_, False);
end;

procedure TC40_Custom_ClientPool.WaitConnectedDoneC(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventC);
var
  tmp: TC40_Custom_ClientPool_Wait;
begin
  tmp := TC40_Custom_ClientPool_Wait.Create(dependNetwork_);
  tmp.Pool_ := Self;
  tmp.On_C := OnResult;
  SystemPostProgress.PostExecuteM_NP(0.1, tmp.DoRun);
end;

procedure TC40_Custom_ClientPool.WaitConnectedDoneM(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventM);
var
  tmp: TC40_Custom_ClientPool_Wait;
begin
  tmp := TC40_Custom_ClientPool_Wait.Create(dependNetwork_);
  tmp.Pool_ := Self;
  tmp.On_M := OnResult;
  SystemPostProgress.PostExecuteM_NP(0.1, tmp.DoRun);
end;

procedure TC40_Custom_ClientPool.WaitConnectedDoneP(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventP);
var
  tmp: TC40_Custom_ClientPool_Wait;
begin
  tmp := TC40_Custom_ClientPool_Wait.Create(dependNetwork_);
  tmp.Pool_ := Self;
  tmp.On_P := OnResult;
  SystemPostProgress.PostExecuteM_NP(0.1, tmp.DoRun);
end;

procedure TC40_Auto_Deployment_Client<T_>.Do_Deployment_Ready(States: TC40_Custom_ClientPool_Wait_States);
var
  i: Integer;
  cc: TC40_Custom_Client;
begin
  FClient_Ptr^ := nil;
  for i := 0 to C40_ClientPool.Count - 1 do
    begin
      cc := C40_ClientPool[i];
      if cc is T_ then
          FClient_Ptr^ := cc as T_;
    end;
  if FClient_Ptr^ <> nil then
    begin
      if TC40_Custom_Client(FClient_Ptr^).Connected then
        begin
          try
            if Assigned(FOn_Ready_M) then
                FOn_Ready_M(FClient_Ptr^)
            else if Assigned(FOn_Ready_C) then
                FOn_Ready_C(FClient_Ptr^)
            else if Assigned(FOn_Ready_P) then
                FOn_Ready_P(FClient_Ptr^);
          except
          end;
          DoStatus('deployment "%s"::%s ready ok.', [TC40_Custom_Client(FClient_Ptr^).ClientInfo.ServiceTyp.Text, TC40_Custom_Client(FClient_Ptr^).ClassName]);
        end
      else
          DoStatus('deployment "%s"::%s error!', [TC40_Custom_Client(FClient_Ptr^).ClientInfo.ServiceTyp.Text, TC40_Custom_Client(FClient_Ptr^).ClassName]);
      DelayFreeObj(1.0, Self);
    end;
end;

constructor TC40_Auto_Deployment_Client<T_>.Create_Ptr(dependNetwork_: U_String; Client_: PT_);
begin
  inherited Create;
  FClient_Second := nil;
  if Client_ = nil then
    begin
      FClient_Ptr := @FClient_Second;
    end
  else
    begin
      FClient_Ptr := Client_;
    end;
  FDependNetwork := dependNetwork_;
  FOn_Ready_C := nil;
  FOn_Ready_M := nil;
  FOn_Ready_P := nil;
  C40_ClientPool.WaitConnectedDoneM(FDependNetwork, Do_Deployment_Ready);
end;

constructor TC40_Auto_Deployment_Client<T_>.Create(dependNetwork_: U_String; var Client: T_);
begin
  Create_Ptr(dependNetwork_, @Client);
end;

constructor TC40_Auto_Deployment_Client<T_>.Create(var Client: T_);
var
  n: U_String;
begin
  n := GetRegisterClientTypFromClass(TC40_Custom_Client_Class(T_));
  Create(n, Client);
end;

constructor TC40_Auto_Deployment_Client<T_>.Create_C(OnReady: TOn_Ready_C);
var
  n: U_String;
  p: PT_;
begin
  n := GetRegisterClientTypFromClass(TC40_Custom_Client_Class(T_));
  p := nil;
  Create_Ptr(n, p);
  On_Ready_C := OnReady;
end;

constructor TC40_Auto_Deployment_Client<T_>.Create_M(OnReady: TOn_Ready_M);
var
  n: U_String;
  p: PT_;
begin
  n := GetRegisterClientTypFromClass(TC40_Custom_Client_Class(T_));
  p := nil;
  Create_Ptr(n, p);
  On_Ready_M := OnReady;
end;

constructor TC40_Auto_Deployment_Client<T_>.Create_P(OnReady: TOn_Ready_P);
var
  n: U_String;
  p: PT_;
begin
  n := GetRegisterClientTypFromClass(TC40_Custom_Client_Class(T_));
  p := nil;
  Create_Ptr(n, p);
  On_Ready_P := OnReady;
end;

constructor TC40_Auto_Deployment_Client<T_>.Create_C2(dependNetwork_: U_String; OnReady: TOn_Ready_C);
var
  p: PT_;
begin
  p := nil;
  Create_Ptr(dependNetwork_, p);
  On_Ready_C := OnReady;
end;

constructor TC40_Auto_Deployment_Client<T_>.Create_M2(dependNetwork_: U_String; OnReady: TOn_Ready_M);
var
  p: PT_;
begin
  p := nil;
  Create_Ptr(dependNetwork_, p);
  On_Ready_M := OnReady;
end;

constructor TC40_Auto_Deployment_Client<T_>.Create_P2(dependNetwork_: U_String; OnReady: TOn_Ready_P);
var
  p: PT_;
begin
  p := nil;
  Create_Ptr(dependNetwork_, p);
  On_Ready_P := OnReady;
end;

destructor TC40_Auto_Deployment_Client<T_>.Destroy;
begin
  inherited Destroy;
end;

constructor TOnRemovePhysicsNetwork.Create;
begin
  PhysicsAddr := '';
  PhysicsPort := 0;
end;

procedure TOnRemovePhysicsNetwork.DoRun;
begin
  C40RemovePhysics(PhysicsAddr, PhysicsPort, True, True, True, True);
  DelayFreeObject(1.0, Self);
end;

procedure TC40_Dispatch_Service.cmd_UpdateServiceInfo(Sender: TPeerIO; InData: TDFE);
begin
  if Service_Info_Pool.MergeFromDF(InData) then
    begin
      Prepare_UpdateServerInfoToAllClient;
      if Assigned(FOnServiceInfoChange) then
          FOnServiceInfoChange(Self, Service_Info_Pool);
    end;
end;

procedure TC40_Dispatch_Service.cmd_UpdateServiceState(Sender: TPeerIO; InData: TDFE);
var
  D, ND: TDFE;
  Hash__: TMD5;
  Workload, MaxWorkload: Integer;
  info_: TC40_Info;
  i: Integer;
  S_IO: TPeerIO;
  Arry_: TIO_Array;
  ID_: Cardinal;
  IO_: TPeerIO;
begin
  ND := TDFE.Create;
  D := TDFE.Create;
  while InData.R.NotEnd do
    begin
      InData.R.ReadDataFrame(D);
      Hash__ := D.R.ReadMD5;
      Workload := D.R.ReadInteger;
      MaxWorkload := D.R.ReadInteger;
      info_ := Service_Info_Pool.FindHash(Hash__);
      if (info_ <> nil) then
        begin
          if (info_.Workload <> Workload) or (info_.MaxWorkload <> MaxWorkload) then
              ND.WriteDataFrame(D);
          info_.Workload := Workload;
          info_.MaxWorkload := MaxWorkload;
        end;
    end;
  DisposeObject(D);
  for i := 0 to C40_ServicePool.Count - 1 do
    begin
      info_ := Service_Info_Pool.FindSame(C40_ServicePool[i].ServiceInfo);
      if info_ <> nil then
          info_.Assign(C40_ServicePool[i].ServiceInfo);
    end;
  if ND.Count > 0 then
    begin
      S_IO := nil;
      if Service.DTService.GetUserDefineRecvTunnel(Sender).LinkOk then
          S_IO := Service.DTService.GetUserDefineRecvTunnel(Sender).SendTunnel.Owner;
      Service.SendTunnel.GetIO_Array(Arry_);
      for ID_ in Arry_ do
        begin
          IO_ := Service.SendTunnel[ID_];
          if (IO_ <> nil) and (IO_ <> S_IO) and TService_SendTunnel_UserDefine_NoAuth(IO_.UserDefine).LinkOk then
              IO_.SendStreamNotifyCmd('UpdateServiceState', ND);
        end;
    end;
  DisposeObject(ND);
end;

procedure TC40_Dispatch_Service.cmd_IgnoreChange(Sender: TPeerIO; InData: TDFE);
var
  Hash__: TMD5;
  Ignored: Boolean;
  info_: TC40_Info;
begin
  Hash__ := InData.R.ReadMD5;
  Ignored := InData.R.ReadBool;
  info_ := Service_Info_Pool.FindHash(Hash__);
  if (info_ <> nil) and (info_.Ignored <> Ignored) then
    begin
      info_.Ignored := Ignored;
      IgnoreChangeToAllClient(info_.Hash, info_.Ignored);
    end;
end;

procedure TC40_Dispatch_Service.cmd_RequestUpdate(Sender: TPeerIO; InData: TDFE);
begin
  Prepare_UpdateServerInfoToAllClient;
end;

procedure TC40_Dispatch_Service.cmd_RemovePhysicsNetwork(Sender: TPeerIO; InData: TDFE);
var
  tmp: TOnRemovePhysicsNetwork;
  Arry_: TIO_Array;
  ID_: Cardinal;
  IO_: TPeerIO;
  IODef_: TService_RecvTunnel_UserDefine_NoAuth;
begin
  tmp := TOnRemovePhysicsNetwork.Create;
  tmp.PhysicsAddr := InData.R.ReadString;
  tmp.PhysicsPort := InData.R.ReadWord;
  SysPost.PostExecuteM_NP(2.0, tmp.DoRun);
  if C40ExistsPhysicsNetwork(tmp.PhysicsAddr, tmp.PhysicsPort) then
    begin
      Service.RecvTunnel.GetIO_Array(Arry_);
      for ID_ in Arry_ do
        begin
          IO_ := Service.RecvTunnel[ID_];
          if (IO_ <> nil) and (IO_ <> Sender) and TService_RecvTunnel_UserDefine_NoAuth(IO_.UserDefine).LinkOk then
            begin
              IODef_ := TService_RecvTunnel_UserDefine_NoAuth(IO_.UserDefine);
              IODef_.SendTunnel.Owner.SendStreamNotifyCmd('RemovePhysicsNetwork', InData);
            end;
        end;
    end;
end;

procedure TC40_Dispatch_Service.Prepare_UpdateServerInfoToAllClient;
begin
  FWaiting_UpdateServerInfoToAllClient := True;
  FWaiting_UpdateServerInfoToAllClient_TimeTick := GetTimeTick + C40_UpdateServiceInfoDelayTime;
end;

procedure TC40_Dispatch_Service.UpdateServerInfoToAllClient;
var
  D: TDFE;
  Arry_: TIO_Array;
  ID_: Cardinal;
  IO_: TPeerIO;
begin
  D := TDFE.Create;
  Service_Info_Pool.SaveToDF(D);
  Service.SendTunnel.GetIO_Array(Arry_);
  for ID_ in Arry_ do
    begin
      IO_ := Service.SendTunnel[ID_];
      if (IO_ <> nil) and TService_SendTunnel_UserDefine_NoAuth(IO_.UserDefine).LinkOk then
          IO_.SendStreamNotifyCmd('UpdateServiceInfo', D);
    end;
  DisposeObject(D);
end;

procedure TC40_Dispatch_Service.DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Dispatch_Service.DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoUserOut(UserDefineIO);
end;

procedure TC40_Dispatch_Service.DoDelayCheckLocalServiceInfo;
var
  i: Integer;
  isChange_: Boolean;
  info_: TC40_Info;
begin
  DelayCheck_Working := False;
  isChange_ := False;
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i].C40PhysicsService.Activted then
      begin
        info_ := Service_Info_Pool.FindSame(C40_ServicePool[i].ServiceInfo);
        if info_ = nil then
          begin
            Service_Info_Pool.Add(C40_ServicePool[i].ServiceInfo.Clone);
            isChange_ := True;
          end
        else
            info_.Assign(C40_ServicePool[i].ServiceInfo);
      end;
  if isChange_ then
    begin
      Prepare_UpdateServerInfoToAllClient;
    end
  else
    begin
      UpdateServiceStateToAllClient;
    end;
end;

constructor TC40_Dispatch_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
var
  bak_: Boolean;
  i: Integer;
begin
  bak_ := C40_EnablePerServiceDirectory;
  C40_EnablePerServiceDirectory := False;
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  C40_EnablePerServiceDirectory := bak_;
  FOnServiceInfoChange := nil;
  FWaiting_UpdateServerInfoToAllClient := False;
  FWaiting_UpdateServerInfoToAllClient_TimeTick := 0;
  DelayCheck_Working := False;
  Service := TDT_P2PVM_NoAuth_Custom_Service.Create(TDTService_NoAuth, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.FileSystem := False;
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicFileDirectory := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      if not umlDirectoryExists(Service.DTService.PublicFileDirectory) then
          umlCreateDirectory(Service.DTService.PublicFileDirectory);
    end
  else
    begin
      Service.DTService.PublicFileDirectory := C40_RootPath;
    end;
  Service.RecvTunnel.RegisterStreamNotify('UpdateServiceInfo').OnExecute := cmd_UpdateServiceInfo;
  Service.RecvTunnel.RegisterStreamNotify('UpdateServiceState').OnExecute := cmd_UpdateServiceState;
  Service.RecvTunnel.RegisterStreamNotify('IgnoreChange').OnExecute := cmd_IgnoreChange;
  Service.RecvTunnel.RegisterStreamNotify('RequestUpdate').OnExecute := cmd_RequestUpdate;
  Service.RecvTunnel.RegisterStreamNotify('RemovePhysicsNetwork').OnExecute := cmd_RemovePhysicsNetwork;
  Service.RecvTunnel.PrintParams['UpdateServiceInfo'] := False;
  Service.RecvTunnel.PrintParams['UpdateServiceState'] := False;
  Service.RecvTunnel.PrintParams['IgnoreChange'] := False;
  Service.RecvTunnel.PrintParams['RequestUpdate'] := False;
  Service.SendTunnel.PrintParams['UpdateServiceInfo'] := False;
  Service.SendTunnel.PrintParams['UpdateServiceState'] := False;
  Service.SendTunnel.PrintParams['IgnoreChange'] := False;
  Service.SendTunnel.PrintParams['RequestUpdate'] := False;
  Service_Info_Pool := TC40_InfoList.Create(True);
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i].C40PhysicsService.Activted then
      if Service_Info_Pool.FindSame(C40_ServicePool[i].ServiceInfo) = nil then
          Service_Info_Pool.Add(C40_ServicePool[i].ServiceInfo.Clone);
  UpdateToGlobalDispatch;
end;

destructor TC40_Dispatch_Service.Destroy;
begin
  DisposeObject(Service);
  DisposeObject(Service_Info_Pool);
  inherited Destroy;
end;

procedure TC40_Dispatch_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  if FWaiting_UpdateServerInfoToAllClient and (GetTimeTick > FWaiting_UpdateServerInfoToAllClient_TimeTick) then
    begin
      FWaiting_UpdateServerInfoToAllClient := False;
      FWaiting_UpdateServerInfoToAllClient_TimeTick := 0;
      UpdateServerInfoToAllClient;
    end;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
  if not DelayCheck_Working then
    begin
      DelayCheck_Working := True;
      C40PhysicsService.PhysicsTunnel.PostProgress.PostExecuteM_NP(2.0, DoDelayCheckLocalServiceInfo);
    end;
end;

procedure TC40_Dispatch_Service.IgnoreChangeToAllClient(Hash__: TMD5; Ignored: Boolean);
var
  D: TDFE;
  Arry_: TIO_Array;
  ID_: Cardinal;
  IO_: TPeerIO;
begin
  D := TDFE.Create;
  D.WriteMD5(Hash__);
  D.WriteBool(Ignored);
  Service.SendTunnel.GetIO_Array(Arry_);
  for ID_ in Arry_ do
    begin
      IO_ := Service.SendTunnel[ID_];
      if (IO_ <> nil) and TService_SendTunnel_UserDefine_NoAuth(IO_.UserDefine).LinkOk then
          IO_.SendStreamNotifyCmd('IgnoreChange', D);
    end;
  DisposeObject(D);
end;

procedure TC40_Dispatch_Service.UpdateServiceStateToAllClient;
var
  i: Integer;
  D, tmp: TDFE;
  info_: TC40_Info;
  Arry_: TIO_Array;
  ID_: Cardinal;
  IO_: TPeerIO;
begin
  D := TDFE.Create;
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i].C40PhysicsService.Activted then
      begin
        info_ := C40_ServicePool[i].ServiceInfo;
        tmp := TDFE.Create;
        tmp.WriteMD5(info_.Hash);
        tmp.WriteInteger(info_.Workload);
        tmp.WriteInteger(info_.MaxWorkload);
        D.WriteDataFrame(tmp);
        DisposeObject(tmp);
      end;
  Service.SendTunnel.GetIO_Array(Arry_);
  for ID_ in Arry_ do
    begin
      IO_ := Service.SendTunnel[ID_];
      if (IO_ <> nil) and TService_SendTunnel_UserDefine_NoAuth(IO_.UserDefine).LinkOk then
          IO_.SendStreamNotifyCmd('UpdateServiceState', D);
    end;
  DisposeObject(D);
end;

procedure TC40_Dispatch_Client.cmd_UpdateServiceInfo(Sender: TPeerIO; InData: TDFE);
var
  i: Integer;
  Arry_: TC40_Custom_Client_Array;
  cc: TC40_Custom_Client;
begin
  if Service_Info_Pool.MergeFromDF(InData) then
    begin
      if Assigned(FOnServiceInfoChange) then
          FOnServiceInfoChange(Self, Service_Info_Pool);
      Arry_ := C40_ClientPool.SearchClass(TC40_Dispatch_Client, True);
      for cc in Arry_ do
        if (cc <> Self) then
            TC40_Dispatch_Client(cc).Client.SendTunnel.SendStreamNotifyCmd('UpdateServiceInfo', InData);
    end;
end;

procedure TC40_Dispatch_Client.cmd_UpdateServiceState(Sender: TPeerIO; InData: TDFE);
var
  D: TDFE;
  Hash__: TMD5;
  Workload, MaxWorkload: Integer;
  info_: TC40_Info;
  i, j: Integer;
begin
  D := TDFE.Create;
  while InData.R.NotEnd do
    begin
      InData.R.ReadDataFrame(D);
      Hash__ := D.R.ReadMD5;
      Workload := D.R.ReadInteger;
      MaxWorkload := D.R.ReadInteger;
      info_ := Service_Info_Pool.FindHash(Hash__);
      if (info_ <> nil) then
        begin
          info_.Workload := Workload;
          info_.MaxWorkload := MaxWorkload;
          for j := 0 to C40_ClientPool.Count - 1 do
            if C40_ClientPool[j].ClientInfo.Same(info_) then
                C40_ClientPool[j].ClientInfo.Assign(info_);
        end;
      for i := 0 to C40_ServicePool.Count - 1 do
        if (C40_ServicePool[i] is TC40_Dispatch_Service) then
          begin
            info_ := TC40_Dispatch_Service(C40_ServicePool[i]).Service_Info_Pool.FindHash(Hash__);
            if (info_ <> nil) then
              begin
                info_.Workload := Workload;
                info_.MaxWorkload := MaxWorkload;
              end;
          end;
    end;
  DisposeObject(D);
  for i := 0 to C40_ServicePool.Count - 1 do
    begin
      info_ := Service_Info_Pool.FindSame(C40_ServicePool[i].ServiceInfo);
      if info_ <> nil then
          info_.Assign(C40_ServicePool[i].ServiceInfo);
    end;
end;

procedure TC40_Dispatch_Client.cmd_IgnoreChange(Sender: TPeerIO; InData: TDFE);
var
  Hash__: TMD5;
  Ignored: Boolean;
  info_: TC40_Info;
  Arry_: TC40_Custom_Client_Array;
  cc: TC40_Custom_Client;
  j: Integer;
begin
  Hash__ := InData.R.ReadMD5;
  Ignored := InData.R.ReadBool;
  info_ := Service_Info_Pool.FindHash(Hash__);
  if (info_ <> nil) then
    begin
      info_.Ignored := Ignored;
      for j := 0 to C40_ClientPool.Count - 1 do
        if C40_ClientPool[j].ClientInfo.Same(info_) then
            C40_ClientPool[j].ClientInfo.Assign(info_);
    end;
  Arry_ := C40_ClientPool.SearchClass(TC40_Dispatch_Client, True);
  for cc in Arry_ do
    if (cc <> Self) then
        TC40_Dispatch_Client(cc).Client.SendTunnel.SendStreamNotifyCmd('IgnoreChange', InData);
end;

procedure TC40_Dispatch_Client.cmd_RemovePhysicsNetwork(Sender: TPeerIO; InData: TDFE);
var
  tmp: TOnRemovePhysicsNetwork;
  Arry_: TC40_Custom_Client_Array;
  cc: TC40_Custom_Client;
begin
  tmp := TOnRemovePhysicsNetwork.Create;
  tmp.PhysicsAddr := InData.R.ReadString;
  tmp.PhysicsPort := InData.R.ReadWord;
  SysPost.PostExecuteM_NP(2.0, tmp.DoRun);
  if C40ExistsPhysicsNetwork(tmp.PhysicsAddr, tmp.PhysicsPort) then
    begin
      Arry_ := C40_ClientPool.SearchClass(TC40_Dispatch_Client, True);
      for cc in Arry_ do
        if (cc <> Self) then
            TC40_Dispatch_Client(cc).Client.SendTunnel.SendStreamNotifyCmd('RemovePhysicsNetwork', InData);
    end;
end;

procedure TC40_Dispatch_Client.Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client);
begin
  PostLocalServiceInfo(True);
  RequestUpdate();
  DoNetworkOnline();
end;

procedure TC40_Dispatch_Client.DoDelayCheckLocalServiceInfo;
var
  i: Integer;
begin
  DelayCheck_Working := False;
  PostLocalServiceInfo(False);
  UpdateLocalServiceState;
  for i := 0 to Service_Info_Pool.Count - 1 do
    if Service_Info_Pool[i].FoundServiceTyp(C40PhysicsTunnel.DependNetworkInfoArray) then
        C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(Service_Info_Pool[i], C40PhysicsTunnel.DependNetworkInfoArray, C40PhysicsTunnel.OnEvent);
end;

constructor TC40_Dispatch_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
var
  i: Integer;
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  FOnServiceInfoChange := nil;
  DelayCheck_Working := False;
  Client := TDT_P2PVM_NoAuth_Custom_Client.Create(
    TDTClient_NoAuth, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink;
  Client.RecvTunnel.RegisterStreamNotify('UpdateServiceInfo').OnExecute := cmd_UpdateServiceInfo;
  Client.RecvTunnel.RegisterStreamNotify('UpdateServiceState').OnExecute := cmd_UpdateServiceState;
  Client.RecvTunnel.RegisterStreamNotify('IgnoreChange').OnExecute := cmd_IgnoreChange;
  Client.RecvTunnel.RegisterStreamNotify('RemovePhysicsNetwork').OnExecute := cmd_RemovePhysicsNetwork;
  Client.RecvTunnel.PrintParams['UpdateServiceInfo'] := False;
  Client.RecvTunnel.PrintParams['UpdateServiceState'] := False;
  Client.RecvTunnel.PrintParams['IgnoreChange'] := False;
  Client.RecvTunnel.PrintParams['RequestUpdate'] := False;
  Client.SendTunnel.PrintParams['UpdateServiceInfo'] := False;
  Client.SendTunnel.PrintParams['UpdateServiceState'] := False;
  Client.SendTunnel.PrintParams['IgnoreChange'] := False;
  Client.SendTunnel.PrintParams['RequestUpdate'] := False;
  Service_Info_Pool := TC40_InfoList.Create(True);
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i].C40PhysicsService.Activted then
      if Service_Info_Pool.FindSame(C40_ServicePool[i].ServiceInfo) = nil then
          Service_Info_Pool.Add(C40_ServicePool[i].ServiceInfo.Clone);
  for i := 0 to Service_Info_Pool.Count - 1 do
    if Service_Info_Pool[i].FoundServiceTyp(C40PhysicsTunnel.DependNetworkInfoArray) then
        C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(Service_Info_Pool[i], C40PhysicsTunnel.DependNetworkInfoArray, C40PhysicsTunnel.OnEvent);
end;

destructor TC40_Dispatch_Client.Destroy;
begin
  DisposeObject(Client);
  DisposeObject(Service_Info_Pool);
  inherited Destroy;
end;

procedure TC40_Dispatch_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
  if not DelayCheck_Working then
    begin
      DelayCheck_Working := True;
      C40PhysicsTunnel.PhysicsTunnel.PostProgress.PostExecuteM_NP(2.0, DoDelayCheckLocalServiceInfo);
    end;
end;

procedure TC40_Dispatch_Client.Connect;
begin
  inherited Connect;
  Client.Connect();
end;

function TC40_Dispatch_Client.Connected: Boolean;
begin
  Result := Client.DTClient.LinkOk;
end;

procedure TC40_Dispatch_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

procedure TC40_Dispatch_Client.PostLocalServiceInfo(forcePost_: Boolean);
var
  i: Integer;
  isChange_: Boolean;
  info: TC40_Info;
  D: TDFE;
begin
  isChange_ := False;
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i].C40PhysicsService.Activted then
      begin
        info := Service_Info_Pool.FindSame(C40_ServicePool[i].ServiceInfo);
        if info = nil then
          begin
            Service_Info_Pool.Add(C40_ServicePool[i].ServiceInfo.Clone);
            isChange_ := True;
          end
        else
            info.Assign(C40_ServicePool[i].ServiceInfo);
      end;
  if isChange_ or forcePost_ then
    begin
      D := TDFE.Create;
      Service_Info_Pool.SaveToDF(D);
      Client.SendTunnel.SendStreamNotifyCmd('UpdateServiceInfo', D);
      DisposeObject(D);
    end;
end;

procedure TC40_Dispatch_Client.RequestUpdate;
begin
  Client.SendTunnel.SendStreamNotifyCmd('RequestUpdate');
end;

procedure TC40_Dispatch_Client.IgnoreChangeToService(Hash__: TMD5; Ignored: Boolean);
var
  D: TDFE;
begin
  D := TDFE.Create;
  D.WriteMD5(Hash__);
  D.WriteBool(Ignored);
  Client.SendTunnel.SendStreamNotifyCmd('IgnoreChange', D);
  DisposeObject(D);
end;

procedure TC40_Dispatch_Client.UpdateLocalServiceState;
var
  i: Integer;
  D, tmp: TDFE;
  info_: TC40_Info;
begin
  D := TDFE.Create;
  for i := 0 to C40_ServicePool.Count - 1 do
    if C40_ServicePool[i].C40PhysicsService.Activted then
      begin
        info_ := C40_ServicePool[i].ServiceInfo;
        tmp := TDFE.Create;
        tmp.WriteMD5(info_.Hash);
        tmp.WriteInteger(info_.Workload);
        tmp.WriteInteger(info_.MaxWorkload);
        D.WriteDataFrame(tmp);
        DisposeObject(tmp);
      end;
  Client.SendTunnel.SendStreamNotifyCmd('UpdateServiceState', D);
  DisposeObject(D);
end;

procedure TC40_Dispatch_Client.RemovePhysicsNetwork(PhysicsAddr: U_String; PhysicsPort: Word);
var
  D: TDFE;
begin
  D := TDFE.Create;
  D.WriteString(PhysicsAddr);
  D.WriteWORD(PhysicsPort);
  Client.SendTunnel.SendStreamNotifyCmd('RemovePhysicsNetwork', D);
  DisposeObject(D);
end;

destructor TC40_RegistedDataList.Destroy;
begin
  Clean;
  inherited Destroy;
end;

procedure TC40_RegistedDataList.Clean;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    begin
      Items[i]^.ServiceTyp := '';
      Dispose(Items[i]);
    end;
  inherited Clear;
end;

procedure TC40_RegistedDataList.Print;
var
  i: Integer;
  p: PC40_RegistedData;
begin
  for i := 0 to Count - 1 do
    begin
      p := Items[i];
      DoStatusNoLn();
      DoStatusNoLn('Type "%s"', [p^.ServiceTyp.Text]);
      if p^.ServiceClass <> nil then
          DoStatusNoLn(' Service "%s"', [p^.ServiceClass.ClassName]);
      if p^.ClientClass <> nil then
          DoStatusNoLn(' Client "%s"', [p^.ClientClass.ClassName]);
      DoStatusNoLn();
    end;
end;

procedure TC40_Base_NULL_Service.DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Base_NULL_Service.DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoUserOut(UserDefineIO);
end;

constructor TC40_Base_NULL_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  Service := TDT_P2PVM_NoAuth_Custom_Service.Create(TDTService_NoAuth, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.FileSystem := EStrToBool(ParamList.GetDefaultValue('FileSystem', umlBoolToStr(Service.DTService.FileSystem)), Service.DTService.FileSystem);
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicFileDirectory := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      if not umlDirectoryExists(Service.DTService.PublicFileDirectory) then
          umlCreateDirectory(Service.DTService.PublicFileDirectory);
    end
  else
    begin
      Service.DTService.PublicFileDirectory := C40_RootPath;
    end;
  DTNoAuthService := Service.DTService;
  UpdateToGlobalDispatch;
end;

destructor TC40_Base_NULL_Service.Destroy;
begin
  DisposeObject(Service);
  inherited Destroy;
end;

procedure TC40_Base_NULL_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
end;

procedure TC40_Base_NULL_Client.Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client);
begin
  DoNetworkOnline();
end;

constructor TC40_Base_NULL_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  Client := TDT_P2PVM_NoAuth_Custom_Client.Create(
    TDTClient_NoAuth, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink;
  DTNoAuthClient := Client.DTClient;
end;

destructor TC40_Base_NULL_Client.Destroy;
begin
  DisposeObject(Client);
  inherited Destroy;
end;

procedure TC40_Base_NULL_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
end;

procedure TC40_Base_NULL_Client.Connect;
begin
  inherited Connect;
  Client.Connect();
end;

function TC40_Base_NULL_Client.Connected: Boolean;
begin
  Result := Client.DTClient.LinkOk;
end;

procedure TC40_Base_NULL_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

procedure TC40_Base_NoAuth_Service.DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Base_NoAuth_Service.DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoUserOut(UserDefineIO);
end;

constructor TC40_Base_NoAuth_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  Service := TDT_P2PVM_NoAuth_Custom_Service.Create(TDTService_NoAuth, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.FileSystem := EStrToBool(ParamList.GetDefaultValue('FileSystem', umlBoolToStr(Service.DTService.FileSystem)), Service.DTService.FileSystem);
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicFileDirectory := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      if not umlDirectoryExists(Service.DTService.PublicFileDirectory) then
          umlCreateDirectory(Service.DTService.PublicFileDirectory);
    end
  else
    begin
      Service.DTService.PublicFileDirectory := C40_RootPath;
    end;
  DTNoAuthService := Service.DTService;
  UpdateToGlobalDispatch;
end;

destructor TC40_Base_NoAuth_Service.Destroy;
begin
  DisposeObject(Service);
  inherited Destroy;
end;

procedure TC40_Base_NoAuth_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
end;

procedure TC40_Base_NoAuth_Client.Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client);
begin
  DoNetworkOnline();
end;

constructor TC40_Base_NoAuth_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  Client := TDT_P2PVM_NoAuth_Custom_Client.Create(
    TDTClient_NoAuth, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_NoAuth_Custom_Client_TunnelLink;
  DTNoAuthClient := Client.DTClient;
end;

destructor TC40_Base_NoAuth_Client.Destroy;
begin
  DisposeObject(Client);
  inherited Destroy;
end;

procedure TC40_Base_NoAuth_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
end;

procedure TC40_Base_NoAuth_Client.Connect;
begin
  inherited Connect;
  Client.Connect();
end;

function TC40_Base_NoAuth_Client.Connected: Boolean;
begin
  Result := Client.DTClient.LinkOk;
end;

procedure TC40_Base_NoAuth_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

procedure TC40_Base_DataStoreNoAuth_Service.DoLinkSuccess_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Base_DataStoreNoAuth_Service.DoUserOut_Event(Sender: TDTService_NoAuth; UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth);
begin
  DoUserOut(UserDefineIO);
end;

constructor TC40_Base_DataStoreNoAuth_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  Service := TDT_P2PVM_NoAuth_Custom_Service.Create(TDataStoreService_NoAuth, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.FileSystem := EStrToBool(ParamList.GetDefaultValue('FileSystem', umlBoolToStr(Service.DTService.FileSystem)), Service.DTService.FileSystem);
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicFileDirectory := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      if not umlDirectoryExists(Service.DTService.PublicFileDirectory) then
          umlCreateDirectory(Service.DTService.PublicFileDirectory);
    end
  else
    begin
      Service.DTService.PublicFileDirectory := C40_RootPath;
    end;
  DTNoAuthService := Service.DTService as TDataStoreService_NoAuth;
  UpdateToGlobalDispatch;
end;

destructor TC40_Base_DataStoreNoAuth_Service.Destroy;
begin
  DisposeObject(Service);
  inherited Destroy;
end;

procedure TC40_Base_DataStoreNoAuth_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
end;

procedure TC40_Base_DataStoreNoAuth_Client.Do_DT_P2PVM_DataStoreNoAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_NoAuth_Custom_Client);
begin
  DoNetworkOnline();
end;

constructor TC40_Base_DataStoreNoAuth_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  Client := TDT_P2PVM_NoAuth_Custom_Client.Create(
    TDataStoreClient_NoAuth, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_DataStoreNoAuth_Custom_Client_TunnelLink;
  DTNoAuthClient := Client.DTClient as TDataStoreClient_NoAuth;
end;

destructor TC40_Base_DataStoreNoAuth_Client.Destroy;
begin
  DisposeObject(Client);
  inherited Destroy;
end;

procedure TC40_Base_DataStoreNoAuth_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
end;

procedure TC40_Base_DataStoreNoAuth_Client.Connect;
begin
  inherited Connect;
  Client.Connect();
end;

function TC40_Base_DataStoreNoAuth_Client.Connected: Boolean;
begin
  Result := Client.DTClient.LinkOk;
end;

procedure TC40_Base_DataStoreNoAuth_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

procedure TC40_Base_VirtualAuth_Service.DoUserReg_Event(Sender: TDTService_VirtualAuth; RegIO: TVirtualRegIO);
begin
  RegIO.Accept;
end;

procedure TC40_Base_VirtualAuth_Service.DoUserAuth_Event(Sender: TDTService_VirtualAuth; AuthIO: TVirtualAuthIO);
begin
  AuthIO.Accept;
end;

procedure TC40_Base_VirtualAuth_Service.DoLinkSuccess_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Base_VirtualAuth_Service.DoUserOut_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth);
begin
  DoUserOut(UserDefineIO);
end;

constructor TC40_Base_VirtualAuth_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  Service := TDT_P2PVM_VirtualAuth_Custom_Service.Create(TDTService_VirtualAuth, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnUserAuth := DoUserAuth_Event;
  Service.DTService.OnUserReg := DoUserReg_Event;
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.FileSystem := EStrToBool(ParamList.GetDefaultValue('FileSystem', umlBoolToStr(Service.DTService.FileSystem)), Service.DTService.FileSystem);
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicFileDirectory := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      if not umlDirectoryExists(Service.DTService.PublicFileDirectory) then
          umlCreateDirectory(Service.DTService.PublicFileDirectory);
    end
  else
    begin
      Service.DTService.PublicFileDirectory := C40_RootPath;
    end;
  DTVirtualAuthService := Service.DTService;
  UpdateToGlobalDispatch;
end;

destructor TC40_Base_VirtualAuth_Service.Destroy;
begin
  DisposeObject(Service);
  inherited Destroy;
end;

procedure TC40_Base_VirtualAuth_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
end;

procedure TC40_Base_VirtualAuth_Client.Do_DT_P2PVM_VirtualAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_VirtualAuth_Custom_Client);
begin
  if Client.LoginIsSuccessed then
    begin
      UserName := Client.LastUser;
      Password := Client.LastPasswd;
      NoDTLink := False;
      Client.RegisterUserAndLogin := False;
    end;
  DoNetworkOnline();
end;

constructor TC40_Base_VirtualAuth_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  Client := TDT_P2PVM_VirtualAuth_Custom_Client.Create(
    TDTClient_VirtualAuth, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_VirtualAuth_Custom_Client_TunnelLink;
  DTVirtualAuthClient := Client.DTClient;
  UserName := ParamList.GetDefaultValue('UserName', '');
  Password := ParamList.GetDefaultValue('Password', '');
  Client.RegisterUserAndLogin := EStrToBool(ParamList.GetDefaultValue('RegUser', 'False'), False);
  NoDTLink := EStrToBool(ParamList.GetDefaultValue('NoDTLink', 'True'), True);
end;

destructor TC40_Base_VirtualAuth_Client.Destroy;
begin
  DisposeObject(Client);
  inherited Destroy;
end;

procedure TC40_Base_VirtualAuth_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
end;

procedure TC40_Base_VirtualAuth_Client.Connect;
begin
  inherited Connect;
  if not NoDTLink then
      Client.Connect(UserName, Password);
end;

function TC40_Base_VirtualAuth_Client.Connected: Boolean;
begin
  if NoDTLink then
      Result := Client.DTClient.RecvTunnel.RemoteInited and Client.DTClient.SendTunnel.RemoteInited
  else
      Result := Client.DTClient.LinkOk;
end;

procedure TC40_Base_VirtualAuth_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

function TC40_Base_VirtualAuth_Client.LoginIsSuccessed: Boolean;
begin
  Result := Client.LoginIsSuccessed;
end;

procedure TC40_Base_DataStoreVirtualAuth_Service.DoUserReg_Event(Sender: TDTService_VirtualAuth; RegIO: TVirtualRegIO);
begin
  RegIO.Accept;
end;

procedure TC40_Base_DataStoreVirtualAuth_Service.DoUserAuth_Event(Sender: TDTService_VirtualAuth; AuthIO: TVirtualAuthIO);
begin
  AuthIO.Accept;
end;

procedure TC40_Base_DataStoreVirtualAuth_Service.DoLinkSuccess_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Base_DataStoreVirtualAuth_Service.DoUserOut_Event(Sender: TDTService_VirtualAuth; UserDefineIO: TService_RecvTunnel_UserDefine_VirtualAuth);
begin
  DoUserOut(UserDefineIO);
end;

constructor TC40_Base_DataStoreVirtualAuth_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  Service := TDT_P2PVM_VirtualAuth_Custom_Service.Create(TDataStoreService_VirtualAuth, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnUserAuth := DoUserAuth_Event;
  Service.DTService.OnUserReg := DoUserReg_Event;
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.FileSystem := EStrToBool(ParamList.GetDefaultValue('FileSystem', umlBoolToStr(Service.DTService.FileSystem)), Service.DTService.FileSystem);
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicFileDirectory := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      if not umlDirectoryExists(Service.DTService.PublicFileDirectory) then
          umlCreateDirectory(Service.DTService.PublicFileDirectory);
    end
  else
    begin
      Service.DTService.PublicFileDirectory := C40_RootPath;
    end;
  DTVirtualAuthService := Service.DTService as TDataStoreService_VirtualAuth;
  UpdateToGlobalDispatch;
end;

destructor TC40_Base_DataStoreVirtualAuth_Service.Destroy;
begin
  DisposeObject(Service);
  inherited Destroy;
end;

procedure TC40_Base_DataStoreVirtualAuth_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
end;

procedure TC40_Base_DataStoreVirtualAuth_Client.Do_DT_P2PVM_VirtualAuth_Custom_Client_TunnelLink(Sender: TDT_P2PVM_VirtualAuth_Custom_Client);
begin
  if Client.LoginIsSuccessed then
    begin
      UserName := Client.LastUser;
      Password := Client.LastPasswd;
      NoDTLink := False;
      Client.RegisterUserAndLogin := False;
    end;
  DoNetworkOnline();
end;

constructor TC40_Base_DataStoreVirtualAuth_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  Client := TDT_P2PVM_VirtualAuth_Custom_Client.Create(
    TDataStoreClient_VirtualAuth, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_VirtualAuth_Custom_Client_TunnelLink;
  DTVirtualAuthClient := Client.DTClient as TDataStoreClient_VirtualAuth;
  UserName := ParamList.GetDefaultValue('UserName', '');
  Password := ParamList.GetDefaultValue('Password', '');
  Client.RegisterUserAndLogin := EStrToBool(ParamList.GetDefaultValue('RegUser', 'False'), False);
  NoDTLink := EStrToBool(ParamList.GetDefaultValue('NoDTLink', 'True'), True);
end;

destructor TC40_Base_DataStoreVirtualAuth_Client.Destroy;
begin
  DisposeObject(Client);
  inherited Destroy;
end;

procedure TC40_Base_DataStoreVirtualAuth_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
end;

procedure TC40_Base_DataStoreVirtualAuth_Client.Connect;
begin
  inherited Connect;
  if not NoDTLink then
      Client.Connect(UserName, Password);
end;

function TC40_Base_DataStoreVirtualAuth_Client.Connected: Boolean;
begin
  if NoDTLink then
      Result := Client.DTClient.RecvTunnel.RemoteInited and Client.DTClient.SendTunnel.RemoteInited
  else
      Result := Client.DTClient.LinkOk;
end;

procedure TC40_Base_DataStoreVirtualAuth_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

function TC40_Base_DataStoreVirtualAuth_Client.LoginIsSuccessed: Boolean;
begin
  Result := Client.LoginIsSuccessed;
end;

procedure TC40_Base_Service.DoLinkSuccess_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Base_Service.DoUserOut_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine);
begin
  DoUserOut(UserDefineIO);
end;

constructor TC40_Base_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  Service := TDT_P2PVM_Custom_Service.Create(TDTService, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.AllowRegisterNewUser := True;
  Service.DTService.AllowSaveUserInfo := True;
  Service.DTService.FileSystem := EStrToBool(ParamList.GetDefaultValue('FileSystem', umlBoolToStr(Service.DTService.FileSystem)), Service.DTService.FileSystem);
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicPath := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      Service.DTService.RootPath := Service.DTService.PublicPath;
      if not umlDirectoryExists(Service.DTService.PublicPath) then
          umlCreateDirectory(Service.DTService.PublicPath);
    end
  else
    begin
      Service.DTService.PublicPath := C40_RootPath;
      Service.DTService.RootPath := Service.DTService.PublicPath;
    end;
  DTService := Service.DTService;
  UpdateToGlobalDispatch;
end;

destructor TC40_Base_Service.Destroy;
begin
  DisposeObject(Service);
  inherited Destroy;
end;

procedure TC40_Base_Service.SafeCheck;
begin
  inherited SafeCheck;
  Service.DTService.SaveUserDB;
end;

procedure TC40_Base_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
end;

procedure TC40_Base_Client.Do_DT_P2PVM_Custom_Client_TunnelLink(Sender: TDT_P2PVM_Custom_Client);
begin
  if Client.LoginIsSuccessed then
    begin
      UserName := Client.LastUser;
      Password := Client.LastPasswd;
      NoDTLink := False;
      Client.RegisterUserAndLogin := False;
    end;
  DoNetworkOnline();
end;

constructor TC40_Base_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  Client := TDT_P2PVM_Custom_Client.Create(
    TDTClient, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_Custom_Client_TunnelLink;
  DTClient := Client.DTClient;
  UserName := ParamList.GetDefaultValue('UserName', '');
  Password := ParamList.GetDefaultValue('Password', '');
  Client.RegisterUserAndLogin := EStrToBool(ParamList.GetDefaultValue('RegUser', 'False'), False);
  NoDTLink := EStrToBool(ParamList.GetDefaultValue('NoDTLink', 'True'), True);
end;

destructor TC40_Base_Client.Destroy;
begin
  DisposeObject(Client);
  inherited Destroy;
end;

procedure TC40_Base_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
end;

procedure TC40_Base_Client.Connect;
begin
  inherited Connect;
  if not NoDTLink then
      Client.Connect(UserName, Password);
end;

function TC40_Base_Client.Connected: Boolean;
begin
  if NoDTLink then
      Result := Client.DTClient.RecvTunnel.RemoteInited and Client.DTClient.SendTunnel.RemoteInited
  else
      Result := Client.DTClient.LinkOk;
end;

procedure TC40_Base_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

function TC40_Base_Client.LoginIsSuccessed: Boolean;
begin
  Result := Client.LoginIsSuccessed;
end;

procedure TC40_Base_DataStore_Service.DoLinkSuccess_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine);
begin
  DoLinkSuccess(UserDefineIO);
end;

procedure TC40_Base_DataStore_Service.DoUserOut_Event(Sender: TDTService; UserDefineIO: TService_RecvTunnel_UserDefine);
begin
  DoUserOut(UserDefineIO);
end;

constructor TC40_Base_DataStore_Service.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  Service := TDT_P2PVM_Custom_Service.Create(TDataStoreService, PhysicsService_.PhysicsTunnel,
    ServiceInfo.ServiceTyp + 'R', ServiceInfo.p2pVM_RecvTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_RecvTunnel_Port),
    ServiceInfo.ServiceTyp + 'S', ServiceInfo.p2pVM_SendTunnel_Addr, umlIntToStr(ServiceInfo.p2pVM_SendTunnel_Port)
    );
  Service.DTService.OnLinkSuccess := DoLinkSuccess_Event;
  Service.DTService.OnUserOut := DoUserOut_Event;
  Service.DTService.AllowRegisterNewUser := True;
  Service.DTService.AllowSaveUserInfo := True;
  Service.DTService.FileSystem := EStrToBool(ParamList.GetDefaultValue('FileSystem', umlBoolToStr(Service.DTService.FileSystem)), Service.DTService.FileSystem);
  if enablePerServiceDirectory then
    begin
      Service.DTService.PublicPath := umlCombinePath(C40_RootPath, ServiceInfo.ServiceTyp);
      Service.DTService.RootPath := Service.DTService.PublicPath;
      if not umlDirectoryExists(Service.DTService.PublicPath) then
          umlCreateDirectory(Service.DTService.PublicPath);
    end
  else
    begin
      Service.DTService.PublicPath := C40_RootPath;
      Service.DTService.RootPath := Service.DTService.PublicPath;
    end;
  DTService := Service.DTService as TDataStoreService;
  UpdateToGlobalDispatch;
end;

destructor TC40_Base_DataStore_Service.Destroy;
begin
  DisposeObject(Service);
  inherited Destroy;
end;

procedure TC40_Base_DataStore_Service.SafeCheck;
begin
  inherited SafeCheck;
  Service.DTService.SaveUserDB;
end;

procedure TC40_Base_DataStore_Service.Progress;
begin
  inherited Progress;
  Service.Progress;
  ServiceInfo.Workload := Service.DTService.RecvTunnel.Count + Service.DTService.SendTunnel.Count;
end;

procedure TC40_Base_DataStore_Client.Do_DT_P2PVM_Custom_Client_TunnelLink(Sender: TDT_P2PVM_Custom_Client);
begin
  if Client.LoginIsSuccessed then
    begin
      UserName := Client.LastUser;
      Password := Client.LastPasswd;
      NoDTLink := False;
      Client.RegisterUserAndLogin := False;
    end;
  DoNetworkOnline();
end;

constructor TC40_Base_DataStore_Client.Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String);
begin
  inherited Create(PhysicsTunnel_, source_, Param_);
  Client := TDT_P2PVM_Custom_Client.Create(
    TDataStoreClient, C40PhysicsTunnel.PhysicsTunnel,
    ClientInfo.ServiceTyp + 'R', ClientInfo.p2pVM_ClientRecvTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientRecvTunnel_Port),
    ClientInfo.ServiceTyp + 'S', ClientInfo.p2pVM_ClientSendTunnel_Addr, umlIntToStr(ClientInfo.p2pVM_ClientSendTunnel_Port)
    );
  Client.OnTunnelLink := Do_DT_P2PVM_Custom_Client_TunnelLink;
  DTClient := Client.DTClient as TDataStoreClient;
  UserName := ParamList.GetDefaultValue('UserName', '');
  Password := ParamList.GetDefaultValue('Password', '');
  Client.RegisterUserAndLogin := EStrToBool(ParamList.GetDefaultValue('RegUser', 'False'), False);
  NoDTLink := EStrToBool(ParamList.GetDefaultValue('NoDTLink', 'True'), True);
end;

destructor TC40_Base_DataStore_Client.Destroy;
begin
  DisposeObject(Client);
  inherited Destroy;
end;

procedure TC40_Base_DataStore_Client.Progress;
begin
  inherited Progress;
  Client.Progress;
end;

procedure TC40_Base_DataStore_Client.Connect;
begin
  inherited Connect;
  if not NoDTLink then
      Client.Connect(UserName, Password);
end;

function TC40_Base_DataStore_Client.Connected: Boolean;
begin
  if NoDTLink then
      Result := Client.DTClient.RecvTunnel.RemoteInited and Client.DTClient.SendTunnel.RemoteInited
  else
      Result := Client.DTClient.LinkOk;
end;

procedure TC40_Base_DataStore_Client.Disconnect;
begin
  inherited Disconnect;
  Client.Disconnect;
end;

function TC40_Base_DataStore_Client.LoginIsSuccessed: Boolean;
begin
  Result := Client.LoginIsSuccessed;
end;

constructor TC40_Custom_VM_Service.Create(Param_: U_String);
var
  tmp: TPascalStringList;
begin
  inherited Create;
  Param := Param_;
  ParamList := THashStringList.Create;
  ParamList.AutoUpdateDefaultValue := True;
  try
    tmp := TPascalStringList.Create;
    umlSeparatorText(Param, tmp, ',;' + #13#10);
    ParamList.ImportFromStrings(tmp);
    DisposeObject(tmp);
  except
  end;
  FLastSafeCheckTime := GetTimeTick;
  SafeCheckTime := EStrToInt64(ParamList.GetDefaultValue('SafeCheckTime', umlIntToStr(C40_SafeCheckTime)), C40_SafeCheckTime);
  IPC_Mode := False;
  if ParamList.Exists('IPC') then
      IPC_Mode := EStrToBool(ParamList.GetDefaultValue('IPC', umlBoolToStr(IPC_Mode)), IPC_Mode)
  else if ParamList.Exists('IPC_Mode') then
      IPC_Mode := EStrToBool(ParamList.GetDefaultValue('IPC_Mode', umlBoolToStr(IPC_Mode)), IPC_Mode);
  enablePerServiceDirectory := C40_EnablePerServiceDirectory;
  enablePerServiceDirectory := EStrToBool(ParamList.GetDefaultValue('enablePerServiceDirectory', if_(enablePerServiceDirectory, 'True', 'False')), enablePerServiceDirectory);
  C40_VM_Service_Pool.Add(Self);
  ConsoleCommand := TC4_Help_Console_Command.Create;
end;

destructor TC40_Custom_VM_Service.Destroy;
begin
  DisposeObject(ConsoleCommand);
  C40_VM_Service_Pool.Remove(Self);
  DisposeObject(ParamList);
  inherited Destroy;
end;

procedure TC40_Custom_VM_Service.SafeCheck;
begin
end;

procedure TC40_Custom_VM_Service.Progress;
begin
  if GetTimeTick - FLastSafeCheckTime > SafeCheckTime then
    begin
      try
          SafeCheck;
      except
      end;
      FLastSafeCheckTime := GetTimeTick;
    end;
end;

procedure TC40_Custom_VM_Service.StartService(ListenAddr, ListenPort, Auth: SystemString);
begin
end;

procedure TC40_Custom_VM_Service.StopService;
begin
end;

function TC40_Custom_VM_Service.Get_DB_FileName_Config(source_: U_String): U_String;
begin
  Result := ParamList.GetDefaultValue(source_, source_);
end;

function TC40_Custom_VM_Service.Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;
begin
  Result := TC4_Help_Console_Command_Data.Create;
  Result.Cmd := Cmd;
  Result.Desc := Desc;
  ConsoleCommand.Add(Result);
end;

procedure TC40_Custom_VM_Service.DoLinkSuccess(Trigger_: TCore_Object);
begin
end;

procedure TC40_Custom_VM_Service.DoUserOut(Trigger_: TCore_Object);
begin
end;

constructor TC40_Custom_VM_Client.Create(Param_: U_String);
var
  tmp: TPascalStringList;
begin
  inherited Create;
  Param := Param_;
  ParamList := THashStringList.Create;
  ParamList.AutoUpdateDefaultValue := True;
  try
    tmp := TPascalStringList.Create;
    umlSeparatorText(Param, tmp, ',;' + #13#10);
    ParamList.ImportFromStrings(tmp);
    DisposeObject(tmp);
  except
  end;
  FLastSafeCheckTime := GetTimeTick;
  SafeCheckTime := EStrToInt64(ParamList.GetDefaultValue('SafeCheckTime', umlIntToStr(C40_SafeCheckTime)), C40_SafeCheckTime);
  IPC_Mode := False;
  if ParamList.Exists('IPC') then
      IPC_Mode := EStrToBool(ParamList.GetDefaultValue('IPC', umlBoolToStr(IPC_Mode)), IPC_Mode)
  else if ParamList.Exists('IPC_Mode') then
      IPC_Mode := EStrToBool(ParamList.GetDefaultValue('IPC_Mode', umlBoolToStr(IPC_Mode)), IPC_Mode);
  On_Client_Online := nil;
  On_Client_Offline := nil;
  C40_VM_Client_Pool.Add(Self);
  ConsoleCommand := TC4_Help_Console_Command.Create;
end;

destructor TC40_Custom_VM_Client.Destroy;
begin
  DisposeObject(ConsoleCommand);
  C40_VM_Client_Pool.Remove(Self);
  DisposeObject(ParamList);
  inherited Destroy;
end;

procedure TC40_Custom_VM_Client.SafeCheck;
begin
end;

procedure TC40_Custom_VM_Client.Progress;
begin
  if GetTimeTick - FLastSafeCheckTime > SafeCheckTime then
    begin
      try
          SafeCheck;
      except
      end;
      FLastSafeCheckTime := GetTimeTick;
    end;
end;

function TC40_Custom_VM_Client.Connected: Boolean;
begin
  Result := False;
end;

procedure TC40_Custom_VM_Client.Disconnect;
begin
end;

function TC40_Custom_VM_Client.Get_DB_FileName_Config(source_: U_String): U_String;
begin
  Result := ParamList.GetDefaultValue(source_, source_);
end;

function TC40_Custom_VM_Client.Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;
begin
  Result := TC4_Help_Console_Command_Data.Create;
  Result.Cmd := Cmd;
  Result.Desc := Desc;
  ConsoleCommand.Add(Result);
end;

procedure TC40_Custom_VM_Client.DoNetworkOnline;
begin
  try
    if Assigned(On_Client_Online) then
        On_Client_Online(Self);
  except
  end;
end;

procedure TC40_Custom_VM_Client.DoNetworkOffline;
begin
  try
    if Assigned(On_Client_Offline) then
        On_Client_Offline(Self);
  except
  end;
end;

procedure TC40_Custom_VM_Service_Pool.Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    begin
      try
          Items[i].Progress;
      except
      end;
    end;
end;

procedure TC40_Custom_VM_Client_Pool.Progress;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
    begin
      try
          Items[i].Progress;
      except
      end;
    end;
end;

function TC40_Console_Help.Do_Build_Instance_State(var OP_Param: TOpParam): Variant;
begin
  DisposeObjectAndNil(Last_Instance_State);
  Instance_State_Tool.Queue_Pool.Lock;
  Last_Instance_State := Instance_State_Tool.Clone;
  Instance_State_Tool.Queue_Pool.UnLock;
  Result := True;
end;

function TC40_Console_Help.Do_Compare_Instance_State(var OP_Param: TOpParam): Variant;
var
  tmp: TInstance_State_Tool;
begin
  if Last_Instance_State <> nil then
    begin
      Instance_State_Tool.Queue_Pool.Lock;
      tmp := Instance_State_Tool.Compare_State(Last_Instance_State);
      Instance_State_Tool.Queue_Pool.UnLock;
      DisposeObjectAndNil(Last_Instance_State);
      tmp.Sort_By_Instance;
      if tmp.Num > 0 then
        with tmp.Repeat_ do
          repeat
            if (Queue^.Data^.Data.Second.Instance_Num <> 0) then
                DoStatus('%s : diff %d',
                [Queue^.Data^.Data.Primary, Queue^.Data^.Data.Second.Instance_Num]);
          until not Next;
      DisposeObjectAndNil(tmp);
    end;
  Result := True;
end;

procedure TC40_Console_Help.UpdateServiceInfo;
var
  i: Integer;
  phy_serv: TC40_PhysicsService;
begin
  for i := 0 to C40_PhysicsServicePool.Count - 1 do
    begin
      phy_serv := C40_PhysicsServicePool[i];
      DoStatus('service "%s" port:%d connection workload:%d send:%s receive:%s',
        [phy_serv.PhysicsAddr.Text, phy_serv.PhysicsPort, phy_serv.PhysicsTunnel.Count,
          umlSizeToStr(phy_serv.PhysicsTunnel.Statistics[stSendSize]).Text,
          umlSizeToStr(phy_serv.PhysicsTunnel.Statistics[stReceiveSize]).Text
          ]);
    end;
end;

procedure TC40_Console_Help.UpdateServiceInfo(phy_serv: TC40_PhysicsService);
var
  i, j: Integer;
  custom_serv: TC40_Custom_Service;
  s_recv_, s_send_: TZNet_WithP2PVM_Server;
begin
  DoStatus('Physics service: "%s" Unit: "%s"', [phy_serv.PhysicsTunnel.ClassName, phy_serv.PhysicsTunnel.UnitName + '.pas']);
  DoStatus('Physics service workload: %d', [phy_serv.PhysicsTunnel.Count]);
  DoStatus('Physics service receive:%s, send:%s ', [umlSizeToStr(phy_serv.PhysicsTunnel.Statistics[stReceiveSize]).Text, umlSizeToStr(phy_serv.PhysicsTunnel.Statistics[stSendSize]).Text]);
  DoStatus('Physcis Listening ip: "%s" Port: %d', [phy_serv.PhysicsAddr.Text, phy_serv.PhysicsPort]);
  DoStatus('Listening Successed: %s', [if_(phy_serv.Activted, 'Yes', 'Failed')]);
  for i := 0 to phy_serv.DependNetworkServicePool.Count - 1 do
    begin
      DoStatus('--------------------------------------------', []);
      custom_serv := phy_serv.DependNetworkServicePool[i];
      DoStatus('Type: %s', [custom_serv.ServiceInfo.ServiceTyp.Text]);
      DoStatus('workload: %d / %d', [custom_serv.ServiceInfo.Workload, custom_serv.ServiceInfo.MaxWorkload]);
      if custom_serv.Get_P2PVM_Service(s_recv_, s_send_) then
          DoStatus('receive:%s send:%s',
          [umlSizeToStr(s_recv_.Statistics[stReceiveSize]).Text, umlSizeToStr(s_recv_.Statistics[stSendSize]).Text]);
      DoStatus('Only Instance: %s', [if_(custom_serv.ServiceInfo.OnlyInstance, 'Yes', 'More Instance.')]);
      DoStatus('Hash: %s', [umlMD5ToStr(custom_serv.ServiceInfo.Hash).Text]);
      DoStatus('Alias or Hash: %s', [custom_serv.AliasOrHash.Text]);
      DoStatus('Class: "%s" Unit: "%s"', [custom_serv.ClassName, custom_serv.UnitName + '.pas']);
      DoStatus('Receive Tunnel IP: %s Port: %d',
        [custom_serv.ServiceInfo.p2pVM_RecvTunnel_Addr.Text, custom_serv.ServiceInfo.p2pVM_RecvTunnel_Port]);
      DoStatus('Send Tunnel IP: %s Port: %d',
        [custom_serv.ServiceInfo.p2pVM_SendTunnel_Addr.Text, custom_serv.ServiceInfo.p2pVM_SendTunnel_Port]);
      DoStatus('Parameter', []);
      DoStatus('{', []);
      DoStatus(#9 + umlReplace(custom_serv.ParamList.AsText, #13#10, #13#10#9, False, False));
      DoStatus('}', []);
    end;
  DoStatus('', []);
end;

procedure TC40_Console_Help.UpdateTunnelInfo;
var
  i: Integer;
  phy_tunnel: TC40_PhysicsTunnel;
begin
  for i := 0 to C40_PhysicsTunnelPool.Count - 1 do
    begin
      phy_tunnel := C40_PhysicsTunnelPool[i];
      DoStatus('tunnel "%s" port:%d send:%s receive:%s',
        [phy_tunnel.PhysicsAddr.Text, phy_tunnel.PhysicsPort,
          umlSizeToStr(phy_tunnel.PhysicsTunnel.Statistics[stSendSize]).Text,
          umlSizeToStr(phy_tunnel.PhysicsTunnel.Statistics[stReceiveSize]).Text
          ]);
    end;
end;

procedure TC40_Console_Help.UpdateTunnelInfo(phy_tunnel: TC40_PhysicsTunnel);
var
  i: Integer;
  custom_client: TC40_Custom_Client;
  c_recv_, c_send_: TZNet_WithP2PVM_Client;
begin
  DoStatus('Physics tunnel: "%s" Unit: "%s"', [phy_tunnel.PhysicsTunnel.ClassName, phy_tunnel.PhysicsTunnel.UnitName + '.pas']);
  DoStatus('Physcis ip: "%s" Port: %d', [phy_tunnel.PhysicsAddr.Text, phy_tunnel.PhysicsPort]);
  DoStatus('Physcis Connected: %s', [if_(phy_tunnel.PhysicsTunnel.Connected, 'Yes', 'Failed')]);
  DoStatus('Physics receive:%s, send:%s ', [umlSizeToStr(phy_tunnel.PhysicsTunnel.Statistics[stReceiveSize]).Text, umlSizeToStr(phy_tunnel.PhysicsTunnel.Statistics[stSendSize]).Text]);
  for i := 0 to phy_tunnel.DependNetworkClientPool.Count - 1 do
    begin
      DoStatus('--------------------------------------------', []);
      custom_client := phy_tunnel.DependNetworkClientPool[i];
      DoStatus('Type: %s', [custom_client.ClientInfo.ServiceTyp.Text]);
      DoStatus('Connected: %s', [if_(custom_client.Connected, 'Yes', 'Failed')]);
      if custom_client.Get_P2PVM_Tunnel(c_recv_, c_send_) then
          DoStatus('receive:%s send:%s',
          [umlSizeToStr(c_recv_.Statistics[stReceiveSize]).Text, umlSizeToStr(c_recv_.Statistics[stSendSize]).Text]);
      DoStatus('Only Instance: %s', [if_(custom_client.ClientInfo.OnlyInstance, 'Yes', 'More Instance.')]);
      DoStatus('Hash: %s', [umlMD5ToStr(custom_client.ClientInfo.Hash).Text]);
      DoStatus('Alias or Hash: %s', [custom_client.AliasOrHash.Text]);
      DoStatus('Class: "%s" Unit: "%s"', [custom_client.ClassName, custom_client.UnitName + '.pas']);
      DoStatus('Receive Tunnel IP: %s Port: %d',
        [custom_client.ClientInfo.p2pVM_RecvTunnel_Addr.Text, custom_client.ClientInfo.p2pVM_RecvTunnel_Port]);
      DoStatus('Send Tunnel IP: %s Port: %d',
        [custom_client.ClientInfo.p2pVM_SendTunnel_Addr.Text, custom_client.ClientInfo.p2pVM_SendTunnel_Port]);
      DoStatus('Workload: %d/%d', [custom_client.ClientInfo.Workload, custom_client.ClientInfo.MaxWorkload]);
      DoStatus('Parameter', []);
      DoStatus('{', []);
      DoStatus(#9 + umlReplace(custom_client.ParamList.AsText, #13#10, #13#10#9, False, False));
      DoStatus('}', []);
    end;
  DoStatus('', []);
end;

function TC40_Console_Help.Do_Help(var OP_Param: TOpParam): Variant;
var
  i: Integer;
  L: TPascalStringList;
begin
  L := opRT.GetAllProcDescription(False, '*');
  for i := 0 to L.Count - 1 do
      DoStatus(L[i]);
  Result := True;
end;

function TC40_Console_Help.Do_Exit(var OP_Param: TOpParam): Variant;
begin
  Print_Intermediate_Instance_Status := False;
  Print_Tracking_Delay_Free := False;
  IsExit := True;
  Result := True;
end;

function TC40_Console_Help.Do_Service(var OP_Param: TOpParam): Variant;
var
  i: Integer;
  ip: U_String;
  Port: Word;
begin
  if length(OP_Param) = 1 then
    begin
      ip := umlVarToStr(OP_Param[0], False);
      for i := 0 to C40_PhysicsServicePool.Count - 1 do
        begin
          if (umlMultipleMatch(ip, C40_PhysicsServicePool[i].ListeningAddr)
              or umlMultipleMatch(ip, C40_PhysicsServicePool[i].PhysicsAddr)) then
              UpdateServiceInfo(C40_PhysicsServicePool[i]);
        end;
    end
  else if length(OP_Param) = 2 then
    begin
      ip := umlVarToStr(OP_Param[0], False);
      Port := OP_Param[1];
      for i := 0 to C40_PhysicsServicePool.Count - 1 do
        begin
          if (umlMultipleMatch(ip, C40_PhysicsServicePool[i].ListeningAddr)
              or umlMultipleMatch(ip, C40_PhysicsServicePool[i].PhysicsAddr)) and (Port = C40_PhysicsServicePool[i].PhysicsPort) then
              UpdateServiceInfo(C40_PhysicsServicePool[i]);
        end;
    end
  else
    begin
      UpdateServiceInfo();
    end;
  Result := True;
end;

function TC40_Console_Help.Do_Tunnel(var OP_Param: TOpParam): Variant;
var
  i: Integer;
  ip: U_String;
  Port: Word;
begin
  if length(OP_Param) = 1 then
    begin
      ip := umlVarToStr(OP_Param[0], False);
      for i := 0 to C40_PhysicsTunnelPool.Count - 1 do
        begin
          if umlMultipleMatch(ip, C40_PhysicsTunnelPool[i].PhysicsAddr) then
              UpdateTunnelInfo(C40_PhysicsTunnelPool[i]);
        end;
    end
  else if length(OP_Param) = 2 then
    begin
      ip := umlVarToStr(OP_Param[0], False);
      Port := OP_Param[1];
      for i := 0 to C40_PhysicsTunnelPool.Count - 1 do
        begin
          if umlMultipleMatch(ip, C40_PhysicsTunnelPool[i].PhysicsAddr)
            and (Port = C40_PhysicsTunnelPool[i].PhysicsPort) then
              UpdateTunnelInfo(C40_PhysicsTunnelPool[i]);
        end;
    end
  else
    begin
      UpdateTunnelInfo();
    end;
  Result := True;
end;

function TC40_Console_Help.Do_Reg(var OP_Param: TOpParam): Variant;
begin
  C40_Registed.Print;
  Result := True;
end;

function TC40_Console_Help.Do_KillNet(var OP_Param: TOpParam): Variant;
var
  PhysicsAddr: U_String;
  PhysicsPort: Word;
begin
  PhysicsPort := 0;
  PhysicsAddr := umlVarToStr(OP_Param[0], False);
  if length(OP_Param) > 0 then
      PhysicsPort := OP_Param[1];
  C40RemovePhysics(PhysicsAddr, PhysicsPort, True, True, True, True);
  Result := True;
end;

function TC40_Console_Help.Do_C4_Clean(var OP_Param: TOpParam): Variant;
begin
  C40Clean();
  Result := True;
end;

function TC40_Console_Help.Do_SetQuiet(var OP_Param: TOpParam): Variant;
begin
  C40SetQuietMode(OP_Param[0]);
  Result := True;
end;

function TC40_Console_Help.Do_Save_All_C4Service_Config(var OP_Param: TOpParam): Variant;
var
  i: Integer;
  serv: TC40_Custom_Service;
  ph, fn: U_String;
begin
  for i := 0 to C40_ServicePool.Count - 1 do
    begin
      serv := C40_ServicePool[i];
      ph := umlCombinePath(C40_RootPath, serv.ServiceInfo.ServiceTyp);
      if not umlDirectoryExists(ph) then
          ph := C40_RootPath;
      fn := umlCombineFileName(ph, PFormat('S_%s.conf', [serv.ServiceInfo.ServiceTyp.Text]));
      serv.ParamList.SaveToFile(fn);
      DoStatus('save class "%s" %s to %s', [serv.ClassName, serv.ServiceInfo.ServiceTyp.Text, fn.Text]);
    end;
  Result := True;
end;

function TC40_Console_Help.Do_Save_All_C4Client_Config(var OP_Param: TOpParam): Variant;
var
  i: Integer;
  cli: TC40_Custom_Client;
  ph, fn: U_String;
begin
  for i := 0 to C40_ClientPool.Count - 1 do
    begin
      cli := C40_ClientPool[i];
      ph := C40_RootPath;
      fn := umlCombineFileName(ph, PFormat('C_%s.conf', [cli.ClientInfo.ServiceTyp.Text]));
      cli.ParamList.SaveToFile(fn);
      DoStatus('save class "%s" %s to %s', [cli.ClassName, cli.ClientInfo.ServiceTyp.Text, fn.Text]);
    end;
  Result := True;
end;

function TC40_Console_Help.Do_Instance_Info(var OP_Param: TOpParam): Variant;
begin
  Instance_State_Tool.Queue_Pool.Lock;
  Instance_State_Tool.Sort_By_Instance;
  if Instance_State_Tool.Num > 0 then
    with Instance_State_Tool.Repeat_ do
      repeat
        if (Queue^.Data^.Data.Second.Instance_Num > 0) then
            DoStatus('%s : instance %d update %d time %s',
            [Queue^.Data^.Data.Primary, Queue^.Data^.Data.Second.Instance_Num, Queue^.Data^.Data.Second.Update_Num, umlTimeTickToStr(GetTimeTick - Queue^.Data^.Data.Second.Update_Time).Text]);
      until not Next;
  Instance_State_Tool.Queue_Pool.UnLock;
end;

function TC40_Console_Help.Do_Instance_Info_Sort_Update(var OP_Param: TOpParam): Variant;
begin
  Instance_State_Tool.Queue_Pool.Lock;
  Instance_State_Tool.Sort_By_Update;
  if Instance_State_Tool.Num > 0 then
    with Instance_State_Tool.Repeat_ do
      repeat
        if (Queue^.Data^.Data.Second.Instance_Num > 0) then
            DoStatus('%s : instance %d update %d time %s',
            [Queue^.Data^.Data.Primary, Queue^.Data^.Data.Second.Instance_Num, Queue^.Data^.Data.Second.Update_Num, umlTimeTickToStr(GetTimeTick - Queue^.Data^.Data.Second.Update_Time).Text]);
      until not Next;
  Instance_State_Tool.Queue_Pool.UnLock;
end;

function TC40_Console_Help.Do_Instance_Info_Sort_Time(var OP_Param: TOpParam): Variant;
begin
  Instance_State_Tool.Queue_Pool.Lock;
  Instance_State_Tool.Sort_By_Time;
  if Instance_State_Tool.Num > 0 then
    with Instance_State_Tool.Repeat_ do
      repeat
        if (Queue^.Data^.Data.Second.Instance_Num > 0) then
            DoStatus('%s : instance %d update %d time %s',
            [Queue^.Data^.Data.Primary, Queue^.Data^.Data.Second.Instance_Num, Queue^.Data^.Data.Second.Update_Num, umlTimeTickToStr(GetTimeTick - Queue^.Data^.Data.Second.Update_Time).Text]);
      until not Next;
  Instance_State_Tool.Queue_Pool.UnLock;
end;

function TC40_Console_Help.Do_HPC_Thread_Info(var OP_Param: TOpParam): Variant;
var
  hpc_: THPC_Base;
begin
  HPC_Instance_Pool.Lock;
  try
    if HPC_Instance_Pool.Num > 0 then
      begin
        with HPC_Instance_Pool.Repeat_ do
          repeat
            hpc_ := Queue^.Data;
            if hpc_ is THPC_Stream then
              begin
                DoStatus('cmd:%s framework:%s time:%s ', [
                    THPC_Stream(hpc_).Cmd,
                    THPC_Stream(hpc_).Framework.name,
                    umlTimeTickToStr(GetTimeTick - THPC_Stream(hpc_).TriggerTime).Text]);
              end
            else if hpc_ is THPC_StreamNotify then
              begin
                DoStatus('cmd:%s framework:%s time:%s ', [
                    THPC_StreamNotify(hpc_).Cmd,
                    THPC_StreamNotify(hpc_).Framework.name,
                    umlTimeTickToStr(GetTimeTick - THPC_StreamNotify(hpc_).TriggerTime).Text]);
              end
            else if hpc_ is THPC_Console then
              begin
                DoStatus('cmd:%s framework:%s time:%s ', [
                    THPC_Console(hpc_).Cmd,
                    THPC_Console(hpc_).Framework.name,
                    umlTimeTickToStr(GetTimeTick - THPC_Console(hpc_).TriggerTime).Text]);
              end
            else if hpc_ is THPC_ConsoleNotify then
              begin
                DoStatus('cmd:%s framework:%s time:%s ', [
                    THPC_ConsoleNotify(hpc_).Cmd,
                    THPC_ConsoleNotify(hpc_).Framework.name,
                    umlTimeTickToStr(GetTimeTick - THPC_ConsoleNotify(hpc_).TriggerTime).Text]);
              end
            else if hpc_ is THPC_CompleteBuffer then
              begin
                DoStatus('cmd:%s framework:%s time:%s ', [
                    THPC_CompleteBuffer(hpc_).Cmd,
                    THPC_CompleteBuffer(hpc_).Framework.name,
                    umlTimeTickToStr(GetTimeTick - THPC_CompleteBuffer(hpc_).TriggerTime).Text]);
              end;
          until not Next;
        DoStatus('');
      end;
  finally
      HPC_Instance_Pool.UnLock;
  end;
  TCompute.Get_Core_Thread_Dispatch_Critical.Lock;
  try
    if TCompute.Get_Core_Thread_Pool.Num > 0 then
      begin
        with TCompute.Get_Core_Thread_Pool.Repeat_ do
          repeat
              DoStatus('thread:"%s" time:%s', [Queue^.Data.Thread_Info, umlTimeTickToStr(GetTimeTick - Queue^.Data.Start_Time_Tick).Text]);
          until not Next;
        DoStatus('');
      end;
  finally
      TCompute.Get_Core_Thread_Dispatch_Critical.UnLock;
  end;
  DoStatus('RTL Main-Thread synchronize of per second:%f MaxCPU:%dms', [CPS_Check_System_Thread.CPS, CPS_Check_System_Thread.CPU_Time]);
  DoStatus('Soft Main-Thread synchronize of per second:%f MaxCPU:%d', [CPS_Check_Soft_Thread.CPS, CPS_Check_Soft_Thread.CPU_Time]);
  DoStatus('Compute thread summary ' + TCompute.state);
  DoStatus('');
  Result := HPC_Instance_Pool.Num;
end;

function TC40_Console_Help.Do_ZNet_Instance_Info(var OP_Param: TOpParam): Variant;
begin
  ZNet_Instance_Pool.Print_Status;
  Result := ZNet_Instance_Pool.Num;
end;

function TC40_Console_Help.Do_Enabled_Delay_Free_Info(var OP_Param: TOpParam): Variant;
begin
  if length(OP_Param) > 0 then
      Print_Tracking_Delay_Free := OP_Param[0]
  else
      Print_Tracking_Delay_Free := True;
  Result := True;
end;

function TC40_Console_Help.Do_Enabled_Intermediate_Instance_Info(var OP_Param: TOpParam): Variant;
begin
  if length(OP_Param) > 0 then
      Print_Intermediate_Instance_Status := OP_Param[0]
  else
      Print_Intermediate_Instance_Status := True;
  Result := True;
end;

function TC40_Console_Help.Do_Service_Cmd_Info(var OP_Param: TOpParam): Variant;
begin
  ZNet_Instance_Pool.Print_Service_CMD_Info;
  Result := ZNet_Instance_Pool.Num;
end;

function TC40_Console_Help.Do_Client_Cmd_Info(var OP_Param: TOpParam): Variant;
begin
  ZNet_Instance_Pool.Print_Client_CMD_Info;
  Result := ZNet_Instance_Pool.Num;
end;

function TC40_Console_Help.Do_Service_Statistics_Info(var OP_Param: TOpParam): Variant;
begin
  ZNet_Instance_Pool.Print_Service_Statistics_Info;
  Result := ZNet_Instance_Pool.Num;
end;

function TC40_Console_Help.Do_Client_Statistics_Info(var OP_Param: TOpParam): Variant;
begin
  ZNet_Instance_Pool.Print_Client_Statistics_Info;
  Result := ZNet_Instance_Pool.Num;
end;

function TC40_Console_Help.Do_ZDB2_Info(var OP_Param: TOpParam): Variant;
var
  tmp: SystemString;
begin
  DoStatus('');
  Static_Copy_Instance_Pool__.Lock;
  try
    DoStatus('total static-technology copy task: %d', [Static_Copy_Instance_Pool__.Num]);
    if Static_Copy_Instance_Pool__.Num > 0 then
      begin
        with Static_Copy_Instance_Pool__.Repeat_ do
          repeat
              DoStatus('static-technology copy task: %s', [Queue^.Data.Copy_To_Dest.Text]);
          until not Next;
      end;
  finally
      Static_Copy_Instance_Pool__.UnLock;
  end;
  DoStatus('');
  Dynamic_Copy_Instance_Pool__.Lock;
  try
    DoStatus('total dynamic-technology copy task: %d', [Dynamic_Copy_Instance_Pool__.Num]);
    if Dynamic_Copy_Instance_Pool__.Num > 0 then
      begin
        with Dynamic_Copy_Instance_Pool__.Repeat_ do
          repeat
              DoStatus('dynamic-technology copy task: %s', [Queue^.Data.Copy_To_Dest.Text]);
          until not Next;
      end;
  finally
      Dynamic_Copy_Instance_Pool__.UnLock;
  end;
  if Th_Engine_Marshal_Pool__.Num > 0 then
    begin
      DoStatus('');
      Th_Engine_Marshal_Pool__.Lock;
      try
        with Th_Engine_Marshal_Pool__.Repeat_ do
          repeat
            if Queue^.Data.Owner <> nil then
                tmp := Queue^.Data.Owner.ClassName
            else
                tmp := 'NULL';
            DoStatus('"%s" Owner "%s" database %d/%s/%s ', [Queue^.Data.ClassName, tmp, Queue^.Data.Total,
                umlGSizeToStr(Queue^.Data.Database_Size).Text,
                umlGSizeToStr(Queue^.Data.Database_Physics_Size).Text
                ]);
            DoStatus(Queue^.Data.Get_State_Info());
          until not Next;
      finally
          Th_Engine_Marshal_Pool__.UnLock;
      end;
    end;
  if ZDB2_Th_Queue_Instance_Pool__.Num > 0 then
    begin
      DoStatus('');
      ZDB2_Th_Queue_Instance_Pool__.Lock;
      try
        with ZDB2_Th_Queue_Instance_Pool__.Repeat_ do
          repeat
              DoStatus('Queue Engine: %d Queue:%d Size/Block:%s/%s/%d MTime: %s file: %s',
              [I__ + 1,
                Queue^.Data.QueueNum,
                umlSizeToStr(Queue^.Data.CoreSpace_Size).Text,
                umlSizeToStr(Queue^.Data.CoreSpace_Physics_Size).Text,
                Queue^.Data.CoreSpace_BlockCount,
                umlTimeTickToStr(GetTimeTick - Queue^.Data.Last_Modification).Text,
                if_(Queue^.Data.Is_Memory_Database, '(Memory)', Queue^.Data.Database_FileName.Text)]);
          until not Next;
      finally
          ZDB2_Th_Queue_Instance_Pool__.UnLock;
      end;
    end;
  Result := ZDB2_Th_Queue_Instance_Pool__.Num;
end;

function TC40_Console_Help.Do_ZDB2_Flush(var OP_Param: TOpParam): Variant;
begin
  if Th_Engine_Marshal_Pool__.Num > 0 then
    begin
      DoStatus('');
      Th_Engine_Marshal_Pool__.Lock;
      try
        with Th_Engine_Marshal_Pool__.Repeat_ do
          repeat
              Queue^.Data.Flush(False);
          until not Next;
      finally
          Th_Engine_Marshal_Pool__.UnLock;
      end;
    end;
  Result := Th_Engine_Marshal_Pool__.Num;
end;

function TC40_Console_Help.Do_Custom_Console_Cmd(Sender: TOpCustomRunTime; OP_RT_Data: POpRTData; var OP_Param: TOpParam): Variant;
var
  tk: TTimeTick;
  LName: U_String;
  i: Integer;
  cc: TC4_Help_Console_Command;
  __repeat__: TC4_Help_Console_Command_Decl.TRepeat___;
  rData: TC4_Help_Console_Command_Data;
begin
  tk := GetTimeTick;
  LName := OP_RT_Data^.name;
  for i := 0 to C40_ServicePool.Count - 1 do
    begin
      cc := C40_ServicePool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if LName.Same(rData.Cmd) then
              begin
                rData.DoExecute(OP_Param);
                DoStatus('execute %s from %s(%s)', [rData.Cmd, C40_ServicePool[i].ClassName, C40_ServicePool[i].ServiceInfo.ServiceTyp.Text]);
              end;
          until not __repeat__.Next;
        end;
    end;
  for i := 0 to C40_ClientPool.Count - 1 do
    begin
      cc := C40_ClientPool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if LName.Same(rData.Cmd) then
              begin
                rData.DoExecute(OP_Param);
                DoStatus('execute %s from %s(%s)', [rData.Cmd, C40_ClientPool[i].ClassName, C40_ClientPool[i].ClientInfo.ServiceTyp.Text]);
              end;
          until not __repeat__.Next;
        end;
    end;
  for i := 0 to C40_VM_Service_Pool.Count - 1 do
    begin
      cc := C40_VM_Service_Pool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if LName.Same(rData.Cmd) then
              begin
                rData.DoExecute(OP_Param);
                DoStatus('execute %s from %s', [rData.Cmd, C40_VM_Service_Pool[i].ClassName]);
              end;
          until not __repeat__.Next;
        end;
    end;
  for i := 0 to C40_VM_Client_Pool.Count - 1 do
    begin
      cc := C40_VM_Client_Pool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if LName.Same(rData.Cmd) then
              begin
                rData.DoExecute(OP_Param);
                DoStatus('execute %s from %s', [rData.Cmd, C40_VM_Client_Pool[i].ClassName]);
              end;
          until not __repeat__.Next;
        end;
    end;
  Result := PFormat('time:%dms', [GetTimeTick - tk]);
end;

constructor TC40_Console_Help.Create;
begin
  inherited Create;
  HelpTextStyle := tsPascal;
  IsExit := False;
  opRT := nil;
  Last_Instance_State := nil;
  Update_opRT;
end;

destructor TC40_Console_Help.Destroy;
begin
  DisposeObjectAndNil(opRT);
  DisposeObjectAndNil(Last_Instance_State);
  inherited Destroy;
end;

procedure TC40_Console_Help.Update_opRT;
var
  i: Integer;
  cc: TC4_Help_Console_Command;
  __repeat__: TC4_Help_Console_Command_Decl.TRepeat___;
  rData: TC4_Help_Console_Command_Data;
begin
  DisposeObjectAndNil(opRT);
  opRT := TOpCustomRunTime.Create;
  opRT.Reg_Param_OpM('Help', 'help info.', Do_Help)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Exit', 'safe close this console.', Do_Exit)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Close', 'safe close this console.', Do_Exit)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('service', 'service(ip, port), local service report.', Do_Service, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('server', 'server(ip, port), local service report.', Do_Service, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('serv', 'serv(ip, port), local service report.', Do_Service, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('tunnel', 'tunnel(ip, port), tunnel report.', Do_Tunnel, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('client', 'client(ip, port), tunnel report.', Do_Tunnel, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('cli', 'cli(ip, port), tunnel report.', Do_Tunnel, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('RegInfo', 'C4 registed info.', Do_Reg, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('KillNet', 'KillNet(ip,port), kill physics network.', Do_KillNet, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('C4_Clean', 'C4_Clean(), clean all physics network.', Do_C4_Clean, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Quiet', 'Quiet(bool), set quiet mode.', Do_SetQuiet, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Save_All_C4Service_Config', 'Save_All_C4Service_Config(), save all c4 service config to file', Do_Save_All_C4Service_Config, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Save_All_C4Client_Config', 'Save_All_C4Client_Config(), save all c4 client config to file', Do_Save_All_C4Client_Config, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Instance_Info', 'Instance_Info(), print all instance state.', Do_Instance_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Inst_Info', 'Inst_Info(), print all instance state.', Do_Instance_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Instance_Info_Sort_Update', 'Instance_Info_Sort_Update(), print all instance state sort by update.', Do_Instance_Info_Sort_Update, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Inst_Info_Sort_Update', 'Inst_Info_Sort_Update(), print all instance state sort by update.', Do_Instance_Info_Sort_Update, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Instance_Info_Sort_Time', 'Instance_Info_Sort_Time(), print all instance states sort by time.', Do_Instance_Info_Sort_Time, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Inst_Info_Sort_Time', 'Inst_Info_Sort_Time(), print all instance states sort by time.', Do_Instance_Info_Sort_Time, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Build_Instance_State', 'Build_Instance_State(), build current instance states.', Do_Build_Instance_State, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Compare_Instance_State', 'Compare_Instance_State(), compare current instance states.', Do_Compare_Instance_State, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('HPC_Thread_Info', 'HPC_Thread_Info(), print hpc-thread for C4 network.', Do_HPC_Thread_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('ZNet_Instance_Info', 'ZNet_Instance_Info(), print Z-Net instance for C4 network.', Do_ZNet_Instance_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('ZNet_Info', 'ZNet_Info(), print Z-Net instance for C4 network.', Do_ZNet_Instance_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Delay_Free_Info', 'Delay_Free_Info(enabled), print delay free instance info.', Do_Enabled_Delay_Free_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Enabled_Delay_Info', 'Enabled_Delay_Info(enabled), print delay free instance info.', Do_Enabled_Delay_Free_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Intermediate_Instance_Info', 'Intermediate_Instance_Info(enabled), print Intermediateinstance status.', Do_Enabled_Intermediate_Instance_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Enabled_Intermediate_Instance_Info', 'Enabled_Intermediate_Instance_Info(enabled), print Intermediateinstance status.', Do_Enabled_Intermediate_Instance_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Service_CMD_Info', 'Service_CMD_Info(), print service cmd info.', Do_Service_Cmd_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Server_CMD_Info', 'Server_CMD_Info(), print service cmd info.', Do_Service_Cmd_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Client_CMD_Info', 'Client_CMD_Info(), print Client cmd info.', Do_Client_Cmd_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Cli_CMD_Info', 'Cli_CMD_Info(), print Client cmd info.', Do_Client_Cmd_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Service_Statistics_Info', 'Service_Statistics_Info(), print service Statistics info.', Do_Service_Statistics_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Server_Statistics_Info', 'Server_Statistics_Info(), print service Statistics info.', Do_Service_Statistics_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Client_Statistics_Info', 'Client_Statistics_Info(), print Client Statistics info.', Do_Client_Statistics_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('Cli_Statistics_Info', 'Cli_Statistics_Info(), print Client Statistics info.', Do_Client_Statistics_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('ZDB2_Info', 'ZDB2_Info(), print zdb2 thread engine for C4 network.', Do_ZDB2_Info, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('ZDB2_Flush', 'ZDB2_Flush(), flush all zdb2 thread engine.', Do_ZDB2_Flush, rtmPost)^.Category := 'C4 help';
  opRT.Reg_Param_OpM('SetQuiet', 'SetQuiet(bool), set quiet mode.', Do_SetQuiet, rtmPost)^.Category := 'C4 help';
  for i := 0 to C40_ServicePool.Count - 1 do
    begin
      cc := C40_ServicePool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if not opRT.ProcList.Exists(rData.Cmd) then
                opRT.Reg_RT_OpM(rData.Cmd, rData.Desc, Do_Custom_Console_Cmd, rtmPost)^.Category := 'C4 Console';
          until not __repeat__.Next;
        end;
    end;
  for i := 0 to C40_ClientPool.Count - 1 do
    begin
      cc := C40_ClientPool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if not opRT.ProcList.Exists(rData.Cmd) then
                opRT.Reg_RT_OpM(rData.Cmd, rData.Desc, Do_Custom_Console_Cmd, rtmPost)^.Category := 'C4 Console';
          until not __repeat__.Next;
        end;
    end;
  for i := 0 to C40_VM_Service_Pool.Count - 1 do
    begin
      cc := C40_VM_Service_Pool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if not opRT.ProcList.Exists(rData.Cmd) then
                opRT.Reg_RT_OpM(rData.Cmd, rData.Desc, Do_Custom_Console_Cmd, rtmPost)^.Category := 'C4 Console';
          until not __repeat__.Next;
        end;
    end;
  for i := 0 to C40_VM_Client_Pool.Count - 1 do
    begin
      cc := C40_VM_Client_Pool[i].ConsoleCommand;
      if cc.Num > 0 then
        begin
          __repeat__ := cc.Repeat_;
          repeat
            rData := __repeat__.Queue^.Data;
            if not opRT.ProcList.Exists(rData.Cmd) then
                opRT.Reg_RT_OpM(rData.Cmd, rData.Desc, Do_Custom_Console_Cmd, rtmPost)^.Category := 'C4 Console';
          until not __repeat__.Next;
        end;
    end;
end;

procedure TC40_Console_Help.Run_HelpCmd(exp_: U_String);
var
  R: Variant;
  r_arry: TExpressionValueVector;
begin
  if IsSymbolVectorExpression(exp_, HelpTextStyle) then
    begin
      r_arry := EvaluateExpressionVector(False, False, nil, HelpTextStyle, exp_, opRT, nil);
      if not ExpressionValueVectorIsError(r_arry) then
          DoStatus('%s result: %s', [exp_.Text, ExpressionValueVectorToStr(r_arry).Text]);
    end
  else
    begin
      R := EvaluateExpressionValue(False, HelpTextStyle, exp_, opRT);
      if not ExpressionValueIsError(R) then
          DoStatus('%s result: %s', [exp_.Text, umlVarToStr(R, False).Text]);
    end;
end;

initialization

C40_QuietMode := False;
C40_SafeCheckTime := C_Tick_Second * 45;
C40_PhysicsReconnectionDelayTime := 5.0;
C40_UpdateServiceInfoDelayTime := C_Tick_Second * 1;
C40_PhysicsServiceTimeout := C_Tick_Minute * 15;
C40_PhysicsTunnelTimeout := C_Tick_Minute * 15;
C40_KillDeadPhysicsConnectionTimeout := C_Tick_Second * 60;
C40_KillIDCFaultTimeout := C_Tick_Hour * 24 * 7;
C40_EnablePerServiceDirectory := True;
{$IFDEF FPC}
C40_RootPath := umlCurrentPath;
{$ELSE FPC}
C40_RootPath := TPath.GetLibraryPath;
{$ENDIF FPC}
C40_Password := 'DTC40@ZSERVER';
C40_PhysicsClientClass := Z.Net.PhysicsIO.TPhysicsClient;
C40_Registed := TC40_RegistedDataList.Create;
C40_PhysicsServicePool := TC40_PhysicsServicePool.Create;
C40_ServicePool := TC40_Custom_ServicePool.Create;
C40_PhysicsTunnelPool := TC40_PhysicsTunnelPool.Create;
C40_ClientPool := TC40_Custom_ClientPool.Create;
C40_VM_Service_Pool := TC40_Custom_VM_Service_Pool.Create;
C40_VM_Client_Pool := TC40_Custom_VM_Client_Pool.Create;
RegisterC40('DP', TC40_Dispatch_Service, TC40_Dispatch_Client);
RegisterC40('NULL', TC40_Base_NULL_Service, TC40_Base_NULL_Client);
RegisterC40('NA', TC40_Base_NoAuth_Service, TC40_Base_NoAuth_Client);
RegisterC40('DNA', TC40_Base_DataStoreNoAuth_Service, TC40_Base_DataStoreNoAuth_Client);
RegisterC40('VA', TC40_Base_VirtualAuth_Service, TC40_Base_VirtualAuth_Client);
RegisterC40('DVA', TC40_Base_DataStoreVirtualAuth_Service, TC40_Base_DataStoreVirtualAuth_Client);
RegisterC40('D', TC40_Base_Service, TC40_Base_Client);
RegisterC40('DD', TC40_Base_DataStore_Service, TC40_Base_DataStore_Client);
C40_DefaultConfig := THashStringList.CustomCreate(8);
C40WriteConfig(C40_DefaultConfig);
C40_Cycle_Order_Seed := 0;
Ignore_Command_Line := TPascalStringList.Create;
Hooked_OnCheckThreadSynchronize := Z.Core.OnCheckThreadSynchronize;
Z.Core.OnCheckThreadSynchronize := DoCheckThreadSynchronize;

finalization

Print_Intermediate_Instance_Status := False;
Print_Tracking_Delay_Free := False;
C40Clean;
DisposeObjectAndNil(C40_PhysicsServicePool);
DisposeObjectAndNil(C40_ServicePool);
DisposeObjectAndNil(C40_PhysicsTunnelPool);
DisposeObjectAndNil(C40_ClientPool);
DisposeObjectAndNil(C40_VM_Service_Pool);
DisposeObjectAndNil(C40_VM_Client_Pool);
DisposeObjectAndNil(C40_Registed);
DisposeObjectAndNil(C40_DefaultConfig);
DisposeObjectAndNil(Ignore_Command_Line);
Z.Core.OnCheckThreadSynchronize := Hooked_OnCheckThreadSynchronize;

end.
 
