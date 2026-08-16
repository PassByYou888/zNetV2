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
{ ****************************************************************************** }
{ * Low MemoryHook                                                             * }
{ ****************************************************************************** }
unit sec.MH;

{$I ..\Z.Define.inc}

interface

uses sec.Core, SyncObjs, sec.ListEngine;

procedure BeginMemoryHook_1;
procedure EndMemoryHook_1;
function GetHookMemorySize_1: nativeUInt;
function GetHookPtrList_1: TPointerHashNativeUIntList;

procedure BeginMemoryHook_2;
procedure EndMemoryHook_2;
function GetHookMemorySize_2: nativeUInt;
function GetHookPtrList_2: TPointerHashNativeUIntList;

procedure BeginMemoryHook_3;
procedure EndMemoryHook_3;
function GetHookMemorySize_3: nativeUInt;
function GetHookPtrList_3: TPointerHashNativeUIntList;

implementation

uses sec.MH_ZDB, sec.MH1, sec.MH2, sec.MH3, sec.Status, sec.PascalStrings, sec.UPascalStrings;

procedure BeginMemoryHook_1;
begin
  sec.MH1.BeginMemoryHook($FFFF);
end;

procedure EndMemoryHook_1;
begin
  sec.MH1.EndMemoryHook;
end;

function GetHookMemorySize_1: nativeUInt;
begin
  Result := sec.MH1.GetHookMemorySize;
end;

function GetHookPtrList_1: TPointerHashNativeUIntList;
begin
  Result := sec.MH1.GetHookPtrList;
end;

procedure BeginMemoryHook_2;
begin
  sec.MH2.BeginMemoryHook($FFFF);
end;

procedure EndMemoryHook_2;
begin
  sec.MH2.EndMemoryHook;
end;

function GetHookMemorySize_2: nativeUInt;
begin
  Result := sec.MH2.GetHookMemorySize;
end;

function GetHookPtrList_2: TPointerHashNativeUIntList;
begin
  Result := sec.MH2.GetHookPtrList;
end;

procedure BeginMemoryHook_3;
begin
  sec.MH3.BeginMemoryHook($FFFF);
end;

procedure EndMemoryHook_3;
begin
  sec.MH3.EndMemoryHook;
end;

function GetHookMemorySize_3: nativeUInt;
begin
  Result := sec.MH3.GetHookMemorySize;
end;

function GetHookPtrList_3: TPointerHashNativeUIntList;
begin
  Result := sec.MH3.GetHookPtrList;
end;

var
  MHStatusCritical: TCriticalSection;
  OriginDoStatusHook: TDoStatus_C;

procedure InternalDoStatus(Text: SystemString; const ID: Integer);
var
  hook_state_bak: Boolean;
begin
  hook_state_bak := GlobalMemoryHook.V;
  GlobalMemoryHook.V := False;
  MHStatusCritical.Acquire;
  try
      OriginDoStatusHook(Text, ID);
  finally
    MHStatusCritical.Release;
    GlobalMemoryHook.V := hook_state_bak;
  end;
end;

initialization

MHStatusCritical := TCriticalSection.Create;
OriginDoStatusHook := OnDoStatusHook;
OnDoStatusHook := {$IFDEF FPC}@{$ENDIF FPC}InternalDoStatus;

finalization

DisposeObject(MHStatusCritical);
OnDoStatusHook := OriginDoStatusHook;

end.
