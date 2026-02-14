import Foundation

/// Formats keychain items for command-line output.
struct OutputFormatter: Sendable {
  /// Formats keychain items according to a selected output style.
  ///
  /// Password values are excluded unless `showPasswords` is `true`.
  static func format(
    _ items: [KeychainItem],
    style: OutputStyle,
    showPasswords: Bool = false
  ) -> String {
    switch style {
    case .table:
      return formatTable(items, showPasswords: showPasswords)
    case .json:
      return formatJSON(items, showPasswords: showPasswords)
    case .csv:
      return formatCSV(items, showPasswords: showPasswords)
    case .plain:
      return formatPlain(items, showPasswords: showPasswords)
    }
  }

  private static func formatTable(
    _ items: [KeychainItem],
    showPasswords: Bool
  ) -> String {
    _ = items
    _ = showPasswords
    return ""
  }

  private static func formatJSON(
    _ items: [KeychainItem],
    showPasswords: Bool
  ) -> String {
    _ = items
    _ = showPasswords
    return ""
  }

  private static func formatCSV(
    _ items: [KeychainItem],
    showPasswords: Bool
  ) -> String {
    _ = items
    _ = showPasswords
    return ""
  }

  private static func formatPlain(
    _ items: [KeychainItem],
    showPasswords: Bool
  ) -> String {
    _ = items
    _ = showPasswords
    return ""
  }
}
