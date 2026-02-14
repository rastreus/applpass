import Foundation
import Testing
@testable import ApplPass

@Suite("Smoke Tests")
struct SmokeTests {
  @Test("Version constant is set")
  func versionConstantIsSet() {
    #expect(!ApplPass.version.isEmpty)
  }

  @Test("Command configuration exposes version")
  func commandConfigurationHasVersion() {
    #expect(ApplPass.configuration.version == ApplPass.version)
  }

  @Test("Version constant matches Package.swift marker")
  func versionConstantMatchesPackageMarker() throws {
    let packageContents = try packageManifestContents()
    let packageVersion = try manifestVersion(in: packageContents)

    #expect(ApplPass.version == packageVersion)
  }

  @Test("Supported subcommands are wired in expected order")
  func supportedSubcommandsAreWiredInExpectedOrder() {
    #expect(
      ApplPass.supportedSubcommands == ["get", "list", "add", "update", "delete", "generate"]
    )
  }

  @Test("Root help includes commands and examples")
  func rootHelpIncludesCommandsAndExamples() {
    let help = ApplPass.rootHelpText(executableName: "applpass")

    #expect(help.contains("COMMANDS:"))
    #expect(help.contains("EXAMPLES:"))
    #expect(help.contains("applpass get --service github.com --account bot@example.com --value-only"))
    #expect(help.contains("applpass add --service github.com --account bot@example.com --stdin"))
  }

  @Test("Get help includes usage and examples")
  func getHelpIncludesUsageAndExamples() {
    let help = ApplPass.subcommandHelpText(for: "get", executableName: "applpass")

    #expect(help?.contains("USAGE:") == true)
    #expect(help?.contains("--service <service>") == true)
    #expect(help?.contains("--account <account>") == true)
    #expect(help?.contains("EXAMPLES:") == true)
  }

  @Test("Missing command error lists available subcommands")
  func missingCommandErrorListsAvailableSubcommands() {
    let commands = ApplPass.supportedSubcommands.joined(separator: ", ")

    #expect(
      ApplPassCommandError.missingSubcommand.description
        == "Missing command. Available commands: \(commands)."
    )
  }

  @Test("Unknown command error lists available subcommands")
  func unknownCommandErrorListsAvailableSubcommands() {
    let commands = ApplPass.supportedSubcommands.joined(separator: ", ")

    #expect(
      ApplPassCommandError.unknownSubcommand("bad").description
        == "Unknown command 'bad'. Available commands: \(commands)."
    )
  }

  private func packageManifestContents() throws -> String {
    for path in packageManifestPaths() {
      if let contents = try? String(contentsOfFile: path, encoding: .utf8) {
        return contents
      }
    }

    throw ManifestLookupError.packageManifestNotFound
  }

  private func packageManifestPaths() -> [String] {
    let currentDirectoryPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      .appendingPathComponent("Package.swift")
      .path
    let sourceTreePath = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Package.swift")
      .path

    return [currentDirectoryPath, sourceTreePath]
  }

  private func manifestVersion(in packageContents: String) throws -> String {
    let prefix = "let applPassVersion = \""
    guard let start = packageContents.range(of: prefix) else {
      throw ManifestLookupError.versionMarkerNotFound
    }

    let remainder = packageContents[start.upperBound...]
    guard let endQuote = remainder.firstIndex(of: "\"") else {
      throw ManifestLookupError.versionMarkerMalformed
    }

    return String(remainder[..<endQuote])
  }
}

enum ManifestLookupError: Error, Sendable {
  case packageManifestNotFound
  case versionMarkerNotFound
  case versionMarkerMalformed
}
