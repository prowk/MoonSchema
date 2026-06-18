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

///|
test "const keyword requires exact JSON value" {
  let schema : Json = { "const": { "role": "admin" } }
  assert_true(@MoonSchema.is_valid(schema, { "role": "admin" }))
  let errors = @MoonSchema.validate(schema, { "role": "user" })
  inspect(errors.length(), content="1")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::ConstMismatch)
  inspect(errors[0].schema_path.to_pointer(), content="#const")
}

///|
test "enum keyword accepts one of options" {
  let schema : Json = { "enum": ["red", "green", "blue"] }
  assert_true(@MoonSchema.is_valid(schema, "green".to_json()))
  let errors = @MoonSchema.validate(schema, "yellow".to_json())
  inspect(errors.length(), content="1")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::EnumMismatch)
}

///|
test "number minimum and maximum bounds" {
  let schema : Json = { "type": "number", "minimum": 0.0, "maximum": 10.0 }
  assert_true(@MoonSchema.is_valid(schema, 5.0.to_json()))
  let low = @MoonSchema.validate(schema, (-1.0).to_json())
  inspect(low.length(), content="1")
  assert_true(low[0].kind == @MoonSchema.ErrorKind::NumberTooSmall)
  inspect(low[0].schema_path.to_pointer(), content="#minimum")
  let high = @MoonSchema.validate(schema, 11.0.to_json())
  inspect(high.length(), content="1")
  assert_true(high[0].kind == @MoonSchema.ErrorKind::NumberTooLarge)
  inspect(high[0].schema_path.to_pointer(), content="#maximum")
}

///|
test "exclusive number bounds" {
  let schema : Json = { "exclusiveMinimum": 0.0, "exclusiveMaximum": 10.0 }
  assert_true(@MoonSchema.is_valid(schema, 5.0.to_json()))
  assert_false(@MoonSchema.is_valid(schema, 0.0.to_json()))
  assert_false(@MoonSchema.is_valid(schema, 10.0.to_json()))
}

///|
test "string length bounds" {
  let schema : Json = { "type": "string", "minLength": 2.0, "maxLength": 4.0 }
  assert_true(@MoonSchema.is_valid(schema, "abc".to_json()))
  let short = @MoonSchema.validate(schema, "a".to_json())
  inspect(short.length(), content="1")
  assert_true(short[0].kind == @MoonSchema.ErrorKind::StringTooShort)
  inspect(short[0].schema_path.to_pointer(), content="#minLength")
  let long = @MoonSchema.validate(schema, "abcde".to_json())
  inspect(long.length(), content="1")
  assert_true(long[0].kind == @MoonSchema.ErrorKind::StringTooLong)
  inspect(long[0].schema_path.to_pointer(), content="#maxLength")
}

///|
test "string pattern constraint" {
  let schema : Json = { "type": "string", "pattern": "^[a-z]+-[0-9]+$" }
  assert_true(@MoonSchema.is_valid(schema, "ticket-42".to_json()))
  let errors = @MoonSchema.validate(schema, "Ticket 42".to_json())
  inspect(errors.length(), content="1")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::PatternMismatch)
  inspect(errors[0].schema_path.to_pointer(), content="#pattern")
}

///|
test "array items are recursively validated" {
  let schema : Json = { "type": "array", "items": { "type": "integer" } }
  assert_true(@MoonSchema.is_valid(schema, [1.0, 2.0, 3.0]))
  let errors = @MoonSchema.validate(schema, [1.0, "two", 3.0])
  inspect(errors.length(), content="1")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::TypeMismatch)
  inspect(errors[0].instance_path.to_pointer(), content="#1")
  inspect(errors[0].schema_path.to_pointer(), content="#items/type")
}

///|
test "array length and uniqueness constraints" {
  let schema : Json = {
    "type": "array",
    "minItems": 2.0,
    "maxItems": 3.0,
    "uniqueItems": true,
  }
  assert_true(@MoonSchema.is_valid(schema, ["a", "b"]))
  let too_short = @MoonSchema.validate(schema, ["a"])
  inspect(too_short.length(), content="1")
  assert_true(too_short[0].kind == @MoonSchema.ErrorKind::ArrayTooShort)
  let too_long = @MoonSchema.validate(schema, ["a", "b", "c", "d"])
  inspect(too_long.length(), content="1")
  assert_true(too_long[0].kind == @MoonSchema.ErrorKind::ArrayTooLong)
  let duplicate = @MoonSchema.validate(schema, ["a", "b", "a"])
  inspect(duplicate.length(), content="1")
  assert_true(duplicate[0].kind == @MoonSchema.ErrorKind::UniqueItemsMismatch)
  inspect(duplicate[0].instance_path.to_pointer(), content="#2")
}

///|
test "object properties and required are validated" {
  let schema : Json = {
    "type": "object",
    "required": ["name", "age"],
    "properties": {
      "name": { "type": "string", "minLength": 1.0 },
      "age": { "type": "integer", "minimum": 0.0 },
    },
  }
  assert_true(@MoonSchema.is_valid(schema, { "name": "Ada", "age": 36.0 }))
  let errors = @MoonSchema.validate(schema, { "name": "", "age": -1.0 })
  inspect(errors.length(), content="2")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::StringTooShort)
  assert_true(errors[1].kind == @MoonSchema.ErrorKind::NumberTooSmall)
  inspect(errors[0].instance_path.to_pointer(), content="#name")
  inspect(errors[1].instance_path.to_pointer(), content="#age")
  let missing = @MoonSchema.validate(schema, { "name": "Ada" })
  inspect(missing.length(), content="1")
  assert_true(missing[0].kind == @MoonSchema.ErrorKind::MissingRequired)
  inspect(missing[0].instance_path.to_pointer(), content="#age")
}

///|
test "additionalProperties can reject or validate extras" {
  let closed_schema : Json = {
    "properties": { "name": { "type": "string" } },
    "additionalProperties": false,
  }
  let extra = @MoonSchema.validate(closed_schema, { "name": "Ada", "debug": true })
  inspect(extra.length(), content="1")
  assert_true(extra[0].kind == @MoonSchema.ErrorKind::AdditionalProperty)
  inspect(extra[0].instance_path.to_pointer(), content="#debug")

  let typed_extra_schema : Json = {
    "properties": { "name": { "type": "string" } },
    "additionalProperties": { "type": "integer" },
  }
  assert_true(@MoonSchema.is_valid(typed_extra_schema, { "name": "Ada", "score": 5.0 }))
  let typed_extra = @MoonSchema.validate(typed_extra_schema, {
    "name": "Ada",
    "score": "five",
  })
  inspect(typed_extra.length(), content="1")
  assert_true(typed_extra[0].kind == @MoonSchema.ErrorKind::TypeMismatch)
  inspect(typed_extra[0].instance_path.to_pointer(), content="#score")
  inspect(typed_extra[0].schema_path.to_pointer(), content="#additionalProperties/type")
}

///|
test "allOf validates every subschema" {
  let schema : Json = {
    "allOf": [
      { "type": "integer" },
      { "minimum": 1.0 },
      { "maximum": 3.0 },
    ],
  }
  assert_true(@MoonSchema.is_valid(schema, 2.0.to_json()))
  let errors = @MoonSchema.validate(schema, 4.0.to_json())
  inspect(errors.length(), content="1")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::NumberTooLarge)
  inspect(errors[0].schema_path.to_pointer(), content="#allOf/2/maximum")
}

///|
test "anyOf oneOf and not combinations" {
  let any_schema : Json = {
    "anyOf": [{ "type": "string" }, { "type": "integer" }],
  }
  assert_true(@MoonSchema.is_valid(any_schema, "ok".to_json()))
  assert_false(@MoonSchema.is_valid(any_schema, true.to_json()))

  let one_schema : Json = {
    "oneOf": [{ "type": "number" }, { "type": "integer" }],
  }
  assert_true(@MoonSchema.is_valid(one_schema, 1.5.to_json()))
  assert_false(@MoonSchema.is_valid(one_schema, 1.0.to_json()))

  let not_schema : Json = { "not": { "type": "null" } }
  assert_true(@MoonSchema.is_valid(not_schema, "value".to_json()))
  assert_false(@MoonSchema.is_valid(not_schema, null))
}

///|
test "local refs resolve definitions" {
  let schema : Json = {
    "$defs": {
      "positiveInteger": { "type": "integer", "minimum": 1.0 },
      "namedUser": {
        "type": "object",
        "required": ["name"],
        "properties": { "name": { "type": "string", "minLength": 1.0 } },
      },
    },
    "type": "object",
    "required": ["user", "score"],
    "properties": {
      "user": { "$ref": "#/$defs/namedUser" },
      "score": { "$ref": "#/$defs/positiveInteger" },
    },
  }
  assert_true(@MoonSchema.is_valid(schema, {
    "user": { "name": "Ada" },
    "score": 3.0,
  }))
  let errors = @MoonSchema.validate(schema, {
    "user": { "name": "" },
    "score": 0.0,
  })
  inspect(errors.length(), content="2")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::StringTooShort)
  assert_true(errors[1].kind == @MoonSchema.ErrorKind::NumberTooSmall)
  inspect(errors[0].schema_path.to_pointer(), content="#properties/user/$ref/properties/name/minLength")
  inspect(errors[1].schema_path.to_pointer(), content="#properties/score/$ref/minimum")
}

///|
test "unresolved ref reports structured error" {
  let schema : Json = { "$ref": "#/$defs/missing" }
  let errors = @MoonSchema.validate(schema, null)
  inspect(errors.length(), content="1")
  assert_true(errors[0].kind == @MoonSchema.ErrorKind::RefNotFound)
  inspect(errors[0].schema_path.to_pointer(), content="#$ref")
}
