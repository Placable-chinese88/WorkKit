// MARK: - Snappy Errors

/// Errors that can occur during Snappy compression operations.
public enum SnappyError: Error {
  /// The input data is invalid or corrupted.
  case invalidInput

  /// The provided buffer is too small for the operation.
  case bufferTooSmall

  /// Memory allocation failed for the requested size.
  case memoryAllocationFailed(size: Int)

  /// Compression operation failed.
  case compressionFailed

  /// Decompression operation failed.
  case decompressionFailed

  /// The data does not appear to be Snappy-compressed.
  case invalidCompressedData
}
