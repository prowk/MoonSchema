///| MoonSchema 的版本号。
pub fn version() -> String {
  "0.1.0"
}

///| 校验结果。数组为空表示通过。
pub type ValidationResult = Array[ValidationError]

///| 校验实例是否符合 schema，返回全部可收集的错误。
pub fn validate(schema : Json, instance : Json) -> ValidationResult {
  let errors : Array[ValidationError] = []
  validate_at(schema, instance, Path::root(), Path::root(), errors)
  errors
}

///| 快速判断实例是否通过校验。
pub fn is_valid(schema : Json, instance : Json) -> Bool {
  validate(schema, instance).is_empty()
}

///| 在指定路径下递归校验。
fn validate_at(
  schema : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match schema {
    True => ()
    False =>
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path,
          InvalidSchema,
          "boolean schema false rejects every value",
        ),
      )
    Object(rules) => {
      if rules.get("type") is Some(type_rule) {
        check_type(type_rule, instance, instance_path, schema_path.field("type"), errors)
      }
      if rules.get("const") is Some(expected) {
        check_const(expected, instance, instance_path, schema_path.field("const"), errors)
      }
      if rules.get("enum") is Some(options) {
        check_enum(options, instance, instance_path, schema_path.field("enum"), errors)
      }
    }
    _ =>
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path,
          InvalidSchema,
          "schema must be an object or a boolean",
        ),
      )
  }
}

///| 校验 `const` 关键字。
fn check_const(
  expected : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  if instance == expected {
    return
  }
  errors.push(
    ValidationError::new(
      instance_path,
      schema_path,
      ConstMismatch,
      "value does not equal the required constant",
    ),
  )
}

///| 校验 `enum` 关键字。
fn check_enum(
  options : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match options {
    Array(values) =>
      if !values.any(value => value == instance) {
        errors.push(
          ValidationError::new(
            instance_path,
            schema_path,
            EnumMismatch,
            "value is not one of the allowed enum values",
          ),
        )
      }
    _ =>
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path,
          InvalidSchema,
          "`enum` must be an array",
        ),
      )
  }
}

///| 校验 `type` 关键字，支持字符串或字符串数组。
fn check_type(
  rule : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  let accepted = match rule {
    String(name) => [name]
    Array(items) =>
      items.filter_map(item =>
        match item {
          String(name) => Some(name)
          _ => None
        },
      )
    _ => []
  }
  if accepted.is_empty() {
    errors.push(
      ValidationError::new(
        instance_path,
        schema_path,
        InvalidSchema,
        "`type` must be a string or an array of strings",
      ),
    )
    return
  }
  if accepted.any(name => matches_type(name, instance)) {
    return
  }
  let expected = accepted.join(" or ")
  let actual = json_type(instance)
  errors.push(
    ValidationError::new(
      instance_path,
      schema_path,
      TypeMismatch,
      "expected \{expected}, got \{actual}",
    ),
  )
}

///| 判断实例是否匹配 JSON Schema 类型名。
fn matches_type(name : String, instance : Json) -> Bool {
  match name {
    "null" => instance is Null
    "boolean" => instance is True || instance is False
    "number" => instance is Number(_)
    "integer" =>
      match instance {
        Number(n, ..) => n == @double.trunc(n)
        _ => false
      }
    "string" => instance is String(_)
    "array" => instance is Array(_)
    "object" => instance is Object(_)
    _ => false
  }
}

///| 返回用于错误消息的实例类型名。
fn json_type(value : Json) -> String {
  match value {
    Null => "null"
    True | False => "boolean"
    Number(n, ..) => if n == @double.trunc(n) { "integer" } else { "number" }
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}
