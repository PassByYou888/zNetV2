# Z.FP.Net CrossSocket 适配层最终知识手册

> **本文档整合了 CrossSocket 标准版与 FPC 移植版的深度技术差异分析，以及 Z.FP.Net 上层适配器（Client/Server）的完整知识。**  
> **目标读者**：开发者与 AI 辅助编程。  
> **核心结论**：Z.FP.Net.CrossSocket 是标准 `Z.Net.CrossSocket` 的 **FPC 编译器重构版**，深度整合 **Z.Core 基础库**，在 **并发模型、锁机制、内存管理、流控、跨平台稳定性** 上全面优于标准版，尤其适合 **IoT 物联网、嵌入式设备、高负载边缘计算** 场景。

---

## 1. 概述

### 1.1 定位

`Z.FP.Net.CrossSocket` 系列单元是 **Z.Net 框架** 针对 Free Pascal 编译器的 **物理传输适配层**。它包含：

- **底层异步 I/O 引擎**：`Z.FP.Net.CrossSocket`（及其平台实现 `Epoll` / `Kqueue` / `Iocp`）
- **Z.Net 框架适配器**：`Z.FP.Net.Client.CrossSocket` 和 `Z.FP.Net.Server.CrossSocket`

该适配层将 Z.Net 抽象的 `TZNet_Server` / `TZNet_Client` 接口桥接到 **CrossSocket 异步 I/O 模型**（基于 epoll、kqueue、IOCP），使 Z.Net 应用能够运行在纯异步、事件驱动的网络引擎之上，享受高并发、低延迟的跨平台网络服务。

### 1.2 与标准版的关系

| 项目 | 标准版（`Z.Net.CrossSocket`） | FPC 移植版（`Z.FP.Net.CrossSocket`） |
| :--- | :--- | :--- |
| **原始来源** | [winddriver/Delphi-Cross-Socket](https://github.com/winddriver/Delphi-Cross-Socket) | 基于同一代码库，**专门为 FPC 重构** |
| **编译器** | Delphi（Windows/macOS/Linux） | **Free Pascal**（+ Delphi 兼容） |
| **核心基础库** | Delphi RTL（`System.Classes`, `System.Generics.Collections`） | **Z.Core**（`TCritical`, `TAtomInt`, `TCompute`, `TBigList`, `Check_Soft_Thread_Synchronize`） |
| **设计目标** | 跨平台异步 I/O 引擎 | 在 FPC 环境下提供 **更高稳定性、更细粒度流控、更低资源占用** |

FPC 移植版并非简单的“翻译”，而是在 **并发模型、锁机制、连接生命周期、队列统计、线程管理** 五个关键层面进行了系统性重构，使其在 IoT 和服务器场景下表现更优。

---

## 2. 核心架构

```
┌─────────────────────────────────────────────────────────────┐
│  Z.Net 框架（TZNet_Server / TZNet_Client）                  │
│  └── 命令注册、协议解析、P2PVM、加密压缩                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Z.FP.Net.Server.CrossSocket / Z.FP.Net.Client.CrossSocket │
│  └── 适配器：TCrossSocketServer_PeerIO / Client_PeerIO     │
│       - 实现 TPeerIO 接口                                   │
│       - 管理发送队列（碎片合并、异步回调）                   │
│       - 统计队列字节数（FWriteBuffer_Size）                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Z.FP.Net.CrossSocket（引擎）                              │
│  ├── Z.FP.Net.CrossSocket.Base（接口与基类）               │
│  ├── Z.FP.Net.CrossSocket.Iocp   （Windows）               │
│  ├── Z.FP.Net.CrossSocket.Epoll  （Linux/Android）          │
│  └── Z.FP.Net.CrossSocket.Kqueue （BSD/macOS/iOS）         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Z.FP.Net.SocketAPI（跨平台系统调用封装）                   │
│  └── 使用 FPC 原生单元（BaseUnix, Sockets, netdb 等）      │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. 与标准 CrossSocket 的深度技术差异

### 3.1 编译器与基础库

| 项 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **编译器** | Delphi | **FPC**（同时兼容 Delphi） |
| **基础库** | Delphi RTL | **Z.Core**（统一跨平台基础库） |
| **字符串** | `string`（Delphi Unicode/Ansi） | `SystemString` / `U_String`（Z.PascalStrings） |
| **容器** | `TList<T>`, `TDictionary<TKey,TValue>` | `TBigList<T>`（支持回收池）, `TCriticalBigList` |
| **日志** | `OutputDebugString` / 自定 | `Z.Status.DoStatus`（钩子驱动） |

**技术意义**：Z.Core 提供了 **跨平台原子操作、统一临界区、线程池、软同步** 等基础设施，这些在标准 Delphi RTL 中要么缺失，要么实现不一致。FPC 移植版借此实现了 **行为一致性**。

### 3.2 锁机制

| 项 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **锁对象** | `System.TMonitor`（对象监视器） | `TCritical`（Z.Core） |
| **底层实现** | 操作系统临界区 | **可选自旋锁**（`SoftCritical` 宏）或临界区 |
| **锁回收** | 无 | **锁实例回收池**：销毁后复用底层句柄 |
| **原子操作** | `TInterlocked`（Delphi） | `AtomInc` / `AtomDec` / `TAtomInt`（统一跨平台） |

**技术意义**：`TCritical` 支持自旋模式，在多核 CPU 高竞争场景下减少上下文切换；锁回收池降低频繁创建/销毁锁的开销。

### 3.3 连接生命周期管理

| 机制 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **kqueue 引用计数** | `_AddRef` / `_Release`（每个事件） | **放弃引用计数**，使用 UID 查找 |
| **所有平台统一** | kqueue 特殊处理 | **IOCP/epoll/kqueue 均使用 UID 查找** |
| **连接关闭触发** | `shutdown` 触发事件释放引用 | `shutdown` 触发事件，移除字典条目 |
| **延迟释放** | 无统一机制 | `DelayFreeObject`（Z.Core）确保回调链完成后释放 |

**技术意义**：引用计数在极端并发下容易出现循环引用或提前释放。UID 查找将生命周期管理权交还给上层容器，降低了对象间耦合，也使三个平台的行为完全一致。

### 3.4 发送队列与流控

| 项 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **队列容器** | `TList<PSendItem>` | `TBigList<PSendItem>`（双向循环链表 + 回收池） |
| **队列统计** | 仅 `Count` | **新增 `FWriteBuffer_Size: Int64`**（原子操作追踪总字节数） |
| **队列操作** | `Add`, `Delete` | `Add` 复用回收节点，`Next` 高效删除 |
| **流控支持** | 需上层自行实现 | **提供 `WriteBuffer_State` 方法**返回队列数和字节数，便于背压控制 |

**技术意义**：`FWriteBuffer_Size` 是 **IoT 场景下的关键指标**——当网络带宽有限时，应用层可根据队列字节数主动暂停写入，避免内存耗尽。`TBigList` 的回收池在高频发送时减少内存分配次数。

### 3.5 线程模型

| 项 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **I/O 线程数** | `CPUCount * 2 + 1`（固定） | **`Get_Parallel_Granularity`**（Z.Core 全局配置，默认 CPU 数） |
| **线程创建** | `TThread.Create` | **`TCompute` 线程池**（自缩放） |
| **空闲回收** | 无 | **线程空闲超时自动退出**（默认 200ms） |
| **线程退出等待** | `while IO_Is_Busy do Sleep(1)` | `while IO_Is_Busy do Check_Soft_Thread_Synchronize(10, False)` |
| **软同步清理** | 无 | **析构时强制清理 RTL 同步队列**，避免死锁 |

**技术意义**：TCompute 线程池的自缩放特性在连接数波动大的 IoT 设备上尤其宝贵。`Check_Soft_Thread_Synchronize` 解决了 CrossSocket 在无 UI 应用（DLL、服务）中常见的 **线程无法退出** 问题。

### 3.6 错误处理与健壮性

| 场景 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **EMFILE（文件句柄耗尽）** | 支持（占位 `/dev/null`） | 支持，且保护临界区 |
| **发送失败回调** | 调用 `ACallback(False)` | 相同 + **原子递减 `FWriteBuffer_Size`** |
| **StopLoop 超时** | 可能无限等待 | 通过软同步驱动，避免死等 |
| **日志输出** | `_Log` 使用 `OutputDebugString` | **统一 `DoStatus`**，支持钩子转发到文件/控制台 |

### 3.7 跨平台适配层对比

| 单元 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **系统调用** | `Posix.SysSocket`, `Posix.UniStd` | `BaseUnix`, `Unix`, `Sockets`, `netdb`（FPC 原生） |
| **epoll** | `Z.Linux.epoll`（Delphi 声明） | `Z.FP.Net.Linux.epoll`（FPC 声明 + `eventfd` 实现） |
| **kqueue** | `Z.BSD.kqueue`（Delphi 声明） | `Z.FP.Net.BSD.kqueue`（FPC 声明 + `pipe` 实现） |
| **WinSock** | `Z.Net.Winsock2` / `Wship6` | `Z.FP.Net.Winsock2` / `Wship6`（FPC 兼容） |
| **SocketAPI** | `Z.Net.SocketAPI` | `Z.FP.Net.SocketAPI`（使用 FPC 的 `fpSocket` 等） |
| **POSIX 发送辅助** | `Z.Net.Posix.inc` | `Z.FP.Net.Posix.inc`（含 `MSG_NOSIGNAL` 差异） |

---

## 4. 上层适配器（Client / Server）

### 4.1 服务端适配器（`Z.FP.Net.Server.CrossSocket`）

#### 核心类
- `TZNet_Server_FP_CrossSocket`（继承 `TZNet_Server`）
- `TCrossSocketServer_PeerIO`（继承 `TPeerIO`，管理发送队列）

#### 关键属性
| 属性 | 类型 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- |
| `MaxConnection` | `Integer` | 20000 | 最大并发连接数 |
| `StartedService` | `Boolean` | - | 服务是否运行 |
| `driver` | `TDriverEngine` | - | 底层 CrossSocket 引擎 |
| `BindHost`, `BindPort` | 字符串 / Word | - | 当前绑定的地址/端口 |

#### 关键方法
- `StartService(Host, Port): Boolean`：同步启动监听，内部使用 `TListen_Backcall_Bridge_` 收集异步结果。
- `StopService`：关闭所有监听和连接。
- `Progress`：驱动 I/O 进度（继承自 `TZNet_Server`）。

#### 发送流程（重要）
1. 应用层调用 `SendConsoleCmd` 等 → Z.Net 封装为 `TQueueData`。
2. `Process_Send_Buffer` → `Write_IO_Buffer` 将数据追加到 `CurrentBuff`（碎片合并）。
3. `WriteBufferFlush` 将 `CurrentBuff` 入队，若 `Sending=False`，立即调用 `Context.SendBuf` 发起异步发送。
4. 发送完成回调 `SendBuffResult(Success)`：
   - 原子递减 `FWriteBuffer_Size`。
   - 若成功，从队列中取下一块继续发送；若失败，触发断开。
   - 队列为空时置 `Sending=False`。

#### 注意事项
- **同步阻塞命令不支持**：`WaitSendConsoleCmd` 和 `WaitSendStreamCmd` 直接抛出异常，请使用异步回调（`Send*CmdM/P`）。
- **`MaxConnection` 限制**：默认 20000，需根据系统调优。
- **发送队列可能无限增长**：建议通过 `WriteBuffer_State` 监控 `FWriteBuffer_Size` 并实施流控。

### 4.2 客户端适配器（`Z.FP.Net.Client.CrossSocket`）

#### 核心类
- `TZNet_Client_FP_CrossSocket`（继承 `TZNet_Client`）
- `TGlobalCrossSocketClientPool`（全局连接池，共享一个 `TDriverEngine`）
- `TCrossSocketClient_PeerIO`（继承 `TCrossSocketServer_PeerIO`，增加 `OwnerClient` 引用）

#### 关键特性
- **全局连接池**：所有客户端实例共享一个 CrossSocket 引擎，避免每个客户端独自创建 I/O 线程。
- **引用计数管理**：`CrossSocket_Instance_Num` 跟踪活跃客户端，归零时自动释放全局池。
- **同步连接（`Connect`）**：内部通过忙等 + `Check_Soft_Thread_Synchronize` 实现，超时 5 秒。
- **异步连接（`AsyncConnectC/M/P`）**：使用 `TAsync_Connect_Backcall_Bridge_` 对象桥接 FPC 回调。

#### 连接流程
1. `BuildAsyncConnect` 调用 `driver.Connect`，传入桥接对象。
2. 桥接对象 `Do_Async_Connect_Bakcall_` 在连接完成时触发：
   - 成功：创建 `TCrossSocketClient_PeerIO`，绑定到连接，调用 `DoConnected`。
   - 失败：若 `AutoReconnect=True` 则重试，否则触发 `TriggerDoConnectFailed`。

#### 注意事项
- **同步连接并非真正阻塞**：`BuildConnect` 内部使用循环轮询，会短暂占用 CPU。
- **全局池生命周期**：由引用计数自动管理，但需确保所有客户端在程序退出前 `Disconnect`，避免 `finalization` 后野指针。

---

## 5. 性能与稳定性特点

| 特性 | 实现方式 | 收益 |
| :--- | :--- | :--- |
| **发送队列原子统计** | `FWriteBuffer_Size` 使用 `AtomInc/AtomDec` | 精确流控，避免内存爆炸 |
| **锁回收池** | `TCritical` 实例回收 | 降低锁创建开销 |
| **发送队列回收池** | `TBigList` 节点复用 | 减少内存分配，提高吞吐 |
| **碎片合并** | `CurrentBuff` 累积小包 | 减少系统调用次数 |
| **延迟释放** | `DelayFreeObject` | 确保异步回调安全 |
| **软同步清理** | `Check_Soft_Thread_Synchronize` | 根治无 UI 环境的线程退出死锁 |
| **自缩放线程池** | `TCompute` | 空闲时回收 I/O 线程，节省 CPU |
| **统一 UID 查找**（kqueue 也使用） | 放弃引用计数 | 避免循环引用，简化调试 |

---

## 6. 使用示例

### 6.1 启动 TCP 服务

```pascal
var
  server: TZNet_Server_FP_CrossSocket;
begin
  server := TZNet_Server_FP_CrossSocket.Create;
  server.MaxConnection := 5000;
  if server.StartService('0.0.0.0', 8080) then
  begin
    while True do
    begin
      server.Progress;
      Check_Soft_Thread_Synchronize(10);
    end;
  end;
  server.Free;
end;
```

### 6.2 异步客户端连接

```pascal
var
  client: TZNet_Client_FP_CrossSocket;
begin
  client := TZNet_Client_FP_CrossSocket.Create;
  client.AsyncConnectC('127.0.0.1', 8080,
    procedure(Success: Boolean)
    begin
      if Success then
        client.SendConsoleCmd('ping', 'hello');
    end);
  while True do
  begin
    client.Progress;
    Check_Soft_Thread_Synchronize(10);
    if not client.Connected then Break;
  end;
  client.Free;
end;
```

### 6.3 监控发送队列

```pascal
var
  qNum, qBytes: Int64;
begin
  if client.ClientIO <> nil then
    if client.ClientIO.WriteBuffer_State(qNum, qBytes) then
      DoStatus('队列中有 %d 个缓冲，共 %d 字节', [qNum, qBytes]);
end;
```

---

## 7. 重要注意事项（必读）

1. **同步阻塞命令不支持**  
   `WaitSendConsoleCmd` / `WaitSendStreamCmd` 在服务端和客户端适配器中均抛出异常，**必须使用异步回调**。

2. **同步连接是忙等，非真正阻塞**  
   客户端 `Connect` 内部循环轮询，会占用 CPU。高并发连接创建时需评估影响。

3. **发送队列可能无限增长**  
   若对端接收缓慢，`Internal_Send_Queue` 会积累大量 `TMem64` 对象。建议通过 `WriteBuffer_State` 监控 `FWriteBuffer_Size`，并在应用层实施背压。

4. **最大连接数限制**  
   服务端默认 20000，接近此值会拒绝新连接。需根据系统文件描述符限制调大。

5. **客户端全局池生命周期**  
   引用计数自动管理，但若客户端在 `finalization` 后仍存活（如全局对象），可能导致野指针。**建议在程序退出前主动 `Disconnect` 所有客户端**。

6. **线程同步与软同步**  
   CrossSocket 内部可能使用 RTL 的 `Synchronize`，在无 UI 的后台服务/DLL 中，需在析构时调用 `Check_Soft_Thread_Synchronize` 清理队列（FPC 移植版已自动处理）。

7. **跨平台编译依赖**  
   需确保 `Z.FP.Net.CrossSocket` 及其子单元正确链接，特别是 FPC 下的系统库（`libc`、`pthread` 等）。

---

## 8. 附录：关键类速查

| 类名 | 模块 | 职责 |
| :--- | :--- | :--- |
| `TZNet_Server_FP_CrossSocket` | `Z.FP.Net.Server.CrossSocket` | 服务端适配器 |
| `TZNet_Client_FP_CrossSocket` | `Z.FP.Net.Client.CrossSocket` | 客户端适配器 |
| `TCrossSocketServer_PeerIO` | `Z.FP.Net.Server.CrossSocket` | 服务端 IO 处理（含发送队列） |
| `TCrossSocketClient_PeerIO` | `Z.FP.Net.Client.CrossSocket` | 客户端 IO 处理（继承自服务端） |
| `TGlobalCrossSocketClientPool` | `Z.FP.Net.Client.CrossSocket` | 全局客户端连接池 |
| `TDriverEngine` | `Z.FP.Net.CrossSocket` | 平台工厂（IOCP/epoll/kqueue） |
| `TAbstractCrossSocket` | `Z.FP.Net.CrossSocket.Base` | 引擎抽象基类 |
| `TEpollCrossSocket` | `Z.FP.Net.CrossSocket.Epoll` | Linux epoll 实现 |
| `TKqueueCrossSocket` | `Z.FP.Net.CrossSocket.Kqueue` | BSD kqueue 实现 |
| `TIocpCrossSocket` | `Z.FP.Net.CrossSocket.Iocp` | Windows IOCP 实现 |
| `TSocketAPI` | `Z.FP.Net.SocketAPI` | 跨平台系统调用封装 |

---

*本手册整合了 CrossSocket 标准版与 FPC 移植版的深度技术对比，以及 Z.FP.Net 上层适配器的完整知识，适用于开发者快速上手、AI 辅助编程及系统设计参考。*
