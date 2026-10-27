.include "defs.inc"

.section .text

# is_assignable(src=edi, dst=esi) -> eax
.globl is_assignable
is_assignable:
    cmp edi, esi
    je .is_assignable_yes
    cmp edi, TY_ANY
    je .is_assignable_yes
    cmp esi, TY_ANY
    je .is_assignable_yes
    xor eax, eax
    ret
.is_assignable_yes:
    mov eax, 1
    ret

# err_assign(src=edi, dst=esi, line=edx, col=ecx)
.globl err_assign
err_assign:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    cmp ebx, TY_ERR
    je .err_assign_ret
    cmp r12d, TY_ERR
    je .err_assign_ret
    call mb_reset
    lea rdi, [rip+s_type_prefix]
    mov esi, OFFSET s_type_prefix_len
    call mb_add
    mov edi, ebx
    call mb_add_type
    lea rdi, [rip+s_not_assign]
    mov esi, OFFSET s_not_assign_len
    call mb_add
    mov edi, r12d
    call mb_add_type
    mov edi, '.'
    call mb_add_char
    mov edi, r13d
    mov esi, r14d
    mov edx, 2322
    call diag_msg
.err_assign_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_arg(actual=edi, expected=esi, line=edx, col=ecx)
.globl err_arg
err_arg:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    cmp ebx, TY_ERR
    je .err_arg_ret
    cmp r12d, TY_ERR
    je .err_arg_ret
    call mb_reset
    lea rdi, [rip+s_arg_prefix]
    mov esi, OFFSET s_arg_prefix_len
    call mb_add
    mov edi, ebx
    call mb_add_type
    lea rdi, [rip+s_arg_mid]
    mov esi, OFFSET s_arg_mid_len
    call mb_add
    mov edi, r12d
    call mb_add_type
    mov edi, '.'
    call mb_add_char
    mov edi, r13d
    mov esi, r14d
    mov edx, 2345
    call diag_msg
.err_arg_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_arity(expected=edi, got=esi, line=edx, col=ecx)
.globl err_arity
err_arity:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    call mb_reset
    lea rdi, [rip+s_expected_arg_pre]
    mov esi, OFFSET s_expected_arg_pre_len
    call mb_add
    mov edi, ebx
    call mb_add_uint
    lea rdi, [rip+s_expected_arg_mid]
    mov esi, OFFSET s_expected_arg_mid_len
    call mb_add
    mov edi, r12d
    call mb_add_uint
    lea rdi, [rip+s_expected_arg_post]
    mov esi, OFFSET s_expected_arg_post_len
    call mb_add
    mov edi, r13d
    mov esi, r14d
    mov edx, 2554
    call diag_msg
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_operator(op=rdi, op_len=esi, left=edx, right=ecx, line=r8d, col=r9d)
.globl err_operator
err_operator:
    push rbx
    push r12
    push r13
    push r14
    push r15
    push r9
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d
    cmp r13d, TY_ERR
    je .err_operator_ret
    cmp r14d, TY_ERR
    je .err_operator_ret
    call mb_reset
    lea rdi, [rip+s_operator_pre]
    mov esi, OFFSET s_operator_pre_len
    call mb_add
    mov edi, '\''
    call mb_add_char
    mov rdi, rbx
    mov esi, r12d
    call mb_add
    mov edi, '\''
    call mb_add_char
    lea rdi, [rip+s_operator_mid]
    mov esi, OFFSET s_operator_mid_len
    call mb_add
    mov edi, r13d
    call mb_add_type
    lea rdi, [rip+s_and]
    mov esi, OFFSET s_and_len
    call mb_add
    mov edi, r14d
    call mb_add_type
    mov edi, '.'
    call mb_add_char
    mov edi, r15d
    mov esi, dword ptr [rsp]
    mov edx, 2365
    call diag_msg
.err_operator_ret:
    pop r9
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_no_overlap(left=edi, right=esi, line=edx, col=ecx)
.globl err_no_overlap
err_no_overlap:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    cmp ebx, TY_ERR
    je .err_no_overlap_ret
    cmp r12d, TY_ERR
    je .err_no_overlap_ret
    call mb_reset
    lea rdi, [rip+s_no_overlap_pre]
    mov esi, OFFSET s_no_overlap_pre_len
    call mb_add
    mov edi, ebx
    call mb_add_type
    lea rdi, [rip+s_no_overlap_mid]
    mov esi, OFFSET s_no_overlap_mid_len
    call mb_add
    mov edi, r12d
    call mb_add_type
    lea rdi, [rip+s_no_overlap_post]
    mov esi, OFFSET s_no_overlap_post_len
    call mb_add
    mov edi, r13d
    mov esi, r14d
    mov edx, 2367
    call diag_msg
.err_no_overlap_ret:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_name(tok=rdi) -> TS2304
.globl err_name
err_name:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, dword ptr [rdi+TK_LINE]
    mov r12d, dword ptr [rdi+TK_COL]
    mov r13d, dword ptr [rdi+TK_OFF]
    mov r14d, dword ptr [rdi+TK_LEN]
    call mb_reset
    lea rdi, [rip+s_cannot_find_pre]
    mov esi, OFFSET s_cannot_find_pre_len
    call mb_add
    lea rdi, [rip+src_buf]
    add rdi, r13
    mov esi, r14d
    call mb_add_name
    mov edi, '.'
    call mb_add_char
    mov edi, ebx
    mov esi, r12d
    mov edx, 2304
    call diag_msg
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_redeclare(tok=rdi) -> TS2451
.globl err_redeclare
err_redeclare:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, dword ptr [rdi+TK_LINE]
    mov r12d, dword ptr [rdi+TK_COL]
    mov r13d, dword ptr [rdi+TK_OFF]
    mov r14d, dword ptr [rdi+TK_LEN]
    lea rdi, [rip+src_buf]
    add rdi, r13
    mov esi, r14d
    mov edx, ebx
    mov ecx, r12d
    call err_redeclare_at
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.globl err_redeclare_at
err_redeclare_at:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    call mb_reset
    lea rdi, [rip+s_redeclare_pre]
    mov esi, OFFSET s_redeclare_pre_len
    call mb_add
    mov rdi, rbx
    mov esi, r12d
    call mb_add_name
    mov edi, '.'
    call mb_add_char
    mov edi, r13d
    mov esi, r14d
    mov edx, 2451
    call diag_msg
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_dup_ident_at(name=rdi, len=esi, line=edx, col=ecx) -> TS2300
.globl err_dup_ident_at
err_dup_ident_at:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    call mb_reset
    lea rdi, [rip+s_dup_ident_pre]
    mov esi, OFFSET s_dup_ident_pre_len
    call mb_add
    mov rdi, rbx
    mov esi, r12d
    call mb_add_name
    mov edi, '.'
    call mb_add_char
    mov edi, r13d
    mov esi, r14d
    mov edx, 2300
    call diag_msg
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_dup_func_at(line=edi, col=esi) -> TS2393
.globl err_dup_func_at
err_dup_func_at:
    mov edx, 2393
    lea rcx, [rip+s_dup_func]
    mov r8d, OFFSET s_dup_func_len
    jmp diag

# err_dup_ident_pair(entry=rdi, curtok=rsi) -> TS2300 at both, source order
.globl err_dup_ident_pair
err_dup_ident_pair:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12, rsi
    mov r13d, dword ptr [rbx+SY_LINE]
    mov r14d, dword ptr [rbx+SY_COL]
    mov r15d, dword ptr [r12+TK_LINE]
    mov eax, dword ptr [r12+TK_COL]
    cmp r13d, r15d
    jb .err_dup_ident_pair_exist
    ja .err_dup_ident_pair_current
    cmp r14d, eax
    jbe .err_dup_ident_pair_exist
.err_dup_ident_pair_current:
    mov rdi, qword ptr [rbx+SY_NAME]
    mov esi, dword ptr [rbx+SY_NLEN]
    mov edx, r15d
    mov ecx, dword ptr [r12+TK_COL]
    call err_dup_ident_at
    mov rdi, qword ptr [rbx+SY_NAME]
    mov esi, dword ptr [rbx+SY_NLEN]
    mov edx, r13d
    mov ecx, r14d
    call err_dup_ident_at
    jmp .err_dup_ident_pair_done
.err_dup_ident_pair_exist:
    mov rdi, qword ptr [rbx+SY_NAME]
    mov esi, dword ptr [rbx+SY_NLEN]
    mov edx, r13d
    mov ecx, r14d
    call err_dup_ident_at
    mov rdi, qword ptr [rbx+SY_NAME]
    mov esi, dword ptr [rbx+SY_NLEN]
    mov edx, r15d
    mov ecx, dword ptr [r12+TK_COL]
    call err_dup_ident_at
.err_dup_ident_pair_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# err_assign_const(tok=rdi) -> TS2588
.globl err_assign_const
err_assign_const:
    push rbx
    push r12
    push r13
    push r14
    mov ebx, dword ptr [rdi+TK_LINE]
    mov r12d, dword ptr [rdi+TK_COL]
    mov r13d, dword ptr [rdi+TK_OFF]
    mov r14d, dword ptr [rdi+TK_LEN]
    call mb_reset
    lea rdi, [rip+s_assign_const_pre]
    mov esi, OFFSET s_assign_const_pre_len
    call mb_add
    lea rdi, [rip+src_buf]
    add rdi, r13
    mov esi, r14d
    call mb_add_name
    lea rdi, [rip+s_assign_const_post]
    mov esi, OFFSET s_assign_const_post_len
    call mb_add
    mov edi, ebx
    mov esi, r12d
    mov edx, 2588
    call diag_msg
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# Fixed-message helpers. All take line=edi, col=esi.
.globl err_semi_expected
err_semi_expected:
    mov edx, 1005
    lea rcx, [rip+s_expected_semi]
    mov r8d, OFFSET s_expected_semi_len
    jmp diag

.globl err_ident_expected
err_ident_expected:
    mov edx, 1003
    lea rcx, [rip+s_ident_expected]
    mov r8d, OFFSET s_ident_expected_len
    jmp diag

.globl err_expr_expected
err_expr_expected:
    mov edx, 1109
    lea rcx, [rip+s_expr_expected]
    mov r8d, OFFSET s_expr_expected_len
    jmp diag

.globl err_rbrace_expected
err_rbrace_expected:
    mov edx, 1005
    lea rcx, [rip+s_rbrace_expected]
    mov r8d, OFFSET s_rbrace_expected_len
    jmp diag

.globl err_rparen_expected
err_rparen_expected:
    mov edx, 1005
    lea rcx, [rip+s_rparen_expected]
    mov r8d, OFFSET s_rparen_expected_len
    jmp diag

.globl err_lparen_expected
err_lparen_expected:
    mov edx, 1005
    lea rcx, [rip+s_lparen_expected]
    mov r8d, OFFSET s_lparen_expected_len
    jmp diag

.globl err_colon_expected
err_colon_expected:
    mov edx, 1005
    lea rcx, [rip+s_colon_expected]
    mov r8d, OFFSET s_colon_expected_len
    jmp diag

.globl err_return_outside
err_return_outside:
    mov edx, 1108
    lea rcx, [rip+s_return_outside]
    mov r8d, OFFSET s_return_outside_len
    jmp diag

.globl err_const_init
err_const_init:
    mov edx, 1155
    lea rcx, [rip+s_const_init]
    mov r8d, OFFSET s_const_init_len
    jmp diag

.globl err_not_callable
err_not_callable:
    push rbx
    push r12
    push r13
    mov ebx, edi
    mov r12d, esi
    mov r13d, edx
    mov edi, ebx
    mov esi, r12d
    mov edx, 2349
    lea rcx, [rip+s_not_callable]
    mov r8d, OFFSET s_not_callable_len
    call diag
    mov edi, FD_STDOUT
    lea rsi, [rip+s_cap_pre]
    mov edx, OFFSET s_cap_pre_len
    call write_fd
    lea rsi, [rip+s_cap_error]
    mov edx, OFFSET s_cap_error_len
    cmp r13d, TY_NUM
    jne .err_not_callable_c1
    lea rsi, [rip+s_cap_number]
    mov edx, OFFSET s_cap_number_len
    jmp .err_not_callable_emit
.err_not_callable_c1:
    cmp r13d, TY_STR
    jne .err_not_callable_c2
    lea rsi, [rip+s_cap_string]
    mov edx, OFFSET s_cap_string_len
    jmp .err_not_callable_emit
.err_not_callable_c2:
    cmp r13d, TY_BOOL
    jne .err_not_callable_c3
    lea rsi, [rip+s_cap_boolean]
    mov edx, OFFSET s_cap_boolean_len
    jmp .err_not_callable_emit
.err_not_callable_c3:
    cmp r13d, TY_VOID
    jne .err_not_callable_emit
    lea rsi, [rip+s_cap_void]
    mov edx, OFFSET s_cap_void_len
.err_not_callable_emit:
    mov edi, FD_STDOUT
    call write_fd
    mov edi, FD_STDOUT
    lea rsi, [rip+s_cap_post]
    mov edx, OFFSET s_cap_post_len
    call write_fd
    pop r13
    pop r12
    pop rbx
    ret

.globl err_func_missing
err_func_missing:
    mov edx, 2391
    lea rcx, [rip+s_func_missing]
    mov r8d, OFFSET s_func_missing_len
    jmp diag

.globl err_arith_left
err_arith_left:
    mov edx, 2362
    lea rcx, [rip+s_arith_left]
    mov r8d, OFFSET s_arith_left_len
    jmp diag

.globl err_arith_right
err_arith_right:
    mov edx, 2363
    lea rcx, [rip+s_arith_right]
    mov r8d, OFFSET s_arith_right_len
    jmp diag
