@main
struct ApplPass {
  static let version = "0.1.0"

  static func main() {
    let arguments = CommandLine.arguments.dropFirst()
    if arguments.contains("--version") {
      print(version)
      return
    }

    print("applpass \(version)")
  }
}
