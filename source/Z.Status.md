# Z.Status 完全使用指南：从基础日志到高级调试

Z.Status 是 Z‑framework 的线程安全状态/日志子系统。它提供了一个集中式的消息队列和灵活的钩子机制，让你可以在任何线程中发出状态消息，并由主线程（或任意线程）异步（或同步）处理。它内置了控制台输出、无换行累积、内存转储、字符串列表输出等实用功能，是调试、监控和日常日志记录的得力助手。

---

## 1. Z.Status 解决什么问题？

在多线程应用中，直接使用 `WriteLn` 或 `OutputDebugString` 会带来两个问题：
- **线程安全问题**：多个线程同时写入控制台会导致输出混乱。
- **主线程 UI 更新问题**：从工作线程直接更新 UI 控件会引发异常。

Z.Status 通过一个**线程安全的队列**将消息从任意线程收集起来，然后由主线程（或通过钩子）统一分发。你可以：
- 注册自己的处理函数（钩子），将消息发送到日志文件、数据库、调试器或 UI 控件。
- 控制输出是否显示在控制台上。
- 构建多行消息而不产生额外的换行符。
- 以十六进制格式转储内存块。
- 打印包含对象信息的字符串列表。

---

## 2. 核心概念

### 2.1 DoStatus —— 发出消息
所有输出的入口函数是 `DoStatus`。它接受一个字符串（或各种重载）和一个可选的整数标识符（ID）。ID 可用于消息分类（如错误级别、模块编号）。

### 2.2 钩子（Hook）—— 自定义消息处理
你可以注册一个或多个钩子函数，它们会在每条消息被分发时被调用。支持三种回调风格：
- **C**（procedure）— 独立过程或类静态方法。
- **M**（method）— 对象方法。
- **P**（nested/reference）— 嵌套过程或匿名方法，可以捕获外部上下文。

钩子会在调用线程（通常是主线程）中执行，因此可以安全地更新 UI 或访问非线程安全的资源。

### 2.3 消息队列与异步分发
所有 `DoStatus` 调用都会将消息放入一个内部队列。默认的 `OnDoStatusHook`（即 `InternalDoStatus`）将消息入队，然后如果调用线程是主线程则立即处理队列；否则消息会在主线程的同步检查点（由 `Z.Core.OnCheckThreadSynchronize` 触发）被处理。这样保证了消息的异步性，同时避免阻塞工作线程。

### 2.4 控制台输出
如果 `ConsoleOutput` 变量为 `True`（默认），消息也会被写入控制台（使用 `WriteLn`）。在 Windows 下，它会使用 `WriteConsoleW` 来正确处理 Unicode。

### 2.5 无换行累积（DoStatusNoLn）
你可以连续调用 `DoStatusNoLn` 来累积文本，直到遇到换行符（`#13` 或 `#10`），此时累积的文本会作为完整行被发出。这有助于构建进度条或逐字输出的日志。

---

## 3. 基本用法：最简单的日志

```pascal
uses Z.Status;

begin
  DoStatus('Hello, world!');
  DoStatus('This is a message with ID', 1001);
end.
```

输出（假设控制台启用）：
```
[1234] Hello, world!
[1234] This is a message with ID
```
（其中 `[1234]` 是线程 ID，如果 `StatusThreadID=True`）

---

## 4. 配置输出

### 4.1 启用/禁用控制台输出
```pascal
ConsoleOutput := True;   // 启用（默认）
ConsoleOutput := False;  // 禁用控制台输出，仅通过钩子处理
```

### 4.2 启用/禁用全局状态输出
你可以暂时禁止所有输出（包括钩子和控制台），但队列仍会累积消息：
```pascal
DisableStatus;          // 禁止分发
// ... 在此期间发出的消息不会被分发
EnabledStatus;          // 恢复分发，队列中的消息将立即或在下一次检查时被处理
```

检查当前状态：
```pascal
if Is_EnabledStatus then ... else ...
if Is_DisableStatus then ...
```

### 4.3 控制线程 ID 显示
```pascal
StatusThreadID := False;  // 不显示线程 ID
StatusThreadID := True;   // 显示线程 ID（默认）
```

### 4.4 设置每步处理的消息数量限制
```pascal
One_Step_Status_Limit := 50;  // 默认 20
```
该值决定 `CheckDoStatus` 一次最多处理多少条消息，防止主线程被大量消息阻塞。

---

## 5. 自定义消息处理：钩子（Hooks）

你可以注册自己的处理函数来将消息输出到任意目标（日志文件、数据库、备忘录等）。

### 5.1 添加方法钩子（M 风格）
```pascal
type
  TMyLogger = class
    procedure LogToMemo(Text_: SystemString; const ID: Integer);
  end;

procedure TMyLogger.LogToMemo(Text_: SystemString; const ID: Integer);
begin
  Form1.Memo1.Lines.Add(Format('[%d] %s', [ID, Text_]));
end;

// 注册
var
  Logger: TMyLogger;
begin
  Logger := TMyLogger.Create;
  AddDoStatusHookM(Logger, Logger.LogToMemo);
```

### 5.2 添加过程钩子（C 风格）
```pascal
procedure MyFileLogger(Text_: SystemString; const ID: Integer);
var
  F: TextFile;
begin
  AssignFile(F, 'log.txt');
  Append(F);
  WriteLn(F, Format('[%d] %s', [ID, Text_]));
  CloseFile(F);
end;

// 注册
AddDoStatusHookC(Self, MyFileLogger);
```

### 5.3 添加嵌套/匿名钩子（P 风格）
```pascal
AddDoStatusHookP(Self,
  procedure(Text_: SystemString; const ID: Integer)
  begin
    // 捕获外部变量
    if ID > 0 then
      WriteLn('Error: ' + Text_)
    else
      WriteLn('Info: ' + Text_);
  end
);
```

### 5.4 删除钩子
使用注册时提供的 TokenObj 来移除：
```pascal
DeleteDoStatusHook(Logger);   // 或 RemoveDoStatusHook
```
所有使用该 Token 注册的钩子都会被移除。

---

## 6. 队列管理与手动处理

### 6.1 处理消息队列（CheckDoStatus）
通常消息会在主线程的同步钩子中自动处理，但你也可以手动调用：
```pascal
CheckDoStatus;   // 处理最多 One_Step_Status_Limit 条消息
```

### 6.2 等待队列清空
```pascal
Wait_DoStatus_Queue;  // 忙等直到队列为空（每 10ms 检查一次）
```
这在程序关闭或需要确保所有消息都已被处理时有用。

### 6.3 取出并处理单条消息
```pascal
var
  S: TPascalString;
begin
  if Pick_One_Status(S) then
    DoStatus('Processed: ' + S.Text);
end;
```

### 6.4 将队列中的所有消息转移到字符串列表
```pascal
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    Pick_State_To(SL);
    // SL 现在包含所有未处理的消息
  finally
    SL.Free;
  end;
end;
```

---

## 7. 无换行输出（DoStatusNoLn）

### 7.1 构建单行进度条
```pascal
DoStatusNoLn('Processing: ');
for i := 1 to 100 do
begin
  DoStatusNoLn('.');
  if i mod 10 = 0 then
    DoStatusNoLn(' ' + IntToStr(i) + '%' + #13#10);  // 换行并刷新
end;
DoStatusNoLn(#13#10);  // 强制换行
```
输出：
```
Processing: .......... 10%
.................... 20%
...
```

### 7.2 强制刷新缓冲区
```pascal
DoStatusNoLn('Partial line');  // 尚未换行
// ... 稍后
DoStatusNoLn;   // 强制将累积内容作为一行输出
```

### 7.3 格式化无换行输出
```pascal
DoStatusNoLn('Value = %d, Name = %s', [123, 'test']);
```

---

## 8. 高级功能：内存转储、对象列表等

### 8.1 十六进制内存转储
```pascal
var
  Buffer: array[0..63] of Byte;
begin
  // 填充 Buffer...
  DoStatus(@Buffer, 64, 16);   // 每行16字节
end;
```
输出示例：
```
00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F
10 11 12 13 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F
...
```

带前缀：
```pascal
DoStatus('Data: ', @Buffer, 64, 16);
```

### 8.2 输出字符串列表（包含对象信息）
```pascal
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  SL.AddObject('Item1', TObject.Create);
  SL.AddObject('Item2', TObject.Create);
  DoStatus(SL);   // 输出 "Item1<TObject>" 等
  SL.Free;
end;
```

### 8.3 输出常见类型
```pascal
DoStatus(123);                 // 整数
DoStatus(3.1415);              // 浮点数
DoStatus(@SomeVar);            // 指针地址（0x...）
DoStatus(MyMD5Digest);         // MD5 摘要（十六进制）
DoStatus(@Buffer, 16);         // 任意内存块（十六进制字符串，无换行）
```

### 8.4 格式化输出
```pascal
DoStatus('Current time: %s, value: %d', [DateTimeToStr(Now), 42]);
```
如果格式化失败（例如参数不匹配），会输出原始格式字符串并附带错误提示。

### 8.5 拼接多个字符串
```pascal
DoStatus('Hello', ' ', 'World');   // 输出 "Hello World"
```

---

## 9. 与 Z.Core 的协同工作

### 9.1 自动挂钩
Z.Status 在初始化时替换了 `Z.Core.OnCheckThreadSynchronize`，使得每次主线程检查同步（例如 `CheckThread` 或 `Check_Soft_Thread_Synchronize`）时都会自动调用 `CheckDoStatus`。这意味着如果你使用了 Z.Core 的线程池或软同步，消息队列会自动被处理，无需额外代码。

### 9.2 异常捕获
`InternalDoStatus` 会捕获所有钩子中的异常，避免因日志处理错误导致程序崩溃。你也可以通过替换 `On_Raise_Info` 来接收这些异常信息（默认由 Z.Status 处理）。

### 9.3 线程安全
所有内部队列操作都由 `Status_Critical__` 保护，因此你可以在任何线程中安全地调用 `DoStatus`。

---

## 10. 性能与最佳实践

### 10.1 避免在性能关键路径上使用过多消息
虽然 `DoStatus` 本身很快，但大量消息会导致队列膨胀和处理开销。对于高频日志，建议使用批量输出或仅在调试模式下启用。

### 10.2 合理设置 `One_Step_Status_Limit`
如果消息量很大，可以调高该值以加快清空速度，但注意不要阻塞主线程太久。

### 10.3 使用 `DoStatusNoLn` 减少换行开销
频繁的换行会导致多次队列操作，使用 `DoStatusNoLn` 累积文本再一次性输出更高效。

### 10.4 及时删除不必要的钩子
如果某个组件不再需要日志处理，请调用 `DeleteDoStatusHook` 避免钩子引用失效导致访问违规。

### 10.5 在程序退出前等待队列清空
```pascal
DisableStatus;                // 停止新消息入队？
Wait_DoStatus_Queue;          // 等待处理完现有消息
// 然后释放资源
```
注意：`DisableStatus` 会阻止新消息分发，但不会阻止入队。若想彻底清空，可先调用 `Wait_DoStatus_Queue`，然后关闭程序。

---

## 11. 调试与故障排除

### 11.1 查看最后一条消息
```pascal
WriteLn(LastDoStatus);   // 保存了最后被分发的消息
```

### 11.2 检查队列大小
```pascal
Writeln('Queue count: ', Get_DoStatus_Queue_Num);
```

### 11.3 强制同步处理（阻塞调用者）
若想立即处理队列并等待完成，可以在主线程中调用 `CheckDoStatus`，但在工作线程中无法强制主线程立即处理。可以考虑使用 `TCompute.Sync` 将 `CheckDoStatus` 同步到主线程：
```pascal
TCompute.Sync(
  procedure
  begin
    CheckDoStatus;
  end
);
```

### 11.4 钩子中的异常处理
如果某个钩子抛出异常，它会被 `InternalDoStatus` 捕获并忽略，但会触发 `On_Raise_Info`（如果已分配）。你可以通过重写 `On_Raise_Info` 来记录这些异常。

---

## 12. 完整示例：构建一个带文件日志和控制台输出的日志系统

```pascal
program LogDemo;

{$APPTYPE CONSOLE}

uses
  SysUtils, Z.Core, Z.Status;

var
  LogFile: TextFile;

procedure FileLogger(Text_: SystemString; const ID: Integer);
begin
  WriteLn(LogFile, Format('[%d] %s', [ID, Text_]));
  Flush(LogFile);
end;

begin
  // 初始化日志文件
  AssignFile(LogFile, 'app.log');
  Rewrite(LogFile);

  // 添加文件钩子
  AddDoStatusHookC(Self, FileLogger);

  // 控制台输出默认启用，保留
  ConsoleOutput := True;

  // 关闭线程 ID 显示（简洁）
  StatusThreadID := False;

  // 发出测试消息
  DoStatus('Application started');
  DoStatus('Config loaded successfully', 0);
  DoStatus('Warning: low memory', 1);
  DoStatus('Error: connection failed', 2);

  // 模拟无换行输出
  DoStatusNoLn('Progress: ');
  for i := 1 to 5 do
  begin
    Sleep(100);
    DoStatusNoLn('.');
  end;
  DoStatusNoLn(' Done' + #13#10);

  // 强制处理队列（确保所有消息都已写入文件）
  CheckDoStatus;
  Wait_DoStatus_Queue;

  // 清理
  DeleteDoStatusHook(Self);
  CloseFile(LogFile);
end.
```

---

## 13. 总结

Z.Status 提供了一个强大而灵活的日志框架，它：
- **线程安全**：任意线程都可以安全地调用。
- **异步处理**：消息队列避免阻塞工作线程。
- **高度可定制**：支持多种钩子风格，便于集成到各种目标。
- **丰富的输出功能**：内存转储、无换行、格式化等。
- **与 Z.Core 无缝集成**：自动配合 Z.Core 的同步机制。

无论你是构建一个简单的控制台应用，还是复杂的高并发服务器，Z.Status 都能满足你的日志和调试需求。它让你可以专注于业务逻辑，而不必担心日志系统的线程安全和性能问题。

---

*本指南涵盖了 Z.Status 的主要功能和使用场景。更多细节请参考单元源码和 Z-framework 的其它文档。*
