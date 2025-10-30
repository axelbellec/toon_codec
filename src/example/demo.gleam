import gleam/io
import gleam/string
import toon_codec
import toon_codec/types.{
  Array, Bool, Comma, EncodeOptions, HashMarker, NoMarker, Number, Object, Pipe,
  String, Tab,
}

pub fn main() {
  io.println("=== TOON DEMO ===\n")

  // Example 1: Simple User Object
  io.println("1. Simple User Object")
  demo_simple_user()

  // Example 2: Nested Objects
  io.println("\n2. Nested Objects (Person with Address)")
  demo_nested_objects()

  // Example 3: Arrays - Different Formats
  io.println("\n3. Arrays - Inline Format (Primitives)")
  demo_inline_array()

  io.println("\n4. Arrays - Tabular Format (Objects)")
  demo_tabular_array()

  io.println("\n5. Arrays - Expanded Format (Mixed Types)")
  demo_expanded_array()

  // Example 4: Custom Delimiters
  io.println("\n6. Custom Delimiters (Tab-separated)")
  demo_custom_delimiter()

  // Example 5: Custom Options
  io.println("\n7. Custom Options (4-space indent, hash markers)")
  demo_custom_options()

  // Example 6: Round-trip (Encode -> Decode)
  io.println("\n8. Round-trip Test (Encode -> Decode)")
  demo_roundtrip()
}

fn demo_simple_user() {
  let user =
    Object([
      #("name", String("Alice")),
      #("age", Number(30.0)),
      #("active", Bool(True)),
      #("role", String("admin")),
    ])

  let encoded = toon_codec.encode(user)
  io.println("Encoded:")
  io.println(encoded)
}

fn demo_nested_objects() {
  let person =
    Object([
      #("name", String("Bob Smith")),
      #("email", String("bob@example.com")),
      #(
        "address",
        Object([
          #("street", String("123 Main St")),
          #("city", String("New York")),
          #("zip", String("10001")),
          #(
            "coordinates",
            Object([#("lat", Number(40.7128)), #("lng", Number(-74.006))]),
          ),
        ]),
      ),
    ])

  let encoded = toon_codec.encode(person)
  io.println("Encoded:")
  io.println(encoded)
}

fn demo_inline_array() {
  let numbers = Array([Number(1.0), Number(2.0), Number(3.0), Number(4.0)])

  let encoded = toon_codec.encode(numbers)
  io.println("Encoded:")
  io.println(encoded)
}

fn demo_tabular_array() {
  let users =
    Array([
      Object([
        #("name", String("Alice")),
        #("age", Number(30.0)),
        #("active", Bool(True)),
      ]),
      Object([
        #("name", String("Bob")),
        #("age", Number(25.0)),
        #("active", Bool(False)),
      ]),
      Object([
        #("name", String("Charlie")),
        #("age", Number(35.0)),
        #("active", Bool(True)),
      ]),
    ])

  let encoded = toon_codec.encode(users)
  io.println("Encoded:")
  io.println(encoded)
}

fn demo_expanded_array() {
  let mixed =
    Array([
      String("text item"),
      Number(42.0),
      Bool(True),
      Object([#("key", String("value")), #("count", Number(10.0))]),
      Array([String("nested"), String("array")]),
    ])

  let encoded = toon_codec.encode(mixed)
  io.println("Encoded:")
  io.println(encoded)
}

fn demo_custom_delimiter() {
  let data = Array([String("apple"), String("banana"), String("cherry")])

  let options =
    EncodeOptions(indent: 2, delimiter: Tab, length_marker: NoMarker)

  let encoded = toon_codec.encode_with_options(data, options)
  io.println("Encoded with Tab delimiter:")
  io.println(encoded)

  let options_pipe =
    EncodeOptions(indent: 2, delimiter: Pipe, length_marker: NoMarker)

  let encoded_pipe = toon_codec.encode_with_options(data, options_pipe)
  io.println("\nEncoded with Pipe delimiter:")
  io.println(encoded_pipe)
}

fn demo_custom_options() {
  let data =
    Object([
      #("title", String("Project")),
      #(
        "tasks",
        Array([
          Object([#("id", Number(1.0)), #("name", String("Task 1"))]),
          Object([#("id", Number(2.0)), #("name", String("Task 2"))]),
        ]),
      ),
    ])

  let encode_options =
    EncodeOptions(indent: 4, delimiter: Comma, length_marker: HashMarker)

  let encoded = toon_codec.encode_with_options(data, encode_options)
  io.println("Encoded with 4-space indent and hash markers:")
  io.println(encoded)
}

fn demo_roundtrip() {
  let original =
    Object([
      #("product", String("Widget")),
      #("price", Number(19.99)),
      #("in_stock", Bool(True)),
      #("tags", Array([String("electronics"), String("gadgets")])),
    ])

  io.println("Original:")
  io.println(string.inspect(original))

  let encoded = toon_codec.encode(original)
  io.println("\nEncoded to TOON:")
  io.println(encoded)

  case toon_codec.decode(encoded) {
    Ok(decoded) -> {
      io.println("\nDecoded back to JsonValue:")
      io.println(string.inspect(decoded))
      io.println("\n✓ Round-trip successful!")
    }
    Error(err) -> {
      io.println("\n✗ Decoding failed:")
      io.println(string.inspect(err))
    }
  }
}
