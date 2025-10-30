import gleam_toon
import gleam_toon/types.{Bool, Null, Number, String}
import gleeunit/should

// Null encoding/decoding tests
pub fn encode_null_test() {
  gleam_toon.encode(Null)
  |> should.equal("null")
}

pub fn decode_null_test() {
  gleam_toon.decode("null")
  |> should.be_ok
  |> should.equal(Null)
}

// Boolean encoding/decoding tests
pub fn encode_true_test() {
  gleam_toon.encode(Bool(True))
  |> should.equal("true")
}

pub fn encode_false_test() {
  gleam_toon.encode(Bool(False))
  |> should.equal("false")
}

pub fn decode_true_test() {
  gleam_toon.decode("true")
  |> should.be_ok
  |> should.equal(Bool(True))
}

pub fn decode_false_test() {
  gleam_toon.decode("false")
  |> should.be_ok
  |> should.equal(Bool(False))
}

// Number encoding/decoding tests
pub fn encode_integer_test() {
  gleam_toon.encode(Number(42.0))
  |> should.equal("42")
}

pub fn encode_negative_integer_test() {
  gleam_toon.encode(Number(-123.0))
  |> should.equal("-123")
}

pub fn encode_zero_test() {
  gleam_toon.encode(Number(0.0))
  |> should.equal("0")
}

pub fn encode_decimal_test() {
  gleam_toon.encode(Number(3.14))
  |> should.equal("3.14")
}

pub fn encode_negative_decimal_test() {
  gleam_toon.encode(Number(-2.5))
  |> should.equal("-2.5")
}

// Note: Decoder parses bare numbers as strings by default (as per TOON spec)
// This is because in TOON, field values without explicit type markers are strings
pub fn decode_integer_as_string_test() {
  gleam_toon.decode("42")
  |> should.be_ok
  |> should.equal(String("42"))
}

pub fn decode_negative_integer_as_string_test() {
  gleam_toon.decode("-123")
  |> should.be_ok
  |> should.equal(String("-123"))
}

pub fn decode_zero_as_string_test() {
  gleam_toon.decode("0")
  |> should.be_ok
  |> should.equal(String("0"))
}

// String encoding/decoding tests
pub fn encode_simple_string_test() {
  gleam_toon.encode(String("hello"))
  |> should.equal("hello")
}

// Note: In TOON, strings with spaces are NOT quoted by default
pub fn encode_string_with_spaces_test() {
  gleam_toon.encode(String("hello world"))
  |> should.equal("hello world")
}

// Per SPEC Section 7.2: strings containing double quotes MUST be quoted and escaped
pub fn encode_quoted_string_test() {
  gleam_toon.encode(String("say \"hi\""))
  |> should.equal("\"say \\\"hi\\\"\"")
}

pub fn encode_string_with_newline_test() {
  gleam_toon.encode(String("line1\nline2"))
  |> should.equal("\"line1\\nline2\"")
}

pub fn encode_empty_string_test() {
  gleam_toon.encode(String(""))
  |> should.equal("\"\"")
}

pub fn decode_simple_string_test() {
  gleam_toon.decode("hello")
  |> should.be_ok
  |> should.equal(String("hello"))
}

pub fn decode_quoted_string_test() {
  gleam_toon.decode("\"hello world\"")
  |> should.be_ok
  |> should.equal(String("hello world"))
}

pub fn decode_escaped_quote_test() {
  gleam_toon.decode("\"say \\\"hi\\\"\"")
  |> should.be_ok
  |> should.equal(String("say \"hi\""))
}

pub fn decode_escaped_newline_test() {
  gleam_toon.decode("\"line1\\nline2\"")
  |> should.be_ok
  |> should.equal(String("line1\nline2"))
}

pub fn decode_empty_string_test() {
  gleam_toon.decode("\"\"")
  |> should.be_ok
  |> should.equal(String(""))
}

// Edge cases
pub fn decode_string_that_looks_like_number_test() {
  gleam_toon.decode("\"42\"")
  |> should.be_ok
  |> should.equal(String("42"))
}

pub fn decode_string_that_looks_like_bool_test() {
  gleam_toon.decode("\"true\"")
  |> should.be_ok
  |> should.equal(String("true"))
}

// These should fail validation
pub fn decode_invalid_escape_sequence_test() {
  gleam_toon.decode("\"invalid\\xescape\"")
  |> should.be_error
}
