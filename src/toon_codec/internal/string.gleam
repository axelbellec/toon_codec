//// String manipulation utilities for TOON encoding/decoding.
////
//// This internal module provides functions for escaping, unescaping, quoting,
//// and finding characters in strings while respecting quote contexts.
//// Escape special characters in a string for encoding.
////
//// Escapes: backslash, double quote, newline, carriage return, tab.
////
//// ## Examples
////
//// ```gleam
//// escape_string("hello\\nworld")
//// // -> "hello\\\\nworld"
//// ```
//// Unescape a string by processing escape sequences.
////
//// Valid escape sequences: \\\\, \\\", \\n, \\r, \\t
////
//// Returns an error for invalid escape sequences.
//// Find the index of the closing double quote in a string.
////
//// Accounts for escape sequences. Returns the index of the closing quote,
//// or an error if not found.
////
//// ## Arguments
////
//// * `content` - The string to search in
//// * `start` - The index of the opening quote
//// Find the first unquoted occurrence of a character in a string.
////
//// Returns the index of the first occurrence of `char` that is not
//// inside quotes, or None if not found.
////
//// ## Arguments
////
//// * `content` - The string to search in
//// * `char` - The character to find
//// * `start` - Starting index (default: 0)
//// Check if a string needs quoting based on TOON rules.
////
//// A string needs quoting if:
//// - It's empty
//// - Has leading/trailing whitespace
//// - Equals a literal (true, false, null)
//// - Is numeric-like
//// - Contains special characters (colon, quote, backslash, brackets, braces)
//// - Contains control characters (newline, carriage return, tab)
//// - Contains the active delimiter
//// - Equals "-" or starts with "-"
//// Check if a key needs quoting.
////
//// A key needs quoting if it doesn't match the pattern: ^[A-Za-z_][\\w.]*$
//// Wrap a string in double quotes and escape it.
//// Extract content from a quoted string (remove quotes and unescape).

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import toon_codec/error.{type ToonError}
import toon_codec/internal/char
import toon_codec/types.{type Delimiter}

// Escaping

pub fn escape_string(value: String) -> String {
  value
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

// Unescaping

pub fn unescape_string(value: String) -> Result(String, ToonError) {
  let chars = string.to_graphemes(value)
  unescape_chars(chars, [], 0)
}

fn unescape_chars(
  chars: List(String),
  acc: List(String),
  position: Int,
) -> Result(String, ToonError) {
  case chars {
    [] -> Ok(string.join(list.reverse(acc), ""))

    ["\\", next, ..rest] -> {
      case next {
        "\\" -> unescape_chars(rest, ["\\", ..acc], position + 2)
        "\"" -> unescape_chars(rest, ["\"", ..acc], position + 2)
        "n" -> unescape_chars(rest, ["\n", ..acc], position + 2)
        "r" -> unescape_chars(rest, ["\r", ..acc], position + 2)
        "t" -> unescape_chars(rest, ["\t", ..acc], position + 2)
        _ -> Error(error.invalid_escape(next, position + 1))
      }
    }

    ["\\"] -> Error(error.invalid_escape("", position))

    [char, ..rest] -> unescape_chars(rest, [char, ..acc], position + 1)
  }
}

// Quote finding

pub fn find_closing_quote(content: String, start: Int) -> Result(Int, ToonError) {
  let chars = string.to_graphemes(content)
  find_closing_quote_loop(chars, start + 1, start + 1, False)
}

fn find_closing_quote_loop(
  chars: List(String),
  position: Int,
  search_pos: Int,
  escaped: Bool,
) -> Result(Int, ToonError) {
  case list.drop(chars, search_pos) {
    [] -> Error(error.unterminated_string(position))

    ["\\", _, ..] if !escaped ->
      find_closing_quote_loop(chars, position, search_pos + 2, False)

    ["\"", ..] if !escaped -> Ok(search_pos)

    [_, ..] -> find_closing_quote_loop(chars, position, search_pos + 1, False)
  }
}

// Unquoted character finding

pub fn find_unquoted_char(
  content: String,
  char: String,
  start: Int,
) -> Option(Int) {
  let chars = string.to_graphemes(content)
  find_unquoted_char_loop(chars, char, start, False, 0)
}

fn find_unquoted_char_loop(
  chars: List(String),
  target: String,
  position: Int,
  in_quotes: Bool,
  current: Int,
) -> Option(Int) {
  case chars {
    [] -> None

    ["\\", _, ..rest] if in_quotes ->
      find_unquoted_char_loop(rest, target, position, in_quotes, current + 2)

    ["\"", ..rest] -> {
      let new_in_quotes = !in_quotes
      find_unquoted_char_loop(
        rest,
        target,
        position,
        new_in_quotes,
        current + 1,
      )
    }

    [c, ..] if c == target && !in_quotes && current >= position -> Some(current)

    [_, ..rest] ->
      find_unquoted_char_loop(rest, target, position, in_quotes, current + 1)
  }
}

// Quoting rules

pub fn needs_quoting(value: String, delimiter: Delimiter) -> Bool {
  value == ""
  || has_leading_or_trailing_whitespace(value)
  || is_literal(value)
  || is_numeric_like(value)
  || contains_special_chars(value)
  || contains_delimiter(value, delimiter)
  || starts_with_hyphen(value)
}

fn has_leading_or_trailing_whitespace(value: String) -> Bool {
  case string.to_graphemes(value) {
    [] -> False
    [first, ..] -> {
      case char.is_whitespace(first) {
        True -> True
        False -> {
          let last =
            value
            |> string.to_graphemes
            |> list.last
          case last {
            Ok(l) -> char.is_whitespace(l)
            _ -> False
          }
        }
      }
    }
  }
}

fn is_literal(value: String) -> Bool {
  value == "true" || value == "false" || value == "null"
}

fn is_numeric_like(value: String) -> Bool {
  // Simplified numeric check without regex
  // Check if it looks like a number: starts with optional -, then digits
  // Includes patterns like: 123, -456, 3.14, 1e6, 05 (leading zero)
  case string.to_graphemes(value) {
    [] -> False
    ["-", ..rest] -> is_numeric_pattern(rest)
    chars -> is_numeric_pattern(chars)
  }
}

fn is_numeric_pattern(chars: List(String)) -> Bool {
  case chars {
    [] -> False
    [first, ..] ->
      char.is_digit(first)
      && list.all(chars, fn(c) {
        char.is_digit(c)
        || c == "."
        || c == "e"
        || c == "E"
        || c == "+"
        || c == "-"
      })
  }
}

fn contains_special_chars(value: String) -> Bool {
  string.contains(value, ":")
  || string.contains(value, "\"")
  || string.contains(value, "\\")
  || string.contains(value, "[")
  || string.contains(value, "]")
  || string.contains(value, "{")
  || string.contains(value, "}")
  || string.contains(value, "\n")
  || string.contains(value, "\r")
  || string.contains(value, "\t")
}

fn contains_delimiter(value: String, delimiter: Delimiter) -> Bool {
  let delim_str = types.delimiter_to_string(delimiter)
  string.contains(value, delim_str)
}

fn starts_with_hyphen(value: String) -> Bool {
  string.starts_with(value, "-")
}

pub fn key_needs_quoting(key: String) -> Bool {
  case string.to_graphemes(key) {
    [] -> True
    [first, ..rest] ->
      case char.is_key_start(first) {
        False -> True
        True -> !list.all(rest, char.is_key_char)
      }
  }
}

// String wrapping

pub fn quote_string(value: String) -> String {
  "\"" <> escape_string(value) <> "\""
}

pub fn unquote_string(value: String) -> Result(String, ToonError) {
  case string.starts_with(value, "\"") && string.ends_with(value, "\"") {
    True -> {
      let len = string.length(value)
      let content = string.slice(value, 1, len - 2)
      unescape_string(content)
    }
    False -> Error(error.validation_error("Not a quoted string"))
  }
}
