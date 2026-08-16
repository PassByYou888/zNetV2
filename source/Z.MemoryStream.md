# Z.MemoryStream 完全使用指南：高性能64位内存流与压缩库

`Z.MemoryStream` 是 Z‑framework 中用于**高性能内存数据管理**的核心单元。它提供了两个主要的流类：`TMS64`（继承自 `TCore_Stream`）和 `TMem64`（独立对象），两者都支持 **64 位寻址**（可处理 >2GB 数据）、**Delta 增量扩容**、**零拷贝内存映射**、**保护模式**（只读映射），并集成了 **LZ4**、**Snappy** 和 **ZLIB** 压缩/解压缩，以及丰富的**序列化方法**（基本类型、字符串、MD5 等）。本指南将带你全面掌握这个强大的内存流工具，无论你是处理网络数据、文件缓存，还是构建高性能二进制协议，都能找到最佳实践。

---

## 1. 为什么需要 TMS64 / TMem64？

在 Delphi / FPC 中，标准 `TMemoryStream` 有以下局限：
- **32 位大小限制**（最大 2GB）。
- **扩容策略简单**（每次倍增，可能浪费内存）。
- **缺乏内置压缩**和**零拷贝映射**。
- **不支持只读保护模式**（无法安全地映射外部缓冲区）。

`TMS64` 和 `TMem64` 针对这些问题提供了：
- **64 位容量**（`NativeUInt` / `Int64` 大小）。
- **Delta 增量扩容**（可自定义增长步长，减少重分配）。
- **`Mapping` 方法**：将流映射到已存在的内存块（只读或读写），实现零拷贝。
- **`ProtectedMode`**：标记为只读，防止意外修改。
- **内置 LZ4 / Snappy / ZLIB 压缩**，并支持并行压缩/解压。
- **完整的序列化 API**：直接读写整数、浮点、字符串、MD5。
- **与 `TMem64` 互换**：两种类可相互映射、交换，适应不同继承需求。

---

## 2. 核心类对比

| 特性 | `TMS64` | `TMem64` |
|------|---------|----------|
| **继承** | `TCore_Stream`（即 `TStream`） | `TCore_Object_Intermediate`（独立对象） |
| **兼容性** | 可直接用于 `TStream` 参数 | 需转换（提供 `Stream64` 方法） |
| **位置/大小类型** | `NativeUInt`（无符号） | `Int64`（有符号） |
| **主要用途** | 替代 `TMemoryStream`，与现有流接口协同 | 作为独立内存缓冲区，轻量级，适合频繁交换 |
| **相互转换** | `Mem64` 方法返回 `TMem64` | `Stream64` 方法返回 `TMS64` |
| **映射实例** | `Create_Mapping_Instance` | `Create_Mapping_Instance` |

**选择建议**：
- 如果你的代码需要 `TStream` 接口（如很多 RTL 函数），使用 `TMS64`。
- 如果只需要纯粹的内存缓冲区，并且不想受 `TStream` 限制，使用 `TMem64`。

---

## 3. 基本操作

### 3.1 创建与销毁
```pascal
var
  ms: TMS64;
begin
  ms := TMS64.Create;                 // 默认 Delta = 256
  // 或自定义 Delta（增长步长，范围 64~1MB）
  ms := TMS64.CustomCreate(1024);     // 每次扩容至少 1KB
  ...
  ms.Free;
end;
```
对于 `TMem64` 用法相同。

### 3.2 写入数据
```pascal
var
  buf: array[0..99] of Byte;
  s: string;
begin
  // 写入原始字节
  ms.WriteBuffer(buf, SizeOf(buf));   // 继承自 TStream
  // 或使用 Write64（64位计数）
  ms.Write64(buf, Length(buf));
  // 写入字符串（自动 UTF-8）
  ms.WriteString('Hello');
  // 写入基本类型
  ms.WriteInt32(12345);
  ms.WriteDouble(3.14);
  ms.WriteBool(True);
end;
```

### 3.3 读取数据
```pascal
var
  val: Integer;
  d: Double;
  s: TPascalString;
begin
  ms.Position := 0;
  val := ms.ReadInt32;
  d := ms.ReadDouble;
  s := ms.ReadString;  // 自动解码 UTF-8
  // 读取原始字节
  ms.ReadBuffer(buf, SizeOf(buf));
end;
```

### 3.4 定位与大小
```pascal
ms.Size := 1024;               // 设置大小（会扩容）
ms.Position := 100;            // 当前位置
var pos: Int64;
pos := ms.Seek(0, soFromEnd);  // 移到末尾
ms.Seek(-10, soCurrent);       // 相对当前位置后退10字节
```

### 3.5 清空与重置
```pascal
ms.Clear;        // 释放内存，Size=0，Position=0
ms.DiscardMemory; // 仅丢弃内部指针（不释放内存，谨慎使用）
```

---

## 4. 高级内存管理

### 4.1 保护模式（只读映射）
将流映射到外部内存块，且禁止写入/扩容。常用于解析网络包或只读文件映射。

```pascal
var
  data: TBytes;
  ms: TMS64;
begin
  data := TFile.ReadAllBytes('file.bin');
  ms := TMS64.Create;
  ms.Mapping(@data[0], Length(data));   // 此时 ms.ProtectedMode = True
  // 可以读取，但不能写入或调整大小
  val := ms.ReadInt32;
  // ms.WriteInt32(0);   // 会失败（保护模式）
  ms.Free;
end;
```

### 4.2 内存交换（SwapInstance）
高效地交换两个流的内容（O(1)），常用于“移动”大块数据而不复制。

```pascal
var
  a, b: TMS64;
begin
  a := TMS64.Create;
  b := TMS64.Create;
  a.WriteString('Data in A');
  b.WriteString('Data in B');
  a.SwapInstance(b);        // 现在 a 包含 'Data in B'，b 包含 'Data in A'
  a.Free;
  b.Free;
end;
```

### 4.3 克隆与映射实例
- **`NewClone`**：深拷贝整个流数据。
- **`Create_Mapping_Instance`**：创建一个新的 `TMS64` 实例，**共享同一块内存**（零拷贝），但不会自动释放原内存，需要手动管理。

```pascal
var
  orig, clone, mapped: TMS64;
begin
  orig := TMS64.Create;
  orig.WriteString('Original');
  clone := orig.NewClone;               // 独立副本
  mapped := orig.Create_Mapping_Instance; // 共享内存（只读）
  // 修改 orig 会影响 mapped，但不会影响 clone
  orig.Clear;
  // mapped 仍指向原内存（已释放？危险！应确保原内存有效）
  // 正确用法：在映射期间不要释放原流
  mapped.Free;
  clone.Free;
  orig.Free;
end;
```

### 4.4 与 TMem64 互转
```pascal
var
  ms: TMS64;
  mem: TMem64;
begin
  ms := TMS64.Create;
  ms.WriteString('Hello');
  mem := ms.Mem64;            // 获取映射的 TMem64
  // 或通过 SwapInstance 交换内容
  mem.SwapInstance(ms);       // 现在 mem 拥有数据，ms 变空
  mem.Free;
end;
```

---

## 5. 压缩与解压缩

### 5.1 内置快速压缩：LZ4 和 Snappy
`TMS64` / `TMem64` 直接提供 `LZ4`、`UnLZ4`、`Snappy_Pas`、`UnSnappy_Pas` 方法，方便压缩/解压流内容。

```pascal
var
  src, compressed, decompressed: TMS64;
begin
  src := TMS64.Create;
  src.WriteString('This is some text to compress...');
  // 压缩
  compressed := src.LZ4;        // 或 src.Snappy_Pas
  // 解压
  decompressed := compressed.UnLZ4; // 或 UnSnappy_Pas
  // 验证
  if src.ToBytes = decompressed.ToBytes then ...
  src.Free; compressed.Free; decompressed.Free;
end;
```
**输出格式**：`[OriginalSize: Int64] [CompressedSize: Int64] [CompressedData]`，可以安全存储或传输。

### 5.2 ZLIB 压缩（标准流接口）
使用全局函数 `CompressStream`、`DecompressStream`、`MaxCompressStream`、`FastCompressStream` 对任意 `TCore_Stream` 进行压缩/解压。

```pascal
var
  sour, dest: TMS64;
begin
  sour := TMS64.Create;
  sour.WriteString('Data');
  dest := TMS64.Create;
  CompressStream(sour, dest);   // dest 包含压缩数据
  dest.Position := 0;
  sour.Clear;
  DecompressStream(dest, sour); // 恢复原始数据
  sour.Free; dest.Free;
end;
```

### 5.3 自动选择压缩算法（SelectCompressStream）
`SelectCompressStream` 在输出流开头写入一个 `Byte` 标识压缩方法，`SelectDecompressStream` 能自动识别并解压。

```pascal
var
  sour, dest: TMS64;
begin
  sour := TMS64.Create;
  sour.WriteString('Data');
  dest := TMS64.Create;
  SelectCompressStream(scmLZ4, sour, dest); // 可选用 scmZLIB, scmSnappy_Pas 等
  // 解压时自动检测
  SelectDecompressStream(dest, sour);
end;
```

### 5.4 并行压缩/解压
对于大型数据，可以使用 `ParallelCompressMemory` 和 `ParallelDecompressStream` 利用多核加速。

```pascal
var
  sour, dest: TMS64;
begin
  sour := TMS64.Create;
  // 填充大量数据...
  dest := TMS64.Create;
  // 使用 4 线程，分片数自动计算
  ParallelCompressMemory(scmZLIB, sour, dest);
  // 解压
  sour.Clear;
  ParallelDecompressStream(dest, sour);
end;
```

---

## 6. 序列化支持

### 6.1 基本类型读写
| 方法 | 类型 |
|------|------|
| `WriteBool` / `ReadBool` | `Boolean` |
| `WriteInt8` / `ReadInt8` | `ShortInt` |
| `WriteInt16` / `ReadInt16` | `SmallInt` |
| `WriteInt32` / `ReadInt32` | `Integer` |
| `WriteInt64` / `ReadInt64` | `Int64` |
| `WriteInt128` / `ReadInt128` | `Int128` |
| `WriteUInt8` / `ReadUInt8` | `Byte` |
| `WriteUInt16` / `ReadUInt16` | `Word` |
| `WriteUInt32` / `ReadUInt32` | `Cardinal` |
| `WriteUInt64` / `ReadUInt64` | `UInt64` |
| `WriteUInt128` / `ReadUInt128` | `UInt128` |
| `WriteSingle` / `ReadSingle` | `Single` |
| `WriteDouble` / `ReadDouble` | `Double` |
| `WriteCurrency` / `ReadCurrency` | `Currency` |
| `WriteMD5` / `ReadMD5` | `TMD5` |

### 6.2 字符串读写
- `WriteString(const buff: TPascalString)`：先写入长度（UInt32），再写入 UTF-8 字节。
- `ReadString: TPascalString`：读取长度和 UTF-8 数据，返回字符串。
- `ReadStringAsBuff: TBytes`：仅读取原始字节（不解码）。
- `IgnoreReadString`：跳过字符串（不读取内容）。

### 6.3 流式序列化辅助（全局函数）
这些函数直接操作 `TCore_Stream`，适用于任何流类型（不仅限于 `TMS64`）：

- `StreamWriteBool`, `StreamReadBool`
- `StreamWriteInt32`, `StreamReadInt32`
- `StreamWriteString`, `StreamReadString`
- `StreamWriteMD5`, `StreamReadMD5`
- 等等（见单元接口）。

---

## 7. 实用工具

### 7.1 转为字节数组
```pascal
var
  bytes: TBytes;
begin
  bytes := ms.ToBytes;  // 复制数据到新 TBytes
end;
```

### 7.2 计算 MD5
```pascal
var
  md5: TMD5;
begin
  md5 := ms.ToMD5;   // 对全部内容计算 MD5
end;
```

### 7.3 文件操作
```pascal
ms.LoadFromFile('data.bin');   // 从文件加载
ms.SaveToFile('out.bin');      // 保存到文件
```

### 7.4 从其他流复制
```pascal
ms.CopyFrom(otherStream, -1);   // 复制全部内容
ms.CopyFrom(otherStream, 100);  // 复制 100 字节
```

---

## 8. 列表管理与线程安全

`TMemoryStream64List` 和 `TMemoryStream64ThreadList` 提供对 `TMS64` 对象的集合管理，后者是线程安全的（使用 `TCritical`）。

```pascal
var
  list: TMemoryStream64ThreadList;
begin
  list := TMemoryStream64ThreadList.Create;
  list.AutoFree_Stream := True;   // 删除时自动释放流
  list.Lock;
  try
    list.Add(TMS64.Create);
    // ...
  finally
    list.UnLock;
  end;
  list.Clean;  // 释放所有流并清空
  list.Free;
end;
```

---

## 9. 读写触发器（接口通知）

当你需要监控流读写操作时，可以实现 `IMemoryStream64WriteTrigger`、`IMemoryStream64ReadTrigger` 或 `IMemoryStream64ReadWriteTrigger` 接口，并创建对应的触发类（`TMemoryStream64OfWriteTrigger` 等）。每次 `Write64` 或 `Read64` 会调用接口方法。

```pascal
type
  TMyTrigger = class(TInterfacedObject, IMemoryStream64WriteTrigger)
    procedure TriggerWrite64(Count: Int64);
  end;

procedure TMyTrigger.TriggerWrite64(Count: Int64);
begin
  DoStatus('Written %d bytes', [Count]);
end;

var
  trig: TMyTrigger;
  ms: TMS64;
begin
  trig := TMyTrigger.Create;
  ms := TMemoryStream64OfWriteTrigger.Create(trig);
  ms.WriteString('Test'); // 会触发 TriggerWrite64
  ms.Free;
end;
```

---

## 10. 完整示例：压缩工具

下面是一个完整的控制台程序，演示如何压缩和解压文件，支持 LZ4 和 ZLIB。

```pascal
program CompressDemo;

{$APPTYPE CONSOLE}

uses
  SysUtils, Z.Core, Z.MemoryStream, Z.UnicodeMixedLib;

procedure CompressFile(const InFile, OutFile: string; UseLZ4: Boolean);
var
  msIn, msOut: TMS64;
begin
  msIn := TMS64.Create;
  msOut := TMS64.Create;
  try
    msIn.LoadFromFile(InFile);
    if UseLZ4 then
      msOut := msIn.LZ4
    else
      SelectCompressStream(scmZLIB, msIn, msOut);
    msOut.SaveToFile(OutFile);
    WriteLn(Format('Compressed %s -> %s (%.2f%%)',
      [InFile, OutFile, (msOut.Size / msIn.Size) * 100]));
  finally
    msIn.Free;
    msOut.Free;
  end;
end;

procedure DecompressFile(const InFile, OutFile: string);
var
  msIn, msOut: TMS64;
begin
  msIn := TMS64.Create;
  msOut := TMS64.Create;
  try
    msIn.LoadFromFile(InFile);
    // 自动检测压缩类型
    if not SelectDecompressStream(msIn, msOut) then
      raise Exception.Create('Decompression failed');
    msOut.SaveToFile(OutFile);
    WriteLn('Decompressed to ' + OutFile);
  finally
    msIn.Free;
    msOut.Free;
  end;
end;

var
  InFile, OutFile: string;
begin
  if ParamCount < 2 then
  begin
    WriteLn('Usage: CompressDemo <input> <output>');
    Halt(1);
  end;
  InFile := ParamStr(1);
  OutFile := ParamStr(2);
  CompressFile(InFile, OutFile, True);  // 使用 LZ4
  // 解压测试
  DecompressFile(OutFile, OutFile + '.decomp');
end.
```

---

## 11. 性能与最佳实践

1. **选择合适的 Delta**：如果预知数据大小，设置较大的 Delta（如 1MB）可减少扩容次数。默认 256 适用于大多数情况。
2. **优先使用映射而非复制**：当需要只读访问外部数据时，使用 `Mapping` 可避免额外的内存分配和复制。
3. **压缩算法选择**：
   - **LZ4**：速度极快，压缩率适中，适合实时压缩。
   - **Snappy**：类似 LZ4，Google 常用。
   - **ZLIB**：压缩率高（尤其 `clMax`），但速度较慢，适合存储。
4. **并行压缩**：对于超过 10MB 的数据，使用 `ParallelCompressMemory` 可显著提升速度。
5. **保护模式**：映射外部缓冲区后，不要释放原缓冲区，直到流被销毁。
6. **内存释放**：务必调用 `Free` 释放流；若使用 `Create_Mapping_Instance`，共享内存由原始流管理，不要重复释放。
7. **线程安全**：`TMS64` / `TMem64` 本身不是线程安全的，多线程操作需要外部加锁。

---

## 12. 总结

`Z.MemoryStream` 提供了完整的现代内存流解决方案，覆盖了从基础读写到高级压缩、映射、序列化的所有需求。它设计精巧，性能优异，与 Z‑framework 其他单元无缝集成，是处理二进制数据的首选工具。掌握它，你将能够高效地处理网络数据包、文件缓存、数据库 Blob 以及任何需要灵活内存操作的场景。

本指南涵盖了绝大多数常用功能，更深入的用法（如自定义压缩算法、触发器链式操作）可参考单元源码和 Z‑framework 的其他文档。
