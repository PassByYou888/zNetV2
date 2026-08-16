# jemalloc4p — Pascal 内存管理器绑定 (jemalloc)

## 1. 概述

**jemalloc4p** 是一个 Pascal 单元，它将 **jemalloc** 高性能内存分配器集成到 Delphi 和 Free Pascal (FPC) 项目中。该单元通过替换默认的内存管理器（`GetMem`、`FreeMem`、`ReallocMem` 等），使所有内存分配操作都转为使用 jemalloc，从而获得更好的多线程扩展性和更低的内存碎片。

jemalloc 是由 Jason Evans 最初为 FreeBSD 开发的内存分配库，现已成为业界广泛使用的标准组件，被应用于：
- **Firefox** 浏览器
- **Redis** 数据库
- **Rust** 编程语言
- 许多大型服务器和高性能应用

其主要特点：
- **高度可扩展**：多核 CPU 下性能接近线性
- **低碎片化**：使用多个 arena（分配区）和 per‑thread 缓存
- **可选的性能分析**（本单元未启用）
- **稳定性**：经过大量生产环境验证

本单元提供了：
- 与 Delphi / FPC 内存管理器完全兼容的钩子函数
- **FPC 专用头部**：存储用户请求的准确大小（保证 `MemSize` 返回正确值）
- 支持 **Windows (32/64)、Linux、macOS、iOS、Android** 平台
- 自动加载对应的动态库（`.dll`、`.so`、`.dylib`）

---

## 2. 仓库地址

**GitHub**: [https://github.com/PassByYou888/jemalloc4p](https://github.com/PassByYou888/jemalloc4p)

仓库中包含了：
- 本单元的源代码 (`jemalloc4p.pas`)
- 预编译的 jemalloc 动态库（Windows 和 Linux）
- 示例程序
- 构建和部署说明 (`README.md`)

---

## 3. 编译与部署

### 3.1 环境要求

- **Delphi** (XE 或更高) 或 **Free Pascal** (3.0+)
- 目标平台对应的 **jemalloc 动态库**（可以从仓库的 `lib/` 目录获取，或自行编译）

### 3.2 获取 jemalloc 动态库

#### 使用预编译库
仓库的 `lib/` 目录下通常包含：
- `jemalloc_IA32.dll` – Windows 32 位
- `jemalloc_X64.dll` – Windows 64 位
- `libjemalloc.so` – Linux (x86_64)
- `libjemalloc.dylib` – macOS

将这些文件复制到你的应用程序可执行文件目录，或系统搜索路径中。

#### 从源码编译
你也可以自行编译 jemalloc：
```bash
# Linux / macOS
git clone https://github.com/jemalloc/jemalloc.git
cd jemalloc
./autogen.sh
./configure --enable-shared
make -j4
sudo make install

# Windows (使用 Visual Studio 或 MinGW)
# 见 jemalloc 官方文档
```

### 3.3 集成到项目

1. 将 `jemalloc4p.pas` 文件放置到你的项目源码目录，或添加到搜索路径。
2. 在需要启用 jemalloc 的**主程序**（或第一个引用它的单元）中，将 `jemalloc4p` 添加到 `uses` 子句。
   ```pascal
   program MyApp;
   uses
     jemalloc4p,  // 放在最前面，确保加载时替换内存管理器
     ...;
   ```
3. 确保动态库在运行时可以被加载（见上文）。
4. 编译运行，所有内存操作将自动使用 jemalloc。

### 3.4 注意事项

- **FPC 与 Delphi 行为差异**：
  - 在 FPC 下，本单元会在每个分配块前存储一个 `PtrUInt` 大小的头部，用于记录用户请求的精确大小。这样 `MemSize` 就能返回准确值。
  - 在 Delphi 下，RTL 本身已经跟踪块大小，因此不需要额外头部，直接转发调用。
- 该单元会在单元初始化 (`initialization`) 时自动安装内存钩子，在终结 (`finalization`) 时恢复原管理器。因此无需额外调用安装函数。
- 如果需要在运行时切换管理器，可以调用 `InstallMemoryHook` 和 `UnInstallMemoryHook`（但通常不推荐）。
- jemalloc 本身是线程安全的，本单元不添加额外锁。

---

## 4. 核心特性详解

### 4.1 FPC 下的头部存储

为了确保 `MemSize` 在 FPC 下能返回正确的用户请求大小（而不依赖 jemalloc 内部元数据），本单元在 FPC 版本中在每个分配块前预留了 `SizeOf(PtrUInt)` 字节的头部，其中存储了用户原始请求的字节数。`MemSize` 读取该值并返回。这保证了与 FPC RTL 的完全兼容。

### 4.2 安全的重分配

`ReallocMem` 的实现遵循标准语义：
- 当新大小为 0 时，释放原内存，返回 `nil`。
- 当原指针为 `nil` 时，执行普通分配。
- 当内存不足时，**原指针保持不变**，返回 `nil`（不丢失原数据）。这符合 Delphi/FPC 的预期行为。

### 4.3 零初始化

`AllocMem` 使用 `je_malloc` 分配内存后，调用 `Fast_FillByte` 将整个区域（包括头部，如有）填充为零，确保内存完全清零。

### 4.4 优化的快速填充

`Fast_FillByte` 使用 64 位写操作来加速内存填充，比简单循环快得多，尤其适用于大块内存的零初始化。

---

## 5. 使用示例

### 5.1 自动使用（推荐）

将 `jemalloc4p` 加入到 `uses` 列表，无需任何额外代码：

```pascal
program TestJemalloc;

{$APPTYPE CONSOLE}

uses
  jemalloc4p,  // 替换内存管理器
  SysUtils;

var
  P: Pointer;
  Size: NativeInt;
begin
  GetMem(P, 1024);          // 由 jemalloc 分配
  FillChar(P^, 1024, 0);
  Size := MemSize(P);       // FPC下返回 1024，Delphi下返回实际块大小
  WriteLn('Allocated: ', Size);
  FreeMem(P);
end.
```

### 5.2 手动调用 jemalloc 函数（不经过 RTL）

如果你需要直接使用 jemalloc 的原始函数（如 `je_malloc`、`je_free`），可以这样：

```pascal
uses jemalloc4p;  // 该单元已经外部声明了 je_malloc 等

var
  P: Pointer;
begin
  P := je_malloc(100);
  if P <> nil then
  begin
    // 使用 P ...
    je_free(P);
  end;
end.
```

> 注意：在 FPC 下，如果绕过 RTL 直接调用 `je_malloc`，则不会包含头部，`MemSize` 无法正常工作。通常推荐使用 RTL 的 `GetMem`/`FreeMem`，以保证 `MemSize` 准确性。

---

## 6. 平台与库文件对照

| 平台           | 动态库文件名          | 函数前缀 |
|----------------|-----------------------|----------|
| Windows 32-bit | `jemalloc_IA32.dll`   | `je_`    |
| Windows 64-bit | `jemalloc_X64.dll`    | `je_`    |
| Linux          | `libjemalloc.so`      | (空)     |
| macOS          | `libjemalloc.dylib`   | `_je_`   |
| iOS            | `libjemalloc.a`       | `_je_`   |
| Android        | `libjemalloc.so`      | `je_`    |

编译时，编译器会根据平台自动选择对应的库名和函数前缀。

---

## 7. 常见问题

**Q: 程序启动时提示找不到动态库？**  
A: 确保动态库位于应用程序目录、系统 PATH 或 LD_LIBRARY_PATH 中。如果使用 Delphi 的 `delayed` 加载，也可以忽略该错误直到第一次调用。

**Q: 如何验证 jemalloc 已生效？**  
A: 可以编写一个小程序大量分配/释放，对比启用前后的性能差异，或者使用内存分析工具查看堆分配器名称。

**Q: 是否会影响已有的第三方内存管理（如 FastMM）？**  
A: 本单元替换的是全局内存管理器，如果之前已安装 FastMM，则会覆盖。可以按需选择。

**Q: 为何 FPC 下 `MemSize` 返回准确值，而 Delphi 下可能返回更大值？**  
A: 在 FPC 下我们手工存储了用户大小；在 Delphi 下直接调用 RTL 的 `MemSize`，后者返回的是底层实际分配大小（可能包含对齐和元数据）。两者的行为差异是设计如此，不影响程序逻辑。

**Q: 此单元与 `mimalloc4p` 有何区别？**  
A: 两者均为内存管理器替换单元，但底层库不同（jemalloc vs mimalloc）。选择哪个取决于你的具体需求：jemalloc 更成熟、广泛使用，mimalloc 更新、在某些场景下更快。本单元与 mimalloc4p 可以互换使用，但不能同时启用。

---

## 8. 许可证

本单元（`jemalloc4p.pas`）的代码遵循与 Z‑framework 相同的许可证（BSD 风格）。底层的 jemalloc 库使用 BSD 2‑Clause 许可证。

---

## 9. 更多信息

- **jemalloc 官网**: [http://jemalloc.net/](http://jemalloc.net/)
- **jemalloc GitHub**: [https://github.com/jemalloc/jemalloc](https://github.com/jemalloc/jemalloc)
- **jemalloc4p 仓库**: [https://github.com/PassByYou888/jemalloc4p](https://github.com/PassByYou888/jemalloc4p)
- **Z‑framework 文档**: 参见主手册

---

*文档版本 1.0 – 基于 jemalloc4p.pas 及相关资源整理。*