procedure tpascal_func_decl_tool.Fill_C;

  procedure DebugLog(const Msg: string; const Args: array of const); overload;
  begin
    if Pascal_Func_Tool_Log_Enabled then
        DoStatus('[c_parser] ' + PFormat(Msg, Args));
  end;

  procedure DebugLog(const Msg: string); overload;
  begin
    if Pascal_Func_Tool_Log_Enabled then
        DoStatus('[c_parser] ' + Msg);
  end;

  function IsCReservedWord(const s: TP_String): boolean;
  begin
    Result :=
      s.Same('auto') or s.Same('break') or s.Same('case') or s.Same('char') or
      s.Same('const') or s.Same('continue') or s.Same('default') or s.Same('do') or
      s.Same('double') or s.Same('else') or s.Same('enum') or s.Same('extern') or
      s.Same('float') or s.Same('for') or s.Same('goto') or s.Same('if') or
      s.Same('inline') or s.Same('int') or s.Same('long') or s.Same('register') or
      s.Same('restrict') or s.Same('return') or s.Same('short') or s.Same('signed') or
      s.Same('sizeof') or s.Same('static') or s.Same('struct') or s.Same('switch') or
      s.Same('typedef') or s.Same('union') or s.Same('unsigned') or s.Same('void') or
      s.Same('volatile') or s.Same('while') or
      s.Same('_Alignas') or s.Same('_Alignof') or s.Same('_Atomic') or s.Same('_Bool') or
      s.Same('_Complex') or s.Same('_Generic') or s.Same('_Imaginary') or
      s.Same('_Noreturn') or s.Same('_Static_assert') or s.Same('_Thread_local') or
      s.Same('__cdecl') or s.Same('__stdcall') or s.Same('__fastcall') or
      s.Same('__pascal') or s.Same('__vectorcall') or
      s.Same('__declspec') or s.Same('__attribute__') or s.Same('__attribute') or
      s.Same('__inline') or s.Same('__forceinline') or
      s.Same('__restrict') or s.Same('__restrict__') or
      s.Same('__volatile__') or s.Same('__volatile') or
      s.Same('__extension__') or s.Same('__asm__') or s.Same('__asm') or
      s.Same('cbytes');
  end;

  function IsWhitespaceToken(idx: integer): boolean;
  begin
    Result := (Parser.Tokens[idx]^.TokenType = ttUnknow) and
      (Parser.Tokens[idx]^.Text.TrimChar(#32#9#13#10) = '');
  end;

  function IsNoSpaceBefore(const s: TP_String): boolean;
  begin
    Result := s.Same(')') or s.Same(']') or s.Same(',') or s.Same(';');
  end;

  function IsNoSpaceAfter(const s: TP_String): boolean;
  begin
    Result := s.Same('(') or s.Same('[');
  end;

  function JoinTokens(bIdx, eIdx: integer): TP_String;
  var
    k: integer;
    s: TP_String;
  begin
    Result := '';
    if (bIdx < 0) or (eIdx < bIdx) then
        Exit;
    for k := bIdx to eIdx do
      begin
        if IsWhitespaceToken(k) then
            Continue;

        s := Parser.Tokens[k]^.Text;
        if Result.Len > 0 then
            Result.Append(' ');
        Result.Append(s);
      end;
    Result := Result.TrimChar(#32#9#13#10);
  end;

  function JoinTypeTokens(bIdx, eIdx: integer): TP_String;
  var
    k: integer;
    s: TP_String;
  begin
    Result := '';
    if (bIdx < 0) or (eIdx < bIdx) then
        Exit;
    for k := bIdx to eIdx do
      begin
        if IsWhitespaceToken(k) then
            Continue;

        s := Parser.Tokens[k]^.Text;

        if s.Same('restrict') or s.Same('__restrict') or s.Same('__restrict__') then
          begin
            DebugLog('  JoinTypeTokens: dropped restrict qualifier');
            Continue;
          end;

        if Result.Len > 0 then
            Result.Append(' ');
        Result.Append(s);
      end;
    Result := Result.TrimChar(#32#9#13#10);
  end;

  function JoinTokens_Canonical(bIdx, eIdx: integer): TP_String;
  var
    k: integer;
    s, prev_s: TP_String;
    NeedSpace: boolean;
  begin
    Result := '';
    prev_s := '';
    if (bIdx < 0) or (eIdx < bIdx) then
        Exit;

    for k := bIdx to eIdx do
      begin
        if IsWhitespaceToken(k) then
            Continue;

        s := Parser.Tokens[k]^.Text;

        NeedSpace := False;
        if Result.Len > 0 then
          begin
            if IsNoSpaceBefore(s) then
                NeedSpace := False
            else if IsNoSpaceAfter(prev_s) then
                NeedSpace := False
            else
                NeedSpace := True;
          end;

        if NeedSpace then
            Result.Append(' ');
        Result.Append(s);
        prev_s := s;
      end;

    Result := Result.TrimChar(#32#9#13#10);
  end;

  function ExtractReturnType(bIdx, eIdx: integer): TP_String;
  var
    m: integer;
    depth: integer;
    s: TP_String;
  begin
    Result := '';
    if (bIdx < 0) or (eIdx < bIdx) then
        Exit;

    m := bIdx;
    while m <= eIdx do
      begin
        s := Parser.Tokens[m]^.Text;

        if IsWhitespaceToken(m) then
          begin
            Inc(m);
            Continue;
          end;

        if s.Same('__declspec') or s.Same('__attribute__') or s.Same('__attribute') then
          begin
            if (m + 1 <= eIdx) and Parser.Tokens[m + 1]^.Text.Same('(') then
              begin
                DebugLog('Skipping attribute wrapper starting at token %d', [m]);
                depth := 1;
                Inc(m, 2);
                while (m <= eIdx) and (depth > 0) do
                  begin
                    if Parser.Tokens[m]^.Text.Same('(') then Inc(depth)
                    else if Parser.Tokens[m]^.Text.Same(')') then Dec(depth);
                    Inc(m);
                  end;
                Continue;
              end;
          end;

        if s.Same('extern') or s.Same('static') or s.Same('inline') or
          s.Same('__inline') or s.Same('__forceinline') or
          s.Same('__cdecl') or s.Same('__stdcall') or s.Same('__fastcall') or
          s.Same('__pascal') or s.Same('__vectorcall') or
          s.Same('register') or s.Same('volatile') or
          s.Same('__volatile__') or s.Same('__volatile') then
          begin
            DebugLog('Filtered modifier "%s" from return type', [s.Text]);
            Inc(m);
            Continue;
          end;

        if Result.Len > 0 then
            Result.Append(' ');
        Result.Append(s);
        Inc(m);
      end;

    Result := Result.TrimChar(#32#9#13#10);
  end;

  function ExtractPrecedingComments(idx: integer): TP_String;
  var
    CommentTokens: TP_ArrayString;
    Temp: TP_String;
    i2, Count: integer;
    Token: PTokenData;
    Lines: TPascalStringList;
    k: integer;
  begin
    Count := 0;
    SetLength(CommentTokens, 0);
    i2 := idx - 1;

    while i2 >= 0 do
      begin
        Token := Parser.Tokens[i2];
        if (Token^.TokenType = ttUnknow) and (Token^.Text.TrimChar(#32#9#13#10) = '') then
            Dec(i2)
        else
            Break;
      end;

    while i2 >= 0 do
      begin
        Token := Parser.Tokens[i2];
        if Token^.TokenType = ttComment then
          begin
            SetLength(CommentTokens, Count + 1);
            CommentTokens[Count] := Token^.Text;
            Inc(Count);
            Dec(i2);
          end
        else
            Break;
      end;

    Result := '';
    for i2 := Count - 1 downto 0 do
      begin
        Temp := CommentTokens[i2];
        if Result.Len > 0 then
            Result := Result + #13#10 + Temp
        else
            Result := Temp;
      end;

    SetLength(CommentTokens, 0);

    if (Result.Len > 0) and Result.Exists([#10, #13]) then
      begin
        Lines := TPascalStringList.Create;
        try
          UmlSeparatorText(Result, Lines, #10);
          Result := '';
          for k := 0 to Lines.Count - 1 do
            begin
              Temp := Lines[k];
              while (Temp.Len > 0) and (Temp.Last = #13) do
                  Temp.DeleteLast;

              if k > 0 then
                  Result.Append(sLineBreak);

              if k = 0 then
                begin
                  Result.Append(Temp.Text);
                end
              else
                begin
                  Temp := Temp.TrimChar(#32#9);

                  if (Temp.Len > 0) and (Temp.First = '*') then
                    begin
                      Temp.DeleteFirst;
                      while (Temp.Len > 0) and (Temp.First in [#32, #9]) do
                          Temp.DeleteFirst;
                      Result.Append(' *');
                      if Temp.Len > 0 then
                        begin
                          Result.Append(' ');
                          Result.Append(Temp.Text);
                        end;
                    end
                  else if (Temp.Len > 0) and (Temp.First = '/') then
                    begin
                      Result.Append(Temp.Text);
                    end
                  else if Temp.Len > 0 then
                    begin
                      Result.Append(' * ');
                      Result.Append(Temp.Text);
                    end;
                end;
            end;
        finally
            disposeObject(Lines);
        end;
      end;
  end;

  function ExtractUnitNameFromHeader: TP_String;
  const
    SCAN_LINES = 100;
  var
    txt: TP_String;
    i, j: Integer;
    lineNo: Integer;
    scanEnd: Integer;
    kw_is_ifndef: Boolean;
    kw_is_ifdef: Boolean;
    kw_is_define: Boolean;
    MacroName: TP_String;

    function IsIdentChar_(c: TP_Char): Boolean;
    begin
      Result := CharIn(c, [cAtoZ, c0to9], '_');
    end;

    function IdentBeforeFileName(pos: Integer): TP_String;
    var
      p, start: Integer;
    begin
      p := pos - 1;
      while (p >= 1) and (IsIdentChar_(txt[p]) or (txt[p] = '.')) do
          Dec(p);
      start := p + 1;
      while (start < pos) and (txt[start] = '.') do
          Inc(start);
      if (start >= pos) or (not CharIn(txt[start], cAtoZ)) then
        begin
          Result := '';
          Exit;
        end;
      Result := txt.GetString(start, pos);
    end;

    function IdentAfter(pos: Integer): TP_String;
    var
      p: Integer;
    begin
      Result := '';
      p := pos;
      while (p <= txt.Len) and IsIdentChar_(txt[p]) do
        begin
          Result.Append(txt[p]);
          Inc(p);
        end;
    end;

    function IsGuardMacroName(const s: TP_String): Boolean;
    var
      t: TP_String;
    begin
      Result := False;
      t := s;
      if t.Len < 2 then
          Exit;

      if t.GetString(t.Len - 1, t.Len + 1).Same('_H') then Exit(True);
      if (t.Len >= 3) and
         t.GetString(t.Len - 2, t.Len + 1).Same('_H_') then Exit(True);
      if (t.Len >= 4) and
         t.GetString(t.Len - 3, t.Len + 1).Same('_H__') then Exit(True);
      if (t.Len >= 5) and
         t.GetString(t.Len - 4, t.Len + 1).Same('_HPP') then Exit(True);
      if (t.Len >= 5) and
         t.GetString(t.Len - 4, t.Len + 1).Same('_HXX') then Exit(True);
      if (t.Len >= 10) and
         t.GetString(t.Len - 9, t.Len + 1).Same('_INCLUDED') then Exit(True);
    end;

    function StripGuard(const s: TP_String): TP_String;
    var
      t, su: TP_String;
      idx: Integer;
      suffixes: array[0..5] of TP_String;
    begin
      suffixes[0] := '_INCLUDED';
      suffixes[1] := '_HXX';
      suffixes[2] := '_HPP';
      suffixes[3] := '_H__';
      suffixes[4] := '_H_';
      suffixes[5] := '_H';

      t := s;
      while (t.Len > 0) and (t.Last = '_') do
          t.DeleteLast;

      for idx := 0 to 5 do
        begin
          su := suffixes[idx];
          if (t.Len >= su.Len) and
             (t.GetString(t.Len - su.Len + 1, t.Len + 1).Same(su)) then
            begin
              t.Len := t.Len - su.Len;
              Break;
            end;
        end;

      while (t.Len > 0) and (t.First = '_') do
          t.DeleteFirst;

      Result := t;
    end;

  begin
    Result := 'untitled.h';

    if Parser = nil then
      begin
        DebugLog('Parser is nil, using default unit name: "%s"',
          [Result.Text]);
        Exit;
      end;

    txt := Parser.Text;
    if txt.Len = 0 then
      begin
        DebugLog('Empty input, using default unit name: "%s"',
          [Result.Text]);
        Exit;
      end;

    lineNo := 1;
    scanEnd := 1;
    while (scanEnd <= txt.Len) and (lineNo <= SCAN_LINES) do
      begin
        if txt[scanEnd] in [#10, #13] then
          begin
            Inc(lineNo);
            while (scanEnd <= txt.Len) and (txt[scanEnd] in [#10, #13]) do
                Inc(scanEnd);
          end
        else
            Inc(scanEnd);
      end;

    i := 1;
    while i < scanEnd do
      begin
        if txt[i] = '.' then
          begin
            if (i + 1 < scanEnd) and
               ((txt[i + 1] = 'h') or (txt[i + 1] = 'H') or
                (txt[i + 1] = 'c') or (txt[i + 1] = 'C')) then
              begin
                if (i + 2 >= scanEnd) or
                   (not IsIdentChar_(txt[i + 2])) then
                  begin
                    Result := IdentBeforeFileName(i);
                    if Result.Len > 0 then
                      begin
                        DebugLog('Unit name from file name: "%s"',
                          [Result.Text]);
                        Exit;
                      end;
                  end;
              end;
          end;
        Inc(i);
      end;

    i := 1;
    while i < scanEnd do
      begin
        if txt[i] = '#' then
          begin
            kw_is_ifndef := txt.ComparePos(i, '#ifndef');
            kw_is_ifdef  := (not kw_is_ifndef) and txt.ComparePos(i, '#ifdef');
            kw_is_define := (not kw_is_ifndef) and (not kw_is_ifdef) and
                            txt.ComparePos(i, '#define');

            if kw_is_ifndef or kw_is_ifdef or kw_is_define then
              begin
                j := i + 1;
                while (j < scanEnd) and IsIdentChar_(txt[j]) do
                    Inc(j);
                while (j < scanEnd) and (txt[j] in [#32, #9]) do
                    Inc(j);
                MacroName := IdentAfter(j);
                if MacroName.Len > 0 then
                  begin
                    if (not kw_is_define) or IsGuardMacroName(MacroName) then
                      begin
                        Result := StripGuard(MacroName);
                        if Result.Len > 0 then
                          begin
                            DebugLog('Unit name from include guard: "%s"',
                              [Result.Text]);
                            Exit;
                          end;
                      end;
                  end;
              end;
          end;
        Inc(i);
      end;

    Result := 'untitled.h';
    DebugLog('Unit name not found in header, using default: "%s"',
      [Result.Text]);
  end;

  function ContainsFuncPtrParam(OpenParenIdx, CloseParenIdx: integer): boolean;
  var
    m: integer;
  begin
    Result := False;
    m := OpenParenIdx + 1;
    while m < CloseParenIdx do
      begin
        if Parser.Tokens[m]^.Text.Same('(') then
          begin
            if (m + 1 < CloseParenIdx) and Parser.Tokens[m + 1]^.Text.Same('*') then
              begin
                Result := True;
                Exit;
              end;
          end;
        Inc(m);
      end;
  end;

  function ExtractArraySuffix(segB, segE: integer): TP_String;
  var
    m: integer;
  begin
    Result := '';
    if (segB < 0) or (segE < segB) then
        Exit;

    m := segE;
    while (m >= segB) and IsWhitespaceToken(m) do
        Dec(m);
    if (m < segB) or (not Parser.Tokens[m]^.Text.Same(']')) then
        Exit;

    while (m >= segB) and (not Parser.Tokens[m]^.Text.Same('[')) do
        Dec(m);
    if m < segB then
        Exit;

    Result := JoinTokens_Canonical(m, segE);
    DebugLog('  ExtractArraySuffix: "%s"', [Result.Text]);
  end;

  procedure ParseParamSegment(segB, segE: integer; out ParamMod, ParamName, ParamTyp: TP_String);
  var
    m: integer;
    LastIdentIdx: integer;
    depth: integer;
  begin
    ParamMod := '';
    ParamName := '';
    ParamTyp := '';

    if (segB < 0) or (segE < segB) then
        Exit;

    if (segB = segE) and Parser.Tokens[segB]^.Text.Same('void') then
      begin
        ParamTyp := 'void';
        DebugLog('  ParseParamSegment: (void) -> empty parameter', []);
        Exit;
      end;

    LastIdentIdx := -1;
    m := segE;
    while m >= segB do
      begin
        if Parser.Tokens[m]^.Text.Same(']') then
          begin
            depth := 1;
            Dec(m);
            while (m >= segB) and (depth > 0) do
              begin
                if Parser.Tokens[m]^.Text.Same(']') then Inc(depth)
                else if Parser.Tokens[m]^.Text.Same('[') then Dec(depth);
                Dec(m);
              end;
            Continue;
          end;

        if (Parser.Tokens[m]^.TokenType = ttAscii) and
          (not IsCReservedWord(Parser.Tokens[m]^.Text)) then
          begin
            LastIdentIdx := m;
            Break;
          end;

        Dec(m);
      end;

    if LastIdentIdx < 0 then
      begin
        ParamTyp := JoinTypeTokens(segB, segE);
        for m := segB to segE do
          if Parser.Tokens[m]^.Text.Same('const') then
            begin
              ParamMod := 'const';
              Break;
            end;
        DebugLog('  ParseParamSegment: unnamed, typ="%s"', [ParamTyp.Text]);
        Exit;
      end;

    if (LastIdentIdx > segB) and
      (Parser.Tokens[LastIdentIdx - 1]^.Text.Same('struct') or
        Parser.Tokens[LastIdentIdx - 1]^.Text.Same('enum') or
        Parser.Tokens[LastIdentIdx - 1]^.Text.Same('union')) then
      begin
        ParamTyp := JoinTypeTokens(segB, segE);
        for m := segB to LastIdentIdx - 1 do
          if Parser.Tokens[m]^.Text.Same('const') then
            begin
              ParamMod := 'const';
              Break;
            end;
        DebugLog('  ParseParamSegment: unnamed struct/enum/union, typ="%s"', [ParamTyp.Text]);
        Exit;
      end;

    ParamName := Parser.Tokens[LastIdentIdx]^.Text;
    if LastIdentIdx > segB then
        ParamTyp := JoinTypeTokens(segB, LastIdentIdx - 1)
    else
        ParamTyp := '';

    for m := segB to LastIdentIdx - 1 do
      if Parser.Tokens[m]^.Text.Same('const') then
        begin
          ParamMod := 'const';
          Break;
        end;

    DebugLog('  ParseParamSegment: mod="%s", name="%s", typ="%s"',
      [ParamMod.Text, ParamName.Text, ParamTyp.Text]);
  end;

  procedure ParseParamList(pB, pE: integer; var Decl: tfunc_decl);
  var
    j: integer;
    segBegin: integer;
    depth: integer;
    ParamArr: array of tfunc_param_decl;
    ParamCount: integer;
    PMod, PName, PTyp: TP_String;
    ParamRec: tfunc_param_decl;
  begin
    SetLength(ParamArr, 0);
    ParamCount := 0;

    if pB > pE then
      begin
        SetLength(Decl.param_arry, 0);
        DebugLog('  ParseParamList: empty parameter list', []);
        Exit;
      end;

    segBegin := pB;
    depth := 0;
    for j := pB to pE do
      begin
        if Parser.Tokens[j]^.Text.Same('(') then
            Inc(depth)
        else if Parser.Tokens[j]^.Text.Same(')') then
            Dec(depth)
        else if (depth = 0) and Parser.Tokens[j]^.Text.Same(',') then
          begin
            ParseParamSegment(segBegin, j - 1, PMod, PName, PTyp);
            ParamRec.reset;
            ParamRec.param_mod := PMod;
            ParamRec.param_name := PName;
            ParamRec.param_typ := PTyp;
            ParamRec.param_array := ExtractArraySuffix(segBegin, j - 1);
            SetLength(ParamArr, ParamCount + 1);
            ParamArr[ParamCount] := ParamRec;
            Inc(ParamCount);
            segBegin := j + 1;
          end;
      end;

    ParseParamSegment(segBegin, pE, PMod, PName, PTyp);
    ParamRec.reset;
    ParamRec.param_mod := PMod;
    ParamRec.param_name := PName;
    ParamRec.param_typ := PTyp;
    ParamRec.param_array := ExtractArraySuffix(segBegin, pE);
    SetLength(ParamArr, ParamCount + 1);
    ParamArr[ParamCount] := ParamRec;
    Inc(ParamCount);

    if (ParamCount = 1) and (ParamArr[0].param_typ.Same('void')) then
      begin
        SetLength(Decl.param_arry, 0);
        DebugLog('  ParseParamList: (void) -> zero parameters', []);
        Exit;
      end;

    SetLength(Decl.param_arry, ParamCount);
    for j := 0 to ParamCount - 1 do
        Decl.param_arry[j] := ParamArr[j];
    DebugLog('  ParseParamList: %d parameter(s) stored', [ParamCount]);
  end;

  procedure ProcessStatement(StmtB, StmtE: integer;
    var Decl: tfunc_decl; var IsFunc: boolean);
  var
    j: integer;
    ParenOpenIdx: integer;
    ParenCloseTok: PTokenData;
    NameIdx: integer;
    ReturnTypeText: TP_String;
    ParamsText: TP_String;
    TrimmedRetType: TP_String;
  begin
    IsFunc := False;

    if StmtB > StmtE then
        Exit;

    ParenOpenIdx := -1;
    NameIdx := -1;
    for j := StmtB to StmtE do
      begin
        if Parser.Tokens[j]^.Text.Same('(') then
          begin
            if (j > StmtB) and
              (Parser.Tokens[j - 1]^.TokenType = ttAscii) and
              (not IsCReservedWord(Parser.Tokens[j - 1]^.Text)) then
              begin
                ParenOpenIdx := j;
                NameIdx := j - 1;
                Break;
              end;
          end;
      end;

    if ParenOpenIdx < 0 then
      begin
        DebugLog('ProcessStatement: no function-name pattern found in [%d..%d]',
          [StmtB, StmtE]);
        Exit;
      end;

    ParenCloseTok := Parser.IndentSymbolEndProbeR(ParenOpenIdx, '(', ')');
    if ParenCloseTok = nil then
      begin
        DebugLog('ProcessStatement: unmatched "(" at token %d', [ParenOpenIdx]);
        Exit;
      end;

    for j := ParenCloseTok^.Index + 1 to StmtE do
      begin
        if Parser.Tokens[j]^.Text.Same('=') then
          begin
            DebugLog('ProcessStatement: skipped (contains "=" initializer)');
            Exit;
          end;
      end;

    if ContainsFuncPtrParam(ParenOpenIdx, ParenCloseTok^.Index) then
      begin
        DebugLog('Skipped function-pointer parameter at statement starting at token %d', [StmtB]);
        Exit;
      end;

    if NameIdx > StmtB then
        ReturnTypeText := ExtractReturnType(StmtB, NameIdx - 1)
    else
        ReturnTypeText := 'void';

    Decl.ResultMod := '';
    if NameIdx > StmtB then
      for j := StmtB to NameIdx - 1 do
        if Parser.Tokens[j]^.Text.Same('const') then
          begin
            Decl.ResultMod := 'const';
            DebugLog('ProcessStatement: return type carries const qualifier');
            Break;
          end;

    ParamsText := JoinTokens_Canonical(ParenOpenIdx, ParenCloseTok^.Index);

    Decl.Name := Parser.Tokens[NameIdx]^.Text;
    Decl.IsProc := True;
    TrimmedRetType := ReturnTypeText.TrimChar(#32#9#13#10);
    Decl.IsFunction := not TrimmedRetType.Same('void');
    Decl.BPos := Parser.Tokens[StmtB]^.BPos;
    Decl.EPos := Parser.Tokens[StmtE]^.EPos;
    Decl.Body := Parser.GetStr(Decl.BPos, Decl.EPos);
    Decl.ResultDecl := TrimmedRetType;
    Decl.ParamDecl := ParamsText;
    Decl.Comment := ExtractPrecedingComments(StmtB);
    Decl.NestLevel := 0;
    Decl.Index := FuncList.Num;
    Decl.CallConv := '';
    Decl.IsExternal := False;
    Decl.ExternalLibrary := '';
    Decl.HasExplicitName := False;
    Decl.ExplicitName := '';
    Decl.HasExplicitIndex := False;
    Decl.ExplicitIndex := '';

    ParseParamList(ParenOpenIdx + 1, ParenCloseTok^.Index - 1, Decl);

    DebugLog('ProcessStatement: accepted "%s", ret="%s", params="%s"',
      [Decl.Name.Text, Decl.ResultDecl.Text, Decl.ParamDecl.Text]);

    IsFunc := True;
  end;

  function ShouldSkipBlock(OpenIdx, StmtB: integer): boolean;
  var
    k2: integer;
  begin
    Result := False;
    if StmtB < 0 then
        Exit;

    if (OpenIdx > StmtB) and Parser.Tokens[OpenIdx - 1]^.Text.Same(')') then
      begin
        Result := True;
        Exit;
      end;

    for k2 := StmtB to OpenIdx - 1 do
      if Parser.Tokens[k2]^.Text.Same('struct') or
        Parser.Tokens[k2]^.Text.Same('enum') or
        Parser.Tokens[k2]^.Text.Same('union') or
        Parser.Tokens[k2]^.Text.Same('typedef') then
        begin
          Result := True;
          Exit;
        end;
  end;

var
  i: integer;
  k: integer;
  Tok: PTokenData;
  CloseTok: PTokenData;
  DeclItem: pfunc_decl;
  ErrorOccurred: boolean;
  FuncCount: integer;
  StmtBIdx: integer;
  HashLine: integer;
  IsFunc: boolean;
  NeedSkip: boolean;
begin
  DebugLog('Starting C header parsing', []);

  FuncList.Clear;
  UsesList.Clear;
  ParseSuccess := False;

  if Parser = nil then
    begin
      DoStatus('Parser is nil');
      UnitName := 'untitled.h';
      Exit;
    end;

  UnitName := ExtractUnitNameFromHeader;

  i := 0;
  ErrorOccurred := False;
  FuncCount := 0;
  StmtBIdx := -1;

  while (i < Parser.TokenCount) and (not ErrorOccurred) do
    begin
      Tok := Parser.Tokens[i];

      if (Tok^.TokenType = ttUnknow) and (Tok^.Text.TrimChar(#32#9#13#10) = '') then
        begin
          Inc(i);
          Continue;
        end;

      if Tok^.TokenType = ttComment then
        begin
          Inc(i);
          Continue;
        end;

      if Tok^.Text.Same('#') then
        begin
          DebugLog('Skipping preprocessor line starting at token %d', [i]);
          HashLine := Parser.GetPoint(Tok^.BPos).y;
          k := i + 1;
          while k < Parser.TokenCount do
            begin
              if Parser.GetPoint(Parser.Tokens[k]^.BPos).y > HashLine then
                  Break;
              Inc(k);
            end;
          i := k;
          StmtBIdx := -1;
          Continue;
        end;

      if Tok^.Text.Same('{') then
        begin
          NeedSkip := ShouldSkipBlock(i, StmtBIdx);

          if NeedSkip then
            begin
              DebugLog('Skipping block at token %d', [i]);
              CloseTok := Parser.IndentSymbolEndProbeR(i, '{', '}');
              if CloseTok = nil then
                begin
                  DebugLog('Unmatched { at token %d', [i]);
                  ErrorOccurred := True;
                  Break;
                end;
              i := CloseTok^.Index + 1;
              if (i < Parser.TokenCount) and Parser.Tokens[i]^.Text.Same(';') then
                  Inc(i);
              StmtBIdx := -1;
              Continue;
            end;

          DebugLog('Transparent { at token %d', [i]);
          StmtBIdx := -1;
          Inc(i);
          Continue;
        end;

      if Tok^.Text.Same('}') then
        begin
          Inc(i);
          if (i < Parser.TokenCount) and Parser.Tokens[i]^.Text.Same(';') then
              Inc(i);
          StmtBIdx := -1;
          Continue;
        end;

      if Tok^.Text.Same(';') then
        begin
          if StmtBIdx >= 0 then
            begin
              New(DeclItem);
              DeclItem^.Init;
              ProcessStatement(StmtBIdx, i - 1, DeclItem^, IsFunc);
              if IsFunc then
                begin
                  FuncList.Add(DeclItem);
                  Inc(FuncCount);
                  DebugLog('Recorded function "%s" (total %d)',
                    [DeclItem^.Name.Text, FuncCount]);
                end
              else
                begin
                  DeclItem^.Free;
                  Dispose(DeclItem);
                end;
            end;
          StmtBIdx := -1;
          Inc(i);
          Continue;
        end;

      if StmtBIdx < 0 then
          StmtBIdx := i;

      Inc(i);
    end;

  if ErrorOccurred then
    begin
      DoStatus('Error occurred during C parsing, aborted');
      ParseSuccess := False;
    end
  else
    begin
      ParseSuccess := FuncCount > 0;
      if ParseSuccess then
          DebugLog('C parsing successful, found %d function prototypes', [FuncCount])
      else
          DebugLog('C parsing completed, no function prototypes found');
    end;

  UnitToken := nil;
  InterfaceToken := nil;
  ImplementationToken := nil;
  EndToken := nil;
  InitToken := nil;
  FinalToken := nil;
end;
