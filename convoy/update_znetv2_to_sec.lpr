program update_znetv2_to_sec;

{-----------------------------------------------------------------------------
  程序名称: update_znetv2_to_sec
  功能描述: 将基于 ZNetV2 主库（Main Library）的 Pascal 项目代码，
            自动迁移为 ZNetV2 副库（Secondary Library）兼容代码。
            副库是主库的精简/独立分支，适用于资源受限或特定场景。
  使用方法: update_znetv2_to_sec.exe "目标项目目录路径"
  示例:     update_znetv2_to_sec.exe "c:\myproject\"
  输出:     扫描并迁移指定目录下所有 Pascal 源文件（.pas, .dpr, .lpr, .pp, .inc）
  原理:     加载 ZNetV2_Secondary_Model 迁移模型，通过词法分析精准替换
            主库特有的标识符、单元引用和 API 调用，使之适配副库接口。
  作者:     PassByYou888
  项目主页: https://github.com/PassByYou888/zNetV2 (主库)
            https://github.com/PassByYou888/zNetV2/tree/main/source/sec (副库)
-----------------------------------------------------------------------------}

{$DEFINE FPC_DELPHI_MODE}
{$I ..\..\Z.Define.inc}

uses
  SysUtils,                     // 系统核心单元，提供文件、日期、命令行等基础功能
  Z.Core,                       // Z框架核心库：线程池、原子操作、高性能容器
  Z.PascalStrings,              // TPascalString 字符串类型（ANSI/系统编码）
  Z.UPascalStrings,             // TUPascalString 字符串类型（Unicode/UTF-16）
  Z.UnicodeMixedLib,            // 多功能工具集：文件操作、MD5、Base64、路径处理等
  Z.Parsing,                    // 词法分析引擎：将 Pascal 源码解析为 Token 流
  Z.MemoryStream,               // 64位内存流，支持大文件处理
  Z.Status,                     // 线程安全日志系统，用于输出运行状态
  Z.Pascal_Code_Tool,           // Pascal 代码重构工具：批量替换标识符、单元引用
  ZNet_To_ZNetV2_Model;         // 升级模型单元（同时提供主→副库迁移模型函数）

 {-----------------------------------------------------------------------------
  过程: DoHelp
  功能: 显示程序帮助信息（中文）
  参数: 无
  返回: 无
  说明: 当用户输入错误参数或请求帮助时，输出详细的使用说明
-----------------------------------------------------------------------------}
procedure DoHelp;
begin
  DoStatus('═══════════════════════════════════════════════════════════════');
  DoStatus('  ZNetV2 主库 → 副库 代码迁移工具 v1.0');
  DoStatus('  功能：将 ZNetV2 主库项目代码自动迁移为副库兼容代码');
  DoStatus('  主库项目：https://github.com/PassByYou888/zNetV2');
  DoStatus('  副库项目：https://github.com/PassByYou888/zNetV2/tree/main/source/sec');
  DoStatus('═══════════════════════════════════════════════════════════════');
  DoStatus('');
  DoStatus('  使用方法：');
  DoStatus('    update_znetv2_to_sec.exe "目标项目目录路径"');
  DoStatus('');
  DoStatus('  示例：');
  DoStatus('    update_znetv2_to_sec.exe "c:\myproject\"');
  DoStatus('    update_znetv2_to_sec.exe "/home/user/myproject/"');
  DoStatus('');
  DoStatus('  支持的文件类型：');
  DoStatus('    .pas  - Pascal 单元文件');
  DoStatus('    .dpr  - Delphi 项目文件');
  DoStatus('    .lpr  - Lazarus 项目文件');
  DoStatus('    .pp   - Free Pascal 源文件');
  DoStatus('    .inc  - 包含文件');
  DoStatus('');
  DoStatus('  迁移内容：');
  DoStatus('    1. 将主库单元引用替换为副库对应的单元名');
  DoStatus('    2. 替换主库特有的类名、函数名和常量');
  DoStatus('    3. 更新 uses 子句中的依赖关系');
  DoStatus('    4. 处理 $INCLUDE、$R 等编译器指令中的文件名');
  DoStatus('    5. 调整部分 API 调用以适配副库接口差异');
  DoStatus('═══════════════════════════════════════════════════════════════');
end;

{-----------------------------------------------------------------------------
  过程: Fill_CMD
  功能: 主执行过程，解析命令行参数并执行代码迁移
  参数: 无（从 ParamStr 读取命令行参数）
  返回: 无（通过 ExitCode 返回执行结果）
  说明:
    1. 检查命令行参数数量是否正确
    2. 验证目标目录是否存在
    3. 加载 ZNetV2 主库→副库迁移模型
    4. 递归扫描并迁移目录下所有 Pascal 源文件
    5. 输出迁移进度和统计信息
-----------------------------------------------------------------------------}
procedure Fill_CMD;
var
  Dir_: U_String;              // 用户指定的目标项目目录路径
  model_stream: TMS64;         // 迁移模型数据流（包含所有映射规则）

  {-----------------------------------------------------------------------------
    嵌套过程: Do_RewriteStatus
    功能: 作为回调函数，接收代码重构过程中的状态信息并输出到控制台
    参数:
      Fmt   - 格式化字符串（类似 Format 的格式）
      Args  - 可变参数数组
    返回: 无
    说明: 该回调会被 Z.Pascal_Code_Tool 在重构每个文件时调用，
          用于实时显示迁移进度
  -----------------------------------------------------------------------------}
  procedure Do_RewriteStatus(const Fmt: SystemString; const Args: array of const);
  begin
    DoStatus(Fmt, Args);       // 通过 Z.Status 输出格式化的状态信息
  end;
begin
  ExitCode := 0;               // 默认成功退出码

  { 检查命令行参数：必须且仅能传入一个参数——目标项目目录路径 }
  if ParamCount <> 1 then
  begin
    DoHelp();                  // 参数错误，显示帮助信息
    Exit;
  end;

  Dir_ := ParamStr(1);         // 获取用户指定的目标目录

  DoStatus('');
  DoStatus('▶ 开始执行 ZNetV2 主库 → 副库 代码迁移...');
  DoStatus('▶ 目标目录: "%s"', [Dir_.Text]);

  { 验证目标目录是否存在 }
  if not umlDirectoryExists(Dir_) then
  begin
    DoStatus('✗ 错误：目录不存在或无法访问 - "%s"', [Dir_.Text]);
    ExitCode := 1;
    Exit;
  end;

  {
    加载迁移模型数据
    模型由 ZNet_To_ZNetV2_Model 单元中的 Get_ZNetV2_Secondary_Model_Stream 提供，
    该模型定义了主库→副库的所有映射规则：
    - 单元重命名映射（UnitData）
    - 标识符/API 替换映射（PatternData）
    - 自定义文件匹配规则（CustomPattern）
  }
  model_stream := TMS64.Create;
  try
    try
      Get_ZNetV2_Secondary_Model_Stream(model_stream);
      model_stream.Position := 0;
      DoStatus('✓ 迁移模型加载成功');
    except
      DoStatus('✗ 错误：迁移模型加载失败');
      ExitCode := 2;
      Exit;
    end;

    DoStatus('▶ 开始扫描并迁移源代码文件...');
    DoStatus('─────────────────────────────────────────────────────────────');

    {
      调用 Pascal 代码重构引擎，执行批量迁移
      参数说明：
        False        - 不使用并行模式（串行执行，便于观察进度）
        Dir_         - 目标目录路径
        model_stream - 包含迁移规则的数据流
        False        - 不反转映射（即主库→副库，若为 True 则反向，即副库→主库）
        Do_RewriteStatus - 状态回调函数，实时输出迁移进度
    }
    RewritePascal_ProcessDirectory(False, Dir_, model_stream, False, Do_RewriteStatus);

    DoStatus('─────────────────────────────────────────────────────────────');
    DoStatus('✓ 代码迁移完成！');
    DoStatus('▶ 请检查迁移后的项目代码，确认无误后重新编译');
    DoStatus('▶ 副库项目文档及差异说明请访问：');
    DoStatus('   https://github.com/PassByYou888/zNetV2/tree/main/source/sec');
    DoStatus('');

  finally
    DisposeObject(model_stream);   // 释放迁移模型数据流
  end;
end;

{-----------------------------------------------------------------------------
  程序入口点
  说明: 程序启动后调用 Fill_CMD 执行主逻辑，完成后等待用户按键退出
-----------------------------------------------------------------------------}
begin
  Fill_CMD;                    // 执行主迁移流程
  DoStatus('按 Enter 键退出...');
  Readln;                      // 等待用户按键，便于查看输出结果
end.
