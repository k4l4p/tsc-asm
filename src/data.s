.include "defs.inc"

# Mutable compiler state.
.section .data
.balign 8
.globl src_len, tok_count, tok_pos, sym_count, scope_depth, scope_base
.globl param_count, has_error, out_len, cur_ret, in_func
.globl no_emit, dump_tokens, file_ptr, file_len
src_len:      .long 0
tok_count:    .long 0
tok_pos:      .long 0
sym_count:    .long 0
scope_depth:  .long 0
scope_base:   .long 0
param_count:  .long 0
has_error:    .long 0
out_len:      .long 0
cur_ret:      .long TY_VOID
in_func:      .long 0
no_emit:      .long 0
dump_tokens:  .long 0
file_ptr:     .quad 0
file_len:     .long 0

# Storage. BSS keeps the binary small.
.section .bss
.balign 16
.globl src_buf, tok_buf, sym_buf, param_pool, scope_stack
.globl out_buf, msg_buf, msg_len, out_name, out_name_len, hash_buckets
src_buf:     .skip SRC_MAX
tok_buf:     .skip TOK_MAX * TK_SIZE
sym_buf:     .skip SYM_MAX * SY_SIZE
param_pool:  .skip PARAM_MAX * 4
scope_stack: .skip SCOPE_MAX * 4
out_buf:     .skip OUT_MAX
msg_buf:     .skip MSG_MAX
msg_len:     .skip 4
hash_buckets: .skip HASH_BUCKETS * 4
out_name:    .skip 4096
out_name_len: .skip 4
