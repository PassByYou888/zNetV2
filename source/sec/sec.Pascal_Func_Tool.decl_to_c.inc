function tpascal_func_decl_tool.decl_to_c(Report: TPascalStringList): TP_String;

  function PascalTypeToCType(const Typ: TP_String): TP_String;
  var
    t: TP_String;
  begin
    t := Typ.TrimChar(#32#9).LowerText;

    if t.Same('shortint') then
      begin
        Result := 'signed char'; Exit;
      end;
    if t.Same('smallint') then
      begin
        Result := 'short'; Exit;
      end;
    if t.Same('integer') then
      begin
        Result := 'int'; Exit;
      end;
    if t.Same('longint') then
      begin
        Result := 'long'; Exit;
      end;
    if t.Same('int64') then
      begin
        Result := 'long long'; Exit;
      end;

    if t.Same('byte') then
      begin
        Result := 'unsigned char'; Exit;
      end;
    if t.Same('word') then
      begin
        Result := 'unsigned short'; Exit;
      end;
    if t.Same('cardinal') or t.Same('dword') then
      begin
        Result := 'unsigned int'; Exit;
      end;
    if t.Same('longword') then
      begin
        Result := 'unsigned long'; Exit;
      end;
    if t.Same('uint64') then
      begin
        Result := 'unsigned long long'; Exit;
      end;

    if t.Same('int8') then
      begin
        Result := 'signed char'; Exit;
      end;
    if t.Same('int16') then
      begin
        Result := 'short'; Exit;
      end;
    if t.Same('int32') then
      begin
        Result := 'int'; Exit;
      end;
    if t.Same('uint8') then
      begin
        Result := 'unsigned char'; Exit;
      end;
    if t.Same('uint16') then
      begin
        Result := 'unsigned short'; Exit;
      end;
    if t.Same('uint32') then
      begin
        Result := 'unsigned int'; Exit;
      end;

    if t.Same('single') then
      begin
        Result := 'float'; Exit;
      end;
    if t.Same('double') then
      begin
        Result := 'double'; Exit;
      end;
    if t.Same('extended') or t.Same('real') then
      begin
        Result := 'long double'; Exit;
      end;

    if t.Same('pointer') then
      begin
        Result := 'void *'; Exit;
      end;

    if t.Same('tbytes') then
      begin
        Result := 'CBytes'; Exit;
      end;

    if t.Same('string', 'ansistring', 'unicodestring') or
      t.Same('pchar', 'pansichar', 'pwidechar') or
      t.Same('tp_string', 'tpascalstring', 'tupascalstring', 'u_string') then
      begin
        Result := 'char *'; Exit;
      end;

    if (t = '') or t.Same('void') then
      begin
        Result := 'void'; Exit;
      end;

    Result := Typ.TrimChar(#32#9);
  end;

  function ConvertPascalCommentToCComment(const PCmt: TP_String): TP_String;
  var
    tp: TTextParsing;
    i: integer;
    plain_comment: TP_String;
  begin
    Result := '';
    if PCmt = '' then
        Exit;

    if PCmt.ComparePos(1, '/*') then
      begin
        Result := PCmt;
        Exit;
      end;

    tp := TTextParsing.Create(PCmt, tsPascal);
    try
      plain_comment := '';
      for i := 0 to tp.TokenCount - 1 do
        begin
          if tp.Token[i]^.TokenType = TTokenType.ttComment then
            begin
              if plain_comment.Len > 0 then
                  plain_comment.Append(#13#10);
              plain_comment.Append(
                TTextParsing.Translate_Pascal_Decl_Comment_To_Text(tp.Token[i]^.Text)
                );
            end;
        end;
    finally
        disposeObject(tp);
    end;

    plain_comment := plain_comment.TrimChar(#32#9#13#10);
    if plain_comment.Len > 0 then
        Result := '/* ' + plain_comment.Text + ' */';
  end;

  function BuildCParamString(const Params: tfunc_param_arry): TP_String;
  var
    i: integer;
    ParamType: TP_String;
    Piece: TP_String;
  begin
    Result := '';
    if Length(Params) = 0 then
      begin
        Result := 'void';
        Exit;
      end;

    for i := 0 to High(Params) do
      begin
        Piece := '';
        if Params[i].param_mod.Same('const') then
            Piece := Piece + 'const ';
        ParamType := PascalTypeToCType(Params[i].param_typ);
        Piece := Piece + ParamType;
        if Params[i].param_name <> '' then
            Piece := Piece + ' ' + Params[i].param_name;
        if Params[i].param_array <> '' then
            Piece := Piece + Params[i].param_array;

        if i > 0 then
            Result := Result + ', ';
        Result := Result + Piece;
      end;
  end;

  function BuildDeclString(const Decl: tfunc_decl): TP_String;
  var
    ParamStr: TP_String;
    RetType: TP_String;
  begin
    Result := '';

    if Decl.Comment <> '' then
      begin
        Result := ConvertPascalCommentToCComment(Decl.Comment) + #13#10;
      end;

    if Decl.IsFunction and (Decl.ResultDecl <> '') then
        RetType := PascalTypeToCType(Decl.ResultDecl)
    else
        RetType := 'void';

    if RetType = '' then
        RetType := 'void';

    if Decl.IsFunction and Decl.ResultMod.Same('const') then
        RetType := 'const ' + RetType;

    Result := Result + RetType + ' ' + Decl.Name;

    ParamStr := BuildCParamString(Decl.param_arry);
    Result := Result + '(' + ParamStr + ')';

    Result := Result + ';';
  end;

  function IsSupportedCType(const Typ: TP_String): boolean;
  var
    t: TP_String;
  begin
    t := Typ.TrimChar(#32#9).LowerText;
    Result :=
      t.Same('shortint', 'smallint', 'integer', 'longint', 'int64') or
      t.Same('byte', 'word', 'cardinal', 'dword', 'longword', 'uint64') or
      t.Same('int8', 'int16', 'int32') or
      t.Same('uint8', 'uint16', 'uint32') or
      t.Same('single', 'double', 'extended', 'real') or
      t.Same('pointer') or
      t.Same('tbytes') or
      t.Same('string', 'ansistring', 'unicodestring') or
      t.Same('pchar', 'pansichar', 'pwidechar') or
      t.Same('tp_string', 'tpascalstring', 'tupascalstring', 'u_string') or
      (t = '') or t.Same('void');
  end;

  function IsDeclSupported(const Decl: tfunc_decl; out Reason: TP_String): boolean;
  var
    i: integer;
  begin
    Reason := '';
    if not Decl.IsProc then
      begin
        Reason := 'Not a procedure/function (IsProc=False)';
        Exit(False);
      end;
    if Decl.Name = '' then
      begin
        Reason := 'Empty name';
        Exit(False);
      end;
    for i := 0 to High(Decl.param_arry) do
      begin
        if Decl.param_arry[i].param_mod.Same('var') or
          Decl.param_arry[i].param_mod.Same('out') then
          begin
            Reason := 'var/out parameter "' + Decl.param_arry[i].param_name +
              '" not supported in C prototype';
            Exit(False);
          end;
        if (Decl.param_arry[i].param_typ <> '') and
          (not IsSupportedCType(Decl.param_arry[i].param_typ)) then
          begin
            Reason := 'Parameter "' + Decl.param_arry[i].param_name +
              '" has unsupported type "' + Decl.param_arry[i].param_typ + '"';
            Exit(False);
          end;
      end;
    if Decl.IsFunction and (Decl.ResultDecl <> '') then
      begin
        if not IsSupportedCType(Decl.ResultDecl) then
          begin
            Reason := 'Return type "' + Decl.ResultDecl + '" is unsupported';
            Exit(False);
          end;
      end;
    Result := True;
  end;

var
  i: integer;
  Decl: pfunc_decl;
  SupportedCount: integer;
  Reason, tmp: TP_String;
begin
  Result := '';
  SupportedCount := 0;

  if Report <> nil then
    begin
      Report.Clear;
      Report.Add('=== C Declaration skip report ===');
      Report.Add(PFormat('Total declarations in FuncList: %d', [FuncList.Count]));
    end;

  if UnitName <> '' then
    begin
      Result := PFormat(
        '/* %s.h */' + #13#10 + #13#10 + '#ifndef %s_H' + #13#10 + '#define %s_H' + #13#10,
        [UnitName.Text, UnitName.Text, UnitName.Text]);

      Result := Result + '/* Generated from unit ' + UnitName + '.h */' +
        #13#10 + #13#10;
    end;

  for i := 0 to FuncList.Count - 1 do
    begin
      Decl := FuncList[i];
      if IsDeclSupported(Decl^, Reason) then
        begin
          if SupportedCount > 0 then
              Result := Result + #13#10;
          tmp := BuildDeclString(Decl^);
          Result := Result + tmp + if_(tmp.Exists([#13, #10]), #13#10, '');
          Inc(SupportedCount);
        end
      else
        begin
          if Report <> nil then
            Report.Add(PFormat('Skipped: "%s" (index %d) - Reason: %s',
              [Decl^.Name.Text, i, Reason.Text]));
        end;
    end;

  Result.Text := U_Replace(Result.Text,
    #13#10 + #13#10 + #13#10, #13#10 + #13#10, False, False);

  if UnitName <> '' then
    begin
      Result := Result + #13#10 + PFormat('#endif /* %s_H */' + #13#10, [UnitName.Text]);
    end;

  if Report <> nil then
    begin
      Report.Add(PFormat('Emitted %d top-level C declarations.', [SupportedCount]));
      Report.Add('=== End of report ===');
    end;
end;
