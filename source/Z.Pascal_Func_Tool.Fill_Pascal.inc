type
  tfunc_param_tool = class(TBigList<tfunc_param_decl>)
  public
    procedure DoFree(var Data: tfunc_param_decl); override;
    procedure fill_param(ParamDecl: TP_String);
    function get_param_arry: tfunc_param_arry;
    class function extract_param_to_arry(ParamDecl: TP_String): tfunc_param_arry;
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
    lPos, rNum: integer;
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
    lPos, rNum, i: integer;
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
  lPos: integer;
  SplitOutput: TSymbolVector;
  i: integer;
begin
  tmp := ParamDecl.TrimChar('()'#32#9#13#10);
  if tmp = '' then
  begin
    if Pascal_Func_Tool_Log_Enabled then
      DoStatus('[tfunc_param_tool] fill_param: empty or only parentheses');
    exit;
  end;

  if Pascal_Func_Tool_Log_Enabled then
    DoStatus('[tfunc_param_tool] fill_param: parsing "%s"', [tmp.Text]);

  tp := TTextParsing.Create(tmp, tsPascal);
  tp.DeletedComment;
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
  tpascal_func_decl_tool.Fill_Pascal
  ------------------------------------------------------------------------------ }
{ ------------------------------------------------------------------------------
  tpascal_func_decl_tool.Fill_Pascal
  ------------------------------------------------------------------------------
  Parses the Pascal source code and extracts only function/procedure
  declarations.

  This method uses TBigList (provided by Z.Core) as the primary data structure
  for storing declarations. Only items with IsProc=True are added to FuncList.
  Structural markers (unit, interface, implementation, end.) are recognized
  for parsing flow control but are NOT stored in FuncList.

  The UnitToken, InterfaceToken, etc. pointers are set to nil because they are
  not needed for further processing (decl_to_pascal and JSON serialization
  only require FuncList). All internal node management is handled by TBigList
  automatically.

  Memory management:
  - All pfunc_decl records that are added to FuncList are owned and freed
  by TBigList when it is destroyed or cleared.
  - No separate structural declarations are allocated, so no extra cleanup
  is required.
}
procedure tpascal_func_decl_tool.Fill_Pascal;

// ---------- Debug logging helpers (unchanged) ----------
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

// ---------- Extract preceding comments (unchanged) ----------
  function ExtractPrecedingComments(Idx: integer): TP_String;
  var
    CommentTokens: TP_ArrayString;
    Temp: TP_String;
    i, Count: integer;
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
        DebugLog('  Checking Token[%d]: type=%s, text="%s"',
          [i, GetEnumName(TypeInfo(TTokenType), Ord(Token^.TokenType)), Token^.Text.Text]);

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
                Result := Result + #13#10 + Temp
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

// ---------- Process external and calling convention (unchanged) ----------
  function ProcessExternalAndCallingConvention(Idx: integer; var Output: tfunc_decl): integer;
  var
    TokenAfterSemi, TokenAfterExternal: PTokenData;
    i: integer;
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
        DebugLog('Routine "%s" recognised calling convention: %s',
          [Output.Name.Text, TokenAfterSemi^.Text.Text]);

        TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1, [ttSymbol], ';');
        if TokenAfterExternal = nil then
          begin
            DebugLog('In declaration of "%s", missing semicolon after calling convention "%s"',
              [Output.Name.Text, TokenAfterSemi^.Text.Text]);
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

    TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
    if (TokenAfterExternal <> nil) and (TokenAfterExternal^.TokenType in [ttTextDecl, ttAscii]) then
      begin
        Output.ExternalLibrary := TokenAfterExternal^.Text;
        DebugLog('external library: %s', [Output.ExternalLibrary.Text]);
      end
    else if (TokenAfterExternal <> nil) and (TokenAfterExternal^.TokenType in [ttSymbol]) and (TokenAfterExternal^.Text.Same(';')) then
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

    TokenAfterSemi := Parser.ProbeR(TokenAfterExternal^.Index + 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
    if TokenAfterSemi^.TokenType = ttAscii then
      begin
        Output.HasExplicitName :=
          TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal_Name].Decl);
        Output.HasExplicitIndex :=
          TokenAfterSemi^.Text.Same(Pascal_Keyword_DICT[kExternal_Index].Decl);

        if Output.HasExplicitName or Output.HasExplicitIndex then
          begin
            if Output.HasExplicitName then
                DebugLog('Routine "%s" found "name" clause', [Output.Name.Text])
            else
                DebugLog('Routine "%s" found "index" clause', [Output.Name.Text]);

            TokenAfterExternal := Parser.ProbeR(TokenAfterSemi^.Index + 1, [ttSymbol], ';');
            if TokenAfterExternal = nil then
              begin
                DebugLog('In "%s" clause of "%s", missing terminating semicolon',
                  [TokenAfterSemi^.Text.Text, Output.Name.Text]);
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

// ---------- Process a single procedure/function declaration ----------
  function ProcessProcDeclaration(ProcDeclToken, ProcNameToken: PTokenData; var Output: tfunc_decl): integer;
  var
    TokenAfterName, TokenAfterParen: PTokenData;
    i: integer;
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
                    DebugLog('In routine "%s", missing matching closing parenthesis ")"',
                      [Output.Name.Text]);
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
                DebugLog('In function "%s", missing terminating semicolon after return type',
                  [Output.Name.Text]);
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

// ---------- Process the uses clause ----------
  procedure ProcessUsesClause(const AText: TP_String);
  var
    LocalParser: TTextParsing;
    LocalList: TPascalStringList;
    CleanedText: TP_String;
    i: integer;
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
  i: integer;
  CurrentToken, NextToken, NextNextToken: PTokenData;
  DeclItem: pfunc_decl;
  Sections: TCurrentSections;
  NestedLevel: integer;
  Keyword: TPascal_Keyword;
  PreComment: TP_String;
  FuncCount: integer;
  ErrorOccurred: boolean;
  // ----- Flags to determine ParseSuccess -----
  FoundInterface, FoundImplementation, FoundEnd: boolean;
begin
  DebugLog('Starting Pascal unit parsing', []);

  // Clear any previous data
  FuncList.Clear;
  UsesList.Clear;
  UnitName := '';
  ParseSuccess := False;

  // Initialise state
  i := 0;
  Sections := [];
  NestedLevel := 0;
  FuncCount := 0;
  ErrorOccurred := False;
  FoundInterface := False;
  FoundImplementation := False;
  FoundEnd := False;
  if Parser = nil then
    begin
      DoStatus('Parser is nil');
      exit;
    end;

  // ----- Main parsing loop -----
  while (i < Parser.TokenCount) and (not ErrorOccurred) do
    begin
      CurrentToken := Parser.Tokens[i];
      DebugLog('Main loop: index=%d, type=%s, text="%s"',
        [i, GetEnumName(TypeInfo(TTokenType), Ord(CurrentToken^.TokenType)), CurrentToken^.Text.Text]);

      // Skip whitespace tokens
      if (CurrentToken^.TokenType = ttUnknow) and (CurrentToken^.Text.TrimChar(#32#9#13#10) = '') then
        begin
          DebugLog('  Skipping whitespace');
          Inc(i);
          Continue;
        end;

      // ----- Create a declaration item for the current token -----
      New(DeclItem);
      DeclItem^.Init;
      DeclItem^.NestLevel := NestedLevel;
      DeclItem^.Body := CurrentToken^.Text;
      DeclItem^.IsProc := False;
      DeclItem^.BPos := CurrentToken^.BPos;
      DeclItem^.EPos := CurrentToken^.EPos;

      // ----- Handle nested structures (classes, interfaces, records) -----
      if (not(csEndUnit in Sections)) and (csIntf in Sections) and (not(csImp in Sections)) and (NestedLevel > 0) then
        begin
          if (CurrentToken^.TokenType = ttAscii) then
            begin
              Keyword := Pascal_Keyword(CurrentToken^.Text);
              DebugLog('  Nested level %d, keyword: %s', [NestedLevel, CurrentToken^.Text.Text]);

              if Keyword = kClass then
                begin
                  NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                  if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                    begin
                      NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if not NextNextToken^.Text.Same('(', ';', 'of') then
                        begin
                          Inc(NestedLevel);
                          DebugLog('Nesting +1 (class), depth: %d', [NestedLevel]);
                        end
                      else if NextNextToken^.Text.Same('(') then
                        begin
                          NextNextToken := Parser.ProbeR(Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
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
                  NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                  if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                    begin
                      NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if not NextNextToken^.Text.Same('(', ';') then
                        begin
                          Inc(NestedLevel);
                          DebugLog('Nesting +1 (interface), depth: %d', [NestedLevel]);
                        end
                      else if NextNextToken^.Text.Same('(') then
                        begin
                          NextNextToken := Parser.ProbeR(Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1,
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
                  if Parser.ComparePosStr(CurrentToken^.BPos, 'end;') or Parser.ComparePosStr(CurrentToken^.BPos, 'end ') then
                    begin
                      Dec(NestedLevel);
                      DebugLog('Nesting -1 (end), depth: %d', [NestedLevel]);
                    end;
                end;
            end;
        end

        // ----- Handle top-level structures (unit, interface, implementation, etc.) -----
      else if (not(csEndUnit in Sections)) and (NestedLevel = 0) and (CurrentToken^.TokenType = ttAscii) then
        begin
          Keyword := Pascal_Keyword(CurrentToken^.Text);
          DebugLog('  Top-level token: "%s" (keyword=%s)',
            [CurrentToken^.Text.Text, GetEnumName(TypeInfo(TPascal_Keyword), Ord(Keyword))]);

          // ----- Unit declaration -----
          if (not(csBeginUnit in Sections)) and (Keyword = kUnit) then
            begin
              Sections := [csBeginUnit];
              NextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttSymbol], ';');
              if NextToken = nil then
                begin
                  DebugLog('In unit declaration, unit name or terminating semicolon not found');
                  ErrorOccurred := True;
                  Continue;
                end;
              UnitName := Parser.TokenCombine(CurrentToken^.Index + 1, NextToken^.Index - 1).TrimChar(#32);
              DebugLog('Unit name identified: "%s"', [UnitName.Text]);
              // UnitToken is no longer stored 每 we keep only FuncList
            end;

          if (csBeginUnit in Sections) then
            begin
              // ----- Interface section -----
              if (not(csIntf in Sections)) and (Keyword = kInterface) then
                begin
                  Include(Sections, csIntf);
                  FoundInterface := True;
                  DebugLog('Entering interface section');
                end

                // ----- Implementation section -----
              else if (not(csImp in Sections)) and (Keyword = kImplementation) then
                begin
                  Include(Sections, csImp);
                  FoundImplementation := True;
                  DebugLog('Entering implementation section');
                end

                // ----- Implementation-level blocks (initialization, finalization, end.) -----
              else if (csImp in Sections) and (not(csEndUnit in Sections)) and (CurrentToken^.TokenType = ttAscii) then
                begin
                  if Keyword = kInitialization then
                    begin
                      DebugLog('Initialization block identified');
                      // InitToken no longer stored
                    end
                  else if Keyword = kFinalization then
                    begin
                      DebugLog('Finalization block identified');
                      // FinalToken no longer stored
                    end
                  else if (Parser.ComparePosStr(CurrentToken^.BPos, 'end.')) then
                    begin
                      Include(Sections, csEndUnit);
                      FoundEnd := True;
                      DebugLog('End. identified');
                    end;
                end

                // ----- Interface-level declarations (uses, function, procedure, etc.) -----
              else if (csIntf in Sections) and (not(csImp in Sections)) then
                begin
                  // ----- Uses clause -----
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
                      ProcessUsesClause(Parser.TokenCombine(CurrentToken^.Index + 1, NextToken^.Index - 1));
                      i := NextToken^.Index + 1;
                      // The uses clause itself is not stored as a DeclItem
                      // Dispose the temporary DeclItem and continue
                      DeclItem^.Free;
                      Dispose(DeclItem);
                      Continue;
                    end;
                  Include(Sections, csIntfUses);

                  // ----- Function or procedure declaration -----
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
                      if (NextToken <> nil) and (NextToken^.TokenType = ttAscii) and (Pascal_Keyword(NextToken^.Text) <> kOf) then
                        begin
                          i := ProcessProcDeclaration(CurrentToken, NextToken, DeclItem^);
                          if i = -1 then
                            begin
                              DebugLog('Routine "%s" parsing failed', [DeclItem^.Name.Text]);
                              ErrorOccurred := True;
                              DeclItem^.Free; // <--- fixed
                              Dispose(DeclItem); // <--- fixed
                              Continue;
                            end;
                          // Extend Body to include the entire declaration text
                          DeclItem^.Body := Parser.GetStr(DeclItem^.BPos, DeclItem^.EPos);
                          // Add to FuncList 每 this is our primary storage
                          DeclItem^.Index := FuncList.Num;
                          FuncList.Add(DeclItem);
                          Inc(FuncCount);
                          DebugLog('Recorded routine "%s" (total %d)', [DeclItem^.Name.Text, FuncCount]);
                        end
                      else
                        begin
                          // Not a valid function/procedure declaration; free the item
                          DeclItem^.Free;
                          Dispose(DeclItem);
                        end;
                    end

                    // ----- Class, Interface, Record declarations (nested structures) -----
                  else if Keyword = kClass then
                    begin
                      NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                        begin
                          NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                          if not NextNextToken^.Text.Same('(', ';', 'of') then
                            begin
                              Inc(NestedLevel);
                              DebugLog('Nesting +1 (class), depth: %d', [NestedLevel]);
                            end
                          else if NextNextToken^.Text.Same('(') then
                            begin
                              NextNextToken := Parser.ProbeR(Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1,
                                [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                              if not NextNextToken^.Text.Same('(', ';') then
                                begin
                                  Inc(NestedLevel);
                                  DebugLog('Nesting +1 (class with paren), depth: %d', [NestedLevel]);
                                end;
                            end;
                        end;
                      // Free the temporary DeclItem 每 not a function/procedure
                      DeclItem^.Free;
                      Dispose(DeclItem);
                    end

                  else if Keyword = kInterface then
                    begin
                      NextToken := Parser.TokenProbeL(CurrentToken^.Index - 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                      if (NextToken <> nil) and (NextToken^.Text.Same('=')) then
                        begin
                          NextNextToken := Parser.ProbeR(CurrentToken^.Index + 1, [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                          if not NextNextToken^.Text.Same('(', ';') then
                            begin
                              Inc(NestedLevel);
                              DebugLog('Nesting +1 (interface), depth: %d', [NestedLevel]);
                            end
                          else if NextNextToken^.Text.Same('(') then
                            begin
                              NextNextToken := Parser.ProbeR(Parser.ProbeR(NextNextToken^.Index + 1, ')')^.Index + 1,
                                [ttTextDecl, ttNumber, ttSymbol, ttAscii]);
                              if not NextNextToken^.Text.Same('(', ';') then
                                begin
                                  Inc(NestedLevel);
                                  DebugLog('Nesting +1 (interface with paren), depth: %d', [NestedLevel]);
                                end;
                            end;
                        end;
                      DeclItem^.Free;
                      Dispose(DeclItem);
                    end

                  else if Keyword = kRecord then
                    begin
                      Inc(NestedLevel);
                      DebugLog('Nesting +1 (record), depth: %d', [NestedLevel]);
                      DeclItem^.Free;
                      Dispose(DeclItem);
                    end

                  else
                    begin
                      // Other top-level tokens (type, var, const, etc.) 每 not stored
                      DeclItem^.Free;
                      Dispose(DeclItem);
                    end;
                end
              else
                begin
                  // Other tokens inside implementation, etc. 每 not stored
                  DeclItem^.Free;
                  Dispose(DeclItem);
                end;
            end
          else
            begin
              // Token before unit declaration 每 ignore
              DeclItem^.Free;
              Dispose(DeclItem);
            end;
        end
      else
        begin
          // Other tokens 每 not function/procedure declarations
          DeclItem^.Free;
          Dispose(DeclItem);
        end;

      Inc(i);
    end;

  // ----- Finalise parsing -----
  if ErrorOccurred then
    begin
      DoStatus('Error occurred during parsing, aborted');
      ParseSuccess := False;
    end
  else
    begin
      if UnitName.Len = 0 then
          DoStatus('Warning: unit name not found');

      ParseSuccess := (UnitName.Len > 0) and FoundInterface and FoundImplementation and FoundEnd;

      if ParseSuccess then
          DebugLog('Parsing successful, found %d function/procedure declarations', [FuncCount])
      else
          DebugLog('Parsing failed, missing required structure');
    end;

  // ----- Clear structural pointers (they are no longer used) -----
  UnitToken := nil;
  InterfaceToken := nil;
  ImplementationToken := nil;
  EndToken := nil;
  InitToken := nil;
  FinalToken := nil;
end;
