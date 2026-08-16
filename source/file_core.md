# Z-Framework 核心库速查手册（纯文本目录版）

本手册按模块分类组织，每个单元包含 **单元作用**、**依赖关系**、**导出符号**、**全局变量** 以及 **初始化/终结行为**。每个小节提供 **关键字**（便于搜索）和 **单元作用说明**。

---

## 1. 模块依赖总览（层级关系）

```
底层核心
├── Z.Core              (基础类型、线程池、原子操作、MT19937、链式容器)
├── Z.PascalStrings     (TPascalString – ANSI/系统编码字符串)
├── Z.UPascalStrings    (TUPascalString – Unicode字符串)
├── Z.Int128            (128位整数及变体支持)
├── Z.FPC.GenericList   (FPC泛型列表兼容层)
├── Z.ListEngine        (旧版非泛型集合，多数已被泛型替代)
└── Z.Status            (线程安全日志)

中间层 – 实用工具与算法
├── Z.UnicodeMixedLib   (文件IO、编码、Base64、MD5、CRC、路径操作、随机等)
├── Z.MemoryStream      (64位内存流及压缩/解压辅助)
├── Z.Compress          (Deflate / BRRC 压缩)
├── Z.LZ4_Pas           (LZ4 压缩)
├── Z.Snappy_Pas        (Snappy 压缩)
├── Z.MD5               (快速MD5，调用UnicodeMixedLib)
├── Z.AES               (AES加密核心)
├── Z.Cipher            (统一加密/哈希框架，整合AES、DES、Blowfish、SHA等)
├── Z.Parsing           (词法分析：Pascal/C/Text风格)
├── Z.Expression        (表达式解析与编译，依赖 Parsing + OpCode)
├── Z.OpCode            (虚拟机执行引擎)
├── Z.HashList.Templet  (泛型哈希表池)
├── Z.HashMinutes.Templet / Z.HashHours.Templet (时间分片哈希池)
├── Z.Matched.Templet   (双向匹配算法)
├── Z.IOThread          (IO任务队列/线程)
├── Z.Cadencer          (时间驱动动画/定时器)
├── Z.Notify            (延迟执行任务调度)
└── Z.Line2D.Templet    (2D画线模板)

几何与数学
├── Z.Geometry2D        (2D向量、多边形、碰撞、投影)
├── Z.Geometry.Low      (3D向量/矩阵/四元数/平面)
├── Z.Geometry3D        (强类型3D向量/矩阵/AABB)
├── Z.Geometry.Rotation (欧拉角解码/步进)
├── Z.BulletMovementEngine (子弹运动引擎)
└── Z.MovementEngine    (通用运动引擎)

数据容器与序列化
├── Z.DFE               (Data Frame Engine – 二进制序列化/JSON互转)
├── Z.Json              (JSON对象封装，依赖DFE或第三方)
├── Z.TextDataEngine    (INI风格文本配置引擎)
├── Z.Number            (动态命名变量系统，整合Expression)
├── Z.FragmentBuffer    (碎片缓冲区管理)
└── Z.LinearAction      (线性动作序列执行)

调试与性能
├── Z.Instance.Tool     (对象实例计数跟踪)
├── Z.MH, Z.MH1, Z.MH2, Z.MH3, Z.MH_ZDB (内存钩子，用于泄漏检测)
├── Z.Opti_Distance_D   (SSE优化双精度距离)
└── Z.Opti_Distance_S   (SSE优化单精度距离)

表达式高级执行
├── Z.Expression.Sequence (非阻塞表达式序列执行)
└── Z.UReplace          (Unicode批量替换)
```

---

## 底层核心

### Z.Core
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 框架基石：线程池（`TCompute`）、原子操作、自旋/临界区（`TCritical`）、高性能容器（`TBigList`, `TBig_Hash_Pair_Pool`）、MT19937 随机数、软同步、对象池、CPS 性能工具。 |
| **依赖** | `SysUtils`, `Classes`, `SyncObjs`, `Math`，以及 `Z.FPC.GenericList`（FPC）或 `System.Generics.Collections`（Delphi）。 |
| **导出类** | `TCritical`, `TCompute`, `TBigList<T>`, `TBig_Hash_Pair_Pool<TKey,TValue>`, `TOrderStruct<T>`, `TAtomVar<T>`, `TMT19937Random`, `TThreadPost`, `TSoft_Synchronize_Tool`。 |
| **导出函数** | `AtomInc/Dec`, `ParallelFor`, `CheckThreadSynchronize`, `GetTimeTick`, `DisposeObject`。 |
| **全局变量** | `Main_Thread`, `Main_Thread_ID`, `Boot_Thread`, `MainThreadProgress`；若启用 `Intermediate_Instance_Tool`，还有 `Instance_State_Tool`。 |
| **初始化** | 设置主线程引用，创建 `Main_Thread_Sync_Tool` 和 `MainThreadProgress`；若启用实例跟踪，创建 `Instance_State_Tool`。 |
| **终结** | 关闭调度线程（`Close_Core_Dispatch_Thread`），释放全局对象。 |
| **关键字** | 线程池, TCompute, 原子操作, TCritical, TBigList, MT19937, ParallelFor, 软同步, 对象池 |

### Z.PascalStrings
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 定义 `TPascalString` 记录（ANSI/系统编码），提供运算符重载、UTF-8/ANSI 转换、Smith-Waterman 算法、随机字符串生成、C 字符串指针处理。 |
| **依赖** | `Z.Core`。 |
| **导出类** | `TPascalString` 记录。 |
| **导出函数** | `SmithWatermanCompare`（多种重载），`CharIn`, `TextIs`, `RandomString`。 |
| **全局变量** | `MaxSmithWatermanMatrix`, `FirstCharPos` 常量。 |
| **初始化/终结** | 无。 |
| **关键字** | TPascalString, 字符串, UTF-8, ANSI, Smith-Waterman, 随机字符串, 运算符重载 |

### Z.UPascalStrings
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 定义 `TUPascalString` 记录（Unicode），与 `TPascalString` 类似但使用 `USystemChar`（UTF-16）。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`。 |
| **导出类** | `TUPascalString` 记录。 |
| **导出函数** | `USmithWatermanCompare`, `UCharIn`, `TextIs`, `RandomString`（Unicode 版本）。 |
| **全局变量** | `UMaxSmithWatermanMatrix`, `UFirstCharPos`。 |
| **初始化/终结** | 无。 |
| **关键字** | TUPascalString, Unicode, UTF-16, Smith-Waterman, USystemChar |

### Z.Int128
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 128 位有符号/无符号整数（`Int128`, `UInt128`），支持运算符重载、变体类型、原子操作辅助。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`。 |
| **导出类** | `Int128`, `UInt128`, `TAtomInt128`, `TAtomUInt128`。 |
| **导出函数** | `Max`/`Min`/`Clamp`/`InRange` 的 128 位重载。 |
| **全局变量** | `UInt128_VariantType`, `Int128_VariantType`（自定义变体类型对象）。 |
| **初始化** | 注册 `varType_UInt128` 和 `varType_Int128` 自定义变体类型。 |
| **终结** | 释放变体类型对象。 |
| **关键字** | Int128, UInt128, 变体, 128位整数, 运算符重载, 原子操作 |

### Z.FPC.GenericList
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 为 Free Pascal 提供泛型列表 `TGenericsList<T>`（兼容 Delphi 语法），并修复了旧版 FPC 的 `IndexOf` 问题。 |
| **依赖** | `fgl`（FPC RTL）。 |
| **导出类** | `TGenericsList<T>`。 |
| **初始化/终结** | 无。 |
| **关键字** | FPC, 泛型列表, TGenericsList, 兼容层 |

### Z.ListEngine
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 旧版非泛型集合库（保留兼容），包含 `THashList`, `THashObjectList`, `THashStringList`, `THashVariantList`, `TListString`, `TListPascalString` 等。**新代码请使用泛型版本**（`TBigList`, `TBig_Hash_Pair_Pool`）。 |
| **依赖** | `Z.Core`, `Z.FPC.GenericList`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Int128`。 |
| **导出类** | `THashList`, `THashObjectList`, `THashStringList`, `THashVariantList`, `TListString`, `TListPascalString`。 |
| **初始化/终结** | 无。 |
| **关键字** | THashList, 旧版集合, 非泛型, TListString, THashStringList |

### Z.Status
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 线程安全日志系统，支持消息队列、多钩子（C/M/P）、控制台输出、无换行累积。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`。 |
| **导出函数** | `DoStatus`, `DoStatusNoLn`, `AddDoStatusHook`, `DeleteDoStatusHook`, `CheckDoStatus`, `EnabledStatus`。 |
| **全局变量** | `OnDoStatusHook`（默认 `InternalDoStatus`）, `LastDoStatus`, `ConsoleOutput`, `StatusThreadID`, `One_Step_Status_Limit`。 |
| **初始化** | 设置 `OnDoStatusHook := InternalDoStatus`，初始化消息队列。 |
| **终结** | 清空队列和钩子。 |
| **关键字** | 日志, DoStatus, 线程安全, 钩子, 控制台输出, CheckDoStatus |

---

## 中间层 – 实用工具与算法

### Z.UnicodeMixedLib
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 多功能实用工具集，涵盖文件系统操作、路径处理、MD5/CRC/Base64 编解码、随机数、URL 解析、CSV、动态库加载、字节序转换、文本批处理等。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Int128`, `Z.ListEngine`, `Z.MemoryStream`。 |
| **导出函数** | 数百个 `uml*` 函数（`umlFileExists`, `umlMD5`, `umlBase64Encode`, `umlRandom`, `umlBatchReplace` 等）。 |
| **导出类** | `TReliableFileStream`, `TIOHnd`, `TMD5_Pair_Pool`。 |
| **全局变量** | `Lib_DateTimeFormatSettings`。 |
| **初始化** | 初始化 `Lib_DateTimeFormatSettings` 为 ISO 格式。 |
| **终结** | 释放动态库缓存。 |
| **关键字** | 文件操作, MD5, CRC, Base64, URL, CSV, 随机数, 批处理, uml |

### Z.MemoryStream
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 64 位内存流（`TMS64`, `TMem64`），支持自动增长、压缩/解压（ZLib, LZ4, Snappy）、序列化读写。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Int128`。 |
| **导出类** | `TMS64`, `TMem64`, `TMemoryStream64List`。 |
| **导出函数** | `CompressStream`, `DecompressStream`, `ParallelCompressMemory`, `SelectCompressStream`。 |
| **初始化/终结** | 无。 |
| **关键字** | TMS64, TMem64, 内存流, 64位, LZ4, Snappy, ZLib, 并行压缩 |

### Z.Compress
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 提供 Deflate（基于 zlib）和 BRRC 压缩算法，支持流压缩/解压。 |
| **依赖** | `Z.Core`。 |
| **导出类** | `TCompressor`, `TCompressorDeflate`, `TCompressorBRRC`。 |
| **导出函数** | `DeflateCompressStream`, `BRRCDecompressStream` 等。 |
| **初始化/终结** | 无。 |
| **关键字** | Deflate, BRRC, 压缩, 解压, 流 |

### Z.LZ4_Pas
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 纯 Pascal LZ4 块压缩/解压，32/64 位接口。 |
| **依赖** | `Z.Core`。 |
| **导出函数** | `LZ4_compressBound`, `LZ4_compress_default`, `LZ4_decompress_safe`（及 64 位版本）。 |
| **初始化/终结** | 无。 |
| **关键字** | LZ4, 压缩, 解压, 块, 纯Pascal |

### Z.Snappy_Pas
| 属性 | 内容 |
| :--- | :--- |
| **功能** | Snappy 压缩/解压纯 Pascal 实现。 |
| **依赖** | `Z.Core`。 |
| **导出函数** | `SnappyMaxCompressedLength64`, `SnappyCompress`, `SnappyDecompress`。 |
| **初始化/终结** | 无。 |
| **关键字** | Snappy, 压缩, 解压, 纯Pascal |

### Z.MD5
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 快速 MD5 计算，提供内存块和流的 MD5，Windows/Delphi 下使用汇编加速。 |
| **依赖** | `Z.Core`, `Z.UnicodeMixedLib`。 |
| **导出函数** | `FastMD5`（重载）。 |
| **初始化/终结** | 无。 |
| **关键字** | MD5, FastMD5, 哈希, 流, 汇编加速 |

### Z.AES
| 属性 | 内容 |
| :--- | :--- |
| **功能** | AES-128/192/256 块加密，支持 ECB / CBC 模式，提供密钥扩展和加解密流。 |
| **依赖** | `Z.Core`。 |
| **导出类** | `TAESKey128/192/256`, `TAESExpandedKey*`。 |
| **导出函数** | `EncryptAES`, `DecryptAES`, `EncryptAESStreamCBC` 等。 |
| **初始化/终结** | 无（纯算法）。 |
| **关键字** | AES, 加密, 解密, ECB, CBC, 密钥扩展 |

### Z.Cipher
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 统一加密/哈希框架，整合 DES、Blowfish、LBC、LQC、RNG、RC6、Serpent、Mars、Rijndael、Twofish、AES 以及多种哈希（MD5、SHA1/256/512、SHA3、ELF、CRC）。提供密码生成、量子密码哈希。 |
| **依赖** | `Z.Core`, `Z.AES`, `Z.UnicodeMixedLib`, `Z.MemoryStream`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.ListEngine`。 |
| **导出类** | `TCipher`（静态方法），各具体算法类（`TCipher_DES64` 等）。 |
| **导出枚举** | `TCipherSecurity`, `THashSecurity`。 |
| **导出函数** | `SequEncrypt`, `GeneratePasswordHash`, `QuantumCryptographyPassword`。 |
| **全局变量** | `SystemCBC`（默认 CBC 向量）。 |
| **初始化** | `SystemCBC` 由 `InitSysCBCAndDefaultKey` 填充随机数据。 |
| **终结** | 无。 |
| **关键字** | 加密, 解密, 哈希, AES, DES, SHA, MD5, 量子密码, TCipher |

### Z.Parsing
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 词法分析引擎，支持 Pascal / C / Text 风格，缓存 Token 和注释/字符串区间，提供语义探针、向量提取、文本编辑、字符串/注释转换。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.ListEngine`。 |
| **导出类** | `TTextParsing`。 |
| **导出枚举** | `TTextStyle`, `TTokenType`。 |
| **全局变量** | `SpacerSymbol`（`TAtomString`）。 |
| **初始化** | 创建 `SpacerSymbol` 并赋默认值（`C_SpacerSymbol`）。 |
| **终结** | 释放 `SpacerSymbol`。 |
| **关键字** | 词法分析, Token, TTextParsing, Pascal, C, 语义探针, 向量提取, 注释转换 |

### Z.Expression
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 字符串表达式解析、优先级处理、编译为 `TOpCode`，并提供缓存和求值入口。 |
| **依赖** | `Z.Core`, `Z.Parsing`, `Z.OpCode`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`, `Z.Status`, `Z.ListEngine`。 |
| **导出类** | `TSymbolExpression`（中间表示）。 |
| **导出函数** | `ParseTextExpressionAsSymbol`, `BuildAsOpCode`, `EvaluateExpressionValue`, `EvaluateExpressionVector`。 |
| **全局变量** | 无（`OpCache` 返回全局缓存池）。 |
| **初始化** | 首次调用 `OpCache` 时创建全局缓存池。 |
| **终结** | 释放全局缓存池。 |
| **关键字** | 表达式, 解析, 优先级, AST, TOpCode, 缓存, EvaluateExpressionValue |

### Z.OpCode
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 虚拟机执行引擎，定义 OpCode 树、运行时环境（`TOpCustomRunTime`）和非线性执行（`TOpCode_NonLinear`），支持异步暂停/恢复。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.MemoryStream`, `Z.Status`, `Z.ListEngine`, `Z.HashList.Templet`, `Z.Parsing`。 |
| **导出类** | `TOpCode`（及其子类）, `TOpCustomRunTime`, `TOpCode_NonLinear`, `TOpCode_NonLinear_Pool`, `TOpCode_Pool`。 |
| **导出函数** | `LoadOpFromStream`。 |
| **全局变量** | `OpRegTool`, `OpSystemAPI`, `SystemOpRunTime`, `System_NonLinear_Pool`。 |
| **初始化** | 创建 `OpRegTool` 并注册所有内置 OpCode 类；创建 `OpSystemAPI` 和 `SystemOpRunTime`，注册系统 API；创建 `System_NonLinear_Pool`。 |
| **终结** | 释放 `SystemOpRunTime`, `OpSystemAPI`, `System_NonLinear_Pool`, `OpRegTool`。 |
| **关键字** | OpCode, 虚拟机, TOpCustomRunTime, 非线性, 异步, TOpCode_NonLinear, 系统API |

### Z.HashList.Templet
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 提供大量泛型哈希表（字符串、浮点、整数、对象等），支持键值对存储、排序、遍历。 |
| **依赖** | `Z.Core`, `Z.Status`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`。 |
| **导出类** | `TPascalString_Hash_Pool`, `TString_Big_Hash_Pair_Pool`, `TSingle_Big_Hash_Pair_Pool`, `TGeneric_String_Object_Hash<T>` 等。 |
| **初始化/终结** | 无。 |
| **关键字** | 泛型哈希表, TPascalString_Hash_Pool, 键值对, 排序, 遍历 |

### Z.HashMinutes.Templet / Z.HashHours.Templet
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 线程安全的泛型哈希池，按小时/分钟分片存储键值对，支持时间范围检索。 |
| **依赖** | `Z.Core`, `Z.Status`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`。 |
| **导出类** | `THours_Buffer_Pool<T>`, `TMinutes_Buffer_Pool<T>`。 |
| **初始化/终结** | 无。 |
| **关键字** | 时间分片, 哈希池, 小时, 分钟, 范围检索, 线程安全 |

### Z.Matched.Templet
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 双向匹配算法模板，用于在两组数据间建立最优配对（基于用户定义的差异函数）。 |
| **依赖** | `Z.Core`。 |
| **导出类** | `TBidirectional_Matched<T>`, `TBidirectional_Matched_D<T>`。 |
| **初始化/终结** | 无。 |
| **关键字** | 双向匹配, 最优配对, 差异函数, 模板 |

### Z.IOThread
| 属性 | 内容 |
| :--- | :--- |
| **功能** | IO 任务队列，支持多线程消费和直接执行模式。 |
| **依赖** | `Z.Core`。 |
| **导出类** | `TIO_Thread_Base`, `TIO_Thread`, `TIO_Direct`, `TThread_Pool`。 |
| **初始化/终结** | 无。 |
| **关键字** | IO, 任务队列, 多线程, TIO_Thread, TThread_Pool |

### Z.Cadencer
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 时间驱动器，基于 `TThread.GetTickCount` 提供高精度定时回调，支持时间缩放、最小/最大步长。 |
| **依赖** | `Z.Core`。 |
| **导出类** | `TCadencer`, `ICadencerProgressInterface`。 |
| **初始化/终结** | 无。 |
| **关键字** | 时间驱动器, TCadencer, 定时回调, 时间缩放, 动画 |

### Z.Notify
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 延迟任务调度器，支持过程/方法/匿名回调，可在指定秒数后执行，并可携带对象池自动释放。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.DFE`, `Z.Cadencer`。 |
| **导出类** | `TN_Progress_Tool`, `TCadencer_N_Progress_Tool`, `TN_Post_Execute`。 |
| **全局变量** | `SystemPostProgress`（全局调度器）。 |
| **初始化** | 创建 `SystemPostProgress`，挂接到 `Z.Core.OnCheckThreadSynchronize`。 |
| **终结** | 释放 `SystemPostProgress`。 |
| **关键字** | 延迟执行, 任务调度, TN_Progress_Tool, PostExecute, 自动释放 |

### Z.Line2D.Templet
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 2D 画线模板，支持 Bresenham 算法绘制线段、矩形填充，像素处理可重载。 |
| **依赖** | `Z.Core`。 |
| **导出类** | `TLine_2D_Templet<T>`。 |
| **初始化/终结** | 无。 |
| **关键字** | 2D画线, Bresenham, 矩形填充, 模板 |

---

## 几何与数学

### Z.Geometry.Low
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 3D 几何和线性代数底层库，提供向量（2/3/4D）、矩阵（3x3/4x4）、四元数、平面、插值、碰撞检测等基础运算。 |
| **依赖** | `Z.Core`, `Z.Geometry2D`。 |
| **导出类型** | `TVector2f/3f/4f`, `TMatrix3f/4f`, `TQuaternion`, `THmgPlane`。 |
| **导出函数** | `VectorAdd`, `VectorDotProduct`, `MatrixMultiply`, `QuaternionSlerp`, `PlaneMake` 等数百个。 |
| **全局常量** | `XVector`, `IdentityMatrix`, `Epsilon`。 |
| **初始化/终结** | 无。 |
| **关键字** | 3D, 向量, 矩阵, 四元数, 平面, 插值, 碰撞, TGeoFloat |

### Z.Geometry2D
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 完整 2D 几何库，包括向量、矩形、多边形、三角剖分、凸包、碰撞检测、投影变换、SVG 风格工具。 |
| **依赖** | `Z.Core`, `Z.FPC.GenericList`, `Z.MemoryStream`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Int128`。 |
| **导出类型** | `TVec2`, `TRectV2`, `TV2L`（多边形列表）, `TV2Rect4`（旋转矩形）, `TDeflectionPolygon`（极坐标多边形）。 |
| **导出函数** | `PointInPolygon`, `RectToRectIntersect`, `ConvexHull` 等。 |
| **全局常量** | `XPoint`, `NULLRect`, `ZeroTriangle`。 |
| **初始化/终结** | 无。 |
| **关键字** | 2D, TVec2, 多边形, 凸包, 三角剖分, 碰撞, 投影, TV2L |

### Z.Geometry3D
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 强类型 3D 向量/矩阵/AABB，提供运算符重载和常用变换。 |
| **依赖** | `Z.Core`, `Z.Geometry.Low`, `Z.Geometry2D`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`。 |
| **导出类型** | `TVector3`, `TVector4`, `TMatrix4`, `TAABB`。 |
| **导出函数** | `StrToVec3`, `Vector3`, `VecToStr` 等。 |
| **初始化/终结** | 无。 |
| **关键字** | TVector3, TVector4, TMatrix4, AABB, 运算符重载, 3D |

### Z.Geometry.Rotation
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 欧拉角（pitch/turn/roll）的解码、步进、设定，基于 `Z.Geometry.Low`。 |
| **依赖** | `Z.Geometry.Low`。 |
| **导出函数** | `DecodeOrderAngle`, `ComputePitch`, `StepPitch`, `SetPitch` 等。 |
| **初始化/终结** | 无。 |
| **关键字** | 欧拉角, pitch, turn, roll, 旋转, DecodeOrderAngle |

### Z.BulletMovementEngine
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 高速子弹运动引擎，匀速移动，无转弯减速，支持路径跟随和旋转。 |
| **依赖** | `Z.Core`, `Z.Geometry2D`, `Z.Geometry3D`。 |
| **导出类** | `TBulletMovementEngine`, `IBulletMovementInterface`。 |
| **导出类型** | `TBulletMovementStepData`, `TStepHistoryData`。 |
| **初始化/终结** | 无。 |
| **关键字** | 子弹, 运动引擎, 匀速, 路径跟随, 旋转, IBulletMovementInterface |

### Z.MovementEngine
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 通用 2D 运动引擎，支持路径跟随、平滑旋转、循环、暂停，可配置转弯减速。 |
| **依赖** | `Z.Core`, `Z.Geometry2D`。 |
| **导出类** | `TMovementEngine`, `IMovementEngineInterface`。 |
| **导出类型** | `TMovementStepData`。 |
| **初始化/终结** | 无。 |
| **关键字** | 运动引擎, 路径跟随, 平滑旋转, 循环, TMovementEngine |

---

## 数据容器与序列化

### Z.DFE
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 二进制序列化框架，支持任意数据类型的帧序列，可压缩/加密，能与 JSON 互转。 |
| **依赖** | `Z.Core`, `Z.UnicodeMixedLib`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.ListEngine`, `Z.MemoryStream`, `Z.Cipher`, `Z.Status`, `Z.Geometry.Low`, `Z.Geometry2D`, `Z.Geometry3D`, `Z.Json`, `Z.Expression`, `Z.OpCode`, `Z.TextDataEngine`, `Z.Number`, `Z.Compress`, `Z.Int128`。 |
| **导出类** | `TDFE`, `TDFE_Reader`, `TDataWriter`, `TDataReader`，各帧类型（`TDF_String`, `TDF_Integer` 等）。 |
| **初始化/终结** | 无。 |
| **关键字** | DFE, 序列化, 二进制, JSON, 压缩, 加密, TDataWriter |

### Z.Json
| 属性 | 内容 |
| :--- | :--- |
| **功能** | JSON 对象封装，支持读写、流、文件，内部可选用 Delphi 的 `JsonDataObjects` 或 FPC 的 `fpjson`。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`, `Z.MemoryStream`, `Z.Int128`，以及条件编译的 JSON 实现。 |
| **导出类** | `TZ_JsonObject`, `TZ_JsonArray`, `TZ_JsonObject_List`。 |
| **初始化/终结** | 无。 |
| **关键字** | JSON, TZ_JsonObject, 解析, 生成, 流, 文件 |

### Z.TextDataEngine
| 属性 | 内容 |
| :--- | :--- |
| **功能** | INI 风格配置引擎，支持 Variant 和字符串两种访问模式，自动懒加载，注释处理。 |
| **依赖** | `Z.Core`, `Z.UnicodeMixedLib`, `Z.PascalStrings`, `Z.ListEngine`, `Z.MemoryStream`, `Z.Int128`。 |
| **导出类** | `THashTextEngine`。 |
| **初始化/终结** | 无。 |
| **关键字** | INI, 配置, THashTextEngine, 懒加载, 注释, Variant |

### Z.Number
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 动态命名变量系统（`TNumberModulePool`），支持类型安全访问、钩子、事件，并与 `Z.Expression` 集成，允许在脚本中读写变量。 |
| **依赖** | `Z.Core`, `Z.HashList.Templet`, `Z.ListEngine`, `Z.PascalStrings`, `Z.Parsing`, `Z.Expression`, `Z.OpCode`。 |
| **导出类** | `TNumberModulePool`, `TNumberModule`, `TNumberModuleHookPool`, `TNumberModuleEventPool`。 |
| **初始化/终结** | 无。 |
| **关键字** | 动态变量, TNumberModulePool, 钩子, 事件, 脚本集成, 表达式 |

### Z.FragmentBuffer
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 碎片化缓冲区管理，支持不连续空间的数据读写、自动合并重叠片段、哈希加速定位，并提供安全的文件写入（`TSafe_Flush_Stream`）。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.MemoryStream`。 |
| **导出类** | `TFragment_Space_Tool`, `TSafe_Flush_Stream`, `TPart_Data`。 |
| **初始化/终结** | 无。 |
| **关键字** | 碎片缓冲区, TFragment_Space_Tool, 安全写入, TSafe_Flush_Stream, 哈希加速 |

### Z.LinearAction
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 线性动作序列执行引擎，支持动作列表和嵌套，由 `TCadencer` 驱动。 |
| **依赖** | `Z.Core`, `Z.Status`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`, `Z.Cadencer`。 |
| **导出类** | `TLAction`, `TLActionList`, `TLAction_Linear`。 |
| **初始化/终结** | 无。 |
| **关键字** | 线性动作, TLAction, 序列执行, TCadencer, 脚本 |

---

## 调试与性能

### Z.Instance.Tool
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 跟踪对象实例的创建/销毁计数，用于内存泄漏检测（需定义 `Intermediate_Instance_Tool`）。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`。 |
| **导出类** | `TInstance_State_Tool`。 |
| **全局变量** | `Instance_State_Tool`, `Print_Intermediate_Instance_Status`。 |
| **初始化** | 若启用跟踪宏，创建 `Instance_State_Tool`。 |
| **终结** | 释放 `Instance_State_Tool`。 |
| **关键字** | 实例跟踪, 内存泄漏, TInstance_State_Tool, 调试 |

### Z.MH / Z.MH1 / Z.MH2 / Z.MH3 / Z.MH_ZDB
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 内存分配钩子，用于跟踪每次内存分配的大小和地址，辅助内存泄漏检测（可同时启用多个钩子）。 |
| **依赖** | `Z.Core`, `Z.ListEngine`。 |
| **导出函数** | `BeginMemoryHook`, `EndMemoryHook`, `GetHookMemorySize`, `GetHookPtrList`。 |
| **全局变量** | 每个钩子维护自己的内存列表。 |
| **初始化/终结** | 无（需手动调用 `BeginMemoryHook`）。 |
| **关键字** | 内存钩子, 内存泄漏, BeginMemoryHook, GetHookMemorySize |

### Z.Opti_Distance_D
| 属性 | 内容 |
| :--- | :--- |
| **功能** | SSE 优化的双精度浮点距离计算，若 `SSE_Optimize_Distance_Compute` 未定义则回退到 Pascal 实现。 |
| **依赖** | `Z.Core`。 |
| **导出函数** | `SSE_Distance_D`, `Pascal_Distance_D`, `Do_Test_SIMD_Distance_D`。 |
| **初始化/终结** | 无。 |
| **关键字** | SSE, 距离, 双精度, SIMD, 优化 |

### Z.Opti_Distance_S
| 属性 | 内容 |
| :--- | :--- |
| **功能** | SSE 优化的单精度浮点距离计算。 |
| **依赖** | `Z.Core`。 |
| **导出函数** | `SSE_Distance_S`, `Pascal_Distance_S`, `Do_Test_SIMD_Distance_S`。 |
| **初始化/终结** | 无。 |
| **关键字** | SSE, 距离, 单精度, SIMD, 优化 |

---

## 表达式高级执行

### Z.Expression.Sequence
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 非阻塞顺序执行多个表达式（脚本），每个表达式可暂停等待异步事件（如延迟）。 |
| **依赖** | `Z.Core`, `Z.Parsing`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`, `Z.Notify`, `Z.Status`, `Z.ListEngine`, `Z.Expression`, `Z.OpCode`。 |
| **导出类** | `TExpression_Sequence`, `TExpression_Sequence_RunTime`, `TExpression_Sequence_Pool`。 |
| **初始化/终结** | 无。 |
| **关键字** | 脚本, 非阻塞, 异步, TExpression_Sequence, 暂停, 恢复 |

### Z.UReplace
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 基于 `TUPascalString` 的批量替换工具，支持全词匹配、大小写、自定义符号集。 |
| **依赖** | `Z.Core`, `Z.UPascalStrings`, `Z.ListEngine`。 |
| **导出函数** | `U_BatchReplace`, `U_BatchSum`, `U_Replace` 等。 |
| **初始化/终结** | 无。 |
| **关键字** | 批量替换, U_BatchReplace, 全词匹配, Unicode, 大小写 |

---

## 初始化与终结汇总

| 单元 | 初始化行为 | 终结行为 |
| :--- | :--- | :--- |
| **Z.Core** | 设置主线程 ID，创建主线程软同步工具和 `MainThreadProgress`；若启用实例跟踪，创建 `Instance_State_Tool`。 | 关闭调度线程（`Close_Core_Dispatch_Thread`），释放全局对象。 |
| **Z.OpCode** | 创建 `OpRegTool`，注册所有内置 OpCode 类；创建 `OpSystemAPI` 和 `SystemOpRunTime`，注册系统 API；创建 `System_NonLinear_Pool`。 | 释放 `SystemOpRunTime`, `OpSystemAPI`, `System_NonLinear_Pool`, `OpRegTool`。 |
| **Z.Cipher** | 初始化 `SystemCBC` 随机向量；注册 128 位整数变体类型。 | 释放变体类型对象。 |
| **Z.Int128** | 注册 `UInt128` 和 `Int128` 的自定义变体类型。 | 释放变体类型对象。 |
| **Z.Parsing** | 初始化全局 `SpacerSymbol` 字符串。 | 释放 `SpacerSymbol`。 |
| **Z.Status** | 设置 `OnDoStatusHook := InternalDoStatus`，初始化消息队列。 | 清空队列和钩子。 |
| **Z.Notify** | 创建 `SystemPostProgress` 并挂接到 `Z.Core` 的同步钩子。 | 释放 `SystemPostProgress`。 |
| **Z.UnicodeMixedLib** | 初始化 `Lib_DateTimeFormatSettings` 为 ISO 格式。 | 释放动态库缓存。 |
| **Z.Instance.Tool** | 若启用跟踪宏，创建 `Instance_State_Tool`。 | 释放 `Instance_State_Tool`。 |

---

## 快速导航

| 需求 | 推荐单元 | 关键类/函数 |
| :--- | :--- | :--- |
| 多线程/并行 | **Z.Core** | `TCompute.RunC`, `ParallelFor`, `TCritical` |
| 字符串处理（ANSI） | **Z.PascalStrings** | `TPascalString` |
| 字符串处理（Unicode） | **Z.UPascalStrings** | `TUPascalString` |
| 文件/编码/随机 | **Z.UnicodeMixedLib** | `umlFileExists`, `umlMD5`, `umlRandom` |
| 日志输出 | **Z.Status** | `DoStatus`, `AddDoStatusHook` |
| 内存流/压缩 | **Z.MemoryStream** | `TMS64`, `CompressStream` |
| 加密/哈希 | **Z.Cipher** | `TCipher.EncryptBuffer`, `GeneratePasswordHash` |
| 表达式求值 | **Z.Expression** | `EvaluateExpressionValue` |
| 脚本顺序执行 | **Z.Expression.Sequence** | `TExpression_Sequence` |
| 2D/3D 几何 | **Z.Geometry2D** / **Z.Geometry3D** | `TVec2`, `TVec3`, `TMatrix4` |
| 配置管理 | **Z.TextDataEngine** | `THashTextEngine` |
| 动态变量 | **Z.Number** | `TNumberModulePool` |
| 序列化 | **Z.DFE** | `TDFE` |
| JSON | **Z.Json** | `TZ_JsonObject` |
| 延迟任务 | **Z.Notify** | `SysPostProgress.PostExecuteC` |
| 内存泄漏检测 | **Z.Instance.Tool** / **Z.MH** | `BeginMemoryHook`, `Instance_State_Tool` |

---

*本手册基于源码接口和框架设计文档整理，具体实现细节请参考各单元源码及注释。*

