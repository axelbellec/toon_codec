//// Line scanner and cursor for TOON decoding.
////
//// This module provides functions to scan input text into parsed lines
//// with depth information, and a cursor type for traversing those lines.
//// Scan input into a list of parsed lines with depth information.
////
//// Each line is analyzed for indentation, depth is calculated,
//// and blank lines are tracked.
////
//// ## Arguments
////
//// * `input` - The TOON format string to scan
//// * `indent_size` - Number of spaces per indentation level
//// * `strict` - Whether to enforce strict indentation rules
//// Parse a single line to extract depth and content.
//// Count leading spaces in a string.
//// Calculate indentation depth from leading spaces.
//// Opaque type for traversing parsed lines.
//// Create a new cursor from parsed lines.
//// Peek at the current line without advancing.
//// Advance the cursor to the next line.
//// Check if the cursor is at the end (no more lines).
//// Get the current position of the cursor.
//// Get the total number of lines.
//// Peek ahead at a line N positions from current.
//// Get all remaining lines from the current position.

import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleam_toon/error.{type ToonError}
import gleam_toon/types.{type ParsedLine}

// Line scanning

pub fn scan_lines(
  input: String,
  indent_size: Int,
  strict: Bool,
) -> Result(List(ParsedLine), ToonError) {
  let lines = string.split(input, "\n")

  scan_lines_loop(lines, [], indent_size, strict, 1)
}

fn scan_lines_loop(
  lines: List(String),
  acc: List(ParsedLine),
  indent_size: Int,
  strict: Bool,
  line_number: Int,
) -> Result(List(ParsedLine), ToonError) {
  case lines {
    [] -> Ok(list.reverse(acc))

    [line, ..rest] -> {
      // Skip completely blank lines
      case string.trim(line) {
        "" -> scan_lines_loop(rest, acc, indent_size, strict, line_number + 1)
        _ -> {
          case parse_line(line, line_number, indent_size, strict) {
            Ok(parsed) ->
              scan_lines_loop(
                rest,
                [parsed, ..acc],
                indent_size,
                strict,
                line_number + 1,
              )
            Error(err) -> Error(err)
          }
        }
      }
    }
  }
}

fn parse_line(
  raw: String,
  line_number: Int,
  indent_size: Int,
  strict: Bool,
) -> Result(ParsedLine, ToonError) {
  // Count leading spaces
  let indent = count_leading_spaces(raw)

  // Calculate depth
  case calculate_depth(indent, indent_size, strict, line_number) {
    Ok(depth) -> {
      let content = string.trim_start(raw)
      Ok(types.new_parsed_line(raw, depth, indent, content, line_number))
    }
    Error(err) -> Error(err)
  }
}

fn count_leading_spaces(s: String) -> Int {
  let chars = string.to_graphemes(s)
  count_leading_spaces_loop(chars, 0)
}

fn count_leading_spaces_loop(chars: List(String), count: Int) -> Int {
  case chars {
    [" ", ..rest] -> count_leading_spaces_loop(rest, count + 1)
    _ -> count
  }
}

fn calculate_depth(
  indent: Int,
  indent_size: Int,
  strict: Bool,
  line_number: Int,
) -> Result(Int, ToonError) {
  case strict {
    True -> {
      // In strict mode, indent must be exact multiple
      case indent % indent_size {
        0 -> Ok(indent / indent_size)
        _ ->
          Error(error.indentation_error(
            "Indentation must be a multiple of "
              <> int.to_string(indent_size)
              <> " spaces",
            line_number,
          ))
      }
    }
    False -> {
      // In non-strict mode, use floor division
      Ok(indent / indent_size)
    }
  }
}

// Line cursor

pub opaque type LineCursor {
  LineCursor(lines: List(ParsedLine), position: Int)
}

pub fn cursor_new(lines: List(ParsedLine)) -> LineCursor {
  LineCursor(lines: lines, position: 0)
}

pub fn cursor_peek(cursor: LineCursor) -> Option(ParsedLine) {
  cursor.lines
  |> list.drop(cursor.position)
  |> list.first
  |> option.from_result
}

pub fn cursor_advance(cursor: LineCursor) -> LineCursor {
  LineCursor(..cursor, position: cursor.position + 1)
}

pub fn cursor_at_end(cursor: LineCursor) -> Bool {
  cursor.position >= list.length(cursor.lines)
}

pub fn cursor_position(cursor: LineCursor) -> Int {
  cursor.position
}

pub fn cursor_length(cursor: LineCursor) -> Int {
  list.length(cursor.lines)
}

pub fn cursor_peek_ahead(cursor: LineCursor, offset: Int) -> Option(ParsedLine) {
  cursor.lines
  |> list.drop(cursor.position + offset)
  |> list.first
  |> option.from_result
}

pub fn cursor_remaining_lines(cursor: LineCursor) -> List(ParsedLine) {
  list.drop(cursor.lines, cursor.position)
}
