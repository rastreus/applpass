# applpass - Swift CLI Password Manager - Design Document

## Project Overview

### Purpose
A command-line interface (CLI) tool written in Swift that provides secure access to passwords stored in Apple's iCloud Keychain, with support for shared password groups from the Passwords app (iOS 18+, macOS Sequoia+).

**Binary Name**: `applpass` (Apple Password CLI)

### Use Case
Enables automated bots, scripts, and workflows to securely retrieve credentials without hardcoding sensitive information. Particularly useful for:
- Bot accounts that need to access shared team credentials
- Automated deployment scripts
- CI/CD pipelines running on macOS
- Personal automation workflows
- CLI-based password management

### Target Audience
- Developers building macOS automation tools
- DevOps engineers managing credentials
- Power users who prefer command-line workflows
- Bot operators needing secure credential access

### Technology Standards
- **Swift Version**: 6.2.3 (strict concurrency enabled)
- **Testing Framework**: Swift Testing (modern testing with `@Test` macros)
- **Code Formatting**: swift-format with strict style enforcement
- **Best Practices**: Idiomatic Swift 6 patterns, value types, protocol-oriented design

## Core Requirements

### Functional Requirements
1. **Read Operations**
   - Retrieve individual passwords by service name and account
   - List all available passwords with metadata
   - Search/filter passwords by service, account, or domain
   - Access both personal and shared passwords
   - Retrieve verification codes (TOTP)

2. **Write Operations**
   - Add new passwords to keychain
   - Update existing passwords
   - Delete passwords
   - Generate strong random passwords

3. **Shared Password Support**
   - Access passwords from iCloud Keychain shared groups
   - List which passwords are shared vs. personal
   - Identify shared group membership

4. **Output Formats**
   - Plain text (for piping to other commands)
   - JSON (for programmatic consumption)
   - Formatted table (for human readability)
   - Secure clipboard copy

### Non-Functional Requirements
1. **Security**
   - Never log passwords to disk
   - Support secure output (clipboard, stdout)
   - Respect macOS keychain access controls
   - No credential storage in memory longer than necessary

2. **Performance**
   - Sub-second response for single password retrieval
   - Efficient batch operations for listing

3. **Usability**
   - Intuitive command structure
   - Helpful error messages
   - Interactive mode for sensitive operations
   - Shell completion support

4. **Portability**
   - Works on macOS 14+ (Sonoma and later)
   - No external dependencies beyond Swift standard library
   - Single binary distribution

## Architecture

### Technology Stack
- **Language**: Swift 6.2.3 (with strict concurrency checking)
- **Framework**: Security.framework (Apple's Keychain Services)
- **CLI Framework**: Swift Argument Parser 1.5+
- **Build System**: Swift Package Manager
- **Testing**: Swift Testing framework (modern `@Test` syntax)
- **Formatting**: swift-format (automated code style)
- **Optional**: Benchmark package for performance validation

### Component Design

```
┌─────────────────────────────────────┐
│         CLI Interface Layer         │
│   (Argument parsing, formatting)    │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│      Business Logic Layer           │
│  (Password operations, validation)  │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│    Keychain Services Layer          │
│  (SecItem API wrapper, queries)     │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│       macOS Keychain                │
│    (iCloud Keychain Storage)        │
└─────────────────────────────────────┘
```

### Module Structure

```
applpass/
├── Package.swift
├── .swift-format                      # Code style configuration
├── Sources/
│   └── ApplPass/
│       ├── ApplPass.swift             # Entry point with @main
│       ├── Commands/
│       │   ├── GetCommand.swift       # Get password
│       │   ├── ListCommand.swift      # List passwords
│       │   ├── AddCommand.swift       # Add password
│       │   ├── UpdateCommand.swift    # Update password
│       │   ├── DeleteCommand.swift    # Delete password
│       │   └── GenerateCommand.swift  # Generate password
│       ├── KeychainManager/
│       │   ├── KeychainManager.swift  # Core keychain operations
│       │   ├── KeychainItem.swift     # Data models (Sendable)
│       │   └── KeychainQuery.swift    # Query builder
│       ├── Output/
│       │   ├── OutputFormatter.swift  # Format output
│       │   └── OutputStyle.swift      # Output style enum
│       └── Utilities/
│           ├── PasswordGenerator.swift # Random password gen
│           └── SecureString.swift      # Secure string handling
├── Tests/
│   └── ApplPassTests/
│       ├── KeychainManagerTests.swift
│       ├── PasswordGeneratorTests.swift
│       ├── OutputFormatterTests.swift
│       └── IntegrationTests.swift
└── Benchmarks/                         # Optional performance tests
    └── ApplPassBenchmarks/
        └── KeychainBenchmarks.swift
```

## Technical Specifications

### Data Models

#### KeychainItem
```swift
/// Represents a keychain item with all its metadata.
/// Conforms to Sendable for safe concurrent access in Swift 6.
struct KeychainItem: Sendable, Equatable, Codable {
    let service: String           // e.g., "github.com"
    let account: String           // e.g., "bot@example.com"
    let password: String          // The actual credential
    let label: String?            // User-friendly label
    let creationDate: Date?
    let modificationDate: Date?
    let isShared: Bool            // Is this in a shared group?
    let sharedGroupName: String?  // Name of shared group
    let itemClass: ItemClass      // Internet vs Generic password
    
    enum ItemClass: String, Sendable, Codable {
        case internetPassword
        case genericPassword
    }
}
```

#### KeychainQuery
```swift
/// Query parameters for searching keychain items.
/// Uses value semantics for thread-safety.
struct KeychainQuery: Sendable {
    var service: String?
    var account: String?
    var domain: String?
    var includeShared: Bool = true
    var itemClass: ItemClass = .internetPassword
    var limit: Int = 100
    
    enum ItemClass: String, Sendable {
        case internetPassword
        case genericPassword
    }
}
```

### Command Structure

#### 1. Get Command
```bash
# Basic retrieval
applpass get --service github.com --account bot@example.com

# With output format
applpass get --service github.com --account bot@example.com --format json

# Copy to clipboard
applpass get --service github.com --account bot@example.com --clipboard

# Show only password value (for piping)
applpass get --service github.com --account bot@example.com --value-only
```

**Flags:**
- `--service`, `-s`: Service name (required)
- `--account`, `-a`: Account name (required)
- `--format`, `-f`: Output format [text, json] (default: text)
- `--clipboard`, `-c`: Copy to clipboard instead of stdout
- `--value-only`, `-v`: Output only password value
- `--include-metadata`: Show creation/modification dates

#### 2. List Command
```bash
# List all passwords
applpass list

# Filter by service
applpass list --service github.com

# Show only shared passwords
applpass list --shared-only

# Output as JSON
applpass list --format json

# Search in service names
applpass list --search api
```

**Flags:**
- `--service`, `-s`: Filter by service
- `--account`, `-a`: Filter by account
- `--search`, `-q`: Search term (matches service/account)
- `--format`, `-f`: Output format [table, json, csv] (default: table)
- `--shared-only`: Show only shared passwords
- `--personal-only`: Show only personal passwords
- `--show-passwords`: Include passwords in output (use carefully!)

#### 3. Add Command
```bash
# Interactive mode (prompts for password)
applpass add --service api.openai.com --account bot@example.com

# With password from stdin
echo "secret123" | applpass add --service api.openai.com --account bot@example.com --stdin

# Generate random password
applpass add --service api.openai.com --account bot@example.com --generate

# Add with label
applpass add --service api.openai.com --account bot@example.com --label "OpenAI API Key"
```

**Flags:**
- `--service`, `-s`: Service name (required)
- `--account`, `-a`: Account name (required)
- `--password`, `-p`: Password (not recommended, use stdin or interactive)
- `--stdin`: Read password from stdin
- `--generate`, `-g`: Generate random password
- `--length`: Password length when generating (default: 32)
- `--label`, `-l`: User-friendly label
- `--sync`: Enable iCloud sync (default: true)

#### 4. Update Command
```bash
# Update password (interactive)
applpass update --service github.com --account bot@example.com

# Update with new password from stdin
echo "newsecret" | applpass update --service github.com --account bot@example.com --stdin

# Generate new password
applpass update --service github.com --account bot@example.com --generate
```

**Flags:**
- Same as add command
- `--force`, `-f`: Skip confirmation prompt

#### 5. Delete Command
```bash
# Delete with confirmation
applpass delete --service github.com --account bot@example.com

# Delete without confirmation
applpass delete --service github.com --account bot@example.com --force

# Delete all matching a pattern
applpass delete --service github.com --all-accounts --force
```

**Flags:**
- `--service`, `-s`: Service name (required)
- `--account`, `-a`: Account name (required unless --all-accounts)
- `--force`, `-f`: Skip confirmation
- `--all-accounts`: Delete all accounts for service

#### 6. Generate Command
```bash
# Generate password and copy to clipboard
applpass generate

# Generate with specific length
applpass generate --length 64

# Generate with specific character sets
applpass generate --no-symbols --length 20

# Generate multiple
applpass generate --count 5
```

**Flags:**
- `--length`, `-l`: Password length (default: 32)
- `--count`, `-n`: Number of passwords to generate (default: 1)
- `--no-uppercase`: Exclude uppercase letters
- `--no-lowercase`: Exclude lowercase letters
- `--no-digits`: Exclude digits
- `--no-symbols`: Exclude symbols
- `--clipboard`, `-c`: Copy to clipboard
- `--pronounceable`: Generate pronounceable password

### Keychain Services Integration

#### Query Construction
```swift
class KeychainManager {
    func buildQuery(for item: KeychainQuery) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]
        
        if item.includeShared {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }
        
        if let service = item.service {
            query[kSecAttrServer as String] = service
        }
        
        if let account = item.account {
            query[kSecAttrAccount as String] = account
        }
        
        if item.limit == 1 {
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        } else {
            query[kSecMatchLimit as String] = kSecMatchLimitAll
        }
        
        return query
    }
}
```

#### Error Handling
```swift
enum KeychainError: Error, LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedPasswordData
    case unhandledError(status: OSStatus)
    case authorizationDenied
    case invalidParameter(String)
    
    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Password not found in keychain"
        case .duplicateItem:
            return "A password with these credentials already exists"
        case .unexpectedPasswordData:
            return "Unable to decode password data"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        case .authorizationDenied:
            return "Access to keychain was denied. Please allow access when prompted."
        case .invalidParameter(let msg):
            return "Invalid parameter: \(msg)"
        }
    }
}
```

### Output Formatting

#### Table Format
```
Service              Account              Label           Shared  Modified
-------------------- -------------------- --------------- ------- --------------------
github.com           bot@example.com      GitHub Token    Yes     2025-02-13 10:30:15
api.openai.com       bot@example.com      OpenAI API      No      2025-02-12 14:22:03
database.prod        admin                Prod DB         Yes     2025-02-10 09:15:42
```

#### JSON Format
```json
{
  "items": [
    {
      "service": "github.com",
      "account": "bot@example.com",
      "label": "GitHub Token",
      "isShared": true,
      "sharedGroupName": "Team Credentials",
      "creationDate": "2025-01-15T10:30:00Z",
      "modificationDate": "2025-02-13T10:30:15Z",
      "itemClass": "internetPassword"
    }
  ],
  "count": 1
}
```

#### Plain Value Output
```bash
# For piping to other commands
applpass get --service github.com --account bot@example.com --value-only
ghp_1234567890abcdefghijklmnopqrstuvwxyz
```

## Security Considerations

### Security Features
1. **No Credential Logging**
   - Passwords never written to log files
   - No debug output containing credentials
   - Clear error messages without exposing data

2. **Secure Memory Handling**
   - Use `SecureString` wrapper for in-memory passwords
   - Zero out password strings after use
   - Minimize password lifetime in memory

3. **Input Validation**
   - Validate all service/account parameters
   - Sanitize user input
   - Prevent injection attacks

4. **Clipboard Security**
   - Clear clipboard after configurable timeout
   - Warn user when copying to clipboard

5. **Permission Model**
   - Respect macOS keychain access controls
   - Graceful handling of authorization prompts
   - Clear error messages when access denied

### Security Best Practices for Users
1. Never use `--password` flag (credentials in shell history)
2. Use `--stdin` or interactive mode
3. Be cautious with `--show-passwords` in list command
4. Review keychain access prompts carefully
5. Use clipboard with timeout for sensitive operations

## Building and Distribution

### Package.swift
```swift
// swift-tools-version: 6.2.3
import PackageDescription

let package = Package(
    name: "applpass",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-format", from: "600.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "ApplPass",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("AccessLevelOnImport"),
            ]
        ),
        .testTarget(
            name: "ApplPassTests",
            dependencies: ["ApplPass"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

### .swift-format Configuration
Create a `.swift-format` file in the project root for consistent code styling:

```json
{
  "version": 1,
  "lineLength": 100,
  "indentation": {
    "spaces": 2
  },
  "maximumBlankLines": 1,
  "respectsExistingLineBreaks": true,
  "lineBreakBeforeControlFlowKeywords": false,
  "lineBreakBeforeEachArgument": false,
  "prioritizeKeepingFunctionOutputTogether": true,
  "indentConditionalCompilationBlocks": true,
  "lineBreakAroundMultilineExpressionChainComponents": false,
  "rules": {
    "AllPublicDeclarationsHaveDocumentation": false,
    "AlwaysUseLowerCamelCase": true,
    "AmbiguousTrailingClosureOverload": true,
    "BeginDocumentationCommentWithOneLineSummary": false,
    "DoNotUseSemicolons": true,
    "DontRepeatTypeInStaticProperties": true,
    "FileScopedDeclarationPrivacy": true,
    "FullyIndirectEnum": true,
    "GroupNumericLiterals": true,
    "IdentifiersMustBeASCII": true,
    "NeverForceUnwrap": false,
    "NeverUseForceTry": false,
    "NeverUseImplicitlyUnwrappedOptionals": false,
    "NoAccessLevelOnExtensionDeclaration": true,
    "NoBlockComments": true,
    "NoCasesWithOnlyFallthrough": true,
    "NoEmptyTrailingClosureParentheses": true,
    "NoLabelsInCasePatterns": true,
    "NoLeadingUnderscores": false,
    "NoParensAroundConditions": true,
    "NoVoidReturnOnFunctionSignature": true,
    "OneCasePerLine": true,
    "OneVariableDeclarationPerLine": true,
    "OnlyOneTrailingClosureArgument": true,
    "OrderedImports": true,
    "ReturnVoidInsteadOfEmptyTuple": true,
    "UseEarlyExits": true,
    "UseLetInEveryBoundCaseVariable": true,
    "UseShorthandTypeNames": true,
    "UseSingleLinePropertyGetter": true,
    "UseSynthesizedInitializer": true,
    "UseTripleSlashForDocumentationComments": true,
    "UseWhereClausesInForLoops": false,
    "ValidateDocumentationComments": false
  }
}
```

### Build Instructions
```bash
# Format code before building (run this before commits!)
swift format --in-place --recursive Sources/ Tests/

# Lint code for style violations
swift format lint --recursive Sources/ Tests/

# Development build
swift build

# Release build (optimized)
swift build -c release

# Run tests with Swift Testing
swift test

# Run tests with verbose output
swift test --verbose

# Run specific test
swift test --filter ApplPassTests.KeychainManagerTests

# Install to /usr/local/bin
cp .build/release/ApplPass /usr/local/bin/applpass
chmod +x /usr/local/bin/applpass

# Verify installation
applpass --version
```

### Development Workflow
```bash
# 1. Make changes to code
vim Sources/ApplPass/Commands/GetCommand.swift

# 2. Format code
swift format --in-place --recursive Sources/

# 3. Build
swift build

# 4. Run tests
swift test

# 5. Lint before committing
swift format lint --recursive Sources/ Tests/
```

### Optional Code Signing
```bash
# Sign the binary
codesign --force --sign "Apple Development: your@email.com" \
    .build/release/PasswordCLI

# Verify signature
codesign -dv .build/release/PasswordCLI
```

## Usage Examples

### Common Workflows

#### 1. Bot Retrieving API Keys
```bash
#!/bin/bash
# Script to deploy using stored credentials

# Get GitHub token
GITHUB_TOKEN=$(applpass get --service github.com \
    --account bot@example.com --value-only)

# Get AWS credentials
AWS_KEY=$(applpass get --service aws.amazon.com \
    --account bot@example.com --value-only)

# Use credentials in deployment
git clone https://${GITHUB_TOKEN}@github.com/org/repo.git
aws s3 sync ./build s3://bucket --access-key ${AWS_KEY}
```

#### 2. Adding New Credentials
```bash
# Interactive mode (most secure)
applpass add --service api.stripe.com --account production

# From environment variable
echo "${STRIPE_API_KEY}" | applpass add \
    --service api.stripe.com \
    --account production \
    --stdin \
    --label "Stripe Production API"

# Generate random password
applpass add --service internal.database \
    --account admin \
    --generate \
    --length 64
```

#### 3. Auditing Passwords
```bash
# List all passwords
applpass list --format table

# Find all GitHub-related credentials
applpass list --search github

# Export to JSON for processing
applpass list --format json > passwords-audit.json

# List only shared credentials
applpass list --shared-only
```

#### 4. Rotating Credentials
```bash
# Update with new generated password
applpass update --service api.openai.com \
    --account bot@example.com \
    --generate \
    --length 48

# Get the new password to update in the service
NEW_PASSWORD=$(applpass get --service api.openai.com \
    --account bot@example.com --value-only)

# Update the external service
curl -X POST https://api.openai.com/v1/keys/rotate \
    -H "Authorization: Bearer ${NEW_PASSWORD}"
```

#### 5. Integration with Other Tools
```bash
# Use with jq for JSON processing
applpass list --format json | jq '.items[] | select(.isShared == true)'

# Pipe to clipboard manager
applpass get --service github.com --account bot --value-only | pbcopy

# Use in Python script
import subprocess
password = subprocess.check_output([
    'applpass', 'get',
    '--service', 'api.openai.com',
    '--account', 'bot@example.com',
    '--value-only'
]).decode().strip()
```

## Testing Strategy

### Testing Framework: Swift Testing
All tests use the modern Swift Testing framework with `@Test` macros, not XCTest.

### Unit Tests with Swift Testing

#### Example: Password Generator Tests
```swift
import Testing
@testable import ApplPass

@Suite("Password Generator Tests")
struct PasswordGeneratorTests {
  
  @Test("Generate password with default length")
  func generateDefaultLength() {
    let password = PasswordGenerator.generate()
    #expect(password.count == 32)
  }
  
  @Test("Generate password with custom length", arguments: [16, 32, 64, 128])
  func generateCustomLength(length: Int) {
    let password = PasswordGenerator.generate(length: length)
    #expect(password.count == length)
  }
  
  @Test("Generated password contains required character sets")
  func passwordCharacterSets() {
    let password = PasswordGenerator.generate(length: 50)
    
    #expect(password.contains(where: { $0.isUppercase }))
    #expect(password.contains(where: { $0.isLowercase }))
    #expect(password.contains(where: { $0.isNumber }))
  }
  
  @Test("Exclude symbols when requested")
  func excludeSymbols() {
    let password = PasswordGenerator.generate(
      length: 100,
      includeSymbols: false
    )
    
    #expect(!password.contains(where: { "!@#$%^&*()".contains($0) }))
  }
}
```

#### Example: Keychain Manager Tests
```swift
import Testing
@testable import ApplPass

@Suite("Keychain Manager Tests")
struct KeychainManagerTests {
  
  @Test("Build query for internet password")
  func buildInternetPasswordQuery() {
    let query = KeychainQuery(
      service: "github.com",
      account: "test@example.com",
      itemClass: .internetPassword
    )
    
    let built = KeychainManager.buildQuery(for: query)
    
    #expect(built[kSecClass as String] as? String == kSecClassInternetPassword as String)
    #expect(built[kSecAttrServer as String] as? String == "github.com")
    #expect(built[kSecAttrAccount as String] as? String == "test@example.com")
  }
  
  @Test("Error handling for missing item")
  func missingItemError() throws {
    let manager = KeychainManager()
    let query = KeychainQuery(
      service: "nonexistent.service",
      account: "nobody@example.com"
    )
    
    #expect(throws: KeychainError.itemNotFound) {
      try manager.getPassword(for: query)
    }
  }
}
```

#### Example: Output Formatter Tests
```swift
import Testing
@testable import ApplPass

@Suite("Output Formatter Tests")
struct OutputFormatterTests {
  
  @Test("Format single item as JSON")
  func formatSingleItemJSON() throws {
    let item = KeychainItem(
      service: "github.com",
      account: "bot@example.com",
      password: "secret123",
      label: "GitHub Token",
      creationDate: Date(),
      modificationDate: Date(),
      isShared: true,
      sharedGroupName: "Team",
      itemClass: .internetPassword
    )
    
    let json = try OutputFormatter.format([item], style: .json)
    
    #expect(json.contains("github.com"))
    #expect(json.contains("bot@example.com"))
    #expect(!json.contains("secret123")) // Password excluded by default
  }
  
  @Test("Format multiple items as table")
  func formatMultipleItemsTable() {
    let items = [
      KeychainItem(
        service: "github.com",
        account: "bot@example.com",
        password: "secret1",
        label: nil,
        creationDate: nil,
        modificationDate: nil,
        isShared: true,
        sharedGroupName: "Team",
        itemClass: .internetPassword
      ),
      KeychainItem(
        service: "api.openai.com",
        account: "bot@example.com",
        password: "secret2",
        label: "OpenAI",
        creationDate: nil,
        modificationDate: nil,
        isShared: false,
        sharedGroupName: nil,
        itemClass: .internetPassword
      ),
    ]
    
    let table = OutputFormatter.format(items, style: .table)
    
    #expect(table.contains("github.com"))
    #expect(table.contains("api.openai.com"))
    #expect(table.contains("Yes")) // Shared status
    #expect(table.contains("No"))  // Not shared status
  }
}
```

### Integration Tests
Integration tests verify end-to-end functionality:

```swift
import Testing
@testable import ApplPass

@Suite("Integration Tests", .serialized) // Run serially to avoid keychain conflicts
struct IntegrationTests {
  
  @Test("Add, retrieve, and delete password")
  func fullPasswordLifecycle() throws {
    let manager = KeychainManager()
    
    // Add
    try manager.addPassword(
      service: "test.integration.com",
      account: "test@example.com",
      password: "testpass123",
      label: "Integration Test"
    )
    
    // Retrieve
    let query = KeychainQuery(
      service: "test.integration.com",
      account: "test@example.com"
    )
    let item = try manager.getPassword(for: query)
    #expect(item.password == "testpass123")
    #expect(item.isShared == false)
    
    // Delete
    try manager.deletePassword(for: query)
    
    // Verify deleted
    #expect(throws: KeychainError.itemNotFound) {
      try manager.getPassword(for: query)
    }
  }
}
```

### Test Coverage Goals
- Unit test coverage: > 80%
- All public APIs tested
- Error paths tested
- Edge cases covered

### Running Tests
```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific suite
swift test --filter PasswordGeneratorTests

# Run specific test
swift test --filter PasswordGeneratorTests.generateDefaultLength

# Run tests in parallel (default)
swift test --parallel

# Run tests serially (for debugging)
swift test --no-parallel
```

### Manual Testing Checklist
- [ ] Add password interactively
- [ ] Retrieve password
- [ ] Update existing password
- [ ] Delete password
- [ ] List all passwords
- [ ] Access shared password
- [ ] Generate random password
- [ ] Export to JSON
- [ ] Copy to clipboard
- [ ] Error handling (wrong credentials, denied access)
- [ ] Code signing verification
- [ ] Keychain access prompts

## Swift 6 Code Quality & Best Practices

### Concurrency
- All types crossing isolation boundaries conform to `Sendable`
- Use structured concurrency with `async/await`
- Enable strict concurrency checking
- Avoid `@unchecked Sendable` unless absolutely necessary

```swift
// Good: Sendable value type
struct KeychainItem: Sendable {
  let service: String
  let password: String
}

// Good: Actor for mutable state
actor KeychainCache {
  private var cache: [String: KeychainItem] = [:]
  
  func get(_ key: String) -> KeychainItem? {
    cache[key]
  }
  
  func set(_ key: String, _ item: KeychainItem) {
    cache[key] = item
  }
}
```

### Error Handling
- Use typed errors (conform to `Error` protocol)
- Provide helpful error messages
- Use `Result` type for operations that may fail
- Avoid force unwrapping (`!`) in production code

```swift
enum KeychainError: Error, LocalizedError, Sendable {
  case itemNotFound
  case duplicateItem
  case authorizationDenied
  case invalidParameter(String)
  
  var errorDescription: String? {
    switch self {
    case .itemNotFound:
      "Password not found in keychain"
    case .duplicateItem:
      "A password with these credentials already exists"
    case .authorizationDenied:
      "Access denied. Please allow access when prompted."
    case .invalidParameter(let msg):
      "Invalid parameter: \(msg)"
    }
  }
}
```

### Value Types Over Reference Types
- Prefer `struct` over `class` for data models
- Use `enum` for state machines and options
- Avoid unnecessary reference semantics

### Protocol-Oriented Design
```swift
protocol PasswordProvider {
  func getPassword(for query: KeychainQuery) throws -> KeychainItem
}

protocol OutputFormatting {
  func format(_ items: [KeychainItem]) -> String
}

// Extensions for default implementations
extension OutputFormatting {
  func formatCompact(_ items: [KeychainItem]) -> String {
    items.map { "\($0.service): \($0.account)" }.joined(separator: "\n")
  }
}
```

### Access Control
- Use `private` by default
- Use `fileprivate` only when necessary
- Make public API minimal and explicit
- Document all public declarations

### Code Style Enforcement
All code must pass `swift-format lint` before committing:

```bash
# Auto-format code
swift format --in-place --recursive Sources/ Tests/

# Check for violations
swift format lint --recursive Sources/ Tests/

# CI will fail if linting fails
```

### Documentation
- Use triple-slash (`///`) comments for public APIs
- Include parameter descriptions
- Provide usage examples for complex functions

```swift
/// Generates a cryptographically secure random password.
///
/// - Parameters:
///   - length: The desired password length (default: 32)
///   - includeSymbols: Whether to include special characters (default: true)
/// - Returns: A randomly generated password string
/// - Throws: `PasswordGeneratorError` if length is invalid
///
/// Example:
/// ```swift
/// let password = try PasswordGenerator.generate(length: 64)
/// print(password) // "aB3$xY9..."
/// ```
func generate(
  length: Int = 32,
  includeSymbols: Bool = true
) throws -> String
```

## Continuous Integration

### GitHub Actions Workflow
Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  format:
    name: Check Code Formatting
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      
      - name: Check Swift version
        run: swift --version
      
      - name: Check formatting
        run: |
          swift format lint --recursive Sources/ Tests/
          if [ $? -ne 0 ]; then
            echo "❌ Code formatting issues found. Run 'swift format --in-place --recursive Sources/ Tests/'"
            exit 1
          fi

  test:
    name: Run Tests
    runs-on: macos-14
    needs: format
    steps:
      - uses: actions/checkout@v4
      
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.2.app
      
      - name: Check Swift version
        run: swift --version
      
      - name: Resolve dependencies
        run: swift package resolve
      
      - name: Build
        run: swift build -c release
      
      - name: Run tests
        run: swift test --verbose
  
  build:
    name: Build Release Binary
    runs-on: macos-14
    needs: test
    steps:
      - uses: actions/checkout@v4
      
      - name: Build release binary
        run: |
          swift build -c release
          cp .build/release/ApplPass ./applpass
      
      - name: Upload binary
        uses: actions/upload-artifact@v4
        with:
          name: applpass-macos
          path: applpass
          retention-days: 7
```

### Pre-commit Hook
Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash

echo "Running swift-format..."
swift format --in-place --recursive Sources/ Tests/

# Check if there are any unstaged changes after formatting
if ! git diff --exit-code --quiet; then
  echo "❌ Code was reformatted. Please review changes and commit again."
  git diff --name-only
  exit 1
fi

echo "✅ Code formatting passed"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Performance Considerations

### Optional: Benchmark Package
For performance-critical operations, add benchmarks:

```swift
// Benchmarks/ApplPassBenchmarks/KeychainBenchmarks.swift
import Benchmark
@testable import ApplPass

let benchmarks = {
  Benchmark("Keychain query construction") { benchmark in
    let query = KeychainQuery(
      service: "test.service",
      account: "test@example.com"
    )
    
    for _ in benchmark.scaledIterations {
      blackHole(KeychainManager.buildQuery(for: query))
    }
  }
  
  Benchmark("Password generation", 
           configuration: .init(metrics: [.wallClock, .cpuTotal])) { benchmark in
    for _ in benchmark.scaledIterations {
      blackHole(try! PasswordGenerator.generate(length: 32))
    }
  }
}
```

Run benchmarks:
```bash
swift package benchmark
```

## Open Source Considerations

### License
Recommended: MIT License (permissive, allows commercial use)

### README.md Structure
1. Overview and features
2. Requirements 
   - macOS 14.0+ (Sonoma or later)
   - Swift 6.2.3+
   - Xcode 16.0+ (for development)
3. Installation instructions
4. Quick start guide
5. Command reference
6. Code formatting and contribution guidelines
7. Security best practices
8. Troubleshooting guide
9. License
6. Security best practices
7. Contributing guidelines
8. License

### Documentation
- Comprehensive command reference
- Security guide
- Architecture overview
- API documentation (if exposing as library)
- Troubleshooting guide

### Contributing
- Code of conduct
- Contribution guidelines
- Issue templates
- Pull request template

## Future Enhancements

### Phase 2 Features
- Support for passkeys (view only)
- Export to 1Password/Bitwarden format
- Import from other password managers
- Password strength analysis
- Breach detection integration
- Shell completion scripts (bash, zsh, fish)

### Phase 3 Features
- GUI wrapper (SwiftUI)
- Browser extension integration
- SSH key management
- Certificate management
- Team password policies
- Audit logging

## Deployment Considerations

### For Bot Account
1. Clone repository on bot's MacBook Air
2. Build from source: `swift build -c release`
3. Copy binary to convenient location: `/usr/local/bin/`
4. Ensure bot's Apple ID is logged in
5. Add bot to relevant shared password groups
6. Test access to shared credentials
7. Set up automated scripts using the CLI

### For Open Source Users
1. Provide clear installation instructions
2. Document Apple ID / Keychain requirements
3. Include troubleshooting for common issues
4. Provide examples for common use cases
5. Create GitHub releases with release notes

## Performance Targets

- Single password retrieval: < 100ms
- List all passwords (100 items): < 500ms
- Generate password: < 10ms
- Add password: < 200ms
- Startup time: < 50ms

## Compatibility

### Supported Platforms
- macOS 14.0 (Sonoma) or later
- Apple Silicon and Intel Macs

### Requirements
- Swift 6.2.3+
- Xcode 16.0+ (for development)
- Security.framework (system framework)

### Dependencies
- Swift Argument Parser 1.5+ (CLI parsing)
- swift-format 600.0.0+ (code formatting, dev dependency)
- Swift Testing (built into Swift 6, testing only)

### Not Supported
- iOS/iPadOS (CLI not applicable)
- Windows/Linux (Keychain Services is macOS-only)
- macOS < 14.0 (Passwords app features not available)

## Success Metrics

### For Development
- [ ] All commands implemented and tested
- [ ] Code coverage > 80%
- [ ] Zero security vulnerabilities
- [ ] Documentation complete
- [ ] Build time < 30 seconds

### For Adoption (Open Source)
- GitHub stars
- Issue response time < 48 hours
- Active contributors
- User testimonials

## Swift 6 Language Features in Use

This project leverages modern Swift 6 features for improved safety and expressiveness:

### Strict Concurrency Checking
- All data types crossing isolation boundaries are `Sendable`
- Compiler enforces data-race safety
- `@MainActor` for UI-related code (if applicable)

### Typed Throws (SE-0413)
```swift
enum KeychainError: Error {
  case itemNotFound
  case accessDenied
}

func getPassword() throws(KeychainError) -> String {
  // Can only throw KeychainError
}
```

### Noncopyable Types (where applicable)
For sensitive data that shouldn't be copied:
```swift
struct SecurePassword: ~Copyable {
  private let value: String
  
  consuming func use() {
    // Use password
  }
}
```

### Parameter Packs (for variadic generics)
```swift
func formatOutput<each T: Formattable>(
  _ values: repeat each T
) -> String {
  // Format multiple types
}
```

### Modern String Processing
- Use Swift's native String APIs
- Prefer `Character` over `UnicodeScalar` where appropriate
- Use `String.Index` properly

### Swift Argument Parser Features
- `@Option`, `@Flag`, `@Argument` property wrappers
- Automatic help generation
- Subcommand support with `ParsableCommand`

## Appendix

### Keychain Item Classes Reference

| Class | kSec Constant | Use Case |
|-------|---------------|----------|
| Internet Password | kSecClassInternetPassword | Website passwords, API keys |
| Generic Password | kSecClassGenericPassword | App passwords, tokens |
| Certificate | kSecClassCertificate | X.509 certificates |
| Key | kSecClassKey | Cryptographic keys |
| Identity | kSecClassIdentity | Certificate + private key |

### Common OSStatus Codes

| Code | Constant | Meaning |
|------|----------|---------|
| 0 | errSecSuccess | Operation successful |
| -25300 | errSecItemNotFound | Item not found |
| -25299 | errSecDuplicateItem | Item already exists |
| -128 | errSecUserCanceled | User canceled operation |
| -25293 | errSecAuthFailed | Authentication failed |

### Environment Variables

```bash
# Disable colored output
export PASSWORD_CLI_NO_COLOR=1

# Default output format
export PASSWORD_CLI_FORMAT=json

# Clipboard timeout (seconds)
export PASSWORD_CLI_CLIPBOARD_TIMEOUT=30
```

---

## Document Version
- **Version**: 2.0
- **Date**: February 13, 2026
- **Author**: Bot Owner
- **Status**: Design Complete - Ready for Implementation
- **Target**: Swift 6.2.3, macOS 14.0+
- **Key Updates from v1.0**:
  - CLI renamed to `applpass`
  - Updated to Swift 6.2.3 with strict concurrency
  - Migrated to Swift Testing framework
  - Added swift-format integration
  - Added comprehensive CI/CD workflows
  - Added code quality and best practices sections
  - Updated all examples and commands
