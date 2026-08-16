# Z.PascalStrings 与 Z.UPascalStrings 联合使用指南：统一操作、编码切换与自动释放指针

---

## 概述

`Z.PascalStrings` 和 `Z.UPascalStrings` 是 Z‑framework 提供的两个核心字符串单元，分别定义了 `TPascalString` 和 `TUPascalString` 类型。它们的设计目标：

- **提供一套统一的、丰富的字符串操作 API**，涵盖构造、访问、修改、查找、替换、修剪、编码转换、哈希、相似度计算、随机生成、C 指针互操作等。
- **解决 Delphi 和 Free Pascal 之间字符编码的不一致性**，让开发者能够编写跨编译器、跨平台且编码安全的代码。
- **在 FPC 下方便地在 ANSI（单字节）和 UTF‑8/UTF‑16 之间切换**，适应不同场景（内存敏感、多语言、系统 API 等）。

两个类型在接口上几乎完全对称，你可以用相同的代码操作它们，仅在需要关注底层编码时做出选择。本指南将重点展示它们 **共同的日常用法**，阐明在 FPC 下因编码差异而需要注意的细微之处，并介绍一种实用的 **自动释放 C 字符串指针** 机制，用于简化跨语言、临时字符串传递。

---

## 1. 核心差异：编码与内存

| 特性 | `TPascalString` (Z.PascalStrings) | `TUPascalString` (Z.UPascalStrings) |
|------|-----------------------------------|--------------------------------------|
| **基础字符类型** | `SystemChar` | `USystemChar` |
| **Delphi 下** | `Char` (UTF‑16, 2 字节) | 同左 |
| **FPC 下** | `AnsiChar` (1 字节，代码页相关，通常为 ANSI 或 UTF‑8) | `UnicodeChar` (UTF‑16, 2 字节) |
| **编码一致性** | 取决于编译器及代码页 | 始终 UTF‑16 |
| **内存占用 (FPC)** | 低（1 字节/字符） | 高（2 字节/字符） |
| **适用场景** | 纯 ASCII、遗留系统、单字节编码协议 | 多语言文本、现代 API、网络数据 |

> **关键点**：在 Delphi 下两者完全等价，因为 `Char` 就是 `UnicodeChar`。在 FPC 下，`TPascalString` 存储单字节，`TUPascalString` 存储双字节 Unicode。若处理非 ASCII 字符，优先使用 `TUPascalString`；若数据仅为 ASCII，可用 `TPascalString` 节省内存。

---

## 2. 互相转换：编码安全的桥梁

两种类型可以轻松转换，且不会丢失信息（通过 UTF‑8 作为中介）。转换方式：

```pascal
var
  ps: TPascalString;
  ups: TUPascalString;
begin
  ps := 'Hello 世界';     // Delphi 下直接；FPC 下 TPascalString 会用系统 ANSI 存储（可能丢失 '世界' 若代码页不支持）
  // 安全转换：使用 UTF‑8 作为中间层
  ups.Bytes := ps.Bytes;   // ps.Bytes 返回 UTF‑8 编码
  // 反向转换
  ps.UTF8 := ups.Bytes;    // 或 ps.Bytes := ups.Bytes;
  // 更简洁的隐式转换（如果运算符可用）
  ups := ps;               // 内部通过 Bytes 实现
  ps := ups;
end;
```

> **注意**：直接赋值（`ups := ps`）在 FPC 下可能涉及 ANSI→UTF‑16 转换，如果 `ps` 中包含了当前代码页不支持的字符，可能会变为 '?'。建议使用显式的 `Bytes` 属性（UTF‑8）进行转换，确保所有 Unicode 字符无损。

---

## 3. 统一 API：日常操作一览

下面列出的所有方法和属性在 `TPascalString` 和 `TUPascalString` 中均以相同名称、相同参数存在，你可以通用。

### 3.1 构造与赋值

```pascal
var
  s: TPascalString;  // 或 TUPascalString
begin
  s := '';               // 空字符串
  s := 'Hello';          // 从原生字符串
  s := SystemChar('A');  // 从单个字符
  s.Text := 'World';     // 通过 Text 属性
  s.Clear;               // 清空
  s.Reset;               // 同 Clear
end;
```

### 3.2 长度与字符访问（1‑based）

```pascal
var
  s: TPascalString;
  c: SystemChar;
  i: Integer;
begin
  s := 'Pascal';
  i := s.Len;            // 6
  i := s.L;              // 简写
  c := s.Chars[1];       // 'P'
  s.Chars[2] := 'a';     // 修改第二个字符
  c := s[1];             // 默认属性，同 Chars
  // 大小写访问
  c := s.UpperChar[1];   // 若小写则转大写
  s.LowerChar[1] := 'A'; // 设为小写 'a'
end;
```

### 3.3 子串提取

```pascal
var
  s, sub: TPascalString;
begin
  s := 'Delphi Pascal';
  sub := s.Copy(1, 6);      // 'Delphi'
  sub := s.Copy(8, 6);      // 'Pascal'
  sub := s.GetString(1, 7); // 返回位置1到位置6（7-1）=> 'Delphi '
  // 若 ePos 超出长度，自动截断
end;
```

### 3.4 查找与位置

```pascal
var
  s: TPascalString;
  pos: Integer;
begin
  s := 'The quick brown fox';
  pos := s.GetPos('quick');        // 5
  pos := s.GetPos('fox', 10);      // 从第10个字符开始找 => 17
  if s.StrExists('brown') then ...;
end;
```

### 3.5 删除与插入

```pascal
var
  s: TPascalString;
begin
  s := 'Hello World';
  s.Delete(6, 5);          // 删除位置6开始5个字符 => 'Hello'
  s.Insert(' Beautiful', 6); // 在位置6插入 => 'Hello Beautiful'
  s.DeleteFirst;           // 删除首字符 => 'ello Beautiful'
  s.DeleteLast;            // 删除尾字符 => 'ello Beautiful'（少最后一个字符）
end;
```

### 3.6 修剪与替换

```pascal
var
  s: TPascalString;
begin
  s := '  Hello World  ';
  s := s.TrimChar(' ');          // 'Hello World'
  s := s.DeleteChar('o');        // 'Hell Wrld'
  s := s.ReplaceChar('e', 'a');  // 'Hall Wrld'
  // 使用字符类别（TOrdChars 或 TUOrdChars）
  s := s.ReplaceChar([c0to9], '*'); // 将所有数字替换为 '*'
end;
```

### 3.7 大小写转换

```pascal
var
  s: TPascalString;
begin
  s := 'Pascal';
  s.Text := s.LowerText;   // 'pascal'
  s.Text := s.UpperText;   // 'PASCAL'
end;
```

### 3.8 反转

```pascal
var
  s, rev: TPascalString;
begin
  s := 'abc';
  rev := s.Invert;         // 'cba'
end;
```

### 3.9 快速哈希（ASCII 大小写不敏感）

```pascal
var
  s: TPascalString;
begin
  s := 'Hello';
  WriteLn(s.hash);     // 32‑bit
  WriteLn(s.Hash64);   // 64‑bit
end;
```

### 3.10 Smith‑Waterman 相似度

```pascal
var
  a, b: TPascalString;
  score: Double;
begin
  a := 'kitten';
  b := 'sitting';
  score := a.SmithWaterman(b);   // 返回 0~1 相似度
end;
```

### 3.11 随机字符串生成（类方法）

```pascal
var
  s: TPascalString;
begin
  // 使用默认随机数生成器
  s := TPascalString.RandomString(10);
  // 指定字符类别（字母数字）
  s := TPascalString.RandomString(12, [cAtoZ, c0to9]);
end;
```

### 3.12 编码转换属性（通用）

```pascal
var
  s: TPascalString;
  buf: TBytes;
begin
  s := '你好';
  buf := s.UTF8;          // 获取 UTF‑8 字节
  s.UTF8 := buf;          // 从 UTF‑8 解码
  buf := s.ANSI;          // 获取 ANSI（当前代码页）字节
  s.ANSI := buf;          // 从 ANSI 解码
  buf := s.PlatformBytes; // 系统默认编码
  s.PlatformBytes := buf;
  // 带 BOM 的 UTF‑8
  buf := s.BOMBytes;
end;
```

### 3.13 C 字符串指针互操作（含自动释放）

两种类型都提供了构建以 null 结尾的 C 字符串指针的方法，方便与 C 库或操作系统 API 交互。**特别地，所有 `Build*` 方法都有一个 `autofree: Boolean` 参数的重载**：当 `autofree=True` 时，返回的指针会在约 60 秒后由全局调度器自动释放，无需手动调用 `Free*`。这极大简化了临时字符串传递的场景，避免了内存泄漏和手动管理负担。

可用的构建方法：

| 方法 | 返回类型 | 说明 | 适用类型 |
|------|----------|------|----------|
| `BuildAnsiChar(autofree: Boolean)` | `Pointer` (PAnsiChar) | 使用系统 ANSI 编码（FPC 下为代码页，Delphi 下为 UTF‑16 转 ANSI） | 两者 |
| `BuildWideChar(autofree: Boolean)` | `Pointer` (PWideChar) | 使用 UTF‑16 编码 | **仅 TUPascalString 可靠**（TPascalString 在 FPC 下返回的是 `SystemChar` 缓冲区，而 `SystemChar` 是 `AnsiChar`，故不适用于宽字符） |
| `BuildUTF8AnsiChar(autofree: Boolean)` | `Pointer` (PAnsiChar) | 使用 UTF‑8 编码（以 null 结束的单字节序列） | 两者 |

**使用示例**：

```pascal
var
  s: TUPascalString;
  p: PAnsiChar;
begin
  s := 'Hello, 世界';
  // 手动管理（需释放）
  p := s.BuildUTF8AnsiChar(False);
  try
    SomeCFunction(p);
  finally
    TUPascalString.FreeUTF8AnsiChar(p);
  end;

  // 自动释放（无需手动 Free）
  p := s.BuildUTF8AnsiChar(True);   // 60 秒后自动释放
  SomeCFunction(p);
  // 不需要再调用 Free，指针会在后台释放
end;
```

**应用场景**：
- 调用 C 动态库函数（如 `dlsym` 后的函数指针）时，需要传递字符串参数。
- 与 Windows API 交互（ANSI 或 Wide 版本）。
- 在快速回调中构造临时字符串，不想操心内存释放。
- 跨语言（如 Python C API、Lua C API）传递短暂生命周期的字符串。

**注意事项**：
- 自动释放是在 60 秒后通过 `Z.Notify` 延迟执行的，因此必须确保指针在 60 秒内不会再被使用（即调用方已复制或完成操作）。对于需要长期持有的指针，应使用手动管理（`autofree=False`）。
- `BuildWideChar` 对于 `TPascalString` 在 FPC 下是不安全的，因为 `SystemChar` 是 `AnsiChar`，无法存储宽字符。**务必使用 `TUPascalString.BuildWideChar` 获取真正的宽字符串指针**。

---

## 4. 差异细化：FPC 下的陷阱与对策

### 4.1 `TPascalString` 索引按字节，而非字符
在 FPC 下，`TPascalString` 存储的是单字节数据（可能是 ANSI 或 UTF‑8）。如果该字符串包含多字节 UTF‑8 序列（如中文），则 `s.Chars[i]` 会返回单个字节，而不是完整的 Unicode 码点。这会导致字符截断、显示错误。

**对策**：
- 仅在确信内容为 ASCII 时使用 `TPascalString` 的索引操作。
- 若需处理多语言，使用 `TUPascalString` 进行内部操作，仅在 I/O 时用 `TPascalString` 或 `Bytes` 进行编码转换。

### 4.2 `Len` 返回的是字节数（`TPascalString`）还是代码单元数（`TUPascalString`）
- `TUPascalString.Len` → UTF‑16 代码单元数（通常 = 字符数，代理对除外）。
- `TPascalString.Len` → 字节数（若为 UTF‑8 编码，则可能 > 字符数）。

**对策**：若需要字符数，应使用 `TUPascalString`，或对 `TPascalString` 进行解码后再计算。

### 4.3 编码转换中的“？”问题
当将 `TUPascalString` 赋值给 `TPascalString` 的 `ANSI` 属性，若目标代码页不支持某些字符，这些字符会被替换为 '?'。同样的，`PlatformBytes` 也可能丢失信息。

**对策**：使用 `Bytes` / `UTF8` 属性进行转换，因为 UTF‑8 可以表示所有 Unicode 字符，不会丢失。

### 4.4 字符串字面量的编码
在 FPC 下，源代码文件的编码决定了字符串字面量的实际字节。如果源文件是 UTF‑8 且代码页为 CP_UTF8，则 `TPascalString` 会正确存储 UTF‑8 字节；如果代码页不是 UTF‑8，则字面量会按系统 ANSI 编码，可能导致 Unicode 字符丢失。

**对策**：在 FPC 中，建议使用 `{$CODEPAGE UTF8}` 指示字，使所有字符串字面量以 UTF‑8 编码，然后使用 `TUPascalString` 进行内部处理，或使用 `UTF8` 属性解码。

---

## 5. 日常使用场景与最佳实践

### 5.1 通用内部处理（推荐 `TUPascalString`）
绝大多数应用应默认使用 `TUPascalString`，因为它提供一致的 Unicode 行为，不受编译器或区域设置影响。所有操作（查找、替换、子串等）都基于完整字符，安全可靠。

```pascal
var
  s: TUPascalString;
begin
  s := '用户输入：你好';
  s := s.ReplaceChar('好', '坏');
  // 输出...
end;
```

### 5.2 与文件/网络 I/O 交互
使用 `TUPascalString` 的 `Bytes` 属性读写 UTF‑8 文件/网络流，这是最通用的编码。

```pascal
var
  s: TUPascalString;
  bytes: TBytes;
begin
  bytes := TFile.ReadAllBytes('utf8_file.txt');
  s.Bytes := bytes;           // 解码
  // 处理 s
  bytes := s.Bytes;           // 编码回 UTF‑8
  TFile.WriteAllBytes('output.txt', bytes);
end;
```

### 5.3 与 Windows API（Wide）交互
使用 `TUPascalString.BuildWideChar` 获取 `PWideChar`，调用需要 LPWSTR 的 API。推荐使用自动释放版本以简化代码：

```pascal
var
  s: TUPascalString;
begin
  s := '路径名';
  SetCurrentDirectoryW(s.BuildWideChar(True));   // 自动释放，无需手动 FreeWideChar
end;
```

### 5.4 与旧式 ANSI API 交互（如 Linux 下 `write`）
当需要将 Unicode 文本发送到期望单字节流的设备时，可先将 `TUPascalString` 转为 UTF‑8 单字节字符串（`TPascalString`），然后使用其 `BuildUTF8AnsiChar`（自动释放）或直接使用 `Bytes`。

```pascal
var
  s: TUPascalString;
  p: PAnsiChar;
begin
  s := 'Hello Linux';
  p := s.BuildUTF8AnsiChar(True);   // 自动释放
  write(STDOUT_FILENO, p^, Length(s));  // 示例：实际需 strlen
  // 无需释放
end;
```

### 5.5 性能优先的纯 ASCII 场景
如果确定所有数据都是 ASCII（<128），可以使用 `TPascalString` 以节省内存和提升速度。转换依然安全，因为 ASCII 在两种类型中都一致。

```pascal
var
  ps: TPascalString;
begin
  ps := 'Only ASCII';
  // 处理...
end;
```

### 5.6 字符串拼接与性能优化
对于大量拼接，使用 `Append` 方法而不是 `+` 运算符，以避免多次复制。

```pascal
var
  s: TPascalString;
  i: Integer;
begin
  s := '';
  for i := 1 to 10000 do
    s.Append('x');   // 高效
end;
```

### 5.7 传递参数给函数
当不需要修改字符串时，使用 `const` 参数避免复制。

```pascal
procedure ProcessString(const s: TPascalString);
begin
  // 只读操作
end;
```

---

## 6. 完整示例：跨平台文本处理 + C API 交互

下面的控制台程序演示了完整的流程：读取 UTF‑8 文件，处理文本，调用一个假想的 C 库函数（需要 UTF‑8 字符串参数），最后写入结果。

```pascal
program Demo;

{$APPTYPE CONSOLE}

uses
  SysUtils, Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.UnicodeMixedLib;

// 模拟一个 C 库函数，打印传入的 UTF‑8 字符串
procedure SomeCLibraryFunction(p: PAnsiChar); cdecl; external 'mylib.so';

var
  text: TUPascalString;
  outBytes: TBytes;
  p: PAnsiChar;
begin
  // 1. 读取 UTF‑8 文件（带 BOM 或纯 UTF‑8）
  text.Bytes := umlFileBytes('input.txt');

  // 2. 处理文本：转为大写（仅 ASCII 字母），替换数字为 '#'
  text.Text := UpperCase(text.Text);
  text := text.ReplaceChar([uc0to9], '#');

  // 3. 调用 C 库，传递自动释放的 UTF‑8 指针
  p := text.BuildUTF8AnsiChar(True);
  SomeCLibraryFunction(p);   // 库函数会复制字符串或立即使用，无需手动释放

  // 4. 保存结果
  outBytes := text.Bytes;
  umlBytesToFile('output.txt', outBytes);

  WriteLn('Done.');
end.
```

---

## 7. 总结

`Z.PascalStrings` 和 `Z.UPascalStrings` 提供了两套几乎完全相同的字符串 API，使开发者可以根据编码需求灵活选择。在日常使用中，绝大部分操作（构造、访问、查找、替换、修剪、哈希、相似度等）对两者通用，你可以轻松互换。唯一需要注意的差异在于 **FPC 下的编码行为**：

- 用 `TUPascalString` 处理多语言文本，保持一致性。
- 用 `TPascalString` 处理 ASCII 或单字节数据，节省内存。
- 通过 `Bytes` / `UTF8` / `ANSI` 属性安全地转换编码。

**自动释放的 C 字符串指针**（`Build*` 的 `autofree=True` 版本）是对跨语言交互的有力补充，让你无需手动管理内存，尤其适合短生命周期的临时字符串传递。结合 Z‑framework 的延迟释放机制，既安全又简洁。

掌握这两个类型，就能在 Delphi 和 FPC 之间无缝切换，同时享受 Z‑framework 提供的丰富字符串处理功能。本指南涵盖了绝大多数常用场景及高级用法，更多细节请参考单元源码及 Z‑framework 的其它文档。
