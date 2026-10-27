.include "defs.inc"

.section .text

# sym_hash(name=rdi, len=esi) -> eax bucket. FNV-1a.
.globl sym_hash
sym_hash:
    mov eax, 2166136261
    xor ecx, ecx
.sym_hash_loop:
    cmp ecx, esi
    jae .sym_hash_done
    movzx edx, byte ptr [rdi+rcx]
    xor eax, edx
    imul eax, eax, 16777619
    inc ecx
    jmp .sym_hash_loop
.sym_hash_done:
    and eax, HASH_MASK
    ret

# sym_add(name=rdi, len=esi, type=edx, kind=ecx, line=r8d, col=r9d) -> index rax
.globl sym_add
sym_add:
    mov r10d, r8d
    mov r11d, r9d
    mov r8d, dword ptr [rip+sym_count]
    cmp r8d, SYM_MAX
    jae .sym_add_overflow
    mov eax, r8d
    imul rax, rax, SY_SIZE
    lea r9, [rip+sym_buf]
    add r9, rax
    mov qword ptr [r9+SY_NAME], rdi
    mov dword ptr [r9+SY_NLEN], esi
    mov dword ptr [r9+SY_TYPE], edx
    mov dword ptr [r9+SY_KIND], ecx
    mov dword ptr [r9+SY_LINE], r10d
    mov dword ptr [r9+SY_COL], r11d
    mov dword ptr [r9+SY_ARITY], 0
    mov dword ptr [r9+SY_PARAMS], 0
    mov dword ptr [r9+SY_RET], TY_ANY
    mov dword ptr [r9+SY_ALIVE], 1
    mov dword ptr [r9+SY_DUP], 0
    call sym_hash
    lea rcx, [rip+hash_buckets]
    mov edx, dword ptr [rcx+rax*4]
    mov dword ptr [r9+SY_NEXT], edx
    mov dword ptr [rcx+rax*4], r8d
    inc dword ptr [rip+sym_count]
    mov eax, r8d
    ret
.sym_add_overflow:
    mov edi, 1
    jmp exit_now

# sym_lookup(name=rdi, len=esi) -> index or -1
.globl sym_lookup
sym_lookup:
    xor edx, edx
    jmp sym_lookup_range

# sym_find_in_scope(name=rdi, len=esi) -> index or -1
.globl sym_find_in_scope
sym_find_in_scope:
    mov edx, dword ptr [rip+scope_base]
    jmp sym_lookup_range

# sym_lookup_range(name=rdi, len=esi, low=edx) -> index or -1
# Walks the hash chain newest-first and skips dead symbols below low.
.globl sym_lookup_range
sym_lookup_range:
    push rbx
    push r12
    push r13
    push r14
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    call sym_hash
    lea rdx, [rip+hash_buckets]
    mov r14d, dword ptr [rdx+rax*4]
.sym_lookup_range_loop:
    cmp r14d, -1
    je .sym_lookup_range_none
    cmp r14d, r13d
    jl .sym_lookup_range_none
    mov eax, r14d
    imul rax, rax, SY_SIZE
    lea rdx, [rip+sym_buf]
    add rdx, rax
    cmp dword ptr [rdx+SY_ALIVE], 0
    je .sym_lookup_range_next
    cmp dword ptr [rdx+SY_NLEN], r12d
    jne .sym_lookup_range_next
    mov r8, qword ptr [rdx+SY_NAME]
    xor r9d, r9d
.sym_lookup_range_cmp:
    cmp r9d, r12d
    jae .sym_lookup_range_found
    mov al, byte ptr [rbx+r9]
    cmp al, byte ptr [r8+r9]
    jne .sym_lookup_range_next
    inc r9d
    jmp .sym_lookup_range_cmp
.sym_lookup_range_found:
    mov eax, r14d
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.sym_lookup_range_next:
    mov r14d, dword ptr [rdx+SY_NEXT]
    jmp .sym_lookup_range_loop
.sym_lookup_range_none:
    mov eax, -1
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# sym_lookup_func_pos(name=rdi, len=esi, line=edx, col=ecx) -> index or -1
.globl sym_lookup_func_pos
sym_lookup_func_pos:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    call sym_hash
    lea rdx, [rip+hash_buckets]
    mov r15d, dword ptr [rdx+rax*4]
.sym_lookup_func_pos_loop:
    cmp r15d, -1
    je .sym_lookup_func_pos_none
    mov eax, r15d
    imul rax, rax, SY_SIZE
    lea rdx, [rip+sym_buf]
    add rdx, rax
    cmp dword ptr [rdx+SY_ALIVE], 0
    je .sym_lookup_func_pos_next
    cmp dword ptr [rdx+SY_KIND], SK_FUNC
    jne .sym_lookup_func_pos_next
    cmp dword ptr [rdx+SY_LINE], r13d
    jne .sym_lookup_func_pos_next
    cmp dword ptr [rdx+SY_COL], r14d
    jne .sym_lookup_func_pos_next
    cmp dword ptr [rdx+SY_NLEN], r12d
    jne .sym_lookup_func_pos_next
    mov r8, qword ptr [rdx+SY_NAME]
    xor r9d, r9d
.sym_lookup_func_pos_cmp:
    cmp r9d, r12d
    jae .sym_lookup_func_pos_found
    mov al, byte ptr [rbx+r9]
    cmp al, byte ptr [r8+r9]
    jne .sym_lookup_func_pos_next
    inc r9d
    jmp .sym_lookup_func_pos_cmp
.sym_lookup_func_pos_found:
    mov eax, r15d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
.sym_lookup_func_pos_next:
    mov r15d, dword ptr [rdx+SY_NEXT]
    jmp .sym_lookup_func_pos_loop
.sym_lookup_func_pos_none:
    mov eax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# sym_count_funcs(name=rdi, len=esi, low=edx) -> eax, saturates at 2
.globl sym_count_funcs
sym_count_funcs:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r15d, edx
    call sym_hash
    lea rdx, [rip+hash_buckets]
    mov r13d, dword ptr [rdx+rax*4]
    xor r14d, r14d
.sym_count_funcs_loop:
    cmp r13d, -1
    je .sym_count_funcs_done
    cmp r13d, r15d
    jl .sym_count_funcs_done
    mov eax, r13d
    imul rax, rax, SY_SIZE
    lea rdx, [rip+sym_buf]
    add rdx, rax
    cmp dword ptr [rdx+SY_ALIVE], 0
    je .sym_count_funcs_next
    cmp dword ptr [rdx+SY_KIND], SK_FUNC
    jne .sym_count_funcs_next
    cmp dword ptr [rdx+SY_NLEN], r12d
    jne .sym_count_funcs_next
    mov r8, qword ptr [rdx+SY_NAME]
    xor r9d, r9d
.sym_count_funcs_cmp:
    cmp r9d, r12d
    jae .sym_count_funcs_match
    mov al, byte ptr [rbx+r9]
    cmp al, byte ptr [r8+r9]
    jne .sym_count_funcs_next
    inc r9d
    jmp .sym_count_funcs_cmp
.sym_count_funcs_match:
    inc r14d
    cmp r14d, 2
    jae .sym_count_funcs_done
.sym_count_funcs_next:
    mov r13d, dword ptr [rdx+SY_NEXT]
    jmp .sym_count_funcs_loop
.sym_count_funcs_done:
    mov eax, r14d
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# sym_mark_dup_funcs(name=rdi, len=esi, low=edx) -> report each same-scope
# duplicate function implementation once, in declaration order.
.globl sym_mark_dup_funcs
sym_mark_dup_funcs:
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbx, rdi
    mov r12d, esi
    mov r13d, edx
    mov r14d, edx
.sym_mark_dup_funcs_loop:
    cmp r14d, dword ptr [rip+sym_count]
    jae .sym_mark_dup_funcs_done
    mov eax, r14d
    imul rax, rax, SY_SIZE
    lea r15, [rip+sym_buf]
    add r15, rax
    cmp dword ptr [r15+SY_ALIVE], 0
    je .sym_mark_dup_funcs_next
    cmp dword ptr [r15+SY_KIND], SK_FUNC
    jne .sym_mark_dup_funcs_next
    cmp dword ptr [r15+SY_DUP], 0
    jne .sym_mark_dup_funcs_next
    cmp dword ptr [r15+SY_NLEN], r12d
    jne .sym_mark_dup_funcs_next
    mov r8, qword ptr [r15+SY_NAME]
    xor r9d, r9d
.sym_mark_dup_funcs_cmp:
    cmp r9d, r12d
    jae .sym_mark_dup_funcs_match
    mov al, byte ptr [rbx+r9]
    cmp al, byte ptr [r8+r9]
    jne .sym_mark_dup_funcs_next
    inc r9d
    jmp .sym_mark_dup_funcs_cmp
.sym_mark_dup_funcs_match:
    mov dword ptr [r15+SY_DUP], 1
    mov edi, dword ptr [r15+SY_LINE]
    mov esi, dword ptr [r15+SY_COL]
    call err_dup_func_at
.sym_mark_dup_funcs_next:
    inc r14d
    jmp .sym_mark_dup_funcs_loop
.sym_mark_dup_funcs_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

# sym_set_func(index=edi, arity=esi, params_off=edx, ret=ecx)
.globl sym_set_func
sym_set_func:
    mov eax, edi
    imul rax, rax, SY_SIZE
    lea r8, [rip+sym_buf]
    add r8, rax
    mov dword ptr [r8+SY_ARITY], esi
    mov dword ptr [r8+SY_PARAMS], edx
    mov dword ptr [r8+SY_RET], ecx
    mov dword ptr [r8+SY_TYPE], TY_FUNC
    mov dword ptr [r8+SY_KIND], SK_FUNC
    ret

# sym_add_param(type=edi) -> offset eax
.globl sym_add_param
sym_add_param:
    mov eax, dword ptr [rip+param_count]
    cmp eax, PARAM_MAX
    jae .sym_add_param_overflow
    lea r8, [rip+param_pool]
    mov dword ptr [r8+rax*4], edi
    lea edx, [rax+1]
    mov dword ptr [rip+param_count], edx
    ret
.sym_add_param_overflow:
    mov edi, 1
    jmp exit_now

# scope_push()
.globl scope_push
scope_push:
    mov eax, dword ptr [rip+sym_count]
    mov ecx, dword ptr [rip+scope_depth]
    cmp ecx, SCOPE_MAX
    jae .scope_push_overflow
    lea rdx, [rip+scope_stack]
    mov dword ptr [rdx+rcx*4], eax
    inc ecx
    mov dword ptr [rip+scope_depth], ecx
    mov dword ptr [rip+scope_base], eax
    ret
.scope_push_overflow:
    mov edi, 1
    jmp exit_now

# scope_pop()
.globl scope_pop
scope_pop:
    mov ecx, dword ptr [rip+scope_depth]
    dec ecx
    mov dword ptr [rip+scope_depth], ecx
    lea rdx, [rip+scope_stack]
    mov eax, dword ptr [rdx+rcx*4]
    mov r8d, dword ptr [rip+sym_count]
.scope_pop_mark:
    cmp eax, r8d
    jae .scope_pop_marked
    mov r9d, eax
    imul r9, r9, SY_SIZE
    lea r10, [rip+sym_buf]
    add r9, r10
    mov dword ptr [r9+SY_ALIVE], 0
    inc eax
    jmp .scope_pop_mark
.scope_pop_marked:
    test ecx, ecx
    je .scope_pop_top
    mov eax, dword ptr [rdx+rcx*4-4]
    mov dword ptr [rip+scope_base], eax
    ret
.scope_pop_top:
    mov dword ptr [rip+scope_base], 0
    ret
