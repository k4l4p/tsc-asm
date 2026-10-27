.include "defs.inc"

.section .rodata
usage_msg: .ascii "usage: tsc-asm [--noEmit] [--tokens] <file.ts>\n"
usage_len = . - usage_msg
open_err_msg: .ascii "tsc-asm: cannot read input file\n"
open_err_len = . - open_err_msg
write_err_msg: .ascii "tsc-asm: cannot write output file\n"
write_err_len = . - write_err_msg
too_large_msg: .ascii "tsc-asm: input file too large\n"
too_large_len = . - too_large_msg
opt_noemit: .ascii "--noEmit"
opt_noemit_len = . - opt_noemit
opt_tokens: .ascii "--tokens"
opt_tokens_len = . - opt_tokens
ext_ts: .ascii ".ts"
ext_js: .ascii ".js"

.section .text

# str_len(cstr=rdi) -> eax
str_len:
    xor eax, eax
.str_len_loop:
    cmp byte ptr [rdi+rax], 0
    je .str_len_done
    inc eax
    jmp .str_len_loop
.str_len_done:
    ret

# usage_exit()
usage_exit:
    mov edi, FD_STDERR
    lea rsi, [rip+usage_msg]
    mov edx, usage_len
    call write_fd
    mov edi, 2
    jmp exit_now

# dump_tokens_to_stdout()
dump_tokens_to_stdout:
    push rbx
    push r12
    mov r12d, 0
.dump_tokens_to_stdout_loop:
    cmp r12d, dword ptr [rip+tok_count]
    jae .dump_tokens_to_stdout_done
    mov edi, r12d
    call tok_ptr
    mov rbx, rax

    mov edi, FD_STDOUT
    mov esi, dword ptr [rbx+TK_LINE]
    call write_int_fd
    mov edi, FD_STDOUT
    lea rsi, [rip+s_colon]
    mov edx, 1
    call write_fd
    mov edi, FD_STDOUT
    mov esi, dword ptr [rbx+TK_COL]
    call write_int_fd
    mov edi, FD_STDOUT
    lea rsi, [rip+s_space]
    mov edx, 1
    call write_fd

    mov eax, dword ptr [rbx+TK_KIND]
    shl rax, 3
    lea rdx, [rip+token_names]
    mov rdi, qword ptr [rdx+rax]
    call str_len
    mov edx, eax
    mov eax, dword ptr [rbx+TK_KIND]
    shl rax, 3
    lea rcx, [rip+token_names]
    mov rsi, qword ptr [rcx+rax]
    mov edi, FD_STDOUT
    call write_fd

    cmp dword ptr [rbx+TK_LEN], 0
    je .dump_tokens_to_stdout_no_text
    mov edi, FD_STDOUT
    lea rsi, [rip+s_space]
    mov edx, 1
    call write_fd
    mov edi, FD_STDOUT
    lea rsi, [rip+src_buf]
    mov eax, dword ptr [rbx+TK_OFF]
    add rsi, rax
    mov edx, dword ptr [rbx+TK_LEN]
    call write_fd
.dump_tokens_to_stdout_no_text:
    mov edi, FD_STDOUT
    lea rsi, [rip+s_newline]
    mov edx, 1
    call write_fd
    inc r12d
    jmp .dump_tokens_to_stdout_loop
.dump_tokens_to_stdout_done:
    pop r12
    pop rbx
    ret

# write_output_file()
write_output_file:
    push rbx
    push r12
    push r13
    # copy input name
    mov rcx, 0
    mov ecx, dword ptr [rip+file_len]
    cmp ecx, 4000
    jae .write_output_file_too_large
    lea rsi, [rip+file_ptr]
    mov rsi, qword ptr [rsi]
    lea rdi, [rip+out_name]
    push rcx
    rep movsb
    pop rcx
    lea rdx, [rip+out_name]
    mov dword ptr [rip+out_name_len], ecx
    # replace .ts suffix with .js, else append .js
    cmp ecx, 3
    jb .write_output_file_append
    mov eax, ecx
    sub eax, 3
    lea rdx, [rip+out_name]
    add rdx, rax
    cmp byte ptr [rdx], '.'
    jne .write_output_file_append
    cmp byte ptr [rdx+1], 't'
    jne .write_output_file_append
    cmp byte ptr [rdx+2], 's'
    jne .write_output_file_append
    mov byte ptr [rdx], '.'
    mov byte ptr [rdx+1], 'j'
    mov byte ptr [rdx+2], 's'
    jmp .write_output_file_terminate
.write_output_file_append:
    lea rdx, [rip+out_name]
    add rdx, rcx
    mov byte ptr [rdx], '.'
    mov byte ptr [rdx+1], 'j'
    mov byte ptr [rdx+2], 's'
    add ecx, 3
    mov dword ptr [rip+out_name_len], ecx
.write_output_file_terminate:
    lea rdx, [rip+out_name]
    mov eax, dword ptr [rip+out_name_len]
    mov byte ptr [rdx+rax], 0
    # open
    mov eax, SYS_OPEN
    mov rdi, rdx
    mov esi, O_WRONLY | O_CREAT | O_TRUNC
    mov edx, 420
    syscall
    test rax, rax
    js .write_output_file_open_fail
    mov r12, rax
    # write loop
    xor r13d, r13d
.write_output_file_wloop:
    mov eax, dword ptr [rip+out_len]
    cmp r13d, eax
    jae .write_output_file_wdone
    mov eax, SYS_WRITE
    mov edi, r12d
    lea rsi, [rip+out_buf]
    add rsi, r13
    mov edx, dword ptr [rip+out_len]
    sub edx, r13d
    syscall
    test rax, rax
    jle .write_output_file_write_fail
    add r13, rax
    jmp .write_output_file_wloop
.write_output_file_wdone:
    mov eax, SYS_CLOSE
    mov edi, r12d
    syscall
    pop r13
    pop r12
    pop rbx
    ret
.write_output_file_open_fail:
    mov edi, FD_STDERR
    lea rsi, [rip+open_err_msg]
    mov edx, open_err_len
    call write_fd
    mov edi, 2
    jmp exit_now
.write_output_file_write_fail:
    mov edi, FD_STDERR
    lea rsi, [rip+write_err_msg]
    mov edx, write_err_len
    call write_fd
    mov edi, 2
    jmp exit_now
.write_output_file_too_large:
    mov edi, FD_STDERR
    lea rsi, [rip+too_large_msg]
    mov edx, too_large_len
    call write_fd
    mov edi, 2
    jmp exit_now

.globl _start
_start:
    mov r13, qword ptr [rsp]        # argc
    lea r14, [rsp+8]                # argv
    mov r12, 1                      # index
    xor ebx, ebx                    # input pointer
._start_arg_loop:
    cmp r12, r13
    jae ._start_args_done
    mov r15, qword ptr [r14+r12*8]  # arg
    mov rdi, r15
    call str_len
    mov ebp, eax                    # length
    cmp ebp, opt_noemit_len
    jne ._start_chk_tokens
    mov rdi, r15
    lea rsi, [rip+opt_noemit]
    mov edx, opt_noemit_len
    call bytes_eq
    test eax, eax
    je ._start_chk_tokens
    mov dword ptr [rip+no_emit], 1
    jmp ._start_next_arg
._start_chk_tokens:
    cmp ebp, opt_tokens_len
    jne ._start_chk_input
    mov rdi, r15
    lea rsi, [rip+opt_tokens]
    mov edx, opt_tokens_len
    call bytes_eq
    test eax, eax
    je ._start_chk_input
    mov dword ptr [rip+dump_tokens], 1
    jmp ._start_next_arg
._start_chk_input:
    cmp byte ptr [r15], '-'
    je ._start_usage
    test rbx, rbx
    jne ._start_usage
    mov rbx, r15
._start_next_arg:
    inc r12
    jmp ._start_arg_loop
._start_args_done:
    test rbx, rbx
    je ._start_usage

    mov qword ptr [rip+file_ptr], rbx
    mov rdi, rbx
    call str_len
    mov dword ptr [rip+file_len], eax

    # open input
    mov eax, SYS_OPEN
    mov rdi, rbx
    xor esi, esi
    xor edx, edx
    syscall
    test rax, rax
    js ._start_open_fail
    mov r15, rax                    # fd
    xor r14d, r14d                  # total
._start_read_loop:
    mov eax, SYS_READ
    mov edi, r15d
    lea rsi, [rip+src_buf]
    add rsi, r14
    mov edx, SRC_MAX
    sub edx, r14d
    syscall
    test rax, rax
    js ._start_open_fail
    je ._start_read_done
    add r14, rax
    cmp r14d, SRC_MAX
    jb ._start_read_loop
    # exactly full: probe for more bytes
    mov eax, SYS_READ
    mov edi, r15d
    lea rsi, [rip+msg_buf]
    mov edx, 1
    syscall
    test rax, rax
    jg ._start_too_large
._start_read_done:
    mov dword ptr [rip+src_len], r14d
    mov eax, SYS_CLOSE
    mov edi, r15d
    syscall

    call lex_all
    cmp dword ptr [rip+dump_tokens], 0
    jne ._start_do_dump

    call parse_program
    cmp dword ptr [rip+no_emit], 0
    je ._start_emit
    jmp ._start_exit
._start_emit:
    call write_output_file
    jmp ._start_exit
._start_do_dump:
    call dump_tokens_to_stdout
    xor edi, edi
    jmp exit_now
._start_usage:
    jmp usage_exit
._start_open_fail:
    mov edi, FD_STDERR
    lea rsi, [rip+open_err_msg]
    mov edx, open_err_len
    call write_fd
    mov edi, 2
    jmp exit_now
._start_too_large:
    mov edi, FD_STDERR
    lea rsi, [rip+too_large_msg]
    mov edx, too_large_len
    call write_fd
    mov edi, 2
    jmp exit_now
._start_exit:
    mov edi, 0
    cmp dword ptr [rip+has_error], 0
    je ._start_do_exit
    mov edi, 2
._start_do_exit:
    jmp exit_now
