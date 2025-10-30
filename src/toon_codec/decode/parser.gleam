//// Parsing functions for TOON format elements.
////
//// This module provides functions to parse array headers, keys, values,
//// and delimited data from TOON format strings.
//// Parse a primitive token (string, number, boolean, or null).
////
//// Quoted strings remain strings even if they look like numbers.
//// Parse a quoted string token.
//// Parse an unquoted value (number or string).
//// Parse a numeric token.
//// Check if a string has a forbidden leading zero.
//// Parse delimited values from a string.
////
//// Splits on the delimiter while respecting quoted sections.
//// Split a string on delimiter, respecting quotes.
//// Parse a key from the beginning of a line.
////
//// Returns the key and the position after the colon.
//// Parse a quoted key.
//// Parse an unquoted key.
//// Parse an array header line.
////
//// Returns the header info and any inline values after the colon.
//// Parse the bracket segment [#?N delim?]
//// Parse length and delimiter from bracket content.
//// Parse fields segment {field1,field2,...}
//// Unescape field names (handle quoted field names).
//// Extract inline values after the colon.
//// Check if a line looks like an array header.
//// Check if content is a key-value line (has unquoted colon).

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import toon_codec/error.{type ToonError}
import toon_codec/internal/char
import toon_codec/internal/string as string_utils
import toon_codec/types.{
  type ArrayHeader, type Delimiter, type JsonValue, ArrayHeader, Bool, Comma,
  Null, Number, Pipe, String as JsonString, Tab,
}

// Primitive token parsing

/// Unquoted tokens are interpreted based on their content.
pub fn parse_primitive(token: String) -> Result(JsonValue, ToonError) {
  let trimmed = string.trim(token)

  case trimmed {
    "" -> Error(error.validation_error("Empty token"))
    "null" -> Ok(Null)
    "true" -> Ok(Bool(True))
    "false" -> Ok(Bool(False))
    _ -> {
      case string.starts_with(trimmed, "\"") {
        True -> parse_quoted_string(trimmed)
        False -> parse_unquoted_value(trimmed)
      }
    }
  }
}

fn parse_quoted_string(token: String) -> Result(JsonValue, ToonError) {
  case string_utils.unquote_string(token) {
    Ok(unescaped) -> Ok(JsonString(unescaped))
    Error(err) -> Error(err)
  }
}

fn parse_unquoted_value(token: String) -> Result(JsonValue, ToonError) {
  // Try to parse as number
  case parse_number(token) {
    Ok(num) -> Ok(num)
    Error(_) -> {
      // Not a number, treat as unquoted string
      Ok(JsonString(token))
    }
  }
}

fn parse_number(token: String) -> Result(JsonValue, ToonError) {
  // Check for forbidden leading zeros (except "0" itself)
  case has_forbidden_leading_zero(token) {
    True -> Error(error.validation_error("Invalid number with leading zero"))
    False -> {
      case float.parse(token) {
        Ok(n) -> Ok(Number(n))
        Error(_) -> Error(error.validation_error("Invalid number: " <> token))
      }
    }
  }
}

fn has_forbidden_leading_zero(s: String) -> Bool {
  case string.to_graphemes(s) {
    ["0", second, ..] -> char.is_digit(second)
    _ -> False
  }
}

// Delimited value parsing

pub fn parse_delimited_values(
  text: String,
  delimiter: Delimiter,
) -> List(String) {
  let delim_str = types.delimiter_to_string(delimiter)
  split_respecting_quotes(text, delim_str)
}

fn split_respecting_quotes(text: String, delimiter: String) -> List(String) {
  let chars = string.to_graphemes(text)
  split_loop(chars, delimiter, [], [], False)
}

fn split_loop(
  chars: List(String),
  delimiter: String,
  current_token: List(String),
  acc: List(String),
  in_quotes: Bool,
) -> List(String) {
  case chars {
    [] -> {
      // End of string - add current token
      let token = string.join(list.reverse(current_token), "")
      list.reverse([token, ..acc])
    }

    ["\\", next, ..rest] if in_quotes -> {
      // Escaped character in quotes - add both
      split_loop(rest, delimiter, [next, "\\", ..current_token], acc, in_quotes)
    }

    ["\"", ..rest] -> {
      // Toggle quote state
      split_loop(rest, delimiter, ["\"", ..current_token], acc, !in_quotes)
    }

    [char, ..rest] if char == delimiter && !in_quotes -> {
      // Delimiter outside quotes - split here
      let token = string.join(list.reverse(current_token), "")
      split_loop(rest, delimiter, [], [token, ..acc], in_quotes)
    }

    [char, ..rest] -> {
      // Regular character
      split_loop(rest, delimiter, [char, ..current_token], acc, in_quotes)
    }
  }
}

// Key parsing

pub fn parse_key(content: String) -> Result(#(String, Int), ToonError) {
  case string.starts_with(content, "\"") {
    True -> parse_quoted_key(content)
    False -> parse_unquoted_key(content)
  }
}

fn parse_quoted_key(content: String) -> Result(#(String, Int), ToonError) {
  case string_utils.find_closing_quote(content, 0) {
    Ok(close_pos) -> {
      // Extract and unescape the key
      let key_with_quotes = string.slice(content, 0, close_pos + 1)
      case string_utils.unquote_string(key_with_quotes) {
        Ok(key) -> {
          // Check for colon after the closing quote
          let after_quote = string.slice(content, close_pos + 1, 1000)
          case string.trim_start(after_quote) {
            ":" <> rest ->
              Ok(#(
                key,
                close_pos + 1 + string.length(after_quote) - string.length(rest),
              ))
            _ -> Error(error.validation_error("Missing colon after quoted key"))
          }
        }
        Error(err) -> Error(err)
      }
    }
    Error(err) -> Error(err)
  }
}

fn parse_unquoted_key(content: String) -> Result(#(String, Int), ToonError) {
  case string_utils.find_unquoted_char(content, ":", 0) {
    Some(colon_pos) -> {
      let key = string.slice(content, 0, colon_pos) |> string.trim
      Ok(#(key, colon_pos + 1))
    }
    None -> Error(error.validation_error("Missing colon after key"))
  }
}

// Array header parsing

pub fn parse_array_header(
  line: String,
) -> Result(#(ArrayHeader, Option(String)), ToonError) {
  // Find the opening bracket
  case string.split_once(line, "[") {
    Ok(#(before_bracket, after_bracket)) -> {
      let key = case string.trim(before_bracket) {
        "" -> None
        k -> Some(k)
      }

      // Parse the bracket segment
      case parse_bracket_segment(after_bracket) {
        Ok(#(length, delimiter, has_marker, rest_after_bracket)) -> {
          // Check for fields segment
          case parse_fields_segment(rest_after_bracket, delimiter) {
            Ok(#(fields, rest_after_fields)) -> {
              // Extract inline values after colon
              let inline_values = extract_inline_values(rest_after_fields)

              let header =
                ArrayHeader(
                  key: key,
                  length: length,
                  delimiter: delimiter,
                  fields: fields,
                  has_length_marker: has_marker,
                )

              Ok(#(header, inline_values))
            }
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
    Error(_) ->
      Error(error.validation_error("Invalid array header: no opening bracket"))
  }
}

fn parse_bracket_segment(
  after_bracket: String,
) -> Result(#(Int, Delimiter, Bool, String), ToonError) {
  // Look for closing bracket
  case string.split_once(after_bracket, "]") {
    Ok(#(bracket_content, rest)) -> {
      // Check for length marker
      let #(has_marker, content_after_marker) = case
        string.starts_with(bracket_content, "#")
      {
        True -> #(True, string.drop_start(bracket_content, 1))
        False -> #(False, bracket_content)
      }

      // Parse length and delimiter
      parse_length_and_delimiter(content_after_marker, has_marker, rest)
    }
    Error(_) ->
      Error(error.validation_error("Invalid array header: no closing bracket"))
  }
}

fn parse_length_and_delimiter(
  content: String,
  has_marker: Bool,
  rest: String,
) -> Result(#(Int, Delimiter, Bool, String), ToonError) {
  // The delimiter is the last character (if any) before ]
  // Check for tab or pipe
  case string.ends_with(content, "\t") {
    True -> {
      let len_str =
        string.slice(content, 0, string.length(content) - 1) |> string.trim
      case int.parse(len_str) {
        Ok(length) -> Ok(#(length, Tab, has_marker, rest))
        Error(_) ->
          Error(error.validation_error("Invalid array length: " <> len_str))
      }
    }
    False ->
      case string.ends_with(content, "|") {
        True -> {
          let len_str =
            string.slice(content, 0, string.length(content) - 1) |> string.trim
          case int.parse(len_str) {
            Ok(length) -> Ok(#(length, Pipe, has_marker, rest))
            Error(_) ->
              Error(error.validation_error("Invalid array length: " <> len_str))
          }
        }
        False -> {
          // No delimiter symbol = comma
          let len_str = string.trim(content)
          case int.parse(len_str) {
            Ok(length) -> Ok(#(length, Comma, has_marker, rest))
            Error(_) ->
              Error(error.validation_error("Invalid array length: " <> len_str))
          }
        }
      }
  }
}

fn parse_fields_segment(
  after_bracket: String,
  delimiter: Delimiter,
) -> Result(#(Option(List(String)), String), ToonError) {
  let trimmed = string.trim_start(after_bracket)

  case string.starts_with(trimmed, "{") {
    True -> {
      // Has fields segment
      case string.split_once(trimmed, "}") {
        Ok(#(fields_content, rest)) -> {
          let fields_str = string.drop_start(fields_content, 1)
          let field_names = parse_delimited_values(fields_str, delimiter)

          // Unescape quoted field names
          case unescape_field_names(field_names) {
            Ok(unescaped_fields) -> Ok(#(Some(unescaped_fields), rest))
            Error(err) -> Error(err)
          }
        }
        Error(_) ->
          Error(error.validation_error("Unclosed fields segment: missing }"))
      }
    }
    False -> Ok(#(None, trimmed))
  }
}

fn unescape_field_names(names: List(String)) -> Result(List(String), ToonError) {
  unescape_names_loop(names, [])
}

fn unescape_names_loop(
  names: List(String),
  acc: List(String),
) -> Result(List(String), ToonError) {
  case names {
    [] -> Ok(list.reverse(acc))
    [name, ..rest] -> {
      let trimmed = string.trim(name)
      case string.starts_with(trimmed, "\"") {
        True -> {
          case string_utils.unquote_string(trimmed) {
            Ok(unescaped) -> unescape_names_loop(rest, [unescaped, ..acc])
            Error(err) -> Error(err)
          }
        }
        False -> unescape_names_loop(rest, [trimmed, ..acc])
      }
    }
  }
}

fn extract_inline_values(after_fields: String) -> Option(String) {
  let trimmed = string.trim_start(after_fields)

  case string.starts_with(trimmed, ":") {
    True -> {
      let after_colon = string.drop_start(trimmed, 1) |> string.trim_start
      case after_colon {
        "" -> None
        values -> Some(values)
      }
    }
    False -> None
  }
}

// Helper predicates

pub fn is_array_header(content: String) -> Bool {
  string.contains(content, "[") && string.contains(content, "]")
}

pub fn is_key_value_line(content: String) -> Bool {
  case string_utils.find_unquoted_char(content, ":", 0) {
    Some(_) -> True
    None -> False
  }
}
