import gleam_toon
import gleam_toon/types.{Array, Bool, Null, Number, Object, String}
import gleeunit/should

// Simple object encoding/decoding
pub fn encode_empty_object_test() {
  gleam_toon.encode(Object([]))
  |> should.equal("")
}

pub fn decode_empty_object_test() {
  gleam_toon.decode("")
  |> should.be_error
  // Empty input is invalid
}

pub fn encode_simple_object_test() {
  let obj = Object([#("name", String("Alice")), #("age", Number(30.0))])
  let result = gleam_toon.encode(obj)

  // TOON format: key: value on separate lines
  result
  |> should.equal("name: Alice\nage: 30")
}

pub fn decode_simple_object_test() {
  let input = "name: Alice\nage: 30"

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(Object([#("name", String("Alice")), #("age", String("30"))]))
}

pub fn encode_object_with_quoted_keys_test() {
  let obj = Object([#("first name", String("Bob"))])

  gleam_toon.encode(obj)
  |> should.equal("\"first name\": Bob")
}

pub fn decode_object_with_quoted_keys_test() {
  let input = "\"first name\": Bob"

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(Object([#("first name", String("Bob"))]))
}

pub fn encode_object_with_all_types_test() {
  let obj =
    Object([
      #("str", String("hello")),
      #("num", Number(42.0)),
      #("bool", Bool(True)),
      #("null", Null),
    ])

  let result = gleam_toon.encode(obj)

  result
  |> should.equal("str: hello\nnum: 42\nbool: true\nnull: null")
}

pub fn decode_object_with_all_types_test() {
  let input = "str: hello\nnum: 42\nbool: true\nnull: null"

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(
    Object([
      #("str", String("hello")),
      #("num", String("42")),
      // Numbers decoded as strings unless in special context
      #("bool", Bool(True)),
      #("null", Null),
    ]),
  )
}

// Nested objects
// Per SPEC Section 7.2: numeric-like strings (e.g. "10001") MUST be quoted
pub fn encode_nested_object_test() {
  let obj =
    Object([
      #("name", String("Alice")),
      #(
        "address",
        Object([#("city", String("NYC")), #("zip", String("10001"))]),
      ),
    ])

  let result = gleam_toon.encode(obj)

  result
  |> should.equal("name: Alice\naddress:\n  city: NYC\n  zip: \"10001\"")
}

pub fn decode_nested_object_test() {
  let input = "name: Alice\naddress:\n  city: NYC\n  zip: 10001"

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(
    Object([
      #("name", String("Alice")),
      #(
        "address",
        Object([#("city", String("NYC")), #("zip", String("10001"))]),
      ),
    ]),
  )
}

pub fn encode_deeply_nested_object_test() {
  let obj =
    Object([
      #(
        "level1",
        Object([
          #(
            "level2",
            Object([#("level3", Object([#("value", String("deep"))]))]),
          ),
        ]),
      ),
    ])

  let result = gleam_toon.encode(obj)

  result
  |> should.equal("level1:\n  level2:\n    level3:\n      value: deep")
}

pub fn decode_deeply_nested_object_test() {
  let input = "level1:\n  level2:\n    level3:\n      value: deep"

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(
    Object([
      #(
        "level1",
        Object([
          #(
            "level2",
            Object([#("level3", Object([#("value", String("deep"))]))]),
          ),
        ]),
      ),
    ]),
  )
}

// Object with array values
pub fn encode_object_with_array_test() {
  let obj =
    Object([
      #("name", String("Alice")),
      #("scores", Array([Number(90.0), Number(85.0), Number(92.0)])),
    ])

  let result = gleam_toon.encode(obj)

  // Arrays in objects use the [count]: format
  result
  |> should.equal("name: Alice\nscores[3]: 90,85,92")
}

pub fn decode_object_with_array_test() {
  let input = "name: Alice\nscores[3]: 90,85,92"

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(
    Object([
      #("name", String("Alice")),
      #("scores", Array([String("90"), String("85"), String("92")])),
    ]),
  )
}

// Edge cases
pub fn encode_object_with_empty_string_value_test() {
  let obj = Object([#("empty", String(""))])

  gleam_toon.encode(obj)
  |> should.equal("empty: \"\"")
}

pub fn decode_object_with_empty_string_value_test() {
  let input = "empty: \"\""

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(Object([#("empty", String(""))]))
}

pub fn encode_object_with_numeric_string_value_test() {
  let obj = Object([#("id", String("123"))])

  gleam_toon.encode(obj)
  |> should.equal("id: \"123\"")
}

pub fn decode_object_with_colon_in_value_test() {
  let input = "time: \"12:30\""

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(Object([#("time", String("12:30"))]))
}

// Object with special characters
pub fn encode_object_with_spaces_in_value_test() {
  let obj = Object([#("text", String("hello world"))])

  gleam_toon.encode(obj)
  |> should.equal("text: hello world")
}

pub fn decode_object_with_spaces_in_value_test() {
  let input = "text: hello world"

  gleam_toon.decode(input)
  |> should.be_ok
  |> should.equal(Object([#("text", String("hello world"))]))
}
