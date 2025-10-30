//// Character classification utilities for TOON parsing.
////
//// This internal module provides functions to classify characters according
//// to TOON syntax rules (keys, numbers, etc.).
//// Check if a character can start an unquoted key.
////
//// Valid key start characters: A-Z, a-z, _
//// Check if a character can appear in an unquoted key.
////
//// Valid key characters: A-Z, a-z, 0-9, _, .
//// Check if a character is a digit (0-9).
//// Check if a character is whitespace (space or tab).
//// Check if a character is a newline (\n or \r).

import gleam/string
import gleam_toon/constants

// Character classification

pub fn is_key_start(char: String) -> Bool {
  string.contains(constants.key_start_chars, char)
}

pub fn is_key_char(char: String) -> Bool {
  string.contains(constants.key_chars, char)
}

pub fn is_digit(char: String) -> Bool {
  string.contains(constants.digits, char)
}

pub fn is_whitespace(char: String) -> Bool {
  char == " " || char == "\t"
}

pub fn is_newline(char: String) -> Bool {
  char == "\n" || char == "\r"
}
