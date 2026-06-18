///| 命令行入口。当前支持直接传入 JSON 文本，便于无文件 IO 环境使用。
fn main {
  println(run_args(@env.args()))
}

///| 执行命令并返回要打印的文本。
fn run_args(args : Array[String]) -> String {
  if args.length() == 1 || args.contains("--help") || args.contains("-h") {
    return usage()
  }
  let schema_text = option_value(args, "--schema-json")
  let instance_text = option_value(args, "--instance-json")
  match (schema_text, instance_text) {
    (Some(schema), Some(instance)) =>
      match @MoonSchema.validate_text_report(schema, instance) {
        Ok(report) => report.render()
        Err(message) => "error: \{message}"
      }
    _ => usage()
  }
}

///| 返回指定选项后的值。
fn option_value(args : Array[String], name : String) -> String? {
  for index = 0; index < args.length(); index = index + 1 {
    if args[index] == name {
      return args.get(index + 1)
    }
  }
  None
}

///| 命令帮助文本。
fn usage() -> String {
  let text = #|MoonSchema
  #|
  #|Usage:
  #|  moon run cmd/moonschema -- --schema-json <schema> --instance-json <json>
  #|
  #|Example:
  #|  moon run cmd/moonschema -- --schema-json '{"type":"integer"}' --instance-json '42'
  text
}
