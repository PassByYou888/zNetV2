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
(*
  ******************************************************************************
  * Z.Pascal_Func_Tool
  *
  * Extracts structural metadata from Pascal source files: unit name,
  * interface/implementation sections, init/finalization blocks, and all
  * function/procedure declarations including parameters, return types,
  * calling conventions, external linkage, and explicit name/index clauses.
  *
  * Built on Z.Parsing token streams, it scans without manual lexing of
  * comments or string literals. Results are stored in tfunc_decl records
  * suitable for code analysis, documentation generation, or refactoring.
  *
  * Keywords are sourced from Z.Pascal_Code_Tool to avoid hard-coded strings.
  *
  * --------------------------------------------------------------------------
  * Key features:
  *   - Silent error handling: invalid syntax is logged, ErrorOccurred set,
  *     ParseSuccess=False; no RaiseInfo exceptions.
  *   - Debug logging controlled by Pascal_Func_Tool_Log_Enabled (default True).
  *   - NestLevel field tracks declaration depth (0 = top-level, >0 inside
  *     class/record/interface).
  *   - Structured parameter extraction via tfunc_param_tool.
  *   - JSON serialization/deserialization of the entire parsed result.
  *
  * --------------------------------------------------------------------------
  * History:
  *   Original author qq600585 (circa 2012). The token-stream scanning and
  *   semantic probing design was pioneering. Modernised with AI assistance
  *   for naming, comments, and error handling. Thanks to the original author.
  ******************************************************************************
*)
unit sec.Pascal_Func_Tool;

{$DEFINE FPC_DELPHI_MODE}
{$I ..\Z.Define.inc}

interface

uses
  TypInfo,
{$IFDEF FPC}
  sec.FPC.GenericList, fgl,
{$ENDIF FPC}
  sec.Core, sec.PascalStrings, sec.UPascalStrings, sec.UnicodeMixedLib, sec.Status, sec.Parsing, sec.ListEngine, sec.Pascal_Code_Tool, sec.UReplace, sec.Json;

type
  pfunc_decl = ^tfunc_decl;

  tfunc_param_decl = record
    param_mod: TP_String;
    param_name: TP_String;
    param_typ: TP_String;
    param_value: TP_String;
    { Array suffix preserved from C declarators such as 'int buf[]'.
      Stored separately so that the base type stays a simple identifier
      that both decl_to_pascal and decl_to_c can handle. Empty for
      non-array parameters. }
    param_array: TP_String;
    procedure reset;
  end;

  tfunc_param_arry = array of tfunc_param_decl;

  tfunc_decl = record
    Body: TP_String;
    IsProc: boolean;
    BPos, EPos: integer;
    Name: TP_String;
    IsFunction: boolean;
    ParamDecl: TP_String;
    param_arry: tfunc_param_arry;
    ResultDecl: TP_String;
    { Return-type qualifier preserved from C. Currently only 'const' is captured (e.g. 'const char * get_error_message(int)').
      Empty for unqualified return types. decl_to_c prepends 'const ' before the converted C type when this field equals 'const'. }
    ResultMod: TP_String;
    CallConv: TP_String;
    IsExternal: boolean;
    ExternalLibrary: TP_String;
    HasExplicitName: boolean;
    ExplicitName: TP_String;
    HasExplicitIndex: boolean;
    ExplicitIndex: TP_String;
    Index: integer;
    Comment: TP_String;
    NestLevel: integer;
    procedure Init;
    procedure Free;
  end;

  TFuncDeclList = class(TBigList<pfunc_decl>)
  public
    procedure DoFree(var Data: pfunc_decl); override;
  end;

  tpascal_func_decl_tool = class(TCore_Object_Intermediate)
  public
    Parser: TTextParsing;
    FuncList: TFuncDeclList;
    UsesList: TPascalStringList;
    UnitName: TP_String;
    UnitToken: pfunc_decl;
    InterfaceToken: pfunc_decl;
    ImplementationToken: pfunc_decl;
    EndToken: pfunc_decl;
    InitToken: pfunc_decl;
    FinalToken: pfunc_decl;
    ParseSuccess: boolean;

    constructor Create; overload;
    destructor Destroy; override;

    class function CreateFrom_Pascal_Code(AText: TP_String): tpascal_func_decl_tool;
    procedure Fill_Pascal;

    class function CreateFrom_C_Code(AText: TP_String): tpascal_func_decl_tool;
    procedure Fill_C;
    procedure Translate_C_Typ_To_Pascal;

    procedure Clear;
    function Combine(const BTokenIdx, ETokenIdx: integer): TP_String;

    // JSON serialization
    function SaveToJson: TP_String;
    procedure LoadFromJson(const JsonStr: TP_String);

    function decl_to_pascal(Report: TPascalStringList): TP_String;
    function decl_to_c(Report: TPascalStringList): TP_String;
  end;

var
  Pascal_Func_Tool_Log_Enabled: boolean = False;

implementation

{ ------------------------------------------------------------------------------
  tfunc_param_decl.reset
  ------------------------------------------------------------------------------ }
procedure tfunc_param_decl.reset;
begin
  param_mod := '';
  param_name := '';
  param_typ := '';
  param_value := '';
  param_array := '';
end;

{ ------------------------------------------------------------------------------
  tfunc_decl.Init
  ------------------------------------------------------------------------------ }
procedure tfunc_decl.Init;
begin
  Body := '';
  IsProc := False;
  BPos := -1;
  EPos := -1;
  Name := '';
  IsFunction := False;
  ParamDecl := '';
  SetLength(param_arry, 0);
  ResultDecl := '';
  ResultMod := '';
  CallConv := '';
  IsExternal := False;
  ExternalLibrary := '';
  HasExplicitName := False;
  ExplicitName := '';
  HasExplicitIndex := False;
  ExplicitIndex := '';
  Index := 0;
  Comment := '';
  NestLevel := 0;
end;

{ ------------------------------------------------------------------------------
  tfunc_decl.Free
  ------------------------------------------------------------------------------ }
procedure tfunc_decl.Free;
var
  i: integer;
begin
  Body := '';
  IsProc := False;
  BPos := -1;
  EPos := -1;
  Name := '';
  IsFunction := False;
  ParamDecl := '';
  for i := 0 to Length(param_arry) - 1 do param_arry[i].reset;
  SetLength(param_arry, 0);
  ResultDecl := '';
  ResultMod := '';
  CallConv := '';
  IsExternal := False;
  ExternalLibrary := '';
  HasExplicitName := False;
  ExplicitName := '';
  HasExplicitIndex := False;
  ExplicitIndex := '';
  Index := 0;
  Comment := '';
  NestLevel := 0;
end;

{ ------------------------------------------------------------------------------
  TFuncDeclList.DoFree
  ------------------------------------------------------------------------------ }
procedure TFuncDeclList.DoFree(var Data: pfunc_decl);
begin
  if Data <> nil then
    begin
      Data^.Free;
      Dispose(Data);
      Data := nil;
    end;
  inherited;
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.Create
  ------------------------------------------------------------------------------ }
constructor tpascal_func_decl_tool.Create;
begin
  inherited Create;
  if Pascal_Func_Tool_Log_Enabled then
      DoStatus('[tpascal_func_decl_tool.Create] Starting parsing...');
  Parser := nil;
  FuncList := TFuncDeclList.Create;
  UsesList := TPascalStringList.Create;
  UnitName := '';
  UnitToken := nil;
  InterfaceToken := nil;
  ImplementationToken := nil;
  EndToken := nil;
  InitToken := nil;
  FinalToken := nil;
  ParseSuccess := False;
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.Destroy
  ------------------------------------------------------------------------------ }
destructor tpascal_func_decl_tool.Destroy;
begin
  Clear;
  DisposeObjectAndNil(FuncList);
  DisposeObjectAndNil(UsesList);
  DisposeObjectAndNil(Parser);
  inherited Destroy;
  if Pascal_Func_Tool_Log_Enabled then
      DoStatus('[tpascal_func_decl_tool.Destroy] Destroyed.');
end;

class function tpascal_func_decl_tool.CreateFrom_Pascal_Code(AText: TP_String): tpascal_func_decl_tool;
begin
  Result := tpascal_func_decl_tool.Create;
  Result.Parser := TTextParsing.Create(AText, tsPascal);
  Result.Fill_Pascal();
end;

{$I sec.Pascal_Func_Tool.Fill_Pascal.inc}


class function tpascal_func_decl_tool.CreateFrom_C_Code(AText: TP_String): tpascal_func_decl_tool;
begin
  Result := tpascal_func_decl_tool.Create;
  Result.Parser := TTextParsing.Create(AText, tsC);
  Result.Fill_C();
  Result.Translate_C_Typ_To_Pascal();
end;

{$I sec.Pascal_Func_Tool.Fill_C.inc}
{$I sec.Pascal_Func_Tool.Translate_C_Typ_To_Pascal.inc}

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.Clear
  ------------------------------------------------------------------------------ }
procedure tpascal_func_decl_tool.Clear;
begin
  FuncList.Clear;
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.Combine
  ------------------------------------------------------------------------------ }
function tpascal_func_decl_tool.Combine(const BTokenIdx, ETokenIdx: integer): TP_String;
var
  Lo, Hi: integer;
  It: TFuncDeclList.TRepeat___;
begin
  if BTokenIdx > ETokenIdx then
    begin
      Lo := ETokenIdx;
      Hi := BTokenIdx;
    end
  else
    begin
      Lo := BTokenIdx;
      Hi := ETokenIdx;
    end;

  Result := '';
  if (Lo >= 0) and (Hi < FuncList.Num) and (Lo <= Hi) then
    begin
      It := FuncList.repeat_(Lo, Hi);
      repeat
          Result.Append(It.queue^.Data^.Body);
      until not It.Next;
    end;
end;

{ ------------------------------------------------------------------------------
  JSON serialization helpers
  ------------------------------------------------------------------------------ }
function ParamDeclToJson(const p: tfunc_param_decl): TZ_JsonObject;
begin
  Result := TZ_JsonObject.Create;
  Result.S['mod'] := p.param_mod.Text;
  Result.S['name'] := p.param_name.Text;
  Result.S['typ'] := p.param_typ.Text;
  Result.S['value'] := p.param_value.Text;
  Result.S['array'] := p.param_array.Text;
end;

function JsonToParamDecl(const jo: TZ_JsonObject): tfunc_param_decl;
begin
  Result.reset;
  Result.param_mod := jo.S['mod'];
  Result.param_name := jo.S['name'];
  Result.param_typ := jo.S['typ'];
  Result.param_value := jo.S['value'];
  Result.param_array := jo.S['array'];
end;

procedure FuncDeclToJson(const f: tfunc_decl; const obj: TZ_JsonObject);
var
  arr: TZ_JsonArray;
  paramObj: TZ_JsonObject;
  i: integer;
begin
  obj.S['Body'] := f.Body.Text;
  obj.B['IsProc'] := f.IsProc;
  obj.S['Name'] := f.Name.Text;
  obj.B['IsFunction'] := f.IsFunction;
  obj.S['ParamDecl'] := f.ParamDecl.Text;

  arr := obj.A['param_arry'];
  for i := 0 to High(f.param_arry) do
    begin
      paramObj := arr.AddObject;
      paramObj.S['mod'] := f.param_arry[i].param_mod.Text;
      paramObj.S['name'] := f.param_arry[i].param_name.Text;
      paramObj.S['typ'] := f.param_arry[i].param_typ.Text;
      paramObj.S['value'] := f.param_arry[i].param_value.Text;
      paramObj.S['array'] := f.param_arry[i].param_array.Text;
    end;

  obj.S['ResultDecl'] := f.ResultDecl.Text;
  obj.S['ResultMod'] := f.ResultMod.Text;
  obj.S['CallConv'] := f.CallConv.Text;
  obj.B['IsExternal'] := f.IsExternal;
  obj.S['ExternalLibrary'] := f.ExternalLibrary.Text;
  obj.B['HasExplicitName'] := f.HasExplicitName;
  obj.S['ExplicitName'] := f.ExplicitName.Text;
  obj.B['HasExplicitIndex'] := f.HasExplicitIndex;
  obj.S['ExplicitIndex'] := f.ExplicitIndex.Text;
  obj.i['Index'] := f.Index;
  obj.S['Comment'] := f.Comment.Text;
  obj.i['NestLevel'] := f.NestLevel;
end;

procedure JsonToFuncDecl(const jo: TZ_JsonObject; var f: tfunc_decl);
var
  arr: TZ_JsonArray;
  i: integer;
begin
  f.Init;
  f.Body := jo.S['Body'];
  f.IsProc := jo.B['IsProc'];
  f.BPos := 0;
  f.EPos := 0;
  f.Name := jo.S['Name'];
  f.IsFunction := jo.B['IsFunction'];
  f.ParamDecl := jo.S['ParamDecl'];

  arr := jo.A['param_arry'];
  SetLength(f.param_arry, arr.Count);
  for i := 0 to arr.Count - 1 do
      f.param_arry[i] := JsonToParamDecl(arr.O[i]);

  f.ResultDecl := jo.S['ResultDecl'];
  f.ResultMod := jo.S['ResultMod'];
  f.CallConv := jo.S['CallConv'];
  f.IsExternal := jo.B['IsExternal'];
  f.ExternalLibrary := jo.S['ExternalLibrary'];
  f.HasExplicitName := jo.B['HasExplicitName'];
  f.ExplicitName := jo.S['ExplicitName'];
  f.HasExplicitIndex := jo.B['HasExplicitIndex'];
  f.ExplicitIndex := jo.S['ExplicitIndex'];
  f.Index := jo.i['Index'];
  f.Comment := jo.S['Comment'];
  f.NestLevel := jo.i['NestLevel'];
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.SaveToJson
  ------------------------------------------------------------------------------
  Saves all persistent fields of the tool to a JSON string.
  - UnitName, ParseSuccess, UsesList
  - Full FuncList (all tfunc_decl records, including structural markers)
  - Index of each structural token pointer (UnitToken, InterfaceToken, ...)
  in FuncList, or -1 if nil.
  Parser is not saved as it is a transient parsing object.
}
function tpascal_func_decl_tool.SaveToJson: TP_String;
var
  root: TZ_JsonObject;
  funcArr: TZ_JsonArray;
  usesArr: TZ_JsonArray;
  i: integer;
  Decl: pfunc_decl;

  // Helper to get index of a pfunc_decl in FuncList, or -1 if nil
  function GetDeclIndex(p: pfunc_decl): integer;
  var
    j: integer;
  begin
    Result := -1;
    if p = nil then exit;
    for j := 0 to FuncList.Count - 1 do
      if FuncList[j] = p then
          exit(j);
  end;

begin
  root := TZ_JsonObject.Create;
  try
    // Basic fields
    root.S['UnitName'] := UnitName.Text;
    root.B['ParseSuccess'] := ParseSuccess;

    // UsesList as array of strings
    usesArr := root.A['UsesList'];
    for i := 0 to UsesList.Count - 1 do
        usesArr.Add(UsesList[i].Text);

    // FuncList – all declarations, including structural markers
    funcArr := root.A['FuncList'];
    for i := 0 to FuncList.Count - 1 do
      begin
        Decl := FuncList[i];
        // Use existing FuncDeclToJson to serialize the tfunc_decl record
        FuncDeclToJson(Decl^, funcArr.AddObject);
      end;

    // Structural pointers – saved as indices into FuncList
    root.i['UnitTokenIndex'] := GetDeclIndex(UnitToken);
    root.i['InterfaceTokenIndex'] := GetDeclIndex(InterfaceToken);
    root.i['ImplementationTokenIndex'] := GetDeclIndex(ImplementationToken);
    root.i['EndTokenIndex'] := GetDeclIndex(EndToken);
    root.i['InitTokenIndex'] := GetDeclIndex(InitToken);
    root.i['FinalTokenIndex'] := GetDeclIndex(FinalToken);

    Result := root.ToJSONString(True);
  finally
      root.Free;
  end;
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.LoadFromJson
  ------------------------------------------------------------------------------
  Restores all persistent fields from a JSON string previously saved by
  SaveToJson. Rebuilds FuncList and re-establishes structural pointers
  using the stored indices.
}
procedure tpascal_func_decl_tool.LoadFromJson(const JsonStr: TP_String);
var
  root: TZ_JsonObject;
  funcArr: TZ_JsonArray;
  usesArr: TZ_JsonArray;
  i: integer;
  p: pfunc_decl;
  Idx: integer;
begin
  Clear; // clears FuncList and sets all pointers to nil
  root := TZ_JsonObject.Create;
  try
    root.ParseText(JsonStr);

    UnitName := root.S['UnitName'];
    ParseSuccess := root.B['ParseSuccess'];

    // Restore UsesList
    usesArr := root.A['UsesList'];
    for i := 0 to usesArr.Count - 1 do
        UsesList.Add(usesArr.S[i]);

    // Restore FuncList – each element is a tfunc_decl
    funcArr := root.A['FuncList'];
    for i := 0 to funcArr.Count - 1 do
      begin
        New(p);
        p^.Init;
        JsonToFuncDecl(funcArr.O[i], p^);
        FuncList.Add(p);
      end;

    // Restore structural pointers by index
    Idx := root.i['UnitTokenIndex'];
    if (Idx >= 0) and (Idx < FuncList.Count) then
        UnitToken := FuncList[Idx]
    else
        UnitToken := nil;

    Idx := root.i['InterfaceTokenIndex'];
    if (Idx >= 0) and (Idx < FuncList.Count) then
        InterfaceToken := FuncList[Idx]
    else
        InterfaceToken := nil;

    Idx := root.i['ImplementationTokenIndex'];
    if (Idx >= 0) and (Idx < FuncList.Count) then
        ImplementationToken := FuncList[Idx]
    else
        ImplementationToken := nil;

    Idx := root.i['EndTokenIndex'];
    if (Idx >= 0) and (Idx < FuncList.Count) then
        EndToken := FuncList[Idx]
    else
        EndToken := nil;

    Idx := root.i['InitTokenIndex'];
    if (Idx >= 0) and (Idx < FuncList.Count) then
        InitToken := FuncList[Idx]
    else
        InitToken := nil;

    Idx := root.i['FinalTokenIndex'];
    if (Idx >= 0) and (Idx < FuncList.Count) then
        FinalToken := FuncList[Idx]
    else
        FinalToken := nil;

  finally
      root.Free;
  end;
end;


{$I sec.Pascal_Func_Tool.decl_to_pascal.inc}
{$I sec.Pascal_Func_Tool.decl_to_c.inc}

end.
