# Z.UnicodeMixedLib 知识库（最终传承版）

> **定位**：面向 AI 与人类工程师的权威参考。目标是让读者**无需翻阅源码**即可安全、准确地使用 `Z.UnicodeMixedLib`。
> **承诺**：所有描述均来自 `Z.UnicodeMixedLib.pas` 的逐行核对。凡我无法从源码确定的，在文末「诚实的不确定清单」中明示。
> **制图约定**：全文流程图/架构图/决策树一律使用 Mermaid，不使用字符制图。

---

## 第 0 章 快速定位：这个单元是什么

`Z.UnicodeMixedLib` 是 Z 框架的**通用工具库**（"Unicode Mixed" 名不副实，实际是**跨编译器、跨平台的杂项工具集**）。它由以下子系统组成：

```mermaid
flowchart TD
    subgraph L0["依赖层"]
        C1["Z.Core (TCompute / MT19937 / TBigList)"]
        C2["Z.PascalStrings / Z.UPascalStrings"]
        C3["Z.Int128 / Z.ListEngine / Z.MemoryStream"]
        C4["Z.Cipher / Z.Status / Z.FragmentBuffer / Z.Json / Z.HashList.Templet"]
    end

    subgraph L1["本单元子系统"]
        FS["文件系统<br/>umlFileExists / umlFindFirst* / umlGetFileName"]
        IO["高级 I/O<br/>TIOHnd / TReliableFileStream"]
        STR["字符串<br/>umlGetFirstStr / umlReplace / umlMultipleMatch"]
        CNV["类型转换<br/>umlStrToInt / umlVarToStr / umlGetNumTextType"]
        ENC["编码 & 哈希<br/>Base64 / URL / HTML / MD5 / CRC16 / CRC32"]
        RND["随机<br/>umlRandom / umlRandomRange"]
        MDC["文件 MD5 缓存<br/>umlFileMD5 / umlCacheFileMD5"]
        URL["RTSP/RTMP URL 解析"]
        COMP["组件持久化<br/>umlReadComponent / umlWriteComponent"]
        CSV["CSV 导入"]
        LIB["动态库加载<br/>GetExtLib / GetExtProc"]
        MISC["杂项<br/>umlBinToUInt* / SaveMemory / umlBufferIsASCII"]
    end

    L0 --> L1

    style L0 fill:#e8f4ff,stroke:#444
    style L1 fill:#fff7e6,stroke:#444
```

**命名约定**：
- 所有函数前缀 `uml`（UnicodeMixedLib）。
- 无 `uml` 前缀的是 Pascal/Delphi 风格的函数（如 `B64Encode`、`ImportCSV_C`、`GetExtLib`）。
- 类型别名 `U_String = TPascalString`，`U_SystemString = SystemString`，`U_Char = SystemChar`，`U_Bytes = TBytes`，`U_Stream = TCore_Stream`，`TSR = TSearchRec`。

---

## 第 1 章 类型定义与常量

### 1.1 类型别名

```pascal
type
  U_SystemString = SystemString;         // = AnsiString (FPC) / string (Delphi)
  U_String       = TPascalString;        // 统一字符串
  U_Char         = SystemChar;           // = AnsiChar (FPC) / Char (Delphi)
  U_StringArray  = array of U_SystemString;
  U_ArrayString  = U_StringArray;
  U_Bytes        = TBytes;
  TSR            = TSearchRec;
  U_Stream       = TCore_Stream;
```

### 1.2 常量

```pascal
const
  // 数据类型尺寸
  C_Max_UInt32       = $FFFFFFFF;
  C_Address_Size     = SizeOf(Pointer);      // 4 或 8
  C_Pointer_Size     = C_Address_Size;
  C_Integer_Size     = 4;
  C_Int64_Size       = 8;
  C_UInt64_Size      = 8;
  C_Int128_Size      = 16;
  C_UInt128_Size     = 16;
  C_Single_Size      = 4;
  C_Double_Size      = 8;
  C_Small_Int_Size   = 2;
  C_Byte_Size        = 1;
  C_Short_Int_Size   = 1;
  C_Word_Size        = 2;
  C_DWord_Size       = 4;
  C_Cardinal_Size    = 4;
  C_Boolean_Size     = 1;
  C_Bool_Size        = 1;
  C_MD5_Size         = 16;

  // I/O 缓存尺寸
  C_PrepareReadCacheSize = 512;              // 读预取缓存
  C_Buffer_Chunk_Size    = $F000;            // 61440 字节，大块读写阈值

  // TIOHnd 错误码（负数）
  C_Flush_And_Seek_Error = -912;
  C_StringError          = -911;
  C_SeekError            = -910;
  C_FileWriteError       = -909;
  C_FileReadError        = -908;
  C_FileHandleError      = -907;
  C_OpenFileError        = -905;
  C_NotOpenFile          = -904;
  C_CreateFileError      = -903;
  C_FileIsActive         = -902;
  C_NotFindFile          = -901;
  C_NotError             = -900;

  // Base64 错误码（正数）
  BASE64_DECODE_OK                   = 0;
  BASE64_DECODE_INVALID_CHARACTER    = 1;
  BASE64_DECODE_WRONG_DATA_SIZE      = 2;
  BASE64_DECODE_NOT_ENOUGH_SPACE     = 3;
```

### 1.3 全局变量

```pascal
var
  Lib_DateTimeFormatSettings: TFormatSettings;  // 日期时间格式（初始化时设为 ISO）
```

**`Lib_DateTimeFormatSettings` 默认值**（源码初始化）：
- `ShortDateFormat` = `'yyyy-MM-dd'`
- `LongDateFormat` = `'yyyy-MM-dd'`
- `DateSeparator` = `'-'`
- `TimeSeparator` = `':'`
- `DecimalSeparator` = `'.'`
- `LongTimeFormat` = `'hh:mm:ss.zz'`
- `ShortTimeFormat` = `'hh:mm:ss.zz'`

---

## 第 2 章 文件系统操作

### 2.1 存在性与目录

```pascal
function umlFileExists(const FileName: TPascalString): Boolean;
function umlDirectoryExists(const DirectoryName: TPascalString): Boolean;
function umlCreateDirectory(const DirectoryName: TPascalString): Boolean;
function umlCurrentDirectory: TPascalString;
function umlCurrentPath: TPascalString;        // 带尾部分隔符
function umlGetCurrentPath: TPascalString;     // 别名
procedure umlSetCurrentPath(ph: TPascalString);
```

**契约**：

| 函数 | 行为 |
|------|------|
| `umlFileExists` | `FileName.L = 0` 时返回 False；否则调用 `SysUtils.FileExists` |
| `umlDirectoryExists` | `DirectoryName.L = 0` 时返回 False |
| `umlCreateDirectory` | 目录已存在返回 True；否则 `ForceDirectories`；失败再试 `CreateDir`；都不行返回 False |
| `umlCurrentPath` | 平台相关：Windows 尾部补 `'\'`，其他平台补 `'/'` |

### 2.2 文件搜索

```pascal
function umlFindFirstFile(const FileName: TPascalString; var SR: TSR): Boolean;
function umlFindNextFile(var SR: TSR): Boolean;
function umlFindFirstDir(const DirName: TPascalString; var SR: TSR): Boolean;
function umlFindNextDir(var SR: TSR): Boolean;
procedure umlFindClose(var SR: TSR);
```

**契约**：
- **`umlFindFirstFile` / `umlFindNextFile` 跳过目录**（只返回 `(SR.Attr and faDirectory) <> faDirectory` 的项）。
- **`umlFindFirstDir` / `umlFindNextDir` 跳过 `'.'` 和 `'..'`**，只返回真正的子目录。
- **不要自己调用 `FindClose`**，用 `umlFindClose`。
- **`umlFindClose` 在 `FindFirst` 失败后调用是安全的**（`SysUtils.FindClose` 会忽略无效句柄）。

### 2.3 目录内容枚举

```pascal
function uml_Get_File_To_List(const FullPath: TPascalString; AsLst: TCore_Strings): Integer; overload;
function uml_Get_Dir_To_List (const FullPath: TPascalString; AsLst: TCore_Strings): Integer; overload;
function uml_Get_File_To_List(const FullPath: TPascalString; AsLst: TPascalStringList): Integer; overload;
function uml_Get_Dir_To_List (const FullPath: TPascalString; AsLst: TPascalStringList): Integer; overload;

function umlGet_File_Full_Array(const FullPath: TPascalString): U_StringArray;  // 文件全路径
function umlGet_Path_Full_Array(const FullPath: TPascalString): U_StringArray;  // 子目录全路径
function umlGet_File_Array     (const FullPath: TPascalString): U_StringArray;  // 文件名
function umlGet_Path_Array     (const FullPath: TPascalString): U_StringArray;  // 子目录名
```

**契约**：
- 内部用 `umlFindFirstFile(umlCombineFileName(FullPath, '*'))`，**不递归**。
- 返回的列表元素是**文件名**（不含路径）或**目录名**（不含路径）。
- `umlGet_File_Full_Array` / `umlGet_Path_Full_Array` 会在文件名前拼接 `FullPath`。

### 2.4 路径操作

```pascal
function umlFixedPath(S: TPascalString): TPascalString;                     // 规范化 + 尾部加分隔符
function umlCombinePath(const s1, s2: TPascalString): TPascalString;         // 平台感知
function umlCombineFileName(const pathName, FileName: TPascalString): TPascalString;
function umlCombineUnixPath(const s1, s2: TPascalString): TPascalString;     // 强制 '/'
function umlCombineUnixFileName(const pathName, FileName: TPascalString): TPascalString;
function umlCombineWinPath(const s1, s2: TPascalString): TPascalString;      // 强制 '\'
function umlCombineWinFileName(const pathName, FileName: TPascalString): TPascalString;

function umlGetFileName(platform_: TExecutePlatform; const S: TPascalString): TPascalString; overload;
function umlGetFileName(const S: TPascalString): TPascalString; overload;
function umlGetWindowsFileName(const S: TPascalString): TPascalString;
function umlGetUnixFileName(const S: TPascalString): TPascalString;

function umlGetFilePath(platform_: TExecutePlatform; const S: TPascalString): TPascalString; overload;
function umlGetFilePath(const S: TPascalString): TPascalString; overload;
function umlGetWindowsFilePath(const S: TPascalString): TPascalString;
function umlGetUnixFilePath(const S: TPascalString): TPascalString;

function umlChangeFileExt(const S, ext: TPascalString): TPascalString;
function umlGetFileExt(const S: TPascalString): TPascalString;
```

**`umlCombinePath` / `umlCombineWinPath` / `umlCombineUnixPath` 的差异**：

```mermaid
flowchart TD
    A["umlCombineXxxPath(s1, s2)"] --> B["1. Trim 输入"]
    B --> C["2. 统一分隔符为 '/' (Unix) 或 '\\' (Win)"]
    C --> D["3. 去掉 s2 的前导分隔符"]
    D --> E["4. 拼接（s1 尾部保证有分隔符）"]
    E --> F["5. 循环替换 '//' → '/' 或 '\\\\' → '\\'"]
    F --> G{"哪个版本？"}

    G -- "umlCombineXxxPath" --> H["尾部分隔符保留"]
    G -- "umlCombineXxxFileName" --> I["删除 s2 的前导和尾部分隔符\n（结果不含尾部分隔符）"]

    style I fill:#e8ffe8,stroke:#0a0
```

**`umlCombineWinPath` 特例**：**会在末尾保证 `'\'`**（因为它是"路径"）。
**`umlCombineWinFileName` 特例**：**会删除末尾的 `'\'`**（因为它是"文件名"）。

**`umlGetFileName` / `umlGetFilePath` 契约**：

| 输入 | `umlGetFileName` 返回 | `umlGetFilePath` 返回 |
|------|----------------------|----------------------|
| `'C:\a\b.txt'` | `'b.txt'` | `'C:\a\'` |
| `'C:\a\'` | `''` | `'C:\a\'` |
| `'C:\a'` | `'a'` | `''` |
| `''` | `''` | `''` |
| `'C:'` | `'C:'`（Windows 下 `umlMultipleMatch('?:', Result)` 会补 `'\'`） | — |

**`umlChangeFileExt` 契约**：
- `ext` 无前导 `.` 时自动补 `.`。
- 若原文件有扩展名，替换；否则追加。

### 2.5 文件时间与大小

```pascal
function umlGetFileTime(const FileName: TPascalString): TDateTime;   // 修改时间
procedure umlSetFileTime(const FileName: TPascalString; newTime: TDateTime);
function umlGetFileSize(const FileName: TPascalString): Int64;       // 支持通配符（累加）
function umlGetFileCount(const FileName: TPascalString): Integer;    // 支持通配符（计数）
function umlGetFileDateTime(const FileName: TPascalString): TDateTime; // FileAge
```

**契约**：
- `umlGetFileSize` 和 `umlGetFileCount` **支持通配符**（如 `*.txt`），会把所有匹配文件的大小/数量累加。
- `umlGetFileTime` 在 Windows 下用 `FindFirst` + `ftLastWriteTime`；非 Windows 下用 `FileOpen` + `FileGetDate`。
- **失败时返回 `0`（TDateTime）**，不抛异常。
- `umlGetFileDateTime` 使用 `FileAge(FileName, Result, False)`；失败时返回 `Now`。

### 2.6 文件增删改

```pascal
function umlDeleteFile(const FileName: TPascalString; const _VerifyCheck: Boolean): Boolean; overload;
function umlDeleteFile(const FileName: TPascalString): Boolean; overload;
function umlCopyFile(const SourFile, DestFile: TPascalString): Boolean;
function umlRenameFile(const OldName, NewName: TPascalString): Boolean;
```

**`umlDeleteFile` 的精确行为**：

```mermaid
flowchart TD
    A["umlDeleteFile(FileName, _VerifyCheck)"] --> B{"FileName 含通配符？"}
    B -- "含 '*?'" --> C["FindFirstFile 遍历\n逐个 DeleteFile"]
    C --> D["Result := True（无论成功与否）"]
    B -- "不含" --> E["DeleteFile(FileName)"]
    E --> F{"Result and _VerifyCheck？"}
    F -- "是" --> G["Result := not umlFileExists(FileName)"]
    F -- "否" --> H["Result := True"]

    style D fill:#ffe6e6,stroke:#a00
    style H fill:#ffe6e6,stroke:#a00
```

**⚠️ 两个已知缺陷**（源码行为）：
1. **通配符删除**：不管实际删除成功与否，都返回 True。若某个文件被占用删不掉，用户不会察觉。
2. **`_VerifyCheck=False`**：如果 `DeleteFile` 返回 False（比如文件不存在），`Result` 被 **强行改成 True**。

**建议**：需要可靠删除时，用 `_VerifyCheck=True` 并自己检查结果。

**`umlCopyFile` 契约**：
- 源文件不存在返回 False。
- 源与目标完全相同（`ExpandFileName` 后比较）返回 False。
- 复制成功后**保留源文件的修改时间**到目标。

---

## 第 3 章 `TIOHnd` 文件 I/O

### 3.1 结构

```pascal
TIOHnd = record
  IsOnlyRead: Boolean;
  IsOpen: Boolean;
  AutoFree: Boolean;           // True 表示 Close 时释放 Handle
  Handle: U_Stream;
  Time: TDateTime;
  Size: Int64;
  Position: Int64;
  FileName: U_String;
  Cache: TIOHnd_Cache;         // 读/写缓存
  IORead, IOWrite: Int64;      // 累计读/写字节数
  ChangeFromWrite: Boolean;
  FixedStringL: Byte;          // 默认 65 = 64 + 1
  Data: Pointer;
  Return: Integer;             // 最后错误码
  function FixedString2Pascal(S: TBytes): TPascalString;
  procedure Pascal2FixedString(var n: TPascalString; var out_: TBytes);
  function CheckFixedStringLoss(S: TPascalString): Boolean;
end;

TIOHnd_Cache = record
  PrepareWriteBuff: U_Stream;    // 写缓存
  PrepareReadPosition: Int64;
  PrepareReadBuff: U_Stream;     // 读缓存
  UsedWriteCache: Boolean;
  UsedReadCache: Boolean;
end;
```

### 3.2 生命周期

```mermaid
flowchart LR
    A["InitIOHnd"] --> B["umlFileCreate\numlFileOpen\numlFileCreateAsMemory\numlFileCreateAsStream\numlFileOpenAsStream"]
    B --> C["读写 / Seek / SetSize"]
    C --> D["umlFileUpdate\n（flush）"]
    D --> B
    C --> E["umlFileClose"]
    E --> F["Handle := nil\n（AutoFree=True 时释放）"]

    style A fill:#e8f4ff,stroke:#444
    style E fill:#ffe6e6,stroke:#444
```

### 3.3 初始化与打开

```pascal
procedure InitIOHnd(var IOHnd: TIOHnd);
function umlFileCreate(const FileName: TPascalString; var IOHnd: TIOHnd): Boolean;
function umlFileOpen(const FileName: TPascalString; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean;
function umlFileCreateAsMemory(var IOHnd: TIOHnd): Boolean;
function umlFileCreateAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean; overload;
function umlFileCreateAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd): Boolean; overload;
function umlFileCreateAsStream(stream: U_Stream; var IOHnd: TIOHnd): Boolean; overload;
function umlFileCreateAsStream(stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean; overload;
function umlFileOpenAsStream(const FileName: TPascalString; stream: U_Stream; var IOHnd: TIOHnd; OnlyRead_: Boolean): Boolean;
```

**契约**：

| 函数 | `AutoFree` | `UsedWriteCache` | `UsedReadCache` | `FixedStringL` |
|------|-----------|------------------|-----------------|-----------------|
| `InitIOHnd` | False | False | False | 65 |
| `umlFileCreate` | True | True | True | 65 |
| `umlFileOpen` | True | True | True | 65 |
| `umlFileCreateAsMemory` | True | False | False | 65 |
| `umlFileCreateAsStream` | False | 若 Handle 是 FileStream/ReliableFileStream 则 True | 同左 | 65 |
| `umlFileOpenAsStream` | False | 同左 | 同左 | 65 |

**重要细节**：
- **`umlFileCreate` / `umlFileOpen` 使用 `TReliableFileStream`**（见 §3.7）。
- **`umlFileCreateAsStream` / `umlFileOpenAsStream` 在 `FileName=''` 时**会从 `Handle` 猜测文件名（若 Handle 是 `TCore_FileStream` / `TReliableFileStream` / `TSafe_Flush_Stream`）。
- **`IsOpen=True` 时调用任何 Open/Create 都会失败并设 `Return = C_FileIsActive`**。

### 3.4 关闭与更新

```pascal
function umlFileClose(var IOHnd: TIOHnd): Boolean;
function umlFileUpdate(var IOHnd: TIOHnd): Boolean;
function umlFileTest(var IOHnd: TIOHnd): Boolean;
```

**`umlFileClose` 精确行为**：
1. 若 `IsOpen=False` → `Return := C_NotOpenFile`，返回 False。
2. 若 `Handle=nil` → `Return := C_FileHandleError`，返回 False。
3. `umlFileFlushWriteCache` 刷新写缓存。
4. 释放 `PrepareReadBuff`，置 `PrepareReadPosition := -1`。
5. **`AutoFree=True` 时 `DisposeObject(Handle)`；否则 `Handle := nil`**。
6. 重置所有字段。

**⚠️ 陷阱**：**即使 `AutoFree=False`，`Handle` 也会被置 nil**。如果调用方需要在 Close 后继续使用 Handle，必须提前保存引用。

**`umlFileUpdate` 行为**：
- 刷新写缓存 + 重置读缓存。
- 若 Handle 是 `TSafe_Flush_Stream` → 调 `Flush`。
- 若 Handle 是 `TCore_FileStream` → Windows 下调 `FlushFileBuffers`。
- `ChangeFromWrite := False`。

### 3.5 读操作

```pascal
procedure umlResetPrepareRead(var IOHnd: TIOHnd);
function umlFilePrepareRead(var IOHnd: TIOHnd; Size: Int64; var buff): Boolean;
function umlFileRead(var IOHnd: TIOHnd; const Size: Int64; var buff): Boolean;
function umlBlockRead(var IOHnd: TIOHnd; var buff; const Size: Int64): Boolean;
```

**`umlFileRead` 执行流程**：

```mermaid
flowchart TD
    A["umlFileRead(Size, buff)"] --> B["FlushWriteCache"]
    B --> C{"Size = 0？"}
    C -- "是" --> D["返回 True"]
    C -- "否" --> E["umlFilePrepareRead"]
    E --> F{"读缓存命中？"}
    F -- "是" --> G["CopyPtr 从缓存\n返回 True"]
    F -- "否" --> H{"Size &gt; C_Buffer_Chunk_Size (61440)？"}
    H -- "是" --> I["按 61440 分块读"]
    H -- "否" --> J["直接 Handle.Read"]

    I --> K["累计 IORead + Position"]
    J --> K
    K --> L["返回 True"]

    style G fill:#e8ffe8,stroke:#0a0
    style I fill:#fff7e6,stroke:#444
```

**读缓存逻辑（`umlFilePrepareRead`）**：
- 若 `Size > C_PrepareReadCacheSize (512)` → **放弃缓存**，直接读。
- 若缓存未命中（当前位置不在缓存范围内）→ 从当前位置预读 512 字节。
- 命中 → 从缓存 `CopyPtr` 到 `buff`，`Position += Size`。
- **预读失败返回 False，调用方回退到直接读**。

### 3.6 写操作

```pascal
function umlFilePrepareWrite(var IOHnd: TIOHnd): Boolean;
function umlFileFlushWriteCache(var IOHnd: TIOHnd): Boolean;
function umlFileWrite(var IOHnd: TIOHnd; const Size: Int64; const buff): Boolean;
function umlBlockWrite(var IOHnd: TIOHnd; const buff; const Size: Int64): Boolean;
function umlFileWriteFixedString(var IOHnd: TIOHnd; var Value: TPascalString): Boolean;
function umlFileReadFixedString(var IOHnd: TIOHnd; var Value: TPascalString): Boolean;
```

**`umlFileWrite` 执行流程**：

```mermaid
flowchart TD
    A["umlFileWrite(Size, buff)"] --> B{"IsOnlyRead 或 IsOpen=False？"}
    B -- "是" --> Z["Return := C_FileWriteError\n返回 False"]
    B -- "否" --> C{"Size = 0？"}
    C -- "是" --> D["返回 True"]
    C -- "否" --> E["ChangeFromWrite := True\nResetPrepareRead"]
    E --> F{"Size &lt;= 61440？"}
    F -- "是" --> G["umlFilePrepareWrite\n（创建 8MB 缓冲）"]
    F -- "否" --> H["直接用 Handle.Write 分块"]
    G --> I{"PrepareWriteBuff 非 nil？"}
    I -- "是" --> J["写入缓冲\n若 &gt; 8MB 则 flush"]
    I -- "否" --> H
    J --> K["更新 Position / Size / IOWrite"]
    H --> K

    style Z fill:#ffe6e6,stroke:#a00
```

**写缓存细节**：
- **`PrepareWriteBuff` 只在第一次写时创建**，大小 8MB。
- **超过 8MB 自动 Flush**。
- **`Size > 61440` 时绕过缓存**直接写。
- **`Position` 和 `Size` 每次写后都会更新**（不管是否走缓存）。

**`umlFileWriteFixedString` / `umlFileReadFixedString`**：
- 使用 `FixedStringL`（默认 65）作为固定字段长度。
- 格式：`[长度字节(1 byte)] [数据字节(FixedStringL-1 bytes)]`。
- **`Pascal2FixedString` 会自动截断过长的字符串**（按字节）。
- **`CheckFixedStringLoss` 可以检测是否会被截断**。

**⚠️ 陷阱**：**`FixedStringL` 是字节数**，不是字符数。对 `TPascalString` 而言，FPC 下 1 字符 = 1 字节，Delphi 下 1 字符 = 2 字节。

### 3.7 `TReliableFileStream`（备份文件流）

```pascal
TReliableFileStream = class(TCore_Stream)
protected
  FSource_IO, FBackup_IO: TCore_FileStream;
  FActivted: Boolean;
  FFileName, Backup_FileName: SystemString;
  procedure InitIO;
  procedure FreeIO;
  procedure SetSize(const NewSize: Int64); override;
  procedure SetSize(NewSize: longint); override;
public
  constructor Create(const FileName_: SystemString; IsNew_, IsWrite_: Boolean);
  destructor Destroy; override;
  property FileName: SystemString read FFileName;
  property BackupFileName: SystemString read Backup_FileName;
  property Activted: Boolean read FActivted;
  function Write(const buffer; Count: longint): longint; override;
  function Read(var buffer; Count: longint): longint; override;
  function Seek(const Offset: Int64; origin: TSeekOrigin): Int64; override;
end;
```

**激活条件**：
- **只有 `{$DEFINE ZDB_BACKUP}` 时 `FActivted` 才可能为 True**（源码 `{$IFDEF ZDB_BACKUP}` 分支）。
- **默认未定义**，所以 `FActivted=False`，行为等价于直接操作 `FSource_IO`。

**激活后行为**：
1. 构造时把 `FileName` 拷贝到 `FileName.save`。
2. 之后所有读写都作用于 `FBackup_IO`（`.save` 文件）。
3. `Destroy` 时：删除原文件，把 `.save` 重命名为原文件。

**⚠️ 已知依赖**：`FreeIO` 使用 `umlDeleteFile` + `umlRenameFile`。**`umlDeleteFile` 有缺陷**（见 §2.6），若原文件删除失败，重命名会失败，导致备份文件残留。

---

## 第 4 章 字符串操作

### 4.1 大小写与比较

```pascal
function umlUpperCase(const S: TPascalString): TPascalString; overload;
function umlUpperCase(const S: PPascalString): TPascalString; overload;
function umlLowerCase(const S: TPascalString): TPascalString; overload;
function umlLowerCase(const S: PPascalString): TPascalString; overload;
function umlSameText(const s1, s2: TPascalString): Boolean; overload;
function umlSameText(const s1, s2: PPascalString): Boolean; overload;
function umlCompareText(s1, s2: TPascalString): Integer;  // 返回 -1/0/1
```

**`umlUpperCase` / `umlLowerCase` 契约**：
- 直接调用 `S.UpperText` / `S.LowerText`（即 `SysUtils.UpperCase` / `LowerCase`）。
- **对中文无效**（只对 ASCII 字母生效）。

**`umlCompareText` 特殊逻辑**（源码）：
1. **先比较是否"宽字符"**（含 `Ord(C) > 127`）。
2. 若宽字符状态不同，**宽字符的排后**。
3. 若宽字符状态相同，比较长度（短的排前）。
4. 长度相同，调用 `SysUtils.CompareText`（大小写不敏感）。

### 4.2 字符集合操作

```pascal
function umlDeleteChar(const SText, Ch: TPascalString): TPascalString; overload;
function umlDeleteChar(const SText: TPascalString; const SomeChars: TArrayChar): TPascalString; overload;
function umlDeleteChar(const SText: TPascalString; const SomeCharsets: TOrdChars): TPascalString; overload;
function umlTrimChar(const S, trim_s: TPascalString): TPascalString;
function umlReplaceChar(const S: TPascalString; OldPattern, NewPattern: U_Char): TPascalString;
function umlCharReplace(const S: TPascalString; OldPattern, NewPattern: U_Char): TPascalString;
```

**契约**：
- `umlDeleteChar` **返回新字符串**，不修改自身。
- `umlTrimChar` **两端都裁剪**，`trim_s` 是"字符集合"。
- `umlReplaceChar` / `umlCharReplace` 是**别名**，行为相同。

### 4.3 数字提取与字符检测

```pascal
function umlGetNumberCharInText(const n: TPascalString): TPascalString;
function umlMatchChar(CharValue: U_Char; cVal: PPascalString): Boolean; overload;
function umlMatchChar(CharValue: U_Char; cVal: TPascalString): Boolean; overload;
function umlExistsChar(StrValue: TPascalString; cVal: TPascalString): Boolean; overload;
function umlExistsChar(StrValue, cVal: PPascalString): Boolean; overload;
function umlNumberCount(const sVal: TPascalString): Integer;
```

**`umlGetNumberCharInText` 契约**：
- **返回字符串中第一段连续数字**。
- 若开头没有数字，跳过非数字直到找到第一个数字。
- 遇到非数字结束。
- **没有数字时返回空字符串**。

### 4.4 分词（`umlGetFirstStr` 系列）

```pascal
function umlGetFirstStr(const sVal, trim_s: TPascalString): TPascalString;
function umlGetLastStr(const sVal, trim_s: TPascalString): TPascalString;
function umlDeleteFirstStr(const sVal, trim_s: TPascalString): TPascalString;
function umlDeleteLastStr(const sVal, trim_s: TPascalString): TPascalString;
function umlGetIndexStrCount(const sVal, trim_s: TPascalString): Integer;
function umlGetIndexStr(const sVal: TPascalString; trim_s: TPascalString; index: Integer): TPascalString;
```

**连续分隔符语义**（这些函数使用）：**连续的分隔符被视为一个**。

例如 `'a;;b'` 用 `';'` 分词：
- `umlGetIndexStrCount` = **2**
- `umlGetIndexStr(..., 1)` = `'a'`
- `umlGetIndexStr(..., 2)` = `'b'`

**不连续版本（三个下划线）**：

```pascal
function umlGetFirstStr___(const sVal, trim_s: TPascalString): TPascalString;
function umlDeleteFirstStr___(const sVal, trim_s: TPascalString): TPascalString;
function umlGetLastStr___(const sVal, trim_s: TPascalString): TPascalString;
function umlDeleteLastStr___(const sVal, trim_s: TPascalString): TPascalString;
function umlGetIndexStrCount___(const sVal, trim_s: TPascalString): Integer;
function umlGetIndexStr___(const sVal: TPascalString; trim_s: TPascalString; index: Integer): TPascalString;
```

**不连续语义**：**每个分隔符产生一个空 token**。

例如 `'a;;b'` 用 `';'` 分词：
- `umlGetIndexStrCount___` = **3**
- `umlGetIndexStr___(..., 1)` = `'a'`
- `umlGetIndexStr___(..., 2)` = `''`
- `umlGetIndexStr___(..., 3)` = `'b'`

**使用场景**：
- **CSV 解析**用不连续版本（保留空字段）。
- **路径分词、关键词搜索**用连续版本（合并空）。

**`umlGetIndexStr` 的 `index` 语义**：
- `index = -1`：返回空字符串。
- `index = 0` 或 `1`：返回第一个 token。
- `index >= Count`：返回最后一个 token。

### 4.5 分割与组合

```pascal
procedure umlGetSplitArray(const sour: TPascalString; var dest: TArrayPascalString; const splitC: TPascalString); overload;
procedure umlGetSplitArray(const sour: TPascalString; var dest: U_StringArray; const splitC: TPascalString); overload;
function ArrayStringToText(var ary: TArrayPascalString; const splitC: TPascalString): TPascalString;
function umlStringsToSplitText(lst: TCore_Strings; const splitC: TPascalString): TPascalString; overload;
function umlStringsToSplitText(lst: TListPascalString; const splitC: TPascalString): TPascalString; overload;
function umlSeparatorText(Text_: TPascalString; dest: TCore_Strings; SeparatorChar: TPascalString): Integer; overload;
function umlSeparatorText(Text_: TPascalString; dest: THashVariantList; SeparatorChar: TPascalString): Integer; overload;
function umlSeparatorText(Text_: TPascalString; dest: TListPascalString; SeparatorChar: TPascalString): Integer; overload;
function umlSeparatorText(Text_: TPascalString; var dest: U_StringArray; SeparatorChar: TPascalString): Integer; overload;
```

**`umlGetSplitArray`**：
- **使用连续分隔符语义**（`umlGetIndexStrCount` + `umlGetFirstStr`）。
- 特殊：`sour.L = 0` 但 `idxCount = 0` 时，返回长度为 1 且内容为空的数组。

**`umlSeparatorText` 的 `THashVariantList` 版本**：
- 使用 `dest.IncValue(token, 1)` **累加计数**。同一个 token 出现多次会叠加。

### 4.6 文本替换

```pascal
function umlStringReplace(const S, OldPattern, NewPattern: TPascalString; IgnoreCase: Boolean): TPascalString;
function umlReplaceString(const S, OldPattern, NewPattern: TPascalString; IgnoreCase: Boolean): TPascalString;  // 别名
```

**契约**：
- 调用 `SysUtils.StringReplace(S.text, Old, New, [rfReplaceAll] + [rfIgnoreCase])`。
- **不处理 "整词"（OnlyWord）语义**。要整词替换用 `umlReplace`。

### 4.7 高级替换（含整词、位置跟踪）

```pascal
type
  TOnBatchProc = ...;  // procedure(bPos, ePos: Integer; sour, dest: PPascalString; var Accept: Boolean)

  TBatch = record
    sour, dest: TPascalString;
    sum: Integer;
  end;

  TBatchInfo = record
    Batch: Integer;
    sour_bPos, sour_ePos: Integer;
    dest_bPos, dest_ePos: Integer;
  end;

  TBatchInfoList = TGenericsList<TBatchInfo>;

function umlBuildBatch(L: THashStringList): TArrayBatch; overload;
function umlBuildBatch(L: THashVariantList): TArrayBatch; overload;
procedure umlClearBatch(var arry: TArrayBatch);
procedure umlSortBatch(var arry: TArrayBatch);   // 按 sour 长度降序排序

function umlBatchSum(p: PPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer; overload;
function umlBatchReplace(p: PPascalString; var arry: TArrayBatch; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList; On_P: TOnBatchProc): TPascalString; overload;
function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): TPascalString; overload;
function umlReplace(S, OldPattern, NewPattern: TPascalString; OnlyWord, IgnoreCase: Boolean): TPascalString; overload;
function umlReplaceSum(S, Pattern: TPascalString; OnlyWord, IgnoreCase: Boolean; bPos, ePos: Integer; Info: TBatchInfoList): Integer; overload;
```

**契约**：
- **`OnlyWord=True` 时**，只匹配"整词"（用 `umlIsWord` 判断，词边界是"符号字符"）。
- **`umlSortBatch` 按 `sour` 长度降序排序**，确保"最长匹配优先"。
- **`umlReplace` 使用 `TMem64` 累积输出**，性能优于逐字符 `Append`。
- **`On_P` 回调可以设置 `Accept=False` 取消替换**（源码中 `Accept` 参数被声明但实现未使用，**可能是未完成功能**）。

**符号字符定义**（`umlCharIsSymbol`）：

```pascal
[#13, #10, #9, #32, #46, #44, #43, #45, #42, #47, #40, #41, #59, #58, #61, #35, #64, #94,
 #38, #37, #33, #34, #91, #93, #60, #62, #63, #123, #125, #39, #36, #124]
```

即：`CR LF TAB SPACE . , + - * / ( ) ; : = # @ ^ & % ! " [ ] < > ? { } ' $ |`

### 4.8 整词判定与提取

```pascal
function umlIsWord(p: PPascalString; bPos, ePos: Integer): Boolean; overload;
function umlIsWord(S: TPascalString; bPos, ePos: Integer): Boolean; overload;
function umlExtractWord(S: TPascalString): TArrayPascalString; overload;
function umlExtractWord(S: TPascalString; const CustomSymbol_: TArrayChar): TArrayPascalString; overload;
function umlCharIsSymbol(C: SystemChar): Boolean; overload;
function umlCharIsSymbol(C: SystemChar; const CustomSymbol_: TArrayChar): Boolean; overload;
```

**契约**：
- **`umlIsWord(p, bPos, ePos)`**：检查 `p^[bPos..ePos]` 是否是"被符号包围的整词"。
  - `bPos=1` 且 `ePos=p^.L`：True
  - `bPos=1`：只需 `p^[ePos+1]` 是符号
  - `ePos=p^.L`：只需 `p^[bPos-1]` 是符号
  - 其他：两侧都是符号
- **`umlExtractWord` 返回单词数组**（不含符号）。

### 4.9 文本区间操作

```pascal
function umlGetFirstTextPos(const S: TPascalString; const TextArry: TArrayPascalString; var OutText: TPascalString): Integer;
function umlDeleteText(const sour: TPascalString; const bToken, eToken: TArrayPascalString; ANeedBegin, ANeedEnd: Boolean): TPascalString;
function umlGetTextContent(const sour: TPascalString; const bToken, eToken: TArrayPascalString): TPascalString;
```

**语义**：
- `umlGetFirstTextPos`：从 `S` 中找 `TextArry` 里任一 token 的**首次出现位置**（1 基），输出匹配的 token。
- `umlDeleteText`：删除 `bToken` 和 `eToken` 之间的内容。`ANeedBegin` / `ANeedEnd` 控制是否必须存在起始/结束 token。
- `umlGetTextContent`：**提取** `bToken` 和 `eToken` 之间的内容。

**⚠️ 陷阱**：`umlDeleteText` 和 `umlGetTextContent` **递归调用自身**（源码），可能在特定嵌套结构下产生栈溢出。

### 4.10 转义与编码

```pascal
function umlEncodeText2HTML(const psSrc: TPascalString): TPascalString;
function umlURLEncode(const Data: TPascalString): TPascalString;
function umlURLDecode(const Data: TPascalString; FormEncoded: Boolean): TPascalString;
```

**`umlEncodeText2HTML` 转换规则**：

| 字符 | 替换 |
|------|------|
| 空格 | `&nbsp;` |
| `<` | `&lt;` |
| `>` | `&gt;` |
| `&` | `&amp;` |
| `"` | `&quot;` |
| TAB (`#9`) | `&nbsp;&nbsp;&nbsp;&nbsp;` |
| `#13` / `#10` | `<br>`（CRLF 合并为一个） |

**⚠️ 未处理**：`'`（单引号）**不**转换。有些 HTML 场景需要手动处理。

**`umlURLEncode` 契约**：
- **不编码**：`A-Z`、`a-z`、`0-9`、`-`、`.`、`_`、`~`、`/`、`:`。
- **编码**：其他所有字节。
- **先转 UTF-8 再编码**。

**`umlURLDecode` 契约**：
- `FormEncoded=True` 时把 `+` 解码为空格。
- `%XX` 解码。
- **非法 `%XX`（非十六进制字符）会抛异常**。

### 4.11 文本显示与换行

```pascal
function umlDivisionText(const buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean): TPascalString;
function umlDivisionBase64Text(const buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean): TPascalString;
function umlComputeTextPoint(p: PPascalString; Pos_: Integer): TPoint;
```

**契约**：
- `umlDivisionText`：每 `width` 字符换行（`\r\n`）。`DivisionAsPascalString=True` 时每行包裹 `'...' +`。
- `umlDivisionBase64Text`：类似，但 `width-1` 处换行（源码细节，看 §不确定清单）。
- **`umlComputeTextPoint`**：根据字符位置计算行列（1 基）。
  - `#10` → 新行，列重置为 1
  - `#13` → 列重置为 0
  - 其他 → 列 + 1
  - **CRLF 序列**：CR 设列=0，LF 设列=1，行+1

### 4.12 列表与字符串互转

```pascal
function umlListAsSplitText(const List: TCore_Strings; Limit: TPascalString): TPascalString; overload;
function umlListAsSplitText(const List: TListPascalString; Limit: TPascalString): TPascalString; overload;
procedure umlSplitTextAsList(const SText, Limit: TPascalString; AsLst: TCore_Strings);
procedure umlSplitTextAsListAndTrimSpace(const SText, Limit: TPascalString; AsLst: TCore_Strings);
function umlSplitTextMatch(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): Boolean;
function umlSplitTextTrimSpaceMatch(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): Boolean;
function umlSplitDeleteText(const SText, Limit, MatchText: TPascalString; IgnoreCase: Boolean): TPascalString;
function umlStringsMatchText(OriginValue: TCore_Strings; DestValue: TPascalString; IgnoreCase: Boolean): Boolean;
function umlStringsInExists(dest: TListPascalString; SText: TPascalString; IgnoreCase: Boolean): Boolean; overload;
function umlStringsInExists(dest: TCore_Strings; SText: TPascalString; IgnoreCase: Boolean): Boolean; overload;
function umlTextInStrings(const SText: TPascalString; dest: TListPascalString; IgnoreCase: Boolean): Boolean; overload;
function umlAddNewStrTo(source: TPascalString; dest: TListPascalString; IgnoreCase: Boolean): Boolean; overload;
function umlAddNewStrTo(source: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Boolean; overload;
function umlDeleteStrings(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer;
function umlDeleteStringsNot(const SText: TPascalString; dest: TCore_Strings; IgnoreCase: Boolean): Integer;
function umlMergeStrings(source, dest: TCore_Strings; IgnoreCase: Boolean): Integer; overload;
function umlConverStrToFileName(const Value: TPascalString): TPascalString;
```

**契约**：
- **`umlSplitTextMatch`**：按 `Limit` 分割 `SText`，检查**任一 token 是否匹配 `MatchText`**（通配符）。**MatchText 为空返回 True**。
- **`umlStringsInExists`**：检查 `SText` 是否存在于列表中（不区分/区分大小写）。
  - **注意**：源码计算了 `ns := umlUpperCase(SText)` 但**从未使用**，是死代码。
- **`umlDeleteStrings`**：删除列表中匹配 `SText`（通配符）的项。
- **`umlDeleteStringsNot`**：删除**不匹配**的项（保留匹配的）。
- **`umlConverStrToFileName`**：把 `":;/\|<>?*%` 替换为空格。

### 4.13 HTML / URL / 组件名工具

```pascal
function umlUpdateComponentName(const Name: TPascalString): TPascalString;
function umlMakeComponentName(Owner: TCore_Component; RefrenceName: TPascalString): TPascalString;
```

**`umlUpdateComponentName` 契约**：
- 第一个字符必须是字母（A-Z / a-z）。
- 后续字符可以是字母、数字、`-`。
- **其他所有字符被丢弃**（不是替换为空格）。

**`umlMakeComponentName` 契约**：
- 先生成合法名。
- 循环尝试 `Name`、`Name1`、`Name2` ... 直到 `Owner.FindComponent` 找不到。

---

## 第 5 章 通配符匹配（`umlMultipleMatch`）

### 5.1 家族

```pascal
function umlMultipleMatch(IgnoreCase: Boolean; const source, target, Multiple_, Character_: TPascalString): Boolean; overload;
function umlMultipleMatch(IgnoreCase: Boolean; const source, target: TPascalString): Boolean; overload;  // 默认 '*' 和 '?'
function umlMultipleMatch(const source, target: TPascalString): Boolean; overload;  // IgnoreCase=True，支持 ';' 多模式
function umlMultipleMatch(const source: array of TPascalString; const target: TPascalString): Boolean; overload;
function umlMultipleMatch(const source: TPascalStringList; const target: TPascalString): Boolean; overload;
function umlSearchMatch(const source, target: TPascalString): Boolean; overload;
function umlSearchMatch(const source, exclude, target: TPascalString): Boolean; overload;
function umlSearchMatch(const source: TArrayPascalString; target: TPascalString): Boolean; overload;
function umlSearchMatch(const source, exclude: TArrayPascalString; target: TPascalString): Boolean; overload;
function umlMatchFileInfo(const exp_, sour_, dest_: TPascalString): Boolean;
```

### 5.2 语义

```mermaid
flowchart TD
    A["umlMultipleMatch(source, target)"] --> B{"source 为空 或 '*'？"}
    B -- "是" --> C["返回 True（匹配一切）"]
    B -- "否" --> D{"source 含 ';'？"}
    D -- "是" --> E["拆分为多个模式\n任一匹配即可"]
    D -- "否" --> F["单模式匹配"]

    F --> G["内部算法：\n逐字符比较 + '*' 回溯"]

    style C fill:#fff7e6,stroke:#444
```

**`source` 的语义**：
- **空字符串** 或 `'*'`：**匹配一切**（返回 True）。
- **含 `';'`**：视为多模式，任一匹配即可。
- **其他**：单模式。

**匹配算法**（`umlMultipleMatch(IgnoreCase, source, target, Multiple_, Character_)`）：
- 支持自定义通配符（`Multiple_` = `*`，`Character_` = `?`）。
- **大小写敏感度由 `IgnoreCase` 控制**。
- **算法实现**：使用 `label` 和 `goto` 的状态机（`C_Proc_` / `MC_Proc_` / `MS_Proc_`）。
- **性能**：**O(n*m) 最坏情况**。

**`umlSearchMatch`**：
- 类似 `umlMultipleMatch`，但**先尝试子串匹配**，再尝试通配符匹配。
- **默认分隔符是 `;` 和 `,`**。
- **`exclude` 优先检查**：若 `exclude` 匹配，返回 False。

**`umlMatchFileInfo`**：
- `exp_` 支持 `<prefix>` 和 `<postfix>` 占位符。
- `<prefix>` = 目标文件的**无扩展名部分**。
- `<postfix>` = 目标文件的**扩展名部分**。

---

## 第 6 章 类型转换

### 6.1 布尔

```pascal
function umlBoolToStr(const Value: Boolean): TPascalString;        // 'True' 或 'False'
function umlStrToBool(const Value: TPascalString; Default_: Boolean): Boolean;
function umlStrToBool(const Value: TPascalString): Boolean;        // Default_=False
```

**`umlStrToBool` 识别的字符串**（大小写不敏感）：
- True：`'Yes'`、`'ON'`、`'True'`、`'1'`
- False：`'No'`、`'OFF'`、`'False'`、`'0'`
- 其他：返回 `Default_`

**⚠️ 陷阱**：先 `umlTrimSpace`，然后 `Same` 比较（大小写不敏感）。

### 6.2 数字类型检测

```pascal
type
  TTextType = (ntBool, ntInt, ntInt64, ntUInt64, ntWord, ntByte, ntSmallInt, ntShortInt, ntUInt, ntSingle, ntDouble, ntCurrency, ntUnknow);

function umlGetNumTextType(const S: TPascalString): TTextType;
function umlIsHex(const sVal: TPascalString): Boolean;
function umlIsNumber(const sVal: TPascalString): Boolean;
function umlIsIntNumber(const sVal: TPascalString): Boolean;
function umlIsFloatNumber(const sVal: TPascalString): Boolean;
function umlIsBool(const sVal: TPascalString): Boolean;
```

**`umlGetNumTextType` 检测规则**（源码逻辑）：

1. 先 `umlTrimSpace`。
2. 若 `'true'` 或 `'false'` → `ntBool`。
3. 逐字符分类：
   - 数字 `0-9` → `vsNum`
   - 字母 `a-f` / `A-F` → `vsAtoF`
   - 字母 `e` / `E` → `vsE`（也是 `vsAtoF`）
   - `.` → `vsDot`
   - `-` → `vsSymSub`
   - `+` → `vsSymAdd`
   - `$`（首字符）→ `vsSymDollar`
   - 其他 → `ntUnknow`（立即返回）
4. 根据计数判断：
   - **多个 `.`**：`ntUnknow`
   - **多个 `$`**：`ntUnknow`
   - **无 `$` 且无数字**：`ntUnknow`
   - **有 `$`**：根据数字+a-f的位数判断 `ntByte` / `ntWord` / `ntUInt` / `ntUInt64`（负数则 `ntShortInt` / `ntSmallInt` / `ntInt` / `ntInt64`）
   - **有 `.` 或 `e`**：根据小数位数和总位数判断 `ntCurrency` / `ntSingle` / `ntDouble`
   - **其他**（整数）：根据位数判断 `ntByte` / `ntWord` / `ntUInt` / `ntUInt64`

**位宽阈值**：

| 类型 | 无符号位数 | 有符号位数 |
|------|-----------|-----------|
| `ntByte` / `ntShortInt` | < 3 | < 3 |
| `ntWord` / `ntSmallInt` | < 5 | < 5 |
| `ntUInt` / `ntInt` | < 8 | < 8 |
| `ntUInt64` / `ntInt64` | < 16 | < 15 |

**`umlIsHex` / `umlIsIntNumber` 的注意事项**：
- **名字误导**：`umlIsHex` 实际是"是否是整数类型"，不只是十六进制。
- **真正的十六进制必须带 `$` 前缀**。

**`umlIsNumber`**：任何非 `ntUnknow` 且非 `ntBool` 的情况。

### 6.3 字符串 ↔ 数字

```pascal
function umlIntToStr(Parameter: Single): TPascalString; overload;
function umlIntToStr(Parameter: Double): TPascalString; overload;
function umlIntToStr(Parameter: Int64): TPascalString; overload;
function umlIntToStr(Parameter: UInt64): TPascalString; overload;
function umlIntToStr(Parameter: Int128): TPascalString; overload;
function umlIntToStr(Parameter: UInt128): TPascalString; overload;
function umlIntToStr(Parameter: Integer): TPascalString; overload;
function umlIntToStr(Parameter: Cardinal): TPascalString; overload;
function umlPointerToStr(param: Pointer): TPascalString;

function umlStrToInt(const V_: TPascalString): Integer; overload;
function umlStrToInt(const V_: TPascalString; _Def: Integer): Integer; overload;
function umlStrToInt64(const V_: TPascalString): Int64; overload;
function umlStrToInt64(const V_: TPascalString; _Def: Int64): Int64; overload;
function umlStrToInt128(const V_: TPascalString): Int128; overload;
function umlStrToInt128(const V_: TPascalString; _Def: Int128): Int128; overload;
function umlStrToFloat(const V_: TPascalString): Double; overload;
function umlStrToFloat(const V_: TPascalString; _Def: Double): Double; overload;
```

**契约**：
- **`umlStrToInt` / `umlStrToInt64` / `umlStrToFloat` 先用 `umlIsNumber` 检查**，不是数字则直接返回默认值。
- **`umlStrToInt128` 不用 `umlIsNumber`**，直接 `try Int128(V_.Text) except Result := _Def`。
- **`umlIntToStr(Single/Double)` 会四舍五入**（`Round(Parameter)`）。

### 6.4 尺寸与速率格式化

```pascal
function umlSmartSizeToStr(Size: Int64): TPascalString;
function umlSizeToStr(Parameter: Int64): TPascalString;      // 别名
function umlGSizeToStr(Parameter: Int64): TPascalString;     // 支持 GB
function umlMBPSToStr(Size: Int64): TPascalString;
```

**`umlSmartSizeToStr` 规则**：
- `< 1024`：`'%d'`（纯数字，不带单位）
- `< 1024*1024`：`'%fKb'`
- 其他：`'%fM'`

**⚠️ 陷阱**：**不带单位时是纯数字**，用户可能误以为是字节。

**`umlGSizeToStr` 规则**：支持 `G`。`< 1G` 时同 `umlSmartSizeToStr`，`>= 1G` 用 `'%fG'`。

**`umlMBPSToStr` 规则**：`bps` / `Kbps` / `Mbps`，**都乘 10**（源码 `Size * 10`）。这看起来是 bug。

### 6.5 时间与日期

```pascal
function umlDefaultTime: Double;   // = Now
function umlNow: Double;
function umlTime: Double;          // = Time
function umlDate: Double;          // = Date

function umlStrToTime(S: TPascalString): TDateTime;
function umlTimeToStr(t: TDateTime): TPascalString;
function umlStrToDateTime(S: TPascalString): TDateTime;
function umlDateTimeToStr(t: TDateTime): TPascalString;
function umlDT(t: TDateTime): TPascalString; overload;
function umlDT(S: TPascalString): TDateTime; overload;
function umlDT(S: TPascalString; Default_: TDateTime): TDateTime; overload;
function umlT(t: TDateTime): TPascalString; overload;
function umlT(S: TPascalString): TDateTime; overload;
function umlT(S: TPascalString; Default_: TDateTime): TDateTime; overload;
function umlTimeTickToStr(const t: TTimeTick): TPascalString;
function umlDateToStr(t: TDateTime): TPascalString;
```

**契约**：
- 所有 Str/Date 转换使用 **`Lib_DateTimeFormatSettings`**（ISO 格式）。
- **`umlDT(S)` / `umlT(S)` 不捕获异常**，格式错误会抛。用 `umlDT(S, Default_)` 版本更安全。
- **`umlTimeTickToStr`** 格式：`[D Day ]H:M:S.ms`。**无前导零**（D/H/M 用 `IntToStr`，S 用 `'%2.2f'`）。

### 6.6 百分比与循环值

```pascal
function umlPercentageToFloat(OriginMax, OriginMin, ProcressParameter: Double): Double;
function umlPercentageToInt64(OriginParameter, ProcressParameter: Int64): Integer;
function umlPercentageToInt(OriginParameter, ProcressParameter: Integer): Integer;
function umlPercentageToStr(OriginParameter, ProcressParameter: Integer): TPascalString;
function umlProcessCycleValue(CurrentVal, DeltaVal, StartVal, OverVal: Single; var EndFlag: Boolean): Single;
```

**契约**：
- **`umlPercentageToInt64` / `umlPercentageToInt` 分母为 0 时返回 0**。
- **`umlProcessCycleValue`**：在 `[StartVal, OverVal]` 之间循环振荡。`EndFlag` 记录方向（True=向下，False=向上）。

### 6.7 数字 ↔ 字符串（限界辅助）

```pascal
function umlMax(...): ...;  // 12 个重载（UInt64/Cardinal/Word/Byte/Int64/Integer/SmallInt/ShortInt/Double/Single/UInt128/Int128）
function umlMin(...): ...;  // 12 个重载
function umlClamp(v, min_, max_: ...): ...;  // 12 个重载
function umlInRange(v, min_, max_: ...): Boolean;  // 12 个重载
```

**契约**：
- `umlClamp` 会**自动交换 `min_` 和 `max_`**（若 `min_ > max_`）。
- `umlInRange` **也自动交换**，判断 `v` 是否在 `[min(min_,max_), max(min_,max_)]` 中。

### 6.8 二进制字符串 ↔ 整数

```pascal
function umlBinToUInt8 (Value: U_String): Byte;
function umlBinToUInt16(Value: U_String): Word;
function umlBinToUInt32(Value: U_String): Cardinal;
function umlBinToUInt64(Value: U_String): UInt64;
function umlUInt8ToBin (v: Byte): U_String;
function umlUInt16ToBin(v: Word): U_String;
function umlUInt32ToBin(v: Cardinal): U_String;
function umlUInt64ToBin(v: UInt64): U_String;
```

**契约**：
- **`umlBinToUInt*`**：字符串从**末尾**开始解析。`'101'` → `1*4 + 0*2 + 1 = 5`。
- **`umlUInt*ToBin(0)` 返回 `'0'`**（不是空字符串）。
- **`umlUInt*ToBin` 会删除前导 '0'**（源码 `while Result.First = '0' do Result.DeleteFirst`）。

### 6.9 变体 ↔ 字符串

```pascal
function umlVarToStr(const v: Variant; const Base64Conver: Boolean): TPascalString; overload;
function umlVarToStr(const v: Variant): TPascalString; overload;  // Base64Conver=True
function umlStrToVar(const S: TPascalString): Variant;
function umlSameVarValue(const v1, v2: Variant): Boolean;
function umlSameVariant(const v1, v2: Variant): Boolean;
```

**`umlVarToStr` 契约**：
- 根据 `VarType` 分派。
- **字符串类型含 `#10#13#9#8#0` 时**，进行 Base64 编码，**前缀 `___base64:`**。
- 其他类型直接 `VarToStr`。

**`umlStrToVar` 契约**：
- **若输入含控制字符**，进行 Base64 编码，**前缀 `___base64:`**。
- 否则直接返回字符串。

**⚠️ 重大不确定**：**`umlStrToVar` 名为 "Str to Var"，但行为是"编码为可存储字符串"**。它**没有解码**带 `___base64:` 前缀的字符串。**可能是 bug 或设计不一致**。见不确定清单。

**`umlSameVarValue` 契约**：调用 `VarSameValue`，异常时返回 False。

---

## 第 7 章 编码

### 7.1 Base64 上下文

```pascal
type
  TBase64Context = record
    Tail: array [0 .. 3] of Byte;       // 未处理字节
    TailBytes: Integer;                 // Tail 字节数
    LineWritten: Integer;               // 当前行已写字节数
    LineSize: Integer;                  // 行宽（0 = 不换行）
    TrailingEol: Boolean;
    PutFirstEol: Boolean;
    LiberalMode: Boolean;
    fEOL: array [0 .. 3] of Byte;       // EOL 标记
    EOLSize: Integer;
    OutBuf: array [0 .. 3] of Byte;
    EQUCount: Integer;                  // '=' 计数
    UseUrlAlphabet: Boolean;
  end;

  TBase64EOLMarker = (emCRLF, emCR, emLF, emNone);
```

**全局表**：
- `Base64Symbols: array[0..63] of Byte`（标准编码表 `A-Za-z0-9+/`）。
- `Base64Values: array[0..255] of Byte`（解码表，`$FF` = 非法，`$FD` = `'='`，`$FE` = `\r`/`\n`/`\0`）。

### 7.2 流式 API

```pascal
function B64EstimateEncodedSize(cont: TBase64Context; InSize: Integer): Integer;
function B64InitializeDecoding(var cont: TBase64Context; LiberalMode: Boolean): Boolean;
function B64InitializeEncoding(var cont: TBase64Context; LineSize: Integer; fEOL: TBase64EOLMarker; TrailingEol: Boolean): Boolean;
function B64Encode(var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer): Boolean;
function B64Decode(var cont: TBase64Context; buffer: PByte; Size: Integer; OutBuffer: PByte; var OutSize: Integer): Boolean;
function B64FinalizeEncoding(var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer): Boolean;
function B64FinalizeDecoding(var cont: TBase64Context; OutBuffer: PByte; var OutSize: Integer): Boolean;
```

**契约**：
- **`B64InitializeEncoding` 要求 `LineSize >= 4`**，否则返回 False。
- **`emNone` 时 `EOLSize` 设为 0**。
- **`B64Encode` 调用前必须检查 `OutSize >= EstSize`**（否则 `OutSize` 被设为 EstSize 但数据未写）。
- **`B64FinalizeEncoding` 写入 padding 和 trailing EOL**。

### 7.3 高级 API

```pascal
function umlBase64Encode(InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; WrapLines: Boolean): Boolean;
function umlBase64Decode(InBuffer: PByte; InSize: Integer; OutBuffer: PByte; var OutSize: Integer; LiberalMode: Boolean): Integer;

procedure umlBase64EncodeBytes(var sour, dest: TBytes); overload;
procedure umlBase64DecodeBytes(var sour, dest: TBytes); overload;
procedure umlBase64EncodeBytes(var sour: TBytes; var dest: TPascalString); overload;
procedure umlBase64DecodeBytes(const sour: TPascalString; var dest: TBytes); overload;

procedure umlDecodeLineBASE64(const buffer: TPascalString; var output: TPascalString); overload;
procedure umlEncodeLineBASE64(const buffer: TPascalString; var output: TPascalString); overload;
function  umlDecodeLineBASE64(const buffer: TPascalString): TPascalString; overload;
function  umlEncodeLineBASE64(const buffer: TPascalString): TPascalString; overload;
procedure umlDecodeStreamBASE64(const buffer: TPascalString; output: TCore_Stream);
procedure umlEncodeStreamBASE64(buffer: TCore_Stream; var output: TPascalString);
function  umlDivisionBase64Text(const buffer: TPascalString; width: Integer; DivisionAsPascalString: Boolean): TPascalString;
function  umlTestBase64(const text: TPascalString): Boolean;
```

**契约**：
- `umlBase64Encode` 的 `WrapLines=True` 使用 64 字符行宽 + CRLF。
- **`umlBase64Decode` 返回值是错误码**（不是 Boolean）：
  - `BASE64_DECODE_OK = 0`：成功
  - `BASE64_DECODE_INVALID_CHARACTER = 1`
  - `BASE64_DECODE_WRONG_DATA_SIZE = 2`
  - `BASE64_DECODE_NOT_ENOUGH_SPACE = 3`
- **`umlBase64Decode` 会自动忽略 `\r` `\n` `\0`**（源码预扫描 ExtraSyms）。
- **`umlBase64DecodeBytes` 使用 `LiberalMode=True`**（更宽容）。
- **`umlDecodeLineBASE64` 只处理单行**，不带换行；`WrapLines` 需要自己处理。
- **`umlTestBase64` 只检查解码是否产生**任何字节，**不校验内容**。

---

## 第 8 章 哈希

### 8.1 MD5 常量

```pascal
const
  NULL_MD5:      TMD5 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
  Zero_MD5:      TMD5 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
  NULLMD5:       TMD5 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
  ZeroMD5:       TMD5 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
  umlNULLMD5:    TMD5 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
  umlZeroMD5:    TMD5 = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0);
  NULL_Buff_MD5: TMD5 = (212,29,140,217,143,0,178,4,233,128,9,152,236,248,66,126);
```

**`NULL_Buff_MD5`** = MD5 of 空缓冲（16 字节全 0）。用于 MD5 计算失败时的哨兵值。

### 8.2 基础 MD5

```pascal
function umlMD5(const buffPtr: PByte; bufSiz: NativeUInt): TMD5;
function umlMD5Char(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString;
function umlMD5String(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString;  // 别名
function umlMD5Str(const buffPtr: PByte; const BuffSize: NativeUInt): TPascalString;     // 别名
function umlMD5ToStr(md5: TMD5): TPascalString;
function umlMD5ToStr(const buffPtr: PByte; bufSiz: NativeUInt): TPascalString; overload;
function umlMD5ToString(md5: TMD5): TPascalString;   // 别名
function umlMD5ToString(const buffPtr: PByte; bufSiz: NativeUInt): TPascalString; overload;  // 别名
function umlMD52String(md5: TMD5): TPascalString;    // 别名
function umlMD5Compare(const m1, m2: TMD5): Boolean;
function umlCompareMD5(const m1, m2: TMD5): Boolean;  // 别名
function umlIsNullMD5(M: TMD5): Boolean;
function umlWasNullMD5(M: TMD5): Boolean;             // 别名
```

**编译期开关**：
- **`FastMD5` + Delphi + Windows** 时，使用 `Z.md5` 的 `FastMD5` 优化版本。
- **其他情况**，使用**纯 Pascal** 实现（源码 `umlTransformMD5`）。

### 8.3 流和文件 MD5

```pascal
function umlStreamMD5(stream: TCore_Stream; StartPos, EndPos: Int64): TMD5; overload;
function umlStreamMD5(stream: TCore_Stream): TMD5; overload;
function umlStreamMD5Char(stream: TCore_Stream): TPascalString; overload;
function umlStreamMD5String(stream: TCore_Stream): TPascalString; overload;
function umlStreamMD5Str(stream: TCore_Stream): TPascalString; overload;
function umlStringMD5(const Value: TPascalString): TPascalString;
function umlFileMD5___(FileName: TPascalString): TMD5;        // 无缓存
function umlFileMD5(FileName: TPascalString; StartPos, EndPos: Int64): TMD5; overload;  // 范围
function umlFileMD5(FileName: TPascalString): TMD5; overload; // **有缓存**
```

**`umlStreamMD5(stream, StartPos, EndPos)` 契约**：
- **参数自动交换**：`StartPos > EndPos` 时交换。
- **参数自动 clamp 到 [0, stream.Size]**。
- **内存流优化**：`TCore_MemoryStream` / `TMS64` 直接用内存指针，不分块。
- **普通流**：按 4MB 分块读取。

**`umlFileMD5(FileName)` 有缓存！**
- 使用 `FileMD5Cache.DoGetFileMD5`（见 §8.6）。
- **缓存键是文件名**。
- **缓存值包含 (Time, Size, MD5)**。
- **失效条件**：文件时间或大小变化。

### 8.4 MD5 组合

```pascal
function umlCombineMD5(const m1: TMD5): TMD5; overload;                       // = MD5(m1)
function umlCombineMD5(const m1, m2: TMD5): TMD5; overload;                   // = MD5(m1 + m2)
function umlCombineMD5(const m1, m2, m3: TMD5): TMD5; overload;
function umlCombineMD5(const m1, m2, m3, m4: TMD5): TMD5; overload;
function umlCombineMD5(const buff: array of TMD5): TMD5; overload;
```

**契约**：把 N 个 MD5 拼接后计算 MD5。用于生成文件的"组合指纹"。

### 8.5 `TMD5_Tool`（增量 MD5）

```pascal
TMD5_Tool = class(TCore_Object_Intermediate)
public
  constructor Create;
  destructor Destroy; override;
  procedure Update(buff: Pointer; Size__: Int64);
  function FinalizeMD5: TMD5;
  property Completed_Size: Int64 read FCompleted_Size;
end;
```

**契约**：
- `Update` 累积数据到内部 `Mem`（TMem64），每当满 64 字节就调用 `umlTransformMD5`。
- `FinalizeMD5` 处理剩余字节，返回最终 MD5。
- **`Completed_Size` 是已处理的字节数**（只增不减，`FinalizeMD5` 也会加）。

### 8.6 文件 MD5 缓存（`TFileMD5Cache`）

```pascal
var
  FileMD5Cache: TFileMD5Cache;   // 单例

procedure umlCacheFileMD5(FileName: U_String);
procedure umlCacheFileMD5FromDirectory(Directory_, Filter_: U_String);
```

**内部结构**：
- `FHash: THashList`：文件名 → `PFileMD5_CacheData`。
- `PFileMD5_CacheData = ^TFileMD5_CacheData`，`TFileMD5_CacheData = record Time_: TDateTime; Size_: Int64; md5: TMD5; end`。
- **`FHash.IgnoreCase := True`**（文件名比较不区分大小写）。
- **`FHash.AccessOptimization := True`**（LRU 优化）。

**缓存失效**：时间或大小改变。

**`umlCacheFileMD5` 契约**：
- **异步**：通过 `TCompute.RunC` 投递。
- **UserData 是 `PPascalString`**，在 `Do_ThCacheFileMD5` 内 `Dispose(p)`。
- **不等待**：调用后立即返回。

**`umlCacheFileMD5FromDirectory` 契约**：
- 异步投递任务，扫描目录所有文件，匹配 `Filter_` 的缓存 MD5。
- **全局变量 `CacheThreadIsAcivted`** 用于中止（finalization 时置 False）。
- **全局计数器 `CacheFileMD5FromDirectory_Num`** 用于等待（finalization 时 spin）。

### 8.7 CRC16 / CRC32

```pascal
function umlCRC16(const Value: PByte; const Count: NativeUInt): Word;
function umlStringCRC16(const Value: TPascalString): Word;
function umlStreamCRC16(stream: U_Stream; StartPos, EndPos: Int64): Word; overload;
function umlStreamCRC16(stream: U_Stream): Word; overload;

function umlCRC32(const Value: PByte; const Count: NativeUInt): Cardinal;
function umlString2CRC32(const Value: TPascalString): Cardinal;
function umlStreamCRC32(stream: U_Stream; StartPos, EndPos: Int64): Cardinal; overload;
function umlStreamCRC32(stream: U_Stream): Cardinal; overload;
```

**契约**：
- **CRC16**：初始值 0，反射处理。查表 `CRC16Table`。
- **CRC32**：初始值 `$FFFFFFFF`，末尾 XOR `$FFFFFFFF`。查表 `C_CRC32Table`（来自 Z.Core）。
- **流版本内存流优化**：`TCore_MemoryStream` / `TMS64` 直接用内存指针。
- **普通流按 1MB 分块**。

---

## 第 9 章 随机数

```pascal
function umlRandom(const rnd: TMT19937Random): Integer; overload;
function umlRandom: Integer; overload;                                    // 用全局 MT19937
function umlRandomRange(const rnd: TMT19937Random; const min_, max_: Integer): Integer; overload;
function umlRandomRange64(const rnd: TMT19937Random; const min_, max_: Int64): Int64; overload;
function umlRandomRangeS(const rnd: TMT19937Random; const min_, max_: Single): Single; overload;
function umlRandomRangeD(const rnd: TMT19937Random; const min_, max_: Double): Double; overload;
function umlRandomRangeF(const rnd: TMT19937Random; const min_, max_: Double): Double; overload;
function umlRandomRange(const min_, max_: Integer): Integer; overload;    // 用全局
function umlRandomRange64(const min_, max_: Int64): Int64; overload;
function umlRandomRangeS(const min_, max_: Single): Single; overload;
function umlRandomRangeD(const min_, max_: Double): Double; overload;
function umlRandomRangeF(const min_, max_: Double): Double; overload;

// 短别名
function umlRR(...): ...;        // = umlRandomRange
function umlRR64(...): ...;      // = umlRandomRange64
function umlRRS(...): ...;       // = umlRandomRangeS
function umlRRD(...): ...;       // = umlRandomRangeD
function umlRRF(...): ...;       // = umlRandomRangeF
```

**契约**：
- **`umlRandom` 返回 `[0, MaxInt)`**。
- 所有函数**直接调用 `TMT19937.RandomRange*`**（见 Z.Core 知识库第 8 章）。

---

## 第 10 章 RTSP/RTMP URL 解析

```pascal
type
  TRTSP_RTMP_URL = record
    prefix, user, passwd, host, port, path: TPascalString;
    procedure Init;
    function Encode: U_String;
    procedure Decode(Data_: U_String);
  end;

function umlExtract_RTSP_RTMP_URL(const URL: TPascalString; var prefix, user, passwd, host, port, path: TPascalString): Boolean; overload;
function umlExtract_RTSP_RTMP_URL(const URL: TPascalString; var To_: TRTSP_RTMP_URL): Boolean; overload;
function umlEncode_RTSP_RTMP_URL(prefix, user, passwd, host, port, path: TPascalString): TPascalString;
function umlRemove_Passwd_RTSP_RTMP_URL(const URL: TPascalString): TPascalString;
```

**`umlExtract_RTSP_RTMP_URL` 支持的格式**：
- `rtsp://host`
- `rtsp://host/path`
- `rtsp://host:port`
- `rtsp://host:port/path`
- `rtsp://user:passwd@host`
- `rtsp://user:passwd@host:port`
- `rtsp://user:passwd@host/path`
- `rtsp://user:passwd@host:port/path`

**默认端口**：
- `rtsp://` → `'554'`
- `rtmp://` → `'1935'`

**`TRTSP_RTMP_URL.Encode`**：用 **`Z.Json` 的 `TZJ`** 序列化为 JSON 字符串（**不是 URL 字符串**）。

**`TRTSP_RTMP_URL.Decode`**：用 TZJ 解析 JSON。

**⚠️ 名字误导**：`Encode` / `Decode` **不是 URL 编解码**，是 JSON 序列化/反序列化。

---

## 第 11 章 组件持久化

```pascal
procedure umlReadComponent(stream: TCore_Stream; comp: TCore_Component);
procedure umlWriteComponent(stream: TCore_Stream; comp: TCore_Component);
procedure umlCopyComponentDataTo(comp, copyto: TCore_Component);
```

**契约**：
- 使用 `TCore_Reader` / `TCore_Writer`（即 `TReader` / `TWriter`）。
- **`IgnoreChildren = True`**（不递归子组件）。
- **`umlReadComponent` 在 `comp.Name = ''` 时会先保存原 Name，读取后恢复**（源码细节）。
- **`umlCopyComponentDataTo` 要求两个组件类相同**（`ClassType` 相等）。

---

## 第 12 章 CSV 导入

```pascal
type
  TCSVGetLine_C = procedure(var L: TPascalString; var IsEnd: Boolean);
  TCSVSave_C = procedure(const sour: TPascalString; const king, Data: TArrayPascalString);
  TCSVGetLine_M = procedure(var L: TPascalString; var IsEnd: Boolean) of object;
  TCSVSave_M = procedure(const sour: TPascalString; const king, Data: TArrayPascalString) of object;
{$IFDEF FPC}
  TCSVGetLine_P = procedure(var L: TPascalString; var IsEnd: Boolean) is nested;
  TCSVSave_P = procedure(const sour: TPascalString; const king, Data: TArrayPascalString) is nested;
{$ELSE FPC}
  TCSVGetLine_P = reference to procedure(var L: TPascalString; var IsEnd: Boolean);
  TCSVSave_P = reference to procedure(const sour: TPascalString; const king, Data: TArrayPascalString);
{$ENDIF FPC}

procedure ImportCSV_C(const sour: TArrayPascalString; OnNotify: TCSVSave_C);
procedure CustomImportCSV_C(const OnGetLine: TCSVGetLine_C; OnNotify: TCSVSave_C);
procedure ImportCSV_M(const sour: TArrayPascalString; OnNotify: TCSVSave_M);
procedure CustomImportCSV_M(const OnGetLine: TCSVGetLine_M; OnNotify: TCSVSave_M);
procedure ImportCSV_P(const sour: TArrayPascalString; OnNotify: TCSVSave_P);
procedure CustomImportCSV_P(const OnGetLine: TCSVGetLine_P; OnNotify: TCSVSave_P);
```

**契约**：
- **第一行非空行作为表头**（`king`）。
- 表头用**不连续分隔符语义**分割（保留空列）。
- 表头列数决定数据列数（`SetLength(buff, hc)`）。
- 数据行不足列数时，**空缺列保持空字符串**。
- **`OnNotify` 回调参数**：
  - `sour`：原始数据行
  - `king`：表头数组
  - `Data`：数据数组
- **`CustomImportCSV_*` 用 `OnGetLine` 回调**而不是预定义数组。

---

## 第 13 章 动态库加载

```pascal
function GetExtLib(LibName: SystemString): HMODULE;      // 加载并缓存
function FreeExtLib(LibName: SystemString): Boolean;     // 卸载
function GetExtProc(const LibName, ProcName: SystemString): Pointer;  // 获取函数地址
```

**实现细节**：
- 内部使用 `__ExLibs__: THash_ExtLibs`（`TString_Big_Hash_Pair_Pool<HMODULE>`）。
- **首次调用 `GetExtLib` 时创建缓存**。
- **iOS + ARM 上所有函数存根**（返回 nil/False/0）。
- **Android 下使用 `umlCombineFileName(System.IOUtils.TPath.GetLibraryPath, LibName)`**。
- **FPC 下用 `LoadLibrary(PAnsiChar(LibName))`**；Delphi 下用 `LoadLibrary(PChar(LibName))`。

**`GetExtProc` 失败时会调用 `DoStatus` 打印错误**（来自 `Z.Status`）。

---

## 第 14 章 杂项

### 14.1 内存与字节

```pascal
procedure SaveMemory(p: Pointer; siz: NativeInt; DestFile: TPascalString);
function  umlBufferIsASCII(buffer: Pointer; siz: NativeUInt): Boolean;
```

**`SaveMemory`**：用 `TMem64.SetPointerWithProtectedMode` 包装内存，保存到文件。**不拷贝**（零拷贝）。

**`umlBufferIsASCII` 契约**：
- **判定 `p^ > $80` 为"非 ASCII"**。
- **⚠️ 边界 bug**：`$80` 本身被认为是 ASCII（应该是 `>= $80`）。

### 14.2 原始字节数组

```pascal
type
  TArrayRawByte = array [0 .. MaxInt - 1] of Byte;
  PArrayRawByte = ^TArrayRawByte;

function  umlCompareByteString(const s1: TPascalString; const s2: PArrayRawByte): Boolean; overload;
function  umlCompareByteString(const s2: PArrayRawByte; const s1: TPascalString): Boolean; overload;
procedure umlSetByteString(const sour: TPascalString; const dest: PArrayRawByte); overload;
procedure umlSetByteString(const dest: PArrayRawByte; const sour: TPascalString); overload;
function  umlGetByteString(const sour: PArrayRawByte; const L: Integer): TPascalString;
```

**契约**：
- **逐字节操作**（`Byte(s1.buff[i])`），不是逐字符。
- **FPC 下 `SystemChar` 是 1 字节**，所以逐字符 = 逐字节。
- **Delphi 下 `SystemChar` 是 2 字节**，逐字节会**丢失高位**。

### 14.3 字符集辅助

```pascal
function umlCharIsSymbol(C: SystemChar): Boolean; overload;
function umlCharIsSymbol(C: SystemChar; const CustomSymbol_: TArrayChar): Boolean; overload;
function umlExtractWord(S: TPascalString): TArrayPascalString; overload;
function umlExtractWord(S: TPascalString; const CustomSymbol_: TArrayChar): TArrayPascalString; overload;
```

**`umlCharIsSymbol`** 的默认符号集（见 §4.7）。

---

## 第 15 章 与 Z.Core / Z.PascalStrings 的契约

### 15.1 类型依赖

```mermaid
flowchart TD
    A["Z.UnicodeMixedLib"] --> B["U_String = TPascalString"]
    A --> C["U_Stream = TCore_Stream"]
    A --> D["TSR = TSearchRec"]
    A --> E["TMT19937Random (Z.Core)"]
    A --> F["TCompute (Z.Core)"]
    A --> G["TBigList / TBig_Hash_Pair_Pool (Z.Core)"]
    A --> H["TMem64 (Z.MemoryStream)"]
    A --> I["TMS64 (Z.MemoryStream)"]
    A --> J["THashList / TString_Big_Hash_Pair_Pool (Z.HashList.Templet)"]
    A --> K["TZJ (Z.Json)"]
    A --> L["TSafe_Flush_Stream (Z.FragmentBuffer)"]
    A --> M["Int128 / UInt128 (Z.Int128)"]
    A --> N["TCore_Strings / TListPascalString (Z.ListEngine)"]

    style A fill:#e8f4ff,stroke:#444
```

### 15.2 线程安全

| 组件 | 线程安全 |
|------|---------|
| 纯函数（无状态） | ✅ 是 |
| `umlFileMD5(FileName)` | ✅ 是（`TFileMD5Cache` 内部有 `TCritical`） |
| `umlCacheFileMD5*` | ✅ 是（异步投递） |
| `GetExtLib` / `GetExtProc` | ⚠️ 部分（内部哈希表非线程安全） |
| `umlMultipleMatch` | ✅ 是（纯函数） |
| `TIOHnd` | ❌ 否（**调用方必须自己保证独占**） |

**⚠️ 重点**：**`GetExtLib` 的 `__ExLibs__` 哈希表没有临界区保护**。多线程同时调用可能崩。**必须外部加锁**。

### 15.3 与 `Z.PascalStrings` 的互操作

- 大部分 `uml*` 函数的参数是 `TPascalString`。
- **`umlVarToStr` / `umlStrToVar`** 处理带控制字符的字符串时使用 `umlEncodeLineBASE64` / `umlDecodeLineBASE64`。
- **`umlStringMD5`** 通过 `TPascalString.Bytes`（UTF-8）计算 MD5。

---

## 第 16 章 反例集

### 16.1 `umlDeleteFile` 的陷阱

```pascal
// ❌ 错误：以为返回 True 就是删除成功
if umlDeleteFile('C:\readonly_file.txt') then
  ShowMessage('Deleted');   // 若文件不存在或删除失败，仍可能显示

// ✅ 正确：显式检查
if umlDeleteFile('C:\file.txt', True) then
  ShowMessage('Deleted');
```

### 16.2 `TIOHnd` 的生命周期

```pascal
// ❌ 错误：Close 后还想用 Handle
umlFileClose(IOHnd);
IOHnd.Handle.Read(...);   // Handle 已经被置 nil

// ✅ 正确：在 Close 前保存
h := IOHnd.Handle;
umlFileClose(IOHnd);
// 使用 h（但要确保 AutoFree=False）
```

### 16.3 `FixedStringL` 的字节 vs 字符

```pascal
// ❌ 错误：在 Delphi 下认为 FixedStringL 是字符数
IOHnd.FixedStringL := 32;
IOHnd.Pascal2FixedString(MyString, buff);
// MyString 是 20 个汉字，Bytes 是 60 字节，会被截断为 31 字节（不完整的汉字）
```

### 16.4 `umlMultipleMatch` 的空字符串

```pascal
// ❌ 错误：以为空模式不匹配任何东西
if umlMultipleMatch('', 'anything') then   // True！

// ✅ 正确：显式检查
if (Pattern <> '') and umlMultipleMatch(Pattern, Target) then
  ...
```

### 16.5 `umlGetIndexStr` 的索引语义

```pascal
// ❌ 错误：以为 index=-1 会返回"最后一个"
umlGetIndexStr('a;b;c', ';', -1);   // 返回 ''

// ✅ 正确：index=0 或 1 返回第一个
umlGetIndexStr('a;b;c', ';', 3);    // 返回 'c'
umlGetIndexStr('a;b;c', ';', 100);  // 返回 'c'
```

### 16.6 `umlURLDecode` 的非法 `%`

```pascal
// ❌ 错误：以为非法 %XX 会被忽略
umlURLDecode('%ZZ', True);   // 抛异常

// ✅ 正确：先检查
if ValidPercentEncoding(S) then
  Result := umlURLDecode(S, True)
else
  Result := S;
```

### 16.7 `umlMD5ToStr` 的返回值

```pascal
// 两个函数功能相同，只是名字不同
s1 := umlMD5ToStr(digest);
s2 := umlMD5ToString(digest);
s3 := umlMD52String(digest);
// s1 = s2 = s3
```

### 16.8 `umlVarToStr` / `umlStrToVar` 的不对称

```pascal
// ❌ 可能引起误解
v := VarArrayOf([...]);
s := umlVarToStr(v);   // 若含控制字符 → '___base64:xxx'
v2 := umlStrToVar(s);  // 不还原！v2 是 '___base64:xxx' 本身
```

### 16.9 `umlFileMD5` 的缓存效应

```pascal
// ❌ 错误：改了文件内容但没改时间戳，MD5 不更新
RewriteFile('C:\data.bin');   // 修改内容但不改时间
md5 := umlFileMD5('C:\data.bin');  // 返回旧缓存值
```

### 16.10 `umlBufferIsASCII` 的边界

```pascal
// 缓冲区含字节 0x80
if umlBufferIsASCII(buf, size) then   // True！0x80 被当作 ASCII
  ...
```

---

## 第 17 章 诚实的不确定清单

> 以下是我从源码**无法完全确定**的点。若 AI 需要在这些场景下工作，**必须回查源码或询问人类**。

1. **`umlStrToVar` 的语义**
   - 函数名暗示 "Str → Var" 转换，但实现是**将字符串编码**（前缀 `___base64:`）。
   - **不确定**：这是 bug，还是 `umlVarToStr` 的逆操作（但逆操作应该是解码）。
   - **推测**：源码可能有 bug，或 `umlStrToVar` 是"为存储做准备"的函数。

2. **`umlDeleteFile` 在 `_VerifyCheck=False` 时返回 True 的行为**
   - 源码：`if Result and _VerifyCheck then ... else Result := True;`
   - **不确定**：这是有意的"宽容模式"，还是 bug。
   - **推测**：可能是 bug。**不要依赖**这个返回 True。

3. **`umlDeleteFile` 通配符模式的返回值**
   - 源码：不管删除成功与否，返回 True。
   - **不确定**：是否有意为之。

4. **`umlMBPSToStr` 的 `* 10`**
   - 源码：`Result := Format('%dBps', [Size * 10])`。
   - **不确定**：这是字节→比特的转换（×8）还是 bug（×10）。
   - **推测**：应该是 `* 8`，写成 `* 10` 是 bug。

5. **`umlBufferIsASCII` 的 `$80` 边界**
   - 源码：`if p^ > $80 then exit`。
   - **不确定**：`$80` 应该算 ASCII 还是非 ASCII。
   - **推测**：应为 `>= $80`。**不要依赖**对 `$80` 的判定。

6. **`umlEncodeText2HTML` 不处理单引号 `'`**
   - 源码只处理 `& < > "`，不处理 `'`。
   - **不确定**：是否故意。
   - **建议**：HTML 属性值用双引号时安全；用单引号需要手动处理。

7. **`umlStringsInExists` 中的 `ns` 变量**
   - 源码计算 `ns := umlUpperCase(SText)` 但**从未使用**。
   - **不确定**：是遗留代码还是准备用于未来优化。

8. **`umlSetByteString` 的两个重载语义是否完全相同**
   - 两个重载的参数顺序不同，但实现完全相同。
   - **不确定**：为什么需要两个重载（避免类型推断歧义？）。

9. **`umlCombineByteString` 的重载语义**
   - 两个重载都执行相同的字节比较。
   - **不确定**：区别是什么（编译期类型匹配？）。

10. **`umlDivisionBase64Text` 的 `width-1` 语义**
    - 源码：`if n >= width - 1 then ...`（而 `umlDivisionText` 是 `n = width`）。
    - **不确定**：为什么 base64 版本用 `width-1`。

11. **`umlGetNumTextType` 对 `$` 位置的处理**
    - 源码：`else if CharIn(C, '$') and (i = 1) then`——**只有一个分支处理 `$`**，但 `i <> 1` 时也会 `inc(cnt[vsSymDollar])`，与 `if i <> 1 then exit(ntUnknow)` 矛盾。
    - **不确定**：实际行为是"非首位 `$` 退出"还是"计入 cnt 后不退出"。
    - **推测**：源码逻辑复杂，可能有 bug。**不要依赖**对 `$` 的精确位置判断。

12. **`TIOHnd.FixedString2Pascal` 的字节 → 字符串转换**
    - 源码：`Result.Bytes := buff`（buff 是 TBytes）。
    - **不确定**：非 UTF-8 字节序列是否会乱码。
    - **推测**：会，因为 `TPascalString.Bytes` 是 UTF-8 解码。

13. **`TReliableFileStream.FreeIO` 的失败处理**
    - 源码：`try ... except end` 吞掉所有异常。
    - **不确定**：如果 `umlDeleteFile` + `umlRenameFile` 都失败，原文件可能已被删除但备份未重命名。
    - **推测**：会丢失数据。**依赖 `ZDB_BACKUP` 时需谨慎**。

14. **`GetExtLib` 的线程安全**
    - 源码：`__ExLibs__` 哈希表无锁保护。
    - **不确定**：`TString_Big_Hash_Pair_Pool` 是否内部有锁。
    - **推测**：无锁。**多线程调用需外部加锁**。

15. **`umlExtract_RTSP_RTMP_URL` 的严格前缀匹配**
    - 源码：`umlMultipleMatch('RTSP://*', n)`——**大写匹配**，但 `umlMultipleMatch` 默认 IgnoreCase。
    - **不确定**：是否支持 `rtsp://` 小写。
    - **推测**：支持（因为是 IgnoreCase）。**验证**：`umlMultipleMatch(True, 'RTSP://*', 'rtsp://x')` → True。

16. **`umlFindFirstFile` 在 `FindFirst` 失败后调用 `FindClose` 的行为**
    - 源码：`umlFindFirstFile` 失败时直接 `exit`，但**调用方仍应调用 `umlFindClose`**（源码里 `uml_Get_File_To_List` 在 `FindFirst` 失败时也调用了 `umlFindClose`）。
    - **不确定**：`FindClose` 在未初始化 SR 时是否安全。**推测**：安全（SysUtils.FindClose 会检查）。

17. **`umlCacheFileMD5` 的 `PPascalString` 内存管理**
    - 源码：`new(p); p^ := FileName; TCompute.RunC(p, nil, Do_ThCacheFileMD5)`。
    - `Do_ThCacheFileMD5` 内 `Dispose(p)`。
    - **不确定**：如果 TCompute 任务从未执行，`p` 泄漏。

18. **`umlComputeTextPoint` 的 CRLF 处理**
    - CR：列=0；LF：行+1，列=1。
    - **不确定**：单独 CR 或单独 LF 的行列行为是否符合预期。
    - **推测**：单独 LF 当作换行；单独 CR 只重置列不换行。

19. **`umlBase64Decode` 对 `\0` 的处理**
    - 源码预扫描 `\r \n \0` 计入 `ExtraSyms`。
    - **不确定**：`\0` 是否会被当作 BASE64 字符（`Base64Values[$00] = $FE`）。
    - **推测**：`$FE` 会被跳过（`C < 64` 不成立）。

20. **`ImportCSV_*` 的 `king`/`Data` 生命周期**
    - 源码：`SetLength(king, hc); SetLength(buff, hc)` 在函数内。
    - `OnNotify(sour[i], king, buff)` 传递数组引用。
    - **不确定**：回调内修改 `king`/`Data` 是否影响后续行（应该不会，因为是值传参）。
    - **推测**：TArrayPascalString 是动态数组，作为参数是引用传递，但回调修改是安全的（不会被复用）。

---

## 第 18 章 结语

### 18.1 本知识库覆盖范围

- **已精确描述**：
  - 文件系统操作的所有公开 API 与陷阱。
  - `TIOHnd` 的完整状态机与缓存策略。
  - `TReliableFileStream` 的激活条件与行为。
  - 字符串分词（连续/不连续语义）。
  - 通配符匹配（`umlMultipleMatch` / `umlSearchMatch`）。
  - Base64 流式上下文与高级 API。
  - MD5（含增量工具与文件缓存）。
  - CRC16 / CRC32。
  - RTSP/RTMP URL 解析。
  - CSV 导入。
  - 动态库加载。

- **已纠正的常见幻觉**：
  - **`umlDeleteFile` 在 `_VerifyCheck=False` 时总返回 True**（不是"删除成功"）。
  - **`umlMBPSToStr` 是 `× 10` 不是 `× 8`**（疑似 bug）。
  - **`umlBufferIsASCII` 把 `$80` 当 ASCII**（疑似 bug）。
  - **`umlStrToVar` 不做解码**（疑似 bug）。
  - **`umlGetFileName` / `umlGetFilePath` 对边界输入（如 `'C:\a\'`）返回空字符串**。
  - **`umlGetNumTextType` 的判定阈值是位数**（如 `ntByte` 是 < 3 位）。
  - **`umlIsHex` / `umlIsIntNumber` 语义完全相同**（命名误导）。
  - **`TRTSP_RTMP_URL.Encode` 是 JSON 序列化，不是 URL 编码**。
  - **`TReliableFileStream` 默认不激活**（需 `ZDB_BACKUP` 宏）。
  - **`umlMultipleMatch('', target)` 返回 True**（空模式匹配一切）。

- **未覆盖**：
  - 源码中的 20 个不确定点。
  - 除 `Z.UnicodeMixedLib` 之外的单元。
  - MD5 算法的数学正确性（假设标准实现正确）。

### 18.2 给 AI 的使用规则

1. **文件删除务必用 `_VerifyCheck=True`**。
2. **`TIOHnd` 在 Close 后 `Handle` 被置 nil**，需要时提前保存。
3. **`FixedStringL` 是字节数**，不是字符数（Delphi 下 1 汉字 = 2 字节）。
4. **`umlMultipleMatch` 空模式匹配一切**。
5. **`umlGetIndexStr` 的 `index=0` 或 `1` 等价**（都返回第一个）。
6. **`umlURLDecode` 遇到非法 `%XX` 会抛异常**。
7. **`umlStrToVar` 不做解码**，别指望它还原 `___base64:` 前缀。
8. **`GetExtLib` 的缓存非线程安全**，多线程需外部加锁。
9. **`umlFileMD5` 有缓存**，依赖时间+大小失效。
10. **遇到不确定清单里的场景，请查源码或问人**。

### 18.3 与 Z.Core / Z.PascalStrings 的衔接

- 使用本单元前，请先读 Z.Core 知识库第 1-3 章。
- 字符串类型的所有陷阱（1 基索引、`=` 区分大小写、`SetChars` 不检查边界）在本单元同样适用。
- 本单元的 Base64 / MD5 会用到 `Z.Cipher` / `Z.md5`（非公开 API），不要直接调用这些底层函数。

---

**本知识库的定位**：一份**准确的、有边界的、可操作的** `Z.UnicodeMixedLib` 参考。它不假装能替代源码，但能让你在 90% 的场景下正确使用，并在剩下 10% 的场景下知道该停下来问人。