//// Main decoding module for converting TOON format to JSON values.
////
//// This module provides the primary decoding function that coordinates
//// scanning, parsing, and reconstruction of JSON values from TOON format.
//// Decode TOON format string to JSON value.
////
//// This is the main entry point for decoding. It handles:
//// - Root primitives
//// - Root arrays
//// - Root objects
////
//// ## Examples
////
//// ```gleam
//// // Simple object
//// decode_value("name: Alice\nage: 30", default_decode_options())
//// // -> Ok(Object([#("name", String("Alice")), #("age", Number(30.0))]))
////
//// // Root array
//// decode_value("[3]: 1,2,3", default_decode_options())
//// // -> Ok(Array([Number(1.0), Number(2.0), Number(3.0)]))
//// ```
//// Detect the type of root value.
//// Decode based on detected root form.
//// Decode an object from the cursor at the given depth.
//// Decode a key-value pair from a line.
//// Decode an array from its header.
//// Decode an inline primitive array.
//// Decode a tabular array.
//// Decode a list array (expanded form).
//// Decode a single list item.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import toon_codec/constants
import toon_codec/decode/parser
import toon_codec/decode/scanner.{type LineCursor}
import toon_codec/decode/validation
import toon_codec/error.{type ToonError}
import toon_codec/types.{
  type ArrayHeader, type DecodeOptions, type JsonValue, type ParsedLine,
  type RootForm, Array, Object, RootArray, RootObject, RootPrimitive,
}

// Main decoding function

pub fn decode_value(
  input: String,
  options: DecodeOptions,
) -> Result(JsonValue, ToonError) {
  // Scan lines
  case scanner.scan_lines(input, options.indent, options.strict) {
    Ok(lines) -> {
      case lines {
        [] -> Error(error.EmptyInput)
        _ -> {
          let cursor = scanner.cursor_new(lines)
          case detect_root_form(cursor) {
            Ok(form) -> decode_by_form(form, cursor, options)
            Error(err) -> Error(err)
          }
        }
      }
    }
    Error(err) -> Error(err)
  }
}

// Root form detection

fn detect_root_form(cursor: LineCursor) -> Result(RootForm, ToonError) {
  case scanner.cursor_peek(cursor) {
    None -> Error(error.EmptyInput)
    Some(first) -> {
      let content = types.parsed_line_content(first)

      // Check if it's an array header
      case parser.is_array_header(content) {
        True -> Ok(RootArray)
        False -> {
          // Check if single line and not key-value
          case scanner.cursor_length(cursor) == 1 {
            True -> {
              case parser.is_key_value_line(content) {
                False -> {
                  // Single primitive
                  case parser.parse_primitive(content) {
                    Ok(value) -> Ok(RootPrimitive(value))
                    Error(err) -> Error(err)
                  }
                }
                True -> Ok(RootObject)
              }
            }
            False -> Ok(RootObject)
          }
        }
      }
    }
  }
}

fn decode_by_form(
  form: RootForm,
  cursor: LineCursor,
  options: DecodeOptions,
) -> Result(JsonValue, ToonError) {
  case form {
    RootPrimitive(value) -> Ok(value)
    RootArray -> decode_root_array(cursor, options)
    RootObject -> decode_root_object(cursor, options)
  }
}

// Root array decoding

fn decode_root_array(
  cursor: LineCursor,
  options: DecodeOptions,
) -> Result(JsonValue, ToonError) {
  case scanner.cursor_peek(cursor) {
    Some(line) -> {
      let content = types.parsed_line_content(line)
      case parser.parse_array_header(content) {
        Ok(#(header, inline_values)) -> {
          let cursor = scanner.cursor_advance(cursor)
          case
            decode_array_from_header(header, inline_values, cursor, 0, options)
          {
            Ok(#(items, _)) -> Ok(Array(items))
            Error(err) -> Error(err)
          }
        }
        Error(err) -> Error(err)
      }
    }
    None -> Error(error.EmptyInput)
  }
}

// Root object decoding

fn decode_root_object(
  cursor: LineCursor,
  options: DecodeOptions,
) -> Result(JsonValue, ToonError) {
  case decode_object(cursor, 0, options) {
    Ok(#(fields, _)) -> Ok(Object(fields))
    Error(err) -> Error(err)
  }
}

// Object decoding

fn decode_object(
  cursor: LineCursor,
  base_depth: Int,
  options: DecodeOptions,
) -> Result(#(List(#(String, JsonValue)), LineCursor), ToonError) {
  decode_object_loop(cursor, base_depth, options, [])
}

fn decode_object_loop(
  cursor: LineCursor,
  base_depth: Int,
  options: DecodeOptions,
  acc: List(#(String, JsonValue)),
) -> Result(#(List(#(String, JsonValue)), LineCursor), ToonError) {
  case scanner.cursor_peek(cursor) {
    None -> Ok(#(list.reverse(acc), cursor))
    Some(line) -> {
      let depth = types.parsed_line_depth(line)

      case depth < base_depth {
        True -> Ok(#(list.reverse(acc), cursor))
        False ->
          case depth == base_depth {
            True -> {
              // Process this key-value pair
              case decode_key_value_pair(line, cursor, base_depth, options) {
                Ok(#(key, value, new_cursor)) ->
                  decode_object_loop(new_cursor, base_depth, options, [
                    #(key, value),
                    ..acc
                  ])
                Error(err) -> Error(err)
              }
            }
            False -> Ok(#(list.reverse(acc), cursor))
          }
      }
    }
  }
}

fn decode_key_value_pair(
  line: ParsedLine,
  cursor: LineCursor,
  base_depth: Int,
  options: DecodeOptions,
) -> Result(#(String, JsonValue, LineCursor), ToonError) {
  let content = types.parsed_line_content(line)

  // Check for array header first
  case parser.parse_array_header(content) {
    Ok(#(header, inline_values)) -> {
      case header.key {
        Some(key) -> {
          let cursor = scanner.cursor_advance(cursor)
          case
            decode_array_from_header(
              header,
              inline_values,
              cursor,
              base_depth,
              options,
            )
          {
            Ok(#(items, new_cursor)) -> Ok(#(key, Array(items), new_cursor))
            Error(err) -> Error(err)
          }
        }
        None ->
          Error(error.structure_error(
            "Array header without key in object context",
          ))
      }
    }
    Error(_) -> {
      // Not an array header, parse as regular key-value
      case parser.parse_key(content) {
        Ok(#(key, pos)) -> {
          let rest = string.slice(content, pos, 1000) |> string.trim_start

          case rest {
            // No value after colon - nested object or empty
            "" -> {
              let cursor = scanner.cursor_advance(cursor)
              case decode_object(cursor, base_depth + 1, options) {
                Ok(#(nested_fields, new_cursor)) ->
                  Ok(#(key, Object(nested_fields), new_cursor))
                Error(err) -> Error(err)
              }
            }
            // Has value - parse as primitive
            _ -> {
              case parser.parse_primitive(rest) {
                Ok(value) -> {
                  let cursor = scanner.cursor_advance(cursor)
                  Ok(#(key, value, cursor))
                }
                Error(err) -> Error(err)
              }
            }
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

// Array decoding

fn decode_array_from_header(
  header: ArrayHeader,
  inline_values: Option(String),
  cursor: LineCursor,
  base_depth: Int,
  options: DecodeOptions,
) -> Result(#(List(JsonValue), LineCursor), ToonError) {
  case inline_values {
    // Inline primitive array
    Some(values_str) -> {
      case decode_inline_array(values_str, header.delimiter, header.length) {
        Ok(values) -> {
          case options.strict {
            True -> {
              case
                validation.validate_count(
                  header.length,
                  list.length(values),
                  "inline array",
                )
              {
                Ok(_) -> Ok(#(values, cursor))
                Error(err) -> Error(err)
              }
            }
            False -> Ok(#(values, cursor))
          }
        }
        Error(err) -> Error(err)
      }
    }
    // Array with nested content
    None -> {
      case header.fields {
        // Tabular array
        Some(fields) ->
          decode_tabular_array(
            header.length,
            fields,
            header.delimiter,
            cursor,
            base_depth,
            options,
          )
        // List array
        None ->
          decode_list_array(
            header.length,
            header.delimiter,
            cursor,
            base_depth,
            options,
          )
      }
    }
  }
}

fn decode_inline_array(
  values_str: String,
  delimiter: types.Delimiter,
  _expected_length: Int,
) -> Result(List(JsonValue), ToonError) {
  let tokens = parser.parse_delimited_values(values_str, delimiter)
  parse_tokens_to_values(tokens, [])
}

fn parse_tokens_to_values(
  tokens: List(String),
  acc: List(JsonValue),
) -> Result(List(JsonValue), ToonError) {
  case tokens {
    [] -> Ok(list.reverse(acc))
    [token, ..rest] -> {
      case parser.parse_primitive(token) {
        Ok(value) -> parse_tokens_to_values(rest, [value, ..acc])
        Error(err) -> Error(err)
      }
    }
  }
}

fn decode_tabular_array(
  expected_length: Int,
  fields: List(String),
  delimiter: types.Delimiter,
  cursor: LineCursor,
  base_depth: Int,
  options: DecodeOptions,
) -> Result(#(List(JsonValue), LineCursor), ToonError) {
  let expected_width = list.length(fields)
  decode_tabular_rows(
    cursor,
    base_depth + 1,
    fields,
    delimiter,
    expected_width,
    options,
    [],
    0,
    expected_length,
  )
}

fn decode_tabular_rows(
  cursor: LineCursor,
  row_depth: Int,
  fields: List(String),
  delimiter: types.Delimiter,
  expected_width: Int,
  options: DecodeOptions,
  acc: List(JsonValue),
  row_count: Int,
  expected_length: Int,
) -> Result(#(List(JsonValue), LineCursor), ToonError) {
  case scanner.cursor_peek(cursor) {
    None -> {
      // End of input
      case options.strict {
        True -> {
          case
            validation.validate_count(
              expected_length,
              row_count,
              "tabular rows",
            )
          {
            Ok(_) -> Ok(#(list.reverse(acc), cursor))
            Error(err) -> Error(err)
          }
        }
        False -> Ok(#(list.reverse(acc), cursor))
      }
    }
    Some(line) -> {
      let depth = types.parsed_line_depth(line)

      case depth < row_depth {
        True -> {
          // End of rows
          case options.strict {
            True -> {
              case
                validation.validate_count(
                  expected_length,
                  row_count,
                  "tabular rows",
                )
              {
                Ok(_) -> Ok(#(list.reverse(acc), cursor))
                Error(err) -> Error(err)
              }
            }
            False -> Ok(#(list.reverse(acc), cursor))
          }
        }
        False ->
          case depth == row_depth {
            True -> {
              // Parse this row
              let content = types.parsed_line_content(line)
              let values = parser.parse_delimited_values(content, delimiter)

              // Validate width
              case options.strict {
                True -> {
                  case
                    validation.validate_row_width(
                      expected_width,
                      list.length(values),
                      row_count + 1,
                    )
                  {
                    Ok(_) -> {
                      case parse_tokens_to_values(values, []) {
                        Ok(parsed_values) -> {
                          let obj =
                            list.zip(fields, parsed_values)
                            |> Object
                          decode_tabular_rows(
                            scanner.cursor_advance(cursor),
                            row_depth,
                            fields,
                            delimiter,
                            expected_width,
                            options,
                            [obj, ..acc],
                            row_count + 1,
                            expected_length,
                          )
                        }
                        Error(err) -> Error(err)
                      }
                    }
                    Error(err) -> Error(err)
                  }
                }
                False -> {
                  case parse_tokens_to_values(values, []) {
                    Ok(parsed_values) -> {
                      let obj = list.zip(fields, parsed_values) |> Object
                      decode_tabular_rows(
                        scanner.cursor_advance(cursor),
                        row_depth,
                        fields,
                        delimiter,
                        expected_width,
                        options,
                        [obj, ..acc],
                        row_count + 1,
                        expected_length,
                      )
                    }
                    Error(err) -> Error(err)
                  }
                }
              }
            }
            False ->
              Error(error.structure_error(
                "Unexpected indentation in tabular array",
              ))
          }
      }
    }
  }
}

fn decode_list_array(
  expected_length: Int,
  _delimiter: types.Delimiter,
  cursor: LineCursor,
  base_depth: Int,
  options: DecodeOptions,
) -> Result(#(List(JsonValue), LineCursor), ToonError) {
  decode_list_items(cursor, base_depth + 1, options, [], 0, expected_length)
}

fn decode_list_items(
  cursor: LineCursor,
  item_depth: Int,
  options: DecodeOptions,
  acc: List(JsonValue),
  item_count: Int,
  expected_length: Int,
) -> Result(#(List(JsonValue), LineCursor), ToonError) {
  case scanner.cursor_peek(cursor) {
    None -> {
      case options.strict {
        True -> {
          case
            validation.validate_count(expected_length, item_count, "list items")
          {
            Ok(_) -> Ok(#(list.reverse(acc), cursor))
            Error(err) -> Error(err)
          }
        }
        False -> Ok(#(list.reverse(acc), cursor))
      }
    }
    Some(line) -> {
      let depth = types.parsed_line_depth(line)

      case depth < item_depth {
        True -> {
          case options.strict {
            True -> {
              case
                validation.validate_count(
                  expected_length,
                  item_count,
                  "list items",
                )
              {
                Ok(_) -> Ok(#(list.reverse(acc), cursor))
                Error(err) -> Error(err)
              }
            }
            False -> Ok(#(list.reverse(acc), cursor))
          }
        }
        False ->
          case depth == item_depth {
            True -> {
              let content = types.parsed_line_content(line)
              // Check if it starts with list marker
              case string.starts_with(content, constants.list_item_prefix) {
                True -> {
                  let after_hyphen =
                    string.drop_start(content, 2) |> string.trim_start
                  case
                    decode_list_item(after_hyphen, cursor, item_depth, options)
                  {
                    Ok(#(item, new_cursor)) ->
                      decode_list_items(
                        new_cursor,
                        item_depth,
                        options,
                        [item, ..acc],
                        item_count + 1,
                        expected_length,
                      )
                    Error(err) -> Error(err)
                  }
                }
                False ->
                  Error(error.structure_error(
                    "Expected list item (line starting with '- ')",
                  ))
              }
            }
            False ->
              Error(error.structure_error(
                "Unexpected indentation in list array",
              ))
          }
      }
    }
  }
}

fn decode_list_item(
  after_hyphen: String,
  cursor: LineCursor,
  item_depth: Int,
  options: DecodeOptions,
) -> Result(#(JsonValue, LineCursor), ToonError) {
  // Check for array header
  case parser.parse_array_header(after_hyphen) {
    Ok(#(header, inline_values)) -> {
      let cursor = scanner.cursor_advance(cursor)
      case
        decode_array_from_header(
          header,
          inline_values,
          cursor,
          item_depth,
          options,
        )
      {
        Ok(#(items, new_cursor)) -> Ok(#(Array(items), new_cursor))
        Error(err) -> Error(err)
      }
    }
    Error(_) -> {
      // Check for key-value (object as list item)
      case parser.is_key_value_line(after_hyphen) {
        True -> {
          case parser.parse_key(after_hyphen) {
            Ok(#(key, pos)) -> {
              let rest =
                string.slice(after_hyphen, pos, 1000) |> string.trim_start

              case rest {
                "" -> {
                  // Nested object on first field
                  let cursor = scanner.cursor_advance(cursor)
                  case decode_object(cursor, item_depth + 2, options) {
                    Ok(#(nested_fields, cursor2)) -> {
                      // Also get sibling fields at item_depth + 1
                      case decode_object(cursor2, item_depth + 1, options) {
                        Ok(#(sibling_fields, new_cursor)) -> {
                          let all_fields =
                            list.append(
                              [#(key, Object(nested_fields))],
                              sibling_fields,
                            )
                          Ok(#(Object(all_fields), new_cursor))
                        }
                        Error(err) -> Error(err)
                      }
                    }
                    Error(err) -> Error(err)
                  }
                }
                _ -> {
                  // Primitive value
                  case parser.parse_primitive(rest) {
                    Ok(value) -> {
                      let cursor = scanner.cursor_advance(cursor)
                      // Get remaining fields at item_depth + 1
                      case decode_object(cursor, item_depth + 1, options) {
                        Ok(#(other_fields, new_cursor)) -> {
                          let all_fields = [#(key, value), ..other_fields]
                          Ok(#(Object(all_fields), new_cursor))
                        }
                        Error(err) -> Error(err)
                      }
                    }
                    Error(err) -> Error(err)
                  }
                }
              }
            }
            Error(err) -> Error(err)
          }
        }
        False -> {
          // Primitive item
          case parser.parse_primitive(after_hyphen) {
            Ok(value) -> {
              let cursor = scanner.cursor_advance(cursor)
              Ok(#(value, cursor))
            }
            Error(err) -> Error(err)
          }
        }
      }
    }
  }
}
