# tcmalloc4p — Pascal 内存管理器绑定 (tcmalloc)

## 1. 概述

**tcmalloc4p** 是一个 Pascal 单元，它将 Google 的 **tcmalloc** (Thread‑Caching Malloc) 高性能内存分配器集成到 Delphi 和 Free Pascal (FPC) 项目中。该单元通过替换默认的内存管理器（`GetMem`、`FreeMem`、`ReallocMem` 等），使所有内存分配操作都转为使用 tcmalloc，从而获得更好的多线程性能和更低的内存碎片。

tcmalloc 是 Google 内部广泛使用的内存分配库，其设计目标是为大规模服务器应用提供高效的内存管理。主要特点：
- **线程本地缓存**：每个线程拥有自己的小对象缓存，极大减少锁竞争
- **高效的大块分配**：对大对象使用页级分配器
- **可选的堆分析**（本单元使用最小化版本，不包含此功能）
- **内存释放回操作系统**：通过 `MallocExtension_ReleaseFreeMemory` 可以主动释放空闲内存

本单元使用 tcmalloc 的 **minimal** 版本（不包含堆分析扩展），以减小库体积。它提供了：
- 与 Delphi / FPC 内存管理器完全兼容的钩子函数
- **FPC 专用头部**：存储用户请求的准确大小（保证 `MemSize` 返回正确值）
- **`tc_free_sized` 支持**：在 FPC 下使用带尺寸的释放，提高性能
- 支持 **Windows (32/64)、Linux、macOS、iOS、Android** 平台
- 自动加载对应的动态库

---

## 2. 仓库地址

**GitHub**: [https://github.com/PassByYou888/tcmalloc4p](https://github.com/PassByYou888/tcmalloc4p)

仓库中包含了：
- 本单元的源代码 (`tcmalloc4p.pas`)
- 预编译的 tcmalloc 动态库（Windows 和 Linux）
- 示例程序
- 构建和部署说明 (`README.md`)

---

## 3. 编译与部署

### 3.1 环境要求

- **Delphi** (XE 或更高) 或 **Free Pascal** (3.0+)
- 目标平台对应的 **tcmalloc 动态库**（可以从仓库的 `lib/` 目录获取，或自行编译）

### 3.2 获取 tcmalloc 动态库

#### 使用预编译库
仓库的 `lib/` 目录下通常包含：
- `libtcmalloc_minimal_ia32.dll` – Windows 32 位
- `libtcmalloc_minimal_x64.dll` – Windows 64 位
- `libtcmalloc_minimal.so` – Linux (x86_64)
- `libtcmalloc_minimal.dylib` – macOS

将这些文件复制到你的应用程序可执行文件目录，或系统搜索路径中。

#### 从源码编译
你也可以自行编译 tcmalloc（通常从 Google 的 [gperftools](https://github.com/gperftools/gperftools) 获取）：
```bash
git clone https://github.com/gperftools/gperftools.git
cd gperftools
./autogen.sh
./configure --enable-minimal   # 仅构建 minimal 版本
make -j4
sudo make install
```
Windows 下可使用 Visual Studio 或 MinGW 编译（参见官方文档）。

### 3.3 集成到项目

1. 将 `tcmalloc4p.pas` 文件放置到你的项目源码目录，或添加到搜索路径。
2. 在需要启用 tcmalloc 的**主程序**（或第一个引用它的单元）中，将 `tcmalloc4p` 添加到 `uses` 子句。
   ```pascal
   program MyApp;
   uses
     tcmalloc4p,  // 放在最前面，确保加载时替换内存管理器
     ...;
   ```
3. 确保动态库在运行时可以被加载（见上文）。
4. 编译运行，所有内存操作将自动使用 tcmalloc。

### 3.4 注意事项

- **FPC 与 Delphi 行为差异**：
  - 在 FPC 下，本单元会在每个分配块前存储一个 `PtrUInt` 大小的头部，用于记录用户请求的精确大小。这样 `MemSize` 就能返回准确值。
  - 在 Delphi 下，RTL 本身已经跟踪块大小，因此不需要额外头部，直接转发调用。
- 该单元会在单元初始化 (`initialization`) 时自动安装内存钩子，在终结 (`finalization`) 时恢复原管理器。因此无需额外调用安装函数。
- 如果需要在运行时切换管理器，可以调用 `InstallMemoryHook` 和 `UnInstallMemoryHook`（但通常不推荐）。
- tcmalloc 本身是线程安全的，本单元不添加额外锁。

---

## 4. 核心特性详解

### 4.1 FPC 下的头部存储

为了确保 `MemSize` 在 FPC 下能返回正确的用户请求大小（而不依赖 tcmalloc 内部元数据），本单元在 FPC 版本中在每个分配块前预留了 `SizeOf(PtrUInt)` 字节的头部，其中存储了用户原始请求的字节数。`MemSize` 读取该值并返回。这保证了与 FPC RTL 的完全兼容。

### 4.2 使用 `tc_free_sized` 提高性能

在 FPC 的 `FreeMemSize` 钩子中，本单元调用了 `tc_free_sized(P, Size)`，而不是普通的 `tc_free`。这允许 tcmalloc 利用已知的大小信息跳过一些元数据查找，从而稍微提高释放速度。

### 4.3 安全的重分配

`ReallocMem` 的实现遵循标准语义：
- 当新大小为 0 时，释放原内存，返回 `nil`。
- 当原指针为 `nil` 时，执行普通分配。
- 当内存不足时，**原指针保持不变**，返回 `nil`（不丢失原数据）。这符合 Delphi/FPC 的预期行为。

### 4.4 零初始化

`AllocMem` 使用 `tc_malloc` 分配内存后，调用 `Fast_FillByte` 将整个区域（包括头部，如有）填充为零，确保内存完全清零。

### 4.5 优化的快速填充

`Fast_FillByte` 使用 64 位写操作来加速内存填充，比简单循环快得多，尤其适用于大块内存的零初始化。

### 4.6 释放空闲内存

本单元导出了 `MallocExtension_ReleaseFreeMemory` 函数（但未在钩子中自动调用）。你可以在应用程序中手动调用它，使 tcmalloc 将未使用的堆内存归还给操作系统，从而降低进程内存占用。

---

## 5. 使用示例

### 5.1 自动使用（推荐）

将 `tcmalloc4p` 加入到 `uses` 列表，无需任何额外代码：

```pascal
program TestTCMalloc;

{$APPTYPE CONSOLE}

uses
  tcmalloc4p,  // 替换内存管理器
  SysUtils;

var
  P: Pointer;
  Size: NativeInt;
begin
  GetMem(P, 1024);          // 由 tcmalloc 分配
  FillChar(P^, 1024, 0);
  Size := MemSize(P);       // FPC下返回 1024，Delphi下返回实际块大小
  WriteLn('Allocated: ', Size);
  FreeMem(P);
end.
```

### 5.2 手动调用 tcmalloc 函数

如果你需要直接使用 tcmalloc 的原始函数（如 `tc_malloc`、`tc_free`），可以这样：

```pascal
uses tcmalloc4p;

var
  P: Pointer;
begin
  P := tc_malloc(100);
  if P <> nil then
  begin
    // 使用 P ...
    tc_free(P);
  end;
end.
```

> 注意：在 FPC 下，如果绕过 RTL 直接调用 `tc_malloc`，则不会包含头部，`MemSize` 无法正常工作。通常推荐使用 RTL 的 `GetMem`/`FreeMem`，以保证 `MemSize` 准确性。

### 5.3 释放空闲内存

如果你希望主动将空闲内存归还给操作系统：

```pascal
uses tcmalloc4p;
...
MallocExtension_ReleaseFreeMemory();
```

---

## 6. 平台与库文件对照

| 平台           | 动态库文件名                      | 函数前缀 |
|----------------|-----------------------------------|----------|
| Windows 32-bit | `libtcmalloc_minimal_ia32.dll`    | `tc_`    |
| Windows 64-bit | `libtcmalloc_minimal_x64.dll`     | `tc_`    |
| Linux          | `libtcmalloc_minimal.so`          | `tc_`    |
| macOS          | `libtcmalloc_minimal.dylib`       | `_tc_`   |
| iOS            | `libtcmalloc_minimal.a`           | `_tc_`   |
| Android        | `libtcmalloc_minimal.so`          | `tc_`    |

编译时，编译器会根据平台自动选择对应的库名和函数前缀。

---

## 7. 常见问题

**Q: 程序启动时提示找不到动态库？**  
A: 确保动态库位于应用程序目录、系统 PATH 或 LD_LIBRARY_PATH 中。如果使用 Delphi 的 `delayed` 加载，也可以忽略该错误直到第一次调用。

**Q: 如何验证 tcmalloc 已生效？**  
A: 可以编写一个小程序大量分配/释放，对比启用前后的性能差异，或者使用内存分析工具查看堆分配器名称。也可以调用 `MallocExtension_ReleaseFreeMemory` 并观察内存占用变化。

**Q: 是否会影响已有的第三方内存管理（如 FastMM）？**  
A: 本单元替换的是全局内存管理器，如果之前已安装 FastMM，则会覆盖。可以按需选择。

**Q: 为何 FPC 下 `MemSize` 返回准确值，而 Delphi 下可能返回更大值？**  
A: 在 FPC 下我们手工存储了用户大小；在 Delphi 下直接调用 RTL 的 `MemSize`，后者返回的是底层实际分配大小（可能包含对齐和元数据）。两者的行为差异是设计如此，不影响程序逻辑。

**Q: 此单元与 jemalloc4p/mimalloc4p 有何区别？**  
A: 三者均为内存管理器替换单元，但底层库不同：tcmalloc（Google）、jemalloc（FreeBSD/Rust）、mimalloc（Microsoft）。选择取决于你的具体需求。本单元与它们可以互换使用，但不能同时启用。

---

## 8. 许可证

本单元（`tcmalloc4p.pas`）的代码遵循与 Z‑framework 相同的许可证（BSD 风格）。底层的 tcmalloc 库（gperftools）使用 BSD 3‑Clause 许可证。

---

## 9. 更多信息

- **tcmalloc（gperftools）官网**: [https://github.com/gperftools/gperftools](https://github.com/gperftools/gperftools)
- **Google 性能工具指南**: [https://gperftools.github.io/gperftools/](https://gperftools.github.io/gperftools/)
- **tcmalloc4p 仓库**: [https://github.com/PassByYou888/tcmalloc4p](https://github.com/PassByYou888/tcmalloc4p)
- **Z‑framework 文档**: 参见主手册

---

*文档版本 1.0 – 基于 tcmalloc4p.pas 及相关资源整理。*