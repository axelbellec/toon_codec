//// Line writer for building TOON output with proper indentation.
////
//// This internal module provides an opaque Writer type that accumulates
//// lines with automatic indentation formatting.
//// Opaque type for building lines with indentation.
//// Create a new writer with the specified indentation size.
////
//// ## Examples
////
//// ```gleam
//// let writer = new(2)
//// ```
//// Add a line at the specified depth.
////
//// The depth is multiplied by indent_size to calculate the indentation.
////
//// ## Examples
////
//// ```gleam
//// let writer = new(2)
//// let writer = push(writer, 0, "name: Alice")
//// let writer = push(writer, 1, "id: 123")
//// ```
//// Convert the writer to a final string output.
////
//// Lines are reversed (since they were accumulated in reverse order)
//// and joined with newlines. No trailing newline is added.
////
//// ## Examples
////
//// ```gleam
//// let writer = new(2)
//// let writer = push(writer, 0, "name: Alice")
//// let writer = push(writer, 1, "id: 123")
//// to_string(writer)
//// // -> "name: Alice\n  id: 123"
//// ```
//// Check if the writer is empty (has no lines).
//// Get the number of lines in the writer.

import gleam/list
import gleam/string

// Writer type

pub opaque type Writer {
  Writer(indent_size: Int, lines: List(String))
}

// Public API

pub fn new(indent_size: Int) -> Writer {
  Writer(indent_size: indent_size, lines: [])
}

pub fn push(writer: Writer, depth: Int, line: String) -> Writer {
  let indent = string.repeat(" ", depth * writer.indent_size)
  let formatted_line = indent <> line
  Writer(..writer, lines: [formatted_line, ..writer.lines])
}

pub fn to_string(writer: Writer) -> String {
  writer.lines
  |> list.reverse
  |> string.join("\n")
}

pub fn is_empty(writer: Writer) -> Bool {
  list.is_empty(writer.lines)
}

pub fn line_count(writer: Writer) -> Int {
  list.length(writer.lines)
}
