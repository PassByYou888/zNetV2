# Z.Net.C4 分布式服务框架技术白皮书

> **版本**：基于 Cloud 4.0 (C4) 框架核心实现  
> **单元**：`Z.Net.C4.pas`  
> **依赖层次**：Z.Core → Z.Net → Z.Net.DoubleTunnelIO.* → Z.Net.DataStoreService.* → Z.Net.C4

---

## 目录

- [1. 框架概述](#1-框架概述)
- [2. 核心概念](#2-核心概念)
  - [2.1 P2PVM 隧道通信](#21-p2pvm-隧道通信)
  - [2.2 服务发现与注册](#22-服务发现与注册)
  - [2.3 认证模型](#23-认证模型)
  - [2.4 依赖描述符](#24-依赖描述符)
- [3. 物理层服务与隧道](#3-物理层服务与隧道)
  - [3.1 TC40_PhysicsService](#31-tc40_physicsservice)
  - [3.2 TC40_PhysicsServicePool](#32-tc40_physicsservicepool)
  - [3.3 TC40_PhysicsTunnel](#33-tc40_physicstunnel)
  - [3.4 TC40_PhysicsTunnelPool](#34-tc40_physicstunnelpool)
  - [3.5 TC40_First_BuildDependNetwork_Fault_Fixed_Bridge](#35-tc40_first_builddependnetwork_fault_fixed_bridge)
- [4. 服务信息与发现](#4-服务信息与发现)
  - [4.1 TC40_Info](#41-tc40_info)
  - [4.2 TC40_InfoList](#42-tc40_infolist)
- [5. 自定义服务基类](#5-自定义服务基类)
  - [5.1 TC40_Custom_Service](#51-tc40_custom_service)
  - [5.2 TC40_Custom_ServicePool](#52-tc40_custom_servicepool)
  - [5.3 TC40_Custom_Client](#53-tc40_custom_client)
  - [5.4 TC40_Custom_ClientPool](#54-tc40_custom_clientpool)
  - [5.5 TC40_Custom_ClientPool_Wait](#55-tc40_custom_clientpool_wait)
  - [5.6 TSearchServiceAndBuildConnection_Bridge](#56-tsearchserviceandbuildconnection_bridge)
- [6. 自动部署机制](#6-自动部署机制)
  - [6.1 TC40_Auto_Deployment_Client\<T\>](#61-tc40_auto_deployment_clientt)
- [7. 调度服务（Dispatch）](#7-调度服务dispatch)
  - [7.1 TC40_Dispatch_Service](#71-tc40_dispatch_service)
  - [7.2 TC40_Dispatch_Client](#72-tc40_dispatch_client)
- [8. 认证模型实现](#8-认证模型实现)
  - [8.1 NULL 模型](#81-null-模型)
  - [8.2 NoAuth 模型](#82-noauth-模型)
  - [8.3 VirtualAuth 模型](#83-virtualauth-模型)
  - [8.4 BuiltInAuth 模型](#84-builtinauth-模型)
  - [8.5 DataStore 变体](#85-datastore-变体)
- [9. VM 服务/客户端模板](#9-vm-服务客户端模板)
  - [9.1 TC40_Custom_VM_Service](#91-tc40_custom_vm_service)
  - [9.2 TC40_Custom_VM_Client](#92-tc40_custom_vm_client)
  - [9.3 池管理](#93-池管理)
- [10. 控制台帮助系统](#10-控制台帮助系统)
  - [10.1 TC4_Help_Console_Command_Data](#101-tc4_help_console_command_data)
  - [10.2 TC4_Help_Console_Command](#102-tc4_help_console_command)
  - [10.3 TC40_Console_Help](#103-tc40_console_help)
- [11. 全局 API 函数](#11-全局-api-函数)
- [12. 全局变量](#12-全局变量)
- [13. 初始化与终结](#13-初始化与终结)
- [14. 回调类型与接口](#14-回调类型与接口)
  - [14.1 IC40_PhysicsService_Event](#141-ic40_physicsservice_event)
  - [14.2 IC40_PhysicsTunnel_Event](#142-ic40_physicstunnel_event)
- [15. 附录](#15-附录)
  - [15.1 依赖描述符速查](#151-依赖描述符速查)
  - [15.2 认证模型选择指南](#152-认证模型选择指南)
  - [15.3 典型部署拓扑](#153-典型部署拓扑)

---

## 1. 框架概述

**Z.Net.C4 (Cloud 4.0)** 是一个面向大规模分布式系统设计的服务框架，构建在 Z.Net 网络层之上，利用 P2PVM（Peer-to-Peer Virtual Machine）隧道实现服务间通信。该框架提供了：

- **物理层抽象**：统一管理服务端（`TC40_PhysicsService`）和客户端（`TC40_PhysicsTunnel`）物理连接。
- **服务发现**：通过调度服务（Dispatch Service）实现服务注册、发现和负载感知路由。
- **多种认证模型**：NoAuth（无认证）、VirtualAuth（虚拟认证）和 BuiltInAuth（内置认证）。
- **依赖注入**：通过依赖描述符（`TC40_DependNetworkInfo`）自动构建服务依赖网络。
- **自动部署**：`TC40_Auto_Deployment_Client<T>` 泛型类实现客户端的自动等待和部署。
- **交互式控制台**：`TC40_Console_Help` 提供丰富的诊断和管理命令。
- **VM 风格封装**：`TC40_Custom_VM_Service/Client` 提供可独立启动/停止的组件模型。

### 1.1 架构层次图

```
┌─────────────────────────────────────────────────────────────────┐
│                   Application / User Code                        │
│         (自定义服务/客户端，继承自 TC40_Custom_*)               │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────┐
│              TC40_Custom_Service / Client                        │
│         (服务/客户端基类，提供 P2PVM 集成、配置管理)            │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────┐
│           TC40_PhysicsService / PhysicsTunnel                    │
│         (物理端点管理 — 监听/连接，依赖构建)                    │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────┐
│              TZNet (Z.Net) — 底层网络 I/O                        │
│         (命令协议、P2PVM、序列包、加密压缩)                     │
└─────────────────────────────────────────────────────────────────┘
                                 │
┌─────────────────────────────────────────────────────────────────┐
│              Z.Core — 基础库                                     │
│         (线程、容器、原子操作、日志)                            │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 数据流

1. **物理服务启动**：`TC40_PhysicsService` 监听物理端口，根据依赖描述符构建依赖服务。
2. **物理隧道连接**：`TC40_PhysicsTunnel` 连接远程物理服务，构建对应的依赖客户端。
3. **服务注册**：每个自定义服务通过 `UpdateToGlobalDispatch` 将其 `TC40_Info` 发布到调度服务。
4. **服务发现**：调度服务维护全局 `TC40_InfoList`，并广播更新到所有连接的调度客户端。
5. **服务查询**：客户端通过 `TC40_InfoList` 查询可用服务，通过 `GetOrCreatePhysicsTunnel` 建立连接。
6. **通信**：所有数据通过 P2PVM 双通道隧道（分离的接收/发送逻辑通道）传输。

---

## 2. 核心概念

### 2.1 P2PVM 隧道通信

P2PVM 是 C4 框架的通信基础，它在单条物理连接上建立多个逻辑通道：

- **接收隧道（RecvTunnel）**：接收来自对端的消息。
- **发送隧道（SendTunnel）**：向对端发送消息。
- **双通道（DoubleTunnel）**：Recv 和 Send 分离，实现双向并行通信。
- **服务信息发布**：每个服务在启动时生成唯一的 IPv6 地址和端口，作为 P2PVM 隧道的端点标识。

### 2.2 服务发现与注册

- **TC40_Info**：描述服务的元数据（类型、物理地址、P2PVM 端点、工作负载等）。
- **TC40_InfoList**：维护服务信息列表，支持按类型、负载、地址等条件查询。
- **TC40_Dispatch_Service**：中央调度服务，聚合所有服务信息并广播。
- **TC40_Dispatch_Client**：连接调度服务，同步本地服务信息池。

### 2.3 认证模型

| 模型 | 服务基类 | 客户端基类 | 说明 |
| :--- | :--- | :--- | :--- |
| **NoAuth** | `TC40_Base_NoAuth_Service` | `TC40_Base_NoAuth_Client` | 无认证，适用于内部网络或测试环境。 |
| **VirtualAuth** | `TC40_Base_VirtualAuth_Service` | `TC40_Base_VirtualAuth_Client` | 认证逻辑由应用程序回调实现（`OnUserAuth`/`OnUserReg`）。 |
| **BuiltInAuth** | `TC40_Base_Service` | `TC40_Base_Client` | 内置用户数据库（基于 `THashTextEngine`），提供完整的用户注册/登录。 |
| **DataStore 变体** | `*_DataStore*` | `*_DataStore*` | 在上述模型上增加文件系统和数据库存储能力。 |

### 2.4 依赖描述符

依赖描述符用于声明服务或客户端所依赖的其他服务类型：

```pascal
// 单个依赖
TC40_DependNetworkInfo = record
  Typ: U_String;   // 服务类型标识，如 'DP', 'NA', 'UserDB'
  Param: U_String; // 可选配置参数
end;

// 依赖数组
TC40_DependNetworkInfoArray = array of TC40_DependNetworkInfo;

// 字符串表达：'DP|<>UserDB@SafeCheckTime=10000'
// 解析为两个依赖：'DP' 和 'UserDB'，后者带参数 'SafeCheckTime=10000'
```

---

## 3. 物理层服务与隧道

### 3.1 TC40_PhysicsService

服务端物理端点管理器，负责监听入站连接并构建依赖服务。

#### 3.1.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FActivted` | `Boolean` | 服务是否处于活动监听状态。 |
| `FLastDeadConnectionCheckTime_` | `TTimeTick` | 上次死连接检查的时间戳。 |

#### 3.1.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `ListeningAddr` | `U_String` | 读写 | 监听绑定的 IP 地址。 |
| `PhysicsAddr` | `U_String` | 读写 | 对外公布的物理地址。 |
| `PhysicsPort` | `Word` | 读写 | 监听端口。 |
| `PhysicsTunnel` | `TZNet_Server` | 读写 | 底层网络服务器实例。 |
| `AutoFreePhysicsTunnel` | `Boolean` | 读写 | 析构时是否自动释放 `PhysicsTunnel`。 |
| `DependNetworkServicePool` | `TC40_Custom_ServicePool` | 只读 | 已构建的依赖服务池。 |
| `OnEvent` | `IC40_PhysicsService_Event` | 读写 | 生命周期事件接口。 |
| `Activted` | `Boolean` | 只读 | 服务是否处于活动状态。 |

#### 3.1.3 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create(ListeningAddr_, PhysicsAddr_: U_String; PhysicsPort_: Word; PhysicsTunnel_: TZNet_Server); overload;` | 完整配置构造，允许监听地址和公布地址不同。 |
| `constructor Create(PhysicsAddr_: U_String; PhysicsPort_: Word; PhysicsTunnel_: TZNet_Server); overload;` | 简化构造，监听地址与公布地址相同。 |

#### 3.1.4 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Destroy` | `destructor Destroy; override;` | 析构，停止服务并释放资源。 |
| `Progress` | `procedure Progress; virtual;` | 主进度方法，处理网络事件和健康检查。 |
| `IPC_Mode` | `function IPC_Mode: Boolean;` | 返回是否处于 IPC（进程间通信）模式。 |
| `BuildDependNetwork` | `function BuildDependNetwork(const Depend_: TC40_DependNetworkInfoArray): Boolean; overload; virtual;` | 从依赖信息数组构建依赖服务。 |
| `BuildDependNetwork` | `function BuildDependNetwork(const Depend_: TC40_DependNetworkString): Boolean; overload;` | 从字符串数组构建依赖服务。 |
| `BuildDependNetwork` | `function BuildDependNetwork(const Depend_: U_String): Boolean; overload;` | 从管道分隔字符串构建依赖服务。 |
| `StartService` | `procedure StartService; virtual;` | 启动物理服务监听。 |
| `StopService` | `procedure StopService; virtual;` | 停止物理服务。 |
| `DoLinkSuccess` | `procedure DoLinkSuccess(Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);` | 触发连接成功事件。 |
| `DoUserOut` | `procedure DoUserOut(Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);` | 触发用户断开事件。 |

#### 3.1.5 内部命令

| 命令名 | 处理器 | 说明 |
| :--- | :--- | :--- |
| `QueryInfo` | `cmd_QueryInfo` | 处理服务信息查询请求。 |

---

### 3.2 TC40_PhysicsServicePool

物理服务池，管理多个 `TC40_PhysicsService` 实例。

#### 3.2.1 继承

`TGenericsList<TC40_PhysicsService>`

#### 3.2.2 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Progress` | `procedure Progress;` | 调用池中所有服务的 `Progress` 方法。 |
| `Enabled_Progress` | `procedure Enabled_Progress;` | 启用池中所有服务的进度处理。 |
| `Disable_Progress` | `procedure Disable_Progress;` | 禁用池中所有服务的进度处理。 |
| `ExistsPhysicsAddr` | `function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;` | 检查是否存在指定地址/端口的物理服务。 |
| `GetRS` | `procedure GetRS(var recv, send: Int64);` | 聚合所有物理服务的收发统计字节数。 |

---

### 3.3 TC40_PhysicsTunnel

客户端物理隧道管理器，负责连接远程物理服务并构建依赖客户端。

#### 3.3.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FLast_Delay_Connecting_Time` | `TTimeTick` | 上次延迟连接触发时间。 |
| `FIsConnecting` | `Boolean` | 是否正在连接中。 |
| `FWait_Build_Depend_Network` | `Boolean` | 是否等待构建依赖网络。 |
| `FNetwork_Already_Inited` | `Boolean` | 网络是否已完全初始化。 |
| `FOfflineTime` | `TTimeTick` | 离线时间戳。 |

#### 3.3.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `PhysicsAddr` | `U_String` | 只读 | 远程物理地址。 |
| `PhysicsPort` | `Word` | 只读 | 远程物理端口。 |
| `PhysicsTunnel` | `TZNet_Client` | 只读 | 底层网络客户端实例。 |
| `DependNetworkInfoArray` | `TC40_DependNetworkInfoArray` | 只读 | 依赖信息数组。 |
| `DependNetworkClientPool` | `TC40_Custom_ClientPool` | 只读 | 依赖客户端池。 |
| `OnEvent` | `IC40_PhysicsTunnel_Event` | 读写 | 生命周期事件接口。 |

#### 3.3.3 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create(Addr_: U_String; Port_: Word);` | 使用远程地址和端口创建隧道。 |

#### 3.3.4 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Destroy` | `destructor Destroy; override;` | 析构，断开连接并释放资源。 |
| `Progress` | `procedure Progress; virtual;` | 主进度方法，处理连接管理和重连。 |
| `IPC_Mode` | `function IPC_Mode: Boolean;` | 返回是否处于 IPC 模式。 |
| `IsLocalNetwork` | `function IsLocalNetwork: Boolean;` | 返回目标地址是否为本地网络地址。 |
| `ResetDepend` | `function ResetDepend(const Depend_: TC40_DependNetworkInfoArray): Boolean; overload;` | 重置依赖数组。 |
| `ResetDepend` | `function ResetDepend(const Depend_: TC40_DependNetworkString): Boolean; overload;` | 从字符串数组重置依赖。 |
| `ResetDepend` | `function ResetDepend(const Depend_: U_String): Boolean; overload;` | 从管道分隔字符串重置依赖。 |
| `CheckDepend` | `function CheckDepend(): Boolean; overload;` | 同步检查依赖是否可用。 |
| `CheckDependC` | `function CheckDependC(OnResult: TOnState_C): Boolean;` | 异步检查依赖（C 风格回调）。 |
| `CheckDependM` | `function CheckDependM(OnResult: TOnState_M): Boolean;` | 异步检查依赖（方法回调）。 |
| `CheckDependP` | `function CheckDependP(OnResult: TOnState_P): Boolean;` | 异步检查依赖（嵌套回调）。 |
| `BuildDependNetwork` | `function BuildDependNetwork(): Boolean; overload;` | 同步构建依赖网络。 |
| `BuildDependNetworkC` | `function BuildDependNetworkC(OnResult: TOnState_C): Boolean;` | 异步构建（C 风格）。 |
| `BuildDependNetworkM` | `function BuildDependNetworkM(OnResult: TOnState_M): Boolean;` | 异步构建（方法风格）。 |
| `BuildDependNetworkP` | `function BuildDependNetworkP(OnResult: TOnState_P): Boolean;` | 异步构建（嵌套风格）。 |
| `QueryInfoC` | `procedure QueryInfoC(OnResult: TDCT40_OnQueryResultC);` | 异步查询服务信息（C 风格）。 |
| `QueryInfoM` | `procedure QueryInfoM(OnResult: TDCT40_OnQueryResultM);` | 异步查询服务信息（方法风格）。 |
| `QueryInfoP` | `procedure QueryInfoP(OnResult: TDCT40_OnQueryResultP);` | 异步查询服务信息（嵌套风格）。 |
| `DependNetworkIsConnected` | `function DependNetworkIsConnected: Boolean;` | 检查所有依赖客户端是否已连接。 |
| `DoNetworkOnline` | `procedure DoNetworkOnline(Custom_Client_: TC40_Custom_Client);` | 触发依赖客户端上线事件。 |

#### 3.3.5 内部回调

| 方法名 | 说明 |
| :--- | :--- |
| `ClientConnected` | 物理客户端连接成功回调。 |
| `ClientDisconnect` | 物理客户端断开回调。 |

---

### 3.4 TC40_PhysicsTunnelPool

物理隧道池，管理多个 `TC40_PhysicsTunnel` 实例，支持自动重试和故障修复。

#### 3.4.1 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Auto_Repair_First_BuildDependNetwork_Fault` | `Boolean` | 读写 | 是否自动修复首次构建依赖网络故障。 |

#### 3.4.2 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create;` | 构造，根据编译开关初始化自动修复标志。 |
| `GetRS` | `procedure GetRS(var recv, send: Int64);` | 聚合所有物理隧道的收发统计。 |
| `ExistsPhysicsAddr` | `function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;` | 检查是否存在指定地址/端口的物理隧道。 |
| `GetPhysicsTunnel` | `function GetPhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word): TC40_PhysicsTunnel;` | 获取指定地址/端口的物理隧道。 |
| `GetOrCreatePhysicsTunnel` | `function GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word): TC40_PhysicsTunnel; overload;` | 获取或创建物理隧道。 |
| `GetOrCreatePhysicsTunnel` | `function GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word; const Depend_: TC40_DependNetworkInfoArray; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;` | 获取或创建带依赖和事件的物理隧道。 |
| `GetOrCreatePhysicsTunnel` | `function GetOrCreatePhysicsTunnel(PhysicsAddr: U_String; PhysicsPort: Word; const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;` | 获取或创建带字符串依赖和事件的物理隧道。 |
| `GetOrCreatePhysicsTunnel` | `function GetOrCreatePhysicsTunnel(dispInfo: TC40_Info): TC40_PhysicsTunnel; overload;` | 从服务信息获取或创建物理隧道。 |
| `GetOrCreatePhysicsTunnel` | `function GetOrCreatePhysicsTunnel(dispInfo: TC40_Info; const Depend_: TC40_DependNetworkInfoArray; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;` | 从服务信息+依赖获取或创建。 |
| `GetOrCreatePhysicsTunnel` | `function GetOrCreatePhysicsTunnel(dispInfo: TC40_Info; const Depend_: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TC40_PhysicsTunnel; overload;` | 从服务信息+字符串依赖获取或创建。 |
| `Progress` | `procedure Progress;` | 驱动池中所有隧道进度。 |
| `Enabled_Progress` | `procedure Enabled_Progress;` | 启用所有隧道的进度处理。 |
| `Disable_Progress` | `procedure Disable_Progress;` | 禁用所有隧道的进度处理。 |
| `SearchServiceAndBuildConnection` | `function SearchServiceAndBuildConnection(PhysicsAddr: U_String; PhysicsPort: Word; FullConnection_: Boolean; const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge; overload;` | 搜索服务并构建连接（指定是否全连接）。 |
| `SearchServiceAndBuildConnection` | `function SearchServiceAndBuildConnection(PhysicsAddr: U_String; PhysicsPort: Word; const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge; overload;` | 搜索服务并构建全连接（包装）。 |
| `SearchServiceAndOptimizeConnection` | `function SearchServiceAndOptimizeConnection(PhysicsAddr: U_String; PhysicsPort: Word; const ServiceTyp: U_String; const OnEvent_: IC40_PhysicsTunnel_Event): TSearchServiceAndBuildConnection_Bridge; overload;` | 搜索服务并优化连接（最小负载）。 |

---

### 3.5 TC40_First_BuildDependNetwork_Fault_Fixed_Bridge

首次构建依赖网络故障修复桥接器，实现自动重试机制。

#### 3.5.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Fault_Fixed_Bridge_Begin_Time` | `TTimeTick` | 重试过程开始时间。 |
| `Tunnel` | `TC40_PhysicsTunnel` | 关联的物理隧道。 |

#### 3.5.2 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create(Tunnel_: TC40_PhysicsTunnel);` | 创建关联指定隧道的修复桥接器。 |

#### 3.5.3 方法

| 方法名 | 说明 |
| :--- | :--- |
| `Do_Delay_Next_BuildDependNetwork` | 调度下一次重试尝试。 |
| `Do_First_BuildDependNetwork(const state: Boolean);` | 构建依赖网络尝试的回调。 |

---

## 4. 服务信息与发现

### 4.1 TC40_Info

服务描述符，包含服务实例的所有元数据。

#### 4.1.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Ignored` | `Boolean` | 是否在查询中被忽略。 |

#### 4.1.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `OnlyInstance` | `Boolean` | 读写 | 是否只允许单一实例。 |
| `ServiceTyp` | `U_String` | 读写 | 服务类型标识符（如 'DP', 'NA'）。 |
| `PhysicsAddr` | `U_String` | 读写 | 服务所在物理地址。 |
| `PhysicsPort` | `Word` | 读写 | 服务所在物理端口。 |
| `p2pVM_RecvTunnel_Addr` | `U_String` | 读写 | P2PVM 接收隧道 IPv6 地址（服务端视角）。 |
| `p2pVM_RecvTunnel_Port` | `Word` | 读写 | P2PVM 接收隧道端口。 |
| `p2pVM_SendTunnel_Addr` | `U_String` | 读写 | P2PVM 发送隧道 IPv6 地址（服务端视角）。 |
| `p2pVM_SendTunnel_Port` | `Word` | 读写 | P2PVM 发送隧道端口。 |
| `Workload` | `Integer` | 读写 | 当前工作负载（如连接用户数）。 |
| `MaxWorkload` | `Integer` | 读写 | 最大工作负载容量。 |
| `Hash` | `TMD5` | 只读 | 服务实例的唯一 MD5 哈希。 |
| `p2pVM_ClientRecvTunnel_Addr` | `U_String` | 只读 | 客户端视角的接收隧道地址（映射自 `p2pVM_SendTunnel_Addr`）。 |
| `p2pVM_ClientRecvTunnel_Port` | `Word` | 只读 | 客户端视角的接收隧道端口。 |
| `p2pVM_ClientSendTunnel_Addr` | `U_String` | 只读 | 客户端视角的发送隧道地址（映射自 `p2pVM_RecvTunnel_Addr`）。 |
| `p2pVM_ClientSendTunnel_Port` | `Word` | 只读 | 客户端视角的发送隧道端口。 |

#### 4.1.3 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create;` | 构造，初始化所有字段为默认值。 |
| `Destroy` | `destructor Destroy; override;` | 析构，释放字符串资源。 |
| `Assign` | `procedure Assign(source: TC40_Info);` | 从源实例复制所有字段。 |
| `Clone` | `function Clone: TC40_Info;` | 创建完整副本。 |
| `Load` | `procedure Load(stream: TCore_Stream);` | 从流中加载服务信息。 |
| `Save` | `procedure Save(stream: TCore_Stream);` | 将服务信息保存到流。 |
| `Same` | `function Same(Data_: TC40_Info): Boolean;` | 检查与另一个信息是否完全相同。 |
| `SameServiceTyp` | `function SameServiceTyp(Data_: TC40_Info): Boolean;` | 检查服务类型是否相同。 |
| `SamePhysicsAddr` | `function SamePhysicsAddr(PhysicsAddr_: U_String): Boolean; overload;` | 检查物理地址是否匹配。 |
| `SamePhysicsAddr` | `function SamePhysicsAddr(Arry_: TArrayPascalString): Boolean; overload;` | 检查物理地址是否匹配数组中的任一地址。 |
| `SamePhysicsAddr` | `function SamePhysicsAddr(PhysicsAddr_: U_String; PhysicsPort_: Word): Boolean; overload;` | 检查物理地址和端口是否匹配。 |
| `SamePhysicsAddr` | `function SamePhysicsAddr(Data_: TC40_Info): Boolean; overload;` | 检查物理地址是否与另一个信息相同。 |
| `SamePhysicsAddr` | `function SamePhysicsAddr(Data_: TC40_PhysicsTunnel): Boolean; overload;` | 检查物理地址是否与物理隧道相同。 |
| `SamePhysicsAddr` | `function SamePhysicsAddr(Data_: TC40_PhysicsService): Boolean; overload;` | 检查物理地址是否与物理服务相同。 |
| `SameP2PVMAddr` | `function SameP2PVMAddr(Data_: TC40_Info): Boolean;` | 检查 P2PVM 地址是否相同。 |
| `FoundServiceTyp` | `function FoundServiceTyp(Arry_: TC40_DependNetworkInfoArray): Boolean; overload;` | 检查服务类型是否匹配依赖数组中的任一类型。 |
| `FoundServiceTyp` | `function FoundServiceTyp(servTyp_: U_String): Boolean; overload;` | 检查服务类型是否匹配依赖字符串。 |
| `ReadyC40Client` | `function ReadyC40Client: Boolean;` | 检查该服务类型是否已注册客户端类。 |
| `GetOrCreateC40Client` | `function GetOrCreateC40Client(PhysicsTunnel_: TC40_PhysicsTunnel; Param_: U_String): TC40_Custom_Client;` | 获取或创建对应的 C4 客户端实例。 |

---

### 4.2 TC40_InfoList

服务信息列表容器，支持自动释放和丰富的查询功能。

#### 4.2.1 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `AutoFree` | `Boolean` | 读写 | 移除时是否自动释放对象。 |

#### 4.2.2 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create(AutoFree_: Boolean);` | 创建信息列表，指定是否自动释放。 |

#### 4.2.3 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Destroy` | `destructor Destroy; override;` | 析构，释放所有信息对象。 |
| `Remove` | `procedure Remove(obj: TC40_Info);` | 移除信息，若 `AutoFree` 则释放。 |
| `Delete` | `procedure Delete(index: Integer);` | 删除指定索引的信息。 |
| `Clear` | `procedure Clear;` | 清空列表，释放所有信息。 |
| `SortWorkLoad` | `class procedure SortWorkLoad(L_: TC40_InfoList);` | 按工作负载比率升序排序。 |
| `GetInfoArray` | `function GetInfoArray: TC40_Info_Array;` | 返回动态数组形式的列表。 |
| `IsOnlyInstance` | `function IsOnlyInstance(ServiceTyp: U_String): Boolean;` | 检查服务类型是否标记为"唯一实例"。 |
| `GetServiceTypNum` | `function GetServiceTypNum(ServiceTyp: U_String): Integer;` | 返回指定服务类型的实例数量。 |
| `SearchMinWorkload` | `function SearchMinWorkload(arry: TC40_DependNetworkInfoArray): TC40_Info_Array; overload;` | 搜索匹配依赖且负载最小的服务。 |
| `SearchMinWorkload` | `function SearchMinWorkload(ServiceTyp: U_String): TC40_Info_Array; overload;` | 搜索指定类型且负载最小的服务。 |
| `SearchService` | `function SearchService(arry: TC40_DependNetworkInfoArray; full_: Boolean): TC40_Info_Array; overload;` | 搜索匹配依赖的服务（可指定返回全部）。 |
| `SearchService` | `function SearchService(arry: TC40_DependNetworkInfoArray): TC40_Info_Array; overload;` | 搜索匹配依赖的服务（返回全部）。 |
| `SearchService` | `function SearchService(ServiceTyp: U_String): TC40_Info_Array; overload;` | 搜索指定类型的服务。 |
| `ExistsService` | `function ExistsService(arry: TC40_DependNetworkInfoArray): Boolean; overload;` | 检查是否存在匹配依赖的服务。 |
| `ExistsService` | `function ExistsService(ServiceTyp: U_String): Boolean; overload;` | 检查是否存在指定类型的服务。 |
| `FindSame` | `function FindSame(Data_: TC40_Info): TC40_Info;` | 查找与指定信息相同的实例。 |
| `FindHash` | `function FindHash(Hash: TMD5): TC40_Info;` | 通过 MD5 哈希查找服务。 |
| `ExistsPhysicsAddr` | `function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;` | 检查是否存在指定物理地址/端口的服务。 |
| `RemovePhysicsAddr` | `procedure RemovePhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word);` | 移除指定物理地址/端口的所有服务信息。 |
| `OverwriteInfo` | `function OverwriteInfo(Data_: TC40_Info): Boolean;` | 覆盖或添加服务信息。 |
| `MergeAndUpdateWorkload` | `function MergeAndUpdateWorkload(source: TC40_InfoList): Boolean;` | 合并另一个列表并更新工作负载信息。 |
| `MergeFromDF` | `function MergeFromDF(D: TDFE): Boolean;` | 从 DFE 流合并服务信息。 |
| `SaveToDF` | `procedure SaveToDF(D: TDFE);` | 将服务信息保存到 DFE 流。 |

---

## 5. 自定义服务基类

### 5.1 TC40_Custom_Service

所有 C4 自定义服务的基类，提供生命周期管理、配置、P2PVM 集成和控制台命令注册。

#### 5.1.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FLastSafeCheckTime` | `TTimeTick` | 上次安全检查时间。 |

#### 5.1.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Param` | `U_String` | 只读 | 参数字符串。 |
| `Param_File` | `U_String` | 只读 | 配置文件路径。 |
| `ParamList` | `THashStringList` | 只读 | 解析后的参数键值对。 |
| `SafeCheckTime` | `TTimeTick` | 只读 | 安全检查间隔。 |
| `Alias_or_Hash___` | `U_String` | 读写 | 用户友好的别名或哈希字符串。 |
| `enablePerServiceDirectory` | `Boolean` | 只读 | 是否启用每个服务的子目录。 |
| `Tag` | `Integer` | 读写 | 用户标签。 |
| `ServiceInfo` | `TC40_Info` | 只读 | 服务描述符。 |
| `C40PhysicsService` | `TC40_PhysicsService` | 只读 | 父物理服务。 |
| `ConsoleCommand` | `TC4_Help_Console_Command` | 只读 | 控制台命令注册表。 |
| `PhysicsService` | `TC40_PhysicsService` | 只读 | `C40PhysicsService` 的别名。 |
| `Hash` | `TMD5` | 只读 | 服务信息的 MD5 哈希。 |
| `AliasOrHash` | `U_String` | 读写 | 别名或哈希字符串（读写属性）。 |

#### 5.1.3 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); virtual;` | 创建服务实例，解析参数，生成 P2PVM 端点信息。 |

#### 5.1.4 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Destroy` | `destructor Destroy; override;` | 析构，释放资源并从池中移除。 |
| `SafeCheck` | `procedure SafeCheck; virtual;` | 周期性安全检查，子类可重写。 |
| `Progress` | `procedure Progress; virtual;` | 主进度方法，触发 `SafeCheck`。 |
| `SetWorkload` | `procedure SetWorkload(Workload_, MaxWorkload_: Integer);` | 设置当前工作负载和最大负载。 |
| `UpdateToGlobalDispatch` | `procedure UpdateToGlobalDispatch;` | 将服务信息更新到所有全局调度服务。 |
| `GetHash` | `function GetHash: TMD5;` | 获取服务信息的 MD5。 |
| `GetAliasOrHash` | `function GetAliasOrHash: U_String;` | 获取别名或哈希字符串。 |
| `Get_P2PVM_Service` | `function Get_P2PVM_Service(var recv_, send_: TZNet_WithP2PVM_Server): Boolean;` | 获取 P2PVM 服务端点。 |
| `Get_DB_FileName_Config` | `function Get_DB_FileName_Config(source_: U_String): U_String;` | 从参数列表获取配置文件名称。 |
| `Where_C4_File` | `function Where_C4_File(fileName, ServiceTyp: U_String): U_String; overload;` | 在 C4 根路径中查找配置文件。 |
| `Where_C4_File` | `function Where_C4_File(fileName: U_String): U_String; overload;` | 使用服务类型在 C4 根路径中查找配置文件。 |
| `Register_ConsoleCommand` | `function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;` | 注册控制台命令。 |
| `DoLinkSuccess` | `procedure DoLinkSuccess(Trigger_: TCore_Object);` | 触发连接成功事件。 |
| `DoUserOut` | `procedure DoUserOut(Trigger_: TCore_Object);` | 触发用户断开事件。 |

---

### 5.2 TC40_Custom_ServicePool

自定义服务池，管理多个服务实例，支持按类型、地址、类等条件查询。

#### 5.2.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FIPV6_Seed` | `Word` | IPv6 地址生成种子，每次分配递增。 |

#### 5.2.2 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create;` | 构造，初始化 IPv6 种子为 1。 |
| `Progress` | `procedure Progress;` | 驱动池中所有服务的进度。 |
| `SortWorkLoad` | `class procedure SortWorkLoad(L_: TC40_Custom_ServicePool);` | 按工作负载比率排序。 |
| `MakeP2PVM_IPv6_Port` | `procedure MakeP2PVM_IPv6_Port(var ip6, port: U_String);` | 生成新的 IPv6 地址和端口对。 |
| `FindHash` | `function FindHash(hash_: TMD5): TC40_Custom_Service;` | 通过哈希查找服务。 |
| `FindAliasOrHash` | `function FindAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Service;` | 通过别名或哈希查找服务。 |
| `MakeAlias` | `function MakeAlias(preset_: U_String): U_String;` | 从预设生成唯一别名。 |
| `GetServiceFromHash` | `function GetServiceFromHash(Hash: TMD5): TC40_Custom_Service;` | 通过哈希获取服务（`FindHash` 别名）。 |
| `GetServiceFromAliasOrHash` | `function GetServiceFromAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Service;` | 通过别名或哈希获取服务。 |
| `ExistsPhysicsAddr` | `function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;` | 检查是否存在指定物理地址的服务。 |
| `ExistsOnlyInstance` | `function ExistsOnlyInstance(ServiceTyp: U_String): Boolean;` | 检查服务类型是否配置为"唯一实例"。 |
| `FindTag` | `function FindTag(Tag: Integer): TC40_Custom_Service;` | 通过标签获取服务。 |
| `GetC40Array` | `function GetC40Array(is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload;` | 返回服务数组（可过滤 IPC 模式）。 |
| `GetC40Array` | `function GetC40Array: TC40_Custom_Service_Array; overload;` | 返回所有服务数组。 |
| `GetFromServiceTyp` | `function GetFromServiceTyp(ServiceTyp: U_String; is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload;` | 按服务类型获取服务（可过滤 IPC）。 |
| `GetFromServiceTyp` | `function GetFromServiceTyp(ServiceTyp: U_String): TC40_Custom_Service_Array; overload;` | 按服务类型获取服务。 |
| `GetFromPhysicsAddr` | `function GetFromPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word; is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload;` | 按物理地址获取服务（可过滤 IPC）。 |
| `GetFromPhysicsAddr` | `function GetFromPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): TC40_Custom_Service_Array; overload;` | 按物理地址获取服务。 |
| `GetFromClass` | `function GetFromClass(Class_: TC40_Custom_Service_Class; is_ipc_mode: Boolean): TC40_Custom_Service_Array; overload;` | 按类获取服务（可过滤 IPC）。 |
| `GetFromClass` | `function GetFromClass(Class_: TC40_Custom_Service_Class): TC40_Custom_Service_Array; overload;` | 按类获取服务。 |

---

### 5.3 TC40_Custom_Client

所有 C4 自定义客户端的基类，提供连接管理、配置、P2PVM 集成和控制台命令注册。

#### 5.3.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FLastSafeCheckTime` | `TTimeTick` | 上次安全检查时间。 |

#### 5.3.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Param` | `U_String` | 只读 | 参数字符串。 |
| `Param_File` | `U_String` | 只读 | 配置文件路径。 |
| `ParamList` | `THashStringList` | 只读 | 解析后的参数键值对。 |
| `SafeCheckTime` | `TTimeTick` | 只读 | 安全检查间隔。 |
| `Alias_or_Hash___` | `U_String` | 读写 | 用户友好的别名或哈希字符串。 |
| `Tag` | `Integer` | 读写 | 用户标签。 |
| `ClientInfo` | `TC40_Info` | 只读 | 客户端服务描述符。 |
| `C40PhysicsTunnel` | `TC40_PhysicsTunnel` | 只读 | 父物理隧道。 |
| `ConsoleCommand` | `TC4_Help_Console_Command` | 只读 | 控制台命令注册表。 |
| `On_Client_Offline` | `TOn_Client_Offline` | 读写 | 离线回调。 |
| `PhysicsTunnel` | `TC40_PhysicsTunnel` | 只读 | `C40PhysicsTunnel` 的别名。 |
| `Hash` | `TMD5` | 只读 | 客户端信息的 MD5 哈希。 |
| `AliasOrHash` | `U_String` | 读写 | 别名或哈希字符串（读写属性）。 |

#### 5.3.3 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); virtual;` | 创建客户端实例，解析参数，关联物理隧道。 |

#### 5.3.4 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Destroy` | `destructor Destroy; override;` | 析构，释放资源并从池中移除。 |
| `SafeCheck` | `procedure SafeCheck; virtual;` | 周期性安全检查，子类可重写。 |
| `Progress` | `procedure Progress; virtual;` | 主进度方法，触发 `SafeCheck`。 |
| `Connect` | `procedure Connect; virtual;` | 发起连接，子类可重写。 |
| `Connected` | `function Connected: Boolean; virtual;` | 返回是否已连接。 |
| `Disconnect` | `procedure Disconnect; virtual;` | 断开连接。 |
| `GetHash` | `function GetHash: TMD5;` | 获取客户端信息的 MD5。 |
| `GetAliasOrHash` | `function GetAliasOrHash: U_String;` | 获取别名或哈希字符串。 |
| `Get_P2PVM_Tunnel` | `function Get_P2PVM_Tunnel(var recv_, send_: TZNet_WithP2PVM_Client): Boolean;` | 获取 P2PVM 隧道端点。 |
| `Get_DB_FileName_Config` | `function Get_DB_FileName_Config(source_: U_String): U_String;` | 从参数列表获取配置文件名称。 |
| `Where_C4_File` | `function Where_C4_File(fileName: U_String): U_String;` | 在 C4 根路径中查找配置文件。 |
| `Register_ConsoleCommand` | `function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;` | 注册控制台命令。 |
| `DoNetworkOnline` | `procedure DoNetworkOnline; virtual;` | 连接成功时调用。 |
| `DoNetworkOffline` | `procedure DoNetworkOffline; virtual;` | 断开连接时调用。 |

---

### 5.4 TC40_Custom_ClientPool

自定义客户端池，管理多个客户端实例，支持按哈希、别名、类型、类等条件查询。

#### 5.4.1 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Progress` | `procedure Progress;` | 驱动池中所有客户端的进度。 |
| `SortWorkLoad` | `class procedure SortWorkLoad(L_: TC40_Custom_ClientPool);` | 按工作负载比率排序。 |
| `FindHash` | `function FindHash(hash_: TMD5; isConnected: Boolean): TC40_Custom_Client; overload;` | 通过哈希查找客户端（可过滤连接状态）。 |
| `FindHash` | `function FindHash(hash_: TMD5): TC40_Custom_Client; overload;` | 通过哈希查找客户端。 |
| `FindAliasOrHash` | `function FindAliasOrHash(AliasOrhash_: U_String; isConnected: Boolean): TC40_Custom_Client; overload;` | 通过别名或哈希查找（可过滤连接状态）。 |
| `FindAliasOrHash` | `function FindAliasOrHash(AliasOrhash_: U_String): TC40_Custom_Client; overload;` | 通过别名或哈希查找。 |
| `MakeAlias` | `function MakeAlias(preset_: U_String): U_String;` | 从预设生成唯一别名。 |
| `ExistsPhysicsAddr` | `function ExistsPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;` | 检查是否存在指定物理地址的客户端。 |
| `ExistsServiceInfo` | `function ExistsServiceInfo(info_: TC40_Info): Boolean;` | 检查是否存在匹配服务信息的客户端。 |
| `ExistsServiceTyp` | `function ExistsServiceTyp(ServiceTyp: U_String): Boolean;` | 检查是否存在指定服务类型的客户端。 |
| `ExistsClass` | `function ExistsClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;` | 查找指定类的客户端。 |
| `ExistsConnectedClass` | `function ExistsConnectedClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;` | 查找指定类且已连接的客户端。 |
| `ExistsConnectedServiceTyp` | `function ExistsConnectedServiceTyp(ServiceTyp: U_String): TC40_Custom_Client;` | 查找指定类型且已连接的客户端。 |
| `ExistsConnectedServiceTypAndClass` | `function ExistsConnectedServiceTypAndClass(ServiceTyp: U_String; Class_: TC40_Custom_Client_Class): TC40_Custom_Client;` | 查找指定类型和类且已连接的客户端。 |
| `FindPhysicsAddr` | `function FindPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;` | `ExistsPhysicsAddr` 的旧别名。 |
| `FindServiceInfo` | `function FindServiceInfo(info_: TC40_Info): Boolean;` | `ExistsServiceInfo` 的旧别名。 |
| `FindServiceTyp` | `function FindServiceTyp(ServiceTyp: U_String): Boolean;` | `ExistsServiceTyp` 的旧别名。 |
| `FindTag` | `function FindTag(Tag: Integer): TC40_Custom_Client;` | 通过标签获取客户端。 |
| `FindClass` | `function FindClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;` | `ExistsClass` 的旧别名。 |
| `FindConnectedClass` | `function FindConnectedClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client;` | `ExistsConnectedClass` 的旧别名。 |
| `FindConnectedServiceTyp` | `function FindConnectedServiceTyp(ServiceTyp: U_String): TC40_Custom_Client;` | `ExistsConnectedServiceTyp` 的旧别名。 |
| `FindConnectedServiceTypAndClass` | `function FindConnectedServiceTypAndClass(ServiceTyp: U_String; Class_: TC40_Custom_Client_Class): TC40_Custom_Client;` | `ExistsConnectedServiceTypAndClass` 的旧别名。 |
| `GetClientFromHash` | `function GetClientFromHash(Hash: TMD5): TC40_Custom_Client;` | 通过哈希获取客户端。 |
| `GetC40Array` | `function GetC40Array(is_ipc_mode: Boolean): TC40_Custom_Client_Array; overload;` | 返回客户端数组（可过滤 IPC 模式）。 |
| `GetC40Array` | `function GetC40Array: TC40_Custom_Client_Array; overload;` | 返回所有客户端数组。 |
| `SearchServiceTyp` | `function SearchServiceTyp(ServiceTyp: U_String; isConnected: Boolean): TC40_Custom_Client_Array; overload;` | 按服务类型搜索客户端（可过滤连接状态）。 |
| `SearchServiceTyp` | `function SearchServiceTyp(ServiceTyp: U_String): TC40_Custom_Client_Array; overload;` | 按服务类型搜索客户端。 |
| `SearchPhysicsAddr` | `function SearchPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word; isConnected: Boolean): TC40_Custom_Client_Array; overload;` | 按物理地址搜索客户端（可过滤连接状态）。 |
| `SearchPhysicsAddr` | `function SearchPhysicsAddr(PhysicsAddr: U_String; PhysicsPort: Word): TC40_Custom_Client_Array; overload;` | 按物理地址搜索客户端。 |
| `SearchClass` | `function SearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode, is_local_network: Boolean): TC40_Custom_Client_Array; overload;` | 按类搜索客户端（可过滤连接/IPC/本地网络）。 |
| `SearchClass` | `function SearchClass(Class_: TC40_Custom_Client_Class; isConnected, is_ipc_mode: Boolean): TC40_Custom_Client_Array; overload;` | 按类搜索客户端（可过滤连接/IPC）。 |
| `SearchClass` | `function SearchClass(Class_: TC40_Custom_Client_Class; isConnected: Boolean): TC40_Custom_Client_Array; overload;` | 按类搜索客户端（可过滤连接状态）。 |
| `SearchClass` | `function SearchClass(Class_: TC40_Custom_Client_Class): TC40_Custom_Client_Array; overload;` | 按类搜索客户端。 |
| `WaitConnectedDoneC` | `procedure WaitConnectedDoneC(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventC);` | 等待依赖服务连接完成（C 风格）。 |
| `WaitConnectedDoneM` | `procedure WaitConnectedDoneM(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventM);` | 等待依赖服务连接完成（方法风格）。 |
| `WaitConnectedDoneP` | `procedure WaitConnectedDoneP(dependNetwork_: U_String; OnResult: TOn_C40_Custom_Client_EventP);` | 等待依赖服务连接完成（嵌套风格）。 |

---

### 5.5 TC40_Custom_ClientPool_Wait

等待客户端连接完成的内部辅助类。

#### 5.5.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `States_` | `TC40_Custom_ClientPool_Wait_States` | 等待的服务状态列表。 |
| `Pool_` | `TC40_Custom_ClientPool` | 要监控的池。 |
| `On_C` | `TOn_C40_Custom_Client_EventC` | C 风格完成回调。 |
| `On_M` | `TOn_C40_Custom_Client_EventM` | 方法风格完成回调。 |
| `On_P` | `TOn_C40_Custom_Client_EventP` | 嵌套风格完成回调。 |

#### 5.5.2 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create(dependNetwork_: U_String);` | 从依赖字符串创建等待状态。 |

#### 5.5.3 方法

| 方法名 | 说明 |
| :--- | :--- |
| `DoRun` | 轮询连接状态，完成时触发回调。 |

---

### 5.6 TSearchServiceAndBuildConnection_Bridge

搜索服务并构建连接的桥接器。

#### 5.6.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `PhysicsPool_` | `TC40_PhysicsTunnelPool` | 物理隧道池。 |
| `FullConnection_` | `Boolean` | 是否连接所有实例。 |
| `ServiceTyp` | `U_String` | 要搜索的服务类型。 |
| `OnEvent_` | `IC40_PhysicsTunnel_Event` | 事件处理器。 |
| `Done_ClientPool` | `TC40_Custom_ClientPool` | 已连接的客户端池。 |
| `TaskNum` | `Integer` | 待完成任务数。 |
| `OnDone_C` | `TOnSearchServiceAndBuildConnection_C` | C 风格完成回调。 |
| `OnDone_M` | `TOnSearchServiceAndBuildConnection_M` | 方法风格完成回调。 |
| `OnDone_P` | `TOnSearchServiceAndBuildConnection_P` | 嵌套风格完成回调。 |

#### 5.6.2 方法

| 方法名 | 说明 |
| :--- | :--- |
| `Do_SearchService_Event` | 处理服务查询结果。 |
| `Do_Done_Client` | 客户端连接完成时调用。 |

---

## 6. 自动部署机制

### 6.1 TC40_Auto_Deployment_Client<T>

泛型自动部署辅助类，等待指定类型的客户端可用并连接。

#### 6.1.1 类型参数

| 参数 | 说明 |
| :--- | :--- |
| `T_` | 客户端类类型，必须继承自 `TC40_Custom_Client`。 |

#### 6.1.2 属性

| 属性名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `On_Ready_C` | `TOn_Ready_C` | C 风格就绪回调。 |
| `On_Ready_M` | `TOn_Ready_M` | 方法风格就绪回调。 |
| `On_Ready_P` | `TOn_Ready_P` | 嵌套风格就绪回调。 |

#### 6.1.3 构造函数

| 原型 | 说明 |
| :--- | :--- |
| `constructor Create_Ptr(dependNetwork_: U_String; Client_: PT_);` | 使用指针和依赖网络创建。 |
| `constructor Create(dependNetwork_: U_String; var Client: T_); overload;` | 使用变量引用和依赖网络创建。 |
| `constructor Create(var Client: T_); overload;` | 自动检测依赖网络。 |
| `constructor Create_C(OnReady: TOn_Ready_C);` | 仅就绪回调（自动检测依赖）。 |
| `constructor Create_M(OnReady: TOn_Ready_M);` | 仅就绪回调（方法风格）。 |
| `constructor Create_P(OnReady: TOn_Ready_P);` | 仅就绪回调（嵌套风格）。 |
| `constructor Create_C2(dependNetwork_: U_String; OnReady: TOn_Ready_C);` | 显式依赖网络 + C 风格回调。 |
| `constructor Create_M2(dependNetwork_: U_String; OnReady: TOn_Ready_M);` | 显式依赖网络 + 方法风格回调。 |
| `constructor Create_P2(dependNetwork_: U_String; OnReady: TOn_Ready_P);` | 显式依赖网络 + 嵌套风格回调。 |

#### 6.1.4 别名

| 别名 | 说明 |
| :--- | :--- |
| `TC40_Auto_Deploy_Client<T_>` | `TC40_Auto_Deployment_Client<T_>` 的别名。 |
| `TC40_Auto_Deploy<T_>` | 同上。 |
| `TC40_Deploy<T_>` | 同上。 |

---

## 7. 调度服务（Dispatch）

### 7.1 TC40_Dispatch_Service

中央调度服务，聚合所有服务信息并广播到连接的客户端。

#### 7.1.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOnServiceInfoChange` | `TOnServiceInfoChange` | 服务信息变更回调。 |
| `FWaiting_UpdateServerInfoToAllClient` | `Boolean` | 是否有待发送的更新。 |
| `FWaiting_UpdateServerInfoToAllClient_TimeTick` | `TTimeTick` | 预定更新时间。 |
| `DelayCheck_Working` | `Boolean` | 延迟检查是否正在运行。 |

#### 7.1.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Service` | `TDT_P2PVM_NoAuth_Custom_Service` | 只读 | 底层 P2PVM 服务。 |
| `Service_Info_Pool` | `TC40_InfoList` | 只读 | 已知服务的完整列表。 |
| `OnServiceInfoChange` | `TOnServiceInfoChange` | 读写 | 服务信息变更事件。 |

#### 7.1.3 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create(PhysicsService_: TC40_PhysicsService; ServiceTyp, Param_: U_String); override;` | 创建调度服务，初始化 P2PVM 服务和信息池。 |
| `Destroy` | `destructor Destroy; override;` | 析构，释放资源。 |
| `Progress` | `procedure Progress; override;` | 驱动进度，处理待发送更新。 |
| `IgnoreChangeToAllClient` | `procedure IgnoreChangeToAllClient(Hash__: TMD5; Ignored: Boolean);` | 向所有客户端发送忽略变更通知。 |
| `UpdateServiceStateToAllClient` | `procedure UpdateServiceStateToAllClient;` | 向所有客户端发送工作负载状态更新。 |

---

### 7.2 TC40_Dispatch_Client

调度客户端，连接调度服务并同步本地服务信息池。

#### 7.2.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOnServiceInfoChange` | `TOnServiceInfoChange` | 服务信息变更回调。 |
| `DelayCheck_Working` | `Boolean` | 延迟检查是否正在运行。 |

#### 7.2.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Client` | `TDT_P2PVM_NoAuth_Custom_Client` | 只读 | 底层 P2PVM 客户端。 |
| `Service_Info_Pool` | `TC40_InfoList` | 只读 | 本地服务信息副本。 |
| `OnServiceInfoChange` | `TOnServiceInfoChange` | 读写 | 服务信息变更事件。 |

#### 7.2.3 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create(PhysicsTunnel_: TC40_PhysicsTunnel; source_: TC40_Info; Param_: U_String); override;` | 创建调度客户端，初始化 P2PVM 客户端和信息池。 |
| `Destroy` | `destructor Destroy; override;` | 析构，释放资源。 |
| `Progress` | `procedure Progress; override;` | 驱动进度，执行延迟检查。 |
| `Connect` | `procedure Connect; override;` | 连接调度服务。 |
| `Connected` | `function Connected: Boolean; override;` | 返回是否已连接。 |
| `Disconnect` | `procedure Disconnect; override;` | 断开连接。 |
| `PostLocalServiceInfo` | `procedure PostLocalServiceInfo(forcePost_: Boolean);` | 向调度服务发布本地服务信息。 |
| `RequestUpdate` | `procedure RequestUpdate();` | 请求完整更新。 |
| `IgnoreChangeToService` | `procedure IgnoreChangeToService(Hash__: TMD5; Ignored: Boolean);` | 发送忽略变更请求。 |
| `UpdateLocalServiceState` | `procedure UpdateLocalServiceState;` | 发布本地工作负载状态。 |
| `RemovePhysicsNetwork` | `procedure RemovePhysicsNetwork(PhysicsAddr: U_String; PhysicsPort: Word);` | 请求移除物理网络。 |

---

## 8. 认证模型实现

### 8.1 NULL 模型

#### 8.1.1 TC40_Base_NULL_Service

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Service` | `TDT_P2PVM_NoAuth_Custom_Service` | 底层 P2PVM 服务。 |
| `DTNoAuthService` | `TDTService_NoAuth` | 无认证双通道服务。 |
| `DTNoAuth` | `TDTService_NoAuth` | `DTNoAuthService` 的属性别名。 |

**方法**：`Create`, `Destroy`, `Progress`。

#### 8.1.2 TC40_Base_NULL_Client

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Client` | `TDT_P2PVM_NoAuth_Custom_Client` | 底层 P2PVM 客户端。 |
| `DTNoAuthClient` | `TDTClient_NoAuth` | 无认证双通道客户端。 |
| `DTNoAuth` | `TDTClient_NoAuth` | `DTNoAuthClient` 的属性别名。 |

**方法**：`Create`, `Destroy`, `Progress`, `Connect`, `Connected`, `Disconnect`。

---

### 8.2 NoAuth 模型

#### 8.2.1 TC40_Base_NoAuth_Service

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Service` | `TDT_P2PVM_NoAuth_Custom_Service` | 底层 P2PVM 服务。 |
| `DTNoAuthService` | `TDTService_NoAuth` | 无认证双通道服务。 |
| `DTNoAuth` | `TDTService_NoAuth` | `DTNoAuthService` 的属性别名。 |

**方法**：`Create`, `Destroy`, `Progress`。

#### 8.2.2 TC40_Base_NoAuth_Client

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Client` | `TDT_P2PVM_NoAuth_Custom_Client` | 底层 P2PVM 客户端。 |
| `DTNoAuthClient` | `TDTClient_NoAuth` | 无认证双通道客户端。 |
| `DTNoAuth` | `TDTClient_NoAuth` | `DTNoAuthClient` 的属性别名。 |

**方法**：`Create`, `Destroy`, `Progress`, `Connect`, `Connected`, `Disconnect`。

---

### 8.3 VirtualAuth 模型

#### 8.3.1 TC40_Base_VirtualAuth_Service

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Service` | `TDT_P2PVM_VirtualAuth_Custom_Service` | 底层 P2PVM 虚拟认证服务。 |
| `DTVirtualAuthService` | `TDTService_VirtualAuth` | 虚拟认证双通道服务。 |
| `DTVirtualAuth` | `TDTService_VirtualAuth` | `DTVirtualAuthService` 的属性别名。 |

**方法**：`Create`, `Destroy`, `Progress`。

**虚方法（可重写）**：
| 方法名 | 说明 |
| :--- | :--- |
| `DoUserReg_Event` | 处理用户注册请求（默认接受）。 |
| `DoUserAuth_Event` | 处理用户认证请求（默认接受）。 |

#### 8.3.2 TC40_Base_VirtualAuth_Client

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Client` | `TDT_P2PVM_VirtualAuth_Custom_Client` | 底层 P2PVM 虚拟认证客户端。 |
| `DTVirtualAuthClient` | `TDTClient_VirtualAuth` | 虚拟认证双通道客户端。 |
| `UserName` | `U_String` | 用户名。 |
| `Password` | `U_String` | 密码。 |
| `NoDTLink` | `Boolean` | 是否跳过双通道链接过程。 |
| `DTVirtualAuth` | `TDTClient_VirtualAuth` | `DTVirtualAuthClient` 的属性别名。 |

**方法**：`Create`, `Destroy`, `Progress`, `Connect`, `Connected`, `Disconnect`, `LoginIsSuccessed`。

---

### 8.4 BuiltInAuth 模型

#### 8.4.1 TC40_Base_Service

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Service` | `TDT_P2PVM_Custom_Service` | 底层 P2PVM 服务（内置认证）。 |
| `DTService` | `TDTService` | 内置认证双通道服务。 |
| `DT` | `TDTService` | `DTService` 的属性别名。 |

**方法**：`Create`, `Destroy`, `SafeCheck`, `Progress`。

#### 8.4.2 TC40_Base_Client

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Client` | `TDT_P2PVM_Custom_Client` | 底层 P2PVM 客户端（内置认证）。 |
| `DTClient` | `TDTClient` | 内置认证双通道客户端。 |
| `UserName` | `U_String` | 用户名。 |
| `Password` | `U_String` | 密码。 |
| `NoDTLink` | `Boolean` | 是否跳过双通道链接过程。 |
| `DT` | `TDTClient` | `DTClient` 的属性别名。 |

**方法**：`Create`, `Destroy`, `Progress`, `Connect`, `Connected`, `Disconnect`, `LoginIsSuccessed`。

---

### 8.5 DataStore 变体

每个认证模型都有对应的 DataStore 变体，增加了文件系统和数据库存储能力：

| 模型 | 服务基类 | 客户端基类 |
| :--- | :--- | :--- |
| NoAuth + DataStore | `TC40_Base_DataStoreNoAuth_Service` | `TC40_Base_DataStoreNoAuth_Client` |
| VirtualAuth + DataStore | `TC40_Base_DataStoreVirtualAuth_Service` | `TC40_Base_DataStoreVirtualAuth_Client` |
| BuiltInAuth + DataStore | `TC40_Base_DataStore_Service` | `TC40_Base_DataStore_Client` |

这些类的结构和对应基础类相同，但 `DTNoAuthService`/`DTVirtualAuthService`/`DTService` 类型为 DataStore 变体（如 `TDataStoreService_NoAuth`）。

---

## 9. VM 服务/客户端模板

VM（虚拟机）风格封装将服务/客户端包装为可独立启动/停止的组件。

### 9.1 TC40_Custom_VM_Service

VM 服务基类，提供独立的生命周期管理。

#### 9.1.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FLastSafeCheckTime` | `TTimeTick` | 上次安全检查时间。 |

#### 9.1.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Param` | `U_String` | 只读 | 参数字符串。 |
| `ParamList` | `THashStringList` | 只读 | 解析后的参数键值对。 |
| `SafeCheckTime` | `TTimeTick` | 只读 | 安全检查间隔。 |
| `IPC_Mode` | `Boolean` | 只读 | 是否处于 IPC 模式。 |
| `enablePerServiceDirectory` | `Boolean` | 只读 | 是否启用每个服务的子目录。 |
| `ConsoleCommand` | `TC4_Help_Console_Command` | 只读 | 控制台命令注册表。 |

#### 9.1.3 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create(Param_: U_String); virtual;` | 创建 VM 服务，解析参数。 |
| `Destroy` | `destructor Destroy; override;` | 析构，释放资源。 |
| `SafeCheck` | `procedure SafeCheck; virtual;` | 周期性安全检查。 |
| `Progress` | `procedure Progress; virtual;` | 主进度方法。 |
| `StartService` | `procedure StartService(ListenAddr, ListenPort, Auth: SystemString); virtual;` | 启动服务。 |
| `StopService` | `procedure StopService; virtual;` | 停止服务。 |
| `Get_DB_FileName_Config` | `function Get_DB_FileName_Config(source_: U_String): U_String;` | 获取配置文件名称。 |
| `Register_ConsoleCommand` | `function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;` | 注册控制台命令。 |
| `DoLinkSuccess` | `procedure DoLinkSuccess(Trigger_: TCore_Object); virtual;` | 连接成功事件。 |
| `DoUserOut` | `procedure DoUserOut(Trigger_: TCore_Object); virtual;` | 用户断开事件。 |

---

### 9.2 TC40_Custom_VM_Client

VM 客户端基类。

#### 9.2.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FLastSafeCheckTime` | `TTimeTick` | 上次安全检查时间。 |

#### 9.2.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Param` | `U_String` | 只读 | 参数字符串。 |
| `ParamList` | `THashStringList` | 只读 | 解析后的参数键值对。 |
| `SafeCheckTime` | `TTimeTick` | 只读 | 安全检查间隔。 |
| `IPC_Mode` | `Boolean` | 只读 | 是否处于 IPC 模式。 |
| `ConsoleCommand` | `TC4_Help_Console_Command` | 只读 | 控制台命令注册表。 |
| `On_Client_Online` | `TOn_VM_Client_Event` | 读写 | 客户端上线回调。 |
| `On_Client_Offline` | `TOn_VM_Client_Event` | 读写 | 客户端离线回调。 |

#### 9.2.3 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create(Param_: U_String); virtual;` | 创建 VM 客户端。 |
| `Destroy` | `destructor Destroy; override;` | 析构，释放资源。 |
| `SafeCheck` | `procedure SafeCheck; virtual;` | 周期性安全检查。 |
| `Progress` | `procedure Progress; virtual;` | 主进度方法。 |
| `Connected` | `function Connected: Boolean; virtual;` | 返回是否已连接。 |
| `Disconnect` | `procedure Disconnect; virtual;` | 断开连接。 |
| `Get_DB_FileName_Config` | `function Get_DB_FileName_Config(source_: U_String): U_String;` | 获取配置文件名称。 |
| `Register_ConsoleCommand` | `function Register_ConsoleCommand(Cmd, Desc: SystemString): TC4_Help_Console_Command_Data;` | 注册控制台命令。 |
| `DoNetworkOnline` | `procedure DoNetworkOnline; virtual;` | 连接成功时调用。 |
| `DoNetworkOffline` | `procedure DoNetworkOffline; virtual;` | 断开连接时调用。 |

---

### 9.3 池管理

| 池类 | 元素类型 | 说明 |
| :--- | :--- | :--- |
| `TC40_Custom_VM_Service_Pool` | `TC40_Custom_VM_Service` | VM 服务池，提供 `Progress` 方法。 |
| `TC40_Custom_VM_Client_Pool` | `TC40_Custom_VM_Client` | VM 客户端池，提供 `Progress` 方法。 |

---

## 10. 控制台帮助系统

### 10.1 TC4_Help_Console_Command_Data

单个控制台命令的数据容器。

#### 10.1.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Cmd` | `SystemString` | 命令名称。 |
| `Desc` | `SystemString` | 命令描述。 |
| `OnEvent_C` | `TOn_C4_Help_Console_Command_C` | C 风格处理器。 |
| `OnEvent_M` | `TOn_C4_Help_Console_Command_M` | 方法风格处理器。 |
| `OnEvent_P` | `TOn_C4_Help_Console_Command_P` | 嵌套风格处理器。 |

#### 10.1.2 方法

| 方法名 | 说明 |
| :--- | :--- |
| `DoExecute` | 执行命令，调用注册的处理器。 |

---

### 10.2 TC4_Help_Console_Command

控制台命令注册表，继承自 `TBigList<TC4_Help_Console_Command_Data>`。

#### 10.2.1 方法

| 方法名 | 说明 |
| :--- | :--- |
| `DoFree` | 释放命令数据。 |

---

### 10.3 TC40_Console_Help

交互式控制台帮助系统，提供丰富的诊断和管理命令。

#### 10.3.1 字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Last_Instance_State` | `TInstance_State_Tool` | 缓存的实例状态（用于比较）。 |

#### 10.3.2 属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `opRT` | `TOpCustomRunTime` | 只读 | 表达式执行运行时。 |
| `HelpTextStyle` | `TTextStyle` | 读写 | 表达式解析文本风格。 |
| `IsExit` | `Boolean` | 只读 | 是否退出控制台。 |

#### 10.3.3 方法

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `Create` | `constructor Create; virtual;` | 创建控制台帮助，初始化运行时并注册命令。 |
| `Destroy` | `destructor Destroy; override;` | 析构，释放运行时。 |
| `Update_opRT` | `procedure Update_opRT; virtual;` | 更新运行时，重新注册所有命令。 |
| `Run_HelpCmd` | `procedure Run_HelpCmd(exp_: U_String);` | 执行控制台命令表达式。 |

#### 10.3.4 内置命令

| 命令名 | 描述 | 说明 |
| :--- | :--- | :--- |
| `Help` | 帮助信息 | 列出所有可用命令。 |
| `Exit` / `Close` | 安全关闭控制台 | 设置 `IsExit := True`。 |
| `service` | `service(ip, port)` | 显示本地服务报告。 |
| `server` / `serv` | `server(ip, port)` | `service` 的别名。 |
| `tunnel` / `client` / `cli` | `tunnel(ip, port)` | 显示隧道报告。 |
| `RegInfo` | C4 注册信息 | 显示所有已注册的服务类型。 |
| `KillNet` | `KillNet(ip, port)` | 终止物理网络。 |
| `C4_Clean` | 清理所有物理网络 | 移除所有连接和服务。 |
| `Quiet` | `Quiet(bool)` | 设置静默模式。 |
| `Save_All_C4Service_Config` | 保存所有服务配置 | 将服务配置保存到文件。 |
| `Save_All_C4Client_Config` | 保存所有客户端配置 | 将客户端配置保存到文件。 |
| `Instance_Info` / `Inst_Info` | 实例状态信息 | 打印所有实例状态。 |
| `Instance_Info_Sort_Update` | 按更新排序 | 按更新时间排序实例状态。 |
| `Instance_Info_Sort_Time` | 按时间排序 | 按时间排序实例状态。 |
| `Build_Instance_State` | 构建实例状态 | 捕获当前实例状态快照。 |
| `Compare_Instance_State` | 比较实例状态 | 与快照比较实例状态变化。 |
| `HPC_Thread_Info` | HPC 线程信息 | 显示 HPC 任务状态。 |
| `ZNet_Instance_Info` / `ZNet_Info` | ZNet 实例信息 | 显示 ZNet 实例状态。 |
| `Delay_Free_Info` / `Enabled_Delay_Info` | 延迟释放信息 | 显示延迟释放实例信息。 |
| `Intermediate_Instance_Info` / `Enabled_Intermediate_Instance_Info` | 中间实例状态 | 显示中间实例状态。 |
| `Service_CMD_Info` / `Server_CMD_Info` | 服务命令信息 | 显示服务命令统计。 |
| `Client_CMD_Info` / `Cli_CMD_Info` | 客户端命令信息 | 显示客户端命令统计。 |
| `Service_Statistics_Info` / `Server_Statistics_Info` | 服务统计信息 | 显示服务端统计。 |
| `Client_Statistics_Info` / `Cli_Statistics_Info` | 客户端统计信息 | 显示客户端统计。 |
| `ZDB2_Info` | ZDB2 引擎信息 | 显示 ZDB2 线程引擎状态。 |
| `ZDB2_Flush` | 刷新 ZDB2 引擎 | 刷新所有 ZDB2 线程引擎。 |
| `SetQuiet` | `SetQuiet(bool)` | `Quiet` 的别名。 |

---

## 11. 全局 API 函数

| 函数名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `C40Progress` | `procedure C40Progress(sleep_: Integer); overload;` | 主进度循环，带休眠参数。 |
| `C40Progress` | `procedure C40Progress; overload;` | 主进度循环，默认 1ms 休眠。 |
| `C40_Online_DP` | `function C40_Online_DP: TC40_Dispatch_Client;` | 获取当前在线的调度客户端实例。 |
| `C40SetQuietMode` | `procedure C40SetQuietMode(QuietMode_: Boolean);` | 设置整个 C4 框架的静默模式。 |
| `C40WriteConfig` | `procedure C40WriteConfig(HS: THashStringList);` | 将当前 C4 配置写入哈希字符串列表。 |
| `C40ReadConfig` | `procedure C40ReadConfig(HS: THashStringList);` | 从哈希字符串列表读取 C4 配置。 |
| `C40ResetDefaultConfig` | `procedure C40ResetDefaultConfig;` | 重置所有 C4 配置为默认值。 |
| `C40Clean` | `procedure C40Clean;` | 清理所有 C4 资源。 |
| `C40Clean_Service` | `procedure C40Clean_Service;` | 仅清理服务端资源。 |
| `C40Clean_Client` | `procedure C40Clean_Client;` | 仅清理客户端资源。 |
| `C40PrintRegistation` | `procedure C40PrintRegistation;` | 打印所有已注册的服务类型。 |
| `C40ExistsPhysicsNetwork` | `function C40ExistsPhysicsNetwork(PhysicsAddr: U_String; PhysicsPort: Word): Boolean;` | 检查物理网络是否存在。 |
| `C40_Get_Physics_Connected_Num` | `function C40_Get_Physics_Connected_Num(): Integer;` | 获取物理连接总数。 |
| `C40_Get_Physics_Netowork_Is_Inited_Num` | `function C40_Get_Physics_Netowork_Is_Inited_Num(): Integer;` | 获取已初始化的物理网络数。 |
| `C40RemovePhysics` | `procedure C40RemovePhysics(PhysicsAddr: U_String; PhysicsPort: Word; Remove_P2PVM_Client_, Remove_Physics_Client_, RemoveP2PVM_Service_, Remove_Physcis_Service_: Boolean); overload;` | 移除物理网络及其关联资源。 |
| `C40RemovePhysics` | `procedure C40RemovePhysics(Tunnel_: TC40_PhysicsTunnel); overload;` | 移除物理隧道及其关联资源。 |
| `C40RemovePhysics` | `procedure C40RemovePhysics(Service_: TC40_PhysicsService); overload;` | 移除物理服务及其关联资源。 |
| `C40CheckAndKillDeadPhysicsTunnel` | `procedure C40CheckAndKillDeadPhysicsTunnel();` | 检查并终止死物理隧道。 |
| `RegisterC40` | `function RegisterC40(ServiceTyp: U_String; ServiceClass: TC40_Custom_Service_Class; ClientClass: TC40_Custom_Client_Class): Boolean;` | 注册服务类型及其类。 |
| `FindRegistedC40` | `function FindRegistedC40(ServiceTyp: U_String): PC40_RegistedData;` | 查找注册记录。 |
| `GetRegisterClientTypFromClass` | `function GetRegisterClientTypFromClass(ClientClass: TC40_Custom_Client_Class): U_String; overload;` | 获取客户端类关联的服务类型。 |
| `GetRegisterServiceTypFromClass` | `function GetRegisterServiceTypFromClass(ClientClass: TC40_Custom_Client_Class): U_String; overload;` | 同 `GetRegisterClientTypFromClass`（别名）。 |
| `GetRegisterServiceTypFromClass` | `function GetRegisterServiceTypFromClass(ServiceClass: TC40_Custom_Service_Class): U_String; overload;` | 获取服务类关联的服务类型。 |
| `Compare_C40_ServiceTyp` | `function Compare_C40_ServiceTyp(typ1, typ2: U_String): Boolean; overload;` | 比较两个服务类型是否兼容。 |
| `Compare_C40_ServiceTyp` | `function Compare_C40_ServiceTyp(typ1, typ2, typ3: U_String): Boolean; overload;` | 比较三个服务类型是否互相兼容。 |
| `ExtractDependInfo` | `function ExtractDependInfo(info: TC40_DependNetworkInfoList): TC40_DependNetworkInfoArray; overload;` | 从列表提取依赖信息数组。 |
| `ExtractDependInfo` | `function ExtractDependInfo(info: U_String): TC40_DependNetworkInfoArray; overload;` | 从管道分隔字符串提取依赖信息。 |
| `ExtractDependInfo` | `function ExtractDependInfo(arry: TC40_DependNetworkString): TC40_DependNetworkInfoArray; overload;` | 从字符串数组提取依赖信息。 |
| `ExtractDependInfoToL` | `function ExtractDependInfoToL(info: U_String): TC40_DependNetworkInfoList; overload;` | 从管道分隔字符串提取依赖信息列表。 |
| `ExtractDependInfoToL` | `function ExtractDependInfoToL(arry: TC40_DependNetworkString): TC40_DependNetworkInfoList; overload;` | 从字符串数组提取依赖信息列表。 |
| `ResetDependInfoBuff` | `procedure ResetDependInfoBuff(var arry: TC40_DependNetworkInfoArray);` | 重置依赖信息缓冲区。 |
| `Is_IPC_Addr` | `function Is_IPC_Addr(ListenAddr_Or_PhysicsAddr: U_String): Boolean;` | 检查地址是否为 IPC 地址（以 `ipc:*` 开头）。 |
| `Get_Physics_Server_Class` | `function Get_Physics_Server_Class(ListenAddr, PhysicsAddr: U_String): TZNet_ServerClass;` | 根据地址获取物理服务类。 |
| `Get_Physics_Client_Class` | `function Get_Physics_Client_Class(PhysicsAddr: U_String): TZNet_ClientClass;` | 根据地址获取物理客户端类。 |

---

## 12. 全局变量

| 变量名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `C40_QuietMode` | `Boolean` | 静默模式，抑制大部分日志输出。默认 `False`。 |
| `C40_SafeCheckTime` | `TTimeTick` | 物理服务安全检查间隔（毫秒）。默认 `45 * 1000`。 |
| `C40_PhysicsReconnectionDelayTime` | `Double` | C4 重连延迟时间（秒）。默认 `5.0`。 |
| `C40_UpdateServiceInfoDelayTime` | `TTimeTick` | 调度服务信息更新延迟（毫秒）。默认 `1000`。 |
| `C40_PhysicsServiceTimeout` | `TTimeTick` | 物理服务超时（毫秒）。默认 `15 * 60 * 1000`。 |
| `C40_PhysicsTunnelTimeout` | `TTimeTick` | 物理隧道超时（毫秒）。默认 `15 * 60 * 1000`。 |
| `C40_KillDeadPhysicsConnectionTimeout` | `TTimeTick` | 死物理连接清理超时（毫秒）。默认 `60 * 1000`。 |
| `C40_KillIDCFaultTimeout` | `TTimeTick` | IDC 故障清理超时（毫秒）。默认 `24 * 7 * 60 * 60 * 1000`（7天）。 |
| `C40_EnablePerServiceDirectory` | `Boolean` | 是否启用每个服务的子目录。默认 `True`。 |
| `C40_RootPath` | `U_String` | C4 配置和数据文件的根路径。默认当前目录。 |
| `C40_Password` | `SystemString` | 默认 P2PVM 认证密码。默认 `'DTC40@ZSERVER'`。 |
| `C40_PhysicsClientClass` | `TZNet_ClientClass` | 物理客户端类。默认 `TPhysicsClient`。 |
| `C40_Registed` | `TC40_RegistedDataList` | 全局服务类型注册表。 |
| `C40_PhysicsServicePool` | `TC40_PhysicsServicePool` | 全局物理服务池。 |
| `C40_ServicePool` | `TC40_Custom_ServicePool` | 全局自定义服务池。 |
| `C40_PhysicsTunnelPool` | `TC40_PhysicsTunnelPool` | 全局物理隧道池。 |
| `C40_ClientPool` | `TC40_Custom_ClientPool` | 全局自定义客户端池。 |
| `C40_VM_Service_Pool` | `TC40_Custom_VM_Service_Pool` | 全局 VM 服务池。 |
| `C40_VM_Client_Pool` | `TC40_Custom_VM_Client_Pool` | 全局 VM 客户端池。 |
| `C40_DefaultConfig` | `THashStringList` | 默认配置哈希字符串列表。 |
| `Ignore_Command_Line` | `TPascalStringList` | 要忽略的命令行参数列表。 |

---

## 13. 初始化与终结

### 初始化阶段

1. 设置所有全局配置变量为默认值。
2. 创建全局池：
   - `C40_Registed`
   - `C40_PhysicsServicePool`
   - `C40_ServicePool`
   - `C40_PhysicsTunnelPool`
   - `C40_ClientPool`
   - `C40_VM_Service_Pool`
   - `C40_VM_Client_Pool`
3. 注册默认服务类型：
   - `'DP'` → `TC40_Dispatch_Service` / `TC40_Dispatch_Client`
   - `'NULL'` → `TC40_Base_NULL_Service` / `TC40_Base_NULL_Client`
   - `'NA'` → `TC40_Base_NoAuth_Service` / `TC40_Base_NoAuth_Client`
   - `'DNA'` → `TC40_Base_DataStoreNoAuth_Service` / `TC40_Base_DataStoreNoAuth_Client`
   - `'VA'` → `TC40_Base_VirtualAuth_Service` / `TC40_Base_VirtualAuth_Client`
   - `'DVA'` → `TC40_Base_DataStoreVirtualAuth_Service` / `TC40_Base_DataStoreVirtualAuth_Client`
   - `'D'` → `TC40_Base_Service` / `TC40_Base_Client`
   - `'DD'` → `TC40_Base_DataStore_Service` / `TC40_Base_DataStore_Client`
4. 备份默认配置到 `C40_DefaultConfig`。
5. 创建 `Ignore_Command_Line` 列表。
6. 挂钩 `OnCheckThreadSynchronize` 以集成 `C40Progress`。

### 终结阶段

1. 禁用实例跟踪打印。
2. 调用 `C40Clean` 清理所有资源。
3. 释放所有全局池。
4. 恢复 `OnCheckThreadSynchronize`。

---

## 14. 回调类型与接口

### 14.1 IC40_PhysicsService_Event

物理服务生命周期事件接口。

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `C40_PhysicsService_Build_Network` | `procedure C40_PhysicsService_Build_Network(Sender: TC40_PhysicsService; Custom_Service_: TC40_Custom_Service);` | 构建依赖网络服务时调用。 |
| `C40_PhysicsService_Start` | `procedure C40_PhysicsService_Start(Sender: TC40_PhysicsService);` | 物理服务启动成功时调用。 |
| `C40_PhysicsService_Stop` | `procedure C40_PhysicsService_Stop(Sender: TC40_PhysicsService);` | 物理服务停止时调用。 |
| `C40_PhysicsService_LinkSuccess` | `procedure C40_PhysicsService_LinkSuccess(Sender: TC40_PhysicsService; Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);` | 客户端成功连接到依赖服务时调用。 |
| `C40_PhysicsService_UserOut` | `procedure C40_PhysicsService_UserOut(Sender: TC40_PhysicsService; Custom_Service_: TC40_Custom_Service; Trigger_: TCore_Object);` | 用户/客户端从依赖服务断开时调用。 |

---

### 14.2 IC40_PhysicsTunnel_Event

物理隧道生命周期事件接口。

| 方法名 | 原型 | 说明 |
| :--- | :--- | :--- |
| `C40_PhysicsTunnel_Connected` | `procedure C40_PhysicsTunnel_Connected(Sender: TC40_PhysicsTunnel);` | 物理隧道建立连接时调用。 |
| `C40_PhysicsTunnel_Disconnect` | `procedure C40_PhysicsTunnel_Disconnect(Sender: TC40_PhysicsTunnel);` | 物理隧道断开时调用。 |
| `C40_PhysicsTunnel_Build_Network` | `procedure C40_PhysicsTunnel_Build_Network(Sender: TC40_PhysicsTunnel; Custom_Client_: TC40_Custom_Client);` | 构建依赖网络客户端时调用。 |
| `C40_PhysicsTunnel_Client_Connected` | `procedure C40_PhysicsTunnel_Client_Connected(Sender: TC40_PhysicsTunnel; Custom_Client_: TC40_Custom_Client);` | 依赖客户端连接成功时调用。 |

---

### 其他回调类型

| 类型名 | 说明 |
| :--- | :--- |
| `TDCT40_OnQueryResultC/M/P` | 物理隧道查询结果回调（C/M/P 风格）。 |
| `TOn_C40_Custom_Client_EventC/M/P` | 自定义客户端池事件回调。 |
| `TOnSearchServiceAndBuildConnection_C/M/P` | 搜索服务并构建连接完成回调。 |
| `TOn_C4_Help_Console_Command_C/M/P` | 控制台命令执行回调。 |
| `TOn_Client_Offline` | 客户端离线回调。 |
| `TOn_VM_Client_Event` | VM 客户端事件回调。 |
| `TOnServiceInfoChange` | 服务信息变更回调。 |

---

## 15. 附录

### 15.1 依赖描述符速查

| 表示形式 | 示例 | 说明 |
| :--- | :--- | :--- |
| 单个服务类型 | `'DP'` | 依赖名为 `DP` 的服务。 |
| 带参数 | `'UserDB@SafeCheckTime=10000'` | 依赖 `UserDB` 服务，传入参数。 |
| 多个依赖（数组） | `['DP', 'UserDB@SafeCheckTime=10000']` | 依赖多个服务。 |
| 管道分隔字符串 | `'DP|<>UserDB@SafeCheckTime=10000'` | 使用 `|<>` 分隔多个依赖。 |

### 15.2 认证模型选择指南

| 场景 | 推荐模型 | 原因 |
| :--- | :--- | :--- |
| 内部网络、测试环境 | NoAuth | 性能最优，无认证开销。 |
| 需要自定义认证逻辑 | VirtualAuth | 认证逻辑完全由应用控制。 |
| 需要内置用户数据库 | BuiltInAuth | 开箱即用的用户管理。 |
| 需要文件存储能力 | DataStore 变体 | 提供数据库和文件系统能力。 |

### 15.3 典型部署拓扑

```
┌─────────────────────────────────────────────────────────────┐
│                    物理服务 (物理机/容器)                    │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │ TC40_PhysicsService │    │ TC40_PhysicsService │                │
│  │  Listening: 0.0.0.0:8008 │    │  Listening: 0.0.0.0:8009 │                │
│  │  Depend: DP, UserDB │    │  Depend: FS2, LogDB  │                │
│  └────────┬────────┘    └────────┬────────┘                │
│           │                       │                         │
│  ┌────────┴───────────────────────┴────────┐               │
│  │       P2PVM 隧道 (逻辑网络)              │               │
│  └────────┬───────────────────────┬────────┘               │
│           │                       │                         │
│  ┌────────┴────────┐    ┌────────┴────────┐                │
│  │ TC40_Dispatch_Service │    │ TC40_Dispatch_Service │                │
│  │  (调度服务)           │    │  (调度服务)           │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    物理客户端 (应用)                         │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │ TC40_PhysicsTunnel  │    │ TC40_PhysicsTunnel  │                │
│  │  Connect: 192.168.1.1:8008 │    │  Connect: 192.168.1.2:8008 │                │
│  │  Depend: DP, UserDB │    │  Depend: DP, FS2    │                │
│  └─────────────────┘    └─────────────────┘                │
│                                                             │
│  应用通过 C40_ClientPool 获取服务客户端实例                  │
└─────────────────────────────────────────────────────────────┘
```

---

*本白皮书基于 `Z.Net.C4.pas` 源代码逐项整理，涵盖了所有类、方法、属性、字段、全局函数和变量。如有任何遗漏，请参照源代码进行补充。*
