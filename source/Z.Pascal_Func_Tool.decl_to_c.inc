(*
  * ------------------------------------------------------------------------------
  * tpascal_func_decl_tool.decl_to_c
  * ------------------------------------------------------------------------------
  * Reconstructs a valid C header fragment from the parsed metadata.
  *
  * This function is the inverse of Fill_C + Translate_C_Typ_To_Pascal: it
  * takes the internal Pascal-normalised tfunc_decl records and regenerates
  * C-style function prototypes.
  *
  * The function filters out declarations that cannot be safely regenerated
  * (empty names, unsupported types). All skipped declarations are reported
  * in detail if a Report list is provided.
  *
  * Type mapping (Pascal -> C).
  *   The mapping is the exact inverse of Translate_C_Typ_To_Pascal and
  *   preserves both width and signedness so that a full C -> Pascal -> C
  *   round-trip yields an equivalent prototype.
  *
  *   Signed integers:
  *     ShortInt   -> signed char
  *     SmallInt   -> short
  *     Integer    -> int
  *     LongInt    -> long
  *     Int64      -> long long
  *
  *   Unsigned integers:
  *     Byte       -> unsigned char
  *     Word       -> unsigned short
  *     Cardinal   -> unsigned int
  *     LongWord   -> unsigned long
  *     UInt64     -> unsigned long long
  *
  *   Floating point:
  *     Single     -> float
  *     Double     -> double
  *     Extended   -> long double
  *
  *   Untyped pointer:
  *     Pointer    -> void *
  *
  *   C strings:
  *     string family -> char *
  *
  *   Void:
  *     void / ''  -> void
  *
  *   Legacy aliases (longint, dword, longword, smallint, word, byte,
  *   uint64, int8..int32, uint8..uint32, real) are also accepted for
  *   backward compatibility.
  *
  * Parameter modifiers:
  *   const                    -> preserved
  *   var / out                -> not supported (declaration is skipped)
  *
  * Array suffixes:
  *   param_array is appended verbatim after the parameter name so that
  *   declarators such as 'int buf[]' survive the round-trip.
  *
  * Return-type qualifiers:
  *   ResultMod is prepended before the converted return type when it
  *   equals 'const', producing e.g. 'const char * get_error_message(...)'.
  *
  * Comment handling
  * ----------------
  * The Comment field is guaranteed to be in Pascal-style because both
  * producer paths normalise it. It is converted back into a C block
  * comment using direct string concatenation, which avoids the CJK
  * character mangling that would result from a full re-tokenisation pass.
  *
  * @param Report  If provided, receives a detailed list of skipped
  *                declarations with reasons. The caller must free it.
  * @return        The reconstructed C header fragment as a TP_String.
*)
function tpascal_func_decl_tool.decl_to_c(Report: TPascalStringList): TP_String;

// ---------- Helper: convert Pascal type string to C type string ----------
  function PascalTypeToCType(const Typ: TP_String): TP_String;
  var
    t: TP_String;
  begin
    t := Typ.TrimChar(#32#9).LowerText;

    // ----- Signed integer family -> C signed integers -----
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

    // ----- Unsigned integer family -> C unsigned integers -----
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

    // ----- Legacy integer aliases (still accepted) -----
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

    // ----- Floating-point family -> C floating point -----
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

    // ----- Untyped pointer -> void * -----
    if t.Same('pointer') then
      begin
        Result := 'void *'; Exit;
      end;

    // ----- String family -> char * -----
    if t.Same('string', 'ansistring', 'unicodestring') or
      t.Same('pchar', 'pansichar', 'pwidechar') or
      t.Same('tp_string', 'tpascalstring', 'tupascalstring', 'u_string') then
      begin
        Result := 'char *'; Exit;
      end;

    // ----- Void -----
    if (t = '') or t.Same('void') then
      begin
        Result := 'void'; Exit;
      end;

    // ----- Unknown type: keep as-is -----
    Result := Typ.TrimChar(#32#9);
  end;

// ---------- Helper: convert Pascal comment to C comment ----------
(*
  * Convert a Pascal-style comment into a C block comment
  *
  * - If the input is already in C-style, it is
  *   returned unchanged (defensive: normally never reached).
  * - The conversion uses tsPascal to strip the Pascal comment markers,
  *   then re-wraps the plain text using direct concatenation. This avoids
  *   the CJK character mangling that a full re-tokenisation pass would
  *   introduce, and it keeps the exact character sequence of the body.
*)
  function ConvertPascalCommentToCComment(const PCmt: TP_String): TP_String;
  var
    tp: TTextParsing;
    i: integer;
    plain_comment: TP_String;
  begin
    Result := '';
    if PCmt = '' then
        Exit;

    // Already C-style (defensive): keep as-is
    if PCmt.ComparePos(1, '/*') then
      begin
        Result := PCmt;
        Exit;
      end;

    // Parse the Pascal-style comment using tsPascal
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

    // Trim surrounding whitespace and wrap into a C block comment using
    // direct concatenation to preserve the exact character sequence.
    plain_comment := plain_comment.TrimChar(#32#9#13#10);
    if plain_comment.Len > 0 then
        Result := '/* ' + plain_comment.Text + ' */';
  end;

// ---------- Build C parameter list from structured param_arry ----------
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
        // Parameter modifier (only 'const' is preserved)
        if Params[i].param_mod.Same('const') then
            Piece := Piece + 'const ';
        // Convert base type
        ParamType := PascalTypeToCType(Params[i].param_typ);
        Piece := Piece + ParamType;
        // Parameter name (may be empty for unnamed parameters)
        if Params[i].param_name <> '' then
            Piece := Piece + ' ' + Params[i].param_name;
        // Array suffix (e.g. '[]') attaches directly after the name
        if Params[i].param_array <> '' then
            Piece := Piece + Params[i].param_array;

        if i > 0 then
            Result := Result + ', ';
        Result := Result + Piece;
      end;
  end;

// ---------- Build a single C declaration string ----------
  function BuildDeclString(const Decl: tfunc_decl): TP_String;
  var
    ParamStr: TP_String;
    RetType: TP_String;
  begin
    Result := '';

    // -------------------------------------------------------------------
    // 1. Preceding comment.
    //
    // After Translate_C_Typ_To_Pascal (or Fill_Pascal), the Comment field
    // is guaranteed to be in Pascal-style form. It is converted back into
    // a C block comment via a dedicated helper. This gives the output a
    // proper C-style comment consistent with the original header format.
    // -------------------------------------------------------------------
    if Decl.Comment <> '' then
      begin
        Result := ConvertPascalCommentToCComment(Decl.Comment) + #13#10;
      end;

    // -------------------------------------------------------------------
    // 2. Return type: 'void' for procedures, converted type for functions.
    // A captured 'const' qualifier is prepended so that, e.g.,
    // 'string' + 'const' becomes 'const char *'.
    // -------------------------------------------------------------------
    if Decl.IsFunction and (Decl.ResultDecl <> '') then
        RetType := PascalTypeToCType(Decl.ResultDecl)
    else
        RetType := 'void';

    if RetType = '' then
        RetType := 'void';

    if Decl.IsFunction and Decl.ResultMod.Same('const') then
        RetType := 'const ' + RetType;

    // 3. "return_type name"
    Result := Result + RetType + ' ' + Decl.Name;

    // 4. Parameter list
    ParamStr := BuildCParamString(Decl.param_arry);
    Result := Result + '(' + ParamStr + ')';

    // 5. Terminating semicolon
    Result := Result + ';';
  end;

// ---------- Check if a Pascal type can be safely mapped to C ----------
  function IsSupportedCType(const Typ: TP_String): boolean;
  var
    t: TP_String;
  begin
    t := Typ.TrimChar(#32#9).LowerText;
    Result :=
    // Signed integer family
      t.Same('shortint', 'smallint', 'integer', 'longint', 'int64') or
    // Unsigned integer family
      t.Same('byte', 'word', 'cardinal', 'dword', 'longword', 'uint64') or
    // Legacy integer aliases
      t.Same('int8', 'int16', 'int32') or
      t.Same('uint8', 'uint16', 'uint32') or
    // Floating-point family
      t.Same('single', 'double', 'extended', 'real') or
    // Untyped pointer
      t.Same('pointer') or
    // String family
      t.Same('string', 'ansistring', 'unicodestring') or
      t.Same('pchar', 'pansichar', 'pwidechar') or
      t.Same('tp_string', 'tpascalstring', 'tupascalstring', 'u_string') or
    // Void (return type only)
      (t = '') or t.Same('void');
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
        Exit(False);
      end;
    if Decl.Name = '' then
      begin
        Reason := 'Empty name';
        Exit(False);
      end;
    // Check each parameter
    for i := 0 to High(Decl.param_arry) do
      begin
        // var / out modifiers cannot be represented in a plain C prototype
        if Decl.param_arry[i].param_mod.Same('var') or
          Decl.param_arry[i].param_mod.Same('out') then
          begin
            Reason := 'var/out parameter "' + Decl.param_arry[i].param_name +
              '" not supported in C prototype';
            Exit(False);
          end;
        // Parameter type must be supported (empty type means unnamed - skip check)
        if (Decl.param_arry[i].param_typ <> '') and
          (not IsSupportedCType(Decl.param_arry[i].param_typ)) then
          begin
            Reason := 'Parameter "' + Decl.param_arry[i].param_name +
              '" has unsupported type "' + Decl.param_arry[i].param_typ + '"';
            Exit(False);
          end;
      end;
    // Check return type for functions
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

  // --- Optional header comment ---
  if UnitName <> '' then
    begin
      Result := PFormat(
        '/* %s.h */' + #13#10 + #13#10 + '#ifndef %s_H' + #13#10 + '#define %s_H' + #13#10,
        [UnitName.Text, UnitName.Text, UnitName.Text]);

      Result := Result + '/* Generated from unit ' + UnitName + '.h */' +
        #13#10 + #13#10;
    end;

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

  // --- Collapse multiple blank lines at the end (defensive) ---
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
