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
unit Z.Pascal_Func_Model;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  {$IFDEF FPC}
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
  Z.HashList.Templet;

type
  TParamStructure = record
    Name: TP_String;
    Typ: TP_String;
    PascalType: TP_String;
    Description: TP_String;
    procedure Clear;
  end;

  TParamArray = array of TParamStructure;

  TFunctionStructure = record
    Name: TP_String;
    IsFunction: boolean;
    Params: TParamArray;
    ReturnType: TP_String;
    Comment: TP_String;
    procedure Clear;
    function Clone: TFunctionStructure;
  end;

  TFunctionList = TGenericsList<TFunctionStructure>;

  TTyp_Normalize_Func = (tnf_Json, tnf_ABI);

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

    procedure LoadFromParser(Parser: tpascal_func_decl_tool; Report: TPascalStringList);
    procedure SaveToParser(Parser: tpascal_func_decl_tool);
    procedure LoadFromJson(const JsonStr: TP_String);
    function SaveToJson: TP_String;
    procedure FixDuplicateFunctionNames;
  end;

function Normalize_Json_Type(const Typ: TP_String): TP_String;
function Normalize_ABI_Type(const Typ: TP_String): TP_String;

var
  PascalFuncModel_LogEnabled: boolean = False;

implementation

procedure Log(const Msg: TP_String); overload;
begin
  if PascalFuncModel_LogEnabled then
    DoStatus('[PascalFuncModel] ' + Msg);
end;

procedure Log(const Fmt: TP_String; const Args: array of const); overload;
begin
  if PascalFuncModel_LogEnabled then
    DoStatus('[PascalFuncModel] ' + PFormat(Fmt, Args));
end;

procedure TParamStructure.Clear;
begin
  Name := '';
  Typ := '';
  PascalType := '';
  Description := '';
end;

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

function TPascal_Func_Model.Do_Normalize_Type(const Typ: TP_String): TP_String;
begin
  case FTyp_Normalize_Func of
    tnf_Json: Result := Normalize_Json_Type(Typ);
    tnf_ABI: Result := Normalize_ABI_Type(Typ);
    else
      RaiseInfo('error');
  end;
end;

constructor TPascal_Func_Model.Create;
begin
  inherited Create;
  FUnitName := '';
  FTyp_Normalize_Func := TTyp_Normalize_Func.tnf_Json;
  FFuncs := TFunctionList.Create;
  Log('TPascal_Func_Model created.');
end;

destructor TPascal_Func_Model.Destroy;
begin
  Clear;
  FFuncs.Free;
  inherited Destroy;
  Log('TPascal_Func_Model destroyed.');
end;

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

function TPascal_Func_Model.GetFuncCount: integer;
begin
  Result := FFuncs.Count;
end;

function Normalize_Json_Type(const Typ: TP_String): TP_String;
var
  lowTyp: TP_String;
begin
  lowTyp := Typ.TrimChar(#32#9).LowerText;
  if lowTyp.Same('integer', 'int64', 'cardinal', 'longint', 'dword') or lowTyp.Same('word', 'smallint', 'byte', 'uint64', 'longword') then
    Result := 'int64'
  else if lowTyp.Same('double', 'single', 'extended', 'real') then
    Result := 'double'
  else if lowTyp.Same('tbytes') or lowTyp.Same('array of byte') then
    Result := 'TBytes'
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
  else if lowTyp.Same('tbytes') or lowTyp.Same('array of byte') then
    Result := 'TBytes'
  else if lowTyp.Same('tpascalstring', 'tupascalstring', 'tp_string', 'string', 'ansistring', 'unicodestring') or lowTyp.Same('pchar', 'pansichar', 'pwidechar') then
    Result := lowTyp
  else
    Result := '';
end;

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

function ExtractParamDescriptions(const CommentText___: TP_String; const ParamNames: TP_ArrayString): TParamDescPool;

  function IsIdentStart(c: TP_Char): boolean;
  begin
    Result := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z')) or (c = '_');
  end;

  function IsIdentChar(c: TP_Char): boolean;
  begin
    Result := IsIdentStart(c) or ((c >= '0') and (c <= '9'));
  end;

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

  procedure SkipWS(const S: TP_String; var pos: integer);
  begin
    while (pos <= S.Len) and IsHSpace(S[pos]) do
      Inc(pos);
  end;

  function ReadIdent(const S: TP_String; var pos: integer): TP_String;
  begin
    Result := '';
    while (pos <= S.Len) and IsIdentChar(S[pos]) do
    begin
      Result := Result + S[pos];
      Inc(pos);
    end;
  end;

  function MatchParam(const Name_: TP_String): TP_String;
  var
    jj: integer;
  begin
    Result := '';
    for jj := 0 to High(ParamNames) do
      if ParamNames[jj].Same(True, Name_) then
        Exit(ParamNames[jj]);
  end;

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

    if (TrimmedLine_[pos] = '@') or (TrimmedLine_[pos] = '\') then
    begin
      Inc(pos);
      SkipWS(TrimmedLine_, pos);
      if pos > TrimmedLine_.Len then
        Exit;

      ident := ReadIdent(TrimmedLine_, pos);
      if ident = '' then
        Exit;

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
      RawLine := TP_String(Lines[i]);

      while (RawLine.Len > 0) and ((RawLine.Last = #13) or (RawLine.Last = #10)) do
        RawLine.DeleteLast;
      while (RawLine.Len > 0) and IsHSpace(RawLine.Last) do
        RawLine.DeleteLast;

      ContentLine := GetContentLine(RawLine);
      TrimmedLine := ContentLine.TrimChar(#32#9);

      if TrimmedLine.Len = 0 then
      begin
        FlushCurrent;
        Continue;
      end;

      Found := TryMatchParamLine(TrimmedLine, MatchedParam, DescStartPos);
      if Found then
      begin
        FlushCurrent;
        CurrentParam := MatchedParam;
        ParamIndent := ComputeIndent(ContentLine);
        CurrentDesc := ExtractDescAfterName(TrimmedLine, DescStartPos);
        Continue;
      end;

      RawIndent := ComputeIndent(ContentLine);
      if (CurrentParam <> '') and (RawIndent > ParamIndent) then
      begin
        if CurrentDesc <> '' then
          CurrentDesc := CurrentDesc + #10 + ContentLine
        else
          CurrentDesc := ContentLine;
        Continue;
      end;

      FlushCurrent;
    end;

    FlushCurrent;
  finally
    Lines.Free;
  end;

  Log('ExtractParamDescriptions: extracted %d entries', [Pool.Count]);
end;

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

  FixDuplicateFunctionNames;
end;

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
            Log('LoadFromJson:   Param[%d] object is nil, skipping', [j]);
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

    FixDuplicateFunctionNames;
  finally
    jo.Free;
  end;
end;

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

procedure TPascal_Func_Model.FixDuplicateFunctionNames;
var
  i: integer;
  UsedNames: TString_Big_Hash_Pair_Pool<Boolean>;
  f: TFunctionStructure;
  BaseName: TP_String;
  NewName: TP_String;
  Counter: integer;
begin
  Log('FixDuplicateFunctionNames: scanning %d functions', [FFuncs.Count]);

  UsedNames := TString_Big_Hash_Pair_Pool<Boolean>.Create(256, False);
  try
    for i := 0 to FFuncs.Count - 1 do
    begin
      f := FFuncs[i];
      BaseName.Text := f.Name.Text;

      if BaseName = '' then
        Continue;

      if UsedNames.Exists(BaseName.Text) then
      begin
        Counter := 1;
        repeat
          NewName := BaseName.Text + umlIntToStr(Counter).Text;
          Inc(Counter);
        until not UsedNames.Exists(NewName);

        f.Name.Text := NewName.Text;
        FFuncs[i] := f;

        Log('  Renamed duplicate function "%s" -> "%s"',
          [BaseName.Text, NewName.Text]);
        UsedNames.Add(NewName, True, True);
      end
      else
      begin
        UsedNames.Add(BaseName, True, True);
      end;
    end;
  finally
    UsedNames.Free;
  end;

  Log('FixDuplicateFunctionNames: completed');
end;

end.
 
