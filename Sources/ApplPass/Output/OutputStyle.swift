/// Supported output rendering styles for keychain items.
enum OutputStyle: String, Sendable, Equatable, Codable {
  case table
  case json
  case csv
  case plain
}
