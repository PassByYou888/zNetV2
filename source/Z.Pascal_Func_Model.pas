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
  * Z.Pascal_Func_Model – Middle‑Layer Metadata Model for Pascal Function Declarations
  *
  * This unit defines the core data structures and a container class that serves
  * as the intermediate layer between the low‑level Pascal parser
  * (Z.Pascal_Func_Tool) and high‑level code generators (e.g., pas_mcp_generator_tool).
  *
  * ┌───────────────────────────────────────────────────────────────────────────┐
  * │                         Architecture Overview                             │
  * ├───────────────────────────────────────────────────────────────────────────┤
  * │                                                                           │
  * │  Z.Pascal_Func_Tool (Parser)                                              │
  * │  └─► Extracts raw declarations (tfunc_decl records) from Pascal source.   │
  * │                                                                           │
  * │  pascal_func_model (THIS UNIT)                                            │
  * │  └─► Converts raw declarations into structured, normalized models         │
  * │      (TFunctionStructure, TParamStructure) suitable for further           │
  * │      processing. Provides type normalization, comment cleaning,           │
  * │      parameter description extraction, and JSON serialization.            │
  * │                                                                           │
  * │  pas_mcp_generator_tool (Generator)                                       │
  * │  └─► Uses the model to generate LingoFuse tool provider code.             │
  * │                                                                           │
  * └───────────────────────────────────────────────────────────────────────────┘
  *
  * =============================================================================
  * 1.  PURPOSE
  * =============================================================================
  *   • Provide a clean, type‑safe representation of Pascal functions and
  *     procedures extracted from the interface section of a unit.
  *   • Normalize Pascal types (Integer → Int64, Double → Double, String → string)
  *     to a small set of supported types used by downstream generators.
  *   • Clean and merge comment blocks, and extract parameter descriptions from
  *     various documentation styles (Doxygen, colon, equal, space‑separated).
  *   • Offer JSON import/export for persistence and cross‑tool communication.
  *
  * =============================================================================
  * 2.  DEPENDENCIES
  * =============================================================================
  *   This unit relies on the following Z‑framework components:
  *
  *     | Unit                    | Role                                      |
  *     |-------------------------|-------------------------------------------|
  *     | Z.Core                  | Base classes, generics, memory management |
  *     | Z.PascalStrings         | TP_String type (UTF‑16 Pascal string)     |
  *     | Z.UPascalStrings        | Additional string utilities               |
  *     | Z.Pascal_Func_Tool      | Parser that produces tfunc_decl records   |
  *     | Z.Parsing               | TTextParsing for comment token extraction |
  *     | Z.Json                  | JSON serialization (TZ_JsonObject)        |
  *     | Z.UnicodeMixedLib       | String manipulation helpers               |
  *     | Z.Status                | Logging (DoStatus)                        |
  *     | Z.ListEngine            | List utilities                            |
  *     | Z.HashList.Templet      | Hash map for parameter descriptions       |
  *
  * =============================================================================
  * 3.  KEY TYPES
  * =============================================================================
  *   • TParamStructure   – Metadata for a single parameter (name, raw type,
  *                         normalized type, description).
  *   • TParamArray       – Dynamic array of TParamStructure.
  *   • TFunctionStructure– Metadata for a function/procedure (name, isFunction,
  *                         parameters, return type, cleaned comment).
  *   • TPascal_Func_Model– Main container that holds the unit name and a list
  *                         of TFunctionStructure. Provides LoadFromParser,
  *                         LoadFromJson, SaveToJson, and SaveToParser.
  *
  * =============================================================================
  * 4.  USAGE EXAMPLE (Complete Workflow)
  * =============================================================================
  *
  *   // 1. Parse Pascal source code using the low‑level parser.
  *   var
  *     Parser: tpascal_func_decl_tool;
  *     Model: TPascal_Func_Model;
  *   begin
  *     Parser := tpascal_func_decl_tool.Create(SourceCode);
  *     try
  *       if not Parser.ParseSuccess then
  *         raise Exception.Create('Parsing failed');
  *
  *       // 2. Load the model from the parser.
  *       Model := TPascal_Func_Model.Create;
  *       try
  *         Model.LoadFromParser(Parser);
  *
  *         // 3. Now you can access all extracted data.
  *         for var f in Model.Funcs do
  *         begin
  *           WriteLn('Function: ', f.Name.Text);
  *           WriteLn('  IsFunction: ', f.IsFunction);
  *           WriteLn('  ReturnType: ', f.ReturnType.Text);
  *           WriteLn('  Comment: ', f.Comment.Text);
  *           for var p in f.Params do
  *             WriteLn('    Param: ', p.Name.Text, ' : ', p.PascalType.Text, ' (', p.Description.Text, ')');
  *         end;
  *
  *         // 4. Save to JSON for later reuse.
  *         var JsonStr := Model.SaveToJson;
  *         // JsonStr can be stored or transmitted.
  *
  *         // 5. Load from JSON.
  *         var Model2 := TPascal_Func_Model.Create;
  *         Model2.LoadFromJson(JsonStr);
  *         // Model2 now contains the same data.
  *
  *         // 6. Write model back to a parser (for further processing or source generation).
  *         Model.SaveToParser(Parser);
  *       finally
  *         Model.Free;
  *       end;
  *     finally
  *       Parser.Free;
  *     end;
  *   end;
  *
  * =============================================================================
  * 5.  NOTES & LIMITATIONS
  * =============================================================================
  *   • Only top‑level functions and procedures (NestLevel = 0) are included.
  *   • Type normalization supports only Integer‑family → 'Int64',
  *     Float‑family → 'Double', and String‑family → 'string'. Any other type
  *     results in an empty string and the routine is skipped.
  *   • Parameter descriptions are extracted from comments immediately preceding
  *     the routine. The comment must be directly adjacent (no blank lines) to be
  *     correctly associated.
  *   • The model is designed to be consumed by code generators that produce
  *     LingoFuse tool providers; it is not a full Pascal AST but a simplified
  *     view suitable for RPC binding.
  *
  * =============================================================================
  * 6.  AUTHOR & VERSION
  * =============================================================================
  *   Original author: qq600585 (circa 2012)
  *   Modernised and documented for the Z‑framework ecosystem.
  *   Version: 2.6
  *
  *   For questions or contributions, please refer to the Z‑framework
  *   documentation.
  * ****************************************************************************
*)
unit Z.Pascal_Func_Model;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
{$IFDEF FPC}
  {FPC-specific generic list support (backported from fgl)}
  Z.FPC.GenericList,
{$ENDIF FPC}
  Z.Core,
  Z.PascalStrings, Z.UPascalStrings,
  Z.Pascal_Func_Tool,
  Z.Parsing,
  Z.Json,
  Z.UnicodeMixedLib,
  Z.Status,
  Z.ListEngine,
  Z.HashList.Templet; // For TPascalString_Big_Hash_Pair_Pool

type
  { *
    * TParamStructure – Metadata for a single parameter of a function or procedure.
    *
    * @field Name          The original parameter name as declared in Pascal.
    * @field Typ           The raw Pascal type string (e.g. 'Integer', 'TColor').
    * @field PascalType    Normalized type name (one of 'Int64', 'Double', 'string',
    *                      or empty if unsupported).
    * @field Description   Human-readable description extracted from the comment,
    *                      if any.
    *
    * @example
    *   var p: TParamStructure;
    *   begin
    *     p.Name := 'a';
    *     p.Typ := 'Integer';
    *     p.PascalType := 'Int64';
    *     p.Description := 'First operand';
    *   end;
    *
    * @see TParamArray
    * @see TFunctionStructure
    * }
  TParamStructure = record
    Name: TP_String;
    Typ: TP_String;
    PascalType: TP_String;
    Description: TP_String;
    procedure Clear;
  end;

  { * Dynamic array of TParamStructure, used to hold all parameters of a routine. }
  TParamArray = array of TParamStructure;

  { *
    * TFunctionStructure – Complete metadata for a Pascal function or procedure.
    *
    * @field Name         The routine name (e.g. 'Add').
    * @field IsFunction   True if this is a function (has a return type), false
    *                     for a procedure.
    * @field Params       Array of parameter metadata.
    * @field ReturnType   Normalized return type (empty for procedures).
    * @field Comment      Cleaned comment text (without Pascal comment markers)
    *                     extracted from the source.
    *
    * @example
    *   var f: TFunctionStructure;
    *   begin
    *     f.Name := 'Add';
    *     f.IsFunction := True;
    *     SetLength(f.Params, 2);
    *     f.Params[0].Name := 'a'; f.Params[0].PascalType := 'Int64';
    *     f.Params[1].Name := 'b'; f.Params[1].PascalType := 'Int64';
    *     f.ReturnType := 'Int64';
    *     f.Comment := 'Adds two integers.';
    *   end;
    *
    * @see TFunctionList
    * @see TPascal_Func_Model
    * }
  TFunctionStructure = record
    Name: TP_String;
    IsFunction: boolean;
    Params: TParamArray;
    ReturnType: TP_String;
    Comment: TP_String;
    procedure Clear;
    function Clone: TFunctionStructure;
  end;

  { * Generic list of TFunctionStructure records. }
  TFunctionList = TGenericsList<TFunctionStructure>;

  { *
    * TPascal_Func_Model – Main container for parsed metadata of a Pascal unit.
    *
    * This class holds the unit name and a list of all top‑level functions and
    * procedures extracted from the interface section. It can be populated from
    * a Z.Pascal_Func_Tool parser (LoadFromParser) or from a JSON string
    * (LoadFromJson), and can export itself to JSON (SaveToJson) as well as write
    * back to a parser object (SaveToParser).
    *
    * @property UnitName   The name of the Pascal unit (e.g. 'MyUnit').
    * @property Funcs      List of all extracted routines.
    * @property FuncCount  Number of routines.
    *
    * @usage
    *   // Parse source code and load model:
    *   var Parser := tpascal_func_decl_tool.Create(SourceCode);
    *   if Parser.ParseSuccess then
    *   begin
    *     Model := TPascal_Func_Model.Create;
    *     Model.LoadFromParser(Parser);
    *     // Now model.Funcs contains all functions/procedures.
    *   end;
    *   Parser.Free;
    *
    * @note This model is designed to be used by code generators like
    *       pas_mcp_generator_tool to produce LingoFuse tool providers.
    * }
  TPascal_Func_Model = class(TCore_Object_Intermediate)
  private
    FUnitName: TP_String;
    FFuncs: TFunctionList;
    function GetFuncCount: integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;

    property UnitName: TP_String read FUnitName write FUnitName;
    property Funcs: TFunctionList read FFuncs;
    property FuncCount: integer read GetFuncCount;

    // ----- Interface with tpascal_func_decl_tool -----

    { * Populates the model from a parser instance.
      * @param Parser  A successfully parsed tpascal_func_decl_tool object.
      * @param Report  Optional TCore_Strings to receive a report of skipped declarations.
      *                If provided, it will be cleared and filled with messages about
      *                declarations that were not loaded (unsupported types, var/out, etc.).
      * }
    procedure LoadFromParser(Parser: tpascal_func_decl_tool; Report: TPascalStringList);

    { * Writes the model data back into a parser object, allowing further processing
      * or source code generation.
      * @param Parser  The target parser object, whose previous content will be cleared.
      * }
    procedure SaveToParser(Parser: tpascal_func_decl_tool);

    // ----- JSON serialization -----

    { * Restores the model from a JSON string.
      * @param JsonStr  A valid JSON string containing unit name and function list.
      * }
    procedure LoadFromJson(const JsonStr: TP_String);

    { * Exports the model to a JSON string.
      * @return  A formatted JSON string.
      * }
    function SaveToJson: TP_String;
  end;

var
  { * Global flag to enable/disable logging within this unit. }
  PascalFuncModel_LogEnabled: boolean = False;

implementation

// -----------------------------------------------------------------------------
// Logging helpers
// -----------------------------------------------------------------------------

{ * Internal logging procedure; outputs message only if PascalFuncModel_LogEnabled is True. }
procedure Log(const Msg: TP_String); overload;
begin
  if PascalFuncModel_LogEnabled then
      DoStatus('[PascalFuncModel] ' + Msg);
end;

{ * Internal logging procedure with formatting; uses PFormat for safety. }
procedure Log(const Fmt: TP_String; const Args: array of const); overload;
begin
  if PascalFuncModel_LogEnabled then
      DoStatus('[PascalFuncModel] ' + PFormat(Fmt, Args));
end;

{ TParamStructure.Clear }
{ * Resets all fields to empty strings. }
procedure TParamStructure.Clear;
begin
  Name := '';
  Typ := '';
  PascalType := '';
  Description := '';
end;

{ TFunctionStructure.Clear }
{ *
  * Releases all parameter records and resets the structure to a clean state.
  * This is called before assigning new data to avoid memory leaks.
  * }
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

{ TFunctionStructure.Clone }
{ *
  * Creates a deep copy of the structure, ensuring that the dynamic array
  * of parameters is copied element‑by‑element.
  * @return A new TFunctionStructure with independent parameter array.
  * }
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
      Result.Params[i] := Self.Params[i]; // TParamStructure is a record, direct copy
end;

{ TPascal_Func_Model }
{ * Constructor: initialises the function list and logs creation. }
constructor TPascal_Func_Model.Create;
begin
  inherited Create;
  FUnitName := '';
  FFuncs := TFunctionList.Create;
  Log('TPascal_Func_Model created.');
end;

{ * Destructor: clears all data and frees the function list. }
destructor TPascal_Func_Model.Destroy;
begin
  Clear;
  FFuncs.Free;
  inherited Destroy;
  Log('TPascal_Func_Model destroyed.');
end;

{ * Clears all functions and resets unit name. }
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

{ * Returns the number of functions currently stored. }
function TPascal_Func_Model.GetFuncCount: integer;
begin
  Result := FFuncs.Count;
end;

{ *
  * NormalizeType – Converts a Pascal type TP_String to a canonical type name.
  *
  * Recognises integer types (Integer, Int64, Cardinal, …) -> 'Int64'
  * Recognises floating point types (Double, Single, Extended, …) -> 'Double'
  * Recognises string types (string, TP_String, AnsiString, UnicodeString) -> 'string'
  * All other types return an empty TP_String (unsupported).
  *
  * @param Typ  The raw type TP_String (e.g. 'Integer', 'TColor').
  * @return     Normalised type name, or empty if not supported.
  * }
function NormalizeType(const Typ: TP_String): TP_String;
var
  lowTyp: TP_String;
begin
  lowTyp := Typ.TrimChar(#32#9).LowerText;
  if lowTyp.Same('integer', 'int64', 'cardinal', 'longint', 'dword') or lowTyp.Same('word', 'smallint', 'byte', 'uint64', 'longword') then
      Result := 'int64'
  else if lowTyp.Same('double', 'single', 'extended', 'real') then
      Result := 'double'
  else if lowTyp.Same('tpascalstring', 'tupascalstring', 'tp_string', 'string', 'ansistring', 'unicodestring') or
    lowTyp.Same('pchar', 'pansichar', 'pwidechar') then
      Result := 'string'
  else
      Result := '';
end;

(*
  * CleanComment – Extracts the actual comment text from a Pascal comment token.
  * @param Cmt  The raw comment text as it appears in source code.
  * @return     Cleaned, merged comment text without markers.
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
  if Cmt = '' then Exit;

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
    // Join parts with line breaks.
    Result := '';
    for i := 0 to High(Parts) do
      begin
        if i > 0 then Result := Result + sLineBreak;
        Result := Result + Parts[i];
      end;
  finally
      Parser.Free;
  end;
end;

{ *
  * TParamDescPool – A hash map that stores parameter descriptions keyed by
  * parameter name. It is used internally by ExtractParamDescriptions to gather
  * descriptions and automatically manage TP_String memory.
  *
  * @see ExtractParamDescriptions
  * }
type
  TParamDescPool = class(TPascalString_Big_Hash_Pair_Pool<TP_String>)
  public
    procedure DoFree(var Key: TPascalString; var Value: TP_String); override;
  end;

  { * Frees the value TP_String (does nothing extra). }
procedure TParamDescPool.DoFree(var Key: TPascalString; var Value: TP_String);
begin
  Value := '';
  inherited DoFree(Key, Value);
end;

{ *
  * IndexOfString – Returns the index of Value in the array Arr.
  *
  * Compares using the Same method (case‑insensitive by default).
  *
  * @param Arr          The array of strings to search.
  * @param Value        The TP_String to look for.
  * @param IgnoreCase   If True, compare case‑insensitively.
  * @return             Index (0‑based) or -1 if not found.
  * }
function IndexOfString(const Arr: TP_ArrayString; const Value: TP_String; IgnoreCase: boolean): integer;
var
  i: integer;
begin
  Result := -1;
  for i := 0 to High(Arr) do
    if Arr[i].Same(IgnoreCase, Value) then
        Exit(i);
end;

{ *
  * ExtractParamDescriptions – Scans the comment text line by line to find
  * descriptions for each parameter name in ParamNames.
  *
  * It recognises several common documentation styles:
  *   - Doxygen: '@param a description'  or '\param a description'
  *   - Colon/equal: 'a: description' or 'a = description'
  *   - Space‑separated: 'a   description' (provided the next token is not another
  *     parameter name)
  *
  * The function returns a hash map (TParamDescPool) where the key is the parameter
  * name (as provided in ParamNames) and the value is the concatenated description.
  *
  * @param CommentText  The cleaned comment (from CleanComment).
  * @param ParamNames   Array of parameter names (order does not matter).
  * @return             A TParamDescPool containing descriptions for found parameters.
  *
  * @example
  *   var pool := ExtractParamDescriptions(
  *     'Adds two numbers.' + sLineBreak +
  *     '@param a First operand' + sLineBreak +
  *     '@param b Second operand',
  *     ['a', 'b']
  *   );
  *   // pool['a'] = 'First operand', pool['b'] = 'Second operand'
  * }
function ExtractParamDescriptions(const CommentText___: TP_String; const ParamNames: TP_ArrayString): TParamDescPool;
var
  CommentText: TP_String;
  Lines: TPascalStringList;
  i, k: integer;
  line: TP_String;
  LineParser: TTextParsing;
  Token: PTokenData;
  foundParam: boolean;
  desc: TP_String;
  j: integer;
  nextNonSpace: PTokenData;
  prevNonSpace: PTokenData;
begin
  CommentText := CleanComment(CommentText___);
  Result := TParamDescPool.Create(256, '');
  if (CommentText = '') or (Length(ParamNames) = 0) then
      Exit;

  Lines := TPascalStringList.Create;
  try
    umlSeparatorText(CommentText, Lines, #10); // Split by newline.

    for i := 0 to Lines.Count - 1 do
      begin
        line := Lines[i].TrimChar(#32#9);
        if line.Len = 0 then Continue;

        LineParser := TTextParsing.Create(line, tsPascal);
        try
          for k := 0 to LineParser.TokenCount - 1 do
            begin
              Token := LineParser.Tokens[k];
              if Token^.tokenType <> ttAscii then Continue;

              // Check if this token is one of our parameter names.
              if IndexOfString(ParamNames, Token^.Text, True) < 0 then Continue;

              foundParam := False;

              // ---- Look backward for a non‑whitespace token ----
              prevNonSpace := nil;
              j := k - 1;
              while j >= 0 do
                begin
                  if (LineParser.Tokens[j]^.tokenType = ttUnknow) and (LineParser.Tokens[j]^.Text = ' ') then
                      Dec(j)
                  else
                    begin
                      prevNonSpace := LineParser.Tokens[j];
                      Break;
                    end;
                end;

              // ---- Look forward for a non‑whitespace token ----
              nextNonSpace := nil;
              j := k + 1;
              while j < LineParser.TokenCount do
                begin
                  if (LineParser.Tokens[j]^.tokenType = ttUnknow) and (LineParser.Tokens[j]^.Text = ' ') then
                      Inc(j)
                  else
                    begin
                      nextNonSpace := LineParser.Tokens[j];
                      Break;
                    end;
                end;

              // ---- Recognition rules ----
              // 1) Preceded by '@' or '\'
              if (prevNonSpace <> nil) and (prevNonSpace^.tokenType = ttSymbol) and (prevNonSpace^.Text.Same('@') or
                  prevNonSpace^.Text.Same('\')) then
                  foundParam := True

                // 2) Followed by ':' or '='
              else if (nextNonSpace <> nil) and (nextNonSpace^.tokenType = ttSymbol) and (nextNonSpace^.Text.Same(':') or
                  nextNonSpace^.Text.Same('=')) then
                  foundParam := True

                // 3) Space‑separated: next token is not a symbol and is not another param name
              else if (nextNonSpace <> nil) and (nextNonSpace^.tokenType <> ttSymbol) then
                begin
                  if IndexOfString(ParamNames, nextNonSpace^.Text, True) < 0 then
                      foundParam := True;
                end;

              if foundParam then
                begin
                  // Extract description: from after this token to end of line.
                  desc := line.GetString(Token^.EPos, line.Len + 1).TrimChar(#32#9);
                  // Remove leading ':' or '=' if present (they may have been left).
                  if (desc.Len > 0) and (desc[1] = ':') then
                      desc := desc.GetString(2, desc.Len + 1).TrimChar(#32#9)
                  else if (desc.Len > 0) and (desc[1] = '=') then
                      desc := desc.GetString(2, desc.Len + 1).TrimChar(#32#9);

                  if desc <> '' then
                    begin
                      if Result.Exists(Token^.Text) then
                          Result.Key_Value[Token^.Text] := Result.Key_Value[Token^.Text] + ' ' + desc
                      else
                          Result.Add(Token^.Text, desc, False);
                      Break; // Only one description per line.
                    end;
                end;
            end;
        finally
            LineParser.Free;
        end;
      end;
  finally
      Lines.Free;
  end;

  Log('ExtractParamDescriptions: extracted %d entries', [Result.Count]);
end;

// =============================================================================
// LoadFromParser – Populates the model from a tpascal_func_decl_tool.
// =============================================================================
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
      Log('LoadFromParser: Parser.ParseSuccess = False, cannot load structure.');
      if Report <> nil then
          Report.Add('ERROR: Parser.ParseSuccess is False, structure not loaded.');
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

      // Reset all fields of f explicitly.
      f.Name := '';
      f.IsFunction := False;
      f.Comment := '';
      f.ReturnType := '';
      SetLength(f.Params, 0);

      f.Name := decl^.Name;
      f.IsFunction := decl^.IsFunction;
      f.Comment := decl^.Comment;
      Log('  Processing routine: %s (IsFunction=%s, Comment length=%d)', [f.Name.Text, umlBoolToStr(f.IsFunction).Text, f.Comment.Len]);

      // Build array of parameter names for description extraction.
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

            normTyp := NormalizeType(paramDecl.param_typ);
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
            Log('    Param[%d]: %s: %s -> %s (desc: %s)', [j, paramName.Text, paramDecl.param_typ.Text, normTyp.Text, paramList[j].Description.Text]);
          end;
      finally
          descPool.Free;
      end;
      if not ok then Continue;

      // Assign parameter list to f.Params.
      f.Params := paramList;

      if f.IsFunction then
        begin
          f.ReturnType := NormalizeType(decl^.ResultDecl);
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

      // Add a deep clone to the model list.
      FFuncs.Add(f.Clone);
      Log('  Added routine "%s" with %d parameters', [f.Name.Text, Length(f.Params)]);
    end;

  Log('LoadFromParser: finished, %d routines loaded', [FFuncs.Count]);
  if Report <> nil then
    begin
      Report.Add(PFormat('Loaded %d routines.', [FFuncs.Count]));
      Report.Add('=== End of report ===');
    end;
end;

// =============================================================================
// SaveToParser – Writes the model data back into a tpascal_func_decl_tool.
// =============================================================================
procedure TPascal_Func_Model.SaveToParser(Parser: tpascal_func_decl_tool);
var
  i, j: integer;
  f: TFunctionStructure;
  decl: pfunc_decl;
  paramDecl: tfunc_param_decl;
begin
  Log('SaveToParser: starting');
  // Clear parser's existing content
  Parser.FuncList.Clear;
  Parser.UsesList.Clear;
  Parser.UnitName := FUnitName;

  // Iterate over all functions in the model
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
      decl^.NestLevel := 0; // top-level
      decl^.CallConv := ''; // no calling convention info
      decl^.IsExternal := False;
      decl^.ExternalLibrary := '';
      decl^.HasExplicitName := False;
      decl^.ExplicitName := '';
      decl^.HasExplicitIndex := False;
      decl^.ExplicitIndex := '';
      decl^.Index := 0;

      // Convert parameters
      SetLength(decl^.param_arry, Length(f.Params));
      for j := 0 to High(f.Params) do
        begin
          paramDecl.param_mod := ''; // no var/const/out
          paramDecl.param_name := f.Params[j].Name;
          paramDecl.param_typ := f.Params[j].Typ; // original type
          paramDecl.param_value := ''; // no default value
          decl^.param_arry[j] := paramDecl;
        end;

      // Add to parser's FuncList
      Parser.FuncList.Add(decl);
      Log('SaveToParser: added routine "%s" with %d parameters', [f.Name.Text, Length(f.Params)]);
    end;

  // Mark parsing as successful
  Parser.ParseSuccess := True;
  Log('SaveToParser: finished, %d routines saved', [FFuncs.Count]);
end;

// =============================================================================
// LoadFromJson – Restores the model from a JSON string.
// =============================================================================
procedure TPascal_Func_Model.LoadFromJson(const JsonStr: TP_String);
var
  jo: TZ_JsonObject;
  Arr: TZ_JsonArray;
  i, j: integer;
  paramObj: TZ_JsonObject;
  p: TParamStructure;
  paramsArr: TZ_JsonArray;
  f: TFunctionStructure; // loop variable, reused safely
begin
  Log('LoadFromJson: started, JSON length=%d', [JsonStr.Len]);
  Clear;

  jo := TZ_JsonObject.Create;
  try
    // Parse JSON – catch any exception
    try
        jo.ParseText(JsonStr);
    except
      Log('LoadFromJson: JSON parse error');
      Exit;
    end;

    // Read UnitName
    FUnitName := jo.s['UnitName'];
    Log('LoadFromJson: UnitName = "%s"', [FUnitName.Text]);

    // Read Functions array
    Arr := jo.A['Functions'];
    if Arr = nil then
      begin
        Log('LoadFromJson: "Functions" array is nil or missing');
        Exit;
      end;

    Log('LoadFromJson: Functions array count = %d', [Arr.Count]);

    for i := 0 to Arr.Count - 1 do
      begin
        // Reset all fields of f explicitly.
        f.Name := '';
        f.IsFunction := False;
        f.Comment := '';
        f.ReturnType := '';
        SetLength(f.Params, 0);

        f.Name := Arr.O[i].s['Name'];
        f.IsFunction := Arr.O[i].B['IsFunction'];
        f.Comment := Arr.O[i].s['Comment'];
        f.ReturnType := Arr.O[i].s['ReturnType'];

        Log('LoadFromJson: Function[%d] "%s" (IsFunction=%s)', [i, f.Name.Text, umlBoolToStr(f.IsFunction).Text]);

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
                    Log('LoadFromJson:   Param[%d] object is nil, skipping', [j]);
                    // Leave p fields empty
                  end
                else
                  begin
                    p.Name := paramObj.s['Name'];
                    p.Typ := paramObj.s['Typ'];
                    p.PascalType := paramObj.s['PascalType'];
                    p.Description := paramObj.s['Description'];
                    Log('LoadFromJson:   Param[%d]: Name="%s", Typ="%s", PascalType="%s"',
                      [j, p.Name.Text, p.Typ.Text, p.PascalType.Text]);
                    f.Params[j] := p;
                  end;
              end;
          end;

        // Add a deep clone to the model list.
        FFuncs.Add(f.Clone);
        Log('LoadFromJson:   Added routine "%s" with %d parameters', [f.Name.Text, Length(f.Params)]);

        // Do NOT clear f.Params – f will be reset at the start of the next iteration.
      end;

    Log('LoadFromJson: finished, loaded %d routines', [FFuncs.Count]);

  finally
      jo.Free;
  end;
end;

// =============================================================================
// SaveToJson – Exports the model to a JSON string.
// =============================================================================
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
    jo.s['UnitName'] := FUnitName.Text;
    Arr := jo.A['Functions'];

    for i := 0 to FFuncs.Count - 1 do
      begin
        f := FFuncs[i];
        funcObj := Arr.AddObject;
        funcObj.s['Name'] := f.Name.Text;
        funcObj.B['IsFunction'] := f.IsFunction;
        funcObj.s['Comment'] := f.Comment.Text;
        funcObj.s['ReturnType'] := f.ReturnType.Text;

        fArr := funcObj.A['Params'];
        for j := 0 to High(f.Params) do
          begin
            fArr.AddObject;
            fArr.O[fArr.Count - 1].s['Name'] := f.Params[j].Name.Text;
            fArr.O[fArr.Count - 1].s['Typ'] := f.Params[j].Typ.Text;
            fArr.O[fArr.Count - 1].s['PascalType'] := f.Params[j].PascalType.Text;
            fArr.O[fArr.Count - 1].s['Description'] := f.Params[j].Description.Text;
          end;

        Log('SaveToJson:   Function[%d] "%s" has %d parameters', [i, f.Name.Text, Length(f.Params)]);
      end;

    Result := jo.ToJSONString(True);
    Log('SaveToJson: finished, JSON length=%d', [Result.Len]);

  finally
      jo.Free;
  end;
end;

end.
 
