# Z.Snappy — Pascal 绑定 for Google Snappy 压缩库

## 1. 概述

**Z.Snappy** 是 Google [Snappy](https://github.com/google/snappy) 压缩库的 **Pascal 绑定**。它封装了原生 Snappy 动态库（`snappy_x86.dll`、`snappy_x64.dll` 或 `libsnappy.so`），并为 Z‑框架中的 `TMS64` 和 `TMem64` 内存流类提供了 **便捷的辅助方法**，让压缩/解压缩操作可以一行代码完成。

Snappy 是一个 **极速** 的压缩/解压缩库，其设计目标是速度优先于压缩比。它在 Google 的生产环境中处理了 PB 级的数据。在主流 CPU 上的典型性能：
- 压缩速度：**> 250 MB/s**
- 解压速度：**> 500 MB/s**

压缩比相对适中：
- 纯文本：1.5–1.7 倍
- HTML：2–4 倍
- 已压缩数据（JPEG、PNG 等）：约 1.0 倍

Snappy 的比特流格式 **稳定**，且解压器对损坏或恶意输入具有 **鲁棒性**。

---

## 2. 用途

本单元旨在 **将 Snappy 压缩集成到任何基于 Z‑框架的 Delphi 或 Free Pascal 项目** 中。它提供：

- **动态加载** 原生 Snappy 库（无需静态链接）。
- **平台相关库选择**（Windows 32/64、Linux）。
- **零拷贝** 辅助方法，让 `TMS64` 和 `TMem64` 可以直接压缩或解压自身内容。
- **校验支持**，检查缓冲区是否为有效的 Snappy 数据。
- **线程安全** API（所有原生函数均可重入）。

---

## 3. 仓库与源码

该单元托管在 GitHub 上：

🔗 **[https://github.com/PassByYou888/ZSnappy](https://github.com/PassByYou888/ZSnappy)**

仓库中包含：
- Pascal 绑定单元（`Z.Snappy.pas`）
- 预编译的原生库（Windows 和 Linux）或构建脚本
- 示例项目和 `README.md` 构建说明

---

## 4. 编译与部署

### 4.1 环境要求

- **Delphi**（XE 或更高）或 **Free Pascal**（3.0+）
- **Z‑框架**（Z.Core、Z.MemoryStream 等）——已在仓库中提供
- **原生 Snappy 库** – 你可以：
  - 使用仓库 `lib/` 目录下提供的预编译二进制文件，或者
  - 从源码构建 Snappy（见下文）

### 4.2 构建原生 Snappy 库

#### Windows（使用 Visual Studio）
```bash
git clone https://github.com/google/snappy.git
cd snappy
mkdir build && cd build
cmake .. -G "Visual Studio 17 2022" -A Win32   # 32 位
cmake --build . --config Release
```
生成的文件为 `snappy.dll`（或 `snappy_x86.dll`）。根据 `Z.Snappy.pas` 中的常量重命名（32 位对应 `snappy_x86.dll`，64 位对应 `snappy_x64.dll`），并将其放置到可执行文件目录或系统 PATH 中。

#### Linux
```bash
sudo apt-get install libsnappy-dev   # Debian/Ubuntu
# 或从源码编译
git clone https://github.com/google/snappy.git
cd snappy
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j4
sudo make install
```
在 Linux 上，库通常名为 `libsnappy.so` – 单元会按标准库搜索路径（`LD_LIBRARY_PATH` 或系统目录）查找。

#### 使用仓库中的预编译库
ZSnappy 仓库的 `lib/` 文件夹中包含了可直接使用的二进制文件。只需将对应文件复制到你的应用程序目录即可。

### 4.3 集成到项目

1. 将 Z‑框架源码路径（例如 `..\ZFramework\Source`）添加到项目的搜索路径。
2. 在 `uses` 子句中添加 `Z.Snappy`。
3. 确保原生 Snappy 库位于动态链接器能够找到的位置。

无需额外配置 —— 绑定使用 `delayed` 加载（Delphi）或标准动态链接（FPC），所以库会在首次调用时自动加载。

---

## 5. API 摘要

本单元提供两组 API：

### 5.1 原生 Snappy 函数（底层）

这些是从 DLL/SO 直接导入的函数：

| 函数 | 说明 |
|------|------|
| `snappy_compress` | 压缩内存块。 |
| `snappy_uncompress` | 解压 Snappy 数据块。 |
| `snappy_max_compressed_length` | 返回给定输入长度的最大可能压缩后大小。 |
| `snappy_uncompressed_length` | 从压缩块中获取精确的解压后大小。 |
| `snappy_validate_compressed_buffer` | 快速检查缓冲区是否为有效的 Snappy 数据。 |

所有函数均返回 `TSnappy_Status`（`SNAPPY_OK`、`SNAPPY_INVALID_INPUT`、`SNAPPY_BUFFER_TOO_SMALL`）。

### 5.2 流辅助方法

`TMS64` 和 `TMem64` 均获得以下方法：

```pascal
function snappy_compress_To(inst: TMS64): Boolean; overload;
function snappy_compress_To(inst: TMem64): Boolean; overload;
function snappy_compress_From(inst: TMS64): Boolean; overload;
function snappy_compress_From(inst: TMem64): Boolean; overload;

function snappy_uncompress_From(inst: TMS64): Boolean; overload;
function snappy_uncompress_From(inst: TMem64): Boolean; overload;
function snappy_uncompress_To(inst: TMS64): Boolean; overload;
function snappy_uncompress_To(inst: TMem64): Boolean; overload;

function is_snappy_compressed: Boolean;
```

- `compress_To` 将当前流压缩并写入目标流。
- `compress_From` 将源流压缩并写入当前流。
- `uncompress_To` / `uncompress_From` 同理，用于解压。
- `is_snappy_compressed` 验证当前流是否为有效的 Snappy 数据。

所有方法成功时返回 `True`。

### 5.3 使用示例

```pascal
uses Z.Snappy;

var
  src, compressed, decompressed: TMS64;
begin
  src := TMS64.Create;
  src.WriteString('Hello, Snappy!');

  compressed := TMS64.Create;
  if src.snappy_compress_To(compressed) then
    WriteLn('压缩后大小: ', compressed.Size);

  decompressed := TMS64.Create;
  if compressed.snappy_uncompress_To(decompressed) then
    WriteLn('解压后内容: ', decompressed.ToString);

  // 检查有效性
  if compressed.is_snappy_compressed then
    WriteLn('有效的 Snappy 数据块');

  FreeAndNil(src); FreeAndNil(compressed); FreeAndNil(decompressed);
end;
```

---

## 6. 依赖项

- **Z.Core** – 提供基础类型和内存管理。
- **Z.MemoryStream** – 提供 `TMS64` 和 `TMem64`。
- **Z.PascalStrings** / **Z.UPascalStrings** – 字符串处理。
- **原生 Snappy 库** – 运行时必须存在。

---

## 7. 平台支持

| 平台 | 库文件名 | 备注 |
|------|----------|------|
| Windows 32 位 | `snappy_x86.dll` | 已在 Delphi 和 FPC 中测试 |
| Windows 64 位 | `snappy_x64.dll` | |
| Linux（x86_64） | `libsnappy.so` | 需要安装 libsnappy |
| 其他 | 不支持 | |

---

## 8. 性能注意事项

- **缓冲区分配**：`snappy_compress_To` 始终分配最大可能的压缩后大小（调用 `snappy_max_compressed_length`）。这避免了重新分配，但可能会浪费少量内存。对于大数据，你可以自行调用 `snappy_max_compressed_length` 并调整目标流大小。
- **线程安全**：原生 Snappy 库是线程安全的。你可以从多个线程同时调用辅助方法，只要操作不同的流即可。
- **非对齐内存**：Snappy 在小端架构且非对齐加载开销较低时表现更好。此绑定默认采用小端（x86/x64）。

---

## 9. 许可证

Pascal 绑定（Z.Snappy）遵循与 Z‑框架相同的许可证（BSD 风格）。底层的 Snappy 库同样采用 BSD 类型的许可证。

---

## 10. 更多信息

- **Snappy 官网**：[https://google.github.io/snappy/](https://google.github.io/snappy/)
- **Google Snappy GitHub**：[https://github.com/google/snappy](https://github.com/google/snappy)
- **ZSnappy 仓库**：[https://github.com/PassByYou888/ZSnappy](https://github.com/PassByYou888/ZSnappy)
- **Z‑框架文档**：关于 `TMS64`、`TMem64` 和内存流的更多内容，请参阅 Z‑框架主手册。

---

*文档版本 1.0 – 基于 Z.Snappy.pas 及相关资源整理。*