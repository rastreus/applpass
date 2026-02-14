import Foundation

/// Formats keychain items for command-line output.
struct OutputFormatter: Sendable {
  private static let headers = ["SERVICE", "ACCOUNT", "LABEL", "SHARED", "GROUP", "CLASS"]

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
    let headerRow = columns(showPasswords: showPasswords)
    let rows = items.map { rowValues(for: $0, showPasswords: showPasswords) }
    let widths = (0..<headerRow.count).map { index in
      max(headerRow[index].count, rows.map { $0[index].count }.max() ?? 0)
    }

    let formattedHeader = renderLine(headerRow, widths: widths)
    let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "-+-")
    let formattedRows = rows.map { renderLine($0, widths: widths) }

    return ([formattedHeader, separator] + formattedRows).joined(separator: "\n")
  }

  private static func formatJSON(
    _ items: [KeychainItem],
    showPasswords: Bool
  ) -> String {
    let payload = items.map { jsonObject(for: $0, showPasswords: showPasswords) }
    guard
      JSONSerialization.isValidJSONObject(payload),
      let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
      let text = String(data: data, encoding: .utf8)
    else {
      return "[]"
    }

    return text
  }

  private static func formatCSV(
    _ items: [KeychainItem],
    showPasswords: Bool
  ) -> String {
    let header = columns(showPasswords: showPasswords)
      .map(escapedCSVField)
      .joined(separator: ",")
    let rows = items.map { item in
      rowValues(for: item, showPasswords: showPasswords)
        .map(escapedCSVField)
        .joined(separator: ",")
    }

    return ([header] + rows).joined(separator: "\r\n")
  }

  private static func formatPlain(
    _ items: [KeychainItem],
    showPasswords: Bool
  ) -> String {
    items
      .map { item in
        var fields = [item.service, item.account]
        if showPasswords {
          fields.append(item.password)
        }
        return fields.joined(separator: "\t")
      }
      .joined(separator: "\n")
  }

  private static func columns(showPasswords: Bool) -> [String] {
    if showPasswords {
      return headers + ["PASSWORD"]
    }
    return headers
  }

  private static func rowValues(for item: KeychainItem, showPasswords: Bool) -> [String] {
    var values = [
      item.service,
      item.account,
      item.label ?? "",
      item.isShared ? "yes" : "no",
      item.sharedGroupName ?? "",
      item.itemClass.rawValue,
    ]
    if showPasswords {
      values.append(item.password)
    }
    return values
  }

  private static func renderLine(_ values: [String], widths: [Int]) -> String {
    zip(values, widths)
      .map { value, width in
        value.padding(toLength: width, withPad: " ", startingAt: 0)
      }
      .joined(separator: " | ")
  }

  private static func jsonObject(for item: KeychainItem, showPasswords: Bool) -> [String: Any] {
    var object: [String: Any] = [
      "service": item.service,
      "account": item.account,
      "label": item.label as Any,
      "isShared": item.isShared,
      "sharedGroupName": item.sharedGroupName as Any,
      "itemClass": item.itemClass.rawValue,
    ]
    if let creationDate = item.creationDate {
      object["creationDate"] = creationDate.ISO8601Format()
    }
    if let modificationDate = item.modificationDate {
      object["modificationDate"] = modificationDate.ISO8601Format()
    }
    if showPasswords {
      object["password"] = item.password
    }
    return object
  }

  private static func escapedCSVField(_ field: String) -> String {
    let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
    let requiresQuotes = escaped.contains(",") || escaped.contains("\"")
      || escaped.contains("\n") || escaped.contains("\r")
    guard requiresQuotes else {
      return escaped
    }
    return "\"\(escaped)\""
  }
}
