# Z.TextDataEngine 完全使用指南：INI 风格配置引擎

`Z.TextDataEngine`（单元 `Z.TextDataEngine`）是 Z‑framework 中一个灵活、高性能的 INI 风格配置引擎。它通过**节（Section）** 和**键（Key）** 组织数据，支持 **Variant 模式**（自动类型识别）和 **纯文本模式**（字符串存储），并提供懒加载缓存、类型化访问器、注释保留、流/文件持久化、合并克隆等丰富功能。本指南将带你从零开始掌握它的设计理念、API 用法和最佳实践，无论你是 AI 还是人类开发者，都能轻松上手。

---

## 1. 设计目标与核心概念

### 1.1 为什么需要 TextDataEngine？
- 传统 INI 文件解析器往往功能简单，不支持复杂数据类型（整数、浮点、布尔、日期时间等），且每次读写都重新解析文件，性能不佳。
- 许多应用需要内存中高效缓存配置，支持快速读写，并能保持与文本文件的同步。
- 需要处理注释（`;` 风格），并保留全局注释（节外的描述性文本）。

### 1.2 架构概览
`THashTextEngine` 内部维护 **三层存储**，协同工作：

1. **原始字符串列表**（`FSectionList`）：每个节对应一个 `TCore_Strings`，存储未经解析的键值对行（例如 `Port=8080`）。这是持久化的基础。
2. **Variant 哈希缓存**（`FSectionHashVariantList`）：当以 Variant 模式访问某个节时，引擎将原始字符串解析为 `THashVariantList`（键→Variant），并缓存以加快后续访问。
3. **字符串哈希缓存**（`FSectionHashStringList`）：当以纯文本模式访问某个节时，解析为 `THashStringList`（键→string），同样缓存。

三个层协同工作，采用 **懒加载** 策略：只有在第一次读取或写入时才会解析原始字符串并创建缓存。修改缓存后，原始字符串不会立即更新，直到调用 `Rebuild` 或导出时才会同步。

### 1.3 两种操作模式（重要）
**对同一个节（section），必须选择一种模式并保持一致，不要混用。**

| 模式 | 访问属性 | 数据类型 | 适用场景 |
|------|----------|----------|----------|
| **Variant 模式** | `Hit[]`、`HitVariant[]`、`VariantList[]`、`HVariantList[]` | Variant（自动识别整数、浮点、布尔、字符串等） | 配置文件包含多种类型，希望自动转换 |
| **文本模式** | `HitString[]`、`HitS[]`、`SHit[]`、`StringList[]`、`HStringList[]` | 纯 `SystemString`（需手动解析） | 所有值都是字符串，或你想自己控制解析 |

> **为什么不能混用？** 因为 Variant 缓存和字符串缓存是独立的，对同一个键用两种模式写入，不会自动同步，导致数据不一致。例如，先用 `Hit['Section','Key'] := 123`（Variant 模式），再用 `HitString['Section','Key']` 读取，后者不会得到 `'123'`，而是空字符串（因为字符串缓存尚未填充）。

---

## 2. 基本操作

### 2.1 创建与销毁
```pascal
var
  cfg: THashTextEngine;
begin
  cfg := THashTextEngine.Create;        // 默认 16 个节的哈希桶
  // 或指定节池大小
  cfg := THashTextEngine.Create(32);    // 32 个桶
  // 或同时指定节和列表（每个节内部键的哈希桶）大小
  cfg := THashTextEngine.Create(32, 64);
  ...
  cfg.Free;
end;
```

### 2.2 写入与读取（Variant 模式）
```pascal
cfg.Hit['Network', 'Port'] := 8080;          // 自动存储为整数
cfg.Hit['Network', 'Enabled'] := True;       // 布尔值
cfg.Hit['Network', 'Name'] := 'MyServer';    // 字符串
cfg.Hit['Network', 'Timeout'] := 30.5;       // 浮点数

var port: Integer;
port := cfg.Hit['Network', 'Port'];          // 返回 Variant，自动转换
if cfg.Hit['Network', 'Enabled'] then ...
```

### 2.3 写入与读取（文本模式）
```pascal
cfg.HitString['Database', 'Host'] := 'localhost';
cfg.HitString['Database', 'Port'] := '5432';
cfg.HitString['Database', 'SSL'] := 'true';

var host: string;
host := cfg.HitString['Database', 'Host'];
var ssl: Boolean;
ssl := cfg.HitString['Database', 'SSL'] = 'true';
```

### 2.4 检查存在性
```pascal
if cfg.Exists('Network') then ...
if cfg.ExistsKey('Network', 'Port') then ...
```

### 2.5 删除键或节
```pascal
cfg.DeleteKey('Network', 'Timeout');
cfg.Delete('Network');   // 删除整个节
```

### 2.6 清空全部
```pascal
cfg.Clear;
```

---

## 3. 类型化辅助方法（推荐）

为了简化从文本模式读取类型值，引擎提供了 `GetDefaultText_*` 和 `SetDefaultText_*` 方法。它们基于字符串缓存（`HStringList`）工作，因此 **无论你使用的是 Variant 模式还是文本模式，这些方法都能正确读取**（因为字符串缓存总是与原始字符串同步）。但如果你使用 Variant 模式写入，字符串缓存可能未被填充，因此 **最佳实践：统一使用文本模式（`HitString`）写入，然后使用类型化方法读取**，以保证一致性和类型安全。

```pascal
// 写入（使用文本模式）
cfg.HitString['Settings', 'Timeout'] := '5000';
cfg.HitString['Settings', 'Enabled'] := 'True';
cfg.HitString['Settings', 'Pi'] := '3.1415';
cfg.HitString['Settings', 'Date'] := '2025-01-01 12:00:00';

// 读取（类型安全，带默认值）
var timeout: Integer;
timeout := cfg.GetDefaultText_I32('Settings', 'Timeout', 1000);  // 5000

var enabled: Boolean;
enabled := cfg.GetDefaultText_Bool('Settings', 'Enabled', False); // True

var pi: Double;
pi := cfg.GetDefaultText_Float('Settings', 'Pi', 0.0); // 3.1415

var dt: TDateTime;
dt := cfg.GetDefaultText_DT('Settings', 'Date', Now); // 指定日期
```

支持的类型：
- `I32` (Integer)
- `I64` (Int64)
- `I128` (Int128)
- `Float` (Double)
- `Bool` (Boolean)
- `DT` (TDateTime)

对应的 Set 方法：
```pascal
cfg.SetDefaultText_I32('Settings', 'Timeout', 6000);
cfg.SetDefaultText_Bool('Settings', 'Enabled', False);
```

### 3.1 AutoUpdateDefaultValue 特性
如果将 `AutoUpdateDefaultValue` 属性设为 `True`，当使用 `GetDefaultValue` 或 `GetDefaultText` 读取一个不存在的键时，引擎会自动将该键设置为提供的默认值并写入。这在初始化配置时非常方便。

```pascal
cfg.AutoUpdateDefaultValue := True;
var val: Integer;
val := cfg.GetDefaultText_I32('Section', 'Key', 42);  // 如果 Key 不存在，则自动创建 Key=42，并返回 42
```

---

## 4. 注释处理

### 4.1 导入时的注释剥离
当你使用 `DataImport` 从 `TPascalStringList` 导入时，引擎会自动去掉行尾 `;` 及其后的内容（标准 INI 注释风格）。例如：

输入文本：
```
[Server]
Port=8080  ; Listen port for HTTP
Host=0.0.0.0  ; Bind all interfaces

; This line is skipped (starts with ;)
LogLevel=Info  ; Verbosity
```

导入后存储的值：
- `Port=8080`
- `Host=0.0.0.0`
- `LogLevel=Info`

所有 `;` 注释不会被存储。

### 4.2 全局注释（节外文本）
节外的非空、非 `;` 开头的行会被当作全局注释，保存在 `Comment` 属性中（`TCore_Strings`）。导出时会原样输出。

```pascal
cfg.Comment.Add('This is a global comment');
cfg.Comment.Add('Another comment line');
```

### 4.3 自定义注释的保留
当你手动修改或通过 `VariantList`/`StringList` 写入时，不会影响原始字符串中的注释，因为注释仅存在于原始字符串层。若要保留自定义注释，建议在导入时提供注释行，或导出后再手动添加。

---

## 5. 文件与流 I/O

### 5.1 保存到文件
```pascal
cfg.SaveToFile('config.ini');
```
内部会将当前数据（重建后）导出为 INI 格式文本，并写入文件。

### 5.2 从文件加载
```pascal
cfg.LoadFromFile('config.ini');
```
加载后，原始字符串列表被填充，缓存清空，`IsChanged` 重置为 `False`。

### 5.3 使用流
```pascal
var ms: TMemoryStream;
ms := TMemoryStream.Create;
cfg.SaveToStream(ms);
ms.Position := 0;
cfg.LoadFromStream(ms);
ms.Free;
```

### 5.4 获取/设置纯文本
```pascal
var text: string;
text := cfg.AsText;          // 导出为单一字符串
cfg.AsText := '[Section]'#13#10'Key=Value';  // 从字符串加载
```

---

## 6. 高级操作

### 6.1 重建（Rebuild）
`Rebuild` 将所有缓存（Variant 和 String）转换回原始字符串列表，使原始字符串与缓存同步。通常在导出前自动调用，但如果你手动修改了 Variant 缓存并希望立即得到最新的原始字符串，可以主动调用。

```pascal
cfg.Rebuild;
```

### 6.2 合并与赋值
- **Assign**：深拷贝另一个引擎的数据。
- **Merge**：将另一个引擎的数据合并进来，如果键冲突则覆盖。
- **Clone**：创建当前引擎的独立副本。

```pascal
var other: THashTextEngine;
other := THashTextEngine.Create;
other.LoadFromFile('default.ini');

cfg.Assign(other);           // cfg 变成 other 的副本
cfg.Merge(other);            // 将 other 的键合并到 cfg（覆盖同名）
var clone := cfg.Clone;      // 全新副本
```

### 6.3 交换（SwapInstance）
高效地交换两个引擎的内部数据（O(1)），常用于需要快速切换配置的场景。

```pascal
cfg.SwapInstance(other);
```

### 6.4 比较（Same）
检查两个引擎是否具有完全相同的内容（基于原始字符串比较）。

```pascal
if cfg.Same(other) then ...
```

### 6.5 获取节名列表
```pascal
var names: TCore_Strings;
names := TStringList.Create;
cfg.GetSectionList(names);
// names 包含所有节名
```

### 6.6 总键数
```pascal
var total: Integer;
total := cfg.TotalCount;
```

### 6.7 最大/最小节名长度
```pascal
cfg.MaxSectionNameSize;  // 最长节名
cfg.MinSectionNameSize;  // 最短节名
```

---

## 7. 直接访问底层缓存（高级）

如果你需要直接操作 Variant 或 String 哈希表（例如批量导入），可以通过 `VariantList` 和 `StringList` 属性获取。

```pascal
var vl: THashVariantList;
vl := cfg.VariantList['Network'];   // 获取或创建 Variant 哈希
vl['Port'] := 9090;                 // 直接修改

var sl: THashStringList;
sl := cfg.StringList['Database'];   // 获取或创建 String 哈希
sl['Host'] := '127.0.0.1';
```

注意：直接修改哈希表后，需要调用 `Rebuild` 使原始字符串同步，否则导出时会丢失更改。

---

## 8. 性能与最佳实践

### 8.1 选择合适的模式
- **如果配置项包含多种类型**（整数、布尔、浮点），且你希望自动转换，使用 **Variant 模式**。
- **如果配置项纯文本**，或者你需要自己控制解析逻辑（例如自定义日期格式），使用 **文本模式 + 类型化方法**。

### 8.2 避免混用模式
对同一个节，坚持一种模式。最安全的做法是：**统一使用文本模式（`HitString`）写入，使用 `GetDefaultText_*` 读取**，这样既保证了数据一致性，又获得了类型安全。

### 8.3 缓存管理
引擎的懒加载机制使得首次访问某个节时会有解析开销，但后续访问很快。如果你的应用启动时就需要加载大量配置，可以预加载所有节（通过遍历节名并访问 `StringList` 或 `VariantList`），将解析预热。

### 8.4 IsChanged 标志
`IsChanged` 属性在每次修改（写入、删除、导入）后自动设为 `True`，在 `Rebuild`、`LoadFrom*` 或 `DataImport` 后重置为 `False`。你可以利用它来决定是否需要保存。

```pascal
if cfg.IsChanged then
  cfg.SaveToFile('config.ini');
```

### 8.5 大文件处理
对于大型配置文件（数千个键），建议使用适当的哈希桶大小（构造函数参数）以减少碰撞，提高查找性能。默认 16 个桶对于大多数应用足够。

### 8.6 线程安全
`THashTextEngine` **不是线程安全**的。如果多线程同时读写，需要外部加锁（例如使用 `TCritical`）。

---

## 9. 完整示例：应用配置管理

```pascal
program ConfigDemo;

{$APPTYPE CONSOLE}

uses
  SysUtils, Z.Core, Z.TextDataEngine, Z.UnicodeMixedLib;

var
  cfg: THashTextEngine;
  port: Integer;
  host: string;
  enabled: Boolean;
begin
  cfg := THashTextEngine.Create;
  try
    // 尝试加载现有配置文件
    if umlFileExists('app.ini') then
      cfg.LoadFromFile('app.ini')
    else
    begin
      // 创建默认配置
      cfg.HitString['Server', 'Host'] := '0.0.0.0';
      cfg.HitString['Server', 'Port'] := '8080';
      cfg.HitString['Server', 'SSL'] := 'false';
      cfg.HitString['Logging', 'Level'] := 'Info';
      cfg.SaveToFile('app.ini');
    end;

    // 读取配置（使用类型化方法）
    host := cfg.GetDefaultText('Server', 'Host', '127.0.0.1');
    port := cfg.GetDefaultText_I32('Server', 'Port', 80);
    enabled := cfg.GetDefaultText_Bool('Server', 'SSL', False);

    WriteLn(Format('Server: %s:%d, SSL=%s', [host, port, BoolToStr(enabled, True)]));

    // 修改并保存
    cfg.SetDefaultText_I32('Server', 'Port', 9090);
    if cfg.IsChanged then
      cfg.SaveToFile('app.ini');

  finally
    cfg.Free;
  end;
end.
```

---

## 10. 常见问题解答

### Q：Variant 模式和文本模式可以混用吗？
A：**严格禁止**对同一个节混用。如果混用，会导致数据不一致。例如，先用 `Hit['Section','Key'] := 123`（Variant 模式），再用 `HitString['Section','Key']` 读取，后者不会得到 `'123'`，而是空字符串，因为字符串缓存未更新。

### Q：为什么我修改了 `HitString`，但 `GetDefaultText_I32` 读取到的还是旧值？
A：`GetDefaultText_I32` 直接从字符串缓存读取，而 `HitString` 会更新字符串缓存，因此应该能读到新值。如果你遇到不一致，可能是你没有调用 `Rebuild` 或未正确选择模式。建议统一使用 `HitString` 写入，然后使用 `GetDefaultText_*` 读取。

### Q：注释中的 `;` 会被存储吗？
A：不会。导入时，行尾的 `;` 及其后内容会被剥离并丢弃。全局注释（节外的非 `;` 开头的行）会保留在 `Comment` 属性中。

### Q：如何保留自定义注释？
A：你可以在导出后手动添加注释行到导出的字符串列表中，或者通过 `Comment` 属性添加全局注释。引擎本身不提供键级注释存储，但你可以通过外部数据结构关联注释。

### Q：`AutoUpdateDefaultValue` 对 `GetDefaultText` 有效吗？
A：是的，对 `GetDefaultText` 和 `GetDefaultValue` 都有效。当设置为 `True` 时，如果键不存在，会自动创建并存储默认值。

### Q：`TotalCount` 是否包含注释？
A：不包含，只计算键值对的数量。

---

## 11. 总结

`Z.TextDataEngine` 是一个功能丰富、性能优良的 INI 风格配置引擎，它通过懒加载缓存、两种操作模式和丰富的辅助方法，极大简化了配置文件的读写和管理。关键要点：

- **选择一种模式**：Variant 或 Text，不要混用。
- **优先使用文本模式 + 类型化方法**，保证一致性和类型安全。
- **善用 `IsChanged`** 避免不必要的磁盘写入。
- **利用 `Rebuild`** 在必要时同步各层数据。
- **处理注释**：导入时自动剥离行尾 `;` 注释，全局注释保存在 `Comment` 属性中。

通过本指南，你应该能够轻松地将 `Z.TextDataEngine` 集成到你的项目中，高效管理各类配置数据。更多细节请参考单元源码及 Z‑framework 的其他文档。