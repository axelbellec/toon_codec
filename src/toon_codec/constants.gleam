//// Constants used throughout the TOON encoder/decoder.
////
//// This module defines all structural characters, escape sequences,
//// delimiters, and literals used in the TOON format.

// Structural characters

/// Colon separator for key-value pairs
pub const colon = ":"

/// Space character
pub const space = " "

/// Comma delimiter (default)
pub const comma = ","

/// Pipe delimiter
pub const pipe = "|"

/// Tab character (used as delimiter, not for indentation)
pub const tab = "\t"

/// Hash symbol for length markers
pub const hash = "#"

/// Hyphen for list items
pub const hyphen = "-"

/// List item prefix (hyphen + space)
pub const list_item_prefix = "- "

// Brackets and braces

/// Opening square bracket for array headers
pub const open_bracket = "["

/// Closing square bracket for array headers
pub const close_bracket = "]"

/// Opening curly brace for field lists
pub const open_brace = "{"

/// Closing curly brace for field lists
pub const close_brace = "}"

// Quotes

/// Double quote character
pub const double_quote = "\""

/// Backslash character (for escaping)
pub const backslash = "\\"

// Literals

/// Null literal
pub const null_literal = "null"

/// True boolean literal
pub const true_literal = "true"

/// False boolean literal
pub const false_literal = "false"

// Escape sequences

/// Newline character (LF, U+000A)
pub const newline = "\n"

/// Carriage return character (CR, U+000D)
pub const carriage_return = "\r"

// Note: tab constant is defined above in structural characters section

// Character sets for validation

/// Valid characters that can start an unquoted key (letters and underscore)
pub const key_start_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"

/// Valid characters in unquoted keys (letters, digits, underscore, dot)
pub const key_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_."

/// Digit characters
pub const digits = "0123456789"
