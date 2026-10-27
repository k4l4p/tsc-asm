.include "defs.inc"

.globl s_quote
.globl s_type_prefix
.globl s_not_assign
.globl s_arg_prefix
.globl s_arg_mid
.globl s_cannot_find_pre
.globl s_period
.globl s_expected_semi
.globl s_ident_expected
.globl s_expr_expected
.globl s_rbrace_expected
.globl s_rparen_expected
.globl s_lparen_expected
.globl s_colon_expected
.globl s_arith_left
.globl s_arith_right
.globl s_no_overlap_pre
.globl s_no_overlap_mid
.globl s_no_overlap_post
.globl s_operator_pre
.globl s_operator_mid
.globl s_and
.globl s_expected_arg_pre
.globl s_expected_arg_mid
.globl s_expected_arg_post
.globl s_return_outside
.globl s_const_init
.globl s_dup_ident_pre
.globl s_dup_ident_pre_len
.globl s_dup_func
.globl s_dup_func_len
.globl s_redeclare_pre
.globl s_assign_const_pre
.globl s_assign_const_post
.globl s_func_missing
.globl s_func_missing_len
.globl s_not_callable
.globl s_cap_pre
.globl s_cap_pre_len
.globl s_cap_number
.globl s_cap_number_len
.globl s_cap_string
.globl s_cap_string_len
.globl s_cap_boolean
.globl s_cap_boolean_len
.globl s_cap_void
.globl s_cap_void_len
.globl s_cap_error
.globl s_cap_error_len
.globl s_cap_post
.globl s_cap_post_len
.globl s_unterminated_str
.globl s_unterminated_comment
.globl s_invalid_char
.globl s_diag_prefix
.globl s_colon_space
.globl s_type_number
.globl s_type_string
.globl s_type_boolean
.globl s_type_void
.globl s_type_any
.globl s_type_function
.globl s_type_error
.globl s_open_paren
.globl s_comma
.globl s_close_paren
.globl s_colon
.globl s_semi
.globl s_newline
.globl s_space
.globl s_arrow
.globl s_console
.globl s_log
.globl s_function_kw
.globl s_space_eq
.globl s_space_lparen
.globl s_rparen_space
.globl s_rparen_brace_nl
.globl s_if_open
.globl s_else
.globl s_return
.globl s_return_bare
.globl s_lbrace_nl
.globl s_rbrace_nl
.globl s_semi_nl
.globl s_equals
.globl s_type_expected
.globl token_names
.globl s_tok_eof
.globl s_tok_ident
.globl s_tok_num
.globl s_tok_str
.globl s_tok_let
.globl s_tok_const
.globl s_tok_var
.globl s_tok_function
.globl s_tok_return
.globl s_tok_if
.globl s_tok_else
.globl s_tok_true
.globl s_tok_false
.globl s_tok_colon2
.globl s_tok_semi
.globl s_tok_comma
.globl s_tok_lparen
.globl s_tok_rparen
.globl s_tok_lbrace
.globl s_tok_rbrace
.globl s_tok_assign
.globl s_tok_plus
.globl s_tok_minus
.globl s_tok_star
.globl s_tok_slash
.globl s_tok_percent
.globl s_tok_eq3
.globl s_tok_neq3
.globl s_tok_lt
.globl s_tok_gt
.globl s_tok_le
.globl s_tok_ge
.globl s_tok_bang
.globl s_tok_andand
.globl s_tok_oror
.globl s_tok_eq2
.globl s_tok_neq2
.globl s_tok_dot
.globl s_quote_len
.globl s_type_prefix_len
.globl s_not_assign_len
.globl s_arg_prefix_len
.globl s_arg_mid_len
.globl s_cannot_find_pre_len
.globl s_period_len
.globl s_expected_semi_len
.globl s_ident_expected_len
.globl s_expr_expected_len
.globl s_rbrace_expected_len
.globl s_rparen_expected_len
.globl s_lparen_expected_len
.globl s_colon_expected_len
.globl s_arith_left_len
.globl s_arith_right_len
.globl s_no_overlap_pre_len
.globl s_no_overlap_mid_len
.globl s_no_overlap_post_len
.globl s_operator_pre_len
.globl s_operator_mid_len
.globl s_and_len
.globl s_expected_arg_pre_len
.globl s_expected_arg_mid_len
.globl s_expected_arg_post_len
.globl s_return_outside_len
.globl s_const_init_len
.globl s_redeclare_pre_len
.globl s_assign_const_pre_len
.globl s_assign_const_post_len
.globl s_not_callable_len
.globl s_unterminated_str_len
.globl s_unterminated_comment_len
.globl s_invalid_char_len
.globl s_diag_prefix_len
.globl s_colon_space_len
.globl s_type_number_len
.globl s_type_string_len
.globl s_type_boolean_len
.globl s_type_void_len
.globl s_type_any_len
.globl s_type_function_len
.globl s_type_error_len
.globl s_console_len
.globl s_log_len
.globl s_function_kw_len
.globl s_space_eq_len
.globl s_space_lparen_len
.globl s_rparen_space_len
.globl s_rparen_brace_nl_len
.globl s_if_open_len
.globl s_else_len
.globl s_return_len
.globl s_return_bare_len
.globl s_lbrace_nl_len
.globl s_rbrace_nl_len
.globl s_semi_nl_len
.globl s_equals_len
.globl s_type_expected_len

.section .rodata
s_quote:      .ascii "'"
s_quote_len = . - s_quote
s_type_prefix: .ascii "Type "
s_type_prefix_len = . - s_type_prefix
s_not_assign: .ascii " is not assignable to type "
s_not_assign_len = . - s_not_assign
s_arg_prefix: .ascii "Argument of type "
s_arg_prefix_len = . - s_arg_prefix
s_arg_mid:    .ascii " is not assignable to parameter of type "
s_arg_mid_len = . - s_arg_mid
s_cannot_find_pre: .ascii "Cannot find name "
s_cannot_find_pre_len = . - s_cannot_find_pre
s_period:     .ascii "."
s_period_len = 1
s_expected_semi: .ascii "';' expected."
s_expected_semi_len = . - s_expected_semi
s_ident_expected: .ascii "Identifier expected."
s_ident_expected_len = . - s_ident_expected
s_expr_expected: .ascii "Expression expected."
s_expr_expected_len = . - s_expr_expected
s_rbrace_expected: .ascii "'}' expected."
s_rbrace_expected_len = . - s_rbrace_expected
s_rparen_expected: .ascii "')' expected."
s_rparen_expected_len = . - s_rparen_expected
s_lparen_expected: .ascii "'(' expected."
s_lparen_expected_len = . - s_lparen_expected
s_colon_expected: .ascii "':' expected."
s_colon_expected_len = . - s_colon_expected
s_arith_left: .ascii "The left-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type."
s_arith_left_len = . - s_arith_left
s_arith_right: .ascii "The right-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type."
s_arith_right_len = . - s_arith_right
s_no_overlap_pre: .ascii "This comparison appears to be unintentional because the types "
s_no_overlap_pre_len = . - s_no_overlap_pre
s_no_overlap_mid: .ascii " and "
s_no_overlap_mid_len = . - s_no_overlap_mid
s_no_overlap_post: .ascii " have no overlap."
s_no_overlap_post_len = . - s_no_overlap_post
s_operator_pre: .ascii "Operator "
s_operator_pre_len = . - s_operator_pre
s_operator_mid: .ascii " cannot be applied to types "
s_operator_mid_len = . - s_operator_mid
s_and: .ascii " and "
s_and_len = . - s_and
s_expected_arg_pre: .ascii "Expected "
s_expected_arg_pre_len = . - s_expected_arg_pre
s_expected_arg_mid: .ascii " arguments, but got "
s_expected_arg_mid_len = . - s_expected_arg_mid
s_expected_arg_post: .ascii "."
s_expected_arg_post_len = . - s_expected_arg_post
s_return_outside: .ascii "A 'return' statement can only be used within a function body."
s_return_outside_len = . - s_return_outside
s_const_init: .ascii "'const' declarations must be initialized."
s_const_init_len = . - s_const_init
s_dup_ident_pre: .ascii "Duplicate identifier "
s_dup_ident_pre_len = . - s_dup_ident_pre
s_dup_func: .ascii "Duplicate function implementation."
s_dup_func_len = . - s_dup_func
s_redeclare_pre: .ascii "Cannot redeclare block-scoped variable "
s_redeclare_pre_len = . - s_redeclare_pre
s_assign_const_pre: .ascii "Cannot assign to "
s_assign_const_pre_len = . - s_assign_const_pre
s_assign_const_post: .ascii " because it is a constant."
s_assign_const_post_len = . - s_assign_const_post
s_func_missing: .ascii "Function implementation is missing or not immediately following the declaration."
s_func_missing_len = . - s_func_missing
s_not_callable: .ascii "This expression is not callable."
s_not_callable_len = . - s_not_callable
s_cap_pre: .ascii "  Type '"
s_cap_pre_len = . - s_cap_pre
s_cap_number: .ascii "Number"
s_cap_number_len = . - s_cap_number
s_cap_string: .ascii "String"
s_cap_string_len = . - s_cap_string
s_cap_boolean: .ascii "Boolean"
s_cap_boolean_len = . - s_cap_boolean
s_cap_void: .ascii "Void"
s_cap_void_len = . - s_cap_void
s_cap_error: .ascii "Error"
s_cap_error_len = . - s_cap_error
s_cap_post: .ascii "' has no call signatures.\n"
s_cap_post_len = . - s_cap_post
s_unterminated_str: .ascii "Unterminated string literal."
s_unterminated_str_len = . - s_unterminated_str
s_unterminated_comment: .ascii "'*/' expected."
s_unterminated_comment_len = . - s_unterminated_comment
s_invalid_char: .ascii "Invalid character."
s_invalid_char_len = . - s_invalid_char
s_diag_prefix: .ascii "): error TS"
s_diag_prefix_len = . - s_diag_prefix
s_colon_space: .ascii ": "
s_colon_space_len = 2

s_type_number:  .ascii "number"
s_type_number_len = . - s_type_number
s_type_string:  .ascii "string"
s_type_string_len = . - s_type_string
s_type_boolean: .ascii "boolean"
s_type_boolean_len = . - s_type_boolean
s_type_void:    .ascii "void"
s_type_void_len = . - s_type_void
s_type_any:     .ascii "any"
s_type_any_len = . - s_type_any
s_type_function: .ascii "function"
s_type_function_len = . - s_type_function
s_type_error:   .ascii "error"
s_type_error_len = . - s_type_error

s_open_paren: .ascii "("
s_comma: .ascii ","
s_close_paren: .ascii ")"
s_colon: .ascii ":"
s_semi: .ascii ";"
s_newline: .ascii "\n"
s_space: .ascii " "
s_arrow: .ascii " -> "
s_console: .ascii "console"
s_console_len = . - s_console
s_log: .ascii "log"
s_log_len = . - s_log
s_function_kw: .ascii "function "
s_function_kw_len = . - s_function_kw
s_space_eq: .ascii " = "
s_space_eq_len = . - s_space_eq
s_space_lparen: .ascii " ("
s_space_lparen_len = . - s_space_lparen
s_rparen_space: .ascii ") "
s_rparen_space_len = . - s_rparen_space
s_rparen_brace_nl: .ascii ") {\n"
s_rparen_brace_nl_len = . - s_rparen_brace_nl
s_if_open: .ascii "if ("
s_if_open_len = . - s_if_open
s_else: .ascii "else "
s_else_len = . - s_else
s_return: .ascii "return "
s_return_len = . - s_return
s_return_bare: .ascii "return;\n"
s_return_bare_len = . - s_return_bare
s_lbrace_nl: .ascii "{\n"
s_lbrace_nl_len = . - s_lbrace_nl
s_rbrace_nl: .ascii "}\n"
s_rbrace_nl_len = . - s_rbrace_nl
s_semi_nl: .ascii ";\n"
s_semi_nl_len = . - s_semi_nl
s_equals: .ascii "="
s_equals_len = 1
s_type_expected: .ascii "Type expected."
s_type_expected_len = . - s_type_expected

# Token kinds for --tokens output (indexed by kind)
.globl token_names
token_names:
  .quad s_tok_eof, s_tok_ident, s_tok_num, s_tok_str, s_tok_let, s_tok_const
  .quad s_tok_var, s_tok_function, s_tok_return, s_tok_if, s_tok_else
  .quad s_tok_true, s_tok_false, s_tok_colon2, s_tok_semi, s_tok_comma
  .quad s_tok_lparen, s_tok_rparen, s_tok_lbrace, s_tok_rbrace
  .quad s_tok_assign, s_tok_plus, s_tok_minus, s_tok_star, s_tok_slash
  .quad s_tok_percent, s_tok_eq3, s_tok_neq3, s_tok_lt, s_tok_gt
  .quad s_tok_le, s_tok_ge, s_tok_bang, s_tok_andand, s_tok_oror
  .quad s_tok_eq2, s_tok_neq2, s_tok_dot
s_tok_eof:      .asciz "EOF"
s_tok_ident:    .asciz "ident"
s_tok_num:      .asciz "number"
s_tok_str:      .asciz "string"
s_tok_let:      .asciz "let"
s_tok_const:    .asciz "const"
s_tok_var:      .asciz "var"
s_tok_function: .asciz "function"
s_tok_return:   .asciz "return"
s_tok_if:       .asciz "if"
s_tok_else:     .asciz "else"
s_tok_true:     .asciz "true"
s_tok_false:    .asciz "false"
s_tok_colon2:   .asciz ":"
s_tok_semi:     .asciz ";"
s_tok_comma:    .asciz ","
s_tok_lparen:   .asciz "("
s_tok_rparen:   .asciz ")"
s_tok_lbrace:   .asciz "{"
s_tok_rbrace:   .asciz "}"
s_tok_assign:   .asciz "="
s_tok_plus:     .asciz "+"
s_tok_minus:    .asciz "-"
s_tok_star:     .asciz "*"
s_tok_slash:    .asciz "/"
s_tok_percent:  .asciz "%"
s_tok_eq3:      .asciz "==="
s_tok_neq3:     .asciz "!=="
s_tok_lt:       .asciz "<"
s_tok_gt:       .asciz ">"
s_tok_le:       .asciz "<="
s_tok_ge:       .asciz ">="
s_tok_bang:     .asciz "!"
s_tok_andand:   .asciz "&&"
s_tok_oror:     .asciz "||"
s_tok_eq2:      .asciz "=="
s_tok_neq2:     .asciz "!="
s_tok_dot:      .asciz "."
