function tpascal_func_decl_tool.decl_to_pascal(Report: TPascalStringList): TP_String;

  function JoinStringList(const List: TPascalStringList; const Sep: TP_String): TP_String;
  var
    i: integer;
  begin
    Result := '';
    for i := 0 to List.Count - 1 do
      begin
        if i > 0 then
            Result := Result + Sep;
        Result := Result + TP_String(List[i]);
      end;
  end;

  function BuildParamString(const Params: tfunc_param_arry): TP_String;
  var
    i: integer;
    TypeStr: TP_String;
  begin
    Result := '';
    for i := 0 to High(Params) do
      begin
        if i > 0 then
            Result := Result + '; ';
        if Params[i].param_mod <> '' then
            Result := Result + Params[i].param_mod + ' ';
        if Params[i].param_array <> '' then
          begin
            if Params[i].param_typ.Same('Byte') then
                TypeStr := 'TBytes'
            else
                TypeStr := 'array of ' + Params[i].param_typ;
          end
        else
            TypeStr := Params[i].param_typ;
        Result := Result + Params[i].param_name + ': ' + TypeStr;
      end;
    if Result <> '' then
        Result := '(' + Result + ')';
  end;

  function BuildDeclString(const Decl: tfunc_decl): TP_String;
  var
    ParamStr: TP_String;
    DeclStr: TP_String;
  begin
    Result := '';

    if Decl.Comment <> '' then
      begin
        Result := Decl.Comment + #13#10;
      end;

    if Decl.IsFunction then
        DeclStr := 'function ' + Decl.Name
    else
        DeclStr := 'procedure ' + Decl.Name;

    ParamStr := BuildParamString(Decl.param_arry);

    if Decl.IsFunction and (Decl.ResultDecl <> '') then
        DeclStr := DeclStr + ParamStr + ': ' + Decl.ResultDecl.TrimChar(#32#9)
    else
        DeclStr := DeclStr + ParamStr;

    DeclStr := DeclStr + ';';

    Result := Result + DeclStr;
  end;

  function IsSupportedPascalType(const Typ: TP_String): boolean;
  var
    lowTyp: TP_String;
  begin
    lowTyp := Typ.TrimChar(#32#9).LowerText;
    Result :=
      lowTyp.Same('shortint', 'smallint', 'integer', 'longint', 'int64', 'dword') or
      lowTyp.Same('byte', 'word', 'cardinal', 'longword', 'uint64') or
      lowTyp.Same('int8', 'int16', 'int32') or
      lowTyp.Same('uint8', 'uint16', 'uint32') or
      lowTyp.Same('single', 'double', 'extended', 'real') or
      lowTyp.Same('pointer') or
      lowTyp.Same('tbytes') or
      lowTyp.Same('string', 'ansistring', 'unicodestring') or
      lowTyp.Same('pchar', 'pansichar', 'pwidechar') or
      lowTyp.Same('tp_string', 'tpascalstring', 'tupascalstring', 'u_string');
  end;

  function IsDeclSupported(const Decl: tfunc_decl; out Reason: TP_String): boolean;
  var
    i: integer;
  begin
    Reason := '';
    if not Decl.IsProc then
      begin
        Reason := 'Not a procedure/function (IsProc=False)';
        exit(False);
      end;
    if Decl.NestLevel <> 0 then
      begin
        Reason := 'Nested declaration (NestLevel=' + umlIntToStr(Decl.NestLevel) + ')';
        exit(False);
      end;
    if Decl.Name = '' then
      begin
        Reason := 'Empty name';
        exit(False);
      end;
    for i := 0 to High(Decl.param_arry) do
      begin
        if Decl.param_arry[i].param_name = '' then
          begin
            Reason := 'Parameter name is empty';
            exit(False);
          end;
        if (Decl.param_arry[i].param_mod <> '') and
          (Decl.param_arry[i].param_mod.Same('var') or
            Decl.param_arry[i].param_mod.Same('out')) then
          begin
            Reason := 'var/out parameter "' + Decl.param_arry[i].param_name + '" not supported';
            exit(False);
          end;
        if not IsSupportedPascalType(Decl.param_arry[i].param_typ) then
          begin
            Reason := 'Parameter "' + Decl.param_arry[i].param_name +
              '" has unsupported type "' + Decl.param_arry[i].param_typ + '"';
            exit(False);
          end;
      end;
    if Decl.IsFunction then
      begin
        if not IsSupportedPascalType(Decl.ResultDecl) then
          begin
            Reason := 'Return type "' + Decl.ResultDecl + '" is unsupported';
            exit(False);
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
      Report.Add('=== Declaration skip report ===');
      Report.Add(PFormat('Total declarations in FuncList: %d', [FuncList.Count]));
    end;

  if UnitName <> '' then
      Result := 'unit ' + UnitName + ';' + #13#10 + #13#10
  else
      Result := 'unit YourUnit;' + #13#10 + #13#10;

  Result := Result + 'interface' + #13#10 + #13#10;

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

  Result := Result + #13#10 + #13#10 + 'implementation' + #13#10 + #13#10 + 'end.' + #13#10;
  Result.Text := U_Replace(Result.Text,
    #13#10 + #13#10 + #13#10, #13#10 + #13#10, False, False);

  if Report <> nil then
    begin
      Report.Add(PFormat('Emitted %d top-level declarations.', [SupportedCount]));
      Report.Add('=== End of report ===');
    end;
end;
