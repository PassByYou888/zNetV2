# Z.Net 框架完整白皮书

## 核心网络框架类（TZNet 家族）

---

## 1. TZNet — 网络框架抽象基类

### 1.1 功能说明

`TZNet` 是所有网络框架（服务端、客户端、P2PVM 实例）的顶层抽象基类。它提供了：

- **命令注册中心**：管理所有业务命令的注册与查找。
- **IO 连接池**：维护所有 `TPeerIO` 连接实例的哈希表。
- **进度调度引擎**：驱动所有连接的收发处理，并支持外部进度事件挂载。
- **统计与监控**：提供丰富的性能计数器，包括收发包大小、命令频次、加密/压缩次数、命令执行耗时等。
- **安全配置容器**：统一管理加密算法、压缩开关、空闲超时等全局安全策略。
- **调试工具**：支持命令列表打印、参数过滤日志、静默模式等。

`TZNet` 不直接处理网络 I/O，而是作为框架容器，将具体 I/O 操作委托给 `TZNet_Server` 和 `TZNet_Client` 实现。开发者通常不直接实例化 `TZNet`，而是使用其派生类。

### 1.2 典型用法

```pascal
// 1. 使用派生类创建框架实例
var Server := TZNet_Server.Create;
// 2. 注册命令
Server.RegisterConsole('echo').OnExecute := MyEchoHandler;
// 3. 启动服务并进入主循环
Server.StartService('0.0.0.0', 8080);
while True do
begin
  Server.Progress;  // 驱动网络
  Sleep(1);
end;
```

### 1.3 构造与析构

| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(HashPoolSize: Integer);` | 构造框架实例。`HashPoolSize` 指定命令哈希池和 IO 哈希池的初始容量，建议根据预期并发连接数设置（通常 10000~200000）。构造时会自动注册内部系统命令（如 `__@CipherModel`、`__@NULL` 等）。 |
| `procedure CreateAfter; virtual;` | 构造后虚钩子，派生类可重写以执行额外初始化。在 `Create` 末尾自动调用。 |
| `destructor Destroy; override;` | 析构函数，释放所有 IO 连接、命令池、进度事件池、统计池等资源。 |

### 1.4 公开字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Statistics` | `array[TStatisticsType] of Int64` | 性能统计计数器数组。包括收发包字节数、各类型命令计数、加密/压缩次数、序列包统计、超时断开次数等 30+ 指标。可在运行时读取以监控系统状态。 |
| `CmdRecvStatistics` | `TCommand_Num_Hash_Pool` | 接收命令频次统计。键为命令名，值为累计接收次数。用于分析热点命令。 |
| `CmdSendStatistics` | `TCommand_Num_Hash_Pool` | 发送命令频次统计。键为命令名，值为累计发送次数。 |
| `CmdMaxExecuteConsumeStatistics` | `TCommand_Tick_Hash_Pool` | 命令最大执行耗时统计。键为命令名，值为该命令单次执行的最大耗时（毫秒）。用于性能瓶颈定位。 |

### 1.5 公开属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Send_Critical` | `TCritical` | 只读 | 发送操作锁，用于 `LockSend`/`UnLockSend` 方法内部，开发者通常无需直接访问。 |
| `SequencePacketActivted` | `Boolean` | 读写 | 是否启用序列包可靠传输模型。启用后，底层数据包将带有序号和重传机制，适用于 UDP 或不稳定网络环境。默认由编译开关 `UsedSequencePacket` 控制。 |
| `Progress_Pool` | `TZNet_Progress_Pool` | 只读 | 进度事件池，管理所有挂载的 `TZNet_Progress` 事件。通过 `AddProgresss` 添加。 |
| `Protocol` | `TCommunicationProtocol` | 读写 | 通信协议模式。`cpZServer`（默认）为框架内置的二进制安全协议；`cpCustom` 为原始数据透传模式，需自行实现协议解析。 |
| `PrefixName` | `SystemString` | 读写 | 日志前缀字符串，用于区分不同框架实例的输出。 |
| `Name` | `SystemString` | 读写 | 框架实例名称，在日志和调试信息中显示。 |
| `IOInterface` | `IIOInterface` | 读写 | IO 生命周期事件接口。实现此接口可监听连接创建和销毁事件。 |
| `VMInterface` | `IZNet_VMInterface` | 读写 | P2PVM 虚拟网络事件接口。实现此接口可处理 P2PVM 认证、隧道开启/关闭等事件。别名：`OnVMInterface`, `OnVM`。 |
| `OnBigStreamInterface` | `IOnBigStreamInterface` | 读写 | 大流传输进度事件接口。实现此接口可接收大流开始、进度更新、完成等通知。别名：`OnBigStream`。 |
| `AutomatedP2PVMServiceBind` | `TAutomatedP2PVMServiceBind` | 只读 | 自动 P2PVM 服务绑定列表。通过 `AddService` 方法将虚拟服务器挂载到自动 P2PVM 框架。 |
| `AutomatedP2PVMClientBind` | `TAutomatedP2PVMClientBind` | 只读 | 自动 P2PVM 客户端绑定列表。通过 `AddClient` 方法将虚拟客户端挂载到自动 P2PVM 框架。 |
| `AutomatedP2PVMService` | `Boolean` | 读写 | 是否启用自动 P2PVM 服务模式。启用后，当物理连接建立且认证通过时，自动挂载 `AutomatedP2PVMServiceBind` 中的虚拟服务。默认 `True`。 |
| `AutomatedP2PVMClient` | `Boolean` | 读写 | 是否启用自动 P2PVM 客户端模式。启用后，当物理连接建立且认证通过时，自动连接 `AutomatedP2PVMClientBind` 中的虚拟客户端。默认 `True`。 |
| `AutomatedP2PVMClientDelayBoot` | `Double` | 读写 | 自动 P2PVM 客户端启动延迟（秒）。在物理连接建立后等待此时间再启动虚拟客户端连接。默认 `0.5`。 |
| `AutomatedP2PVMAuthToken` | `SystemString` | 读写 | 自动 P2PVM 认证令牌。用于 P2PVM 握手认证，服务端和客户端需匹配。默认 `'AutomatedP2PVM for ZServer'`。 |
| `Progress_CPS` | `TCPS_Tool` | 只读 | 每秒 `Progress` 调用次数统计器，用于评估框架主循环负载。 |
| `PeerIO_HashPool` | `TPeer_IO_Hash_Pool` | 只读 | IO ID 到 `TPeerIO` 实例的哈希池。可通过 `IOPool` 别名访问。 |
| `IOPool` | `TPeer_IO_Hash_Pool` | 只读 | `PeerIO_HashPool` 的别名。 |
| `PeerIOUserDefineClass` | `TPeer_IO_User_Define_Class` | 读写 | 用户扩展对象的工厂类。框架为每个连接自动创建此类的实例，挂载到 `TPeerIO.UserDefine`。默认为 `TPeer_IO_User_Define`。派生类可重写以提供自定义扩展对象。 |
| `PeerIOUserSpecialClass` | `TPeer_IO_User_Special_Class` | 读写 | 特殊用户扩展对象的工厂类。挂载到 `TPeerIO.UserSpecial`。默认为 `TPeer_IO_User_Special`。 |
| `HashSecurity` | `THashSecurity` | 只读 | 全局哈希安全级别，用于数据完整性校验。通过 `SwitchMaxSecurity`/`SwitchMaxPerformance` 切换。默认 `hsNone`。 |
| `CipherSecurityArray` | `TCipherSecurityArray` | 只读 | 可用的加密算法数组。每个新连接建立时，服务端从此数组中随机选择一种算法作为该连接的加密方案。 |
| `RandomCipherSecurity` | `TCipherSecurity` | 只读 | 随机选择的加密算法（每次调用返回不同结果）。用于为新连接分配加密方案。 |
| `IdleTimeOut` | `TTimeTick` | 读写 | 空闲超时（毫秒）。若连接在此时间内无任何通信，框架自动断开。`0` 表示不检测。默认 `0`。别名：`TimeOutIDLE`, `TimeOut`。 |
| `TimeOutIDLE` | `TTimeTick` | 读写 | `IdleTimeOut` 别名。 |
| `TimeOut` | `TTimeTick` | 读写 | `IdleTimeOut` 别名。 |
| `FastEncrypt` | `Boolean` | 读写 | 快速加密模式。启用后，每个连接复用加密/解密实例（`FEncryptInstance`/`FDecryptInstance`），避免重复创建开销。默认 `True`。 |
| `UsedParallelEncrypt` | `Boolean` | 读写 | 并行加密模式。启用后，加密操作可在多线程环境中安全执行（使用 `TCipher` 的并行加密实现）。默认 `True`。 |
| `SyncOnResult` | `Boolean` | 读写 | 结果同步执行标志。若为 `True`，命令结果回调在接收线程中立即执行；若为 `False`，结果回调延迟到主 `Progress` 循环中执行。默认 `True`。 |
| `SyncOnCompleteBuffer` | `Boolean` | 读写 | 完整缓冲同步执行标志。类似 `SyncOnResult`，但针对完整缓冲命令。默认 `True`。 |
| `BigStreamMemorySwapSpace` | `Boolean` | 读写 | 大流内存交换空间开关。启用后，大流数据在内存紧张时自动缓存到磁盘临时文件。默认 `False`（由 `ZNet_Def_BigStream_Memory_SwapSpace_Activted` 控制）。 |
| `BigStreamSwapSpaceTriggerSize` | `Int64` | 读写 | 大流交换触发大小（字节）。当大流数据超过此大小时触发磁盘交换。默认 `1MB`（`ZNet_Def_BigStream_SwapSpace_Trigger`）。 |
| `EnabledAtomicLockAndMultiThread` | `Boolean` | 读写 | 原子锁和多线程安全开关。启用后，框架内部操作使用 `TCritical` 加锁，支持多线程并发调用 `Progress`。默认 `True`。 |
| `TimeOutKeepAlive` | `Boolean` | 读写 | 超时 Keep-Alive 开关。启用后，当连接超过 1 秒无通信时，自动发送 Keep-Alive 探测包。默认 `True`。 |
| `QuietMode` | `Boolean` | 读写 | 静默模式开关。启用后，框架不输出任何调试日志，适用于生产环境。默认由编译开关 `Communication_QuietMode` 控制。 |
| `PhysicsFragmentSwapSpaceTechnology` | `Boolean` | 读写 | 物理片段交换空间技术开关。启用后，接收到的物理数据包片段在超过阈值时缓存到磁盘。默认 `False`（由 `ZNet_Def_Physics_Fragment_Cache_Activted` 控制）。 |
| `PhysicsFragmentSwapSpaceTrigger` | `NativeInt` | 读写 | 物理片段交换触发数量。当接收到的片段数量超过此值时触发磁盘交换。默认 `10000`。 |
| `SendFlushSize` | `NativeInt` | 读写 | 发送刷新块大小（字节）。发送缓冲按此大小分块写入底层 Socket。默认 `32KB`（`ZNet_Def_SendFlushSize`）。 |
| `SendDataCompressed` | `Boolean` | 读写 | 发送数据压缩开关。启用后，发送的控制台/流命令载荷使用 ZLib 压缩。默认 `False`。 |
| `CompleteBufferCompressed` | `Boolean` | 读写 | 完整缓冲压缩开关。启用后，完整缓冲数据在发送前压缩。默认 `False`。 |
| `Per_Progress_Loop_Limit` | `Integer` | 读写 | 每次 `Progress` 循环最大处理的命令数。防止单次循环过长导致其他连接饥饿。`0` 表示无限制。默认 `500`（`ZNet_Def_Per_Progress_Loop_Limit`）。 |
| `Extract_Physics_Fragment_Max_Size` | `Int64` | 读写 | 每次 `Progress` 循环从物理片段池提取的最大字节数。默认 `1MB`（`ZNet_Def_Extract_Physics_Fragment_Max_Size`）。 |
| `MaxCompleteBufferSize` | `Cardinal` | 读写 | 允许的最大完整缓冲大小（字节）。超过此大小的完整缓冲命令将被拒绝并断开连接。`0` 表示无限制。默认 `64MB`（`ZNet_Def_MaxCompleteBufferSize`）。 |
| `CompleteBufferCompressionCondition` | `Cardinal` | 读写 | 完整缓冲压缩条件阈值（字节）。仅当完整缓冲数据超过此大小时才进行压缩。默认 `1024`。 |
| `CompleteBufferSwapSpace` | `Boolean` | 读写 | 完整缓冲交换空间开关。启用后，完整缓冲数据在内存紧张时缓存到磁盘。默认 `False`（由 `ZNet_Def_CompleteBuffer_SwapSpace_Activted` 控制）。 |
| `CompleteBufferSwapSpaceTriggerSize` | `Int64` | 读写 | 完整缓冲交换触发大小（字节）。默认 `1024`。 |
| `AutomaticWaitRemoteReponse` | `Boolean` | 读写 | 自动等待远程响应开关。启用后，发送通知命令后自动发送空命令触发远程处理。默认 `False`。 |
| `Encrypt_P2PVM_Packet` | `Boolean` | 读写 | P2PVM 数据包加密开关。启用后，P2PVM 隧道中的数据包额外加密。默认由编译开关 `Encrypt_P2PVM_Packet` 控制。 |
| `ProgressMaxDelay` | `TTimeTick` | 读写 | 每次 `Progress` 循环最大耗时（毫秒）。防止单次循环过长导致主线程卡顿。默认 `1000`（`ZNet_Progress_Max_Delay`）。 |
| `CMD_Thread_Runing_Num` | `Integer` | 只读 | 当前正在运行的 HPC 线程数。用于监控后台任务负载。 |
| `InitedTimeMD5` | `TMD5` | 只读 | 框架初始化时间的 MD5 值，用于客户端验证服务端身份。 |
| `DoubleChannelFramework` | `TCore_Object` | 读写 | 双通道框架引用。当此框架作为双通道（Recv/Send 分离）的一部分时，指向配对框架对象。 |
| `CustomUserData` | `Pointer` | 读写 | 用户自定义数据指针，任意用途。 |
| `CustomUserObject` | `TCore_Object` | 读写 | 用户自定义对象，任意用途。 |
| `FrameworkIsServer` | `Boolean` | 只读 | 是否为服务端框架。`TZNet_Server` 中为 `True`，`TZNet_Client` 中为 `False`。 |
| `FrameworkIsClient` | `Boolean` | 只读 | 是否为客户端框架。 |
| `FrameworkInfo` | `SystemString` | 只读 | 框架类名等标识信息。 |
| `OnExecuteCommand` | `TPeerIOCMDNotify` | 读写 | 命令执行前钩子。可在此事件中拦截或拒绝命令执行。 |
| `OnSendCommand` | `TPeerIOCMDNotify` | 读写 | 命令发送前钩子。可在此事件中拦截或拒绝命令发送。 |
| `PrintParams` | `TPrint_Param_Hash_Pool` | 只读 | 打印参数过滤器。控制哪些命令的调试日志被输出，默认内部系统命令被过滤。 |
| `ProgressEngine` | `TN_Progress_ToolWithCadencer` | 只读 | 延迟执行工具，提供 `PostExecute`、`PostExecuteM` 等方法用于任务调度。别名：`ProgressPost`, `PostProgress`, `PostRun`, `PostExecute`。 |

### 1.6 核心方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure Progress; virtual;` | **主循环核心方法**。驱动所有连接的 I/O 处理。必须定期调用（通常在应用主循环中）。此方法执行以下操作：① 调用全局后台钩子 `ProgressBackgroundProc`/`ProgressBackgroundMethod`；② 遍历所有 IO 连接，调用其 `Progress` 方法处理收发；③ 驱动自动 P2PVM 服务/客户端进度；④ 触发 `PostProgress` 延迟任务；⑤ 触发进度事件池。 |
| `procedure Enabled_Progress;` | 启用进度处理。框架默认启用，调用后可恢复被 `Disable_Progress` 暂停的进度。 |
| `procedure Disable_Progress;` | 禁用进度处理。调用后 `Progress` 方法将直接返回，不执行任何 I/O 操作。用于临时暂停网络活动。 |
| `function IOBusy(): Boolean;` | 检查是否有任何连接处于繁忙状态（有待发送数据或待处理接收数据）。返回 `True` 表示至少一个连接繁忙。 |
| `procedure ProgressWaitSend(P_IO: TPeerIO); overload; virtual;` | 阻塞式进度循环，专门用于同步发送等待。在等待期间反复调用 `Progress`，直到指定 IO 完成发送。此方法会短暂占用当前线程，应谨慎使用。 |
| `function ProgressWaitSend(IO_ID: Cardinal): Boolean; overload;` | 通过 IO ID 进行阻塞式进度等待。返回 `True` 表示等待成功完成。 |

### 1.7 命令注册方法

| 方法名 | 说明 |
| :--- | :--- |
| `function RegisterConsole(const Cmd: SystemString): TCommandConsole;` | 注册**请求-响应**型控制台命令。`Cmd` 为命令名（字符串），返回 `TCommandConsole` 实例，通过其 `OnExecute` 属性绑定处理函数。处理函数签名：`procedure(Sender: TPeerIO; InData: string; var OutData: string)`。 |
| `function RegisterStream(const Cmd: SystemString): TCommandStream;` | 注册**请求-响应**型流命令。处理函数签名：`procedure(Sender: TPeerIO; InData, OutData: TDFE)`。适用于结构化数据交换。 |
| `function RegisterStreamNotify(const Cmd: SystemString): TCommandStreamNotify;` | 注册流通知命令（无响应）。处理函数签名：`procedure(Sender: TPeerIO; InData: TDFE)`。适用于单向数据推送。 |
| `function RegisterConsoleNotify(const Cmd: SystemString): TCommandConsoleNotify;` | 注册控制台通知命令（无响应）。处理函数签名：`procedure(Sender: TPeerIO; InData: string)`。适用于单向文本消息。 |
| `function RegisterBigStream(const Cmd: SystemString): TCommandBigStream;` | 注册大流命令。处理函数签名：`procedure(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64)`。用于接收大文件或数据流。 |
| `function RegisterCompleteBuffer(const Cmd: SystemString): TCommandCompleteBuffer;` | 注册完整缓冲命令。处理函数签名：`procedure(Sender: TPeerIO; InData: PByte; DataSize: NativeInt)`。用于接收原子数据块。 |
| `function RegisterCompleteBuffer_StreamNotify(const Cmd: SystemString): TCommandCompleteBuffer_StreamNotify;` | 注册完整缓冲流通知命令。是 `RegisterStreamNotify` 的优化版本，使用完整缓冲协议传输，性能更高。处理函数接收 `TDFE`。 |
| `function RegisterCompleteBuffer_Asynchronous_StreamNotify(const Cmd: SystemString): TCommandCompleteBuffer_StreamNotify;` | 注册异步完整缓冲流通知命令。与 `RegisterCompleteBuffer_StreamNotify` 类似，但解码在后台线程执行，不阻塞主循环。设置 `Sync_Decrypt := False` 启用异步模式。 |
| `function RegisterCompleteBuffer_NoWait_Stream(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Stream;` | 注册无等待流命令。发送方不等待响应，响应通过回调异步返回。是 `RegisterStream` 的非阻塞版本。设置 `Execute_In_Thread := True` 可在后台线程执行。 |
| `function RegisterCompleteBuffer_NoWait_Stream_Thread(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Stream;` | 注册线程无等待流命令。与 `RegisterCompleteBuffer_NoWait_Stream` 类似，但强制在后台线程执行（`Execute_In_Thread` 自动为 `True`）。 |
| `function RegisterCompleteBuffer_NoWait_Bridge_Stream(const Cmd: SystemString): TCommandCompleteBuffer_NoWait_Bridge_Stream;` | 注册桥接流命令。处理函数接收 `TCommandCompleteBuffer_NoWait_Bridge` 对象，提供 `Pause`/`Resume` 能力，可精细控制响应发送时机。 |
| `function RemoveRegistedCMD(const Cmd: SystemString): Boolean;` | 删除已注册命令。返回 `True` 表示删除成功。别名：`DeleteRegistedCMD`, `UnRegisted`。 |
| `function DeleteRegistedCMD(const Cmd: SystemString): Boolean;` | 同 `RemoveRegistedCMD`。 |
| `function UnRegisted(const Cmd: SystemString): Boolean;` | 同 `RemoveRegistedCMD`。 |
| `function ExistsRegistedCmd(const Cmd: SystemString): Boolean;` | 检查指定命令是否已注册。 |

### 1.8 IO 管理方法

| 方法名 | 说明 |
| :--- | :--- |
| `function FirstIO: TPeerIO;` | 返回第一个连接的 IO 对象。若无连接则返回 `nil`。 |
| `function LastIO: TPeerIO;` | 返回最后一个连接的 IO 对象。 |
| `function ExistsID(IO_ID: Cardinal): Boolean;` | 检查指定 ID 的 IO 连接是否存在。 |
| `procedure GetIO_Array(out IO_Array: TIO_Array); overload;` | 获取所有 IO 连接的 ID 数组。线程安全（内部加锁）。 |
| `procedure GetIO_Order(Order_: TIO_Order); overload;` | 获取所有 IO 连接的 ID 顺序队列。线程安全。 |
| `procedure ProgressPeerIOC(const OnBackcall: TPeerIOList_C);` | 遍历所有 IO 连接，对每个连接执行 C 风格回调 `procedure(P_IO: TPeerIO)`。线程安全。 |
| `procedure ProgressPeerIOM(const OnBackcall: TPeerIOList_M);` | 遍历所有 IO 连接，执行 M 风格回调 `procedure(P_IO: TPeerIO) of object`。 |
| `procedure ProgressPeerIOP(const OnBackcall: TPeerIOList_P);` | 遍历所有 IO 连接，执行 P 风格回调 `procedure(P_IO: TPeerIO) is nested`。 |
| `procedure FastProgressPeerIOC(const OnBackcall: TPeerIOList_C); overload;` | 快速遍历所有 IO 连接（不加锁）。**警告**：若在遍历过程中 IO 池发生变化，可能导致访问无效指针，仅在确定安全时使用。 |
| `procedure FastProgressPeerIOM(const OnBackcall: TPeerIOList_M); overload;` | 快速遍历（不加锁），M 风格回调。 |
| `procedure FastProgressPeerIOP(const OnBackcall: TPeerIOList_P); overload;` | 快速遍历（不加锁），P 风格回调。 |

### 1.9 进度事件管理

| 方法名 | 说明 |
| :--- | :--- |
| `function AddProgresss(Progress_: TZNet_Progress_Class): TZNet_Progress; overload;` | 添加进度事件实例，使用指定的 `Progress_` 类（须为 `TZNet_Progress` 的派生类）。返回新创建的进度事件对象。 |
| `function AddProgresss(): TZNet_Progress; overload;` | 添加进度事件实例，使用默认类 `TZNet_Progress`。返回新创建的进度事件对象。 |

### 1.10 安全与配置方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure SwitchMaxPerformance; virtual;` | 切换为最大性能模式：关闭加密（`csNone`）、关闭哈希校验、关闭压缩。适用于内网或性能优先场景。 |
| `procedure SwitchMaxSecurity; virtual;` | 切换为最大安全模式：启用强加密（AES256、TwoFish 等）、启用 MD5 哈希校验、启用压缩。适用于公网或安全敏感场景。 |
| `procedure SwitchDefaultPerformance; virtual;` | 切换为默认性能模式：启用快速加密、并行加密、关闭压缩和哈希。是性能和安全的平衡模式。 |
| `procedure CopyParamFrom(Source: TZNet);` | 从源框架复制所有配置参数（加密、压缩、超时、名称等）。 |
| `procedure CopyParamTo(Dest: TZNet);` | 将当前框架的所有配置参数复制到目标框架。 |

### 1.11 P2PVM 自动化方法

| 方法名 | 说明 |
| :--- | :--- |
| `function AutomatedP2PVMClientConnectionDone(P_IO: TPeerIO): Boolean; overload;` | 检查指定 IO 的所有自动 P2PVM 客户端是否已全部连接完成。返回 `True` 表示全部就绪。 |
| `function AutomatedP2PVMClientConnectionDone(): Boolean; overload;` | 检查当前框架（作为客户端）的所有自动 P2PVM 客户端是否已全部连接完成。 |
| `procedure AutomatedP2PVM_Open(P_IO: TPeerIO); overload;` | 为指定 IO 启动自动 P2PVM 隧道建立流程（包括认证、挂载框架、连接虚拟客户端）。 |
| `procedure AutomatedP2PVM_Open(); overload;` | 为当前客户端框架启动自动 P2PVM 隧道建立流程。 |
| `procedure AutomatedP2PVM_Open_C(P_IO: TPeerIO; const OnResult: TOnIOState_C);` | 异步启动自动 P2PVM，C 风格回调。回调参数 `(P_IO: TPeerIO; State: Boolean)`。 |
| `procedure AutomatedP2PVM_Open_M(P_IO: TPeerIO; const OnResult: TOnIOState_M);` | 异步启动自动 P2PVM，M 风格回调。 |
| `procedure AutomatedP2PVM_Open_P(P_IO: TPeerIO; const OnResult: TOnIOState_P);` | 异步启动自动 P2PVM，P 风格回调。 |
| `procedure AutomatedP2PVM_Close(P_IO: TPeerIO); overload;` | 关闭指定 IO 的自动 P2PVM 隧道，断开所有虚拟连接。 |
| `procedure AutomatedP2PVM_Close(); overload;` | 关闭当前客户端框架的自动 P2PVM 隧道。 |
| `function p2pVMTunnelReadyOk(P_IO: TPeerIO): Boolean; overload;` | 检查指定 IO 的 P2PVM 隧道是否已认证就绪。 |
| `function p2pVMTunnelReadyOk(): Boolean; overload;` | 检查当前客户端框架的 P2PVM 隧道是否已认证就绪。 |

### 1.12 打印与调试方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure Print(const v: SystemString); overload;` | 输出调试信息到日志（通过 `DoStatus`）。受 `QuietMode` 控制。 |
| `procedure Print(const v: SystemString; const Args: array of const); overload;` | 格式化输出调试信息。 |
| `procedure PrintParam(const v, Args: SystemString);` | 带参数过滤的打印。仅当 `Args` 对应的命令不在 `PrintParams` 过滤列表中时才输出。 |
| `procedure Error(const v: SystemString); overload;` | 输出错误信息（使用 `DoStatus`）。 |
| `procedure Error(const v: SystemString; const Args: array of const); overload;` | 格式化输出错误信息。 |
| `procedure PrintError(const v: SystemString); overload;` | 同 `Error`。 |
| `procedure PrintError(const v: SystemString; const Args: array of const); overload;` | 同 `Error` 格式化版本。 |
| `procedure PrintErrorParam(const v, Args: SystemString);` | 带参数过滤的错误输出。 |
| `procedure Warning(const v: SystemString);` | 输出警告信息。 |
| `procedure PrintWarning(const v: SystemString);` | 同 `Warning`。 |
| `procedure PrintRegistedCMD; overload;` | 打印所有已注册命令到日志。包含内部系统命令。 |
| `procedure PrintRegistedCMD(prefix: SystemString; incl_internalCMD: Boolean); overload;` | 打印已注册命令，可指定前缀和是否包含内部命令。 |
| `procedure PrintRegistedCMD(prefix: SystemString); overload;` | 打印已注册命令，指定前缀，包含内部命令。 |

### 1.13 同步与锁方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure LockSend;` | 锁定发送操作。内部使用 `FSend_Critical`，若 `EnabledAtomicLockAndMultiThread` 为 `False` 则不执行任何操作。 |
| `procedure UnLockSend;` | 解锁发送操作。 |
| `procedure Lock_All_IO; virtual;` | 锁定所有 IO 操作（遍历 IO 池时使用）。内部使用 `FCritical`。 |
| `procedure UnLock_All_IO; virtual;` | 解锁所有 IO 操作。 |

---

## 2. TZNet_Server — 服务端框架

### 2.1 功能说明

`TZNet_Server` 是 `TZNet` 的服务端实现。它负责：
- 在指定 IP 和端口上监听入站连接。
- 为每个新连接创建 `TPeerIO` 实例，自动完成 `CipherModel` 握手（交换加密密钥、分配 ID、同步服务器状态）。
- 提供丰富的发送 API，支持向指定连接或所有连接发送各类命令。
- 支持同步阻塞式命令发送（`WaitSendConsoleCmd` 等），适用于需要立即返回结果的场景。
- 支持自定义协议模式（`cpCustom`），通过 `OnReceiveBuffer` 事件处理原始数据。
- 内置稳定会话层（`StableIO`）支持，可无缝升级到断线重连会话。

`TZNet_Server` 是构建服务端应用的核心类，通常作为单例运行。

### 2.2 典型用法

```pascal
var
  Server: TZNet_Server;
begin
  Server := TZNet_Server.Create;
  // 注册命令
  Server.RegisterConsole('echo').OnExecute := MyEchoHandler;
  // 启动监听
  if Server.StartService('0.0.0.0', 8080) then
  begin
    while True do
    begin
      Server.Progress;
      Sleep(1);
    end;
  end;
  Server.Free;
end;
```

### 2.3 构造与析构

| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create; virtual;` | 构造服务端实例，哈希池大小默认为 `100000`（`10 * 10000`）。自动注册内部命令 `C_CipherModel` 和 `C_Wait`。 |
| `constructor CreateCustomHashPool(HashPoolSize: Integer); virtual;` | 构造服务端实例，指定哈希池大小。适用于高并发场景（建议 `连接数 * 2`）。 |
| `destructor Destroy; override;` | 析构服务端，停止监听、断开所有连接、释放资源。会等待 HPC 线程完成（超时 5 秒）。 |

### 2.4 公开属性（特有/重载）

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Count` | `Integer` | 只读 | 当前连接总数。 |
| `IO[ID: Cardinal]` | `TPeerIO` | 只读 | 通过 ID 获取连接对象（默认索引属性）。若 ID 不存在返回 `nil`。 |
| `PeerIO[ID: Cardinal]` | `TPeerIO` | 只读 | 同 `IO[ID]`。 |

### 2.5 公开方法

#### 生命周期管理

| 方法名 | 说明 |
| :--- | :--- |
| `function StartService(Host: SystemString; Port: Word): Boolean; virtual;` | 启动监听服务。`Host` 为监听 IP（`'0.0.0.0'` 监听所有 IPv4，`'::'` 监听所有 IPv6），`Port` 为端口号。返回 `True` 表示启动成功。 |
| `procedure StopService; virtual;` | 停止监听服务，断开所有客户端连接并释放资源。 |
| `procedure Progress; override;` | 驱动服务端进度。除调用基类 `Progress` 外，还会驱动 `StableIO`（若已创建）。 |
| `function StableIO: TZNet_StableServer;` | 获取稳定会话层实例。若不存在则自动创建（懒加载）。返回的 `TZNet_StableServer` 实例可配置 `OfflineTimeout` 等参数。 |

#### 发送方法（指定 IO）

| 方法名 | 说明 |
| :--- | :--- |
| `procedure SendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString);` | 向指定连接发送控制台命令（无回调）。 |
| `procedure SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M); overload;` | 向指定连接发送控制台命令，M 风格回调。 |
| `procedure SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M); overload;` | 向指定连接发送控制台命令，带用户参数的 M 风格回调。 |
| `procedure SendConsoleCmdM(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M); overload;` | 向指定连接发送控制台命令，带成功和失败双回调。 |
| `procedure SendConsoleCmdP(...);` | P 风格（嵌套）回调版本，重载同 M 风格。 |
| `procedure SendConsoleCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString);` | 通过 ID 向指定连接发送控制台命令。 |
| `procedure SendConsoleCmdM(IO_ID: Cardinal; ...);` | 通过 ID 发送控制台命令，M 风格回调。 |
| `procedure SendConsoleCmdP(IO_ID: Cardinal; ...);` | 通过 ID 发送控制台命令，P 风格回调。 |
| `procedure SendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;` | 向指定连接发送流命令，`DoneAutoFree` 为 `True` 时自动释放 `StreamData`。 |
| `procedure SendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE); overload;` | 向指定连接发送流命令，从 `TDFE` 编码载荷。 |
| `procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; const OnResult: TOnStream_M; DoneAutoFree: Boolean); overload;` | 流命令 + M 风格回调。 |
| `procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; const OnResult: TOnStream_M); overload;` | 从 TDFE 发送流命令 + M 风格回调。 |
| `procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M); overload;` | 带用户参数的 M 风格回调。 |
| `procedure SendStreamCmdM(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE; Param1: Pointer; Param2: TObject; const OnResult: TOnStreamParam_M; const OnFailed: TOnStreamFailed_M); overload;` | 带成功/失败双回调。 |
| `procedure SendStreamCmdP(...);` | P 风格版本。 |
| `procedure SendStreamCmd(IO_ID: Cardinal; ...);` | 通过 ID 发送流命令。 |
| `procedure SendStreamCmdM(IO_ID: Cardinal; ...);` | 通过 ID 发送流命令 + M 风格回调。 |
| `procedure SendStreamCmdP(IO_ID: Cardinal; ...);` | 通过 ID 发送流命令 + P 风格回调。 |
| `procedure SendConsoleNotifyCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString); overload;` | 向指定连接发送控制台通知（无响应）。 |
| `procedure SendConsoleNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString); overload;` | 向指定连接发送空控制台通知。 |
| `procedure SendConsoleNotifyCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString);` | 通过 ID 发送控制台通知。 |
| `procedure SendConsoleNotifyCmd(IO_ID: Cardinal; const Cmd: SystemString);` | 通过 ID 发送空控制台通知。 |
| `procedure SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;` | 向指定连接发送流通知。 |
| `procedure SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData: TDFE); overload;` | 从 TDFE 发送流通知。 |
| `procedure SendStreamNotifyCmd(P_IO: TPeerIO; const Cmd: SystemString); overload;` | 发送空流通知。 |
| `procedure SendStreamNotifyCmd(IO_ID: Cardinal; ...);` | 通过 ID 发送流通知。 |
| `procedure SendBigStream(P_IO: TPeerIO; const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean); overload;` | 向指定连接发送大流，从 `StartPos` 位置开始传输。 |
| `procedure SendBigStream(P_IO: TPeerIO; const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean); overload;` | 向指定连接发送大流，从头开始。 |
| `procedure SendBigStream(IO_ID: Cardinal; ...);` | 通过 ID 发送大流。 |
| `procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean); overload;` | 向指定连接发送完整缓冲。 |
| `procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean); overload;` | 从 `TMS64` 发送完整缓冲。 |
| `procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean); overload;` | 从 `TMem64` 发送完整缓冲。 |
| `procedure SendCompleteBuffer(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE); overload;` | 从 `TDFE` 编码并发送完整缓冲。 |
| `procedure SendCompleteBuffer_StreamNotify(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE); overload;` | 使用流通知模式发送完整缓冲（等价于 `SendCompleteBuffer` 带 TDFE）。 |
| `procedure SendCompleteBuffer_NoWait_StreamM(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M); overload;` | 无等待流模式发送完整缓冲，M 风格回调。 |
| `procedure SendCompleteBuffer_NoWait_StreamP(P_IO: TPeerIO; const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P); overload;` | 无等待流模式发送完整缓冲，P 风格回调。 |
| `procedure SendCompleteBuffer(IO_ID: Cardinal; ...);` | 通过 ID 发送完整缓冲。 |
| `procedure SendCompleteBuffer_NoWait_StreamM(IO_ID: Cardinal; ...);` | 通过 ID 无等待流发送完整缓冲。 |
| `procedure SendCompleteBuffer_NoWait_StreamP(IO_ID: Cardinal; ...);` | 通过 ID 无等待流发送完整缓冲。 |
| `procedure SendCompleteBuffer_StreamNotify(IO_ID: Cardinal; ...);` | 通过 ID 流通知模式发送完整缓冲。 |
| `procedure Send_NULL(P_IO: TPeerIO); overload;` | 向指定连接发送空命令（Keep-Alive）。 |
| `procedure SendNULL(P_IO: TPeerIO); overload;` | 同 `Send_NULL`。 |
| `procedure Send_NULL(IO_ID: Cardinal); overload;` | 通过 ID 发送空命令。 |

#### 同步等待发送方法

| 方法名 | 说明 |
| :--- | :--- |
| `function WaitSendConsoleCmd(P_IO: TPeerIO; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; overload; virtual;` | **阻塞**发送控制台命令并等待响应。返回响应字符串，超时返回空字符串。**警告**：此方法会阻塞当前线程，仅在测试或简单场景使用。 |
| `procedure WaitSendStreamCmd(P_IO: TPeerIO; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); overload; virtual;` | **阻塞**发送流命令并等待响应，结果写入 `Result_`。 |
| `function WaitSendConsoleCmd(IO_ID: Cardinal; const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; overload;` | 通过 ID 阻塞发送控制台命令。 |
| `procedure WaitSendStreamCmd(IO_ID: Cardinal; const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); overload;` | 通过 ID 阻塞发送流命令。 |

#### 广播方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure BroadcastConsoleNotifyCmd(const Cmd, ConsoleData: SystemString);` | 向所有在线连接广播控制台通知。 |
| `procedure BroadcastStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE);` | 向所有在线连接广播流通知。 |
| `procedure BroadcastCompleteBufferCmd(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt); overload;` | 向所有在线连接广播完整缓冲。 |
| `procedure BroadcastCompleteBufferCmd(const Cmd: SystemString; StreamData: TDFE); overload;` | 从 TDFE 广播完整缓冲。 |

#### IO 管理方法

| 方法名 | 说明 |
| :--- | :--- |
| `function GetCount: Integer;` | 获取当前连接数量。 |
| `function Exists(P_IO: TPeerIO): Boolean; overload;` | 检查连接是否存在。 |
| `function Exists(P_IO: TPeer_IO_User_Define): Boolean; overload;` | 通过用户扩展对象检查连接是否存在。 |
| `function Exists(P_IO: TPeer_IO_User_Special): Boolean; overload;` | 通过特殊用户扩展对象检查连接是否存在。 |
| `function Exists(IO_ID: Cardinal): Boolean; overload;` | 通过 ID 检查连接是否存在。 |
| `function GetPeerIO(ID: Cardinal): TPeerIO;` | 通过 ID 获取连接对象。 |
| `procedure Disconnect(ID: Cardinal); overload;` | 立即断开指定连接。 |
| `procedure Disconnect(ID: Cardinal; delay: Double); overload;` | 延迟指定秒数后断开连接。 |

#### 自定义协议方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure OnReceiveBuffer(Sender: TPeerIO; const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean); virtual;` | 自定义协议模式下的接收回调。当 `Protocol = cpCustom` 时，框架将接收到的原始数据传入此方法。设置 `FillDone := True` 表示数据已被消费。 |
| `procedure BeginWriteBuffer(P_IO: TPeerIO);` | 开始写自定义缓冲（协议模式）。 |
| `procedure EndWriteBuffer(P_IO: TPeerIO);` | 结束写自定义缓冲。 |
| `procedure WriteBuffer(P_IO: TPeerIO; const Buffer: PByte; const Size: NativeInt); overload; virtual;` | 写入自定义协议数据。 |
| `procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMS64); overload;` | 从 TMS64 写入自定义数据。 |
| `procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMem64); overload;` | 从 TMem64 写入自定义数据。 |
| `procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMS64; const doneFreeBuffer: Boolean); overload;` | 写入并自动释放 TMS64。 |
| `procedure WriteBuffer(P_IO: TPeerIO; const Buffer: TMem64; const doneFreeBuffer: Boolean); overload;` | 写入并自动释放 TMem64。 |

#### 生命周期钩子

| 方法名 | 说明 |
| :--- | :--- |
| `procedure DoIOConnectBefore(Sender: TPeerIO); virtual;` | 连接建立前钩子。在 `TPeerIO` 创建后、握手开始前调用。可在此方法中初始化连接专属资源。 |
| `procedure DoIOConnectAfter(Sender: TPeerIO); virtual;` | 连接建立后钩子。在握手完成后调用。此时连接已分配 ID 和密钥，可安全发送数据。 |
| `procedure DoIODisconnect(Sender: TPeerIO); virtual;` | 连接断开钩子。在 `TPeerIO` 销毁前调用。可在此方法中清理连接专属资源。 |

---

## 3. TZNet_Client — 客户端框架

### 3.1 功能说明

`TZNet_Client` 是 `TZNet` 的客户端实现。它负责：
- 主动连接远程服务端，自动完成 `CipherModel` 握手（交换密钥、获取服务端分配的 ID 和配置）。
- 同步服务端状态参数（如 `SyncOnResult`、`MaxCompleteBufferSize` 等），本地框架自动适配。
- 提供丰富的发送 API，与 `TZNet_Server` 的发送 API 相对应。
- 支持同步和异步两种连接模式。
- 支持稳定会话层（`StableIO`）增强断线重连能力。
- 提供 `Wait` 方法用于延迟测试。

`TZNet_Client` 通常作为单例运行，负责与单个服务端通信。

### 3.2 典型用法

```pascal
var
  Client: TZNet_Client;
begin
  Client := TZNet_Client.Create;
  Client.AsyncConnectC('127.0.0.1', 8080,
    procedure(Ok: Boolean)
    begin
      if Ok then
        Client.SendConsoleCmdM('echo', 'Hello',
          procedure(S: TPeerIO; R: string)
          begin
            WriteLn('Response: ', R);
          end
        );
    end
  );
  while not Client.Connected do
  begin
    Client.Progress;
    Sleep(1);
  end;
  // 主循环
  while True do
  begin
    Client.Progress;
    Sleep(1);
  end;
  Client.Free;
end;
```

### 3.3 构造与析构

| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create; virtual;` | 构造客户端实例，哈希池大小默认为 `1`（单连接）。注册内部命令。 |
| `destructor Destroy; override;` | 析构客户端，断开连接、释放资源。 |
| `procedure DelayFreeSelf;` | 延迟释放自身（在 IO 空闲后自动释放）。适用于一次性客户端。 |

### 3.4 公开属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `OnInterface` | `IZNet_ClientInterface` | 读写 | 客户端连接/断开事件接口。实现 `ClientConnected` 和 `ClientDisconnect` 方法监听状态变化。别名：`NotyifyInterface`, `OnNotyifyInterface`。 |
| `AsyncConnectTimeout` | `TTimeTick` | 读写 | 异步连接超时（毫秒）。若在此时间内未完成握手，连接被判定为失败。默认 `60000`（60 秒）。 |
| `OnCipherModelDone` | `TOnCipherModelDone` | 读写 | 握手完成回调。在 `CipherModel` 交换成功后触发，参数为客户端自身。 |
| `ReponseTime` | `TTimeTick` | 只读 | 握手完成耗时（从发送握手请求到收到响应的时间差），可用于评估网络延迟。 |
| `LastConnectIsSuccessed` | `Boolean` | 只读 | 上次连接尝试是否成功。 |
| `P2PVM` | `TZNet_P2PVM` | 只读 | 若连接已开启 P2PVM 隧道，返回隧道实例；否则返回 `nil`。 |
| `P2PVMTunnel` | `TZNet_P2PVM` | 只读 | 同 `P2PVM`。 |

### 3.5 公开方法

#### 连接管理

| 方法名 | 说明 |
| :--- | :--- |
| `function Connect(addr: SystemString; Port: Word): Boolean; virtual;` | **同步**连接服务端。阻塞直至握手完成或超时。返回 `True` 表示连接成功。 |
| `procedure AsyncConnectC(addr: SystemString; Port: Word; const OnResult: TOnState_C); overload; virtual;` | **异步**连接服务端，C 风格回调 `procedure(State: Boolean)`。 |
| `procedure AsyncConnectM(addr: SystemString; Port: Word; const OnResult: TOnState_M); overload; virtual;` | **异步**连接服务端，M 风格回调。 |
| `procedure AsyncConnectP(addr: SystemString; Port: Word; const OnResult: TOnState_P); overload; virtual;` | **异步**连接服务端，P 风格回调。 |
| `procedure AsyncConnectC(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_C); overload;` | **异步**连接服务端，带用户参数，C 风格回调 `procedure(Param1: Pointer; Param2: TObject; State: Boolean)`。 |
| `procedure AsyncConnectM(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_M); overload;` | **异步**连接服务端，带用户参数，M 风格回调。 |
| `procedure AsyncConnectP(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: TOnParamState_P); overload;` | **异步**连接服务端，带用户参数，P 风格回调。 |
| `function Connected: Boolean; virtual;` | 返回是否已连接且握手完成。 |
| `procedure Disconnect; virtual;` | 断开连接。 |
| `procedure DelayCloseIO; overload;` | 延迟关闭底层 IO。 |
| `procedure DelayCloseIO(const t: Double); overload;` | 延迟指定秒数关闭底层 IO。 |
| `function ClientIO: TPeerIO; virtual;` | 获取底层 `TPeerIO` 连接对象。 |
| `function RemoteID: Cardinal;` | 获取服务端分配的连接 ID。 |
| `function RemoteKey: TCipherKeyBuffer;` | 获取当前使用的加密密钥。 |
| `function RemoteInited: Boolean;` | 远程服务端是否已完成握手初始化。 |

#### 发送方法
（与 `TZNet_Server` 的发送方法签名相同，但无 `P_IO` 参数，均作用于当前连接）

| 方法名 | 说明 |
| :--- | :--- |
| `procedure SendConsoleCmd(const Cmd, ConsoleData: SystemString);` | 发送控制台命令。 |
| `procedure SendConsoleCmdM(...);` | 发送控制台命令 + M 回调。 |
| `procedure SendConsoleCmdP(...);` | 发送控制台命令 + P 回调。 |
| `procedure SendStreamCmd(...);` | 发送流命令。 |
| `procedure SendStreamCmdM(...);` | 发送流命令 + M 回调。 |
| `procedure SendStreamCmdP(...);` | 发送流命令 + P 回调。 |
| `procedure SendConsoleNotifyCmd(...);` | 发送控制台通知。 |
| `procedure SendStreamNotifyCmd(...);` | 发送流通知。 |
| `procedure SendBigStream(...);` | 发送大流。 |
| `procedure SendCompleteBuffer(...);` | 发送完整缓冲。 |
| `procedure SendCompleteBuffer_StreamNotify(...);` | 流通知模式发送完整缓冲。 |
| `procedure SendCompleteBuffer_NoWait_StreamM(...);` | 无等待流模式 + M 回调。 |
| `procedure SendCompleteBuffer_NoWait_StreamP(...);` | 无等待流模式 + P 回调。 |
| `procedure Send_NULL();` | 发送空命令。 |
| `procedure SendNULL();` | 同 `Send_NULL`。 |

#### 同步等待方法

| 方法名 | 说明 |
| :--- | :--- |
| `function WaitSendConsoleCmd(const Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString; virtual;` | **阻塞**发送控制台命令并等待响应。 |
| `procedure WaitSendStreamCmd(const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick); virtual;` | **阻塞**发送流命令并等待响应。 |
| `function Wait(TimeOut_: TTimeTick): SystemString;` | 发送空命令测试网络延迟，返回服务端响应的时间戳字符串。 |
| `function WaitC(TimeOut_: TTimeTick; const OnResult: TOnState_C): Boolean;` | 异步延迟测试，C 风格回调。 |
| `function WaitM(TimeOut_: TTimeTick; const OnResult: TOnState_M): Boolean;` | 异步延迟测试，M 风格回调。 |
| `function WaitP(TimeOut_: TTimeTick; const OnResult: TOnState_P): Boolean;` | 异步延迟测试，P 风格回调。 |

#### 状态查询工具

| 方法名 | 说明 |
| :--- | :--- |
| `function ServerState: PZNet_ServerState;` | 获取服务端状态快照指针（包含 `SyncOnResult`、`MaxCompleteBufferSize` 等配置）。 |
| `function WaitSendBusy: Boolean;` | 是否正在等待发送结果（有未完成的同步等待）。 |
| `function LastQueueData: PQueueData;` | 获取发送队列中最后一个数据块。 |
| `function LastQueueCmd: SystemString;` | 获取发送队列中最后一个命令名。 |
| `function QueueCmdCount: Integer;` | 获取发送队列中待发送命令数量。 |
| `function Last_IO_IDLE_Time: TTimeTick;` | 获取底层 IO 的最后空闲时间。 |
| `function Client_ID: Cardinal;` | 获取客户端连接 ID（同 `RemoteID`）。 |

#### IO 空闲跟踪

| 方法名 | 说明 |
| :--- | :--- |
| `procedure IO_IDLE_TraceC(data: TCore_Object; const OnNotify: TOnDataNotify_C);` | 当 IO 变为空闲时执行 C 风格回调。 |
| `procedure IO_IDLE_TraceM(data: TCore_Object; const OnNotify: TOnDataNotify_M);` | 当 IO 变为空闲时执行 M 风格回调。 |
| `procedure IO_IDLE_TraceP(data: TCore_Object; const OnNotify: TOnDataNotify_P);` | 当 IO 变为空闲时执行 P 风格回调。 |
| `procedure IO_IDLE_Trace_And_FreeSelf(Additional_Object_: TCore_Object);` | IO 空闲时释放自身，可传入附加对象一起释放。 |

#### 自定义协议方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure OnReceiveBuffer(const Buffer: PByte; const Size: NativeInt; var FillDone: Boolean); virtual;` | 自定义协议模式接收回调。 |
| `procedure BeginWriteBuffer();` | 开始写自定义缓冲。 |
| `procedure EndWriteBuffer();` | 结束写自定义缓冲。 |
| `procedure WriteBuffer(...);` | 多种重载写自定义缓冲。 |

#### 生命周期钩子

| 方法名 | 说明 |
| :--- | :--- |
| `procedure TriggerDoConnectFailed; virtual;` | 连接失败触发器，可重写以自定义失败处理。 |
| `procedure TriggerDoConnectFinished; virtual;` | 连接成功触发器，可重写以自定义成功处理。 |
| `procedure TriggerDoDisconnect;` | 触发断开事件。 |
| `procedure CipherModelDone; virtual;` | 握手完成钩子，在 `OnCipherModelDone` 之前调用。 |

---


## 4. TPeerIO — 连接状态机

### 4.1 功能说明

`TPeerIO` 是 Z.Net 框架中最核心的类，代表一条活跃的网络连接。每个 `TPeerIO` 实例管理着该连接的全部状态和操作，包括：

- **发送队列管理**：将应用程序发出的命令（`TQueueData`）排队，按优先级和类型依次发送。
- **接收缓冲处理**：维护接收缓冲区，解析协议帧，识别命令类型并分发给对应的命令处理器。
- **大流传输控制**：支持大文件/数据流的分片发送与接收，包含流控信号机制。
- **完整缓冲组装**：将分片到达的完整缓冲数据重组为原子块。
- **加密与解密**：每个连接持有独立的加密密钥和加密/解密实例（支持快速模式）。
- **序列包可靠传输**：在 UDP 或不稳定网络环境下提供基于序号的重传和确认机制。
- **P2PVM 隧道支持**：可在连接之上开启 P2P 虚拟网络覆盖。
- **用户自定义数据挂载**：通过 `UserDefine` 和 `UserSpecial` 挂载业务层会话状态。

`TPeerIO` 由框架自动创建（服务端接受连接时或客户端连接成功后），开发者通常不直接实例化，而是在命令回调中通过 `Sender: TPeerIO` 参数与客户端交互。

### 4.2 典型用法

```pascal
// 在命令回调中向客户端发送响应
procedure MyCommandHandler(Sender: TPeerIO; InData: TDFE; OutData: TDFE);
begin
  // 直接填充 OutData 即可自动发送响应
  OutData.WriteString('OK');
  
  // 也可以主动向该连接发送其他命令（异步推送）
  Sender.SendConsoleNotifyCmd('progress', 'Task completed');
end;

// 主动获取连接并发送消息
var IO: TPeerIO := Server.PeerIO[ClientID];
if IO <> nil then
  IO.SendConsoleCmd('ping', 'hello');
```

### 4.3 公开字段

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FID` | `Cardinal` | 连接唯一标识符，由 `TZNet` 分配。 |
| `FIO_Create_TimeTick` | `TTimeTick` | 连接创建时间戳（毫秒）。 |
| `FHeadToken` | `Cardinal` | 协议帧头标记，默认 `$F0F0F0F0`。 |
| `FTailToken` | `Cardinal` | 协议帧尾标记，默认 `$F1F1F1F1`。 |
| `FConsoleToken` | `Byte` | 控制台命令类型标记，默认 `$F1`。 |
| `FStreamToken` | `Byte` | 流命令类型标记，默认 `$2F`。 |
| `FConsoleNotifyToken` | `Byte` | 控制台通知类型标记，默认 `$F3`。 |
| `FStreamNotifyToken` | `Byte` | 流通知类型标记，默认 `$4F`。 |
| `FBigStreamToken` | `Byte` | 大流命令类型标记，默认 `$F5`。 |
| `FBigStreamReceiveFragmentSignal` | `Byte` | 大流分片信号标记，默认 `$F6`。 |
| `FBigStreamReceiveDoneSignal` | `Byte` | 大流完成信号标记，默认 `$F7`。 |
| `FCompleteBufferToken` | `Byte` | 完整缓冲类型标记，默认 `$6F`。 |
| `FReceivedBuffer` | `TMS64` | 主接收缓冲区，存储待解析的原始数据。 |
| `FReceivedBuffer_Busy` | `TMS64` | 忙时接收缓冲区，在接收处理繁忙时暂存数据。 |
| `FBigStreamReceiveProcessing` | `Boolean` | 是否正在接收大流。 |
| `FBigStreamTotal` | `Int64` | 当前正在接收的大流总字节数。 |
| `FBigStreamCompleted` | `Int64` | 当前大流已接收字节数。 |
| `FBigStreamCmd` | `SystemString` | 当前大流的命令名。 |
| `FSyncBigStreamReceive` | `TCore_Stream` | 同步接收大流时的流对象引用。 |
| `FBigStreamSending` | `TCore_Stream` | 当前正在发送的大流对象。 |
| `FBigStreamSendCurrentPos` | `Int64` | 大流发送的当前位置偏移量。 |
| `FBigStreamSendDoneTimeFree` | `Boolean` | 大流发送完成后是否自动释放流对象。 |
| `FWaitBigStreamReceiveDoneSignal` | `Boolean` | 是否正在等待大流完成信号。 |
| `FCompleteBufferReceiveProcessing` | `Boolean` | 是否正在接收完整缓冲。 |
| `FCompleteBufferTotal` | `Cardinal` | 当前完整缓冲的总大小。 |
| `FCompleteBufferCompressedSize` | `Cardinal` | 压缩后的完整缓冲大小（0 表示未压缩）。 |
| `FCompleteBufferCompleted` | `Cardinal` | 当前完整缓冲已接收字节数。 |
| `FCompleteBufferCmd` | `SystemString` | 当前完整缓冲的命令名。 |
| `FCompleteBufferReceivedStream` | `TMS64` | 正在组装的完整缓冲数据流。 |
| `FCompleteBuffer_Current_Trigger` | `TMS64` | 当前触发的完整缓冲数据（传递给命令处理器）。 |
| `FCurrentQueueData` | `PQueueData` | 当前正在处理的队列数据项。 |
| `FWaitOnResult` | `Boolean` | 是否正在等待远程响应。 |
| `FPause_Result_Send` | `Boolean` | 是否暂停了结果发送（用于异步桥接）。 |
| `FReceiveTriggerRuning` | `Boolean` | 接收触发器是否正在运行。 |
| `FReceiveDataCipherSecurity` | `TCipherSecurity` | 接收数据使用的加密算法。 |
| `FResultDataBuffer` | `TMS64` | 暂存待发送的结果数据。 |
| `FSendDataCipherSecurity` | `TCipherSecurity` | 发送数据使用的加密算法。 |
| `FCipherKey` | `TCipherKeyBuffer` | 本连接专属的加密密钥。 |
| `FDecryptInstance` | `TCipher_Base` | 解密实例（快速加密模式下复用）。 |
| `FEncryptInstance` | `TCipher_Base` | 加密实例（快速加密模式下复用）。 |
| `FSend_Queue_Pool` | `TQueueData_Pool` | 发送队列（FIFO）。 |
| `FLastCommunicationTick` | `TTimeTick` | 最后通信时间戳。 |
| `FRemoteExecutedForConnectInit` | `Boolean` | 远程是否已完成握手初始化。 |
| `FInCmd` | `SystemString` | 当前接收的命令名。 |
| `FInText` | `SystemString` | 当前接收的控制台文本数据。 |
| `FOutText` | `SystemString` | 当前待发送的控制台文本数据。 |
| `FInDataFrame` | `TDFE` | 当前接收的流数据。 |
| `FOutDataFrame` | `TDFE` | 当前待发送的流数据。 |
| `FResult_Text` | `SystemString` | 控制台命令的结果文本。 |
| `FResult_DFE` | `TDFE` | 流命令的结果数据。 |
| `FSyncPick` | `PQueueData` | 同步发送时正在处理的队列项。 |
| `FWaitSendBusy` | `Boolean` | 同步发送忙碌标志。 |
| `FReceiveCommandRuning` | `Boolean` | 命令正在执行标志。 |
| `FReceiveResultRuning` | `Boolean` | 结果正在执行标志。 |
| `FProgressRunning` | `Boolean` | `Progress` 方法重入保护标志。 |
| `FTimeOutProcessDone` | `Boolean` | 超时处理已完成标志。 |
| `FLast_IO_Is_IDLE` | `Boolean` | 上次检测时 IO 是否为空闲。 |
| `FLast_IO_IDLE_Time` | `TTimeTick` | 最后进入空闲状态的时间戳。 |
| `FSequencePacketActivted` | `Boolean` | 序列包模型是否激活。 |
| `FSequencePacketSignal` | `Boolean` | 序列包信号是否启用。 |
| `SequenceNumberOnSendCounter` | `Cardinal` | 发送序号计数器。 |
| `SequenceNumberOnReceivedCounter` | `Cardinal` | 接收序号计数器。 |
| `SendingSequencePacketHistory` | `TSequence_Packet_Hash_Pool` | 已发送序列包历史（用于重传）。 |
| `SequencePacketReceivedPool` | `TSequence_Packet_Hash_Pool` | 已接收序列包池（用于排序）。 |
| `FSequencePacketMTU` | `Word` | 序列包最大传输单元，默认 `1536`。 |
| `FSequencePacketLimitPhysicsMemory` | `Int64` | 序列包内存使用上限（`0` 表示不限制）。 |
| `FP2PVMTunnel` | `TZNet_P2PVM` | P2PVM 隧道实例（若已开启）。 |
| `FP2PVM_Auth_Token` | `TBytes` | P2PVM 认证令牌。 |
| `FP2PVM_Cipher_Key` | `TCipherKeyBuffer` | P2PVM 加密密钥。 |
| `FP2PVM_Cipher` | `TCipher_Base` | P2PVM 加密实例。 |
| `FUserData` | `Pointer` | 用户自定义数据指针。 |
| `FUserValue` | `Variant` | 用户自定义 Variant 值。 |
| `FUserVariants` | `THashVariantList` | 用户 Variant 键值存储（懒加载）。 |
| `FUserObjects` | `THashObjectList` | 用户对象存储（不自动释放，懒加载）。 |
| `FUserAutoFreeObjects` | `THashObjectList` | 用户对象存储（自动释放，懒加载）。 |
| `FUser_Define` | `TPeer_IO_User_Define` | 主用户扩展对象。 |
| `FUser_Special` | `TPeer_IO_User_Special` | 辅助用户扩展对象。 |

### 4.4 公开属性

| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `ID` | `Cardinal` | 读写 | 连接唯一标识。修改 ID 会更新 IO 池中的映射。 |
| `PeerIP` | `SystemString` | 只读 | 对端 IP 地址。 |
| `UserDefine` | `TPeer_IO_User_Define` | 只读 | 主用户扩展对象，由 `PeerIOUserDefineClass` 工厂创建。 |
| `IODefine` | `TPeer_IO_User_Define` | 只读 | 同 `UserDefine`。 |
| `Define` | `TPeer_IO_User_Define` | 只读 | 同 `UserDefine`。 |
| `UserSpecial` | `TPeer_IO_User_Special` | 只读 | 辅助用户扩展对象。 |
| `IOSpecial` | `TPeer_IO_User_Special` | 只读 | 同 `UserSpecial`。 |
| `Special` | `TPeer_IO_User_Special` | 只读 | 同 `UserSpecial`。 |
| `UserVariants` | `THashVariantList` | 只读 | 用户 Variant 存储（懒加载，首次访问时创建）。 |
| `UserObjects` | `THashObjectList` | 只读 | 用户对象存储（不自动释放）。 |
| `UserAutoFreeObjects` | `THashObjectList` | 只读 | 用户对象存储（连接断开时自动释放）。 |
| `UserData` | `Pointer` | 读写 | 用户数据指针，任意用途。 |
| `UserValue` | `Variant` | 读写 | 用户 Variant，任意用途。 |
| `P2PVM` | `TZNet_P2PVM` | 只读 | P2PVM 隧道实例（未开启则返回 `nil`）。 |
| `P2PVMTunnel` | `TZNet_P2PVM` | 只读 | 同 `P2PVM`。 |
| `P2PVM_Auth_Token` | `TBytes` | 只读 | P2PVM 认证令牌。 |
| `P2PVM_Cipher_Key` | `TCipherKeyBuffer` | 只读 | P2PVM 加密密钥。 |
| `P2PVM_Cipher` | `TCipher_Base` | 只读 | P2PVM 加密实例。 |
| `SequencePacketSignal` | `Boolean` | 只读 | 序列包信号是否启用。 |
| `SequencePacketMTU` | `Word` | 读写 | 序列包 MTU。 |
| `SequencePacketLimitOwnerIOMemory` | `Int64` | 读写 | 序列包内存上限。 |
| `SequencePacketUsagePhysicsMemory` | `Int64` | 只读 | 当前序列包内存使用量。 |
| `SequencePacketState` | `SystemString` | 只读 | 序列包状态描述字符串。 |
| `CurrentCommand` | `SystemString` | 只读 | 当前正在处理的命令名。 |
| `CurrentCmd` | `SystemString` | 只读 | 同 `CurrentCommand`。 |
| `CompleteBufferCmd` | `SystemString` | 只读 | 当前正在接收的完整缓冲命令名。 |
| `BigStreamBatch` | `TBigStreamBatch` | 只读 | 大流批量数据列表。 |
| `BigStreamBatchList` | `TBigStreamBatch` | 只读 | 同 `BigStreamBatch`。 |
| `Last_IO_IDLE_Time` | `TTimeTick` | 只读 | 最后进入空闲状态的时间戳。 |
| `LastCommunicationTime` | `TTimeTick` | 只读 | 最后通信时间戳。 |
| `LastCommunicationTimeTick` | `TTimeTick` | 只读 | 同 `LastCommunicationTime`。 |
| `OwnerFramework` | `TZNet` | 只读 | 所属框架实例。 |
| `SendCipherSecurity` | `TCipherSecurity` | 读写 | 发送数据使用的加密算法。 |
| `CipherKey` | `TCipherKeyBuffer` | 只读 | 本连接加密密钥。 |
| `InText` | `SystemString` | 只读 | 当前接收的控制台文本。 |
| `InConsole` | `SystemString` | 只读 | 同 `InText`。 |
| `OutText` | `SystemString` | 读写 | 当前待发送的控制台文本。 |
| `OutConsole` | `SystemString` | 读写 | 同 `OutText`。 |
| `InDataFrame` | `TDFE` | 只读 | 当前接收的流数据。 |
| `InDFE` | `TDFE` | 只读 | 同 `InDataFrame`。 |
| `OutDataFrame` | `TDFE` | 只读 | 当前待发送的流数据。 |
| `OutDFE` | `TDFE` | 只读 | 同 `OutDataFrame`。 |
| `WaitOnResult` | `Boolean` | 只读 | 是否正在等待远程响应。 |
| `AllSendProcessing` | `Boolean` | 只读 | 发送处理是否正在运行。 |
| `BigStreamReceiveing` | `Boolean` | 只读 | 是否正在接收大流。 |
| `WaitSendBusy` | `Boolean` | 只读 | 同步发送是否忙碌。 |
| `ReceiveProcessing` | `Boolean` | 只读 | 接收处理是否正在运行。 |
| `ReceiveCommandRuning` | `Boolean` | 只读 | 命令处理是否正在运行。 |
| `ReceiveResultRuning` | `Boolean` | 只读 | 结果处理是否正在运行。 |
| `ResultSendIsPaused` | `Boolean` | 只读 | 结果发送是否已暂停。 |
| `ResultIsPaused` | `Boolean` | 只读 | 同 `ResultSendIsPaused`。 |
| `Disable_Progress` | `Boolean` | 只读 | 是否禁用了进度处理。 |
| `CurrentQueueData` | `PQueueData` | 只读 | 当前正在处理的队列数据项。 |
| `CompleteBufferReceivedStream` | `TMS64` | 只读 | 正在组装的完整缓冲流。 |
| `CompleteBuffer_Current_Trigger` | `TMS64` | 只读 | 当前触发的完整缓冲数据。 |

### 4.5 构造与析构

| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(OwnerFramework_: TZNet; IOInterface_: TCore_Object);` | 构造 `TPeerIO` 实例。由 `TZNet` 在连接建立时调用。初始化所有缓冲区、队列、加密密钥，并将自身注册到 IO 池。 |
| `procedure CreateAfter; virtual;` | 构造后虚钩子，派生类可重写以执行额外初始化。在 `Create` 末尾自动调用。 |
| `destructor Destroy; override;` | 析构函数。释放所有缓冲区、队列项、加密实例、P2PVM 隧道、用户扩展对象等资源。从 IO 池中移除自身。 |

### 4.6 核心方法

| 方法名 | 说明 |
| :--- | :--- |
| `function Connected: Boolean; virtual;` | 返回连接是否有效（对于物理连接，始终返回 `True`，因为 `TPeerIO` 存在即表示连接有效）。在 P2PVM 虚拟连接中，此方法会检查底层物理连接状态。 |
| `procedure Disconnect; virtual;` | 主动断开连接。释放 `TPeerIO` 实例并通知框架。 |
| `procedure DelayClose; overload;` | 延迟关闭（立即在下一进度循环执行）。 |
| `procedure DelayClose(const t: Double); overload;` | 延迟指定秒数后关闭连接。 |
| `procedure DelayFree; overload;` | 延迟释放（立即在下一进度循环执行）。 |
| `procedure DelayFree(const t: Double); overload;` | 延迟指定秒数后释放连接对象。 |
| `procedure Progress; virtual;` | 驱动连接状态机。执行接收缓冲处理、发送队列处理、序列包管理、P2PVM 进度、空闲超时检测等。由框架的 `Progress` 循环定期调用。 |
| `procedure Process_Receive_Buffer();` | 处理接收缓冲区数据。解析协议帧，识别命令类型，分发给对应的命令处理器。 |
| `procedure Process_Send_Buffer();` | 处理发送队列。从队列中取出待发送命令，序列化并发送到对端。 |
| `procedure Pause; virtual;` | 暂停当前命令的结果发送。用于异步桥接模式，在命令处理器中调用后，框架不会立即发送 `OutData`，等待 `Resume` 调用。 |
| `procedure Resume; virtual;` | 恢复结果发送。将 `OutData` 编码并发送到对端。 |
| `procedure PauseResultSend;` | 同 `Pause`。 |
| `procedure BreakResultSend;` | 同 `Pause`。 |
| `procedure SkipResultSend;` | 同 `Pause`。 |
| `procedure NoResultSend;` | 同 `Pause`。 |
| `procedure StopResultSend;` | 同 `Pause`。 |
| `procedure ContinueResultSend;` | 同 `Resume`。 |
| `procedure Continue_Send_Result;` | 同 `Resume`。 |
| `procedure ResumeResultSend;` | 同 `Resume`。 |
| `procedure NowResultSend;` | 同 `Resume`。 |
| `function IOBusy: Boolean;` | 检查连接是否繁忙（有待发送数据、待处理接收数据或正在执行命令）。 |
| `function NoneCommunicationTime: TTimeTick;` | 返回从最后通信时刻到现在的毫秒数。 |
| `procedure UpdateLastCommunicationTime;` | 更新最后通信时间戳为当前时间。 |
| `procedure GenerateHashCode(const hs: THashSecurity; buff: Pointer; siz: Integer; var output: TBytes);` | 生成哈希校验码。使用指定的哈希算法对数据进行哈希计算。 |
| `function VerifyHashCode(const hs: THashSecurity; buff: Pointer; siz: Integer; var Code: TBytes): Boolean;` | 验证哈希校验码。比对计算出的哈希与传入的哈希是否一致。 |
| `procedure Encrypt(CS: TCipherSecurity; DataPtr: Pointer; Size: Cardinal; var k: TCipherKeyBuffer; enc: Boolean);` | 加密或解密数据。根据 `enc` 参数决定加密或解密，使用连接专属密钥。支持快速加密模式（复用实例）。 |
| `function GetPeerIP: SystemString; virtual;` | 获取对端 IP 地址字符串。 |
| `procedure Print(const v: SystemString); overload;` | 输出调试信息到日志。受 `QuietMode` 控制。 |
| `procedure Print(const v: SystemString; const Args: array of const); overload;` | 格式化输出调试信息。 |
| `procedure PrintCommand(const v, Args: SystemString);` | 带命令名过滤的打印。仅当命令名不在 `PrintParams` 过滤列表中时输出。 |
| `procedure PrintParam(const v, Args: SystemString);` | 同 `PrintCommand`。 |
| `procedure PrintError(const v: SystemString); overload;` | 输出错误信息。 |
| `procedure PrintError(const v: SystemString; const Args: array of const); overload;` | 格式化输出错误信息。 |
| `procedure PrintWarning(const v: SystemString); overload;` | 输出警告信息。 |
| `procedure PrintWarning(const v: SystemString; const Args: array of const); overload;` | 格式化输出警告信息。 |
| `procedure IO_IDLE_TraceC(data: TCore_Object; OnNotify: TOnDataNotify_C);` | 当连接变为空闲时执行 C 风格回调。若已空闲则立即执行，否则在空闲后执行。 |
| `procedure IO_IDLE_TraceM(data: TCore_Object; OnNotify: TOnDataNotify_M);` | 当连接变为空闲时执行 M 风格回调。 |
| `procedure IO_IDLE_TraceP(data: TCore_Object; OnNotify: TOnDataNotify_P);` | 当连接变为空闲时执行 P 风格回调。 |

### 4.7 发送命令方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure SendConsoleCmd(const Cmd, ConsoleData: SystemString);` | 发送控制台命令（无回调）。 |
| `procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; const OnResult: TOnConsole_M); overload;` | 发送控制台命令，M 风格回调。 |
| `procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M); overload;` | 发送控制台命令，带用户参数的 M 风格回调。 |
| `procedure SendConsoleCmdM(const Cmd, ConsoleData: SystemString; Param1: Pointer; Param2: TObject; const OnResult: TOnConsoleParam_M; const OnFailed: TOnConsoleFailed_M); overload;` | 发送控制台命令，带成功和失败双回调。 |
| `procedure SendConsoleCmdP(...);` | P 风格版本。 |
| `procedure SendStreamCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;` | 发送流命令。 |
| `procedure SendStreamCmd(const Cmd: SystemString; StreamData: TDFE); overload;` | 从 `TDFE` 编码并发送流命令。 |
| `procedure SendStreamCmdM(...);` | 流命令 + M 风格回调。 |
| `procedure SendStreamCmdP(...);` | 流命令 + P 风格回调。 |
| `procedure SendConsoleNotifyCmd(const Cmd, ConsoleData: SystemString); overload;` | 发送控制台通知（无响应）。 |
| `procedure SendConsoleNotifyCmd(const Cmd: SystemString); overload;` | 发送空控制台通知。 |
| `procedure SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TMS64; DoneAutoFree: Boolean); overload;` | 发送流通知。 |
| `procedure SendStreamNotifyCmd(const Cmd: SystemString; StreamData: TDFE); overload;` | 从 `TDFE` 编码并发送流通知。 |
| `procedure SendStreamNotifyCmd(const Cmd: SystemString); overload;` | 发送空流通知。 |
| `procedure SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; StartPos: Int64; DoneAutoFree: Boolean); overload;` | 发送大流，从指定位置开始。 |
| `procedure SendBigStream(const Cmd: SystemString; BigStream: TCore_Stream; DoneAutoFree: Boolean); overload;` | 发送大流，从头开始。 |
| `procedure SendCompleteBuffer(const Cmd: SystemString; buff: PByte; BuffSize: NativeInt; DoneAutoFree: Boolean); overload;` | 发送完整缓冲。 |
| `procedure SendCompleteBuffer(const Cmd: SystemString; buff: TMS64; DoneAutoFree: Boolean); overload;` | 从 `TMS64` 发送完整缓冲。 |
| `procedure SendCompleteBuffer(const Cmd: SystemString; buff: TMem64; DoneAutoFree: Boolean); overload;` | 从 `TMem64` 发送完整缓冲。 |
| `procedure SendCompleteBuffer(const Cmd: SystemString; buff: TDFE); overload;` | 从 `TDFE` 编码并发送完整缓冲。 |
| `procedure SendCompleteBuffer_StreamNotify(const Cmd: SystemString; buff: TDFE);` | 使用流通知模式发送完整缓冲。 |
| `procedure SendCompleteBuffer_NoWait_StreamM(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_M);` | 无等待流模式发送完整缓冲，M 风格回调。 |
| `procedure SendCompleteBuffer_NoWait_StreamP(const Cmd: SystemString; buff: TDFE; OnResult: TOnStream_P);` | 无等待流模式发送完整缓冲，P 风格回调。 |
| `procedure Send_NULL();` | 发送空命令（Keep-Alive）。 |
| `procedure SendNULL();` | 同 `Send_NULL`。 |

### 4.8 同步等待方法

| 方法名 | 说明 |
| :--- | :--- |
| `function WaitSendConsoleCmd(Cmd, ConsoleData: SystemString; TimeOut_: TTimeTick): SystemString;` | **阻塞**发送控制台命令并等待响应。返回响应字符串，超时返回空字符串。 |
| `procedure WaitSendStreamCmd(const Cmd: SystemString; StreamData, Result_: TDFE; TimeOut_: TTimeTick);` | **阻塞**发送流命令并等待响应，结果写入 `Result_`。 |

### 4.9 P2PVM 相关方法

| 方法名 | 说明 |
| :--- | :--- |
| `function p2pVMTunnelReadyOk: Boolean;` | 检查 P2PVM 隧道是否已认证就绪。 |
| `procedure BuildP2PAuthToken; overload;` | 构建 P2PVM 认证令牌（同步）。 |
| `procedure BuildP2PAuthTokenC(const OnResult: TOnNotify_C);` | 异步构建认证令牌，C 风格回调。 |
| `procedure BuildP2PAuthTokenM(const OnResult: TOnNotify_M);` | 异步构建认证令牌，M 风格回调。 |
| `procedure BuildP2PAuthTokenP(const OnResult: TOnNotify_P);` | 异步构建认证令牌，P 风格回调。 |
| `procedure BuildP2PAuthTokenIO_C(const OnResult: TOnIONotify_C);` | 异步构建认证令牌，C 风格带 IO 引用回调。 |
| `procedure BuildP2PAuthTokenIO_M(const OnResult: TOnIONotify_M);` | 异步构建认证令牌，M 风格带 IO 引用回调。 |
| `procedure BuildP2PAuthTokenIO_P(const OnResult: TOnIONotify_P);` | 异步构建认证令牌，P 风格带 IO 引用回调。 |
| `procedure OpenP2PVMTunnel(SendRemoteRequest: Boolean; const AuthToken: SystemString); overload;` | 开启 P2PVM 隧道。`SendRemoteRequest` 为 `True` 时向对端发送初始化请求，`AuthToken` 为认证令牌。 |
| `procedure OpenP2PVMTunnelC(SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_C); overload;` | 异步开启 P2PVM 隧道，C 风格回调。 |
| `procedure OpenP2PVMTunnelM(...);` | 异步开启，M 风格回调。 |
| `procedure OpenP2PVMTunnelP(...);` | 异步开启，P 风格回调。 |
| `procedure OpenP2PVMTunnelC(vmHashPoolSize: Integer; SendRemoteRequest: Boolean; const AuthToken: SystemString; const OnResult: TOnState_C); overload;` | 异步开启 P2PVM 隧道，指定 VM 哈希池大小。 |
| `procedure OpenP2PVMTunnelM(...);` | 异步开启，M 风格回调，指定哈希池大小。 |
| `procedure OpenP2PVMTunnelP(...);` | 异步开启，P 风格回调，指定哈希池大小。 |
| `procedure OpenP2PVMTunnelIO_C(...);` | 异步开启，C 风格带 IO 引用回调。 |
| `procedure OpenP2PVMTunnelIO_M(...);` | 异步开启，M 风格带 IO 引用回调。 |
| `procedure OpenP2PVMTunnelIO_P(...);` | 异步开启，P 风格带 IO 引用回调。 |
| `procedure OpenP2PVMTunnel; overload;` | 使用默认参数开启 P2PVM 隧道（`SendRemoteRequest=False`, `AuthToken=''`）。 |
| `procedure CloseP2PVMTunnel;` | 关闭 P2PVM 隧道。 |
| `procedure DoP2PVM_Created(Sender: TZNet_P2PVM); virtual;` | P2PVM 创建钩子。在 P2PVM 隧道实例创建后调用。 |
| `procedure DoP2PVM_InstallLogicFramework(Inst: TZNet); virtual;` | 安装逻辑框架钩子。在逻辑框架挂载到 P2PVM 时调用。 |
| `procedure DoP2PVM_UninstallLogicFramework(Inst: TZNet); virtual;` | 卸载逻辑框架钩子。在逻辑框架从 P2PVM 卸载时调用。 |

### 4.10 双通道相关方法

| 方法名 | 说明 |
| :--- | :--- |
| `function Is_Double_Tunnel: Boolean;` | 检查连接是否处于双通道模式（Recv/Send 分离）。 |
| `function Is_Recveive_Tunnel: Boolean;` | 检查当前 IO 是否为接收隧道。 |
| `function Is_Send_Tunnel: Boolean;` | 检查当前 IO 是否为发送隧道。 |
| `function Is_Link_OK: Boolean;` | 检查双通道链接是否正常（发送隧道和接收隧道均已连接）。 |
| `function Get_Send_Tunnel_IO: TPeerIO;` | 获取发送隧道的 IO 对象。 |
| `function Get_Send_Tunnel(var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean;` | 获取发送隧道的框架引用和 IO ID。 |
| `function Get_Recv_Tunnel_IO: TPeerIO;` | 获取接收隧道的 IO 对象。 |
| `function Get_Recv_Tunnel(var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean;` | 获取接收隧道的框架引用和 IO ID。 |

### 4.11 自定义协议方法

| 方法名 | 说明 |
| :--- | :--- |
| `procedure BeginWriteCustomBuffer;` | 开始写入自定义协议数据（打开写缓冲）。 |
| `procedure EndWriteCustomBuffer;` | 结束写入自定义协议数据（刷新并关闭缓冲）。 |
| `procedure WriteCustomBuffer(const Buffer: PByte; const Size: NativeInt); overload; virtual;` | 写入自定义协议数据。 |
| `procedure WriteCustomBuffer(const Buffer: TMS64); overload;` | 从 `TMS64` 写入自定义数据。 |
| `procedure WriteCustomBuffer(const Buffer: TMem64); overload;` | 从 `TMem64` 写入自定义数据。 |
| `procedure WriteCustomBuffer(const Buffer: TMS64; const doneFreeBuffer: Boolean); overload;` | 写入自定义数据并自动释放 `TMS64`。 |
| `procedure WriteCustomBuffer(const Buffer: TMem64; const doneFreeBuffer: Boolean); overload;` | 写入自定义数据并自动释放 `TMem64`。 |

---

## 5. 辅助类（Helper Classes）

### 5.1 TIO_ID_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | IO ID 池，用于分配和回收连接 ID。基于 `TBigList<Cardinal>` 实现，支持 ID 的重复利用。 |
| **典型用法** | 框架内部使用，开发者通常不直接操作。 |
| **继承** | `TBigList<Cardinal>` |

**公开成员**：无额外成员，继承自 `TBigList<Cardinal>`。

---

### 5.2 TIO_ID_List

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 简单的 IO ID 列表，基于 `TGenericsList<Cardinal>` 实现。用于存储和遍历 IO ID。 |
| **典型用法** | 框架内部使用，用于 `GetIO_Array` 等方法返回 ID 列表。 |
| **继承** | `TGenericsList<Cardinal>` |

**公开成员**：无额外成员，继承自 `TGenericsList<Cardinal>`。

---

### 5.3 TOnStateStruct

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 包含三种风格（C/M/P）状态回调的记录类型。用于统一传递状态回调。 |
| **典型用法** | 在需要同时支持三种回调风格的 API 内部使用。 |
| **类型** | `record` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `On_C` | `TOnState_C` | C 风格状态回调。 |
| `On_M` | `TOnState_M` | M 风格状态回调。 |
| `On_P` | `TOnState_P` | P 风格状态回调。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure Init;` | 将所有回调字段清空为 `nil`。 |

---

### 5.4 TOnResult_Bridge_Templet

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 结果桥接器的抽象基类。用于自定义异步结果的接收和处理。子类可重写相应的 `Do*Event` 方法。 |
| **典型用法** | 继承此类并重写 `DoStreamEvent` 等方法，然后作为回调参数传递给发送函数。 |
| **继承** | `TCore_Object_Intermediate` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure DoConsoleEvent(Sender: TPeerIO; Result_: SystemString); virtual;` | 处理控制台结果。 |
| `procedure DoConsoleParamEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: SystemString); virtual;` | 处理带参数的控制台结果。 |
| `procedure DoConsoleFailedEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: SystemString); virtual;` | 处理控制台失败。 |
| `procedure DoStreamEvent(Sender: TPeerIO; Result_: TDFE); virtual;` | 处理流结果。 |
| `procedure DoStreamParamEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData, Result_: TDFE); virtual;` | 处理带参数的流结果。 |
| `procedure DoStreamFailedEvent(Sender: TPeerIO; Param1: Pointer; Param2: TObject; SendData: TDFE); virtual;` | 处理流失败。 |
| `procedure DoCompleteBufferStreamEvent(Sender: TCommandCompleteBuffer_NoWait_Bridge; InData, OutData: TDFE); virtual;` | 处理完整缓冲流桥接事件。 |

---

### 5.5 TOnResult_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | `TOnResult_Bridge_Templet` 的具体实现类，可直接创建使用。所有 `Do*Event` 方法默认为空，可由用户赋值具体事件处理器。 |
| **典型用法** | 创建实例，为 `OnResultM` 等事件赋值，然后作为回调参数传递。 |
| **继承** | `TOnResult_Bridge_Templet` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |

---

### 5.6 TProgress_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 绑定到框架 `Progress` 事件的桥接器，用于执行周期性任务。 |
| **典型用法** | 创建实例并重写 `Progress` 方法，或为 `OnProgress_M` 事件赋值。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Framework` | `TZNet` | 目标框架。 |
| `ProgressInstance` | `TZNet_Progress` | 进度事件实例。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Framework_: TZNet); virtual;` | 构造，自动创建并挂载进度事件。 |
| `destructor Destroy; override;` | 析构，自动释放进度事件。 |
| `procedure Progress(Sender: TZNet_Progress); virtual;` | 进度回调，重写此方法实现周期逻辑。 |

---

### 5.7 TState_Param_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 将带参数的异步状态回调转换为标准 `TOnState_M` 风格，便于与框架 API 对接。 |
| **典型用法** | 创建实例，设置 `Param1`/`Param2` 和对应的 `OnNotifyC/M/P` 回调，然后将 `OnStateMethod` 传给框架。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `OnNotifyC` | `TOnParamState_C` | C 风格回调。 |
| `OnNotifyM` | `TOnParamState_M` | M 风格回调。 |
| `OnNotifyP` | `TOnParamState_P` | P 风格回调。 |
| `Param1` | `Pointer` | 用户参数 1。 |
| `Param2` | `TObject` | 用户参数 2。 |
| `OnStateMethod` | `TOnState_M` | 内部状态方法。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create; virtual;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `procedure DoStateResult(const State: Boolean);` | 触发回调并自动释放自身。 |

---

### 5.8 TCustom_Event_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 绑定到特定 IO 的进度事件桥接器，用于在连接生命周期内执行周期性检查或任务。 |
| **典型用法** | 创建实例，传入目标 IO，重写 `Progress` 方法实现针对该连接的周期逻辑。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Framework_` | `TZNet` | 父框架。 |
| `ID_` | `Cardinal` | IO 标识。 |
| `ProgressInstance` | `TZNet_Progress` | 进度事件实例。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(IO_: TPeerIO); virtual;` | 构造，自动创建并挂载进度事件到指定 IO。 |
| `destructor Destroy; override;` | 析构，自动释放进度事件。 |
| `function CheckIO: Boolean; virtual;` | 检查 IO 是否仍在线。 |
| `function IO: TPeerIO; virtual;` | 获取 IO 引用。 |
| `procedure Progress(Sender: TZNet_Progress); virtual;` | 进度回调，重写此方法实现周期逻辑。 |

---

### 5.9 TStream_Event_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 在流命令处理中提供暂停/恢复结果发送能力的桥接器。适用于命令处理需要异步等待（如数据库查询、后台线程）的场景。 |
| **典型用法** | 在命令处理器中创建桥接器，调用 `Pause` 暂停响应，完成异步任务后调用 `Play` 发送结果并自动释放。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `OnResultC` | `TOnStream_Event_Bridge_Event_C` | C 风格结果回调。 |
| `OnResultM` | `TOnStream_Event_Bridge_Event_M` | M 风格结果回调。 |
| `OnResultP` | `TOnStream_Event_Bridge_Event_P` | P 风格结果回调。 |
| `AutoPause` | `Boolean` | 是否自动暂停结果发送。 |
| `AutoFree` | `Boolean` | 完成后是否自动释放。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(IO_: TPeerIO; AutoPause_: Boolean); overload;` | 构造，指定是否自动暂停。 |
| `constructor Create(IO_: TPeerIO); overload;` | 构造，`AutoPause` 默认为 `True`。 |
| `destructor Destroy; override;` | 析构。 |
| `procedure Pause;` | 暂停结果发送。 |
| `procedure Play(ResultData_: TDFE);` | 发送结果并恢复（若 `AutoFree` 为 `True` 则自动释放）。 |

---

### 5.10 TConsole_Event_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 与 `TStream_Event_Bridge` 类似，但针对控制台命令，载荷为字符串。 |
| **典型用法** | 在控制台命令处理器中创建，用于异步发送响应。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：（同 `TStream_Event_Bridge`，但回调类型为控制台版本）

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(IO_: TPeerIO; AutoPause_: Boolean); overload;` | 构造。 |
| `constructor Create(IO_: TPeerIO); overload;` | 构造，`AutoPause` 默认为 `True`。 |
| `destructor Destroy; override;` | 析构。 |
| `procedure Pause;` | 暂停结果发送。 |
| `procedure Play(ResultData_: SystemString);` | 发送结果并恢复。 |

---

### 5.11 TCustom_CompleteBuffer_Stream_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 为 `TCommandCompleteBuffer_NoWait_Bridge` 提供进度事件的桥接器。 |
| **典型用法** | 框架内部使用。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Bridge` | `TCommandCompleteBuffer_NoWait_Bridge` | 关联的桥接器。 |
| `ProgressInstance` | `TZNet_Progress` | 进度事件实例。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge); virtual;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function CheckIO: Boolean; virtual;` | 检查 IO 是否在线。 |
| `function IO: TPeerIO; virtual;` | 获取 IO 引用。 |
| `procedure Progress(Sender: TZNet_Progress); virtual;` | 进度回调。 |

---

### 5.12 TCompleteBuffer_Stream_Event_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 专用于 `TCommandCompleteBuffer_NoWait_Bridge_Stream` 命令的桥接器，提供完整的流事件处理能力。 |
| **典型用法** | 在桥接命令处理器中创建，通过 `Play` 方法发送结果。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Framework_` | `TZNet` | 父框架。 |
| `Bridge` | `TCommandCompleteBuffer_NoWait_Bridge` | 源桥接器。 |
| `OnResultC` | `TOnCompleteBuffer_Stream_Event_Bridge_C` | C 风格回调。 |
| `OnResultM` | `TOnCompleteBuffer_Stream_Event_Bridge_M` | M 风格回调。 |
| `OnResultP` | `TOnCompleteBuffer_Stream_Event_Bridge_P` | P 风格回调。 |
| `AutoPause` | `Boolean` | 是否自动暂停。 |
| `AutoFree` | `Boolean` | 完成后是否自动释放。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge; AutoPause_: Boolean); overload;` | 构造。 |
| `constructor Create(Bridge_: TCommandCompleteBuffer_NoWait_Bridge); overload;` | 构造，`AutoPause` 默认为 `True`。 |
| `destructor Destroy; override;` | 析构。 |
| `procedure Pause;` | 暂停结果发送。 |
| `procedure Play(ResultData_: TDFE);` | 发送结果并恢复。 |

---

### 5.13 TP2PVM_CloneConnectEventBridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 用于接收 `TZNet_WithP2PVM_Client.CloneConnect*` 返回的新客户端实例的桥接器。 |
| **典型用法** | 由 `CloneConnectM` 等方法自动创建，在回调中通过 `NewClient` 字段操作克隆连接。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Source` | `TZNet_WithP2PVM_Client` | 源客户端。 |
| `NewClient` | `TZNet_WithP2PVM_Client` | 新创建的克隆客户端。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Source_: TZNet_WithP2PVM_Client);` | 构造。 |
| `destructor Destroy; override;` | 析构。 |

---

## 6. 交换空间类（Swap Space）

### 6.1 TFile_Swap_Space_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 管理临时文件池，用于大流数据的磁盘交换。当内存紧张时，大流数据被缓存到磁盘临时文件。 |
| **典型用法** | 框架内部使用。可通过 `WorkPath` 属性设置临时文件目录。 |
| **继承** | `TCritical_BigList<TFile_Swap_Space_Stream>` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `WorkPath` | `U_String` | 临时文件工作目录。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造，`WorkPath` 默认为当前目录。 |
| `destructor Destroy; override;` | 析构，清理所有临时文件。 |
| `procedure DoFree(var data: TFile_Swap_Space_Stream); override;` | 释放流并删除临时文件。 |
| `function CompareData(const Data_1, Data_2: TFile_Swap_Space_Stream): Boolean; override;` | 比较两个流对象是否相同。 |
| `class function RunTime_Pool(): TFile_Swap_Space_Pool;` | 获取全局单例池。 |

---

### 6.2 TFile_Swap_Space_Stream

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 基于临时文件的流对象，由 `TFile_Swap_Space_Pool` 管理。用于大流数据的磁盘缓存。 |
| **典型用法** | 由 `Create_BigStream` 方法创建，框架自动管理生命周期。 |
| **继承** | `TCore_FileStream` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOwnerSwapSpace` | `TFile_Swap_Space_Pool` | 所属池。 |
| `FPoolPtr` | `TFile_Swap_Space_Pool.PQueueStruct` | 池中指针。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `class function Create_BigStream(stream_: TCore_Stream; OwnerSwapSpace_: TFile_Swap_Space_Pool): TFile_Swap_Space_Stream;` | 从现有流创建交换流，自动复制数据到临时文件。 |
| `destructor Destroy; override;` | 析构，从池中移除并删除临时文件。 |

---

### 6.3 TZDB2_Swap_Space_Technology

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 基于 ZDB2 数据库的交换空间，用于完整缓冲的持久化缓存。支持加密存储。 |
| **典型用法** | 框架内部使用。可通过 `RunTime_Pool` 获取全局单例。 |
| **继承** | `TZDB2_Core_Space` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Critical` | `TCritical` | 同步锁。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create();` | 构造，创建临时数据库文件。 |
| `destructor Destroy; override;` | 析构，删除临时数据库文件。 |
| `function Create_Memory(buff: PByte; BuffSiz: NativeInt; BuffProtected_: Boolean): TZDB2_Swap_Space_Technology_Memory;` | 在交换空间中分配内存块，返回视图对象。 |
| `class function RunTime_Pool(): TZDB2_Swap_Space_Technology;` | 获取全局单例。 |

---

### 6.4 TZDB2_Swap_Space_Technology_Memory

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 交换空间中的内存块视图，继承自 `TMem64`。可延迟从数据库加载数据。 |
| **典型用法** | 由 `TZDB2_Swap_Space_Technology.Create_Memory` 创建，通过 `Prepare` 方法加载数据。 |
| **继承** | `TMem64` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOwner` | `TZDB2_Swap_Space_Technology` | 所属交换空间。 |
| `FID` | `Integer` | 数据库条目 ID。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(); overload;` | 空构造。 |
| `constructor Create(Owner_: TZDB2_Swap_Space_Technology; ID_: Integer); overload;` | 从 ID 构造。 |
| `destructor Destroy; override;` | 析构，从数据库删除条目。 |
| `function Prepare: Boolean;` | 从数据库加载数据到内存，返回是否成功。 |

---

## 7. 队列与命令类（Queue & Command）

### 7.1 TQueueData_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 非线程安全的发送队列，基于 `TOrderStruct<PQueueData>` 实现。用于存储待发送的命令数据。 |
| **典型用法** | 框架内部使用，每个 `TPeerIO` 拥有一个 `TQueueData_Pool` 实例。 |
| **继承** | `TOrderStruct<PQueueData>` |

**公开成员**：无额外成员，继承自 `TOrderStruct<PQueueData>`。

---

### 7.2 TCritical_QueueData_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 线程安全的发送队列，基于 `TCritical_BigList<PQueueData>` 实现。用于跨线程的发送队列交换。 |
| **典型用法** | 框架内部使用，作为全局发送队列交换池。 |
| **继承** | `TCritical_BigList<PQueueData>` |

**公开成员**：无额外成员，继承自 `TCritical_BigList<PQueueData>`。

---

### 7.3 TCommand_base

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 所有注册命令的抽象基类。不包含公开成员，仅作为命令哈希池中的基类型。 |
| **典型用法** | 由具体命令类继承，开发者不直接使用。 |
| **继承** | `TCore_Object_Intermediate` |

**公开成员**：无。

---

### 7.4 TCommandStream

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 流命令处理器（请求-响应）。处理结构化数据交换。 |
| **典型用法** | 通过 `TZNet.RegisterStream` 创建，为 `OnExecute` 事件赋值处理逻辑。 |
| **继承** | `TCommand_base` |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `OnExecute` | `TOnCommandStream_M` | 读写 | M 风格执行处理器。 |
| `OnExecute_C` | `TOnCommandStream_C` | 读写 | C 风格执行处理器。 |
| `OnExecute_M` | `TOnCommandStream_M` | 读写 | M 风格执行处理器（同 `OnExecute`）。 |
| `OnExecute_P` | `TOnCommandStream_P` | 读写 | P 风格执行处理器。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData, OutData: TDFE): Boolean;` | 执行命令，调用绑定的处理器。 |
| `function Execute_Complete_Stream(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;` | 从完整缓冲执行流命令（内部使用）。 |

---

### 7.5 TCommandConsole

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 控制台命令处理器（请求-响应）。处理文本命令。 |
| **典型用法** | 通过 `TZNet.RegisterConsole` 创建。 |
| **继承** | `TCommand_base` |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `OnExecute` | `TOnCommandConsole_M` | 读写 | M 风格执行处理器。 |
| `OnExecute_C/M/P` | 对应类型 | 读写 | 三种风格的执行处理器。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: SystemString; var OutData: SystemString): Boolean;` | 执行命令。 |

---

### 7.6 TCommandStreamNotify

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 流通知命令（无响应）。适用于单向数据推送。 |
| **典型用法** | 通过 `TZNet.RegisterStreamNotify` 创建。 |
| **继承** | `TCommand_base` |

**公开属性**：同 `TCommandStream`，但处理器无 `OutData` 参数。

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: TDFE): Boolean;` | 执行命令。 |

---

### 7.7 TCommandConsoleNotify

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 控制台通知命令（无响应）。 |
| **典型用法** | 通过 `TZNet.RegisterConsoleNotify` 创建。 |
| **继承** | `TCommand_base` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: SystemString): Boolean;` | 执行命令。 |

---

### 7.8 TCommandBigStream

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 大流命令处理器。接收大文件或数据流，提供进度信息。 |
| **典型用法** | 通过 `TZNet.RegisterBigStream` 创建。 |
| **继承** | `TCommand_base` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: TCore_Stream; BigStreamTotal, BigStreamCompleteSize: Int64): Boolean;` | 执行命令。 |

---

### 7.9 TCommandCompleteBuffer

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 完整缓冲命令处理器。接收原子数据块。 |
| **典型用法** | 通过 `TZNet.RegisterCompleteBuffer` 创建。 |
| **继承** | `TCommand_base` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;` | 执行命令。 |

---

### 7.10 TCommandCompleteBuffer_StreamNotify

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 完整缓冲流通知命令。是 `TCommandStreamNotify` 的优化版本，使用完整缓冲协议传输，性能更高。支持同步/异步解密。 |
| **典型用法** | 通过 `TZNet.RegisterCompleteBuffer_StreamNotify` 创建。设置 `Sync_Decrypt := False` 启用异步解密。 |
| **继承** | `TCommand_base` |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Sync_Decrypt` | `Boolean` | 读写 | 是否同步解密。`False` 时在后台线程解密。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;` | 执行命令。 |

---

### 7.11 TCommandCompleteBuffer_NoWait_Stream

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 无等待流命令。发送方不等待响应，响应通过回调异步返回。支持后台线程执行。 |
| **典型用法** | 通过 `TZNet.RegisterCompleteBuffer_NoWait_Stream` 创建。设置 `Execute_In_Thread := True` 启用后台执行。 |
| **继承** | `TCommand_base` |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Execute_In_Thread` | `Boolean` | 读写 | 是否在后台线程执行。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;` | 执行命令。 |

---

### 7.12 TCommandCompleteBuffer_NoWait_Bridge_Stream

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 桥接流命令。提供 `TCommandCompleteBuffer_NoWait_Bridge` 对象，支持暂停/恢复结果发送。 |
| **典型用法** | 通过 `TZNet.RegisterCompleteBuffer_NoWait_Bridge_Stream` 创建。在命令处理器中通过 `Bridge` 对象控制响应时机。 |
| **继承** | `TCommand_base` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Execute(Sender: TPeerIO; InData: PByte; DataSize: NativeInt): Boolean;` | 执行命令，创建 `TCommandCompleteBuffer_NoWait_Bridge` 并传递给处理器。 |

---

### 7.13 TCommandCompleteBuffer_NoWait_Bridge

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 桥接流命令的上下文对象。在命令处理器中通过此对象控制结果发送的暂停和恢复，并持有输入/输出数据。 |
| **典型用法** | 由 `TCommandCompleteBuffer_NoWait_Bridge_Stream.Execute` 自动创建，传递给处理器。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Owner` | `TCommandCompleteBuffer_NoWait_Bridge_Stream` | 所属命令。 |
| `Cmd` | `SystemString` | 命令名。 |
| `R_Framework` | `TZNet` | 接收框架。 |
| `R_ID` | `Cardinal` | 接收 IO ID。 |
| `S_Framework` | `TZNet` | 发送框架。 |
| `S_ID` | `Cardinal` | 发送 IO ID。 |
| `UserData` | `UInt64` | 用户数据令牌。 |
| `InData` | `TDFE` | 输入数据。 |
| `OutData` | `TDFE` | 输出数据。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `InDataFrame` | `TDFE` | 只读 | 同 `InData`。 |
| `InDFE` | `TDFE` | 只读 | 同 `InData`。 |
| `OutDataFrame` | `TDFE` | 只读 | 同 `OutData`。 |
| `OutDFE` | `TDFE` | 只读 | 同 `OutData`。 |
| `ResultSendIsPaused` | `Boolean` | 只读 | 结果发送是否暂停。 |
| `ResultIsPaused` | `Boolean` | 只读 | 同 `ResultSendIsPaused`。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function R_IO: TPeerIO;` | 获取接收 IO。 |
| `function S_IO: TPeerIO;` | 获取发送 IO。 |
| `procedure Pause;` | 暂停结果发送。 |
| `procedure PauseResultSend;` | 同 `Pause`。 |
| `procedure BreakResultSend;` | 同 `Pause`。 |
| `procedure SkipResultSend;` | 同 `Pause`。 |
| `procedure NoResultSend;` | 同 `Pause`。 |
| `procedure StopResultSend;` | 同 `Pause`。 |
| `procedure Resume;` | 恢复结果发送并发送 `OutData`。 |
| `procedure ContinueResultSend;` | 同 `Resume`。 |
| `procedure Continue_Send_Result;` | 同 `Resume`。 |
| `procedure ResumeResultSend;` | 同 `Resume`。 |
| `procedure NowResultSend;` | 同 `Resume`。 |

---

## 8. 用户扩展类（User Define）

### 8.1 TPeer_IO_User_Define

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 挂载到 `TPeerIO` 的主用户扩展对象。每个连接自动创建此类的实例，用于存储连接专属的业务状态、会话数据等。通过 `TZNet.PeerIOUserDefineClass` 可指定自定义派生类。 |
| **典型用法** | 继承此类添加业务字段，在 `DoIOConnectAfter` 中初始化，在命令处理器中通过 `Sender.UserDefine` 访问。 |
| **继承** | `TCore_InterfacedObject_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOwner` | `TPeerIO` | 所属 IO 连接。 |
| `FWorkPlatform` | `TExecutePlatform` | 执行平台标识（由客户端握手时上报）。 |
| `FBigStreamBatch` | `TBigStreamBatch` | 大流批量数据列表。 |
| `FBusy` | `Boolean` | 忙标志，可由用户设置。 |
| `FBusyNum` | `Integer` | 忙计数器，可由用户操作。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Owner` | `TPeerIO` | 只读 | 所属 IO 连接。 |
| `WorkPlatform` | `TExecutePlatform` | 读写 | 执行平台。 |
| `BigStreamBatchList` | `TBigStreamBatch` | 只读 | 大流批量列表。 |
| `BigStreamBatch` | `TBigStreamBatch` | 只读 | 同 `BigStreamBatchList`。 |
| `BatchStream` | `TBigStreamBatch` | 只读 | 同 `BigStreamBatchList`。 |
| `BatchList` | `TBigStreamBatch` | 只读 | 同 `BigStreamBatchList`。 |
| `Busy` | `Boolean` | 读写 | 忙标志。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Owner_: TPeerIO); virtual;` | 构造，绑定到指定 IO。 |
| `destructor Destroy; override;` | 析构，释放 `BigStreamBatch`。 |
| `procedure Progress; virtual;` | 进度回调，可重写以执行周期任务。 |
| `function BusyNum: PInteger;` | 获取忙计数器指针，用于原子操作。 |

---

### 8.2 TPeer_IO_User_Special

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 挂载到 `TPeerIO` 的辅助用户扩展对象。与 `TPeer_IO_User_Define` 功能相同，但无 `BigStreamBatch` 字段，作为第二个独立的扩展槽使用。 |
| **典型用法** | 当需要一个独立于主扩展对象的额外状态容器时使用。 |
| **继承** | `TCore_InterfacedObject_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOwner` | `TPeerIO` | 所属 IO 连接。 |
| `FBusy` | `Boolean` | 忙标志。 |
| `FBusyNum` | `Integer` | 忙计数器。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Owner` | `TPeerIO` | 只读 | 所属 IO 连接。 |
| `Busy` | `Boolean` | 读写 | 忙标志。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Owner_: TPeerIO); virtual;` | 构造，绑定到指定 IO。 |
| `destructor Destroy; override;` | 析构。 |
| `procedure Progress; virtual;` | 进度回调。 |
| `function BusyNum: PInteger;` | 获取忙计数器指针。 |

---

## 9. 批量流类（Batch Stream）

### 9.1 TBigStreamBatchPostData

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 记录单个大流批量发布任务的数据结构，包含源数据、MD5 校验、回调指针等信息。 |
| **典型用法** | 由 `TBigStreamBatch.NewPostData` 创建并填充，内部使用。 |
| **类型** | `record` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Source` | `TMS64` | 源数据流。 |
| `CompletedBackcallPtr` | `UInt64` | 完成回调指针。 |
| `RemoteMD5` | `TMD5` | 远程数据 MD5。 |
| `SourceMD5` | `TMD5` | 源数据 MD5。 |
| `index` | `Integer` | 在列表中的索引。 |
| `DBStorePos` | `Int64` | 数据库存储位置。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure Init;` | 初始化所有字段为默认值。 |
| `procedure Encode(d: TDFE);` | 编码到 DFE。 |
| `procedure Decode(d: TDFE);` | 从 DFE 解码。 |

---

### 9.2 TBigStreamBatchPostData_List

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | `TBigStreamBatchPostData` 指针列表，用于存储批量任务。 |
| **继承** | `TGenericsList<PBigStreamBatchPostData>` |

**公开成员**：无额外成员，继承自 `TGenericsList`。

---

### 9.3 TBigStreamBatch

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 管理多个大流发布任务的容器。支持添加、删除、遍历批量任务。用于批量上传大文件场景。 |
| **典型用法** | 通过 `TPeerIO.BigStreamBatch` 获取，调用 `NewPostData` 添加任务。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOwner` | `TPeerIO` | 所属 IO。 |
| `FList` | `TBigStreamBatchPostData_List` | 任务列表。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Items[const index: Integer]` | `PBigStreamBatchPostData` | 只读 | 获取指定索引的任务（默认索引属性）。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Owner_: TPeerIO);` | 构造，绑定到指定 IO。 |
| `destructor Destroy; override;` | 析构，释放所有任务。 |
| `procedure Clear;` | 清空所有任务。 |
| `function Count: Integer;` | 获取任务数量。 |
| `function NewPostData: PBigStreamBatchPostData;` | 创建新的任务数据项。 |
| `function First: PBigStreamBatchPostData;` | 获取第一个任务。 |
| `function Last: PBigStreamBatchPostData;` | 获取最后一个任务。 |
| `procedure DeleteLast;` | 删除最后一个任务。 |
| `procedure Delete(const index: Integer);` | 删除指定索引的任务。 |

---

## 10. P2PVM 虚拟网络类

### 10.1 TZNet_P2PVM

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | P2PVM（Peer-to-Peer Virtual Machine）虚拟网络核心。在一条物理连接上构建虚拟二层网络，支持挂载多个逻辑服务端/客户端，实现 NAT 穿透和服务隔离。 |
| **典型用法** | 通过 `TPeerIO.OpenP2PVMTunnel` 开启隧道，然后使用 `InstallLogicFramework` 挂载虚拟服务或客户端。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FOwner_IO` | `TPeerIO` | 底层物理 IO。 |
| `FAuthWaiting` | `Boolean` | 是否正在等待认证。 |
| `FAuthed` | `Boolean` | 是否已认证。 |
| `FAuthSending` | `Boolean` | 是否正在发送认证。 |
| `FFrameworkPool` | `TUInt32HashObjectList` | 已安装的逻辑框架池（ID -> TZNet）。 |
| `FFrameworkListenPool` | `TP2PVM_Listen_List` | 虚拟监听列表。 |
| `FMaxVMFragmentSize` | `Cardinal` | 最大 VM 分片大小，默认 `1536`。 |
| `FProgress_Send_Size` | `Int64` | 每次进度发送最大字节数，默认 `500KB`。 |
| `FQuietMode` | `Boolean` | 静默模式。 |
| `FReceiveStream` | `TMem64` | 接收缓冲流。 |
| `FSendStream` | `TMem64` | 发送缓冲流。 |
| `FWaitEchoList` | `TP2PVM_ECHO_List` | 等待回显列表。 |
| `FVMID` | `Cardinal` | 虚拟网络 ID。 |
| `OnAuthSuccessOnesNotify` | `TP2PVMAuthSuccessMethod` | 认证成功一次性回调。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `Owner_IO` | `TPeerIO` | 只读 | 底层物理 IO。 |
| `FrameworkPool` | `TUInt32HashObjectList` | 只读 | 逻辑框架池。 |
| `MaxVMFragmentSize` | `Cardinal` | 读写 | 最大 VM 分片大小。 |
| `Progress_Send_Size` | `Int64` | 读写 | 每次进度发送最大字节数。 |
| `QuietMode` | `Boolean` | 读写 | 静默模式。 |
| `WasAuthed` | `Boolean` | 只读 | 是否已认证。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(HashPoolSize: Integer);` | 构造，指定框架哈希池大小。 |
| `destructor Destroy; override;` | 析构，关闭隧道并释放所有资源。 |
| `procedure Progress;` | 驱动 P2PVM 进度（收发分片、回显超时检测）。 |
| `procedure OpenP2PVMTunnel(c: TPeerIO);` | 在物理 IO 上开启 P2PVM 隧道。 |
| `procedure CloseP2PVMTunnel;` | 关闭 P2PVM 隧道，卸载所有逻辑框架。 |
| `procedure AuthWaiting;` | 进入认证等待状态。 |
| `procedure AuthVM; overload;` | 执行认证（发送认证令牌）。 |
| `procedure AuthSuccessed;` | 发送认证成功信号。 |
| `procedure InstallLogicFramework(Inst: TZNet);` | 挂载逻辑框架到虚拟网络。 |
| `procedure UninstallLogicFramework(Inst: TZNet);` | 从虚拟网络卸载逻辑框架。 |
| `procedure ProgressZNet_C(const OnBackcall: TZNet_List_C);` | 遍历所有逻辑框架执行 C 风格回调。 |
| `procedure ProgressZNet_M(const OnBackcall: TZNet_List_M);` | 遍历所有逻辑框架执行 M 风格回调。 |
| `procedure ProgressZNet_P(const OnBackcall: TZNet_List_P);` | 遍历所有逻辑框架执行 P 风格回调。 |
| `procedure echoingC(const OnResult: TOnState_C; TimeOut_: TTimeTick);` | 发送回显请求，C 风格回调。 |
| `procedure echoingM(const OnResult: TOnState_M; TimeOut_: TTimeTick);` | 发送回显请求，M 风格回调。 |
| `procedure echoingP(const OnResult: TOnState_P; TimeOut_: TTimeTick);` | 发送回显请求，P 风格回调。 |
| `procedure echoBuffer(const buff: Pointer; const siz: NativeInt);` | 回显缓冲区数据（被动响应）。 |
| `procedure SendListen(const FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; const Listening: Boolean);` | 发送虚拟监听通知。 |
| `procedure SendListenState(const FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; const Listening: Boolean);` | 发送虚拟监听状态更新。 |
| `procedure SendConnecting(const Remote_frameworkID, FrameworkID, p2pID: Cardinal; const IPV6: TIPV6; const Port: Word);` | 发送虚拟连接请求。 |
| `procedure SendConnectedReponse(const Remote_frameworkID, Remote_p2pID, FrameworkID, p2pID: Cardinal);` | 发送虚拟连接响应。 |
| `procedure SendDisconnect(const Remote_frameworkID, Remote_p2pID: Cardinal);` | 发送虚拟断开通知。 |
| `function ListenCount: Integer;` | 获取虚拟监听数量。 |
| `function GetListen(const index: Integer): PP2PVMListen;` | 获取指定索引的监听记录。 |
| `function FindListen(const IPV6: TIPV6; const Port: Word): PP2PVMListen;` | 查找监听记录。 |
| `function FindListening(const IPV6: TIPV6; const Port: Word): PP2PVMListen;` | 查找活动监听记录。 |
| `procedure DeleteListen(const IPV6: TIPV6; const Port: Word);` | 删除监听记录。 |
| `procedure ClearListen;` | 清空所有监听记录。 |

---

### 10.2 TZNet_WithP2PVM_Server

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 挂载到 P2PVM 上的虚拟服务端。可在虚拟网络中监听并接受来自其他虚拟客户端的连接。每个虚拟服务端拥有独立的命令注册表和 IO 池。 |
| **典型用法** | 创建实例，通过 `P2PVM.InstallLogicFramework` 挂载，然后调用 `StartService` 在虚拟网络中监听。 |
| **继承** | `TZNet_Server` |

**公开构造**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造，哈希池大小默认 `200000`（`20*10000`）。 |
| `constructor CustomCreate(HashPoolSize: Integer; FrameworkID: Cardinal);` | 构造，指定哈希池大小和框架 ID。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `destructor Destroy; override;` | 析构，关闭所有虚拟连接并卸载自身。 |
| `function StartService(Host_: SystemString; Port: Word): Boolean; override;` | 在虚拟网络中启动监听。`Host_` 为虚拟 IPv6 地址（空字符串则自动生成）。 |
| `procedure StopService; override;` | 停止监听，关闭所有虚拟连接。 |
| `procedure CloseAllClient;` | 关闭所有虚拟客户端连接。 |
| `function ListenCount: Integer;` | 获取虚拟监听数量。 |
| `function GetListen(const index: Integer): PP2PVMListen;` | 获取指定索引的监听记录。 |
| `function FindListen(const IPV6: TIPV6; const Port: Word): PP2PVMListen;` | 查找监听记录。 |
| `function FindListening(const IPV6: TIPV6; const Port: Word): PP2PVMListen;` | 查找活动监听记录。 |
| `procedure DeleteListen(const IPV6: TIPV6; const Port: Word);` | 删除监听记录。 |
| `procedure ClearListen;` | 清空所有监听记录。 |

**受保护方法（可重写）**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure Connecting(SenderVM: TZNet_P2PVM; const Remote_frameworkID, FrameworkID: Cardinal; const IPV6: TIPV6; const Port: Word; var Allowed: Boolean); virtual;` | 处理虚拟连接请求，设置 `Allowed` 决定是否接受。 |
| `procedure ListenState(SenderVM: TZNet_P2PVM; const IPV6: TIPV6; const Port: Word; const State: Boolean); virtual;` | 虚拟监听状态变化通知。 |

---

### 10.3 TZNet_WithP2PVM_Client

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 挂载到 P2PVM 上的虚拟客户端。可连接虚拟服务端，支持克隆（在同一物理连接上创建多个独立虚拟客户端）。 |
| **典型用法** | 创建实例，通过 `P2PVM.InstallLogicFramework` 挂载，调用 `AsyncConnect` 连接虚拟服务端。通过 `CloneConnect*` 创建克隆客户端。 |
| **继承** | `TZNet_Client` |

**公开构造**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create; overload;` | 构造。 |
| `constructor CustomCreate(FrameworkID: Cardinal); overload;` | 构造，指定框架 ID。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `ClonePool` | `TZNet_WithP2PVM_Client_Clone_Pool` | 只读 | 克隆客户端池。 |
| `P2PVM_Clone_NextProgressDoFreeSelf` | `Boolean` | 读写 | 下次进度循环时是否释放自身。 |
| `LinkVM` | `TZNet_P2PVM` | 只读 | 所属 P2PVM 隧道。 |
| `FrameworkWithVM_ID` | `Cardinal` | 只读 | 框架在 P2PVM 中的 ID。 |
| `VMClientIO` | `TP2PVM_PeerIO` | 只读 | 虚拟客户端 IO。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `destructor Destroy; override;` | 析构，断开连接并释放克隆池。 |
| `function Connected: Boolean; override;` | 虚拟连接是否已建立。 |
| `procedure Disconnect; override;` | 断开虚拟连接。 |
| `function Connect(addr: SystemString; Port: Word): Boolean; override;` | 同步连接虚拟服务端。 |
| `procedure AsyncConnect(addr: SystemString; Port: Word);` | 异步连接虚拟服务端（无回调）。 |
| `procedure AsyncConnectC/M/P(addr: SystemString; Port: Word; const OnResult: ...); override;` | 异步连接虚拟服务端（三种风格）。 |
| `procedure AsyncConnectC/M/P(addr: SystemString; Port: Word; Param1: Pointer; Param2: TObject; const OnResult: ...); overload;` | 异步连接，带用户参数。 |
| `function ClientIO: TPeerIO; override;` | 获取虚拟客户端 IO。 |
| `procedure Progress; override;` | 驱动虚拟客户端进度。 |
| `function CloneConnectC(OnResult: TOnP2PVM_CloneConnectEvent_C): TP2PVM_CloneConnectEventBridge;` | 创建克隆客户端，C 风格回调。 |
| `function CloneConnectM(OnResult: TOnP2PVM_CloneConnectEvent_M): TP2PVM_CloneConnectEventBridge;` | 创建克隆客户端，M 风格回调。 |
| `function CloneConnectP(OnResult: TOnP2PVM_CloneConnectEvent_P): TP2PVM_CloneConnectEventBridge;` | 创建克隆客户端，P 风格回调。 |

**受保护方法（可重写）**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure VMConnectSuccessed(SenderVM: TZNet_P2PVM; Remote_frameworkID, Remote_p2pID, FrameworkID: Cardinal); virtual;` | 虚拟连接成功钩子。 |
| `procedure VMDisconnect(SenderVM: TZNet_P2PVM); virtual;` | 虚拟连接断开钩子。 |

---

### 10.4 TP2PVM_PeerIO

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | P2PVM 虚拟连接上的 IO 对象，继承自 `TPeerIO`。通过 P2PVM 隧道收发数据，将虚拟网络中的数据分片封装/解封装。 |
| **典型用法** | 由框架自动创建，开发者通常不直接操作。 |
| **继承** | `TPeerIO` |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `LinkVM` | `TZNet_P2PVM` | 只读 | 所属 P2PVM 隧道。 |
| `Remote_frameworkID` | `Cardinal` | 只读 | 远程框架 ID。 |
| `Remote_p2pID` | `Cardinal` | 只读 | 远程 IO ID。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure CreateAfter; override;` | 构造后初始化。 |
| `destructor Destroy; override;` | 析构。 |
| `function Connected: Boolean; override;` | 虚拟连接是否有效。 |
| `procedure Disconnect; override;` | 断开虚拟连接。 |
| `procedure Write_IO_Buffer(const buff: PByte; const Size: NativeInt); override;` | 写入数据到虚拟网络。 |
| `procedure WriteBufferOpen; override;` | 打开写缓冲。 |
| `procedure WriteBufferFlush; override;` | 刷新写缓冲，将数据分片发送到 P2PVM 隧道。 |
| `procedure WriteBufferClose; override;` | 关闭写缓冲。 |
| `function GetPeerIP: SystemString; override;` | 获取虚拟对端 IP。 |
| `function WriteBuffer_is_NULL: Boolean; override;` | 写缓冲是否为空。 |
| `function WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean; override;` | 获取写缓冲状态。 |
| `procedure Progress; override;` | 驱动虚拟 IO 进度。 |

---

### 10.5 TP2PVMListen（记录）

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | P2PVM 虚拟监听记录，包含监听所属框架 ID、虚拟 IP 地址、端口和活动状态。 |
| **类型** | `record` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `FrameworkID` | `Cardinal` | 所属框架 ID。 |
| `ListenHost` | `TIPV6` | 虚拟 IPv6 地址。 |
| `ListenPort` | `Word` | 虚拟端口。 |
| `Listening` | `Boolean` | 是否处于监听状态。 |

---

### 10.6 TP2PVMListen_List

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | P2PVM 监听记录列表。 |
| **继承** | `TGenericsList<PP2PVMListen>` |

**公开成员**：无额外成员，继承自 `TGenericsList`。

---

## 11. 稳定会话层（StableIO）

### 11.1 TStableServer_OwnerIO_UserDefine

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 稳定会话服务端物理连接的扩展对象，持有对稳定会话 IO 的引用。 |
| **典型用法** | 框架内部使用，由稳定会话服务端自动挂载到物理连接。 |
| **继承** | `TPeer_IO_User_Define` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `BindStableIO` | `TStableServer_PeerIO` | 关联的稳定会话 IO。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(Owner_: TPeerIO); override;` | 构造。 |
| `destructor Destroy; override;` | 析构，清理稳定会话引用。 |

---

### 11.2 TStableServer_PeerIO

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 稳定会话服务端的虚拟 IO，可跨越物理连接重连而保持会话状态。即使底层物理连接断开，此 IO 对象依然存活，并缓存待发送数据。 |
| **典型用法** | 由稳定会话服务端自动创建和管理。 |
| **继承** | `TPeerIO` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Activted` | `Boolean` | 是否激活。 |
| `DestroyRecycleOwnerIO` | `Boolean` | 销毁时是否回收物理 IO。 |
| `Connection_Token` | `Cardinal` | 唯一连接令牌（用于重连识别）。 |
| `Internal_Bind_Owner_IO` | `TPeerIO` | 当前绑定的物理 IO。 |
| `OfflineTick` | `TTimeTick` | 离线时间戳。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `BindOwnerIO` | `TPeerIO` | 读写 | 当前绑定的物理 IO。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure CreateAfter; override;` | 构造后初始化。 |
| `destructor Destroy; override;` | 析构。 |
| `function Connected: Boolean; override;` | 始终返回 `True`（逻辑连接有效）。 |
| `procedure Disconnect; override;` | 断开逻辑连接。 |
| `procedure Write_IO_Buffer(const buff: PByte; const Size: NativeInt); override;` | 写入数据（若物理连接存在则转发）。 |
| `procedure WriteBufferOpen; override;` | 打开写缓冲。 |
| `procedure WriteBufferFlush; override;` | 刷新写缓冲。 |
| `procedure WriteBufferClose; override;` | 关闭写缓冲。 |
| `function GetPeerIP: SystemString; override;` | 获取对端 IP。 |
| `function WriteBuffer_is_NULL: Boolean; override;` | 写缓冲是否为空。 |
| `function WriteBuffer_State(var WriteBuffer_Queue_Num, WriteBuffer_Size: Int64): Boolean; override;` | 获取写缓冲状态。 |
| `procedure Progress; override;` | 驱动稳定会话进度（检测离线超时）。 |

---

### 11.3 TZNet_CustomStableServer

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 稳定会话服务端基类。包装物理服务端，提供会话持久化能力。客户端断线重连后，逻辑会话（状态、待发数据）自动恢复。 |
| **典型用法** | 创建实例，设置 `OwnerIOServer` 为物理服务端，然后使用。通常使用别名 `TZNet_StableServer`。 |
| **继承** | `TZNet_Server` |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `OwnerIOServer` | `TZNet_Server` | 读写 | 底层物理服务端。 |
| `OfflineTimeout` | `TTimeTick` | 读写 | 离线超时（默认 5 分钟）。 |
| `LimitSequencePacketMemoryUsage` | `Int64` | 读写 | 序列包内存限制。 |
| `AutoFreeOwnerIOServer` | `Boolean` | 读写 | 是否自动释放底层服务端（默认 `False`）。 |
| `AutoProgressOwnerIOServer` | `Boolean` | 读写 | 是否自动驱动底层服务端进度（默认 `True`）。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create; override;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function StartService(Host: SystemString; Port: Word): Boolean; override;` | 启动服务（代理到底层）。 |
| `procedure StopService; override;` | 停止服务。 |
| `procedure Progress; override;` | 驱动稳定会话进度。 |

---

### 11.4 TStableClient_PeerIO

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 稳定会话客户端的虚拟 IO，与 `TStableServer_PeerIO` 对应。在物理连接断开时保持逻辑会话。 |
| **典型用法** | 由稳定会话客户端自动创建和管理。 |
| **继承** | `TPeerIO` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Activted` | `Boolean` | 是否激活。 |
| `WaitConnecting` | `Boolean` | 是否正在等待重连。 |
| `OwnerIO_LastConnectTick` | `TTimeTick` | 最后连接尝试时间。 |
| `Connection_Token` | `Cardinal` | 连接令牌。 |
| `BindOwnerIO` | `TPeerIO` | 当前绑定的物理 IO。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure CreateAfter; override;` | 构造后初始化。 |
| `destructor Destroy; override;` | 析构。 |
| `function Connected: Boolean; override;` | 逻辑连接是否有效。 |
| `procedure Disconnect; override;` | 断开逻辑连接。 |
| `procedure Write_IO_Buffer(...); override;` | 写入数据。 |
| `procedure WriteBufferOpen/Flush/Close; override;` | 写缓冲操作。 |
| `function GetPeerIP: SystemString; override;` | 获取对端 IP。 |
| `function WriteBuffer_is_NULL: Boolean; override;` | 写缓冲是否为空。 |
| `function WriteBuffer_State(...): Boolean; override;` | 获取写缓冲状态。 |
| `procedure Progress; override;` | 驱动稳定会话进度。 |

---

### 11.5 TZNet_CustomStableClient

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 稳定会话客户端基类。包装物理客户端，自动处理重连和会话恢复。支持 `AutomatedConnection` 自动重连模式。 |
| **典型用法** | 创建实例，设置 `OwnerIOClient` 为物理客户端，调用 `Connect` 或 `AsyncConnect`。通常使用别名 `TZNet_StableClient`。 |
| **继承** | `TZNet_Client` |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `OwnerIOClient` | `TZNet_Client` | 读写 | 底层物理客户端。 |
| `AutomatedConnection` | `Boolean` | 读写 | 是否自动重连（默认 `True`）。 |
| `LimitSequencePacketMemoryUsage` | `Int64` | 读写 | 序列包内存限制。 |
| `AutoFreeOwnerIOClient` | `Boolean` | 读写 | 是否自动释放底层客户端（默认 `False`）。 |
| `AutoProgressOwnerIOClient` | `Boolean` | 读写 | 是否自动驱动底层客户端进度（默认 `True`）。 |
| `StableClientIO` | `TStableClient_PeerIO` | 只读 | 稳定会话 IO。 |
| `StopCommunicationTimeTick` | `TTimeTick` | 只读 | 停止通信时间戳。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create; override;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function Connect(addr: SystemString; Port: Word): Boolean; override;` | 同步连接。 |
| `procedure AsyncConnectC/M/P(addr: SystemString; Port: Word; const OnResult: ...); override;` | 异步连接（三种风格）。 |
| `function Connected: Boolean; override;` | 逻辑连接是否有效。 |
| `procedure Disconnect; override;` | 断开逻辑连接。 |
| `function ClientIO: TPeerIO; override;` | 获取客户端 IO。 |
| `procedure Progress; override;` | 驱动稳定会话进度（包含重连逻辑）。 |

---

## 12. HPC 线程池执行类

### 12.1 THPC_Base

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 所有 HPC（High-Performance Computing）任务的抽象基类。自动注册到 `HPC_Instance_Pool` 全局池，便于调试和监控。 |
| **典型用法** | 由具体 HPC 任务类继承，开发者通常使用全局 `RunHPC_*` 函数提交任务。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Instance_Ptr` | `THPC_Instance_Pool.PQueueStruct` | 全局池中指针。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造，自动注册到全局池。 |
| `procedure Do_Free_Instance_Ptr; virtual;` | 从全局池移除自身。 |
| `destructor Destroy; override;` | 析构，从全局池移除。 |

---

### 12.2 THPC_Stream

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 流式 HPC 任务。在后台线程中执行流命令处理，输入输出为 `TDFE`。执行完成后自动将结果返回给客户端。 |
| **典型用法** | 由 `RunHPC_Stream*` 函数创建和提交。 |
| **继承** | `THPC_Base` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Thread` | `TCompute` | 执行线程。 |
| `Framework` | `TZNet` | 所属框架。 |
| `Cmd` | `SystemString` | 命令名。 |
| `TriggerTime` | `TTimeTick` | 触发时间。 |
| `WorkID` | `Cardinal` | IO ID。 |
| `Send_Tunnel` | `TZNet` | 发送隧道框架。 |
| `Send_Tunnel_ID` | `Cardinal` | 发送隧道 IO ID。 |
| `UserData` | `Pointer` | 用户数据指针。 |
| `UserObject` | `TCore_Object` | 用户对象。 |
| `UserVariant` | `Variant` | 用户 Variant。 |
| `InData` | `TDFE` | 输入数据。 |
| `OutData` | `TDFE` | 输出数据。 |
| `OnDone_C` | `TOnHPC_Stream_Done_C` | C 风格完成回调。 |
| `OnDone_M` | `TOnHPC_Stream_Done_M` | M 风格完成回调。 |
| `OnDone_P` | `TOnHPC_Stream_Done_P` | P 风格完成回调。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `ID` | `Cardinal` | 只读 | 同 `WorkID`。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create;` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `function IsOnline: Boolean;` | 检查 IO 是否仍在线。 |
| `function IO: TPeerIO;` | 获取 IO 引用。 |

---

### 12.3 THPC_StreamNotify

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 流通知 HPC 任务。与 `THPC_Stream` 类似，但无输出数据（单向通知）。 |
| **典型用法** | 由 `RunHPC_StreamNotify*` 函数创建和提交。 |
| **继承** | `THPC_Base` |

**公开字段**：同 `THPC_Stream`，但无 `OutData` 和 `OnDone_*` 字段。

**公开方法**：同 `THPC_Stream`。

---

### 12.4 THPC_Console

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 控制台 HPC 任务。在后台线程中执行控制台命令处理，输入输出为字符串。 |
| **典型用法** | 由 `RunHPC_Console*` 函数创建和提交。 |
| **继承** | `THPC_Base` |

**公开字段**：同 `THPC_Stream`，但 `InData` 和 `OutData` 为 `SystemString`。

**公开方法**：同 `THPC_Stream`。

---

### 12.5 THPC_ConsoleNotify

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 控制台通知 HPC 任务。无输出数据。 |
| **典型用法** | 由 `RunHPC_ConsoleNotify*` 函数创建和提交。 |
| **继承** | `THPC_Base` |

**公开字段**：同 `THPC_ConsoleNotify`，但无 `OutData`。

**公开方法**：同 `THPC_Stream`。

---

### 12.6 THPC_CompleteBuffer

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 完整缓冲 HPC 任务。在后台线程中处理完整缓冲数据。 |
| **典型用法** | 由 `RunHPC_CompleteBuffer*` 函数创建和提交。 |
| **继承** | `THPC_Base` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `InData` | `TMS64` | 输入缓冲数据。 |

**公开方法**：同 `THPC_Stream`。

---

### 12.7 THPC_CompleteBuffer_Stream

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 桥接流 HPC 任务。在后台线程中处理 `TCommandCompleteBuffer_NoWait_Bridge` 桥接命令。 |
| **典型用法** | 由 `RunHPC_CompleteBuffer_Stream*` 函数创建和提交。 |
| **继承** | `THPC_Base` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Bridge` | `TCommandCompleteBuffer_NoWait_Bridge` | 桥接对象。 |

**公开方法**：同 `THPC_Stream`。

---

### 12.8 HPC 全局提交函数

| 函数名 | 说明 |
| :--- | :--- |
| `procedure RunHPC_StreamC(Sender: TPeerIO; const UserData: Pointer; const UserObject: TCore_Object; const UserVariant: Variant; const InData, OutData: TDFE; const OnRun: TOnHPC_Stream_C);` | 提交流式 HPC 任务，C 风格执行回调。 |
| `procedure RunHPC_StreamM(...);` | 提交流式 HPC 任务，M 风格执行回调。 |
| `procedure RunHPC_StreamP(...);` | 提交流式 HPC 任务，P 风格执行回调。 |
| `procedure RunHPC_StreamNotifyC/M/P(...);` | 提交流通知 HPC 任务。 |
| `procedure RunHPC_ConsoleC/M/P(...);` | 提交控制台 HPC 任务。 |
| `procedure RunHPC_ConsoleNotifyC/M/P(...);` | 提交控制台通知 HPC 任务。 |
| `procedure RunHPC_CompleteBufferC/M/P(...);` | 提交完整缓冲 HPC 任务。 |
| `procedure RunHPC_CompleteBuffer_StreamC/M/P(Sender: TCommandCompleteBuffer_NoWait_Bridge; ...);` | 提交桥接流 HPC 任务。 |

---

## 13. IO 池与统计类

### 13.1 TPeer_IO_Hash_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | IO ID 到 `TPeerIO` 实例的哈希池。线程安全，支持并发访问。 |
| **典型用法** | 框架内部使用，通过 `TZNet.PeerIO_HashPool` 访问。 |
| **继承** | `TCritical_Big_Hash_Pair_Pool<Cardinal, TPeerIO>` |

**公开成员**：无额外成员，继承自 `TCritical_Big_Hash_Pair_Pool`。

---

### 13.2 TZNet_Instance_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 全局 `TZNet` 实例池，跟踪所有活跃的框架实例。主要用于调试和监控。 |
| **典型用法** | 通过 `ZNet_Instance_Pool` 全局变量访问，调用 `Print_Status` 等方法输出诊断信息。 |
| **继承** | `TCritical_BigList<TZNet>` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure Print_Status;` | 打印所有框架实例及其 IO 连接的状态。 |
| `procedure Print_Service_Statistics_Info;` | 打印服务端统计信息（收发包、命令频次等）。 |
| `procedure Print_Service_CMD_Info;` | 打印服务端命令执行耗时统计。 |
| `procedure Print_Client_Statistics_Info;` | 打印客户端统计信息。 |
| `procedure Print_Client_CMD_Info;` | 打印客户端命令执行耗时统计。 |

---

### 13.3 TCommand_Num_Hash_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 命令计数哈希池，用于统计命令的接收或发送频次。 |
| **典型用法** | 框架内部使用，通过 `CmdRecvStatistics` 和 `CmdSendStatistics` 访问。 |
| **继承** | `TCritical_String_Big_Hash_Pair_Pool<Integer>` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure IncValue(Key_: SystemString; Value_: Integer);` | 增加指定命令的计数。 |
| `procedure IncValue(Source: TCommand_Num_Hash_Pool);` | 合并另一个统计池的计数。 |
| `procedure GetKeyList(output: TPascalStringList);` | 获取所有命令名列表。 |

---

### 13.4 TCommand_Tick_Hash_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 命令耗时哈希池，用于统计命令的最大执行耗时。 |
| **典型用法** | 框架内部使用，通过 `CmdMaxExecuteConsumeStatistics` 访问。 |
| **继承** | `TCritical_String_Big_Hash_Pair_Pool<TTimeTick>` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure SetMax(Key_: SystemString; Value_: TTimeTick);` | 设置命令的最大耗时（仅当 `Value_` 大于当前值时更新）。 |
| `procedure SetMax(Source: TCommand_Tick_Hash_Pool);` | 合并另一个统计池的耗时数据。 |
| `procedure GetKeyList(output: TPascalStringList);` | 获取所有命令名列表。 |

---

### 13.5 TCommand_Hash_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 命令注册池，存储命令名到 `TCommand_base` 实例的映射。 |
| **典型用法** | 框架内部使用，通过 `TZNet.FCommand_Hash_Pool` 访问。 |
| **继承** | `TCritical_String_Big_Hash_Pair_Pool<TCommand_base>` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure DoFree(var Key: SystemString; var Value: TCommand_base); override;` | 释放命令实例。 |

---

### 13.6 TZNet_Progress_Pool

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | `TZNet_Progress` 事件池，管理所有挂载的进度事件。 |
| **典型用法** | 框架内部使用，通过 `TZNet.Progress_Pool` 访问。 |
| **继承** | `TBigList<TZNet_Progress>` |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `procedure DoFree(var data: TZNet_Progress); override;` | 释放进度事件实例。 |

---

### 13.7 TZNet_Progress

| 项目 | 内容 |
| :--- | :--- |
| **功能说明** | 挂载到框架的进度事件。在每次 `Progress` 循环中被调用，用于执行周期性任务。 |
| **典型用法** | 通过 `TZNet.AddProgresss` 创建，为 `OnProgress_M` 等事件赋值。 |
| **继承** | `TCore_Object_Intermediate` |

**公开字段**：
| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `OnFree` | `TZNet_Progress_Free_OnEvent` | 释放事件回调。 |
| `OnProgress_C` | `TZNet_Progress_OnEvent_C` | C 风格进度回调。 |
| `OnProgress_M` | `TZNet_Progress_OnEvent_M` | M 风格进度回调。 |
| `OnProgress_P` | `TZNet_Progress_OnEvent_P` | P 风格进度回调。 |
| `NextProgressDoFree` | `Boolean` | 下次进度循环时是否自动释放。 |

**公开属性**：
| 属性名 | 类型 | 读写性 | 说明 |
| :--- | :--- | :--- | :--- |
| `OwnerFramework` | `TZNet` | 只读 | 所属框架。 |

**公开方法**：
| 方法名 | 说明 |
| :--- | :--- |
| `constructor Create(OwnerFramework_: TZNet);` | 构造。 |
| `destructor Destroy; override;` | 析构。 |
| `procedure Progress; virtual;` | 进度回调，触发绑定的 `OnProgress_*` 事件。 |
| `procedure ResetEvent;` | 清空所有事件回调。 |

---

## 14. 全局 API 函数

| 函数名 | 说明 |
| :--- | :--- |
| `procedure DisposeQueueData(const v: PQueueData);` | 释放队列数据块及其内部载荷（流、缓冲等）。若 `DoneAutoFree` 为 `True` 则自动释放载荷。 |
| `procedure InitQueueData(var v: TQueueData);` | 初始化 `TQueueData` 记录的所有字段为默认值。 |
| `function NewQueueData(IO: TPeerIO): PQueueData;` | 在堆上分配新的 `TQueueData` 记录并初始化，设置 `IO_ID` 和 `IP` 字段。 |
| `function IsSystemCMD(const Cmd: U_String): Boolean;` | 判断命令名是否为内部系统命令（以 `__@` 开头）。 |
| `function StrToIPv4(const S: U_String; var Success: Boolean): TIPV4;` | 解析 IPv4 地址字符串，`Success` 返回是否成功。 |
| `function IPv4ToStr(const IPv4Addr_: TIPV4): U_String;` | 将 `TIPV4` 转换为点分十进制字符串。 |
| `function StrToIPv6(const S: U_String; var Success: Boolean; var ScopeID: Cardinal): TIPV6; overload;` | 解析 IPv6 地址字符串，返回 `ScopeID`（区域 ID）。 |
| `function StrToIPv6(const S: U_String; var Success: Boolean): TIPV6; overload;` | 解析 IPv6 地址字符串（无 ScopeID）。 |
| `function IPv6ToStr(const IPv6Addr: TIPV6): U_String;` | 将 `TIPV6` 转换为标准 IPv6 字符串（压缩零段）。 |
| `function IsIPv4(const S: U_String): Boolean;` | 检查字符串是否为有效的 IPv4 地址格式。 |
| `function IsIPV6(const S: U_String): Boolean;` | 检查字符串是否为有效的 IPv6 地址格式。 |
| `function MakeRandomIPV6(): TIPV6;` | 生成随机 IPv6 地址（基于时间戳、随机数和种子）。 |
| `function IsLocalNetworkIPV4(const S: U_String): Boolean;` | 检查 IPv4 地址是否为内网地址（192.168.x.x, 10.x.x.x, 172.16-31.x.x）。 |
| `function CompareIPV4(const IP1, IP2: TIPV4): Boolean;` | 比较两个 IPv4 地址是否相等。 |
| `function CompareIPV6(const IP1, IP2: TIPV6): Boolean;` | 比较两个 IPv6 地址是否相等。 |
| `function TranslateBindAddr(addr: SystemString): SystemString;` | 将绑定地址翻译为可读描述（如 `'0.0.0.0'` → `'All IPv4'`）。 |
| `procedure ExtractHostAddress(var Host: U_String; var Port: Word); overload;` | 从 `Host:Port` 或 `[IPv6]:Port` 格式字符串中提取地址和端口。 |
| `procedure ExtractHostAddress(var Host, Port: U_String); overload;` | 同上，端口以字符串返回。 |
| `function Build_Host_URL(Host, Port: SystemString): SystemString; overload;` | 构建 `Host:Port` URL，IPv6 自动加方括号。 |
| `function Build_Host_URL(Host: SystemString; Port: Word): SystemString; overload;` | 构建 `Host:Port` URL。 |
| `function Get_Link_OK_Send_Tunnel(IO_: TPeerIO; var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean; overload;` | 获取双通道模式下的发送隧道引用和 IO ID。 |
| `function Get_Link_OK_Send_Tunnel(Framework_: TZNet; ID_: Cardinal; var Send_Tunnel: TZNet; var Send_Tunnel_ID: Cardinal): Boolean; overload;` | 通过框架和 IO ID 获取发送隧道。 |
| `function Get_Link_OK_Recv_Tunnel(IO_: TPeerIO; var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean; overload;` | 获取双通道模式下的接收隧道引用和 IO ID。 |
| `function Get_Link_OK_Recv_Tunnel(Framework_: TZNet; ID_: Cardinal; var Recv_Tunnel: TZNet; var Recv_Tunnel_ID: Cardinal): Boolean; overload;` | 通过框架和 IO ID 获取接收隧道。 |
| `procedure DoExecuteResult(IO: TPeerIO; const QueuePtr: PQueueData; const Result_Text: SystemString; Result_DF: TDFE);` | 执行队列数据的结果回调。根据 `QueuePtr` 中的回调类型（Console/Stream）调用相应的回调函数。 |
| `procedure Set_Instance_QuietMode(Inst: TZNet; QuietMode_: Boolean);` | 递归设置框架实例及其所有克隆（P2PVM 克隆客户端）的静默模式。 |

---

## 15. 全局常量与变量

### 15.1 全局变量

| 变量名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `ZNet_Instance_Pool` | `TZNet_Instance_Pool` | 全局框架实例池，跟踪所有活跃的 `TZNet` 实例。用于调试和监控。 |
| `HPC_Instance_Pool` | `THPC_Instance_Pool` | 全局 HPC 任务池，跟踪所有活跃的 `THPC_Base` 任务。用于调试和监控。 |
| `ProgressBackgroundProc` | `TOnProgressBackground_C` | 全局后台进度钩子（C 风格）。在每个 `Progress` 循环开始时调用。 |
| `ProgressBackgroundMethod` | `TOnProgressBackground_M` | 全局后台进度钩子（方法风格）。在每个 `Progress` 循环开始时调用。 |

### 15.2 协议标记常量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `ZNet_Def_Sequence_Packet_HeadSize` | `$16`（22 字节） | 序列包头部大小（不含类型字节）。 |
| `ZNet_Def_Sequence_QuietPacket` | `$01` | 安静序列包标记（不要求确认）。 |
| `ZNet_Def_Sequence_Packet` | `$02` | 标准序列包标记（要求确认）。 |
| `ZNet_Def_Sequence_EchoPacket` | `$03` | 序列包确认标记。 |
| `ZNet_Def_Sequence_KeepAlive` | `$04` | Keep-Alive 序列包标记。 |
| `ZNet_Def_Sequence_EchoKeepAlive` | `$05` | Keep-Alive 确认标记。 |
| `ZNet_Def_Sequence_RequestResend` | `$06` | 重传请求标记。 |
| `ZNet_Def_p2pVM_echoing` | `$01` | P2PVM 回显请求。 |
| `ZNet_Def_p2pVM_echo` | `$02` | P2PVM 回显响应。 |
| `ZNet_Def_p2pVM_AuthSuccessed` | `$09` | P2PVM 认证成功。 |
| `ZNet_Def_p2pVM_Listen` | `$10` | P2PVM 监听通知。 |
| `ZNet_Def_p2pVM_ListenState` | `$11` | P2PVM 监听状态更新。 |
| `ZNet_Def_p2pVM_Connecting` | `$20` | P2PVM 连接请求。 |
| `ZNet_Def_p2pVM_ConnectedReponse` | `$21` | P2PVM 连接响应。 |
| `ZNet_Def_p2pVM_Disconnect` | `$40` | P2PVM 断开通知。 |
| `ZNet_Def_p2pVM_LogicFragmentData` | `$54` | P2PVM 逻辑分片数据。 |
| `ZNet_Def_p2pVM_OwnerIOFragmentData` | `$64` | P2PVM 物理 IO 分片数据。 |
| `ZNet_Def_DefaultConsoleToken` | `$F1` | 控制台命令类型标记。 |
| `ZNet_Def_DefaultStreamToken` | `$2F` | 流命令类型标记。 |
| `ZNet_Def_DefaultConsoleNotifyToken` | `$F3` | 控制台通知类型标记。 |
| `ZNet_Def_DefaultStreamNotifyToken` | `$4F` | 流通知类型标记。 |
| `ZNet_Def_DefaultBigStreamToken` | `$F5` | 大流命令类型标记。 |
| `ZNet_Def_DefaultBigStreamReceiveFragmentSignal` | `$F6` | 大流分片信号标记。 |
| `ZNet_Def_DefaultBigStreamReceiveDoneSignal` | `$F7` | 大流完成信号标记。 |
| `ZNet_Def_DefaultCompleteBufferToken` | `$6F` | 完整缓冲类型标记。 |
| `ZNet_Def_DataHeadToken` | `$F0F0F0F0` | 协议帧头标记。 |
| `ZNet_Def_DataTailToken` | `$F1F1F1F1` | 协议帧尾标记。 |

### 15.3 默认配置常量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `ZNet_Progress_Max_Delay` | `1000` | 每次 `Progress` 循环最大耗时（毫秒）。 |
| `ZNet_Def_SendFlushSize` | `32 * 1024` | 发送刷新块大小（字节）。 |
| `ZNet_Def_Extract_Physics_Fragment_Max_Size` | `1024 * 1024` | 每次提取物理片段最大字节数。 |
| `ZNet_Def_Per_Progress_Loop_Limit` | `500` | 每次 `Progress` 循环最大处理命令数。 |
| `ZNet_Def_MaxCompleteBufferSize` | `64 * 1024 * 1024` | 最大完整缓冲大小（字节）。 |
| `ZNet_Def_CompleteBufferCompressionCondition` | `1024` | 完整缓冲压缩条件阈值（字节）。 |
| `ZNet_Def_CompleteBuffer_SwapSpace_Activted` | `False` | 完整缓冲交换空间默认状态。 |
| `ZNet_Def_CompleteBuffer_SwapSpace_Trigger` | `1024` | 完整缓冲交换触发大小（字节）。 |
| `ZNet_Def_SequencePacketMTU` | `1536` | 序列包 MTU（字节）。 |
| `ZNet_Def_P2PVM_MaxVMFragmentSize` | `1536` | P2PVM 最大分片大小（字节）。 |
| `ZNet_Def_P2PVM_Progress_Send_Size` | `500 * 1024` | P2PVM 每次进度发送最大字节数。 |
| `ZNet_Def_DoStatusID` | `$0FFFFFFF` | 日志输出 ID。 |
| `ZNet_Def_VMAuthSize` | `16` | P2PVM 认证令牌大小（32 位整数个数）。 |
| `ZNet_Def_BigStream_ChunkSize` | `1024 * 1024` | 大流分片大小（字节）。 |
| `ZNet_Def_BigStream_Memory_SwapSpace_Activted` | `False` | 大流交换空间默认状态。 |
| `ZNet_Def_BigStream_SwapSpace_Trigger` | `1024 * 1024` | 大流交换触发大小（字节）。 |
| `ZNet_Def_Physics_Fragment_Cache_Activted` | `False` | 物理片段缓存默认状态。 |
| `ZNet_Def_Physics_Fragment_Cache_Trigger` | `10000` | 物理片段缓存触发数量。 |
| `ZNet_Def_Swap_Space_Technology_Security_Model` | `False` | 交换空间加密默认状态。 |
| `ZNet_Def_Swap_Space_Technology_Delta` | `64 * 1024 * 1024` | 交换空间增量大小（字节）。 |
| `ZNet_Def_Swap_Space_Technology_Block` | `$FFFF` | 交换空间块大小。 |
| `ZNet_Def_IPV6_Seed` | `0` | IPv6 地址生成种子。 |

### 15.4 内部系统命令名

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `C_CipherModel` | `__@CipherModel` | 加密模型协商命令（握手）。 |
| `C_Wait` | `__@Wait` | 延迟测试命令。 |
| `C_BuildP2PAuthToken` | `__@BuildP2PAuthToken` | 构建 P2PVM 认证令牌命令。 |
| `C_InitP2PTunnel` | `__@InitP2PTunnel` | 初始化 P2PVM 隧道命令。 |
| `C_CloseP2PTunnel` | `__@CloseP2PTunnel` | 关闭 P2PVM 隧道命令。 |
| `C_NULL` | `__@NULL` | 空命令（Keep-Alive）。 |
| `C_Complete_Buffer_Stream_Reponse` | `__@Complete_Buffer_Stream_Reponse` | 完整缓冲流响应命令。 |
| `C_BuildStableIO` | `__@BuildStableIO` | 构建稳定会话命令。 |
| `C_OpenStableIO` | `__@OpenStableIO` | 打开稳定会话命令。 |
| `C_CloseStableIO` | `__@CloseStableIO` | 关闭稳定会话命令。 |

---

*Z.Net 框架完整白皮书至此结束。本白皮书涵盖了 `Z.Net.pas` 中所有公开类、记录、枚举、接口、回调类型、全局函数及常量，并对每个类提供了功能说明与典型用法。适用于深度学习、日常开发及 AI 辅助编程参考。*
