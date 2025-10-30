//// Validation functions for strict mode decoding.
////
//// This module provides functions to validate counts, indentation,
//// and other structural requirements in strict mode.
//// Validate that actual count matches expected count.
////
//// Used in strict mode to ensure array lengths match declarations.
//// Validate row width in tabular arrays.
//// Validate that indentation is a multiple of indent_size.

import gleam/int
import toon_codec/error.{type ToonError}

// Count validation

pub fn validate_count(
  expected: Int,
  actual: Int,
  context: String,
) -> Result(Nil, ToonError) {
  case expected == actual {
    True -> Ok(Nil)
    False -> Error(error.count_mismatch(expected, actual, context))
  }
}

pub fn validate_row_width(
  expected: Int,
  actual: Int,
  row_number: Int,
) -> Result(Nil, ToonError) {
  case expected == actual {
    True -> Ok(Nil)
    False ->
      Error(error.validation_error(
        "Row "
        <> int.to_string(row_number)
        <> ": expected "
        <> int.to_string(expected)
        <> " values, got "
        <> int.to_string(actual),
      ))
  }
}

// Indentation validation

pub fn validate_indentation(
  indent: Int,
  indent_size: Int,
  line: Int,
) -> Result(Nil, ToonError) {
  case indent % indent_size {
    0 -> Ok(Nil)
    _ ->
      Error(error.indentation_error(
        "Indentation must be a multiple of "
          <> int.to_string(indent_size)
          <> " spaces",
        line,
      ))
  }
}
