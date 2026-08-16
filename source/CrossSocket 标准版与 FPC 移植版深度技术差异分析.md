# CrossSocket 标准版与 FPC 移植版深度技术差异分析

## 1. 概述

`Z.Net.CrossSocket`（标准版）与 `Z.FP.Net.CrossSocket`（FPC 移植版）是同一底层异步 I/O 引擎的两个变体。标准版基于 [winddriver/Delphi-Cross-Socket](https://github.com/winddriver/Delphi-Cross-Socket) 项目，面向 Delphi 编译器；FPC 移植版则基于 `Z.FP.Net.CrossSocket` 单元，**专门为 Free Pascal 编译器重构**，并深度整合了 **Z.Core 基础库** 的线程模型、原子操作、临界区管理和软同步机制。

两者共享相同的架构分层和平台实现策略（Windows/IOCP、Linux/Epoll、BSD/Kqueue），但在 **并发模型、资源管理、锁机制、错误处理、可移植性** 五个关键维度上存在显著差异。这些差异直接决定了 FPC 移植版在 **IoT 物联网、嵌入式设备、高负载服务器** 场景下的优越性。

---

## 2. 整体架构对比

| 维度 | 标准版（Z.Net.CrossSocket） | FPC 移植版（Z.FP.Net.CrossSocket） |
| :--- | :--- | :--- |
| **基础库依赖** | Delphi RTL（`System.Classes`, `System.Generics.Collections`, `System.SysUtils`） | FPC RTL + **Z.Core**（`TCritical`, `TAtomInt`, `TCompute`, `TOrderStruct`, `Check_Soft_Thread_Synchronize`） |
| **锁机制** | `System.TMonitor`（对象监视器锁） | `TCritical`（Z.Core 自旋/临界区，支持回收池） |
| **原子操作** | `AtomicIncrement` / `TInterlocked`（Delphi 原生） | `AtomInc` / `AtomDec` / `TAtomInt`（Z.Core 跨平台原子操作，支持 64 位） |
| **线程池** | 自行管理 `TThread` 派生类 | 使用 `TCompute` 线程池（Z.Core 自缩放线程池） |
| **连接对象查找** | epoll/kqueue 事件中存储 `UID`，通过 `TDictionary<UID, ICrossData>` 查找 | 同标准版，但锁粒度更细 |
| **发送队列** | `TList<PSendItem>`（标准 TList，带 `Notify` 回调） | `TBigList<PSendItem>`（Z.Core 双向循环链表 + 回收池） |
| **发送队列统计** | 仅队列长度 | **新增 `FWriteBuffer_Size` 字段**，原子操作追踪总字节数 |
| **内存分配** | 标准 `New`/`Dispose` | 标准 `New`/`Dispose`，但通过 `TBigList` 回收池复用节点 |
| **跨平台系统调用** | `Posix.*`（Delphi 跨平台单元） | `BaseUnix` / `Unix` / `Sockets` / `netdb`（FPC 原生单元）+ 自定义 `pipe` / `eventfd` 封装 |

---

## 3. 核心设计理念差异

### 3.1 Kqueue 实现差异（BSD/macOS/iOS）

**标准版（`Z.Net.CrossSocket.Kqueue`）**：

- 使用 **引用计数**（`_AddRef` / `_Release`）管理连接对象生命周期。
- `EVFILT_READ` 和 `EVFILT_WRITE` 事件独立注册，每次添加事件时调用 `_AddRef`，事件触发时调用 `_Release`。
- **关闭连接**：使用 `shutdown` 触发 kqueue 事件，确保引用计数平衡。

**FPC 移植版（`Z.FP.Net.CrossSocket.Kqueue`）**：

- **放弃引用计数**，改用 **UID 查找** 机制（与 epoll 实现一致）。
- 每次事件触发后，通过 `UID` 从 `TAbstractCrossSocket` 的连接/监听字典中查找对象，**无需引用计数干预**。
- **关闭连接**：同样使用 `shutdown`，但仅用于触发事件，不依赖引用计数释放。

**技术意义**：引用计数在极端并发场景下容易出现循环引用或提前释放；UID 查找机制将生命周期管理权交还给上层容器，降低了对象间耦合，简化了调试难度。

---

### 3.2 Epoll 实现差异（Linux/Android）

**标准版（`Z.Net.CrossSocket.Epoll`）**：

- 使用 `epoll` 的 **边缘触发（EPOLLET）+ 单次触发（EPOLLONESHOT）**。
- 发送队列使用 `TList<PSendItem>`，`Notify` 方法在元素移除时释放 `PSendItem`。
- 发送数据在 `_HandleWrite` 中调用 `PosixSend`，**发送完成后立即解锁队列**，允许回调中继续发送。
- **锁机制**：使用 `System.TMonitor` 保护 `FLock` 对象。

**FPC 移植版（`Z.FP.Net.CrossSocket.Epoll`）**：

- 同样使用 `EPOLLET` + `EPOLLONESHOT`，逻辑一致。
- 发送队列使用 **`TBigList<PSendItem>`**，支持节点回收池，减少频繁分配/释放开销。
- 发送数据在 `_HandleWrite` 中调用 `PosixSend`，**先复制回调指针再解锁**，避免回调嵌套导致的死锁。
- **锁机制**：使用 `TCritical`（Z.Core 临界区），性能优于 `TMonitor`，且支持自旋模式。

**技术意义**：`TBigList` 的回收池机制在高频发送场景下显著降低内存分配压力；`TCritical` 比 `TMonitor` 更轻量，尤其在多核 CPU 上竞争激烈时表现更优。

---

### 3.3 IOCP 实现差异（Windows）

**标准版（`Z.Net.CrossSocket.Iocp`）**：

- 使用 `AcceptEx` / `ConnectEx` / `WSASend` / `WSARecv`。
- 每个 I/O 操作分配 `TPerIoData` 结构（含 `TWSAOverlapped`）。
- `ProcessIoEvent` 中 `GetQueuedCompletionStatus` 获取完成包，分发到 `_HandleAccept` / `_HandleConnect` / `_HandleRead` / `_HandleWrite`。

**FPC 移植版（`Z.FP.Net.CrossSocket.Iocp`）**：

- API 调用方式相同，但底层使用 `Z.FP.Net.Winsock2` 和 `Z.FP.Net.Wship6`（FPC 兼容的 WinSock 封装）。
- 内存管理使用 Z.Core 的 `DisposeObject` / `DelayFreeObject` 模式，确保完成包处理完成后安全释放。
- **新增 `FWriteBuffer_Size` 原子统计**，精确追踪每个连接的发送队列字节数。

**技术意义**：Windows 平台下，FPC 移植版与标准版功能对等，但内存释放路径更安全，避免 `Free` 和 `Dispose` 在异步回调中可能引发的访问冲突。

---

## 4. 并发模型差异

| 特性 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **I/O 线程数默认值** | `CPUCount * 2 + 1` | `Get_Parallel_Granularity`（Z.Core 全局并行粒度） |
| **线程创建** | `TThread.Create`（Delphi RTL） | `TCompute` 线程池（Z.Core，支持自缩放） |
| **线程退出等待** | `while FIoThreads[I].IO_Is_Busy do Sleep(1)` | `while FIoThreads[I].IO_Is_Busy do Check_Soft_Thread_Synchronize(10, False)`（软同步驱动） |
| **StopLoop 死锁检测** | 抛出异常：“不能在IO线程中执行StopLoop!” | 相同检测 + 软同步队列清理 |
| **锁粒度** | 使用 `System.TMonitor.Enter/Exit` 保护关键区 | 使用 `TCritical.Lock/UnLock`，支持递归锁和自旋 |

**技术意义**：Z.Core 的 `TCompute` 线程池具备 **自缩放** 能力——空闲线程超过阈值后自动回收，避免 I/O 线程空转浪费 CPU。`Check_Soft_Thread_Synchronize` 驱动 RTL 同步队列，在无 UI 的服务器/DLL 环境中尤其重要。

---

## 5. 锁机制对比

标准版使用 **`System.TMonitor`**，这是 Delphi 的对象监视器锁，基于操作系统临界区实现，但有以下缺陷：

- **无法支持自旋**：在锁竞争不激烈时，自旋锁比临界区更高效。
- **无法跨平台一致优化**：不同平台的 `TMonitor` 实现差异较大。

FPC 移植版使用 **Z.Core 的 `TCritical`**：

- 底层可切换为 **自旋锁**（通过 `SoftCritical` 宏）或 **操作系统临界区**。
- 支持 **锁回收池**：销毁的 `TCritical` 对象可复用底层句柄，减少创建销毁开销。
- 提供 `Inc_` / `Dec_` 等原子操作便利方法，在锁内安全修改变量。

**技术意义**：在高并发 I/O 场景（如 10K+ 连接），自旋锁能有效减少上下文切换；锁回收池在频繁创建/销毁连接时降低资源分配压力。

---

## 6. 连接生命周期管理对比

| 机制 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **连接查找** | UID → `TDictionary` 查找 | 同左 |
| **锁保护** | `TMonitor.Enter(FConnectionsLock)` | `TCritical.Lock` |
| **连接关闭** | `Close` 直接关闭套接字 | 同左，但增加原子计数清理 |
| **延迟释放** | 无统一机制 | `DelayFreeObject`（Z.Core）确保异步回调完成后释放 |
| **资源泄漏防护** | 依赖引用计数（kqueue） | 依赖 UID 查找 + 字典删除（所有平台统一） |

**技术意义**：FPC 移植版在 kqueue 平台上放弃了引用计数，使三个平台（IOCP/epoll/kqueue）的生命周期管理逻辑完全统一，降低了平台特定 bug 的风险。`DelayFreeObject` 机制确保在异步回调链完全结束后才释放对象，避免悬空指针。

---

## 7. 发送队列与流控对比

**标准版**：

- 发送队列为 `TList<PSendItem>`，仅存储队列长度。
- 无队列字节数统计，流控依赖上层应用自行实现。

**FPC 移植版**：

- 发送队列为 **`TBigList<PSendItem>`**，支持回收池。
- **新增 `FWriteBuffer_Size: Int64` 字段**，通过 `AtomInc` / `AtomDec` 原子操作追踪队列总字节数。
- 提供 `WriteBuffer_State` 方法，返回队列数量和总字节数，供上层应用做流控决策。

**技术意义**：`FWriteBuffer_Size` 是 **关键性能指标**。在 IoT 场景中，网络带宽有限，精确的队列字节数允许应用层实现 **背压（Backpressure）** 机制——当队列字节数超过阈值时，暂停写入数据，避免内存耗尽。

---

## 8. 错误处理与健壮性对比

| 特性 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **EMFILE 恢复** | 标准版同样支持 | 支持，使用 `/dev/null` 占位句柄 |
| **发送错误处理** | 回调 `False` | 回调 `False` + 队列字节数原子递减 |
| **StopLoop 超时** | 无超时，可能无限等待 | 使用 `Check_Soft_Thread_Synchronize` 驱动同步队列，避免死等 |
| **日志输出** | `_Log` 使用 `OutputDebugString` 或 `DoStatus`（Z.Status） | 统一使用 `Z.Status.DoStatus`，支持钩子转发 |
| **同步队列清理** | 无显式清理 | 析构时强制调用 `Check_Soft_Thread_Synchronize` |

**技术意义**：FPC 移植版通过 `Check_Soft_Thread_Synchronize` 解决了 CrossSocket 在无 UI 应用（DLL、服务、IoT 设备）中可能出现的 **RTL 同步队列死锁** 问题。这是标准版 CrossSocket 的一个已知痛点，在 Z.Core 体系中得到了根治。

---

## 9. 跨平台适配层对比

| 单元 | 标准版 | FPC 移植版 |
| :--- | :--- | :--- |
| **系统调用** | `Posix.SysSocket` / `Posix.UniStd` / `Posix.NetDB` | `BaseUnix` / `Unix` / `Sockets` / `netdb`（FPC 原生） |
| **epoll 系统调用** | `Z.Linux.epoll`（Delphi 封装） | `Z.FP.Net.Linux.epoll`（FPC 封装） |
| **kqueue 系统调用** | `Z.BSD.kqueue`（Delphi 封装） | `Z.FP.Net.BSD.kqueue`（FPC 封装） |
| **WinSock** | `Z.Net.Winsock2` / `Z.Net.Wship6` | `Z.FP.Net.Winsock2` / `Z.FP.Net.Wship6` |
| **SocketAPI** | `Z.Net.SocketAPI`（Delphi 跨平台） | `Z.FP.Net.SocketAPI`（FPC 跨平台） |
| **Posix 发送辅助** | `Z.Net.Posix.inc` | `Z.FP.Net.Posix.inc` |

**技术意义**：FPC 移植版完整重写了所有系统调用适配层，确保在 FPC 编译器下正确链接。`Z.FP.Net.SocketAPI` 使用 FPC 的 `fpSocket` / `fpConnect` / `fpsend` / `fprecv` 等函数族，与 Delphi 的 `Posix.*` 单元在类型定义（如 `socklen_t` vs `Integer`）上存在细微差异，移植版已全部适配。

---

## 10. Z.Core 体系带来的关键改进

### 10.1 软同步（Soft Synchronize）机制

标准版 CrossSocket 在 DLL 或无窗口应用中，`StopLoop` 后可能出现 I/O 线程无法正常退出的情况，原因是 RTL 的 `Synchronize` 队列未及时处理。FPC 移植版在析构时强制调用：

```pascal
Check_Soft_Thread_Synchronize(0, False);
```

这确保所有同步请求被清空，I/O 线程得以正常终止。

### 10.2 原子操作统一化

标准版使用 `AtomicIncrement` / `TInterlocked`，但 Delphi 各版本实现不一致。FPC 移植版使用 Z.Core 的 `AtomInc` / `AtomDec`，在 FPC 下映射为 `InterlockedIncrement` / `InterlockedDecrement`，在 Delphi 下映射为 `System.AtomicIncrement`，**行为完全一致**。

### 10.3 线程池自缩放

标准版的 I/O 线程数量固定为 `CPUCount * 2 + 1`。FPC 移植版使用 `TCompute` 线程池，I/O 线程空闲超过阈值后自动退出，在连接数波动较大的场景下（如 IoT 设备间歇性连接），CPU 资源利用更高效。

### 10.4 延迟释放（DelayFree）机制

标准版中，连接对象的释放依赖 `Free` 或 `Dispose`，在异步回调中可能出现“先释放后访问”的问题。FPC 移植版使用 `DelayFreeObject`：

```pascal
DelayFreeObject(1.0, self);
```

延迟 1 秒释放，确保所有待处理回调执行完毕。

---

## 11. 总结

| 对比维度 | 标准版 CrossSocket | FPC 移植版 CrossSocket |
| :--- | :--- | :--- |
| **编译器支持** | Delphi（Windows/macOS/Linux） | FPC + Delphi（全平台） |
| **基础库** | Delphi RTL | Z.Core（统一跨平台基础库） |
| **锁机制** | `TMonitor` | `TCritical`（支持自旋/回收池） |
| **原子操作** | `TInterlocked` | `AtomInc` / `TAtomInt`（统一跨平台） |
| **发送队列统计** | 仅队列长度 | **新增字节数原子统计**（精确流控） |
| **连接生命周期** | kqueue 使用引用计数 | **所有平台统一 UID 查找** |
| **线程管理** | 固定数量 I/O 线程 | **TCompute 自缩放线程池** |
| **同步队列清理** | 无 | `Check_Soft_Thread_Synchronize`（根治死锁） |
| **延迟释放** | 无统一机制 | `DelayFreeObject`（安全异步释放） |
| **适用场景** | 常规服务器 | **IoT 物联网、嵌入式、高负载服务器** |

**FPC 移植版并非简单的代码翻译，而是从并发模型、锁策略、内存管理、生命周期控制四个层面，对 CrossSocket 引擎做了系统性重构**，使其在 Free Pascal 环境下具备更高的稳定性和可预测性，尤其适合资源受限的 IoT 设备和高并发边缘计算场景。Z.Core 体系的深度整合，使移植版在跨平台一致性、调试便利性和运行时效性上均优于标准版。
