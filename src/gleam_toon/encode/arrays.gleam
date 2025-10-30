//// Array encoding functions.
////
//// This module handles encoding of JSON arrays to TOON format, including:
//// - Inline primitive arrays
//// - Tabular arrays (uniform objects)
//// - Arrays of arrays
//// - Mixed/complex arrays (expanded list form)
//// Encode an array to TOON format.
////
//// Automatically detects the best representation:
//// - Empty arrays: `key[0]:`
//// - Primitive arrays: inline format `key[N]: v1,v2,v3`
//// - Arrays of primitive arrays: expanded list with inline subarrays
//// - Uniform objects with primitive values: tabular format
//// - Mixed/complex: expanded list format
////
//// ## Arguments
////
//// * `key` - Optional key name (None for root arrays)
//// * `values` - The array elements
//// * `writer` - The line writer
//// * `depth` - Current indentation depth
//// * `options` - Encoding options
//// Encode a primitive array in inline format.
////
//// ## Examples
////
//// ```
//// tags[3]: admin,ops,dev
//// ```
//// Encode an array of primitive arrays in expanded list format.
////
//// ## Examples
////
//// ```
//// pairs[2]:
////   - [2]: 1,2
////   - [2]: 3,4
//// ```
//// Encode an array of uniform objects in tabular format.
////
//// ## Examples
////
//// ```
//// users[2]{id,name}:
////   1,Alice
////   2,Bob
//// ```
//// Encode a mixed/complex array in expanded list format.
////
//// ## Examples
////
//// ```
//// items[3]:
////   - 1
////   - a: 1
////   - text
//// ```
//// Encode a single list item (element in expanded array).
//// Encode a complex array as a list item.
//// Encode an object as a list item.
////
//// The first field appears on the hyphen line, remaining fields at depth + 1.
//// Encode the first field of an object on the hyphen line.
//// Encode object fields (helper for encoding remaining fields).
//// Encode a key-value pair at a specific depth.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam_toon/constants
import gleam_toon/encode/internal
import gleam_toon/encode/primitives
import gleam_toon/encode/writer.{type Writer}
import gleam_toon/types.{
  type EncodeOptions, type JsonValue, Array, Object, String as JsonString,
}

// Main array encoding

pub fn encode_array(
  key: Option(String),
  values: List(JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  case values {
    [] -> encode_empty_array(key, writer, depth, options)
    _ -> detect_and_encode_array(key, values, writer, depth, options)
  }
}

// Empty arrays

fn encode_empty_array(
  key: Option(String),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let header =
    primitives.format_header(0, key, options.delimiter, options.length_marker)
  writer.push(writer, depth, header)
}

// Array structure detection and routing

fn detect_and_encode_array(
  key: Option(String),
  values: List(JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  case internal.is_array_of_primitives(values) {
    True -> encode_primitive_array(key, values, writer, depth, options)
    False ->
      case internal.is_array_of_arrays(values) {
        True ->
          case internal.all_arrays_of_primitives(values) {
            True -> encode_array_of_arrays(key, values, writer, depth, options)
            False -> encode_mixed_array(key, values, writer, depth, options)
          }
        False ->
          case internal.detect_tabular(values) {
            Some(fields) ->
              encode_tabular_array(key, values, fields, writer, depth, options)
            None -> encode_mixed_array(key, values, writer, depth, options)
          }
      }
  }
}

// Primitive array encoding

fn encode_primitive_array(
  key: Option(String),
  values: List(JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let length = list.length(values)
  let header =
    primitives.format_header(
      length,
      key,
      options.delimiter,
      options.length_marker,
    )
  let values_str =
    primitives.encode_and_join_primitives(values, options.delimiter)
  let line = header <> " " <> values_str
  writer.push(writer, depth, line)
}

// Array of arrays encoding

fn encode_array_of_arrays(
  key: Option(String),
  values: List(JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let length = list.length(values)
  let header =
    primitives.format_header(
      length,
      key,
      options.delimiter,
      options.length_marker,
    )

  // Add header line
  let writer = writer.push(writer, depth, header)

  // Add each array as a list item
  list.fold(values, writer, fn(w, item) {
    case item {
      Array(inner_items) -> {
        let inner_length = list.length(inner_items)
        let inner_header =
          primitives.format_header(
            inner_length,
            None,
            options.delimiter,
            options.length_marker,
          )
        let inner_values_str =
          primitives.encode_and_join_primitives(inner_items, options.delimiter)
        let line =
          constants.list_item_prefix <> inner_header <> " " <> inner_values_str
        writer.push(w, depth + 1, line)
      }
      _ -> w
    }
  })
}

// Tabular array encoding

fn encode_tabular_array(
  key: Option(String),
  values: List(JsonValue),
  fields: List(String),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let length = list.length(values)
  let header =
    primitives.format_tabular_header(
      length,
      key,
      fields,
      options.delimiter,
      options.length_marker,
    )

  // Add header line
  let writer = writer.push(writer, depth, header)

  // Add each object as a row
  list.fold(values, writer, fn(w, obj) {
    let field_values = internal.extract_field_values(obj, fields)
    let row =
      primitives.encode_and_join_primitives(field_values, options.delimiter)
    writer.push(w, depth + 1, row)
  })
}

// Mixed array encoding

fn encode_mixed_array(
  key: Option(String),
  values: List(JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let length = list.length(values)
  let header =
    primitives.format_header(
      length,
      key,
      options.delimiter,
      options.length_marker,
    )

  // Add header line
  let writer = writer.push(writer, depth, header)

  // Add each item as a list item
  list.fold(values, writer, fn(w, item) {
    encode_list_item(item, w, depth + 1, options)
  })
}

// List item encoding

fn encode_list_item(
  item: JsonValue,
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  case item {
    // Primitive: "- value"
    types.Null | types.Bool(_) | types.Number(_) | JsonString(_) -> {
      let value_str = primitives.encode_primitive(item, options.delimiter)
      let line = constants.list_item_prefix <> value_str
      writer.push(writer, depth, line)
    }

    // Array: check if primitive array or complex
    Array(items) -> {
      case internal.is_array_of_primitives(items) {
        // Inline primitive array: "- [N]: v1,v2,..."
        True -> {
          let length = list.length(items)
          let header =
            primitives.format_header(
              length,
              None,
              options.delimiter,
              options.length_marker,
            )
          let values_str =
            primitives.encode_and_join_primitives(items, options.delimiter)
          let line = constants.list_item_prefix <> header <> " " <> values_str
          writer.push(writer, depth, line)
        }
        // Complex array: "- " then nested items
        False -> encode_complex_array_item(items, writer, depth, options)
      }
    }

    // Object: "- key: value" format (first field on hyphen line)
    Object(fields) -> encode_object_as_list_item(fields, writer, depth, options)
  }
}

fn encode_complex_array_item(
  items: List(JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  // For complex arrays, we can't inline them, so we need a key
  // We'll use an empty hyphen line and nest the array
  let writer = writer.push(writer, depth, constants.hyphen)
  encode_array(None, items, writer, depth + 1, options)
}

fn encode_object_as_list_item(
  fields: List(#(String, JsonValue)),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  case fields {
    // Empty object: just a hyphen
    [] -> writer.push(writer, depth, constants.hyphen)

    // First field on hyphen line
    [first, ..rest] -> {
      let writer = encode_first_field_on_hyphen(first, writer, depth, options)
      // Remaining fields at depth + 1
      case rest {
        [] -> writer
        _ -> encode_object_fields(rest, writer, depth + 1, options)
      }
    }
  }
}

fn encode_first_field_on_hyphen(
  field: #(String, JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let #(key, value) = field
  let encoded_key = primitives.encode_key(key)

  case value {
    // Primitive: "- key: value"
    types.Null | types.Bool(_) | types.Number(_) | JsonString(_) -> {
      let encoded_value = primitives.encode_primitive(value, options.delimiter)
      let line =
        constants.list_item_prefix <> encoded_key <> ": " <> encoded_value
      writer.push(writer, depth, line)
    }

    // Array: check structure and encode appropriately
    Array(items) -> {
      case internal.is_array_of_primitives(items) {
        // Inline primitive array: "- key[N]: v1,v2,..."
        True -> {
          let length = list.length(items)
          let header =
            primitives.format_header(
              length,
              Some(key),
              options.delimiter,
              options.length_marker,
            )
          let values_str =
            primitives.encode_and_join_primitives(items, options.delimiter)
          let line = constants.list_item_prefix <> header <> " " <> values_str
          writer.push(writer, depth, line)
        }
        // Complex array: check for tabular or mixed
        False ->
          case internal.detect_tabular(items) {
            // Tabular array: "- key[N]{fields}:" then rows at depth + 1
            Some(tab_fields) -> {
              let length = list.length(items)
              let header =
                primitives.format_tabular_header(
                  length,
                  Some(key),
                  tab_fields,
                  options.delimiter,
                  options.length_marker,
                )
              let line = constants.list_item_prefix <> header
              let writer = writer.push(writer, depth, line)

              // Add rows at depth + 1
              list.fold(items, writer, fn(w, obj) {
                let field_values =
                  internal.extract_field_values(obj, tab_fields)
                let row =
                  primitives.encode_and_join_primitives(
                    field_values,
                    options.delimiter,
                  )
                writer.push(w, depth + 1, row)
              })
            }

            // Non-tabular array: "- key[N]:" then items at depth + 1
            None -> {
              let length = list.length(items)
              let header =
                primitives.format_header(
                  length,
                  Some(key),
                  options.delimiter,
                  options.length_marker,
                )
              let line = constants.list_item_prefix <> header
              let writer = writer.push(writer, depth, line)
              encode_array(None, items, writer, depth + 1, options)
            }
          }
      }
    }

    // Nested object: "- key:" then fields at depth + 2
    Object(nested_fields) -> {
      let line = constants.list_item_prefix <> encoded_key <> ":"
      let writer = writer.push(writer, depth, line)
      // Nested fields at depth + 2 (one deeper than sibling fields)
      encode_object_fields(nested_fields, writer, depth + 2, options)
    }
  }
}

fn encode_object_fields(
  fields: List(#(String, JsonValue)),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  list.fold(fields, writer, fn(w, field) {
    let #(key, value) = field
    encode_key_value_at_depth(key, value, w, depth, options)
  })
}

fn encode_key_value_at_depth(
  key: String,
  value: JsonValue,
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let encoded_key = primitives.encode_key(key)

  case value {
    types.Null | types.Bool(_) | types.Number(_) | JsonString(_) -> {
      let encoded_value = primitives.encode_primitive(value, options.delimiter)
      let line = encoded_key <> ": " <> encoded_value
      writer.push(writer, depth, line)
    }

    Array(items) -> encode_array(Some(key), items, writer, depth, options)

    Object(nested_fields) -> {
      let writer = writer.push(writer, depth, encoded_key <> ":")
      encode_object_fields(nested_fields, writer, depth + 1, options)
    }
  }
}
