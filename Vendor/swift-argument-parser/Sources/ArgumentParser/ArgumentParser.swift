import Darwin

public struct CommandConfiguration: Sendable {
  public let abstract: String
  public let version: String?

  public init(
    abstract: String = "",
    version: String? = nil
  ) {
    self.abstract = abstract
    self.version = version
  }
}

public protocol ParsableCommand {
  init()
  static var configuration: CommandConfiguration { get }
  mutating func run() throws
}

extension ParsableCommand {
  public static var configuration: CommandConfiguration {
    CommandConfiguration()
  }

  public mutating func run() throws {}

  public static func main() {
    var command = Self.init()
    let arguments = CommandLine.arguments.dropFirst()

    if arguments.contains("--version") {
      if let version = Self.configuration.version {
        print(version)
      }
      return
    }

    do {
      try command.run()
    } catch {
      fputs("\(error)\n", stderr)
    }
  }
}
