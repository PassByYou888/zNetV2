# Cloud 4.0 (C4) 分布式服务框架 — 从入门到精通

## 完整使用指南与速查手册

> **基于**：`Z.Net.C4.pas` 及配套示例项目  
> **覆盖范围**：物理层、调度服务、认证模型、业务服务、高级特性  
> **目标读者**：从初学者到高级开发者

---

## 第一部分：入门篇

### 第1章 框架概述

#### 1.1 什么是 C4？

Cloud 4.0（C4）是一个构建在 Z.Net 之上的**分布式服务框架**，核心设计理念：

- **P2PVM 隧道通信**：单条物理连接承载多个逻辑服务
- **服务自动发现**：通过调度服务实现注册、发现和负载感知路由
- **多种认证模型**：NoAuth / VirtualAuth / BuiltInAuth
- **依赖注入**：通过依赖描述符自动构建服务网络

#### 1.2 核心概念速览

| 概念 | 说明 | 对应类 |
| :--- | :--- | :--- |
| 物理服务 | 监听端口，接受连接 | `TC40_PhysicsService` |
| 物理隧道 | 连接远程服务 | `TC40_PhysicsTunnel` |
| 调度服务 | 服务注册与发现 | `TC40_Dispatch_Service` / `TC40_Dispatch_Client` |
| 自定义服务 | 业务逻辑 | `TC40_Custom_Service` 子类 |
| 自定义客户端 | 调用业务 | `TC40_Custom_Client` 子类 |
| VM 服务 | 独立启动/停止组件 | `TC40_Custom_VM_Service` / `TC40_Custom_VM_Client` |

#### 1.3 环境准备

```pascal
program MinimalC4;

uses
  Z.Core,
  Z.PascalStrings,
  Z.UnicodeMixedLib,
  Z.Status,
  Z.Net,
  Z.Net.PhysicsIO,
  Z.Net.C4,
  Z.Net.C4_Console_APP;

begin
  Z.Net.C4.C40_QuietMode := False;
  // ... 你的代码 ...
  C40_Execute_Main_Loop;
  Z.Net.C4.C40Clean;
end.
```

---

### 第2章 第一个 C4 程序

#### 2.1 启动一个调度服务（DP）

```pascal
program FirstDP;

uses
  Z.Core, Z.PascalStrings, Z.UnicodeMixedLib,
  Z.Net, Z.Net.PhysicsIO, Z.Net.C4, Z.Net.C4_Console_APP;

const
  DP_ADDR = '127.0.0.1';
  DP_PORT = 8387;

begin
  C40_QuietMode := False;

  // 创建物理服务，监听 8387 端口
  with TC40_PhysicsService.Create(DP_ADDR, DP_PORT, TPhysicsServer.Create) do
  begin
    BuildDependNetwork('dp');  // 构建调度服务
    StartService;
  end;

  // 客户端连接到调度服务
  C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(DP_ADDR, DP_PORT, 'dp', nil);

  C40_Execute_Main_Loop;
  C40Clean;
end.
```

**编译运行后**，你将看到一个运行中的调度服务。

#### 2.2 依赖描述符（Depend String）

依赖描述符用于声明服务依赖：

```pascal
// 单个依赖
'DP'

// 多个依赖（管道分隔）
'DP|UserDB|FS'

// 带参数
'UserDB@SafeCheckTime=5000'

// 混合
'DP|<>UserDB@SafeCheckTime=5000|FS@CacheSize=1024'
```

#### 2.3 物理服务的生命周期

```pascal
var
  Service: TC40_PhysicsService;
begin
  Service := TC40_PhysicsService.Create('0.0.0.0', 8008, TPhysicsServer.Create);
  try
    Service.BuildDependNetwork('DP|UserDB');
    Service.StartService;
    // ... 运行中 ...
    Service.StopService;
  finally
    Service.Free;
  end;
end;
```

---

## 第二部分：精通篇

### 第3章 物理层深入

#### 3.1 TC40_PhysicsService 完整 API

**创建**：

```pascal
// 方式1：监听地址与公布地址相同
constructor Create(PhysicsAddr: U_String; PhysicsPort: Word; PhysicsTunnel: TZNet_Server);

// 方式2：监听地址与公布地址不同（NAT 场景）
constructor Create(ListeningAddr, PhysicsAddr: U_String; PhysicsPort: Word; PhysicsTunnel: TZNet_Server);
```

**属性**：

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `ListeningAddr` | `U_String` | 实际监听的 IP 地址 |
| `PhysicsAddr` | `U_String` | 对外公布的地址 |
| `PhysicsPort` | `Word` | 监听端口 |
| `PhysicsTunnel` | `TZNet_Server` | 底层网络服务 |
| `Activted` | `Boolean` | 是否处于活动状态 |
| `DependNetworkServicePool` | `TC40_Custom_ServicePool` | 依赖服务池 |
| `OnEvent` | `IC40_PhysicsService_Event` | 事件接口 |

**方法**：

| 方法 | 说明 |
| :--- | :--- |
| `BuildDependNetwork(Depend_: TC40_DependNetworkInfoArray): Boolean` | 从数组构建依赖 |
| `BuildDependNetwork(Depend_: TC40_DependNetworkString): Boolean` | 从字符串数组构建 |
| `BuildDependNetwork(Depend_: U_String): Boolean` | 从管道字符串构建 |
| `StartService` | 启动监听 |
| `StopService` | 停止监听 |
| `Progress` | 驱动进度（通常由 C40Progress 调用） |
| `IPC_Mode: Boolean` | 是否 IPC 模式 |
| `DoLinkSuccess` / `DoUserOut` | 触发事件 |

#### 3.2 TC40_PhysicsTunnel 完整 API

**创建**：

```pascal
constructor Create(Addr: U_String; Port: Word);
```

**属性**：

| 属性 | 类型 | 说明 |
| :--- | :--- | :--- |
| `PhysicsAddr` | `U_String` | 远程地址 |
| `PhysicsPort` | `Word` | 远程端口 |
| `PhysicsTunnel` | `TZNet_Client` | 底层网络客户端 |
| `DependNetworkInfoArray` | `TC40_DependNetworkInfoArray` | 依赖信息 |
| `DependNetworkClientPool` | `TC40_Custom_ClientPool` | 依赖客户端池 |
| `OnEvent` | `IC40_PhysicsTunnel_Event` | 事件接口 |

**方法**：

| 方法 | 说明 |
| :--- | :--- |
| `ResetDepend(...)` | 重置依赖（多种重载） |
| `CheckDepend` / `CheckDependC/M/P` | 检查依赖是否可用（同步/异步） |
| `BuildDependNetwork` / `BuildDependNetworkC/M/P` | 构建依赖网络 |
| `QueryInfoC/M/P` | 查询远程服务信息 |
| `DependNetworkIsConnected: Boolean` | 所有依赖是否已连接 |
| `IPC_Mode: Boolean` | 是否 IPC 模式 |
| `IsLocalNetwork: Boolean` | 目标是否为本地网络 |

#### 3.3 物理隧道池 TC40_PhysicsTunnelPool

**方法**：

| 方法 | 说明 |
| :--- | :--- |
| `GetOrCreatePhysicsTunnel(addr, port): TC40_PhysicsTunnel` | 获取或创建 |
| `GetOrCreatePhysicsTunnel(addr, port, depend, event)` | 带依赖和事件 |
| `GetOrCreatePhysicsTunnel(dispInfo: TC40_Info)` | 从服务信息创建 |
| `SearchServiceAndBuildConnection(...)` | 搜索服务并构建连接 |
| `ExistsPhysicsAddr(addr, port): Boolean` | 检查是否存在 |
| `GetPhysicsTunnel(addr, port): TC40_PhysicsTunnel` | 获取指定隧道 |
| `GetRS(var recv, send: Int64)` | 获取收发统计 |
| `Progress` | 驱动所有隧道进度 |

---

### 第4章 服务信息与发现

#### 4.1 TC40_Info — 服务描述符

**字段**：

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `OnlyInstance` | `Boolean` | 是否唯一实例 |
| `ServiceTyp` | `U_String` | 服务类型 |
| `PhysicsAddr` | `U_String` | 物理地址 |
| `PhysicsPort` | `Word` | 物理端口 |
| `p2pVM_RecvTunnel_Addr/Port` | `U_String` / `Word` | P2PVM 接收隧道 |
| `p2pVM_SendTunnel_Addr/Port` | `U_String` / `Word` | P2PVM 发送隧道 |
| `Workload` | `Integer` | 当前负载 |
| `MaxWorkload` | `Integer` | 最大负载 |
| `Hash` | `TMD5` | 唯一标识 |

**方法**：

| 方法 | 说明 |
| :--- | :--- |
| `Assign(source: TC40_Info)` | 复制信息 |
| `Clone: TC40_Info` | 克隆 |
| `Load(stream)` / `Save(stream)` | 序列化 |
| `Same(Data): Boolean` | 是否相同 |
| `SamePhysicsAddr(addr, port): Boolean` | 地址匹配 |
| `FoundServiceTyp(typ): Boolean` | 类型匹配 |
| `GetOrCreateC40Client(...): TC40_Custom_Client` | 获取或创建客户端 |

#### 4.2 TC40_InfoList — 服务列表

**方法**：

| 方法 | 说明 |
| :--- | :--- |
| `SortWorkLoad(L: TC40_InfoList)` | 按负载排序（类方法） |
| `SearchService(typ): TC40_Info_Array` | 搜索服务 |
| `SearchMinWorkload(typ): TC40_Info_Array` | 搜索最小负载服务 |
| `ExistsService(typ): Boolean` | 检查服务是否存在 |
| `FindSame(info): TC40_Info` | 查找相同信息 |
| `FindHash(hash): TC40_Info` | 通过哈希查找 |
| `OverwriteInfo(info): Boolean` | 覆盖或添加信息 |
| `MergeFromDF(D: TDFE): Boolean` | 从 DFE 合并 |
| `SaveToDF(D: TDFE)` | 保存到 DFE |

---

### 第5章 认证模型

#### 5.1 三种认证模型对比

| 模型 | 服务基类 | 客户端基类 | 适用场景 |
| :--- | :--- | :--- | :--- |
| **NoAuth** | `TC40_Base_NoAuth_Service` | `TC40_Base_NoAuth_Client` | 内部网络/测试 |
| **VirtualAuth** | `TC40_Base_VirtualAuth_Service` | `TC40_Base_VirtualAuth_Client` | 自定义认证逻辑 |
| **BuiltInAuth** | `TC40_Base_Service` | `TC40_Base_Client` | 内置用户数据库 |
| **DataStore 变体** | `*_DataStore*` | `*_DataStore*` | 增加存储能力 |

#### 5.2 NoAuth 模型

```pascal
// 注册（框架已预注册）
RegisterC40('NA', TC40_Base_NoAuth_Service, TC40_Base_NoAuth_Client);

// 使用
BuildDependNetwork('NA');
```

#### 5.3 VirtualAuth 模型（重点）

**服务端 — 自定义认证逻辑**：

```pascal
type
  TMyVA_Service = class(TC40_Base_VirtualAuth_Service)
  protected
    procedure DoUserReg_Event(Sender: TDTService_VirtualAuth; RegIO: TVirtualRegIO); override;
    procedure DoUserAuth_Event(Sender: TDTService_VirtualAuth; AuthIO: TVirtualAuthIO); override;
  end;

procedure TMyVA_Service.DoUserReg_Event(Sender: TDTService_VirtualAuth; RegIO: TVirtualRegIO);
begin
  if MyUserDB.Exists(RegIO.UserID) then
    RegIO.Reject  // 用户已存在
  else
  begin
    MyUserDB.Save(RegIO.UserID, RegIO.Passwd);
    RegIO.Accept;  // 接受注册
  end;
end;

procedure TMyVA_Service.DoUserAuth_Event(Sender: TDTService_VirtualAuth; AuthIO: TVirtualAuthIO);
begin
  if MyUserDB.Verify(AuthIO.UserID, AuthIO.Passwd) then
    AuthIO.Accept   // 认证通过
  else
    AuthIO.Reject;  // 认证失败
end;
```

**客户端 — 登录流程**：

```pascal
// 注册服务类型
RegisterC40('MyVA', TMyVA_Service, TC40_Base_VirtualAuth_Client);

// 等待服务就绪并登录
C40_ClientPool.WaitConnectedDoneP('MyVA',
  procedure(States: TC40_Custom_ClientPool_Wait_States)
  var
    Client: TC40_Base_VirtualAuth_Client;
  begin
    Client := States[0].Client_ as TC40_Base_VirtualAuth_Client;

    // 方式1：先注册再登录
    Client.Client.RegisterUserAndLogin := True;
    Client.Client.Connect_P('username', 'password',
      procedure(const State: Boolean)
      begin
        if State then DoStatus('登录成功');
      end);

    // 方式2：仅登录（已注册用户）
    Client.Client.RegisterUserAndLogin := False;
    Client.Client.Connect_P('username', 'password', ...);
  end);
```

**TVirtualAuthIO / TVirtualRegIO 关键方法**：

| 方法 | 说明 |
| :--- | :--- |
| `Accept` | 接受注册/认证 |
| `Reject` | 拒绝注册/认证 |
| `Online: Boolean` | 客户端是否仍在线 |
| `UserDefineIO` | 获取 IO 定义对象 |
| `Bye` | 强制断开客户端 |

#### 5.4 BuiltInAuth 模型

```pascal
RegisterC40('D', TC40_Base_Service, TC40_Base_Client);

// 服务端配置
Service.DTService.AllowRegisterNewUser := True;
Service.DTService.RootPath := './users/';
Service.DTService.LoadUserDB;  // 加载用户数据库

// 客户端登录
Client.Client.Login('username', 'password');
```

---

### 第6章 调度服务（Dispatch）

#### 6.1 调度服务架构

```
┌─────────────────────────────────────────────────┐
│            TC40_Dispatch_Service                 │
│  - 维护全局 TC40_InfoList                        │
│  - 广播服务信息到所有连接的 Dispatch Client       │
└─────────────────────────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
┌─────────────────────────────────────────────────┐
│            TC40_Dispatch_Client                  │
│  - 同步本地 Service_Info_Pool                   │
│  - 报告本地服务状态                              │
│  - 触发 OnServiceInfoChange 事件                │
└─────────────────────────────────────────────────┘
```

#### 6.2 服务端部署

```pascal
with TC40_PhysicsService.Create('0.0.0.0', 8387, TPhysicsServer.Create) do
begin
  BuildDependNetwork('dp');
  StartService;
end;
```

#### 6.3 客户端连接

```pascal
C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel('127.0.0.1', 8387, 'dp', nil);

// 获取在线 DP 客户端
var DP: TC40_Dispatch_Client;
DP := C40_Online_DP;
if DP <> nil then
  DP.RequestUpdate;  // 请求刷新服务信息
```

#### 6.4 查询服务信息

```pascal
// 方式1：通过物理隧道查询
Tunnel.QueryInfoP(
  procedure(Sender: TC40_PhysicsTunnel; L: TC40_InfoList)
  var
    arry: TC40_Info_Array;
  begin
    arry := L.SearchService('MyVA');  // 搜索所有 MyVA 服务
    // arry 已按负载排序，arry[0] 负载最小
    if Length(arry) > 0 then
      C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(arry[0], 'MyVA', nil);
  end);

// 方式2：通过 Dispatch Client 的 Service_Info_Pool
var DP: TC40_Dispatch_Client;
DP := C40_Online_DP;
if DP <> nil then
begin
  var arry := DP.Service_Info_Pool.SearchService('MyVA');
  // 使用 arry...
end;
```

#### 6.5 服务信息变更事件

```pascal
// 监听服务信息变更
DP.OnServiceInfoChange :=
  procedure(Sender: TCore_Object; Service_Info_Pool: TC40_InfoList)
  begin
    DoStatus('服务列表已更新，共 %d 个服务', [Service_Info_Pool.Count]);
  end;
```

---

### 第7章 自定义服务与客户端

#### 7.1 创建自定义服务

```pascal
type
  TMyCustomService = class(TC40_Base_NoAuth_Service)
  protected
    // 重写生命周期方法
    procedure DoLinkSuccess_Event(Sender: TDTService_NoAuth;
      UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); override;
    procedure DoUserOut_Event(Sender: TDTService_NoAuth;
      UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); override;
  public
    // 自定义业务方法
    procedure MyBusinessMethod(Data: TDFE);
  end;

implementation

procedure TMyCustomService.DoLinkSuccess_Event(...);
begin
  inherited;
  DoStatus('客户端已连接');
end;

procedure TMyCustomService.DoUserOut_Event(...);
begin
  inherited;
  DoStatus('客户端已断开');
end;
```

#### 7.2 注册自定义服务

```pascal
// 在 initialization 或程序启动时注册
RegisterC40('MyService', TMyCustomService, TC40_Base_NoAuth_Client);
```

#### 7.3 创建自定义客户端

```pascal
type
  TMyCustomClient = class(TC40_Base_NoAuth_Client)
  public
    procedure MyBusinessMethod(Data: TDFE);
  end;

implementation

procedure TMyCustomClient.MyBusinessMethod(Data: TDFE);
begin
  if not Connected then Exit;
  DTNoAuth.SendStreamNotifyCmd('MyCommand', Data);
end;
```

#### 7.4 自动部署客户端

```pascal
// 方式1：等待客户端就绪
var
  MyClient: TMyCustomClient;
begin
  TC40_Auto_Deployment_Client<TMyCustomClient>.Create('MyService', MyClient);
  // MyClient 将在服务就绪后被赋值
end;

// 方式2：回调方式
TC40_Auto_Deployment_Client<TMyCustomClient>.Create_P(
  procedure(var sender: TMyCustomClient)
  begin
    sender.MyBusinessMethod(...);
  end);
```

---

### 第8章 业务服务详解

#### 8.1 用户数据库服务（UserDB）

**服务端部署**：

```pascal
with TC40_PhysicsService.Create('0.0.0.0', 8387, TPhysicsServer.Create) do
begin
  BuildDependNetwork('DP|UserDB');
  StartService;
end;
```

**客户端 API**：

| 方法 | 说明 |
| :--- | :--- |
| `Usr_RegC/M/P(user, passwd, callback)` | 注册用户 |
| `Usr_AuthC/M/P(user, passwd, callback)` | 认证用户 |
| `Usr_ExistsC/M/P(user, callback)` | 检查用户是否存在 |
| `Usr_ChangePasswordC/M/P(user, old, new, callback)` | 修改密码 |
| `Usr_ResetPassword(user, new)` | 重置密码（管理员） |
| `Usr_NewIdentifierC/M/P(user, identifier, callback)` | 添加别名 |
| `Usr_GetPrimaryIdentifierC/M/P(user, callback)` | 获取主标识符 |
| `Usr_GetC/M/P(user, objName, callback)` | 获取用户 JSON 数据 |
| `Usr_Set(user, objName, Json)` | 设置用户 JSON 数据 |
| `Usr_Open(user)` / `Usr_Close(user)` | 用户上线/下线 |
| `Usr_Msg(from, to, msg)` | 发送消息 |
| `Usr_GetFriendsC/M/P(user, callback)` | 获取好友列表 |
| `Usr_RequestAddFriend(from, to, msg)` | 请求添加好友 |
| `Usr_ReponseAddFriend(from, to, msg, accept)` | 响应好友请求 |
| `Usr_RemoveFriend(user, friend)` | 删除好友 |
| `Usr_Kick(user)` | 踢出用户（管理员） |
| `Usr_Enabled(user)` / `Usr_Disable(user)` | 启用/禁用用户 |
| `Usr_OnlineNumC/M/P(callback)` | 获取在线人数 |
| `Usr_OnlineListC/M/P(max, callback)` | 获取在线用户列表 |
| `Usr_SearchM/P(text, max, callback)` | 搜索用户（管理员） |
| `Usr_Upload(Json)` / `Usr_Remove(user)` | 批量上传/删除（管理员） |

**IM 事件接口**：

```pascal
TMyIMHandler = class(TCore_InterfacedObject, I_ON_C40_UserDB_Client_Notify)
  procedure Do_User_Msg(Sender: TC40_UserDB_Client;
    FromUserName, ToUserName, Msg: U_String);
  procedure Do_User_Open(Sender: TC40_UserDB_Client;
    UserName, ToUserName: U_String);
  procedure Do_User_Close(Sender: TC40_UserDB_Client;
    UserName, ToUserName: U_String);
  procedure Do_User_Request_Friend(Sender: TC40_UserDB_Client;
    FromUserName, DestFriendUserName, Msg: U_String);
  procedure Do_User_Kick(Sender: TC40_UserDB_Client;
    UserName: U_String);
end;

// 设置事件接口
GetUserDBClient.ON_C40_UserDB_Client_Notify := TMyIMHandler.Create;
```

#### 8.2 文件系统服务（FS/FS2/FS3）

**FS 1.0**：

```pascal
// 服务端
BuildDependNetwork('DP|FS@SafeCheckTime=5000');

// 客户端：上传
GetFSClient.FS_PostFile_P('test', stream, True,
  procedure(Sender: TC40_FS_Client; info: U_String)
  begin
    DoStatus('上传完成，MD5: ' + info);
  end);

// 下载
GetFSClient.FS_GetFile_P(False, 'test',
  procedure(Sender: TC40_FS_Client; stream: TMS64; Token: U_String; Successed: Boolean)
  begin
    if Successed then DoStatus('下载完成');
  end);

// 其他方法
FS_GetFileMD5C/M/P     // 获取文件 MD5
FS_RemoveFile          // 删除文件
FS_SizeC/M/P           // 获取文件大小
FS_SearchC/M/P         // 搜索文件
```

**FS 2.0（增强）**：

| 新增方法 | 说明 |
| :--- | :--- |
| `FS2_CheckMD5AndFastCopyC/M/P` | 检查 MD5 并快速复制 |
| `FS2_PostFile(UsedCache, ...)` | 上传（支持缓存） |
| `FS2_SearchMultiMD5C/M/P` | 批量 MD5 查询 |
| `FS2_GetMD5FilesC/M/P` | 获取 MD5 对应的文件列表 |
| `FS2_UpdateFileTime` | 更新文件时间 |
| `FS2_UpdateFileRef` / `FS2_IncFileRef` | 更新/增加引用计数 |
| `FS2_PoolFragC/M/P` | 遍历所有文件片段 |

**FS 3.0（轻量级）**：

```pascal
// 服务端
BuildDependNetwork('DP|FS3');

// 上传（带生命周期）
GetFS3Client.Post_File_P('demo', umlNow(), 30.0, stream, True,
  procedure(Sender: TC40_FS3_Client; Bridge: TC40_FS3_Client_Post_File_Bridge; Successed: Boolean)
  begin
    // 文件 30 天后过期
  end);

// 下载（指定范围）
GetFS3Client.Get_File_P('demo', 0, 0, outputStream,
  procedure(Sender: TC40_FS3_Client; Stream: TCore_Stream; MD5: TMD5; Successed: Boolean)
  begin
    // 处理数据
    DisposeObject(Stream);
  end);

// 文件列表
GetFS3Client.Get_File_List_P('', 0,
  procedure(Sender: TC40_FS3_Client; arry: TC40_FS3_Client_File_List_Array)
  begin
    for var info in arry do
      DoStatus('%s size:%s', [info.File_Name.Text, umlSizeToStr(info.File_Size).Text]);
  end);
```

#### 8.3 网络变量服务（Var）

```pascal
// 服务端
BuildDependNetwork('DP|var');

// 客户端
function GetVarClient: TC40_Var_Client;

// 初始化变量池
GetVarClient.NM_Init('MyPool', True, nil);

// 设置变量
GetVarClient.NM_Change('MyPool', 'counter', 100);
GetVarClient.NM_Change('MyPool', 'message', 'Hello');

// 读取变量
GetVarClient.NM_GetValueP('MyPool', ['counter', 'message'],
  procedure(Sender: TC40_Var_Client; NM: TNumberModule)
  begin
    DoStatus('counter = ' + NM['counter'].AsString);
  end);

// 执行脚本
GetVarClient.NM_ScriptP('MyPool', ['x=10; y=20; result=x+y;'],
  procedure(Sender: TC40_Var_Client; Result: TExpressionValueVector)
  begin
    DoStatus('结果: ' + ExpressionValueVectorToStr(Result).Text);
  end);

// 临时变量池（超时自动销毁）
GetVarClient.NM_InitAsTemp('TempPool', 60000, True, nil);

// 其他方法
NM_Remove, NM_RemoveKey, NM_Open, NM_Close, NM_CloseAll, NM_Keep, NM_Save, NM_Search, NM_SearchAndRunScript
```

#### 8.4 日志数据库服务（Log DB）

```pascal
// 服务端
BuildDependNetwork('DP|Log@LogDBRecycleMemory=5000');

// 客户端
function GetLogClient: TC40_Log_DB_Client;

// 写入日志
GetLogClient.PostLog('my_log_db', '事件描述', '详细信息');

// 查询日志
GetLogClient.QueryLogP('my_log_db', StartTime, EndTime,
  procedure(Sender: TC40_Log_DB_Client; LogDB: string; arry: TArrayLogData)
  begin
    for var log in arry do
      DoStatus(log.Log1 + ': ' + log.Log2);
  end);

// 启用实时监控
GetLogClient.ON_C40_Log_DB_Client_Interface := TMyLogHandler.Create;
GetLogClient.Enabled_LogMonitor(True);

// 其他方法
GetLogDB, CloseDB, RemoveDB, QueryAndRemoveLog, RemoveLog
```

#### 8.5 键值存储服务（TEKeyValue）

```pascal
// 服务端
BuildDependNetwork('DP|TEKeyValue');

// 客户端
function GetTEKVClient: TC40_TEKeyValue_Client;

// 设置值（Variant 类型）
GetTEKVClient.SetValue('db', 'section', 'key', 123);

// 设置值（字符串类型）
GetTEKVClient.SetTextValue('db', 'section', 'key', 'value');

// 读取值
GetTEKVClient.GetTextValue_P('db', 'section', 'key', '',
  procedure(Sender: TC40_TEKeyValue_Client; Value: U_String)
  begin
    DoStatus('key = ' + Value);
  end);

// 获取 Section 所有键
GetTEKVClient.GetTextKey_P('db', 'section',
  procedure(Sender: TC40_TEKeyValue_Client; arry: U_StringArray)
  begin
    for var key in arry do DoStatus(key);
  end);

// 搜索
GetTEKVClient.SearchTE_P('my_*', '', '', True, 100,
  procedure(Sender: TC40_TEKeyValue_Client; arry: TC40_TEKeyValue_Client_SearchTE_Result_Array)
  begin
    for var r in arry do DoStatus(r.name);
  end);

// 其他方法
Rebuild, SetTE, MergeTE, RemoveTE, ExistsTE, ExistsSection, ExistsKey, RemoveSection, RemoveKey
```

#### 8.6 随机种子服务（RandSeed）

```pascal
// 服务端
BuildDependNetwork('DP|RandSeed');

// 客户端
function GetRandSeedClient: TC40_RandSeed_Client;

// 申请随机数
GetRandSeedClient.MakeSeed_P('my_group', 1000, 9999,
  procedure(sender: TC40_RandSeed_Client; Seed: UInt32)
  begin
    DoStatus('随机数: ' + IntToStr(Seed));
  end);

// 释放随机数
GetRandSeedClient.RemoveSeed('my_group', seed_value);
```

#### 8.7 XNAT 内网穿透

**服务端（配置中心）**：

```pascal
RegisterC40('MY_XNAT', TC40_XNAT_Service_Tool, TC40_XNAT_Client_Tool);

with TC40_PhysicsService.Create('0.0.0.0', 8397, TPhysicsServer.Create) do
begin
  BuildDependNetwork('MY_XNAT@XNAT_Host:127.0.0.1,XNAT_Port:9911');
  StartService;
end;
```

**客户端（映射本地服务）**：

```pascal
// 连接 XNAT 配置服务
C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel('127.0.0.1', 8397, 'MY_XNAT', nil);

C40_ClientPool.WaitConnectedDoneP('MY_XNAT',
  procedure(States: TC40_Custom_ClientPool_Wait_States)
  var
    XNAT_Cli: TC40_XNAT_Client_Tool;
  begin
    XNAT_Cli := States[0].Client_ as TC40_XNAT_Client_Tool;

    // 添加映射：外部 8888 → 本地服务
    XNAT_Cli.Add_XNAT_Mapping(True, 8888, 'test', 5000);
    XNAT_Cli.Open_XNAT_Tunnel;

    // 创建虚拟服务
    XNAT_Cli.Build_Physics_ServiceP('test', 1000,
      procedure(Sender: TC40_XNAT_Client_Tool; Service: TXNAT_MappingOnVirutalService)
      begin
        with TC40_PhysicsService.Create('127.0.0.1', 8888, Service) do
        begin
          BuildDependNetwork('DP');
          StartService;
        end;
      end);
  end);
```

---

### 第9章 高级特性

#### 9.1 事件接口 IC40_PhysicsTunnel_Event

```pascal
TMyEventHandler = class(TCore_InterfacedObject, IC40_PhysicsTunnel_Event)
  procedure C40_PhysicsTunnel_Connected(Sender: TC40_PhysicsTunnel);
  procedure C40_PhysicsTunnel_Disconnect(Sender: TC40_PhysicsTunnel);
  procedure C40_PhysicsTunnel_Build_Network(Sender: TC40_PhysicsTunnel;
    Custom_Client_: TC40_Custom_Client);
  procedure C40_PhysicsTunnel_Client_Connected(Sender: TC40_PhysicsTunnel;
    Custom_Client_: TC40_Custom_Client);
end;

// 使用
C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(addr, port, depend, TMyEventHandler.Create);
```

#### 9.2 自动部署泛型类

```pascal
// 基础用法
TC40_Auto_Deployment_Client<TMyClient>.Create_P(
  procedure(var sender: TMyClient)
  begin
    // sender 已就绪
  end);

// 带变量引用
var
  MyClient: TMyClient;
begin
  TC40_Auto_Deployment_Client<TMyClient>.Create('MyService', MyClient);
end;

// 三种回调风格
TC40_Auto_Deployment_Client<TMyClient>.Create_C(OnReady_C);
TC40_Auto_Deployment_Client<TMyClient>.Create_M(OnReady_M);
TC40_Auto_Deployment_Client<TMyClient>.Create_P(OnReady_P);
```

#### 9.3 等待多个服务就绪

```pascal
C40_ClientPool.WaitConnectedDoneP('DP|UserDB|FS',
  procedure(States: TC40_Custom_ClientPool_Wait_States)
  begin
    for var State in States do
      DoStatus(State.ServiceTyp_ + ' 就绪');
  end);
```

#### 9.4 控制台命令注册

```pascal
// 在服务或客户端中注册控制台命令
function MyConsoleCommand(var OP_Param: TOpParam): Variant;
begin
  DoStatus('执行自定义命令');
  Result := True;
end;

// 注册
Register_ConsoleCommand('mycmd', '我的自定义命令').OnEvent_M := MyConsoleCommand;
```

#### 9.5 负载均衡与优化连接

```pascal
// 搜索最小负载服务
C40_PhysicsTunnelPool.SearchServiceAndOptimizeConnection(
  '127.0.0.1', 8387, 'MyService', nil);

// 连接所有实例（全连接）
C40_PhysicsTunnelPool.SearchServiceAndBuildConnection(
  '127.0.0.1', 8387, 'MyService', nil);
```

---

### 第10章 控制台与调试

#### 10.1 C40_Execute_Main_Loop

```pascal
StatusThreadID := False;  // 禁用状态线程
C40_Execute_Main_Loop;    // 进入主循环
```

#### 10.2 内置控制台命令

| 命令 | 说明 | 示例 |
| :--- | :--- | :--- |
| `Help` | 显示帮助 | `Help` |
| `Exit` | 退出 | `Exit` |
| `Service` / `Server` | 显示服务信息 | `Service` / `Service(192.168.1.1)` |
| `Tunnel` / `Client` | 显示隧道信息 | `Tunnel` / `Tunnel(127.0.0.1,8387)` |
| `RegInfo` | 注册信息 | `RegInfo` |
| `KillNet` | 终止网络 | `KillNet(127.0.0.1,8387)` |
| `C4_Clean` | 清理所有 | `C4_Clean` |
| `Quiet` / `SetQuiet` | 静默模式 | `Quiet(True)` |
| `Instance_Info` | 实例状态 | `Instance_Info` |
| `HPC_Thread_Info` | HPC 线程 | `HPC_Thread_Info` |
| `ZDB2_Info` | ZDB2 引擎 | `ZDB2_Info` |
| `Service_CMD_Info` | 服务命令统计 | `Service_CMD_Info` |
| `Client_Statistics_Info` | 客户端统计 | `Client_Statistics_Info` |
| `Save_All_C4Service_Config` | 保存服务配置 | `Save_All_C4Service_Config` |

#### 10.3 调试开关

```pascal
// 关闭静默模式
C40_QuietMode := False;

// 启用实例跟踪
Print_Intermediate_Instance_Status := True;
Print_Tracking_Delay_Free := True;

// 设置单个实例静默
Set_Instance_QuietMode(PhysicsTunnel, True);
```

---

### 第11章 常见模式与最佳实践

#### 11.1 服务端部署模式

```pascal
// 单一服务
BuildDependNetwork('DP');

// 组合服务
BuildDependNetwork('DP|UserDB|FS2|Var|Log|TEKeyValue');

// 带参数
BuildDependNetwork('UserDB@SafeCheckTime=5000|FS2@CacheSize=1024');
```

#### 11.2 客户端连接模式

```pascal
// 方式1：直接连接
C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(addr, port, depend, nil);

// 方式2：搜索并优化连接
C40_PhysicsTunnelPool.SearchServiceAndOptimizeConnection(addr, port, depend, nil);

// 方式3：从服务信息创建
var info: TC40_Info;
C40_PhysicsTunnelPool.GetOrCreatePhysicsTunnel(info, depend, nil);
```

#### 11.3 认证集成模式

```pascal
// VirtualAuth + UserDB 集成
procedure TMyVA_Service.DoUserReg_Event(...);
var
  tmp: TTemp_Reg_Class;
begin
  if UserDB_Client = nil then Exit;
  tmp := TTemp_Reg_Class.Create;
  tmp.RegIO := RegIO;
  UserDB_Client.Usr_RegM(RegIO.UserID, RegIO.Passwd, tmp.Do_Usr_Reg);
end;

// 使用临时桥接类处理异步回调
TTemp_Reg_Class = class
  RegIO: TVirtualRegIO;
  procedure Do_Usr_Reg(Sender: TC40_UserDB_Client; State: Boolean; info: string);
end;
```

#### 11.4 IM 系统模式

```pascal
// 1. 用户登录时记录在线会话
// 2. 发送消息时查找目标用户的所有在线会话
// 3. 广播消息到所有会话（多设备支持）
// 4. 用户断开时清理会话

function SearchIOByUserID(UserID: U_String): TList;
begin
  Result := TList.Create;
  for IO in AllIOs do
    if IO.UserID = UserID then
      Result.Add(IO);
end;
```

#### 11.5 性能调优

```pascal
// 调整安全检查间隔
C40_SafeCheckTime := 60000;  // 60 秒

// 调整重连延迟
C40_PhysicsReconnectionDelayTime := 3.0;  // 3 秒

// 调整超时
C40_PhysicsServiceTimeout := 30 * 60 * 1000;  // 30 分钟
C40_PhysicsTunnelTimeout := 30 * 60 * 1000;   // 30 分钟

// 启用静默模式
C40_QuietMode := True;
```

---

## 第三部分：速查手册

### 第12章 快速参考

#### 12.1 全局变量速查

| 变量 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `C40_QuietMode` | `Boolean` | `False` | 静默模式 |
| `C40_SafeCheckTime` | `TTimeTick` | `45 * 1000` | 安全检查间隔 |
| `C40_PhysicsReconnectionDelayTime` | `Double` | `5.0` | 重连延迟（秒） |
| `C40_UpdateServiceInfoDelayTime` | `TTimeTick` | `1000` | DP 更新延迟 |
| `C40_PhysicsServiceTimeout` | `TTimeTick` | `15 * 60 * 1000` | 服务超时 |
| `C40_PhysicsTunnelTimeout` | `TTimeTick` | `15 * 60 * 1000` | 隧道超时 |
| `C40_KillDeadPhysicsConnectionTimeout` | `TTimeTick` | `60 * 1000` | 死连接清理超时 |
| `C40_KillIDCFaultTimeout` | `TTimeTick` | `7 * 24 * 60 * 60 * 1000` | IDC 故障超时 |
| `C40_EnablePerServiceDirectory` | `Boolean` | `True` | 启用服务子目录 |
| `C40_RootPath` | `U_String` | 当前目录 | 根路径 |
| `C40_Password` | `SystemString` | `'DTC40@ZSERVER'` | P2PVM 密码 |
| `C40_PhysicsClientClass` | `TZNet_ClientClass` | `TPhysicsClient` | 物理客户端类 |

#### 12.2 全局函数速查

| 函数 | 说明 |
| :--- | :--- |
| `C40Progress(sleep: Integer)` | 主进度循环 |
| `C40Progress` | 主进度循环（1ms 休眠） |
| `C40_Online_DP: TC40_Dispatch_Client` | 获取在线 DP |
| `C40SetQuietMode(Quiet: Boolean)` | 设置静默模式 |
| `C40WriteConfig(HS: THashStringList)` | 写入配置 |
| `C40ReadConfig(HS: THashStringList)` | 读取配置 |
| `C40ResetDefaultConfig` | 重置默认配置 |
| `C40Clean` | 清理所有资源 |
| `C40Clean_Service` | 仅清理服务端 |
| `C40Clean_Client` | 仅清理客户端 |
| `C40PrintRegistation` | 打印注册信息 |
| `C40ExistsPhysicsNetwork(addr, port): Boolean` | 检查物理网络 |
| `C40_Get_Physics_Connected_Num: Integer` | 获取物理连接数 |
| `C40_Get_Physics_Netowork_Is_Inited_Num: Integer` | 获取已初始化网络数 |
| `C40RemovePhysics(addr, port, ...)` | 移除物理网络 |
| `C40RemovePhysics(Tunnel)` | 移除物理隧道 |
| `C40RemovePhysics(Service)` | 移除物理服务 |
| `C40CheckAndKillDeadPhysicsTunnel` | 清理死隧道 |
| `RegisterC40(typ, svcClass, cliClass): Boolean` | 注册服务类型 |
| `FindRegistedC40(typ): PC40_RegistedData` | 查找注册信息 |
| `GetRegisterClientTypFromClass(cls): U_String` | 获取客户端类型 |
| `GetRegisterServiceTypFromClass(cls): U_String` | 获取服务类型 |
| `Compare_C40_ServiceTyp(typ1, typ2): Boolean` | 比较服务类型 |
| `ExtractDependInfo(info): TC40_DependNetworkInfoArray` | 提取依赖信息 |
| `ResetDependInfoBuff(var arry)` | 重置依赖缓冲 |
| `Is_IPC_Addr(addr): Boolean` | 检查 IPC 地址 |
| `Get_Physics_Server_Class(addr): TZNet_ServerClass` | 获取物理服务类 |
| `Get_Physics_Client_Class(addr): TZNet_ClientClass` | 获取物理客户端类 |

#### 12.3 预注册服务类型

| 类型 | 服务类 | 客户端类 | 说明 |
| :--- | :--- | :--- | :--- |
| `DP` | `TC40_Dispatch_Service` | `TC40_Dispatch_Client` | 调度服务 |
| `NULL` | `TC40_Base_NULL_Service` | `TC40_Base_NULL_Client` | 空服务 |
| `NA` | `TC40_Base_NoAuth_Service` | `TC40_Base_NoAuth_Client` | 无认证 |
| `DNA` | `TC40_Base_DataStoreNoAuth_Service` | `TC40_Base_DataStoreNoAuth_Client` | 无认证+存储 |
| `VA` | `TC40_Base_VirtualAuth_Service` | `TC40_Base_VirtualAuth_Client` | 虚拟认证 |
| `DVA` | `TC40_Base_DataStoreVirtualAuth_Service` | `TC40_Base_DataStoreVirtualAuth_Client` | 虚拟认证+存储 |
| `D` | `TC40_Base_Service` | `TC40_Base_Client` | 内置认证 |
| `DD` | `TC40_Base_DataStore_Service` | `TC40_Base_DataStore_Client` | 内置认证+存储 |
| `UserDB` | `TC40_UserDB_Service` | `TC40_UserDB_Client` | 用户数据库 |
| `FS` | `TC40_FS_Service` | `TC40_FS_Client` | 文件系统 1.0 |
| `FS2` | `TC40_FS2_Service` | `TC40_FS2_Client` | 文件系统 2.0 |
| `FS3` | `TC40_FS3_Service` | `TC40_FS3_Client` | 文件系统 3.0 |
| `Var` | `TC40_Var_Service` | `TC40_Var_Client` | 网络变量 |
| `Log` | `TC40_Log_DB_Service` | `TC40_Log_DB_Client` | 日志数据库 |
| `TEKeyValue` | `TC40_TEKeyValue_Service` | `TC40_TEKeyValue_Client` | 键值存储 |
| `RandSeed` | `TC40_RandSeed_Service` | `TC40_RandSeed_Client` | 随机种子 |
| `Alias` | `TC40_Alias_Service` | `TC40_Alias_Client` | 别名服务 |

#### 12.4 常用回调类型

| 类型 | 说明 |
| :--- | :--- |
| `TOnState_C/M/P` | 状态回调（成功/失败） |
| `TOnStream_C/M/P` | 流数据回调 |
| `TOnConsole_C/M/P` | 控制台命令回调 |
| `TOnNotify_C/M/P` | 无参数通知回调 |
| `TOnDataNotify_C/M/P` | 数据通知回调 |
| `TOnIOState_C/M/P` | IO 状态回调 |
| `TOnIONotify_C/M/P` | IO 通知回调 |
| `TOn_C40_Custom_Client_EventC/M/P` | 客户端事件回调 |
| `TDCT40_OnQueryResultC/M/P` | 查询结果回调 |
| `TOn_C4_Help_Console_Command_C/M/P` | 控制台命令回调 |
| `TOnServiceInfoChange` | 服务信息变更回调 |
| `TOn_Client_Offline` | 客户端离线回调 |
| `TOn_VM_Client_Event` | VM 客户端事件回调 |

---

## 附录

### A. 示例项目索引

| 项目 | 说明 | 涉及模块 |
| :--- | :--- | :--- |
| `_1_DispatchSeed.dpr` | 基础调度服务 | DP |
| `_1_UserDB_serv.dpr` | UserDB 服务端 | UserDB |
| `_2_UserDB_Client.dpr` | UserDB 客户端 | UserDB |
| `_1_Auth_serv.dpr` | VirtualAuth 服务端 | VA |
| `_2_Auth_Client.dpr` | VirtualAuth 客户端 | VA |
| `_3_Auth_Client.dpr` | VirtualAuth 负载均衡 | VA, DP |
| `_1_FS_Service.dpr` | FS 服务端 | FS |
| `_2_FS_Client.dpr` | FS 客户端 | FS |
| `_1_FS2_Service.dpr` | FS2 服务端 | FS2 |
| `_2_FS2_Client.dpr` | FS2 客户端 | FS2 |
| `_17_C4_FS3_Demo.dpr` | FS3 演示 | FS3 |
| `_4_Var_Service.dpr` | Var 服务端 | Var |
| `_2_Var_Client.dpr` | Var 客户端 | Var |
| `_1_LOG_DB_Service.dpr` | Log DB 服务端 | Log |
| `_2_LOG_DB_Client.dpr` | Log DB 客户端 | Log |
| `_1_TEKeyValue_Serv.dpr` | TEKeyValue 服务端 | TEKeyValue |
| `_2_TEKeyValue_Cli.dpr` | TEKeyValue 客户端 | TEKeyValue |
| `_1_RandNum_Service.dpr` | RandSeed 服务端 | RandSeed |
| `_2_RandNum_Client.dpr` | RandSeed 客户端 | RandSeed |
| `_1_XNAT_Mapping_Service.dpr` | XNAT 配置服务 | XNAT |
| `_2_XNAT_Mapping_Client_DP.dpr` | XNAT 客户端 | XNAT, DP |
| `_2_VM_Auth_IM_serv.dpr` | IM 服务端 | VA, UserDB |
| `_3_Auth_IM_Client.dpr` | IM 客户端 | VA |
| `C4_Auto_Deployment_Server.dpr` | 自动部署服务端 | AutoDeploy |
| `C4_Auto_Deployment_Client.dpr` | 自动部署客户端 | AutoDeploy |
| `C4_For_Android_HelloWorld.dpr` | Android 示例 | C4 |
| `C4_For_Android_Server.dpr` | Android 服务端 | C4 |
| `C4_VAR_Tech_Demo_Serv.dpr` | Var 技术演示服务端 | Var |
| `C4_VAR_Tech_Demo_Cli.dpr` | Var 技术演示客户端 | Var |

### B. 常见问题

**Q: 物理隧道连接失败？**

检查目标地址/端口、防火墙、`C40_KillDeadPhysicsConnectionTimeout` 设置。

**Q: 依赖服务未就绪？**

使用 `C40_ClientPool.WaitConnectedDoneP` 等待服务就绪。

**Q: 服务未注册到 DP？**

确保调用 `UpdateToGlobalDispatch`，DP 服务正常运行，物理隧道已连接。

**Q: 内存泄漏？**

启用 `Print_Intermediate_Instance_Status := True`，使用 `Instance_Info` 和 `Compare_Instance_State` 命令排查。

---

*本指南基于 Z.Net.C4.pas 源码及配套示例项目整理，覆盖了从入门到精通再到速查的完整知识体系。如发现遗漏，请参照源码进行补充。*