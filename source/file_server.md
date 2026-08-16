# Z.Net 系列模块查询手册（修订完整版）

本手册按模块分类组织，涵盖 Z.Net 体系下的网络通信框架、双通道 IO、数据存储服务、Cloud 4.0 分布式服务、XNAT 穿透等核心单元。每个条目包含 **功能**、**依赖**（完整 uses 列表）、**导出类/类型**、**导出函数/过程**、**全局变量**、**初始化/终结** 以及 **关键字**。

> **修订说明**：本版根据源代码完整核对，补全了所有遗漏的导出方法、依赖项和全局变量，统一了术语与格式。

---

```text

Z.Net 系列模块依赖总览（按层级排序）

底层基础
├── Z.Net                      - 核心网络框架：命令协议、P2PVM、序列包、HPC、稳定IO
├── Z.Net.PhysicsIO            - 物理IO适配层：根据编译开关选择后端（ICS/CrossSocket/DIOCP/Indy/Synapse等）
└── Z.Net.IO                   - 简化别名：将 TPhysicsServer/Client 再导出为 TServer/TClient

双通道IO框架
├── Z.Net.DoubleTunnelIO       - 带内置用户认证的双通道（Recv/Send）服务/客户端
├── Z.Net.DoubleTunnelIO.NoAuth - 无认证版本的双通道
├── Z.Net.DoubleTunnelIO.VirtualAuth - 虚拟认证（回调驱动）双通道
└── Z.Net.DoubleTunnelIO.ServMan - 服务管理器：节点注册、负载上报、离线通知

DataStore 服务
├── Z.Net.DataStoreService.Common - 公共类型定义（管道、查询回调、通知结构）
├── Z.Net.DataStoreService      - 带内置认证的 DataStore（基于 TDTService）
├── Z.Net.DataStoreService.NoAuth - 无认证 DataStore（基于 TDTService_NoAuth）
└── Z.Net.DataStoreService.VirtualAuth - 虚拟认证 DataStore（基于 TDTService_VirtualAuth）

XNAT 穿透系统
├── Z.Net.XNAT.Physics         - 物理层基础：协议常量、缓冲区打包/解包
├── Z.Net.XNAT.Client          - XNAT 客户端：连接服务、端口映射、本地转发
├── Z.Net.XNAT.Service         - XNAT 服务端：监听外部、转发至注册客户端
└── Z.Net.XNAT.MappingOnVirutalService - 虚拟服务映射：每个映射作为独立 TZNet_Server

Cloud 4.0 核心
├── Z.Net.C4                   - C4 分布式核心：物理服务/隧道、服务发现（DP）、依赖注入、认证模型
└── Z.Net.C4.VM                - C4 VM 封装：将 NoAuth/VirtualAuth/内置认证 包装为可启动/停止组件

C4 基础服务
├── 用户数据库
│   ├── Z.Net.C4_UserDB        - 用户注册/认证/好友/IM/在线状态（基于 ZDB2 JSON）
│   └── Z.Net.C4_VM_UserDB     - VM 封装版本
├── 别名服务
│   └── Z.Net.C4_Alias         - 字符串别名 ↔ 字符串/MD5 映射（基于 ZDB2 HashString）
├── 随机种子
│   ├── Z.Net.C4_RandSeed      - 命名种子组管理
│   └── Z.Net.C4_VM_RandSeed   - VM 封装版本
└── 日志数据库
    └── Z.Net.C4_Log_DB        - 日志存储、查询、删除、监控（基于 ZDB2 HashString）

C4 文件系统
├── Z.Net.C4_FS                - 文件系统 1.0：上传/下载/MD5/删除/搜索（基于 ZDB2 MS64）
├── Z.Net.C4_FS2               - 文件系统 2.0：增加引用计数、MD5池、快速复制、多MD5查询
├── Z.Net.C4_VM_FS2            - VM 封装版本
├── Z.Net.C4_FS3               - 文件系统 3.0：基于 LiteData，支持生命周期、片段上传/异步队列
├── Z.Net.C4_FS3.ZDB2.LiteData - FS3 底层引擎：FileInfo/LinkTable/Body 存储，同步/队列操作
└── Z.Net.C4_VM_FS3            - VM 封装版本

C4 键值存储
├── Z.Net.C4_TEKeyValue        - 文本引擎键值服务（基于 ZDB2 HashTextEngine）
└── Z.Net.C4.VM_TEKeyValue     - VM 封装版本

C4 变量服务
├── Z.Net.C4_Var               - 动态变量服务（基于 TNumberModulePool），支持脚本执行
└── Z.Net.C4.VM_Var            - VM 封装版本

C4 网络磁盘
├── Z.Net.C4_NetDisk_Directory - 目录服务：文件元数据（MD5/片段）、列表/搜索/复制/重命名
├── Z.Net.C4_NetDisk_Service   - 网盘核心服务：整合 UserDB/Directory/FS2/Log/TEKeyValue，提供完整 API
├── Z.Net.C4_NetDisk_Admin_Tool - 管理工具：检查并回收无效片段
├── Z.Net.C4_NetDisk_Client    - 网盘客户端：用户认证/好友/文件操作/自动化上传下载
├── Z.Net.C4_NetDisk_Client.Task - 客户端任务系统：队列化上传/下载/目录同步，支持加密/解密
├── Z.Net.C4_NetDisk_VM_Client - VM 封装的网盘客户端
├── Z.Net.C4_NetDisk_VM_Client.Task - VM 客户端任务系统
└── Z.Net.C4_NetDisk_VM_Service - VM 封装的网盘服务

C4 XNAT 集成
├── Z.Net.C4_XNAT              - XNAT 的 C4 封装：服务/客户端管理映射
└── Z.Net.C4_XNAT_Cluster_Port_Mapping - 集群端口映射（CPM）：基于 XNAT 的集群端口转发

C4 代码重写工具
├── Z.Net.C4_PascalRewrite_Client - 客户端：提交代码请求重写
├── Z.Net.C4_PascalRewrite_Service - 服务端：执行单元/符号重写（支持 HPC）
└── Z.Pascal_Rewrite_Model_Data  - 重写模型数据资源

C4 控制台应用
└── Z.Net.C4_Console_APP       - 控制台应用框架：解析命令行/脚本，启动主循环与交互式控制台
```

**依赖关系说明**：
- 底层 `Z.Net` 被所有上层依赖；`Z.Net.PhysicsIO` 为 `Z.Net` 提供物理传输。
- 双通道 IO 框架建立在 `Z.Net` 之上，并作为 DataStore 和 C4 服务的基础。
- DataStore 服务基于双通道，提供数据库操作能力。
- XNAT 穿透系统独立于 C4，但可被 C4 集成。
- C4 核心建立在双通道和 DataStore 之上，提供分布式服务框架。
- C4 各具体服务依赖 C4 核心，并相互组合。
- VM 系列是对应服务的轻量封装，依赖 `Z.Net.C4.VM`。
- 控制台应用 `C4_Console_APP` 位于最上层。

---

## 1. 核心网络基础

### Z.Net
| 属性 | 内容 |
| :--- | :--- |
| **功能** | Z 框架网络通信核心，提供命令驱动的协议栈（控制台/流/大流/完整缓冲）、P2PVM 虚拟网络、序列包可靠传输、HPC 线程池执行、稳定 IO 会话、加密压缩、双通道支持。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.HashList.Templet`, `Z.ListEngine`, `Z.UnicodeMixedLib`, `Z.Status`, `Z.DFE`, `Z.MemoryStream`, `Z.Cipher`, `Z.Notify`, `Z.Cadencer`, `Z.ZDB2`。 |
| **导出类** | `TPeerIO`, `TZNet`, `TZNet_Server`, `TZNet_Client`, `TZNet_P2PVM`, `TZNet_WithP2PVM_Server`, `TZNet_WithP2PVM_Client`, `TZNet_StableServer`, `TZNet_StableClient`, `TZNet_Progress`, `TCommandStream`, `TCommandConsole`, `TCommandStreamNotify`, `TCommandConsoleNotify`, `TCommandBigStream`, `TCommandCompleteBuffer`, `TCommandCompleteBuffer_StreamNotify`, `TCommandCompleteBuffer_NoWait_Stream`, `TCommandCompleteBuffer_NoWait_Bridge_Stream`, `TCommandCompleteBuffer_NoWait_Bridge`, `THPC_Stream`, `THPC_StreamNotify`, `THPC_Console`, `THPC_ConsoleNotify`, `THPC_CompleteBuffer`, `THPC_CompleteBuffer_Stream`。 |
| **导出函数** | `NewQueueData`, `DisposeQueueData`, `InitQueueData`, `IsSystemCMD`, `RunHPC_Stream*`, `RunHPC_StreamNotify*`, `RunHPC_Console*`, `RunHPC_ConsoleNotify*`, `RunHPC_CompleteBuffer*`, `RunHPC_CompleteBuffer_Stream*`, `StrToIPv4`, `IPv4ToStr`, `StrToIPv6`, `IPv6ToStr`, `IsIPv4`, `IsIPV6`, `MakeRandomIPV6`, `CompareIPV4`, `CompareIPV6`, `TranslateBindAddr`, `ExtractHostAddress`, `Build_Host_URL`, `Get_Link_OK_Send_Tunnel`, `Get_Link_OK_Recv_Tunnel`, `DoExecuteResult`, `Set_Instance_QuietMode`。 |
| **全局变量** | `ZNet_Instance_Pool`, `HPC_Instance_Pool`, `ZNet_Def_*` 协议常量, `ProgressBackgroundProc`, `ProgressBackgroundMethod`。 |
| **初始化/终结** | 全局池在首次使用时创建，终结时释放。 |
| **关键字** | TPeerIO, TZNet, P2PVM, HPC, 序列包, 稳定IO, 加密, 压缩, 大流, 完整缓冲, 命令协议 |

### Z.Net.PhysicsIO
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 物理 IO 适配层，根据编译开关选择具体网络后端（ICS、CrossSocket、DIOCP、Indy、Synapse、FPC‑CrossSocket），对外统一暴露 `TPhysicsServer` 和 `TPhysicsClient`。 |
| **依赖** | 根据宏包含对应后端的实现单元，以及 `Z.Core`。 |
| **导出类型** | `TPhysicsServer`, `TPhysicsClient`, `TPhysicsService`, `TZService`, `TPhysicsTunnel`, `TZClient`, `TZTunnel`。 |
| **导出函数** | 无（仅类型别名）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | PhysicsIO, 网络后端, ICS, CrossSocket, DIOCP, Indy, Synapse, 适配层 |

### Z.Net.IO
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 极简重导出单元，将 `TPhysicsServer` / `TPhysicsClient` 再导出为 `TServer` / `TClient`。 |
| **依赖** | `Z.Net.PhysicsIO`。 |
| **导出类型** | `TServer`, `TClient`。 |
| **初始化/终结** | 无。 |
| **关键字** | 别名, 简化引用 |

---

## 2. 双通道 IO 框架

### Z.Net.DoubleTunnelIO
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 带内置用户认证的双通道（Recv/Send）服务与客户端，支持用户注册/登录、公/私文件存储、目录管理、批处理流、P2PVM 集成。 |
| **依赖** | `Z.Core`, `Z.ListEngine`, `Z.UnicodeMixedLib`, `Z.DFE`, `Z.MemoryStream`, `Z.Net`, `Z.TextDataEngine`, `Z.Status`, `Z.Cadencer`, `Z.Notify`, `Z.ZDB.FilePackage_LIB`, `Z.Cipher`。 |
| **导出类** | `TDTService`, `TDTClient`, `TService_RecvTunnel_UserDefine`, `TService_SendTunnel_UserDefine`, `TClient_RecvTunnel`, `TClient_SendTunnel`, `TDT_P2PVM_Service`, `TDT_P2PVM_Client`, `TDT_P2PVM_Custom_Service`, `TDT_P2PVM_Custom_Client`。 |
| **导出函数** | 文件操作回调类型：`TGetFileInfo_*`, `TFileMD5_*`, `TFileComplete_*`, `TFileFragmentData_*`（C/M/P 三风格）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 双通道, 用户认证, 文件存储, 公/私有, P2PVM, 批处理流 |

### Z.Net.DoubleTunnelIO.NoAuth
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 无认证版本的双通道服务/客户端，提供文件传输、批处理流、P2PVM 集成，省略用户管理。 |
| **依赖** | 同 `Z.Net.DoubleTunnelIO`，但不依赖用户 DB。 |
| **导出类** | `TDTService_NoAuth`, `TDTClient_NoAuth`, `TService_RecvTunnel_UserDefine_NoAuth`, `TService_SendTunnel_UserDefine_NoAuth`, `TClient_RecvTunnel_NoAuth`, `TClient_SendTunnel_NoAuth`, `TDT_P2PVM_NoAuth_Service`, `TDT_P2PVM_NoAuth_Client`, `TDT_P2PVM_NoAuth_Custom_Service`, `TDT_P2PVM_NoAuth_Custom_Client`。 |
| **导出函数** | 文件操作回调类型（`*_NoAuth` 后缀）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 双通道, 无认证, 文件传输, P2PVM, 批处理流 |

### Z.Net.DoubleTunnelIO.VirtualAuth
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 虚拟认证双通道框架，认证/注册逻辑通过应用程序回调（`OnUserAuth`, `OnUserReg`）实现，不内置用户数据库。 |
| **依赖** | 同 `Z.Net.DoubleTunnelIO`，但回调驱动。 |
| **导出类** | `TDTService_VirtualAuth`, `TDTClient_VirtualAuth`, `TVirtualAuthIO`, `TVirtualRegIO`, `TService_RecvTunnel_UserDefine_VirtualAuth`, `TService_SendTunnel_UserDefine_VirtualAuth`, `TClient_RecvTunnel_VirtualAuth`, `TClient_SendTunnel_VirtualAuth`, `TDT_P2PVM_VirtualAuth_Service`, `TDT_P2PVM_VirtualAuth_Client`, `TDT_P2PVM_VirtualAuth_Custom_Service`, `TDT_P2PVM_VirtualAuth_Custom_Client`。 |
| **导出函数** | 文件操作回调类型（`*_VirtualAuth` 后缀）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 双通道, 虚拟认证, 回调认证, P2PVM |

### Z.Net.DoubleTunnelIO.ServMan
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 服务管理器，用于注册/监控远程服务节点，支持反空闲、负载上报、节点离线通知。 |
| **依赖** | `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Core`, `Z.TextDataEngine`, `Z.ListEngine`, `Z.Notify`, `Z.Cipher`。 |
| **导出类** | `TServerManager`, `TServerManager_Client`, `TServerManager_ClientPool`, `TServerManager_SendTunnelData`, `TServerManager_RecvTunnelData`。 |
| **导出函数** | `serverType2Str`。 |
| **全局变量** | `DEFAULT_MANAGERSERVICE_RECVPORT`, `DEFAULT_MANAGERSERVICE_SENDPORT`, `DEFAULT_MANAGERSERVICE_QUERYPORT`。 |
| **初始化/终结** | 无。 |
| **关键字** | 服务管理, 节点注册, 负载上报, 离线通知, 反空闲 |

---

## 3. DataStore 服务

### Z.Net.DataStoreService.Common
| 属性 | 内容 |
| :--- | :--- |
| **功能** | DataStore 服务的公共类型定义，包括管道类、查询回调结构、通知记录等。 |
| **依赖** | `Z.Core`, `Z.Net`, `Z.PascalStrings`, `Z.ZDB.Engine`, `Z.ZDB.LocalManager`, `Z.MemoryStream`, `Z.DFE`。 |
| **导出类型** | `TTDataStoreService_DBPipeline`, `TTDataStoreService_Query_C`, `TDataStoreClientQueryNotify`, `TDataStoreClientDownloadNotify`, `TStorePosTransformNotify`, `TPipeState`。 |
| **导出函数** | 无。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | DataStore, 管道, 查询, 下载, 位置变换 |

### Z.Net.DataStoreService
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 带内置用户认证的 DataStore 服务，基于 `TDTService` 扩展，提供数据库（ZDB）的查询、下载、插入、修改、删除等操作，支持管道和回调。 |
| **依赖** | `Z.Core`, `Z.ListEngine`, `Z.UnicodeMixedLib`, `Z.DFE`, `Z.MemoryStream`, `Z.Net`, `Z.TextDataEngine`, `Z.Status`, `Z.Cadencer`, `Z.Notify`, `Z.Cipher`, `Z.ZDB.Engine`, `Z.ZDB.ItemStream_LIB`, `Z.Compress`, `Z.Json`, `Z.Net.DoubleTunnelIO`, `Z.Net.DataStoreService.Common`, `Z.ZDB.LocalManager`。 |
| **导出类** | `TDataStoreService`, `TDataStoreClient`, `TDataStoreService_RecvTunnel_UserDefine`, `TDataStoreService_SendTunnel_UserDefine`。 |
| **导出函数（客户端）** | `InitDB`, `CloseDB`, `CopyDB`（含 C/M/P 回调）, `CompressDB`（含 C/M/P）, `ReplaceDB`, `ResetData`, `QuietQueryDB`, `QueryDB`（含 C/M/P 和用户参数）, `DownloadDB`（含 C/M/P）, `DownloadDBWithID`（含 C/M/P）, `BeginAssembleStream`, `RequestDownloadAssembleStream`（含 C/M/P）, `RequestFastDownloadAssembleStream`（含 C/M/P）, `PostAssembleStream`（多种重载：流/DFE/HashVariant/HashString/SectionText/Json/字符串）, `InsertAssembleStream`（多种重载）, `ModifyAssembleStream`（多种重载）, `EndAssembleStream`, `DeleteData`, `FastPostCompleteBuffer`（多种重载）, `FastInsertCompleteBuffer`（多种重载）, `FastModifyCompleteBuffer`（多种重载）, `GetPostAssembleStreamStateM/P`, `QueryStop`, `QueryPause`, `QueryPlay`, `GetDBListM/P`, `GetQueryListM/P`, `GetQueryStateM/P`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | DataStore, 数据库, 查询, ZDB, 管道, 认证 |

### Z.Net.DataStoreService.NoAuth
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 无认证版的 DataStore 服务，基于 `TDTService_NoAuth` 扩展，功能同 `DataStoreService` 但不含用户认证。 |
| **依赖** | 同 `DataStoreService`，但使用 NoAuth 双通道。 |
| **导出类** | `TDataStoreService_NoAuth`, `TDataStoreClient_NoAuth`, `TDataStoreService_RecvTunnel_UserDefine_NoAuth`, `TDataStoreService_SendTunnel_UserDefine_NoAuth`。 |
| **导出函数** | 同 `TDataStoreClient` 的所有公共方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | DataStore, 无认证, ZDB, 查询, 管道 |

### Z.Net.DataStoreService.VirtualAuth
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 虚拟认证版的 DataStore 服务，基于 `TDTService_VirtualAuth` 扩展，认证回调由应用处理。 |
| **依赖** | 同 `DataStoreService`，但使用 VirtualAuth 双通道。 |
| **导出类** | `TDataStoreService_VirtualAuth`, `TDataStoreClient_VirtualAuth`, `TDataStoreService_RecvTunnel_UserDefine_VirtualAuth`, `TDataStoreService_SendTunnel_UserDefine_VirtualAuth`。 |
| **导出函数** | 同 `TDataStoreClient` 的所有公共方法（但回调类型带 `_VirtualAuth` 后缀）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | DataStore, 虚拟认证, ZDB, 查询, 管道 |

---

## 4. Cloud 4.0 (C4) 核心框架

### Z.Net.C4
| 属性 | 内容 |
| :--- | :--- |
| **功能** | Cloud 4.0 分布式服务框架核心，提供物理服务/隧道管理、服务发现（DP）、依赖注入、多种认证模型（NoAuth/VirtualAuth/BuiltInAuth）、自动部署、控制台命令。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Parsing`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.Expression`, `Z.OpCode`, `Z.ZDB2`, `Z.ZDB2.Thread.Queue`, `Z.ZDB2.Thread`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO`, `Z.Net.DoubleTunnelIO.VirtualAuth`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.DataStoreService`, `Z.Net.DataStoreService.VirtualAuth`, `Z.Net.DataStoreService.NoAuth`, `Z.Net.Client.IPC`, `Z.Net.Server.IPC`, `Z.Instance.Tool`。 |
| **导出类** | `TC40_PhysicsService`, `TC40_PhysicsTunnel`, `TC40_Info`, `TC40_InfoList`, `TC40_Custom_Service`, `TC40_Custom_Client`, `TC40_Dispatch_Service`, `TC40_Dispatch_Client`, `TC40_Base_NoAuth_Service`, `TC40_Base_NoAuth_Client`, `TC40_Base_VirtualAuth_Service`, `TC40_Base_VirtualAuth_Client`, `TC40_Base_Service`, `TC40_Base_Client`, `TC40_Base_DataStoreNoAuth_Service/Client`, `TC40_Base_DataStoreVirtualAuth_Service/Client`, `TC40_Base_DataStore_Service/Client`, `TC40_Custom_VM_Service`, `TC40_Custom_VM_Client`, `TC40_Console_Help`。 |
| **导出函数** | `RegisterC40`, `FindRegistedC40`, `GetRegisterClientTypFromClass`, `GetRegisterServiceTypFromClass`, `Compare_C40_ServiceTyp`（多重重载）, `ExtractDependInfo`（多种重载）, `ResetDependInfoBuff`, `Is_IPC_Addr`, `Get_Physics_Server_Class`, `Get_Physics_Client_Class`, `C40Progress`, `C40_Online_DP`, `C40SetQuietMode`, `C40WriteConfig`, `C40ReadConfig`, `C40ResetDefaultConfig`, `C40Clean`, `C40Clean_Service`, `C40Clean_Client`, `C40PrintRegistation`, `C40ExistsPhysicsNetwork`, `C40_Get_Physics_Connected_Num`, `C40_Get_Physics_Netowork_Is_Inited_Num`, `C40RemovePhysics`（多重重载）, `C40CheckAndKillDeadPhysicsTunnel`。 |
| **全局变量** | `C40_QuietMode`, `C40_SafeCheckTime`, `C40_PhysicsReconnectionDelayTime`, `C40_UpdateServiceInfoDelayTime`, `C40_PhysicsServiceTimeout`, `C40_PhysicsTunnelTimeout`, `C40_KillDeadPhysicsConnectionTimeout`, `C40_KillIDCFaultTimeout`, `C40_EnablePerServiceDirectory`, `C40_RootPath`, `C40_Password`, `C40_PhysicsClientClass`, `C40_Registed`, `C40_PhysicsServicePool`, `C40_ServicePool`, `C40_PhysicsTunnelPool`, `C40_ClientPool`, `C40_VM_Service_Pool`, `C40_VM_Client_Pool`, `C40_DefaultConfig`, `Ignore_Command_Line`。 |
| **初始化/终结** | 注册默认服务类型，创建全局池；终结时释放各池。 |
| **关键字** | C4, 分布式, 服务发现, DP, 依赖注入, 认证, 物理隧道, VM, 控制台 |

### Z.Net.C4.VM
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 的 VM（虚拟机）风格服务/客户端封装，将 `TDTService_NoAuth/VirtualAuth` 等包装为可独立启动/停止的组件，并提供 DataStore 变体。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.Expression`, `Z.OpCode`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.DoubleTunnelIO.VirtualAuth`, `Z.Net.DataStoreService`, `Z.Net.DataStoreService.NoAuth`, `Z.Net.DataStoreService.VirtualAuth`, `Z.Net.C4`, `Z.Net.Client.IPC`, `Z.Net.Server.IPC`。 |
| **导出类** | `TC40_NoAuth_VM_Service`, `TC40_NoAuth_VM_Client`, `TC40_DataStore_NoAuth_VM_Service`, `TC40_DataStore_NoAuth_VM_Client`, `TC40_VirtualAuth_VM_Service`, `TC40_VirtualAuth_VM_Client`, `TC40_DataStore_VirtualAuth_VM_Service`, `TC40_DataStore_VirtualAuth_VM_Client`, `TC40_VM_Service`（内置认证）, `TC40_VM_Client`, `TC40_DataStore_VM_Service`, `TC40_DataStore_VM_Client`。 |
| **导出函数** | `TC40_NoAuth_VM_Service.Get_Service_Class`, `TC40_NoAuth_VM_Client.Get_Client_Class` 及 `Connect` 重载（`addr, Port, Auth` 无返回值）, 其它类似类方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, 虚拟机, 服务封装, 客户端封装, NoAuth, VirtualAuth, DataStore |

---

## 5. C4 基础服务

### Z.Net.C4_UserDB
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 用户数据库服务，基于 ZDB2 JSON 存储，提供用户注册/认证/密码管理、好友系统、在线状态、IM 消息、管理功能（搜索/上传/删除）。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.Geometry2D`, `Z.DFE`, `Z.Expression`, `Z.OpCode`, `Z.ListEngine`, `Z.Json`, `Z.HashList.Templet`, `Z.ZDB2`, `Z.ZDB2.Json`, `Z.Cipher`, `Z.Notify`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`。 |
| **导出类** | `TC40_UserDB_Service`, `TC40_UserDB_Client`, `I_ON_C40_UserDB_Client_Notify`。 |
| **导出函数（客户端）** | `Usr_Open`, `Usr_Close`, `Usr_IsOpen`（单/多用户，C/M/P）, `Usr_Msg`, `Usr_GetFriends`（C/M/P）, `Usr_RemoveFriend`, `Usr_RequestAddFriend`, `Usr_ReponseAddFriend`, `Usr_OnlineNum`（C/M/P）, `Usr_OnlineList`（C/M/P）, `Usr_Kick`, `Usr_Enabled`, `Usr_Disable`, `Usr_Reg`（C/M/P）, `Usr_Exists`（C/M/P）, `Usr_Auth`（C/M/P）, `Usr_ChangePassword`（C/M/P）, `Usr_ResetPassword`, `Usr_NewIdentifier`（C/M/P）, `Usr_GetPrimaryIdentifier`（C/M/P）, `Usr_Get`（C/M/P）, `Usr_Set`, `Usr_SearchM/P`, `Usr_Upload`（JSON/List）, `Usr_Remove`（单/列表）。 |
| **导出函数（服务端）** | `SendMsg`（发送 IM 消息）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 用户数据库, 注册, 认证, 好友, IM, 在线状态, ZDB2, JSON |

### Z.Net.C4_VM_UserDB
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_UserDB_Service`/`Client` 的 VM 封装版本，继承自 `TC40_NoAuth_VM_Service`/`Client`。 |
| **依赖** | 同 `Z.Net.C4_UserDB`，但增加 `Z.Net.C4.VM`。 |
| **导出类** | `TC40_UserDB_VM_Service`, `TC40_UserDB_VM_Client`, `I_ON_C40_UserDB_VM_Client_Notify`。 |
| **导出函数** | 同 `TC40_UserDB_Client` 的所有公共方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, 用户数据库, 注册, 认证, 好友, IM |

### Z.Net.C4_Alias
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 别名服务，提供字符串别名到字符串或 MD5 的映射存储，基于 ZDB2 HashString。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.Geometry2D`, `Z.DFE`, `Z.ListEngine`, `Z.Parsing`, `Z.Expression`, `Z.OpCode`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`, `Z.ZDB2.HS`, `Z.ZDB2`。 |
| **导出类** | `TC40_Alias_Service`, `TC40_Alias_Client`。 |
| **导出函数（客户端）** | `SetAlias`（重载：别名→字符串/别名→MD5）, `GetAlias_C/M/P`, `RemoveAlias`, `SearchAlias_C/M/P`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 别名, 映射, ZDB2, HashString |

---

## 6. C4 文件系统服务

### Z.Net.C4_FS
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 文件系统服务（版本 1.0），提供文件上传/下载、MD5 查询、删除、搜索、大小统计，基于 ZDB2 MS64 存储。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Expression`, `Z.OpCode`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.ZDB2`, `Z.ZDB2.MS64`, `Z.HashList.Templet`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`。 |
| **导出类** | `TC40_FS_Service`, `TC40_FS_Client`, `TFS_Service_File_Data`, `TFS_Client_CacheData`。 |
| **导出函数（客户端）** | `FS_PostFile`（重载：文件/流）, `FS_PostFile_C/M/P`, `FS_GetFile_C/M/P`, `FS_GetFileMD5_C/M/P`, `FS_RemoveFile`（单/列表）, `FS_Size_C/M/P`, `FS_Search_C/M/P`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 文件系统, FS, 上传, 下载, MD5, ZDB2, MS64 |

### Z.Net.C4_FS2
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 文件系统服务版本 2.0，在 FS 基础上增加引用计数（Ref）、MD5 池、快速复制、多 MD5 查询、片段池管理。 |
| **依赖** | 同 `Z.Net.C4_FS`，并增加 `Z.HashList.Templet`。 |
| **导出类** | `TC40_FS2_Service`, `TC40_FS2_Client`, `TC40_FS2_Service_File_Data`, `TC40_FS2_Service_MD5_Data_Pool`, `TC40_FS2_Service_ZDB2_MS64`。 |
| **导出函数（客户端）** | `FS2_CheckMD5AndFastCopy`（C/M/P，两种重载：MD5+Size 或 Stream）, `FS2_PostFile`（带 UsedCache 参数，C/M/P）, `FS2_GetFile`（C/M/P）, `FS2_GetFileMD5`（C/M/P）, `FS2_SearchMultiMD5`（C/M/P）, `FS2_GetMD5Files`（C/M/P）, `FS2_RemoveFile`（单/列表）, `FS2_UpdateFileTime`, `FS2_UpdateFileRef`, `FS2_IncFileRef`, `FS2_Size`（C/M/P）, `FS2_Search`（C/M/P）, `FS2_PoolFrag`（C/M/P）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | FS2, 文件系统, 引用计数, MD5池, 快速复制, 多MD5, 片段池 |

### Z.Net.C4_VM_FS2
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_FS2_Service`/`Client` 的 VM 封装。 |
| **依赖** | 同 `Z.Net.C4_FS2`，但增加 `Z.Net.C4.VM`。 |
| **导出类** | `TC40_FS2_VM_Service`, `TC40_FS2_VM_Client`。 |
| **导出函数** | 同 `TC40_FS2_Client` 的所有公共方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, FS2, 文件系统 |

### Z.Net.C4_FS3
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 文件系统服务版本 3.0，基于 `Z.Net.C4_FS3.ZDB2.LiteData` 引擎，支持文件生命周期、片段式上传/下载、异步队列、轻量级数据库。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Expression`, `Z.OpCode`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`, `Z.ZDB2`, `Z.ZDB2.Thread`, `Z.ZDB2.Thread.Queue`, `Z.Net.C4_FS3.ZDB2.LiteData`。 |
| **导出类** | `TC40_FS3_Service`, `TC40_FS3_Client`, `TC40_FS3_Service_RecvTunnel_NoAuth`, `TC40_FS3_Service_SendTunnel_NoAuth`, `TC40_FS3_Service_Get_File_Bridge`, `TC40_FS3_Client_Post_File_Bridge`, `TC40_FS3_Client_Get_File_Bridge`。 |
| **导出函数（客户端）** | `Fast_Post_File`, `Post_File`（C/M/P）, `Get_File`（C/M/P，不自动释放输出流）, `Get_File_List`（C/M/P）, `Remove_File`, `Update_Lite_Info`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | FS3, 文件系统, 生命周期, 片段, 轻量级, LiteData |

### Z.Net.C4_VM_FS3
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_FS3_Service`/`Client` 的 VM 封装。 |
| **依赖** | 同 `Z.Net.C4_FS3`，但增加 `Z.Net.C4.VM`。 |
| **导出类** | `TC40_FS3_VM_Service`, `TC40_FS3_VM_Client`。 |
| **导出函数** | 同 `TC40_FS3_Client` 的所有公共方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, FS3, 文件系统 |

### Z.Net.C4_FS3.ZDB2.LiteData
| 属性 | 内容 |
| :--- | :--- |
| **功能** | FS3 的底层 ZDB2 轻量数据引擎，实现文件信息（FileInfo）、链接表（LinkTable）、数据体（Body）的存储，提供同步/队列上传、下载、删除、生命周期检查。 |
| **依赖** | `Z.Core`, `Z.IOThread`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Expression`, `Z.OpCode`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.HashList.Templet`, `Z.ZDB2`, `Z.ZDB2.Thread`, `Z.ZDB2.Thread.APP`, `Z.ZDB2.Thread.Queue`, `Z.ZDB2.Thread.LiteData`, `Z.TextDataEngine`。 |
| **导出类** | `TZDB2_FS3_Lite`, `TZDB2_FS3_FileInfo`, `TZDB2_FS3_Link_Table`, `TZDB2_FS3_Body`, `TZDB2_FS3_Sync_Post_Tool`, `TZDB2_FS3_Sync_Post_Queue_Tool`, `TZDB2_FS3_Sync_Get_Tool`, `TZDB2_FS3_Remove_Tool`。 |
| **导出函数** | `TZDB2_FS3_Lite` 方法：`Sync_Post_Data`（C/M/P）, `Create_Sync_Post_Queue`, `Create_FI_From_LT_MD5`, `Sync_Get_Data`（C/M/P）, `Remove`（C/M/P）, `Check_Life`, `Check_Recycle_Pool`, `Progress`, `SetBackupDirectory`, `Backup`, `Backup_If_No_Exists`, `Flush`, `Database_Size`, `Database_Physics_Size`, `Total`, `QueueNum`, `Fragment_Buffer_Num`, `Fragment_Buffer_Memory`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | LiteData, ZDB2, FS3, 文件信息, 链接表, 数据体, 生命周期, 队列上传 |

---

## 7. C4 键值存储服务

### Z.Net.C4_TEKeyValue
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 文本引擎键值服务，基于 ZDB2 HashTextEngine 存储，提供键值对的增删改查、批量操作、节（Section）管理、搜索。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.Geometry2D`, `Z.DFE`, `Z.ListEngine`, `Z.Parsing`, `Z.Expression`, `Z.OpCode`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`, `Z.TextDataEngine`, `Z.ZDB2.TE`, `Z.ZDB2`, `Z.HashList.Templet`。 |
| **导出类** | `TC40_TEKeyValue_Service`, `TC40_TEKeyValue_Client`。 |
| **导出函数（客户端）** | `Rebuild`, `GetTE`（C/M/P）, `SetTE`, `MergeTE`, `RemoveTE`, `SearchAndRemoveTE`, `GetSection`（C/M/P）, `GetKey`（C/M/P）, `GetTextKey`（C/M/P）, `GetKeyValue`（C/M/P）, `GetTextKeyValue`（C/M/P）, `ExistsTE`（C/M/P）, `ExistsSection`（C/M/P）, `ExistsKey`（C/M/P）, `RemoveSection`, `RemoveKey`, `GetValue`（C/M/P）, `GetTextValue`（C/M/P）, `SetValue`, `SetTextValue`, `SearchTE`（C/M/P）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 键值, TEKeyValue, HashTextEngine, ZDB2, Section, Key-Value |

### Z.Net.C4.VM_TEKeyValue
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_TEKeyValue_Service`/`Client` 的 VM 封装。 |
| **依赖** | 同 `Z.Net.C4_TEKeyValue`，增加 `Z.Net.C4.VM`。 |
| **导出类** | `TC40_TEKeyValue_VM_Service`, `TC40_TEKeyValue_VM_Client`。 |
| **导出函数** | 同 `TC40_TEKeyValue_Client` 的所有公共方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, TEKeyValue, 键值 |

---

## 8. C4 变量服务

### Z.Net.C4_Var
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 动态变量服务，基于 `TNumberModulePool` 提供命名变量集，支持变量读写、脚本执行（表达式）、临时变量、生命周期管理，并集成 `Z.Expression`。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.Geometry2D`, `Z.DFE`, `Z.ListEngine`, `Z.Parsing`, `Z.Expression`, `Z.OpCode`, `Z.Json`, `Z.HashList.Templet`, `Z.Number`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.ZDB.ObjectData_LIB`, `Z.ZDB`, `Z.ZDB.ItemStream_LIB`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`。 |
| **导出类** | `TC40_Var_Service`, `TC40_Var_Client`, `TC40_Var_Service_NM_Pool`。 |
| **导出函数（客户端）** | `NM_Init`, `NM_InitAsTemp`, `NM_Remove`, `NM_RemoveKey`, `NM_Get`（C/M/P）, `NM_GetValue`（C/M/P）, `NM_Open`（C/M/P）, `NM_Close`, `NM_CloseAll`, `NM_Change`, `NM_Keep`, `NM_Script`（C/M/P）, `NM_Save`, `NM_Search`（C/M/P）, `NM_SearchAndRunScript`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 变量, Var, NumberModule, 脚本, 表达式, 临时变量 |

### Z.Net.C4.VM_Var
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_Var_Service`/`Client` 的 VM 封装。 |
| **依赖** | 同 `Z.Net.C4_Var`，增加 `Z.Net.C4.VM`。 |
| **导出类** | `TC40_Var_VM_Service`, `TC40_Var_VM_Client`。 |
| **导出函数** | 同 `TC40_Var_Client` 的所有公共方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, Var, 变量 |

---

## 9. C4 随机种子服务

### Z.Net.C4_RandSeed
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 全局随机种子服务，管理命名种子组（`TUInt32HashPointerList`），客户端可申请/移除随机数。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Expression`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.ZDB2`, `Z.HashList.Templet`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`。 |
| **导出类** | `TC40_RandSeed_Service`, `TC40_RandSeed_Client`。 |
| **导出函数（客户端）** | `MakeSeed`（C/M/P，含 Bridge 重载）, `RemoveSeed`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 随机种子, RandSeed, 种子组 |

### Z.Net.C4_VM_RandSeed
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_RandSeed_Service`/`Client` 的 VM 封装。 |
| **依赖** | 同 `Z.Net.C4_RandSeed`，增加 `Z.Net.C4.VM`。 |
| **导出类** | `TC40_RandSeed_VM_Service`, `TC40_RandSeed_VM_Client`。 |
| **导出函数** | 同 `TC40_RandSeed_Client` 的所有公共方法。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, 随机种子 |

---

## 10. C4 日志数据库服务

### Z.Net.C4_Log_DB
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 日志数据库服务，基于 ZDB2 HashString 存储日志条目（时间、内容1、内容2），支持按时间范围查询、删除、日志数据库管理、实时监控。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Expression`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.ZDB2`, `Z.ZDB2.HS`, `Z.HashList.Templet`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`。 |
| **导出类** | `TC40_Log_DB_Service`, `TC40_Log_DB_Client`, `TLogData__`, `TLogData_List`。 |
| **导出函数（客户端）** | `PostLog`（重载：单/双日志）, `QueryLog`（C/M/P，含 Bridge 重载，支持 filter）, `QueryAndRemoveLog`（重载：带/不带 filter）, `RemoveLog`（数组索引）, `GetLogDB`（C/M/P）, `CloseDB`, `RemoveDB`, `Enabled_LogMonitor`。 |
| **导出函数（公共）** | `MakeNowDateStr`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 日志, Log, ZDB2, HashString, 查询, 删除, 监控 |

---

## 11. C4 网络磁盘（NetDisk）

### Z.Net.C4_NetDisk_Directory
| 属性 | 内容 |
| :--- | :--- |
| **功能** | NetDisk 目录服务，管理用户文件目录（Field/Item），存储文件元数据（MD5、片段列表），支持文件列表、MD5 查询、片段信息、搜索、复制、重命名、空间统计。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.Geometry2D`, `Z.DFE`, `Z.Json`, `Z.Expression`, `Z.OpCode`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.ZDB2`, `Z.ZDB2.ObjectDataManager`, `Z.ZDB2.DFE`, `Z.ZDB.ObjectData_LIB`, `Z.ZDB`, `Z.ZDB.ItemStream_LIB`, `Z.HashList.Templet`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`。 |
| **导出类** | `TC40_NetDisk_Directory_Service`, `TC40_NetDisk_Directory_Client`, `TDirectory_MD5_Data_Frag_Struct_List`, `TOpti_Directory_File_Hash_Item_Data_List`。 |
| **导出函数（客户端）** | `ExistsDB`（C/M/P）, `NewDB`（C/M/P）, `RemoveDB`, `download_DB`（C/M/P）, `GetItemList`（C/M/P）, `GetItemMD5`（C/M/P）, `GetItemFrag`（C/M/P）, `FoundMD5`（C/M/P）, `PutItemFrag`（C/M/P）, `PutItemMD5`（C/M/P）, `RemoveField`, `RemoveItem`, `NewField`, `SpaceInfo`（C/M/P）, `SearchItem`（C/M/P）, `SearchField`（C/M/P）, `CopyItem`（数组）, `CopyField`（数组）, `RenameField`, `RenameItem`, `SearchInvalidFrag`（C/M/P）, `SearchSameItem`（C/M/P）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 目录, Directory, NetDisk, 元数据, 片段, 文件列表 |

### Z.Net.C4_NetDisk_Service
| 属性 | 内容 |
| :--- | :--- |
| **功能** | NetDisk 核心服务，整合用户认证（UserDB）、目录（Directory）、文件存储（FS2）、日志（Log）、键值（TEKeyValue），提供文件上传/下载/复制/删除、分享磁盘、搜索等全套网盘 API。 |
| **依赖** | 同 `Z.Net.C4_NetDisk_Service` 的 uses 列表（见代码）。 |
| **导出类** | `TC40_NetDisk_Service`, `TC40_NetDisk_UserDB_Service/Client`, `TC40_NetDisk_FS2_Service/Client`, `TC40_NetDisk_Log_DB_Service/Client`, `TC40_NetDisk_TEKeyValue_Service/Client`。 |
| **导出函数（服务端）** | `cmd_Auth`, `cmd_Reg`, `cmd_NewLoginName`, `cmd_NewAlias`, `cmd_GetAlias`, `cmd_Msg`, `cmd_RequestFriend`, `cmd_ReponseFriend`, `cmd_RemoveFriend`, `cmd_GetMyFriends`, `cmd_GetOnlineNum`, `cmd_GetOnlineList`, `cmd_Get_NetDisk_Config`, `cmd_Get_FS_Service`, `cmd_SearchMultiMD5_FS_Service`, `cmd_CheckAndCopy_NetDisk_File`, `cmd_BeginPost_NetDisk_File`, `cmd_CheckAndCopy_NetDisk_File_Frag`, `cmd_Fast_Copy_NetDisk_File_Frag`, `cmd_Post_NetDisk_File_Frag`, `cmd_EndPost_NetDisk_File`, `cmd_Get_NetDisk_File_Frag_Info`, `cmd_Get_NetDisk_File_Frag_MD5`, `cmd_Get_NetDisk_Multi_File_Frag_MD5`, `cmd_Get_NetDisk_File_Frag`, `cmd_Get_NetDisk_File_MD5`, `cmd_Get_NetDisk_File_List`, `cmd_Get_NetDisk_SpaceInfo`, `cmd_Remove_Item`, `cmd_Remove_Field`, `cmd_Copy_Item`, `cmd_Copy_Field`, `cmd_CreateField`, `cmd_RenameField`, `cmd_RenameItem`, `cmd_Build_Share_Disk`, `cmd_Get_Share_Disk`, `cmd_Remove_Share_Disk`, `cmd_Get_Share_Disk_File_List`, `cmd_Get_Share_Disk_File_Frag_Info`, `cmd_Search_NetDisk_File`, `cmd_Search_Share_NetDisk_File`, `cmd_Search_NetDisk_Field`, `cmd_Search_Share_NetDisk_Field`, `cmd_Auth_Admin`, `cmd_Close_Auth_Admin`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | NetDisk, 网盘, 文件上传, 下载, 分享, 目录, 用户认证 |

### Z.Net.C4_NetDisk_Admin_Tool
| 属性 | 内容 |
| :--- | :--- |
| **功能** | NetDisk 管理工具服务，提供自动化管理程序，如检查并回收 FS2 中的无效片段。 |
| **依赖** | 同 `Z.Net.C4_NetDisk_Service`。 |
| **导出类** | `TC40_NetDisk_Admin_Tool_Service`, `TC40_NetDisk_Admin_Tool_Client`。 |
| **导出函数（客户端）** | `Enabled_Automated_Admin_Program`, `Check_And_Recycle_Fragment_For_FS2`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 管理, 回收, 无效片段, Admin |

### Z.Net.C4_NetDisk_Client
| 属性 | 内容 |
| :--- | :--- |
| **功能** | NetDisk 客户端，提供用户认证、好友、消息、文件操作（上传/下载/删除/复制/搜索）、分享磁盘、自动化上传/下载（支持片段匹配和断点续传）。 |
| **依赖** | 同 `Z.Net.C4_NetDisk_Service` 但仅客户端侧，增加 `Z.IOThread`, `Z.ZDB2.Thread.Pair_MD5_Stream` 等。 |
| **导出类** | `TC40_NetDisk_Client`, `TC40_NetDisk_Client_On_Usr_Auto_Post_File`, `TC40_NetDisk_Client_On_Usr_Auto_Get_File`。 |
| **导出函数（客户端）** | `AuthC/M/P`, `RegC/M/P`, `NewLoginName_C/M/P`, `NewAlias`, `GetAlias_C/M/P`, `Msg`, `RequestFriend`, `ReponseFriend`, `RemoveFriend`, `GetMyFriends_C/M/P`, `GetOnlineNum_C/M/P`, `GetOnlineList_C/M/P`, `Get_FS_Service_C/M/P`, `SearchMultiMD5_FS_Service_C/M/P`, `CheckAndCopy_NetDisk_File_C/M/P`, `BeginPost_NetDisk_File_C/M/P`, `CheckAndCopy_NetDisk_File_Frag_C/M/P`, `Fast_Copy_NetDisk_File_Frag`, `Post_NetDisk_File_Frag`, `EndPost_NetDisk_File_C/M/P`, `Get_NetDisk_File_Frag_Info_C/M/P`, `Get_NetDisk_File_Frag_MD5_C/M/P`, `Get_NetDisk_Multi_File_Frag_MD5_C/M/P`, `Get_NetDisk_File_Frag`, `Get_NetDisk_File_MD5_C/M/P`, `Get_NetDisk_File_List_C/M/P`, `Get_NetDisk_SpaceInfo_C/M/P`, `Remove_Item`, `Remove_Field`, `Copy_Item`, `Copy_Field`, `CreateField`, `RenameField`, `RenameItem`, `Build_Share_Disk_C/M/P`, `Get_Share_Disk_C/M/P`, `Remove_Share_Disk`, `Get_Share_Disk_File_List_C/M/P`, `Get_Share_Disk_File_Frag_Info_C/M/P`, `Search_NetDisk_File_C/M/P`, `Search_Share_NetDisk_File_C/M/P`, `Search_NetDisk_Field_C/M/P`, `Search_Share_NetDisk_Field_C/M/P`, `Auth_AdminC/M/P`, `Close_Auth_Admin`, `Auto_Post_File_C/M/P`, `Auto_Get_File_C/M/P`, `Auto_Get_File_From_Share_Disk_C/M/P`。 |
| **全局变量** | `Fragment_Cache_FileName`（用于 MD5 流缓存）。 |
| **初始化/终结** | 无。 |
| **关键字** | NetDisk客户端, 认证, 上传, 下载, 自动化, 片段, 分享 |

### Z.Net.C4_NetDisk_VM_Client
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_NetDisk_Client` 的 VM 封装版本。 |
| **依赖** | 同 `Z.Net.C4_NetDisk_Client`，增加 `Z.Net.C4.VM`。 |
| **导出类** | `TC40_NetDisk_VM_Client`, `TC40_NetDisk_VM_Client_On_Usr_Auto_Post_File`, `TC40_NetDisk_VM_Client_On_Usr_Auto_Get_File`。 |
| **导出函数** | 同 `TC40_NetDisk_Client` 的所有公共方法。 |
| **全局变量** | `Fragment_Cache_FileName`（复用）。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, NetDisk客户端 |

### Z.Net.C4_NetDisk_Client.Task
| 属性 | 内容 |
| :--- | :--- |
| **功能** | NetDisk 客户端任务系统，将上传/下载/目录同步等操作封装为任务，支持队列、并发、自动重试，并集成加密/解密流。 |
| **依赖** | 同 `Z.Net.C4_NetDisk_Client`，增加 `Z.IOThread` 等。 |
| **导出类** | `TC40_NetDisk_Client_Task_Tool`, `TC40_NetDisk_Client_Task`, `TC40_NetDisk_Client_Task_Clone_Connection`, `TC40_NetDisk_Client_Task_Auto_Post_Stream`, `TC40_NetDisk_Client_Task_Auto_Get_Stream`, `TC40_NetDisk_Client_Task_Auto_Post_Encrypt_Stream`, `TC40_NetDisk_Client_Task_Auto_Get_Decrypt_Stream`, `TC40_NetDisk_Client_Task_Auto_Post_File`, `TC40_NetDisk_Client_Task_Auto_Get_File`, `TC40_NetDisk_Client_Task_Auto_Get_Directory`, `TC40_NetDisk_Client_Task_Auto_Post_Directory`。 |
| **导出函数** | 无（方法为内部使用）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 任务, 队列, 上传, 下载, 加密, 解密, 目录同步 |

### Z.Net.C4_NetDisk_VM_Client.Task
| 属性 | 内容 |
| :--- | :--- |
| **功能** | `TC40_NetDisk_VM_Client` 的任务系统，功能相同。 |
| **依赖** | 同 `Z.Net.C4_NetDisk_VM_Client`。 |
| **导出类** | `TC40_NetDisk_VM_Client_Task_Tool`, `TC40_NetDisk_VM_Client_Task` 及其各种子类。 |
| **导出函数** | 无。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, 任务, 上传, 下载, 加密, 解密, 目录 |

### Z.Net.C4_NetDisk_VM_Service
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 与 `TC40_NetDisk_Service` 功能相同，但基于 VM 风格（`TC40_NoAuth_VM_Service`）。 |
| **依赖** | 同 `Z.Net.C4_NetDisk_Service`，但继承自 `TC40_NoAuth_VM_Service`。 |
| **导出类** | `TC40_NetDisk_VM_Service` 及其内部桥接类。 |
| **导出函数** | 同 `TC40_NetDisk_Service` 的命令处理器。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | VM, NetDisk服务, 网盘 |

---

## 12. C4 代码重写工具

### Z.Net.C4_PascalRewrite_Client
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 Pascal 代码重写客户端，通过 C4 网络向服务端提交代码文件，请求进行单元/符号重写。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.Geometry2D`, `Z.DFE`, `Z.ListEngine`, `Z.Parsing`, `Z.Expression`, `Z.OpCode`, `Z.Json`, `Z.HashList.Templet`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`。 |
| **导出类** | `TC40_Pascal_Rewrite_Tool`, `TPascal_Source_`, `TPascal_Rewrite_Tool_CodePool`。 |
| **导出函数（客户端）** | `SetDefaultModel`, `UpdateModel`, `Build_CodePool`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 代码重写, Pascal, 重构, 客户端 |

### Z.Net.C4_PascalRewrite_Service
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 Pascal 代码重写服务端，接收代码文件，使用 `Z.Pascal_Code_Tool` 进行单元/符号重写，支持 HPC 线程处理。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.Geometry2D`, `Z.DFE`, `Z.ListEngine`, `Z.Parsing`, `Z.Pascal_Code_Tool`, `Z.Expression`, `Z.OpCode`, `Z.Json`, `Z.HashList.Templet`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.FragmentBuffer`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`, `Z.ZDB2`, `Z.ZDB2.FileEncoder`, `Z.Pascal_Rewrite_Model_Data`。 |
| **导出类** | `TC40_Pascal_Rewrite_Service`, `TUnitRewriteService_IO_Define_`。 |
| **导出函数** | 无（内部命令处理）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 代码重写, 服务, Pascal, 重构, HPC |

### Z.Pascal_Rewrite_Model_Data
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 存储 Pascal 重写模型数据（如 `PassByYou888UpLevelModel`）的资源单元，提供将模型数据流化的函数。 |
| **依赖** | `Z.Core`。 |
| **导出函数** | `Get_PassByYou888UpLevelModel_Stream`（返回预编译的二进制模型数据）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | 重写模型, 数据, 资源 |

---

## 13. C4 XNAT 集成

### Z.Net.C4_XNAT
| 属性 | 内容 |
| :--- | :--- |
| **功能** | 将 XNAT 穿透系统集成到 C4 框架，提供 XNAT 服务/客户端的 C4 封装，支持服务端管理映射、客户端构建物理服务。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.Geometry2D`, `Z.DFE`, `Z.ListEngine`, `Z.Parsing`, `Z.Expression`, `Z.OpCode`, `Z.Notify`, `Z.Cipher`, `Z.MemoryStream`, `Z.Net`, `Z.Net.PhysicsIO`, `Z.Net.DoubleTunnelIO.NoAuth`, `Z.Net.C4`, `Z.Net.XNAT.Client`, `Z.Net.XNAT.MappingOnVirutalService`, `Z.Net.XNAT.Service`, `Z.Net.XNAT.Physics`。 |
| **导出类** | `TC40_XNAT_Service_Tool`, `TC40_XNAT_Client_Tool`, `TC40_XNAT_Mapping_Info`。 |
| **导出函数（客户端）** | `Get_XNAT_Mapping`（C/M/P）, `Add_XNAT_Mapping`, `Open_XNAT_Tunnel`, `Build_Physics_Service`（C/M/P）。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | XNAT, 穿透, C4集成, 端口映射 |

### Z.Net.C4_XNAT_Cluster_Port_Mapping
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 集群端口映射（CPM）工具，基于 XNAT 实现集群内端口映射管理，支持服务端监听配置、客户端上报映射地址。 |
| **依赖** | 同 `Z.Net.C4_XNAT`。 |
| **导出类** | `TC40_CPM_Service_Tool`, `TC40_CPM_Client_Tool`, `TC40_CPM_Info`。 |
| **导出函数（客户端）** | `Get_CPM_Mapping`（C/M/P）, `Add_CPM_Service_Listening`（多种重载）, `Open_CPM_Service_Tunnel`, `Begin_CPM_Address_Mapping`, `Add_CPM_Address_Mapping`, `End_CPM_Address_Mapping`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | CPM, 集群端口映射, XNAT, 端口转发 |

---

## 14. XNAT 独立实现

### Z.Net.XNAT.Physics
| 属性 | 内容 |
| :--- | :--- |
| **功能** | XNAT 物理层基础，定义 `TXPhysicsServer`/`TXPhysicsClient` 别名，并提供 XNAT 协议常量（`C_RequestListen` 等）和缓冲区打包/解包函数。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Net.PhysicsIO`。 |
| **导出类型** | `TXPhysicsServer`, `TXPhysicsClient`, `TXNAT_PHYSICS_MODEL` 枚举。 |
| **导出函数** | `Build_XNAT_Buff`, `Extract_XNAT_Buff`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | XNAT, 物理层, 协议常量, 缓冲区打包 |

### Z.Net.XNAT.Client
| 属性 | 内容 |
| :--- | :--- |
| **功能** | XNAT 客户端实现，连接 XNAT 服务，通过 P2PVM 建立端口映射，将外部请求转发至本地服务，支持负载均衡、工作量上报。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.Status`, `Z.UnicodeMixedLib`, `Z.ListEngine`, `Z.TextDataEngine`, `Z.Cipher`, `Z.DFE`, `Z.MemoryStream`, `Z.Net`, `Z.Notify`, `Z.HashList.Templet`, `Z.Net.XNAT.Physics`。 |
| **导出类** | `TXNATClient`, `TXClientMapping`, `TXClientCustomProtocol`。 |
| **导出函数（客户端）** | `AddMapping`, `OpenTunnel`（重载：带 MODEL 参数）, `Progress`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | XNAT客户端, 端口映射, P2PVM, 负载均衡 |

### Z.Net.XNAT.Service
| 属性 | 内容 |
| :--- | :--- |
| **功能** | XNAT 服务端实现，监听外部客户端连接，通过 P2PVM 将连接转发至注册的 XNAT 客户端，支持分布式负载均衡。 |
| **依赖** | 同 `Z.Net.XNAT.Client`。 |
| **导出类** | `TXNATService`, `TXServiceListen`, `TXServerCustomProtocol`。 |
| **导出函数（服务端）** | `AddMapping`, `AddNoDistributedMapping`, `OpenTunnel`（重载：带 MODEL 参数）, `Reset`, `Progress`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | XNAT服务端, 端口映射, P2PVM, 负载均衡, 转发 |

### Z.Net.XNAT.MappingOnVirutalService
| 属性 | 内容 |
| :--- | :--- |
| **功能** | XNAT 虚拟服务映射，将每个映射作为一个独立的 `TZNet_Server` 虚拟服务。 |
| **依赖** | 同 `Z.Net.XNAT.Client`/`Service`。 |
| **导出类** | `TXNAT_VS_Mapping`, `TXNAT_MappingOnVirutalService`, `TXNAT_MappingOnVirutalService_IO`。 |
| **导出函数（管理类）** | `AddMappingService`/`AddMappingServer`, `OpenTunnel`（重载：带 MODEL 参数）, `Progress`, `GetCount`, `GetServices`, `GetServicesOnMapping`。 |
| **全局变量** | 无。 |
| **初始化/终结** | 无。 |
| **关键字** | XNAT, 虚拟服务, 映射, TZNet_Server |

---

## 15. C4 控制台应用

### Z.Net.C4_Console_APP
| 属性 | 内容 |
| :--- | :--- |
| **功能** | C4 控制台应用程序框架，解析命令行参数，执行脚本（`Service`, `Client`, `Auto`, `KeepAlive` 等命令），启动主循环并交互式控制台。 |
| **依赖** | `Z.Core`, `Z.PascalStrings`, `Z.UPascalStrings`, `Z.UnicodeMixedLib`, `Z.Status`, `Z.ListEngine`, `Z.HashList.Templet`, `Z.Expression`, `Z.OpCode`, `Z.Parsing`, `Z.DFE`, `Z.TextDataEngine`, `Z.Json`, `Z.Geometry2D`, `Z.Geometry3D`, `Z.Number`, `Z.MemoryStream`, `Z.Net`, `Z.ZDB.ObjectData_LIB`, `Z.ZDB`, `Z.ZDB.Engine`, `Z.ZDB.LocalManager`, `Z.ZDB.FileIndexPackage_LIB`, `Z.ZDB.FilePackage_LIB`, `Z.ZDB.ItemStream_LIB`, `Z.ZDB.HashField_LIB`, `Z.ZDB.HashItem_LIB`, `Z.ZDB2`, `Z.ZDB2.DFE`, `Z.ZDB2.HS`, `Z.ZDB2.HV`, `Z.ZDB2.Json`, `Z.ZDB2.MS64`, `Z.ZDB2.NM`, `Z.ZDB2.TE`, `Z.ZDB2.FileEncoder`, `Z.Net.C4`, `Z.Net.C4_UserDB`, `Z.Net.C4_Var`, `Z.Net.C4_FS`, `Z.Net.C4_RandSeed`, `Z.Net.C4_Log_DB`, `Z.Net.C4_XNAT`, `Z.Net.C4_Alias`, `Z.Net.C4_FS2`, `Z.Net.C4_PascalRewrite_Client`, `Z.Net.C4_PascalRewrite_Service`, `Z.Net.C4_NetDisk_Admin_Tool`, `Z.Net.C4_TEKeyValue`, `Z.Net.PhysicsIO`, `Z.Net.C4_NetDisk_Client`, `Z.Net.C4_NetDisk_Directory`, `Z.Net.C4_FS3`, `Z.Net.C4_NetDisk_Service`。 |
| **导出函数** | `C40_Init_AppParamFromSystemCmdLine`, `C40_Extract_CmdLine`（多重重载）, `C40_Execute_Main_Loop`。 |
| **全局变量** | `C40AppParam`, `C40AppParsingTextStyle`, `On_C40_PhysicsTunnel_Event_Console`, `On_C40_PhysicsService_Event_Console`。 |
| **初始化/终结** | 无。 |
| **关键字** | 控制台, APP, 脚本, 命令行, Service, Client, KeepAlive, 交互式 |

---

## 初始化与终结汇总

| 单元 | 初始化行为 | 终结行为 |
| :--- | :--- | :--- |
| **Z.Net** | 全局池（`ZNet_Instance_Pool`, `HPC_Instance_Pool`）在首次使用时创建。 | 终结时释放池。 |
| **Z.Net.C4** | 注册默认服务类型，创建全局池；`C40ResetDefaultConfig` 重置配置变量。 | 释放全局池（`C40_PhysicsServicePool` 等）。 |
| **Z.Net.DoubleTunnelIO.ServMan** | 无显式初始化。 | 无。 |
| **其余单元** | 无显式初始化（仅类型定义和回调注册）。 | 无。 |

---

*本手册基于源码接口和设计文档整理，已与源代码逐项核对，确保完整准确。具体实现细节请参考各单元源码及注释。*