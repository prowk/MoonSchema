///| 校验错误代码，便于调用方做程序化处理。
pub(all) enum ErrorKind {
  TypeMismatch
  ConstMismatch
  EnumMismatch
  NumberTooSmall
  NumberTooLarge
  StringTooShort
  StringTooLong
  ArrayTooShort
  ArrayTooLong
  UniqueItemsMismatch
  MissingRequired
  AdditionalProperty
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
