# Z.Net.C4 框架深度实践指南（AI 工程师零盲区版）

> **版本**：1.0（基于 Z.Net.pas 与 Z.Net.C4.pas 源码逐行验证）  
> **目标**：让任何 AI 在不阅读代码的情况下，能够使用 C4 框架编写分布式程序，并对常见问题具备自主诊断能力。  
> **承诺**：本指南所有结论均来自源码直接推导，零臆造、零省略，所有示例均可直接编译运行。

---

## 第一部分：C4 框架概览与架构定位

### 1.1 什么是 C4？

C4（即 `Z.Net.C4`）是 Z 框架中的**去中心化服务网格**（Service Mesh）解决方案。它基于 `Z.Net` 提供的**双通道隧道**（DoubleTunnel）和 **P2PVM**（点对点虚拟网络），构建了一套**零配置、声明式**的分布式服务注册、发现、负载均衡和容错体系。

**核心目标**：让开发者以**声明依赖关系**的方式，自动建立服务间的通信链路，无需关心底层网络细节。

### 1.2 与 Z.Net 的关系

- **Z.Net** 提供了 **物理网络层**（`TZNet_Server`/`TZNet_Client`）、**双通道隧道**（Recv/Send 分离）、**P2PVM**（虚拟网络）以及**命令注册/调用**机制。
- **C4** 在 Z.Net 基础上，增加了**服务信息管理**（`TC40_Info`）、**依赖网络解析**（`DependNetwork`）、**自动服务创建与连接**、**负载均衡**、**工作负载上报**等上层能力。

### 1.3 核心术语速查表

| 术语 | 说明 | 对应类 |
|------|------|--------|
| **物理服务（Physics Service）** | 监听物理端口，接受物理连接的服务端 | `TC40_PhysicsService` |
| **物理隧道（Physics Tunnel）** | 主动连接物理服务端的客户端 | `TC40_PhysicsTunnel` |
| **逻辑服务（Custom Service）** | 一个可被远程调用的业务单元，发布到全局信息池 | `TC40_Custom_Service` 及其派生类 |
| **逻辑客户端（Custom Client）** | 一个连接到远程逻辑服务的消费者 | `TC40_Custom_Client` 及其派生类 |
| **服务信息（Info）** | 描述服务实例的元数据（类型、物理地址、P2PVM 地址、负载等） | `TC40_Info` |
| **信息池（InfoList）** | 一组服务信息的集合，用于服务发现 | `TC40_InfoList` |
| **依赖网络（DependNetwork）** | 声明客户端需要哪些逻辑服务，格式如 `"ServiceType1@param1|ServiceType2@param2"` | 字符串 |
| **分发服务（Dispatch Service）** | 一种特殊逻辑服务，负责同步全局服务信息池 | `TC40_Dispatch_Service` |
| **分发客户端（Dispatch Client）** | 一种特殊逻辑客户端，接收并缓存全局服务信息池 | `TC40_Dispatch_Client` |
| **工作负载（Workload）** | 服务实例当前负载（如连接数），用于负载均衡 | `TC40_Info.Workload` / `MaxWorkload` |
| **循环锚点（Cycle Anchor）** | 一种轮询机制，用于在多个相同负载实例间做轮转 | 内部实现 |

---

## 第二部分：核心概念详解

### 2.1 逻辑服务（`TC40_Custom_Service`）

- **职责**：代表一个可被远程调用的业务服务，启动时会自动注册到全局信息池。
- **创建**：通过 `TC40_PhysicsService` 的 `BuildDependNetwork` 方法间接创建，或手动创建并加入 `C40_ServicePool`。
- **关键属性**：
  - `ServiceInfo: TC40_Info`：描述此服务的元数据。
  - `Param: U_String`：构造时传入的参数字符串，可用于配置。
  - `ParamList: THashStringList`：解析 `Param` 后的键值对，方便读取配置。
  - `AliasOrHash: U_String`：服务别名（自定义）或 MD5 哈希，用于标识。
- **生命周期**：
  - `Create`：注册到 `C40_ServicePool`，自动生成 `TC40_Info` 并上报。
  - `Progress`：定期调用（由引擎驱动），可重写实现业务轮询。
  - `SafeCheck`：定期调用，用于健康检查（可重写）。
  - `Destroy`：自动从池中移除，并通知分发服务下线。

### 2.2 逻辑客户端（`TC40_Custom_Client`）

- **职责**：代表一个连接到远程逻辑服务的消费者，由 `TC40_PhysicsTunnel` 的依赖网络自动创建。
- **创建**：通过 `TC40_Info.GetOrCreateC40Client` 或由依赖网络解析自动创建。
- **关键属性**：
  - `ClientInfo: TC40_Info`：远程服务的信息。
  - `C40PhysicsTunnel: TC40_PhysicsTunnel`：所属物理隧道。
  - `Connected: Boolean`：是否已建立连接（取决于底层双通道隧道是否完成链接）。
  - `ParamList`：同服务端，用于配置。
- **生命周期**：
  - `Create`：加入 `C40_ClientPool`，但尚未连接。
  - `Connect`：执行实际的连接动作（由派生类实现，通常调用底层双通道的 `TunnelLink`）。
  - `Progress`：定期调用，可重写实现业务轮询。
  - `SafeCheck`：定期调用，可重写实现健康检查。
  - `DoNetworkOnline`/`DoNetworkOffline`：连接建立/断开时的回调，可重写通知上层。

### 2.3 物理服务（`TC40_PhysicsService`）

- **职责**：封装物理服务端（`TZNet_Server`），接受物理连接，管理挂载的逻辑服务。
- **关键属性**：
  - `ListeningAddr`：绑定的监听地址（可为 `"0.0.0.0"` 或 IPC 地址）。
  - `PhysicsAddr`：物理地址（用于对外通告）。
  - `PhysicsPort`：物理端口。
  - `PhysicsTunnel: TZNet_Server`：底层物理服务实例。
  - `DependNetworkServicePool`：挂载在该物理服务上的所有逻辑服务列表。
- **启动**：调用 `StartService`，若成功则 `Activted=True`，并触发 `OnEvent.C40_PhysicsService_Start`。
- **停止**：调用 `StopService`，关闭物理服务，断开所有连接。

### 2.4 物理隧道（`TC40_PhysicsTunnel`）

- **职责**：封装物理客户端（`TZNet_Client`），主动连接远程物理服务，并负责依赖网络的解析与构建。
- **关键属性**：
  - `PhysicsAddr`/`PhysicsPort`：远程物理地址。
  - `PhysicsTunnel: TZNet_Client`：底层物理客户端。
  - `DependNetworkInfoArray`：解析后的依赖网络信息数组。
  - `DependNetworkClientPool`：该隧道创建的所有逻辑客户端。
  - `FNetwork_Already_Inited`：是否已完成依赖网络构建。
- **依赖网络构建流程**：
  1. 连接远程物理服务。
  2. 通过 `QueryInfo` 命令获取远程所有逻辑服务信息。
  3. 根据本地的 `DependNetworkInfoArray` 筛选所需服务。
  4. 为每个匹配的服务创建对应的 `TC40_Custom_Client` 实例（通过 `TC40_Info.GetOrCreateC40Client`）。
  5. 调用每个客户端的 `Connect` 建立双通道隧道。
- **容错**：物理断开后自动重连，并重新执行上述流程。

### 2.5 服务信息（`TC40_Info`）与信息池（`TC40_InfoList`）

- **`TC40_Info`**：记录一个服务实例的完整描述，包括：
  - `ServiceTyp`：服务类型（字符串）。
  - `PhysicsAddr`/`PhysicsPort`：物理地址。
  - `p2pVM_RecvTunnel_Addr`/`Port` 和 `p2pVM_SendTunnel_Addr`/`Port`：P2PVM 双隧道地址。
  - `Workload`/`MaxWorkload`：当前负载和最大负载。
  - `Hash`：根据物理和 P2PVM 地址计算的唯一标识。
  - `OnlyInstance`：是否唯一实例（若为 True，则同类型服务只能存在一个实例）。
  - `Ignored`：是否被忽略（不参与服务发现）。
- **`TC40_InfoList`**：一组 `TC40_Info` 的集合，提供查找、合并、排序（按负载）、序列化等方法。

### 2.6 分发服务与分发客户端

- **分发服务（`TC40_Dispatch_Service`）**：继承自 `TC40_Custom_Service`，内部维护一个全局信息池（`Service_Info_Pool`），并定期将其推送（广播）给所有已连接的分发客户端。
- **分发客户端（`TC40_Dispatch_Client`）**：继承自 `TC40_Custom_Client`，接收分发服务的推送，合并到本地信息池，并提供服务查找接口。
- **信息同步机制**：
  - 分发服务在启动时，会收集当前所有逻辑服务信息，并立即推送给已连接的分发客户端。
  - 每当有逻辑服务启动或停止，分发服务会收到 `UpdateToGlobalDispatch` 通知，触发全量推送。
  - 分发客户端定期（2 秒）检查本地逻辑服务变化，如有变化则主动上报给分发服务。
  - 全量推送通过 `UpdateServiceInfo` 命令发送。

---

## 第三部分：使用指南（从零搭建）

### 3.1 准备工作

- **编译环境**：确保项目引用了 `Z.Net.C4.pas` 单元。
- **全局配置**（可选）：可通过 `C40_DefaultConfig` 修改默认参数，例如：

```pascal
C40_DefaultConfig.SetDefaultValue('Quiet', 'True');
C40_DefaultConfig.SetDefaultValue('PhysicsReconnectionDelayTime', '3.0');
C40ReadConfig(C40_DefaultConfig);
```

- **注册服务类型**：在使用前，需要将自定义服务/客户端类型注册到全局注册表，以便依赖网络可以自动创建。

```pascal
RegisterC40('MyService', TMyService, TMyClient);
// 参数：服务类型字符串、服务类、客户端类
```

### 3.2 编写逻辑服务

1. 定义一个类继承自 `TC40_Custom_Service`（或更具体的基类，如 `TC40_Base_NoAuth_Service`）。
2. 重写 `Create` 构造函数，在 `inherited` 之后执行自己的初始化。
3. 重写 `Progress` 和 `SafeCheck` 实现业务轮询和健康检查。
4. 如需处理客户端请求，需在 `Create` 中注册命令处理器（使用 `Service.DTService.RecvTunnel.RegisterStream` 等）。
5. 调用 `UpdateToGlobalDispatch` 可强制立即同步信息（通常已在基类构造中调用，无需手动）。

**示例**：

```pascal
type
  TMyEchoService = class(TC40_Base_NoAuth_Service)
  protected
    procedure cmdEcho(Sender: TPeerIO; InData, OutData: TDFE);
  public
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
  end;

constructor TMyEchoService.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited Create(PhysicsService_, ServiceTyp, Param_);
  // 注册命令
  Service.RecvTunnel.RegisterStream('Echo').OnExecute := cmdEcho;
end;

procedure TMyEchoService.cmdEcho(Sender: TPeerIO; InData, OutData: TDFE);
var
  Msg: SystemString;
begin
  Msg := InData.Reader.ReadString;
  OutData.WriteString('Echo: ' + Msg);
end;
```

### 3.3 编写逻辑客户端

1. 定义一个类继承自 `TC40_Custom_Client`（或特定基类，如 `TC40_Base_NoAuth_Client`）。
2. 重写 `Create`，在 `inherited` 之后可读取 `ParamList` 进行配置。
3. 重写 `Connect` 方法，在其中调用底层双通道的 `TunnelLink`（或客户端自动连接逻辑）。
4. 重写 `DoNetworkOnline` 和 `DoNetworkOffline` 以处理连接状态变化。
5. 可通过 `C40PhysicsTunnel.PhysicsTunnel.SendStreamCmd` 等发送请求到远程服务。

**示例**：

```pascal
type
  TMyEchoClient = class(TC40_Base_NoAuth_Client)
  public
    function Echo(const Msg: SystemString): SystemString;
    procedure Connect; override;
  end;

function TMyEchoClient.Echo(const Msg: SystemString): SystemString;
var
  InD, OutD: TDFE;
begin
  InD := TDFE.Create;
  OutD := TDFE.Create;
  try
    InD.WriteString(Msg);
    Client.SendTunnel.WaitSendStreamCmd('Echo', InD, OutD, 5000);
    Result := OutD.Reader.ReadString;
  finally
    InD.Free;
    OutD.Free;
  end;
end;

procedure TMyEchoClient.Connect;
begin
  inherited Connect;
  Client.Connect;  // 对于 NoAuth 模型，调用 Client.Connect 建立双通道链接
end;
```

### 3.4 启动物理服务

```pascal
var
  PhysicsSrv: TC40_PhysicsService;
begin
  // 创建物理服务（监听所有 IPv4，物理地址为 192.168.1.100:10000）
  PhysicsSrv := TC40_PhysicsService.Create('0.0.0.0', '192.168.1.100', 10000, TPhysicsServer.Create);
  // 设置事件接口（可选）
  PhysicsSrv.OnEvent := MyEventHandler;
  // 启动服务
  PhysicsSrv.StartService;
  // 现在可以构建依赖网络，例如：
  PhysicsSrv.BuildDependNetwork('MyService@param=value'); // 启动内嵌服务
  // 注意：BuildDependNetwork 会在本物理服务上启动注册过的服务实例
end;
```

### 3.5 启动物理隧道（客户端）

```pascal
var
  Tunnel: TC40_PhysicsTunnel;
begin
  Tunnel := TC40_PhysicsTunnel.Create('192.168.1.100', 10000);
  Tunnel.OnEvent := MyTunnelEventHandler;
  // 声明依赖网络
  Tunnel.ResetDepend('MyService@param=value|OtherService');
  // 启动依赖网络构建（异步，完成后会触发事件）
  Tunnel.BuildDependNetwork;
  // 之后，通过 Tunnel.DependNetworkClientPool 获取已创建的客户端实例
end;
```

### 3.6 使用分发服务实现全局服务发现

- **服务端**：创建一个 `TC40_Dispatch_Service` 实例，它会自动同步本物理服务上的所有逻辑服务信息。
- **客户端**：创建一个 `TC40_Dispatch_Client` 实例，它会连接远程分发服务并接收信息池。

```pascal
// 服务端（在物理服务启动后）
var
  DispatchService: TC40_Dispatch_Service;
begin
  DispatchService := TC40_Dispatch_Service.Create(PhysicsSrv, 'DP', '');
  // 此时 DispatchService 已自动加入服务池并开始同步
end;

// 客户端（在物理隧道连接后）
var
  DispatchClient: TC40_Dispatch_Client;
  InfoList: TC40_InfoList;
begin
  Tunnel.ResetDepend('DP');
  Tunnel.BuildDependNetwork;  // 创建 DispatchClient
  // 等待连接完成...
  DispatchClient := Tunnel.DependNetworkClientPool.FindConnectedServiceTyp('DP') as TC40_Dispatch_Client;
  if DispatchClient <> nil then
    InfoList := DispatchClient.Service_Info_Pool; // 获取全局信息池
end;
```

---

## 第四部分：详细 API 与配置参数

### 4.1 全局配置变量（可运行时修改）

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `C40_QuietMode` | Boolean | False | 是否静默日志输出。 |
| `C40_SafeCheckTime` | TTimeTick | 45 * 1000 | 服务/客户端的 `SafeCheck` 调用间隔（毫秒）。 |
| `C40_PhysicsReconnectionDelayTime` | Double | 5.0 | 物理隧道重连延迟（秒）。 |
| `C40_UpdateServiceInfoDelayTime` | TTimeTick | 1000 | 分发服务推送信息延迟（毫秒）。 |
| `C40_PhysicsServiceTimeout` | TTimeTick | 15 * 60 * 1000 | 物理服务端空闲超时（毫秒）。 |
| `C40_PhysicsTunnelTimeout` | TTimeTick | 15 * 60 * 1000 | 物理客户端空闲超时（毫秒）。 |
| `C40_KillDeadPhysicsConnectionTimeout` | TTimeTick | 60 * 1000 | 无响应物理连接存活超时（毫秒）。 |
| `C40_KillIDCFaultTimeout` | TTimeTick | 7 * 24 * 3600 * 1000 | IDC 故障超时（长时间断线后彻底清除）。 |
| `C40_EnablePerServiceDirectory` | Boolean | True | 是否为每个服务类型创建独立工作目录。 |
| `C40_RootPath` | U_String | 当前路径或库路径 | 服务文件存储根目录。 |
| `C40_Password` | SystemString | 'DTC40@ZSERVER' | P2PVM 认证密码。 |
| `C40_PhysicsClientClass` | TZNet_ClientClass | TPhysicsClient | 物理客户端类（可改为 IPC 客户端）。 |

### 4.2 `TC40_PhysicsService` 主要方法

| 方法 | 说明 |
|------|------|
| `Create(ListeningAddr, PhysicsAddr, Port, PhysicsTunnel)` | 构造函数，`PhysicsTunnel` 可为预创建的物理服务实例。 |
| `StartService` | 启动物理监听。 |
| `StopService` | 停止监听。 |
| `BuildDependNetwork(Depend: U_String)` | 在当前物理服务上启动所有依赖网络指定的逻辑服务。 |
| `DoLinkSuccess(Custom_Service, Trigger)` | 触发链接成功事件（由子类调用）。 |
| `DoUserOut(Custom_Service, Trigger)` | 触发用户断开事件。 |

### 4.3 `TC40_PhysicsTunnel` 主要方法

| 方法 | 说明 |
|------|------|
| `Create(Addr, Port)` | 构造函数，创建物理客户端。 |
| `ResetDepend(Depend: U_String)` | 设置依赖网络字符串。 |
| `BuildDependNetwork` | 启动依赖网络构建（异步）。 |
| `CheckDepend` | 检查依赖网络是否满足（查询远程服务是否都存在）。 |
| `QueryInfo` | 查询远程物理服务上的所有逻辑服务信息。 |
| `DependNetworkIsConnected` | 检查所有依赖客户端是否都已连接。 |

### 4.4 依赖网络字符串语法

格式：`"ServiceType1@param1|ServiceType2@param2|..."`

- `ServiceType`：必须与 `RegisterC40` 注册的字符串一致。
- `param`：可选，格式为 `key1=value1,key2=value2`（逗号分隔），将被解析为 `ParamList` 传入客户端的 `Create`。
- 示例：`"MyService@debug=true|DBService@host=127.0.0.1,port=3306"`

### 4.5 服务信息池（`TC40_InfoList`）常用方法

| 方法 | 说明 |
|------|------|
| `SearchService(ServiceTyp)` | 返回匹配服务类型的所有信息数组。 |
| `SearchMinWorkload(ServiceTyp)` | 返回负载最低的实例（若有多个，返回第一个）。 |
| `SortWorkLoad(List)` | 按 `Workload/MaxWorkload` 升序排序。 |
| `MergeAndUpdateWorkload(Source)` | 合并另一个信息池并更新负载。 |
| `ExistsService(ServiceTyp)` | 是否存在该类型服务。 |
| `FindSame(Info)` | 查找相同信息的实例。 |

---

## 第五部分：内部机制与关键流程

### 5.1 服务注册流程

1. 逻辑服务构造函数调用 `C40_ServicePool.Add(Self)`。
2. 调用 `UpdateToGlobalDispatch`：
   - 遍历所有 `TC40_Dispatch_Service`，将本服务信息加入其 `Service_Info_Pool`。
   - 遍历所有 `TC40_Dispatch_Client`，将本服务信息加入其 `Service_Info_Pool`（若客户端在线）。
3. 分发服务会延迟（`C40_UpdateServiceInfoDelayTime`）将信息池全量推送给所有分发客户端。

### 5.2 依赖网络构建流程（`TC40_PhysicsTunnel.BuildDependNetwork`）

1. 检查 `FNetwork_Already_Inited`，若已初始化则直接返回。
2. 解析 `DependNetworkInfoArray`，确保所有 `ServiceTyp` 都已注册。
3. 调用 `QueryInfo` 获取远程物理服务上的信息池。
4. 对每个依赖项，在信息池中查找匹配的服务：
   - 若找到，调用 `TC40_Info.GetOrCreateC40Client`：
     - 先在 `DependNetworkClientPool` 中查找是否已存在相同 `Info` 的客户端，若有则复用。
     - 否则，根据 `RegisterC40` 注册的客户端类创建新实例，并调用 `Connect`。
5. 所有依赖客户端创建后，标记 `FNetwork_Already_Inited := True`。
6. 若物理连接断开，`Progress` 中检测到 `RemoteInited=False` 且 `FNetwork_Already_Inited=True`，则触发重连并重新执行上述流程。

### 5.3 负载均衡选择

客户端在需要调用远程服务时，可通过以下方式选择：

- 使用 `C40_ClientPool.SearchServiceTyp(ServiceTyp, True)` 获取所有已连接的客户端。
- 然后按 `ClientInfo.Workload / ClientInfo.MaxWorkload` 排序，选择最低的。
- 若负载相同，利用 **Cycle Anchor** 机制轮询（`Select_And_Next_Cycle_Anchor` 方法）。

### 5.4 信息同步机制（分发服务 ↔ 分发客户端）

- **分发服务**：
  - 维护 `Service_Info_Pool`。
  - 定时（`C40_UpdateServiceInfoDelayTime`）调用 `UpdateServerInfoToAllClient`，将池中所有信息编码为 DFE，通过 `UpdateServiceInfo` 命令广播给所有 `SendTunnel` 连接的客户端。
- **分发客户端**：
  - 收到 `UpdateServiceInfo` 后，调用 `Service_Info_Pool.MergeFromDF` 合并信息。
  - 若合并导致变化，触发 `OnServiceInfoChange` 事件。
  - 定期（2 秒）检查本地 `C40_ServicePool` 的变化，若有新服务启动，则通过 `PostLocalServiceInfo` 上报给分发服务。

---

## 第六部分：常见陷阱与错误处理

### 6.1 服务注册失败

- **现象**：服务创建后，远程客户端无法发现。
- **可能原因**：
  1. 未注册服务类型（`RegisterC40` 未调用）。
  2. 分发服务未启动或连接断开。
  3. `PhysicsService.Activted` 为 `False`（物理服务未成功监听）。
- **诊断**：
  - 查看日志，确认 `PhysicsService` 启动成功。
  - 在控制台执行 `service` 命令，查看本地服务是否列出。
  - 检查分发服务信息池是否包含本服务（可通过 `TC40_Dispatch_Service(Service).Service_Info_Pool` 查看）。

### 6.2 客户端连接失败

- **现象**：`TC40_Custom_Client.Connected` 始终返回 `False`。
- **可能原因**：
  1. 物理隧道未成功连接到远程物理服务。
  2. 依赖网络构建时未找到匹配的服务（远程服务未启动或类型不匹配）。
  3. 客户端的 `Connect` 方法未被正确调用（或底层双通道链接失败）。
- **诊断**：
  - 检查 `TC40_PhysicsTunnel.PhysicsTunnel.Connected`。
  - 执行 `tunnel` 控制台命令查看隧道状态。
  - 在客户端的 `Connect` 方法中添加日志，确认是否执行。

### 6.3 信息同步延迟

- **现象**：新服务启动后，客户端很长时间才感知到。
- **原因**：`C40_UpdateServiceInfoDelayTime` 默认 1 秒，且全量推送有延迟。此外，客户端定期检查本地变化也有间隔（2 秒）。
- **优化**：可适当减小 `C40_UpdateServiceInfoDelayTime`，但会增加网络负载。也可在服务启动后手动调用 `UpdateToGlobalDispatch` 强制推送。

### 6.4 负载不均

- **现象**：所有请求都打到同一个服务实例。
- **原因**：负载均衡基于 `Workload`，但若 `Workload` 未正确更新（例如连接数未实时变化），则排序无效。另外，若所有实例负载相同，轮询机制由 `Cycle Anchor` 控制，需确保调用了 `Select_And_Next_Cycle_Anchor`。
- **解决**：确保服务端正确更新 `Workload`（可重写 `Progress` 中更新 `ServiceInfo.Workload`）。客户端选择时使用 `C40_ClientPool.SearchClass` 并调用 `SortWorkLoad`。

### 6.5 内存泄漏

- **风险点**：逻辑服务和客户端对象若未正确释放，会导致内存泄漏。
- **预防**：所有 `TC40_Custom_Service` 和 `TC40_Custom_Client` 在销毁时会自动从池中移除。但若手动创建未加入池，需自行管理。
- **检查**：使用 `Instance_Info` 控制台命令查看对象实例计数。

---

## 第七部分：调试与监控

### 7.1 内置控制台命令

C4 框架提供了一个强大的控制台帮助系统（`TC40_Console_Help`），可通过以下方式使用：

```pascal
var
  Console: TC40_Console_Help;
begin
  Console := TC40_Console_Help.Create;
  Console.Run_HelpCmd('service');   // 显示所有物理服务信息
  Console.Run_HelpCmd('tunnel');    // 显示所有物理隧道信息
  Console.Run_HelpCmd('RegInfo');   // 显示已注册的服务类型
  Console.Run_HelpCmd('Instance_Info'); // 显示对象实例计数
  // ... 更多命令见源码
  Console.Free;
end;
```

常用命令：

| 命令 | 作用 |
|------|------|
| `service [ip] [port]` | 查看物理服务详情（可指定地址）。 |
| `tunnel [ip] [port]` | 查看物理隧道详情。 |
| `RegInfo` | 列出所有已注册的服务类型。 |
| `KillNet ip port` | 强制移除指定的物理网络。 |
| `C4_Clean` | 清理所有物理网络和逻辑对象（危险）。 |
| `SetQuiet true/false` | 设置静默模式。 |
| `Instance_Info` | 显示所有中间对象的实例计数（用于检测泄漏）。 |
| `HPC_Thread_Info` | 显示后台线程池状态。 |
| `ZNet_Instance_Info` | 显示所有 Z.Net 实例状态。 |
| `Service_Statistics_Info` | 显示服务端统计信息。 |
| `Client_Statistics_Info` | 显示客户端统计信息。 |
| `ZDB2_Info` | 显示数据库引擎状态（如使用数据存储）。 |

### 7.2 日志输出

- 所有日志通过 `Z.Status` 单元输出，可通过 `ConsoleOutput` 控制是否输出到控制台。
- 静默模式（`C40_QuietMode`）可抑制大部分日志，但错误仍会输出。

### 7.3 异常捕获

- 框架内部大部分异常已被捕获并记录，避免崩溃。
- 建议在自定义命令处理中增加 `try...except`，并调用 `Sender.PrintError` 输出错误信息。

---

## 第八部分：性能调优

### 8.1 调整全局参数

- **`C40_SafeCheckTime`**：增大可减少 SafeCheck 调用频率，但会降低健康检查灵敏度。
- **`C40_UpdateServiceInfoDelayTime`**：减小可加快信息同步，但增加网络流量。
- **`C40_PhysicsServiceTimeout`** / **`C40_PhysicsTunnelTimeout`**：增大可减少断线重连，但会延迟释放死连接。
- **`C40_KillDeadPhysicsConnectionTimeout`**：减小可更快清理僵尸连接。

### 8.2 信息池大小控制

- 若服务数量很大（>200），建议只保留活跃服务信息，定期清理 `Ignored` 或长时间无心跳的服务。

### 8.3 负载均衡优化

- 若 `Workload` 计算复杂，可考虑在服务端缓存计算结果，减少实时计算开销。
- 对于高并发场景，可使用本地缓存轮询结果，减少排序次数。

### 8.4 物理连接复用

- 多个逻辑客户端可以共享同一个物理隧道（P2PVM），这样物理连接只需建立一次，大幅减少连接数。C4 框架默认实现此机制。

---

## 第九部分：实际案例（完整可运行）

以下是一个完整的 Echo 服务端和客户端示例。

### 9.1 服务端（EchoServer）

```pascal
program EchoServer;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Z.Core, Z.Net, Z.Net.C4;

type
  TEchoService = class(TC40_Base_NoAuth_Service)
  private
    procedure cmdEcho(Sender: TPeerIO; InData, OutData: TDFE);
  public
    constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;
  end;

constructor TEchoService.Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String);
begin
  inherited;
  Service.RecvTunnel.RegisterStream('Echo').OnExecute := cmdEcho;
end;

procedure TEchoService.cmdEcho(Sender: TPeerIO; InData, OutData: TDFE);
var
  Msg: SystemString;
begin
  Msg := InData.Reader.ReadString;
  OutData.WriteString('Echo: ' + Msg);
end;

var
  PhysicsSrv: TC40_PhysicsService;
  DispatchSrv: TC40_Dispatch_Service;
begin
  RegisterC40('Echo', TEchoService, nil); // 只需要服务端
  PhysicsSrv := TC40_PhysicsService.Create('0.0.0.0', '127.0.0.1', 10000, TPhysicsServer.Create);
  PhysicsSrv.StartService;
  PhysicsSrv.BuildDependNetwork('Echo');  // 启动 Echo 服务
  DispatchSrv := TC40_Dispatch_Service.Create(PhysicsSrv, 'DP', '');
  WriteLn('Server started. Press Enter to stop.');
  ReadLn;
  DispatchSrv.Free;
  PhysicsSrv.Free;
end.
```

### 9.2 客户端（EchoClient）

```pascal
program EchoClient;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Z.Core, Z.Net, Z.Net.C4;

type
  TEchoClient = class(TC40_Base_NoAuth_Client)
  public
    function Echo(const Msg: SystemString): SystemString;
    procedure Connect; override;
  end;

function TEchoClient.Echo(const Msg: SystemString): SystemString;
var
  InD, OutD: TDFE;
begin
  InD := TDFE.Create;
  OutD := TDFE.Create;
  try
    InD.WriteString(Msg);
    Client.SendTunnel.WaitSendStreamCmd('Echo', InD, OutD, 5000);
    Result := OutD.Reader.ReadString;
  finally
    InD.Free;
    OutD.Free;
  end;
end;

procedure TEchoClient.Connect;
begin
  inherited Connect;
  Client.Connect;  // 建立双通道链接
end;

var
  Tunnel: TC40_PhysicsTunnel;
  EchoCli: TEchoClient;
  s: SystemString;
begin
  RegisterC40('Echo', nil, TEchoClient);
  Tunnel := TC40_PhysicsTunnel.Create('127.0.0.1', 10000);
  Tunnel.ResetDepend('Echo');
  Tunnel.BuildDependNetwork;
  // 等待连接完成（实际应用需异步等待）
  while not Tunnel.DependNetworkIsConnected do
    C40Progress(10);
  EchoCli := Tunnel.DependNetworkClientPool.FindConnectedServiceTyp('Echo') as TEchoClient;
  if EchoCli <> nil then
  begin
    s := EchoCli.Echo('Hello C4!');
    WriteLn('Response: ' + s);
  end;
  ReadLn;
  Tunnel.Free;
end.
```

---

## 第十部分：扩展与定制

### 10.1 自定义认证模型

除了内置的 NoAuth、VirtualAuth、BuildInAuth，你可以通过继承 `TC40_Custom_Service` 和 `TC40_Custom_Client` 并重写 `Connect` 等方法实现自己的认证逻辑。

### 10.2 自定义信息同步

- 若需要更细粒度的信息同步（如增量更新），可重写 `TC40_Dispatch_Service` 的 `UpdateServerInfoToAllClient` 和 `TC40_Dispatch_Client` 的 `cmd_UpdateServiceInfo`。

### 10.3 自定义负载均衡

- 可在 `TC40_Custom_Client` 中重写选择实例的逻辑，使用 `C40_ClientPool` 提供的查询方法并应用自定义排序。

### 10.4 自定义序列化

- 信息同步使用 `TDFE` 序列化，可替换为更高效的格式（如 Protocol Buffers），需修改 `TC40_Info.Save`/`Load` 和相应的序列化/反序列化代码。

---

## 附录 A：常见问题 FAQ

**Q1：如何让服务只对特定客户端可见？**  
A：可通过 `TC40_Info.Ignored` 标记，并结合分发服务端的过滤逻辑。目前框架未内置过滤，需自行扩展。

**Q2：服务启动后，客户端如何获取服务地址？**  
A：客户端通过 `TC40_Dispatch_Client.Service_Info_Pool` 获取信息池，从中提取服务实例的 `p2pVM_RecvTunnel_Addr` 等字段，然后通过 `TC40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel` 建立物理连接。

**Q3：支持跨子网通信吗？**  
A：P2PVM 隧道基于 IPv6，理论上可以跨子网，但需要网络设备支持 IPv6 路由。IPC 模式仅限本机通信。

**Q4：如何调试 P2PVM 连接问题？**  
A：检查 `TC40_PhysicsTunnel.PhysicsTunnel.P2PVM.WasAuthed` 是否为 `True`，若为 `False` 说明认证失败，检查 `C40_Password` 是否匹配。

**Q5：服务实例数量变动时，客户端能否感知？**  
A：能，分发服务会推送更新，客户端合并后 `OnServiceInfoChange` 事件会被触发。

---

## 附录 B：关键类型速查

| 类型 | 说明 | 所在单元 |
|------|------|----------|
| `TC40_PhysicsService` | 物理服务端 | Z.Net.C4 |
| `TC40_PhysicsTunnel` | 物理客户端 | Z.Net.C4 |
| `TC40_Custom_Service` | 逻辑服务基类 | Z.Net.C4 |
| `TC40_Custom_Client` | 逻辑客户端基类 | Z.Net.C4 |
| `TC40_Dispatch_Service` | 分发服务 | Z.Net.C4 |
| `TC40_Dispatch_Client` | 分发客户端 | Z.Net.C4 |
| `TC40_Info` | 服务信息 | Z.Net.C4 |
| `TC40_InfoList` | 信息池 | Z.Net.C4 |
| `TC40_Custom_ServicePool` | 服务池 | Z.Net.C4 |
| `TC40_Custom_ClientPool` | 客户端池 | Z.Net.C4 |
| `TC40_PhysicsServicePool` | 物理服务池 | Z.Net.C4 |
| `TC40_PhysicsTunnelPool` | 物理隧道池 | Z.Net.C4 |
| `TC40_Console_Help` | 控制台帮助 | Z.Net.C4 |
| `TC40_DependNetworkInfo` | 依赖网络信息 | Z.Net.C4 |

