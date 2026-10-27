.include "defs.inc"

.section .text

# write_fd(fd=edi, buf=rsi, len=edx)
.globl write_fd
write_fd:
    mov eax, SYS_WRITE
    syscall
    ret

# write_int_fd(fd=edi, value=esi)
.globl write_int_fd
write_int_fd:
    push rbx
    sub rsp, 32
    mov ebx, edi
    mov eax, esi
    lea rsi, [rsp+32]
    xor r9d, r9d
    test eax, eax
    jne .write_int_fd_loop
    dec rsi
    mov byte ptr [rsi], '0'
    inc r9d
    jmp .write_int_fd_emit
.write_int_fd_loop:
    xor edx, edx
    mov ecx, 10
    div ecx
    add dl, '0'
    dec rsi
    mov byte ptr [rsi], dl
    inc r9d
    test eax, eax
    jne .write_int_fd_loop
.write_int_fd_emit:
    mov edi, ebx
    mov edx, r9d
    call write_fd
    add rsp, 32
    pop rbx
    ret

# exit_now(code=edi)
.globl exit_now
exit_now:
    mov eax, SYS_EXIT
    syscall

# bytes_eq(a=rdi, b=rsi, len=edx) -> eax 0/1
# Clobbers only rax, r8, r9.
.globl bytes_eq
bytes_eq:
    xor eax, eax
    xor r8d, r8d
.bytes_eq_loop:
    cmp r8d, edx
    jae .bytes_eq_yes
    mov r9b, byte ptr [rdi+r8]
    cmp r9b, byte ptr [rsi+r8]
    jne .bytes_eq_no
    inc r8d
    jmp .bytes_eq_loop
.bytes_eq_yes:
    mov eax, 1
.bytes_eq_no:
    ret

# type_name(type=edi) -> rax ptr, edx len
.globl type_name
type_name:
    cmp edi, TY_NUM
    je .type_name_num
    cmp edi, TY_STR
    je .type_name_str
    cmp edi, TY_BOOL
    je .type_name_bool
    cmp edi, TY_VOID
    je .type_name_void
    cmp edi, TY_ANY
    je .type_name_any
    cmp edi, TY_FUNC
    je .type_name_func
    lea rax, [rip+s_type_error]
    mov edx, OFFSET s_type_error_len
    ret
.type_name_num:
    lea rax, [rip+s_type_number]
    mov edx, OFFSET s_type_number_len
    ret
.type_name_str:
    lea rax, [rip+s_type_string]
    mov edx, OFFSET s_type_string_len
    ret
.type_name_bool:
    lea rax, [rip+s_type_boolean]
    mov edx, OFFSET s_type_boolean_len
    ret
.type_name_void:
    lea rax, [rip+s_type_void]
    mov edx, OFFSET s_type_void_len
    ret
.type_name_any:
    lea rax, [rip+s_type_any]
    mov edx, OFFSET s_type_any_len
    ret
.type_name_func:
    lea rax, [rip+s_type_function]
    mov edx, OFFSET s_type_function_len
    ret

# --- message buffer ---------------------------------------------------------
.globl mb_reset
mb_reset:
    mov dword ptr [rip+msg_len], 0
    ret

# mb_add(ptr=rdi, len=esi)
.globl mb_add
mb_add:
    mov eax, dword ptr [rip+msg_len]
    mov ecx, MSG_MAX
    sub ecx, esi
    jle .mb_add_full
    cmp eax, ecx
    jbe .mb_add_ok
    mov esi, ecx
    jmp .mb_add_ok
.mb_add_full:
    ret
.mb_add_ok:
    lea r8, [rip+msg_buf]
    add r8, rax
    xor r9d, r9d
.mb_add_loop:
    cmp r9d, esi
    jae .mb_add_done
    mov r10b, byte ptr [rdi+r9]
    mov byte ptr [r8+r9], r10b
    inc r9d
    jmp .mb_add_loop
.mb_add_done:
    add dword ptr [rip+msg_len], esi
    ret

# mb_add_char(ch=dil)
.globl mb_add_char
mb_add_char:
    mov eax, dword ptr [rip+msg_len]
    cmp eax, MSG_MAX
    jae .mb_add_char_ret
    lea rdx, [rip+msg_buf]
    mov byte ptr [rdx+rax], dil
    inc eax
    mov dword ptr [rip+msg_len], eax
.mb_add_char_ret:
    ret

# mb_add_uint(value=edi)
.globl mb_add_uint
mb_add_uint:
    push rbx
    sub rsp, 32
    mov eax, edi
    lea rsi, [rsp+32]
    xor ebx, ebx
    test eax, eax
    jne .mb_add_uint_loop
    dec rsi
    mov byte ptr [rsi], '0'
    inc ebx
    jmp .mb_add_uint_emit
.mb_add_uint_loop:
    xor edx, edx
    mov ecx, 10
    div ecx
    add dl, '0'
    dec rsi
    mov byte ptr [rsi], dl
    inc ebx
    test eax, eax
    jne .mb_add_uint_loop
.mb_add_uint_emit:
    mov rdi, rsi
    mov esi, ebx
    call mb_add
    add rsp, 32
    pop rbx
    ret

# mb_add_type(type=edi) -> 'number'
.globl mb_add_type
mb_add_type:
    push rbx
    mov ebx, edi
    mov edi, '\''
    call mb_add_char
    mov edi, ebx
    call type_name
    mov rdi, rax
    mov esi, edx
    call mb_add
    mov edi, '\''
    call mb_add_char
    pop rbx
    ret

# mb_add_name(ptr=rdi, len=esi) -> 'name'
.globl mb_add_name
mb_add_name:
    push rbx
    push r12
    mov rbx, rdi
    mov r12d, esi
    mov edi, '\''
    call mb_add_char
    mov rdi, rbx
    mov esi, r12d
    call mb_add
    mov edi, '\''
    call mb_add_char
    pop r12
    pop rbx
    ret

# --- diagnostics ------------------------------------------------------------
# diag(line=edi, col=esi, code=edx, msg=rcx, len=r8d)
.globl diag
diag:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov r15, rcx
    mov rbx, r8

    mov edi, FD_STDOUT
    mov rsi, qword ptr [rip+file_ptr]
    mov edx, dword ptr [rip+file_len]
    call write_fd

    mov edi, FD_STDOUT
    lea rsi, [rip+s_open_paren]
    mov edx, 1
    call write_fd

    mov edi, FD_STDOUT
    mov esi, r12d
    call write_int_fd

    mov edi, FD_STDOUT
    lea rsi, [rip+s_comma]
    mov edx, 1
    call write_fd

    mov edi, FD_STDOUT
    mov esi, r13d
    call write_int_fd

    mov edi, FD_STDOUT
    lea rsi, [rip+s_diag_prefix]
    mov edx, OFFSET s_diag_prefix_len
    call write_fd

    mov edi, FD_STDOUT
    mov esi, r14d
    call write_int_fd

    mov edi, FD_STDOUT
    lea rsi, [rip+s_colon_space]
    mov edx, OFFSET s_colon_space_len
    call write_fd

    mov edi, FD_STDOUT
    mov rsi, r15
    mov edx, ebx
    call write_fd

    mov edi, FD_STDOUT
    lea rsi, [rip+s_newline]
    mov edx, 1
    call write_fd

    mov dword ptr [rip+has_error], 1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# diag_msg(line=edi, col=esi, code=edx) uses msg_buf/msg_len
.globl diag_msg
diag_msg:
    mov ecx, dword ptr [rip+msg_len]
    mov r8d, ecx
    lea rcx, [rip+msg_buf]
    jmp diag

# fatal_diag(line=edi, col=esi, code=edx, msg=rcx, len=r8d)
.globl fatal_diag
fatal_diag:
    call diag
    mov edi, 2
    jmp exit_now

# --- output -----------------------------------------------------------------
# emit_str(ptr=rdi, len=esi)
.globl emit_str
emit_str:
    mov eax, dword ptr [rip+out_len]
    mov ecx, OUT_MAX
    sub ecx, esi
    jle .emit_str_full
    cmp eax, ecx
    jbe .emit_str_ok
    mov esi, ecx
    jmp .emit_str_ok
.emit_str_full:
    ret
.emit_str_ok:
    lea r8, [rip+out_buf]
    add r8, rax
    xor r9d, r9d
.emit_str_loop:
    cmp r9d, esi
    jae .emit_str_done
    mov r10b, byte ptr [rdi+r9]
    mov byte ptr [r8+r9], r10b
    inc r9d
    jmp .emit_str_loop
.emit_str_done:
    add dword ptr [rip+out_len], esi
    ret

# emit_char(ch=dil)
.globl emit_char
emit_char:
    mov eax, dword ptr [rip+out_len]
    cmp eax, OUT_MAX
    jae .emit_char_ret
    lea rdx, [rip+out_buf]
    mov byte ptr [rdx+rax], dil
    inc eax
    mov dword ptr [rip+out_len], eax
.emit_char_ret:
    ret

# emit_span(start=edi, end=esi) copies source bytes
.globl emit_span
emit_span:
    mov eax, edi
    mov edx, esi
    sub edx, eax
    jbe .emit_span_ret
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, edx
    jmp emit_str
.emit_span_ret:
    ret

# emit_tok(tokptr=rdi)
.globl emit_tok
emit_tok:
    mov eax, dword ptr [rdi+TK_OFF]
    mov ecx, dword ptr [rdi+TK_LEN]
    lea rdi, [rip+src_buf]
    add rdi, rax
    mov esi, ecx
    jmp emit_str
