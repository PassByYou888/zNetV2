procedure tpascal_func_decl_tool.Translate_C_Typ_To_Pascal;

  procedure DebugLog(const Msg: string; const Args: array of const); overload;
  begin
    if Pascal_Func_Tool_Log_Enabled then
        DoStatus('[Translate_C_Typ] ' + PFormat(Msg, Args));
  end;

  procedure DebugLog(const Msg: string); overload;
  begin
    if Pascal_Func_Tool_Log_Enabled then
        DoStatus('[Translate_C_Typ] ' + Msg);
  end;

  function ConvertCTypeToPascal(const CTyp: TP_String): TP_String;
  var
    t: TP_String;
  begin
    t := CTyp.TrimChar(#32#9#13#10).LowerText;

    if t.Same('signed char') or t.Same('int8_t') then
      begin
        Result := 'ShortInt'; Exit;
      end;
    if t.Same('short') or t.Same('short int') or
      t.Same('signed short') or t.Same('signed short int') or
      t.Same('int16_t') then
      begin
        Result := 'SmallInt'; Exit;
      end;
    if t.Same('int') or t.Same('signed') or t.Same('signed int') or
      t.Same('int32_t') then
      begin
        Result := 'Integer'; Exit;
      end;
    if t.Same('long') or t.Same('long int') or
      t.Same('signed long') or t.Same('signed long int') then
      begin
        Result := 'LongInt'; Exit;
      end;
    if t.Same('long long') or t.Same('long long int') or
      t.Same('signed long long') or t.Same('signed long long int') or
      t.Same('int64_t') then
      begin
        Result := 'Int64'; Exit;
      end;

    if t.Same('unsigned char') or t.Same('uint8_t') then
      begin
        Result := 'Byte'; Exit;
      end;
    if t.Same('unsigned short') or t.Same('unsigned short int') or
      t.Same('uint16_t') then
      begin
        Result := 'Word'; Exit;
      end;
    if t.Same('unsigned') or t.Same('unsigned int') or
      t.Same('uint32_t') then
      begin
        Result := 'Cardinal'; Exit;
      end;
    if t.Same('unsigned long') or t.Same('unsigned long int') then
      begin
        Result := 'LongWord'; Exit;
      end;
    if t.Same('unsigned long long') or t.Same('unsigned long long int') or
      t.Same('uint64_t') then
      begin
        Result := 'UInt64'; Exit;
      end;

    if t.Same('size_t') or t.Same('uintptr_t') then
      begin
        Result := 'UInt64'; Exit;
      end;
    if t.Same('ssize_t') or t.Same('ptrdiff_t') or t.Same('intptr_t') then
      begin
        Result := 'Int64'; Exit;
      end;

    if t.Same('float') then
      begin
        Result := 'Single'; Exit;
      end;
    if t.Same('double') then
      begin
        Result := 'Double'; Exit;
      end;
    if t.Same('long double') then
      begin
        Result := 'Extended'; Exit;
      end;

    if t.Same('char *') or t.Same('char*') or
      t.Same('const char *') or t.Same('const char*') or
      t.Same('char const *') or t.Same('char const*') or
      t.Same('const char * const') or t.Same('const char* const') or
      t.Same('char const * const') or t.Same('char const* const') then
      begin
        Result := 'string'; Exit;
      end;

    if t.Same('cbytes') or t.Same('const cbytes') or
      t.Same('cbytes *') or t.Same('const cbytes *') or
      t.Same('cbytes*') or t.Same('const cbytes*') then
      begin
        Result := 'TBytes'; Exit;
      end;

    if CTyp.Exists('*') then
      begin
        Result := 'Pointer'; Exit;
      end;

    if t.Same('void') then
      begin
        Result := ''; Exit;
      end;

    Result := CTyp.TrimChar(#32#9#13#10);
  end;

  function BuildPascalParamDecl(const Params: tfunc_param_arry): TP_String;
  var
    j: integer;
    Body: TP_String;
  begin
    Body := '';
    for j := 0 to High(Params) do
      begin
        if j > 0 then
            Body.Append('; ');
        if Params[j].param_mod <> '' then
          begin
            Body.Append(Params[j].param_mod);
            Body.Append(' ');
          end;
        Body.Append(Params[j].param_name);
        Body.Append(': ');
        Body.Append(Params[j].param_typ);
      end;

    if Body.Len > 0 then
      begin
        Result := '(';
        Result.Append(Body);
        Result.Append(')');
      end
    else
        Result := '';
  end;

  function ConvertCCommentToPascalComment(const CComment: TP_String): TP_String;
  var
    tp: TTextParsing;
    i: integer;
    plain_comment: TP_String;
  begin
    Result := '';
    if CComment = '' then
        Exit;

    if CComment.ComparePos(1, '{') or CComment.ComparePos(1, '(*') then
      begin
        Result := CComment;
        Exit;
      end;

    tp := TTextParsing.Create(CComment, tsC);
    try
      plain_comment := '';
      for i := 0 to tp.TokenCount - 1 do
        begin
          if tp.Token[i]^.TokenType = TTokenType.ttComment then
            begin
              if plain_comment.Len > 0 then
                  plain_comment.Append(#13#10);
              plain_comment.Append(
                TTextParsing.Translate_C_Decl_Comment_To_Text(tp.Token[i]^.Text)
                );
            end;
        end;
    finally
        disposeObject(tp);
    end;

    plain_comment := plain_comment.TrimChar(#32#9#13#10);
    if (plain_comment.Len > 0) and (plain_comment.First = '*') then
      begin
        plain_comment.DeleteFirst;
        plain_comment := plain_comment.TrimChar(#32#9#13#10);
      end;

    if plain_comment.Len > 0 then
        Result := '{ ' + plain_comment.Text + ' }';
  end;

  function BuildPascalBody(const Decl: tfunc_decl): TP_String;
  begin
    Result := '';

    if Decl.Comment <> '' then
      begin
        Result.Append(Decl.Comment);
        Result.Append(#13#10);
      end;

    if Decl.IsFunction then
      begin
        Result.Append('function ');
        Result.Append(Decl.Name);
      end
    else
      begin
        Result.Append('procedure ');
        Result.Append(Decl.Name);
      end;

    Result.Append(Decl.ParamDecl);

    if Decl.IsFunction and (Decl.ResultDecl <> '') then
      begin
        Result.Append(': ');
        Result.Append(Decl.ResultDecl);
      end;

    Result.Append(';');
  end;

var
  i, j: integer;
  Decl: pfunc_decl;
  NewRetType: TP_String;
begin
  DebugLog('Translate_C_Typ_To_Pascal: starting, %d declaration(s)',
    [FuncList.Count]);

  for i := 0 to FuncList.Count - 1 do
    begin
      Decl := FuncList[i];
      if not Decl^.IsProc then
          Continue;

      for j := 0 to High(Decl^.param_arry) do
        begin
          Decl^.param_arry[j].param_typ :=
            ConvertCTypeToPascal(Decl^.param_arry[j].param_typ);
          Decl^.param_arry[j].param_value := '';

          if (Decl^.param_arry[j].param_array <> '') and
             Decl^.param_arry[j].param_typ.Same('Byte') then
            begin
              Decl^.param_arry[j].param_typ := 'TBytes';
              Decl^.param_arry[j].param_array := '';
            end;
        end;

      Decl^.ParamDecl := BuildPascalParamDecl(Decl^.param_arry);

      if Decl^.IsFunction then
        begin
          NewRetType := ConvertCTypeToPascal(Decl^.ResultDecl);
          Decl^.ResultDecl := NewRetType;
          if NewRetType = '' then
            begin
              Decl^.IsFunction := False;
              Decl^.ResultMod := '';
            end;
        end
      else
        begin
          Decl^.ResultDecl := '';
          Decl^.ResultMod := '';
        end;

      Decl^.BPos := -1;
      Decl^.EPos := -1;
      Decl^.CallConv := '';
      Decl^.IsExternal := False;
      Decl^.ExternalLibrary := '';
      Decl^.HasExplicitName := False;
      Decl^.ExplicitName := '';
      Decl^.HasExplicitIndex := False;
      Decl^.ExplicitIndex := '';
      Decl^.Index := i;
      Decl^.NestLevel := 0;

      Decl^.Comment := ConvertCCommentToPascalComment(Decl^.Comment);

      Decl^.Body := BuildPascalBody(Decl^);

      DebugLog('  Converted "%s": params="%s", ret="%s"',
        [Decl^.Name.Text, Decl^.ParamDecl.Text, Decl^.ResultDecl.Text]);
    end;

  DebugLog('Translate_C_Typ_To_Pascal: done', []);
end;
