# Z.Core 核心库完全指南

**Z.Core** 是一个高性能、跨平台的并发与基础架构库，专为 **Delphi** 和 **Free Pascal** 设计。它提供了自适应的线程池、无锁数据结构、用户态同步机制、Mersenne Twister 随机数生成器、并行循环等核心组件，被广泛应用于高吞吐量服务器、实时系统和复杂计算任务中。

本指南按功能模块组织，每个模块包含 **概念**、**关键类型/函数**、**代码示例**和 **内部机制**，特别深入剖析了 **TCompute 数学线程化机制** 与 **TBigList 高性能链表结构**。

---

## 1. 核心设计哲学

Z.Core 遵循以下设计原则：

- **性能优先**：大量使用对象池、自旋锁、自定义内存操作和无锁技术，最小化开销。
- **跨编译器与跨平台**：统一 Delphi 和 FPC 的差异，支持 Windows、Linux、macOS、iOS、Android、BSD。
- **自包含**：最小化外部依赖，自行实现线程同步、线程池和数据结构。
- **软同步技术**：提供用户态线程同步（`TSoft_Synchronize_Tool`），避免内核上下文切换，适用于高频短小同步操作。

---

## 2. 全局配置与初始化

### 2.1 线程池初始化

**主题**：启动核心线程池  
**关键函数**：`InitCoreThreadPool`  
**参数**：
- `Thread_Num`：线程池最大尺寸（实际受 `LimitMaxComputeThread` 宏限制）。
- `Parallel_Granularity_`：并行循环默认使用的线程数（即 `ParallelGranularity`）。

**示例**：
```pascal
// 通常在程序初始化段调用
InitCoreThreadPool(
  CpuCount * 2,    // 最大并发线程数
  CpuCount * 2     // 默认并行粒度
);
```

**内部机制**：
- 创建全局调度线程（`TCore_Dispatch_Order_Thread`）和空闲线程池。
- 内部使用 `TCritical` 保护共享结构。
- 自缩放机制：空闲线程超过 `Core_Thread_Life_Time_Tick__`（默认 200ms）后自动退出。

### 2.2 安全关闭调度器

**主题**：优雅终止线程池  
**关键函数**：`Close_Core_Dispatch_Thread`、`Open_Core_Dispatch_Thread`

**行为**：
- `Close_Core_Dispatch_Thread` 设置终止标志，等待调度线程退出（最长 1 秒），再等待所有活动任务完成（最长 1 秒），期间调用 `Check_Soft_Thread_Synchronize` 防止死锁。
- 超时后强制返回，避免进程挂起（适合 DLL 卸载或程序退出）。
- `Open_Core_Dispatch_Thread` 先关闭已有调度器，再创建新实例，保证单例。

---

## 3. 数据结构

### 3.1 TBigList – 双向循环链表与回收池

**类型**：`TBigList<T>`  
**关键特性**：
- **双向循环链表**：每个节点包含 `Prev`/`Next` 指针，O(1) 插入/删除。
- **回收池（Recycle Pool）**：删除的节点暂存于池中，后续添加优先复用，减少内存分配。
- **索引缓存（FList）**：懒加载的指针数组，提供 O(1) 随机访问（修改后自动失效并重建）。
- **迭代器**：正向（`TRepeat___`）和反向（`TInvert_Repeat___`），支持安全删除当前节点（`Discard`）。
- **排序**：内置快速排序，支持三种回调风格（C, M, P），排序基于快照交换数据，不改变链表结构。

**基本操作示例**：
```pascal
var
  List: TBigList<Integer>;
  It: TBigList<Integer>.TRepeat___;
begin
  List := TBigList<Integer>.Create;
  try
    List.Add(10);
    List.Add(20);
    List.Insert(15, List.First); // 头部插入

    It := List.Repeat_;
    while It.Next do
      if It.Queue^.Data = 15 then
        It.Discard;               // 安全删除

    WriteLn(List[0]);             // 索引访问 → 10

    List.Sort_C(function(var L, R: Integer): Integer
      begin Result := L - R; end);

    List.MoveToFirst(List.Find_Data(20)); // LRU 优化
  finally
    List.Free;
  end;
end;
```

**回收池机制**：
- `Remove_P`/`Remove_Data` 将节点放入 `FRecycle_Pool__`（一个 `TOrderStruct`），而非直接释放。
- `Add`/`Add_Null` 优先从回收池取用，仅当池空时才分配新节点。
- 可调用 `Free_Recycle_Pool` 强制清空并真正释放所有节点。

**索引缓存**：
- `List[Index]` 访问时检查 `FChanged` 标志，若列表被修改则重建指针数组（懒加载）。
- 适合读多写少场景。

**线程安全版本**：`TCritical_BigList<T>`（`TC_BigList<T>` 为其别名）在每个公共方法上加锁。

**对象列表特化**：`TBig_Object_List<T: class>` 增加 `AutoFreeObject` 属性，删除时自动释放对象。

### 3.2 TOrderStruct – 简单 FIFO 队列

**类型**：`TOrderStruct<T>`  
**特点**：
- 单向链表，仅支持尾部入队（`Push`）和头部出队（`Next`）。
- 非线程安全；线程安全版本 `TCriticalOrderStruct`。
- 可自定义 `OnFree` 事件进行数据清理。

**示例**：
```pascal
var
  Queue: TOrderStruct<Integer>;
begin
  Queue := TOrderStruct<Integer>.Create;
  try
    Queue.Push(1);
    Queue.Push(2);
    while Queue.Num > 0 do
    begin
      WriteLn(Queue.First^.Data);
      Queue.Next; // 出队并释放节点
    end;
  finally
    Queue.Free;
  end;
end;
```

### 3.3 TBig_Hash_Pair_Pool – 链式哈希表

**类型**：`TBig_Hash_Pair_Pool<TKey, TValue>`  
**特性**：
- 使用 CRC32 计算键哈希，通过桶索引映射。
- 冲突解决采用链表，并维护全局队列（`FQueue_Pool`）便于遍历。
- 查找命中时自动将节点移到桶链表头部（LRU 优化）。
- 提供 `Get_Value_Ptr`：若键不存在则插入默认值并返回指针。
- 线程安全版本：`TCritical_Big_Hash_Pair_Pool`。

**示例**：
```pascal
type
  THashMap = TBig_Hash_Pair_Pool<string, Integer>;
var
  Map: THashMap;
  p: THashMap.PPair_Pool_Value__;
begin
  Map := THashMap.Create(1024);
  try
    Map.Add('apple', 1, False);
    Map.Add('banana', 2, True); // 覆盖

    WriteLn(Map['apple']);      // → 1

    p := Map.Get_Value_Ptr('orange', 0);
    p^.Second := 10;

    Map.For_C(procedure(p: THashMap.PPair_Pool_Value__; var Aborted: Boolean)
      begin WriteLn(p^.Data.Primary, '=>', p^.Data.Second); end);

    Map.Delete('banana');
  finally
    Map.Free;
  end;
end;
```

---

## 4. 线程与并发

### 4.1 TCompute – 工作线程与任务调度

**主题**：线程池工作单元，专为数学计算优化  
**关键类**：`TCompute`  
**核心概念**：
- **任务提交**：通过静态方法 `RunC`、`RunM`、`RunP` 提交三种回调风格的任务（C：普通过程，M：对象方法，P：匿名/嵌套过程）。
- **自缩放线程池**：全局调度器（`TCore_Dispatch_Order_Thread`）监控任务队列，若有新任务则分配给空闲线程或创建新线程（受 `LimitMaxComputeThread` 宏限制）。空闲线程超过 `Core_Thread_Life_Time_Tick__`（默认 200ms）后自动退出。
- **线程局部随机数**：每个 `TCompute` 线程独立拥有一个 MT19937 实例（`FRndInstance`），避免竞争。种子在启动时根据宏 `MT19937SeedOnTComputeThreadIs0` 决定（默认置 0）。
- **状态监控**：`IsRuning` 和 `IsExit` 指针变量用于跟踪任务执行状态。
- **调试信息**：`Set_Thread_Info` 可设置当前线程信息。

**任务提交示例**：
```pascal
TCompute.RunC(
  procedure(Th: TCompute)
  var
    i: Integer;
  begin
    for i := 0 to 999 do
      TMT19937.Rand32(100); // 使用线程局部 MT19937
    TCompute.Set_Thread_Info('My Math Task');
  end,
  procedure(Th: TCompute)
  begin
    WriteLn('Task completed');
  end
);

// 带状态监控
var
  Running, Exited: Boolean;
begin
  TCompute.RunC(procedure(Th: TCompute) begin Sleep(100); end,
                @Running, @Exited);
  while Running do Sleep(1);
end;
```

**线程池调度流程**：
1. 任务通过 `PostComputeDispatchData` 加入 `Core_Dispatch_Order__`（一个 `TCriticalOrderStruct`）。
2. 调度线程循环取任务，先尝试唤醒空闲线程（通过 `Core_Thread_Wait_Sum__` 统计）。
3. 若无空闲线程且未达上限，则创建新 `TCompute`。
4. 工作线程执行任务后进入等待循环，超时自动退出。

**MT19937 隔离**：
- 线程启动时调用 `InternalMT19937__()` 获取或创建实例，存入 `FRndInstance`。
- 实例仅在当前线程使用，完全无锁。
- 线程销毁时，实例回收到全局池供复用。

### 4.2 软同步（User‑Space Synchronization）

**主题**：轻量级线程同步，避免内核切换  
**核心类**：`TSoft_Synchronize_Tool`  
**关键函数**：`Check_Soft_Thread_Synchronize`, `TCompute.Sync`

**机制**：
- 每个线程（包括主线程）拥有一个 `TSoft_Synchronize_Tool`，内部维护一个队列。
- 同步请求（通过 `Synchronize` 方法）被放入队列，目标线程定期调用 `Check_Synchronize` 处理。
- 完全用户态，无内核切换，适合高频短小同步操作（但会占用 CPU）。
- 通过宏 `Core_Thread_Soft_Synchronize` 启用（默认开启）。

**示例**：
```pascal
// 同步到主线程
TCompute.Sync(procedure begin Form1.Caption := 'Updated'; end);

// 同步到指定 TCompute 线程
TCompute.Sync_To(TargetThread, procedure begin // 在目标线程执行 end);
```

### 4.3 TThreadPost – 线程消息投递

**主题**：向指定线程投递过程  
**关键类**：`TThreadPost`  
**关键方法**：`PostC1`, `PostM1`, `PostP1`, `Sync_Wait_Post*`

**特性**：
- 每个 `TThreadPost` 绑定一个线程 ID，向该线程投递过程。
- 支持三种回调风格（C, M, P）。
- 目标线程调用 `Progress` 方法处理队列。
- `Sync_Wait_*` 方法阻塞调用者直到过程被执行。

**示例**：
```pascal
var
  MainPost: TThreadPost;
begin
  MainPost := MainThreadProgress;
  MainPost.PostC1(procedure begin ShowMessage('Hello'); end);
  MainPost.Sync_Wait_PostC1(procedure begin ShowMessage('Blocking'); end);
end;
```

---

## 5. 并行循环

**主题**：多线程 `for` 循环  
**全局过程**：`ParallelFor`（根据编译器自动选择 `DelphiParallelFor` 或 `FPCParallelFor`）

**两种策略**：
- **Block（块）**：将区间分成连续块，每个线程处理一块，适合工作量均匀的场景。
- **Fold（折叠）**：使用步长（`Granularity`）分配，每个线程跳过 `Granularity` 个索引，实现负载均衡，适合工作量不均衡的场景。
- 默认使用 `Fold`（由宏 `FoldParallel` 控制）。

**溢出控制**：
- 通过 `Parallel_Overflow__` 限制并发循环数量（由 `Max_Activted_Parallel__` 配置，0 为无限制），防止过度订阅。

**后备模式**：当循环粒度较小、单线程更快，或并行开关（`WorkInParallelCore`）关闭时，自动退化为单线程执行。

**示例**：
```pascal
ParallelFor(0, 999, procedure(pass: Integer) begin // 处理 end);
ParallelFor(4, True, 0, 999, procedure(pass: Integer) begin // ... end);
```

---

## 6. 随机数生成 – MT19937

**主题**：Mersenne Twister 随机数生成器  
**核心类**：`TMT19937`（静态类，使用当前线程实例），`TMT19937Random`（独立对象）

**算法特性**：
- 标准 MT19937，状态向量 624 个 32 位字，周期 2^19937-1。
- 每个 `TCompute` 线程拥有独立实例（`FRndInstance`），避免竞争。
- 支持保存/恢复状态（`SaveToStream` / `LoadFromStream`）。
- 可选替换 Delphi 内置 `Random`（定义 `InstallMT19937CoreToDelphi`）。

**静态方法示例**：
```pascal
TMT19937.Randomize;
rnd := TMT19937.Rand32(100);     // 0..99
WriteLn(TMT19937.RandD);          // 0..1 双精度
```

**独立对象示例**：
```pascal
var RNG: TMT19937Random;
begin
  RNG := TMT19937Random.Create;
  RNG.seed := 12345;
  WriteLn(RNG.Rand64(1000));
  RNG.Free;
end;
```

---

## 7. 原子操作与锁

### 7.1 原子增减

**函数**：`AtomInc`/`AtomDec` 支持 `Int64`, `UInt64`, `Integer`, `Cardinal`。  
**实现**：
- Delphi：映射到 `System.AtomicIncrement`/`Decrement`。
- FPC：若定义 `USED_INTERLOCK` 则使用 `InterlockedExchangeAdd`，否则用临界区模拟。

**示例**：
```pascal
var Counter: Integer;
begin
  Counter := 0;
  ParallelFor(0, 99, procedure(pass: Integer) begin AtomInc(Counter); end);
  // Counter = 100
end;
```

### 7.2 可回收临界区 – TCritical

**特性**：
- 底层使用 `TSystem_Critical`（默认为 `TCriticalSection`，若定义 `SoftCritical` 则使用自旋锁 `TSoftCritical`）。
- 实例池：销毁时底层对象放入 `System_Critical_Recycle_Pool__` 供复用。
- 提供便利方法 `Inc_`, `Dec_`, `Get` 在锁内原子修改变量。

**示例**：
```pascal
var Lock: TCritical; Shared: Integer;
begin
  Lock := TCritical.Create;
  Lock.Acquire;
  try Inc(Shared); finally Lock.Release; end;
  Lock.Free;
end;
```

---

## 8. 内存与对象管理

**安全释放函数**：
- `DisposeObject(Obj)`：捕获异常，返回是否成功释放。
- `DisposeObjectAndNil(var Obj)`：释放并置 `nil`。
- 支持批量释放：`DisposeObject([Obj1, Obj2])`。

**示例**：
```pascal
var Obj: TObject;
begin
  Obj := TObject.Create;
  DisposeObjectAndNil(Obj); // Obj = nil
end;
```

---

## 9. 实用工具函数

### 9.1 CRC32 与哈希

- `Get_CRC32(Data: PByte; Size: NativeInt): THash`
- `Hash_Key_Mod(hash: THash; Num: Integer): Integer` 映射哈希到桶索引。

### 9.2 内存操作

- `FillPtrByte(dest: Pointer; Size: NativeUInt; Value: Byte)`：高效填充（块操作）。
- `CompareMemory(p1, p2: Pointer; Size: NativeUInt): Boolean`
- `CopyPtr(sour, dest: Pointer; Size: NativeUInt)`：支持重叠拷贝。

### 9.3 时间与平台

- `GetTimeTick(): TTimeTick`：单调递增毫秒时钟（基于 `TThread.GetTickCount` 累加，避免回退）。
- `CurrentPlatform` 枚举标识运行平台（Win32/64, OSX, Linux, Android, iOS, BSD）。
- `IsMobile: Boolean` 判断是否 iOS/Android。
- `Get_Compiler_Version: string` 返回编译器名称、版本及位数。

---

## 10. CPS 性能分析工具

**类型**：`TCPS_Tool`（记录类型）  
**方法**：
- `Begin_Caller` / `End_Caller` 包围要测量的代码。
- 每秒自动更新 `CPS` 字段（调用次数/秒），并记录单次调用最大耗时 `CPU_Time`。

**示例**：
```pascal
var CPS: TCPS_Tool;
begin
  CPS.Reset;
  while True do
  begin
    CPS.Begin_Caller;
    // 要测量的代码
    CPS.End_Caller;
    Sleep(100);
  end;
end;
```

---

## 11. 双主线程（Simulator Main Thread）

**主题**：让任意线程拥有独立同步队列  
**过程**：`Begin_Simulator_Main_Thread(Simulator_Main_Proc_: TOnSynchronize_C_NP)`  
**状态**：`Simulator_Main_Thread_Activted: Boolean`

**机制**：
- 调用后，`Main_Thread_ID` 和 `Main_Thread` 切换为模拟线程，所有 `TCompute.Sync*` 和 `TSoft_Synchronize_Tool` 的同步请求路由到模拟线程。
- 原始主线程和模拟线程都需调用 `Check_Soft_Thread_Synchronize` 消费各自的队列。
- 用于脱离 RTL 的 `CheckSynchronize`，特别适用于 DLL、服务或无窗口应用。

**示例**：
```pascal
procedure MySimulatedMain;
begin
  while Simulator_Main_Thread_Activted do
  begin
    Check_Soft_Thread_Synchronize(10);
    // 处理自定义消息
  end;
end;

begin
  Begin_Simulator_Main_Thread(MySimulatedMain);
  while Simulator_Main_Thread_Activted do
    Check_Soft_Thread_Synchronize(0);
end;
```

---

## 附录：常用宏开关

| 宏名                              | 作用                                                         |
|-----------------------------------|--------------------------------------------------------------|
| `Core_Thread_Soft_Synchronize`    | 启用软同步（默认开启）                                       |
| `FoldParallel`                    | 并行循环采用 Fold 策略（默认）                               |
| `LimitMaxParallelThread`          | 限制并行循环最大线程数                                       |
| `LimitMaxComputeThread`           | 限制线程池最大线程数                                         |
| `InstallMT19937CoreToDelphi`      | 用 MT19937 替换 Delphi 的 `Random`（仅特定版本默认）         |
| `MT19937SeedOnTComputeThreadIs0`  | 工作线程启动时种子置 0（默认）                               |
| `Intermediate_Instance_Tool`      | 启用对象实例跟踪（调试用）                                   |
| `SoftCritical`                    | 使用自旋锁代替操作系统临界区                                 |
| `USED_INTERLOCK`                  | FPC 下使用 `InterlockedExchangeAdd` 实现原子操作（64 位启用）|

---

本指南全面覆盖了 Z.Core 的核心功能，深入剖析了 **TCompute 数学线程化**（内置随机数种子、自缩放线程池）和 **TBigList 高性能链表**（双向循环、回收池、索引缓存、迭代器）的实现细节与使用方式。每个模块均提供了可运行的示例和内部机制说明，便于快速掌握并应用于实际项目。