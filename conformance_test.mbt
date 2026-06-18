///| 更接近 JSON Schema 官方测试集风格的回归用例。
struct Case {
  name : String
  schema : Json
  valid : Array[Json]
  invalid : Array[Json]
}

///| 执行一组通过/失败样例。
fn run_case(case : Case) -> Unit raise {
  case.valid.each(value => {
    if !@MoonSchema.is_valid(case.schema, value) {
      fail("expected valid case: \{case.name}")
    }
  })
  case.invalid.each(value => {
    if @MoonSchema.is_valid(case.schema, value) {
      fail("expected invalid case: \{case.name}")
    }
  })
}

///|
test "conformance type matrix" {
  let cases = [
    {
      name: "null type",
      schema: { "type": "null" },
      valid: [null],
      invalid: [false.to_json(), 0.0.to_json(), "".to_json(), [], {}],
    },
    {
      name: "boolean type",
      schema: { "type": "boolean" },
      valid: [true.to_json(), false.to_json()],
      invalid: [null, 0.0.to_json(), "false".to_json(), [], {}],
    },
    {
      name: "integer type",
      schema: { "type": "integer" },
      valid: [0.0.to_json(), 10.0.to_json(), (-2.0).to_json()],
      invalid: [1.5.to_json(), "1".to_json(), true.to_json(), null],
    },
    {
      name: "union type",
      schema: { "type": ["string", "integer"] },
      valid: ["one".to_json(), 1.0.to_json()],
      invalid: [1.5.to_json(), false.to_json(), null, []],
    },
  ]
  cases.each(run_case)
}

///|
test "conformance numeric matrix" {
  let cases = [
    {
      name: "inclusive range",
      schema: { "type": "number", "minimum": 1.0, "maximum": 5.0 },
      valid: [1.0.to_json(), 3.0.to_json(), 5.0.to_json()],
      invalid: [0.0.to_json(), 6.0.to_json()],
    },
    {
      name: "exclusive range",
      schema: { "exclusiveMinimum": 1.0, "exclusiveMaximum": 5.0 },
      valid: [1.1.to_json(), 3.0.to_json(), 4.9.to_json()],
      invalid: [1.0.to_json(), 5.0.to_json()],
    },
    {
      name: "multiple of integer",
      schema: { "multipleOf": 3.0 },
      valid: [0.0.to_json(), 3.0.to_json(), 9.0.to_json()],
      invalid: [1.0.to_json(), 10.0.to_json()],
    },
    {
      name: "multiple of decimal",
      schema: { "multipleOf": 0.25 },
      valid: [0.5.to_json(), 1.25.to_json()],
      invalid: [0.3.to_json(), 1.1.to_json()],
    },
  ]
  cases.each(run_case)
}

///|
test "conformance string matrix" {
  let cases = [
    {
      name: "length bounds",
      schema: { "minLength": 2.0, "maxLength": 4.0 },
      valid: ["ab".to_json(), "abcd".to_json()],
      invalid: ["a".to_json(), "abcde".to_json()],
    },
    {
      name: "anchored pattern",
      schema: { "pattern": "^[A-Z]+-[0-9]+$" },
      valid: ["AB-12".to_json(), "MOON-1".to_json()],
      invalid: ["ab-12".to_json(), "AB".to_json(), "AB-".to_json()],
    },
  ]
  cases.each(run_case)
}

///|
test "conformance array matrix" {
  let cases = [
    {
      name: "items schema",
      schema: { "items": { "type": "integer" } },
      valid: [[], [1.0, 2.0, 3.0]],
      invalid: [[1.0, "two", 3.0], ["one"]],
    },
    {
      name: "length bounds",
      schema: { "minItems": 1.0, "maxItems": 2.0 },
      valid: [[1.0], [1.0, 2.0]],
      invalid: [[], [1.0, 2.0, 3.0]],
    },
    {
      name: "unique items",
      schema: { "uniqueItems": true },
      valid: [[1.0, 2.0], [{ "a": 1.0 }, { "a": 2.0 }]],
      invalid: [[1.0, 1.0], [{ "a": 1.0 }, { "a": 1.0 }]],
    },
    {
      name: "contains count",
      schema: {
        "contains": { "type": "string", "pattern": "^x" },
        "minContains": 1.0,
        "maxContains": 2.0,
      },
      valid: [["x1"], ["x1", "no", "x2"]],
      invalid: [["no"], ["x1", "x2", "x3"]],
    },
  ]
  cases.each(run_case)
}

///|
test "conformance object matrix" {
  let cases = [
    {
      name: "required and properties",
      schema: {
        "required": ["name"],
        "properties": { "name": { "type": "string" } },
      },
      valid: [{ "name": "Ada" }],
      invalid: [{}, { "name": 1.0 }],
    },
    {
      name: "closed object",
      schema: {
        "properties": { "name": { "type": "string" } },
        "additionalProperties": false,
      },
      valid: [{}, { "name": "Ada" }],
      invalid: [{ "name": "Ada", "extra": true }],
    },
    {
      name: "typed additional properties",
      schema: {
        "properties": { "name": { "type": "string" } },
        "additionalProperties": { "type": "integer" },
      },
      valid: [{ "name": "Ada", "score": 1.0 }],
      invalid: [{ "name": "Ada", "score": "one" }],
    },
    {
      name: "property names",
      schema: { "propertyNames": { "pattern": "^[a-z]+$" } },
      valid: [{ "name": "Ada" }],
      invalid: [{ "bad-name": true }],
    },
    {
      name: "dependent required",
      schema: { "dependentRequired": { "card": ["billing"] } },
      valid: [{}, { "card": "1", "billing": "addr" }],
      invalid: [{ "card": "1" }],
    },
  ]
  cases.each(run_case)
}

///|
test "conformance composition matrix" {
  let cases = [
    {
      name: "allOf",
      schema: { "allOf": [{ "type": "integer" }, { "minimum": 1.0 }] },
      valid: [1.0.to_json(), 2.0.to_json()],
      invalid: [0.0.to_json(), "1".to_json()],
    },
    {
      name: "anyOf",
      schema: { "anyOf": [{ "type": "string" }, { "type": "integer" }] },
      valid: ["x".to_json(), 1.0.to_json()],
      invalid: [1.5.to_json(), null],
    },
    {
      name: "oneOf",
      schema: { "oneOf": [{ "type": "number" }, { "type": "integer" }] },
      valid: [1.5.to_json()],
      invalid: [1.0.to_json(), "x".to_json()],
    },
    {
      name: "not",
      schema: { "not": { "type": "null" } },
      valid: ["x".to_json(), 1.0.to_json()],
      invalid: [null],
    },
  ]
  cases.each(run_case)
}
