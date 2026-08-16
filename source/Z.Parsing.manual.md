# Z.Parsing 使用指南：从词法分析到语义探针

## 1. 引言：词法分析在编译原理中的位置

在计算机科学中，**词法分析（Lexical Analysis）** 是编译原理前端的第一个阶段。它的任务是将源代码的字符流转换为有意义的记号序列（**Token**）。词法分析器（Lexer / Scanner）通常基于**正则文法**（Regular Grammar）和**有限状态自动机（DFA）** 实现，是编译器中最为成熟和标准化的部分。

经典的词法分析器生成器（如 **Flex**）要求开发者定义一组正则表达式规则，然后自动生成对应的 C 代码。然而，在许多应用场景（如代码重构、静态分析、表达式求值）中，我们并不需要构建完整的编译器，而是需要一个**可直接使用的、高效的、易于集成的词法分析库**。

**Z.Parsing** 正是为此而生。它不是生成器，而是一个**预置了 Pascal 和 C 风格语法的词法分析器，并扩展了语义级查询和文本编辑能力**的库。它使得开发者无需掌握复杂的编译器构造理论，也能轻松完成专业的文本解析任务。

---

## 2. 核心概念

### 2.1 Token（记号）

Token 是词法分析的最小单元。在 Z.Parsing 中，每个 Token 由以下信息描述：

```pascal
TTokenData = record
  bPos, ePos: Integer;     // 在源文本中的起始位置（1‑based）和结束位置（exclusive）
  Text: TP_String;         // Token 的文本内容
  tokenType: TTokenType;   // 类型（如 ttNumber, ttAscii）
  Index: Integer;          // 在 Token 列表中的序号
end;
```

### 2.2 Token 类型（TTokenType）

Z.Parsing 定义了以下 Token 类型：

| 类型 | 含义 | 示例（Pascal 风格） |
| :--- | :--- | :--- |
| `ttTextDecl` | 字符串字面量 | `'Hello'`, `#65#66`, `"World"` (C风格) |
| `ttComment` | 注释 | `{ comment }`, `// line`, `(* comment *)`, `/* comment */` |
| `ttNumber` | 数值 | `123`, `3.14`, `$FF`, `0xABCD` |
| `ttSymbol` | 单字符符号 | `+`, `-`, `*`, `/`, `(`, `)` |
| `ttAscii` | 标识符（字母数字及下划线） | `variable`, `TForm1`, `sin` |
| `ttSpecialSymbol` | 多字符特殊符号 | `:=`, `>=`, `<<`, `->` |
| `ttUnknow` | 未识别字符（通常不应出现） | |

### 2.3 解析风格（TTextStyle）

Z.Parsing 支持三种解析风格：

- **tsPascal**：识别 `{}`、`(* *)`、`//` 注释，单引号字符串，`#` 编码字符（如 `#65`），`$` 十六进制。
- **tsC**：识别 `/* */`、`//` 注释，双引号字符串，反斜杠转义（`\n`、`\t` 等），`0x` 十六进制。
- **tsText**：纯文本模式，不识别任何注释、字符串或特殊符号，每个字符作为独立的 Token 或合并为标识符。

### 2.4 缓存系统（TTextParsingCache）

Z.Parsing 在解析时会构建以下缓存结构：

- `CommentDecls`：所有注释区间的列表（有序）。
- `TextDecls`：所有字符串字面量区间的列表（有序）。
- `TokenDataList`：所有 Token 的列表（按源顺序）。
- `CharToken`：一个数组，长度为源文本长度，每个元素指向该位置所属的 Token 指针（若属于某个 Token）。**这使得 O(1) 的定位成为可能**。

缓存构建在构造函数中自动完成（`RebuildParsingCache`），后续的查询和修改操作都基于缓存进行，性能极高。

---

## 3. 架构与设计精髓

### 3.1 扁平 Token 流与语义探针

Z.Parsing 产生的 Token 流是**扁平的**（Flat），即不包含嵌套结构。它只负责识别词法单元，而不处理语法结构（如括号匹配、运算符优先级）。**这与 Flex 的输出类似**。

在此基础上，Z.Parsing 提供了一套**语义探针（Semantic Probe）** 方法，允许用户在 Token 流上进行高效的搜索：

- 按 Token 类型过滤（`[ttAscii]`）
- 按 Token 文本匹配（支持忽略大小写）
- 组合条件（类型 + 文本）
- 方向控制（向左搜索 `ProbeL`，向右搜索 `ProbeR`）
- 嵌套括号匹配（`IndentSymbolEndProbeR`）

这些探针方法封装了常见的遍历逻辑，让开发者无需手动维护循环和边界条件。

### 3.2 增量更新与编辑

通过 `RebuildText` 和 `RebuildToken` 方法，Z.Parsing 支持对源文本进行局部修改后的缓存刷新：

- **修改注释/字符串内容**：直接修改 `TTextPos` 中的 `Text` 字段，然后调用 `RebuildText`。
- **修改 Token 内容**：修改 `TTokenData` 中的 `Text` 字段，然后调用 `RebuildToken`。

这种设计使得代码重构工具能够高效地执行替换操作，而无需每次都重新解析整个文件。

### 3.3 字符串与注释转换

Z.Parsing 提供了类方法，用于在不同风格的字符串/注释之间进行转换：

- `Translate_Pascal_Decl_To_Text`：将 Pascal 字符串字面量转换为纯文本。
- `Translate_Text_To_Pascal_Decl`：将纯文本编码为 Pascal 字符串字面量。
- `Translate_C_Decl_To_Text` / `Translate_Text_To_C_Decl`：C 风格的对应版本。
- 注释转换：`Translate_Pascal_Decl_Comment_To_Text` 等。

这些转换器正确处理了转义字符、引号、换行等，极大简化了跨语言迁移工具的开发。

---

## 4. 安装与快速开始

### 4.1 环境要求

- **Delphi**：支持 XE 及以上版本（推荐 10.3+）
- **Free Pascal**：支持 3.0.0 及以上版本（推荐 3.2.0+）
- **操作系统**：Windows、Linux、macOS、iOS、Android、BSD

### 4.2 添加单元引用

在你的项目中，使用以下 uses 子句引入所需单元：

```pascal
uses
  Z.Core,                // 基础核心库（包含 TCore_Object 等）
  Z.PascalStrings,       // 高性能字符串类型 TPascalString
  Z.UPascalStrings,      // Unicode 字符串类型 TUPascalString
  Z.Parsing;             // 词法分析与解析主单元
```

### 4.3 第一个程序：解析并输出所有标识符

下面是一个完整的控制台程序，它读取一个 Pascal 源文件，输出所有标识符（`ttAscii`）及其在源代码中的位置。

```pascal
program ListIdentifiers;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Z.Core,
  Z.PascalStrings,
  Z.UPascalStrings,
  Z.Parsing,
  Z.UnicodeMixedLib;

var
  Source: U_String;
  Parser: TTextParsing;
  i: Integer;
  Token: PTokenData;
begin
  if ParamCount < 1 then
  begin
    Writeln('Usage: ListIdentifiers <pascal_source_file>');
    Halt(1);
  end;

  Source := umlStringFromFile(ParamStr(1));
  if Source = '' then
  begin
    Writeln('Failed to read file: ', ParamStr(1));
    Halt(1);
  end;

  // 1. 创建解析器（采用 Pascal 风格）
  Parser := TTextParsing.Create(Source, tsPascal);
  try
    // 2. 遍历 Token 列表
    for i := 0 to Parser.TokenCount - 1 do
    begin
      Token := Parser.Tokens[i];
      if Token^.tokenType = ttAscii then
      begin
        // 3. 输出标识符及其位置（行列号）
        Writeln(Format('[%d:%d] %s',
          [Parser.GetPoint(Token^.bPos).Y,   // 行号（1-based）
           Parser.GetPoint(Token^.bPos).X,   // 列号（1-based）
           Token^.Text.Text]));
      end;
    end;
  finally
    Parser.Free;
  end;

  Readln;
end.
```

**说明**：
- `umlStringFromFile` 是 Z.UnicodeMixedLib 提供的便捷函数，可自动检测文件编码并加载为 `U_String`。
- `Parser.GetPoint` 将字符位置转换为 `TPoint`（`X`=列，`Y`=行），便于呈现给用户。

---

## 5. 深入 API：探针、提取与编辑

### 5.1 探针（Probing）

探针是 Z.Parsing 最强大的功能之一，它让你能以声明式方式在 Token 流中定位特定元素。

#### 5.1.1 基础探针

```pascal
// 从索引0开始，向右搜索第一个标识符（ttAscii）
Token := Parser.ProbeR(0, [ttAscii]);

// 从索引10开始，向左搜索第一个 '+' 或 '-' 符号
Token := Parser.ProbeL(10, [ttSymbol], '+', '-');

// 搜索特定的单词（忽略大小写），仅限标识符类型
Token := Parser.ProbeR(0, [ttAscii], 'begin');
```

#### 5.1.2 嵌套括号匹配

```pascal
// 假设我们找到了一个左括号 '(' 的 Token
OpenParen := Parser.ProbeR(0, [ttSymbol], '(');
if OpenParen <> nil then
begin
  // 找到与之匹配的右括号 ')'（自动处理嵌套）
  CloseParen := Parser.IndentSymbolEndProbeR(OpenParen^.Index, '(', ')');
  if CloseParen <> nil then
    Writeln('Matched pair: ', OpenParen^.Index, ' -> ', CloseParen^.Index);
end;
```

**工作原理**：`IndentSymbolEndProbeR` 维护一个计数器，遇到左括号 +1，右括号 -1，当计数器归零时即为匹配位置。

#### 5.1.3 按前缀搜索（用于代码补全）

```pascal
// 在当前位置之后搜索以 'T' 开头的标识符
Token := Parser.StringProbe(CurrentIndex, [ttAscii], 'T');
```

### 5.2 向量提取（Vector Extraction）

当你需要提取逗号分隔的列表（如函数参数、数组元素）时，`Extract_Symbol_Vector` 是你的首选。

```pascal
var
  Vec: TSymbolVector;
begin
  // 解析表达式列表，自动忽略括号内的逗号
  Vec := Parser.Extract_Symbol_Vector;
  for i := 0 to High(Vec) do
    Writeln('Element ', i, ': ', Vec[i].Text);
end;
```

**示例**：对于文本 `"a, (b, c), d"`，返回的向量包含三个元素：`"a"`, `"(b, c)"`, `"d"`。括号内的逗号不会被误当作顶层分隔符。

### 5.3 文本编辑与缓存更新

#### 5.3.1 删除一段文本

```pascal
// 删除从 bPos 到 ePos-1 的字符
Parser.DeletePos(bPos, ePos);
// 或使用 TTextPos 结构
Parser.DeletePos(TextPos);
```

#### 5.3.2 插入文本

```pascal
// 在 bPos 处插入文本，并删除 ePos 之前的旧内容（替换）
Parser.InsertTextBlock(bPos, ePos, 'new text');
```

#### 5.3.3 修改 Token 后重建

```pascal
// 将所有标识符 'foo' 替换为 'bar'
for i := 0 to Parser.TokenCount - 1 do
begin
  Token := Parser.Tokens[i];
  if (Token^.tokenType = ttAscii) and (Token^.Text.Same('foo')) then
    Token^.Text := 'bar';
end;
// 从 Token 列表重建源文本，并刷新缓存
Parser.RebuildToken;
// 现在 Parser.Text 已更新为替换后的内容
```

### 5.4 字符串与注释转换（类方法）

这些方法无需实例化 `TTextParsing`，可直接调用：

```pascal
var
  Plain, Decl: TP_String;
begin
  // Pascal 字符串 → 纯文本
  Plain := TTextParsing.Translate_Pascal_Decl_To_Text('''Hello,'+#10+'World''');
  // Plain = 'Hello,'#10'World'

  // 纯文本 → Pascal 字符串字面量
  Decl := TTextParsing.Translate_Text_To_Pascal_Decl('Hello'#10'World');
  // Decl = '''Hello,''#10''World'''

  // C 字符串 → 纯文本
  Plain := TTextParsing.Translate_C_Decl_To_Text('"Hello\nWorld"');
  // Plain = 'Hello'#10'World'

  // 纯文本 → C 字符串字面量
  Decl := TTextParsing.Translate_Text_To_C_Decl('Hello'#10'World');
  // Decl = '"Hello\\nWorld"'
end;
```

注释转换类似，例如 `Translate_Pascal_Decl_Comment_To_Text` 会去除 `{ }` 或 `(* *)` 外衣，提取纯文本。

---

## 6. 实战案例

### 6.1 案例1：提取单元依赖关系（Uses Clause Parser）

我们在引言中已经展示了一个完整的函数，现在补充完整示例，包括如何处理 `in` 子句和路径转换。

```pascal
uses
  Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Parsing, Z.UnicodeMixedLib;

type
  TDependency = record
    UnitName: U_String;
    FileName: U_String;  // 如果指定了 'in'，则包含路径
  end;
  TDependencyList = array of TDependency;

function ExtractUsesDependencies(const Source: U_String; const BasePath: U_String): TDependencyList;
var
  Parser: TTextParsing;
  i: Integer;
  Token, NextToken: PTokenData;
  Dep: TDependency;
begin
  Result := nil;
  Parser := TTextParsing.Create(Source, tsPascal);
  try
    Token := Parser.ProbeR(0, [ttAscii], 'uses');
    if Token = nil then Exit;

    i := Token^.Index + 1;
    while i < Parser.TokenCount do
    begin
      Token := Parser.Tokens[i];
      if (Token^.tokenType = ttSymbol) and (Token^.Text = ';') then
        Break;

      if Token^.tokenType = ttAscii then
      begin
        Dep.UnitName := Token^.Text;
        Dep.FileName := '';

        // 检查是否有 'in' 子句
        NextToken := Parser.Tokens[i + 1];
        if (NextToken <> nil) and (NextToken^.tokenType = ttAscii) and
           (NextToken^.Text.Same('in')) then
        begin
          NextToken := Parser.Tokens[i + 2];
          if (NextToken <> nil) and (NextToken^.tokenType = ttTextDecl) then
          begin
            Dep.FileName := Parser.GetTextBody(NextToken^.Text);
            // 转换为绝对路径
            Dep.FileName := umlCombineFileName(BasePath, Dep.FileName);
            Inc(i, 3);
            SetLength(Result, Length(Result) + 1);
            Result[High(Result)] := Dep;
            Continue;
          end;
        end;

        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Dep;
      end;
      Inc(i);
    end;
  finally
    Parser.Free;
  end;
end;
```

### 6.2 案例2：批量重命名标识符（重构工具）

以下示例遍历所有标识符，将 `OldName` 替换为 `NewName`，并保持注释和字符串中的内容不变（因为 `ttAscii` 不包括它们）。

```pascal
function RenameIdentifier(const Source: U_String; const OldName, NewName: U_String): U_String;
var
  Parser: TTextParsing;
  i: Integer;
  Token: PTokenData;
begin
  Parser := TTextParsing.Create(Source, tsPascal);
  try
    for i := 0 to Parser.TokenCount - 1 do
    begin
      Token := Parser.Tokens[i];
      if (Token^.tokenType = ttAscii) and (Token^.Text.Same(OldName)) then
        Token^.Text := NewName;
    end;
    Parser.RebuildToken;
    Result := Parser.Text;
  finally
    Parser.Free;
  end;
end;
```

**注意**：该操作仅替换标识符 Token，不会影响字符串字面量和注释中出现的同名文本，正是我们期望的行为。

### 6.3 案例3：从 Pascal 代码中提取所有字符串字面量

```pascal
function ExtractStringLiterals(const Source: U_String): TArrayPascalString;
var
  Parser: TTextParsing;
  i: Integer;
  Token: PTokenData;
begin
  Result := nil;
  Parser := TTextParsing.Create(Source, tsPascal);
  try
    for i := 0 to Parser.TokenCount - 1 do
    begin
      Token := Parser.Tokens[i];
      if Token^.tokenType = ttTextDecl then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Parser.GetTextBody(Token^.Text); // 转换为纯文本
      end;
    end;
  finally
    Parser.Free;
  end;
end;
```

---

## 7. 性能与最佳实践

### 7.1 性能特征

- **解析阶段**：`TTextParsing.Create` 执行完整的词法分析，时间复杂度为 O(n)，其中 n 为源文本字符数。
- **缓存占用**：`CharToken` 数组大小为 n，每个元素为指针（4/8 字节），因此内存开销约为 4n ~ 8n 字节。对于 1MB 的文本，额外内存约 4~8MB，通常可接受。
- **查询操作**：`TokenPos[cOffset]` 为 O(1)，`ProbeL/R` 在最坏情况下为 O(k)，其中 k 为搜索范围内 Token 的数量。但平均情况下，由于探针往往从当前位置附近开始，性能良好。
- **二分查找**：在 `GetTextDeclPos` 和 `GetCommentPos` 中使用了二分查找，复杂度为 O(log m)，其中 m 为区间数量。

### 7.2 最佳实践

1. **尽量重用解析器实例**：如果需要对同一份文本进行多次不同查询，应保持解析器存活，重复使用其缓存。
2. **批量修改后统一重建**：若需修改多个 Token，应在所有修改完成后调用一次 `RebuildToken`，避免多次重建开销。
3. **注意文本长度**：对于超大文本（> 100 MB），`CharToken` 数组的内存开销可能过高，此时可考虑使用流式处理或按块解析。
4. **使用 `FastRebuildTokenTo` 避免修改原文本**：当你只需获取修改后的文本而不需要更新解析器内部状态时，使用此方法更轻量。
5. **优先使用探针而非手动循环**：探针方法内部已经优化，并考虑了边界条件，更安全且代码更短。

---

## 8. 与其他库的协同工作

- **Z.Core**：提供基础类型、线程安全容器、内存管理等基础设施。
- **Z.PascalStrings / Z.UPascalStrings**：提供了 `TP_String` 和 `U_String`，是 Z.Parsing 处理文本的基础。
- **Z.Expression**：基于 Z.Parsing 的 Token 流，实现了完整的表达式解析与求值，可处理运算符优先级、函数调用等。
- **Z.Pascal_Code_Tool**：利用 Z.Parsing 实现批量代码重构、单元重命名、包含文件处理等功能。

---

## 9. 总结

Z.Parsing 是一个 **实用主义** 的词法分析库。它不追求覆盖所有编译原理理论，而是聚焦于 **解决实际文本处理问题**。通过将词法分析与语义探针、文本编辑、转换工具融为一体，它极大地降低了开发者在处理源代码或结构化文本时的门槛。

无论你是想构建一个代码分析工具、实现一个自定义 DSL 的解析器，还是仅仅需要从代码中提取信息，Z.Parsing 都提供了可靠、高效且易于使用的解决方案。

**接下来，你可以：**
- 阅读 `Z.Parsing` 单元源码，深入理解缓存构建细节。
- 探索 `Z.Expression`，了解如何基于 Token 流构建语法分析器。
- 尝试编写自己的探针函数，或者扩展 `SpecialSymbol` 以支持更多多字符操作符。

**让解析变得简单，让代码触手可及。**
