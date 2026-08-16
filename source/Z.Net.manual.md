# Z.Net.pas 网络框架完全使用指南

> 基于 Z.Net.pas 核心库，覆盖从物联网设备到云服务器的全场景网络通信解决方案

---

## 前言：Z.Net 的设计哲学

Z.Net 是 ZServer4D 的技术重构与矩阵转移，其核心定位是**为 SaaS、p2pVM、IoT、大数据存储 IO 及现役项目群提供通信地基支持**。与传统的网络库不同，Z.Net 站在计算机机理的角度，以结构和算法为辅，从 ZDB2 大数据系统、现代泛型结构系统、高级线程控制系统三个维度全面提升服务器工作能力。

对于 Z.Net 而言，通信系统仅仅是一个接口，**服务器内部的运作才是关键**。Z.Net 不玩概念和设计，所有问题都使用最简单的方法解决：**算法 + 机制 + API = 解决问题**。

Z.Net 的应用场景覆盖：
- 通过 Web API 支持现代项目系统的数据处理中心
- IoT 和 AIoT 中的通信系统集成
- 创业项目中的大规模通信基础设施
- 超越常规的大数据存储与分析（PB 级数据量）
- 小型通信工具（文件上传下载管理、内网穿透、自动化部署）
- Z-AI 第六代监控数据中心后台

---

## 第一部分：核心架构概览

### 1.1 三层架构

Z.Net 采用分层设计，由三个核心模块构成流水线：

| 层级 | 说明 |
|------|------|
| **传输层 (Transport Layer)** | 直接与操作系统 Socket 交互，负责数据的发送与接收 |
| **协议层 (Protocol Layer)** | 负责数据的封包与解包，定义数据包的结构（Header + Body），自动处理粘包/半包问题 |
| **应用层 (Application Layer)** | 提供给开发者的接口，通过事件驱动或回调函数处理业务数据 |

### 1.2 核心类体系

```
TZNet (抽象基类)
├── TZNet_Server (服务端框架)
│   ├── TZNet_WithP2PVM_Server (P2PVM 虚拟服务端)
│   ├── TZNet_CustomStableServer (稳定会话服务端)
│   └── TZNet_StableServer (稳定会话服务端别名)
├── TZNet_Client (客户端框架)
│   ├── TZNet_WithP2PVM_Client (P2PVM 虚拟客户端)
│   ├── TZNet_CustomStableClient (稳定会话客户端)
│   └── TZNet_StableClient (稳定会话客户端别名)
├── TPeerIO (连接状态机 - 每个连接的核心)
├── TZNet_P2PVM (P2P 虚拟网络覆盖)
└── 双通道体系 (Double Tunnel)
    ├── TZNet_DoubleTunnelClient / TZNet_DoubleTunnelService
    ├── TZNet_DoubleTunnelClient_NoAuth / TZNet_DoubleTunnelService_NoAuth
    └── TZNet_DoubleTunnelClient_VirtualAuth / TZNet_DoubleTunnelService_VirtualAuth
```

---

## 第二部分：快速上手

### 2.1 最小服务端

```pascal
uses
  Z.Net, Z.Net.PhysicsIO, Z.Status, Z.Core, Z.DFE;

var
  Server: TPhysicsServer;  // TPhysicsServer = TZNet_Server + PhysicsIO
begin
  Server := TPhysicsServer.Create;
  
  // 注册一个控制台命令
  Server.RegisterConsole('echo').OnExecute := 
    procedure(Sender: TPeerIO; InData: string; var OutData: string)
    begin
      OutData := 'Echo: ' + InData;
    end;
  
  // 启动服务
  Server.StartService('0.0.0.0', 9818);
  
  // 主循环
  while True do
  begin
    Server.Progress;
    Sleep(1);
  end;
end;
```

### 2.2 最小客户端

```pascal
var
  Client: TPhysicsClient;
begin
  Client := TPhysicsClient.Create;
  
  // 异步连接
  Client.AsyncConnectP('127.0.0.1', 9818, 
    procedure(const cState: Boolean)
    begin
      if cState then
        DoStatus('连接成功');
    end);
  
  // 主循环
  while not Client.Connected do
  begin
    Client.Progress;
    Sleep(1);
  end;
  
  // 发送命令并接收响应
  Client.SendConsoleCmdP('echo', 'Hello World',
    procedure(Sender: TPeerIO; ResultData: string)
    begin
      DoStatus('响应: ' + ResultData);
    end);
end;
```

> **注意**：`TPhysicsServer` 和 `TPhysicsClient` 是基于 PhysicsIO 实现的便捷类，底层封装了 `TZNet_Server`/`TZNet_Client`。

---

## 第三部分：TPeerIO — 连接的核心

`TPeerIO` 是 Z.Net 中最核心的类，代表一条活跃的网络连接。每个 `TPeerIO` 实例管理着该连接的全部状态和操作。

### 3.1 连接生命周期

| 阶段 | 服务端事件 | 客户端事件 |
|------|-----------|-----------|
| 连接建立前 | `DoIOConnectBefore` | — |
| 连接建立后 | `DoIOConnectAfter` | `DoConnected` |
| 握手完成 | — | `CipherModelDone` |
| 连接断开 | `DoIODisconnect` | `DoDisconnect` |

### 3.2 用户自定义数据挂载

每个 `TPeerIO` 提供了**三层**用户数据存储机制：

```pascal
// 1. 简单指针和 Variant
Sender.UserData := Pointer;
Sender.UserValue := Variant;

// 2. 键值存储（懒加载）
Sender.UserVariants['session_id'] := 'abc123';
Sender.UserObjects['cache'] := TMyObject.Create;
Sender.UserAutoFreeObjects['temp'] := TMyTempObject.Create; // 自动释放

// 3. 专用扩展对象（推荐）
type
  TMySession = class(TPeer_IO_User_Define)
  public
    UserID: string;
    LoginTime: TDateTime;
    DataCache: TDictionary<string, Variant>;
  end;

// 在服务端设置工厂类
Server.PeerIOUserDefineClass := TMySession;

// 在命令中访问
var Session := Sender.UserDefine as TMySession;
```

### 3.3 连接状态检测

```pascal
// 检查连接是否繁忙
if Sender.IOBusy then
  DoStatus('连接正在处理数据');

// 获取最后通信时间
var idleTime := Sender.NoneCommunicationTime;
if idleTime > 30000 then
  Sender.DelayClose;  // 30秒无通信则断开

// 空闲回调
Sender.IO_IDLE_TraceM(MyData, 
  procedure(Data: TCore_Object)
  begin
    // 连接变为空闲时执行
  end);
```

---

## 第四部分：命令系统（Command System）

Z.Net 提供了**六种**命令类型，覆盖从简单文本到大数据传输的所有场景。

### 4.1 命令类型一览

| 命令类型 | 注册方法 | 回调签名 | 适用场景 |
|---------|---------|---------|---------|
| Console | `RegisterConsole` | `(Sender, InData: string; var OutData: string)` | 简单文本命令 |
| ConsoleNotify | `RegisterConsoleNotify` | `(Sender: TPeerIO; InData: string)` | 单向文本通知 |
| Stream | `RegisterStream` | `(Sender: TPeerIO; InData, OutData: TDFE)` | 结构化数据交换 |
| StreamNotify | `RegisterStreamNotify` | `(Sender: TPeerIO; InData: TDFE)` | 单向结构化数据 |
| BigStream | `RegisterBigStream` | `(Sender: TPeerIO; InData: TCore_Stream; Total, Complete: Int64)` | 大文件/数据流传输 |
| CompleteBuffer | `RegisterCompleteBuffer` | `(Sender: TPeerIO; InData: PByte; DataSize: NativeInt)` | 原子数据块 |

### 4.2 TDFE — 结构化数据帧

`TDFE` (Data Frame Exchange) 是 Z.Net 的核心序列化格式，支持任意数据类型的帧序列，可压缩/加密，能与 JSON 互转。

```pascal
// 编码
var d := TDFE.Create;
d.WriteString('username');
d.WriteInteger(12345);
d.WriteFloat(3.14159);
d.WriteStream(TMemoryStream.Create);
d.WriteJson(TZ_JsonObject.Create);

// 发送
Client.SendStreamCmd('user_info', d);

// 解码（服务端）
procedure OnUserInfo(Sender: TPeerIO; InData, OutData: TDFE);
var
  name: string;
  id: Integer;
  pi: Double;
begin
  name := InData.Reader.ReadString;
  id := InData.Reader.ReadInteger;
  pi := InData.Reader.ReadFloat;
  // 处理数据...
end;
```

### 4.3 三种调用方式

```pascal
// 1. 无回调（Fire-and-Forget）
Client.SendConsoleNotifyCmd('log', 'user logged in');

// 2. 异步回调（推荐）
Client.SendConsoleCmdP('query', 'SELECT * FROM users',
  procedure(Sender: TPeerIO; Result: string)
  begin
    ProcessResult(Result);
  end);

// 3. 同步阻塞（谨慎使用，会阻塞当前线程）
var Result := Client.WaitSendConsoleCmd('query', 'SELECT *', 5000);
```

### 4.4 高级命令类型

Z.Net 还提供了针对高性能场景的优化命令：

| 命令类型 | 说明 |
|---------|------|
| `RegisterCompleteBuffer_StreamNotify` | 完整缓冲流通知，比传统 StreamNotify 性能更高 |
| `RegisterCompleteBuffer_Asynchronous_StreamNotify` | 异步解码版本，不阻塞主循环 |
| `RegisterCompleteBuffer_NoWait_Stream` | 无等待流命令，响应通过回调异步返回 |
| `RegisterCompleteBuffer_NoWait_Stream_Thread` | 强制在后台线程执行的版本 |
| `RegisterCompleteBuffer_NoWait_Bridge_Stream` | 支持 Pause/Resume 的桥接流命令 |

---

## 第五部分：四种数据传输模式

### 5.1 Console 模式（文本命令）

适用于简单的文本交互、管理命令、日志等。

```pascal
// 服务端注册
Server.RegisterConsole('ping').OnExecute := 
  procedure(S: TPeerIO; I: string; var O: string)
  begin
    O := 'pong';
  end;

// 客户端发送
Client.SendConsoleCmdP('ping', 'hello', 
  procedure(S: TPeerIO; R: string)
  begin
    DoStatus('响应: ' + R);
  end);
```

### 5.2 Stream 模式（结构化数据）

适用于 API 调用、数据库查询、业务数据交换等。

```pascal
// 服务端注册
Server.RegisterStream('calculate').OnExecute :=
  procedure(S: TPeerIO; InData, OutData: TDFE)
  var
    a, b: Integer;
  begin
    a := InData.Reader.ReadInteger;
    b := InData.Reader.ReadInteger;
    OutData.WriteInteger(a + b);
  end;

// 客户端发送
var d := TDFE.Create;
d.WriteInteger(10);
d.WriteInteger(20);
Client.SendStreamCmdP('calculate', d,
  procedure(S: TPeerIO; R: TDFE)
  begin
    DoStatus('结果: ' + IntToStr(R.Reader.ReadInteger));
  end);
```

### 5.3 BigStream 模式（大文件/数据流）

适用于文件传输、大块数据交换、流式处理等。

```pascal
// 服务端注册
Server.RegisterBigStream('upload').OnExecute :=
  procedure(S: TPeerIO; InData: TCore_Stream; Total, Complete: Int64)
  var
    fs: TFileStream;
  begin
    fs := TFileStream.Create('received.dat', fmCreate);
    fs.CopyFrom(InData, InData.Size);
    fs.Free;
    DoStatus('接收完成: %d/%d', [Complete, Total]);
  end;

// 客户端发送
var fs := TFileStream.Create('large_file.dat', fmOpenRead);
Client.SendBigStream('upload', fs, True);
```

### 5.4 CompleteBuffer 模式（原子数据块）

适用于需要完整接收才能处理的数据块，如加密数据、压缩包、完整消息等。

```pascal
// 服务端注册
Server.RegisterCompleteBuffer('image').OnExecute :=
  procedure(S: TPeerIO; InData: PByte; DataSize: NativeInt)
  begin
    // 直接处理完整数据块
    ProcessImage(InData, DataSize);
  end;

// 客户端发送
var buff := GetMemory(1024 * 1024);
FillBuffer(buff);
Client.SendCompleteBuffer('image', buff, 1024 * 1024, True);
```

---

## 第六部分：双通道（Double Tunnel）体系

双通道是 Z.Net 的核心创新之一，将**接收通道（RecvTunnel）**和**发送通道（SendTunnel）**分离，实现更高的吞吐量和更低的延迟。

### 6.1 架构原理

```
┌─────────────────────────────────────────────────────┐
│                  双通道客户端                        │
│  ┌─────────────┐    ┌─────────────┐               │
│  │ RecvTunnel  │    │ SendTunnel  │               │
│  │ (接收通道)   │    │ (发送通道)   │               │
│  └──────┬──────┘    └──────┬──────┘               │
│         │                  │                       │
│         └────────┬─────────┘                       │
│                  ▼                                 │
│         TZNet_DoubleTunnelClient                   │
└─────────────────────────────────────────────────────┘
```

### 6.2 三种认证模式

| 模式 | 类名 | 说明 |
|------|------|------|
| 无认证 | `TZNet_DoubleTunnelClient_NoAuth` / `TZNet_DoubleTunnelService_NoAuth` | 适用于内网或无需用户验证的场景 |
| 用户认证 | `TZNet_DoubleTunnelClient` / `TZNet_DoubleTunnelService` | 带用户注册/登录的完整认证体系 |
| 虚拟认证 | `TZNet_DoubleTunnelClient_VirtualAuth` / `TZNet_DoubleTunnelService_VirtualAuth` | 适用于 P2PVM 环境下的认证 |

### 6.3 客户端实现

```pascal
// 创建双通道客户端
RecvTunnel := TPhysicsClient.Create;
SendTunnel := TPhysicsClient.Create;
Client := TZNet_DoubleTunnelClient_NoAuth.Create(RecvTunnel, SendTunnel);
Client.RegisterCommand;

// 异步连接（自动完成双通道握手）
Client.AsyncConnectP('127.0.0.1', 9816, 9815,
  procedure(const cState: Boolean)
  begin
    if cState then
    begin
      // 合并两个通道
      Client.TunnelLinkP(
        procedure(const tState: Boolean)
        begin
          if tState then
            DoStatus('双通道链接成功');
        end);
    end;
  end);

// 通过发送通道发送命令
Client.SendTunnel.SendConsoleNotifyCmd('hello', 'world');
```

### 6.4 服务端实现

```pascal
type
  TMyService = class(TZNet_DoubleTunnelService_NoAuth)
  protected
    procedure UserLinkSuccess(UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); override;
    procedure UserOut(UserDefineIO: TService_RecvTunnel_UserDefine_NoAuth); override;
  end;

// 创建服务
RecvTunnel := TPhysicsServer.Create;
SendTunnel := TPhysicsServer.Create;
Service := TMyService.Create(RecvTunnel, SendTunnel);
Service.RegisterCommand;

RecvTunnel.StartService('0.0.0.0', 9815);
SendTunnel.StartService('0.0.0.0', 9816);
```

---

## 第七部分：P2PVM — 虚拟网络覆盖

P2PVM（Peer-to-Peer Virtual Machine）是 Z.Net 的**虚拟网络覆盖层**，在一条物理连接上构建虚拟二层网络，支持挂载多个逻辑服务端/客户端，实现 NAT 穿透和服务隔离。

### 7.1 核心概念

```
物理连接 (Physics Connection)
    └── P2PVM 隧道 (TZNet_P2PVM)
        ├── 虚拟服务端 A (TZNet_WithP2PVM_Server)
        │   └── 虚拟客户端连接
        ├── 虚拟服务端 B (TZNet_WithP2PVM_Server)
        │   └── 虚拟客户端连接
        └── 虚拟客户端 C (TZNet_WithP2PVM_Client)
            └── 连接到远程虚拟服务端
```

### 7.2 服务端挂载 P2PVM

```pascal
// 物理服务端
PhysicsServer := TPhysicsServer.Create;
PhysicsServer.VMInterface := Self;  // 实现 IZNet_VMInterface

// 虚拟服务端
VMServer := TZNet_WithP2PVM_Server.Create;
VMServer.StartService('::', 11139);  // 在虚拟网络中监听

// 在物理连接建立时挂载虚拟服务端
procedure TMyForm.p2pVMTunnelOpenBefore(Sender: TPeerIO; p2pVMTunnel: TZNet_P2PVM);
begin
  p2pVMTunnel.InstallLogicFramework(VMServer);
end;
```

### 7.3 客户端挂载 P2PVM

```pascal
// 物理客户端
PhysicsClient := TPhysicsClient.Create;

// 虚拟客户端
VMClient := TZNet_WithP2PVM_Client.Create;
VMClient.AsyncConnect('::', 11139);

// 或者使用自动化 P2PVM（推荐）
PhysicsClient.AutomatedP2PVMClientBind.AddClient(VMClient, '::', 1);
PhysicsClient.AutomatedP2PVMClient := True;
PhysicsClient.AutomatedP2PVMAuthToken := 'my_token';
```

### 7.4 P2PVM 克隆（多虚拟连接）

```pascal
// 在单个物理连接上创建多个虚拟客户端
var Bridge := VMClient.CloneConnectM(
  procedure(NewClient: TZNet_WithP2PVM_Client)
  begin
    DoStatus('克隆连接已建立');
    NewClient.SendConsoleNotifyCmd('hello', 'from clone');
  end);
```

---

## 第八部分：稳定会话层（StableIO）

StableIO 提供**会话持久化**能力：即使物理连接断开，逻辑会话依然存活，并在重连后自动恢复。

### 8.1 工作原理

```
物理连接断开 → StableIO 进入离线状态（保留会话数据）
    ↓
物理连接重连 → StableIO 自动恢复（会话状态不变）
```

### 8.2 服务端使用

```pascal
// 物理服务端
PhysicsServer := TPhysicsServer.Create;

// 包装为稳定会话服务端
StableServer := TZNet_StableServer.Create;
StableServer.OwnerIOServer := PhysicsServer;
StableServer.OfflineTimeout := 5 * 60 * 1000;  // 5分钟离线超时

// 所有命令注册在 StableServer 上
StableServer.RegisterConsole('echo').OnExecute := MyHandler;
StableServer.StartService('0.0.0.0', 8080);
```

### 8.3 客户端使用

```pascal
// 物理客户端
PhysicsClient := TPhysicsClient.Create;

// 包装为稳定会话客户端
StableClient := TZNet_StableClient.Create;
StableClient.OwnerIOClient := PhysicsClient;
StableClient.AutomatedConnection := True;  // 自动重连

StableClient.AsyncConnectC('127.0.0.1', 8080,
  procedure(Ok: Boolean)
  begin
    if Ok then DoStatus('稳定会话已建立');
  end);
```

---

## 第九部分：安全与加密

### 9.1 三种安全模式

```pascal
// 1. 最大性能模式（无加密、无压缩）
Server.SwitchMaxPerformance;

// 2. 默认模式（快速加密 + 并行加密）
Server.SwitchDefaultPerformance;

// 3. 最大安全模式（强加密 + MD5 哈希 + 压缩）
Server.SwitchMaxSecurity;
```

### 9.2 支持的加密算法

Z.Net 支持 DES、Blowfish、LBC、LQC、RC6、Serpent、Mars、Rijndael、TwoFish、AES128/192/256 等多种算法。每个连接可独立选择加密方案。

### 9.3 用户认证（双通道）

```pascal
// 服务端：重写认证方法
type
  TMyService = class(TZNet_DoubleTunnelService)
  protected
    procedure UserAuth(Sender: TPeerIO; const UserID, Passwd: string; var Accept: Boolean); override;
  end;

procedure TMyService.UserAuth(Sender: TPeerIO; const UserID, Passwd: string; var Accept: Boolean);
begin
  Accept := ValidateUser(UserID, Passwd);  // 自定义验证逻辑
end;

// 客户端：登录
Client.UserLoginP('admin', '123456',
  procedure(const State: Boolean)
  begin
    if State then DoStatus('登录成功');
  end);
```

### 9.4 数据完整性校验

```pascal
// 生成哈希
var Code: TBytes;
Sender.GenerateHashCode(hsSHA256, @Data[0], DataSize, Code);

// 验证哈希
if Sender.VerifyHashCode(hsSHA256, @Data[0], DataSize, Code) then
  DoStatus('数据完整性验证通过');
```

---

## 第十部分：性能优化

### 10.1 关键性能参数

| 参数 | 属性 | 默认值 | 说明 |
|------|------|--------|------|
| 发送刷新块大小 | `SendFlushSize` | 32KB | 发送缓冲分块大小 |
| 每循环最大命令数 | `Per_Progress_Loop_Limit` | 500 | 防止单次循环过长 |
| 物理片段提取上限 | `Extract_Physics_Fragment_Max_Size` | 1MB | 每循环提取上限 |
| 最大完整缓冲大小 | `MaxCompleteBufferSize` | 64MB | 超过则拒绝 |
| 进度最大延迟 | `ProgressMaxDelay` | 1000ms | 防止主线程卡顿 |
| 空闲超时 | `IdleTimeOut` | 0（不检测） | 连接空闲断开时间 |

### 10.2 大流与完整缓冲优化

```pascal
// 启用磁盘交换（减少内存占用）
Server.BigStreamMemorySwapSpace := True;
Server.BigStreamSwapSpaceTriggerSize := 1024 * 1024;  // 1MB

// 完整缓冲压缩
Server.CompleteBufferCompressed := True;
Server.CompleteBufferCompressionCondition := 1024;  // 大于1KB才压缩
Server.CompleteBufferSwapSpace := True;
```

### 10.3 并行处理

```pascal
// 并行加密
Server.UsedParallelEncrypt := True;

// 并行循环（在 HPC 线程中）
ParallelFor(0, 10000,
  procedure(pass: Integer)
  begin
    // 并行处理
  end);
```

### 10.4 序列包模型（可靠传输）

```pascal
// 启用序列包模型（适用于 UDP 或不稳定网络）
Server.SequencePacketActivted := True;

// 每个连接可单独配置
ClientIO.SequencePacketMTU := 1536;
ClientIO.SequencePacketLimitOwnerIOMemory := 100 * 1024 * 1024;  // 100MB
```

---

## 第十一部分：应用场景实战

### 11.1 常规 C/S 架构（企业管理软件）

```pascal
// 服务端
Server := TPhysicsServer.Create;
Server.RegisterStream('login').OnExecute := LoginHandler;
Server.RegisterStream('query').OnExecute := QueryHandler;
Server.RegisterBigStream('upload').OnExecute := UploadHandler;
Server.StartService('0.0.0.0', 8080);

// 客户端
Client := TPhysicsClient.Create;
Client.Connect('server.company.com', 8080);
Client.SendStreamCmdP('login', LoginData, OnLoginResult);
```

### 11.2 物联网（IoT）设备通信

```pascal
// 设备端（轻量级客户端）
DeviceClient := TPhysicsClient.Create;
DeviceClient.AsyncConnectP('mqtt.company.com', 1883,
  procedure(Ok: Boolean)
  begin
    if Ok then
    begin
      // 上报传感器数据
      var d := TDFE.Create;
      d.WriteFloat(Temperature);
      d.WriteFloat(Humidity);
      DeviceClient.SendStreamNotifyCmd('sensor_data', d);
    end;
  end);

// 服务端（高并发接入）
Server := TPhysicsServer.Create;
Server.MaxCompleteBufferSize := 1024 * 1024;  // IoT 数据包通常较小
Server.IdleTimeOut := 30000;  // 30秒无通信则断开
Server.RegisterStreamNotify('sensor_data').OnExecute :=
  procedure(S: TPeerIO; D: TDFE)
  begin
    StoreSensorData(S.PeerIP, D.Reader.ReadFloat, D.Reader.ReadFloat);
  end;
```

### 11.3 移动端应用（FMX 跨平台）

```pascal
// FMX 客户端（iOS/Android/Windows/macOS）
Client := TZNet_Client_Indy.Create;  // 或 TPhysicsClient
Client.AsyncConnectP(Host, Port,
  procedure(Ok: Boolean)
  begin
    if Ok then
      TThread.Queue(nil,
        procedure
        begin
          // 更新 UI
          StatusLabel.Text := '已连接';
        end);
  end);

// 在 Timer 中驱动 Progress
procedure TForm.Timer1Timer(Sender: TObject);
begin
  CheckThread;
  Client.Progress;
end;
```

### 11.4 内网穿透（XNAT）

```pascal
// 内网设备（被控端）
XCli := TXNATClient.Create;
XCli.Host := 'public.server.com';
XCli.Port := '7890';
XCli.AuthToken := '123456';
XCli.AddMapping('127.0.0.1', '80', 'web8000', 100);  // 映射本地 Web 服务
XCli.OpenTunnel;

// 公网服务器端（自动处理反向代理）
// 无需额外编码，XNAT 服务端自动处理
```

### 11.5 分布式大数据系统

```pascal
// 数据节点
DataNode := TPhysicsServer.Create;
DataNode.BigStreamMemorySwapSpace := True;
DataNode.CompleteBufferSwapSpace := True;
DataNode.RegisterBigStream('store_chunk').OnExecute := StoreChunkHandler;

// 调度中心（双通道）
Master := TZNet_DoubleTunnelService_NoAuth.Create(Recv, Send);
Master.RegisterStream('query').OnExecute := DistributedQueryHandler;
```

### 11.6 实时聊天/消息推送

```pascal
// 服务端广播
Server.BroadcastConsoleNotifyCmd('new_message', MessageText);
Server.BroadcastStreamNotifyCmd('new_data', DataFrame);

// 或定向发送
Server.SendConsoleNotifyCmd(TargetClient, 'private_msg', Text);
```

---

## 第十二部分：调试与监控

### 12.1 日志系统

```pascal
// 添加日志钩子
AddDoStatusHook(Self,
  procedure(Text: SystemString; const ID: Integer)
  begin
    Memo.Lines.Add(Text);
  end);

// 静默模式（生产环境）
Server.QuietMode := True;

// 选择性打印
Server.PrintParams.Add('MyCommand', False);  // 不打印此命令的日志
```

### 12.2 统计信息

```pascal
// 读取统计
DoStatus('接收字节: ' + IntToStr(Server.Statistics[stReceiveSize]));
DoStatus('发送字节: ' + IntToStr(Server.Statistics[stSendSize]));
DoStatus('连接数: ' + IntToStr(Server.Statistics[stConnected]));

// 命令统计
var Count := Server.CmdRecvStatistics['login'];
var MaxTime := Server.CmdMaxExecuteConsumeStatistics['query'];

// 全局实例池
ZNet_Instance_Pool.Print_Status;
ZNet_Instance_Pool.Print_Service_Statistics_Info;
```

### 12.3 连接调试

```pascal
// 打印所有已注册命令
Server.PrintRegistedCMD;

// 获取连接状态
ClientIO.Print('连接信息');
ClientIO.PrintCommand('执行命令: %s', CmdName);

// 序列包状态
DoStatus(ClientIO.SequencePacketState);
```

---

## 第十三部分：常见问题与最佳实践

### 13.1 必须定期调用 Progress

```pascal
// ✅ 正确：在主循环中调用
while Running do
begin
  Server.Progress;
  Sleep(1);
end;

// ❌ 错误：不调用 Progress 将导致数据积压
```

### 13.2 善用异步回调，避免阻塞

```pascal
// ✅ 推荐：异步方式
Client.SendStreamCmdP('query', Data,
  procedure(S: TPeerIO; R: TDFE)
  begin
    ProcessResult(R);
  end);

// ❌ 避免：同步阻塞（会阻塞当前线程）
var R := Client.WaitSendStreamCmd('query', Data, 5000);
```

### 13.3 大文件传输使用 BigStream

```pascal
// ✅ 推荐：使用 BigStream
Client.SendBigStream('upload', FileStream, True);

// ❌ 避免：用 Stream 传输大文件（会消耗大量内存）
```

### 13.4 连接断开处理

```pascal
// 服务端：重写断开事件
procedure TMyService.UserOut(UserDefineIO: TService_RecvTunnel_UserDefine);
begin
  inherited;
  DoStatus('用户 ' + UserDefineIO.UserID + ' 已断开');
  CleanupUserSession(UserDefineIO.UserID);
end;

// 客户端：检测断开
if not Client.Connected then
begin
  DoStatus('连接已断开');
  Reconnect;
end;
```

### 13.5 内存管理

```pascal
// TDFE 需要手动释放
var d := TDFE.Create;
try
  d.WriteString('data');
  Client.SendStreamNotifyCmd('cmd', d);
finally
  d.Free;
end;

// 或使用 DisposeObject
DisposeObject(d);

// 批量释放
DisposeObject([d1, d2, d3]);
```

---

## 附录：核心类型速查

| 类型 | 说明 |
|------|------|
| `TZNet` | 所有网络框架的抽象基类 |
| `TZNet_Server` | 服务端框架 |
| `TZNet_Client` | 客户端框架 |
| `TPeerIO` | 连接状态机 |
| `TDFE` | 数据帧交换（序列化格式） |
| `TZNet_P2PVM` | P2P 虚拟网络 |
| `TZNet_DoubleTunnelClient/Service` | 双通道客户端/服务端 |
| `TZNet_StableServer/Client` | 稳定会话层 |
| `TPhysicsServer/Client` | PhysicsIO 实现的便捷类 |
| `TQueueState` | 命令队列状态枚举 |
| `TStatisticsType` | 统计指标枚举 |

---

> **参考资源**：
> - ZNet 官方仓库：[https://github.com/PassByYou888/ZNet](https://github.com/PassByYou888/ZNet)
> - 参考手册：[https://zpascal.net/ZNet_Manual_EN.pdf](https://zpascal.net/ZNet_Manual_EN.pdf)
> - Demo 程序位于 ZNet 仓库的 Demo 目录下

Z.Net 是一个从计算机机理角度设计的通信框架，其核心思想是**算法 + 机制 + API = 解决问题**。掌握 Z.Net 不仅仅是学会 API 调用，更是理解其背后的设计哲学——通信只是接口，服务器内部的运作才是关键。
