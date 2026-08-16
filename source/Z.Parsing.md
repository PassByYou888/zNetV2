# 让文本解析变得无比简单：Z.Parsing 库正式登场！

在浩瀚的编程世界里，文本解析是一项基础却往往让人头疼的工作。你是否有过这样的经历？

- 想从一段 Pascal 代码里提取所有 `uses` 的单元名，却被注释、字符串、换行搞得焦头烂额？
- 想实现一个简单的表达式计算器，却要手写一个完整的递归下降解析器，还得处理运算符优先级？
- 想写一个代码重构工具，却发现自己被 `//`、`{ }`、`(* *)` 三种注释风格绕晕？

如果你点头了，那么 **Z.Parsing** 就是为你量身打造的救星！

---

## 🚀 Z.Parsing 是什么？

`Z.Parsing` 是 **Z-framework** 中的核心词法分析单元，它不是一个需要你学习复杂语法文件的“编译器生成器”，而是一个**开箱即用的、高性能的、跨平台的文本解析库**。

你只需要把源码丢给它，它就能瞬间完成词法分析，把文本变成结构化的 **Token 流**，并提供一套优雅的 **“语义探针”** 方法，让你像查数据库一样搜索代码。

**一句话概括：把“解析”变成“检索”。**

---

## 🤔 为什么你需要 Z.Parsing？

### 传统解析的“三座大山”

1. **手写状态机**：要区分数字、标识符、字符串，你得写一大堆 `case` 和 `if`，代码又臭又长。
2. **注释与字符串的噩梦**：遇到 `//` 要跳过一行，遇到 `{` 要找匹配的 `}`，稍不留神就索引越界。
3. **前瞻与回退**：想“偷看”下一个词法单元？你得手动保存和恢复位置指针，容易出错。

### Z.Parsing 的降维打击

- **零词法代码**：你不用写一行 `IsDigit` 或 `SkipComment`，所有脏活累活都封装在库内部。
- **语义级探针**：`ProbeR(0, [ttAscii], 'uses')` 一行代码，直接找到 `uses` 关键字，无视注释和字符串干扰。
- **内置字符串转义处理**：`GetTextBody` 方法轻松解开 Pascal 的 `''Hello''` 和 C 的 `\n`，不用手写状态机。

---

## ✨ 核心亮点

### 🎯 多风格支持
内置三种解析模式：
- **tsPascal**：支持 `{}`、`(* *)`、`//` 注释，单引号字符串，`#` 编码字符。
- **tsC**：支持 `/* */`、`//` 注释，双引号字符串，反斜杠转义。
- **tsText**：纯文本模式，不作任何特殊处理。

### 🗂️ 智能缓存
解析结果被完整缓存，包括注释区间、字符串区间、Token 列表，以及**字符到 Token 的映射表**。后续查询都是 O(1) 或 O(log n) 的复杂度，极速响应。

### 🔍 语义探针系统
- `TokenProbeL` / `TokenProbeR`：向左或向右搜索指定类型或文本的 Token。
- `IndentSymbolEndProbeR`：自动匹配嵌套的括号、方括号，无需手写栈。
- `StringProbe`：按前缀搜索 Token，方便做代码补全。

### 📦 向量与矩阵提取
一行代码即可提取逗号分隔的表达式列表，自动处理括号嵌套。配合 `Z.Expression`，可直接进行数值计算。

### 🔄 字符串与注释转换
内置 Pascal ↔ C 风格的字符串字面量和注释双向转换，轻松处理跨语言迁移。

### ✏️ 文本编辑支持
修改 Token 内容后，调用 `RebuildToken` 即可更新源文本，非常适合代码重构工具。

---

## 📝 一分钟上手示例

下面是一个真实的代码依赖分析器，提取 `uses` 子句中的单元名，并解析 `in 'File.pas'` 中的文件名：

```pascal
uses Z.Core, Z.PascalStrings, Z.UPascalStrings, Z.Parsing, Z.UnicodeMixedLib;

function ExtractUsesDependencies(SourceCode: U_String): TPascalStringList;
var
  Parser: TTextParsing;
  i: Integer;
  CurrentToken, NextToken: PTokenData;
  UnitName, InFile: U_String;
begin
  Result := TPascalStringList.Create;
  Parser := TTextParsing.Create(SourceCode, tsPascal);
  try
    // 直接定位 uses 关键字
    CurrentToken := Parser.ProbeR(0, [ttAscii], 'uses');
    if CurrentToken = nil then Exit;

    i := CurrentToken^.Index + 1;
    while i < Parser.TokenCount do
    begin
      CurrentToken := Parser.Tokens[i];
      if (CurrentToken^.tokenType = ttSymbol) and (CurrentToken^.Text = ';') then
        Break;

      if CurrentToken^.tokenType = ttAscii then
      begin
        UnitName := CurrentToken^.Text;
        InFile := '';
        NextToken := Parser.Tokens[i + 1];
        if (NextToken <> nil) and (NextToken^.Text.Same('in')) then
        begin
          NextToken := Parser.Tokens[i + 2];
          if (NextToken <> nil) and (NextToken^.tokenType = ttTextDecl) then
          begin
            InFile := Parser.GetTextBody(NextToken^.Text); // 自动去除引号和转义
            InFile := umlCombineFileName(ExtractFilePath(ParamStr(0)), InFile);
            Inc(i, 3);
            Continue;
          end;
        end;
        Result.Add(UnitName + ' -> ' + InFile);
      end;
      Inc(i);
    end;
  finally
    Parser.Free;
  end;
end;
```

**没有手写状态机，没有注释跳过逻辑，一切都在直观的 Token 操作中完成！**

---

## 🌍 适用场景

- **代码分析工具**：提取依赖、统计符号、生成文档。
- **代码重构工具**：批量重命名标识符，统一代码风格。
- **表达式计算器**：配合 `Z.Expression`，直接支持用户输入的数学公式。
- **配置文件解析器**：处理 Pascal/C 风格的配置语法。
- **IDE 插件**：实现语法高亮、括号匹配、代码折叠。
- **数据格式转换**：将一种语言的字符串/注释风格转换为另一种。

---

## 🔧 与 Flex/Bison、ANTLR 的定位差异

很多人问我：“Z.Parsing 和 Flex/Bison 比怎么样？”

答案很明确：**它们解决不同层级的问题。**

| 工具 | 定位 | 使用方式 | 适用场景 |
| :--- | :--- | :--- | :--- |
| **Flex/Bison** | 词法/语法分析器生成器 | 编写 `.l` / `.y` 规则文件，生成 C 代码 | 需要**极致性能**和**完全定制语法**的编译器项目 |
| **ANTLR** | 词法/语法分析器生成器 | 编写 `.g4` 语法文件，生成多语言代码 | 复杂语言、DSL 的解析，要求**可读性好**、**调试方便** |
| **Z.Parsing** | **开箱即用的词法分析库** | 直接创建对象，调用 API | **应用程序内**的文本解析、代码分析、表达式求值，追求**开发效率**和**集成简便性** |

**Z.Parsing 不是要取代这些工业级工具，而是在“应用级文本解析”领域，提供一种更轻量、更快捷的解决方案。** 你不必为了解析一个 `uses` 子句而搭建一整套 Flex/Bison 环境。

---

## 💡 结语

Z.Parsing 是 Z-framework 为所有需要文本处理的开发者献上的一份礼物。它凝聚了多年的工程经验，将繁琐的词法分析封装为优雅的 API，让你专注于真正的业务逻辑。

如果你正为手写解析器而烦恼，或者想快速为你的应用添加强大的文本处理能力，不妨试试 Z.Parsing。你会发现，原来解析代码可以如此简单！

---

**Let’s parse the world, one token at a time!**
