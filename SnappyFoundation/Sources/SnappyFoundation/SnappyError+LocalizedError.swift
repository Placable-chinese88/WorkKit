import Foundation

extension SnappyError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .invalidInput:
      return "The input data is invalid or corrupted."
    case .bufferTooSmall:
      return "The provided buffer is too small for the operation."
    case .memoryAllocationFailed(let size):
      return "Memory allocation failed for size: \(size) bytes."
    case .compressionFailed:
      return "Snappy failed to compress the buffer."
    case .decompressionFailed:
      return "Snappy failed to decompress the buffer."
    case .invalidCompressedData:
      return "The data does not appear to be Snappy-compressed."
    }
  }
}
