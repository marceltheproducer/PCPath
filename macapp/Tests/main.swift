// Standalone entry point for the swiftc-based test runner.
// (Xcode builds use an XCTest target; this lets us run tests with no Xcode.)
import Foundation
exit(Int32(runPathConverterTests() == 0 ? 0 : 1))
