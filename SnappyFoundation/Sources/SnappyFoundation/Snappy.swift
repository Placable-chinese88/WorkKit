import Foundation
import snappyc

// MARK: - Snappy Compression

/// A Swift wrapper for the Snappy compression library.
///
/// Snappy is a compression library designed for speed rather than maximum compression.
/// It provides fast compression and decompression operations suitable for scenarios
/// where performance is more important than compression ratio.
///
/// ## Topics
///
/// ### Compressing and Decompressing Data
///
/// - ``compress(_:)``
/// - ``decompress(_:)``
///
/// ### Validating Compressed Data
///
/// - ``isSnappyCompressed(_:)``
///
/// ### Size Calculations
///
/// - ``maxCompressedLength(for:)``
/// - ``uncompressedLength(of:)``
public enum Snappy {

  // MARK: - Compression

  /// Compresses the provided data using Snappy compression.
  ///
  /// This method takes raw data and returns a compressed version using the Snappy
  /// compression algorithm. The compressed data can later be decompressed using
  /// the ``decompress(_:)`` method.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let originalData = "Hello, World!".data(using: .utf8)!
  /// let compressed = try Snappy.compress(originalData)
  /// let decompressed = try Snappy.decompress(compressed)
  /// ```
  ///
  /// - Parameter data: The data to compress.
  /// - Returns: The compressed data.
  /// - Throws: ``SnappyError/memoryAllocationFailed(size:)`` if buffer allocation fails,
  ///           or ``SnappyError/compressionFailed`` if the compression operation fails.
  ///
  /// - Complexity: O(n) where n is the size of the input data.
  public static func compress(_ data: Data) throws -> Data {
    let maxCompressedLength = snappy_max_compressed_length(data.count)

    guard maxCompressedLength > 0 else {
      throw SnappyError.memoryAllocationFailed(size: maxCompressedLength)
    }

    guard let buffer = malloc(maxCompressedLength) else {
      throw SnappyError.memoryAllocationFailed(size: maxCompressedLength)
    }
    defer { free(buffer) }

    var compressedLength = maxCompressedLength

    let status = data.withUnsafeBytes { rawBufferPointer in
      snappy_compress(
        rawBufferPointer.bindMemory(to: CChar.self).baseAddress,
        data.count,
        buffer.assumingMemoryBound(to: CChar.self),
        &compressedLength
      )
    }

    guard status == SNAPPY_OK else {
      throw SnappyError.compressionFailed
    }

    return Data(bytes: buffer, count: compressedLength)
  }

  // MARK: - Decompression

  /// Decompresses Snappy-compressed data.
  ///
  /// This method takes data that was previously compressed using Snappy compression
  /// and returns the original uncompressed data.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let compressed = try Snappy.compress(originalData)
  /// let decompressed = try Snappy.decompress(compressed)
  /// assert(decompressed == originalData)
  /// ```
  ///
  /// - Parameter data: The compressed data to decompress.
  /// - Returns: The decompressed data.
  /// - Throws: ``SnappyError/invalidCompressedData`` if the data is not valid Snappy-compressed data,
  ///           ``SnappyError/memoryAllocationFailed(size:)`` if buffer allocation fails,
  ///           or ``SnappyError/decompressionFailed`` if the decompression operation fails.
  ///
  /// - Complexity: O(n) where n is the size of the uncompressed data.
  ///
  /// - SeeAlso: ``isSnappyCompressed(_:)`` to validate data before decompression.
  public static func decompress(_ data: Data) throws -> Data {
    guard isSnappyCompressed(data) else {
      throw SnappyError.invalidCompressedData
    }

    var uncompressedLength = 0

    var status = data.withUnsafeBytes { rawBufferPointer in
      snappy_uncompressed_length(
        rawBufferPointer.bindMemory(to: CChar.self).baseAddress,
        data.count,
        &uncompressedLength
      )
    }

    guard status == SNAPPY_OK else {
      throw SnappyError.invalidCompressedData
    }

    guard let buffer = malloc(uncompressedLength) else {
      throw SnappyError.memoryAllocationFailed(size: uncompressedLength)
    }
    defer { free(buffer) }

    status = data.withUnsafeBytes { rawBufferPointer in
      snappy_uncompress(
        rawBufferPointer.bindMemory(to: CChar.self).baseAddress,
        data.count,
        buffer.assumingMemoryBound(to: CChar.self),
        &uncompressedLength
      )
    }

    guard status == SNAPPY_OK else {
      throw SnappyError.decompressionFailed
    }

    return Data(bytes: buffer, count: uncompressedLength)
  }

  // MARK: - Validation

  /// Validates whether the given data is Snappy-compressed.
  ///
  /// This method performs a fast check to determine if the data appears to be
  /// valid Snappy-compressed data. It does not perform full decompression.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let data = try Snappy.compress(originalData)
  /// if Snappy.isSnappyCompressed(data) {
  ///     let decompressed = try Snappy.decompress(data)
  /// }
  /// ```
  ///
  /// - Parameter data: The data to validate.
  /// - Returns: `true` if the data appears to be valid Snappy-compressed data,
  ///            `false` otherwise.
  ///
  /// - Complexity: O(n) where n is the size of the data, but typically faster
  ///              than full decompression.
  public static func isSnappyCompressed(_ data: Data) -> Bool {
    let status = data.withUnsafeBytes { rawBufferPointer in
      snappy_validate_compressed_buffer(
        rawBufferPointer.bindMemory(to: CChar.self).baseAddress,
        data.count
      )
    }
    return status == SNAPPY_OK
  }

  // MARK: - Size Calculation

  /// Returns the maximum possible compressed size for input of the given length.
  ///
  /// This method calculates the maximum number of bytes that could result from
  /// compressing data of the specified length. The actual compressed size will
  /// typically be smaller.
  ///
  /// Use this method to pre-allocate buffers for compression operations when
  /// working directly with the underlying C library.
  ///
  /// - Parameter sourceLength: The length of the uncompressed data.
  /// - Returns: The maximum possible compressed size in bytes.
  ///
  /// - Complexity: O(1)
  public static func maxCompressedLength(for sourceLength: Int) -> Int {
    snappy_max_compressed_length(sourceLength)
  }

  /// Returns the uncompressed length of Snappy-compressed data.
  ///
  /// This method extracts the uncompressed size from Snappy-compressed data
  /// without performing full decompression.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let compressed = try Snappy.compress(originalData)
  /// let expectedLength = try Snappy.uncompressedLength(of: compressed)
  /// print("Decompressed data will be \(expectedLength) bytes")
  /// ```
  ///
  /// - Parameter compressedData: The Snappy-compressed data.
  /// - Returns: The length of the data when uncompressed.
  /// - Throws: ``SnappyError/invalidCompressedData`` if the data is not valid
  ///           Snappy-compressed data or if parsing fails.
  ///
  /// - Complexity: O(1)
  public static func uncompressedLength(of compressedData: Data) throws -> Int {
    var length = 0

    let status = compressedData.withUnsafeBytes { rawBufferPointer in
      snappy_uncompressed_length(
        rawBufferPointer.bindMemory(to: CChar.self).baseAddress,
        compressedData.count,
        &length
      )
    }

    guard status == SNAPPY_OK else {
      throw SnappyError.invalidCompressedData
    }

    return length
  }
}
