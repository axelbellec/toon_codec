//// TOON (Token-Oriented Object Notation) encoder/decoder for Gleam.
////
//// TOON is a compact, human-readable format for LLM input that reduces
//// token usage compared to JSON while maintaining readability.
////
//// This library provides encoding and decoding functions for converting
//// between JSON-like values and TOON format strings.
////
//// ## Quick Start
////
//// ```gleam
//// import toon_codec.{type JsonValue, Object, String, Number}
////
//// pub fn main() {
////   // Create a JSON value
////   let user = Object([
////     #("name", String("Alice")),
////     #("age", Number(30.0)),
////     #("active", Bool(True)),
////   ])
////
////   // Encode to TOON
////   let toon_str = toon_codec.encode(user)
////   // Result: "name: Alice\nage: 30\nactive: true"
////
////   // Decode back to JSON
////   case toon_codec.decode(toon_str) {
////     Ok(decoded) -> // Process the decoded value
////     Error(err) -> // Handle the error
////   }
//// }
//// ```
////
//// ## Custom Options
////
//// ```gleam
//// import toon_codec.{EncodeOptions, Tab}
////
//// let options = EncodeOptions(
////   indent: 4,
////   delimiter: Tab,
////   length_marker: HashMarker,
//// )
////
//// let toon = toon_codec.encode_with_options(value, options)
//// ```
//// Encode a JSON value to TOON format with default options.
////
//// Default options:
//// - indent: 2 spaces
//// - delimiter: comma
//// - length_marker: no marker
////
//// ## Examples
////
//// ```gleam
//// let value = Object([
////   #("name", String("Alice")),
////   #("age", Number(30.0)),
//// ])
//// encode(value)
//// // -> "name: Alice\nage: 30"
//// ```
//// Encode a JSON value to TOON format with custom options.
////
//// ## Examples
////
//// ```gleam
//// let options = EncodeOptions(
////   indent: 4,
////   delimiter: Tab,
////   length_marker: HashMarker,
//// )
//// encode_with_options(value, options)
//// ```
//// Decode TOON format to JSON value with default options.
////
//// Default options:
//// - indent: 2 spaces
//// - strict: true
////
//// ## Examples
////
//// ```gleam
//// decode("name: Alice\nage: 30")
//// // -> Ok(Object([#("name", String("Alice")), #("age", Number(30.0))]))
//// ```
//// Decode TOON format to JSON value with custom options.
////
//// ## Examples
////
//// ```gleam
//// let options = DecodeOptions(indent: 4, strict: False)
//// decode_with_options(input, options)
//// ```
//// Get the default encoding options.
////
//// Returns:
//// - indent: 2
//// - delimiter: Comma
//// - length_marker: NoMarker
//// Get the default decoding options.
////
//// Returns:
//// - indent: 2
//// - strict: True

import toon_codec/decode
import toon_codec/encode

// Re-export all public types and constructors
pub type JsonValue =
  types.JsonValue

pub type EncodeOptions =
  types.EncodeOptions

pub type DecodeOptions =
  types.DecodeOptions

pub type ToonError =
  error.ToonError

pub type Delimiter =
  types.Delimiter

pub type LengthMarker =
  types.LengthMarker

// Import just types and error type for re-export
import toon_codec/error
import toon_codec/types

// Encoding

pub fn encode(value: JsonValue) -> String {
  let options = types.default_encode_options()
  encode.encode_value(value, options)
}

pub fn encode_with_options(value: JsonValue, options: EncodeOptions) -> String {
  encode.encode_value(value, options)
}

// Decoding

pub fn decode(input: String) -> Result(JsonValue, ToonError) {
  let options = types.default_decode_options()
  decode.decode_value(input, options)
}

pub fn decode_with_options(
  input: String,
  options: DecodeOptions,
) -> Result(JsonValue, ToonError) {
  decode.decode_value(input, options)
}

// Options helpers

pub fn default_encode_options() -> EncodeOptions {
  types.default_encode_options()
}

pub fn default_decode_options() -> DecodeOptions {
  types.default_decode_options()
}
