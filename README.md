# gleam_toon

[![Package Version](https://img.shields.io/hexpm/v/gleam_toon)](https://hex.pm/packages/gleam_toon)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleam_toon/)
![Tests](https://img.shields.io/badge/tests-113%20passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

A Gleam implementation of TOON (Token-Oriented Object Notation) - a compact, human-readable format designed to reduce token usage in Large Language Model (LLM) input.

## Origin

gleam_toon is a Gleam port of the original TOON format created by _Johann Schopplich_ →
https://github.com/johannschopplich/toon/tree/main

## About TOON

TOON is a serialization format optimized for LLM consumption that achieves significant token reduction compared to JSON while maintaining human readability. It uses indentation-based syntax, compact array notation, and eliminates redundant syntax like braces and quotes where possible.

### Key Benefits

- **Token Efficient**: Reduces token count by 30-50% compared to JSON
- **Human Readable**: Clean, indentation-based syntax similar to YAML
- **LLM Optimized**: Designed specifically for prompt engineering and LLM input
- **Flexible**: Supports multiple array formats (inline, tabular, expanded)
- **Type Safe**: Strongly typed API with comprehensive error handling

## Installation

Add `gleam_toon` to your Gleam project:

```sh
gleam add gleam_toon
```

## Quick Start

```gleam
import gleam_toon
import gleam_toon/types.{Array, Bool, Number, Object, String}

pub fn main() {
  // Create a data structure
  let user = Object([
    #("name", String("Alice")),
    #("age", Number(30.0)),
    #("active", Bool(True)),
    #("tags", Array([String("admin"), String("developer")])),
  ])

  // Encode to TOON format
  let toon_str = gleam_toon.encode(user)
  // Result:
  // name: Alice
  // age: 30
  // active: true
  // tags[2]: admin,developer

  // Decode back to JsonValue
  case gleam_toon.decode(toon_str) {
    Ok(decoded) -> io.println("Successfully decoded!")
    Error(err) -> io.println("Error: " <> string.inspect(err))
  }
}
```

For a comprehensive working example with multiple use cases, see the [src/example/](src/example/) folder and run:

```sh
gleam run -m example/demo
```

## Features

- ✅ **Primitive Types**: Strings, numbers, booleans, null
- ✅ **Objects**: Indentation-based key-value pairs (no braces)
- ✅ **Arrays**:
  - Inline format for primitives: `[3]: 1,2,3`
  - Tabular format for objects: `[2]{name,age}:\n  Alice,30\n  Bob,25`
  - Expanded format for mixed types: `[2]:\n  - item1\n  - item2`
- ✅ **Custom Delimiters**: Comma (default), Tab, Pipe
- ✅ **Strict Mode**: Optional validation for array counts and indentation
- ✅ **String Quoting**: Automatic quoting for special characters, numbers, and keywords
- ✅ **Nested Structures**: Full support for deeply nested objects and arrays

## Usage Examples

### Primitives

```gleam
import gleam_toon
import gleam_toon/types.{Bool, Null, Number, String}

// Strings
gleam_toon.encode(String("hello"))
// -> "hello"

// Numbers
gleam_toon.encode(Number(42.5))
// -> "42.5"

// Booleans
gleam_toon.encode(Bool(True))
// -> "true"

// Null
gleam_toon.encode(Null)
// -> "null"
```

### Objects

```gleam
import gleam_toon/types.{Number, Object, String}

// Simple object
let user = Object([
  #("name", String("Alice")),
  #("age", Number(30.0)),
])

gleam_toon.encode(user)
// -> "name: Alice\nage: 30"

// Nested object
let person = Object([
  #("name", String("Bob")),
  #("address", Object([
    #("city", String("NYC")),
    #("zip", String("10001")),
  ])),
])

gleam_toon.encode(person)
// -> "name: Bob\naddress:\n  city: NYC\n  zip: \"10001\""
```

### Arrays

#### Inline Arrays (Primitives)

```gleam
import gleam_toon/types.{Array, Number}

let numbers = Array([Number(1.0), Number(2.0), Number(3.0)])
gleam_toon.encode(numbers)
// -> "[3]: 1,2,3"
```

#### Tabular Arrays (Objects with Same Keys)

```gleam
import gleam_toon/types.{Array, Number, Object, String}

let users = Array([
  Object([#("name", String("Alice")), #("age", Number(30.0))]),
  Object([#("name", String("Bob")), #("age", Number(25.0))]),
])

gleam_toon.encode(users)
// -> "[2]{name,age}:\n  Alice,30\n  Bob,25"
```

#### Expanded Arrays (Mixed Types)

```gleam
import gleam_toon/types.{Array, Number, Object, String}

let mixed = Array([
  String("item1"),
  Number(42.0),
  Object([#("key", String("value"))]),
])

gleam_toon.encode(mixed)
// -> "[3]:\n  - item1\n  - 42\n  - key: value"
```

### Custom Delimiters

```gleam
import gleam_toon
import gleam_toon/types.{Array, EncodeOptions, Number, Tab}

let numbers = Array([Number(1.0), Number(2.0), Number(3.0)])
let options = EncodeOptions(indent: 2, delimiter: Tab, length_marker: types.NoMarker)

gleam_toon.encode_with_options(numbers, options)
// -> "[3\t]: 1\t2\t3"
```

### Custom Options

```gleam
import gleam_toon/types.{Comma, DecodeOptions, EncodeOptions, HashMarker}

// Encoding options
let encode_opts = EncodeOptions(
  indent: 4,                    // 4 spaces per indentation level
  delimiter: Comma,             // Use comma separator (Tab, Pipe also available)
  length_marker: HashMarker,    // Prefix array lengths with #: [#3]:
)

// Decoding options
let decode_opts = DecodeOptions(
  indent: 4,      // Match encoding indent
  strict: True,   // Validate array counts and indentation
)

let encoded = gleam_toon.encode_with_options(value, encode_opts)
let result = gleam_toon.decode_with_options(encoded, decode_opts)
```

## API Reference

### Core Functions

- **`encode(value: JsonValue) -> String`**
  Encode a JSON value to TOON format with default options.

- **`encode_with_options(value: JsonValue, options: EncodeOptions) -> String`**
  Encode with custom indentation, delimiter, and length marker options.

- **`decode(input: String) -> Result(JsonValue, ToonError)`**
  Decode TOON format to JSON value with default options.

- **`decode_with_options(input: String, options: DecodeOptions) -> Result(JsonValue, ToonError)`**
  Decode with custom indentation and strict mode settings.

### Types

- **`JsonValue`**: `Null | Bool(Bool) | Number(Float) | String(String) | Array(List(JsonValue)) | Object(List(#(String, JsonValue)))`
- **`EncodeOptions`**: `EncodeOptions(indent: Int, delimiter: Delimiter, length_marker: LengthMarker)`
- **`DecodeOptions`**: `DecodeOptions(indent: Int, strict: Bool)`
- **`Delimiter`**: `Comma | Tab | Pipe`
- **`LengthMarker`**: `NoMarker | HashMarker`

## TOON Format Examples

### JSON vs TOON Comparison

**JSON:**

```json
{
  "users": [
    { "name": "Alice", "age": 30, "active": true },
    { "name": "Bob", "age": 25, "active": false }
  ],
  "total": 2
}
```

**TOON:**

```
users[2]{name,age,active}:
  Alice,30,true
  Bob,25,false
total: 2
```

**Token Savings**: ~40% reduction in this example.

## Testing

gleam_toon includes a comprehensive test suite with **113 tests** covering:

- Primitive type encoding/decoding
- Object encoding/decoding with nesting
- Array formats (inline, tabular, expanded)
- Delimiter variations (comma, tab, pipe)
- Strict mode validation
- String quoting and escaping
- Error handling

Run tests with:

```sh
gleam test
```

## Specification

gleam_toon implements the **TOON Specification v1.2**. For complete format details, see:

- [TOON Specification](https://github.com/byjohann/toon/blob/main/SPEC.md)

## Development

```sh
# Clone the repository
git clone https://github.com/axelbellec/toon.git
cd toon

# Install dependencies
gleam deps download

# Run tests
gleam test

# Build the project
gleam build

# Format code
gleam format
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- **Johann Schopplich** for creating the original TOON format and specification
- The **Gleam community** for the excellent language and tooling
