///| MoonSchema 的版本号。
pub fn version() -> String {
  "0.1.0"
}

///| 校验结果。数组为空表示通过。
pub type ValidationResult = Array[ValidationError]
