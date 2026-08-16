# Z.Parsing → Z.Expression → Z.OpCode：从文本到执行的全链路深度分析

Z-framework 的表达式引擎并非一个“大泥球”，而是由三个职责清晰、配合紧密的模块构成的流水线：**词法分析**（`Z.Parsing`）、**语法分析与中间表示**（`Z.Expression`）、**执行引擎**（`Z.OpCode`）。这条链路的设计吸收了编译原理的经典思想，同时又针对动态表达式求值场景做了高度优化，使得我们可以从一句 `sin(x) * 10 + 5` 这样的字符串，一路走到高效、可缓存、甚至支持异步恢复的执行流程。

---

## 1. 词法分析：Z.Parsing —— 将源码变成结构化的 Token 流

### 1.1 缓存驱动的设计哲学

`TTextParsing` 在构造时立即调用 `RebuildParsingCache`，完成对源文本的完整扫描，并构建三个核心缓存：

- **注释与字符串区间列表** (`CommentDecls` / `TextDecls`)：有序数组，用于后续 O(log n) 的定位。
- **Token 列表** (`TokenDataList`)：按源码顺序存放所有 Token，每个 Token 包含起止位置、类型、文本内容。
- **字符→Token 映射表** (`CharToken`)：长度为文本字符数的数组，每个元素指向所属 Token。这实现了 **O(1) 的随机访问**，对后续语法分析中根据字符位置反查 Token 极其高效。

### 1.2 Token 化的具体流程

`RebuildParsingCache` 的工作过程可概括为两遍扫描：

1. **第一遍：确定所有注释和字符串区间**  
   从左到右，调用 `CompareCommentGetEndPos` 和 `CompareTextDeclGetEndPos`，这些函数会识别 `//`、`{`、`(*`、`/*`、`'`、`"`、`#` 等边界，并返回结束位置。这一步独立于 Token 化，确保在后续识别过程中可以轻易跳过这些区域。

2. **第二遍：生成 Token**  
   再次从左到右，对于每个尚未跳过的位置，按优先级尝试匹配：
   - 多字符特殊符号（`SpecialSymbol` 列表，支持贪婪匹配）
   - 字符串字面量
   - 注释
   - 数字（支持十进制、十六进制、科学计数法）
   - 单字符符号（`SymbolTable` 中的字符）
   - 标识符（`ttAscii`）
   - 其他字符合并为 `ttUnknow`

   每生成一个 Token，记录起止位置、类型、文本，并填入 `CharToken` 映射。

### 1.3 对上层应用提供的接口

`Z.Expression` 主要依赖以下能力：
- `TokenPos[cOffset]` 快速获取某个字符位置所在的 Token。
- `GetStr(bPos, ePos)` 获取子串。
- `GetTextBody` 将 Pascal 或 C 风格的字符串字面量还原为纯文本（去除引号、处理转义）。
- 探针方法（`ProbeL/R`）允许在 Token 流上按类型或内容进行搜索，但 `Z.Expression` 实际上没有大量使用探针，因为它需要完整地遍历所有 Token 来构建符号表。

---

## 2. 语法分析与中间表示：Z.Expression —— 从 Token 到符号表达式

`Z.Expression` 承担了词法分析之后的所有工作：**解析、优先级处理、AST 构建**。它没有使用传统的 YACC/ANTLR 式文法生成器，而是采用**手写的递归下降解析器**，配合**优先级爬升（Pratt Parsing）** 的变体来处理运算符优先级。

### 2.1 中间表示：TSymbolExpression

`TSymbolExpression` 是连接解析器和代码生成器的核心数据结构，它本质上是一个**扁平列表**，每个元素（`TExpressionListData`）可以是：
- 一个符号（运算符、括号、逗号等）
- 一个字面量（数值、字符串、布尔值）
- 一个函数标识符（`edtProcExp`），附带一个子 `TSymbolExpression` 作为参数列表
- 一个子表达式（`edtExpressionAsValue`），用于表示括号括起来的表达式或函数参数分组

**关键设计**：`TSymbolExpression` 在初始构造时是**扁平的**（所有 Token 按顺序排列），但内部可以通过 `Expression` 字段指向子表达式，形成初步的层次结构（例如函数调用的参数）。

### 2.2 解析流程：`ParseTextExpressionAsSymbol__`

这个函数是解析的入口，它接收一个 `TTextParsing` 实例，然后遍历其 Token 流，构建扁平的 `TSymbolExpression`。

解析过程采用**状态机**（`TExpressionParsingState`）来控制期望：
- `esFirst`：期望一个值（字面量、标识符或括号）
- `esWaitValue`：期望一个值
- `esWaitOp`：期望一个运算符或分隔符
- `esWaitIndentEnd` / `esWaitPropParamIndentEnd`：用于匹配括号或方括号

在遍历过程中：
1. 遇到数字、字符串、标识符（非关键字）时，直接添加为字面量或函数标识符（`edtProcExp`）。
2. 遇到 `(` 或 `[` 时，增加缩进计数，并添加对应的开始符号。
3. 遇到 `)` 或 `]` 时，减少缩进计数，并添加结束符号。
4. 遇到运算符（`+`、`-`、`*`、`/`、`=`、`>` 等）时，添加为 `edtSymbol`。
5. 遇到逗号时，添加 `soCommaSymbol`。

**关键点**：此时并没有处理运算符优先级，也没有处理函数调用的参数列表嵌套——这些都留到后续的“重构”阶段。

### 2.3 优先级与括号重构：`RebuildAllSymbol`

解析得到的扁平符号列表包含所有括号和运算符，但尚未体现优先级。`RebuildAllSymbol` 的作用就是**将扁平的列表转化为真正的 AST 树**。它分两步：

#### 2.3.1 括号匹配与参数分组：`ProcessIndent`

- 遍历列表，遇到 `(` 或 `[` 时，递归调用 `ProcessIndent` 处理其内部内容，然后将返回的子表达式包装为一个 `edtExpressionAsValue` 节点，并挂载到当前节点。
- 遇到 `)` 或 `]` 时，结束当前递归。
- 函数调用（`edtProcExp`）后紧跟括号时，将该括号内的子表达式作为函数的参数列表（每个参数也是一个 `TSymbolExpression`）。

这一步之后，嵌套结构和函数参数已经被正确拆分，但运算符优先级仍由左到右顺序决定。

#### 2.3.2 优先级重组：`RebuildLogicalPrioritySymbol`

该函数基于**运算符优先级表**（`SymbolOperationPriority`，从低到高分为 5 级：`and`, `or/xor`, 比较, 加减, 乘除/移位/幂），在符号列表中插入虚拟括号来强制运算顺序。

算法采用**类 Pratt 解析**的递归过程：
- 从第一个值开始，向右扫描，记录当前运算符和上一个运算符的优先级。
- 当发现当前运算符优先级高于上一个运算符时，将之前的部分作为一个子表达式入栈，然后递归处理更高优先级的后续部分。
- 当优先级降低时，结束当前子表达式并弹出。

具体实现中，`ProcessSymbol` 函数负责处理一个符号及其后续内容，通过比较 `SymbolPriority` 来决定是否要插入 `soBlockIndentBegin` 和 `soBlockIndentEnd`。经过这一转换，原来的扁平列表变为一个**完全括号化的表达式**，每个二元运算都成为一个 `edtExpressionAsValue` 节点（但其 `Symbol` 保存了具体的运算符）。

最终，`RebuildAllSymbol` 返回的 `TSymbolExpression` 已经完全是一棵层次化的 AST，根节点可以是任意表达式，函数调用节点的参数也已经作为独立子树挂载。

---

## 3. 代码生成：Z.Expression.BuildAsOpCode —— 从 AST 到可执行 OpCode

`TSymbolExpression` 仍然是平台无关的符号结构，`BuildAsOpCode` 将其转换为 `TOpCode` 对象树，这是 Z.OpCode 的底层执行单元。

### 3.1 OpCode 类型体系

`TOpCode` 是抽象基类，每个具体子类（如 `op_Add`、`op_Mul`、`op_Proc`）实现 `DoExecute` 方法。所有 OpCode 都支持参数列表（可以是字面量或子 OpCode），形成**复合模式**（Composite Pattern）。执行时，父 OpCode 会递归计算所有参数的值，然后调用自己的 `DoExecute`。

`BuildAsOpCode` 的核心工作就是递归遍历 `TSymbolExpression` 的树结构，为每个节点创建对应的 OpCode 实例。

### 3.2 遍历策略：`ProcessIndent`

函数 `ProcessIndent`（在 `BuildAsOpCode` 中）递归遍历经过优先级重构后的符号树，根据节点类型创建不同 OpCode：

- **字面量节点**（`edtBool`, `edtInt`, `edtString` 等）：创建一个 `op_Value` 节点，并将字面量作为其第一个参数。
- **运算符节点**（`edtExpressionAsValue` 且 `Symbol` 是二元运算符）：创建对应的二元 OpCode（如 `op_Add`），然后递归处理左右子表达式，分别添加为参数。
- **前缀运算符**（如 `soAdd` 或 `soSub` 出现在表达式开头）：创建 `op_Add_Prefix` 或 `op_Sub_Prefix`，递归处理其操作数。
- **函数调用**（`edtProcExp`）：创建 `op_Proc`，将函数名作为第一个参数（字面量），然后递归处理每个参数表达式，添加为后续参数。

**关键优化**：`BuildAsOpCode` 使用一个临时 `TCore_ListForObj` 来收集所有创建的 OpCode，一旦构建成功，便将它们的 `AutoFreeLink` 设置为 `True`，确保在析构时自动释放子节点；若构建失败，则手动释放所有创建的对象，避免内存泄漏。

### 3.3 缓存集成

`BuildAsOpCode` 可以被 `OpCache` 调用（`OpCache.Add`），将编译好的 OpCode 树缓存起来，以便后续相同表达式直接返回克隆副本，跳过解析和构建步骤，显著提升重复求值性能。

---

## 4. 执行引擎：Z.OpCode —— 虚拟机的两种运行模式

### 4.1 同步递归执行（标准模式）

`TOpCode.OpCode_Execute` 方法是入口：
1. 调用 `OpCode_EvaluateParam`，递归地执行所有子 OpCode，将计算结果存入每个参数的 `Value` 字段。
2. 调用当前 OpCode 的 `DoExecute`，使用已计算好的参数值进行实际运算。
3. 返回结果。

这种模式简单、直接，适合计算密集型且无 I/O 等待的表达式。

### 4.2 非线性异步执行（TOpCode_NonLinear）

有些场景下，表达式中可能包含需要等待外部事件的操作（如延迟、网络请求）。普通递归执行会阻塞线程，无法满足非阻塞要求。`TOpCode_NonLinear` 通过**线性化递归树 + 暂停/恢复**机制解决了这个问题。

#### 4.2.1 线性化栈（Build_Stack）

`TOpCode_NonLinear` 在构造时调用 `Build_Stack`，对根 OpCode 进行**后序遍历**，将所有参数求值动作压入一个队列（`FStack___`）。这个队列记录了执行每个子 OpCode 的顺序，以及它们将结果写入哪个父节点参数。

#### 4.2.2 执行与暂停

- 调用 `Execute` 或 `Process` 时，从栈顶取出一个待执行的 OpCode，调用其 `DoExecute`，并将结果写入对应参数。
- 如果当前 OpCode 在执行过程中调用了 `NonLinear.Do_Begin`，则会设置 `FIs_Wait_End := True`，并立即返回，允许外部循环继续处理其他任务。
- 外部线程（或事件回调）在异步操作完成后调用 `NonLinear.Do_End(Result)`，将结果存入 `FEnd_Result`，然后下一次 `Process` 会继续从栈中弹出下一个 OpCode。
- 当栈空时，表示整个表达式执行完毕，触发 `On_Done` 回调。

#### 4.2.3 与表达式序列的协作

`Z.Expression.Sequence` 正是基于此机制，将多行表达式按顺序执行，每一行可以包含异步操作。`TExpression_Sequence_RunTime` 继承自 `TOpCustomRunTime`，允许自定义函数（如 `Delay`）调用 `Do_Begin` 并安排定时器，之后通过 `Do_End` 恢复。

---

## 5. 运行时上下文：TOpCustomRunTime 与函数注册

`TOpCustomRunTime` 是 OpCode 执行时的“环境”，它维护了一个函数名到实现（`TOpRTData`）的哈希表。`SystemOpRunTime` 是全局默认运行时，内置了大量数学、字符串、转换函数（由 `TOpSystemAPI` 注册）。

自定义运行时可以继承并注册自己的函数，实现特定领域的 DSL。函数支持三种回调风格（C、M、P）和三种执行模式（Direct、Sync、Post），以适应不同的线程模型。

---

## 6. 全流程总结：从字符串到结果

1. **输入**：表达式字符串 `"sin(x) + 10"`。
2. **词法分析**：`TTextParsing` 产生 Token 流 `[ttAscii:'sin', ttSymbol:'(', ttAscii:'x', ttSymbol:')', ttSymbol:'+', ttNumber:'10']`。
3. **解析**：`ParseTextExpressionAsSymbol` 构建扁平列表 `[edtProcExp:'sin', soBlockIndentBegin, edtAscii:'x', soBlockIndentEnd, soAdd, edtInt:10]`。
4. **重构**：`RebuildAllSymbol` 将函数调用和优先级处理为树结构：根是 `soAdd`，左子是 `edtProcExp`（其参数是 `edtAscii:'x'`），右子是 `edtInt:10`。
5. **代码生成**：`BuildAsOpCode` 生成 `op_Add` 实例，其两个参数分别是 `op_Proc`（函数名 "sin"，参数是 `op_Value` 包含变量 `x` 的引用）和 `op_Value`（字面量 10）。
6. **执行**：执行时，`op_Add` 先计算 `op_Proc`：在运行时中查找 "sin" 函数，执行它，再计算右参数 10，最后相加返回结果。

整个链路设计精巧、分工明确，且通过缓存和非线性扩展，既支持快速数值计算，也支持复杂的异步流程控制。这正是 Z-framework 在表达式求值领域能够兼顾性能与灵活性的根本原因。
