# Z.UnicodeMixedLib 完整 API 参考手册

> 本文档以表格形式列出 `Z.UnicodeMixedLib` 单元的全部导出成员（函数、类、变量、常量、类型定义），每个条目均附有说明。

---

## 目录

- [1. 类型定义](#1-类型定义)
- [2. 常量](#2-常量)
- [3. 全局变量](#3-全局变量)
- [4. 类](#4-类)
  - [TReliableFileStream](#41-treliablefilestream)
  - [TIOHnd（记录类型）](#42-tiohnd记录类型)
  - [TMD5_Tool](#43-tmd5_tool)
  - [TMD5_Pair_Pool](#44-tmd5_pair_pool)
- [5. 字符串与编码函数](#5-字符串与编码函数)
- [6. 文件系统函数](#6-文件系统函数)
- [7. 路径操作函数](#7-路径操作函数)
- [8. 文件 I/O 函数（TIOHnd 相关）](#8-文件-io-函数tiohnd-相关)
- [9. 类型转换与格式化函数](#9-类型转换与格式化函数)
- [10. 数学与随机函数](#10-数学与随机函数)
- [11. MD5 哈希函数](#11-md5-哈希函数)
- [12. CRC16 / CRC32 函数](#12-crc16--crc32-函数)
- [13. Base64 编解码函数](#13-base64-编解码函数)
- [14. URL 与 HTML 编码函数](#14-url-与-html-编码函数)
- [15. 批量替换与文本处理函数](#15-批量替换与文本处理函数)
- [16. 时间与日期函数](#16-时间与日期函数)
- [17. 动态库加载函数](#17-动态库加载函数)
- [18. RTSP/RTMP URL 解析函数](#18-rtsp-rtmp-url-解析函数)
- [19. CSV 导入函数](#19-csv-导入函数)
- [20. 组件操作函数](#20-组件操作函数)
- [21. 杂项工具函数](#21-杂项工具函数)

---

## 1. 类型定义

| 类型名 | 说明 |
| :--- | :--- |
| `U_SystemString` | `SystemString` 别名，避免命名冲突。 |
| `U_String` | `TPascalString` 别名，统一的字符串类型。 |
| `U_Char` | `SystemChar` 别名，统一的字符类型。 |
| `U_StringArray` | 动态数组 `array of U_SystemString`。 |
| `U_ArrayString` | `U_StringArray` 别名。 |
| `U_Bytes` | `TBytes` 别名。 |
| `TSR` | `TSearchRec` 别名，用于文件搜索。 |
| `U_Stream` | `TCore_Stream` 别名。 |
| `TReliableFileStream` | 可靠文件流类，写入时创建备份副本，关闭时原子替换原文件。 |
| `PIOHnd` | `^TIOHnd` 指针类型。 |
| `TIOHnd_Cache` | I/O 句柄的读写缓存管理记录。 |
| `TIOHnd` | I/O 句柄核心记录，封装流、位置、大小、缓存、错误码等。 |
| `U_ByteArray` | 可越界索引的字节数组类型 `array[0..MaxInt div SizeOf(Byte)-1] of Byte`。 |
| `P_ByteArray` | `^U_ByteArray`。 |
| `TTextType` | 数值文本类型枚举（`ntBool`, `ntInt`, `ntSingle`, `ntDouble` 等）。 |
| `TBatch` | 批量替换记录，包含 `sour`（源）、`dest`（目标）、`sum`（匹配数）。 |
| `PBatch` | `^TBatch`。 |
| `TArrayBatch` | `array of TBatch`。 |
| `TBatchInfo` | 单次替换的位置信息记录。 |
| `TBatchInfoList` | `TGenericsList<TBatchInfo>`。 |
| `TOnBatchProc` | 批量替换回调（FPC 为 `is nested`，Delphi 为 `reference to`）。 |
| `TRTSP_RTMP_URL` | RTSP/RTMP URL 组件记录（prefix, user, passwd, host, port, path）。 |
| `TBase64Context` | Base64 流式编解码上下文。 |
| `TBase64EOLMarker` | Base64 换行标记（`emCRLF`, `emCR`, `emLF`, `emNone`）。 |
| `TMD5_Pool` | `TGenericsList<TMD5>`。 |
| `TMD5_Big_Pool` | `TBigList<TMD5>`。 |
| `TArrayMD5` | `array of TMD5`。 |
| `TMD5_Pair_Pool_Decl` | `TBig_Hash_Pair_Pool<TMD5, TMD5>`。 |
| `TMD5_Tool` | 增量 MD5 计算工具类（通过 `Update` 分块更新，`FinalizeMD5` 输出结果）。 |
| `TMD5_Pair_Pool` | MD5 键值对哈希池，支持 `LoadFromStream`/`SaveToStream`，带 `IsChanged` 标记。 |
| `TCSVGetLine_C/M/P` | CSV 行读取回调（C/M/P 三种风格）。 |
| `TCSVSave_C/M/P` | CSV 数据保存回调（C/M/P 三种风格）。 |

---

## 2. 常量

| 常量名 | 值 | 说明 |
| :--- | :--- | :--- |
| `C_Max_UInt32` | `$FFFFFFFF` | 最大 32 位无符号整数。 |
| `C_Address_Size` | `SizeOf(Pointer)` | 指针大小（4 或 8 字节）。 |
| `C_Pointer_Size` | `C_Address_Size` | 指针大小别名。 |
| `C_Integer_Size` | `4` | Integer 类型字节数。 |
| `C_Int64_Size` | `8` | Int64 字节数。 |
| `C_UInt64_Size` | `8` | UInt64 字节数。 |
| `C_Int128_Size` | `16` | Int128 字节数。 |
| `C_UInt128_Size` | `16` | UInt128 字节数。 |
| `C_Single_Size` | `4` | Single 字节数。 |
| `C_Double_Size` | `8` | Double 字节数。 |
| `C_Small_Int_Size` | `2` | SmallInt 字节数。 |
| `C_Byte_Size` | `1` | Byte 字节数。 |
| `C_Short_Int_Size` | `1` | ShortInt 字节数。 |
| `C_Word_Size` | `2` | Word 字节数。 |
| `C_DWord_Size` | `4` | DWord 字节数。 |
| `C_Cardinal_Size` | `4` | Cardinal 字节数。 |
| `C_Boolean_Size` | `1` | Boolean 字节数。 |
| `C_Bool_Size` | `1` | Bool 字节数。 |
| `C_MD5_Size` | `16` | MD5 摘要字节数。 |
| `C_PrepareReadCacheSize` | `512` | 读缓存预取大小（字节）。 |
| `C_Buffer_Chunk_Size` | `$F000`（61440） | 大块 I/O 的块大小。 |
| `C_Flush_And_Seek_Error` | `-912` | 刷新并寻址错误。 |
| `C_StringError` | `-911` | 字符串转换错误。 |
| `C_SeekError` | `-910` | 寻址错误。 |
| `C_FileWriteError` | `-909` | 文件写入错误。 |
| `C_FileReadError` | `-908` | 文件读取错误。 |
| `C_FileHandleError` | `-907` | 文件句柄无效。 |
| `C_OpenFileError` | `-905` | 打开文件错误。 |
| `C_NotOpenFile` | `-904` | 文件未打开。 |
| `C_CreateFileError` | `-903` | 创建文件错误。 |
| `C_FileIsActive` | `-902` | 文件已处于活动状态。 |
| `C_NotFindFile` | `-901` | 文件未找到。 |
| `C_NotError` | `-900` | 无错误。 |
| `Base64Symbols` | 表 | Base64 编码符号表（64 个 ASCII 字符）。 |
| `Base64Values` | 表 | Base64 解码值表（256 个字节映射）。 |
| `CRC16Table` | 表 | CRC16 查找表（256 个 Word）。 |
| `NULL_MD5` | `(0,0,...,0)` | 全零 MD5。 |
| `Zero_MD5` | `(0,0,...,0)` | 全零 MD5 别名。 |
| `NULLMD5` | `(0,0,...,0)` | 全零 MD5 别名。 |
| `ZeroMD5` | `(0,0,...,0)` | 全零 MD5 别名。 |
| `umlNULLMD5` | `(0,0,...,0)` | 全零 MD5 别名。 |
| `umlZeroMD5` | `(0,0,...,0)` | 全零 MD5 别名。 |
| `NULL_Buff_MD5` | `(212,29,...,126)` | 空缓冲区的 MD5（`umlMD5(nil,0)`）。 |
| `BASE64_DECODE_OK` | `0` | Base64 解码成功。 |
| `BASE64_DECODE_INVALID_CHARACTER` | `1` | Base64 解码遇到无效字符。 |
| `BASE64_DECODE_WRONG_DATA_SIZE` | `2` | Base64 解码数据大小错误。 |
| `BASE64_DECODE_NOT_ENOUGH_SPACE` | `3` | Base64 解码输出缓冲区不足。 |

---

## 3. 全局变量

| 变量名 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Lib_DateTimeFormatSettings` | `TFormatSettings` | 全局日期时间格式设置（ISO 风格：`yyyy-MM-dd hh:mm:ss.zz`）。 |
| `FileMD5Cache` | `TFileMD5Cache` | 文件 MD5 缓存实例，用于避免重复计算（内部使用，单元初始化时创建）。 |
| `__ExLibs__` | `THash_ExtLibs` | 动态库句柄缓存哈希表（`TString_Big_Hash_Pair_Pool<HMODULE>`）。 |

---

## 4. 类

### 4.1 TReliableFileStream

| 成员 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Create(FileName_: SystemString; IsNew_, IsWrite_: Boolean)` | 构造函数 | 创建可靠文件流。若 `IsNew_` 或 `IsWrite_` 为 True，则创建备份文件并启用可靠写入模式。 |
| `Destroy` | 析构函数 | 关闭流；若启用可靠模式，则用备份文件替换原文件。 |
| `Write` | 函数 | 写入数据（可靠模式下写入备份，否则写入原文件）。 |
| `Read` | 函数 | 读取数据（可靠模式下从备份读取，否则从原文件读取）。 |
| `Seek` | 函数 | 定位（可靠模式下定位到备份，否则定位到原文件）。 |
| `FileName` | 属性 | 原文件名。 |
| `BackupFileName` | 属性 | 备份文件名（`原文件名.save`）。 |
| `Activted` | 属性 | 是否处于可靠写入模式。 |

---

### 4.2 TIOHnd（记录类型）

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `IsOnlyRead` | `Boolean` | 是否只读。 |
| `IsOpen` | `Boolean` | 句柄是否打开。 |
| `AutoFree` | `Boolean` | 关闭时是否自动释放 `Handle`。 |
| `Handle` | `U_Stream` | 底层流对象。 |
| `Time` | `TDateTime` | 文件最后修改时间。 |
| `Size` | `Int64` | 文件大小。 |
| `Position` | `Int64` | 当前读写位置。 |
| `FileName` | `U_String` | 文件名。 |
| `Cache` | `TIOHnd_Cache` | 读写缓存信息。 |
| `IORead` | `Int64` | 累计读取字节数。 |
| `IOWrite` | `Int64` | 累计写入字节数。 |
| `ChangeFromWrite` | `Boolean` | 是否发生过写入操作。 |
| `FixedStringL` | `Byte` | 定长字符串字段长度（默认 65）。 |
| `Data` | `Pointer` | 用户自定义数据指针。 |
| `Return` | `Integer` | 最后一次操作的错误码（负值）。 |
| **方法** | | |
| `FixedString2Pascal(S: TBytes)` | 函数 | 将定长字节数组（首字节为长度）转换为 Pascal 字符串。 |
| `Pascal2FixedString(var n: TPascalString; var out_: TBytes)` | 过程 | 将 Pascal 字符串转换为定长字节数组（截断超长部分）。 |
| `CheckFixedStringLoss(S: TPascalString)` | 函数 | 检查 Pascal 字符串是否超出定长缓冲区容量。 |

---

### 4.3 TMD5_Tool

| 成员 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Create` | 构造函数 | 创建增量 MD5 计算器，初始摘要为 MD5 初始向量。 |
| `Destroy` | 析构函数 | 释放内部内存流。 |
| `Update(buff: Pointer; Size__: Int64)` | 过程 | 追加数据到 MD5 计算。 |
| `FinalizeMD5` | 函数 | 完成计算并返回最终 MD5 摘要（调用后工具状态重置）。 |
| `Completed_Size` | 属性 | 已处理的字节数。 |

---

### 4.4 TMD5_Pair_Pool

| 成员 | 类型 | 说明 |
| :--- | :--- | :--- |
| `Create(HashSize_: Integer)` | 构造函数 | 创建 MD5 键值对哈希池。 |
| `IsChanged` | 属性 | 自上次保存后是否发生过修改。 |
| `DoFree` | 过程 | 删除键值对时调用，设置 `IsChanged := True`。 |
| `DoAdd` | 过程 | 添加键值对时调用，设置 `IsChanged := True`。 |
| `LoadFromStream(stream: TCore_Stream)` | 过程 | 从流中加载 MD5 键值对（每 32 字节一组）。 |
| `SaveToStream(stream: TCore_Stream)` | 过程 | 将全部键值对保存到流中（每对 32 字节）。 |

---

## 5. 字符串与编码函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlBytesOf` | `S: TPascalString` | `TBytes` | 将 TPascalString 转换为 UTF-8 字节数组。 |
| `umlStringOf` | `S: TBytes` | `TPascalString` | 将 UTF-8 字节数组转换为 TPascalString。 |
| `umlNewString` | `S: TPascalString` | `PPascalString` | 在堆上分配并初始化新的 TPascalString。 |
| `umlFreeString` | `p: PPascalString` | - | 释放由 `umlNewString` 分配的 PPascalString。 |
| `umlComparePosStr` | `S: TPascalString; Offset: Integer; t: TPascalString` | `Boolean` | 比较 S 从 Offset 开始的子串与 t 是否相等（区分大小写）。 |
| `umlPos` | `SubStr, S: TPascalString; Offset: Integer = 1` | `Integer` | 查找 SubStr 在 S 中的位置（从 Offset 开始），返回 1-based 位置或 0。 |
| `umlVarToStr` | `v: Variant; Base64Conver: Boolean` | `TPascalString` | 将 Variant 转为字符串，若 `Base64Conver` 为 True 且含有控制字符，则编码为 Base64。 |
| `umlVarToStr` | `v: Variant` | `TPascalString` | 同上，`Base64Conver` 默认为 True。 |
| `umlStrToVar` | `S: TPascalString` | `Variant` | 将字符串转回 Variant，若以 `___base64:` 开头则解码。 |
| `umlCompareText` | `s1, s2: TPascalString` | `Integer` | 不区分大小写比较两个字符串，返回 -1/0/1。 |
| `umlUpperCase` | `S: TPascalString` / `S: PPascalString` | `TPascalString` | 返回大写副本。 |
| `umlLowerCase` | `S: TPascalString` / `S: PPascalString` | `TPascalString` | 返回小写副本。 |
| `umlCopyStr` | `sVal: TPascalString; MainPosition, LastPosition: Integer` | `TPascalString` | 提取 `[MainPosition, LastPosition)` 范围内的子串。 |
| `umlSameText` | `s1, s2: TPascalString` / `s1, s2: PPascalString` | `Boolean` | 不区分大小写比较是否相等。 |
| `umlDeleteChar` | `SText, Ch: TPascalString` | `TPascalString` | 删除 SText 中所有在 Ch 中出现的字符。 |
| `umlDeleteChar` | `SText: TPascalString; SomeChars: TArrayChar` | `TPascalString` | 删除 SText 中所有在字符数组中的字符。 |
| `umlDeleteChar` | `SText: TPascalString; SomeCharsets: TOrdChars` | `TPascalString` | 删除 SText 中所有匹配字符集的字符。 |
| `umlTrimChar` | `S, trim_s: TPascalString` | `TPascalString` | 去除 S 首尾所有在 `trim_s` 中的字符。 |
| `umlTrimSpace` | `S: TPascalString` | `TPascalString` | 去除 S 首尾的空格和 #0 字符。 |
| `umlGetNumberCharInText` | `n: TPascalString` | `TPascalString` | 提取字符串中的第一个连续数字序列。 |
| `umlMatchChar` | `CharValue: U_Char; cVal: PPascalString` / `cVal: TPascalString` | `Boolean` | 检查字符是否在字符串中。 |
| `umlExistsChar` | `StrValue: TPascalString; cVal: TPascalString` / `PPascalString` | `Boolean` | 检查 `cVal` 中的任何字符是否出现在 `StrValue` 中。 |
| `umlGetFirstStr` | `sVal, trim_s: TPascalString` | `TPascalString` | 获取第一个由 `trim_s` 分隔的 Token（连续分隔符合并）。 |
| `umlGetLastStr` | `sVal, trim_s: TPascalString` | `TPascalString` | 获取最后一个 Token。 |
| `umlDeleteFirstStr` | `sVal, trim_s: TPascalString` | `TPascalString` | 删除第一个 Token，返回剩余部分。 |
| `umlDeleteLastStr` | `sVal, trim_s: TPascalString` | `TPascalString` | 删除最后一个 Token，返回剩余部分。 |
| `umlGetIndexStrCount` | `sVal, trim_s: TPascalString` | `Integer` | 计算 Token 数量。 |
| `umlGetIndexStr` | `sVal, trim_s: TPascalString; index: Integer` | `TPascalString` | 获取第 `index` 个 Token（1-based）。 |
| `umlGetSplitArray` | `sour: TPascalString; var dest: TArrayPascalString; splitC: TPascalString` | - | 按分隔符拆分到 TArrayPascalString（连续分隔符合并）。 |
| `umlGetSplitArray` | `sour: TPascalString; var dest: U_StringArray; splitC: TPascalString` | - | 按分隔符拆分到 U_StringArray。 |
| `ArrayStringToText` | `var ary: TArrayPascalString; splitC: TPascalString` | `TPascalString` | 将数组用分隔符连接成字符串。 |
| `umlStringsToSplitText` | `lst: TCore_Strings; splitC: TPascalString` | `TPascalString` | 将 TCore_Strings 连接成字符串。 |
| `umlStringsToSplitText` | `lst: TListPascalString; splitC: TPascalString` | `TPascalString` | 将 TListPascalString 连接成字符串。 |
| `umlGetFirstStr_Discontinuity` | `sVal, trim_s: TPascalString` | `TPascalString` | 获取第一个 Token（连续分隔符不合并）。 |
| `umlDeleteFirstStr_Discontinuity` | `sVal, trim_s: TPascalString` | `TPascalString` | 删除第一个 Token（连续分隔符不合并）。 |
| `umlGetLastStr_Discontinuity` | `sVal, trim_s: TPascalString` | `TPascalString` | 获取最后一个 Token（连续分隔符不合并）。 |
| `umlDeleteLastStr_Discontinuity` | `sVal, trim_s: TPascalString` | `TPascalString` | 删除最后一个 Token（连续分隔符不合并）。 |
| `umlGetIndexStrCount_Discontinuity` | `sVal, trim_s: TPascalString` | `Integer` | 计算 Token 数量（连续分隔符不合并）。 |
| `umlGetIndexStr_Discontinuity` | `sVal, trim_s: TPascalString; index: Integer` | `TPascalString` | 获取第 `index` 个 Token（连续分隔符不合并）。 |
| `umlGetFirstTextPos` | `S: TPascalString; TextArry: TArrayPascalString; var OutText: TPascalString` | `Integer` | 查找第一个匹配 `TextArry` 中任一文本的位置。 |
| `umlDeleteText` | `sour: TPascalString; bToken, eToken: TArrayPascalString; ANeedBegin, ANeedEnd: Boolean` | `TPascalString` | 删除 `bToken` 和 `eToken` 之间的文本。 |
| `umlGetTextContent` | `sour: TPascalString; bToken, eToken: TArrayPascalString` | `TPascalString` | 提取 `bToken` 和 `eToken` 之间的文本内容。 |
| `umlGetNumTextType` | `S: TPascalString` | `TTextType` | 判断字符串的数值类型（整数/浮点/十六进制/布尔等）。 |
| `umlIsHex` | `sVal: TPascalString` | `Boolean` | 判断是否为十六进制数（含 `$` 前缀）。 |
| `umlIsNumber` | `sVal: TPascalString` | `Boolean` | 判断是否为有效数字（整数或浮点）。 |
| `umlIsIntNumber` | `sVal: TPascalString` | `Boolean` | 判断是否为整数（非浮点）。 |
| `umlIsFloatNumber` | `sVal: TPascalString` | `Boolean` | 判断是否为浮点数。 |
| `umlIsBool` | `sVal: TPascalString` | `Boolean` | 判断是否为布尔值（'True'/'False' 等）。 |
| `umlNumberCount` | `sVal: TPascalString` | `Integer` | 统计数字字符个数。 |
| `umlStringReplace` | `S, OldPattern, NewPattern: TPascalString; IgnoreCase: Boolean` | `TPascalString` | 使用 RTL 的 `StringReplace`（`rfReplaceAll`）。 |
| `umlReplaceString` | 同上 | `TPascalString` | `umlStringReplace` 别名。 |
| `umlCharReplace` | `S: TPascalString; OldPattern, NewPattern: U_Char` | `TPascalString` | 字符级替换。 |
| `umlReplaceChar` | 同上 | `TPascalString` | `umlCharReplace` 别名。 |
| `umlEncodeText2HTML` | `psSrc: TPascalString` | `TPascalString` | 将 HTML 特殊字符转义为 HTML 实体（`<`→`&lt;` 等）。 |
| `umlURLEncode` | `Data: TPascalString` | `TPascalString` | URL 百分号编码。 |
| `umlURLDecode` | `Data: TPascalString; FormEncoded: Boolean` | `TPascalString` | URL 解码，`FormEncoded` 为 True 时将 `+` 转为空格。 |
| `umlConverStrToFileName` | `Value: TPascalString` | `TPascalString` | 将非法文件名字符（`":;/\|<>?*%`）替换为空格。 |
| `umlSeparatorText` | `Text_: TPascalString; dest: TCore_Strings; SeparatorChar: TPascalString` | `Integer` | 拆分文本到 TCore_Strings，返回 Token 数。 |
| `umlSeparatorText` | `Text_: TPascalString; dest: THashVariantList; SeparatorChar: TPascalString` | `Integer` | 拆分文本到 THashVariantList，统计每个 Token 出现次数。 |
| `umlSeparatorText` | `Text_: TPascalString; dest: TListPascalString; SeparatorChar: TPascalString` | `Integer` | 拆分文本到 TListPascalString。 |
| `umlSeparatorText` | `Text_: TPascalString; var dest: U_StringArray; SeparatorChar: TPascalString` | `Integer` | 拆分文本到 U_StringArray。 |
| `umlSplitTextMatch` | `SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean` | `Boolean` | 检查任意 Token 是否匹配 `MatchText`（通配符）。 |
| `umlSplitTextTrimSpaceMatch` | 同上 | `Boolean` | 同上，但先对 Token 做 `TrimSpace`。 |
| `umlSplitDeleteText` | `SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean` | `TPascalString` | 删除匹配 `MatchText` 的 Token，返回剩余字符串。 |
| `umlSplitTextAsList` | `SText, Limit: TPascalString; AsLst: TCore_Strings` | `Boolean` | 拆分到 TCore_Strings，返回是否有任何 Token。 |
| `umlSplitTextAsListAndTrimSpace` | 同上 | `Boolean` | 拆分并 trim 每个 Token。 |
| `umlListAsSplitText` | `List: TCore_Strings; Limit: TPascalString` | `TPascalString` | 将 TCore_Strings 连接成字符串。 |
| `umlListAsSplitText` | `List: TListPascalString; Limit: TPascalString` | `TPascalString` | 将 TListPascalString 连接成字符串。 |
| `umlDivisionText` | `buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean` | `TPascalString` | 按宽度分行文本，可选 Pascal 字符串字面量格式。 |
| `umlMultipleMatch` | 多种重载 | `Boolean` | 通配符匹配（`*` 和 `?`），支持多个模式（`;` 分隔）。 |
| `umlSearchMatch` | 多种重载 | `Boolean` | 搜索匹配（支持包含/排除列表）。 |
| `umlMatchFileInfo` | `exp_, sour_, dest_: TPascalString` | `Boolean` | 用 `<prefix>` 和 `<postfix>` 占位符匹配文件名。 |
| `umlStringsMatchText` | `OriginValue: TCore_Strings; DestValue: TPascalString; IgnoreCase: Boolean` | `Boolean` | 检查列表中任意字符串是否匹配目标（通配符）。 |
| `umlStringsInExists` | 多种重载 | `Boolean` | 检查字符串是否存在于列表中。 |
| `umlTextInStrings` | 多种重载 | `Boolean` | `umlStringsInExists` 别名。 |
| `umlAddNewStrTo` | 多种重载 | `Boolean` / `Integer` | 若字符串不存在则添加到列表。 |
| `umlDeleteStrings` | `SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean` | `Integer` | 删除所有匹配 `SText` 的项。 |
| `umlDeleteStringsNot` | `SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean` | `Integer` | 删除所有不匹配 `SText` 的项。 |
| `umlMergeStrings` | 多种重载 | `Integer` | 将源列表中的唯一项合并到目标列表。 |
| `umlBinToUInt8/16/32/64` | `Value: U_String` | 对应整数类型 | 将二进制字符串（如 `'1010'`）转为整数。 |
| `umlUInt8/16/32/64ToBin` | `v` | `U_String` | 将整数转为二进制字符串。 |

---

## 6. 文件系统函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlFileExists` | `FileName: TPascalString` | `Boolean` | 检查文件是否存在。 |
| `umlDirectoryExists` | `DirectoryName: TPascalString` | `Boolean` | 检查目录是否存在。 |
| `umlCreateDirectory` | `DirectoryName: TPascalString` | `Boolean` | 创建目录（含中间目录），已存在则返回 True。 |
| `umlCurrentDirectory` | - | `TPascalString` | 返回当前工作目录。 |
| `umlCurrentPath` | - | `TPascalString` | 返回当前工作目录（尾部带路径分隔符）。 |
| `umlGetCurrentPath` | - | `TPascalString` | `umlCurrentPath` 别名。 |
| `umlSetCurrentPath` | `ph: TPascalString` | - | 设置当前工作目录。 |
| `umlFindFirstFile` | `FileName: TPascalString; var SR: TSR` | `Boolean` | 查找第一个文件。 |
| `umlFindNextFile` | `var SR: TSR` | `Boolean` | 查找下一个文件。 |
| `umlFindFirstDir` | `DirName: TPascalString; var SR: TSR` | `Boolean` | 查找第一个目录。 |
| `umlFindNextDir` | `var SR: TSR` | `Boolean` | 查找下一个目录。 |
| `umlFindClose` | `var SR: TSR` | - | 关闭搜索句柄。 |
| `uml_Get_File_To_List` | `FullPath: TPascalString; AsLst: TCore_Strings/TPascalStringList` | `Integer` | 将目录下的文件名添加到列表。 |
| `uml_Get_Dir_To_List` | `FullPath: TPascalString; AsLst: TCore_Strings/TPascalStringList` | `Integer` | 将目录下的子目录名添加到列表。 |
| `umlGet_File_Full_Array` | `FullPath: TPascalString` | `U_StringArray` | 返回目录下所有文件的完整路径数组。 |
| `umlGet_Path_Full_Array` | `FullPath: TPascalString` | `U_StringArray` | 返回目录下所有子目录的完整路径数组。 |
| `umlGet_File_Array` | `FullPath: TPascalString` | `U_StringArray` | 返回目录下所有文件名（不含路径）数组。 |
| `umlGet_Path_Array` | `FullPath: TPascalString` | `U_StringArray` | 返回目录下所有子目录名（不含路径）数组。 |
| `umlDeleteFile` | `FileName: TPascalString; _VerifyCheck: Boolean` | `Boolean` | 删除文件（支持通配符），可选验证。 |
| `umlDeleteFile` | `FileName: TPascalString` | `Boolean` | 删除文件（不验证）。 |
| `umlCopyFile` | `SourFile, DestFile: TPascalString` | `Boolean` | 复制文件并保留时间戳。 |
| `umlRenameFile` | `OldName, NewName: TPascalString` | `Boolean` | 重命名文件。 |
| `umlGetFileTime` | `FileName: TPascalString` | `TDateTime` | 获取文件最后修改时间。 |
| `umlSetFileTime` | `FileName: TPascalString; newTime: TDateTime` | - | 设置文件最后修改时间。 |
| `umlGetFileSize` | `FileName: TPascalString` | `Int64` | 获取文件大小（支持通配符，返回总和）。 |
| `umlGetFileCount` | `FileName: TPascalString` | `Integer` | 匹配通配符的文件数量。 |
| `umlGetFileDateTime` | `FileName: TPascalString` | `TDateTime` | 使用 `FileAge` 获取文件时间。 |
| `umlGetResourceStream` | `FileName: TPascalString` | `TCore_Stream` | 从可执行文件资源中加载流（`RT_RCDATA`）。 |
| `SaveMemory` | `p: Pointer; siz: NativeInt; DestFile: TPascalString` | - | 将内存块保存为文件。 |

---

## 7. 路径操作函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlFixedPath` | `S: TPascalString` | `TPascalString` | 归一化路径（平台分隔符 + 尾部分隔符）。 |
| `umlCombinePath` | `s1, s2: TPascalString` | `TPascalString` | 平台感知路径拼接。 |
| `umlCombineFileName` | `pathName, FileName: TPascalString` | `TPascalString` | 平台感知路径 + 文件名拼接。 |
| `umlCombineUnixPath` | `s1, s2: TPascalString` | `TPascalString` | Unix 风格路径拼接（`/`）。 |
| `umlCombineUnixFileName` | `pathName, FileName: TPascalString` | `TPascalString` | Unix 风格路径 + 文件名拼接。 |
| `umlCombineWinPath` | `s1, s2: TPascalString` | `TPascalString` | Windows 风格路径拼接（`\`）。 |
| `umlCombineWinFileName` | `pathName, FileName: TPascalString` | `TPascalString` | Windows 风格路径 + 文件名拼接。 |
| `umlGetFileName` | `platform_: TExecutePlatform; S: TPascalString` / `S: TPascalString` | `TPascalString` | 提取文件名（不含路径）。 |
| `umlGetWindowsFileName` | `S: TPascalString` | `TPascalString` | Windows 风格提取文件名。 |
| `umlGetUnixFileName` | `S: TPascalString` | `TPascalString` | Unix 风格提取文件名。 |
| `umlGetFilePath` | `platform_: TExecutePlatform; S: TPascalString` / `S: TPascalString` | `TPascalString` | 提取目录路径。 |
| `umlGetWindowsFilePath` | `S: TPascalString` | `TPascalString` | Windows 风格提取目录路径。 |
| `umlGetUnixFilePath` | `S: TPascalString` | `TPascalString` | Unix 风格提取目录路径。 |
| `umlChangeFileExt` | `S, ext: TPascalString` | `TPascalString` | 修改文件扩展名（自动添加 `.`）。 |
| `umlGetFileExt` | `S: TPascalString` | `TPascalString` | 提取文件扩展名（含 `.`）。 |

---

## 8. 文件 I/O 函数（TIOHnd 相关）

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `InitIOHnd` | `var IOHnd: TIOHnd` | - | 初始化 I/O 句柄为默认状态。 |
| `umlFileCreateAsStream` | `FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean` | `Boolean` | 将已有流关联到 I/O 句柄。 |
| `umlFileCreateAsStream` | 重载 | `Boolean` | 同上（默认读写）。 |
| `umlFileCreateAsStream` | `stream: U_Stream; var IOHnd: TIOHnd` | `Boolean` | 无文件名版本。 |
| `umlFileOpenAsStream` | `FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean` | `Boolean` | 打开流并关联到 I/O 句柄。 |
| `umlFileCreateAsMemory` | `var IOHnd: TIOHnd` | `Boolean` | 创建内存流并关联到 I/O 句柄。 |
| `umlFileCreate` | `FileName: TPascalString; var IOHnd: TIOHnd` | `Boolean` | 创建新文件并打开。 |
| `umlFileOpen` | `FileName: TPascalString; var IOHnd: TIOHnd; OnlyRead_: Boolean` | `Boolean` | 打开现有文件。 |
| `umlFileClose` | `var IOHnd: TIOHnd` | `Boolean` | 关闭文件，若 `AutoFree` 为 True 则释放流。 |
| `umlFileUpdate` | `var IOHnd: TIOHnd` | `Boolean` | 刷新缓存并更新句柄状态。 |
| `umlFileTest` | `var IOHnd: TIOHnd` | `Boolean` | 检查句柄是否打开且有效。 |
| `umlResetPrepareRead` | `var IOHnd: TIOHnd` | - | 重置读缓存。 |
| `umlFilePrepareRead` | `var IOHnd: TIOHnd; Size: Int64; var buff` | `Boolean` | 预读数据到缓存。 |
| `umlFileRead` | `var IOHnd: TIOHnd; const Size: Int64; var buff` | `Boolean` | 读取数据（支持缓存）。 |
| `umlBlockRead` | 同上 | `Boolean` | `umlFileRead` 别名。 |
| `umlFilePrepareWrite` | `var IOHnd: TIOHnd` | `Boolean` | 准备写缓存。 |
| `umlFileFlushWriteCache` | `var IOHnd: TIOHnd` | `Boolean` | 将写缓存刷新到底层流。 |
| `umlFileWrite` | `var IOHnd: TIOHnd; const Size: Int64; const buff` | `Boolean` | 写入数据（支持缓存）。 |
| `umlBlockWrite` | 同上 | `Boolean` | `umlFileWrite` 别名。 |
| `umlFileWriteFixedString` | `var IOHnd: TIOHnd; var Value: TPascalString` | `Boolean` | 写入定长字符串字段。 |
| `umlFileReadFixedString` | `var IOHnd: TIOHnd; var Value: TPascalString` | `Boolean` | 读取定长字符串字段。 |
| `umlCheckSeedPos` | `var IOHnd: TIOHnd; Pos_: Int64` | `Boolean` | 检查位置是否在文件范围内。 |
| `umlFileSeek` | `var IOHnd: TIOHnd; const Pos_: Int64` | `Boolean` | 定位到绝对位置。 |
| `umlFileSetSize` | `var IOHnd: TIOHnd; siz_: Int64` | `Boolean` | 设置文件大小。 |
| `umlFileGetPOS` | `var IOHnd: TIOHnd` | `Int64` | 获取当前读写位置。 |
| `umlFilePOS` | 同上 | `Int64` | `umlFileGetPOS` 别名。 |
| `umlFileGetSize` | `var IOHnd: TIOHnd` | `Int64` | 获取文件大小。 |
| `umlFileSize` | 同上 | `Int64` | `umlFileGetSize` 别名。 |

---

## 9. 类型转换与格式化函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlBoolToStr` | `Value: Boolean` | `TPascalString` | 布尔转字符串（'True'/'False'）。 |
| `umlStrToBool` | `Value: TPascalString; Default_: Boolean` | `Boolean` | 字符串转布尔，支持 'True'/'Yes'/'1' 等。 |
| `umlStrToBool` | `Value: TPascalString` | `Boolean` | 同上，默认 False。 |
| `umlStrToInt` | `V_: TPascalString; _Def: Integer` | `Integer` | 字符串转整数，失败返回默认值。 |
| `umlStrToInt` | `V_: TPascalString` | `Integer` | 同上，默认 0。 |
| `umlStrToInt64` | `V_: TPascalString; _Def: Int64` | `Int64` | 字符串转 Int64。 |
| `umlStrToInt64` | `V_: TPascalString` | `Int64` | 同上，默认 0。 |
| `umlStrToInt128` | `V_: TPascalString; _Def: Int128` | `Int128` | 字符串转 Int128。 |
| `umlStrToInt128` | `V_: TPascalString` | `Int128` | 同上，默认 0。 |
| `umlStrToFloat` | `V_: TPascalString; _Def: Double` | `Double` | 字符串转浮点数。 |
| `umlStrToFloat` | `V_: TPascalString` | `Double` | 同上，默认 0。 |
| `umlFloatToStr` | `f: Double` | `TPascalString` | 浮点数转字符串（`FloatToStr`）。 |
| `umlShortFloatToStr` | `f: Double` | `TPascalString` | 浮点数转字符串（`Format('%f',[f])`）。 |
| `umlIntToStr` | 多种重载（Single/Double/Int64/UInt64/Int128/Integer/Cardinal） | `TPascalString` | 整数转字符串（取整或直接转换）。 |
| `umlPointerToStr` | `param: Pointer` | `TPascalString` | 指针转十六进制字符串。 |
| `umlSmartSizeToStr` | `Size: Int64` | `TPascalString` | 字节数转可读字符串（`100Kb`, `1.5M`）。 |
| `umlSizeToStr` | `Parameter: Int64` | `TPascalString` | `umlSmartSizeToStr` 别名。 |
| `umlGSizeToStr` | `Parameter: Int64` | `TPascalString` | 字节数转可读字符串（支持 GB 单位）。 |
| `umlMBPSToStr` | `Size: Int64` | `TPascalString` | 速度转可读字符串（`Kbps`/`Mbps`）。 |
| `umlPercentageToFloat` | `OriginMax, OriginMin, ProcressParameter: Double` | `Double` | 计算百分比（浮点）。 |
| `umlPercentageToInt64` | `OriginParameter, ProcressParameter: Int64` | `Integer` | 计算百分比（整数）。 |
| `umlPercentageToInt` | `OriginParameter, ProcressParameter: Integer` | `Integer` | 计算百分比（整数）。 |
| `umlPercentageToStr` | `OriginParameter, ProcressParameter: Integer` | `TPascalString` | 百分比转字符串（如 `'42%'`）。 |
| `umlStrToTime` | `S: TPascalString` | `TDateTime` | 字符串转时间（使用 `Lib_DateTimeFormatSettings`）。 |
| `umlTimeToStr` | `t: TDateTime` | `TPascalString` | 时间转字符串。 |
| `umlStrToDateTime` | `S: TPascalString` | `TDateTime` | 字符串转日期时间。 |
| `umlDateTimeToStr` | `t: TDateTime` | `TPascalString` | 日期时间转字符串。 |
| `umlDT` | `t: TDateTime` / `S: TPascalString` | `TPascalString` / `TDateTime` | 日期时间快捷转换。 |
| `umlT` | `t: TDateTime` / `S: TPascalString` | `TPascalString` / `TDateTime` | 时间快捷转换。 |
| `umlDateToStr` | `t: TDateTime` | `TPascalString` | 日期转字符串。 |
| `umlGetDateTimeStr` | `NowDateTime: TDateTime` | `TPascalString` | 格式 `YYYY-MM-DD HH-MM-SS-MS`。 |
| `umlDecodeTimeToStr` | `NowDateTime: TDateTime` | `TPascalString` | 压缩十六进制日期时间。 |
| `umlDecodeDateTimeToInt64` | `NowDateTime: TDateTime` | `Int64` | 转 Unix 时间戳。 |
| `umlTimeTickToStr` | `t: TTimeTick` | `TPascalString` | 毫秒数转可读时间（`2 Day 12:30:45.123`）。 |
| `umlGenerate_Random_Name` | - / `rand_data: Int64` | `TPascalString` | 生成随机名称（MD5 时间戳 + 随机数）。 |

---

## 10. 数学与随机函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlMax` | 多种重载 | 对应类型 | 返回两个值中的最大值。 |
| `umlMin` | 多种重载 | 对应类型 | 返回两个值中的最小值。 |
| `umlClamp` | `v, min_, max_` | 对应类型 | 将值限制在 `[min_, max_]` 范围内。 |
| `umlInRange` | `v, min_, max_` | `Boolean` | 检查 `v` 是否在 `[min_, max_]` 范围内。 |
| `umlRandom` | `rnd: TMT19937Random` / 无参数 | `Integer` | 返回 `[0, MaxInt]` 范围内的随机整数。 |
| `umlRandomRange` / `umlRR` | 多种重载 | 对应类型 | 返回 `[min_, max_]` 范围内的随机值。 |
| `umlRandomRange64` / `umlRR64` | `rnd: TMT19937Random; min_, max_: Int64` / 无 `rnd` | `Int64` | 返回 `[min_, max_]` 范围内的随机 Int64。 |
| `umlRandomRangeS` / `umlRRS` | 多种重载 | `Single` | 返回 `[min_, max_]` 范围内的随机 Single。 |
| `umlRandomRangeD` / `umlRRD` | 多种重载 | `Double` | 返回 `[min_, max_]` 范围内的随机 Double。 |
| `umlRandomRangeF` / `umlRRF` | 多种重载 | `Double` | `umlRandomRangeD` 别名。 |
| `umlDefaultTime` | - | `Double` | 返回 `Now`（TDateTime）。 |
| `umlNow` | - | `Double` | 返回当前日期时间。 |
| `umlTime` | - | `Double` | 返回当前时间部分。 |
| `umlDate` | - | `Double` | 返回当前日期部分。 |
| `umlDefaultAttrib` | - | `Integer` | 返回 0。 |

---

## 11. MD5 哈希函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlStrIsMD5` | `hex: TPascalString` | `Boolean` | 检查是否为 32 位十六进制 MD5 字符串。 |
| `umlStrToMD5` | `hex: TPascalString` | `TMD5` | 十六进制字符串转 MD5。 |
| `umlTransformMD5` | `var Accu; const Buf` | - | 单块 MD5 变换（内部使用）。 |
| `umlMD5` | `buffPtr: PByte; bufSiz: NativeUInt` | `TMD5` | 计算内存块的 MD5。 |
| `umlMD5Char` / `umlMD5String` / `umlMD5Str` | `buffPtr: PByte; BuffSize: NativeUInt` | `TPascalString` | 计算内存块 MD5 并返回十六进制字符串。 |
| `umlStreamMD5` | `stream: TCore_Stream; StartPos, EndPos: Int64` | `TMD5` | 计算流指定范围的 MD5。 |
| `umlStreamMD5` | `stream: TCore_Stream` | `TMD5` | 计算整个流的 MD5。 |
| `umlStreamMD5Char` / `umlStreamMD5String` / `umlStreamMD5Str` | `stream: TCore_Stream` | `TPascalString` | 流 MD5 转十六进制字符串。 |
| `umlStringMD5` | `Value: TPascalString` | `TPascalString` | 字符串的 MD5 十六进制。 |
| `umlFileMD5___` | `FileName: TPascalString` | `TMD5` | 文件 MD5（内部，无缓存）。 |
| `umlFileMD5` | `FileName: TPascalString; StartPos, EndPos: Int64` | `TMD5` | 文件范围的 MD5。 |
| `umlFileMD5` | `FileName: TPascalString` | `TMD5` | 文件 MD5（带缓存）。 |
| `umlCombineMD5` | 多种重载 | `TMD5` | 组合多个 MD5 摘要（`MD5(m1 + m2)`）。 |
| `umlMD5ToStr` / `umlMD5ToString` / `umlMD52String` | `md5: TMD5` / `buffPtr: PByte; bufSiz: NativeUInt` | `TPascalString` | MD5 转十六进制字符串。 |
| `umlMD5Compare` / `umlCompareMD5` | `m1, m2: TMD5` | `Boolean` | 比较两个 MD5 是否相等。 |
| `umlIsNullMD5` / `umlWasNullMD5` | `M: TMD5` | `Boolean` | 检查 MD5 是否全零。 |
| `umlCacheFileMD5` | `FileName: U_String` | - | 异步缓存文件 MD5。 |
| `umlCacheFileMD5FromDirectory` | `Directory_, Filter_: U_String` | - | 异步缓存目录中匹配文件的所有 MD5。 |

---

## 12. CRC16 / CRC32 函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlCRC16` | `Value: PByte; Count: NativeUInt` | `Word` | 计算内存块的 CRC16。 |
| `umlStringCRC16` | `Value: TPascalString` | `Word` | 计算字符串的 CRC16。 |
| `umlStreamCRC16` | `stream: U_Stream; StartPos, EndPos: Int64` | `Word` | 计算流指定范围的 CRC16。 |
| `umlStreamCRC16` | `stream: U_Stream` | `Word` | 计算整个流的 CRC16。 |
| `umlCRC32` | `Value: PByte; Count: NativeUInt` | `Cardinal` | 计算内存块的 CRC32。 |
| `umlString2CRC32` | `Value: TPascalString` | `Cardinal` | 计算字符串的 CRC32。 |
| `umlStreamCRC32` | `stream: U_Stream; StartPos, EndPos: Int64` | `Cardinal` | 计算流指定范围的 CRC32。 |
| `umlStreamCRC32` | `stream: U_Stream` | `Cardinal` | 计算整个流的 CRC32。 |

---

## 13. Base64 编解码函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `B64EstimateEncodedSize` | `cont: TBase64Context; InSize: Integer` | `Integer` | 估计 Base64 编码后的数据大小。 |
| `B64InitializeDecoding` | `var cont: TBase64Context; LiberalMode: Boolean` | `Boolean` | 初始化解码上下文。 |
| `B64InitializeEncoding` | `var cont: TBase64Context; LineSize: Integer; fEOL: TBase64EOLMarker; TrailingEol: Boolean` | `Boolean` | 初始化编码上下文。 |
| `B64Encode` | `var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer` | `Boolean` | 分块 Base64 编码。 |
| `B64Decode` | `var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer` | `Boolean` | 分块 Base64 解码。 |
| `B64FinalizeEncoding` | `var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer` | `Boolean` | 完成编码（写入填充和换行）。 |
| `B64FinalizeDecoding` | `var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer` | `Boolean` | 完成解码（处理剩余数据）。 |
| `umlBase64Encode` | `InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; WrapLines: Boolean` | `Boolean` | 高级 Base64 编码（支持换行）。 |
| `umlBase64Decode` | `InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; LiberalMode: Boolean` | `Integer` | 高级 Base64 解码（支持宽松模式）。 |
| `umlBase64EncodeBytes` | `var sour, dest: TBytes` | - | TBytes → TBytes Base64 编码。 |
| `umlBase64DecodeBytes` | `var sour, dest: TBytes` | - | TBytes → TBytes Base64 解码。 |
| `umlBase64EncodeBytes` | `var sour: TBytes; var dest: TPascalString` | - | TBytes → TPascalString Base64 编码。 |
| `umlBase64DecodeBytes` | `const sour: TPascalString; var dest: TBytes` | - | TPascalString → TBytes Base64 解码。 |
| `umlDecodeLineBASE64` | `const buffer: TPascalString; var output: TPascalString` | - | 解码 Base64 字符串到 TPascalString。 |
| `umlEncodeLineBASE64` | `const buffer: TPascalString; var output: TPascalString` | - | 编码 TPascalString 到 Base64。 |
| `umlDecodeLineBASE64` | `const buffer: TPascalString` | `TPascalString` | 返回解码后的字符串。 |
| `umlEncodeLineBASE64` | `const buffer: TPascalString` | `TPascalString` | 返回 Base64 编码的字符串。 |
| `umlDecodeStreamBASE64` | `const buffer: TPascalString; output: TCore_Stream` | - | 解码 Base64 字符串并写入流。 |
| `umlEncodeStreamBASE64` | `buffer: TCore_Stream; var output: TPascalString` | - | 将流内容编码为 Base64 字符串。 |
| `umlDivisionBase64Text` | `buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean` | `TPascalString` | 按宽度分行 Base64 文本。 |
| `umlTestBase64` | `text: TPascalString` | `Boolean` | 测试字符串是否为有效的 Base64。 |

---

## 14. URL 与 HTML 编码函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlEncodeText2HTML` | `psSrc: TPascalString` | `TPascalString` | HTML 实体编码。 |
| `umlURLEncode` | `Data: TPascalString` | `TPascalString` | URL 百分号编码。 |
| `umlURLDecode` | `Data: TPascalString; FormEncoded: Boolean` | `TPascalString` | URL 解码。 |

---

## 15. 批量替换与文本处理函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlBuildBatch` | `L: THashStringList` / `THashVariantList` | `TArrayBatch` | 从哈希表构建批量替换数组（Key→Value）。 |
| `umlClearBatch` | `var arry: TArrayBatch` | - | 清空批量替换数组。 |
| `umlSortBatch` | `var arry: TArrayBatch` | - | 按源字符串长度降序排序（最长匹配优先）。 |
| `umlCharIsSymbol` | `C: SystemChar; CustomSymbol_: TArrayChar` | `Boolean` | 判断字符是否为符号。 |
| `umlIsWord` | `p: PPascalString; bPos, ePos: Integer` / `S: TPascalString; bPos, ePos: Integer` | `Boolean` | 判断子串是否为完整单词（边界为符号）。 |
| `umlExtractWord` | `S: TPascalString; CustomSymbol_: TArrayChar` | `TArrayPascalString` | 提取字符串中的所有单词。 |
| `umlBatchSum` | 多种重载 | `Integer` | 统计批量替换模式的出现次数（不执行替换）。 |
| `umlBatchReplace` | 多种重载 | `TPascalString` | 执行批量替换。 |
| `umlReplaceSum` | 多种重载 | `Integer` | 统计单个模式的出现次数。 |
| `umlReplace` | 多种重载 | `TPascalString` | 执行单模式替换（支持回调）。 |
| `umlComputeTextPoint` | `p: PPascalString; Pos_: Integer` | `TPoint` | 计算字符位置的行列号（`X=列, Y=行`）。 |

---

## 16. 时间与日期函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlDefaultTime` | - | `Double` | 返回 `Now`。 |
| `umlNow` | - | `Double` | 返回当前日期时间。 |
| `umlTime` | - | `Double` | 返回当前时间。 |
| `umlDate` | - | `Double` | 返回当前日期。 |
| `umlStrToTime` | `S: TPascalString` | `TDateTime` | 字符串转时间。 |
| `umlTimeToStr` | `t: TDateTime` | `TPascalString` | 时间转字符串。 |
| `umlStrToDateTime` | `S: TPascalString` | `TDateTime` | 字符串转日期时间。 |
| `umlDateTimeToStr` | `t: TDateTime` | `TPascalString` | 日期时间转字符串。 |
| `umlDT` | 多种重载 | 多种 | 日期时间快捷转换。 |
| `umlT` | 多种重载 | 多种 | 时间快捷转换。 |
| `umlDateToStr` | `t: TDateTime` | `TPascalString` | 日期转字符串。 |
| `umlGetDateTimeStr` | `NowDateTime: TDateTime` | `TPascalString` | `YYYY-MM-DD HH-MM-SS-MS` 格式。 |
| `umlDecodeTimeToStr` | `NowDateTime: TDateTime` | `TPascalString` | 压缩十六进制格式。 |
| `umlDecodeDateTimeToInt64` | `NowDateTime: TDateTime` | `Int64` | 转 Unix 时间戳。 |
| `umlTimeTickToStr` | `t: TTimeTick` | `TPascalString` | 毫秒数转可读时间。 |

---

## 17. 动态库加载函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `GetExtLib` | `LibName: SystemString` | `HMODULE` | 加载动态库（带缓存）。 |
| `FreeExtLib` | `LibName: SystemString` | `Boolean` | 卸载动态库（清除缓存）。 |
| `GetExtProc` | `LibName, ProcName: SystemString` | `Pointer` | 获取动态库中的过程地址（带缓存）。 |

---

## 18. RTSP/RTMP URL 解析函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlExtract_RTSP_RTMP_URL` | `URL: TPascalString; var prefix, user, passwd, host, port, path: TPascalString` | `Boolean` | 解析 RTSP/RTMP URL 到各组件。 |
| `umlExtract_RTSP_RTMP_URL` | `URL: TPascalString; var To_: TRTSP_RTMP_URL` | `Boolean` | 解析到记录。 |
| `umlEncode_RTSP_RTMP_URL` | `prefix, user, passwd, host, port, path: TPascalString` | `TPascalString` | 从组件编码 URL。 |
| `umlRemove_Passwd_RTSP_RTMP_URL` | `URL: TPascalString` | `TPascalString` | 移除 URL 中的密码部分。 |

---

## 19. CSV 导入函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `ImportCSV_C` | `sour: TArrayPascalString; OnNotify: TCSVSave_C` | - | 从字符串数组导入 CSV（C 风格回调）。 |
| `CustomImportCSV_C` | `OnGetLine: TCSVGetLine_C; OnNotify: TCSVSave_C` | - | 自定义行读取的 CSV 导入（C 风格）。 |
| `ImportCSV_M` | `sour: TArrayPascalString; OnNotify: TCSVSave_M` | - | 从字符串数组导入 CSV（M 风格回调）。 |
| `CustomImportCSV_M` | `OnGetLine: TCSVGetLine_M; OnNotify: TCSVSave_M` | - | 自定义行读取的 CSV 导入（M 风格）。 |
| `ImportCSV_P` | `sour: TArrayPascalString; OnNotify: TCSVSave_P` | - | 从字符串数组导入 CSV（P 风格回调）。 |
| `CustomImportCSV_P` | `OnGetLine: TCSVGetLine_P; OnNotify: TCSVSave_P` | - | 自定义行读取的 CSV 导入（P 风格）。 |

---

## 20. 组件操作函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlUpdateComponentName` | `Name: TPascalString` | `TPascalString` | 净化组件名（仅保留字母数字和 `-`）。 |
| `umlMakeComponentName` | `Owner: TCore_Component; RefrenceName: TPascalString` | `TPascalString` | 生成唯一的组件名（基于 Owner 查找）。 |
| `umlReadComponent` | `stream: TCore_Stream; comp: TCore_Component` | - | 从流中读取组件。 |
| `umlWriteComponent` | `stream: TCore_Stream; comp: TCore_Component` | - | 将组件写入流。 |
| `umlCopyComponentDataTo` | `comp, copyto: TCore_Component` | - | 复制组件数据到另一个同类型组件。 |

---

## 21. 杂项工具函数

| 函数名 | 参数 | 返回值 | 说明 |
| :--- | :--- | :--- | :--- |
| `umlSetLength` | 多种重载 | - | 设置字符串/数组长度。 |
| `umlGetLength` | 多种重载 | `Integer` | 获取字符串/数组长度。 |
| `umlBufferIsASCII` | `buffer: Pointer; siz: NativeUInt` | `Boolean` | 检查内存块是否全为 ASCII（< 128）。 |
| `umlProcessCycleValue` | `CurrentVal, DeltaVal, StartVal, OverVal: Single; var EndFlag: Boolean` | `Single` | 在 `StartVal` 和 `OverVal` 之间循环振荡。 |
| `umlSameVarValue` / `umlSameVariant` | `v1, v2: Variant` | `Boolean` | 比较两个 Variant 是否相等。 |
| `umlCompareByteString` | 多种重载 | `Boolean` | 比较 Pascal 字符串与原始字节数组。 |
| `umlSetByteString` | 多种重载 | - | Pascal 字符串 ↔ 原始字节数组转换。 |
| `umlGetByteString` | `sour: PArrayRawByte; L: Integer` | `TPascalString` | 从原始字节数组读取 Pascal 字符串。 |

---

> 本手册基于 `Z.UnicodeMixedLib.pas` 接口部分整理，覆盖了全部导出成员。具体实现细节请参考源码。
