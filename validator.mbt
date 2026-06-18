///| MoonSchema 的版本号。
pub fn version() -> String {
  "0.1.0"
}

///| 校验结果。数组为空表示通过。
pub type ValidationResult = Array[ValidationError]

///| 校验实例是否符合 schema，返回全部可收集的错误。
pub fn validate(schema : Json, instance : Json) -> ValidationResult {
  validate_with_root(schema, schema, instance)
}

///| 使用指定根 schema 校验子 schema。
fn validate_with_root(root_schema : Json, schema : Json, instance : Json) -> ValidationResult {
  let errors : Array[ValidationError] = []
  validate_at(root_schema, schema, instance, Path::root(), Path::root(), errors)
  errors
}

///| 快速判断实例是否通过校验。
pub fn is_valid(schema : Json, instance : Json) -> Bool {
  validate(schema, instance).is_empty()
}

///| 从 JSON 文本解析 schema 与实例并执行校验。
pub fn validate_text(
  schema_text : String,
  instance_text : String,
) -> Result[ValidationResult, String] {
  let schema = @json.parse(schema_text) catch {
    _ => return Err("failed to parse schema JSON")
  }
  let instance = @json.parse(instance_text) catch {
    _ => return Err("failed to parse instance JSON")
  }
  Ok(validate(schema, instance))
}

///| 从 JSON 文本快速判断是否通过。
pub fn is_valid_text(schema_text : String, instance_text : String) -> Result[Bool, String] {
  match validate_text(schema_text, instance_text) {
    Ok(errors) => Ok(errors.is_empty())
    Err(message) => Err(message)
  }
}

///| 在指定路径下递归校验。
fn validate_at(
  root_schema : Json,
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
      if rules.get("$ref") is Some(ref_rule) {
        check_ref(
          root_schema,
          ref_rule,
          instance,
          instance_path,
          schema_path.field("$ref"),
          errors,
        )
      }
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
      check_string_pattern(rules, instance, instance_path, schema_path, errors)
      check_array_rules(root_schema, rules, instance, instance_path, schema_path, errors)
      check_object_rules(root_schema, rules, instance, instance_path, schema_path, errors)
      check_combinations(root_schema, rules, instance, instance_path, schema_path, errors)
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

///| 校验本地 `$ref`。
fn check_ref(
  root_schema : Json,
  ref_rule : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match ref_rule {
    String(ref_text) =>
      match resolve_local_ref(root_schema, ref_text) {
        Some(target) =>
          validate_at(root_schema, target, instance, instance_path, schema_path, errors)
        None =>
          errors.push(
            ValidationError::new(
              instance_path,
              schema_path,
              RefNotFound,
              "local $ref could not be resolved",
            ),
          )
      }
    _ =>
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path,
          InvalidSchema,
          "`$ref` must be a string",
        ),
      )
  }
}

///| 解析 `#` 或 `#/path` 形式的本地 JSON Pointer。
fn resolve_local_ref(root_schema : Json, ref_text : String) -> Json? {
  if ref_text == "#" {
    return Some(root_schema)
  }
  guard ref_text.strip_prefix("#/") is Some(pointer) else { return None }
  let mut current = root_schema
  let mut found = true
  pointer.split("/").each(segment => {
    if !found {
      return
    }
    let key = unescape_pointer_segment(segment.to_owned())
    match current {
      Object(fields) =>
        match fields.get(key) {
          Some(next) => current = next
          None => found = false
        }
      _ => found = false
    }
  })
  if found { Some(current) } else { None }
}

///| 反转 JSON Pointer 片段转义。
fn unescape_pointer_segment(segment : String) -> String {
  segment.replace_all(old="~1", new="/").replace_all(old="~0", new="~")
}

///| 校验组合关键字。
fn check_combinations(
  root_schema : Json,
  rules : Map[String, Json],
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  if rules.get("allOf") is Some(items) {
    check_all_of(root_schema, items, instance, instance_path, schema_path.field("allOf"), errors)
  }
  if rules.get("anyOf") is Some(items) {
    check_any_of(root_schema, items, instance, instance_path, schema_path.field("anyOf"), errors)
  }
  if rules.get("oneOf") is Some(items) {
    check_one_of(root_schema, items, instance, instance_path, schema_path.field("oneOf"), errors)
  }
  if rules.get("not") is Some(item) {
    let nested : Array[ValidationError] = []
    validate_at(root_schema, item, instance, instance_path, schema_path.field("not"), nested)
    if nested.is_empty() {
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path.field("not"),
          CombinationFailed,
          "`not` schema matched the instance",
        ),
      )
    }
  }
}

///| 校验 `allOf`。
fn check_all_of(
  root_schema : Json,
  items_rule : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match items_rule {
    Array(items) =>
      items.eachi((index, item) => {
        validate_at(root_schema, item, instance, instance_path, schema_path.index(index), errors)
      })
    _ =>
      errors.push(
        ValidationError::new(instance_path, schema_path, InvalidSchema, "`allOf` must be an array"),
      )
  }
}

///| 校验 `anyOf`。
fn check_any_of(
  root_schema : Json,
  items_rule : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match items_rule {
    Array(items) => {
      if items.any(item => validate_with_root(root_schema, item, instance).is_empty()) {
        return
      }
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path,
          CombinationFailed,
          "instance does not match any schema in anyOf",
        ),
      )
    }
    _ =>
      errors.push(
        ValidationError::new(instance_path, schema_path, InvalidSchema, "`anyOf` must be an array"),
      )
  }
}

///| 校验 `oneOf`。
fn check_one_of(
  root_schema : Json,
  items_rule : Json,
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  match items_rule {
    Array(items) => {
      let mut matches = 0
      items.each(item => {
        if validate_with_root(root_schema, item, instance).is_empty() {
          matches += 1
        }
      })
      if matches != 1 {
        errors.push(
          ValidationError::new(
            instance_path,
            schema_path,
            CombinationFailed,
            "instance must match exactly one schema in oneOf",
          ),
        )
      }
    }
    _ =>
      errors.push(
        ValidationError::new(instance_path, schema_path, InvalidSchema, "`oneOf` must be an array"),
      )
  }
}

///| 校验对象相关关键字。
fn check_object_rules(
  root_schema : Json,
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
                root_schema,
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
      root_schema,
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
  root_schema : Json,
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
      Object(_) => validate_at(root_schema, rule, value, instance_path.field(name), schema_path, errors)
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
  root_schema : Json,
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
        root_schema,
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

///| 校验字符串 `pattern` 关键字。
fn check_string_pattern(
  rules : Map[String, Json],
  instance : Json,
  instance_path : Path,
  schema_path : Path,
  errors : Array[ValidationError],
) -> Unit {
  guard instance is String(value) else { return }
  guard rules.get("pattern") is Some(pattern_rule) else { return }
  match pattern_rule {
    String(pattern) => {
      let regex = @string.Regex::new(pattern) catch {
        _ => {
          errors.push(
            ValidationError::new(
              instance_path,
              schema_path.field("pattern"),
              InvalidSchema,
              "`pattern` is not a valid regular expression",
            ),
          )
          return
        }
      }
      if regex.execute(value) is None {
        errors.push(
          ValidationError::new(
            instance_path,
            schema_path.field("pattern"),
            PatternMismatch,
            "string does not match pattern",
          ),
        )
      }
    }
    _ =>
      errors.push(
        ValidationError::new(
          instance_path,
          schema_path.field("pattern"),
          InvalidSchema,
          "`pattern` must be a string",
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
