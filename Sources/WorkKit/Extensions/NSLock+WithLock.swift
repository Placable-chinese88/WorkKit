import Foundation

extension NSLock {
  /// Executes a closure while holding the lock.
  ///
  /// - Parameter body: The closure to execute.
  /// - Returns: The value returned by the closure.
  /// - Throws: Any error thrown by the closure.
  @inlinable
  package func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
    lock()
    defer { unlock() }
    return try body()
  }
}
