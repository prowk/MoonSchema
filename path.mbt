///| JSON Pointer 风格的路径，用于定位实例或 schema 中的节点。
pub struct Path {
  segments : Array[String]
} derive(Eq, Debug)

///| 创建根路径。
pub fn Path::root() -> Path {
  { segments: [] }
}

///| 返回追加对象属性后的路径。
pub fn Path::field(self : Path, name : String) -> Path {
  let next = self.segments.copy()
  next.push(name)
  { segments: next }
}

///| 返回追加数组下标后的路径。
pub fn Path::index(self : Path, index : Int) -> Path {
  self.field(index.to_string())
}

///| 转为 JSON Pointer 字符串。
pub fn Path::to_pointer(self : Path) -> String {
  if self.segments.is_empty() {
    "#"
  } else {
    "#" + self.segments.map(escape_segment).join("/")
  }
}

///| JSON Pointer 中 `~` 和 `/` 需要转义。
fn escape_segment(segment : String) -> String {
  let buf = StringBuilder::new()
  for ch in segment {
    match ch {
      '~' => buf.write_string("~0")
      '/' => buf.write_string("~1")
      _ => buf.write_char(ch)
    }
  }
  buf.to_string()
}
