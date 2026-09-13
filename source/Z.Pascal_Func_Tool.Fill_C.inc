(*
  * ------------------------------------------------------------------------------
  * tpascal_func_decl_tool.Fill_C
  * ------------------------------------------------------------------------------
  * C header parser — extracts top-level function prototypes from .h files.
  *
  * SCOPE
  *   Extracted   : top-level function prototypes ending with ';'
  *   Skipped     : preprocessor lines, type definitions (struct/enum/union),
  *                 global variables, function definitions (with '{ ... }'),
  *                 variables initialized with '=', function-pointer parameters
  *   Transparent : `extern "C" {` blocks — contents are processed normally
  *
  * TYPE HANDLING
  *   Return types and parameter types are captured as raw text. Storage-class
  *   and calling-convention modifiers (extern, static, inline, __cdecl, ...)
  *   are stripped from the return type but preserved in the source text.
  *
  *   The 'const' qualifier is captured in two places:
  *     - Parameter-level: stored in param_mod (any position in the segment,
  *       so both 'const char *' and 'char const *' are recognised).
  *     - Return-type-level: stored in Decl.ResultMod.
  *
  *   The 'restrict' qualifier is stripped from the type string so that
  *   'int * restrict' is normalised to 'int *'. The downstream type
  *   converter then maps any remaining pointer to a generic Pointer type,
  *   allowing prototypes containing restrict-qualified pointers to be
  *   represented in both Pascal and C output.
  *
  *   Array suffixes ('[]', '[N]') are extracted into param_array so that the
  *   base type stays a simple identifier that both decl_to_pascal and
  *   decl_to_c can handle independently.
  *
  * COMMENT FORMATTING
  *   ExtractPrecedingComments normalises multi-line comments: every line
  *   after the first one receives a leading ' *' so that the emitted
  *   comment follows the canonical C block-comment layout. Lines that
  *   already carry a '*' marker are collapsed to a single ' *'; lines
  *   that begin with '/' (e.g. '// xxx' continuation lines) are kept
  *   as-is; single-line comments are returned unchanged.
  *
  * UNIT NAME EXTRACTION
  *   The unit name is derived from the source header itself, using a
  *   best-effort scan of the leading region. Priority:
  *     1. A file-like identifier ending in '.h' or '.c' inside the leading
  *        comment block (e.g. '/* test_header.h ... *\/' -> 'test_header').
  *        The identifier must begin with a letter so that fragments such as
  *        '1.0.3.h' do not yield '3'.
  *     2. The include-guard macro name.
  *        - '#ifndef' / '#ifdef' always imply a guard.
  *        - '#define' is accepted only when the macro name looks like a
  *          guard (ends with _H, _H_, _H__, _INCLUDED, _HPP or _HXX),
  *          which avoids mistaking plain constants such as
  *          '#define MAX_SIZE 1024' for a guard.
  *     3. Fall back to 'untitled.h' when neither is found (including empty
  *        input and nil Parser).
  *   The scan is restricted to the first SCAN_LINES lines to avoid false
  *   positives from later code and to keep the search cheap.
  *
  * OUTPUT
  *   Prototypes are stored in FuncList as tfunc_decl records, using the same
  *   field layout as Fill_Pascal so that JSON serialization and downstream
  *   processing remain identical.
*)
procedure tpascal_func_decl_tool.Fill_C;

(* ============================================================================ *)
(* SECTION 1: Debug logging helpers *)
(* ============================================================================ *)
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

(* ============================================================================ *)
(* SECTION 2: C reserved word table *)
(* ============================================================================ *)
{ Returns True if s is a C keyword or a compiler-specific modifier that
  cannot be used as a function or parameter name. }
  function IsCReservedWord(const s: TP_String): boolean;
  begin
    Result :=
    (* ----- C89 / C99 / C11 standard keywords ----- *)
      s.Same('auto') or s.Same('break') or s.Same('case') or s.Same('char') or
      s.Same('const') or s.Same('continue') or s.Same('default') or s.Same('do') or
      s.Same('double') or s.Same('else') or s.Same('enum') or s.Same('extern') or
      s.Same('float') or s.Same('for') or s.Same('goto') or s.Same('if') or
      s.Same('inline') or s.Same('int') or s.Same('long') or s.Same('register') or
      s.Same('restrict') or s.Same('return') or s.Same('short') or s.Same('signed') or
      s.Same('sizeof') or s.Same('static') or s.Same('struct') or s.Same('switch') or
      s.Same('typedef') or s.Same('union') or s.Same('unsigned') or s.Same('void') or
      s.Same('volatile') or s.Same('while') or
    (* ----- C11 keywords ----- *)
      s.Same('_Alignas') or s.Same('_Alignof') or s.Same('_Atomic') or s.Same('_Bool') or
      s.Same('_Complex') or s.Same('_Generic') or s.Same('_Imaginary') or
      s.Same('_Noreturn') or s.Same('_Static_assert') or s.Same('_Thread_local') or
    (* ----- Common compiler extensions ----- *)
      s.Same('__cdecl') or s.Same('__stdcall') or s.Same('__fastcall') or
      s.Same('__pascal') or s.Same('__vectorcall') or
      s.Same('__declspec') or s.Same('__attribute__') or s.Same('__attribute') or
      s.Same('__inline') or s.Same('__forceinline') or
      s.Same('__restrict') or s.Same('__restrict__') or
      s.Same('__volatile__') or s.Same('__volatile') or
      s.Same('__extension__') or s.Same('__asm__') or s.Same('__asm');
  end;

(* ============================================================================ *)
(* SECTION 3: Token classification helpers *)
(* ============================================================================ *)

{ Returns True if the token at idx is pure whitespace.
  In tsC mode the lexer emits whitespace as ttUnknow tokens, so we must
  explicitly identify them to avoid injecting extra spaces. }
  function IsWhitespaceToken(idx: integer): boolean;
  begin
    Result := (Parser.Tokens[idx]^.TokenType = ttUnknow) and
      (Parser.Tokens[idx]^.Text.TrimChar(#32#9#13#10) = '');
  end;

{ Returns True if the token text is one of the punctuation characters that
  should NOT be preceded by a space in canonicalized output. }
  function IsNoSpaceBefore(const s: TP_String): boolean;
  begin
    Result := s.Same(')') or s.Same(']') or s.Same(',') or s.Same(';');
  end;

{ Returns True if the token text is one of the punctuation characters that
  should NOT be followed by a space in canonicalized output. }
  function IsNoSpaceAfter(const s: TP_String): boolean;
  begin
    Result := s.Same('(') or s.Same('[');
  end;

(* ============================================================================ *)
(* SECTION 4: Token joining *)
(* ============================================================================ *)

{ Join a token range using single spaces, skipping whitespace tokens.
  Used for canonical type strings such as 'const char *' and 'unsigned int'. }
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

{ Join a token range as a canonical C type string, silently dropping any
  'restrict' / '__restrict' / '__restrict__' qualifier. This normalises
  declarators like 'int * restrict' or 'const char * restrict' down to
  their base pointer form, so the downstream converter can map them to a
  generic Pointer without losing the prototype entirely. }
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

        // Drop restrict-family qualifiers from the type text
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

{ Join a token range using canonical C spacing rules:
  - '(' , '[' : no space after
  - ')' , ']' : no space before
  - ','       : no space before
  - all other tokens separated by a single space
  Example: (int a, int b)  (const char * s)  (int buf[], int len) }
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

(* ============================================================================ *)
(* SECTION 5: Return type extraction *)
(* ============================================================================ *)

{ Extract the return type from a token range, filtering out storage-class
  and calling-convention modifiers. Returns a canonical type string.

  Filtered modifiers:
  extern, static, inline, register, volatile,
  __inline, __forceinline, __volatile, __volatile__,
  __cdecl, __stdcall, __fastcall, __pascal, __vectorcall,
  __declspec(...),  __attribute__((...)) }
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

        (* ----- Skip whitespace ----- *)
        if IsWhitespaceToken(m) then
          begin
            Inc(m);
            Continue;
          end;

        (* ----- Skip __declspec(...) or __attribute__((...)) as a whole ----- *)
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

        (* ----- Skip calling-convention and storage-class modifiers ----- *)
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

        (* ----- Append meaningful token ----- *)
        if Result.Len > 0 then
            Result.Append(' ');
        Result.Append(s);
        Inc(m);
      end;

    Result := Result.TrimChar(#32#9#13#10);
  end;

(* ============================================================================ *)
(* SECTION 6: Preceding comment extraction *)
(* ============================================================================ *)

{ Extract consecutive comment tokens immediately preceding the given index,
  skipping whitespace in between. Returns them in source order.

  Multi-line normalisation
  ------------------------
  When the merged comment spans more than one line, every line after the
  first is normalised so that it begins with a single ' *' marker. This
  yields the canonical C block-comment layout:

      /* first line
       * second line
       * third line *\/

  Rules per line (k > 0):
    - Already begins with '*'  : collapse to a single leading ' *', then
      keep the remaining text.
    - Begins with '/'          : keep as-is (e.g. '//' continuation lines).
    - Otherwise                : prefix with ' * '.
    - Empty line               : preserved unchanged.

  Single-line comments are returned unchanged. }
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

    (* ----- Skip whitespace tokens backwards ----- *)
    while i2 >= 0 do
      begin
        Token := Parser.Tokens[i2];
        if (Token^.TokenType = ttUnknow) and (Token^.Text.TrimChar(#32#9#13#10) = '') then
            Dec(i2)
        else
            Break;
      end;

    (* ----- Collect consecutive comment tokens ----- *)
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

    (* ----- Merge in reverse order (we scanned backwards) ----- *)
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

    (* -------------------------------------------------------------------
      Multi-line normalisation: give every line after the first a leading
      ' *' marker, matching the canonical C block-comment layout.
      ------------------------------------------------------------------- *)
    if (Result.Len > 0) and Result.Exists([#10, #13]) then
      begin
        Lines := TPascalStringList.Create;
        try
          UmlSeparatorText(Result, Lines, #10);
          Result := '';
          for k := 0 to Lines.Count - 1 do
            begin
              Temp := Lines[k];
              // Strip trailing CR so we work only with the visible content
              while (Temp.Len > 0) and (Temp.Last = #13) do
                  Temp.DeleteLast;

              if k > 0 then
                  Result.Append(sLineBreak);

              if k = 0 then
                begin
                  // First line: preserve verbatim
                  Result.Append(Temp.Text);
                end
              else
                begin
                  Temp := Temp.TrimChar(#32#9);

                  if (Temp.Len > 0) and (Temp.First = '*') then
                    begin
                      // Already starred: collapse to a single ' * ' prefix
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
                      // Continuation of a line comment ('// ...'): keep as-is
                      Result.Append(Temp.Text);
                    end
                  else if Temp.Len > 0 then
                    begin
                      // Ordinary content: prefix with ' * '
                      Result.Append(' * ');
                      Result.Append(Temp.Text);
                    end;
                  // Empty lines are preserved as-is (visual layout).
                end;
            end;
        finally
            disposeObject(Lines);
        end;
      end;
  end;

(* ============================================================================ *)
(* SECTION 7: Unit name extraction from source header *)
(* ============================================================================ *)
(*
  Extract a unit name from the source header using a best-effort scan of
  the first SCAN_LINES lines. Priority:
    1. A file-like identifier ending in '.h' or '.c' inside the leading
       comment block (e.g. '/* test_header.h ... *\/' -> 'test_header').
       The identifier must begin with a letter so that fragments such as
       '1.0.3.h' do not yield '3'.
    2. The include-guard macro name.
       - '#ifndef' / '#ifdef' always imply a guard.
       - '#define' is accepted only when the macro name looks like a
         guard (ends with _H, _H_, _H__, _INCLUDED, _HPP or _HXX).
    3. Fall back to 'untitled.h' when neither is found.

  The scan is limited to the first SCAN_LINES lines to avoid false positives
  from later code and to keep the search cheap.
*)
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

    (* -- Returns True for characters that may appear in a C identifier. *)
    function IsIdentChar_(c: TP_Char): Boolean;
    begin
      Result := CharIn(c, [cAtoZ, c0to9], '_');
    end;

    (* -- Read the identifier that ends immediately before position pos.
          '.' is allowed as an internal character so that names like
          'v1.2' are captured whole; an identifier that does not start
          with a letter is rejected (guards against '.1.0.3.h' style
          false hits). *)
    function IdentBeforeFileName(pos: Integer): TP_String;
    var
      p, start: Integer;
    begin
      p := pos - 1;
      while (p >= 1) and (IsIdentChar_(txt[p]) or (txt[p] = '.')) do
          Dec(p);
      start := p + 1;
      // Skip leading '.' (from '.1.0.3.h' etc.)
      while (start < pos) and (txt[start] = '.') do
          Inc(start);
      // Require the first character to be a letter
      if (start >= pos) or (not CharIn(txt[start], cAtoZ)) then
        begin
          Result := '';
          Exit;
        end;
      Result := txt.GetString(start, pos);
    end;

    (* -- Read the identifier that starts at position pos. *)
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

    (* -- Returns True when s looks like an include-guard macro name,
          i.e. ends with '_H', '_H_', '_H__', '_INCLUDED', '_HPP' or
          '_HXX'. Comparison is case-insensitive. *)
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

    (* -- Strip the common include-guard suffix patterns:
          '_H', '_H_', '_H__', '_INCLUDED', '_HPP', '_HXX',
          plus any surrounding underscores. Longest suffixes are tried
          first so that, e.g., 'FOO_H_' reduces to 'FOO'. *)
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
      // Remove trailing underscores first so that '_H__' reduces to '_H'
      while (t.Len > 0) and (t.Last = '_') do
          t.DeleteLast;

      // Try each suffix (longest first)
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

      // Remove leading underscores
      while (t.Len > 0) and (t.First = '_') do
          t.DeleteFirst;

      Result := t;
    end;

  begin
    (* Default result: works even when Parser is nil or the input is empty *)
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

    (* ----- Compute scanEnd: position just after SCAN_LINES lines. ----- *)
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

    (* -------------------------------------------------------------------
      Strategy A: '*.h' or '*.c' file name inside the leading region.

      A '.h' or '.c' is accepted only when:
        - followed by a boundary character (end of scan or non-identifier),
        - preceded by an identifier that begins with a letter.
      This rejects cases such as '1.0.3.h' while accepting 'foo.h' and
      'test_header_v2.h'.
      ------------------------------------------------------------------- *)
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

    (* -------------------------------------------------------------------
      Strategy B: include-guard macro name.

      - '#ifndef' / '#ifdef' always imply a guard.
      - '#define' is accepted only when the macro name looks like a guard
        (see IsGuardMacroName). This avoids misidentifying plain
        constants such as '#define MAX_SIZE 1024'.
      ------------------------------------------------------------------- *)
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
                    // #define: require a guard-like name.
                    // #ifndef / #ifdef: accept any identifier.
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

    (* -------------------------------------------------------------------
      Fallback: no header hint found in the leading region.
      ------------------------------------------------------------------- *)
    Result := 'untitled.h';
    DebugLog('Unit name not found in header, using default: "%s"',
      [Result.Text]);
  end;

(* ============================================================================ *)
(* SECTION 8: Function-pointer parameter detection *)
(* ============================================================================ *)

{ Detect whether a parameter list contains a function-pointer parameter.
  Pattern: a '(' immediately followed by '*' inside the outer parameter parens.
  Examples that trigger:
  void (*cb)(int)
  int (*handler)(int, int)
  void (*)(int) }
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

(* ============================================================================ *)
(* SECTION 9: Array suffix extraction *)
(* ============================================================================ *)
(*
  Extract the array suffix '[ ... ]' from the tail of a parameter segment.
  The suffix is returned verbatim (canonicalized with JoinTokens_Canonical)
  or '' when the segment has no array suffix.

  Examples:
  'int buf []'    -> '[]'
  'int buf [N]'   -> '[N]'
  'int buf'       -> ''
  'int ( * )(int)'  -> ''  (function pointers are rejected earlier)
*)
  function ExtractArraySuffix(segB, segE: integer): TP_String;
  var
    m: integer;
  begin
    Result := '';
    if (segB < 0) or (segE < segB) then
        Exit;

    (* ----- Trim trailing whitespace tokens ----- *)
    m := segE;
    while (m >= segB) and IsWhitespaceToken(m) do
        Dec(m);
    if (m < segB) or (not Parser.Tokens[m]^.Text.Same(']')) then
        Exit;

    (* ----- Walk back to the matching '[' ----- *)
    while (m >= segB) and (not Parser.Tokens[m]^.Text.Same('[')) do
        Dec(m);
    if m < segB then
        Exit;

    Result := JoinTokens_Canonical(m, segE);
    DebugLog('  ExtractArraySuffix: "%s"', [Result.Text]);
  end;

(* ============================================================================ *)
(* SECTION 10: Single parameter segment parsing *)
(* ============================================================================ *)

(*
  Parse a single parameter segment (between two top-level commas).
  Outputs:
  ParamMod  — leading 'const' if present (any position in the segment)
  ParamName — parameter identifier (empty for unnamed parameters)
  ParamTyp  — canonical type string (e.g. 'int', 'const char *')

  Special cases handled:
  - (void)         : single void token -> no parameter
  - int            : pure type, no identifier
  - struct X       : unnamed struct parameter
  - int buf[]      : array suffix is stripped (stored separately)

  'restrict' qualifiers are dropped from the type string so that
  'int * restrict' becomes 'int *'. Downstream stages then map the pointer
  to a generic Pointer, allowing the prototype to survive round-trip.
*)
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

    (* ----- Special case: (void) -> no parameters ----- *)
    if (segB = segE) and Parser.Tokens[segB]^.Text.Same('void') then
      begin
        ParamTyp := 'void';
        DebugLog('  ParseParamSegment: (void) -> empty parameter', []);
        Exit;
      end;

    (* ----- Find the last non-reserved identifier (candidate parameter name) ----- *)
    LastIdentIdx := -1;
    m := segE;
    while m >= segB do
      begin
        (* Skip an array suffix [ ... ] *)
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

    (* ----- No identifier found: pure type segment ----- *)
    if LastIdentIdx < 0 then
      begin
        ParamTyp := JoinTypeTokens(segB, segE);
        (* Detect 'const' anywhere in the type range (prefix or infix form). *)
        for m := segB to segE do
          if Parser.Tokens[m]^.Text.Same('const') then
            begin
              ParamMod := 'const';
              Break;
            end;
        DebugLog('  ParseParamSegment: unnamed, typ="%s"', [ParamTyp.Text]);
        Exit;
      end;

    (* ----- Unnamed parameter of struct/enum/union type ----- *)
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

    (* ----- Last identifier is the parameter name ----- *)
    ParamName := Parser.Tokens[LastIdentIdx]^.Text;
    if LastIdentIdx > segB then
        ParamTyp := JoinTypeTokens(segB, LastIdentIdx - 1)
    else
        ParamTyp := '';

    (* Detect 'const' anywhere in the type range (prefix or infix form).
      Both 'const char *' and 'char const *' are treated as const-qualified. *)
    for m := segB to LastIdentIdx - 1 do
      if Parser.Tokens[m]^.Text.Same('const') then
        begin
          ParamMod := 'const';
          Break;
        end;

    DebugLog('  ParseParamSegment: mod="%s", name="%s", typ="%s"',
      [ParamMod.Text, ParamName.Text, ParamTyp.Text]);
  end;

(* ============================================================================ *)
(* SECTION 11: Full parameter list parsing *)
(* ============================================================================ *)

(*
  Parse a parameter list delimited by token indices (exclusive of outer parens).
  Splits on top-level commas (ignoring nested parentheses), then calls
  ParseParamSegment and ExtractArraySuffix for each segment.
  Special case: a single (void) parameter produces zero parameters.
*)
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

    (* ----- Empty parameter list () ----- *)
    if pB > pE then
      begin
        SetLength(Decl.param_arry, 0);
        DebugLog('  ParseParamList: empty parameter list', []);
        Exit;
      end;

    (* ----- Split by top-level commas ----- *)
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

    (* ----- Final segment after the last top-level comma ----- *)
    ParseParamSegment(segBegin, pE, PMod, PName, PTyp);
    ParamRec.reset;
    ParamRec.param_mod := PMod;
    ParamRec.param_name := PName;
    ParamRec.param_typ := PTyp;
    ParamRec.param_array := ExtractArraySuffix(segBegin, pE);
    SetLength(ParamArr, ParamCount + 1);
    ParamArr[ParamCount] := ParamRec;
    Inc(ParamCount);

    (* ----- Special case: single (void) parameter -> zero parameters ----- *)
    if (ParamCount = 1) and (ParamArr[0].param_typ.Same('void')) then
      begin
        SetLength(Decl.param_arry, 0);
        DebugLog('  ParseParamList: (void) -> zero parameters', []);
        Exit;
      end;

    (* ----- Store result ----- *)
    SetLength(Decl.param_arry, ParamCount);
    for j := 0 to ParamCount - 1 do
        Decl.param_arry[j] := ParamArr[j];
    DebugLog('  ParseParamList: %d parameter(s) stored', [ParamCount]);
  end;

(* ============================================================================ *)
(* SECTION 12: Statement classification (prototype vs. variable) *)
(* ============================================================================ *)

(*
  Try to interpret a token range as a function prototype.

  Detection:
  1. Locate the first top-level '(' whose predecessor is a non-reserved identifier.

  That identifier is the candidate function name.
  2. Locate its matching ')'.
  3. Reject if any top-level '=' follows the closing ')' (variable initializer).
  4. Reject if the parameter list contains a function pointer.
  5. Extract return type and detect a leading 'const' qualifier.
  6. Parse the parameter list.

  Outputs Decl (populated on success) and IsFunc (True on success).
*)
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

    (* ----- Step 1: Locate the first top-level '(' ----- *)
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

    (* ----- Step 2: Locate the matching ')' ----- *)
    ParenCloseTok := Parser.IndentSymbolEndProbeR(ParenOpenIdx, '(', ')');
    if ParenCloseTok = nil then
      begin
        DebugLog('ProcessStatement: unmatched "(" at token %d', [ParenOpenIdx]);
        Exit;
      end;

    (* ----- Step 3: Reject variable initialization (contains '=') ----- *)
    for j := ParenCloseTok^.Index + 1 to StmtE do
      begin
        if Parser.Tokens[j]^.Text.Same('=') then
          begin
            DebugLog('ProcessStatement: skipped (contains "=" initializer)');
            Exit;
          end;
      end;

    (* ----- Step 4: Reject function-pointer parameters ----- *)
    if ContainsFuncPtrParam(ParenOpenIdx, ParenCloseTok^.Index) then
      begin
        DebugLog('Skipped function-pointer parameter at statement starting at token %d', [StmtB]);
        Exit;
      end;

    (* ----- Step 5: Extract return type ----- *)
    if NameIdx > StmtB then
        ReturnTypeText := ExtractReturnType(StmtB, NameIdx - 1)
    else
        ReturnTypeText := 'void';

    (* ----- Step 5b: Detect a 'const' qualifier in the return type ----- *)
    Decl.ResultMod := '';
    if NameIdx > StmtB then
      for j := StmtB to NameIdx - 1 do
        if Parser.Tokens[j]^.Text.Same('const') then
          begin
            Decl.ResultMod := 'const';
            DebugLog('ProcessStatement: return type carries const qualifier');
            Break;
          end;

    (* ----- Step 6: Extract canonical parameter list text ----- *)
    ParamsText := JoinTokens_Canonical(ParenOpenIdx, ParenCloseTok^.Index);

    (* ----- Step 7: Populate Decl ----- *)
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

    (* ----- Step 8: Parse the parameter list ----- *)
    ParseParamList(ParenOpenIdx + 1, ParenCloseTok^.Index - 1, Decl);

    DebugLog('ProcessStatement: accepted "%s", ret="%s", params="%s"',
      [Decl.Name.Text, Decl.ResultDecl.Text, Decl.ParamDecl.Text]);

    IsFunc := True;
  end;

(* ============================================================================ *)
(* SECTION 13: '{' block skip decision *)
(* ============================================================================ *)

(*
  Decide whether an opening '{' should cause the whole block to be skipped.

  Skip conditions:
  A. Previous token is ')'          -> function body
  B. Statement contains struct/enum/union/typedef -> type definition

  Otherwise, the '{' is transparent (e.g. extern "C" {) and processing
  continues inside the block.
*)
  function ShouldSkipBlock(OpenIdx, StmtB: integer): boolean;
  var
    k2: integer;
  begin
    Result := False;
    if StmtB < 0 then
        Exit;

    (* ----- Condition A: function body ----- *)
    if (OpenIdx > StmtB) and Parser.Tokens[OpenIdx - 1]^.Text.Same(')') then
      begin
        Result := True;
        Exit;
      end;

    (* ----- Condition B: struct / enum / union / typedef ----- *)
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

(* ============================================================================ *)
(* SECTION 14: Main parsing loop *)
(* ============================================================================ *)
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

  (* ----- Reset state ----- *)
  FuncList.Clear;
  UsesList.Clear;
  ParseSuccess := False;

  (* Parser must be checked before any field is dereferenced. If it is nil
     we simply install the default unit name and bail out early. *)
  if Parser = nil then
    begin
      DoStatus('Parser is nil');
      UnitName := 'untitled.h';
      Exit;
    end;

  (* Unit name is extracted from the source header itself (comment or
     include guard). The extraction function is safe against nil Parser
     and empty input, both of which yield 'untitled.h'. *)
  UnitName := ExtractUnitNameFromHeader;

  i := 0;
  ErrorOccurred := False;
  FuncCount := 0;
  StmtBIdx := -1;

  (* ----- Main token loop ----- *)
  while (i < Parser.TokenCount) and (not ErrorOccurred) do
    begin
      Tok := Parser.Tokens[i];

      (* ----- Skip whitespace ----- *)
      if (Tok^.TokenType = ttUnknow) and (Tok^.Text.TrimChar(#32#9#13#10) = '') then
        begin
          Inc(i);
          Continue;
        end;

      (* ----- Skip comments (preprocessor lines are classified as ttComment in tsC) ----- *)
      if Tok^.TokenType = ttComment then
        begin
          Inc(i);
          Continue;
        end;

      (* ----- Defensive: skip a standalone '#' line if the lexer emits it ----- *)
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

      (* ----- '{' handling ----- *)
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
              (* Consume trailing ';' if present (e.g. `} ;`) *)
              if (i < Parser.TokenCount) and Parser.Tokens[i]^.Text.Same(';') then
                  Inc(i);
              StmtBIdx := -1;
              Continue;
            end;

          (* ----- Transparent '{' (e.g. extern "C" {) ----- *)
          DebugLog('Transparent { at token %d', [i]);
          StmtBIdx := -1;
          Inc(i);
          Continue;
        end;

      (* ----- '}' handling ----- *)
      if Tok^.Text.Same('}') then
        begin
          Inc(i);
          if (i < Parser.TokenCount) and Parser.Tokens[i]^.Text.Same(';') then
              Inc(i);
          StmtBIdx := -1;
          Continue;
        end;

      (* ----- Statement terminator ';' : finalize current statement ----- *)
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

      (* ----- Any other token: start or continue the current statement ----- *)
      if StmtBIdx < 0 then
          StmtBIdx := i;

      Inc(i);
    end;

  (* ----- Finalize parsing ----- *)
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

  (* ----- Structural pointers are not used in C mode ----- *)
  UnitToken := nil;
  InterfaceToken := nil;
  ImplementationToken := nil;
  EndToken := nil;
  InitToken := nil;
  FinalToken := nil;
end;
