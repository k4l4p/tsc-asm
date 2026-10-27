.include "defs.inc"

.section .rodata
kw_let:      .ascii "let"
kw_const:    .ascii "const"
kw_var:      .ascii "var"
kw_function: .ascii "function"
kw_return:   .ascii "return"
kw_if:       .ascii "if"
kw_else:     .ascii "else"
kw_true:     .ascii "true"
kw_false:    .ascii "false"
.equ KW_COUNT, 9
.balign 8
kw_table:
    .quad kw_let;      .long 3; .long T_LET
    .quad kw_const;    .long 5; .long T_CONST
    .quad kw_var;      .long 3; .long T_VAR
    .quad kw_function; .long 8; .long T_FUNCTION
    .quad kw_return;   .long 6; .long T_RETURN
    .quad kw_if;       .long 2; .long T_IF
    .quad kw_else;     .long 4; .long T_ELSE
    .quad kw_true;     .long 4; .long T_TRUE
    .quad kw_false;    .long 5; .long T_FALSE

.section .text
.macro LADV
    inc r12
    inc r14
.endm

.macro LNEWLINE
    inc r12
    inc r13
    mov r14d, 1
.endm

# is_ident_start(ch=edi) -> eax
is_ident_start:
    mov eax, edi
    cmp al, 'a'
    jb .is_ident_start_upper
    cmp al, 'z'
    jbe .is_ident_start_yes
.is_ident_start_upper:
    cmp al, 'A'
    jb .is_ident_start_other
    cmp al, 'Z'
    jbe .is_ident_start_yes
.is_ident_start_other:
    cmp al, '_'
    je .is_ident_start_yes
    cmp al, '$'
    je .is_ident_start_yes
    xor eax, eax
    ret
.is_ident_start_yes:
    mov eax, 1
    ret

# is_digit(ch=edi) -> eax
is_digit:
    mov eax, edi
    cmp al, '0'
    jb .is_digit_no
    cmp al, '9'
    jbe .is_digit_yes
.is_digit_no:
    xor eax, eax
    ret
.is_digit_yes:
    mov eax, 1
    ret

# is_ident_char(ch=edi) -> eax
is_ident_char:
    call is_ident_start
    test eax, eax
    jne .is_ident_char_yes
    call is_digit
    ret
.is_ident_char_yes:
    mov eax, 1
    ret

# classify_ident(ptr=rdi, len=esi) -> eax kind
classify_ident:
    push rbx
    lea rbx, [rip+kw_table]
    xor r8d, r8d
.classify_ident_loop:
    cmp r8d, KW_COUNT
    jae .classify_ident_ident
    mov eax, r8d
    shl eax, 4
    add rax, rbx
    cmp esi, dword ptr [rax+8]
    jne .classify_ident_next
    mov r9, qword ptr [rax]
    xor ecx, ecx
.classify_ident_cmp:
    cmp ecx, esi
    jae .classify_ident_match
    mov r10b, byte ptr [rdi+rcx]
    cmp r10b, byte ptr [r9+rcx]
    jne .classify_ident_next
    inc ecx
    jmp .classify_ident_cmp
.classify_ident_match:
    mov eax, dword ptr [rax+12]
    pop rbx
    ret
.classify_ident_next:
    inc r8d
    jmp .classify_ident_loop
.classify_ident_ident:
    mov eax, T_IDENT
    pop rbx
    ret

# push_token(kind=edi, off=esi, len=edx, line=ecx, col=r8d)
.globl push_token
push_token:
    mov eax, dword ptr [rip+tok_count]
    cmp eax, TOK_MAX
    jae .push_token_overflow
    imul rax, rax, TK_SIZE
    lea r9, [rip+tok_buf]
    add r9, rax
    mov dword ptr [r9+TK_KIND], edi
    mov dword ptr [r9+TK_OFF], esi
    mov dword ptr [r9+TK_LEN], edx
    mov dword ptr [r9+TK_LINE], ecx
    mov dword ptr [r9+TK_COL], r8d
    mov dword ptr [r9+TK_VAL], 0
    inc dword ptr [rip+tok_count]
    ret
.push_token_overflow:
    mov edi, 1
    jmp exit_now

# lex_all() -> fills tok_buf, sets tok_count
.globl lex_all
lex_all:
    push rbx
    push r12
    push r13
    push r14
    push r15
    lea rbx, [rip+src_buf]
    xor r12d, r12d
    mov r13d, 1
    mov r14d, 1
    mov dword ptr [rip+tok_count], 0
    mov dword ptr [rip+tok_pos], 0

.lex_all_loop:
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_eof
    movzx eax, byte ptr [rbx+r12]

    cmp al, ' '
    je .lex_all_space
    cmp al, 9
    je .lex_all_space
    cmp al, 13
    je .lex_all_space
    cmp al, 10
    je .lex_all_newline
    cmp al, '/'
    je .lex_all_slash
    mov edi, eax
    call is_ident_start
    test eax, eax
    jne .lex_all_ident
    movzx edi, byte ptr [rbx+r12]
    call is_digit
    test eax, eax
    jne .lex_all_number
    movzx eax, byte ptr [rbx+r12]
    cmp al, '"'
    je .lex_all_string
    cmp al, 39
    je .lex_all_string
    jmp .lex_all_punct

.lex_all_space:
    LADV
    jmp .lex_all_loop
.lex_all_newline:
    LNEWLINE
    jmp .lex_all_loop

# --- comments ---------------------------------------------------------------
.lex_all_slash:
    lea rax, [r12+1]
    mov edx, dword ptr [rip+src_len]
    cmp rax, rdx
    jae .lex_all_slash_token
    movzx edx, byte ptr [rbx+r12+1]
    cmp dl, '/'
    je .lex_all_line_comment
    cmp dl, '*'
    je .lex_all_block_comment
    jmp .lex_all_slash_token

.lex_all_line_comment:
    add r12, 2
    add r14, 2
.lex_all_lc_loop:
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_loop
    cmp byte ptr [rbx+r12], 10
    je .lex_all_loop
    LADV
    jmp .lex_all_lc_loop

.lex_all_block_comment:
    mov r15d, r13d          # start line for unterminated error
    mov r8d, r14d           # start col (saved on stack below)
    push r8
    add r12, 2
    add r14, 2
.lex_all_bc_loop:
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_bc_unterminated
    movzx eax, byte ptr [rbx+r12]
    cmp al, '*'
    jne .lex_all_bc_not_close
    lea rax, [r12+1]
    mov edx, dword ptr [rip+src_len]
    cmp rax, rdx
    jae .lex_all_bc_not_close
    cmp byte ptr [rbx+r12+1], '/'
    jne .lex_all_bc_not_close
    add r12, 2
    add r14, 2
    pop r8
    jmp .lex_all_loop
.lex_all_bc_not_close:
    movzx eax, byte ptr [rbx+r12]
    cmp al, 10
    je .lex_all_bc_newline
    LADV
    jmp .lex_all_bc_loop
.lex_all_bc_newline:
    LNEWLINE
    jmp .lex_all_bc_loop
.lex_all_bc_unterminated:
    pop r8
    mov edi, r13d
    mov esi, r14d
    mov edx, 1010
    lea rcx, [rip+s_unterminated_comment]
    mov r8d, OFFSET s_unterminated_comment_len
    jmp fatal_diag

# --- identifiers ------------------------------------------------------------
.lex_all_ident:
    mov r8d, r12d           # start offset
    mov r9d, r14d           # start col
.lex_all_id_loop:
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_id_done
    movzx edi, byte ptr [rbx+r12]
    call is_ident_char
    test eax, eax
    je .lex_all_id_done
    LADV
    jmp .lex_all_id_loop
.lex_all_id_done:
    mov edx, r12d
    sub edx, r8d            # len
    lea rdi, [rbx+r8]
    mov esi, edx
    push r8                 # start offset survives classify_ident
    push r9                 # start col
    call classify_ident
    mov edi, eax
    pop r9
    pop r8
    mov edx, r12d
    sub edx, r8d
    mov esi, r8d
    mov ecx, r13d
    mov r8d, r9d
    call push_token
    jmp .lex_all_loop

# --- numbers ----------------------------------------------------------------
.lex_all_number:
    mov r8d, r12d
    mov r9d, r14d
.lex_all_num_loop:
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_num_done
    movzx edi, byte ptr [rbx+r12]
    call is_digit
    test eax, eax
    je .lex_all_num_done
    LADV
    jmp .lex_all_num_loop
.lex_all_num_done:
    mov edx, r12d
    sub edx, r8d
    mov edi, T_NUM
    mov esi, r8d
    mov ecx, r13d
    mov r8d, r9d
    call push_token
    jmp .lex_all_loop

# --- strings ----------------------------------------------------------------
.lex_all_string:
    mov r8d, r12d           # start offset
    mov r9d, r14d           # start col
    mov r15d, r13d          # start line
    movzx r11d, byte ptr [rbx+r12]   # quote char
    LADV
.lex_all_str_loop:
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_str_unterminated
    movzx eax, byte ptr [rbx+r12]
    cmp al, r11b
    je .lex_all_str_close
    cmp al, 10
    je .lex_all_str_unterminated
    cmp al, '\\'
    jne .lex_all_str_plain
    LADV
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_str_unterminated
    cmp byte ptr [rbx+r12], 10
    je .lex_all_str_esc_newline
    LADV
    jmp .lex_all_str_loop
.lex_all_str_esc_newline:
    LNEWLINE
    jmp .lex_all_str_loop
.lex_all_str_plain:
    LADV
    jmp .lex_all_str_loop
.lex_all_str_close:
    LADV
    mov edx, r12d
    sub edx, r8d
    mov edi, T_STR
    mov esi, r8d
    mov ecx, r15d
    mov r8d, r9d
    call push_token
    jmp .lex_all_loop
.lex_all_str_unterminated:
    mov edi, r13d
    mov esi, r14d
    mov edx, 1002
    lea rcx, [rip+s_unterminated_str]
    mov r8d, OFFSET s_unterminated_str_len
    jmp fatal_diag

# --- punctuation and operators ----------------------------------------------
.lex_all_punct:
    movzx eax, byte ptr [rbx+r12]
    cmp al, '='
    je .lex_all_op_eq
    cmp al, '!'
    je .lex_all_op_bang
    cmp al, '<'
    je .lex_all_op_lt
    cmp al, '>'
    je .lex_all_op_gt
    cmp al, '&'
    je .lex_all_op_and
    cmp al, '|'
    je .lex_all_op_or
    cmp al, ':'
    je .lex_all_p_colon
    cmp al, ';'
    je .lex_all_p_semi
    cmp al, ','
    je .lex_all_p_comma
    cmp al, '('
    je .lex_all_p_lparen
    cmp al, ')'
    je .lex_all_p_rparen
    cmp al, '{'
    je .lex_all_p_lbrace
    cmp al, '}'
    je .lex_all_p_rbrace
    cmp al, '+'
    je .lex_all_p_plus
    cmp al, '-'
    je .lex_all_p_minus
    cmp al, '*'
    je .lex_all_p_star
    cmp al, '%'
    je .lex_all_p_percent
    cmp al, '.'
    je .lex_all_p_dot
    jmp .lex_all_invalid

.lex_all_slash_token:
    mov r8d, r12d
    mov r9d, r14d
    LADV
    mov edi, T_SLASH
    mov esi, r8d
    mov edx, 1
    mov ecx, r13d
    mov r8d, r9d
    call push_token
    jmp .lex_all_loop

.lex_all_op_eq:
    mov r8d, r12d
    mov r9d, r14d
    LADV
    mov edx, 1
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_eq1
    cmp byte ptr [rbx+r12], '='
    jne .lex_all_eq1
    LADV
    mov edx, 2
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_eq2
    cmp byte ptr [rbx+r12], '='
    jne .lex_all_eq2
    LADV
    mov edx, 3
    mov edi, T_EQ3
    jmp .lex_all_op_emit
.lex_all_eq2:
    mov edi, T_EQ2
    jmp .lex_all_op_emit
.lex_all_eq1:
    mov edi, T_ASSIGN
    jmp .lex_all_op_emit

.lex_all_op_bang:
    mov r8d, r12d
    mov r9d, r14d
    LADV
    mov edx, 1
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_bang1
    cmp byte ptr [rbx+r12], '='
    jne .lex_all_bang1
    LADV
    mov edx, 2
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_bang2
    cmp byte ptr [rbx+r12], '='
    jne .lex_all_bang2
    LADV
    mov edx, 3
    mov edi, T_NEQ3
    jmp .lex_all_op_emit
.lex_all_bang2:
    mov edi, T_NEQ2
    jmp .lex_all_op_emit
.lex_all_bang1:
    mov edi, T_BANG
    jmp .lex_all_op_emit

.lex_all_op_lt:
    mov r8d, r12d
    mov r9d, r14d
    LADV
    mov edx, 1
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_lt1
    cmp byte ptr [rbx+r12], '='
    jne .lex_all_lt1
    LADV
    mov edx, 2
    mov edi, T_LE
    jmp .lex_all_op_emit
.lex_all_lt1:
    mov edi, T_LT
    jmp .lex_all_op_emit

.lex_all_op_gt:
    mov r8d, r12d
    mov r9d, r14d
    LADV
    mov edx, 1
    mov eax, dword ptr [rip+src_len]
    cmp r12, rax
    jae .lex_all_gt1
    cmp byte ptr [rbx+r12], '='
    jne .lex_all_gt1
    LADV
    mov edx, 2
    mov edi, T_GE
    jmp .lex_all_op_emit
.lex_all_gt1:
    mov edi, T_GT
    jmp .lex_all_op_emit

.lex_all_op_and:
    mov r8d, r12d
    mov r9d, r14d
    lea rax, [r12+1]
    mov edx, dword ptr [rip+src_len]
    cmp rax, rdx
    jae .lex_all_invalid
    cmp byte ptr [rbx+r12+1], '&'
    jne .lex_all_invalid
    add r12, 2
    add r14, 2
    mov edi, T_ANDAND
    mov edx, 2
    jmp .lex_all_op_emit

.lex_all_op_or:
    mov r8d, r12d
    mov r9d, r14d
    lea rax, [r12+1]
    mov edx, dword ptr [rip+src_len]
    cmp rax, rdx
    jae .lex_all_invalid
    cmp byte ptr [rbx+r12+1], '|'
    jne .lex_all_invalid
    add r12, 2
    add r14, 2
    mov edi, T_OROR
    mov edx, 2
    jmp .lex_all_op_emit

.lex_all_op_emit:
    mov esi, r8d
    mov ecx, r13d
    mov r8d, r9d
    call push_token
    jmp .lex_all_loop

.lex_all_p_colon:
    mov edi, T_COLON
    jmp .lex_all_p_one
.lex_all_p_semi:
    mov edi, T_SEMI
    jmp .lex_all_p_one
.lex_all_p_comma:
    mov edi, T_COMMA
    jmp .lex_all_p_one
.lex_all_p_lparen:
    mov edi, T_LPAREN
    jmp .lex_all_p_one
.lex_all_p_rparen:
    mov edi, T_RPAREN
    jmp .lex_all_p_one
.lex_all_p_lbrace:
    mov edi, T_LBRACE
    jmp .lex_all_p_one
.lex_all_p_rbrace:
    mov edi, T_RBRACE
    jmp .lex_all_p_one
.lex_all_p_plus:
    mov edi, T_PLUS
    jmp .lex_all_p_one
.lex_all_p_minus:
    mov edi, T_MINUS
    jmp .lex_all_p_one
.lex_all_p_star:
    mov edi, T_STAR
    jmp .lex_all_p_one
.lex_all_p_percent:
    mov edi, T_PERCENT
    jmp .lex_all_p_one
.lex_all_p_dot:
    mov edi, T_DOT
.lex_all_p_one:
    mov esi, r12d
    mov edx, 1
    mov ecx, r13d
    mov r8d, r14d
    LADV
    call push_token
    jmp .lex_all_loop

.lex_all_invalid:
    mov edi, r13d
    mov esi, r14d
    mov edx, 1127
    lea rcx, [rip+s_invalid_char]
    mov r8d, OFFSET s_invalid_char_len
    jmp fatal_diag

.lex_all_eof:
    mov edi, T_EOF
    mov esi, r12d
    xor edx, edx
    mov ecx, r13d
    mov r8d, r14d
    call push_token
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
