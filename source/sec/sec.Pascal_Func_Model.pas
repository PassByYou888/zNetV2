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
  * =============================================================================
  * Z.Pascal_Func_Model - Middle-Layer Metadata Model for Pascal Function
  * Declarations
  * =============================================================================
  *
  * This unit defines the core data structures and a container class that serves
  * as the intermediate layer between the low-level Pascal parser
  * (Z.Pascal_Func_Tool) and high-level code generators.
  *
  * ARCHITECTURE OVERVIEW
  * ---------------------
  *
  *   Z.Pascal_Func_Tool (Parser)
  *     -> Extracts raw declarations (tfunc_decl records) from Pascal source.
  *
  *   TPascal_Func_Model (THIS UNIT)
  *     -> Converts raw declarations into structured, normalized models
  *        (TFunctionStructure, TParamStructure) suitable for further
  *        processing. Provides type normalization, comment cleaning,
  *        parameter description extraction, and JSON serialization.
  *
  *   pas_mcp_generator_tool / py_mcp_generator_tool (Generators)
  *     -> Use the model to generate tool provider code.
  *
  * COMMENT PROCESSING PIPELINE
  * ---------------------------
  *
  *   Source comment text
  *     |
  *     v
  *   CleanComment()             - Extract plain text from comment tokens;
  *                                strip comment markers; normalise line
  *                                endings to LF.
  *     |
  *     v
  *   ExtractParamDescriptions() - Line-by-line state machine. Recognises
  *                                parameter declarations in several styles
  *                                and accumulates every following indented
  *                                line into that parameter's description.
  *     |
  *     v
  *   TParamDescPool             - Key/value store keyed by the original
  *                                parameter name.
  *
  * SUPPORTED PARAMETER-DECLARATION STYLES
  * --------------------------------------
  *
  *   A. Line-leading name        :  name: description
  *                                  name = description
  *                                  name description
  *
  *   B. Doxygen immediate        :  @name description
  *                                  \name description
  *
  *   C. Doxygen with keyword     :  @param name description
  *                                  \arg name description
  *                                  @parameter name description
  *
  *   In every style the parameter name must be the FIRST identifier on its
  *   line (or immediately after a Doxygen marker). A parameter name that
  *   appears in the middle of a natural-language sentence is NOT treated as
  *   a declaration. This prevents text such as
  *       "when target produces a single file..."
  *   from polluting the description of 'target'.
  *
  *   Once a parameter declaration is recognised, every following line whose
  *   indentation is STRICTLY GREATER than the declaration line's indentation
  *   is appended verbatim (including its original leading whitespace) to the
  *   parameter's description. The block ends at the first non-indented line,
  *   blank line, or next parameter declaration.
  *
  * BLOCK-COMMENT MARKER NORMALISATION
  * ----------------------------------
  * Two families of comment text reach this unit:
  *
  *   (1) Pure Pascal comments, e.g.:
  *           (---*
  *             source: xxx
  *           *---)
  *       After CleanComment the lines carry no leading marker.
  *
  *   (2) C-style block comments that have been converted into Pascal form by
  *       Translate_C_Typ_To_Pascal. These normalise to:
  *           { * @param source xxx
  *            * @param lang   yyy }
  *       Every line after the opening brace carries a leading asterisk
  *       block-comment marker.
  *
  * The state machine strips the optional leading asterisk before analysing
  * each line. The whitespace that follows the asterisk is preserved: it
  * carries the block's own indentation and is used to compute the nesting
  * depth of continuation lines.
  *
  * NOTES AND LIMITATIONS
  * ---------------------
  *   - Only top-level functions and procedures (NestLevel = 0) are included.
  *   - Type normalization supports only the integer / float / string families.
  *     Any other type results in an empty string and the routine is skipped.
  *   - Parameter descriptions are extracted from comments immediately
  *     preceding the routine. The comment must be directly adjacent (no blank
  *     lines) to be correctly associated.
  *   - This model is designed to be consumed by code generators; it is not a
  *     full Pascal AST but a simplified view suitable for RPC binding.
  *
  * AUTHOR AND VERSION
  * ------------------
  *   Original author: qq600585 (circa 2012)
  *   Modernised and documented for the Z-framework ecosystem.
  *   Version: 3.1 (2026-09-25)
  *     - Automatic duplicate-function-name correction added.
  *   Version: 3.0 (2026-09-20)
  *     - Robust block-comment marker handling (C-to-Pascal path).
  *     - Multi-line parameter description state machine.
  *     - Full English comments and status output.
  *     - Formatter-safe multi-line comment layout (leading asterisks).
  * =============================================================================
*)
unit sec.Pascal_Func_Model;

{$DEFINE FPC_DELPHI_MODE}
{$I ..\Z.Define.inc}

interface

uses
  {$IFDEF FPC}
  (*FPC-specific generic list support (backported from fgl).*)
  sec.FPC.GenericList,
  {$ENDIF FPC}
  sec.Core,
  sec.PascalStrings, sec.UPascalStrings,
  sec.Pascal_Func_Tool,
  sec.Parsing,
  sec.Json,
  sec.UnicodeMixedLib,
  sec.Status,
  sec.ListEngine,
  sec.HashList.Templet; (* For TPascalString_Big_Hash_Pair_Pool *)

type
  (*
    * TParamStructure - Metadata for a single parameter of a function or
    * procedure.
    *
    * Fields
    *   Name        : The original parameter name as declared in Pascal.
    *   Typ         : The raw Pascal type string (e.g. 'Integer', 'TColor').
    *   PascalType  : Normalized type name (one of 'Int64', 'Double', 'string',
    *                 or empty if unsupported).
    *   Description : Human-readable description extracted from the comment,
    *                 if any.
  *)
  TParamStructure = record
    Name: TP_String;
    Typ: TP_String;
    PascalType: TP_String;
    Description: TP_String;
    procedure Clear;
  end;

  (* Dynamic array of TParamStructure, used to hold all parameters of a routine. *)
  TParamArray = array of TParamStructure;

  (*
    * TFunctionStructure - Complete metadata for a Pascal function or procedure.
    *
    * Fields
    *   Name        : The routine name (e.g. 'Add').
    *   IsFunction  : True if this is a function (has a return type), False
    *                 for a procedure.
    *   Params      : Array of parameter metadata.
    *   ReturnType  : Normalized return type (empty for procedures).
    *   Comment     : Cleaned comment text (without Pascal comment markers)
    *                 extracted from the source.
  *)
  TFunctionStructure = record
    Name: TP_String;
    IsFunction: boolean;
    Params: TParamArray;
    ReturnType: TP_String;
    Comment: TP_String;
    procedure Clear;
    function Clone: TFunctionStructure;
  end;

  (* Generic list of TFunctionStructure records. *)
  TFunctionList = TGenericsList<TFunctionStructure>;

  (*
    * TTyp_Normalize_Func - Selects the type normalization scheme.
    *
    *   tnf_Json  : Integer family -> 'int64', Float family -> 'double',
    *               String family -> 'string'. Used for JSON schema output.
    *   tnf_ABI   : Integer family -> lowercased original (e.g. 'integer'),
    *               Float family  -> lowercased original, String family ->
    *               lowercased original. Used for ABI-level output.
  *)
  TTyp_Normalize_Func = (tnf_Json, tnf_ABI);

  (*
    * TPascal_Func_Model - Main container for parsed metadata of a Pascal unit.
    *
    * This class holds the unit name and a list of all top-level functions and
    * procedures extracted from the interface section. It can be populated from
    * a Z.Pascal_Func_Tool parser (LoadFromParser) or from a JSON string
    * (LoadFromJson), and can export itself to JSON (SaveToJson) as well as
    * write back to a parser object (SaveToParser).
    *
    * Properties
    *   UnitName            : The name of the Pascal unit (e.g. 'MyUnit').
    *   Funcs               : List of all extracted routines.
    *   FuncCount           : Number of routines.
    *   Typ_Normalize_Func  : Type normalization scheme (JSON or ABI).
  *)
  TPascal_Func_Model = class(TCore_Object_Intermediate)
  private
    FUnitName: TP_String;
    FTyp_Normalize_Func: TTyp_Normalize_Func;
    FFuncs: TFunctionList;
    function GetFuncCount: integer;
    function Do_Normalize_Type(const Typ: TP_String): TP_String;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    property Typ_Normalize_Func: TTyp_Normalize_Func read FTyp_Normalize_Func write FTyp_Normalize_Func;
    property UnitName: TP_String read FUnitName write FUnitName;
    property Funcs: TFunctionList read FFuncs;
    property FuncCount: integer read GetFuncCount;

    (*
      * LoadFromParser - Populates the model from a parser instance.
      *
      *   Parser  : A successfully parsed tpascal_func_decl_tool object.
      *   Report  : Optional TPascalStringList to receive a report of skipped
      *             declarations. If provided, it is cleared and filled with
      *             messages about declarations that were not loaded (e.g.
      *             unsupported types, var/out parameters).
      *
      * Duplicate function names are automatically corrected after loading.
    *)
    procedure LoadFromParser(Parser: tpascal_func_decl_tool; Report: TPascalStringList);

    (*
      * SaveToParser - Writes the model data back into a parser object,
      * allowing further processing or source code generation.
      *
      *   Parser  : The target parser object, whose previous content is cleared.
    *)
    procedure SaveToParser(Parser: tpascal_func_decl_tool);

    (*
      * LoadFromJson - Restores the model from a JSON string.
      *
      *   JsonStr : A valid JSON string containing unit name and function list.
      *
      * Duplicate function names are automatically corrected after loading.
    *)
    procedure LoadFromJson(const JsonStr: TP_String);

    (*
      * SaveToJson - Exports the model to a JSON string.
      *
      * Returns a formatted JSON string.
    *)
    function SaveToJson: TP_String;

    (*
      * FixDuplicateFunctionNames - Scans all loaded functions and renames
      * any duplicates by appending a numeric suffix (1, 2, 3, ...).
      *
      * The comparison is case-insensitive (Pascal identifier rules).
      * For example, three functions named "Add" become
      * "Add", "Add1", "Add2".
      *
      * This method is invoked automatically at the end of LoadFromParser
      * and LoadFromJson to guarantee unique function names in the model.
      * It can also be called manually if the caller mutates FFuncs.
    *)
    procedure FixDuplicateFunctionNames;
  end;

  (*
    * Normalize_Json_Type - Converts a Pascal type string to a canonical JSON
    * type name.
    *
    *   Recognises integer types (Integer, Int64, Cardinal, ...) -> 'int64'
    *   Recognises floating point types (Double, Single, Extended, ...) ->
    *     'double'
    *   Recognises string types (string, TP_String, AnsiString, UnicodeString,
    *     ...) -> 'string'
    *   All other types return an empty string (unsupported).
  *)
function Normalize_Json_Type(const Typ: TP_String): TP_String;

(*
  * Normalize_ABI_Type - Converts a Pascal type string to a canonical ABI
  * type name (lowercased original for recognized families).
*)
function Normalize_ABI_Type(const Typ: TP_String): TP_String;

var
  (* Global flag to enable/disable logging within this unit. *)
  PascalFuncModel_LogEnabled: boolean = False;

implementation

(* ---------------------------------------------------------------------------
  * Logging helpers
  * --------------------------------------------------------------------------- *)

(* Internal logging procedure; outputs message only when logging is enabled. *)
procedure Log(const Msg: TP_String); overload;
begin
  if PascalFuncModel_LogEnabled then
    DoStatus('[PascalFuncModel] ' + Msg);
end;

(* Internal logging procedure with formatting. *)
procedure Log(const Fmt: TP_String; const Args: array of const); overload;
begin
  if PascalFuncModel_LogEnabled then
    DoStatus('[PascalFuncModel] ' + PFormat(Fmt, Args));
end;

(* ---------------------------------------------------------------------------
  * TParamStructure
  * --------------------------------------------------------------------------- *)

(* Resets all fields to empty strings. *)
procedure TParamStructure.Clear;
begin
  Name := '';
  Typ := '';
  PascalType := '';
  Description := '';
end;

(* ---------------------------------------------------------------------------
  * TFunctionStructure
  * --------------------------------------------------------------------------- *)

(*
  * Releases all parameter records and resets the structure to a clean state.
  * Called before assigning new data to avoid memory leaks.
*)
procedure TFunctionStructure.Clear;
var
  i: integer;
begin
  Name := '';
  IsFunction := False;
  for i := 0 to Length(Params) - 1 do
    Params[i].Clear;
  SetLength(Params, 0);
  ReturnType := '';
  Comment := '';
end;

(*
  * Creates a deep copy of the structure, ensuring that the dynamic array of
  * parameters is copied element by element.
*)
function TFunctionStructure.Clone: TFunctionStructure;
var
  i: integer;
begin
  Result.Name := Self.Name;
  Result.IsFunction := Self.IsFunction;
  Result.ReturnType := Self.ReturnType;
  Result.Comment := Self.Comment;
  SetLength(Result.Params, Length(Self.Params));
  for i := 0 to High(Self.Params) do
    Result.Params[i] := Self.Params[i];
end;

(* ---------------------------------------------------------------------------
  * TPascal_Func_Model
  * --------------------------------------------------------------------------- *)

function TPascal_Func_Model.Do_Normalize_Type(const Typ: TP_String): TP_String;
begin
  case FTyp_Normalize_Func of
    tnf_Json: Result := Normalize_Json_Type(Typ);
    tnf_ABI: Result := Normalize_ABI_Type(Typ);
    else
      RaiseInfo('error');
  end;
end;

(* Constructor: initialises the function list and logs creation. *)
constructor TPascal_Func_Model.Create;
begin
  inherited Create;
  FUnitName := '';
  FTyp_Normalize_Func := TTyp_Normalize_Func.tnf_Json;
  FFuncs := TFunctionList.Create;
  Log('TPascal_Func_Model created.');
end;

(* Destructor: clears all data and frees the function list. *)
destructor TPascal_Func_Model.Destroy;
begin
  Clear;
  FFuncs.Free;
  inherited Destroy;
  Log('TPascal_Func_Model destroyed.');
end;

(* Clears all functions and resets unit name. *)
procedure TPascal_Func_Model.Clear;
var
  i: integer;
begin
  for i := 0 to FFuncs.Count - 1 do
    FFuncs[i].Clear;
  FFuncs.Clear;
  FUnitName := '';
  Log('Structure cleared.');
end;

(* Returns the number of functions currently stored. *)
function TPascal_Func_Model.GetFuncCount: integer;
begin
  Result := FFuncs.Count;
end;

(* ---------------------------------------------------------------------------
  * Type normalization
  * --------------------------------------------------------------------------- *)

function Normalize_Json_Type(const Typ: TP_String): TP_String;
var
  lowTyp: TP_String;
begin
  lowTyp := Typ.TrimChar(#32#9).LowerText;
  if lowTyp.Same('integer', 'int64', 'cardinal', 'longint', 'dword') or lowTyp.Same('word', 'smallint', 'byte', 'uint64', 'longword') then
    Result := 'int64'
  else if lowTyp.Same('double', 'single', 'extended', 'real') then
    Result := 'double'
  else if lowTyp.Same('tpascalstring', 'tupascalstring', 'tp_string', 'string', 'ansistring', 'unicodestring') or lowTyp.Same('pchar', 'pansichar', 'pwidechar') then
    Result := 'string'
  else
    Result := '';
end;

function Normalize_ABI_Type(const Typ: TP_String): TP_String;
var
  lowTyp: TP_String;
begin
  lowTyp := Typ.TrimChar(#32#9).LowerText;
  if lowTyp.Same('integer', 'int64', 'cardinal', 'longint', 'dword') or lowTyp.Same('word', 'smallint', 'byte', 'uint64', 'longword') then
    Result := lowTyp
  else if lowTyp.Same('double', 'single', 'extended', 'real') then
    Result := lowTyp
  else if lowTyp.Same('tpascalstring', 'tupascalstring', 'tp_string', 'string', 'ansistring', 'unicodestring') or lowTyp.Same('pchar', 'pansichar', 'pwidechar') then
    Result := lowTyp
  else
    Result := '';
end;

(* ---------------------------------------------------------------------------
  * CleanComment
  * --------------------------------------------------------------------------- *)

(*
  * Extract the actual comment text from a Pascal comment token.
  *
  * Behaviour
  * ---------
  *   - Runs the input through TTextParsing(tsPascal) to locate ttComment
  *     tokens.
  *   - Converts each comment token into its plain-text form via
  *     Translate_Pascal_Decl_Comment_To_Text.
  *   - Trims surrounding whitespace from each part.
  *   - Joins parts with a single LF (#10).
  *
  * The LF-only join keeps the downstream line splitter
  * (umlSeparatorText(..., #10)) simple and avoids the trailing CR that would
  * otherwise be produced by sLineBreak on Windows.
*)
function CleanComment(const Cmt: TP_String): TP_String;
var
  Parser: TTextParsing;
  i: integer;
  Token: PTokenData;
  Parts: TP_ArrayString;
  Part: TP_String;
begin
  Result := '';
  if Cmt = '' then
    Exit;

  Parser := TTextParsing.Create(Cmt, tsPascal);
  try
    SetLength(Parts, 0);
    for i := 0 to Parser.TokenCount - 1 do
    begin
      Token := Parser.Tokens[i];
      if Token^.tokenType = ttComment then
      begin
        Part := TTextParsing.Translate_Pascal_Decl_Comment_To_Text(Token^.Text);
        Part := Part.TrimChar(#32#9#13#10);
        if Part <> '' then
        begin
          SetLength(Parts, Length(Parts) + 1);
          Parts[High(Parts)] := Part;
        end;
      end;
    end;

    (* Join parts with LF only; keeps line splitting trivial downstream. *)
    Result := '';
    for i := 0 to High(Parts) do
    begin
      if i > 0 then
        Result := Result + #10;
      Result := Result + Parts[i];
    end;
  finally
    Parser.Free;
  end;
end;

(* ---------------------------------------------------------------------------
  * TParamDescPool
  * --------------------------------------------------------------------------- *)

(*
  * TParamDescPool - Hash map that stores parameter descriptions keyed by
  * parameter name. Used internally by ExtractParamDescriptions to gather
  * descriptions and automatically manage TP_String memory.
*)
type
  TParamDescPool = class(TPascalString_Big_Hash_Pair_Pool<TP_String>)
  public
    procedure DoFree(var Key: TPascalString; var Value: TP_String); override;
  end;

procedure TParamDescPool.DoFree(var Key: TPascalString; var Value: TP_String);
begin
  Value := '';
  inherited DoFree(Key, Value);
end;

(* ---------------------------------------------------------------------------
  * ExtractParamDescriptions
  * --------------------------------------------------------------------------- *)

(*
  * ExtractParamDescriptions - Extracts parameter descriptions from a comment.
  *
  * This is a line-by-line state machine. It walks the comment one logical line
  * at a time, maintains the current parameter's name / description /
  * indentation, and flushes that block when it ends.
  *
  * Algorithm
  * ---------
  *   For each line:
  *     - Locate the content start:
  *         skip leading whitespace,
  *         skip an optional leading asterisk block-comment marker.
  *       The remainder (including its own leading whitespace) is the
  *       ContentLine used for indentation and continuation logic.
  *     - If ContentLine is blank                -> flush current block.
  *     - Else if ContentLine starts a parameter -> flush; start a new block.
  *     - Else if its indentation is deeper than
  *       the current parameter's indentation    -> append to current block.
  *     - Else                                    -> flush current block.
  *
  * Parameter declaration forms recognised
  * --------------------------------------
  *   A. Line-leading name        :  name ...
  *   B. Doxygen immediate        :  @name ...   /  \name ...
  *   C. Doxygen with keyword     :  @param name ...
  *                                  \arg name ...
  *                                  @parameter name ...
  *
  * In all forms the parameter name must be the first identifier on the line
  * (or immediately after a Doxygen marker + keyword). A name that appears in
  * the middle of a sentence is never treated as a declaration.
  *
  * Description extraction
  * ----------------------
  * Once a declaration is recognised, the text after the parameter name is
  * taken as the initial description. Any leading separator (':', '=', and
  * their fullwidth variants) is stripped. Every following line whose
  * indentation is strictly greater than the declaration line's indentation is
  * appended verbatim (including its original leading whitespace). Lines are
  * joined with LF (#10).
*)
function ExtractParamDescriptions(const CommentText___: TP_String; const ParamNames: TP_ArrayString): TParamDescPool;

  (* True if c may start a Pascal identifier. *)
  function IsIdentStart(c: TP_Char): boolean;
  begin
    Result := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z')) or (c = '_');
  end;

  (* True if c may continue a Pascal identifier. *)
  function IsIdentChar(c: TP_Char): boolean;
  begin
    Result := IsIdentStart(c) or ((c >= '0') and (c <= '9'));
  end;

  (* True if c is a horizontal whitespace character. *)
  function IsHSpace(c: TP_Char): boolean;
  begin
    Result := (c = ' ') or (c = #9);
  end;

var
  CommentText: TP_String;
  Lines: TPascalStringList;
  CurrentParam: TP_String;
  CurrentDesc: TP_String;
  ParamIndent: integer;
  RawLine: TP_String;
  ContentLine: TP_String;
  TrimmedLine: TP_String;
  MatchedParam: TP_String;
  DescStartPos: integer;
  RawIndent: integer;
  idx: integer;
  i: integer;
  Found: boolean;
  Pool: TParamDescPool;

(* Advance past horizontal whitespace. *)
  procedure SkipWS(const S: TP_String; var pos: integer);
  begin
    while (pos <= S.Len) and IsHSpace(S[pos]) do
      Inc(pos);
  end;

  (* Read an identifier starting at pos; advances pos past it. *)
  function ReadIdent(const S: TP_String; var pos: integer): TP_String;
  begin
    Result := '';
    while (pos <= S.Len) and IsIdentChar(S[pos]) do
    begin
      Result := Result + S[pos];
      Inc(pos);
    end;
  end;

  (* Return the canonical parameter name if Name_ matches one, else ''. *)
  function MatchParam(const Name_: TP_String): TP_String;
  var
    jj: integer;
  begin
    Result := '';
    for jj := 0 to High(ParamNames) do
      if ParamNames[jj].Same(True, Name_) then
        Exit(ParamNames[jj]);
  end;

  (* Compute the number of leading horizontal whitespace characters. *)
  function ComputeIndent(const S: TP_String): integer;
  var
    k: integer;
  begin
    Result := 0;
    for k := 1 to S.Len do
      if IsHSpace(S[k]) then
        Inc(Result)
      else
        Break;
  end;

(*
  * Locate the content start of a raw line.
  *
  * Rules
  * -----
  *   - Skip leading horizontal whitespace.
  *   - If the next character is '*', treat it as a block-comment marker and
  *     skip it. The remainder (including its own leading whitespace) is the
  *     content line; that whitespace carries the block's indentation.
  *   - Otherwise the raw line is returned unchanged.
  *
  * This normalises both of these into the same shape:
  *
  *   Pure Pascal comment     :  '  source: xxx'
  *                               -> '  source: xxx'    (unchanged)
  *
  *   C-style block comment   :  ' *         yyy'
  *                               -> '         yyy'     (asterisk stripped)
  *
  * The returned string keeps the content's own leading whitespace so that
  * indentation-based continuation logic works uniformly across both
  * comment families.
*)
  function GetContentLine(const S: TP_String): TP_String;
  var
    k: integer;
  begin
    k := 1;
    while (k <= S.Len) and IsHSpace(S[k]) do
      Inc(k);
    if (k <= S.Len) and (S[k] = '*') then
      Result := S.GetString(k + 1, S.Len + 1)
    else
      Result := S;
  end;

(*
  * Try to recognise a parameter declaration at the start of TrimmedLine_.
  *
  * On success, MatchedName_ receives the canonical parameter name and
  * DescStartPos_ receives the 1-based character position immediately after
  * the name (so the description text is
  * TrimmedLine_[DescStartPos_ .. Len]).
*)
  function TryMatchParamLine(const TrimmedLine_: TP_String; out MatchedName_: TP_String; out DescStartPos_: integer): boolean;
  var
    pos: integer;
    ident: TP_String;
    canonical: TP_String;
  begin
    Result := False;
    MatchedName_ := '';
    DescStartPos_ := 1;
    if TrimmedLine_.Len = 0 then
      Exit;

    pos := 1;
    SkipWS(TrimmedLine_, pos);
    if pos > TrimmedLine_.Len then
      Exit;

    (* Form B / C: Doxygen marker. *)
    if (TrimmedLine_[pos] = '@') or (TrimmedLine_[pos] = '\') then
    begin
      Inc(pos);
      SkipWS(TrimmedLine_, pos);
      if pos > TrimmedLine_.Len then
        Exit;

      ident := ReadIdent(TrimmedLine_, pos);
      if ident = '' then
        Exit;

      (* Keyword form: '@param name', '@arg name', '@parameter name'. *)
      if ident.Same('param') or ident.Same('arg') or ident.Same('parameter') then
      begin
        SkipWS(TrimmedLine_, pos);
        if pos > TrimmedLine_.Len then
          Exit;
        ident := ReadIdent(TrimmedLine_, pos);
        if ident = '' then
          Exit;
      end;

      canonical := MatchParam(ident);
      if canonical = '' then
        Exit;

      MatchedName_ := canonical;
      DescStartPos_ := pos;
      Result := True;
      Exit;
    end;

    (* Form A: line-leading name. *)
    ident := ReadIdent(TrimmedLine_, pos);
    if ident = '' then
      Exit;

    canonical := MatchParam(ident);
    if canonical = '' then
      Exit;

    MatchedName_ := canonical;
    DescStartPos_ := pos;
    Result := True;
  end;

(*
  * Extract the description text after the parameter name and strip any
  * leading separator characters (ASCII or fullwidth colon / equal).
*)
  function ExtractDescAfterName(const TrimmedLine_: TP_String; DescStartPos_: integer): TP_String;
  var
    desc: TP_String;
  begin
    Result := '';
    if DescStartPos_ > TrimmedLine_.Len then
      Exit;

    desc := TrimmedLine_.GetString(DescStartPos_, TrimmedLine_.Len + 1);
    desc := desc.TrimChar(#32#9);

    while (desc.Len > 0) and ((desc[1] = ':') or (desc[1] = '=') or (desc[1] = #$FF1A) or (desc[1] = #$FF1D)) do
      desc := desc.GetString(2, desc.Len + 1).TrimChar(#32#9);

    Result := desc;
  end;

  (* Write the accumulated parameter description into the pool. *)
  procedure FlushCurrent;
  begin
    if (CurrentParam <> '') and (CurrentDesc <> '') then
    begin
      if Pool.Exists(CurrentParam) then
        Pool.Key_Value[CurrentParam] :=
          Pool.Key_Value[CurrentParam] + #10 + CurrentDesc
      else
        Pool.Add(CurrentParam, CurrentDesc, False);
    end;
    CurrentParam := '';
    CurrentDesc := '';
    ParamIndent := -1;
  end;

begin
  CommentText := CleanComment(CommentText___);
  Pool := TParamDescPool.Create(256, '');
  Result := Pool;
  if (CommentText = '') or (Length(ParamNames) = 0) then
    Exit;

  CurrentParam := '';
  CurrentDesc := '';
  ParamIndent := -1;

  Lines := TPascalStringList.Create;
  try
    umlSeparatorText(CommentText, Lines, #10);

    for i := 0 to Lines.Count - 1 do
    begin
      (* Start from the raw line so that indentation is preserved. *)
      RawLine := TP_String(Lines[i]);

      (* Strip trailing CR / LF and horizontal whitespace. *)
      while (RawLine.Len > 0) and ((RawLine.Last = #13) or (RawLine.Last = #10)) do
        RawLine.DeleteLast;
      while (RawLine.Len > 0) and IsHSpace(RawLine.Last) do
        RawLine.DeleteLast;

        (*
          * Normalise block-comment markers: this is the step that makes the
          * C-to-Pascal path work. After this call, ContentLine carries only
          * the content and its own leading whitespace.
        *)
      ContentLine := GetContentLine(RawLine);
      TrimmedLine := ContentLine.TrimChar(#32#9);

      (* ---- Blank line: flush and continue. ---- *)
      if TrimmedLine.Len = 0 then
      begin
        FlushCurrent;
        Continue;
      end;

      (* ---- Parameter declaration? ---- *)
      Found := TryMatchParamLine(TrimmedLine, MatchedParam, DescStartPos);
      if Found then
      begin
        FlushCurrent;
        CurrentParam := MatchedParam;
        ParamIndent := ComputeIndent(ContentLine);
        CurrentDesc := ExtractDescAfterName(TrimmedLine, DescStartPos);
        Continue;
      end;

      (* ---- Continuation of the current parameter block? ---- *)
      RawIndent := ComputeIndent(ContentLine);
      if (CurrentParam <> '') and (RawIndent > ParamIndent) then
      begin
        if CurrentDesc <> '' then
          CurrentDesc := CurrentDesc + #10 + ContentLine
        else
          CurrentDesc := ContentLine;
        Continue;
      end;

      (* ---- Anything else terminates the current block. ---- *)
      FlushCurrent;
    end;

    (* Flush whatever block is still open. *)
    FlushCurrent;
  finally
    Lines.Free;
  end;

  Log('ExtractParamDescriptions: extracted %d entries', [Pool.Count]);
end;

(* ---------------------------------------------------------------------------
  * LoadFromParser
  * --------------------------------------------------------------------------- *)

(*
  * Populates the model from a tpascal_func_decl_tool parser instance.
  *
  * The parser must have been built by CreateFrom_Pascal_Code or
  * CreateFrom_C_Code and must have ParseSuccess = True. Declarations that
  * cannot be represented (nested routines, var/out parameters, unsupported
  * types) are skipped and reported in the optional Report list.
  *
  * After all declarations have been loaded, FixDuplicateFunctionNames is
  * invoked automatically so that the model always contains uniquely named
  * routines.
*)
procedure TPascal_Func_Model.LoadFromParser(Parser: tpascal_func_decl_tool; Report: TPascalStringList);
var
  i, j: integer;
  decl: pfunc_decl;
  paramList: TParamArray;
  ok: boolean;
  paramDecl: tfunc_param_decl;
  normTyp: TP_String;
  descPool: TParamDescPool;
  paramName: TP_String;
  ParamNames: TP_ArrayString;
  f: TFunctionStructure;
  SkipReason: string;
begin
  Log('LoadFromParser: starting');
  Clear;
  if Report <> nil then
  begin
    Report.Clear;
    Report.Add('=== LoadFromParser skip report ===');
    Report.Add(PFormat('Total declarations in FuncList: %d', [Parser.FuncList.Count]));
  end;

  if not Parser.ParseSuccess then
  begin
    Log('LoadFromParser: Parser.ParseSuccess = False, cannot load.');
    if Report <> nil then
      Report.Add('ERROR: Parser.ParseSuccess is False, nothing loaded.');
    Exit;
  end;

  FUnitName := Parser.UnitName;
  Log('LoadFromParser: UnitName = "%s"', [FUnitName.Text]);
  Log('LoadFromParser: Parser.FuncList.Count = %d', [Parser.FuncList.Count]);

  for i := 0 to Parser.FuncList.Count - 1 do
  begin
    decl := Parser.FuncList[i];

    if not decl^.IsProc then
    begin
      SkipReason := 'Not a procedure/function (IsProc=False)';
      if Report <> nil then
        Report.Add(PFormat('Skipped: "%s" (index %d) - Reason: %s', [decl^.Name.Text, i, SkipReason]));
      Continue;
    end;

    if decl^.NestLevel <> 0 then
    begin
      SkipReason := 'Nested declaration (NestLevel=' + umlIntToStr(decl^.NestLevel) + ')';
      if Report <> nil then
        Report.Add(PFormat('Skipped: "%s" (index %d) - Reason: %s', [decl^.Name.Text, i, SkipReason]));
      Continue;
    end;

    (* Reset all fields of f explicitly. *)
    f.Name := '';
    f.IsFunction := False;
    f.Comment := '';
    f.ReturnType := '';
    SetLength(f.Params, 0);

    f.Name := decl^.Name;
    f.IsFunction := decl^.IsFunction;
    f.Comment := decl^.Comment;
    Log('  Processing routine: %s (IsFunction=%s, Comment length=%d)',
      [f.Name.Text, umlBoolToStr(f.IsFunction).Text, f.Comment.Len]);

    (* Build the parameter name array for description extraction. *)
    SetLength(ParamNames, Length(decl^.param_arry));
    for j := 0 to High(decl^.param_arry) do
      ParamNames[j] := decl^.param_arry[j].param_name;

    descPool := ExtractParamDescriptions(f.Comment, ParamNames);
    try
      SetLength(paramList, Length(decl^.param_arry));
      ok := True;
      for j := 0 to High(decl^.param_arry) do
      begin
        paramDecl := decl^.param_arry[j];

        if paramDecl.param_name = '' then
        begin
          SkipReason := 'Parameter name is empty';
          if Report <> nil then
            Report.Add(PFormat('Skipped: "%s" (index %d) - Reason: %s', [f.Name.Text, i, SkipReason]));
          ok := False;
          Break;
        end;

        if paramDecl.param_mod.Same('var', 'out') then
        begin
          SkipReason := 'var/out parameter "' + paramDecl.param_name + '" not supported';
          if Report <> nil then
            Report.Add(PFormat('Skipped: "%s" (index %d) - Reason: %s', [f.Name.Text, i, SkipReason]));
          ok := False;
          Break;
        end;

        normTyp := Do_Normalize_Type(paramDecl.param_typ);
        if normTyp = '' then
        begin
          SkipReason := 'Parameter "' + paramDecl.param_name + '" has unsupported type "' + paramDecl.param_typ + '"';
          if Report <> nil then
            Report.Add(PFormat('Skipped: "%s" (index %d) - Reason: %s', [f.Name.Text, i, SkipReason]));
          ok := False;
          Break;
        end;

        paramName := paramDecl.param_name;
        paramList[j].Name := paramName;
        paramList[j].Typ := paramDecl.param_typ;
        paramList[j].PascalType := normTyp;
        if descPool.Exists(paramName) then
          paramList[j].Description := descPool.Key_Value[paramName]
        else
          paramList[j].Description := '';

        Log('    Param[%d]: %s: %s -> %s (desc: %s)',
          [j, paramName.Text, paramDecl.param_typ.Text, normTyp.Text, paramList[j].Description.Text]);
      end;
    finally
      descPool.Free;
    end;
    if not ok then
      Continue;

    f.Params := paramList;

    if f.IsFunction then
    begin
      f.ReturnType := Do_Normalize_Type(decl^.ResultDecl);
      if f.ReturnType = '' then
      begin
        SkipReason := 'Return type "' + decl^.ResultDecl + '" is unsupported';
        if Report <> nil then
          Report.Add(PFormat('Skipped: "%s" (index %d) - Reason: %s', [f.Name.Text, i, SkipReason]));
        Continue;
      end;
      Log('    Return type: %s', [f.ReturnType.Text]);
    end
    else
      f.ReturnType := '';

    FFuncs.Add(f.Clone);
    Log('  Added routine "%s" with %d parameters',
      [f.Name.Text, Length(f.Params)]);
  end;

  Log('LoadFromParser: finished, %d routines loaded', [FFuncs.Count]);
  if Report <> nil then
  begin
    Report.Add(PFormat('Loaded %d routines.', [FFuncs.Count]));
    Report.Add('=== End of report ===');
  end;

  (* Enforce unique function names across the entire model. *)
  FixDuplicateFunctionNames;
end;

(* ---------------------------------------------------------------------------
  * SaveToParser
  * --------------------------------------------------------------------------- *)

(*
  * Writes the model data back into a tpascal_func_decl_tool parser object.
  *
  * The parser's previous content is cleared. All model routines are recreated
  * as top-level function or procedure declarations, and ParseSuccess is set
  * to True. Calling convention, external linkage, and default parameter
  * values are not restored because the model does not carry them.
*)
procedure TPascal_Func_Model.SaveToParser(Parser: tpascal_func_decl_tool);
var
  i, j: integer;
  f: TFunctionStructure;
  decl: pfunc_decl;
  paramDecl: tfunc_param_decl;
begin
  Log('SaveToParser: starting');
  Parser.FuncList.Clear;
  Parser.UsesList.Clear;
  Parser.UnitName := FUnitName;

  for i := 0 to FFuncs.Count - 1 do
  begin
    f := FFuncs[i];
    New(decl);
    decl^.Init;
    decl^.IsProc := True;
    decl^.Name := f.Name;
    decl^.IsFunction := f.IsFunction;
    decl^.ResultDecl := f.ReturnType;
    decl^.Comment := f.Comment;
    decl^.NestLevel := 0;
    decl^.CallConv := '';
    decl^.IsExternal := False;
    decl^.ExternalLibrary := '';
    decl^.HasExplicitName := False;
    decl^.ExplicitName := '';
    decl^.HasExplicitIndex := False;
    decl^.ExplicitIndex := '';
    decl^.Index := 0;

    SetLength(decl^.param_arry, Length(f.Params));
    for j := 0 to High(f.Params) do
    begin
      paramDecl.param_mod := '';
      paramDecl.param_name := f.Params[j].Name;
      paramDecl.param_typ := f.Params[j].Typ;
      paramDecl.param_value := '';
      paramDecl.param_array := '';
      decl^.param_arry[j] := paramDecl;
    end;

    Parser.FuncList.Add(decl);
    Log('SaveToParser: added routine "%s" with %d parameters',
      [f.Name.Text, Length(f.Params)]);
  end;

  Parser.ParseSuccess := True;
  Log('SaveToParser: finished, %d routines saved', [FFuncs.Count]);
end;

(* ---------------------------------------------------------------------------
  * LoadFromJson
  * --------------------------------------------------------------------------- *)

(*
  * Restores the model from a JSON string previously produced by SaveToJson.
  * The expected structure is:
  *   {
  *     "UnitName" : "...",
  *     "Functions": [
  *       {
  *         "Name"       : "...",
  *         "IsFunction" : true|false,
  *         "Comment"    : "...",
  *         "ReturnType" : "...",
  *         "Params"     : [
  *           { "Name": "...", "Typ": "...", "PascalType": "...",
  *             "Description": "..." }
  *         ]
  *       }
  *     ]
  *   }
  *
  * After all functions have been read, FixDuplicateFunctionNames is invoked
  * automatically so that the model always contains uniquely named routines.
*)
procedure TPascal_Func_Model.LoadFromJson(const JsonStr: TP_String);
var
  jo: TZ_JsonObject;
  Arr: TZ_JsonArray;
  i, j: integer;
  paramObj: TZ_JsonObject;
  p: TParamStructure;
  paramsArr: TZ_JsonArray;
  f: TFunctionStructure;
begin
  Log('LoadFromJson: started, JSON length=%d', [JsonStr.Len]);
  Clear;

  jo := TZ_JsonObject.Create;
  try
    try
      jo.ParseText(JsonStr);
    except
      Log('LoadFromJson: JSON parse error');
      Exit;
    end;

    FUnitName := jo.S['UnitName'];
    Log('LoadFromJson: UnitName = "%s"', [FUnitName.Text]);

    Arr := jo.A['Functions'];
    if Arr = nil then
    begin
      Log('LoadFromJson: "Functions" array is nil or missing');
      Exit;
    end;

    Log('LoadFromJson: Functions array count = %d', [Arr.Count]);

    for i := 0 to Arr.Count - 1 do
    begin
      f.Name := '';
      f.IsFunction := False;
      f.Comment := '';
      f.ReturnType := '';
      SetLength(f.Params, 0);

      f.Name := Arr.O[i].S['Name'];
      f.IsFunction := Arr.O[i].B['IsFunction'];
      f.Comment := Arr.O[i].S['Comment'];
      f.ReturnType := Arr.O[i].S['ReturnType'];

      Log('LoadFromJson: Function[%d] "%s" (IsFunction=%s)',
        [i, f.Name.Text, umlBoolToStr(f.IsFunction).Text]);

      paramsArr := Arr.O[i].A['Params'];
      if paramsArr = nil then
      begin
        Log('LoadFromJson:   Params array is nil, assuming empty');
        SetLength(f.Params, 0);
      end
      else
      begin
        Log('LoadFromJson:   Params count = %d', [paramsArr.Count]);
        SetLength(f.Params, paramsArr.Count);
        for j := 0 to paramsArr.Count - 1 do
        begin
          paramObj := paramsArr.O[j];
          if paramObj = nil then
          begin
            Log('LoadFromJson:   Param[%d] object is nil, skipping',
              [j]);
            p.Clear;
          end
          else
          begin
            p.Name := paramObj.S['Name'];
            p.Typ := paramObj.S['Typ'];
            p.PascalType := paramObj.S['PascalType'];
            p.Description := paramObj.S['Description'];
            Log('LoadFromJson:   Param[%d]: Name="%s", Typ="%s"',
              [j, p.Name.Text, p.Typ.Text]);
          end;
          f.Params[j] := p;
        end;
      end;

      FFuncs.Add(f.Clone);
      Log('LoadFromJson:   Added routine "%s" with %d parameters',
        [f.Name.Text, Length(f.Params)]);
    end;

    Log('LoadFromJson: finished, loaded %d routines', [FFuncs.Count]);

    (* Enforce unique function names across the entire model. *)
    FixDuplicateFunctionNames;
  finally
    jo.Free;
  end;
end;

(* ---------------------------------------------------------------------------
  * SaveToJson
  * --------------------------------------------------------------------------- *)

(*
  * Exports the model to a formatted JSON string. See LoadFromJson for the
  * exact structure. All string fields are emitted verbatim; Description
  * fields may contain embedded LF characters which the JSON serializer
  * escapes as \n.
*)
function TPascal_Func_Model.SaveToJson: TP_String;
var
  jo: TZ_JsonObject;
  Arr: TZ_JsonArray;
  fArr: TZ_JsonArray;
  i, j: integer;
  f: TFunctionStructure;
  funcObj: TZ_JsonObject;
begin
  Log('SaveToJson: started, saving %d routines', [FFuncs.Count]);

  jo := TZ_JsonObject.Create;
  try
    jo.S['UnitName'] := FUnitName.Text;
    Arr := jo.A['Functions'];

    for i := 0 to FFuncs.Count - 1 do
    begin
      f := FFuncs[i];
      funcObj := Arr.AddObject;
      funcObj.S['Name'] := f.Name.Text;
      funcObj.B['IsFunction'] := f.IsFunction;
      funcObj.S['Comment'] := f.Comment.Text;
      funcObj.S['ReturnType'] := f.ReturnType.Text;

      fArr := funcObj.A['Params'];
      for j := 0 to High(f.Params) do
      begin
        fArr.AddObject;
        fArr.O[fArr.Count - 1].S['Name'] := f.Params[j].Name.Text;
        fArr.O[fArr.Count - 1].S['Typ'] := f.Params[j].Typ.Text;
        fArr.O[fArr.Count - 1].S['PascalType'] :=
          f.Params[j].PascalType.Text;
        fArr.O[fArr.Count - 1].S['Description'] :=
          f.Params[j].Description.Text;
      end;

      Log('SaveToJson:   Function[%d] "%s" has %d parameters',
        [i, f.Name.Text, Length(f.Params)]);
    end;

    Result := jo.ToJSONString(True);
    Log('SaveToJson: finished, JSON length=%d', [Result.Len]);
  finally
    jo.Free;
  end;
end;

(* ---------------------------------------------------------------------------
  * FixDuplicateFunctionNames
  * --------------------------------------------------------------------------- *)

(*
  * Scans all loaded functions and renames any duplicates by appending a
  * numeric suffix (1, 2, 3, ...). The comparison is case-insensitive
  * because it uses TPascalString_Big_Hash_Pair_Pool, whose Compare_Key
  * delegates to TPascalString.Same (ASCII case folding).
  *
  * Example:
  *   Three routines named "Add" become "Add", "Add1", "Add2".
  *   A routine named "Add1" that appears after these would become "Add11"
  *   because "Add1" is already taken.
  *
  * This method is idempotent: running it twice produces the same result.
  * It is called automatically at the end of LoadFromParser and LoadFromJson.
*)
procedure TPascal_Func_Model.FixDuplicateFunctionNames;
var
  i: integer;
  UsedNames: TString_Big_Hash_Pair_Pool<Boolean>;
  f: TFunctionStructure;   (* Mutable copy of the record being inspected. *)
  BaseName: TP_String;
  NewName: TP_String;
  Counter: integer;
begin
  Log('FixDuplicateFunctionNames: scanning %d functions', [FFuncs.Count]);

  UsedNames := TString_Big_Hash_Pair_Pool<Boolean>.Create(256, False);
  try
    for i := 0 to FFuncs.Count - 1 do
    begin
      (*
        IMPORTANT: TFunctionStructure is a record (value type).
        FFuncs[i] returns a COPY, so we must:
          1. pull the copy out,
          2. mutate the copy,
          3. write the modified copy back into the list.
        Writing directly to FFuncs[i].Name would only touch a temporary.
      *)
      f := FFuncs[i];
      BaseName.Text := f.Name.Text;

      (* Empty names are left untouched; they are not real identifiers. *)
      if BaseName = '' then
        Continue;

      if UsedNames.Exists(BaseName.Text) then
      begin
        (* Duplicate detected: try BaseName + '1', BaseName + '2', ...
          until an unused name is found. *)
        Counter := 1;
        repeat
          NewName := BaseName.Text + umlIntToStr(Counter).Text;
          Inc(Counter);
        until not UsedNames.Exists(NewName);

        f.Name.Text := NewName.Text;
        FFuncs[i] := f;   (* Write the modified copy back into the list. *)

        Log('  Renamed duplicate function "%s" -> "%s"',
          [BaseName.Text, NewName.Text]);
        UsedNames.Add(NewName, True, True);
      end
      else
      begin
        (* First occurrence: reserve the original name. *)
        UsedNames.Add(BaseName, True, True);
      end;
    end;
  finally
    UsedNames.Free;
  end;

  Log('FixDuplicateFunctionNames: completed');
end;

end.
