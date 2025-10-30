//// Core type definitions for the TOON encoder/decoder.
////
//// This module defines the JSON value representation, configuration options,
//// and internal types used throughout the library.
//// Represents a JSON value that can be encoded/decoded to TOON format.
////
//// This type is compatible with standard JSON representations and preserves
//// key ordering for objects.
////
//// ## Examples
////
//// ```gleam
//// let user = Object([
////   #("name", String("Alice")),
////   #("age", Number(30.0)),
////   #("active", Bool(True)),
//// ])
//// ```
//// Delimiter character used to separate values in arrays and tabular rows.
////
//// The delimiter determines how inline primitive arrays and tabular data
//// are formatted and parsed.
//// Converts a delimiter to its string representation.
//// Optional marker to prefix array lengths in headers.
////
//// When set to HashMarker, arrays render as [#N] instead of [N].
//// Configuration options for encoding JSON values to TOON format.
////
//// ## Examples
////
//// ```gleam
//// let options = EncodeOptions(
////   indent: 2,
////   delimiter: Comma,
////   length_marker: NoMarker,
//// )
//// ```
//// Returns the default encoding options.
////
//// ## Examples
////
//// ```gleam
//// let options = default_encode_options()
//// // EncodeOptions(indent: 2, delimiter: Comma, length_marker: NoMarker)
//// ```
//// Configuration options for decoding TOON format to JSON values.
////
//// ## Examples
////
//// ```gleam
//// let options = DecodeOptions(indent: 2, strict: True)
//// ```
//// Returns the default decoding options.
////
//// ## Examples
////
//// ```gleam
//// let options = default_decode_options()
//// // DecodeOptions(indent: 2, strict: True)
//// ```
//// Internal: Represents a parsed line with depth and metadata.
////
//// This opaque type is used internally by the decoder to track line information
//// during parsing. The depth indicates the indentation level.
//// Create a new ParsedLine.
//// Get the depth of a parsed line.
//// Get the content of a parsed line.
//// Get the line number of a parsed line.
//// Get the indent of a parsed line.
//// Internal: Information parsed from an array header line.
////
//// This type represents the structured data extracted from headers like:
//// - `[3]:` (inline primitive array)
//// - `items[2]:` (named array)
//// - `users[2]{id,name}:` (tabular array)
//// Internal: Type of root value in a TOON document.

import gleam/option.{type Option}

// JSON types

pub type JsonValue {
  /// Represents a null value
  Null
  /// Represents a boolean value (true or false)
  Bool(Bool)
  /// Represents a numeric value (integers and floats are both Float in Gleam)
  Number(Float)
  /// Represents a string value
  String(String)
  /// Represents an array of JSON values
  Array(List(JsonValue))
  /// Represents an object as an ordered list of key-value pairs
  Object(List(#(String, JsonValue)))
}

// Delimiter types

pub type Delimiter {
  /// Comma delimiter "," (default)
  Comma
  /// Tab delimiter (HTAB, U+0009)
  Tab
  /// Pipe delimiter "|"
  Pipe
}

pub fn delimiter_to_string(delimiter: Delimiter) -> String {
  case delimiter {
    Comma -> ","
    Tab -> "\t"
    Pipe -> "|"
  }
}

// Length marker

pub type LengthMarker {
  /// No length marker (default): [3]
  NoMarker
  /// Hash marker prefix: [#3]
  HashMarker
}

// Encoding options

pub type EncodeOptions {
  EncodeOptions(
    /// Number of spaces per indentation level (default: 2)
    indent: Int,
    /// Delimiter for arrays and tabular data (default: Comma)
    delimiter: Delimiter,
    /// Optional length marker in array headers (default: NoMarker)
    length_marker: LengthMarker,
  )
}

pub fn default_encode_options() -> EncodeOptions {
  EncodeOptions(indent: 2, delimiter: Comma, length_marker: NoMarker)
}

// Decoding options

pub type DecodeOptions {
  DecodeOptions(
    /// Number of spaces per indentation level (default: 2)
    indent: Int,
    /// Enable strict mode validation (default: True)
    strict: Bool,
  )
}

pub fn default_decode_options() -> DecodeOptions {
  DecodeOptions(indent: 2, strict: True)
}

// Internal decoder types

pub opaque type ParsedLine {
  ParsedLine(
    /// The raw line content including indentation
    raw: String,
    /// The indentation depth (0 = root level)
    depth: Int,
    /// Number of leading spaces
    indent: Int,
    /// The line content with indentation removed
    content: String,
    /// Line number in the original input (1-indexed)
    line_number: Int,
  )
}

pub fn new_parsed_line(
  raw: String,
  depth: Int,
  indent: Int,
  content: String,
  line_number: Int,
) -> ParsedLine {
  ParsedLine(
    raw: raw,
    depth: depth,
    indent: indent,
    content: content,
    line_number: line_number,
  )
}

pub fn parsed_line_depth(line: ParsedLine) -> Int {
  line.depth
}

pub fn parsed_line_content(line: ParsedLine) -> String {
  line.content
}

pub fn parsed_line_number(line: ParsedLine) -> Int {
  line.line_number
}

pub fn parsed_line_indent(line: ParsedLine) -> Int {
  line.indent
}

// Internal array header

pub type ArrayHeader {
  ArrayHeader(
    /// Optional key name for the array
    key: Option(String),
    /// Declared array length
    length: Int,
    /// Active delimiter for this array's scope
    delimiter: Delimiter,
    /// Optional field names for tabular arrays
    fields: Option(List(String)),
    /// Whether the length marker "#" was present
    has_length_marker: Bool,
  )
}

// Root form detection

pub type RootForm {
  /// Root is an array (starts with array header)
  RootArray
  /// Root is an object (key-value pairs at depth 0)
  RootObject
  /// Root is a single primitive value
  RootPrimitive(JsonValue)
}
