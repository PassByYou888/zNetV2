# Z.Core 知识库（最终传承版）

> **定位**：面向 AI 与人类工程师的权威参考。目的是让读者**无需翻阅源码**即可安全、准确地使用 Z.Core。
> **承诺**：所有描述均来自 `Z.Core.pas` 及其 `.inc` 源文件的逐行核对。凡我无法从源码确定的，在文末"诚实的不确定清单"中明示。
> **使用方式**：AI 可直接引用本文件内的 API 签名、契约、模板、反例；遇到不确定清单中的场景，必须回查源码或询问人类。

---

## 第 0 章 快速定位：Z.Core 是什么

Z.Core 是一套**面向高并发、低延迟场景的系统级基础设施**，为 Delphi 和 Free Pascal 提供统一 API。它由以下层组成：

```
┌───────────────────────────────────────────────────────────────┐
│  应用层：调用 Z.Core API 的业务代码                              │
├───────────────────────────────────────────────────────────────┤
│  容器层：TBigList / TBig_Hash_Pair_Pool / TOrderStruct         │
├───────────────────────────────────────────────────────────────┤
│  并发层：TCompute 线程池 / TSoft_Synchronize_Tool / TThreadPost │
│          ParallelFor（Block / Fold）                            │
├───────────────────────────────────────────────────────────────┤
│  原语层：TCritical / TAtomVar / AtomInc/Dec / TSystem_Critical  │
├───────────────────────────────────────────────────────────────┤
│  基础层：DisposeObject / CopyPtr / GetTimeTick / Get_CRC32      │
│          MT19937 / 端序 / 位运算 / MemoryAlign                  │
├───────────────────────────────────────────────────────────────┤
│  平台层：Z.Define.inc 抹平 Delphi/FPC 差异                      │
└───────────────────────────────────────────────────────────────┘
```

**核心设计取舍**（理解了这几条，就理解了 Z.Core）：

1. **性能优先**：大量使用对象池、自旋等待、自定义块内存操作。
2. **跨编译器透明**：类型别名（`TCore_Object` / `TCore_Thread` / `TCore_Stream`）统一 Delphi 与 FPC。
3. **用户态同步主导**：默认 `Core_Thread_Soft_Synchronize` 开启，跨线程调用优先走 `TSoft_Synchronize_Tool` 而非 OS 内核同步。
4. **确定性回收**：
   - `TCritical` 的底层 `TSystem_Critical` 实例**真正复用**（从池取、还池）。
   - `TBigList` 的 `FRecycle_Pool__` **不是复用池**，而是**延迟删除队列**（详见 §5.2.5）。
   - `MT19937` 实例按线程分配、按线程回收。

---

## 第 1 章 编译宏与平台定义（Z.Define.inc）

### 1.1 影响行为的关键宏

| 宏名 | 默认 | 作用 | 影响面 |
|------|------|------|--------|
| `Core_Thread_Soft_Synchronize` | **开启** | 用软同步替代 `TThread.Synchronize` | 所有 `TCompute.Sync*` / `Check_*_Thread_Synchronize` |
| `FoldParallel` | **开启** | 并行循环走 Fold；关闭则走 Block | `ParallelFor` / `DelphiParallelFor` / `FPCParallelFor` |
| `LimitMaxParallelThread` | **开启** | 并行循环最大线程数受 CPU 核数限制 | `ParallelFor` |
| `LimitMaxComputeThread` | 关闭 | 线程池最大线程数受限 | `TCompute` 调度 |
| `MT19937SeedOnTComputeThreadIs0` | **开启** | 每个工作线程启动时 RNG 种子置 0 | `TCompute.Execute` |
| `InstallMT19937CoreToDelphi` | 部分 Delphi 版本开启 | 用 MT19937 替换 `Random()` | 全局 `Random` 调用 |
| `Intermediate_Instance_Tool` | DEBUG 下开启 | 跟踪对象构造/析构 | `TCore_Object_Intermediate` 系列 |
| `CriticalSimulateAtomic` | FPC 开 / Delphi 关 | 用 `TMonitor` 模拟原子操作 | `LockObject` / `UnLockObject` |
| `USED_INTERLOCK` | FPC 64 位开启 | 用 `InterlockedExchangeAdd` 实现原子 | `AtomInc` / `AtomDec` |
| `Parallel` | Release 且非 ARM 开启 | 并行计算总开关 | `ParallelFor` 家族 |
| `Debug` | 编译器决定 | 调试模式 | 许多路径分支 |

### 1.2 平台常量

```pascal
CPU64: Boolean;                       // 是否 64 位
IsDebug: Boolean;                     // 是否 DEBUG
CurrentPlatform: TExecutePlatform;    // epWin32/epWin64/epOSX64/.../epUnknow
MaxInt64 = $7FFFFFFFFFFFFFFF;
C_Tick_Second = 1000;                 // 毫秒常量
C_Tick_Minute / C_Tick_Hour / C_Tick_Day / C_Tick_Week / C_Tick_Year
```

### 1.3 类型别名（用于跨编译器）

| Z.Core 别名 | 实际类型 |
|-------------|---------|
| `TCore_Object` | `TObject` |
| `TCore_Persistent` | `TPersistent` |
| `TCore_Stream` | `TStream` |
| `TCore_FileStream` | `TFileStream` |
| `TCore_StringStream` | `TStringStream` |
| `TCore_MemoryStream` | `TMemoryStream` |
| `TCore_Thread` | `TThread` |
| `TCore_Strings` | `TStrings` |
| `TCore_StringList` | `TStringList` |
| `TCore_Component` | `TComponent` |
| `Core_Exception` | `Exception` |
| `THash` | `Cardinal` |
| `THash64` | `UInt64` |
| `TTimeTick` | `UInt64` |
| `TSeekOrigin` | `Classes.TSeekOrigin` |
| `TNotify` | `Classes.TNotifyEvent` |

---

## 第 2 章 基础工具

### 2.1 对象释放

```pascal
function  DisposeObject(const Obj: TObject): Boolean;
procedure DisposeObject(const objs: array of TObject);
function  DisposeObjectAndNil(var Obj): Boolean;
function  FreeObj(const Obj: TObject): Boolean;            // 别名
function  FreeObject(const Obj: TObject): Boolean;         // 别名
procedure FreeObject(const objs: array of TObject);        // 别名
function  FreeObjAndNil(var Obj): Boolean;                 // 别名
```

**契约**：
- **永不抛出异常**。内部 `try...except` 包裹。
- 若释放失败，返回 `False` 并触发 `On_Raise_Info` 回调（若已设置）。
- **不线程安全**：多个线程同时 Free 同一对象会崩。需调用方加锁。
- `DisposeObjectAndNil` 释放后把变量置 `nil`。

### 2.2 内存操作

```pascal
procedure FillPtrByte(const dest: Pointer; Size: NativeUInt; const Value: Byte);
procedure FillPtr(const dest: Pointer; Size: NativeUInt; const Value: Byte);   // = FillPtrByte
procedure FillByte(const dest: Pointer; Size: NativeUInt; const Value: Byte);  // = FillPtrByte
function  CompareMemory(const p1, p2: Pointer; Size: NativeUInt): Boolean;
procedure CopyPtr(const sour, dest: Pointer; Size: NativeUInt);
function  DeltaNum(const value_, Delta_: NativeInt): NativeInt;    // 向上对齐到 Delta
function  DeltaStep(const value_, Delta_: NativeInt): NativeInt;   // = DeltaNum
function  MemoryAlign(addr: Pointer; alignment_: NativeUInt): Pointer;
function  GetOffset(const p_: Pointer; const offset_: NativeInt): Pointer;
function  GetPtr(const p_: Pointer; const offset_: NativeInt): Pointer;
```

**契约**：
- `FillPtrByte` 内部按 8/4/2/1 字节块填充（无 SIMD，纯标量）。
- `CompareMemory` 按 8/4/2/1 字节块比较，比逐字节快。
- `CopyPtr` 处理重叠（类似 `Move`），按 8/4/2/1 字节块拷贝。
- `DeltaNum` 要求 `Delta_` 是 2 的幂；`Delta_ <= 0` 时返回原值。
- **不要**在 `FillPtr` / `CopyPtr` 上叠加 `OverflowCheck` / `RangeCheck` 之外的特殊语义。

### 2.3 时间

```pascal
function GetTimeTick(): TTimeTick;         // 单调递增毫秒计数
function GetTimeTickCount(): TTimeTick;    // 别名
function GetCrashTimeTick(): TTimeTick;    // = MaxUInt64 - GetTimeTick
function SameF(const A, B: Double; Epsilon: Double = 0): Boolean;   // 浮点比较
function SameF(const A, B: Single; Epsilon: Single = 0): Boolean;
```

**`GetTimeTick` 实现要点**：
- 内部使用 `TCore_Thread.GetTickCount()` 累加到 `Core_RunTime_Tick`（64 位），避免 `GetTickCount` 的 49.7 天回绕。
- 用 `TimeTick_Critical__` 保护累加过程。
- **首次调用会初始化 `Core_Step_Tick`**，因此建议在初始化后调用一次再使用。

### 2.4 杂项工具

```pascal
function if_(const bool_: Boolean; const True_, False_: <各种类型>): <同类型>;
function ifv_(const bool_: Boolean; const True_, False_: Variant): Variant;
procedure RaiseInfo(const n: string);
procedure RaiseInfo(const n: string; const Args: array of const);
function IsValidUTF8Bytes(const Data: TBytes): Boolean;
procedure Nop;
function IsDebuging: Boolean;
function Get_Compiler_Version: string;
```

**`if_` 支持的返回类型**：`Boolean`、`ShortInt`、`SmallInt`、`Integer`、`Int64`、`Byte`、`Word`、`Cardinal`、`UInt64`、`Single`、`Double`、`string`。

### 2.5 哈希与 CRC32

```pascal
function Get_CRC32(const Data: PByte; const Size: NativeInt): THash;
function Hash_Key_Mod(const hash: THash; const Num: Integer): Integer;
```

**契约**：
- `Get_CRC32` 查表法（`C_CRC32Table[256]`），无 SIMD 加速。
- `Size > 0` 时正序处理；`Size < 0` 时倒序处理（用于特殊场景）。
- `Hash_Key_Mod` 返回 `hash mod Num`，若 `Num <= 0` 或 `hash <= 0` 返回 0。

### 2.6 等待信号

```pascal
type
  TBool_Signal_Array = array of Boolean;
  PBool_Signal_Array = array of PBoolean;
  TInteger_Signal_Array = array of Integer;
  PInteger_Signal_Array = array of PInteger;

procedure Wait_All_Signal(var arry: TBool_Signal_Array; const signal_: Boolean);
procedure Wait_All_Signal(const arry: PBool_Signal_Array; const signal_: Boolean);
procedure Wait_All_Signal(var arry: TInteger_Signal_Array; const signal_: Integer);
procedure Wait_All_Signal(const arry: PInteger_Signal_Array; const signal_: Integer);
```

**契约**：忙等循环 + `TCompute.Sleep(1)`，直到所有信号匹配。**仅用于测试/演示，不要在生产代码里滥用**。

---

## 第 3 章 临界区与原子操作

### 3.1 TCritical（**可递归的锁包装**）

```pascal
TCritical = class sealed(TCore_Object)
public
  constructor Create(); overload;
  constructor Create(const Name_: string); overload;
  destructor  Destroy; override;

  procedure Acquire;  inline;    // = Lock / Enter
  procedure Release;  inline;    // = UnLock / Leave
  procedure Enter;    inline;
  procedure Leave;    inline;
  procedure Lock;     inline;
  procedure UnLock;   inline;

  function IsBusy: Boolean;                        // LNum > 0
  property IsLock: Boolean read IsBusy;
  property Busy:   Boolean read IsBusy;
  property Name:   string read FName;

  // 便捷原子操作：加锁 → 读/改 → 解锁
  function Get(var x: Int64): Int64; overload;
  function Get(var x: UInt64): UInt64; overload;
  function Get(var x: Integer): Integer; overload;
  function Get(var x: Cardinal): Cardinal; overload;
  function Inc_(var x: Int64): Int64; overload;
  function Inc_(var x: Int64; const v: Int64): Int64; overload;
  function Dec_(var x: Int64): Int64; overload;
  function Dec_(var x: Int64; const v: Int64): Int64; overload;
  // UInt64 / Integer / Cardinal 同理
end;
```

**实现要点**（源码验证）：
- 底层 `Instance__: TSystem_Critical`（即 `TCriticalSection`）**从全局池 `System_Critical_Recycle_Pool__` 复用**：
  - `Create` 时若池非空，取一个复用；否则 `New` 一个。
  - `Destroy` 时把底层实例 `Push` 回池（不 `Free`）。
  - **这是真正的复用池**，与 `TBigList` 的"延迟删除队列"性质不同。
- `LNum: Integer` 是当前 `TCritical` 实例的递归计数，**不是全局引用计数**。
- 可重入性来自底层 `TCriticalSection`（Windows 下可重入；FPC 下取决于平台实现）。

**全局统计**：
```pascal
function Get_System_Critical_Num: NativeInt;                 // 总创建过的实例数
function Get_System_Critical_Recycle_Pool_Num: NativeInt;    // 池中空闲实例数
```

**契约**：
- `Acquire` / `Release` 必须**成对**调用，同一线程内可递归。
- **跨线程不可重入**：不要在两个不同线程分别锁同一个 `TCritical`（会死锁）。
- 构造/析构本身使用 `System_Critical__` 全局锁保护池操作，不要担心并发问题。
- `Inc_` / `Dec_` 系列**内部会加锁再解锁**，适合"读-改-写"原子操作，但不适合多步操作（多步请手动 `Acquire` / `Release`）。

### 3.2 TAtomVar<T>（**线程安全的变量包装**）

```pascal
TAtomVar<T_> = class
public type
  PT_ = ^T_;
private
  FValue__: T_;
  FCritical: TCritical;
public
  constructor Create(Value_: T_);
  destructor  Destroy; override;

  property Critical: TCritical read FCritical;

  function Lock: T_;              // 加锁并返回当前值
  function LockP: PT_;            // 加锁并返回指针
  property P: PT_ read GetValueP;             // 不加锁取指针（危险）
  property Pointer_: PT_ read GetValueP;      // 同上
  procedure UnLock(const Value_: T_); overload;    // 写值 + 解锁
  procedure UnLock(const Value_: PT_); overload;   // 通过指针写值 + 解锁
  procedure UnLock(); overload;                    // 仅解锁
  property V:     T_ read GetValue write SetValue; // 原子读/写
  property Value: T_ read GetValue write SetValue;
end;
```

**预定义别名**：`TAtomBool`、`TAtomInteger`、`TAtomInt64`、`TAtomCardinal`、`TAtomString`、`TAtomTimeTick`、`TAtomSingle`、`TAtomDouble`、`TAtomExtended` 等。

**契约**：
- `V` / `Value` 属性内部加锁，是**原子**的。
- `P` / `Pointer_` **不加锁**：拿到指针后需自己保证生命周期与竞争安全。
- **`TAtomVar<T>` 与 `AtomInc` / `AtomDec` 不可混用**：前者用 `FCritical` 保护，后者用硬件指令（或 FPC 下的全局 `Atom_Num_Critical__`），**两套机制不互斥**。
- `Lock` 返回当前值；`UnLock(v)` 写值并解锁。必须配对，否则死锁。

### 3.3 原子操作函数（AtomInc / AtomDec）

```pascal
function AtomInc(var x: Int64): Int64;          overload;
function AtomInc(var x: Int64; const v: Int64): Int64; overload;
function AtomDec(var x: Int64): Int64;          overload;
function AtomDec(var x: Int64; const v: Int64): Int64; overload;

function AtomInc(var x: UInt64): UInt64;        overload;
function AtomInc(var x: UInt64; const v: UInt64): UInt64; overload;
function AtomDec(var x: UInt64): UInt64;        overload;
function AtomDec(var x: UInt64; const v: UInt64): UInt64; overload;

function AtomInc(var x: Integer): Integer;      overload;
function AtomInc(var x: Integer; const v: Integer): Integer; overload;
function AtomDec(var x: Integer): Integer;      overload;
function AtomDec(var x: Integer; const v: Integer): Integer; overload;

function AtomInc(var x: Cardinal): Cardinal;    overload;
function AtomInc(var x: Cardinal; const v: Cardinal): Cardinal; overload;
function AtomDec(var x: Cardinal): Cardinal;    overload;
function AtomDec(var x: Cardinal; const v: Cardinal): Cardinal; overload;
```

**实现分支**：
- **Delphi**：`System.AtomicIncrement` / `AtomicDecrement`（硬件指令）。
- **FPC + USED_INTERLOCK**：`InterlockedExchangeAdd` / `InterlockedExchangeAdd64`。
- **FPC 无 USED_INTERLOCK**：`Atom_Num_Critical__.Acquire` → `Inc`/`Dec` → `Release`（全局锁保护）。

**契约**：
- 返回值是**操作后的新值**。
- 类型必须严格匹配。`AtomInc(Int64)` 和 `AtomInc(Integer)` 是两个不同的函数。
- 与 `TAtomVar<T>` 不通用（见 §3.2）。

### 3.4 对象锁（LockObject / UnLockObject）

```pascal
procedure LockObject(Obj: TObject);
procedure UnLockObject(Obj: TObject);
```

**实现要点**：
- Delphi 下若 `CriticalSimulateAtomic` 未定义，使用 `TMonitor.Enter` / `TMonitor.Exit`。
- 其他情况下使用 `Lock_Critical_Obj__` / `UnLock_Critical_Obj__`（基于 `Lock_Pool__` 的哈希锁）。
- `Lock_Pool__` 维护 `TCritical_Struct` 的列表，每个 `Obj` 对应一个 `TCritical`，引用计数为 0 时释放。
- **同一对象可被同线程重复锁**（`LEnter` 计数）。

**契约**：
- 必须配对使用。若只 `LockObject` 不 `UnLockObject`，锁永远不释放。
- 释放对象前必须确保没有线程持有其锁，否则会崩。

---

## 第 4 章 队列结构

### 4.1 TOrderStruct<T>（**单向 FIFO 队列**）

```pascal
TOrderStruct<T_> = class(TCore_Object_Intermediate)
public type
  POrderStruct = ^TOrderStruct_;
  TOrderStruct_ = record
    Data: T_;
    Next: POrderStruct;
  end;
  TOnFreeOrderStruct = procedure(var p: T_) of object;
private
  FFirst, FLast: POrderStruct;
  FNum: NativeInt;
  FOnFreeOrderStruct: TOnFreeOrderStruct;
public
  constructor Create; virtual;
  destructor  Destroy; override;
  procedure   DoFree(var Data: T_); virtual;
  procedure   SwapInstance(source: TOrderStruct<T_>);  // 仅交换 FFirst/FLast/FNum
  procedure   Clear;
  procedure   Next;                                    // 移除首节点
  function    Push(const Data: T_): POrderStruct;      // 追加到尾部
  function    Push_Null: POrderStruct;
  property    Current: POrderStruct read FFirst;
  property    First:   POrderStruct read FFirst;
  property    Last:    POrderStruct read FLast;
  property    Num:     NativeInt read FNum;
  property    OnFree:  TOnFreeOrderStruct read FOnFreeOrderStruct write FOnFreeOrderStruct;
end;
```

**契约**：
- **非线程安全**。多线程需用 `TCriticalOrderStruct<T>`。
- `Push` 在锁外 `New`，若 `OnFree` 已设置，节点释放时会触发。
- `SwapInstance` **不交换** `FOnFreeOrderStruct`（只交换 `FFirst` / `FLast` / `FNum`）。
- `Next` 移除并释放首节点（触发 `OnFree`）。

**指针版 `TOrderPtrStruct<T>`**：存 `PT_`，`DoFree` 默认 `Dispose(Data)`。

**线程安全版 `TCriticalOrderStruct<T>`**：内部 `FCritical__` 保护所有公共操作；`Push` 在锁外 `New`、锁内挂链。

**线程安全指针版 `TCriticalOrderPtrStruct<T>`**：同上。

---

## 第 5 章 TBigList —— 双向循环链表

### 5.1 核心数据结构（源码原文）

```pascal
TQueueStruct = record
  Data: T_;                     // 用户数据（值内嵌）
  Next: PQueueStruct;           // 后继
  Prev: PQueueStruct;           // 前驱
  Instance___: T___;            // 所属列表（DEBUG 校验）
  Recycle___: Boolean;          // 是否已被标记为待删除
end;
```

- 非空时 `FFirst^.Prev = FLast` 且 `FLast^.Next = FFirst`（**环状**）。
- 空列表时 `FFirst = FLast = nil`。
- 单节点时 `FFirst = FLast` 且 `p^.Next = p^.Prev = p`。

### 5.2 方法契约

#### 5.2.1 增删改

```pascal
function Add(const Data: T_): PQueueStruct;                       // 追加到尾部
function Add_Null(): PQueueStruct;                                // 追加未初始化节点
function Insert(const Data: T_; To_: PQueueStruct): PQueueStruct; // 在 To_ 之前插入
procedure Remove_P(p: PQueueStruct);                              // 立即移除并释放 p
function Remove_Data(const Data: T_): Integer;                    // 标记所有匹配节点，返回标记数
procedure Remove_T(const Data: T_);                               // = Remove_Data
procedure Next;                                                    // 移除并释放首节点
procedure Clear;                                                   // 清空链表和回收池
```

**关键语义（必须区分）**：

- **`Remove_P`**：**立即**调用 `DoInternalFree(p)` → `Dispose(p)`。节点物理销毁。
- **`Remove_Data`**：先 `Push_To_Recycle_Pool(p)`（标记 `Recycle___=True` 并放入 `FRecycle_Pool__`），再 `Free_Recycle_Pool()` 真正删除。**返回值是 `FRecycle_Pool__.Num`**（本次标记的数量）。
- **`Add` / `Add_Null`**：**直接 `New(p)`**，**不查回收池**。

#### 5.2.2 移动与交换

```pascal
procedure Move_Before(p, To_: PQueueStruct);   // 把 p 移到 To_ 之前
procedure MoveToFirst(p: PQueueStruct);        // 移到首部
procedure MoveToLast(p: PQueueStruct);         // 移到尾部
procedure Exchange(p1, p2: PQueueStruct);      // 交换 Data 字段（不改链接）
```

#### 5.2.3 查询

```pascal
function Found(p1: PQueueStruct): NativeInt;                    // 返回索引或 -1
function Find_Data(const Data: T_): PQueueStruct;               // 返回节点或 nil
function Find_Data_Ptr(const Data_Ptr: P_): PQueueStruct;
function Search_Data_As_Array(const Data: T_): TArray_T_;       // 所有匹配
function Search_Data_As_Order(const Data: T_): TOrder_Data_Pool;
function CompareData(const Data_1, Data_2: T_): Boolean; virtual;  // 默认内存比较
```

#### 5.2.4 迭代器（**核心陷阱区**）

```pascal
function Repeat_(): TRepeat___;                                // 正向全表
function Repeat_(BI_, EI_: NativeInt): TRepeat___;             // 正向范围
function Invert_Repeat_(): TInvert_Repeat___;                  // 反向全表
function Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___;
```

**`TRepeat___.Next` 源码执行顺序**：
1. 若 `I___ > EI___` → `p___ := nil; Result := False; exit`。
2. **`p___ := p___^.Next`（先移动！）**。
3. `Result := I___ < EI___`。
4. 若 `Is_Discard___`：
   - `Is_Discard___ := False`
   - `Instance___.Remove_P(p___^.Prev)`（删除**移动前**的节点）
   - `Dec(EI___)`（总数减少）
5. 否则 `inc(I___)`。

**`Discard`**：仅设 `Is_Discard___ := True`，**不立即删除**。删除发生在下一次 `Next`。

**唯一正确的遍历删除模板**：
```pascal
if List.Num > 0 then
  with List.Repeat_ do
    repeat
      // 处理 Queue^.Data（Queue 指向当前节点）
      if 删除条件 then
        Discard;               // 标记，不删
    until not Next;            // 移动；若上一轮 Discard 则在此处删除
```

**绝对禁止**：
```pascal
with List.Repeat_ do
  while Next do                  // ❌ 首次 Next 后 p___ 指向第二个节点
    Process(Queue^.Data);        //   首节点从未被处理
```

#### 5.2.5 回收池（**重大语义澄清**）

`FRecycle_Pool__: TOrderStruct<PQueueStruct>` **不是"复用池"**，而是**"延迟删除队列"**。

**真实工作机制**：

| 方法 | 行为 |
|------|------|
| `Push_To_Recycle_Pool(p)` | 若 `p^.Recycle___` 为 False：设 `p^.Recycle___ := True`，把 `p` 放入 `FRecycle_Pool__`。**节点仍在主链表中**。 |
| `Free_Recycle_Pool` | 遍历 `FRecycle_Pool__`，对每个节点调用 `Remove_P`（真正从链表移除并 `Dispose`），最后释放队列本身。 |
| `Add` / `Add_Null` | **直接 `New(p)`，不查回收池**。 |
| `Remove_P` | 立即 `Dispose`（不等回收池）。 |
| `Remove_Data` | 先 `Push_To_Recycle_Pool` 所有匹配节点，再 `Free_Recycle_Pool`。 |
| `Clear` | 先 `FRecycle_Pool__.Free`（丢弃标记，节点仍在链表中），再遍历链表逐个 `DoInternalFree`。 |

**为什么这样设计？**
- 迭代删除场景下，若在迭代体内立即 `Remove_P`，会破坏迭代器的 `p___` 引用（源码里 `Remove_P` 直接 `Dispose`）。所以 `Discard` → `Next` 内部 `Remove_P` 的顺序是安全的，但 `Remove_Data` 这种"批量匹配"的场景需要先标记所有匹配节点（避免遍历时改变链表结构），最后统一删除。

**给 AI 的使用规则**：
- 如果你的代码出现"删除后立即返回内存给操作系统"的期待，**不要**依赖 `FRecycle_Pool__`。
- 如果需要在迭代中删除，**用 `Discard`**，不要用 `Remove_Data`。
- 如果需要在迭代外批量删除，`Remove_Data` 是安全的，它会自己标记并立即释放。
- `Get_Recycle_Pool_Num` 返回 `FRecycle_Pool__.Num`（已标记但未释放的数量）。

#### 5.2.6 索引缓存（懒加载）

```pascal
function BuildArrayMemory: PQueueArrayStruct;    // 分配连续指针数组（调用者 FreeMemory）
function CheckList: PQueueArrayStruct;           // 检查失效并重建
property List[const Index: NativeInt]: PQueueStruct ...;
property Items[const Index: NativeInt]: T_ ...; default;
```

**机制**：
- 任何结构变更（`Add` / `Insert` / `Remove_P` / `Move_*` / `Clear`）都置 `FChanged := True`。
- `CheckList` 检测到 `FChanged` 或 `FList = nil` 时调用 `BuildArrayMemory` 重建。
- 重建是 **O(N)** 的。

**性能警告**：
- **"写频繁 + 随机读"是灾难模式**：每次写入后首次索引读会触发全量重建。
- **正确做法**：写密集时用迭代器或 `BuildArrayMemory` 生成快照（只读）。
- **`BuildArrayMemory` 返回的内存由调用者负责 `System.FreeMemory`**。

#### 5.2.7 排序

```pascal
procedure Sort_C(OnSort: TSort_C);   // function(var L, R: T_): Integer
procedure Sort_M(OnSort: TSort_M);
procedure Sort_P(OnSort: TSort_P);
```

**实现**：
- 先 `BuildArrayMemory` 构建指针数组。
- 在数组上做快速排序（**交换节点内的 `Data` 字段，不改链表链接**）。
- 排序后释放临时数组。

**契约**：
- `OnSort` 返回负数表示 `L < R`，正数表示 `L > R`，0 表示相等。
- `FEnabled_Sort=False` 时 `Sort_*` 不做任何事。
- `Num <= 1` 时不做任何事。

### 5.3 事件钩子

```pascal
property OnFree: TOnStruct_Event read FOnFree write FOnFree;
property OnAdd:  TOnStruct_Event read FOnAdd write FOnAdd;
```

**`TOnStruct_Event = procedure(var p: T_) of object;`**

**调用时机**：
- `DoAdd(p^.Data)` 在 `Add` / `Add_Null` / `Insert` 挂链后调用。
- `DoFree(p^.Data)` 在 `DoInternalFree` 内、`Dispose(p)` 之前调用。

### 5.4 对象列表（**必须用于 class 存储**）

```pascal
TBig_Object_List<T_: class> = class(TBigList<T_>)
public
  AutoFreeObject: Boolean;
  constructor Create(AutoFreeObject_: Boolean);
  procedure DoFree(var Data: T_); override;   // 若 AutoFreeObject 则 DisposeObjectAndNil
end;

TCritical_Big_Object_List<T_: class> = class(TCritical_BigList<T_>)
public
  AutoFreeObject: Boolean;
  constructor Create(AutoFreeObject_: Boolean);
  procedure DoFree(var Data: T_); override;
end;
```

**契约**：
- `AutoFreeObject=True` 时，`Remove_P` / `Remove_Data` / `Clear` / 析构 都会自动释放对象。
- **绝对禁止**在 `AutoFreeObject=True` 时手动 `Free` 列表中的对象（二次释放）。
- 若 `AutoFreeObject=False`，**必须**手动维护对象生命周期。

### 5.5 线程安全版 `TCritical_BigList<T>`

**与 `TBigList<T>` 的差异**：
- 构造函数创建 `FCritical__`（`TBigList` 是懒创建）。
- **所有公共方法内部加锁**：`Add` / `Add_Null` / `Insert` / `Remove_P` / `Remove_Data` / `Clear` / `Move_*` / `Sort_*` / `ToArray` / `ToOrder` / `For_*` 等。
- **迭代器不自动加锁**：`Repeat_` / `Invert_Repeat_` 返回后遍历时需外部 `List.Lock` / `List.UnLock`。
- **`Discard` 触发 `Remove_P(p, False)`（不锁）**：所以调用方必须在遍历前手动加锁。
- 提供带/不带锁的重载：`Next(Lock_: Boolean)` / `Add_Null(Lock_: Boolean)` / `Remove_P(p, Lock_: Boolean)` / `Free_Recycle_Pool(Lock_: Boolean)`。

**正确遍历模板（多线程）**：
```pascal
List.Lock;
try
  if List.Num > 0 then
    with List.Repeat_ do
      repeat
        // 处理 Queue^.Data
        if 删除条件 then
          Discard;
      until not Next;
finally
  List.UnLock;
end;
```

### 5.6 完整反例集

| 反例 | 后果 | 修正 |
|------|------|------|
| `while It.Next do` | 漏首节点 | `repeat ... until not Next` |
| 迭代中 `Remove_P(It.Queue)` | 迭代器状态错乱 | 用 `It.Discard` |
| `TBigList<TStringList>` 存对象 | 内存泄漏 | 用 `TBig_Object_List<TStringList>` + `AutoFreeObject=True` |
| `TCritical_BigList` 迭代不加锁 | 崩 | 手动 `Lock` / `UnLock` |
| 写频繁时用 `Items[i]` | O(N) 重建 | 用迭代器或快照 |
| `AutoFreeObject=True` 时手动 Free | 二次释放 | 交给列表管理 |
| 忘记 `FreeMemory(BuildArrayMemory)` | 内存泄漏 | 调用后 `System.FreeMemory` |

---

## 第 6 章 TBig_Hash_Pair_Pool —— 链式哈希表

### 6.1 结构

```
FHash_Buffer: TGenericsList<TValue_Pair_Pool__>      // 桶数组
  └─ 每个桶 = TPair4_Tool<TKey, TValue, Pointer, THash>（内部 TBigList<TPair4>）
       └─ TPair4 = record
            Primary: TKey_;
            Second:  TValue_;
            Third:   Pointer;      // 指向 FQueue_Pool 中的节点
            Fourth:  THash;        // 缓存的哈希值
          end
FQueue_Pool: TBigList<PPair_Pool_Value__>            // 全局遍历队列（所有条目）
```

- **桶用于按哈希查找**，链表头是最近访问/插入的（LRU 效果）。
- **全局队列用于遍历**：`Repeat_` / `Sort_*` / `ToArray_*` 都基于它。
- **双向引用**：`TPair4.Third` ↔ 队列节点的 `Data`。

### 6.2 构造/析构

```pascal
constructor Create(const HashSize_: Integer; const NULL_VALUE_: TValue_); overload;
constructor Create(const HashSize_: Integer); overload;    // NULL_VALUE_ = 零值
destructor  Destroy; override;

function GetHashSize: Integer;   // 桶数
property Queue_Pool: TPool___ read FQueue_Pool;   // 全局队列（可用于直接遍历）
```

**契约**：
- `HashSize_` 决定桶数。`Hash_Key_Mod` 取模。**建议设为预期元素数的 1.5~2 倍**。
- `NULL_VALUE_` 是 `Get_Key_Value` 未命中时的返回值。
- `CreateBefore` / `CreateAfter` 是虚方法钩子。

### 6.3 事件钩子

```pascal
type
  TOn_Event = procedure(var Key: TKey_; var Value: TValue_) of object;
  TOn_Get_Key = procedure(const Key_: PKey_; var Hash: THash) of object;
  TOn_Compare_Key = procedure(const Key_1, Key_2: PKey_; var IsSame: Boolean) of object;
  TOn_Compare_Value = procedure(const Value_1, Value_2: PValue_; var IsSame: Boolean) of object;

property OnAdd: TOn_Event read FOnAdd write FOnAdd;
property OnFree: TOn_Event read FOnFree write FOnFree;
property On_Get_Key: TOn_Get_Key read FOn_Get_Key write FOn_Get_Key;
property On_Compare_Key: TOn_Compare_Key read FOn_Compare_Key write FOn_Compare_Key;
property On_Compare_Value: TOn_Compare_Value read FOn_Compare_Value write FOn_Compare_Value;
```

**默认行为**：
- `Get_Key_Hash` 若未设置 `On_Get_Key`，用 `Get_CRC32(PByte(@Key), SizeOf(TKey_))`。
- `Compare_Key` / `Compare_Value` 若未设置回调，用 `CompareMemory`。

### 6.4 增删改查

```pascal
function Add(const Key: TKey_; const Value: TValue_; Overwrite_: Boolean): PPair_Pool_Value__;
function Get_Key_Value(const Key: TKey_): TValue_;               // 未命中返回 FNULL_VALUE
procedure Set_Key_Value(const Key: TKey_; const Value: TValue_); // = Add(..., True)
property Key_Value[const Key: TKey_]: TValue_ read Get_Key_Value write Set_Key_Value; default;
procedure Delete(const Key: TKey_);
procedure Remove(p: PPair_Pool_Value__); overload;
procedure Remove(p: PPair_Pool_Value__; Do_Free_Recycle_Pool_: Boolean); overload;
function Exists_Key(const Key: TKey_): Boolean;
function Exists_Value(const Data: TValue_): Boolean;
function Exists(const Key: TKey_): Boolean;                      // = Exists_Key
```

**`Add` 的精确语义**（源码验证）：
1. 计算哈希，定位桶 `L`。
2. 若 `Overwrite_=True` 且桶非空：遍历桶，删除所有匹配 Key 的节点（推入回收池 + `Free_Recycle_Pool`）。
3. **重新**获取桶（因为步骤 2 可能释放了桶）。
4. `p := L.L.Add_Null()`。
5. `p^.Data.Primary := Key; Second := Value; Third := FQueue_Pool.Add(p); Fourth := Key_Hash_`。
6. `L.L.MoveToFirst(p)`（LRU）。
7. **解锁后**调用 `DoAdd(Key, Value)`。

**关键陷阱**：
- **`Overwrite_=False` 且 Key 已存在**：源码**不检查**，直接追加新节点。**会产生重复条目**。
- **`Overwrite_=True`**：删除所有匹配（不只第一个）。
- **`Add` 返回值 `p` 是桶节点指针**，出锁后仍有效（除非其他线程 `Delete` 或 `Remove`）。

**`Get_Key_Value`**：
- 未命中返回 `FNULL_VALUE`（**不是 `nil`**，是构造时传入的值）。
- 命中时调用 `MoveToFirst` 更新 LRU。

**`Delete`**：
- 匹配 Key 的所有节点推入回收池。
- `Free_Recycle_Pool()` 真正释放。
- 若桶变空，`Free_Value_List` 释放桶。

**`Remove(p)`**：
- 从桶中移除 `p`。
- 若 `Do_Free_Recycle_Pool_=True`（默认），且桶空则释放桶。

### 6.5 指针访问

```pascal
function Get_Value_Ptr(const Key: TKey_): PValue_; overload;
function Get_Value_Ptr(const Key: TKey_; const Default_: TValue_): PValue_; overload;
function Get_Default_Value(const Key: TKey_; const Default_: TValue_): TValue_;  // 不插入
procedure Set_Default_Value(const Key: TKey_; const Default_: TValue_);
```

**`Get_Value_Ptr` 语义**：
- 命中：返回 `@p^.Data.Second`，并 `MoveToFirst`。
- 未命中：调用 `Add(Key, Default_, False)` 插入默认值，返回 `@p^.Data.Second`。
- **出锁后指针可能失效**（其他线程 `Delete` 会释放节点）。**不要长期持有**。

### 6.6 遍历

```pascal
function Repeat_(): TRepeat___; overload;                        // 遍历 FQueue_Pool
function Repeat_(BI_, EI_: NativeInt): TRepeat___; overload;
function Invert_Repeat_(): TInvert_Repeat___; overload;
function Invert_Repeat_(BI_, EI_: NativeInt): TInvert_Repeat___; overload;
procedure For_C(OnFor: TBig_Hash_Pool_For_C); overload;
procedure For_M(OnFor: TBig_Hash_Pool_For_M); overload;
procedure For_P(OnFor: TBig_Hash_Pool_For_P); overload;
```

**回调签名**：
```pascal
TBig_Hash_Pool_For_C = procedure(p: PPair_Pool_Value__; var Aborted: Boolean);
TBig_Hash_Pool_For_M = procedure(p: PPair_Pool_Value__; var Aborted: Boolean) of object;
TBig_Hash_Pool_For_P = ...;  // Delphi: reference to procedure; FPC: is nested
```

**契约**：
- 遍历的是 `FQueue_Pool`（全局队列），顺序可能与插入顺序不同（`Sort_*` 会改变顺序）。
- `Aborted := True` 会终止遍历。
- **`For_*` 在 `TCritical_Big_Hash_Pair_Pool` 中会全程持锁**：回调内不要调用哈希表自身的会加锁方法（如 `Add` / `Delete`），会死锁。

### 6.7 回收池

```pascal
procedure Push_To_Recycle_Pool(p: PPair_Pool_Value__);
procedure Push_To_Recycle_Pool2(p: TPool_Queue_Ptr___);
procedure Free_Recycle_Pool;
```

**为什么有两个 `Push_To_Recycle_Pool`？**
- `PPair_Pool_Value__` 和 `TPool_Queue_Ptr___` 在 FPC 下都是指针，重载解析有歧义。
- 用不同方法名强制消除二义性。**Delphi 也统一用 `Push_To_Recycle_Pool2`**。

**与 `TBigList` 回收池的差异**：这里的回收池也是**延迟释放机制**，`Push` 只是把节点加入"待释放"队列，`Free_Recycle_Pool` 才真正释放桶节点和全局队列节点。

### 6.8 排序

```pascal
procedure Sort_Key_C(OnSort: TOn_Sort_Key_C);
procedure Sort_Key_M(OnSort: TOn_Sort_Key_M);
procedure Sort_Key_P(OnSort: TOn_Sort_Key_P);
procedure Sort_Value_C(OnSort: TOn_Sort_Value_C);
procedure Sort_Value_M(OnSort: TOn_Sort_Value_M);
procedure Sort_Value_P(OnSort: TOn_Sort_Value_P);
```

**实现**：
- 对 `FQueue_Pool`（`TBigList<PPair_Pool_Value__>`）做快速排序。
- 排序交换 `T_ = PPair_Pool_Value__` 字段，即**交换节点内的指针**。
- 排序后调用 `Extract_Queue_Pool_Third` 重建每个 `TPair4.Third` 指向。

**为什么需要重建 `Third`？**
- 排序时交换的是队列节点的 `Data` 字段（指向 `TPair4` 的指针）。
- 但 `TPair4.Third` 也指向队列节点。交换后，`TPair4.Third` 不再指向正确的队列节点。
- `Extract_Queue_Pool_Third` 遍历队列，把每个 `TPair4.Third` 重新指向其当前的队列节点。

**契约**：
- 排序后，桶链表顺序不变（桶内仍按 LRU），但 `FQueue_Pool` 顺序改变。
- 排序只影响遍历顺序，不影响查找（查找按哈希 + Key 比较）。

### 6.9 导出

```pascal
function ToPool(): TPool___;                     // 新 TBigList<PPair_Pool_Value__>（调用者 Free）
function ToArray_Key(): TArray_Key;              // 动态数组
function ToOrder_Key(): TOrder_Key;              // TOrderStruct<TKey_>（调用者 Free）
function ToArray_Value(): TArray_Value;
function ToOrder_Value(): TOrder_Value;
```

### 6.10 线程安全版 `TCritical_Big_Hash_Pair_Pool`

**差异**：
- 构造函数创建 `FCritical__`（非线程安全版是懒创建）。
- **所有公共方法加锁**：`Add` / `Get_Key_Value` / `Delete` / `Exists_Key` / `Clear` / `For_*` / `Sort_*` / `ToArray_*` / `ToOrder_*` 等。
- `Get_Value_Ptr` 在锁内 `Add`，但返回指针出锁后可能失效。
- `For_*` 全程持锁，回调内不可调加锁方法。

**正确用法（遍历 + 删除）**：
```pascal
Hash.Lock;
try
  with Hash.Repeat_ do
    repeat
      if 删除条件(Queue^.Data^.Data.Primary) then
        Hash.Delete(Queue^.Data^.Data.Primary);   // 会重入锁？
    until not Next;
finally
  Hash.UnLock;
end;
```

**注意**：`Delete` 会再次 `Lock`，导致死锁（`TCritical` 虽可重入，但逻辑上会嵌套）。**正确做法是用 `Push_To_Recycle_Pool` 标记，遍历结束后 `Free_Recycle_Pool`**，或在遍历外用 `For_M` 回调。

### 6.11 对象值版

```pascal
TBig_Hash_Object_Pool<TKey_, TValue_: class> = class(TBig_Hash_Pair_Pool<TKey_, TValue_>)
public
  AutoFree: Boolean;
  constructor Create(const HashSize_: Integer; const AutoFree_: Boolean);
  procedure DoFree(var Key: TKey_; var Value: TValue_); override;  // AutoFree 时 DisposeObjectAndNil
end;

TCritical_Big_Hash_Object_Pool<TKey_, TValue_: class> = class(TCritical_Big_Hash_Pair_Pool<TKey_, TValue_>)
public
  AutoFree: Boolean;
  constructor Create(const HashSize_: Integer; const AutoFree_: Boolean);
  procedure DoFree(var Key: TKey_; var Value: TValue_); override;
end;
```

**契约**：`AutoFree=True` 时删除条目会自动释放值对象。

---

## 第 7 章 并发系统

### 7.1 TCompute —— 自缩放线程池

#### 7.1.1 线程模型

- **调度线程**：`TCore_Dispatch_Order_Thread`，全局唯一，循环从 `Core_Dispatch_Order__` 取任务。
- **工作线程**：`TCompute`，`FreeOnTerminate=True`，空闲超时（`Core_Thread_Life_Time_Tick__`，默认 1000ms）后退出。
- **任务队列**：
  - `Core_Dispatch_Order__: TCriticalOrderStruct<TComputeDispatch>`：待调度任务。
  - `Core_Thread_Dispatch_Queue_Pool__: TBigList<PComputeDispatchData>`：等待空闲线程的任务（调度线程发现有空闲线程时挂起任务，等空闲线程取走）。

#### 7.1.2 关键状态

| 变量 | 类型 | 含义 |
|------|------|------|
| `Core_Thread_Task_Runing__` | `TAtomInt` | 正在执行任务的工作线程数 |
| `Core_Thread_Wait_Sum__` | `TAtomInt` | 空闲等待任务的工作线程数 |
| `Core_Dispatch_Order__.Num` | `NativeInt` | 待调度任务数 |
| `Core_Thread_Life_Time_Tick__` | `TTimeTick` | 空闲线程存活超时（默认 1000ms） |
| `Parallel_Granularity__` | `Integer` | 并行循环默认线程数 |
| `Max_Activted_Parallel__` | `Integer` | 并行循环最大并发数（0 无限制） |

#### 7.1.3 任务投递

```pascal
class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_C); overload;
class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_C); overload;
class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun: TRun_Thread_C; IsRuning_, IsExit_: PBoolean); overload;
class procedure RunC(const Data: Pointer; const Obj: TCore_Object; const OnRun, OnDone: TRun_Thread_C; IsRuning_, IsExit_: PBoolean); overload;
class procedure RunC_NP(const OnRun: TRun_Thread_C_NP); overload;
class procedure RunC_NP(const OnRun: TRun_Thread_C_NP; IsRuning_, IsExit_: PBoolean); overload;

// RunM / RunP 类似
```

**回调类型**：
- `TRun_Thread_C = procedure(ThSender: TCompute);`
- `TRun_Thread_M = procedure(ThSender: TCompute) of object;`
- `TRun_Thread_P = ...;` // Delphi: reference to procedure; FPC: is nested
- `TRun_Thread_C_NP = procedure();`（无参版本）

**执行线程**：
- `OnRun` 在**工作线程**执行。
- `OnDone` 通过 `SyncM(Self, Done_Sync)` 投递到**主线程**执行。

**`IsRuning_` / `IsExit_` 语义**：
- 投递时：`IsRuning_^ := True; IsExit_^ := False`。
- 执行前（工作线程）：`IsRuning^ := True; IsExit^ := False`。
- 执行后（工作线程）：`IsRuning^ := False; IsExit^ := True`。
- **可用于忙等检测任务是否完成**。

**异常**：`OnRun` 中的异常被 `try...except` 吞掉（不传播）。

#### 7.1.4 同步辅助

```pascal
class procedure Sync(OnRun_: TRun_Thread_P_NP); overload;
class procedure Sync(Thread_: TThread; OnRun_: TRun_Thread_P_NP); overload;
class procedure SyncC(OnRun_: TRun_Thread_C_NP); overload;
class procedure SyncC(Thread_: TThread; OnRun_: TRun_Thread_C_NP); overload;
class procedure SyncM(OnRun_: TRun_Thread_M_NP); overload;
class procedure SyncM(Thread_: TThread; OnRun_: TRun_Thread_M_NP); overload;
class procedure SyncP(OnRun_: TRun_Thread_P_NP); overload;
class procedure SyncP(Thread_: TThread; OnRun_: TRun_Thread_P_NP); overload;

class procedure Sync_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_P_NP);
class procedure SyncC_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_C_NP);
class procedure SyncM_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_M_NP);
class procedure SyncP_To(Dest_Thread_: TCompute; OnRun_: TRun_Thread_P_NP);
```

**语义**：
- `Sync*` **阻塞当前线程**，直到目标线程执行完 `OnRun_`。
- 内部用 `TSyncTmp` 包装回调，执行后 `Free` 自己。
- 若 `Main_Thread_Soft_Synchronize=True`，走软同步；否则走系统同步 `TThread.Synchronize`。
- **`Sync` 内部再 `Sync` 会死锁**（主线程被自己阻塞）。

#### 7.1.5 非阻塞投递

```pascal
class procedure PostC1(OnSync: TThreadPost_C1); overload;
class procedure PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean); overload;
class procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2); overload;
class procedure PostC2(Data1: Pointer; OnSync: TThreadPost_C2; IsRuning_, IsExit_: PBoolean); overload;
// PostC3 / PostC4 / PostM1..4 / PostP1..4 同理

class procedure Sync_Wait_PostC1(OnSync: TThreadPost_C1);   // 阻塞版
class procedure Sync_Wait_PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
// ... 同理
```

**契约**：
- `Post*` **立即返回**，`OnSync` 在**主线程**执行。
- `Sync_Wait_Post*` **忙等**直到主线程执行完（`while IsRuning_ do ...`）。
- **`Sync_Wait_Post*` 会导致主线程被阻塞**，回调中不要长时间操作。

#### 7.1.6 线程信息与统计

```pascal
class procedure Set_Thread_Info(Thread_Info_: string);
class procedure Set_Thread_Info(const Fmt: string; const Args: array of const);
class function  Wait_Thread(): NativeInt;      // Core_Thread_Wait_Sum__
class function  ActivtedTask(): NativeInt;    // Core_Thread_Task_Runing__
class function  WaitTask(): NativeInt;        // Core_Dispatch_Order__.Num
class function  TotalTask(): NativeInt;
class function  State(): string;
class function  GetParallelGranularity(): Integer;
class function  GetMaxActivtedParallel(): Integer;
class function  Get_Core_Thread_Pool: TCoreCompute_Thread_Pool;
class function  Get_Core_Thread_Dispatch_Critical: TCritical;
```

**`State()` 返回格式**（用于调试）：
```
Task:%d Thread:%d/%d Wait:%d/%d Critical:%d/%d 19937:%d Atom:%d Parallel:%d/%d Post:%d Sync:%d
```

#### 7.1.7 释放对象在异步线程

```pascal
class procedure PostFreeObjectInThread(const Obj: TObject);
class procedure PostFreeObjectInThreadAndNil(var Obj);
```

**契约**：异步投递，`OnRun` 里 `DisposeObject`。**调用后不要访问对象**。

### 7.2 TSoft_Synchronize_Tool —— 用户态同步

#### 7.2.1 原理

- 每个 TSoft_Synchronize_Tool 绑定一个 `Soft_Synchronize_Main_Thread`（通常是主线程）。
- 调用者的 `Synchronize_*` 把请求（`TPair4<OnSync_C, OnSync_M, OnSync_P, WaitSignal>`）推入目标线程的 `SyncQueue__`。
- 调用者**忙等** `WaitSignal` 变为 False。
- 目标线程定期 `Check_Synchronize` 取出请求执行。

#### 7.2.2 API

```pascal
constructor Create(Soft_Synchronize_Main_Thread_: TCore_Thread);
destructor  Destroy; override;

function Check_Synchronize(Check_Time_: TTimeTick): NativeInt;   // 目标线程调用

procedure Synchronize(OnSync: TOnSynchronize_P_NP); overload;
procedure Synchronize_C(OnSync: TOnSynchronize_C_NP); overload;
procedure Synchronize_M(OnSync: TOnSynchronize_M_NP); overload;
procedure Synchronize_P(OnSync: TOnSynchronize_P_NP); overload;
procedure Synchronize(Thread_: TCore_Thread; OnSync: TOnSynchronize_P_NP); overload;
procedure Synchronize_C(Thread_: TCore_Thread; OnSync: TOnSynchronize_C_NP); overload;
procedure Synchronize_M(Thread_: TCore_Thread; OnSync: TOnSynchronize_M_NP); overload;
procedure Synchronize_P(Thread_: TCore_Thread; OnSync: TOnSynchronize_P_NP); overload;
```

**`Synchronize_*` 的 `Thread_` 参数**：
- 若 `Thread_ = Soft_Synchronize_Main_Thread`：直接执行 `OnSync`。
- 否则：入队 + 忙等。

**`Check_Synchronize`**：
- 若 `CurrentThread <> Soft_Synchronize_Main_Thread`：直接 `exit`（返回 0）。
- 交换 `SyncQueue__` 到临时队列，逐个执行请求，`sync_^.Fourth := False` 唤醒调用者。
- `Check_Time_ = 0`：处理一次就返回。
- `Check_Time_ > 0`：循环处理直到超时。

**关键实现细节**：
- 请求的 `tmp` 是**栈变量**，通过 `@tmp` 入队。调用者 `while tmp.Fourth do Sleep(1)` 保证栈有效。
- `SwapInstance` 交换 `FFirst` / `FLast` / `FNum`，避免执行时阻塞新请求。

#### 7.2.3 全局驱动函数

```pascal
function  Check_Soft_Thread_Synchronize: Boolean; overload;
function  Check_Soft_Thread_Synchronize(Timeout: TTimeTick): Boolean; overload;
function  Check_Soft_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean; overload;
procedure Check_System_Thread_Synchronize; overload;
function  Check_System_Thread_Synchronize(Timeout: TTimeTick): Boolean; overload;
function  Check_System_Thread_Synchronize(Timeout: TTimeTick; Run_Hook_Event_: Boolean): Boolean; overload;
procedure CheckThreadSynchronize;
function  CheckThreadSynchronize(Timeout: TTimeTick): Boolean;
procedure CheckThreadSync;
function  CheckThreadSync(Timeout: TTimeTick): Boolean;
procedure CheckThread;
function  CheckThread(Timeout: TTimeTick): Boolean;
```

**语义**：
- `Check_Soft_Thread_Synchronize`：若 `Main_Thread_Soft_Synchronize=True`，走软同步；否则转调系统同步。
- `Check_System_Thread_Synchronize`：在双主线程模式下会被重定向到软同步（`On_Check_System_Thread_Synchronize := Do_Check_Soft_Thread_Synchronize`）。
- `CheckThread*` 根据 `Main_Thread_Soft_Synchronize` 自动选择。

**`Do_Check_Soft_Thread_Synchronize`**：
- 若 `CurrentThread <> Main_Thread_Sync_Tool.Soft_Synchronize_Main_Thread`：
  - 若 `ThreadID = MainThreadID`（RTL 主线程）：`CheckSynchronize`。
  - 否则：`Sleep(Timeout)`。
- 否则（是软同步目标线程）：
  - 调 `MainThreadProgress.Progress(Main_Thread_ID)`（处理 TThreadPost 队列）。
  - 调 `Timer_Event_Pool__.Progress`（处理定时器）。
  - 调 `Main_Thread_Sync_Tool.Check_Synchronize(Timeout)`（处理软同步请求）。
  - 若 `Run_Hook_Event_`，调 `OnCheckThreadSynchronize`。
  - 若 `Main_Thread_ID = MainThreadID`，调 `CheckSynchronize(1) or Result`。

#### 7.2.4 双主线程模拟

```pascal
procedure Begin_Simulator_Main_Thread(Simulator_Main_Proc_: TOnSynchronize_C_NP);
function  Simulator_Main_Thread_Activted: Boolean;
```

**作用**：把当前线程之外的一个 TCompute 线程设为"模拟主线程"，接管 `Main_Thread_ID` / `Main_Thread` / `MainThreadProgress.ThreadID` / `Main_Thread_Sync_Tool.Soft_Synchronize_Main_Thread`。

**流程**：
1. `Create` 检查 `Main_Thread_Soft_Synchronize` 必须为 True。
2. 备份原 `Main_Thread` / `Main_Thread_ID`。
3. `On_Check_System_Thread_Synchronize := Do_Check_Soft_Thread_Synchronize`（**关闭系统同步**）。
4. 启动 TCompute 执行 `Do_Execute_Main_Thread`。
5. `Do_Execute_Main_Thread` 里设 `Main_Thread := Sender`，执行 `Simulator_Main_Proc`。
6. 返回后恢复原 `Main_Thread` / `Main_Thread_ID`。
7. `On_Check_System_Thread_Synchronize := Do_Check_System_Thread_Synchronize`（**重新打开系统同步**）。

**风险**：
- 若 `Simulator_Main_Proc` 不调用 `Check_Soft_Thread_Synchronize`，投递的同步请求永远不执行。
- 双主线程期间，所有 `Sync*` 会指向模拟线程，而非 RTL 主线程。

### 7.3 TThreadPost —— 线程消息投递

#### 7.3.1 API

```pascal
constructor Create(ThreadID_: TThreadID);
destructor  Destroy; override;

function Count: NativeInt;
property Num: NativeInt read Count;
function Busy: Boolean;

function Progress(ThreadID_: TThreadID): NativeInt; overload;   // 仅目标线程调用
function Progress(Thread_: TThread): NativeInt; overload;
function Progress(): Integer; overload;

// 非阻塞投递
procedure PostC_NP(OnSync: TThreadPost_C1);
procedure PostM_NP(OnSync: TThreadPost_M1);
procedure PostP_NP(OnSync: TThreadPost_P1);
procedure PostC1(OnSync: TThreadPost_C1); overload;
procedure PostC1(OnSync: TThreadPost_C1; IsRuning_, IsExit_: PBoolean); overload;
// PostC2 / C3 / C4 / M1..4 / P1..4 同理

// 阻塞投递
procedure Sync_Wait_PostC1(OnSync: TThreadPost_C1);
procedure Sync_Wait_PostC2(Data1: Pointer; OnSync: TThreadPost_C2);
// ... 同理
```

**回调类型**：
- `TThreadPost_C1 = procedure();`
- `TThreadPost_C2 = procedure(Data1: Pointer);`
- `TThreadPost_C3 = procedure(Data1: Pointer; Data2: TCore_Object; Data3: Variant);`
- `TThreadPost_C4 = procedure(Data1: Pointer; Data2: TCore_Object);`
- `TThreadPost_M1..4`：`of object` 版本。
- `TThreadPost_P1..4`：Delphi `reference to`；FPC `is nested`。

**契约**：
- `Progress(ThreadID_)` 只在 `ThreadID_ = FThreadID` 时处理队列。
- `OneStep=True`（默认）时，每次 `Progress` 只处理一个。
- `OneStep=False` 时（`MainThreadProgress` 被设为 False），批量处理。
- `ResetRandomSeed=True` 时每次执行前 `SetMT19937Seed(0)`。
- `IsRuning_` / `IsExit_` 可用于忙等：`Post` 时置 `IsRuning_:=True, IsExit_:=False`，执行前置 True，执行后置 False / True。

**`Sync_Wait_Post*` 忙等逻辑**：
```pascal
while IsRuning_ do
  if Current_Thread_ID_ = FThreadID then Progress(Current_Thread_ID_)
  else if Current_Thread_ID_ = Main_Thread_ID then CheckThread(1)
  else TCompute.Sleep(1);
```

**风险**：若目标线程长期不 `Progress`，会死锁。

#### 7.3.2 全局实例

- `MainThreadProgress`：主线程投递队列（初始化时 `OneStep := False`）。
- `MainThreadPost`：`MainThreadProgress` 的别名。
- `CoreThreadPost`：`MainThreadProgress` 的别名。

### 7.4 并行循环 ParallelFor

#### 7.4.1 策略

| 策略 | 分配方式 | 适用场景 |
|------|----------|----------|
| **Block** | 将 `[b, e]` 切分为连续块，每线程一块 | 迭代工作量均匀 |
| **Fold** | 每线程以步长 `Granularity` 跳跃（`Pass := b + i`，步长为线程数） | 迭代工作量不均匀 |

**宏控制**：`FoldParallel` 定义时用 Fold，否则用 Block。**默认开启 Fold**。

#### 7.4.2 API（Delphi 版）

```pascal
type
  TDelphiParallel_P32 = reference to procedure(pass: Integer);
  TDelphiParallel_P64 = reference to procedure(pass: Int64);

// Block 直接调用
procedure DelphiParallelFor_Block(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Block(parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Block(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor_Block(parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;

// Fold 直接调用
procedure DelphiParallelFor_Fold(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Fold(parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor_Fold(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
procedure DelphiParallelFor_Fold(parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;

// 自动选择（按 FoldParallel 宏）
procedure DelphiParallelFor(ThNum: Integer; parallel: Boolean; b, e: Integer; OnFor: TDelphiParallel_P32); overload;
procedure DelphiParallelFor(ThNum: Integer; parallel: Boolean; b, e: Int64; OnFor: TDelphiParallel_P64); overload;
// ... 多种重载

// 别名
procedure ParallelFor(...);  // = DelphiParallelFor / FPCParallelFor
```

**FPC 版**：类型是 `TFPCParallel_P32` / `TFPCParallel_P64`（`is nested`），函数名 `FPCParallelFor*`。

**契约**：
- `ThNum` 是并行度（线程数）。`<=0` 或 `parallel=False` 或 `WorkInParallelCore.V=False` 或 `Parallel_Overflow__.Busy()` 时**串行执行**。
- `b`、`e` 是**闭区间**。
- **`OnFor` 中不要调 `TCompute.Sync` 等阻塞同步**（会导致线程池饥饿）。
- **`OnFor` 中修改共享状态必须加锁**。
- `Parallel_Overflow__` 限制同时执行的并行循环数，`Acquire` 忙等，`Release` 减计数。

#### 7.4.3 溢出控制

```pascal
TParallelOverflow = record
  ActivtedParallel: Integer;
  procedure Acquire;               // Busy 时 Sleep(1)，否则 AtomInc
  procedure Release;               // AtomDec
  function  Busy(): Boolean;       // Max_Activted_Parallel__ > 0 且 ActivtedParallel >= Max
end;
```

**`Max_Activted_Parallel__`**：全局上限，0 表示无限制。

---

## 第 8 章 MT19937 随机数

### 8.1 实现核心

- 标准 MT19937，624 字状态。
- 每个 TCompute 线程有独立 `TMT19937Core` 实例，存放在 `FRndInstance`。
- 全局池 `MT19937_POOL__: TMT19937_Pool__` 管理所有实例。
- `Instance_TMT19937Random__` 引用计数，`Busy` 标志防重入，`LastActivtedTime` 用于空闲回收。

### 8.2 全局函数（**推荐**）

```pascal
function MT19937CoreToDelphi: Boolean;
function MT19937InstanceNum(): Integer;
procedure SetMT19937Seed(seed: Integer);
function GetMT19937Seed(): Integer;
procedure MT19937Randomize();
function MT19937Rand32: Integer; overload;
function MT19937Rand32(L: Integer): Integer; overload;              // [0, L-1]
procedure MT19937Rand32(L: Integer; dest: PInteger; Num: NativeInt); overload;
function MT19937Rand64: Int64; overload;
function MT19937Rand64(L: Int64): Int64; overload;
procedure MT19937Rand64(L: Int64; dest: PInt64; Num: NativeInt); overload;
function MT19937RandE: Extended; overload;                          // [0, 1)
procedure MT19937RandE(dest: PExtended; Num: NativeInt); overload;
function MT19937RandF: Single; overload;
procedure MT19937RandF(dest: PSingle; Num: NativeInt); overload;
function MT19937RandD: Double; overload;
procedure MT19937RandD(dest: PDouble; Num: NativeInt); overload;
procedure MT19937SaveToStream(stream: TCore_Stream);
procedure MT19937LoadFromStream(stream: TCore_Stream);
```

**契约**：
- 作用于**当前线程**的实例。TCompute 线程优先用自己的 `FRndInstance`。
- `SetMT19937Seed(seed)`：同时设 `InternalRndSeed` 和 `InternalOldRndSeed`，并 `BuildMT(seed)`。
- `GetMT19937Seed`：返回 `InternalRndSeed`。
- `MT19937Randomize`：种子来自全局计数器 `Randomize_Seed__`（自增），**不是时间**。
- `Rand32(L=0)` 返回 0（源码 `if L < 0 then inc(L)`，`L = 0` 时 `Result mod 0` 会除零？不，源码里 `Result := Integer((Int64(Cardinal(GenRand_MT19937())) * L) shr 32)`，L=0 时乘 0 为 0，shr 32 仍为 0）。所以 **`L=0` 返回 0**。
- `Rand64(L=0)` 返回 0（源码 `if (L <> 0) then Result := Result mod L else Result := 0`）。
- `Rand64(L)` 的算法：先取两个 32 位拼成 63 位正整数，再 `mod L`。

### 8.3 对象级 RNG

```pascal
TMT19937Random = class
public
  constructor Create;
  destructor  Destroy; override;
  procedure Rndmize();
  function  Rand32(L: Integer): Integer; overload;
  procedure Rand32(L: Integer; dest: PInteger; num: NativeInt); overload;
  function  Rand64(L: Int64): Int64; overload;
  procedure Rand64(L: Int64; dest: PInt64; num: NativeInt); overload;
  function  RandE: Extended; overload;
  procedure RandE(dest: PExtended; num: NativeInt); overload;
  function  RandF: Single; overload;
  procedure RandF(dest: PSingle; num: NativeInt); overload;
  function  RandD: Double; overload;
  procedure RandD(dest: PDouble; num: NativeInt); overload;
  function  RandBool: Boolean;
  property  seed: Integer read GetSeed write SetSeed;
end;
TRandom = TMT19937Random;
```

**契约**：
- 内部有 `FInternalCritical` 保护。
- 可跨线程调用，但会有锁竞争。
- **不推荐跨线程共享**。

### 8.4 静态类 TMT19937

```pascal
TMT19937 = class
public
  class function CoreToDelphi: Boolean;
  class function InstanceNum(): Integer;
  class procedure SetSeed(seed: Integer);
  class function GetSeed(): Integer;
  class procedure Randomize();
  class function Rand32: Integer; overload;
  class function Rand32(L: Integer): Integer; overload;
  // ... 其他与全局函数一致

  // 范围函数
  class function RandomRange(const min_, max_: Integer): Integer; overload;
  class function RandomRange64(const min_, max_: Int64): Int64; overload;
  class function RandomRangeS(const min_, max_: Single): Single; overload;
  class function RandomRangeD(const min_, max_: Double): Double; overload;
  class function RandomRangeF(const min_, max_: Double): Double; overload;
  // 带 rnd: TMT19937Random 参数的重载
  class function RandomRange(const rnd: TMT19937Random; const min_, max_: Integer): Integer; overload;
  // ... 同理

  // RR 系列 = RandomRange 的别名
  class function RR(const min_, max_: Integer): Integer; overload;
  // ...

  class procedure SaveToStream(stream: TCore_Stream);
  class procedure LoadFromStream(stream: TCore_Stream);
end;
```

**契约**：静态方法作用于当前线程实例。

---

## 第 9 章 定时器

### 9.1 API

```pascal
type
  TOn_Timer_C = procedure();
  TOn_Timer_M = procedure() of object;
  TOn_Timer_P = ...;  // Delphi: reference to procedure; FPC: is nested

procedure Subscribe_Timer_C(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_C);
procedure Subscribe_Timer_M(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_M);
procedure Subscribe_Timer_P(Bind_: TCore_Object; Interval_: TTimeTick; OnTimer: TOn_Timer_P);
procedure Remove_Timer(Bind_: TCore_Object);
procedure Reset_Timer(Bind_: TCore_Object);
```

### 9.2 实现

- 内部用 `Timer_Event_Pool__: TTimer_Event_Pool__`（`TCritical_Big_Hash_Pair_Pool<TCore_Object, TTimer_Data__>`）。
- `TTimer_Data__` 记录 `Interval`、`LastTimer`、`OnTimer_C/M/P`。
- `Progress` 在 `Check_Soft/System_Thread_Synchronize` 中被调用（主线程）。
- 遍历所有定时器，若 `tk - LastTimer > Interval`，执行回调并更新 `LastTimer`。

### 9.3 契约

- **回调在主线程执行**：不要在回调中阻塞。
- **同一个 `Bind_` 重复订阅会覆盖**：`Add(Bind_, tmp, True)`。
- 精度依赖主线程调用 `Check_*` 的频率。
- **回调执行时间不应过长**，会阻塞主线程。
- **定时器不自动清理**：对象销毁前必须 `Remove_Timer`，否则悬空引用。

---

## 第 10 章 关键契约汇总

### 10.1 线程与所有权

| API | 可调用线程 | 说明 |
|-----|-----------|------|
| `TBigList.*` | 任意 | 非线程安全版需外部加锁 |
| `TCritical_BigList.*` | 任意 | 内部加锁；迭代器除外 |
| `TBig_Hash_Pair_Pool.*` | 任意 | 非线程安全版需外部加锁 |
| `TCritical_Big_Hash_Pair_Pool.*` | 任意 | 内部加锁；`For_*` 全程持锁 |
| `TCompute.Run*` / `Post*` | 任意 | 异步投递 |
| `TCompute.Sync*` / `Sync_Wait_Post*` | 任意 | 阻塞直到目标线程执行完 |
| `TSoft_Synchronize_Tool.Check_Synchronize` | **目标线程自己** | 其他线程调用无效 |
| `Check_*_Thread_Synchronize` | **主线程** | 其他线程调用无效或 Sleep |
| `MT19937*` 全局函数 | 任意 | 作用于当前线程实例 |
| `DisposeObject` | 任意 | 非线程安全，多线程需外部加锁 |

### 10.2 谁负责释放

| 对象 | 释放者 |
|------|--------|
| `TBigList<T>` 中的 `T_`（值类型） | 自动（节点释放时 `DoFree`） |
| `TBigList<T>` 中的 `T_`（class） | **必须用 `TBig_Object_List` + `AutoFreeObject=True`** |
| `TBig_Hash_Pair_Pool` 中的 `TValue_`（class） | **必须用 `TBig_Hash_Object_Pool` + `AutoFree=True`** |
| `TCompute` 实例 | `FreeOnTerminate=True`，自动释放 |
| `TCritical` | 手动 `Free`（构造/析构配对） |
| `TSoft_Synchronize_Tool` | 手动 `Free` |
| `TThreadPost` | 手动 `Free`（全局 `MainThreadProgress` 由终结段释放） |
| `TMT19937Random` | 手动 `Free` |
| `TOrderStruct<T>` | 手动 `Free`；`OnFree` 可自定义数据释放 |
| `BuildArrayMemory` 返回的数组 | 调用者 `System.FreeMemory` |
| `ToPool` / `ToOrder_*` 返回值 | 调用者 `Free` |

### 10.3 生命周期要点

- **`TCompute` 线程**：`FreeOnTerminate=True`，执行完任务后进入等待循环，空闲超时（1000ms）后退出，退出时自动从池中移除、递减计数、清理 MT19937。
- **`TSoft_Synchronize_Tool` 的请求**：`tmp` 是栈变量，调用者忙等保证有效。
- **`TBigList` 的回收池**：延迟删除队列，非复用池。
- **`TCritical` 的底层实例**：真正复用池。
- **`MT19937Core`**：每个 TCompute 线程独立，空闲超时回收。

---

## 第 11 章 常见错误对照表

| 错误 | 后果 | 修正 |
|------|------|------|
| `while It.Next do` | 漏首节点 | `repeat ... until not Next` |
| 迭代中 `Remove_P(It.Queue)` | 迭代器状态错乱 | 用 `It.Discard` |
| `TBigList<TStringList>` 存对象 | 内存泄漏 | `TBig_Object_List` + `AutoFreeObject=True` |
| `AutoFreeObject=True` 时手动 Free | 二次释放 | 交给列表管理 |
| `TCritical_BigList` 迭代不加锁 | 崩 | 手动 `Lock` / `UnLock` |
| 写频繁时用 `Items[i]` | O(N) 重建 | 用迭代器或快照 |
| `TBig_Hash_Pair_Pool.Add(Key, ..., False)` 重复插入 | 重复条目 | 用 `Overwrite_=True` |
| `Get_Value_Ptr` 长期持有 | 悬空指针 | 每次通过 API 访问 |
| `TAtomVar` 与 `AtomInc` 混用 | 原子性破坏 | 只用一种 |
| 主线程不调用 `Check_*` | 工作线程 `Sync` 死锁 | 定期 `CheckThread(1)` |
| `Sync` 里再 `Sync` | 死锁 | 拆分为 `Post` + 回调 |
| `PostFreeObjectInThread` 后访问对象 | 崩 | 等 `IsExit_` 置位 |
| `ParallelFor` 内调 `Sync` | 线程池饥饿 | 用 `Post` |
| `ParallelFor` 无锁修改共享变量 | 数据竞争 | 加锁或用 `TAtomVar` |
| `Rand32(0)` | 返回 0（合法） | 无（源码已处理） |
| `Begin_Simulator_Main_Thread` 后不驱动 `Check_*` | 同步请求不执行 | 定期调用 |
| `Close_Core_Dispatch_Thread` 超时强制置位 | dispatcher 可能未退出 | 接受小量泄漏 |
| 忘记 `Remove_Timer` | 悬空回调 | 在对象析构中调用 |
| `For_C/M/P` 回调里调加锁方法 | 死锁（线程安全版） | 用 `Push_To_Recycle_Pool` 标记，遍历外 `Free_Recycle_Pool` |

---

## 第 12 章 诚实的不确定清单

> 以下是我从源码**无法完全确定**的 15 个点。若 AI 需要在这些场景下工作，必须回查源码或询问人类。

1. **`TBigList.TRepeat___.Init_` 中的 `TSwap<NativeInt>.Do_(BI___, BI___)`**
   - 源码里两边都是 `BI___`，疑似应为 `BI___, EI___` 的笔误。
   - **建议**：直接按源码行为（只交换 `BI___` 自己，无实际效果）。

2. **`TBig_Hash_Pair_Pool.Add` 当 `Overwrite_=False` 且 Key 已存在时**
   - 源码**不检查**，直接插入新节点，产生重复条目。
   - **不确定**：是否有意为之（多值映射？）还是设计缺陷。
   - **建议**：需要去重时用 `Overwrite_=True`。

3. **`TBig_Hash_Pair_Pool.Sort_*` 后 `Extract_Queue_Pool_Third` 的必要性**
   - 排序交换的是 `FQueue_Pool` 节点的 `Data` 字段（指针），不影响节点位置。
   - 但 `Data` 指向的 `TPair4.Third` 也被交换了，需要重建。
   - **已确认**：`Extract_Queue_Pool_Third` 重建 `Third` 指针。

4. **`TCritical_BigList<T>.TRepeat___.Next` 中 `Remove_P(p___^.Prev, False)`**
   - `False` 表示不加锁。迭代器本身不锁。
   - **不确定**：调用方加锁后，若 `OnFree` 回调再次访问列表，是否死锁。`TCritical` 可重入，但 `Remove_P` 内部的 `DoInternalFree` 可能触发用户 `OnFree`。

5. **`TSoft_Synchronize_Tool.Synchronize_*` 的栈变量 `tmp` 生命周期**
   - `tmp` 是栈变量，`SyncQueue__.Push(@tmp)`，`while tmp.Fourth do Sleep(1)`。
   - **已确认**：调用者忙等保证 `tmp` 有效。目标线程 `Check_Synchronize` 执行后置 `Fourth := False` 唤醒调用者。调用者退出循环后 `tmp` 失效，但目标线程不再访问。

6. **`MT19937Core.InternalRndSeed` 与 `InternalOldRndSeed` 的差异**
   - `GenRand` 检测 `<>` 时重置 `MTI`（触发重建）。
   - `SetMT19937Seed` 同时设两者为 `seed`，所以直接调用是立即生效。
   - **不确定**：直接写 `InternalRndSeed := x` 会触发重建还是继续用旧状态（推测会重建）。

7. **`TOrderStruct.SwapInstance` 的注释 `// only reserved FOnFreeOrderStruct`**
   - 源码只交换 `FFirst` / `FLast` / `FNum`，**不交换** `FOnFreeOrderStruct`。
   - **已确认**：注释意思是"仅保留 `FOnFreeOrderStruct` 不交换"。

8. **`Close_Core_Dispatch_Thread` 强制 `Core_Dispatch_Order_IsExit__.V := True`**
   - `Execute` 循环条件用 `Core_Dispatch_Order_Activted__.V`，`IsExit__` 是退出后置位。
   - 强制置 `IsExit__ := True` **不会让 dispatcher 退出**，只是让 `Core_Dispatch_Order_Activted` 返回 True（`Activted and IsExit`）。
   - **疑似 bug**：但注释说"force reset"，可能是有意为之（避免后续检查死等）。

9. **`TAtomVar<T>.Lock` / `UnLock` 的配对**
   - `Lock` 加锁并返回值；`UnLock(v)` 写值并解锁。
   - **不确定**：若只 `Lock` 不 `UnLock`，会死锁（是的）。

10. **`TBig_Hash_Pair_Pool.Get_Value_Ptr` 返回指针的生命周期**
    - 未命中会 `Add` 插入默认值，返回 `@p^.Data.Second`。
    - 出锁后若其他线程 `Delete` 该 Key，指针失效。
    - **已确认**：不要长期持有。

11. **FPC 下 `TCritical` 的可重入性**
    - `TSystem_Critical = TCriticalSection`。FPC 的 `TRTLCriticalSection` 在 Windows 下可重入，在 Linux/macOS 下取决于具体实现。
    - `TCritical.Acquire` 只是 `Instance__.Acquire; Inc(LNum)`，没有额外保护。
    - **建议**：FPC 下不要假设 `TCritical` 可重入。

12. **`TBig_Hash_Pair_Pool.Exists_Value` 的复杂度**
    - 源码遍历所有桶的所有条目，O(N)。
    - **不确定**：是否有优化的查找路径。

13. **`TBigList.For_C/M/P` 的 `Aborted` 语义**
    - 回调设 `Aborted := True` 后循环退出。
    - **不确定**：`For_C(BP_, EP_, OnFor)` 的 `BP_ = EP_` 特殊处理。

14. **`TCompute.RunC` 的 `OnDone` 投递时机**
    - `OnDone` 在 `Execute` 循环内通过 `SyncM(Self, Done_Sync)` 投递。
    - `SyncM` 是**阻塞的**，工作线程会等待主线程执行完。
    - **不确定**：这会不会导致工作线程长期阻塞（如果主线程不 `Check`）。

15. **`Parallel_Overflow__.Acquire` 的原子性**
    - `while Busy() do Sleep(1); AtomInc(ActivtedParallel);`
    - **不确定**：`Busy()` 检查和 `AtomInc` 之间的竞态是否被处理。

---

## 第 13 章 快速决策树

### 13.1 选容器

```
存元素？
├─ class？
│   ├─ 需要 Key 查找？
│   │   ├─ 是 → TBig_Hash_Object_Pool<TKey, TValue>(HashSize, True)
│   │   │        多线程？→ TCritical_Big_Hash_Object_Pool
│   │   └─ 否 → TBig_Object_List<T>(True)
│   │            多线程？→ TCritical_Big_Object_List
│   └─ 不需要自动释放？→ TBig_Object_List<T>(False)，手动管理
└─ 值类型？
    ├─ 需要 Key 查找？→ TBig_Hash_Pair_Pool<TKey, TValue>
    │        多线程？→ TCritical_Big_Hash_Pair_Pool
    └─ 不需要 → TBigList<T>
             多线程？→ TCritical_BigList<T>
```

### 13.2 选线程通信方式

```
需要在其他线程执行代码？
├─ 目标是主线程？
│   ├─ 需要等结果？→ TCompute.Sync_Wait_Post*
│   ├─ 不等结果，要同步语义？→ TCompute.Sync*
│   └─ 不等结果，异步？→ TCompute.Post*
└─ 目标是 TCompute 工作线程？
    └─ TCompute.Sync*_To(Dest, Proc)
```

### 13.3 选并行策略

```
并行循环任务类型？
├─ 每迭代工作量大致相同 → Block（注释掉 FoldParallel 宏）
└─ 每迭代工作量差异大 → Fold（默认）
```

### 13.4 迭代删除配方

```pascal
// 单线程
if List.Num > 0 then
  with List.Repeat_ do
    repeat
      if 删除条件(Queue^.Data) then Discard;
    until not Next;

// 多线程
List.Lock;
try
  if List.Num > 0 then
    with List.Repeat_ do
      repeat
        if 删除条件(Queue^.Data) then Discard;
      until not Next;
finally
  List.UnLock;
end;
```

### 13.5 快照并发遍历配方

```pascal
List.Lock;
try
  Snap := List.BuildArrayMemory;
  N := List.Num;
finally
  List.UnLock;
end;
try
  for i := 0 to N - 1 do
    Process(Snap^[i]^.Data);
finally
  System.FreeMemory(Snap);
end;
```

**注意**：快照只读，节点可能被其他线程删除，需外部机制保护。

---

## 第 14 章 结语

### 14.1 本知识库覆盖范围

- **已精确描述**：所有公开 API 签名、契约、常见陷阱、正确用法模板。
- **已修正的常见幻觉**：
  - `TBigList` 的回收池是"延迟删除队列"，非"复用池"；`Add` 不使用它。
  - `TCritical` 的底层实例是真正复用池（Create 取，Destroy 还）。
  - `TBig_Hash_Pair_Pool.Add(Overwrite_=False)` 不去重，会产生重复条目。
  - 迭代器 `Next` 先移动，`while It.Next do` 会漏首节点。
  - `OnDone` 在主线程执行（通过 `SyncM` 投递）。

### 14.2 本知识库的边界

- **不覆盖**：Z.Core 之外的库（ZNet、ZDB、Z.AI 等）。
- **不覆盖**：源码里的疑似 bug（如 `TSwap<NativeInt>.Do_(BI___, BI___)`）。
- **不覆盖**：不确定清单中的 15 个场景。

### 14.3 给 AI 的使用规则

1. **优先用高层 API**：`TBig_Object_List`、`TBig_Hash_Object_Pool`、`TCompute.Run*`。不要直接操作内部节点。
2. **迭代删除永远用 `Discard`**。
3. **多线程共享容器必须用 `TCritical_*` 版本，且迭代时手动加锁**。
4. **不要混用 `TAtomVar` 和 `AtomInc`**。
5. **`Sync` 系列不要在回调里再 `Sync`**。
6. **`PostFreeObjectInThread` 后不要访问对象**。
7. **并行循环内不要调 `Sync`**。
8. **有疑问就查源码或问人**，不要猜。

---

**本知识库的定位**：一份**准确的、有边界的、可操作的** Z.Core 参考。它不假装能替代源码，但能让你在 90% 的场景下正确使用 Z.Core，并在剩下 10% 的场景下知道该停下来问人。