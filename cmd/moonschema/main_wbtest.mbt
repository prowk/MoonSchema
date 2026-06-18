///|
test "cli validates inline json" {
  let schema = #|{"type":"integer","minimum":1}
  let instance = #|2
  let output = run_args([
    "moonschema",
    "--schema-json",
    schema,
    "--instance-json",
    instance,
  ])
  inspect(output, content="valid")
}

///|
test "cli renders validation errors" {
  let schema = #|{"type":"integer","minimum":1}
  let instance = #|0
  let output = run_args([
    "moonschema",
    "--schema-json",
    schema,
    "--instance-json",
    instance,
  ])
  assert_true(output.contains("invalid"))
  assert_true(output.contains("#minimum"))
}

///|
test "cli reports parse errors" {
  let output = run_args([
    "moonschema",
    "--schema-json",
    "{",
    "--instance-json",
    "{}",
  ])
  inspect(output, content="error: failed to parse schema JSON")
}
