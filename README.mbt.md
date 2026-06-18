# MoonSchema

MoonSchema is a JSON Schema validation library for MoonBit. It builds on MoonBit's
standard `Json` value and focuses on the practical subset needed by typed
configuration files, API payload checks, and test fixtures.

The current target is a Draft 2020-12 compatible core subset. Unsupported
keywords are ignored unless they are part of MoonSchema's documented subset.

## Features

- Public APIs for `Json` values: `validate`, `is_valid`
- Public APIs for JSON text: `validate_text`, `is_valid_text`
- Structured errors with instance path, schema path, error kind, and message
- Type checks: `null`, `boolean`, `number`, `integer`, `string`, `array`, `object`
- Value checks: `const`, `enum`
- Number checks: `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`
- String checks: `minLength`, `maxLength`, `pattern`
- Array checks: `items`, `minItems`, `maxItems`, `uniqueItems`
- Object checks: `properties`, `required`, `additionalProperties`
- Composition: `allOf`, `anyOf`, `oneOf`, `not`
- Local references: `#` and `#/...` JSON Pointer paths, including `$defs`

## Example

```mbt
test {
  let schema : Json = {
    "$defs": {
      "positiveInteger": { "type": "integer", "minimum": 1.0 },
    },
    "type": "object",
    "required": ["name", "score"],
    "properties": {
      "name": { "type": "string", "minLength": 1.0 },
      "score": { "$ref": "#/$defs/positiveInteger" },
    },
    "additionalProperties": false,
  }

  let value : Json = { "name": "Ada", "score": 3.0 }
  assert_true(@MoonSchema.is_valid(schema, value))
}
```

Use `validate` when you need detailed errors:

```mbt
test {
  let schema : Json = { "type": "integer", "minimum": 1.0 }
  let errors = @MoonSchema.validate(schema, 0.0.to_json())
  assert_false(errors.is_empty())
  println(errors[0].summary())
}
```

For text input:

```mbt
test {
  let schema = #|{"type":"object","required":["name"]}
  let value = #|{"name":"Ada"}
  let result = @MoonSchema.is_valid_text(schema, value)
  match result {
    Ok(valid) => assert_true(valid)
    Err(message) => fail(message)
  }
}
```

## Design Notes

MoonSchema collects independent validation errors where possible. Composition
keywords report a compact `CombinationFailed` error for `anyOf`, `oneOf`, and
`not`; `allOf` keeps detailed nested errors.

`$ref` support is intentionally local-only for v0.1. Remote URI loading,
dynamic anchors, format assertion, unevaluated properties/items, conditional
keywords, and full metaschema validation are out of scope for the first release.

## Development

```bash
moon test
```

The repository includes focused unit tests for supported keywords, nested error
paths, local references, and text parsing.

