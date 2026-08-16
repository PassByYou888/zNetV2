# Z.Net.C4_Console_APP 白皮书

**C4 控制台应用框架**  
**版本**：1.0  
**发布日期**：2026年8月  

---

## 1. 概述

`Z.Net.C4_Console_APP` 是 Cloud 4.0 (C4) 分布式服务框架的命令行与脚本驱动入口模块。它提供了一套**轻量级、可编程的部署工具**，允许用户通过简单的表达式脚本或命令行参数，快速启动 C4 服务端和客户端，并集成交互式控制台进行运行时管理与诊断。

该模块专为以下场景设计：

- **服务器集群自动化部署**：通过 Shell 脚本或系统服务管理器（如 systemd）启动多个 C4 节点。
- **嵌入式与 IoT 设备**：在资源受限的环境下，以最小的配置启动 C4 网络。
- **开发与测试**：快速搭建本地 C4 测试环境，验证服务间通信。
- **系统运维控制台**：提供交互式命令行界面，实时查看服务状态、执行诊断命令。

其核心设计理念是**将复杂的 C4 拓扑配置简化为声明式脚本**，无需编写 Pascal 代码即可构建完整的分布式系统。

---

## 2. 架构与工作原理

### 2.1 整体流程

系统启动时，按以下顺序执行：

1. **参数提取**：`C40_Init_AppParamFromSystemCmdLine` 将系统命令行参数复制到全局数组 `C40AppParam`。
2. **参数解析**：`C40_Extract_CmdLine` 创建 `TCommand_Script` 实例，循环遍历 `C40AppParam` 中的每个表达式，交由脚本引擎 `opRT` 求值。
3. **命令执行**：脚本引擎识别 `Service`、`Client`、`Auto`、`KeepAlive` 等命令，将其参数存储到内部列表。
4. **网络构建**：所有脚本执行完毕后，根据列表中存储的信息，创建 `TC40_PhysicsService`（服务端）或 `TC40_PhysicsTunnel`（客户端）实例，并调用相应方法启动网络。
5. **主循环**：`C40_Execute_Main_Loop` 启动主循环，主线程持续调用 `C40Progress` 驱动网络 I/O，同时启动一个后台控制台线程读取用户输入，调用 `TC40_Console_Help` 执行诊断命令。
6. **退出**：控制台输入 `exit` 时，后台线程退出，主循环结束。

### 2.2 核心组件

- **C40AppParam**：全局数组，存储从系统命令行（或用户提供）的参数字符串。
- **C40AppParsingTextStyle**：脚本解析的文本样式（Pascal、C 等），默认为 `tsPascal`。
- **TCommand_Script**：内部类，负责注册脚本命令、解析表达式、收集服务/客户端配置。
- **TC40_Console_Help**：交互式控制台，提供丰富的诊断命令（服务信息、隧道状态、线程池、ZDB2 等）。
- **主循环**：`C40_Execute_Main_Loop` 启动一个后台线程读取用户输入，同时主线程持续调用 `C40Progress` 驱动网络。

### 2.3 脚本引擎

脚本引擎基于 `TOpCustomRunTime`（表达式运行时），支持：
- **变量赋值**：如 `Root('/var/c4/')`，修改全局配置。
- **命令调用**：如 `Service('0.0.0.0','127.0.0.1',8008,'DP')`。
- **复合表达式**：多个命令可在同一参数字符串中用逗号分隔（Windows 命令行）或分行（Linux）。

---

## 3. 脚本命令参考

所有命令均以函数形式调用，参数类型如下：
- **字符串**：使用单引号或双引号，如 `'127.0.0.1'`。
- **整数**：直接数字，如 `8008`。
- **布尔**：`True`/`False` 或 `1`/`0`。

### 3.1 服务端命令

| 命令 | 别名 | 参数 | 说明 |
|------|------|------|------|
| `Service` | `Server`, `Serv`, `Listen`, `Listening` | `( listen_ip, local_ip, port, depend )` 或 `( local_ip, port, depend )` | 创建并启动一个物理服务。若只提供 3 个参数，`listen_ip` 自动根据 `local_ip` 的 IPv4/IPv6/IPC 特性设置为 `0.0.0.0`、`::` 或原值。`depend` 为依赖服务类型字符串。 |

**示例**：
```c4
Service('0.0.0.0', '192.168.1.100', 8008, 'DP|<>UserDB@SafeCheckTime=10000')
Service('127.0.0.1', 9898, 'NA')   // listen_ip 自动设为 '0.0.0.0'
```

---

### 3.2 客户端命令

| 命令 | 别名 | 参数 | 说明 |
|------|------|------|------|
| `Client` | `Cli`, `Tunnel`, `Connect`, `Connection`, `Net`, `Build` | `( ip, port, depend )` | 简单连接，失败后不自动重试。 |
| `Auto` | `AutoClient`, `AutoCli`, `AutoTunnel`, `AutoConnect`, `AutoConnection`, `AutoNet`, `AutoBuild` | `( ip, port, depend [, Min_Workload ] )` | 通过 DP 发现机制自动选择匹配的服务实例。`Min_Workload`（默认 `False`）为 `True` 时选择负载最小的实例。需要网络中已有 DP 服务。 |
| `KeepAlive` | `KeepAliveClient`, `KeepAliveCli`, `KeepAliveTunnel`, `KeepAliveConnect`, `KeepAliveConnection`, `KeepAliveNet`, `KeepAliveBuild` | `( ip, port, depend [, Min_Workload ] )` | 类似 `Auto`，但会持续重试直到连接成功，并在断开后自动重连。自动启用 `Auto_Repair_First_BuildDependNetwork_Fault`。适合部署场景。 |

**示例**：
```c4
Client('192.168.1.100', 8008, 'NA')
Auto('192.168.1.100', 8008, 'DP|<>UserDB', True)   // 选择负载最小的服务
KeepAlive('192.168.1.100', 8008, 'APIHub')
```

---

### 3.3 工具命令

| 命令 | 别名 | 参数 | 说明 |
|------|------|------|------|
| `Wait` | `Sleep` | `( milliseconds )` | 暂停脚本执行指定的毫秒数，用于控制启动顺序。 |
| `Quiet` | `SetQuiet` | `( Boolean )` | 启用/关闭安静模式（抑制大部分日志输出）。 |
| `Title` | - | `( string )` | 设置窗口标题（仅 GUI 模式）。 |
| `AppTitle` | - | `( string )` | 设置应用程序标题（仅 GUI 模式）。 |
| `DisableUI` | - | `( string )` | 禁用 UI 交互（仅 GUI 模式）。 |
| `Timer` | - | `( milliseconds )` | 设置 GUI 主循环定时器间隔。 |

---

### 3.4 配置变量

这些变量可像普通赋值一样设置，影响全局 C4 行为。例如：`Root('/var/c4/')`。

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `Root` | 字符串 | 可执行文件所在目录 | C4 数据文件的根目录。 |
| `Password` | 字符串 | `'DTC40@ZSERVER'` | P2PVM 和 C4 网络认证密码。 |
| `SafeCheckTime` | 整数（毫秒） | `45000` | 服务 `SafeCheck` 周期性检查间隔。 |
| `PhysicsReconnectionDelayTime` | 浮点数（秒） | `5.0` | 物理隧道断线后的重连延迟。 |
| `UpdateServiceInfoDelayTime` | 整数（毫秒） | `1000` | Dispatch 服务广播信息延迟。 |
| `PhysicsServiceTimeout` | 整数（毫秒） | `900000`（15分钟） | 物理服务空闲超时。 |
| `PhysicsTunnelTimeout` | 整数（毫秒） | `900000`（15分钟） | 物理隧道空闲超时。 |
| `KillIDCFaultTimeout` | 整数（毫秒） | `604800000`（7天） | 断线客户端的 IDC 故障清理超时。 |

---

### 3.5 依赖字符串语法

`depend` 参数是一个字符串，用于指定需要构建的服务类型及其参数。格式：
```
Type1@Param1|<>Type2@Param2
```
- 使用 `|<>` 分隔多个依赖。
- 每个依赖由 `Type`（必需）和可选的 `@Param`（键值对字符串，如 `SafeCheckTime=60000`）组成。

---

## 4. 使用示例

### 4.1 单机测试环境

启动一个 DP 服务和一个客户端：
```
# Windows 命令行
C4.exe "Service('127.0.0.1', 9898, 'DP')" "Client('127.0.0.1', 9898, 'DP')"

# Linux shell
./C4 "Service('127.0.0.1', 9898, 'DP')" "Client('127.0.0.1', 9898, 'DP')"
```

### 4.2 生产环境部署

假设有两台服务器：`192.168.1.10`（运行 DP + UserDB）和 `192.168.1.20`（作为客户端集群）。

**服务器 10 启动脚本**：
```
Root('/data/c4/')
Password('MySecurePwd')
SafeCheckTime(30000)
Service('0.0.0.0', '192.168.1.10', 8008, 'DP|<>UserDB@SafeCheckTime=10000')
```

**服务器 20 客户端脚本**：
```
Root('/data/c4/')
KeepAlive('192.168.1.10', 8008, 'DP|<>UserDB')
Wait(5000)
Auto('192.168.1.10', 8008, 'APIHub', True)
```

### 4.3 结合控制台交互

当使用 `C40_Execute_Main_Loop` 启动主循环后，用户可以在终端输入命令进行实时诊断，例如：
- `service`：查看所有物理服务状态。
- `tunnel`：查看所有物理隧道状态。
- `HPC_Thread_Info`：查看线程池信息。
- `ZDB2_Info`：查看存储引擎状态。

---

## 5. 内部实现概览

### 5.1 TCommand_Script

- 继承自 `TCore_Object_Intermediate`，包含：
  - `opRT`：表达式运行时，注册所有命令。
  - `Config`：存储解析到的配置变量。
  - `Client_NetInfo_List` 和 `Service_NetInfo_List`：保存解析出的客户端和服务端信息。
- `RegApi` 方法注册所有命令，包括配置变量（通过 `Do_Config` 通用处理器）和功能命令。
- `Execute` 方法将输入的表达式提交给运行时求值。

### 5.2 解析流程

1. `C40_Extract_CmdLine` 创建 `TCommand_Script` 实例。
2. 依次遍历 `C40AppParam` 数组，跳过被 `Ignore_Command_Line` 过滤的参数。
3. 调用 `cmd_script_.Execute` 解析每个表达式。
4. 执行过程中，`Service`、`Client` 等命令会将配置填入相应的列表。
5. 脚本执行完毕后，根据列表创建 `TC40_PhysicsService` 和 `TC40_PhysicsTunnel` 实例。
6. 若有客户端且 `KeepAlive` 标记为真，自动启用 `Auto_Repair_First_BuildDependNetwork_Fault`。

### 5.3 主循环与控制台

`C40_Execute_Main_Loop` 创建一个 `TMain_Loop_Instance__`，它在后台线程中持续读取控制台输入，并传递给 `TC40_Console_Help.Run_HelpCmd`。主线程则不断调用 `C40Progress` 驱动网络。用户输入 `exit` 后，控制台线程退出，主循环结束。

---

## 6. 与 C4 框架的关系

`Z.Net.C4_Console_APP` 是 C4 框架的**应用层入口**，它依赖于：
- `Z.Net.C4`：核心框架（物理服务/隧道、服务信息、Dispatch 等）。
- `Z.Net.C4_UserDB`, `Z.Net.C4_Var`, `Z.Net.C4_FS` 等：内置服务实现。
- `Z.Expression`, `Z.OpCode`：脚本引擎。

它不直接参与服务间通信，而是负责**解析用户意图，实例化 C4 组件**，并提供运行时控制台。

---

## 7. 扩展与定制

开发者可以通过以下方式扩展该模块的功能：

- **注册新的配置变量**：在 `TCommand_Script.RegApi` 中为 `Config` 添加新的键。
- **添加新的脚本命令**：定义新的处理方法（如 `Do_MyCommand`），并在 `RegApi` 中通过 `opRT.Reg_Param_OpM` 注册。
- **替换事件处理**：通过 `On_C40_PhysicsTunnel_Event_Console` 和 `On_C40_PhysicsService_Event_Console` 全局变量，注入自定义事件处理器。
- **自定义命令行过滤**：修改 `Ignore_Command_Line` 列表，跳过特定参数。

---

## 8. 总结

`Z.Net.C4_Console_APP` 为 Cloud 4.0 框架提供了一个**灵活、强大、易用的命令行和脚本化部署工具**。它将复杂的分布式系统配置转化为简单的声明式脚本，大大降低了 C4 的入门门槛，同时提供了交互式控制台满足运维监控需求。无论是在开发测试、生产部署还是边缘计算场景，该模块都能显著提升效率，是 C4 生态系统中不可或缺的组成部分。

---

*本白皮书基于 `Z.Net.C4_Console_APP.pas` 源代码及 C4 框架整体设计撰写。*