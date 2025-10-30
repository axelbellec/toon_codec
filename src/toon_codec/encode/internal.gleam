//// Internal utilities for array structure detection.
////
//// This module provides functions to analyze arrays and determine
//// whether they should be encoded as inline, tabular, or expanded form.
//// Check if a JSON value is a primitive (not array or object).
//// Check if a JSON value is an object.
//// Check if a JSON value is an array.
//// Check if all values in a list are primitives.
////
//// Returns True if the list is empty or all elements are primitives.
//// Check if all values in a list are arrays.
//// Check if all values in a list are objects.
//// Check if all arrays in a list contain only primitives.
////
//// Used to detect arrays of primitive arrays.
//// Detect if an array of objects can be encoded in tabular form.
////
//// Returns Some(fields) if tabular encoding is possible, where fields
//// is the ordered list of field names. Returns None otherwise.
////
//// Tabular encoding requires:
//// 1. All elements are objects
//// 2. All objects have the same set of keys
//// 3. All values in all objects are primitives (no nested structures)
////
//// ## Examples
////
//// ```gleam
//// let objects = [
////   Object([#("id", Number(1.0)), #("name", JsonString("Alice"))]),
////   Object([#("id", Number(2.0)), #("name", JsonString("Bob"))]),
//// ]
//// detect_tabular(objects)
//// // -> Some(["id", "name"])
//// ```
//// Check if all values in an object are primitives.
//// Check if all objects in a list have the same keys and all primitive values.
//// Extract field values from an object in a specified order.
////
//// Returns the values corresponding to the given field names,
//// in the same order as the field names list.
////
//// ## Examples
////
//// ```gleam
//// let obj = Object([#("name", JsonString("Alice")), #("id", Number(1.0))])
//// extract_field_values(obj, ["id", "name"])
//// // -> [Number(1.0), JsonString("Alice")]
//// ```

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set
import toon_codec/types.{
  type JsonValue, Array, Bool, Null, Number, Object, String as JsonString,
}

// Type predicates

pub fn is_primitive(value: JsonValue) -> Bool {
  case value {
    Null | Bool(_) | Number(_) | JsonString(_) -> True
    Array(_) | Object(_) -> False
  }
}

pub fn is_object(value: JsonValue) -> Bool {
  case value {
    Object(_) -> True
    _ -> False
  }
}

pub fn is_array(value: JsonValue) -> Bool {
  case value {
    Array(_) -> True
    _ -> False
  }
}

// Array structure detection

pub fn is_array_of_primitives(values: List(JsonValue)) -> Bool {
  list.all(values, is_primitive)
}

pub fn is_array_of_arrays(values: List(JsonValue)) -> Bool {
  case values {
    [] -> False
    _ -> list.all(values, is_array)
  }
}

pub fn is_array_of_objects(values: List(JsonValue)) -> Bool {
  case values {
    [] -> False
    _ -> list.all(values, is_object)
  }
}

pub fn all_arrays_of_primitives(values: List(JsonValue)) -> Bool {
  list.all(values, fn(value) {
    case value {
      Array(items) -> is_array_of_primitives(items)
      _ -> False
    }
  })
}

// Tabular detection

pub fn detect_tabular(values: List(JsonValue)) -> Option(List(String)) {
  case values {
    [] -> None
    [Object(first_fields), ..rest] -> {
      // Get field names from first object (in encounter order)
      let first_keys = list.map(first_fields, fn(pair) { pair.0 })

      // Check if first object has all primitive values
      case all_values_primitive(first_fields) {
        False -> None
        True -> {
          // Check if all other objects have the same keys and all primitive values
          case check_uniform_objects(rest, first_keys) {
            True -> Some(first_keys)
            False -> None
          }
        }
      }
    }
    _ -> None
  }
}

pub fn all_values_primitive(fields: List(#(String, JsonValue))) -> Bool {
  list.all(fields, fn(pair) { is_primitive(pair.1) })
}

fn check_uniform_objects(
  objects: List(JsonValue),
  expected_keys: List(String),
) -> Bool {
  list.all(objects, fn(obj) {
    case obj {
      Object(fields) -> {
        let keys = list.map(fields, fn(pair) { pair.0 })
        let keys_set = set.from_list(keys)
        let expected_set = set.from_list(expected_keys)

        // Check same keys and all primitive values
        keys_set == expected_set && all_values_primitive(fields)
      }
      _ -> False
    }
  })
}

// Object field extraction

pub fn extract_field_values(
  obj: JsonValue,
  field_names: List(String),
) -> List(JsonValue) {
  case obj {
    Object(fields) -> {
      list.map(field_names, fn(name) {
        case list.key_find(fields, name) {
          Ok(value) -> value
          Error(_) -> Null
        }
      })
    }
    _ -> []
  }
}
