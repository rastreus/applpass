---
name: swift6
description: "**REQUIRED** - Read before writing ANY Swift code. Covers Swift 6 strict concurrency, Swift Testing framework, common pitfalls, and macOS Security framework patterns specific to this project."
allowed-tools: Bash(swift *)
---

# Swift 6 — Agent Reference Guide

> **CRITICAL**: This project uses Swift 6.2.3 with strict concurrency checking.
> Your training data may contain Swift 5 patterns that will cause compilation errors.
> Read this file before writing ANY Swift code.

## Stack Versions

| Component              | Version | Notes                          |
|------------------------|---------|--------------------------------|
| Swift                  | 6.2.3   | Strict concurrency enabled     |
| Swift Argument Parser  | 1.5+    | CLI framework                  |
| Swift Testing          | Built-in| NOT XCTest                     |
| macOS Target           | 14.0+   | Sonoma or later                |
| Security.framework     | System  | Keychain Services API          |

## Critical Differences from Swift 5

### 1. Sendable Protocol — REQUIRED for Concurrency Safety

**Swift 5 (WRONG in Swift 6 strict mode):**
```swift
// This will cause errors if passed across isolation boundaries
struct KeychainItem {
    let service: String
    let password: String
}
```

**Swift 6 (CORRECT):**
```swift
// Explicitly conform to Sendable
struct KeychainItem: Sendable {
    let service: String
    let password: String
}

// Enums must also be Sendable
enum KeychainError: Error, Sendable {
    case itemNotFound
    case accessDenied
}
```

**Rule**: Any type that crosses isolation boundaries MUST be `Sendable`.
Value types (struct/enum) with all-Sendable properties are automatically Sendable,
but explicit conformance is required in Swift 6.

### 2. Swift Testing — NOT XCTest

**Swift 5 / XCTest (WRONG):**
```swift
import XCTest
@testable import ApplPass

class KeychainTests: XCTestCase {
    func testGetPassword() {
        XCTAssertEqual(value, expected)
    }
}
```

**Swift 6 / Swift Testing (CORRECT):**
```swift
import Testing
@testable import ApplPass

@Suite("Keychain Manager Tests")
struct KeychainManagerTests {
    
    @Test("Get password returns correct item")
    func getPassword() {
        #expect(value == expected)
    }
    
    @Test("Error handling", arguments: [
        KeychainError.itemNotFound,
        KeychainError.accessDenied
    ])
    func errorHandling(error: KeychainError) throws {
        #expect(throws: error) {
            try functionThatThrows(error)
        }
    }
}
```

### 3. Typed Throws (SE-0413)

**Swift 5 (untyped throws):**
```swift
func getPassword() throws -> String {
    // Can throw any Error
}
```

**Swift 6 (typed throws - optional but recommended):**
```swift
enum KeychainError: Error {
    case itemNotFound
    case accessDenied
}

func getPassword() throws(KeychainError) -> String {
    // Can ONLY throw KeychainError
}

// Caller knows exact error type
do {
    let password = try getPassword()
} catch KeychainError.itemNotFound {
    // Handle specific error
}
```

### 4. Access Level on Import (Experimental Feature)

Enable in Package.swift:
```swift
swiftSettings: [
    .enableExperimentalFeature("AccessLevelOnImport")
]
```

Then use:
```swift
internal import Foundation  // Foundation types are internal
```

### 5. Actor Isolation

**Swift 5 patterns may not be thread-safe:**
```swift
// WRONG - mutable state without protection
class Cache {
    var items: [String: KeychainItem] = [:]
}
```

**Swift 6 options:**
```swift
// Option 1: Actor for mutable state
actor Cache {
    private var items: [String: KeychainItem] = [:]
    
    func get(_ key: String) -> KeychainItem? {
        items[key]
    }
    
    func set(_ key: String, _ item: KeychainItem) {
        items[key] = item
    }
}

// Option 2: Sendable value type (immutable)
struct Cache: Sendable {
    let items: [String: KeychainItem]
}
```

## Swift Testing Patterns

### Basic Test Structure

```swift
import Testing
@testable import ApplPass

@Suite("Password Generator Tests")
struct PasswordGeneratorTests {
    
    @Test("Generates password of correct length")
    func correctLength() {
        let password = PasswordGenerator.generate(length: 32)
        #expect(password.count == 32)
    }
    
    @Test("Contains required character sets")
    func characterSets() {
        let password = PasswordGenerator.generate(length: 100)
        
        #expect(password.contains(where: { $0.isUppercase }))
        #expect(password.contains(where: { $0.isLowercase }))
        #expect(password.contains(where: { $0.isNumber }))
    }
}
```

### Parameterized Tests

```swift
@Test("Password length variations", arguments: [16, 32, 64, 128])
func passwordLength(length: Int) {
    let password = PasswordGenerator.generate(length: length)
    #expect(password.count == length)
}

// Multiple parameters
@Test("Character set combinations", arguments: zip(
    [true, false],
    [true, false]
))
func characterSets(includeSymbols: Bool, includeDigits: Bool) {
    let password = PasswordGenerator.generate(
        includeSymbols: includeSymbols,
        includeDigits: includeDigits
    )
    // Verify expectations
}
```

### Error Testing

```swift
@Test("Throws on invalid input")
func invalidInput() {
    #expect(throws: KeychainError.invalidParameter("length")) {
        try PasswordGenerator.generate(length: -1)
    }
}

// Test specific error type
@Test("Item not found error")
func itemNotFound() throws {
    let manager = KeychainManager()
    
    #expect(throws: KeychainError.itemNotFound) {
        try manager.getPassword(for: nonexistentQuery)
    }
}
```

### Suite Organization

```swift
@Suite("Keychain Manager Tests")
struct KeychainManagerTests {
    
    @Suite("Query Building")
    struct QueryBuildingTests {
        @Test("Internet password query")
        func internetPassword() { }
        
        @Test("Generic password query")
        func genericPassword() { }
    }
    
    @Suite("CRUD Operations")
    struct CRUDTests {
        @Test("Add password")
        func add() { }
        
        @Test("Get password")
        func get() { }
    }
}
```

### Async Tests

```swift
@Test("Async operation")
func asyncOperation() async throws {
    let result = await someAsyncFunction()
    #expect(result.isValid)
}
```

### Test Lifecycle

```swift
@Suite(.serialized)  // Run tests in serial (for keychain operations)
struct IntegrationTests {
    
    init() {
        // Setup before all tests in suite
    }
    
    deinit {
        // Cleanup after all tests in suite
    }
}
```

## macOS Keychain Security Framework Patterns

### Query Dictionary Construction

```swift
// Build query for password lookup
let query: [String: Any] = [
    kSecClass as String: kSecClassInternetPassword,
    kSecAttrServer as String: "github.com",
    kSecAttrAccount as String: "bot@example.com",
    kSecReturnData as String: true,
    kSecReturnAttributes as String: true,
    kSecMatchLimit as String: kSecMatchLimitOne
]
```

### Common Query Keys

| Key                          | Purpose                           | Type              |
|------------------------------|-----------------------------------|-------------------|
| `kSecClass`                  | Item class (password, key, etc.)  | CFString          |
| `kSecAttrServer`             | Service/domain name               | String            |
| `kSecAttrAccount`            | Account/username                  | String            |
| `kSecAttrSynchronizable`     | iCloud sync (shared passwords)    | CFBoolean         |
| `kSecReturnData`             | Return password data              | CFBoolean         |
| `kSecReturnAttributes`       | Return metadata                   | CFBoolean         |
| `kSecMatchLimit`             | Number of results                 | CFString/CFNumber |

### Item Classes

```swift
// Internet passwords (websites, APIs)
kSecClassInternetPassword

// Generic passwords (apps, services)
kSecClassGenericPassword

// Certificates
kSecClassCertificate

// Cryptographic keys
kSecClassKey
```

### OSStatus Error Handling

```swift
let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &result)

switch status {
case errSecSuccess:
    // Success
    break
case errSecItemNotFound:
    throw KeychainError.itemNotFound
case errSecAuthFailed, errSecUserCanceled:
    throw KeychainError.authorizationDenied
case errSecDuplicateItem:
    throw KeychainError.duplicateItem
default:
    throw KeychainError.unhandledError(status: status)
}
```

### Common OSStatus Codes

| Code      | Constant              | Meaning                   |
|-----------|-----------------------|---------------------------|
| 0         | errSecSuccess         | Operation successful      |
| -25300    | errSecItemNotFound    | Item not found            |
| -25299    | errSecDuplicateItem   | Item already exists       |
| -128      | errSecUserCanceled    | User canceled operation   |
| -25293    | errSecAuthFailed      | Authentication failed     |

### Password Data Decoding

```swift
// SecItemCopyMatching returns CFData for password
var result: AnyObject?
let status = SecItemCopyMatching(query as CFDictionary, &result)

guard status == errSecSuccess else {
    throw KeychainError.fromStatus(status)
}

guard let data = result as? Data,
      let password = String(data: data, encoding: .utf8) else {
    throw KeychainError.unexpectedPasswordData
}
```

### Adding Passwords

```swift
let addQuery: [String: Any] = [
    kSecClass as String: kSecClassInternetPassword,
    kSecAttrServer as String: service,
    kSecAttrAccount as String: account,
    kSecValueData as String: password.data(using: .utf8)!,
    kSecAttrLabel as String: label,
    kSecAttrSynchronizable as String: kCFBooleanTrue  // Enable iCloud sync
]

let status = SecItemAdd(addQuery as CFDictionary, nil)
```

### Updating Passwords

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassInternetPassword,
    kSecAttrServer as String: service,
    kSecAttrAccount as String: account
]

let update: [String: Any] = [
    kSecValueData as String: newPassword.data(using: .utf8)!
]

let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
```

### Deleting Passwords

```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassInternetPassword,
    kSecAttrServer as String: service,
    kSecAttrAccount as String: account
]

let status = SecItemDelete(query as CFDictionary)
```

## Swift Argument Parser Patterns

### Basic Command Structure

```swift
import ArgumentParser

@main
struct ApplPass: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "macOS Keychain password manager",
        version: "1.0.0",
        subcommands: [Get.self, List.self, Add.self],
        defaultSubcommand: Get.self
    )
}
```

### Subcommand Definition

```swift
extension ApplPass {
    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Get a password from keychain"
        )
        
        @Option(name: .shortAndLong, help: "Service name")
        var service: String
        
        @Option(name: .shortAndLong, help: "Account name")
        var account: String
        
        @Flag(name: .long, help: "Copy to clipboard")
        var clipboard: Bool = false
        
        @Flag(name: .long, help: "Output value only")
        var valueOnly: Bool = false
        
        mutating func run() throws {
            let manager = KeychainManager()
            let query = KeychainQuery(service: service, account: account)
            let item = try manager.getPassword(for: query)
            
            if valueOnly {
                print(item.password)
            } else {
                print("Service: \(item.service)")
                print("Account: \(item.account)")
            }
        }
    }
}
```

### Validation

```swift
struct Add: ParsableCommand {
    @Option var service: String
    @Option var account: String
    
    mutating func validate() throws {
        if service.isEmpty {
            throw ValidationError("Service cannot be empty")
        }
        if account.isEmpty {
            throw ValidationError("Account cannot be empty")
        }
    }
    
    mutating func run() throws {
        // Implementation
    }
}
```

### Enums as Options

```swift
enum OutputFormat: String, ExpressibleByArgument {
    case table
    case json
    case csv
}

struct List: ParsableCommand {
    @Option var format: OutputFormat = .table
    
    mutating func run() throws {
        switch format {
        case .table:
            // Output table
        case .json:
            // Output JSON
        case .csv:
            // Output CSV
        }
    }
}
```

## Common Pitfalls

### ❌ Pitfall 1: Force Unwrapping

```swift
// BAD
let password = dict[kSecValueData]!

// GOOD
guard let passwordData = dict[kSecValueData] as? Data else {
    throw KeychainError.unexpectedPasswordData
}
```

### ❌ Pitfall 2: Non-Sendable Types

```swift
// BAD - will fail with strict concurrency
struct KeychainItem {
    var password: String
}

// GOOD - explicitly Sendable
struct KeychainItem: Sendable {
    let password: String
}
```

### ❌ Pitfall 3: Using XCTest Instead of Swift Testing

```swift
// BAD
import XCTest

// GOOD
import Testing
```

### ❌ Pitfall 4: Logging Passwords

```swift
// BAD - security violation
print("Password: \(password)")
logger.debug("Retrieved password: \(password)")

// GOOD
print("Successfully retrieved password for \(account)")
logger.info("Password retrieved for service: \(service)")
```

### ❌ Pitfall 5: Synchronous Keychain on Main Thread

```swift
// BAD - blocks UI if used in GUI
let password = try keychainManager.getPassword(for: query)

// GOOD - async for non-blocking
let password = try await keychainManager.getPassword(for: query)
```

## Security Best Practices

### 1. Never Log Credentials
```swift
// ❌ NEVER
print("Password: \(password)")
print("Token: \(apiKey)")

// ✅ ALWAYS
print("Successfully retrieved password")
print("Token length: \(apiKey.count)")
```

### 2. Use Stdin for Sensitive Input
```swift
// ❌ NEVER accept passwords as CLI arguments
// applpass add --password "secret123"  // Shows in ps, history!

// ✅ ALWAYS use stdin or interactive prompt
let password = readLine() ?? ""
```

### 3. Zero Out Passwords After Use
```swift
// When possible, clear password from memory
var password = try getPassword()
defer {
    // Zero out string (not guaranteed by Swift, but good practice)
    password = String(repeating: " ", count: password.count)
}
```

### 4. Respect Keychain Access Prompts
```swift
// User will be prompted for keychain access
// NEVER try to bypass or suppress these prompts
// Handle authorization denial gracefully
```

## Package.swift Configuration

```swift
// swift-tools-version: 6.2.3
import PackageDescription

let package = Package(
    name: "applpass",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "ApplPass",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("AccessLevelOnImport")
            ]
        ),
        .testTarget(
            name: "ApplPassTests",
            dependencies: ["ApplPass"]
        )
    ],
    swiftLanguageModes: [.v6]
)
```

## Documentation Comments

```swift
/// Generates a cryptographically secure random password.
///
/// The password is generated using `SecRandomCopyBytes` to ensure
/// cryptographic quality randomness.
///
/// - Parameters:
///   - length: The desired password length. Must be positive.
///   - includeSymbols: Whether to include special characters (!@#$%^&*).
/// - Returns: A randomly generated password string.
/// - Throws: `PasswordGeneratorError.invalidLength` if length <= 0.
///
/// Example:
/// ```swift
/// let password = try PasswordGenerator.generate(length: 32)
/// print(password.count) // 32
/// ```
func generate(
    length: Int = 32,
    includeSymbols: Bool = true
) throws -> String
```

## Quick Reference Commands

```bash
# Build
swift build

# Release build
swift build -c release

# Run tests
swift test

# Verbose test output
swift test --verbose

# Run specific test
swift test --filter ApplPassTests.KeychainManagerTests

# Format code (if swift-format installed)
swift format --in-place --recursive Sources/ Tests/

# Lint code
swift format lint --recursive Sources/ Tests/
```

## Further Reading

- Swift Concurrency: https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html
- Swift Testing: https://developer.apple.com/documentation/testing
- Keychain Services: https://developer.apple.com/documentation/security/keychain_services
- Swift Argument Parser: https://github.com/apple/swift-argument-parser
