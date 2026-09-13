(*
  * ------------------------------------------------------------------------------
  * tpascal_func_decl_tool.Translate_C_Typ_To_Pascal
  * ------------------------------------------------------------------------------
  * Converts all C-typed metadata in FuncList into Pascal-compatible form.
  *
  * For each declaration in FuncList:
  *   1. Convert every parameter type in param_arry from C to Pascal
  *   2. Clear each parameter's default value (C has none)
  *   3. Rebuild ParamDecl from the converted param_arry (Pascal syntax)
  *   4. Convert the return type from C to Pascal
  *      - 'void' collapses to '' and demotes IsFunction to False
  *   5. Convert the Comment field from C-style to Pascal-style and write
  *      it back into the record. From this point on, Comment is uniformly
  *      stored in Pascal.
  *   6. Clear all non-public fields (BPos, EPos, CallConv, IsExternal,
  *      ExternalLibrary, HasExplicitName, ExplicitName, HasExplicitIndex,
  *      ExplicitIndex, NestLevel); reset Index to current position.
  *   7. Rebuild Body from Comment + Name + ParamDecl + ResultDecl.
  *
  * C -> Pascal type mapping (applied to both parameter and return types).
  * Width and signedness are preserved so that the produced Pascal type can
  * later be mapped back to an equivalent C type by decl_to_c.
  *
  *   Signed integers:
  *     signed char, int8_t                                    -> ShortInt
  *     short, short int, signed short, int16_t                -> SmallInt
  *     int, signed, signed int, int32_t                       -> Integer
  *     long, long int, signed long, signed long int           -> LongInt
  *     long long, long long int, signed long long, int64_t    -> Int64
  *
  *   Unsigned integers:
  *     unsigned char, uint8_t                                 -> Byte
  *     unsigned short, unsigned short int, uint16_t           -> Word
  *     unsigned, unsigned int, uint32_t                       -> Cardinal
  *     unsigned long, unsigned long int                       -> LongWord
  *     unsigned long long, unsigned long long int, uint64_t   -> UInt64
  *
  *   Size / pointer-width integers:
  *     size_t, uintptr_t                                      -> UInt64
  *     ssize_t, ptrdiff_t, intptr_t                           -> Int64
  *
  *   Floating point:
  *     float                                                  -> Single
  *     double                                                 -> Double
  *     long double                                            -> Extended
  *
  *   C strings (checked before the generic pointer rule):
  *     char *, const char *, char const *                     -> string
  *
  *   Generic pointer catch-all:
  *     any remaining type containing '*'                      -> Pointer
  *
  *   Void:
  *     void (return type only)                                -> ''
  *
  * COMMENT HANDLING
  *   All incoming C comments (/* ... *\/, //, Doxygen '/**') are converted
  *   into Pascal-style comments of the form '{ ... }' and written back into
  *   the declaration record. This gives a single canonical comment style
  *   for downstream converters:
  *     - decl_to_pascal emits the stored Pascal comment verbatim
  *     - decl_to_c converts it back into a C block comment
  *
  * PRESERVED FIELDS (not touched by this pass)
  *   - ResultMod: the return-type qualifier captured by Fill_C.
  *   - param_array: the array suffix captured per parameter by Fill_C.
*)
procedure tpascal_func_decl_tool.Translate_C_Typ_To_Pascal;

// ============================================================================
// SECTION 1: Debug logging helpers
// ============================================================================
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

// ============================================================================
// SECTION 2: C type -> Pascal type conversion
// ============================================================================
(*
  Convert a single C type string to its Pascal equivalent, preserving
  width and signedness. Input is expected in canonical single-space form
  (e.g. 'const char *', 'unsigned long long').
*)
  function ConvertCTypeToPascal(const CTyp: TP_String): TP_String;
  var
    t: TP_String;
  begin
    t := CTyp.TrimChar(#32#9#13#10).LowerText;

    // -------------------------------------------------------------------
    // Signed integer family (narrow -> wide)
    // -------------------------------------------------------------------
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

    // -------------------------------------------------------------------
    // Unsigned integer family (narrow -> wide)
    // -------------------------------------------------------------------
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

    // -------------------------------------------------------------------
    // Size / pointer-width integer types
    // -------------------------------------------------------------------
    if t.Same('size_t') or t.Same('uintptr_t') then
      begin
        Result := 'UInt64'; Exit;
      end;
    if t.Same('ssize_t') or t.Same('ptrdiff_t') or t.Same('intptr_t') then
      begin
        Result := 'Int64'; Exit;
      end;

    // -------------------------------------------------------------------
    // Floating-point family
    // -------------------------------------------------------------------
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

    // -------------------------------------------------------------------
    // C string family -> Pascal 'string'
    // (checked before the generic pointer rule)
    // -------------------------------------------------------------------
    if t.Same('char *') or t.Same('char*') or
      t.Same('const char *') or t.Same('const char*') or
      t.Same('char const *') or t.Same('char const*') then
      begin
        Result := 'string'; Exit;
      end;

    // -------------------------------------------------------------------
    // Generic pointer catch-all -> Pointer
    // (int *, int **, void *, unsigned char *, ...)
    // -------------------------------------------------------------------
    if CTyp.Exists('*') then
      begin
        Result := 'Pointer'; Exit;
      end;

    // -------------------------------------------------------------------
    // void -> '' (empty, procedure)
    // -------------------------------------------------------------------
    if t.Same('void') then
      begin
        Result := ''; Exit;
      end;

    // -------------------------------------------------------------------
    // Unknown type: keep unchanged
    // -------------------------------------------------------------------
    Result := CTyp.TrimChar(#32#9#13#10);
  end;

// ============================================================================
// SECTION 3: Build Pascal parameter declaration
// ============================================================================
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

// ============================================================================
// SECTION 4: Comment conversion (C-style -> Pascal-style)
// ============================================================================
(*
  * Convert a comment string from C-style to Pascal-style
  *
  * - If the input is already Pascal-style,
  *   it is returned unchanged.
  * - Doxygen '/**' openers are normalised: the extra '*' that follows
  *   the opener is stripped before wrapping.
  * - The wrapping uses direct concatenation ('{ ' + text + ' }') rather
  *   than Translate_Text_To_Pascal_Decl_Comment, which re-tokenises and
  *   re-joins the text and inserts spurious spaces between CJK characters.
*)
  function ConvertCCommentToPascalComment(const CComment: TP_String): TP_String;
  var
    tp: TTextParsing;
    i: integer;
    plain_comment: TP_String;
  begin
    Result := '';
    if CComment = '' then
        Exit;

    // Already Pascal-style: keep as-is
    if CComment.ComparePos(1, '{') or CComment.ComparePos(1, '(*') then
      begin
        Result := CComment;
        Exit;
      end;

    // Parse the C-style comment using tsC
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

    // Trim surrounding whitespace, then strip a leading '*'
    // (residue from a Doxygen '/**' opener).
    plain_comment := plain_comment.TrimChar(#32#9#13#10);
    if (plain_comment.Len > 0) and (plain_comment.First = '*') then
      begin
        plain_comment.DeleteFirst;
        plain_comment := plain_comment.TrimChar(#32#9#13#10);
      end;

    // Wrap into Pascal-style braces
    if plain_comment.Len > 0 then
        Result := '{ ' + plain_comment.Text + ' }';
  end;

// ============================================================================
// SECTION 5: Build Pascal declaration body
// ============================================================================
(*
  Rebuild the declaration Body from Comment + Name + ParamDecl + ResultDecl.

  The Comment field is expected to be already in Pascal-style form (this
  is guaranteed by Step 5 in the main conversion loop below). It is
  emitted verbatim at the top of the body.
*)
  function BuildPascalBody(const Decl: tfunc_decl): TP_String;
  begin
    Result := '';

    // ----- 1. Preceding comment (already in Pascal-style) -----
    if Decl.Comment <> '' then
      begin
        Result.Append(Decl.Comment);
        Result.Append(#13#10);
      end;

    // ----- 2. 'function' or 'procedure' + name -----
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

    // ----- 3. Parameter declaration -----
    Result.Append(Decl.ParamDecl);

    // ----- 4. Return type (functions only) -----
    if Decl.IsFunction and (Decl.ResultDecl <> '') then
      begin
        Result.Append(': ');
        Result.Append(Decl.ResultDecl);
      end;

    // ----- 5. Terminating semicolon -----
    Result.Append(';');
  end;

// ============================================================================
// SECTION 6: Main conversion loop
// ============================================================================
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

      // ----- Step 1: Convert each parameter type -----
      for j := 0 to High(Decl^.param_arry) do
        begin
          Decl^.param_arry[j].param_typ :=
            ConvertCTypeToPascal(Decl^.param_arry[j].param_typ);
          Decl^.param_arry[j].param_value := '';
        end;

      // ----- Step 2: Rebuild ParamDecl from the converted param_arry -----
      Decl^.ParamDecl := BuildPascalParamDecl(Decl^.param_arry);

      // ----- Step 3: Convert the return type -----
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

      // ----- Step 4: Clear all non-public fields -----
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

      // ----- Step 5: Convert Comment to Pascal-style and write it back -----
      // All C-style comments are rewritten into the canonical Pascal-style
      // form here. Both decl_to_pascal and decl_to_c then operate on a
      // single comment style, which simplifies their implementations.
      Decl^.Comment := ConvertCCommentToPascalComment(Decl^.Comment);

      // ----- Step 6: Rebuild Body -----
      Decl^.Body := BuildPascalBody(Decl^);

      DebugLog('  Converted "%s": params="%s", ret="%s"',
        [Decl^.Name.Text, Decl^.ParamDecl.Text, Decl^.ResultDecl.Text]);
    end;

  DebugLog('Translate_C_Typ_To_Pascal: done', []);
end;
