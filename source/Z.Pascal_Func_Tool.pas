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
{ ******************************************************************************
  * Z.Pascal_Func_Tool
  *
  * This unit implements a parser for extracting structural information from
  * Pascal source files: unit name, interface/implementation sections,
  * initialization/finalization blocks, and declarations of all functions
  * and procedures (including parameters, return types, calling conventions,
  * external linkage, and explicit name/index clauses).
  *
  * It is built on the Z.Parsing lexical analysis library, using token streams
  * for efficient scanning without manual handling of comments or string
  * literals. Parsing results are stored in tfunc_decl records, ready for
  * subsequent code analysis or refactoring tools.
  *
  * All keywords are obtained from Z.Pascal_Code_Tool to eliminate hard-coded
  * strings, ensuring maintainability and consistency.
  *
  * --------------------------------------------------------------------------
  * Important changes:
  *   - All exceptions (RaiseInfo) have been removed. The parser now uses
  *     silent error handling: upon encountering invalid syntax, it logs a
  *     debug message, sets ErrorOccurred, and safely exits the loop,
  *     leaving ParseSuccess=False.
  *   - Debug mode is controlled by the DebugMode constant (True by default).
  *   - Added NestLevel field to tfunc_decl to store nesting depth of each
  *     declaration (0 = top‑level, >0 = inside class/record etc.).
  *
  * --------------------------------------------------------------------------
  * History and Acknowledgements:
  *   This unit was originally written by qq600585 around 2012. Its core
  *   design of token stream scanning and semantic probing was visionary.
  *   With the advent of AI, we have preserved the original parsing workflow
  *   while modernising naming, comments, and error handling to make it more
  *   maintainable and accessible. Our sincere thanks go to the original author.
  ****************************************************************************** }
unit Z.Pascal_Func_Tool;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  TypInfo,
  {$IFDEF FPC}
    { FPC-specific generic list support (backported from fgl) }
    Z.FPC.GenericList, fgl,
  {$ENDIF FPC}
  Z.Core,
  Z.PascalStrings,
  Z.UPascalStrings,
  Z.UnicodeMixedLib,
  Z.Status,
  Z.Parsing,
  Z.ListEngine,
  Z.Pascal_Code_Tool; // Provides Pascal_Keyword function and TPascal_Keyword enum

type
  { Pointer to a function/procedure declaration record }
  pfunc_decl = ^tfunc_decl;

  {
    tfunc_decl stores complete declaration information for a function or
    procedure, including its location, name, parameters, return type,
    calling convention, external linkage, and any preceding comment.
    All fields are initialised to safe default values in the Init method.
  }
  tfunc_decl = record
    Body: TP_String; // Full source text of the declaration
    IsProc: Boolean; // True if it is a procedure, False if function
    BPos, EPos: Integer; // Start and end character positions (1-based, exclusive)
    Name: TP_String; // Routine name
    IsFunction: Boolean; // True if it's a function, False if procedure
    ParamDecl: TP_String; // Parameter list, e.g. '(a,b: Integer)'
    ResultDecl: TP_String; // Return type (for functions), e.g. 'Integer'
    CallConv: TP_String; // Calling convention, e.g. 'cdecl', 'stdcall'
    IsExternal: Boolean; // True if 'external' keyword is present
    ExternalLibrary: TP_String; // Library name for external, e.g. 'libname'
    HasExplicitName: Boolean; // True if 'name' alias is specified
    ExplicitName: TP_String; // Explicit export name, e.g. 'pu_xx'
    HasExplicitIndex: Boolean; // True if 'index' ordinal is specified
    ExplicitIndex: TP_String; // Explicit export index, e.g. '110'
    Index: Integer; // Sequential index in the declaration list (0-based)
    Comment: TP_String; // Preceding comment text (if any)
    { +++ NEW FIELD +++ }
    NestLevel: Integer; // Nesting depth: 0 = top‑level, >0 = inside class/record etc.
    procedure Init; // Initialises all fields to default values
  end;

  tfunc_decl_list = TGenericsList<pfunc_decl>;

  {
    tpascal_func_decl_tool is the main class for parsing Pascal units and
    extracting function/procedure declarations. It uses Z.Parsing for lexical
    analysis and locates keywords via probing methods, eliminating the need
    for manual lexing.
    Parsing results are stored in FuncList, and key token positions are
    recorded for structural elements.
  }
  tpascal_func_decl_tool = class(TCore_Object_Intermediate)
  public
    Parser: TTextParsing; // Lexical analyser instance (token cache)
    FuncList: tfunc_decl_list; // List of all parsed function/procedure declarations
    UsesList: TPascalStringList; // Merged list of unit names from interface uses clause
    UnitName: TP_String; // Name of the parsed unit
    UnitToken: pfunc_decl; // Declaration item for the 'unit' keyword
    InterfaceToken: pfunc_decl; // Declaration item for the 'interface' keyword
    ImplementationToken: pfunc_decl; // Declaration item for the 'implementation' keyword
    EndToken: pfunc_decl; // Declaration item for the 'end.' keyword
    InitToken: pfunc_decl; // Declaration item for 'initialization' (if present)
    FinalToken: pfunc_decl; // Declaration item for 'finalization' (if present)
    ParseSuccess: Boolean; // Whether the unit structure was fully parsed

    constructor Create(AText: TP_String);
    destructor Destroy; override;
    class function CreateFromFile(const FileName: TP_String): tpascal_func_decl_tool;

    { Execute parsing, populating all internal data structures }
    procedure Fill;

    { Clear all parsed data and free memory }
    procedure Clear;

    { Concatenate the bodies of declaration items in the given index range }
    function Combine(const BTokenIdx, ETokenIdx: Integer): TP_String;
  end;

const
  Pascal_Func_Tool_Log_Enabled: Boolean = False; // Debug switch; when True, detailed logs are emitted

implementation

{ tfunc_decl.Init --------------------------------------------------------------
  Resets all fields to empty/zero values, ensuring the record is in a
  consistent safe state before use. BPos/EPos are set to -1 to distinguish
  from valid positions (>=1), allowing callers to check whether the record
  has been initialised. }
procedure tfunc_decl.Init;
begin
  Body := '';
  IsProc := False;
  BPos := -1;
  EPos := -1;
  Name := '';
  IsFunction := False;
  ParamDecl := '';
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
  { +++ INIT NEW FIELD +++ }
  NestLevel := 0;
end;

{ tpascal_func_decl_tool.Create ----------------------------------------------------
  Constructs the parser with the given Pascal source text and immediately
  executes Fill. All internal containers and state variables are initialised;
  even if Fill fails, the object can be safely destroyed.
  Debug mode is enabled by default (True) to assist with troubleshooting. }
constructor tpascal_func_decl_tool.Create(AText: TP_String);
begin
  inherited Create;
  Parser := TTextParsing.Create(AText, tsPascal); // Pascal-style lexical analyser
  FuncList := tfunc_decl_list.Create;
  UsesList := TPascalStringList.Create;
  UnitName := '';
  UnitToken := nil;
  InterfaceToken := nil;
  ImplementationToken := nil;
  EndToken := nil;
  InitToken := nil;
  FinalToken := nil;
  ParseSuccess := False;
  Fill; // Run the parser immediately
end;

destructor tpascal_func_decl_tool.Destroy;
begin
  Clear;
  DisposeObject(FuncList);
  DisposeObject(UsesList);
  inherited Destroy;
end;

class function tpascal_func_decl_tool.CreateFromFile(const FileName: TP_String): tpascal_func_decl_tool;
var
  Strings: TPascalStringList;
begin
  Strings := TPascalStringList.Create;
  Strings.LoadFromFile(FileName);
  Result := tpascal_func_decl_tool.Create(Strings.AsText);
  DisposeObject(Strings);
end;

{ * tpascal_func_decl_tool.Fill ------------------------------------------------------
  * Core parsing routine. It scans all tokens, recognises unit structure,
  * and extracts function/procedure declarations.
  *
  * ============================================================================
  * Parsing principle (based on Z.Parsing token stream and probing):
  * Z.Parsing converts source code into a flat list of tokens, each with a type
  * (ttAscii, ttSymbol, ttComment, etc.) and positional information. This method
  * sequentially scans the token list, using a state machine (Sections) and a
  * nesting depth counter (NestedLevel) to distinguish top-level declarations
  * from those inside nested structures (classes, records, interfaces, etc.).
  *
  * Key concepts:
  * - Token Stream: Provided by TTextParsing as a linear sequence accessible
  *   via the Tokens property or by using ProbeL/ProbeR for fast searching.
  * - Probe: ProbeR searches to the right from a given index for a token
  *   matching certain criteria; ProbeL searches to the left. This method
  *   extensively uses ProbeR to locate subsequent symbols like semicolons
  *   and parentheses.
  * - Token Types: ttAscii represents identifiers (including keywords),
  *   ttSymbol represents single-character symbols, ttComment represents
  *   comments, ttUnknow represents whitespace or unrecognised characters.
  * - State Machine (Sections): Tracks the current logical region (unit,
  *   interface, implementation, etc.) because keywords have different meanings
  *   in different contexts (e.g., 'end' in a record vs. unit termination).
  *
  * Parsing strategy:
  * 1. Use the Sections state machine to track whether we are in unit,
  *    interface, implementation, etc.
  * 2. Use NestedLevel to track nesting depth of classes, records, interfaces
  *    to avoid misinterpreting inner declarations as top-level.
  * 3. All keyword comparisons are done via Pascal_Keyword, converting to
  *    an enumeration to eliminate hard-coded strings.
  * 4. In the interface section, locate 'uses' clauses, extract the unit names,
  *    and then identify function/procedure declarations.
  * 5. In the implementation section, only mark initialization, finalization,
  *    and end. keywords.
  * 6. Every token is added to FuncList, but only those with IsProc=True
  *    are true function/procedure declarations (used for final counting).
  *
  * Note: Method declarations inside classes are not extracted separately
  * because when NestedLevel > 0, the top-level processing block is not
  * triggered. This is by design, focusing on unit-level interface declarations.
  *
  * Silent error handling: On syntax errors, the parser does not raise an
  * exception. Instead, it sets ErrorOccurred=True, breaks the loop, and
  * ultimately ParseSuccess=False.
}
procedure tpascal_func_decl_tool.Fill;

{ Debug logging helper – outputs only when Pascal_Func_Tool_Log_Enabled is True }
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

(*
  * Extracts consecutive comments immediately preceding a function/procedure
  * keyword at the given index. It scans backwards from Idx-1, skipping
  * whitespace tokens (ttUnknow with empty Trim), then gathers all consecutive
  * ttComment tokens.
  * Returns the concatenated comment text in source order (i.e., the order
  * they appear in the source code), or an empty string if no comment found.
  *
  * Design considerations:
  * - Whitespace (newlines, spaces, tabs) is treated as non-substantive and
  *   skipped, so that comments separated by newlines or spaces are still captured.
  * - Stop scanning at the first non-comment token (e.g., 'type', 'var', '='),
  *   ensuring only comments directly adjacent to the declaration are bound.
  * - Multiple comment blocks (e.g., a '//' line followed by a '{ }' block)
  *   are merged in order, separated by line breaks.
*)
  function ExtractPrecedingComments(Idx: Integer): TP_String;
  var
    CommentTokens: array of TP_String;
    Temp: TP_String;
    i, Count: Integer;
    Token: PTokenData;
    TokenTypeName: string;
  begin
    Count := 0;
    SetLength(CommentTokens, 0);
    i := Idx - 1;

    DebugLog('Begin extracting comments before index %d', [Idx]);

    // Skip whitespace tokens (ttUnknow and text is empty after trimming)
    while i >= 0 do
      begin
        Token := Parser.Tokens[i];
        TokenTypeName := GetEnumName(TypeInfo(TTokenType), Ord(Token^.TokenType));
        if (Token^.TokenType = ttUnknow) and (Token^.Text.TrimChar(#32#9#13#10) = '') then
          begin
            // (We do not log skipped whitespace to reduce noise, but it is skipped.)
            Dec(i);
          end
        else
            Break;
      end;

    // Now i may point to a comment or to a non-whitespace non-comment token.
    while i >= 0 do
      begin
        Token := Parser.Tokens[i];
        TokenTypeName := GetEnumName(TypeInfo(TTokenType), Ord(Token^.TokenType));
        DebugLog('  Checking Token[%d]: type=%s, text="%s"', [i, TokenTypeName, Token^.Text.Text]);

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
        // Reverse order because we scanned backwards
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

    // Cleanup temporary array
    for i := 0 to Count - 1 do
        CommentTokens[i] := '';
    SetLength(CommentTokens, 0);
  end;

{
  * Processes external declaration part (cdecl; external 'lib' name '...' etc.)
  * and fills the Output record. Input Idx is the token index (usually points
  * to the ';' or 'external' after the declaration). Returns the next index
  * to process, or -1 on error.
  *
  * Parsing logic (fixed):
  * 1. Use ProbeR to find the first identifier after the current token.
  * 2. Determine if it is a calling convention (cdecl, stdcall, etc.) or 'external'.
  * 3. If it is a calling convention, record it, skip it, and continue to find
  *    the following 'external'. If there is no following identifier, then the
  *    declaration ends: return the position after the semicolon.
  *    If there is a following identifier but it is not 'external', then the
  *    declaration ends: return the position after the semicolon.
  * 4. If the first identifier is not a calling convention, check if it is
  *    'external'. If not, then the declaration ends: return the position after
  *    the semicolon. If it is 'external', extract the library name and then
  *    handle optional 'name' or 'index' clauses.
  * 5. All extractions are terminated by a semicolon; if a semicolon is missing,
  *    log an error and return -1.
  *
  * Note: The key fix is that whenever there is no 'external', we must return
  * the position after the semicolon, not the index of the next identifier,
  * to avoid skipping the current declaration.
}
  function ProcessExternalAndCallingConvention(Idx: Integer; var Output: tfunc_decl): Integer;
  var
    TokenAfterSemi, TokenAfterExternal: PTokenData;
    i: Integer;
    Keyword: TPascal_Keyword;
  begin
    Output.EPos := Parser.Tokens[Idx]^.EPos;

    // Find the first identifier after the semicolon
    TokenAfterSemi := Parser.ProbeR(Idx, [ttAscii]);
    if TokenAfterSemi = nil then
      begin
        DebugLog('No identifier found after "%s", skipping', [Output.Name.Text]);
        Result := Idx;
        Exit;
      end;

    Keyword := Pascal_Keyword(TokenAfterSemi^.Text);
    // Check for calling convention
    if Keyword in [kRegister, kPascal, kCdecl, kStdcall, kSafeCall] then
      begin
        Output.CallConv := TokenAfterSemi^.Text;
        DebugLog('Routine "%s" recognised calling convention: %s', [Output.Name.Text, TokenAfterSemi^.Text.Text]);

        // Locate the semicolon after the calling convention
        TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1, [ttSymbol], ';');
        if TokenAfterExternal = nil then
          begin
            DebugLog('In declaration of "%s", missing semicolon after calling convention "%s"', [Output.Name.Text, TokenAfterSemi^.Text.Text]);
            Result := -1;
            Exit;
          end;
        Output.EPos := TokenAfterExternal^.EPos;

        // Look for a subsequent identifier (possibly 'external')
        TokenAfterSemi := Parser.ProbeR(TokenAfterExternal^.Index + 1, [ttAscii]);
        if TokenAfterSemi = nil then
          begin
            // No further identifier, declaration ends after the semicolon
            Result := TokenAfterExternal^.Index + 1;
            Exit;
          end;
        // Check if it is 'external'
        if not TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal].Decl) then
          begin
            // Not external, declaration ends after the semicolon
            Result := TokenAfterExternal^.Index + 1;
            Exit;
          end;
        // Otherwise, it is 'external', continue processing below.
      end
    else if not TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal].Decl) then
      begin
        // Neither calling convention nor external, declaration ends after the semicolon
        Result := Idx;
        Exit;
      end;

    // At this point, TokenAfterSemi is 'external'
    Output.IsExternal := True;
    DebugLog('Routine "%s" marked as external', [Output.Name.Text]);

    // Extract library name (must be a string or identifier)
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
        // external without library name (valid: 'external;')
        DebugLog('external without library name (direct semicolon)', []);
        Result := TokenAfterExternal^.Index + 1;
        Exit;
      end
    else
      begin
        DebugLog('In external declaration of "%s", library name missing or invalid (string or identifier expected)', [Output.Name.Text]);
        Result := -1;
        Exit;
      end;

    // Check for 'name' or 'index' clauses
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

            // Find the following semicolon
            TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1, [ttSymbol], ';');
            if TokenAfterExternal = nil then
              begin
                DebugLog('In "%s" clause of "%s", missing terminating semicolon', [TokenAfterSemi^.Text.Text, Output.Name.Text]);
                Result := -1;
                Exit;
              end;
            // Concatenate all tokens between the keyword and the semicolon
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
        // external without name/index
        DebugLog('external without name/index clause', []);
        Output.EPos := TokenAfterSemi^.EPos;
      end;

    Result := TokenAfterSemi^.Index + 1;
  end;

{
  * Core function/procedure declaration processing.
  * Inputs: ProcDeclToken (the 'function' or 'procedure' token) and
  * ProcNameToken (the routine name token). Extracts parameters (if any),
  * return type (for functions), and then processes calling convention/external.
  * Returns the next index to process, or -1 on error.
  *
  * Parsing strategy:
  * 1. Use ProbeR to find the first symbol after the name; it should be '(' ':' or ';'.
  * 2. If it is '(', extract the parameter list using ProbeR to locate the matching ')'.
  * 3. If it is a procedure and followed by ';', process calling convention/external directly.
  * 4. If it is a function and followed by ':', extract the return type, then process
  *    calling convention/external.
  * 5. Any unexpected structure logs an error and returns -1.
}
  function ProcessProcDeclaration(ProcDeclToken, ProcNameToken: PTokenData;
    var Output: tfunc_decl): Integer;
  var
    TokenAfterName, TokenAfterParen, TokenAfterColon: PTokenData;
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

    // Find first symbol after the name
    TokenAfterName := Parser.ProbeR(ProcNameToken^.Index + 1, [ttSymbol]);
    if (TokenAfterName <> nil) and (TokenAfterName^.TokenType = ttSymbol) then
      begin
        // Handle parameter list
        if TokenAfterName^.Text.Same('(') then
          begin
            TokenAfterParen := Parser.ProbeR(TokenAfterName^.Index + 1, [ttSymbol], ')');
            if TokenAfterParen = nil then
              begin
                DebugLog('In routine "%s", missing matching closing parenthesis ")"', [Output.Name.Text]);
                Result := -1;
                Exit;
              end;
            Output.ParamDecl := Parser.TokenCombine(TokenAfterName^.Index, TokenAfterParen^.Index);
            DebugLog('Parameters: %s', [Output.ParamDecl.Text]);
            TokenAfterName := Parser.ProbeR(TokenAfterParen^.Index + 1, [ttSymbol]);
          end;

        // If procedure (not function) and followed by ';'
        if (not Output.IsFunction) and TokenAfterName^.Text.Same(';') then
          begin
            Output.EPos := TokenAfterName^.EPos;
            DebugLog('Procedure "%s" directly followed by semicolon, entering external processing', [Output.Name.Text]);
            Result := ProcessExternalAndCallingConvention(TokenAfterName^.Index + 1, Output);
            if Result = -1 then
                DebugLog('Routine "%s" external processing failed', [Output.Name.Text])
            else
                DebugLog('Routine "%s" parsed successfully', [Output.Name.Text]);
            Exit;
          end;

        // If function, must handle return type
        if Output.IsFunction and TokenAfterName^.Text.Same(':') then
          begin
            // Get return type identifier
            TokenAfterColon := Parser.ProbeR(TokenAfterName^.Index + 1, [ttAscii, ttSymbol]);
            if TokenAfterColon = nil then
              begin
                DebugLog('In function "%s", return type name not found', [Output.Name.Text]);
                Result := -1;
                Exit;
              end;
            TokenAfterParen := Parser.ProbeR(TokenAfterColon^.Index + 1, [ttSymbol], ';');
            if TokenAfterParen = nil then
              begin
                DebugLog('In function "%s", missing terminating semicolon after return type', [Output.Name.Text]);
                Result := -1;
                Exit;
              end;

            Output.ResultDecl := TokenAfterColon^.Text;
            DebugLog('Return type: %s', [Output.ResultDecl.Text]);
            Result := ProcessExternalAndCallingConvention(TokenAfterParen^.Index + 1, Output);
            if Result = -1 then
                DebugLog('Routine "%s" external processing failed', [Output.Name.Text])
            else
                DebugLog('Routine "%s" parsed successfully', [Output.Name.Text]);
            Exit;
          end
        else
          begin
            DebugLog('In routine "%s", unexpected symbol "%s" (expected ";" or ":")',
              [Output.Name.Text, TokenAfterName^.Text.Text]);
            Result := -1;
            Exit;
          end;
      end
    else
      begin
        DebugLog('In routine "%s", valid name or subsequent symbol not found', [Output.Name.Text]);
        Result := -1;
      end;
  end;

{
  * Extracts unit names from a uses clause, deduplicates, and adds them to UsesList.
  * Parameter AText is the text after the 'uses' keyword (e.g., 'SysUtils, Classes').
  * This process never fails; if parsing errors occur, they are logged and the result
  * may be empty.
  *
  * Processing steps:
  * 1. Use an independent TTextParsing (tsPascal) on the text to remove comments.
  * 2. Split by commas to get candidate unit names.
  * 3. Trim whitespace and filter empty strings.
  * 4. Merge into the main UsesList with automatic deduplication using UmlMergeStrings.
  *
  * Note: Conditional compilation directives (e.g., $IFDEF) are treated as comments
  * and removed. Thus the extracted list may include unit names from all conditional
  * branches, which is a simplification that fits most use cases.
}
  procedure ProcessUsesClause(const AText: TP_String);
  var
    LocalParser: TTextParsing;
    LocalList: TPascalStringList;
    CleanedText: TP_String;
    i: Integer;
  begin
    DebugLog('Processing uses clause, raw text: %s', [AText.Text]);
    LocalParser := TTextParsing.Create(AText, tsPascal);
    LocalParser.DeletedComment; // Remove comments
    CleanedText := LocalParser.ParsingData.Text.DeleteChar(#13#10#9); // Remove newlines and tabs
    DisposeObject(LocalParser);

    LocalList := TPascalStringList.Create;
    UmlSeparatorText(CleanedText, LocalList, ','); // Split by comma
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
    UmlMergeStrings(LocalList, UsesList, True); // Merge and deduplicate
    DisposeObject(LocalList);
  end;

type
  { Represents the current parsing region, used for state machine control }
  TCurrentSection = (csBeginUnit, csEndUnit, csIntf, csIntfUses, csImp);
  TCurrentSections = set of TCurrentSection;

var
  i: Integer;
  CurrentToken, NextToken, NextNextToken: PTokenData;
  DeclItem: pfunc_decl;
  Sections: TCurrentSections;
  NestedLevel: Integer; // Tracks nesting depth (classes, records, interfaces)
  Keyword: TPascal_Keyword;
  PreComment: TP_String;
  FuncCount: Integer; // Number of successfully parsed routines
  ErrorOccurred: Boolean; // Flag indicating if an error occurred
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

      // Skip whitespace tokens (ttUnknow and empty trim) – do not add to FuncList
      if (CurrentToken^.TokenType = ttUnknow) and (CurrentToken^.Text.TrimChar(#32#9#13#10) = '') then
        begin
          Inc(i);
          Continue;
        end;

      New(DeclItem);
      DeclItem^.Init;
      { +++ RECORD CURRENT NESTING LEVEL +++ }
      DeclItem^.NestLevel := NestedLevel;

      DeclItem^.Body := CurrentToken^.Text;
      DeclItem^.IsProc := False;
      DeclItem^.BPos := CurrentToken^.BPos;
      DeclItem^.EPos := CurrentToken^.EPos;

      { Block 1: Handle nested structures (classes, interfaces, records, etc.)
        Only active when we are in the interface section, not in implementation,
        and NestedLevel > 0. This block maintains the NestedLevel counter so
        that inner declarations do not interfere with top-level parsing. }
      if (not(csEndUnit in Sections)) and (csIntf in Sections) and
        (not(csImp in Sections)) and (NestedLevel > 0) then
        begin
          if (CurrentToken^.TokenType = ttAscii) then
            begin
              Keyword := Pascal_Keyword(CurrentToken^.Text);

              { Encountering 'class' with a preceding '=' could indicate a class
                declaration; increase nesting unless followed by '(', ';', or 'of'. }
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
                { 'interface' with a preceding '=' similarly indicates an interface declaration }
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
                { 'record' always increases nesting }
              else if Keyword = kRecord then
                begin
                  Inc(NestedLevel);
                  DebugLog('Nesting +1 (record), depth: %d', [NestedLevel]);
                end
                { 'end' decreases nesting, but only if it is a standalone 'end' (not 'end;' inside a statement) }
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

        { Block 2: Process top-level structures (non-nested)
          Only when NestedLevel = 0 and we have not reached 'end.' }
      else if (not(csEndUnit in Sections)) and (NestedLevel = 0) and
        (CurrentToken^.TokenType = ttAscii) then
        begin
          Keyword := Pascal_Keyword(CurrentToken^.Text);

          { Locate the 'unit' keyword and record the unit name }
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

          { Once the unit keyword is found, continue parsing }
          if (csBeginUnit in Sections) then
            begin
              { Look for 'interface' }
              if (not(csIntf in Sections)) and (Keyword = kInterface) then
                begin
                  Include(Sections, csIntf);
                  InterfaceToken := DeclItem;
                  DebugLog('Entering interface section', []);
                end
                { Look for 'implementation' }
              else if (not(csImp in Sections)) and (Keyword = kImplementation) then
                begin
                  Include(Sections, csImp);
                  ImplementationToken := DeclItem;
                  DebugLog('Entering implementation section', []);
                end
                { In implementation section, look for 'initialization', 'finalization', 'end.' }
              else if (csImp in Sections) and (not(csEndUnit in Sections)) and
                (CurrentToken^.TokenType = ttAscii) then
                begin
                  if Keyword = kInitialization then
                    begin
                      InitToken := DeclItem;
                      DebugLog('Initialization block identified', []);
                    end
                  else if Keyword = kFinalization then
                    begin
                      FinalToken := DeclItem;
                      DebugLog('Finalization block identified', []);
                    end
                  else if (Parser.ComparePosStr(CurrentToken^.BPos, 'end.')) then
                    begin
                      Include(Sections, csEndUnit);
                      DeclItem^.Body := 'end.';
                      Inc(i); // Skip further processing of 'end.'
                      EndToken := DeclItem;
                      DebugLog('End. identified', []);
                    end;
                end
                { In interface section (before implementation), parse uses and function/procedure declarations }
              else if (csIntf in Sections) and (not(csImp in Sections)) then
                begin
                  { Handle uses clause }
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
                      DeclItem^.Body := ''; // uses is not stored as a function item
                      DebugLog('Uses clause processed', []);
                    end;
                  { Ensure uses is processed only once }
                  Include(Sections, csIntfUses);

                  { Identify function/procedure declarations }
                  if (Keyword in [kFunction, kProcedure]) then
                    begin
                      { Extract preceding comment and store it }
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

                    { Handle class, interface, record starts to increase nesting }
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

      { Add the current declaration item to the list }
      DeclItem^.Index := FuncList.Count;
      FuncList.Add(DeclItem);
      Inc(i);
    end; // while

  { After parsing, check if unit structure is complete }
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
          DebugLog('Parsing failed, missing required structure', []);
    end;
end;

{ tpascal_func_decl_tool.Clear ----------------------------------------------------
  Frees all declaration memory and clears the list. Iterates backwards to
  avoid index shifts. }
procedure tpascal_func_decl_tool.Clear;
var
  i: Integer;
begin
  for i := FuncList.Count - 1 downto 0 do
    begin
      FuncList[i]^.Init; // Clear string fields to help garbage collection
      Dispose(FuncList[i]);
    end;
  FuncList.Clear;
end;

{ tpascal_func_decl_tool.Combine --------------------------------------------------
  Concatenates the bodies of all declaration items in the index range
  BTokenIdx..ETokenIdx. If the start index is greater than the end, they are
  swapped. Useful for reconstructing code sections. }
function tpascal_func_decl_tool.Combine(const BTokenIdx, ETokenIdx: Integer): TP_String;
var
  Lo, Hi, Idx: Integer;
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
  Idx := Lo;
  while Idx <= Hi do
    begin
      Result.Append(FuncList[Idx]^.Body);
      Inc(Idx);
    end;
end;

end.
 
