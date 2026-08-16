# Z.ListEngine 使用指南：遗留集合框架（兼容性保留）

`Z.ListEngine` 是 Z‑framework 中的一个**遗留单元**，它提供了一系列非泛型的哈希表、列表和回调容器，最初设计于 Delphi 2007 及更早版本（泛型尚未普及）。这些类经过长期实战考验，功能完整，但由于现代 Delphi 和 FPC 已支持泛型，**新开发应避免使用这些类，转而使用 `Z.Core` 中的泛型容器（如 `TBigList`、`TBig_Hash_Pair_Pool`）或 RTL 的 `TDictionary`、`TList<T>`**。本指南旨在帮助维护旧代码的开发者理解这些类的用法，以及如何将现有代码迁移到泛型方案。

---

## 1. 历史背景与设计哲学

在泛型出现之前，若要实现类型安全的容器，必须为每种键/值类型组合手动编写专门的类。`Z.ListEngine` 正是这样的产物：它提供了 `THashList`（字符串→指针）、`THashObjectList`（字符串→对象）、`THashStringList`（字符串→字符串）、`THashVariantList`（字符串→Variant）等多种变体，还包含整数键的哈希表（`TInt64HashObjectList` 等）和普通字符串列表（`TListString`、`TListPascalString`）。

这些类内部使用 **分离链式哈希表**，并维护一个双向链表以保持插入顺序。它们还支持：
- **LRU 访问优化**：最近访问的条目被移到链表尾部，以加速重复访问。
- **自动释放数据**：删除时自动释放关联的对象或内存。
- **多种回调风格**：遍历时支持 `_C`（过程）、`_M`（对象方法）、`_P`（嵌套/匿名）三种回调形式。
- **文件 I/O**：将内容以 `key=value` 格式保存/加载到流或文件。

尽管这些设计在当时是先进的，但如今泛型容器提供了更好的类型安全性、更简洁的代码和更高的性能。**本单元仅用于兼容旧代码，新项目请勿使用。**

---

## 2. 主要类概览

| 类名 | 键类型 | 值类型 | 说明 |
|------|--------|--------|------|
| `THashList` | `string` | `Pointer` | 基础哈希表，存储任意指针。 |
| `THashObjectList` | `string` | `TObject` | 对象哈希表，支持自动释放对象（`AutoFreeObject`）。 |
| `THashStringList` | `string` | `string` | 字符串哈希表，提供宏替换、默认值、流 I/O 等。 |
| `THashVariantList` | `string` | `Variant` | Variant 哈希表，支持数值快捷访问（`i64`、`F`、`S`）。 |
| `TListString` | 无（按索引） | `string` | 字符串列表，每个条目可关联一个对象。 |
| `TListPascalString` | 无（按索引） | `TPascalString` | 基于 `TPascalString` 的列表，支持排序和查找。 |
| `TBackcall_Pool` | 无（回调集合） | 回调过程 | 管理多个回调（C/M/P 风格），并支持批量触发。 |
| `THashStringTextStream` / `THashVariantTextStream` | 辅助类 | - | 用于在哈希表和文本行之间进行导入/导出。 |
| 各种整数键哈希表 | `Int64`, `UInt32`, `Pointer` | `TObject` / `Pointer` / `NativeUInt` | 类似 `THashList`，但键为整数类型。 |

---

## 3. 详细使用指南

### 3.1 THashList —— 通用指针哈希表

`THashList` 是所有字符串键哈希表的基础。它存储 `Pointer` 值，通过 `Data` 字段关联任意数据。

**创建与销毁**
```pascal
var
  Hash: THashList;
begin
  Hash := THashList.Create;                // 默认 64 个桶
  Hash := THashList.CustomCreate(128);     // 指定桶数
  ...
  Hash.Free;
end;
```

**添加/访问**
```pascal
var
  p: Pointer;
begin
  p := GetSomePointer;
  Hash.Add('key1', p, True);   // True 表示覆盖已有键
  Hash['key2'] := p;           // 通过 KeyValue 属性
  p := Hash['key1'];           // 读取
  if Hash.Exists('key1') then ...
end;
```

**删除与遍历**
```pascal
Hash.Delete('key1');
// 遍历（C 风格回调）
Hash.ProgressC(
  procedure(Name_: PSystemString; hData: PHashListData)
  begin
    DoStatus(Name_^, hData^.Data);
  end
);
// M/P 风格类似
```

**自动释放数据**
设置 `AutoFreeData := True`，删除条目时会调用 `OnFreePtr` 回调释放 `Data` 指针。默认 `OnFreePtr` 仅 `Dispose` 指针，你可以自定义。

```pascal
Hash.AutoFreeData := True;
Hash.OnFreePtr := MyDataFreeProc; // 自定义释放
```

**LRU 优化**
`AccessOptimization := True` 时，每次读取会将被访问的条目移到链表尾部，提高热点数据的查找速度。

**统计信息**
- `Count`：条目数。
- `MaxKeySize` / `MinKeySize`：键的最长/最短长度。

---

### 3.2 THashObjectList —— 对象仓库

`THashObjectList` 继承自 `THashList` 的包装，专门存储 `TObject` 派生对象。它提供 `AutoFreeObject` 属性，删除时自动释放对象。

**创建**
```pascal
var
  ObjList: THashObjectList;
begin
  ObjList := THashObjectList.Create(True); // AutoFreeObject = True
  // 或自定义桶数
  ObjList := THashObjectList.CustomCreate(True, 64);
```

**操作**
```pascal
var
  obj: TMyObject;
begin
  obj := TMyObject.Create;
  ObjList.Add('myobj', obj);
  obj := ObjList['myobj'];           // 读取
  ObjList.Delete('myobj');           // 自动释放 obj
```

**按对象查找键名**
```pascal
var
  name: string;
begin
  name := ObjList.GetObjAsName(obj);
end;
```

**变更通知**
`OnChange[Name]` 可为每个键绑定一个事件，在值被修改时触发。
```pascal
ObjList.OnChange['key'] := MyChangeHandler;
```

**生成唯一名称**
`MakeName` 和 `MakeRefName` 方法可生成不重复的键名，适合动态对象仓库。

---

### 3.3 THashStringList —— 字符串配置表

`THashStringList` 存储 `string` 值，并提供了丰富的辅助方法，是 **INI 风格配置** 的常用工具。

**基本读写**
```pascal
var
  SL: THashStringList;
begin
  SL := THashStringList.Create;
  SL['Host'] := 'localhost';
  SL['Port'] := '8080';
  WriteLn(SL['Host']); // 'localhost'
  if SL.Exists('Port') then ...
  SL.Delete('Port');
end;
```

**默认值与自动填充**
```pascal
SL.AutoUpdateDefaultValue := True;
var s: string;
s := SL.GetDefaultValue('Timeout', '30'); // 若不存在，自动创建 Timeout=30
```

**类型化快捷方法**
```pascal
SL.SetDefaultText_I32('Port', 8080);
var Port: Integer;
Port := SL.GetDefaultText_I32('Port', 80);
// 类似的有 _I64, _Float, _Bool, _DT
```

**宏替换**
`ProcessMacro` 可以将文本中的 `%` 占位符替换为实际值（需自定义前后缀）。
```pascal
var
  outText: string;
begin
  SL['name'] := 'Alice';
  SL.ProcessMacro('Hello %name%', '%', '%', outText);
  // outText = 'Hello Alice'
end;
```

**批量替换**
`Replace` 方法用所有键值对作为替换字典，对给定文本执行批量替换（支持全词匹配和大小写）。

**流/文件 I/O**
```pascal
SL.SaveToFile('config.ini');
SL.LoadFromFile('config.ini');
```
文件格式为每行 `key=value`，支持 `___base64:` 前缀处理二进制数据（通过 `THashStringTextStream` 自动编解码）。

**导入导出**
```pascal
var
  Lines: TListPascalString;
begin
  SL.ExportAsStrings(Lines);   // 导出为行列表
  SL.ImportFromStrings(Lines); // 从行列表导入
end;
```

---

### 3.4 THashVariantList —— 通用 Variant 配置

类似 `THashStringList`，但值为 Variant，支持任意类型自动转换。

**便捷访问**
```pascal
var
  VL: THashVariantList;
begin
  VL := THashVariantList.Create;
  VL['Count'] := 10;                 // 整数
  VL['Pi'] := 3.14;                 // 浮点
  VL['Name'] := 'Test';             // 字符串
  // 类型化快捷
  VL.i64['Big'] := 123456789;        // 64位整数
  VL.F['Temp'] := 36.6;              // 浮点
  VL.S['Desc'] := 'Hello';           // 字符串
  // 读取
  var n: Integer; n := VL['Count'];
  var d: Double; d := VL.F['Pi'];
end;
```

**集合操作**
- `IncValue`：增加值（若为字符串则逗号拼接，若为数值则相加）。
- `SetMax` / `SetMin`：更新最大/最小值。
- `GetDefaultValue` / `SetDefaultValue`：支持默认值。

**宏与替换** 同 `THashStringList`。

---

### 3.5 整数键哈希表

- `TInt64HashObjectList`：键为 `Int64`，值为 `TObject`。
- `TUInt32HashObjectList`：键为 `UInt32`，值为 `TObject`。
- `TUInt32HashPointerList`：键为 `UInt32`，值为 `Pointer`。
- `TPointerHashNativeUIntList`：键为 `Pointer`，值为 `NativeUInt`（并维护总和、最小/最大指针）。

用法类似 `THashList`，但访问属性为 `i64Val`、`u32Val`、`NPtrVal` 等。这些类主要用于性能敏感且键为数值的场景，但同样被泛型替代。

---

### 3.6 字符串列表

#### 3.6.1 TListString —— 简单字符串列表
```pascal
var
  L: TListString;
begin
  L := TListString.Create;
  L.Add('Item1');
  L.Add('Item2', TObject.Create); // 关联对象
  WriteLn(L[0]); // 'Item1'
  L.DeleteString('Item1'); // 删除匹配项
  L.SaveToFile('list.txt');
  L.LoadFromFile('list.txt');
  L.Free;
end;
```

#### 3.6.2 TListPascalString —— TPascalString 列表
功能更强大，支持排序（多种回调风格）、快速查找（基于哈希）。

```pascal
var
  LP: TListPascalString;
begin
  LP := TListPascalString.Create;
  LP.Add('Zebra');
  LP.Add('Apple');
  LP.Sort; // 字母升序（默认）
  // 自定义排序
  LP.Sort_C(
    function(var L, R: TPascalString): Integer
    begin
      Result := Length(L.Text) - Length(R.Text); // 按长度
    end
  );
  // 查找
  if LP.ExistsValue('Apple') >= 0 then ...
  LP.AssignTo(SomeStringList); // 复制到 TStrings
  LP.SaveToFile('list.txt');
end;
```

---

### 3.7 TBackcall_Pool —— 回调调度器

`TBackcall_Pool` 维护一组回调（C/M/P 风格），可通过 `ExecuteBackcall` 一次性触发所有回调，并传递三个 Variant 参数。常用于事件广播。

```pascal
var
  Pool: TBackcall_Pool;
begin
  Pool := TBackcall_Pool.Create;
  // 注册
  Pool.RegisterBackcallC(Self, MyProc);
  Pool.RegisterBackcallM(Self, MyMethod);
  // 触发
  Pool.ExecuteBackcall(Self, 1, 'test', True);
  // 注销
  Pool.UnRegisterBackcall(Self);
  Pool.Free;
end;
```

---

### 3.8 辅助流类

- `THashVariantTextStream`：在 `THashVariantList` 和文本行之间转换。
- `THashStringTextStream`：在 `THashStringList` 和文本行之间转换。

这些类自动处理 Base64 编码（当值包含控制字符时）和表达式求值（`exp(...)` 前缀）。通常不需要直接使用，因为 `THashStringList` 和 `THashVariantList` 已提供 `LoadFromStream`/`SaveToStream`。

---

## 4. 典型使用场景

### 4.1 应用配置管理
使用 `THashStringList` 或 `THashVariantList` 加载 `.ini` 文件，读写设置，并保存。

```pascal
var
  Config: THashStringList;
begin
  Config := THashStringList.Create;
  if FileExists('app.ini') then
    Config.LoadFromFile('app.ini');
  Config.AutoUpdateDefaultValue := True;
  var Port := Config.GetDefaultText_I32('Network', 'Port', 80);
  Config.SetDefaultText_I32('Network', 'Port', 8080);
  Config.SaveToFile('app.ini');
  Config.Free;
end;
```

### 4.2 对象注册表
使用 `THashObjectList` 管理全局对象，通过名称快速检索。

```pascal
var
  Objects: THashObjectList;
begin
  Objects := THashObjectList.Create(True); // 自动释放
  Objects.Add('logger', TLogger.Create);
  Objects.Add('database', TDatabase.Create);
  // 使用
  (Objects['logger'] as TLogger).Log('Hello');
  Objects.Delete('database'); // 自动释放
end;
```

### 4.3 字符串列表操作
使用 `TListPascalString` 处理大量字符串，支持高效排序和查找。

### 4.4 事件分发
`TBackcall_Pool` 可用于插件系统或事件总线，集中管理多个监听器。

---

## 5. 性能与注意事项

- **哈希碰撞**：默认桶数为 64，若数据量较大，建议 `CustomCreate` 指定更大的桶数（如 1024）以减少碰撞。
- **内存开销**：每个条目都保存原始键和哈希值，内存占用略高。
- **线程安全**：**所有类都不是线程安全的**，多线程访问需外部加锁（如 `TCritical`）。
- **自动释放**：使用 `AutoFreeData` 或 `AutoFreeObject` 时，确保数据可安全释放，且不会重复释放。
- **LRU 优化**：频繁访问时开启 `AccessOptimization` 可提高命中率，但会增加少量写操作开销。
- **文件编码**：`LoadFromFile`/`SaveToFile` 默认使用 UTF‑8（Delphi）或系统编码（FPC），若需要 ANSI 请使用流并自行设置。

---

## 6. 迁移指南 —— 从遗留类过渡到现代泛型

由于 `Z.ListEngine` 已被弃用，强烈建议将旧代码迁移到 Z‑framework 的现代容器或 RTL 泛型。以下是等价替换方案：

| 遗留类 | 推荐替代（Z.Core 泛型） | RTL 替代 |
|--------|--------------------------|----------|
| `THashList` | `TBig_Hash_Pair_Pool<string, Pointer>` | `TDictionary<string, Pointer>` |
| `THashObjectList` | `TBig_Hash_Pair_Pool<string, TObject>` | `TObjectDictionary<string, TObject>` |
| `THashStringList` | `TBig_Hash_Pair_Pool<string, string>` | `TDictionary<string, string>` |
| `THashVariantList` | `TBig_Hash_Pair_Pool<string, Variant>` | `TDictionary<string, Variant>` |
| `TListString` | `TBigList<string>` 或 `TList<string>` | `TList<string>` |
| `TListPascalString` | `TBigList<TPascalString>` | `TList<TPascalString>` |
| `TBackcall_Pool` | 自定义事件列表或 `TMulticastEvent`（如使用 Spring4D） | 使用 `TNotifyEvent` 列表 |

**迁移示例**（`THashObjectList` → `TBig_Hash_Pair_Pool`）：

```pascal
// 旧代码
var
  Old: THashObjectList;
begin
  Old := THashObjectList.Create(True);
  Old.Add('key', TMyObject.Create);
  Obj := Old['key'];
end;

// 新代码
uses Z.Core;
type
  TMyObjectPool = TBig_Hash_Pair_Pool<string, TObject>;
var
  NewPool: TMyObjectPool;
begin
  NewPool := TMyObjectPool.Create(1024);
  NewPool.Add('key', TMyObject.Create, False);
  Obj := NewPool['key'];
  // 自动释放需自行处理，或使用 TBig_Hash_Object_Pool
end;
```

**注意**：泛型容器不保留插入顺序，如需顺序可用 `TBigList` 的列表结构。另外，`AutoFreeObject` 功能需要自己管理对象生命周期（或在 `TBig_Hash_Object_Pool` 中设置 `AutoFree`）。

---

## 7. 总结

`Z.ListEngine` 虽然已被泛型容器替代，但它曾是 Z‑framework 的基石，见证了 Pascal 泛型普及前的历史。对于仍在使用它的老项目，本指南提供了全面的 API 说明和最佳实践。然而，对于新项目，**请务必使用现代泛型容器**，它们更安全、更简洁、性能更好。

如果你需要更详细的某个类的用法，请参考单元源码中的注释和实现，那里有丰富的内联文档。
