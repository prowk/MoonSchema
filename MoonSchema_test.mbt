///|
test "version" {
  inspect(@MoonSchema.version(), content="0.1.0")
}

///|
test "path pointer escaping" {
  let path = @MoonSchema.Path::root().field("user/name").field("~meta")
  inspect(path.to_pointer(), content="#user~1name/~0meta")
}

///|
test "error summary contains paths" {
  let err = @MoonSchema.ValidationError::new(
    @MoonSchema.Path::root().field("age"),
    @MoonSchema.Path::root().field("properties").field("age").field("type"),
    @MoonSchema.ErrorKind::TypeMismatch,
    "expected integer",
  )
  inspect(
    err.summary(),
    content="#age violates #properties/age/type: expected integer",
  )
}
