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
  sec.Core,
  sec.PascalStrings,
  sec.UPascalStrings,
  sec.UnicodeMixedLib,
  sec.Status,
  sec.Parsing,
  sec.ListEngine,
  sec.Pascal_Code_Tool,
  sec.Json;

type
  pfunc_decl = ^tfunc_decl;

  tfunc_param_decl = record
    param_mod: TP_String;
    param_name: TP_String;
    param_typ: TP_String;
    param_value: TP_String;
    procedure reset;
  end;

  tfunc_param_arry = array of tfunc_param_decl;

  tfunc_param_tool = class(TBigList<tfunc_param_decl>)
  public
    procedure DoFree(var Data: tfunc_param_decl); override;
    procedure fill_param(ParamDecl: TP_String);
    function get_param_arry: tfunc_param_arry;
    class function extract_param_to_arry(ParamDecl: TP_String): tfunc_param_arry;
  end;

  tfunc_decl = record
    Body: TP_String;
    IsProc: Boolean;
    BPos, EPos: Integer;
    Name: TP_String;
    IsFunction: Boolean;
    ParamDecl: TP_String;
    param_arry: tfunc_param_arry;
    ResultDecl: TP_String;
    CallConv: TP_String;
    IsExternal: Boolean;
    ExternalLibrary: TP_String;
    HasExplicitName: Boolean;
    ExplicitName: TP_String;
    HasExplicitIndex: Boolean;
    ExplicitIndex: TP_String;
    Index: Integer;
    Comment: TP_String;
    NestLevel: Integer;
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
    ParseSuccess: Boolean;

    constructor Create(AText: TP_String);
    destructor Destroy; override;
    class function CreateFromFile(const FileName: TP_String): tpascal_func_decl_tool;

    procedure Fill;
    procedure Clear;
    function Combine(const BTokenIdx, ETokenIdx: Integer): TP_String;

    // JSON serialization
    function SaveToJson: string;
    procedure LoadFromJson(const JsonStr: string);
  end;

var
  Pascal_Func_Tool_Log_Enabled: Boolean = False;

implementation

uses
  sec.MemoryStream;

{ ------------------------------------------------------------------------------
  tfunc_param_decl.reset
  ------------------------------------------------------------------------------ }
procedure tfunc_param_decl.reset;
begin
  param_mod := '';
  param_name := '';
  param_typ := '';
  param_value := '';
end;

{ ------------------------------------------------------------------------------
  tfunc_param_tool.DoFree
  ------------------------------------------------------------------------------ }
procedure tfunc_param_tool.DoFree(var Data: tfunc_param_decl);
begin
  Data.reset;
  inherited;
end;

{ ------------------------------------------------------------------------------
  tfunc_param_tool.fill_param
  ------------------------------------------------------------------------------ }
procedure tfunc_param_tool.fill_param(ParamDecl: TP_String);

  procedure extract_typ_and_value(p: TP_String; var param_typ, param_value: TP_String);
  var
    tmp: TP_String;
    tp: TTextParsing;
    SplitOutput: TSymbolVector;
    lPos, rNum: Integer;
  begin
    tmp := p.TrimChar(#32#9);
    if tmp = '' then exit;
    tp := TTextParsing.Create(tmp, tsPascal);
    try
      rNum := tp.SplitChar(1, lPos, '=', ';', SplitOutput);
      if rNum > 0 then
          param_typ := SplitOutput[0].TrimChar(#32#9);
      if rNum > 1 then
          param_value := SplitOutput[1].TrimChar(#32#9);
    finally
        disposeObject(tp);
    end;
    if Pascal_Func_Tool_Log_Enabled then
        DoStatus('[tfunc_param_tool] extract_typ_and_value: typ="%s", value="%s"',
        [param_typ.Text, param_value.Text]);
  end;

  procedure do_parsing_single_param(p: TP_String);
  var
    tmp: TP_String;
    tp: TTextParsing;
    SplitOutput: TSymbolVector;
    lPos, rNum, i: Integer;
    param_mod, param_name, param_typ, param_value: TP_String;
  begin
    tmp := p.TrimChar(#32#9);
    if tmp = '' then exit;
    param_mod := '';
    param_name := '';
    param_typ := '';
    param_value := '';

    tp := TTextParsing.Create(tmp, tsPascal);
    try
      rNum := tp.SplitChar(1, lPos, True, ',', ':', SplitOutput);

      if (rNum = 0) and (tmp <> '') then
        begin
          SetLength(SplitOutput, 1);
          SplitOutput[0] := tmp;
          rNum := 1;
        end;

      if rNum > 0 then
        begin
          if (lPos + 1 < tp.Len) and (lPos > 0) then
              extract_typ_and_value(tp.GetStr(lPos + 1, tp.Len), param_typ, param_value)
          else if (lPos = 0) then
              extract_typ_and_value(tmp, param_typ, param_value);

          for i := 0 to Length(SplitOutput) - 1 do
            begin
              if (i = 0) and (Pascal_Keyword(SplitOutput[i]) in [kVar, kOut, kIn, kConst]) then
                begin
                  param_mod := SplitOutput[i];
                  if Pascal_Func_Tool_Log_Enabled then
                      DoStatus('[tfunc_param_tool] Modifier found: "%s"', [param_mod.Text]);
                end
              else
                begin
                  with Add_Null^ do
                    begin
                      Data.reset();
                      Data.param_mod := param_mod;
                      Data.param_name := SplitOutput[i];
                      Data.param_typ := param_typ;
                      Data.param_value := param_value;
                    end;
                  if Pascal_Func_Tool_Log_Enabled then
                      DoStatus('[tfunc_param_tool] Added param: %s:%s = %s',
                      [SplitOutput[i].Text, param_typ.Text, param_value.Text]);
                end;
            end;
        end
      else
        begin
          if Pascal_Func_Tool_Log_Enabled then
              DoStatus('[tfunc_param_tool] No tokens found in group: "%s"', [tmp.Text]);
        end;
    finally
        disposeObject(tp);
    end;
  end;

var
  tmp: TP_String;
  tp: TTextParsing;
  lPos: Integer;
  SplitOutput: TSymbolVector;
  i: Integer;
begin
  tmp := ParamDecl.TrimChar('()'#32#9);
  if tmp = '' then
    begin
      if Pascal_Func_Tool_Log_Enabled then
          DoStatus('[tfunc_param_tool] fill_param: empty or only parentheses');
      exit;
    end;

  if Pascal_Func_Tool_Log_Enabled then
      DoStatus('[tfunc_param_tool] fill_param: parsing "%s"', [tmp.Text]);

  tp := TTextParsing.Create(tmp, tsPascal);
  try
    tp.SplitChar(1, lPos, ';', '', SplitOutput);
    for i := 0 to Length(SplitOutput) - 1 do
        do_parsing_single_param(SplitOutput[i]);
  finally
      disposeObject(tp);
  end;
end;

{ ------------------------------------------------------------------------------
  tfunc_param_tool.get_param_arry
  ------------------------------------------------------------------------------ }
function tfunc_param_tool.get_param_arry: tfunc_param_arry;
begin
  SetLength(Result, Num);
  if Num > 0 then
    with repeat_ do
      repeat
          Result[I__] := queue^.Data;
      until not Next;
end;

{ ------------------------------------------------------------------------------
  tfunc_param_tool.extract_param_to_arry
  ------------------------------------------------------------------------------ }
class function tfunc_param_tool.extract_param_to_arry(ParamDecl: TP_String): tfunc_param_arry;
begin
  with tfunc_param_tool.Create do
    begin
      fill_param(ParamDecl);
      Result := get_param_arry();
      Free;
    end;
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
  i: Integer;
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
constructor tpascal_func_decl_tool.Create(AText: TP_String);
begin
  inherited Create;
  if Pascal_Func_Tool_Log_Enabled then
      DoStatus('[tpascal_func_decl_tool.Create] Starting parsing...');
  Parser := TTextParsing.Create(AText, tsPascal);
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
  Fill;
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.Destroy
  ------------------------------------------------------------------------------ }
destructor tpascal_func_decl_tool.Destroy;
begin
  Clear;
  disposeObject(FuncList);
  disposeObject(UsesList);
  inherited Destroy;
  if Pascal_Func_Tool_Log_Enabled then
      DoStatus('[tpascal_func_decl_tool.Destroy] Destroyed.');
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.CreateFromFile
  ------------------------------------------------------------------------------ }
class function tpascal_func_decl_tool.CreateFromFile(const FileName: TP_String): tpascal_func_decl_tool;
var
  Strings: TPascalStringList;
begin
  Strings := TPascalStringList.Create;
  Strings.LoadFromFile(FileName);
  Result := tpascal_func_decl_tool.Create(Strings.AsText);
  disposeObject(Strings);
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.Fill
  ------------------------------------------------------------------------------ }
procedure tpascal_func_decl_tool.Fill;
  procedure DebugLog(const Msg: string; const Args: array of const); overload;
  begin
    if Pascal_Func_Tool_Log_Enabled then
        DoStatus('[parser_structor] ' + PFormat(Msg, Args));
  end;

  procedure DebugLog(const Msg: string); overload;
  begin
    if Pascal_Func_Tool_Log_Enabled then
        DoStatus('[parser_structor] ' + Msg);
  end;

  function ExtractPrecedingComments(Idx: Integer): TP_String;
  var
    CommentTokens: array of TP_String;
    Temp: TP_String;
    i, Count: Integer;
    Token: PTokenData;
  begin
    Count := 0;
    SetLength(CommentTokens, 0);
    i := Idx - 1;

    DebugLog('Begin extracting comments before index %d', [Idx]);

    while i >= 0 do
      begin
        Token := Parser.Tokens[i];
        if (Token^.TokenType = ttUnknow) and (Token^.Text.TrimChar(#32#9#13#10) = '') then
          begin
            DebugLog('  Skipping whitespace token at index %d', [i]);
            Dec(i);
          end
        else
            Break;
      end;

    while i >= 0 do
      begin
        Token := Parser.Tokens[i];
        DebugLog('  Checking Token[%d]: type=%s, text="%s"', [i, GetEnumName(TypeInfo(TTokenType), Ord(Token^.TokenType)), Token^.Text.Text]);

        if Token^.TokenType = ttComment then
          begin
            SetLength(CommentTokens, Count + 1);
            CommentTokens[Count] := Token^.Text;
            Inc(Count);
            Dec(i);
          end
        else
          begin
            DebugLog('  Encountered non-comment token, stopping scan');
            Break;
          end;
      end;

    Result := '';
    if Count > 0 then
      begin
        for i := Count - 1 downto 0 do
          begin
            Temp := CommentTokens[i];
            if Result.Len > 0 then
                Result := Result + sLineBreak + Temp
            else
                Result := Temp;
          end;
        DebugLog('Extracted %d comment block(s), merged length: %d', [Count, Result.Len]);
      end
    else
        DebugLog('No consecutive comments found');

    for i := 0 to Count - 1 do
        CommentTokens[i] := '';
    SetLength(CommentTokens, 0);
  end;

  function ProcessExternalAndCallingConvention(Idx: Integer; var Output: tfunc_decl): Integer;
  var
    TokenAfterSemi, TokenAfterExternal: PTokenData;
    i: Integer;
    Keyword: TPascal_Keyword;
  begin
    Output.EPos := Parser.Tokens[Idx]^.EPos;
    DebugLog('ProcessExternalAndCallingConvention: starting at index %d', [Idx]);

    TokenAfterSemi := Parser.ProbeR(Idx, [ttAscii]);
    if TokenAfterSemi = nil then
      begin
        DebugLog('No identifier found after "%s", skipping', [Output.Name.Text]);
        Result := Idx;
        exit;
      end;
    DebugLog('  Token after semicolon: "%s" (type=%s)',
      [TokenAfterSemi^.Text.Text, GetEnumName(TypeInfo(TTokenType), Ord(TokenAfterSemi^.TokenType))]);

    Keyword := Pascal_Keyword(TokenAfterSemi^.Text);

    if Keyword in [kRegister, kPascal, kCdecl, kStdcall, kSafeCall] then
      begin
        Output.CallConv := TokenAfterSemi^.Text;
        DebugLog('Routine "%s" recognised calling convention: %s', [Output.Name.Text, TokenAfterSemi^.Text.Text]);

        TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1, [ttSymbol], ';');
        if TokenAfterExternal = nil then
          begin
            DebugLog('In declaration of "%s", missing semicolon after calling convention "%s"', [Output.Name.Text, TokenAfterSemi^.Text.Text]);
            Result := -1;
            exit;
          end;
        Output.EPos := TokenAfterExternal^.EPos;
        DebugLog('  Semicolon after calling convention at index %d', [TokenAfterExternal^.Index]);

        TokenAfterSemi := Parser.ProbeR(TokenAfterExternal^.Index + 1, [ttAscii]);
        if TokenAfterSemi = nil then
          begin
            DebugLog('  No further identifier, declaration ends after semicolon');
            Result := TokenAfterExternal^.Index + 1;
            exit;
          end;
        if not TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal].Decl) then
          begin
            DebugLog('  Not external, declaration ends after semicolon');
            Result := TokenAfterExternal^.Index + 1;
            exit;
          end;
      end
    else if not TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal].Decl) then
      begin
        DebugLog('  No calling convention nor external, declaration ends after semicolon');
        Result := Idx;
        exit;
      end;

    Output.IsExternal := True;
    DebugLog('Routine "%s" marked as external', [Output.Name.Text]);

    TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1,
      [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
    if (TokenAfterExternal <> nil) and (TokenAfterExternal^.TokenType in [ttTextDecl, ttAscii]) then
      begin
        Output.ExternalLibrary := TokenAfterExternal^.Text;
        DebugLog('external library: %s', [Output.ExternalLibrary.Text]);
      end
    else if (TokenAfterExternal <> nil) and (TokenAfterExternal^.TokenType in [ttSymbol]) and
      (TokenAfterExternal^.Text.Same(';')) then
      begin
        DebugLog('external without library name (direct semicolon)');
        Result := TokenAfterExternal^.Index + 1;
        exit;
      end
    else
      begin
        DebugLog('In external declaration of "%s", library name missing or invalid (string or identifier expected)', [Output.Name.Text]);
        Result := -1;
        exit;
      end;

    TokenAfterSemi := Parser.ProbeR(TokenAfterExternal^.Index + 1,
      [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
    if TokenAfterSemi^.TokenType = ttAscii then
      begin
        Output.HasExplicitName := TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal_Name].Decl);
        Output.HasExplicitIndex := TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal_Index].Decl);

        if Output.HasExplicitName or Output.HasExplicitIndex then
          begin
            if Output.HasExplicitName then
                DebugLog('Routine "%s" found "name" clause', [Output.Name.Text])
            else
                DebugLog('Routine "%s" found "index" clause', [Output.Name.Text]);

            TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1, [ttSymbol], ';');
            if TokenAfterExternal = nil then
              begin
                DebugLog('In "%s" clause of "%s", missing terminating semicolon', [TokenAfterSemi^.Text.Text, Output.Name.Text]);
                Result := -1;
                exit;
              end;
            for i := TokenAfterSemi^.Index + 1 to TokenAfterExternal^.Index - 1 do
              if Output.HasExplicitName then
                  Output.ExplicitName.Append(Parser.Tokens[i]^.Text)
              else if Output.HasExplicitIndex then
                  Output.ExplicitIndex.Append(Parser.Tokens[i]^.Text);

            if Output.HasExplicitName then
                DebugLog('Explicit name: %s', [Output.ExplicitName.Text])
            else
                DebugLog('Explicit index: %s', [Output.ExplicitIndex.Text]);

            TokenAfterSemi := TokenAfterExternal;
            Output.EPos := TokenAfterExternal^.EPos;
          end;
      end
    else if (TokenAfterSemi^.TokenType = ttSymbol) and (TokenAfterSemi^.Text.Same(';')) then
      begin
        DebugLog('external without name/index clause');
        Output.EPos := TokenAfterSemi^.EPos;
      end;

    Result := TokenAfterSemi^.Index + 1;
  end;

  function ProcessProcDeclaration(ProcDeclToken, ProcNameToken: PTokenData;
    var Output: tfunc_decl): Integer;
  var
    TokenAfterName, TokenAfterParen: PTokenData;
    i: Integer;
  begin
    Output.IsProc := True;
    Output.BPos := ProcDeclToken^.BPos;
    Output.Name := ProcNameToken^.Text;
    Output.IsFunction := (Pascal_Keyword(ProcDeclToken^.Text) = kFunction);
    Output.ParamDecl := '';
    Output.ResultDecl := '';

    DebugLog('Parsing routine: %s (type: %s)',
      [Output.Name.Text, if_(Output.IsFunction, 'function', 'procedure')]);

    TokenAfterName := Parser.ProbeR(ProcNameToken^.Index + 1, [ttSymbol]);
    if (TokenAfterName <> nil) and (TokenAfterName^.TokenType = ttSymbol) then
      begin
        DebugLog('  Symbol after name: "%s"', [TokenAfterName^.Text.Text]);

        if TokenAfterName^.Text.Same('(') then
          begin
            DebugLog('  Found parameter list start');
            TokenAfterParen := Parser.IndentSymbolEndProbeR(TokenAfterName^.Index, '(', ')');
            if TokenAfterParen = nil then
              begin
                TokenAfterParen := Parser.ProbeR(TokenAfterName^.Index + 1, [ttSymbol], ')');
                if TokenAfterParen = nil then
                  begin
                    DebugLog('In routine "%s", missing matching closing parenthesis ")"', [Output.Name.Text]);
                    Result := -1;
                    exit;
                  end;
              end;

            Output.ParamDecl := Parser.TokenCombine(TokenAfterName^.Index, TokenAfterParen^.Index);
            Output.param_arry := tfunc_param_tool.extract_param_to_arry(Output.ParamDecl);

            DebugLog('Parameters: %s (count=%d)', [Output.ParamDecl.Text, Length(Output.param_arry)]);

            TokenAfterName := Parser.ProbeR(TokenAfterParen^.Index + 1, [ttSymbol]);
            DebugLog('  Token after closing paren: "%s"', [TokenAfterName^.Text.Text]);
          end
        else
          begin
            DebugLog('  No parameter list');
            Output.param_arry := nil;
          end;

        if (not Output.IsFunction) and (TokenAfterName <> nil) and TokenAfterName^.Text.Same(';') then
          begin
            Output.EPos := TokenAfterName^.EPos;
            DebugLog('Procedure "%s" directly followed by semicolon, entering external processing', [Output.Name.Text]);
            Result := ProcessExternalAndCallingConvention(TokenAfterName^.Index + 1, Output);
            if Result = -1 then
                DebugLog('Routine "%s" external processing failed', [Output.Name.Text])
            else
                DebugLog('Routine "%s" parsed successfully', [Output.Name.Text]);
            exit;
          end;

        if Output.IsFunction and (TokenAfterName <> nil) and TokenAfterName^.Text.Same(':') then
          begin
            DebugLog('  Found return type start');
            i := TokenAfterName^.Index + 1;
            Output.ResultDecl := '';
            while (i < Parser.TokenCount) and (not Parser.Tokens[i]^.Text.Same(';')) do
              begin
                if Output.ResultDecl.Len > 0 then Output.ResultDecl.Append(' ');
                Output.ResultDecl.Append(Parser.Tokens[i]^.Text);
                Inc(i);
              end;
            if i >= Parser.TokenCount then
              begin
                DebugLog('In function "%s", missing terminating semicolon after return type', [Output.Name.Text]);
                Result := -1;
                exit;
              end;

            DebugLog('Return type: %s', [Output.ResultDecl.Text]);
            Result := ProcessExternalAndCallingConvention(i + 1, Output);
            if Result = -1 then
                DebugLog('Routine "%s" external processing failed', [Output.Name.Text])
            else
                DebugLog('Routine "%s" parsed successfully', [Output.Name.Text]);
            exit;
          end
        else if Output.IsFunction and ((TokenAfterName = nil) or (not TokenAfterName^.Text.Same(':'))) then
          begin
            DebugLog('In function "%s", missing ":" or return type', [Output.Name.Text]);
            Result := -1;
            exit;
          end
        else if (not Output.IsFunction) and ((TokenAfterName = nil) or (not TokenAfterName^.Text.Same(';'))) then
          begin
            if TokenAfterName <> nil then
              begin
                if Pascal_Keyword(TokenAfterName^.Text) in [kRegister, kPascal, kCdecl, kStdcall, kSafeCall, kExternal] then
                  begin
                    Output.EPos := TokenAfterName^.EPos;
                    Result := ProcessExternalAndCallingConvention(TokenAfterName^.Index, Output);
                    if Result = -1 then
                        DebugLog('Routine "%s" external processing failed', [Output.Name.Text])
                    else
                        DebugLog('Routine "%s" parsed successfully', [Output.Name.Text]);
                    exit;
                  end;
              end;
            DebugLog('In routine "%s", unexpected structure', [Output.Name.Text]);
            Result := -1;
            exit;
          end;
      end
    else
      begin
        DebugLog('In routine "%s", valid name or subsequent symbol not found', [Output.Name.Text]);
        Result := -1;
      end;
  end;

  procedure ProcessUsesClause(const AText: TP_String);
  var
    LocalParser: TTextParsing;
    LocalList: TPascalStringList;
    CleanedText: TP_String;
    i: Integer;
  begin
    DebugLog('Processing uses clause, raw text: %s', [AText.Text]);
    LocalParser := TTextParsing.Create(AText, tsPascal);
    LocalParser.DeletedComment;
    CleanedText := LocalParser.ParsingData.Text.DeleteChar(#13#10#9);
    disposeObject(LocalParser);

    LocalList := TPascalStringList.Create;
    UmlSeparatorText(CleanedText, LocalList, ',');
    i := 0;
    while i < LocalList.Count do
      begin
        LocalList[i] := LocalList[i].TrimChar(#32);
        if LocalList[i].Len = 0 then
            LocalList.Delete(i)
        else
            Inc(i);
      end;
    DebugLog('Extracted %d unit names', [LocalList.Count]);
    UmlMergeStrings(LocalList, UsesList, True);
    disposeObject(LocalList);
  end;

type
  TCurrentSection = (csBeginUnit, csEndUnit, csIntf, csIntfUses, csImp);
  TCurrentSections = set of TCurrentSection;

var
  i: Integer;
  CurrentToken, NextToken, NextNextToken: PTokenData;
  DeclItem: pfunc_decl;
  Sections: TCurrentSections;
  NestedLevel: Integer;
  Keyword: TPascal_Keyword;
  PreComment: TP_String;
  FuncCount: Integer;
  ErrorOccurred: Boolean;
begin
  DebugLog('Starting Pascal unit parsing', []);

  i := 0;
  Sections := [];
  NestedLevel := 0;
  FuncCount := 0;
  ErrorOccurred := False;

  while (i < Parser.TokenCount) and (not ErrorOccurred) do
    begin
      CurrentToken := Parser.Tokens[i];
      DebugLog('Main loop: index=%d, type=%s, text="%s"',
        [i, GetEnumName(TypeInfo(TTokenType), Ord(CurrentToken^.TokenType)), CurrentToken^.Text.Text]);

      if (CurrentToken^.TokenType = ttUnknow) and (CurrentToken^.Text.TrimChar(#32#9#13#10) = '') then
        begin
          DebugLog('  Skipping whitespace');
          Inc(i);
          Continue;
        end;

      New(DeclItem);
      DeclItem^.Init;
      DeclItem^.NestLevel := NestedLevel;

      DeclItem^.Body := CurrentToken^.Text;
      DeclItem^.IsProc := False;
      DeclItem^.BPos := CurrentToken^.BPos;
      DeclItem^.EPos := CurrentToken^.EPos;

      if (not(csEndUnit in Sections)) and (csIntf in Sections) and
        (not(csImp in Sections)) and (NestedLevel > 0) then
        begin
          if (CurrentToken^.TokenType = ttAscii) then
            begin
              Keyword := Pascal_Keyword(CurrentToken^.Text);
              DebugLog('  Nested level %d, keyword: %s', [NestedLevel, CurrentToken^.Text.Text]);

              if Keyword = kClass then
                begin
                  NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1,
                    [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                  if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                    begin
                      NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1,
                        [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if not NextNextToken^.Text.Same('(', ';', 'of') then
                        begin
                          Inc(NestedLevel);
                          DebugLog('Nesting +1 (class), depth: %d', [NestedLevel]);
                        end
                      else if NextNextToken^.Text.Same('(') then
                        begin
                          NextNextToken := Parser.ProbeR(
                            Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1,
                            [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                          if not NextNextToken^.Text.Same('(', ';') then
                            begin
                              Inc(NestedLevel);
                              DebugLog('Nesting +1 (class with paren), depth: %d', [NestedLevel]);
                            end;
                        end;
                    end;
                end
              else if Keyword = kInterface then
                begin
                  NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1,
                    [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                  if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                    begin
                      NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1,
                        [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if not NextNextToken^.Text.Same('(', ';') then
                        begin
                          Inc(NestedLevel);
                          DebugLog('Nesting +1 (interface), depth: %d', [NestedLevel]);
                        end
                      else if NextNextToken^.Text.Same('(') then
                        begin
                          NextNextToken := Parser.ProbeR(
                            Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1,
                            [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                          if not NextNextToken^.Text.Same('(', ';') then
                            begin
                              Inc(NestedLevel);
                              DebugLog('Nesting +1 (interface with paren), depth: %d', [NestedLevel]);
                            end;
                        end;
                    end;
                end
              else if Keyword = kRecord then
                begin
                  Inc(NestedLevel);
                  DebugLog('Nesting +1 (record), depth: %d', [NestedLevel]);
                end
              else if Keyword = kEnd then
                begin
                  if Parser.ComparePosStr(CurrentToken^.BPos, 'end;') or
                    Parser.ComparePosStr(CurrentToken^.BPos, 'end ') then
                    begin
                      Dec(NestedLevel);
                      DebugLog('Nesting -1 (end), depth: %d', [NestedLevel]);
                    end;
                end;
            end;
        end

      else if (not(csEndUnit in Sections)) and (NestedLevel = 0) and
        (CurrentToken^.TokenType = ttAscii) then
        begin
          Keyword := Pascal_Keyword(CurrentToken^.Text);
          DebugLog('  Top-level token: "%s" (keyword=%s)', [CurrentToken^.Text.Text, GetEnumName(TypeInfo(TPascal_Keyword), Ord(Keyword))]);

          if (not(csBeginUnit in Sections)) and (Keyword = kUnit) then
            begin
              Sections := [csBeginUnit];
              UnitToken := DeclItem;
              NextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttSymbol], ';');
              if NextToken = nil then
                begin
                  DebugLog('In unit declaration, unit name or terminating semicolon not found');
                  ErrorOccurred := True;
                  Continue;
                end;
              UnitName := Parser.TokenCombine(CurrentToken^.Index + 1,
                NextToken^.Index - 1).TrimChar(#32);
              DebugLog('Unit name identified: "%s"', [UnitName.Text]);
            end;

          if (csBeginUnit in Sections) then
            begin
              if (not(csIntf in Sections)) and (Keyword = kInterface) then
                begin
                  Include(Sections, csIntf);
                  InterfaceToken := DeclItem;
                  DebugLog('Entering interface section');
                end
              else if (not(csImp in Sections)) and (Keyword = kImplementation) then
                begin
                  Include(Sections, csImp);
                  ImplementationToken := DeclItem;
                  DebugLog('Entering implementation section');
                end
              else if (csImp in Sections) and (not(csEndUnit in Sections)) and
                (CurrentToken^.TokenType = ttAscii) then
                begin
                  if Keyword = kInitialization then
                    begin
                      InitToken := DeclItem;
                      DebugLog('Initialization block identified');
                    end
                  else if Keyword = kFinalization then
                    begin
                      FinalToken := DeclItem;
                      DebugLog('Finalization block identified');
                    end
                  else if (Parser.ComparePosStr(CurrentToken^.BPos, 'end.')) then
                    begin
                      Include(Sections, csEndUnit);
                      DeclItem^.Body := 'end.';
                      Inc(i);
                      EndToken := DeclItem;
                      DebugLog('End. identified');
                    end;
                end
              else if (csIntf in Sections) and (not(csImp in Sections)) then
                begin
                  if (not(csIntfUses in Sections)) and (Keyword = kUses) then
                    begin
                      NextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttSymbol], ';');
                      if NextToken = nil then
                        begin
                          DebugLog('In uses clause, terminating semicolon not found');
                          ErrorOccurred := True;
                          Continue;
                        end;
                      Include(Sections, csIntfUses);
                      ProcessUsesClause(Parser.TokenCombine(CurrentToken^.Index + 1,
                          NextToken^.Index - 1));
                      i := NextToken^.Index + 1;
                      DeclItem^.Body := '';
                      DebugLog('Uses clause processed');
                    end;
                  Include(Sections, csIntfUses);

                  if (Keyword in [kFunction, kProcedure]) then
                    begin
                      DebugLog('  Found function/procedure keyword: %s', [CurrentToken^.Text.Text]);
                      PreComment := ExtractPrecedingComments(i);
                      DeclItem^.Comment := PreComment;
                      if PreComment.Len > 0 then
                          DebugLog('Routine "%s" bound comment: %s', [CurrentToken^.Text.Text, PreComment.Text])
                      else
                          DebugLog('Routine "%s" has no preceding comment', [CurrentToken^.Text.Text]);

                      NextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttAscii, ttSymbol]);
                      if (NextToken <> nil) and (NextToken^.TokenType = ttAscii) and
                        (Pascal_Keyword(NextToken^.Text) <> kOf) then
                        begin
                          i := ProcessProcDeclaration(CurrentToken, NextToken, DeclItem^);
                          if i = -1 then
                            begin
                              DebugLog('Routine "%s" parsing failed', [DeclItem^.Name.Text]);
                              ErrorOccurred := True;
                              Continue;
                            end;
                          DeclItem^.Body := Parser.GetStr(DeclItem^.BPos, DeclItem^.EPos);
                          Inc(FuncCount);
                          DebugLog('Recorded routine "%s" (total %d)', [DeclItem^.Name.Text, FuncCount]);
                        end;
                    end

                  else if Keyword = kClass then
                    begin
                      NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1,
                        [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                        begin
                          NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1,
                            [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                          if not NextNextToken^.Text.Same('(', ';', 'of') then
                            begin
                              Inc(NestedLevel);
                              DebugLog('Nesting +1 (class), depth: %d', [NestedLevel]);
                            end
                          else if NextNextToken^.Text.Same('(') then
                            begin
                              NextNextToken := Parser.ProbeR(
                                Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1,
                                [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                              if not NextNextToken^.Text.Same('(', ';') then
                                begin
                                  Inc(NestedLevel);
                                  DebugLog('Nesting +1 (class with paren), depth: %d', [NestedLevel]);
                                end;
                            end;
                        end;
                    end
                  else if Keyword = kInterface then
                    begin
                      NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1,
                        [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                        begin
                          NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1,
                            [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                          if not NextNextToken^.Text.Same('(', ';') then
                            begin
                              Inc(NestedLevel);
                              DebugLog('Nesting +1 (interface), depth: %d', [NestedLevel]);
                            end
                          else if NextNextToken^.Text.Same('(') then
                            begin
                              NextNextToken := Parser.ProbeR(
                                Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1,
                                [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                              if not NextNextToken^.Text.Same('(', ';') then
                                begin
                                  Inc(NestedLevel);
                                  DebugLog('Nesting +1 (interface with paren), depth: %d', [NestedLevel]);
                                end;
                            end;
                        end;
                    end
                  else if Keyword = kRecord then
                    begin
                      Inc(NestedLevel);
                      DebugLog('Nesting +1 (record), depth: %d', [NestedLevel]);
                    end;
                end;
            end;
        end;

      DeclItem^.Index := FuncList.Num;
      FuncList.Add(DeclItem);
      Inc(i);
    end;

  if ErrorOccurred then
    begin
      DoStatus('Error occurred during parsing, aborted');
      ParseSuccess := False;
    end
  else
    begin
      if UnitName.Len = 0 then
          DoStatus('Warning: unit name not found');
      if UnitToken = nil then
          DoStatus('Warning: "unit" declaration not found');
      if InterfaceToken = nil then
          DoStatus('Warning: "interface" declaration not found');
      if ImplementationToken = nil then
          DoStatus('Warning: "implementation" declaration not found');
      if EndToken = nil then
          DoStatus('Warning: "end." declaration not found');

      ParseSuccess := (UnitName.Len > 0) and (UnitToken <> nil) and
        (InterfaceToken <> nil) and (ImplementationToken <> nil) and
        (EndToken <> nil);

      if ParseSuccess then
          DebugLog('Parsing successful, found %d function/procedure declarations', [FuncCount])
      else
          DebugLog('Parsing failed, missing required structure');
    end;
end;

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
function tpascal_func_decl_tool.Combine(const BTokenIdx, ETokenIdx: Integer): TP_String;
var
  Lo, Hi: Integer;
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
end;

function JsonToParamDecl(const jo: TZ_JsonObject): tfunc_param_decl;
begin
  Result.reset;
  Result.param_mod := jo.S['mod'];
  Result.param_name := jo.S['name'];
  Result.param_typ := jo.S['typ'];
  Result.param_value := jo.S['value'];
end;

procedure FuncDeclToJson(const f: tfunc_decl; const obj: TZ_JsonObject);
var
  arr: TZ_JsonArray;
  paramObj: TZ_JsonObject;
  i: Integer;
begin
  obj.S['Body'] := f.Body.Text;
  obj.B['IsProc'] := f.IsProc;
  obj.i['BPos'] := f.BPos;
  obj.i['EPos'] := f.EPos;
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
    end;

  obj.S['ResultDecl'] := f.ResultDecl.Text;
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
  i: Integer;
begin
  f.Init;
  f.Body := jo.S['Body'];
  f.IsProc := jo.B['IsProc'];
  f.BPos := jo.i['BPos'];
  f.EPos := jo.i['EPos'];
  f.Name := jo.S['Name'];
  f.IsFunction := jo.B['IsFunction'];
  f.ParamDecl := jo.S['ParamDecl'];

  arr := jo.A['param_arry'];
  SetLength(f.param_arry, arr.Count);
  for i := 0 to arr.Count - 1 do
      f.param_arry[i] := JsonToParamDecl(arr.O[i]);

  f.ResultDecl := jo.S['ResultDecl'];
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
  ------------------------------------------------------------------------------ }
function tpascal_func_decl_tool.SaveToJson: string;
var
  root: TZ_JsonObject;
  arr: TZ_JsonArray;
  funcObj: TZ_JsonObject;
  i: Integer;
  usesArr: TZ_JsonArray;
begin
  root := TZ_JsonObject.Create;
  try
    root.S['UnitName'] := UnitName.Text;
    root.B['ParseSuccess'] := ParseSuccess;

    arr := root.A['FuncList'];
    for i := 0 to FuncList.Count - 1 do
      begin
        funcObj := arr.AddObject;
        FuncDeclToJson(FuncList[i]^, funcObj);
      end;

    usesArr := root.A['UsesList'];
    for i := 0 to UsesList.Count - 1 do
        usesArr.Add(UsesList[i].Text);

    if UnitToken <> nil then
        root.S['UnitTokenBody'] := UnitToken^.Body.Text;
    if InterfaceToken <> nil then
        root.S['InterfaceTokenBody'] := InterfaceToken^.Body.Text;
    if ImplementationToken <> nil then
        root.S['ImplementationTokenBody'] := ImplementationToken^.Body.Text;
    if EndToken <> nil then
        root.S['EndTokenBody'] := EndToken^.Body.Text;
    if InitToken <> nil then
        root.S['InitTokenBody'] := InitToken^.Body.Text;
    if FinalToken <> nil then
        root.S['FinalTokenBody'] := FinalToken^.Body.Text;

    Result := root.ToJSONString(True);
  finally
      root.Free;
  end;
end;

{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.LoadFromJson
  ------------------------------------------------------------------------------ }
procedure tpascal_func_decl_tool.LoadFromJson(const JsonStr: string);
var
  root: TZ_JsonObject;
  arr: TZ_JsonArray;
  i: Integer;
  p: pfunc_decl;
  usesArr: TZ_JsonArray;
begin
  Clear;
  root := TZ_JsonObject.Create;
  try
    root.ParseText(JsonStr);
    UnitName := root.S['UnitName'];
    ParseSuccess := root.B['ParseSuccess'];

    arr := root.A['FuncList'];
    for i := 0 to arr.Count - 1 do
      begin
        New(p);
        p^.Init;
        JsonToFuncDecl(arr.O[i], p^);
        FuncList.Add(p);
      end;

    usesArr := root.A['UsesList'];
    for i := 0 to usesArr.Count - 1 do
        UsesList.Add(usesArr.S[i]);

    // Structural token bodies are not restored as pointers
  finally
      root.Free;
  end;
end;

end.
