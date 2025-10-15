import Foundation
import SwiftProtobuf

/// A stream for reading Protocol Buffer encoded data.
///
/// This class wraps data and provides methods to read various Protocol Buffer wire format types
/// including varints, fixed-width integers, and length-delimited data.
final class ProtobufInputStream {
  private let data: Data
  private var position: Int

  /// Creates a new input stream from the given data.
  /// - Parameter data: The data to read from
  init(data: Data) {
    self.data = data
    self.position = 0
  }

  /// Reads a varint from the stream.
  /// - Parameter value: A pointer to store the decoded varint value
  /// - Returns: `true` if the varint was successfully read, `false` otherwise
  @discardableResult
  func readVarint(_ value: inout UInt64) -> Bool {
    var result: UInt64 = 0
    var shift: UInt64 = 0

    while position < data.count {
      let byte = data[position]
      position += 1

      result |= UInt64(byte & 0x7F) << shift

      if byte & 0x80 == 0 {
        value = result
        return true
      }

      shift += 7
      if shift >= 64 {
        return false
      }
    }

    return false
  }

  /// Reads a 32-bit little-endian integer from the stream.
  /// - Parameter value: A pointer to store the decoded value
  /// - Returns: `true` if the value was successfully read, `false` otherwise
  @discardableResult
  func readUInt32(_ value: inout UInt32) -> Bool {
    guard position + 4 <= data.count else { return false }

    value =
      data.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: position, as: UInt32.self)
      }.littleEndian

    position += 4
    return true
  }

  /// Reads a 64-bit little-endian integer from the stream.
  /// - Parameter value: A pointer to store the decoded value
  /// - Returns: `true` if the value was successfully read, `false` otherwise
  @discardableResult
  func readUInt64(_ value: inout UInt64) -> Bool {
    guard position + 8 <= data.count else { return false }

    value =
      data.withUnsafeBytes { bytes in
        bytes.load(fromByteOffset: position, as: UInt64.self)
      }.littleEndian

    position += 8
    return true
  }

  /// Reads a fixed number of bytes from the stream.
  /// - Parameter length: The number of bytes to read
  /// - Returns: The data read, or `nil` if not enough bytes are available
  func readData(length: Int) -> Data? {
    guard position + length <= data.count else { return nil }

    let range = position..<(position + length)
    position += length
    return data.subdata(in: range)
  }

  /// Reads length-delimited data from the stream.
  ///
  /// First reads a varint indicating the length, then reads that many bytes.
  /// - Returns: The data read, or `nil` if reading failed
  func readLengthDelimitedData() -> Data? {
    var length: UInt64 = 0
    guard readVarint(&length) else { return nil }

    return readData(length: Int(length))
  }

  /// Returns whether the stream has reached the end of the data.
  var isAtEnd: Bool {
    position >= data.count
  }

  /// Returns the number of bytes remaining in the stream.
  var lengthRemaining: Int {
    max(0, data.count - position)
  }

  /// Returns the current position in the stream.
  var currentPosition: Int {
    position
  }

  /// Reads through the stream until a null tag (tag value of 0) is encountered.
  ///
  /// This is used to find the end of embedded Protocol Buffer descriptors in compiled binaries.
  /// - Returns: The number of bytes consumed, including the final null tag
  @discardableResult
  func readUntilNullTag() -> Int {
    let initialPosition = position

    while !isAtEnd {
      var tag: UInt64 = 0
      guard readVarint(&tag) else { break }

      if tag == 0 {
        // Found null tag
        return position - initialPosition
      }

      // Extract wire type from tag
      let wireType = tag & 0x7

      switch wireType {
      case 0:  // VARINT
        var value: UInt64 = 0
        guard readVarint(&value) else { return position - initialPosition }

      case 1:  // FIXED64
        var value: UInt64 = 0
        guard readUInt64(&value) else { return position - initialPosition }

      case 2:  // LENGTH_DELIMITED
        guard readLengthDelimitedData() != nil else { return position - initialPosition }

      case 3, 4:  // START_GROUP, END_GROUP (deprecated)
        break

      case 5:  // FIXED32
        var value: UInt32 = 0
        guard readUInt32(&value) else { return position - initialPosition }

      default:
        // Unrecognized wire type
        return position - initialPosition
      }
    }

    return position - initialPosition
  }

  /// Reads a varint from data at a specific offset.
  /// - Parameters:
  ///   - value: A pointer to store the decoded varint value
  ///   - data: The data to read from
  ///   - offset: The offset to start reading from
  ///   - bytesConsumed: Optional pointer to store the number of bytes consumed
  /// - Returns: `true` if the varint was successfully read, `false` otherwise
  static func readVarint(
    _ value: inout UInt64,
    from data: Data,
    offset: Int,
    bytesConsumed: inout Int
  ) -> Bool {
    let subdata = data.subdata(in: offset..<data.count)
    let stream = ProtobufInputStream(data: subdata)

    guard stream.readVarint(&value) else { return false }

    bytesConsumed = stream.currentPosition
    return true
  }
}
