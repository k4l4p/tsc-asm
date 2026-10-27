.include "defs.inc"

.section .rodata
type_table:
    .quad s_type_number;  .long s_type_number_len;  .long TY_NUM
    .quad s_type_string;  .long s_type_string_len;  .long TY_STR
    .quad s_type_boolean; .long s_type_boolean_len; .long TY_BOOL
    .quad s_type_void;    .long s_type_void_len;    .long TY_VOID
    .quad s_type_any;     .long s_type_any_len;     .long TY_ANY

.section .text

# --- token helpers ----------------------------------------------------------
.globl cur_tok
cur_tok:
    mov eax, dword ptr [rip+tok_pos]
    imul rax, rax, TK_SIZE
    lea rdx, [rip+tok_buf]
    add rax, rdx
    ret

.globl tok_ptr
tok_ptr:
    mov eax, edi
    imul rax, rax, TK_SIZE
    lea rdx, [rip+tok_buf]
    add rax, rdx
    ret

.globl advance
advance:
    inc dword ptr [rip+tok_pos]
    ret

.globl prev_tok_end
prev_tok_end:
    mov ecx, dword ptr [rip+tok_pos]
    dec ecx
    mov eax, ecx
    imul rax, rax, TK_SIZE
    lea rdx, [rip+tok_buf]
    add rax, rdx
    mov ecx, dword ptr [rax+TK_OFF]
    mov edx, dword ptr [rax+TK_LEN]
    lea eax, [rcx+rdx]
    ret

# tok_text_eq(tok=rdi, text=rsi, len=edx) -> eax
.globl tok_text_eq
tok_text_eq:
    mov eax, dword ptr [rdi+TK_LEN]
    cmp eax, edx
    jne .tok_text_eq_no
    mov eax, dword ptr [rdi+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    jmp bytes_eq
.tok_text_eq_no:
    xor eax, eax
    ret

# type_from_tok(tok=rdi) -> eax type (silent)
.globl type_from_tok
type_from_tok:
    cmp dword ptr [rdi+TK_KIND], T_IDENT
    jne .type_from_tok_err
    mov eax, dword ptr [rdi+TK_OFF]
    mov ecx, dword ptr [rdi+TK_LEN]
    lea rdi, [rip+src_buf]
    add rdi, rax
    lea r8, [rip+type_table]
    xor r9d, r9d
.type_from_tok_loop:
    cmp r9d, 5
    jae .type_from_tok_err
    mov eax, r9d
    shl eax, 4
    add rax, r8
    cmp ecx, dword ptr [rax+8]
    jne .type_from_tok_next
    mov r10, qword ptr [rax]
    xor r11d, r11d
.type_from_tok_cmp:
    cmp r11d, ecx
    jae .type_from_tok_match
    mov dl, byte ptr [rdi+r11]
    cmp dl, byte ptr [r10+r11]
    jne .type_from_tok_next
    inc r11d
    jmp .type_from_tok_cmp
.type_from_tok_match:
    mov eax, dword ptr [rax+12]
    ret
.type_from_tok_next:
    inc r9d
    jmp .type_from_tok_loop
.type_from_tok_err:
    mov eax, TY_ERR
    ret

# parse_type() -> eax type, consumes the type token
parse_type:
    push rbx
    call cur_tok
    mov rbx, rax
    cmp dword ptr [rbx+TK_KIND], T_IDENT
    je .parse_type_ident
    mov edi, dword ptr [rbx+TK_LINE]
    mov esi, dword ptr [rbx+TK_COL]
    mov edx, 1110
    lea rcx, [rip+s_type_expected]
    mov r8d, OFFSET s_type_expected_len
    call diag
    mov eax, TY_ERR
    pop rbx
    ret
.parse_type_ident:
    mov rdi, rbx
    call type_from_tok
    cmp eax, TY_ERR
    jne .parse_type_ok
    mov rdi, rbx
    call err_name
    call advance
    mov eax, TY_ERR
    pop rbx
    ret
.parse_type_ok:
    call advance
    pop rbx
    ret

# expect_semi(): consume ';', accept ASI before '}', EOF, or a newline
expect_semi:
    push rbx
    call cur_tok
    mov rbx, rax
    cmp dword ptr [rbx+TK_KIND], T_SEMI
    je .expect_semi_consume
    cmp dword ptr [rbx+TK_KIND], T_RBRACE
    je .expect_semi_ok
    cmp dword ptr [rbx+TK_KIND], T_EOF
    je .expect_semi_ok
    mov eax, dword ptr [rip+tok_pos]
    test eax, eax
    je .expect_semi_err
    dec eax
    imul rax, rax, TK_SIZE
    lea rdx, [rip+tok_buf]
    add rax, rdx
    mov ecx, dword ptr [rax+TK_LINE]
    cmp dword ptr [rbx+TK_LINE], ecx
    ja .expect_semi_ok
.expect_semi_err:
    mov edi, dword ptr [rbx+TK_LINE]
    mov esi, dword ptr [rbx+TK_COL]
    call err_semi_expected
    pop rbx
    ret
.expect_semi_consume:
    call advance
.expect_semi_ok:
    pop rbx
    ret

# skip_stmt(): advance to and consume ';', or stop at '}' / EOF
skip_stmt:
    push rbx
.skip_stmt_loop:
    call cur_tok
    mov rbx, rax
    mov eax, dword ptr [rbx+TK_KIND]
    cmp eax, T_EOF
    je .skip_stmt_done
    cmp eax, T_RBRACE
    je .skip_stmt_done
    cmp eax, T_SEMI
    je .skip_stmt_consume
    call advance
    jmp .skip_stmt_loop
.skip_stmt_consume:
    call advance
.skip_stmt_done:
    pop rbx
    ret

# --- expression type rules --------------------------------------------------
# prec_of(kind=edi) -> eax
prec_of:
    cmp edi, T_OROR
    je .prec_of_p1
    cmp edi, T_ANDAND
    je .prec_of_p2
    cmp edi, T_EQ3
    je .prec_of_p3
    cmp edi, T_NEQ3
    je .prec_of_p3
    cmp edi, T_EQ2
    je .prec_of_p3
    cmp edi, T_NEQ2
    je .prec_of_p3
    cmp edi, T_LT
    je .prec_of_p4
    cmp edi, T_GT
    je .prec_of_p4
    cmp edi, T_LE
    je .prec_of_p4
    cmp edi, T_GE
    je .prec_of_p4
    cmp edi, T_PLUS
    je .prec_of_p5
    cmp edi, T_MINUS
    je .prec_of_p5
    cmp edi, T_STAR
    je .prec_of_p6
    cmp edi, T_SLASH
    je .prec_of_p6
    cmp edi, T_PERCENT
    je .prec_of_p6
    xor eax, eax
    ret
.prec_of_p1:
    mov eax, 1
    ret
.prec_of_p2:
    mov eax, 2
    ret
.prec_of_p3:
    mov eax, 3
    ret
.prec_of_p4:
    mov eax, 4
    ret
.prec_of_p5:
    mov eax, 5
    ret
.prec_of_p6:
    mov eax, 6
    ret

# parse_expr() -> eax type
.globl parse_expr
parse_expr:
    mov edi, 1
    jmp parse_bin

# parse_bin(level=edi) -> eax type
parse_bin:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov dword ptr [rbp-4], edi
    mov eax, dword ptr [rip+tok_pos]
    mov dword ptr [rbp-8], eax
    cmp edi, 7
    jne .parse_bin_recurse
    call parse_unary
    jmp .parse_bin_got
.parse_bin_recurse:
    mov edi, dword ptr [rbp-4]
    inc edi
    call parse_bin
.parse_bin_got:
    mov dword ptr [rbp-12], eax
.parse_bin_loop:
    call cur_tok
    mov edx, dword ptr [rax+TK_KIND]
    mov dword ptr [rbp-16], edx
    mov edi, edx
    call prec_of
    cmp eax, dword ptr [rbp-4]
    jne .parse_bin_done
    call cur_tok
    mov qword ptr [rbp-32], rax
    mov eax, dword ptr [rip+tok_pos]
    mov dword ptr [rbp-20], eax
    call advance
    mov eax, dword ptr [rip+tok_pos]
    mov dword ptr [rbp-24], eax
    mov edi, dword ptr [rbp-4]
    inc edi
    call parse_bin
    mov dword ptr [rbp-36], eax
    mov rdi, qword ptr [rbp-32]
    mov esi, dword ptr [rbp-12]
    mov edx, dword ptr [rbp-36]
    mov ecx, dword ptr [rbp-8]
    mov r8d, dword ptr [rbp-24]
    call apply_binop
    mov dword ptr [rbp-12], eax
    jmp .parse_bin_loop
.parse_bin_done:
    mov eax, dword ptr [rbp-12]
    leave
    ret

# apply_binop(op_tok=rdi, left=esi, right=edx, left_start=ecx, right_start=r8d)
apply_binop:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    mov eax, dword ptr [rbx+TK_KIND]
    mov dword ptr [rsp], eax

    cmp r12d, TY_ERR
    je .apply_binop_err
    cmp r13d, TY_ERR
    je .apply_binop_err
    cmp eax, T_PLUS
    je .apply_binop_plus
    cmp eax, T_MINUS
    je .apply_binop_arith
    cmp eax, T_STAR
    je .apply_binop_arith
    cmp eax, T_SLASH
    je .apply_binop_arith
    cmp eax, T_PERCENT
    je .apply_binop_arith
    cmp eax, T_LT
    je .apply_binop_rel
    cmp eax, T_GT
    je .apply_binop_rel
    cmp eax, T_LE
    je .apply_binop_rel
    cmp eax, T_GE
    je .apply_binop_rel
    cmp eax, T_EQ3
    je .apply_binop_eq
    cmp eax, T_NEQ3
    je .apply_binop_eq
    cmp eax, T_EQ2
    je .apply_binop_eq
    cmp eax, T_NEQ2
    je .apply_binop_eq
    cmp eax, T_ANDAND
    je .apply_binop_logic
    cmp eax, T_OROR
    je .apply_binop_logic
    jmp .apply_binop_err                     # unreachable

.apply_binop_plus:
    cmp r12d, TY_ANY
    je .apply_binop_any
    cmp r13d, TY_ANY
    je .apply_binop_any
    cmp r12d, TY_STR
    je .apply_binop_str
    cmp r13d, TY_STR
    je .apply_binop_str
    cmp r12d, TY_NUM
    jne .apply_binop_op_err
    cmp r13d, TY_NUM
    jne .apply_binop_op_err
    mov eax, TY_NUM
    jmp .apply_binop_ret
.apply_binop_str:
    mov eax, TY_STR
    jmp .apply_binop_ret
.apply_binop_any:
    mov eax, TY_ANY
    jmp .apply_binop_ret

.apply_binop_arith:
    cmp r12d, TY_ANY
    je .apply_binop_num
    cmp r13d, TY_ANY
    je .apply_binop_num
    cmp r12d, TY_NUM
    jne .apply_binop_bad_left
    cmp r13d, TY_NUM
    jne .apply_binop_bad_right
.apply_binop_num:
    mov eax, TY_NUM
    jmp .apply_binop_ret
.apply_binop_bad_left:
    mov edi, r14d
    call tok_ptr
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_arith_left
    jmp .apply_binop_err
.apply_binop_bad_right:
    mov edi, r15d
    call tok_ptr
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_arith_right
    jmp .apply_binop_err

.apply_binop_rel:
    cmp r12d, TY_ANY
    je .apply_binop_bool
    cmp r13d, TY_ANY
    je .apply_binop_bool
    cmp r12d, TY_NUM
    je .apply_binop_rel_num
    cmp r12d, TY_STR
    je .apply_binop_rel_str
    cmp r12d, TY_BOOL
    je .apply_binop_rel_bool
    jmp .apply_binop_op_err
.apply_binop_rel_num:
    cmp r13d, TY_NUM
    je .apply_binop_bool
    jmp .apply_binop_op_err
.apply_binop_rel_str:
    cmp r13d, TY_STR
    je .apply_binop_bool
    jmp .apply_binop_op_err
.apply_binop_rel_bool:
    cmp r13d, TY_BOOL
    je .apply_binop_bool
    jmp .apply_binop_op_err
.apply_binop_bool:
    mov eax, TY_BOOL
    jmp .apply_binop_ret

.apply_binop_eq:
    cmp r12d, TY_ANY
    je .apply_binop_bool
    cmp r13d, TY_ANY
    je .apply_binop_bool
    cmp r12d, r13d
    je .apply_binop_bool
    # intentional-comparison check
    mov edi, r14d
    call tok_ptr
    mov edx, dword ptr [rax+TK_LINE]
    mov ecx, dword ptr [rax+TK_COL]
    mov edi, r12d
    mov esi, r13d
    call err_no_overlap
    jmp .apply_binop_err

.apply_binop_logic:
    cmp r12d, TY_BOOL
    jne .apply_binop_any
    cmp r13d, TY_BOOL
    jne .apply_binop_any
    mov eax, TY_BOOL
    jmp .apply_binop_ret

.apply_binop_op_err:
    mov edi, r14d
    call tok_ptr
    mov r8d, dword ptr [rax+TK_LINE]
    mov r9d, dword ptr [rax+TK_COL]
    mov eax, dword ptr [rbx+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [rbx+TK_LEN]
    mov edx, r12d
    mov ecx, r13d
    call err_operator
.apply_binop_err:
    mov eax, TY_ERR
.apply_binop_ret:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# parse_unary() -> eax type
parse_unary:
    push rbx
    call cur_tok
    mov rbx, rax
    mov eax, dword ptr [rbx+TK_KIND]
    cmp eax, T_MINUS
    je .parse_unary_num
    cmp eax, T_PLUS
    je .parse_unary_num
    cmp eax, T_BANG
    je .parse_unary_bool
    pop rbx
    jmp parse_primary
.parse_unary_num:
    call advance
    call parse_unary
    cmp eax, TY_ERR
    je .parse_unary_ret
    mov eax, TY_NUM
    pop rbx
    ret
.parse_unary_bool:
    call advance
    call parse_unary
    cmp eax, TY_ERR
    je .parse_unary_ret
    mov eax, TY_BOOL
.parse_unary_ret:
    pop rbx
    ret

# parse_primary() -> eax type
parse_primary:
    push rbx
    push r12
    call cur_tok
    mov rbx, rax
    mov eax, dword ptr [rbx+TK_KIND]
    cmp eax, T_NUM
    je .parse_primary_num
    cmp eax, T_STR
    je .parse_primary_str
    cmp eax, T_TRUE
    je .parse_primary_bool
    cmp eax, T_FALSE
    je .parse_primary_bool
    cmp eax, T_LPAREN
    je .parse_primary_paren
    cmp eax, T_IDENT
    je .parse_primary_ident
    jmp .parse_primary_bad

.parse_primary_num:
    call advance
    mov eax, TY_NUM
    jmp .parse_primary_ret
.parse_primary_str:
    call advance
    mov eax, TY_STR
    jmp .parse_primary_ret
.parse_primary_bool:
    call advance
    mov eax, TY_BOOL
    jmp .parse_primary_ret

.parse_primary_paren:
    call advance
    call parse_expr
    mov r12d, eax
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    je .parse_primary_paren_close
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_rparen_expected
    mov eax, r12d
    jmp .parse_primary_ret
.parse_primary_paren_close:
    call advance
    mov eax, r12d
    jmp .parse_primary_ret

.parse_primary_ident:
    call advance
    call cur_tok
    mov ecx, dword ptr [rax+TK_KIND]
    cmp ecx, T_LPAREN
    je .parse_primary_call
    cmp ecx, T_DOT
    je .parse_primary_member
    # variable reference
    mov eax, dword ptr [rbx+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [rbx+TK_LEN]
    call sym_lookup
    cmp eax, -1
    je .parse_primary_unknown
    imul rax, rax, SY_SIZE
    lea rdx, [rip+sym_buf]
    add rdx, rax
    mov eax, dword ptr [rdx+SY_TYPE]
    jmp .parse_primary_ret
.parse_primary_unknown:
    mov rdi, rbx
    call err_name
    mov eax, TY_ERR
    jmp .parse_primary_ret

.parse_primary_call:
    mov eax, dword ptr [rbx+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [rbx+TK_LEN]
    call sym_lookup
    mov esi, eax
    mov rdi, rbx
    cmp esi, -1
    jne .parse_primary_call_go
    call err_name
    mov rdi, rbx
    mov esi, -1
    call parse_call
    mov eax, TY_ERR
    jmp .parse_primary_ret
.parse_primary_call_go:
    call parse_call
    jmp .parse_primary_ret

.parse_primary_member:
    mov rdi, rbx
    lea rsi, [rip+s_console]
    mov edx, OFFSET s_console_len
    call tok_text_eq
    test eax, eax
    je .parse_primary_member_unknown
    call advance                        # '.'
    call cur_tok
    mov rbx, rax
    cmp dword ptr [rbx+TK_KIND], T_IDENT
    jne .parse_primary_member_bad
    mov rdi, rbx
    lea rsi, [rip+s_log]
    mov edx, OFFSET s_log_len
    call tok_text_eq
    test eax, eax
    je .parse_primary_member_bad
    call advance                        # 'log'
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_LPAREN
    jne .parse_primary_member_nolparen
    mov rdi, rbx
    mov esi, -1
    call parse_call
    jmp .parse_primary_ret
.parse_primary_member_bad:
    mov edi, dword ptr [rbx+TK_LINE]
    mov esi, dword ptr [rbx+TK_COL]
    call err_ident_expected
    mov eax, TY_ERR
    jmp .parse_primary_ret
.parse_primary_member_nolparen:
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_lparen_expected
    mov eax, TY_ERR
    jmp .parse_primary_ret
.parse_primary_member_unknown:
    mov rdi, rbx
    call err_name
    call advance                        # '.'
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_IDENT
    jne .parse_primary_member_unknown_done
    call advance
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_LPAREN
    jne .parse_primary_member_unknown_done
    mov rdi, rax
    mov esi, -1
    call parse_call
.parse_primary_member_unknown_done:
    mov eax, TY_ERR
    jmp .parse_primary_ret

.parse_primary_bad:
    mov edi, dword ptr [rbx+TK_LINE]
    mov esi, dword ptr [rbx+TK_COL]
    call err_expr_expected
    mov eax, dword ptr [rbx+TK_KIND]
    cmp eax, T_EOF
    je .parse_primary_bad_ret
    cmp eax, T_SEMI
    je .parse_primary_bad_ret
    cmp eax, T_RPAREN
    je .parse_primary_bad_ret
    cmp eax, T_RBRACE
    je .parse_primary_bad_ret
    cmp eax, T_COMMA
    je .parse_primary_bad_ret
    call advance
.parse_primary_bad_ret:
    mov eax, TY_ERR
.parse_primary_ret:
    pop r12
    pop rbx
    ret

# parse_call(callee_tok=rdi, sym_idx=esi) -> eax type
parse_call:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 536
    mov qword ptr [rsp], rdi
    mov r12d, esi
    xor r13d, r13d
    xor r14d, r14d
    mov r15d, TY_VOID
    cmp r12d, -1
    je .parse_call_callee_ok
    mov eax, r12d
    imul rax, rax, SY_SIZE
    lea rdx, [rip+sym_buf]
    add rdx, rax
    cmp dword ptr [rdx+SY_KIND], SK_FUNC
    je .parse_call_isfunc
    cmp dword ptr [rdx+SY_TYPE], TY_ANY
    je .parse_call_callee_any
    cmp dword ptr [rdx+SY_TYPE], TY_ERR
    je .parse_call_callee_err
    mov edx, dword ptr [rdx+SY_TYPE]
    mov rax, qword ptr [rsp]
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_not_callable
    mov r12d, -2
    jmp .parse_call_callee_ok
.parse_call_callee_any:
    mov r12d, -3
    mov r15d, TY_ANY
    jmp .parse_call_callee_ok
.parse_call_callee_err:
    mov r12d, -2
    jmp .parse_call_callee_ok
.parse_call_isfunc:
    mov r13d, dword ptr [rdx+SY_ARITY]
    mov r14d, dword ptr [rdx+SY_PARAMS]
    mov r15d, dword ptr [rdx+SY_RET]
.parse_call_callee_ok:
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_LPAREN
    je .parse_call_lp
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_lparen_expected
    mov eax, TY_ERR
    jmp .parse_call_done
.parse_call_lp:
    call advance
    xor ebx, ebx
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    je .parse_call_args_done
.parse_call_arg_loop:
    mov eax, dword ptr [rip+tok_pos]
    mov dword ptr [rsp+8], eax
    call parse_expr
    mov dword ptr [rsp+12], eax
    cmp ebx, 64
    jae .parse_call_next_arg
    lea rdx, [rsp+24]
    mov eax, ebx
    mov ecx, dword ptr [rsp+12]
    mov dword ptr [rdx+rax*8], ecx
    mov ecx, dword ptr [rsp+8]
    mov dword ptr [rdx+rax*8+4], ecx
.parse_call_next_arg:
    inc ebx
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_COMMA
    jne .parse_call_args_done
    call advance
    jmp .parse_call_arg_loop
.parse_call_args_done:
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    je .parse_call_rp
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_rparen_expected
    jmp .parse_call_arity_check
.parse_call_rp:
    call advance
.parse_call_arity_check:
    cmp r12d, 0
    jl .parse_call_result
    cmp ebx, r13d
    je .parse_call_types
    cmp ebx, r13d
    jb .parse_call_arity_few
    cmp r13d, 64
    jae .parse_call_arity_callee
    lea rdx, [rsp+24]
    mov eax, r13d
    mov eax, dword ptr [rdx+rax*8+4]
    imul rax, rax, TK_SIZE
    lea rdx, [rip+tok_buf]
    add rax, rdx
    mov edx, dword ptr [rax+TK_LINE]
    mov ecx, dword ptr [rax+TK_COL]
    jmp .parse_call_arity_emit
.parse_call_arity_callee:
    mov rax, qword ptr [rsp]
    mov edx, dword ptr [rax+TK_LINE]
    mov ecx, dword ptr [rax+TK_COL]
    jmp .parse_call_arity_emit
.parse_call_arity_few:
    mov rax, qword ptr [rsp]
    mov edx, dword ptr [rax+TK_LINE]
    mov ecx, dword ptr [rax+TK_COL]
.parse_call_arity_emit:
    mov edi, r13d
    mov esi, ebx
    call err_arity
    jmp .parse_call_result
.parse_call_types:
    xor ecx, ecx
.parse_call_types_loop:
    cmp ecx, ebx
    jae .parse_call_result
    lea rdx, [rsp+24]
    mov eax, dword ptr [rdx+rcx*8]
    mov edi, eax
    lea rdx, [rip+param_pool]
    mov eax, r14d
    add eax, ecx
    mov esi, dword ptr [rdx+rax*4]
    push rcx
    call is_assignable
    pop rcx
    test eax, eax
    jne .parse_call_types_next
    lea rdx, [rsp+24]
    mov edi, dword ptr [rdx+rcx*8]
    lea rdx, [rip+param_pool]
    mov eax, r14d
    add eax, ecx
    mov esi, dword ptr [rdx+rax*4]
    lea rdx, [rsp+24]
    mov eax, dword ptr [rdx+rcx*8+4]
    imul rax, rax, TK_SIZE
    lea rdx, [rip+tok_buf]
    add rax, rdx
    mov edx, dword ptr [rax+TK_LINE]
    mov ecx, dword ptr [rax+TK_COL]
    call err_arg
    jmp .parse_call_result
.parse_call_types_next:
    inc ecx
    jmp .parse_call_types_loop
.parse_call_result:
    cmp r12d, -1
    je .parse_call_ret_void
    cmp r12d, -2
    je .parse_call_ret_err
    cmp r12d, -3
    je .parse_call_ret_any
    mov eax, r15d
    jmp .parse_call_done
.parse_call_ret_void:
    mov eax, TY_VOID
    jmp .parse_call_done
.parse_call_ret_err:
    mov eax, TY_ERR
    jmp .parse_call_done
.parse_call_ret_any:
    mov eax, TY_ANY
.parse_call_done:
    add rsp, 536
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# --- statements -------------------------------------------------------------
# parse_stmt()
.globl parse_stmt
parse_stmt:
    call cur_tok
    mov eax, dword ptr [rax+TK_KIND]
    cmp eax, T_LET
    je parse_decl
    cmp eax, T_CONST
    je parse_decl
    cmp eax, T_VAR
    je parse_decl
    cmp eax, T_FUNCTION
    je parse_func
    cmp eax, T_RETURN
    je parse_return
    cmp eax, T_IF
    je parse_if
    cmp eax, T_LBRACE
    je parse_block
    cmp eax, T_SEMI
    je .parse_stmt_empty
    cmp eax, T_IDENT
    jne parse_expr_stmt
    mov eax, dword ptr [rip+tok_pos]
    inc eax
    mov edi, eax
    call tok_ptr
    cmp dword ptr [rax+TK_KIND], T_ASSIGN
    jne parse_expr_stmt
    call cur_tok
    mov rdi, rax
    jmp parse_assign
.parse_stmt_empty:
    call advance
    ret

# parse_decl()
parse_decl:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    call cur_tok
    mov rbx, rax
    mov r12d, dword ptr [rbx+TK_KIND]
    call advance
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_IDENT
    je .parse_decl_name_ok
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_ident_expected
    call skip_stmt
    jmp .parse_decl_ret
.parse_decl_name_ok:
    mov r13, rax
    call advance
    mov r14d, TY_ANY
    mov dword ptr [rsp], 0
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_COLON
    jne .parse_decl_no_anno
    call advance
    call parse_type
    mov r14d, eax
    mov dword ptr [rsp], 1
.parse_decl_no_anno:
    mov dword ptr [rsp+4], 0
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_ASSIGN
    jne .parse_decl_no_init
    call advance
    call cur_tok
    mov eax, dword ptr [rax+TK_OFF]
    mov dword ptr [rsp+8], eax
    call parse_expr
    mov dword ptr [rsp+16], eax
    call prev_tok_end
    mov dword ptr [rsp+12], eax
    mov dword ptr [rsp+4], 1
.parse_decl_no_init:
    mov rdi, rbx
    call emit_tok
    mov edi, ' '
    call emit_char
    mov rdi, r13
    call emit_tok
    cmp dword ptr [rsp+4], 0
    je .parse_decl_emit_end
    lea rdi, [rip+s_space_eq]
    mov esi, OFFSET s_space_eq_len
    call emit_str
    mov edi, dword ptr [rsp+8]
    mov esi, dword ptr [rsp+12]
    call emit_span
.parse_decl_emit_end:
    mov edi, ';'
    call emit_char
    mov edi, 10
    call emit_char

    cmp dword ptr [rsp], 0
    je .parse_decl_infer
    cmp dword ptr [rsp+4], 0
    je .parse_decl_after_check
    mov edi, dword ptr [rsp+16]
    mov esi, r14d
    call is_assignable
    test eax, eax
    jne .parse_decl_after_check
    mov edi, dword ptr [rsp+16]
    mov esi, r14d
    mov edx, dword ptr [r13+TK_LINE]
    mov ecx, dword ptr [r13+TK_COL]
    call err_assign
    jmp .parse_decl_after_check
.parse_decl_infer:
    cmp dword ptr [rsp+4], 0
    je .parse_decl_after_check
    mov eax, dword ptr [rsp+16]
    cmp eax, TY_ERR
    jne .parse_decl_infer_ok
    mov eax, TY_ANY
.parse_decl_infer_ok:
    mov r14d, eax
.parse_decl_after_check:
    cmp r12d, T_VAR
    je .parse_decl_add_sym
    mov eax, dword ptr [r13+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r13+TK_LEN]
    call sym_find_in_scope
    cmp eax, -1
    je .parse_decl_add_sym
    imul rax, rax, SY_SIZE
    lea rdx, [rip+sym_buf]
    add rax, rdx
    cmp dword ptr [rax+SY_KIND], SK_FUNC
    je .parse_decl_dup_func_name
    mov rdi, qword ptr [rax+SY_NAME]
    mov esi, dword ptr [rax+SY_NLEN]
    mov edx, dword ptr [rax+SY_LINE]
    mov ecx, dword ptr [rax+SY_COL]
    call err_redeclare_at
    mov rdi, r13
    call err_redeclare
    jmp .parse_decl_add_sym
.parse_decl_dup_func_name:
    mov rdi, rax
    mov rsi, r13
    call err_dup_ident_pair
.parse_decl_add_sym:
    cmp r12d, T_CONST
    jne .parse_decl_no_const_err
    cmp dword ptr [rsp+4], 0
    jne .parse_decl_no_const_err
    mov edi, dword ptr [r13+TK_LINE]
    mov esi, dword ptr [r13+TK_COL]
    call err_const_init
.parse_decl_no_const_err:
    mov eax, dword ptr [r13+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r13+TK_LEN]
    mov edx, r14d
    mov ecx, SK_VAR
    cmp r12d, T_CONST
    jne .parse_decl_kind_ok
    mov ecx, SK_CONST
.parse_decl_kind_ok:
    mov r8d, dword ptr [r13+TK_LINE]
    mov r9d, dword ptr [r13+TK_COL]
    call sym_add
    call expect_semi
.parse_decl_ret:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# parse_assign(name_tok=rdi)
parse_assign:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 32
    mov rbx, rdi
    mov eax, dword ptr [rbx+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [rbx+TK_LEN]
    call sym_lookup
    mov r12d, eax
    mov r13d, TY_ERR
    mov r14d, SK_VAR
    cmp r12d, -1
    je .parse_assign_unknown
    imul rax, rax, SY_SIZE
    lea rdx, [rip+sym_buf]
    add rdx, rax
    mov r13d, dword ptr [rdx+SY_TYPE]
    mov r14d, dword ptr [rdx+SY_KIND]
    jmp .parse_assign_have
.parse_assign_unknown:
    mov rdi, rbx
    call err_name
.parse_assign_have:
    mov rdi, rbx
    call emit_tok
    lea rdi, [rip+s_space_eq]
    mov esi, OFFSET s_space_eq_len
    call emit_str
    call advance                        # name
    call advance                        # '='
    call cur_tok
    mov eax, dword ptr [rax+TK_OFF]
    mov dword ptr [rsp], eax
    call parse_expr
    mov dword ptr [rsp+4], eax
    call prev_tok_end
    mov dword ptr [rsp+8], eax
    mov edi, dword ptr [rsp]
    mov esi, dword ptr [rsp+8]
    call emit_span
    mov edi, ';'
    call emit_char
    mov edi, 10
    call emit_char
    cmp r14d, SK_CONST
    je .parse_assign_const
    cmp r13d, TY_ERR
    je .parse_assign_semi
    mov edi, dword ptr [rsp+4]
    mov esi, r13d
    call is_assignable
    test eax, eax
    jne .parse_assign_semi
    mov edi, dword ptr [rsp+4]
    mov esi, r13d
    mov edx, dword ptr [rbx+TK_LINE]
    mov ecx, dword ptr [rbx+TK_COL]
    call err_assign
    jmp .parse_assign_semi
.parse_assign_const:
    mov rdi, rbx
    call err_assign_const
.parse_assign_semi:
    call expect_semi
    add rsp, 32
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# parse_expr_stmt()
parse_expr_stmt:
    push rbx
    call cur_tok
    mov ebx, dword ptr [rax+TK_OFF]
    call parse_expr
    call prev_tok_end
    mov esi, eax
    mov edi, ebx
    call emit_span
    mov edi, ';'
    call emit_char
    mov edi, 10
    call emit_char
    call expect_semi
    pop rbx
    ret

# parse_return()
parse_return:
    push rbx
    push r12
    push r13
    call cur_tok
    mov rbx, rax
    call advance
    call cur_tok
    mov r12, rax
    mov eax, dword ptr [r12+TK_KIND]
    cmp eax, T_SEMI
    je .parse_return_bare
    cmp eax, T_RBRACE
    je .parse_return_bare
    cmp eax, T_EOF
    je .parse_return_bare
    mov eax, dword ptr [r12+TK_LINE]
    cmp eax, dword ptr [rbx+TK_LINE]
    ja .parse_return_bare
    lea rdi, [rip+s_return]
    mov esi, OFFSET s_return_len
    call emit_str
    mov r13d, dword ptr [r12+TK_OFF]
    call parse_expr
    mov r12d, eax
    call prev_tok_end
    mov esi, eax
    mov edi, r13d
    call emit_span
    mov edi, ';'
    call emit_char
    mov edi, 10
    call emit_char
    cmp dword ptr [rip+in_func], 0
    je .parse_return_outside_expr
    mov eax, dword ptr [rip+cur_ret]
    cmp eax, TY_ANY
    je .parse_return_semi
    cmp eax, TY_ERR
    je .parse_return_semi
    mov edi, r12d
    mov esi, eax
    call is_assignable
    test eax, eax
    jne .parse_return_semi
    mov edi, r12d
    mov esi, dword ptr [rip+cur_ret]
    mov edx, dword ptr [rbx+TK_LINE]
    mov ecx, dword ptr [rbx+TK_COL]
    call err_assign
    jmp .parse_return_semi
.parse_return_outside_expr:
    mov edi, dword ptr [rbx+TK_LINE]
    mov esi, dword ptr [rbx+TK_COL]
    call err_return_outside
.parse_return_semi:
    call expect_semi
    jmp .parse_return_done
.parse_return_bare:
    lea rdi, [rip+s_return_bare]
    mov esi, OFFSET s_return_bare_len
    call emit_str
    cmp dword ptr [rip+in_func], 0
    jne .parse_return_bare_semi
    mov edi, dword ptr [rbx+TK_LINE]
    mov esi, dword ptr [rbx+TK_COL]
    call err_return_outside
.parse_return_bare_semi:
    call expect_semi
.parse_return_done:
    pop r13
    pop r12
    pop rbx
    ret

# parse_if()
parse_if:
    push rbx
    push r12
    push r13
    call cur_tok
    mov rbx, rax
    call advance
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_LPAREN
    je .parse_if_lp
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_lparen_expected
    jmp .parse_if_cond
.parse_if_lp:
    call advance
.parse_if_cond:
    call cur_tok
    mov r12d, dword ptr [rax+TK_OFF]
    call parse_expr
    call prev_tok_end
    mov r13d, eax
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    je .parse_if_rp
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_rparen_expected
    jmp .parse_if_emit
.parse_if_rp:
    call advance
.parse_if_emit:
    lea rdi, [rip+s_if_open]
    mov esi, OFFSET s_if_open_len
    call emit_str
    mov edi, r12d
    mov esi, r13d
    call emit_span
    lea rdi, [rip+s_rparen_space]
    mov esi, OFFSET s_rparen_space_len
    call emit_str
    call parse_stmt
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_ELSE
    jne .parse_if_done
    call advance
    lea rdi, [rip+s_else]
    mov esi, OFFSET s_else_len
    call emit_str
    call parse_stmt
.parse_if_done:
    pop r13
    pop r12
    pop rbx
    ret

# parse_block()
parse_block:
    push rbx
    call advance
    lea rdi, [rip+s_lbrace_nl]
    mov esi, OFFSET s_lbrace_nl_len
    call emit_str
    call scope_push
.parse_block_loop:
    call cur_tok
    mov rbx, rax
    mov eax, dword ptr [rbx+TK_KIND]
    cmp eax, T_RBRACE
    je .parse_block_close
    cmp eax, T_EOF
    je .parse_block_eof
    call parse_stmt
    jmp .parse_block_loop
.parse_block_close:
    call advance
    call scope_pop
    lea rdi, [rip+s_rbrace_nl]
    mov esi, OFFSET s_rbrace_nl_len
    call emit_str
    pop rbx
    ret
.parse_block_eof:
    mov edi, dword ptr [rbx+TK_LINE]
    mov esi, dword ptr [rbx+TK_COL]
    call err_rbrace_expected
    call scope_pop
    lea rdi, [rip+s_rbrace_nl]
    mov esi, OFFSET s_rbrace_nl_len
    call emit_str
    pop rbx
    ret

# parse_func()
parse_func:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 48
    call cur_tok
    mov rbx, rax
    call advance
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_IDENT
    je .parse_func_name_ok
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_ident_expected
    call skip_stmt
    jmp .parse_func_ret
.parse_func_name_ok:
    mov r12, rax
    call advance
    mov eax, dword ptr [r12+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r12+TK_LEN]
    mov edx, dword ptr [r12+TK_LINE]
    mov ecx, dword ptr [r12+TK_COL]
    call sym_lookup_func_pos
    mov r13d, eax
    cmp r13d, -1
    jne .parse_func_have_sym
    mov eax, dword ptr [r12+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r12+TK_LEN]
    mov edx, TY_FUNC
    mov ecx, SK_FUNC
    mov r8d, dword ptr [r12+TK_LINE]
    mov r9d, dword ptr [r12+TK_COL]
    call sym_add
    mov r13d, eax
.parse_func_have_sym:
    mov eax, dword ptr [r12+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r12+TK_LEN]
    mov edx, dword ptr [rip+scope_base]
    call sym_count_funcs
    cmp eax, 1
    jbe .parse_func_no_dup
    mov eax, dword ptr [r12+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r12+TK_LEN]
    mov edx, dword ptr [rip+scope_base]
    call sym_mark_dup_funcs
.parse_func_no_dup:
    lea rdi, [rip+s_function_kw]
    mov esi, OFFSET s_function_kw_len
    call emit_str
    mov rdi, r12
    call emit_tok
    mov edi, '('
    call emit_char
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_LPAREN
    je .parse_func_lp
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_lparen_expected
    jmp .parse_func_ret
.parse_func_lp:
    call advance
    call scope_push
    mov eax, dword ptr [rip+param_count]
    mov dword ptr [rsp], eax
    xor r14d, r14d
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    je .parse_func_params_done
.parse_func_param_loop:
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_IDENT
    jne .parse_func_fail_scoped
    mov r15, rax
    call advance
    test r14d, r14d
    je .parse_func_no_comma
    mov edi, ','
    call emit_char
    mov edi, ' '
    call emit_char
.parse_func_no_comma:
    mov rdi, r15
    call emit_tok
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_COLON
    je .parse_func_colon
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_colon_expected
    jmp .parse_func_fail_scoped
.parse_func_colon:
    call advance
    call parse_type
    mov dword ptr [rsp+12], eax
    mov edi, eax
    call sym_add_param
    mov eax, dword ptr [r15+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r15+TK_LEN]
    mov edx, dword ptr [rsp+12]
    mov ecx, SK_PARAM
    mov r8d, dword ptr [r15+TK_LINE]
    mov r9d, dword ptr [r15+TK_COL]
    call sym_add
    inc r14d
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_COMMA
    jne .parse_func_params_done
    call advance
    jmp .parse_func_param_loop
.parse_func_params_done:
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    je .parse_func_rp
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_rparen_expected
    jmp .parse_func_fail_scoped
.parse_func_rp:
    call advance
    mov r15d, TY_ANY
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_COLON
    jne .parse_func_no_ret
    call advance
    call parse_type
    mov r15d, eax
.parse_func_no_ret:
    mov edi, r13d
    mov esi, r14d
    mov edx, dword ptr [rsp]
    mov ecx, r15d
    call sym_set_func
    mov eax, dword ptr [rip+cur_ret]
    mov dword ptr [rsp+4], eax
    mov eax, dword ptr [rip+in_func]
    mov dword ptr [rsp+8], eax
    mov dword ptr [rip+cur_ret], r15d
    mov dword ptr [rip+in_func], 1
    lea rdi, [rip+s_rparen_brace_nl]
    mov esi, OFFSET s_rparen_brace_nl_len
    call emit_str
    call cur_tok
    cmp dword ptr [rax+TK_KIND], T_LBRACE
    je .parse_func_body
    mov edi, dword ptr [r12+TK_LINE]
    mov esi, dword ptr [r12+TK_COL]
    call err_func_missing
    jmp .parse_func_fail_func
.parse_func_body:
    call advance
.parse_func_body_loop:
    call cur_tok
    mov eax, dword ptr [rax+TK_KIND]
    cmp eax, T_RBRACE
    je .parse_func_body_done
    cmp eax, T_EOF
    je .parse_func_body_eof
    call parse_stmt
    jmp .parse_func_body_loop
.parse_func_body_done:
    call advance
    lea rdi, [rip+s_rbrace_nl]
    mov esi, OFFSET s_rbrace_nl_len
    call emit_str
    call scope_pop
    mov eax, dword ptr [rsp+4]
    mov dword ptr [rip+cur_ret], eax
    mov eax, dword ptr [rsp+8]
    mov dword ptr [rip+in_func], eax
    jmp .parse_func_ret
.parse_func_body_eof:
    mov edi, dword ptr [rax+TK_LINE]
    mov esi, dword ptr [rax+TK_COL]
    call err_rbrace_expected
    lea rdi, [rip+s_rbrace_nl]
    mov esi, OFFSET s_rbrace_nl_len
    call emit_str
    call scope_pop
    mov eax, dword ptr [rsp+4]
    mov dword ptr [rip+cur_ret], eax
    mov eax, dword ptr [rsp+8]
    mov dword ptr [rip+in_func], eax
    jmp .parse_func_ret
.parse_func_fail_func:
    call scope_pop
    mov eax, dword ptr [rsp+4]
    mov dword ptr [rip+cur_ret], eax
    mov eax, dword ptr [rsp+8]
    mov dword ptr [rip+in_func], eax
    jmp .parse_func_ret
.parse_func_fail_scoped:
    call scope_pop
.parse_func_ret:
    add rsp, 48
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# --- pre-scan: register top-level function signatures -----------------------
collect_functions:
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 16
    xor r12d, r12d                 # token index
    xor r13d, r13d                 # brace depth
.collect_functions_loop:
    mov edi, r12d
    call tok_ptr
    mov rbx, rax
    mov eax, dword ptr [rbx+TK_KIND]
    cmp eax, T_EOF
    je .collect_functions_done
    cmp eax, T_LBRACE
    je .collect_functions_inc
    cmp eax, T_RBRACE
    je .collect_functions_dec
    cmp eax, T_FUNCTION
    jne .collect_functions_next
    test r13d, r13d
    jne .collect_functions_next
    # signature starts at index r12
    lea edi, [r12+1]
    call tok_ptr
    mov r14, rax                   # name token
    cmp dword ptr [r14+TK_KIND], T_IDENT
    jne .collect_functions_next
    lea edi, [r12+2]
    call tok_ptr
    cmp dword ptr [rax+TK_KIND], T_LPAREN
    jne .collect_functions_next
    lea r15d, [r12+3]              # p
    mov eax, dword ptr [rip+param_count]
    mov dword ptr [rsp], eax       # params offset
    mov dword ptr [rsp+4], 0       # arity
    mov edi, r15d
    call tok_ptr
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    je .collect_functions_params_end
.collect_functions_check_param:
    cmp dword ptr [rax+TK_KIND], T_IDENT
    jne .collect_functions_fail
    lea edi, [r15+1]
    call tok_ptr
    cmp dword ptr [rax+TK_KIND], T_COLON
    jne .collect_functions_fail
    lea edi, [r15+2]
    call tok_ptr
    mov rdi, rax
    call type_from_tok
    cmp eax, TY_ERR
    jne .collect_functions_ty_ok
    mov eax, TY_ANY
.collect_functions_ty_ok:
    mov edi, eax
    call sym_add_param
    inc dword ptr [rsp+4]
    add r15d, 3
    mov edi, r15d
    call tok_ptr
    cmp dword ptr [rax+TK_KIND], T_COMMA
    jne .collect_functions_check_rparen
    inc r15d
    mov edi, r15d
    call tok_ptr
    jmp .collect_functions_check_param
.collect_functions_check_rparen:
    cmp dword ptr [rax+TK_KIND], T_RPAREN
    jne .collect_functions_fail
.collect_functions_params_end:
    inc r15d
    mov dword ptr [rsp+8], TY_ANY
    mov edi, r15d
    call tok_ptr
    cmp dword ptr [rax+TK_KIND], T_COLON
    jne .collect_functions_after_ret
    lea edi, [r15+1]
    call tok_ptr
    mov rdi, rax
    call type_from_tok
    cmp eax, TY_ERR
    jne .collect_functions_ret_ok
    mov eax, TY_ANY
.collect_functions_ret_ok:
    mov dword ptr [rsp+8], eax
    add r15d, 2
.collect_functions_after_ret:
    mov edi, r15d
    call tok_ptr
    cmp dword ptr [rax+TK_KIND], T_LBRACE
    jne .collect_functions_fail
    # register every top-level function declaration
    mov eax, dword ptr [r14+TK_OFF]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, dword ptr [r14+TK_LEN]
    mov edx, TY_FUNC
    mov ecx, SK_FUNC
    mov r8d, dword ptr [r14+TK_LINE]
    mov r9d, dword ptr [r14+TK_COL]
    call sym_add
    mov edi, eax
    mov esi, dword ptr [rsp+4]
    mov edx, dword ptr [rsp]
    mov ecx, dword ptr [rsp+8]
    call sym_set_func
.collect_functions_registered:
    mov dword ptr [rsp+12], 0
    # r15 points at '{'; skip balanced body
.collect_functions_skip_loop:
    mov edi, r15d
    call tok_ptr
    mov eax, dword ptr [rax+TK_KIND]
    cmp eax, T_EOF
    je .collect_functions_eof_skip
    cmp eax, T_LBRACE
    je .collect_functions_skip_inc
    cmp eax, T_RBRACE
    je .collect_functions_skip_dec
    inc r15d
    jmp .collect_functions_skip_loop
.collect_functions_skip_inc:
    inc dword ptr [rsp+12]
    inc r15d
    jmp .collect_functions_skip_loop
.collect_functions_skip_dec:
    dec dword ptr [rsp+12]
    inc r15d
    cmp dword ptr [rsp+12], 0
    jne .collect_functions_skip_loop
    mov r12d, r15d
    jmp .collect_functions_loop
.collect_functions_fail:
    inc r12d
    jmp .collect_functions_loop
.collect_functions_eof_skip:
    jmp .collect_functions_done
.collect_functions_next:
    inc r12d
    jmp .collect_functions_loop
.collect_functions_inc:
    inc r13d
    inc r12d
    jmp .collect_functions_loop
.collect_functions_dec:
    dec r13d
    inc r12d
    jmp .collect_functions_loop
.collect_functions_done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# --- program ----------------------------------------------------------------
.globl parse_program
parse_program:
    mov dword ptr [rip+tok_pos], 0
    mov dword ptr [rip+sym_count], 0
    mov dword ptr [rip+param_count], 0
    mov dword ptr [rip+scope_depth], 0
    mov dword ptr [rip+scope_base], 0
    mov dword ptr [rip+cur_ret], TY_VOID
    mov dword ptr [rip+in_func], 0
    lea rdi, [rip+hash_buckets]
    mov ecx, HASH_BUCKETS
    mov eax, -1
    rep stosd
    call collect_functions
    mov dword ptr [rip+tok_pos], 0
.parse_program_loop:
    call cur_tok
    mov eax, dword ptr [rax+TK_KIND]
    cmp eax, T_EOF
    je .parse_program_done
    cmp eax, T_SEMI
    je .parse_program_semi
    call parse_stmt
    jmp .parse_program_loop
.parse_program_semi:
    call advance
    jmp .parse_program_loop
.parse_program_done:
    ret
