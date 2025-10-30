//// Primitive value encoding and header formatting.
////
//// This module handles encoding of primitive JSON values (strings, numbers,
//// booleans, null) as well as formatting array headers.
//// Encode a primitive JSON value to its TOON string representation.
////
//// Applies quoting rules based on the active delimiter context.
////
//// ## Examples
////
//// ```gleam
//// encode_primitive(Null, Comma)
//// // -> "null"
////
//// encode_primitive(Bool(True), Comma)
//// // -> "true"
////
//// encode_primitive(Number(42.0), Comma)
//// // -> "42"
////
//// encode_primitive(JsonString("hello"), Comma)
//// // -> "hello"
//// ```
//// Encode a number, removing unnecessary decimals and normalizing -0 to 0.
//// Encode a string value, applying quoting rules based on delimiter.
//// Encode a key for use in key-value pairs.
////
//// Applies quoting rules for keys: keys must be quoted unless they
//// match the pattern ^[A-Za-z_][\\w.]*$
////
//// ## Examples
////
//// ```gleam
//// encode_key("name")
//// // -> "name"
////
//// encode_key("user-id")
//// // -> "\"user-id\""
//// ```
//// Format an array header line.
////
//// ## Arguments
////
//// * `length` - The array length
//// * `key` - Optional key name for the array
//// * `delimiter` - The delimiter for this array's scope
//// * `marker` - Whether to include the "#" length marker
////
//// ## Examples
////
//// ```gleam
//// format_header(3, None, Comma, NoMarker)
//// // -> "[3]:"
////
//// format_header(3, Some("tags"), Comma, HashMarker)
//// // -> "tags[#3]:"
////
//// format_header(2, Some("items"), Tab, NoMarker)
//// // -> "items[2\t]:"
//// ```
//// Format a tabular array header with field names.
////
//// ## Examples
////
//// ```gleam
//// format_tabular_header(2, Some("users"), ["id", "name"], Comma, NoMarker)
//// // -> "users[2]{id,name}:"
//// ```
//// Convert delimiter to its header representation.
////
//// Comma has no representation (empty string).
//// Tab and Pipe appear as their literal characters.
//// Encode and join primitive values with a delimiter.
////
//// Used for inline primitive arrays.
////
//// ## Examples
////
//// ```gleam
//// let values = [Number(1.0), Number(2.0), Number(3.0)]
//// encode_and_join_primitives(values, Comma)
//// // -> "1,2,3"
//// ```

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import toon_codec/constants
import toon_codec/internal/string as string_utils
import toon_codec/types.{
  type Delimiter, type JsonValue, type LengthMarker, Bool, HashMarker, NoMarker,
  Null, Number, String as JsonString,
}

// Primitive encoding

pub fn encode_primitive(value: JsonValue, delimiter: Delimiter) -> String {
  case value {
    Null -> constants.null_literal
    Bool(True) -> constants.true_literal
    Bool(False) -> constants.false_literal
    Number(n) -> encode_number(n)
    JsonString(s) -> encode_string_value(s, delimiter)
    _ -> panic as "encode_primitive called with non-primitive value"
  }
}

fn encode_number(n: Float) -> String {
  // Check for -0 and normalize to 0
  case n == 0.0 {
    True -> "0"
    False -> {
      // Check if it's a whole number
      let floored = float.floor(n)
      case floored == n {
        True -> {
          let truncated = float.truncate(n)
          int.to_string(truncated)
        }
        False -> float.to_string(n)
      }
    }
  }
}

fn encode_string_value(value: String, delimiter: Delimiter) -> String {
  case string_utils.needs_quoting(value, delimiter) {
    True -> string_utils.quote_string(value)
    False -> value
  }
}

// Key encoding

pub fn encode_key(key: String) -> String {
  case string_utils.key_needs_quoting(key) {
    True -> string_utils.quote_string(key)
    False -> key
  }
}

// Header formatting

pub fn format_header(
  length: Int,
  key: Option(String),
  delimiter: Delimiter,
  marker: LengthMarker,
) -> String {
  let key_part = case key {
    Some(k) -> encode_key(k)
    None -> ""
  }

  let marker_part = case marker {
    HashMarker -> constants.hash
    NoMarker -> ""
  }

  let delimiter_part = delimiter_to_header_string(delimiter)

  let bracket_part =
    constants.open_bracket
    <> marker_part
    <> int.to_string(length)
    <> delimiter_part
    <> constants.close_bracket

  key_part <> bracket_part <> constants.colon
}

pub fn format_tabular_header(
  length: Int,
  key: Option(String),
  fields: List(String),
  delimiter: Delimiter,
  marker: LengthMarker,
) -> String {
  let key_part = case key {
    Some(k) -> encode_key(k)
    None -> ""
  }

  let marker_part = case marker {
    HashMarker -> constants.hash
    NoMarker -> ""
  }

  let delimiter_part = delimiter_to_header_string(delimiter)

  let bracket_part =
    constants.open_bracket
    <> marker_part
    <> int.to_string(length)
    <> delimiter_part
    <> constants.close_bracket

  // Encode field names and join with delimiter
  let delim_str = types.delimiter_to_string(delimiter)
  let encoded_fields = list.map(fields, encode_key)
  let fields_part =
    constants.open_brace
    <> string.join(encoded_fields, delim_str)
    <> constants.close_brace

  key_part <> bracket_part <> fields_part <> constants.colon
}

fn delimiter_to_header_string(delimiter: Delimiter) -> String {
  case delimiter {
    types.Comma -> ""
    types.Tab -> "\t"
    types.Pipe -> "|"
  }
}

// Value joining

pub fn encode_and_join_primitives(
  values: List(JsonValue),
  delimiter: Delimiter,
) -> String {
  let delim_str = types.delimiter_to_string(delimiter)
  values
  |> list.map(encode_primitive(_, delimiter))
  |> string.join(delim_str)
}
