///|
test "version" {
  inspect(@MoonSchema.version(), content="0.1.0")
}

///|
test "path pointer escaping" {
  let path = @MoonSchema.Path::root().field("user/name").field("~meta")
  inspect(path.to_pointer(), content="#user~1name/~0meta")
}

///|
test "error summary contains paths" {
  let err = @MoonSchema.ValidationError::new(
    @MoonSchema.Path::root().field("age"),
    @MoonSchema.Path::root().field("properties").field("age").field("type"),
    @MoonSchema.ErrorKind::TypeMismatch,
    "expected integer",
  )
  inspect(
    err.summary(),
    content="#age violates #properties/age/type: expected integer",
  )
}

///|
test "type keyword accepts matching value" {
  let schema : Json = { "type": "string" }
  assert_true(@MoonSchema.is_valid(schema, "MoonBit".to_json()))
}

///|
test "type keyword reports mismatch" {
  let schema : Json = { "type": "integer" }
  let errors = @MoonSchema.validate(schema, "18".to_json())
  inspect(errors.length(), content="1")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::TypeMismatch)
  inspect(errors[0].instance_path.to_pointer(), content="#")
  inspect(errors[0].schema_path.to_pointer(), content="#type")
}

///|
test "type keyword supports union types" {
  let schema : Json = { "type": ["string", "integer"] }
  assert_true(@MoonSchema.is_valid(schema, 42.0.to_json()))
  assert_true(@MoonSchema.is_valid(schema, "ok".to_json()))
  assert_false(@MoonSchema.is_valid(schema, false.to_json()))
}
