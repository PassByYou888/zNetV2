(*
MIT License

Copyright (c) 2026 by.LaoZhang qq600585

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*)
unit Z.ShellRunner;

// Z.ShellRunner - cross-platform shell runner with stdout/stderr capture.
{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  Classes, SysUtils, Z.ListEngine,
{$IFDEF MSWINDOWS} Windows, {$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
  BaseUnix, Unix, ctypes,
{$ENDIF}{$ENDIF}{$ENDIF}
  Z.Core, Z.PascalStrings, Z.Status, Z.UnicodeMixedLib;

type
  TTextEncoding = (teASCII, teUTF8, teGBK, teLatin1);

  TShellRunner = class;

  TShellLineEvent = procedure(Sender: TShellRunner; const Line: TPascalString; const IsError: Boolean) of object;
  TShellExitEvent = procedure(Sender: TShellRunner; const ExitCode: Cardinal) of object;

  TShellReaderThread = class(TCore_Thread)
  private
    FOwner: TShellRunner;
    FIsStdErr: Boolean;
    FLineBuf: RawByteString;
    FFinished: TAtomBool;
    procedure ProcessChunk(const Buf; const Count: Integer);
    procedure DeliverLine(const Line: RawByteString);
  protected
    procedure Execute; override;
  public
{$IFDEF MSWINDOWS}
    FHandle: THandle;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
    FFd: cint;
{$ENDIF}{$ENDIF}{$ENDIF}
    constructor Create(AOwner: TShellRunner; AIsStdErr: Boolean);
    destructor Destroy; override;
    function WaitJoin(const TimeoutMs: Cardinal): Boolean;
  end;

  TShellRunner = class(TCore_Object_Intermediate)
  private
    FCommand: TPascalString;
    FWorkPath: TPascalString;
    FHideWindow: Boolean;
    FAutoShowStdOut: Boolean;
    FAutoShowStdErr: Boolean;
    FRunning: Boolean;
    FExitCode: Cardinal;
    FLastError: string;
    FLog: TPascalStringList;
    FLogLock: TCritical;
    FOnStdOutLine: TShellLineEvent;
    FOnStdErrLine: TShellLineEvent;
    FOnExit: TShellExitEvent;
    FStdOutThread: TShellReaderThread;
    FStdErrThread: TShellReaderThread;
{$IFDEF MSWINDOWS}
    FStdinRead: THandle;
    FStdinWrite: THandle;
    FStdoutRead: THandle;
    FStdoutWrite: THandle;
    FStderrRead: THandle;
    FStderrWrite: THandle;
    FProcessHandle: THandle;
    FThreadHandle: THandle;
    FProcessID: Cardinal;
    procedure CloseAllHandles;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
    FStdinFd: cint;
    FStdoutFd: cint;
    FStderrFd: cint;
    FChildPID: TPid;
    procedure CloseAllFds;
{$ENDIF}{$ENDIF}{$ENDIF}
    procedure DeliverLine(const Line: TPascalString; const IsError: Boolean);
  public
    constructor Create(const Cmd, WorkPath: TPascalString);
    destructor Destroy; override;

    procedure SRLog(const S: string);

    function Start: Boolean;
    function WaitForExit(const TimeoutMs: Cardinal = Cardinal($FFFFFFFF)): Boolean;
    function Terminate: Boolean;
    function WriteStdin(const Data: RawByteString): Boolean;
    function WriteStdinLine(const Line: RawByteString): Boolean;
    function CloseStdin: Boolean;
    function SetWindowVisible(const Visible: Boolean): Boolean;

    property Running: Boolean read FRunning;
    property ExitCode: Cardinal read FExitCode;
    property LastError: string read FLastError;
    property Log: TPascalStringList read FLog;
    property Command: TPascalString read FCommand write FCommand;
    property WorkPath: TPascalString read FWorkPath write FWorkPath;
    property HideWindow: Boolean read FHideWindow write FHideWindow;
    property AutoShowStdOut: Boolean read FAutoShowStdOut write FAutoShowStdOut;
    property AutoShowStdErr: Boolean read FAutoShowStdErr write FAutoShowStdErr;
    property OnStdOutLine: TShellLineEvent read FOnStdOutLine write FOnStdOutLine;
    property OnStdErrLine: TShellLineEvent read FOnStdErrLine write FOnStdErrLine;
    property OnExit: TShellExitEvent read FOnExit write FOnExit;
  end;

function DetectTextEncoding(const B: RawByteString): TTextEncoding;
function IsShellRunnerSupported: Boolean;
function RunShellRunnerSelfTest: Boolean;

var
  Enabled_ShellRunnerLog: Boolean = True;
  DoStatus_ShellRunnerLog: Boolean = True;

implementation

{$DEFINE Z_SHELL_UNSUPPORTED}
{$IFDEF MSWINDOWS}{$UNDEF Z_SHELL_UNSUPPORTED}{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
{$UNDEF Z_SHELL_UNSUPPORTED}
{$ENDIF}{$ENDIF}{$ENDIF}


const
  C_MaxLineBufSize: Integer = 4 * 1024 * 1024;
  C_ReadPollMs: Integer = 100;
  C_ReaderJoinMs: Cardinal = 5000;
  C_DrainGraceMs: Cardinal = 500;
  C_JoinPollMs: Integer = 10;
  C_IdleExitThreshold: Integer = 5;
  C_ScheduleYieldMs: Integer = 1;

function IsShellRunnerSupported: Boolean;
begin
{$IFDEF Z_SHELL_UNSUPPORTED}
  Result := False;
{$ELSE}
  Result := True;
{$ENDIF}
end;

function IsPureASCII(const B: RawByteString): Boolean;
var
  I, N: Integer;
begin
  N := Length(B);
  for I := 1 to N do
    if Byte(B[I]) >= $80 then
      begin
        Result := False;
        Exit;
      end;
  Result := True;
end;

function IsValidUTF8(const B: RawByteString): Boolean;
var
  I, N: Integer;
  c, b1, b2, b3: Byte;
begin
  Result := False;
  N := Length(B);
  I := 1;
  while I <= N do
    begin
      c := Byte(B[I]);
      if c < $80 then
          Inc(I)
      else if (c >= $C2) and (c <= $DF) then
        begin
          if I + 1 > N then Exit;
          b1 := Byte(B[I + 1]);
          if (b1 and $C0) <> $80 then Exit;
          Inc(I, 2);
        end
      else if (c >= $E0) and (c <= $EF) then
        begin
          if I + 2 > N then Exit;
          b1 := Byte(B[I + 1]);
          b2 := Byte(B[I + 2]);
          if (b1 and $C0) <> $80 then Exit;
          if (b2 and $C0) <> $80 then Exit;
          if (c = $E0) and (b1 < $A0) then Exit;
          if (c = $ED) and (b1 >= $A0) then Exit;
          Inc(I, 3);
        end
      else if (c >= $F0) and (c <= $F4) then
        begin
          if I + 3 > N then Exit;
          b1 := Byte(B[I + 1]);
          b2 := Byte(B[I + 2]);
          b3 := Byte(B[I + 3]);
          if (b1 and $C0) <> $80 then Exit;
          if (b2 and $C0) <> $80 then Exit;
          if (b3 and $C0) <> $80 then Exit;
          if (c = $F0) and (b1 < $90) then Exit;
          if (c = $F4) and (b1 > $8F) then Exit;
          Inc(I, 4);
        end
      else
          Exit;
    end;
  Result := True;
end;

function IsValidGBK(const B: RawByteString): Boolean;
var
  I, N: Integer;
  c, c2: Byte;
begin
  Result := False;
  N := Length(B);
  I := 1;
  while I <= N do
    begin
      c := Byte(B[I]);
      if c < $80 then
          Inc(I)
      else if (c >= $81) and (c <= $FE) then
        begin
          if I + 1 > N then Exit;
          c2 := Byte(B[I + 1]);
          if (c2 < $40) or (c2 = $7F) or (c2 = $FF) then Exit;
          Inc(I, 2);
        end
      else
          Exit;
    end;
  Result := True;
end;

function DetectTextEncoding(const B: RawByteString): TTextEncoding;
begin
  if Length(B) = 0 then
      Exit(teASCII);
  if IsPureASCII(B) then
      Exit(teASCII);
  if IsValidUTF8(B) then
      Exit(teUTF8);
  if IsValidGBK(B) then
      Exit(teGBK);
  Result := teLatin1;
end;

{$IFDEF MSWINDOWS}


function WinDecodeMultiByte(const B: RawByteString; CodePage: UINT;
  Flags: DWORD): UnicodeString;
var
  N, W: Integer;
begin
  Result := '';
  N := Length(B);
  if N = 0 then Exit;
  W := MultiByteToWideChar(CodePage, Flags, PAnsiChar(B), N, nil, 0);
  if W <= 0 then Exit;
  SetLength(Result, W);
  MultiByteToWideChar(CodePage, Flags, PAnsiChar(B), N, PWideChar(Result), W);
end;
{$ENDIF}


function BytesToPascalString(const B: RawByteString): TPascalString;
var
  N: Integer;
  enc: TTextEncoding;
{$IFDEF FPC}
  W: UnicodeString;
{$ENDIF}
{$IFNDEF FPC}
  S: UnicodeString;
  I: Integer;
{$IFDEF MSWINDOWS}
  W2: UnicodeString;
{$ELSE}
  c: Byte;
  cp: Cardinal;
  OutLen: Integer;
  Ok: Boolean;
{$ENDIF}
{$ENDIF}
begin
  Result := '';
  N := Length(B);
  if N = 0 then Exit;
  enc := DetectTextEncoding(B);

{$IFDEF FPC}
  case enc of
    teASCII:
      begin
        SetLength(Result.buff, N);
        CopyPtr(@B[1], @Result.buff[0], N);
      end;
    teUTF8:
      begin
        W := UTF8Decode(B);
        Result.Text := W;
      end;
    teGBK, teLatin1:
      begin
        SetLength(Result.buff, N);
        CopyPtr(@B[1], @Result.buff[0], N);
      end;
  end;
{$ELSE}
{$IFDEF MSWINDOWS}
  case enc of
    teASCII, teLatin1:
      begin
        SetLength(S, N);
        for I := 1 to N do
            S[I] := WideChar(Byte(B[I]));
        Result.Text := S;
      end;
    teUTF8:
      begin
        W2 := WinDecodeMultiByte(B, CP_UTF8, MB_ERR_INVALID_CHARS);
        if Length(W2) = 0 then
            W2 := WinDecodeMultiByte(B, CP_UTF8, 0);
        if Length(W2) = 0 then
          begin
            SetLength(S, N);
            for I := 1 to N do
                S[I] := WideChar(Byte(B[I]));
            W2 := S;
          end;
        Result.Text := W2;
      end;
    teGBK:
      begin
        W2 := WinDecodeMultiByte(B, 936, 0);
        if Length(W2) = 0 then
          begin
            SetLength(S, N);
            for I := 1 to N do
                S[I] := WideChar(Byte(B[I]));
            W2 := S;
          end;
        Result.Text := W2;
      end;
  end;
{$ELSE}
  case enc of
    teASCII, teGBK, teLatin1:
      begin
        SetLength(S, N);
        for I := 1 to N do
            S[I] := WideChar(Byte(B[I]));
        Result.Text := S;
      end;
    teUTF8:
      begin
        Ok := True;
        SetLength(S, N);
        OutLen := 0;
        I := 1;
        while I <= N do
          begin
            c := Byte(B[I]);
            if c < $80 then
              begin
                Inc(OutLen);
                S[OutLen] := WideChar(c);
                Inc(I);
              end
            else if (c >= $C2) and (c <= $DF) then
              begin
                if (I + 1 > N) or ((Byte(B[I + 1]) and $C0) <> $80) then
                  begin
                    Ok := False; Break;
                  end;
                cp := ((c and $1F) shl 6) or (Byte(B[I + 1]) and $3F);
                Inc(OutLen);
                S[OutLen] := WideChar(cp);
                Inc(I, 2);
              end
            else if (c >= $E0) and (c <= $EF) then
              begin
                if (I + 2 > N) or
                  ((Byte(B[I + 1]) and $C0) <> $80) or
                  ((Byte(B[I + 2]) and $C0) <> $80) then
                  begin
                    Ok := False; Break;
                  end;
                cp := ((c and $0F) shl 12) or
                  ((Byte(B[I + 1]) and $3F) shl 6) or
                  (Byte(B[I + 2]) and $3F);
                if (cp >= $D800) and (cp <= $DFFF) then
                  begin
                    Ok := False; Break;
                  end;
                Inc(OutLen);
                S[OutLen] := WideChar(cp);
                Inc(I, 3);
              end
            else if (c >= $F0) and (c <= $F4) then
              begin
                if (I + 3 > N) or
                  ((Byte(B[I + 1]) and $C0) <> $80) or
                  ((Byte(B[I + 2]) and $C0) <> $80) or
                  ((Byte(B[I + 3]) and $C0) <> $80) then
                  begin
                    Ok := False; Break;
                  end;
                cp := ((c and $07) shl 18) or
                  ((Byte(B[I + 1]) and $3F) shl 12) or
                  ((Byte(B[I + 2]) and $3F) shl 6) or
                  (Byte(B[I + 3]) and $3F);
                if (cp < $10000) or (cp > $10FFFF) then
                  begin
                    Ok := False; Break;
                  end;
                Dec(cp, $10000);
                Inc(OutLen);
                S[OutLen] := WideChar($D800 + (cp shr 10));
                Inc(OutLen);
                S[OutLen] := WideChar($DC00 + (cp and $3FF));
                Inc(I, 4);
              end
            else
              begin
                Ok := False; Break;
              end;
          end;
        if Ok then
          begin
            SetLength(S, OutLen);
            Result.Text := S;
          end
        else
          begin
            SetLength(S, N);
            for I := 1 to N do
                S[I] := WideChar(Byte(B[I]));
            Result.Text := S;
          end;
      end;
  end;
{$ENDIF}
{$ENDIF}
end;

constructor TShellReaderThread.Create(AOwner: TShellRunner; AIsStdErr: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FIsStdErr := AIsStdErr;
  FLineBuf := '';
  FFinished := TAtomBool.Create(False);
{$IFDEF MSWINDOWS}
  FHandle := 0;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
  FFd := -1;
{$ENDIF}{$ENDIF}{$ENDIF}
end;

destructor TShellReaderThread.Destroy;
begin
  DisposeObjectAndNil(FFinished);
  inherited Destroy;
end;

function TShellReaderThread.WaitJoin(const TimeoutMs: Cardinal): Boolean;
var
  StartTick: TTimeTick;
begin
  if FFinished = nil then
    begin
      Result := True;
      Exit;
    end;
  StartTick := GetTimeTick;
  while not FFinished.V do
    begin
      if (GetTimeTick - StartTick) >= TTimeTick(TimeoutMs) then
        begin
          Result := False;
          Exit;
        end;
      TThread.Sleep(C_JoinPollMs);
    end;
  Result := True;
end;

procedure TShellReaderThread.ProcessChunk(const Buf; const Count: Integer);
var
  S: RawByteString;
  I, Last: Integer;
begin
  if Count <= 0 then Exit;
  SetLength(S, Count);
  CopyPtr(@Buf, @S[1], Count);
  FLineBuf := FLineBuf + S;
  Last := 1;
  for I := 1 to Length(FLineBuf) do
    if FLineBuf[I] = #10 then
      begin
        DeliverLine(Copy(FLineBuf, Last, I - Last));
        Last := I + 1;
      end;
  if Last > 1 then
      Delete(FLineBuf, 1, Last - 1);
  if Length(FLineBuf) >= C_MaxLineBufSize then
    begin
      DeliverLine(FLineBuf);
      FLineBuf := '';
    end;
end;

procedure TShellReaderThread.DeliverLine(const Line: RawByteString);
var
  L: RawByteString;
  U: TPascalString;
  Owner: TShellRunner;
begin
  try
    L := Line;
    if (Length(L) > 0) and (L[Length(L)] = #13) then
        SetLength(L, Length(L) - 1);
    U := BytesToPascalString(L);
    Owner := FOwner;
    if Owner <> nil then
        Owner.DeliverLine(U, FIsStdErr);
  except
    on E: Exception do
      begin
        if Enabled_ShellRunnerLog then
          begin
            if FOwner <> nil then
                FOwner.SRLog('DeliverLine EXCEPTION: ' + E.Message);
          end;
      end;
  end;
end;

procedure TShellReaderThread.Execute;
var
  Buf: array [0 .. 8191] of Byte;
  DrainDeadline: TTimeTick;
  IdleCount: Integer;
  StreamName: string;
{$IFDEF MSWINDOWS}
  Avail, ReadN, BytesRead: Cardinal;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
  fds: TFDSet;
  tv: TTimeVal;
  R: cint;
  N: ssize_t;
{$ENDIF}{$ENDIF}{$ENDIF}
begin
  if FIsStdErr then
      StreamName := 'ERR'
  else
      StreamName := 'OUT';

  if Enabled_ShellRunnerLog then
    begin
      if FOwner <> nil then
          FOwner.SRLog(Format('Reader[%s] enter Execute, Terminated=%s',
            [StreamName, BoolToStr(Terminated, True)]));
    end;

  try
    try
      DrainDeadline := 0;
      IdleCount := 0;
{$IFDEF MSWINDOWS}
      while True do
        begin
          if Terminated and (DrainDeadline = 0) then
            begin
              DrainDeadline := GetTimeTick + C_DrainGraceMs;
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] drain mode, %d ms grace',
                        [StreamName, C_DrainGraceMs]));
                end;
            end;
          if (DrainDeadline > 0) and (GetTimeTick > DrainDeadline) then
            begin
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] drain timeout, exiting',
                        [StreamName]));
                end;
              Break;
            end;

          Avail := 0;
          if not PeekNamedPipe(FHandle, nil, 0, nil, @Avail, nil) then
            begin
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] PeekNamedPipe failed (err=%d), exiting',
                        [StreamName, GetLastError]));
                end;
              Break;
            end;

          if Avail > 0 then
            begin
              IdleCount := 0;
              ReadN := Avail;
              if ReadN > SizeOf(Buf) then
                  ReadN := SizeOf(Buf);
              if not ReadFile(FHandle, Buf, ReadN, BytesRead, nil) then
                begin
                  if Enabled_ShellRunnerLog then
                    begin
                      if FOwner <> nil then
                          FOwner.SRLog(Format('Reader[%s] ReadFile failed (err=%d), exiting',
                            [StreamName, GetLastError]));
                    end;
                  Break;
                end;
              if BytesRead = 0 then
                begin
                  if Enabled_ShellRunnerLog then
                    begin
                      if FOwner <> nil then
                          FOwner.SRLog(Format('Reader[%s] ReadFile 0 bytes, exiting',
                            [StreamName]));
                    end;
                  Break;
                end;
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] read %d bytes (avail was %d)',
                        [StreamName, BytesRead, Avail]));
                end;
              ProcessChunk(Buf, BytesRead);
            end
          else
            begin
              if (FOwner <> nil) and (not FOwner.FRunning) then
                  Inc(IdleCount);
              if IdleCount >= C_IdleExitThreshold then
                begin
                  if Enabled_ShellRunnerLog then
                    begin
                      if FOwner <> nil then
                          FOwner.SRLog(Format('Reader[%s] process exited + %d idle polls, exiting',
                            [StreamName, IdleCount]));
                    end;
                  Break;
                end;
              TThread.Sleep(C_ReadPollMs);
            end;
        end;
      if Length(FLineBuf) > 0 then
        begin
          if Enabled_ShellRunnerLog then
            begin
              if FOwner <> nil then
                  FOwner.SRLog(Format('Reader[%s] flush final line (%d bytes)',
                    [StreamName, Length(FLineBuf)]));
            end;
          DeliverLine(FLineBuf);
          FLineBuf := '';
        end;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
      while True do
        begin
          if Terminated and (DrainDeadline = 0) then
            begin
              DrainDeadline := GetTimeTick + C_DrainGraceMs;
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] drain mode, %d ms grace',
                        [StreamName, C_DrainGraceMs]));
                end;
            end;
          if (DrainDeadline > 0) and (GetTimeTick > DrainDeadline) then
            begin
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] drain timeout, exiting',
                        [StreamName]));
                end;
              Break;
            end;

          fpFD_ZERO(fds);
          fpFD_SET(FFd, fds);
          tv.tv_sec := 0;
          tv.tv_usec := C_ReadPollMs * 1000;
          R := fpSelect(FFd + 1, @fds, nil, nil, @tv);
          if R = 0 then
            begin
              if (FOwner <> nil) and (not FOwner.FRunning) then
                  Inc(IdleCount);
              if IdleCount >= C_IdleExitThreshold then
                begin
                  if Enabled_ShellRunnerLog then
                    begin
                      if FOwner <> nil then
                          FOwner.SRLog(Format('Reader[%s] process exited + %d idle polls, exiting',
                            [StreamName, IdleCount]));
                    end;
                  Break;
                end;
              Continue;
            end;
          if R < 0 then
            begin
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] select failed, exiting',
                        [StreamName]));
                end;
              Break;
            end;
          IdleCount := 0;
          N := FpRead(FFd, Buf, SizeOf(Buf));
          if N = 0 then
            begin
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] EOF, exiting', [StreamName]));
                end;
              Break;
            end;
          if N < 0 then
            begin
              if Enabled_ShellRunnerLog then
                begin
                  if FOwner <> nil then
                      FOwner.SRLog(Format('Reader[%s] read error, exiting',
                        [StreamName]));
                end;
              Break;
            end;
          if Enabled_ShellRunnerLog then
            begin
              if FOwner <> nil then
                  FOwner.SRLog(Format('Reader[%s] read %d bytes', [StreamName, N]));
            end;
          ProcessChunk(Buf, N);
        end;
      if Length(FLineBuf) > 0 then
        begin
          if Enabled_ShellRunnerLog then
            begin
              if FOwner <> nil then
                  FOwner.SRLog(Format('Reader[%s] flush final line (%d bytes)',
                    [StreamName, Length(FLineBuf)]));
            end;
          DeliverLine(FLineBuf);
          FLineBuf := '';
        end;
{$ENDIF}{$ENDIF}{$ENDIF}
    except
      on E: Exception do
        begin
          if Enabled_ShellRunnerLog then
            begin
              if FOwner <> nil then
                  FOwner.SRLog(Format('Reader[%s] EXCEPTION: %s',
                    [StreamName, E.Message]));
            end;
        end;
    end;
  finally
    if Enabled_ShellRunnerLog then
      begin
        if FOwner <> nil then
            FOwner.SRLog(Format('Reader[%s] exit, set finished', [StreamName]));
      end;
    if FFinished <> nil then
        FFinished.V := True;
  end;
end;

constructor TShellRunner.Create(const Cmd, WorkPath: TPascalString);
begin
  inherited Create;

  FLogLock := TCritical.Create('TShellRunner.Log');
  FLog := TPascalStringList.Create;

  FCommand := Cmd;
  FWorkPath := WorkPath;
  FHideWindow := True;
  FAutoShowStdOut := True;
  FAutoShowStdErr := True;
  FRunning := False;
  FExitCode := 0;
  FLastError := '';
  FOnStdOutLine := nil;
  FOnStdErrLine := nil;
  FOnExit := nil;
  FStdOutThread := nil;
  FStdErrThread := nil;
{$IFDEF MSWINDOWS}
  FStdinRead := 0; FStdinWrite := 0;
  FStdoutRead := 0; FStdoutWrite := 0;
  FStderrRead := 0; FStderrWrite := 0;
  FProcessHandle := 0;
  FThreadHandle := 0;
  FProcessID := 0;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
  FStdinFd := -1;
  FStdoutFd := -1;
  FStderrFd := -1;
  FChildPID := 0;
{$ENDIF}{$ENDIF}{$ENDIF}
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('Create cmd="%s"', [Cmd.Text]));
    end;
end;

destructor TShellRunner.Destroy;
var
  Leak: Boolean;
begin
  if Enabled_ShellRunnerLog then
    begin
      SRLog('Destroy begin');
    end;
  Leak := False;

  if FRunning then
    begin
      Terminate;
      WaitForExit(3000);
      if FRunning then
        begin
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
          if FChildPID <> 0 then
            begin
              if Enabled_ShellRunnerLog then
                begin
                  SRLog('Destroy: force SIGKILL');
                end;
              FpKill(FChildPID, SIGKILL);
            end;
{$ENDIF}{$ENDIF}{$ENDIF}
          WaitForExit(1000);
        end;
    end;

  if FStdOutThread <> nil then
    begin
      if Enabled_ShellRunnerLog then
        begin
          SRLog('Destroy: terminating stdout reader');
        end;
      FStdOutThread.Terminate;
      if FStdOutThread.WaitJoin(C_ReaderJoinMs) then
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('Destroy: stdout reader joined OK');
            end;
          DisposeObjectAndNil(FStdOutThread);
{$IFDEF MSWINDOWS}
          if FStdoutRead <> 0 then
            begin
              CloseHandle(FStdoutRead); FStdoutRead := 0;
            end;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
          if FStdoutFd >= 0 then
            begin
              FpClose(FStdoutFd); FStdoutFd := -1;
            end;
{$ENDIF}{$ENDIF}{$ENDIF}
        end
      else
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('Destroy: stdout reader STILL RUNNING - LEAK');
            end;
          Leak := True;
        end;
    end;

  if FStdErrThread <> nil then
    begin
      if Enabled_ShellRunnerLog then
        begin
          SRLog('Destroy: terminating stderr reader');
        end;
      FStdErrThread.Terminate;
      if FStdErrThread.WaitJoin(C_ReaderJoinMs) then
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('Destroy: stderr reader joined OK');
            end;
          DisposeObjectAndNil(FStdErrThread);
{$IFDEF MSWINDOWS}
          if FStderrRead <> 0 then
            begin
              CloseHandle(FStderrRead); FStderrRead := 0;
            end;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
          if FStderrFd >= 0 then
            begin
              FpClose(FStderrFd); FStderrFd := -1;
            end;
{$ENDIF}{$ENDIF}{$ENDIF}
        end
      else
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('Destroy: stderr reader STILL RUNNING - LEAK');
            end;
          Leak := True;
        end;
    end;

  if Leak then
    begin
      if Enabled_ShellRunnerLog then
        begin
          SRLog('[WARN] TShellRunner leaked: reader thread did not exit. Leaking object to prevent use-after-free.');
        end;
      Exit;
    end;

{$IFDEF MSWINDOWS}
  if FStdinWrite <> 0 then
    begin
      CloseHandle(FStdinWrite); FStdinWrite := 0;
    end;
  if FProcessHandle <> 0 then
    begin
      CloseHandle(FProcessHandle); FProcessHandle := 0;
    end;
  if FThreadHandle <> 0 then
    begin
      CloseHandle(FThreadHandle); FThreadHandle := 0;
    end;
{$ENDIF}
{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
  if FStdinFd >= 0 then
    begin
      FpClose(FStdinFd); FStdinFd := -1;
    end;
{$ENDIF}{$ENDIF}{$ENDIF}
  if Enabled_ShellRunnerLog then
    begin
      SRLog('Destroy end');
    end;

  DisposeObjectAndNil(FLogLock);
  FLog.Free;
  FLog := nil;

  inherited Destroy;
end;

procedure TShellRunner.SRLog(const S: string);
var
  Line: string;
begin
  if not Enabled_ShellRunnerLog then
      Exit;

  Line := '[ShellRunner] ' + S;

  if FLogLock <> nil then
    begin
      FLogLock.Acquire;
      try
        if FLog <> nil then
            FLog.Add(Line);
      finally
          FLogLock.Release;
      end;
    end;

  if DoStatus_ShellRunnerLog then
    begin
      try
          DoStatus(Line);
      except
      end;
    end;
end;

procedure TShellRunner.DeliverLine(const Line: TPascalString; const IsError: Boolean);
begin
  if IsError then
    begin
      try
        if Assigned(FOnStdErrLine) then FOnStdErrLine(Self, Line, True);
      except
        on E: Exception do
          begin
            if Enabled_ShellRunnerLog then
              begin
                SRLog('OnStdErrLine EXCEPTION: ' + E.Message);
              end;
          end;
      end;
      if FAutoShowStdErr then
        if Enabled_ShellRunnerLog then
          begin
            SRLog(Line.Text);
          end;
    end
  else
    begin
      try
        if Assigned(FOnStdOutLine) then FOnStdOutLine(Self, Line, False);
      except
        on E: Exception do
          begin
            if Enabled_ShellRunnerLog then
              begin
                SRLog('OnStdOutLine EXCEPTION: ' + E.Message);
              end;
          end;
      end;
      if FAutoShowStdOut then
        if Enabled_ShellRunnerLog then
          begin
            SRLog(Line.Text);
          end;
    end;
end;

{$IFDEF MSWINDOWS}


procedure TShellRunner.CloseAllHandles;
begin
  if FStdinRead <> 0 then
    begin
      CloseHandle(FStdinRead); FStdinRead := 0;
    end;
  if FStdinWrite <> 0 then
    begin
      CloseHandle(FStdinWrite); FStdinWrite := 0;
    end;
  if FStdoutRead <> 0 then
    begin
      CloseHandle(FStdoutRead); FStdoutRead := 0;
    end;
  if FStdoutWrite <> 0 then
    begin
      CloseHandle(FStdoutWrite); FStdoutWrite := 0;
    end;
  if FStderrRead <> 0 then
    begin
      CloseHandle(FStderrRead); FStderrRead := 0;
    end;
  if FStderrWrite <> 0 then
    begin
      CloseHandle(FStderrWrite); FStderrWrite := 0;
    end;
  if FProcessHandle <> 0 then
    begin
      CloseHandle(FProcessHandle); FProcessHandle := 0;
    end;
  if FThreadHandle <> 0 then
    begin
      CloseHandle(FThreadHandle); FThreadHandle := 0;
    end;
end;

function TShellRunner.Start: Boolean;
var
  SA: TSecurityAttributes;
{$IFDEF FPC}
  SI: TStartupInfoW;
{$ELSE}
  SI: TStartupInfo;
{$ENDIF}
  PI: TProcessInformation;
  CmdLineP, PathP: Pointer;
  Path: PWideChar;
  Flags: Cardinal;
begin
  Result := False;
  FLastError := '';
  if FRunning then
    begin
      FLastError := 'process already running'; Exit;
    end;
  FillPtr(@SA, SizeOf(SA), 0);
  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;
  SA.lpSecurityDescriptor := nil;
  if not CreatePipe(FStdinRead, FStdinWrite, @SA, 0) then
    begin
      FLastError := 'CreatePipe(stdin) failed: ' + umlIntToStr(GetLastError); Exit;
    end;
  if not CreatePipe(FStdoutRead, FStdoutWrite, @SA, 0) then
    begin
      FLastError := 'CreatePipe(stdout) failed: ' + umlIntToStr(GetLastError); CloseAllHandles; Exit;
    end;
  if not CreatePipe(FStderrRead, FStderrWrite, @SA, 0) then
    begin
      FLastError := 'CreatePipe(stderr) failed: ' + umlIntToStr(GetLastError); CloseAllHandles; Exit;
    end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('Start pipes: stdinR=%d stdinW=%d stdoutR=%d stdoutW=%d stderrR=%d stderrW=%d',
          [FStdinRead, FStdinWrite, FStdoutRead, FStdoutWrite, FStderrRead, FStderrWrite]));
    end;

  SetHandleInformation(FStdinWrite, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(FStdoutRead, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(FStderrRead, HANDLE_FLAG_INHERIT, 0);
  FillPtr(@SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  SI.hStdInput := FStdinRead;
  SI.hStdOutput := FStdoutWrite;
  SI.hStdError := FStderrWrite;
  if FHideWindow then
    begin
      SI.wShowWindow := SW_HIDE; Flags := CREATE_NO_WINDOW;
    end
  else
    begin
      SI.wShowWindow := SW_SHOW; Flags := 0;
    end;
  PathP := nil;
  Path := nil;
  if FWorkPath.L > 0 then
    begin
      PathP := FWorkPath.BuildWideChar;
      Path := PWideChar(PathP);
    end;
  CmdLineP := FCommand.BuildWideChar;
  try
    if not CreateProcessW(nil, PWideChar(CmdLineP), nil, nil, True,
      Flags, nil, Path, SI, PI) then
      begin
        FLastError := 'CreateProcess failed: ' + umlIntToStr(GetLastError);
        if Enabled_ShellRunnerLog then
          begin
            SRLog(FLastError);
          end;
        CloseAllHandles;
        Exit;
      end;
  finally
    if PathP <> nil then TPascalString.FreeWideChar(PathP);
    TPascalString.FreeWideChar(CmdLineP);
  end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('Start: process created PID=%d', [PI.dwProcessId]));
    end;

  CloseHandle(FStdinRead); FStdinRead := 0;
  CloseHandle(FStdoutWrite); FStdoutWrite := 0;
  CloseHandle(FStderrWrite); FStderrWrite := 0;

  FProcessHandle := PI.hProcess;
  FThreadHandle := PI.hThread;
  FProcessID := PI.dwProcessId;
  FRunning := True;
  FExitCode := 0;

  FStdOutThread := TShellReaderThread.Create(Self, False);
  FStdOutThread.FHandle := FStdoutRead;
  try
    FStdOutThread.Start;
    if Enabled_ShellRunnerLog then
      begin
        SRLog(Format('Start: stdout reader started (handle=%d)', [FStdoutRead]));
      end;
  except
    on E: Exception do
      begin
        FLastError := 'reader thread start failed: ' + E.Message;
        if Enabled_ShellRunnerLog then
          begin
            SRLog(FLastError);
          end;
        DisposeObjectAndNil(FStdOutThread);
        TerminateProcess(FProcessHandle, $FFFFFFFF);
        WaitForSingleObject(FProcessHandle, 1000);
        CloseAllHandles;
        FRunning := False;
        Exit;
      end;
  end;
  TThread.Sleep(C_ScheduleYieldMs);

  FStdErrThread := TShellReaderThread.Create(Self, True);
  FStdErrThread.FHandle := FStderrRead;
  try
    FStdErrThread.Start;
    if Enabled_ShellRunnerLog then
      begin
        SRLog(Format('Start: stderr reader started (handle=%d)', [FStderrRead]));
      end;
  except
    on E: Exception do
      begin
        FLastError := 'reader thread start failed: ' + E.Message;
        if Enabled_ShellRunnerLog then
          begin
            SRLog(FLastError);
          end;
        DisposeObjectAndNil(FStdErrThread);
        FStdOutThread.Terminate;
        FStdOutThread.WaitJoin(C_ReaderJoinMs);
        DisposeObjectAndNil(FStdOutThread);
        TerminateProcess(FProcessHandle, $FFFFFFFF);
        WaitForSingleObject(FProcessHandle, 1000);
        CloseAllHandles;
        FRunning := False;
        Exit;
      end;
  end;
  TThread.Sleep(C_ScheduleYieldMs);

  Result := True;
end;

function TShellRunner.WaitForExit(const TimeoutMs: Cardinal): Boolean;
var
  R: Cardinal;
begin
  if not FRunning then
    begin
      Result := True; Exit;
    end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('WaitForExit: waiting %d ms', [TimeoutMs]));
    end;
  R := WaitForSingleObject(FProcessHandle, TimeoutMs);
  if R = WAIT_TIMEOUT then
    begin
      FLastError := 'wait timeout';
      if Enabled_ShellRunnerLog then
        begin
          SRLog('WaitForExit: TIMEOUT');
        end;
      Result := False;
      Exit;
    end;
  if R <> WAIT_OBJECT_0 then
    begin
      FLastError := 'WaitForSingleObject failed: ' + IntToStr(GetLastError);
      if Enabled_ShellRunnerLog then
        begin
          SRLog(FLastError);
        end;
      Result := False;
      Exit;
    end;
  GetExitCodeProcess(FProcessHandle, FExitCode);
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('WaitForExit: process exited, code=%d', [FExitCode]));
    end;
  FRunning := False;

  if FStdOutThread <> nil then
    begin
      if Enabled_ShellRunnerLog then
        begin
          SRLog('WaitForExit: joining stdout reader');
        end;
      FStdOutThread.Terminate;
      if FStdOutThread.WaitJoin(C_ReaderJoinMs) then
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('WaitForExit: stdout reader joined OK');
            end;
          DisposeObjectAndNil(FStdOutThread);
          if FStdoutRead <> 0 then
            begin
              CloseHandle(FStdoutRead); FStdoutRead := 0;
            end;
        end
      else
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog(Format('[WARN] stdout reader did not exit in %d ms; retry in Destroy',
                  [C_ReaderJoinMs]));
            end;
        end;
    end;

  if FStdErrThread <> nil then
    begin
      if Enabled_ShellRunnerLog then
        begin
          SRLog('WaitForExit: joining stderr reader');
        end;
      FStdErrThread.Terminate;
      if FStdErrThread.WaitJoin(C_ReaderJoinMs) then
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('WaitForExit: stderr reader joined OK');
            end;
          DisposeObjectAndNil(FStdErrThread);
          if FStderrRead <> 0 then
            begin
              CloseHandle(FStderrRead); FStderrRead := 0;
            end;
        end
      else
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog(Format('[WARN] stderr reader did not exit in %d ms; retry in Destroy',
                  [C_ReaderJoinMs]));
            end;
        end;
    end;

  if Assigned(FOnExit) then
    try
        FOnExit(Self, FExitCode);
    except
      on E: Exception do
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('OnExit EXCEPTION: ' + E.Message);
            end;
        end;
    end;
  Result := True;
end;

function TShellRunner.Terminate: Boolean;
begin
  Result := False;
  if not FRunning then
    begin
      FLastError := 'process not running'; Exit;
    end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog('Terminate: calling TerminateProcess');
    end;
  if not TerminateProcess(FProcessHandle, $FFFFFFFF) then
    begin
      FLastError := 'TerminateProcess failed: ' + IntToStr(GetLastError);
      if Enabled_ShellRunnerLog then
        begin
          SRLog(FLastError);
        end;
      Exit;
    end;
  Result := True;
end;

function TShellRunner.WriteStdin(const Data: RawByteString): Boolean;
var
  Written: Cardinal;
  N: Integer;
begin
  Result := False;
  if not FRunning then
    begin
      FLastError := 'process not running'; Exit;
    end;
  if FStdinWrite = 0 then
    begin
      FLastError := 'stdin already closed'; Exit;
    end;
  N := Length(Data);
  if N = 0 then
    begin
      Result := True; Exit;
    end;
  if not WriteFile(FStdinWrite, Data[1], N, Written, nil) then
    begin
      FLastError := 'WriteFile(stdin) failed: ' + IntToStr(GetLastError);
      if Enabled_ShellRunnerLog then
        begin
          SRLog(FLastError);
        end;
      Exit;
    end;
  Result := Written = Cardinal(N);
end;

function TShellRunner.CloseStdin: Boolean;
begin
  if FStdinWrite <> 0 then
    begin
      CloseHandle(FStdinWrite); FStdinWrite := 0;
    end;
  Result := True;
end;

type
  PEnumWindowContext = ^TEnumWindowContext;

  TEnumWindowContext = record
    PID: Cardinal;
    Visible: Boolean;
  end;

function EnumWindowsProc_ShellRunner(hwnd: hwnd; lParam: lParam): BOOL; stdcall;
var
  Ctx: PEnumWindowContext;
  PID: Cardinal;
begin
  Result := True;
  Ctx := PEnumWindowContext(lParam);
  if Ctx = nil then Exit;
  PID := 0;
  GetWindowThreadProcessId(hwnd, @PID);
  if PID = Ctx^.PID then
    if Ctx^.Visible then ShowWindow(hwnd, SW_SHOWNOACTIVATE)
    else ShowWindow(hwnd, SW_HIDE);
end;

function TShellRunner.SetWindowVisible(const Visible: Boolean): Boolean;
var
  Ctx: TEnumWindowContext;
begin
  if not FRunning then
    begin
      FLastError := 'process not running'; Result := False; Exit;
    end;
  Ctx.PID := FProcessID;
  Ctx.Visible := Visible;
  EnumWindows(@EnumWindowsProc_ShellRunner, lParam(@Ctx));
  Result := True;
end;

{$ENDIF MSWINDOWS}

{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}


procedure TShellRunner.CloseAllFds;
begin
  if FStdinFd >= 0 then
    begin
      FpClose(FStdinFd); FStdinFd := -1;
    end;
  if FStdoutFd >= 0 then
    begin
      FpClose(FStdoutFd); FStdoutFd := -1;
    end;
  if FStderrFd >= 0 then
    begin
      FpClose(FStderrFd); FStderrFd := -1;
    end;
end;

function TShellRunner.Start: Boolean;
var
  StdinP, StdoutP, StderrP: TFilDes;
  PID: TPid;
  cmdA, pathA, shellA, dashC: AnsiString;
  Argv: array [0 .. 3] of PAnsiChar;
begin
  Result := False;
  FLastError := '';
  if FRunning then
    begin
      FLastError := 'process already running'; Exit;
    end;
  if FpPipe(StdinP) <> 0 then
    begin
      FLastError := 'pipe(stdin) failed: ' + IntToStr(fpgeterrno); Exit;
    end;
  if FpPipe(StdoutP) <> 0 then
    begin
      FpClose(StdinP[0]); FpClose(StdinP[1]);
      FLastError := 'pipe(stdout) failed: ' + IntToStr(fpgeterrno); Exit;
    end;
  if FpPipe(StderrP) <> 0 then
    begin
      FpClose(StdinP[0]); FpClose(StdinP[1]);
      FpClose(StdoutP[0]); FpClose(StdoutP[1]);
      FLastError := 'pipe(stderr) failed: ' + IntToStr(fpgeterrno); Exit;
    end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('Start pipes: stdin=[%d,%d] stdout=[%d,%d] stderr=[%d,%d]',
          [StdinP[0], StdinP[1], StdoutP[0], StdoutP[1], StderrP[0], StderrP[1]]));
    end;

  PID := FpFork;
  if PID < 0 then
    begin
      FpClose(StdinP[0]); FpClose(StdinP[1]);
      FpClose(StdoutP[0]); FpClose(StdoutP[1]);
      FpClose(StderrP[0]); FpClose(StderrP[1]);
      FLastError := 'fork failed: ' + IntToStr(fpgeterrno);
      Exit;
    end;
  if PID = 0 then
    begin
      if FHideWindow then FpSetsid;
      if FWorkPath.L > 0 then
        begin
          pathA := AnsiString(FWorkPath.Text);
          if FpChdir(PAnsiChar(pathA)) <> 0 then FpExit(127);
        end;
      FpDup2(StdinP[0], 0);
      FpDup2(StdoutP[1], 1);
      FpDup2(StderrP[1], 2);
      FpClose(StdinP[0]); FpClose(StdinP[1]);
      FpClose(StdoutP[0]); FpClose(StdoutP[1]);
      FpClose(StderrP[0]); FpClose(StderrP[1]);
      shellA := '/bin/sh';
      dashC := '-c';
      cmdA := AnsiString(FCommand.Text);
      Argv[0] := PAnsiChar(shellA);
      Argv[1] := PAnsiChar(dashC);
      Argv[2] := PAnsiChar(cmdA);
      Argv[3] := nil;
      FpExecv(PAnsiChar(shellA), PPAnsiChar(@Argv));
      FpExit(127);
    end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('Start: forked PID=%d', [PID]));
    end;
  FpClose(StdinP[0]);
  FpClose(StdoutP[1]);
  FpClose(StderrP[1]);
  FStdinFd := StdinP[1];
  FStdoutFd := StdoutP[0];
  FStderrFd := StderrP[0];
  FChildPID := PID;
  FRunning := True;
  FExitCode := 0;

  FStdOutThread := TShellReaderThread.Create(Self, False);
  FStdOutThread.FFd := FStdoutFd;
  try
    FStdOutThread.Start;
    if Enabled_ShellRunnerLog then
      begin
        SRLog(Format('Start: stdout reader started (fd=%d)', [FStdoutFd]));
      end;
  except
    on E: Exception do
      begin
        FLastError := 'reader thread start failed: ' + E.Message;
        if Enabled_ShellRunnerLog then
          begin
            SRLog(FLastError);
          end;
        DisposeObjectAndNil(FStdOutThread);
        FpKill(FChildPID, SIGKILL);
        FpWaitPid(FChildPID, nil, 0);
        CloseAllFds;
        FRunning := False;
        Exit;
      end;
  end;
  TThread.Sleep(C_ScheduleYieldMs);

  FStdErrThread := TShellReaderThread.Create(Self, True);
  FStdErrThread.FFd := FStderrFd;
  try
    FStdErrThread.Start;
    if Enabled_ShellRunnerLog then
      begin
        SRLog(Format('Start: stderr reader started (fd=%d)', [FStderrFd]));
      end;
  except
    on E: Exception do
      begin
        FLastError := 'reader thread start failed: ' + E.Message;
        if Enabled_ShellRunnerLog then
          begin
            SRLog(FLastError);
          end;
        DisposeObjectAndNil(FStdErrThread);
        FStdOutThread.Terminate;
        FStdOutThread.WaitJoin(C_ReaderJoinMs);
        DisposeObjectAndNil(FStdOutThread);
        FpKill(FChildPID, SIGKILL);
        FpWaitPid(FChildPID, nil, 0);
        CloseAllFds;
        FRunning := False;
        Exit;
      end;
  end;
  TThread.Sleep(C_ScheduleYieldMs);

  Result := True;
end;

function TShellRunner.WaitForExit(const TimeoutMs: Cardinal): Boolean;
var
  Status: cint;
  StartTick: TTimeTick;
  R: TPid;
begin
  if not FRunning then
    begin
      Result := True; Exit;
    end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog(Format('WaitForExit: waiting %d ms', [TimeoutMs]));
    end;
  StartTick := GetTimeTick;
  while True do
    begin
      R := FpWaitPid(FChildPID, Status, WNOHANG);
      if R = FChildPID then
        begin
          if WIFEXITED(Status) then FExitCode := Cardinal(WEXITSTATUS(Status))
          else if WIFSIGNALED(Status) then FExitCode := Cardinal(128 + WTERMSIG(Status))
          else FExitCode := 0;
          if Enabled_ShellRunnerLog then
            begin
              SRLog(Format('WaitForExit: child exited, code=%d', [FExitCode]));
            end;
          Break;
        end
      else if R < 0 then
        begin
          FLastError := 'waitpid failed: ' + IntToStr(fpgeterrno);
          if Enabled_ShellRunnerLog then
            begin
              SRLog(FLastError);
            end;
          Result := False;
          Exit;
        end;
      if TimeoutMs <> Cardinal($FFFFFFFF) then
        if (GetTimeTick - StartTick) >= TTimeTick(TimeoutMs) then
          begin
            FLastError := 'wait timeout';
            if Enabled_ShellRunnerLog then
              begin
                SRLog('WaitForExit: TIMEOUT');
              end;
            Result := False;
            Exit;
          end;
      TThread.Sleep(10);
    end;
  FRunning := False;

  if FStdOutThread <> nil then
    begin
      if Enabled_ShellRunnerLog then
        begin
          SRLog('WaitForExit: joining stdout reader');
        end;
      FStdOutThread.Terminate;
      if FStdOutThread.WaitJoin(C_ReaderJoinMs) then
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('WaitForExit: stdout reader joined OK');
            end;
          DisposeObjectAndNil(FStdOutThread);
          if FStdoutFd >= 0 then
            begin
              FpClose(FStdoutFd); FStdoutFd := -1;
            end;
        end
      else
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog(Format('[WARN] stdout reader did not exit in %d ms; retry in Destroy',
                  [C_ReaderJoinMs]));
            end;
        end;
    end;

  if FStdErrThread <> nil then
    begin
      if Enabled_ShellRunnerLog then
        begin
          SRLog('WaitForExit: joining stderr reader');
        end;
      FStdErrThread.Terminate;
      if FStdErrThread.WaitJoin(C_ReaderJoinMs) then
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('WaitForExit: stderr reader joined OK');
            end;
          DisposeObjectAndNil(FStdErrThread);
          if FStderrFd >= 0 then
            begin
              FpClose(FStderrFd); FStderrFd := -1;
            end;
        end
      else
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog(Format('[WARN] stderr reader did not exit in %d ms; retry in Destroy',
                  [C_ReaderJoinMs]));
            end;
        end;
    end;

  if Assigned(FOnExit) then
    try
        FOnExit(Self, FExitCode);
    except
      on E: Exception do
        begin
          if Enabled_ShellRunnerLog then
            begin
              SRLog('OnExit EXCEPTION: ' + E.Message);
            end;
        end;
    end;
  Result := True;
end;

function TShellRunner.Terminate: Boolean;
begin
  Result := False;
  if not FRunning then
    begin
      FLastError := 'process not running'; Exit;
    end;
  if Enabled_ShellRunnerLog then
    begin
      SRLog('Terminate: sending SIGTERM');
    end;
  if FpKill(FChildPID, SIGTERM) <> 0 then
    begin
      FLastError := 'kill(SIGTERM) failed: ' + IntToStr(fpgeterrno);
      if Enabled_ShellRunnerLog then
        begin
          SRLog(FLastError);
        end;
      Exit;
    end;
  Result := True;
end;

function TShellRunner.WriteStdin(const Data: RawByteString): Boolean;
var
  N, W: ssize_t;
  P: PAnsiChar;
begin
  Result := False;
  if not FRunning then
    begin
      FLastError := 'process not running'; Exit;
    end;
  if FStdinFd < 0 then
    begin
      FLastError := 'stdin already closed'; Exit;
    end;
  N := Length(Data);
  if N = 0 then
    begin
      Result := True; Exit;
    end;
  P := PAnsiChar(Data);
  while N > 0 do
    begin
      W := FpWrite(FStdinFd, P^, N);
      if W <= 0 then
        begin
          FLastError := 'write(stdin) failed: ' + IntToStr(fpgeterrno);
          if Enabled_ShellRunnerLog then
            begin
              SRLog(FLastError);
            end;
          Exit;
        end;
      Inc(P, W);
      Dec(N, W);
    end;
  Result := True;
end;

function TShellRunner.CloseStdin: Boolean;
begin
  if FStdinFd >= 0 then
    begin
      FpClose(FStdinFd); FStdinFd := -1;
    end;
  Result := True;
end;

function TShellRunner.SetWindowVisible(const Visible: Boolean): Boolean;
begin
  FLastError := 'SetWindowVisible is only supported on Windows';
  Result := False;
end;

{$ENDIF}{$ENDIF}{$ENDIF}

{$IFDEF Z_SHELL_UNSUPPORTED}


function TShellRunner.Start: Boolean;
begin
  FLastError := 'shell execution not supported on this platform'; Result := False;
end;

function TShellRunner.WaitForExit(const TimeoutMs: Cardinal): Boolean;
begin
  Result := True;
end;

function TShellRunner.Terminate: Boolean;
begin
  FLastError := 'shell execution not supported on this platform'; Result := False;
end;

function TShellRunner.WriteStdin(const Data: RawByteString): Boolean;
begin
  FLastError := 'shell execution not supported on this platform'; Result := False;
end;

function TShellRunner.CloseStdin: Boolean;
begin
  Result := False;
end;

function TShellRunner.SetWindowVisible(const Visible: Boolean): Boolean;
begin
  FLastError := 'shell execution not supported on this platform'; Result := False;
end;

{$ENDIF Z_SHELL_UNSUPPORTED}


function TShellRunner.WriteStdinLine(const Line: RawByteString): Boolean;
begin
  Result := WriteStdin(Line + #10);
end;

type
  TShellTestCollector = class
  public
    Lock: TCritical;
    StdOut: TStringList;
    StdErr: TStringList;
    ExitCode: Cardinal;
    GotExit: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure OnStdOut(Sender: TShellRunner;
      const Line: TPascalString; const IsError: Boolean);
    procedure OnStdErr(Sender: TShellRunner;
      const Line: TPascalString; const IsError: Boolean);
    procedure OnExitEvent(Sender: TShellRunner; const ExitCode: Cardinal);
    function HasStdOut(const S: String): Boolean;
    function HasStdErr(const S: String): Boolean;
  end;

constructor TShellTestCollector.Create;
begin
  inherited;
  Lock := TCritical.Create('TShellTestCollector');
  StdOut := TStringList.Create;
  StdErr := TStringList.Create;
  ExitCode := 0;
  GotExit := False;
end;

destructor TShellTestCollector.Destroy;
begin
  DisposeObjectAndNil(Lock);
  StdOut.Free;
  StdErr.Free;
  inherited;
end;

procedure TShellTestCollector.OnStdOut(Sender: TShellRunner;
  const Line: TPascalString; const IsError: Boolean);
begin
  if Enabled_ShellRunnerLog then
    begin
      if Sender <> nil then
          Sender.SRLog(Format('Collector.OnStdOut line="%s" len=%d',
            [Line.Text, Line.L]));
    end;
  Lock.Acquire;
  try StdOut.Add(Line.Text);
  finally Lock.Release;
  end;
end;

procedure TShellTestCollector.OnStdErr(Sender: TShellRunner;
  const Line: TPascalString; const IsError: Boolean);
begin
  if Enabled_ShellRunnerLog then
    begin
      if Sender <> nil then
          Sender.SRLog(Format('Collector.OnStdErr line="%s" len=%d',
            [Line.Text, Line.L]));
    end;
  Lock.Acquire;
  try StdErr.Add(Line.Text);
  finally Lock.Release;
  end;
end;

procedure TShellTestCollector.OnExitEvent(Sender: TShellRunner;
  const ExitCode: Cardinal);
begin
  if Enabled_ShellRunnerLog then
    begin
      if Sender <> nil then
          Sender.SRLog(Format('Collector.OnExit code=%d', [ExitCode]));
    end;
  Self.ExitCode := ExitCode;
  Self.GotExit := True;
end;

function TShellTestCollector.HasStdOut(const S: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  Lock.Acquire;
  try
    for I := 0 to StdOut.Count - 1 do
      if Pos(S, StdOut[I]) > 0 then
        begin
          Result := True; Break;
        end;
  finally Lock.Release;
  end;
end;

function TShellTestCollector.HasStdErr(const S: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  Lock.Acquire;
  try
    for I := 0 to StdErr.Count - 1 do
      if Pos(S, StdErr[I]) > 0 then
        begin
          Result := True; Break;
        end;
  finally Lock.Release;
  end;
end;

var
  G_TestPassCount: Integer = 0;
  G_TestFailCount: Integer = 0;

procedure ShellTestCheck(Logger: TShellRunner;
  const Name: string; const Ok: Boolean);
begin
  if Ok then
    begin
      Inc(G_TestPassCount);
      if Enabled_ShellRunnerLog then
        begin
          if Logger <> nil then
              Logger.SRLog(Format('[TEST %s] PASS', [Name]));
        end;
    end
  else
    begin
      Inc(G_TestFailCount);
      if Enabled_ShellRunnerLog then
        begin
          if Logger <> nil then
              Logger.SRLog(Format('[TEST %s] FAIL', [Name]));
        end;
    end;
end;

function Cmd_EchoHello: TPascalString;
begin
{$IFDEF MSWINDOWS}
  Result := 'cmd /c echo hello_runner';
{$ELSE}
  Result := 'echo hello_runner';
{$ENDIF}
end;

function Cmd_Exit42: TPascalString;
begin
{$IFDEF MSWINDOWS}
  Result := 'cmd /c exit 42';
{$ELSE}
  Result := 'exit 42';
{$ENDIF}
end;

function Cmd_ErrOutput: TPascalString;
begin
{$IFDEF MSWINDOWS}
  Result := 'cmd /c "echo error_output 1>&2"';
{$ELSE}
  Result := 'echo error_output 1>&2';
{$ENDIF}
end;

function Cmd_StdinSink: TPascalString;
{$IFDEF MSWINDOWS}
var
  sysDir: array [0 .. MAX_PATH] of Char;
  N: DWORD;
  I: Integer;
  S: string;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  N := GetSystemDirectory(sysDir, MAX_PATH);
  if N > 0 then
    begin
      SetLength(S, N);
      for I := 0 to N - 1 do
          S[I + 1] := sysDir[I];
      Result := TPascalString(S + '\sort.exe');
    end
  else
      Result := 'sort.exe';
{$ELSE}
  Result := 'cat';
{$ENDIF}
end;

function Cmd_LongSleep: TPascalString;
begin
{$IFDEF MSWINDOWS}
  Result := 'cmd /c pause';
{$ELSE}
  Result := 'sleep 10';
{$ENDIF}
end;

function Cmd_ChineseEcho: TPascalString;
begin
{$IFDEF FPC}
  // GBK bytes for the Chinese test string.
  Result := 'cmd /c echo '#$D6#$D0#$CE#$C4#$B2#$E2#$CA#$D4;
{$ELSE}
  Result := 'cmd /c echo 中文测试';
{$ENDIF}
end;

function ShellTestRunOnce(const Name, Cmd: TPascalString;
  const TimeoutMs: Cardinal): TShellTestCollector;
var
  LocalResult: TShellTestCollector;
  Runner: TShellRunner;
  ReleaseOnExit: Boolean;
begin
  Result := nil;
  LocalResult := TShellTestCollector.Create;
  Runner := TShellRunner.Create(Cmd, '');
  ReleaseOnExit := False;
  try
    if Enabled_ShellRunnerLog then
      begin
        Runner.SRLog(Format('===== BEGIN test "%s" cmd="%s" timeout=%d =====',
            [Name.Text, Cmd.Text, TimeoutMs]));
      end;

    Runner.AutoShowStdOut := False;
    Runner.AutoShowStdErr := False;
    Runner.OnStdOutLine := LocalResult.OnStdOut;
    Runner.OnStdErrLine := LocalResult.OnStdErr;
    Runner.OnExit := LocalResult.OnExitEvent;
    if not Runner.Start then
      begin
        if Enabled_ShellRunnerLog then
          begin
            Runner.SRLog(Format('[TEST %s] start failed: %s',
                [Name.Text, Runner.LastError]));
            Runner.SRLog(Format('===== END test "%s" (start failed) =====',
                [Name.Text]));
          end;
        ReleaseOnExit := True;
        Exit;
      end;
    if not Runner.WaitForExit(TimeoutMs) then
      begin
        if Enabled_ShellRunnerLog then
          begin
            Runner.SRLog(Format('[TEST %s] wait failed: %s',
                [Name.Text, Runner.LastError]));
          end;
        Runner.Terminate;
        if not Runner.WaitForExit(2000) then
          begin
            if Enabled_ShellRunnerLog then
              begin
                Runner.SRLog(Format('===== END test "%s" (wait failed, leaked) =====',
                    [Name.Text]));
              end;
            Exit;
          end;
        ReleaseOnExit := True;
        if Enabled_ShellRunnerLog then
          begin
            Runner.SRLog(Format('===== END test "%s" (wait failed after terminate) =====',
                [Name.Text]));
          end;
        Exit;
      end;
    Result := LocalResult;
    LocalResult := nil;
    if Enabled_ShellRunnerLog then
      begin
        Runner.SRLog(Format('===== END test "%s" (success, exit=%d) =====',
            [Name.Text, Result.ExitCode]));
      end;
  finally
    Runner.Free;
    if (LocalResult <> nil) and ReleaseOnExit then
        DisposeObjectAndNil(LocalResult);
  end;
end;

function RunShellRunnerSelfTest: Boolean;
var
  c: TShellTestCollector;
  R: TShellRunner;
  TestLogger: TShellRunner;
  Ok: Boolean;
  encTest: Boolean;
begin
  TestLogger := TShellRunner.Create('', '');

  G_TestPassCount := 0;
  G_TestFailCount := 0;

  encTest :=
    (DetectTextEncoding('hello') = teASCII) and
    (DetectTextEncoding(#$C4#$E3#$BA#$C3) = teGBK) and
    (DetectTextEncoding(#$E4#$BD#$A0#$E5#$A5#$BD) = teUTF8) and
    (DetectTextEncoding(#$FF#$FF#$FF) = teLatin1);

  ShellTestCheck(TestLogger, 'detect_encoding', encTest);

  if not IsShellRunnerSupported then
    begin
      if Enabled_ShellRunnerLog then
        begin
          TestLogger.SRLog('[TEST] ShellRunner not supported on this platform; skipping shell tests');
        end;
      Result := encTest;
      DisposeObjectAndNil(TestLogger);
      Exit;
    end;

  c := ShellTestRunOnce('basic_echo', Cmd_EchoHello, 5000);
  if c <> nil then
    begin
      ShellTestCheck(TestLogger, 'basic_echo.stdout', c.HasStdOut('hello_runner'));
      ShellTestCheck(TestLogger, 'basic_echo.exit0', (c.ExitCode = 0) and c.GotExit);
      DisposeObjectAndNil(c);
    end
  else
      ShellTestCheck(TestLogger, 'basic_echo', False);

  c := ShellTestRunOnce('exit_code', Cmd_Exit42, 5000);
  if c <> nil then
    begin
      ShellTestCheck(TestLogger, 'exit_code.exit42', c.ExitCode = 42);
      DisposeObjectAndNil(c);
    end
  else
      ShellTestCheck(TestLogger, 'exit_code', False);

  c := ShellTestRunOnce('stderr', Cmd_ErrOutput, 5000);
  if c <> nil then
    begin
      ShellTestCheck(TestLogger, 'stderr.captured', c.HasStdErr('error_output'));
      DisposeObjectAndNil(c);
    end
  else
      ShellTestCheck(TestLogger, 'stderr', False);

  c := ShellTestRunOnce('chinese_echo', Cmd_ChineseEcho, 5000);
  if c <> nil then
    begin
      ShellTestCheck(TestLogger, 'chinese_echo.captured', c.StdOut.Count > 0);
      DisposeObjectAndNil(c);
    end
  else
      ShellTestCheck(TestLogger, 'chinese_echo', False);

  c := TShellTestCollector.Create;
  R := TShellRunner.Create(Cmd_StdinSink, '');
  try
    R.AutoShowStdOut := False;
    R.AutoShowStdErr := False;
    R.OnStdOutLine := c.OnStdOut;
    R.OnStdErrLine := c.OnStdErr;
    R.OnExit := c.OnExitEvent;
    if R.Start then
      begin
        R.WriteStdinLine('piped_input');
        R.CloseStdin;
        if R.WaitForExit(5000) then
            ShellTestCheck(TestLogger, 'stdin.echo', c.HasStdOut('piped_input'))
        else
          begin
            ShellTestCheck(TestLogger, 'stdin.wait', False);
            R.Terminate;
            if not R.WaitForExit(3000) then
                c := nil;
          end;
      end
    else
        ShellTestCheck(TestLogger, 'stdin.start', False);
  finally
    R.Free;
    if c <> nil then
        c.Free;
  end;

  R := TShellRunner.Create(Cmd_LongSleep, '');
  try
    R.AutoShowStdOut := False;
    R.AutoShowStdErr := False;
    if R.Start then
      begin
        ShellTestCheck(TestLogger, 'timeout.short', not R.WaitForExit(300));
        R.Terminate;
        R.WaitForExit(3000);
      end
    else
        ShellTestCheck(TestLogger, 'timeout.start', False);
  finally
      R.Free;
  end;

  R := TShellRunner.Create(Cmd_LongSleep, '');
  try
    R.AutoShowStdOut := False;
    R.AutoShowStdErr := False;
    if R.Start then
      begin
        TThread.Sleep(200);
        ShellTestCheck(TestLogger, 'terminate.called', R.Terminate);
        ShellTestCheck(TestLogger, 'terminate.exited', R.WaitForExit(3000));
      end
    else
        ShellTestCheck(TestLogger, 'terminate.start', False);
  finally
      R.Free;
  end;

{$IFDEF MSWINDOWS}
  Ok := True;
{$ELSE}
  Ok := False;
  R := TShellRunner.Create(Cmd_LongSleep, '');
  try
    if R.Start then
      begin
        Ok := not R.SetWindowVisible(True);
        R.Terminate;
        R.WaitForExit(3000);
      end;
  finally
      R.Free;
  end;
{$ENDIF}
  ShellTestCheck(TestLogger, 'setvisible.unsupported', Ok);

  if Enabled_ShellRunnerLog then
    begin
      TestLogger.SRLog(Format('[TEST SUMMARY] pass=%d fail=%d',
          [G_TestPassCount, G_TestFailCount]));
    end;

  Result := G_TestFailCount = 0;
  DisposeObjectAndNil(TestLogger);
end;

initialization

{$IFDEF UNIX}{$IFNDEF ANDROID}{$IFNDEF IOS}
  FpSignal(SIGPIPE, signalhandler_t(SIG_IGN));
{$ENDIF}{$ENDIF}{$ENDIF}


end.
 
