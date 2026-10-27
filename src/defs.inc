.intel_syntax noprefix
# Shared constants for tsc-asm.
# Token kinds
.equ T_EOF,      0
.equ T_IDENT,    1
.equ T_NUM,      2
.equ T_STR,      3
.equ T_LET,      4
.equ T_CONST,    5
.equ T_VAR,      6
.equ T_FUNCTION, 7
.equ T_RETURN,   8
.equ T_IF,       9
.equ T_ELSE,     10
.equ T_TRUE,     11
.equ T_FALSE,    12
.equ T_COLON,    13
.equ T_SEMI,     14
.equ T_COMMA,    15
.equ T_LPAREN,   16
.equ T_RPAREN,   17
.equ T_LBRACE,   18
.equ T_RBRACE,   19
.equ T_ASSIGN,   20
.equ T_PLUS,     21
.equ T_MINUS,    22
.equ T_STAR,     23
.equ T_SLASH,    24
.equ T_PERCENT,  25
.equ T_EQ3,      26
.equ T_NEQ3,     27
.equ T_LT,       28
.equ T_GT,       29
.equ T_LE,       30
.equ T_GE,       31
.equ T_BANG,     32
.equ T_ANDAND,   33
.equ T_OROR,     34
.equ T_EQ2,      35
.equ T_NEQ2,     36
.equ T_DOT,      37

# Token layout (24 bytes)
.equ TK_KIND, 0
.equ TK_OFF,  4
.equ TK_LEN,  8
.equ TK_LINE, 12
.equ TK_COL,  16
.equ TK_VAL,  20
.equ TK_SIZE, 24

# Types
.equ TY_NUM,  0
.equ TY_STR,  1
.equ TY_BOOL, 2
.equ TY_VOID, 3
.equ TY_ANY,  4
.equ TY_FUNC, 5
.equ TY_ERR,  6

# Symbol kinds
.equ SK_VAR,   0
.equ SK_PARAM, 1
.equ SK_FUNC,  2
.equ SK_CONST, 3

# Symbol layout (52 bytes)
.equ SY_NAME,   0
.equ SY_NLEN,   8
.equ SY_TYPE,   12
.equ SY_KIND,   16
.equ SY_ARITY,  20
.equ SY_PARAMS, 24
.equ SY_RET,    28
.equ SY_LINE,   32
.equ SY_COL,    36
.equ SY_NEXT,   40
.equ SY_ALIVE,  44
.equ SY_DUP,    48
.equ SY_SIZE,   52

# Syscalls
.equ SYS_READ,  0
.equ SYS_WRITE, 1
.equ SYS_OPEN,  2
.equ SYS_CLOSE, 3
.equ SYS_EXIT,  60
.equ FD_STDOUT, 1
.equ FD_STDERR, 2
.equ O_RDONLY,  0
.equ O_WRONLY,  1
.equ O_CREAT,   64
.equ O_TRUNC,   512

# Capacities
.equ SRC_MAX,   4194304
.equ TOK_MAX,   2097152
.equ SYM_MAX,   262144
.equ PARAM_MAX, 262144
.equ SCOPE_MAX, 1024
.equ OUT_MAX,   8388608
.equ MSG_MAX,   512
.equ HASH_BITS,  16
.equ HASH_BUCKETS, 65536
.equ HASH_MASK, 65535
