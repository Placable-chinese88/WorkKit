import Foundation
import Testing

@testable import SnappyFoundation

// MARK: - Compression Tests

@Test("Compress empty data")
func compressEmptyData() throws {
  let emptyData = Data()
  let compressed = try Snappy.compress(emptyData)
  #expect(compressed.count > 0)
}

@Test("Compress small string")
func compressSmallString() throws {
  let text = "Hello, World!"
  let data = text.data(using: .utf8)!
  let compressed = try Snappy.compress(data)
  #expect(compressed.count > 0)
  #expect(compressed.count <= data.count + 100)  // Reasonable overhead
}

@Test("Compress large text")
func compressLargeText() throws {
  let text = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 1000)
  let data = text.data(using: .utf8)!
  let compressed = try Snappy.compress(data)
  #expect(compressed.count > 0)
  #expect(compressed.count < data.count)  // Should achieve compression
}

@Test("Compress binary data")
func compressBinaryData() throws {
  let binaryData = Data([0x00, 0xFF, 0xAA, 0x55, 0x12, 0x34, 0x56, 0x78])
  let compressed = try Snappy.compress(binaryData)
  #expect(compressed.count > 0)
}

@Test("Compress highly compressible data")
func compressHighlyCompressibleData() throws {
  // Data with lots of repetition should compress well
  let data = Data(repeating: 0x42, count: 10000)
  let compressed = try Snappy.compress(data)
  #expect(compressed.count > 0)
  #expect(compressed.count < data.count / 10)  // Should compress significantly
}

@Test("Compress random data")
func compressRandomData() throws {
  // Random data typically doesn't compress well
  var randomData = Data(count: 1000)
  randomData.withUnsafeMutableBytes { buffer in
    for i in 0..<buffer.count {
      buffer[i] = UInt8.random(in: 0...255)
    }
  }
  let compressed = try Snappy.compress(randomData)
  #expect(compressed.count > 0)
  // Random data may expand slightly due to compression overhead
}

// MARK: - Decompression Tests

@Test("Decompress valid compressed data")
func decompressValidData() throws {
  let original = "Test data for decompression"
  let data = original.data(using: .utf8)!
  let compressed = try Snappy.compress(data)
  let decompressed = try Snappy.decompress(compressed)
  #expect(decompressed == data)
}

@Test("Decompress empty compressed data")
func decompressEmpty() throws {
  let emptyData = Data()
  let compressed = try Snappy.compress(emptyData)
  let decompressed = try Snappy.decompress(compressed)
  #expect(decompressed == emptyData)
}

@Test("Decompress fails with invalid data")
func decompressInvalidData() throws {
  let invalidData = Data([0xFF, 0xFF, 0xFF, 0xFF])
  #expect(throws: SnappyError.self) {
    try Snappy.decompress(invalidData)
  }
}

@Test("Decompress fails with corrupted data")
func decompressCorruptedData() throws {
  let original = "Test data"
  let data = original.data(using: .utf8)!
  var compressed = try Snappy.compress(data)

  // Corrupt the first byte (format marker) - this should always fail validation
  if compressed.count > 0 {
    compressed[0] = compressed[0] ^ 0xFF
  }

  #expect(throws: SnappyError.self) {
    try Snappy.decompress(compressed)
  }
}

@Test("Decompress fails with truncated data")
func decompressTruncatedData() throws {
  let original = "Test data for truncation"
  let data = original.data(using: .utf8)!
  let compressed = try Snappy.compress(data)

  // Truncate the compressed data
  let truncated = compressed.prefix(compressed.count / 2)

  #expect(throws: SnappyError.self) {
    try Snappy.decompress(truncated)
  }
}

// MARK: - Validation Tests

@Test("Validate compressed data returns true")
func validateCompressedData() throws {
  let text = "Validation test"
  let data = text.data(using: .utf8)!
  let compressed = try Snappy.compress(data)
  #expect(Snappy.isSnappyCompressed(compressed))
}

@Test("Validate uncompressed data returns false")
func validateUncompressedData() {
  let text = "Not compressed"
  let data = text.data(using: .utf8)!
  #expect(!Snappy.isSnappyCompressed(data))
}

@Test("Validate empty data returns false")
func validateEmptyData() {
  let emptyData = Data()
  #expect(!Snappy.isSnappyCompressed(emptyData))
}

@Test("Validate random data returns false")
func validateRandomData() {
  var randomData = Data(count: 100)
  randomData.withUnsafeMutableBytes { buffer in
    for i in 0..<buffer.count {
      buffer[i] = UInt8.random(in: 0...255)
    }
  }
  #expect(!Snappy.isSnappyCompressed(randomData))
}

@Test("Validate corrupted compressed data returns false")
func validateCorruptedData() throws {
  let original = "Test data"
  let data = original.data(using: .utf8)!
  var compressed = try Snappy.compress(data)

  // Corrupt the first byte (format marker)
  if compressed.count > 0 {
    compressed[0] = compressed[0] ^ 0xFF
  }

  #expect(!Snappy.isSnappyCompressed(compressed))
}

// MARK: - Size Calculation Tests

@Test("Max compressed length is reasonable")
func maxCompressedLength() {
  let sourceLength = 1000
  let maxLength = Snappy.maxCompressedLength(for: sourceLength)
  #expect(maxLength >= sourceLength)
  #expect(maxLength < sourceLength * 2)  // Shouldn't be more than 2x
}

@Test("Max compressed length for zero")
func maxCompressedLengthZero() {
  let maxLength = Snappy.maxCompressedLength(for: 0)
  #expect(maxLength >= 0)
}

@Test("Max compressed length for large input")
func maxCompressedLengthLarge() {
  let sourceLength = 1_000_000
  let maxLength = Snappy.maxCompressedLength(for: sourceLength)
  #expect(maxLength >= sourceLength)
}

@Test("Uncompressed length matches original")
func uncompressedLength() throws {
  let original = "Test data for length calculation"
  let data = original.data(using: .utf8)!
  let compressed = try Snappy.compress(data)
  let length = try Snappy.uncompressedLength(of: compressed)
  #expect(length == data.count)
}

@Test("Uncompressed length for empty data")
func uncompressedLengthEmpty() throws {
  let emptyData = Data()
  let compressed = try Snappy.compress(emptyData)
  let length = try Snappy.uncompressedLength(of: compressed)
  #expect(length == 0)
}

@Test("Uncompressed length fails for invalid data")
func uncompressedLengthInvalid() {
  let invalidData = Data([0xFF, 0xFF, 0xFF, 0xFF])
  #expect(throws: SnappyError.self) {
    try Snappy.uncompressedLength(of: invalidData)
  }
}

// MARK: - Integration Tests

@Test("Round-trip compression and decompression")
func roundTripCompression() throws {
  let exampleString =
    "He felt no need to assign a spot to an alternative faction, which shows his priority is projecting dominance over magnanimity, when he is facing international pushback, said Wen-ti Sung, a lecturer at the Australian National University."
  let exampleData = exampleString.data(using: .utf8)!

  let compressedData = try Snappy.compress(exampleData)
  #expect(compressedData.count > 0)
  #expect(Snappy.isSnappyCompressed(compressedData))

  let decompressedData = try Snappy.decompress(compressedData)
  let decompressedString = String(data: decompressedData, encoding: .utf8)!
  #expect(decompressedString == exampleString)
}

@Test("Multiple round-trips preserve data")
func multipleRoundTrips() throws {
  let original = "Test data for multiple compressions"
  var data = original.data(using: .utf8)!

  // Compress and decompress multiple times
  for _ in 0..<5 {
    let compressed = try Snappy.compress(data)
    data = try Snappy.decompress(compressed)
  }

  let final = String(data: data, encoding: .utf8)!
  #expect(final == original)
}

@Test("Compress different data types")
func compressDifferentTypes() throws {
  // String data
  let stringData = "Test string".data(using: .utf8)!
  let compressedString = try Snappy.compress(stringData)
  let decompressedString = try Snappy.decompress(compressedString)
  #expect(decompressedString == stringData)

  // Binary data
  let binaryData = Data([0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD, 0xFC])
  let compressedBinary = try Snappy.compress(binaryData)
  let decompressedBinary = try Snappy.decompress(compressedBinary)
  #expect(decompressedBinary == binaryData)

  // Large data
  let largeData = Data(repeating: 0x42, count: 100000)
  let compressedLarge = try Snappy.compress(largeData)
  let decompressedLarge = try Snappy.decompress(compressedLarge)
  #expect(decompressedLarge == largeData)
}

@Test("Compression reduces size for repetitive data")
func compressionReducesSize() throws {
  let repetitive = String(repeating: "abcdefgh", count: 1000)
  let data = repetitive.data(using: .utf8)!
  let compressed = try Snappy.compress(data)

  #expect(compressed.count < data.count)

  // Verify decompression works
  let decompressed = try Snappy.decompress(compressed)
  #expect(decompressed == data)
}

@Test("Validate then decompress workflow")
func validateThenDecompress() throws {
  let original = "Workflow test"
  let data = original.data(using: .utf8)!
  let compressed = try Snappy.compress(data)

  // Validate before decompressing
  #expect(Snappy.isSnappyCompressed(compressed))

  // Get length before decompressing
  let expectedLength = try Snappy.uncompressedLength(of: compressed)
  #expect(expectedLength == data.count)

  // Decompress
  let decompressed = try Snappy.decompress(compressed)
  #expect(decompressed.count == expectedLength)
  #expect(decompressed == data)
}

@Test("Handle Unicode strings correctly")
func handleUnicodeStrings() throws {
  let unicodeStrings = [
    "Hello, 世界! 🌍",
    "Привет мир",
    "مرحبا بالعالم",
    "🎉🎊🎈🎁🎀",
    "Ñoño Français Deutsch",
  ]

  for original in unicodeStrings {
    let data = original.data(using: .utf8)!
    let compressed = try Snappy.compress(data)
    let decompressed = try Snappy.decompress(compressed)
    let result = String(data: decompressed, encoding: .utf8)!
    #expect(result == original, "Failed for: \(original)")
  }
}

@Test("Stress test with large data")
func stressTestLargeData() throws {
  // 10 MB of data
  let largeData = Data(repeating: 0x42, count: 10_000_000)
  let compressed = try Snappy.compress(largeData)
  #expect(compressed.count > 0)

  let decompressed = try Snappy.decompress(compressed)
  #expect(decompressed == largeData)
}

@Test("Compression is deterministic")
func compressionIsDeterministic() throws {
  let data = "Deterministic test".data(using: .utf8)!

  let compressed1 = try Snappy.compress(data)
  let compressed2 = try Snappy.compress(data)

  #expect(compressed1 == compressed2)
}

@Test("Empty data validation workflow")
func emptyDataWorkflow() throws {
  let emptyData = Data()

  // Compress
  let compressed = try Snappy.compress(emptyData)
  #expect(compressed.count > 0)

  // Validate
  #expect(Snappy.isSnappyCompressed(compressed))

  // Check length
  let length = try Snappy.uncompressedLength(of: compressed)
  #expect(length == 0)

  // Decompress
  let decompressed = try Snappy.decompress(compressed)
  #expect(decompressed.count == 0)
}

// MARK: - Error Handling Tests

@Test("Error descriptions are meaningful")
func errorDescriptions() {
  let errors: [SnappyError] = [
    .invalidInput,
    .bufferTooSmall,
    .memoryAllocationFailed(size: 1024),
    .compressionFailed,
    .decompressionFailed,
    .invalidCompressedData,
  ]

  for error in errors {
    let description = error.errorDescription ?? ""
    #expect(!description.isEmpty, "Error should have description: \(error)")
  }
}

@Test("Error types are correct")
func errorTypes() {
  let invalidData = Data([0xFF, 0xFF, 0xFF, 0xFF])

  do {
    _ = try Snappy.decompress(invalidData)
    Issue.record("Should have thrown an error")
  } catch let error as SnappyError {
    switch error {
    case .invalidCompressedData:
      // Expected
      break
    default:
      Issue.record("Wrong error type: \(error)")
    }
  } catch {
    Issue.record("Wrong error type: \(error)")
  }
}
