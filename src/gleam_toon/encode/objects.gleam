//// Object encoding functions.
////
//// This module handles encoding of JSON objects to TOON format,
//// including nested objects and empty objects.
//// Encode an object to TOON format.
////
//// Objects are encoded as key-value pairs at the specified depth.
//// Each field appears on its own line with proper indentation.
////
//// ## Arguments
////
//// * `fields` - List of key-value pairs
//// * `writer` - The line writer to append to
//// * `depth` - Current indentation depth
//// * `options` - Encoding options
//// Encode a single key-value pair.
////
//// Handles primitives, nested objects, and arrays appropriately.
//// Encode a nested object.
////
//// Empty objects are rendered as "key:" with no content below.
//// Non-empty objects have their fields at depth + 1.
//// Delegate array encoding to the arrays module.

import gleam/list
import gleam/option.{Some}
import gleam_toon/encode/arrays
import gleam_toon/encode/primitives
import gleam_toon/encode/writer.{type Writer}
import gleam_toon/types.{type EncodeOptions, type JsonValue, Array, Object}

// Object encoding

pub fn encode_object(
  fields: List(#(String, JsonValue)),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  list.fold(fields, writer, fn(w, pair) {
    encode_key_value_pair(pair.0, pair.1, w, depth, options)
  })
}

// Key-value pair encoding

fn encode_key_value_pair(
  key: String,
  value: JsonValue,
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  let encoded_key = primitives.encode_key(key)

  case value {
    // Primitive values: inline on the same line
    types.Null | types.Bool(_) | types.Number(_) | types.String(_) -> {
      let encoded_value = primitives.encode_primitive(value, options.delimiter)
      let line = encoded_key <> ": " <> encoded_value
      writer.push(writer, depth, line)
    }

    // Arrays: delegate to array encoding
    Array(items) -> {
      // Import here to avoid circular dependency
      encode_array_for_key(key, items, writer, depth, options)
    }

    // Objects: nested object encoding
    Object(nested_fields) -> {
      encode_nested_object(encoded_key, nested_fields, writer, depth, options)
    }
  }
}

fn encode_nested_object(
  encoded_key: String,
  fields: List(#(String, JsonValue)),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  // Add the "key:" line
  let writer = writer.push(writer, depth, encoded_key <> ":")

  // Add nested fields at depth + 1
  case fields {
    [] -> writer
    _ -> encode_object(fields, writer, depth + 1, options)
  }
}

// Array encoding delegation

fn encode_array_for_key(
  key: String,
  items: List(JsonValue),
  writer: Writer,
  depth: Int,
  options: EncodeOptions,
) -> Writer {
  arrays.encode_array(Some(key), items, writer, depth, options)
}
