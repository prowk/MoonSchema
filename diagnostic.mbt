///| 校验报告，适合 CLI 或上层工具展示。
pub struct ValidationReport {
  valid : Bool
  errors : Array[ValidationError]
} derive(Debug)

///| 从错误数组构造报告。
pub fn ValidationReport::from_errors(errors : Array[ValidationError]) -> ValidationReport {
  { valid: errors.is_empty(), errors }
}

///| 校验并返回报告。
pub fn validate_report(schema : Json, instance : Json) -> ValidationReport {
  ValidationReport::from_errors(validate(schema, instance))
}

///| 校验 JSON 文本并返回报告。
pub fn validate_text_report(
  schema_text : String,
  instance_text : String,
) -> Result[ValidationReport, String] {
  match validate_text(schema_text, instance_text) {
    Ok(errors) => Ok(ValidationReport::from_errors(errors))
    Err(message) => Err(message)
  }
}

///| 将报告渲染为多行文本。
pub fn ValidationReport::render(self : ValidationReport) -> String {
  if self.valid {
    "valid"
  } else {
    let lines : Array[String] = ["invalid"]
    self.errors.eachi((index, error) => {
      lines.push("\{index + 1}. \{error.summary()} [\{error.kind.label()}]")
    })
    lines.join("\n")
  }
}
