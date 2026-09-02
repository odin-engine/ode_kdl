/*
    Ported to Odin from ckdl (https://github.com/tjol/ckdl)
    Original C implementation Copyright (c) Thomas Jollans (MIT License)

    Tokenizer — turns KDL v2 source text into a stream of tokens. Ported
    from ckdl's src/tokenizer.c, string-input only (no kdl_read_func
    streaming variant, see CLAUDE.md) and v2-only (no kdl_character_set,
    no KDLv1 raw-string 'r"..."' prefix).

    Unlike ckdl's pointer-pair (cur/next) walk over a refillable buffer,
    this port advances byte offsets/slices directly over the in-memory
    document string — there's no buffer to refill, so no need to mirror
    ckdl's _tok_get_char refill loop.
*/
package kdl

///////////////////////////////////////////////////////////////////////////////
// Token

    Token_Type :: enum u8 {
        Start_Type,           // '('
        End_Type,             // ')'
        Word,                 // identifier, number, boolean, or null
        String,               // regular string
        Multiline_String,     // multi-line string
        Raw_String,           // raw string: #"..."#
        Raw_Multiline_String, // raw multi-line string
        Single_Line_Comment,  // // ...
        Slashdash,            // /-
        Multi_Line_Comment,   // /* ... */
        Equals,               // '='
        Start_Children,       // '{'
        End_Children,         // '}'
        Newline,              // LF, CR, or CRLF
        Semicolon,            // ';'
        Line_Continuation,    // '\\'
        Whitespace,           // any regular whitespace
    }

    Token :: struct {
        type:  Token_Type,
        value: string,
    }

    Tokenizer_Status :: enum u8 {
        OK,
        EOF,
        Error,
    }

///////////////////////////////////////////////////////////////////////////////
// Tokenizer

    Tokenizer :: struct {
        remaining: string,
    }

    tokenizer__init :: proc(self: ^Tokenizer, document: string) {
        self.remaining = document

        // skip an initial BOM, if present
        probe := document
        c, status := pop_rune(&probe)
        if status == .OK && c == 0xFEFF {
            self.remaining = probe
        }
    }

    tokenizer__pop_token :: proc(self: ^Tokenizer) -> (token: Token, status: Tokenizer_Status) {
        start := self.remaining
        cur := start
        c, ustatus := pop_rune(&cur)
        switch ustatus {
        case .OK:
        case .EOF: return {}, .EOF
        case .Decode_Error: return {}, .Error
        }

        switch {
        case is_illegal_char(c):
            return {}, .Error

        case is_whitespace(c):
            for {
                save := cur
                c2, s2 := pop_rune(&save)
                if s2 != .OK || !is_whitespace(c2) do break
                cur = save
            }
            self.remaining = cur
            return Token{type = .Whitespace, value = start[:len(start) - len(cur)]}, .OK

        case is_newline(c):
            if c == '\r' {
                save := cur
                c2, s2 := pop_rune(&save)
                if s2 == .OK && c2 == '\n' do cur = save
            }
            self.remaining = cur
            return Token{type = .Newline, value = start[:len(start) - len(cur)]}, .OK

        case c == ';':
            self.remaining = cur
            return Token{type = .Semicolon, value = start[:len(start) - len(cur)]}, .OK

        case c == '\\':
            self.remaining = cur
            return Token{type = .Line_Continuation, value = start[:len(start) - len(cur)]}, .OK

        case c == '(':
            self.remaining = cur
            return Token{type = .Start_Type, value = start[:len(start) - len(cur)]}, .OK

        case c == ')':
            self.remaining = cur
            return Token{type = .End_Type, value = start[:len(start) - len(cur)]}, .OK

        case c == '{':
            self.remaining = cur
            return Token{type = .Start_Children, value = start[:len(start) - len(cur)]}, .OK

        case c == '}':
            self.remaining = cur
            return Token{type = .End_Children, value = start[:len(start) - len(cur)]}, .OK

        case c == '=':
            self.remaining = cur
            return Token{type = .Equals, value = start[:len(start) - len(cur)]}, .OK

        case c == '/':
            return tokenizer__pop_comment(self)

        case c == '"':
            return tokenizer__pop_string(self)

        case is_word_char(c):
            if c == '#' {
                // this *could* be a raw string
                if tok, st := tokenizer__pop_string(self); st == .OK do return tok, st
                // else: parse this as an identifier instead (which may also fail)
            }
            return tokenizer__pop_word(self)

        case:
            return {}, .Error
        }
    }

///////////////////////////////////////////////////////////////////////////////
// Private

    @(private)
    tokenizer__pop_word :: proc(self: ^Tokenizer) -> (token: Token, status: Tokenizer_Status) {
        start := self.remaining
        cur := start
        for {
            save := cur
            c, s := pop_rune(&save)
            if s == .EOF do break
            if s == .Decode_Error do return {}, .Error
            if is_end_of_word(c) do break
            if !is_word_char(c) do return {}, .Error
            cur = save
        }
        self.remaining = cur
        return Token{type = .Word, value = start[:len(start) - len(cur)]}, .OK
    }

    @(private)
    tokenizer__pop_comment :: proc(self: ^Tokenizer) -> (token: Token, status: Tokenizer_Status) {
        start := self.remaining
        cur := start
        c1, s1 := pop_rune(&cur)
        if s1 != .OK do return {}, .Error
        c2, s2 := pop_rune(&cur)
        if s2 != .OK do return {}, .Error
        assert(c1 == '/')

        switch c2 {
        case '-':
            self.remaining = cur
            return Token{type = .Slashdash, value = start[:2]}, .OK

        case '/':
            for {
                save := cur
                c, s := pop_rune(&save)
                if s == .EOF do break
                if s == .Decode_Error do return {}, .Error
                if is_illegal_char(c) do return {}, .Error
                if is_newline(c) do break
                cur = save
            }
            self.remaining = cur
            return Token{type = .Single_Line_Comment, value = start[:len(start) - len(cur)]}, .OK

        case '*':
            depth := 1
            prev_char: rune = 0
            for depth > 0 {
                c, s := pop_rune(&cur)
                if s != .OK do return {}, .Error // EOF or error inside a comment is always an error
                if is_illegal_char(c) do return {}, .Error
                if c == '*' && prev_char == '/' {
                    depth += 1
                    c = 0 // "/*/" doesn't count as self-closing
                } else if c == '/' && prev_char == '*' {
                    depth -= 1
                    c = 0 // "*/*" doesn't count as reopening
                }
                prev_char = c
            }
            self.remaining = cur
            return Token{type = .Multi_Line_Comment, value = start[:len(start) - len(cur)]}, .OK

        case:
            return {}, .Error
        }
    }

    @(private)
    tokenizer__pop_string :: proc(self: ^Tokenizer) -> (token: Token, status: Tokenizer_Status) {
        document := self.remaining
        cur := 0
        is_raw := false

        c, _, s := peek_rune(document, cur)
        if s != .OK do return {}, .Error
        switch c {
        case '#':
            is_raw = true
        // cur unchanged: the hash-counting loop below re-reads this same '#'
        case '"':
        // cur unchanged: the quote-counting loop below re-reads this same quote
        case:
            return {}, .Error
        }

        // count the hashes (raw strings only)
        hashes := 0
        for is_raw {
            c2, next2, s2 := peek_rune(document, cur)
            if s2 != .OK do return {}, .Error // eof or error in a string is always an error
            if c2 == '#' {
                hashes += 1
                cur = next2
            } else if c2 == '"' {
                break
            } else {
                return {}, .Error
            }
        }

        // count the opening quotes (1 = regular string, 3 = multi-line string)
        initial_quote_count := 0
        for initial_quote_count < 3 {
            c3, next3, s3 := peek_rune(document, cur)
            if s3 == .EOF {
                if !is_raw && initial_quote_count == 2 {
                    // "" followed immediately by EOF: an empty regular string
                    self.remaining = document[cur:]
                    return Token{type = .String, value = ""}, .OK
                }
                return {}, .Error
            }
            if s3 != .OK do return {}, .Error
            if c3 == '"' {
                initial_quote_count += 1
                cur = next3
            } else {
                break
            }
        }

        if initial_quote_count == 2 {
            // overshot: this is an empty single-quoted string; back off by one quote
            cur -= 1
            initial_quote_count = 1
        }

        string_start := cur

        // scan the string body
        hashes_found := 0
        quotes_found := 0
        end_quote_offset := 0
        prev_char: rune = 0
        end_position := 0

        find_end: for {
            c4, next4, s4 := peek_rune(document, cur)
            if s4 != .OK do return {}, .Error // eof or error in a string is always an error

            if is_illegal_char(c4) {
                return {}, .Error
            } else if !is_raw && c4 == '\\' && prev_char == '\\' {
                c4 = 0 // double backslash is no backslash
                quotes_found, hashes_found = 0, 0
                end_quote_offset = 0
            } else if c4 == '"' && (is_raw || prev_char != '\\') {
                if quotes_found == 0 do end_quote_offset = cur
                if quotes_found < initial_quote_count {
                    quotes_found += 1
                } else {
                    // possibly extra quotes at the end of a raw string
                    end_quote_offset += 1
                }
                hashes_found = 0
            } else if c4 == '#' && (hashes_found != 0 || quotes_found == initial_quote_count) {
                hashes_found += 1
                quotes_found = 0
            } else {
                quotes_found, hashes_found = 0, 0
                end_quote_offset = 0
            }

            if end_quote_offset != 0 &&
               ((hashes == 0 && quotes_found == initial_quote_count) ||
                (hashes != 0 && hashes_found == hashes)) {
                end_position = next4
                break find_end
            }

            prev_char = c4
            cur = next4
        }

        value := document[string_start:end_quote_offset]
        self.remaining = document[end_position:]

        tok_type: Token_Type
        switch {
        case initial_quote_count == 3: tok_type = is_raw ? .Raw_Multiline_String : .Multiline_String
        case is_raw:                   tok_type = .Raw_String
        case:                          tok_type = .String
        }
        return Token{type = tok_type, value = value}, .OK
    }
