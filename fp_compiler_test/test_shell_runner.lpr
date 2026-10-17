program test_shell_runner;

{$DEFINE FPC_DELPHI_MODE}
{$I ..\source\Z.Define.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils, Classes,
  Z.Core, Z.PascalStrings, Z.Status, Z.UnicodeMixedLib,
  Z.ShellRunner;

type
  TCollector = class
  public
    Lock: TCritical;
    StdOutLines: TStringList;
    StdErrLines: TStringList;
    ChildExitCode: Cardinal;
    GotExit: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure OnOut(Sender: TShellRunner; const Line: TPascalString; const IsError: Boolean);
    procedure OnErr(Sender: TShellRunner; const Line: TPascalString; const IsError: Boolean);
    procedure OnChildExit(Sender: TShellRunner; const ExitCode: Cardinal);
    function ContainsOut(const S: String): Boolean;
    function ContainsErr(const S: String): Boolean;
    function OutCount: Integer;
    function ErrCount: Integer;
  end;

var
  TotalPassed: Integer = 0;
  TotalFailed: Integer = 0;

procedure Check(const Name: string; const Ok: Boolean; const Detail: string = '');
begin
  if Ok then
    begin
      Inc(TotalPassed);
      WriteLn('[PASS] ', Name);
    end
  else
    begin
      Inc(TotalFailed);
      WriteLn('[FAIL] ', Name);
      if Detail <> '' then
        WriteLn('       ', Detail);
    end;
end;

{ ---- TCollector ---- }

constructor TCollector.Create;
begin
  inherited Create;
  Lock := TCritical.Create('TCollector');
  StdOutLines := TStringList.Create;
  StdErrLines := TStringList.Create;
  ChildExitCode := 0;
  GotExit := False;
end;

destructor TCollector.Destroy;
begin
  DisposeObjectAndNil(Lock);
  StdOutLines.Free;
  StdErrLines.Free;
  inherited Destroy;
end;

procedure TCollector.OnOut(Sender: TShellRunner; const Line: TPascalString; const IsError: Boolean);
begin
  Lock.Acquire;
  try
    StdOutLines.Add(Line.Text);
  finally
    Lock.Release;
  end;
end;

procedure TCollector.OnErr(Sender: TShellRunner; const Line: TPascalString; const IsError: Boolean);
begin
  Lock.Acquire;
  try
    StdErrLines.Add(Line.Text);
  finally
    Lock.Release;
  end;
end;

procedure TCollector.OnChildExit(Sender: TShellRunner; const ExitCode: Cardinal);
begin
  Lock.Acquire;
  try
    ChildExitCode := ExitCode;
    GotExit := True;
  finally
    Lock.Release;
  end;
end;

function TCollector.ContainsOut(const S: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  Lock.Acquire;
  try
    for I := 0 to StdOutLines.Count - 1 do
      if Pos(S, StdOutLines[I]) > 0 then
        begin
          Result := True;
          Exit;
        end;
  finally
    Lock.Release;
  end;
end;

function TCollector.ContainsErr(const S: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  Lock.Acquire;
  try
    for I := 0 to StdErrLines.Count - 1 do
      if Pos(S, StdErrLines[I]) > 0 then
        begin
          Result := True;
          Exit;
        end;
  finally
    Lock.Release;
  end;
end;

function TCollector.OutCount: Integer;
begin
  Lock.Acquire;
  try
    Result := StdOutLines.Count;
  finally
    Lock.Release;
  end;
end;

function TCollector.ErrCount: Integer;
begin
  Lock.Acquire;
  try
    Result := StdErrLines.Count;
  finally
    Lock.Release;
  end;
end;

{ ---- generic helper ---- }

function RunOne(const Name, Cmd, WorkPath: TPascalString;
  const TimeoutMs: Cardinal; const Coll: TCollector): Boolean;
var
  R: TShellRunner;
begin
  Result := False;
  R := TShellRunner.Create(Cmd, WorkPath);
  try
    R.AutoShowStdOut := False;
    R.AutoShowStdErr := False;
    R.OnStdOutLine := Coll.OnOut;
    R.OnStdErrLine := Coll.OnErr;
    R.OnExit := Coll.OnChildExit;
    if not R.Start then
      begin
        Check(Name + '.start', False, R.LastError);
        Exit;
      end;
    if not R.WaitForExit(TimeoutMs) then
      begin
        Check(Name + '.wait', False, R.LastError);
        R.Terminate;
        R.WaitForExit(2000);
        Exit;
      end;
    Result := True;
  finally
    R.Free;
  end;
end;

{ ---- tests ---- }

procedure TestBasicEcho;
var
  C: TCollector;
begin
  C := TCollector.Create;
  try
    if RunOne('basic_echo', 'echo hello_from_shell_runner', '', 5000, C) then
      begin
        Check('basic_echo.stdout', C.ContainsOut('hello_from_shell_runner'),
          Format('stdout_count=%d', [C.OutCount]));
        Check('basic_echo.exit0', C.GotExit and (C.ChildExitCode = 0),
          Format('exitcode=%d gotexit=%s',
            [C.ChildExitCode, BoolToStr(C.GotExit, True)]));
      end;
  finally
    C.Free;
  end;
end;

procedure TestExitCode;
var
  C: TCollector;
begin
  C := TCollector.Create;
  try
    if RunOne('exit_code', 'exit 42', '', 5000, C) then
      Check('exit_code.exit42', C.ChildExitCode = 42,
        Format('exitcode=%d', [C.ChildExitCode]));
  finally
    C.Free;
  end;
end;

procedure TestStderr;
var
  C: TCollector;
begin
  C := TCollector.Create;
  try
    if RunOne('stderr', 'echo error_line 1>&2', '', 5000, C) then
      Check('stderr.captured', C.ContainsErr('error_line'),
        Format('stderr_count=%d stdout_count=%d', [C.ErrCount, C.OutCount]));
  finally
    C.Free;
  end;
end;

procedure TestStdin;
var
  R: TShellRunner;
  C: TCollector;
begin
  C := TCollector.Create;
  R := TShellRunner.Create('cat', '');
  try
    R.AutoShowStdOut := False;
    R.AutoShowStdErr := False;
    R.OnStdOutLine := C.OnOut;
    R.OnStdErrLine := C.OnErr;
    R.OnExit := C.OnChildExit;
    if not R.Start then
      begin
        Check('stdin.start', False, R.LastError);
        Exit;
      end;
    R.WriteStdinLine('piped_line_1');
    R.WriteStdinLine('piped_line_2');
    R.CloseStdin;
    if not R.WaitForExit(5000) then
      begin
        Check('stdin.wait', False, R.LastError);
        R.Terminate;
        R.WaitForExit(2000);
        Exit;
      end;
    Check('stdin.line1', C.ContainsOut('piped_line_1'),
      Format('stdout_count=%d', [C.OutCount]));
    Check('stdin.line2', C.ContainsOut('piped_line_2'),
      Format('stdout_count=%d', [C.OutCount]));
  finally
    R.Free;
    C.Free;
  end;
end;

procedure TestWorkDir;
var
  C: TCollector;
begin
  C := TCollector.Create;
  try
    if RunOne('workdir', 'pwd', '/tmp', 5000, C) then
      Check('workdir.pwd_is_tmp', C.ContainsOut('/tmp'),
        Format('stdout_count=%d', [C.OutCount]));
  finally
    C.Free;
  end;
end;

procedure TestUtf8Output;
var
  C: TCollector;
  Cmd: TPascalString;
begin
  // "中文" in UTF-8 bytes
  Cmd := 'echo '#$E4#$B8#$AD#$E6#$96#$87;
  C := TCollector.Create;
  try
    if RunOne('utf8_output', Cmd, '', 5000, C) then
      Check('utf8_output.non_empty', C.OutCount > 0,
        Format('stdout_count=%d', [C.OutCount]));
  finally
    C.Free;
  end;
end;

procedure TestLongOutput;
var
  C: TCollector;
begin
  C := TCollector.Create;
  try
    if RunOne('long_output', 'seq 1 1000', '', 10000, C) then
      Check('long_output.1000_lines', C.OutCount >= 1000,
        Format('stdout_count=%d (expected >= 1000)', [C.OutCount]));
  finally
    C.Free;
  end;
end;

procedure TestTimeout;
var
  R: TShellRunner;
  C: TCollector;
begin
  C := TCollector.Create;
  R := TShellRunner.Create('sleep 10', '');
  try
    R.AutoShowStdOut := False;
    R.AutoShowStdErr := False;
    R.OnStdOutLine := C.OnOut;
    R.OnStdErrLine := C.OnErr;
    R.OnExit := C.OnChildExit;
    if not R.Start then
      begin
        Check('timeout.start', False, R.LastError);
        Exit;
      end;
    Check('timeout.short_wait_returns_false', not R.WaitForExit(300));
    R.Terminate;
    R.WaitForExit(3000);
  finally
    R.Free;
    C.Free;
  end;
end;

procedure TestTerminate;
var
  R: TShellRunner;
  C: TCollector;
begin
  C := TCollector.Create;
  R := TShellRunner.Create('sleep 10', '');
  try
    R.AutoShowStdOut := False;
    R.AutoShowStdErr := False;
    R.OnStdOutLine := C.OnOut;
    R.OnStdErrLine := C.OnErr;
    R.OnExit := C.OnChildExit;
    if not R.Start then
      begin
        Check('terminate.start', False, R.LastError);
        Exit;
      end;
    TThread.Sleep(200);
    Check('terminate.call_ok', R.Terminate);
    Check('terminate.exited', R.WaitForExit(3000));
  finally
    R.Free;
    C.Free;
  end;
end;

{ ---- main ---- }

var
  Supported: Boolean;
  SelfTestOk: Boolean;
  G_ExitCode: Integer;
begin
  WriteLn('=========================================================');
  WriteLn(' Z.ShellRunner Test Suite (Lazarus + FPC on Linux)');
  WriteLn('=========================================================');
  WriteLn;

  Supported := IsShellRunnerSupported;
  WriteLn('IsShellRunnerSupported = ', BoolToStr(Supported, True));
  if not Supported then
    begin
      WriteLn('This platform is not supported by Z.ShellRunner.');
      Halt(2);
    end;
  WriteLn;

  WriteLn('--- Group 1: basic echo ---');
  TestBasicEcho;
  WriteLn;

  WriteLn('--- Group 2: exit code ---');
  TestExitCode;
  WriteLn;

  WriteLn('--- Group 3: stderr capture ---');
  TestStderr;
  WriteLn;

  WriteLn('--- Group 4: stdin injection ---');
  TestStdin;
  WriteLn;

  WriteLn('--- Group 5: working directory ---');
  TestWorkDir;
  WriteLn;

  WriteLn('--- Group 6: UTF-8 output ---');
  TestUtf8Output;
  WriteLn;

  WriteLn('--- Group 7: long output (1000 lines) ---');
  TestLongOutput;
  WriteLn;

  WriteLn('--- Group 8: timeout ---');
  TestTimeout;
  WriteLn;

  WriteLn('--- Group 9: terminate ---');
  TestTerminate;
  WriteLn;

  WriteLn('--- Group 10: in-library self test (RunShellRunnerSelfTest) ---');
  WriteLn('Note: "chinese_echo.captured" inside RunShellRunnerSelfTest is');
  WriteLn('      expected to FAIL on Linux because it uses "cmd /c echo",');
  WriteLn('      which does not exist on Linux. This is a known limitation');
  WriteLn('      of the in-library self-test, NOT of Z.ShellRunner itself.');
  SelfTestOk := RunShellRunnerSelfTest;
  WriteLn('RunShellRunnerSelfTest = ', BoolToStr(SelfTestOk, True));
  WriteLn;

  WriteLn('=========================================================');
  WriteLn(Format(' Summary: passed=%d  failed=%d', [TotalPassed, TotalFailed]));
  WriteLn('=========================================================');

  if TotalFailed = 0 then
    G_ExitCode := 0
  else
    G_ExitCode := 1;

  ExitCode := G_ExitCode;
end.
