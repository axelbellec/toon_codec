//// Error types and utility functions for TOON encoding/decoding.
////
//// This module defines all error types that can occur during TOON operations
//// and provides helper functions for error formatting and handling.
//// Comprehensive error type for TOON operations.
////
//// Each variant provides context about what went wrong, including line numbers
//// and positions where applicable for better error reporting.
//// Convert a ToonError to a human-readable error message.
////
//// ## Examples
////
//// ```gleam
//// let error = MissingColon(line: 5)
//// error_to_string(error)
//// // -> "Missing colon after key at line 5"
//// ```
//// Create a parse error with context.
//// Create a validation error.
//// Create a structure error.
//// Create an invalid escape error.
//// Create an unterminated string error.
//// Create a count mismatch error.
//// Create an indentation error.
//// Create a missing colon error.
//// Create an invalid header error.
//// Create a delimiter mismatch error.

import gleam/int

// Error type

pub type ToonError {
  /// Generic parsing error with message, line, and column
  ParseError(message: String, line: Int, column: Int)
  /// Validation error (e.g., invalid structure or format)
  ValidationError(message: String)
  /// Structure error (e.g., unexpected indentation)
  StructureError(message: String)
  /// Invalid escape sequence in a quoted string
  InvalidEscape(sequence: String, position: Int)
  /// Unterminated string (missing closing quote)
  UnterminatedString(position: Int)
  /// Array/row count doesn't match declared length
  CountMismatch(expected: Int, actual: Int, context: String)
  /// Invalid indentation (not a multiple of indent_size in strict mode)
  IndentationError(message: String, line: Int)
  /// Missing colon after a key
  MissingColon(line: Int)
  /// Empty input document
  EmptyInput
  /// Invalid header format
  InvalidHeader(message: String, line: Int)
  /// Delimiter mismatch in array/tabular data
  DelimiterMismatch(expected: String, line: Int)
}

// Error formatting

pub fn error_to_string(error: ToonError) -> String {
  case error {
    ParseError(message, line, column) ->
      "Parse error at line "
      <> int.to_string(line)
      <> ", column "
      <> int.to_string(column)
      <> ": "
      <> message

    ValidationError(message) -> "Validation error: " <> message

    StructureError(message) -> "Structure error: " <> message

    InvalidEscape(sequence, position) ->
      "Invalid escape sequence '\\"
      <> sequence
      <> "' at position "
      <> int.to_string(position)

    UnterminatedString(position) ->
      "Unterminated string: missing closing quote at position "
      <> int.to_string(position)

    CountMismatch(expected, actual, context) ->
      "Count mismatch in "
      <> context
      <> ": expected "
      <> int.to_string(expected)
      <> " but got "
      <> int.to_string(actual)

    IndentationError(message, line) ->
      "Indentation error at line " <> int.to_string(line) <> ": " <> message

    MissingColon(line) ->
      "Missing colon after key at line " <> int.to_string(line)

    EmptyInput -> "Cannot decode empty input: input must be a non-empty string"

    InvalidHeader(message, line) ->
      "Invalid header at line " <> int.to_string(line) <> ": " <> message

    DelimiterMismatch(expected, line) ->
      "Delimiter mismatch at line "
      <> int.to_string(line)
      <> ": expected '"
      <> expected
      <> "'"
  }
}

// Helper constructors

pub fn parse_error(message: String, line: Int, column: Int) -> ToonError {
  ParseError(message, line, column)
}

pub fn validation_error(message: String) -> ToonError {
  ValidationError(message)
}

pub fn structure_error(message: String) -> ToonError {
  StructureError(message)
}

pub fn invalid_escape(sequence: String, position: Int) -> ToonError {
  InvalidEscape(sequence, position)
}

pub fn unterminated_string(position: Int) -> ToonError {
  UnterminatedString(position)
}

pub fn count_mismatch(expected: Int, actual: Int, context: String) -> ToonError {
  CountMismatch(expected, actual, context)
}

pub fn indentation_error(message: String, line: Int) -> ToonError {
  IndentationError(message, line)
}

pub fn missing_colon(line: Int) -> ToonError {
  MissingColon(line)
}

pub fn invalid_header(message: String, line: Int) -> ToonError {
  InvalidHeader(message, line)
}

pub fn delimiter_mismatch(expected: String, line: Int) -> ToonError {
  DelimiterMismatch(expected, line)
}
