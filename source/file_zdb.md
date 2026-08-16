
### 1. ZDB 体系（经典版）

| 文件名 | 说明 |
|--------|------|
| Z.ZDB.ObjectData_LIB.pas | 底层引擎，定义 Header/Field/Item/Block 记录结构及所有基本 I/O 操作函数 |
| Z.ZDB.ItemStream_LIB.pas | 将 ZDB 的 Item 封装为 TCore_Stream（TItemStream），支持流式读写和拷贝 |
| Z.ZDB.HashItem_LIB.pas | 基于 Item 的快速哈希查找（TObjectDataHashItem） |
| Z.ZDB.HashField_LIB.pas | 基于 Field 的快速哈希查找（TObjectDataHashField） |
| Z.ZDB.pas | TObjectDataManager：分层字段/项的 CRUD、搜索、导入导出及缓存封装 |
| Z.ZDB.Engine.pas | TDBStore：带实例缓存、流缓存、异步查询线程的数据库引擎增强 |
| Z.ZDB.FilePackage_LIB.pas | 批量导入/导出文件包，支持路径到数据库的转换 |
| Z.ZDB.FileIndexPackage_LIB.pas | 文件索引包的构建与检查工具 |
| Z.ZDB.LocalManager.pas | 本地数据库管理器，带查询管道、复制、压缩、片段缓冲区及通知接口 |

---

### 2. ZDB2 核心存储引擎

| 文件名 | 说明 |
|--------|------|
| Z.ZDB2.pas | ZDB2 块存储核心，支持加密、读写缓存、空间自动扩展、碎片整理和 CRC16 校验 |

---

### 3. ZDB2 泛化数据处理库（对特定数据结构的持久化封装）

| 文件名 | 说明 |
|--------|------|
| Z.ZDB2.DFE.pas | 对 DFE（数据帧引擎）对象的持久化支持 |
| Z.ZDB2.HS.pas | 对 THashStringList（字符串哈希表）的持久化支持 |
| Z.ZDB2.HV.pas | 对 THashVariantList（变体哈希表）的持久化支持 |
| Z.ZDB2.Json.pas | 对 TZ_JsonObject 的持久化支持 |
| Z.ZDB2.MEM64.pas | 对 TMem64（内存块）的持久化支持 |
| Z.ZDB2.MS64.pas | 对 TMS64（内存流）的持久化支持 |
| Z.ZDB2.NM.pas | 对 TNumberModulePool（数字模块池）的持久化支持 |
| Z.ZDB2.TE.pas | 对 THashTextEngine（文本引擎/INI-like）的持久化支持 |
| Z.ZDB2.ObjectDataManager.pas | 将 ZDB 的 TObjectDataManager 封装为 ZDB2 可持久化的对象（桥接） |

---

### 4. ZDB2 高精尖支持库（线程、并发、归档等高级功能）

| 文件名 | 说明 |
|--------|------|
| Z.ZDB2.Thread.Queue.pas | 线程安全命令队列，提供同步/异步读写、修改、移除操作及桥接回调 |
| Z.ZDB2.Thread.pas | 多线程数据引擎，管理引擎池、数据池、并行加载、备份/复制 |
| Z.ZDB2.Thread.APP.pas | 提供 Mem64/MS64 数据引擎基类，用于应用程序构建 |
| Z.ZDB2.Thread.LiteData.pas | 轻量级单数据库抽象，支持序列 ID 池、外部头优化、多种加载模式 |
| Z.ZDB2.Thread.LargeData.pas | 三层大数据分层数据库（小/中/大），支持批量提交、外部头优化 |
| Z.ZDB2.Thread.Pair_MD5_Stream.pas | 基于 MD5 键值对的片段存储，支持异步读写和并行提取 |
| Z.ZDB2.Thread.Pair_String_Stream.pas | 基于字符串键值对的片段存储，支持异步读写和并行提取 |
| Z.ZDB2.FileEncoder.pas | 文件归档打包器，支持并行压缩/解压、目录导入导出 |

---

### 5. 跨体系应用层（同时依赖 ZDB 和 ZDB2）

| 文件名 | 说明 |
|--------|------|
| Z.MediaCenter.pas | 统一媒体资源访问层，同时支持 ZDB1（TObjectDataHashField）和 ZDB2（TZDB2_File_Decoder）容器 |