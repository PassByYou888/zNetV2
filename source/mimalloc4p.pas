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
{ * mimalloc4p – Pascal binding for the mimalloc memory allocator
  * =============================================================
  *
  * This unit replaces the default memory manager (Delphi or FPC) with
  * Microsoft's mimalloc – a fast, scalable, thread-safe allocator.
  *
  * --------------------------------------------------------------------------
  * How to obtain the native mimalloc library
  * --------------------------------------------------------------------------
  * Prebuilt binaries for all supported platforms are published here:
  *
  *     https://github.com/microsoft/mimalloc/releases
  *
  * Pick the asset that matches your target OS / CPU / ABI, then deploy the
  * native library so that the OS loader can find it at runtime.
  *
  * --- Windows (prebuilt, recommended) --------------------------------------
  *   Assets:
  *     mimalloc-vX.Y.Z-win-x64.zip   -> contains mimalloc.dll
  *     mimalloc-vX.Y.Z-win-x86.zip   -> contains mimalloc.dll
  *
  *   This unit loads the library by these names:
  *     WIN32 -> 'mimalloc32.dll'
  *     WIN64 -> 'mimalloc64.dll'
  *
  *   Rename the DLL and drop it next to the EXE:
  *     :: 32-bit EXE
  *     ren mimalloc.dll mimalloc32.dll
  *     copy mimalloc32.dll  C:\path\to\myapp\
  *
  *     :: 64-bit EXE
  *     ren mimalloc.dll mimalloc64.dll
  *     copy mimalloc64.dll  C:\path\to\myapp\
  *
  *   Windows searches the EXE directory first, so no PATH change is needed.
  *   Do NOT copy the DLL into System32 – it would pollute other processes.
  *
  * --- Linux (prebuilt) ----------------------------------------------------
  *   Asset:
  *     mimalloc-vX.Y.Z-linux-x64.tar.gz
  *
  *   This unit loads the library by the name 'libmimalloc.so'.
  *
  *   Install system-wide:
  *     tar -xzf mimalloc-vX.Y.Z-linux-x64.tar.gz
  *     cd mimalloc-vX.Y.Z-linux-x64
  *     sudo cp -a lib/libmimalloc.so* /usr/local/lib/
  *     sudo ldconfig
  *   Or keep it local and export LD_LIBRARY_PATH at runtime instead.
  *
  * --- macOS (prebuilt) ----------------------------------------------------
  *   Asset:
  *     mimalloc-vX.Y.Z-macos-arm64.tar.gz / -x64.tar.gz
  *
  *   This unit loads the library by the name 'libmimalloc.dylib'.
  *   sudo cp -a lib/libmimalloc.dylib /usr/local/lib/
  *
  * --------------------------------------------------------------------------
  * Design notes
  * --------------------------------------------------------------------------
  *   - Each user allocation reserves HEADER_SIZE (16) bytes in front of the
  *     user pointer. The first PtrUInt field of that header stores the exact
  *     user-requested size, so MemSize does not depend on allocator internals.
  *   - ReallocMem is safe on failure: the original pointer stays valid.
  *   - FPC requires non-nil InitThread/DoneThread callbacks for TLS; stubs
  *     are provided so multi-threaded code does not crash.
  *
  * --------------------------------------------------------------------------
  * Usage (automatic – just add this unit to the uses clause)
  * --------------------------------------------------------------------------
  *   uses mimalloc4p;
  *
  *   var P: Pointer;
  *   begin
  *     GetMem(P, 1024);   // allocated by mi_malloc with a 16-byte header
  *     FreeMem(P);        // mi_free is called
  *   end;
  *
  * This unit is part of the Z-framework and is maintained at:
  *   https://github.com/PassByYou888/mimalloc4p
}
unit mimalloc4p;

{$I Z.Define.inc}
{$POINTERMATH ON}   // Allow pointer arithmetic (e.g. P + HEADER_SIZE)
{$INLINE ON}        // Inline small helper functions

interface

implementation

const
  // Native mimalloc library name, chosen per platform.
  // Must match the deployed file name exactly.
{$IF Defined(WIN32)}
  mimalloc_Lib = 'mimalloc32.dll';
{$ELSEIF Defined(WIN64)}
  mimalloc_Lib = 'mimalloc64.dll';
{$ELSEIF Defined(LINUX)}
  mimalloc_Lib = 'libmimalloc.so';
{$ELSEIF Defined(DARWIN)}
  mimalloc_Lib = 'libmimalloc.dylib';
{$ELSE}
{$MESSAGE FATAL 'Unsupported platform'}
{$IFEND}

  // Bytes reserved in front of every user pointer.
  // The first PtrUInt of this header stores the exact user-requested size,
  // so MemSize does not rely on mimalloc's internal usable-size metadata.
  HEADER_SIZE = 16;

  // --- Core mimalloc functions (cdecl) -------------------------------------

  // mi_malloc: allocates Size bytes; returns nil on failure.
function mi_malloc(Size: NativeUInt): Pointer; cdecl; external mimalloc_Lib name 'mi_malloc';

// mi_free: releases a block obtained from mi_malloc / mi_calloc / mi_realloc.
// Passing nil is a no-op.
procedure mi_free(P: Pointer); cdecl; external mimalloc_Lib name 'mi_free';

// mi_realloc: resizes a block. If P is nil it behaves like mi_malloc;
// if Size is 0 it frees and returns nil.
// On failure it returns nil and the original block stays valid.
function mi_realloc(P: Pointer; Size: NativeUInt): Pointer; cdecl; external mimalloc_Lib name 'mi_realloc';

// mi_calloc: allocates Count * Size zero-initialised bytes; nil on failure.
function mi_calloc(Count: NativeUInt; Size: NativeUInt): Pointer; cdecl; external mimalloc_Lib name 'mi_calloc';

// --- Header helpers -------------------------------------------------------

type
  // Type stored in the header: a pointer-sized unsigned integer.
{$IFDEF FPC}
  TSize__ = PtrUInt;
{$ELSE FPC}
  TSize__ = NativeUInt;
{$ENDIF FPC}
  PSize__ = ^TSize__;

// Reads the user-requested size from the 16-byte header.
function GetStoredSize(RawPtr: Pointer): TSize__; inline;
begin
  Result := PSize__(RawPtr)^;
end;

// Writes the user-requested size into the 16-byte header.
procedure SetStoredSize(RawPtr: Pointer; Size: TSize__); inline;
begin
  PSize__(RawPtr)^ := Size;
end;

// --- Memory manager hooks -------------------------------------------------

{$IFDEF FPC}

var
  OriginMM: TMemoryManager; // original manager, restored on finalization
  HookMM: TMemoryManager;   // manager installed by this unit

// do_GetMem: allocates Size bytes via mi_malloc with a 16-byte header.
// Returns user pointer (raw + HEADER_SIZE), or nil on failure.
function do_GetMem(Size: PtrUInt): Pointer;
var
  RawPtr: Pointer;
begin
  RawPtr := mi_malloc(Size + HEADER_SIZE);
  if RawPtr <> nil then
    begin
      SetStoredSize(RawPtr, Size);
      Result := RawPtr + HEADER_SIZE;
    end
  else
      Result := nil;
end;

// do_FreeMem: releases a block previously returned by do_GetMem.
// FPC expects a PtrUInt return code; 0 means success.
function do_FreeMem(P: Pointer): PtrUInt;
var
  RawPtr: Pointer;
begin
  if P <> nil then
    begin
      RawPtr := P - HEADER_SIZE;
      mi_free(RawPtr);
    end;
  Result := 0;
end;

// do_FreememSize: same as do_FreeMem; mimalloc knows the block size
// internally so the Size argument is ignored.
function do_FreememSize(P: Pointer; Size: PtrUInt): PtrUInt;
begin
  Result := do_FreeMem(P);
end;

// do_AllocMem: zero-initialised allocation via mi_calloc.
function do_AllocMem(Size: PtrUInt): Pointer;
var
  RawPtr: Pointer;
begin
  RawPtr := mi_calloc(1, Size + HEADER_SIZE);
  if RawPtr <> nil then
    begin
      SetStoredSize(RawPtr, Size);
      Result := RawPtr + HEADER_SIZE;
    end
  else
      Result := nil;
end;

// do_ReallocMem: resizes a block.
// Size = 0  -> frees and sets P := nil.
// P = nil   -> allocates a fresh block.
// On failure, P is left unchanged (safe behaviour).
function do_ReallocMem(var P: Pointer; Size: PtrUInt): Pointer;
var
  RawPtr, NewRawPtr: Pointer;
begin
  if Size = 0 then
    begin
      if P <> nil then
        begin
          RawPtr := P - HEADER_SIZE;
          mi_free(RawPtr);
          P := nil;
        end;
      Exit(nil);
    end;

  if P = nil then
    begin
      RawPtr := mi_malloc(Size + HEADER_SIZE);
      if RawPtr <> nil then
        begin
          SetStoredSize(RawPtr, Size);
          P := RawPtr + HEADER_SIZE;
        end;
      Exit(P);
    end;

  RawPtr := P - HEADER_SIZE;
  NewRawPtr := mi_realloc(RawPtr, Size + HEADER_SIZE);
  if NewRawPtr <> nil then
    begin
      SetStoredSize(NewRawPtr, Size);
      P := NewRawPtr + HEADER_SIZE;
    end;
  Result := P;
end;

// do_MemSize: returns the exact user-requested size stored in the header.
function do_MemSize(P: Pointer): PtrUInt;
begin
  if P = nil then
      Exit(0);
  Result := GetStoredSize(P - HEADER_SIZE);
end;

// do_GetHeapStatus / do_GetFPCHeapStatus: mimalloc exposes its own stats API,
// which is not wired into these FPC hooks. Return zeroed records.
function do_GetHeapStatus: THeapStatus;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

function do_GetFPCHeapStatus: TFPCHeapStatus;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

// FPC requires non-nil InitThread/DoneThread for TLS setup; stubs suffice.
procedure DummyInitThread;
begin
end;

procedure DummyDoneThread;
begin
end;

// InstallMemoryHook: replaces the default memory manager with our hooks.
procedure InstallMemoryHook;
const
  C_: TMemoryManager = (
    NeedLock: False;
    GetMem: @do_GetMem;
    FreeMem: @do_FreeMem;
    FreeMemSize: @do_FreememSize;
    AllocMem: @do_AllocMem;
    ReallocMem: @do_ReallocMem;
    MemSize: @do_MemSize;
    InitThread: @DummyInitThread;
    DoneThread: @DummyDoneThread;
    RelocateHeap: nil;
    GetHeapStatus: @do_GetHeapStatus;
    GetFPCHeapStatus: @do_GetFPCHeapStatus;
  );
begin
  GetMemoryManager(OriginMM);
  HookMM := C_;
  SetMemoryManager(HookMM);
end;

// UnInstallMemoryHook: restores the original memory manager.
procedure UnInstallMemoryHook;
begin
  SetMemoryManager(OriginMM);
end;

{$ELSE}  // Delphi

var
  OriginMM: TMemoryManagerEx;
  HookMM: TMemoryManagerEx;

// do_GetMem: allocates Size bytes via mi_malloc with a 16-byte header.
function do_GetMem(Size: NativeInt): Pointer;
var
  RawPtr: Pointer;
begin
  RawPtr := mi_malloc(Size + HEADER_SIZE);
  if RawPtr <> nil then
    begin
      SetStoredSize(RawPtr, Size);
      Result := Pointer(NativeUInt(RawPtr) + HEADER_SIZE);
    end
  else
      Result := nil;
end;

// do_FreeMem: releases a block previously returned by do_GetMem.
function do_FreeMem(P: Pointer): Integer;
var
  RawPtr: Pointer;
begin
  if P <> nil then
    begin
      RawPtr := Pointer(NativeUInt(P) - HEADER_SIZE);
      mi_free(RawPtr);
    end;
  Result := 0;
end;

// do_ReallocMem: resizes a block.
// On failure, the original block stays valid; returns nil.
function do_ReallocMem(P: Pointer; Size: NativeInt): Pointer;
var
  RawPtr, NewRawPtr: Pointer;
begin
  if Size = 0 then
    begin
      if P <> nil then
        begin
          RawPtr := Pointer(NativeUInt(P) - HEADER_SIZE);
          mi_free(RawPtr);
        end;
      Exit(nil);
    end;

  if P = nil then
    begin
      RawPtr := mi_malloc(Size + HEADER_SIZE);
      if RawPtr <> nil then
        begin
          SetStoredSize(RawPtr, Size);
          Result := Pointer(NativeUInt(RawPtr) + HEADER_SIZE);
        end
      else
          Result := nil;
      Exit;
    end;

  RawPtr := Pointer(NativeUInt(P) - HEADER_SIZE);
  NewRawPtr := mi_realloc(RawPtr, Size + HEADER_SIZE);
  if NewRawPtr <> nil then
    begin
      SetStoredSize(NewRawPtr, Size);
      Result := Pointer(NativeUInt(NewRawPtr) + HEADER_SIZE);
    end
  else
      Result := nil;
end;

// do_AllocMem: zero-initialised allocation via mi_calloc.
function do_AllocMem(Size: NativeInt): Pointer;
var
  RawPtr: Pointer;
begin
  RawPtr := mi_calloc(1, Size + HEADER_SIZE);
  if RawPtr <> nil then
    begin
      SetStoredSize(RawPtr, Size);
      Result := Pointer(NativeUInt(RawPtr) + HEADER_SIZE);
    end
  else
      Result := nil;
end;

// Delphi's memory-leak tracking hooks are not implemented; return False.
function do_RegisterExpectedMemoryLeak(P: Pointer): Boolean;
begin
  Result := False;
end;

function do_UnregisterExpectedMemoryLeak(P: Pointer): Boolean;
begin
  Result := False;
end;

// InstallMemoryHook: replaces the default memory manager with our hooks.
procedure InstallMemoryHook;
const
  C_: TMemoryManagerEx = (
    GetMem: do_GetMem;
    FreeMem: do_FreeMem;
    ReallocMem: do_ReallocMem;
    AllocMem: do_AllocMem;
    RegisterExpectedMemoryLeak: do_RegisterExpectedMemoryLeak;
    UnregisterExpectedMemoryLeak: do_UnregisterExpectedMemoryLeak;
  );
begin
  GetMemoryManager(OriginMM);
  HookMM := C_;
  SetMemoryManager(HookMM);
end;

// UnInstallMemoryHook: restores the original memory manager.
procedure UnInstallMemoryHook;
begin
  SetMemoryManager(OriginMM);
end;

{$ENDIF}

initialization

InstallMemoryHook; // replace default memory manager on unit load

finalization

UnInstallMemoryHook; // restore original manager on unit unload

end.
 
