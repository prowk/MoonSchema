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
      check_number_bounds(rules, instance, instance_path, schema_path, errors)
      check_string_length(rules, instance, instance_path, schema_path, errors)
      check_array_rules(rules, instance, instance_path, schema_path, errors)
      check_object_rules(rules, instance, instance_path, schema_path, errors)
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

///| 校验对象相关关键字。
fn check_object_rules(
  rules : Map[String, Json],
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  guard instance is Object(fields) else { return }
  let known_properties : Array[String] = []
  if rules.get("properties") is Some(properties_rule) {
    match properties_rule {
      Object(properties) => {
        properties.each((name, property_schema) => {
          known_properties.push(name)
          if fields.get(name) is Some(value) {
            validate_at(
              property_schema,
              value,
              instance_path.field(name),
              schema_path.field("properties").field(name),
              errors,
            )
          }
        })
      }
      _ =>
        errors.push(
          ValidationError::new(
            instance_path,
            schema_path.field("properties"),
            InvalidSchema,
            "`properties` must be an object",
          ),
        )
    }
  }
  if rules.get("required") is Some(required_rule) {
    check_required(required_rule, fields, instance_path, schema_path.field("required"), errors)
  }
  if rules.get("additionalProperties") is Some(additional_rule) {
    check_additional_properties(
      additional_rule,
      fields,
      known_properties,
      instance_path,
      schema_path.field("additionalProperties"),
      errors,
    )
  }
}

///| 校验 `required` 列表。
fn check_required(
  required_rule : Json,
  fields : Map[String, Json],
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match required_rule {
    Array(names) =>
      names.eachi((index, item) => {
        match item {
          String(name) =>
            if !fields.contains(name) {
              errors.push(
                ValidationError::new(
                  instance_path.field(name),
                  schema_path.index(index),
                  MissingRequired,
                  "required property is missing",
                ),
              )
            }
          _ =>
            errors.push(
              ValidationError::new(
                instance_path,
                schema_path.index(index),
                InvalidSchema,
                "`required` entries must be strings",
              ),
            )
        }
      })
    _ =>
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path,
          InvalidSchema,
          "`required` must be an array of strings",
        ),
      )
  }
}

///| 校验 `additionalProperties`。
fn check_additional_properties(
  rule : Json,
  fields : Map[String, Json],
  known_properties : Array[String],
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  fields.each((name, value) => {
    if known_properties.contains(name) {
      return
    }
    match rule {
      False =>
        errors.push(
          ValidationError::new(
            instance_path.field(name),
            schema_path,
            AdditionalProperty,
            "additional property is not allowed",
          ),
        )
      True => ()
      Object(_) => validate_at(rule, value, instance_path.field(name), schema_path, errors)
      _ =>
        errors.push(
          ValidationError::new(
            instance_path.field(name),
            schema_path,
            InvalidSchema,
            "`additionalProperties` must be a boolean or schema object",
          ),
        )
    }
  })
}

///| 校验数组相关关键字。
fn check_array_rules(
  rules : Map[String, Json],
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  guard instance is Array(items) else { return }
  if rules.get("minItems") is Some(limit) {
    check_length_limit(
      limit,
      items.length(),
      instance_path,
      schema_path.field("minItems"),
      ArrayTooShort,
      current => limit_value => current < limit_value,
      "`minItems` must be a non-negative integer",
      "array has fewer items than minItems",
      errors,
    )
  }
  if rules.get("maxItems") is Some(limit) {
    check_length_limit(
      limit,
      items.length(),
      instance_path,
      schema_path.field("maxItems"),
      ArrayTooLong,
      current => limit_value => current > limit_value,
      "`maxItems` must be a non-negative integer",
      "array has more items than maxItems",
      errors,
    )
  }
  if rules.get("uniqueItems") is Some(flag) {
    check_unique_items(flag, items, instance_path, schema_path.field("uniqueItems"), errors)
  }
  if rules.get("items") is Some(item_schema) {
    items.eachi((index, item) => {
      validate_at(
        item_schema,
        item,
        instance_path.index(index),
        schema_path.field("items"),
        errors,
      )
    })
  }
}

///| 校验 `uniqueItems`。
fn check_unique_items(
  flag : Json,
  items : Array[Json],
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match flag {
    True =>
      for i = 0; i < items.length(); i = i + 1 {
        for j = i + 1; j < items.length(); j = j + 1 {
          if items[i] == items[j] {
            errors.push(
              ValidationError::new(
                instance_path.index(j),
                schema_path,
                UniqueItemsMismatch,
                "array item duplicates a previous item",
              ),
            )
            return
          }
        }
      }
    False => ()
    _ =>
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path,
          InvalidSchema,
          "`uniqueItems` must be a boolean",
        ),
      )
  }
}

///| 校验字符串长度关键字。
fn check_string_length(
  rules : Map[String, Json],
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  guard instance is String(value) else { return }
  if rules.get("minLength") is Some(limit) {
    check_length_limit(
      limit,
      value.length(),
      instance_path,
      schema_path.field("minLength"),
      StringTooShort,
      current => limit_value => current < limit_value,
      "`minLength` must be a non-negative integer",
      "string is shorter than minLength",
      errors,
    )
  }
  if rules.get("maxLength") is Some(limit) {
    check_length_limit(
      limit,
      value.length(),
      instance_path,
      schema_path.field("maxLength"),
      StringTooLong,
      current => limit_value => current > limit_value,
      "`maxLength` must be a non-negative integer",
      "string is longer than maxLength",
      errors,
    )
  }
}

///| 校验长度类整数边界。
fn check_length_limit(
  limit_rule : Json,
  current : Int,
  instance_path : Path,
  schema_path : Path,
  kind : ErrorKind,
  violates_factory : (Int) -> (Int) -> Bool,
  invalid_message : String,
  message : String,
  errors : Array[ValidationError],
) -> Unit {
  match non_negative_integer(limit_rule) {
    Some(limit) =>
      if violates_factory(current)(limit) {
        errors.push(ValidationError::new(instance_path, schema_path, kind, message))
      }
    None =>
      errors.push(
        ValidationError::new(instance_path, schema_path, InvalidSchema, invalid_message),
      )
  }
}

///| 从 JSON number 中提取非负整数。
fn non_negative_integer(value : Json) -> Int? {
  match value {
    Number(n, ..) =>
      if n >= 0.0 && n == @double.trunc(n) {
        Some(n.to_int())
      } else {
        None
      }
    _ => None
  }
}

///| 校验数字范围关键字。
fn check_number_bounds(
  rules : Map[String, Json],
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  guard instance is Number(value, ..) else { return }
  if rules.get("minimum") is Some(limit) {
    check_number_limit(
      limit,
      instance_path,
      schema_path.field("minimum"),
      NumberTooSmall,
      limit => value < limit,
      "`minimum` must be a number",
      "number is smaller than the allowed minimum",
      errors,
    )
  }
  if rules.get("maximum") is Some(limit) {
    check_number_limit(
      limit,
      instance_path,
      schema_path.field("maximum"),
      NumberTooLarge,
      limit => value > limit,
      "`maximum` must be a number",
      "number is larger than the allowed maximum",
      errors,
    )
  }
  if rules.get("exclusiveMinimum") is Some(limit) {
    check_number_limit(
      limit,
      instance_path,
      schema_path.field("exclusiveMinimum"),
      NumberTooSmall,
      limit => value <= limit,
      "`exclusiveMinimum` must be a number",
      "number is not greater than the exclusive minimum",
      errors,
    )
  }
  if rules.get("exclusiveMaximum") is Some(limit) {
    check_number_limit(
      limit,
      instance_path,
      schema_path.field("exclusiveMaximum"),
      NumberTooLarge,
      limit => value >= limit,
      "`exclusiveMaximum` must be a number",
      "number is not smaller than the exclusive maximum",
      errors,
    )
  }
}

///| 提取数字边界并执行比较。
fn check_number_limit(
  limit_rule : Json,
  instance_path : Path,
  schema_path : Path,
  kind : ErrorKind,
  violates : (Double) -> Bool,
  invalid_message : String,
  message : String,
  errors : Array[ValidationError],
) -> Unit {
  match limit_rule {
    Number(limit, ..) =>
      if violates(limit) {
        errors.push(ValidationError::new(instance_path, schema_path, kind, message))
      }
    _ =>
      errors.push(
        ValidationError::new(instance_path, schema_path, InvalidSchema, invalid_message),
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
