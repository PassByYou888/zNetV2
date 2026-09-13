(*
  * ------------------------------------------------------------------------------
  * tpascal_func_decl_tool.decl_to_pascal
  * ------------------------------------------------------------------------------
  * Reconstructs a valid Pascal source unit from the parsed metadata.
  *
  * The function filters out declarations that cannot be safely regenerated
  * due to unsupported features (e.g., unsupported parameter types, var/out
  * modifiers, nested declarations). All skipped declarations are reported
  * in detail.
  *
  * Comment handling
  * ----------------
  * After Translate_C_Typ_To_Pascal (or Fill_Pascal), the Comment field is
  * guaranteed to be already in Pascal-style.
  * It is therefore emitted verbatim at the head of each declaration, with
  * no further style detection or conversion.
  *
  * Type coverage
  * -------------
  * IsSupportedPascalType recognises the following families:
  *   Signed integers   : ShortInt, SmallInt, Integer, LongInt, Int64
  *   Unsigned integers : Byte, Word, Cardinal, LongWord, UInt64
  *   Floating-point    : Single, Double, Extended, Real
  *   Untyped pointer   : Pointer
  *   Strings           : string, AnsiString, UnicodeString, PChar,
  *                       PAnsiChar, PWideChar, TP_String, TPascalString,
  *                       TUPascalString, U_String
  * Legacy aliases (dword, longword, int8..int32, uint8..uint32) are also
  * accepted for backward compatibility.
  *
  * Array parameters
  * ----------------
  * When param_array is non-empty (captured from a C declarator such as
  * 'int buf[]'), the type is rendered as 'array of <type>' in the emitted
  * Pascal code.
  *
  * @param Report  If provided, receives a detailed list of skipped
  *                declarations with reasons. The caller must free it.
  * @return        The reconstructed Pascal source code as a TP_String.
*)
function tpascal_func_decl_tool.decl_to_pascal(Report: TPascalStringList): TP_String;

// ---------- Helper: join a TPascalStringList with a separator ----------
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

// ---------- Build parameter list from structured param_arry ----------
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
        // Parameter modifier (var, const, out) - preserve if present
        if Params[i].param_mod <> '' then
            Result := Result + Params[i].param_mod + ' ';
        // Type: array declarators are converted to Pascal open-array form
        if Params[i].param_array <> '' then
            TypeStr := 'array of ' + Params[i].param_typ
        else
            TypeStr := Params[i].param_typ;
        Result := Result + Params[i].param_name + ': ' + TypeStr;
      end;
    if Result <> '' then
        Result := '(' + Result + ')';
  end;

// ---------- Build a single declaration string ----------
  function BuildDeclString(const Decl: tfunc_decl): TP_String;
  var
    ParamStr: TP_String;
    DeclStr: TP_String;
  begin
    Result := '';

    // -------------------------------------------------------------------
    // 1. Preceding comment.
    //
    // The Comment field is guaranteed to be in Pascal-style form ('{ ... }'
    // or '(* ... *)') because both producer paths normalise it:
    // - Fill_Pascal keeps the original Pascal comments verbatim
    // - Translate_C_Typ_To_Pascal rewrites all C comments into Pascal form
    //
    // It is therefore emitted verbatim, without any style detection or
    // conversion.
    // -------------------------------------------------------------------
    if Decl.Comment <> '' then
      begin
        Result := Decl.Comment + #13#10;
      end;

    // 2. Header: 'function' or 'procedure' + name
    if Decl.IsFunction then
        DeclStr := 'function ' + Decl.Name
    else
        DeclStr := 'procedure ' + Decl.Name;

    // 3. Parameters - rebuilt from param_arry (not from ParamDecl)
    ParamStr := BuildParamString(Decl.param_arry);

    // 4. Return type - only for functions, if ResultDecl is present
    if Decl.IsFunction and (Decl.ResultDecl <> '') then
        DeclStr := DeclStr + ParamStr + ': ' + Decl.ResultDecl.TrimChar(#32#9)
    else
        DeclStr := DeclStr + ParamStr;

    // 5. Terminating semicolon
    DeclStr := DeclStr + ';';

    // NOTE: Calling conventions and external directives are omitted by design.
    // If you need them, extend this function accordingly.

    Result := Result + DeclStr;
  end;

// ---------- Check if a Pascal type is supported for generation ----------
  function IsSupportedPascalType(const Typ: TP_String): boolean;
  var
    lowTyp: TP_String;
  begin
    lowTyp := Typ.TrimChar(#32#9).LowerText;
    Result :=
    // Integer types (signed family: ShortInt..Int64, plus legacy aliases)
      lowTyp.Same('shortint', 'smallint', 'integer', 'longint', 'int64', 'dword') or
    // Integer types (unsigned family: Byte..UInt64, plus legacy aliases)
      lowTyp.Same('byte', 'word', 'cardinal', 'longword', 'uint64') or
    // Legacy integer aliases
      lowTyp.Same('int8', 'int16', 'int32') or
      lowTyp.Same('uint8', 'uint16', 'uint32') or
    // Floating-point types
      lowTyp.Same('single', 'double', 'extended', 'real') or
    // Untyped pointer
      lowTyp.Same('pointer') or
    // String types
      lowTyp.Same('string', 'ansistring', 'unicodestring') or
      lowTyp.Same('pchar', 'pansichar', 'pwidechar') or
      lowTyp.Same('tp_string', 'tpascalstring', 'tupascalstring', 'u_string');
  end;

// ---------- Check a single declaration for compatibility ----------
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
    // Check each parameter
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
    // Check return type for functions
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

  // --- Unit header ---
  if UnitName <> '' then
      Result := 'unit ' + UnitName + ';' + #13#10 + #13#10
  else
      Result := 'unit YourUnit;' + #13#10 + #13#10;

  // --- Interface section ---
  Result := Result + 'interface' + #13#10 + #13#10;

  // --- Emit all supported top-level declarations, collect skipped ones ---
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

  // --- Implementation and end ---
  Result := Result + #13#10 + #13#10 + 'implementation' + #13#10 + #13#10 + 'end.' + #13#10;
  Result.Text := U_Replace(Result.Text,
    #13#10 + #13#10 + #13#10, #13#10 + #13#10, False, False);

  if Report <> nil then
    begin
      Report.Add(PFormat('Emitted %d top-level declarations.', [SupportedCount]));
      Report.Add('=== End of report ===');
    end;
end;
