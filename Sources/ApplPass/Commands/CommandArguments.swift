/// Supported naming patterns for command-line options and flags.
enum CommandOptionName: Sendable {
  case short
  case long
  case shortAndLong
  case customShort(String)
}

/// Metadata wrapper for option arguments.
@propertyWrapper
struct Option<Value: Sendable>: Sendable {
  var wrappedValue: Value

  init(
    wrappedValue: Value,
    name: CommandOptionName = .long,
    help: String = ""
  ) {
    _ = name
    _ = help
    self.wrappedValue = wrappedValue
  }

  init(
    name: CommandOptionName = .long,
    help: String = ""
  ) where Value: ExpressibleByNilLiteral {
    _ = name
    _ = help
    self.wrappedValue = nil
  }
}

/// Metadata wrapper for boolean flags.
@propertyWrapper
struct Flag: Sendable {
  var wrappedValue: Bool

  init(
    wrappedValue: Bool,
    name: CommandOptionName = .long,
    help: String = ""
  ) {
    _ = name
    _ = help
    self.wrappedValue = wrappedValue
  }

  init(
    wrappedValue: Bool,
    name: [CommandOptionName],
    help: String = ""
  ) {
    _ = name
    _ = help
    self.wrappedValue = wrappedValue
  }

  init(
    name: CommandOptionName = .long,
    help: String = ""
  ) {
    _ = name
    _ = help
    self.wrappedValue = false
  }

  init(
    name: [CommandOptionName],
    help: String = ""
  ) {
    _ = name
    _ = help
    self.wrappedValue = false
  }
}

/// Metadata wrapper for grouping shared options.
@propertyWrapper
struct OptionGroup<Value: Sendable>: Sendable {
  var wrappedValue: Value
}
