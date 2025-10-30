//// Main encoding module for converting JSON values to TOON format.
////
//// This module provides the primary encoding function that coordinates
//// the encoding of any JSON value to TOON format.
//// Encode a JSON value to TOON format string.
////
//// This is the main entry point for encoding. It handles all JSON value types:
//// - Primitives (null, booleans, numbers, strings)
//// - Arrays (inline, tabular, or expanded)
//// - Objects (flat or nested)
////
//// ## Examples
////
//// ```gleam
//// // Simple object
//// let value = Object([
////   #("name", JsonString("Alice")),
////   #("age", Number(30.0)),
//// ])
//// encode_value(value, default_encode_options())
//// // -> "name: Alice\nage: 30"
////
//// // Nested object
//// let value = Object([
////   #("user", Object([
////     #("id", Number(1.0)),
////     #("name", JsonString("Bob")),
////   ])),
//// ])
//// encode_value(value, default_encode_options())
//// // -> "user:\n  id: 1\n  name: Bob"
////
//// // Array
//// let value = Array([Number(1.0), Number(2.0), Number(3.0)])
//// encode_value(value, default_encode_options())
//// // -> "[3]: 1,2,3"
//// ```

import gleam/option.{None}
import gleam_toon/encode/arrays
import gleam_toon/encode/objects
import gleam_toon/encode/primitives
import gleam_toon/encode/writer
import gleam_toon/types.{
  type EncodeOptions, type JsonValue, Array, Bool, Null, Number, Object,
  String as JsonString,
}

// Main encoding function

pub fn encode_value(value: JsonValue, options: EncodeOptions) -> String {
  case value {
    // Root primitive - just encode it directly
    Null | Bool(_) | Number(_) | JsonString(_) ->
      primitives.encode_primitive(value, options.delimiter)

    // Root array - encode with no key
    Array(items) -> {
      let w = writer.new(options.indent)
      let w = arrays.encode_array(None, items, w, 0, options)
      writer.to_string(w)
    }

    // Root object - encode fields at depth 0
    Object(fields) -> {
      case fields {
        // Empty object -> empty document
        [] -> ""
        _ -> {
          let w = writer.new(options.indent)
          let w = objects.encode_object(fields, w, 0, options)
          writer.to_string(w)
        }
      }
    }
  }
}
