///| 校验错误代码，便于调用方做程序化处理。
pub(all) enum ErrorKind {
  TypeMismatch
  ConstMismatch
  EnumMismatch
  NumberTooSmall
  NumberTooLarge
  MultipleOfMismatch
  StringTooShort
  StringTooLong
  PatternMismatch
  ArrayTooShort
  ArrayTooLong
  UniqueItemsMismatch
  ContainsMismatch
  MissingRequired
  AdditionalProperty
  ObjectTooSmall
  ObjectTooLarge
  CombinationFailed
  RefNotFound
  InvalidSchema
} derive(Eq, Debug)

///| 单条结构化校验错误。
pub(all) struct ValidationError {
  instance_path : Path
  schema_path : Path
  kind : ErrorKind
  message : String
} derive(Eq, Debug)

///| 构造校验错误。
pub fn ValidationError::new(
  instance_path : Path,
  schema_path : Path,
  kind : ErrorKind,
  message : String,
) -> ValidationError {
  { instance_path, schema_path, kind, message }
}

///| 返回易读的错误位置摘要。
pub fn ValidationError::summary(self : ValidationError) -> String {
  "\{self.instance_path.to_pointer()} violates \{self.schema_path.to_pointer()}: \{self.message}"
}

///| 返回稳定的错误代码文本。
pub fn ErrorKind::label(self : ErrorKind) -> String {
  match self {
    TypeMismatch => "type_mismatch"
    ConstMismatch => "const_mismatch"
    EnumMismatch => "enum_mismatch"
    NumberTooSmall => "number_too_small"
    NumberTooLarge => "number_too_large"
    MultipleOfMismatch => "multiple_of_mismatch"
    StringTooShort => "string_too_short"
    StringTooLong => "string_too_long"
    PatternMismatch => "pattern_mismatch"
    ArrayTooShort => "array_too_short"
    ArrayTooLong => "array_too_long"
    UniqueItemsMismatch => "unique_items_mismatch"
    ContainsMismatch => "contains_mismatch"
    MissingRequired => "missing_required"
    AdditionalProperty => "additional_property"
    ObjectTooSmall => "object_too_small"
    ObjectTooLarge => "object_too_large"
    CombinationFailed => "combination_failed"
    RefNotFound => "ref_not_found"
    InvalidSchema => "invalid_schema"
  }
}
