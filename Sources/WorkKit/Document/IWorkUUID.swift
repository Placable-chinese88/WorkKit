import Foundation

/// Errors that can occur when initializing an IWorkUUID.
package enum IWorkUUIDError: Error {
  case unsupportedDictStructure
  case unsupportedInitType(String)
}

/// A wrapper around UUID that provides conversions to and from various
/// protobuf representations used in iWork documents.
package struct IWorkUUID {
  let uuid: UUID

  // MARK: - Initializers

  /// Creates a new random UUID.
  init() {
    self.uuid = UUID()
  }

  /// Creates an IWorkUUID wrapping an existing UUID.
  ///
  /// - Parameter uuid: The UUID to wrap.
  init(uuid: UUID) {
    self.uuid = uuid
  }

  /// Creates an IWorkUUID from a 128-bit integer.
  ///
  /// - Parameter int: A tuple of two UInt64 values representing the upper and lower
  ///   64 bits of the UUID.
  init(int: (upper: UInt64, lower: UInt64)) {
    var bytes: [UInt8] = []

    // Upper 64 bits (bytes 0-7)
    for i in stride(from: 56, through: 0, by: -8) {
      bytes.append(UInt8((int.upper >> i) & 0xFF))
    }

    // Lower 64 bits (bytes 8-15)
    for i in stride(from: 56, through: 0, by: -8) {
      bytes.append(UInt8((int.lower >> i) & 0xFF))
    }

    self.uuid = UUID(
      uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
      ))
  }

  /// Creates an IWorkUUID from a hex string.
  ///
  /// - Parameter hex: A hexadecimal string representation of the UUID.
  /// - Throws: `IWorkUUIDError.unsupportedInitType` if the hex string is invalid.
  init(hex: String) throws {
    guard let uuid = UUID(uuidString: hex) else {
      throw IWorkUUIDError.unsupportedInitType("Invalid hex string")
    }
    self.uuid = uuid
  }

  /// Creates an IWorkUUID from a TSP_UUID protobuf message.
  ///
  /// - Parameter tspUUID: The protobuf UUID with upper and lower 64-bit values.
  init(tspUUID: TSP_UUID) {
    self.init(int: (upper: tspUUID.upper, lower: tspUUID.lower))
  }

  /// Creates an IWorkUUID from a TSP_CFUUIDArchive protobuf message.
  ///
  /// - Parameter cfUUID: The protobuf UUID with four 32-bit word values.
  init(cfUUID: TSP_CFUUIDArchive) {
    let upper = (UInt64(cfUUID.uuidW3) << 32) | UInt64(cfUUID.uuidW2)
    let lower = (UInt64(cfUUID.uuidW1) << 32) | UInt64(cfUUID.uuidW0)
    self.init(int: (upper: upper, lower: lower))
  }

  /// Creates an IWorkUUID from a dictionary representation.
  ///
  /// The dictionary can be in two formats:
  /// - Two-word format with "upper" and "lower" keys (UInt64 values)
  /// - Four-word format with "uuid_w0", "uuid_w1", "uuid_w2", "uuid_w3" keys (UInt32 values)
  ///
  /// - Parameter dict: A dictionary containing the UUID representation.
  /// - Throws: `IWorkUUIDError.unsupportedDictStructure` if the dictionary format is invalid.
  init(dict: [String: UInt64]) throws {
    if let w0 = dict["uuid_w0"], let w1 = dict["uuid_w1"],
      let w2 = dict["uuid_w2"], let w3 = dict["uuid_w3"]
    {
      let upper = (w3 << 32) | w2
      let lower = (w1 << 32) | w0
      self.init(int: (upper: upper, lower: lower))
    } else if let upper = dict["upper"], let lower = dict["lower"] {
      self.init(int: (upper: upper, lower: lower))
    } else {
      throw IWorkUUIDError.unsupportedDictStructure
    }
  }

  // MARK: - Computed Properties

  /// Returns the UUID as a tuple of upper and lower 64-bit values.
  var int: (upper: UInt64, lower: UInt64) {
    let bytes = uuid.uuid

    var upper: UInt64 = 0
    for i in 0..<8 {
      let byte = [
        bytes.0, bytes.1, bytes.2, bytes.3,
        bytes.4, bytes.5, bytes.6, bytes.7,
      ][i]
      upper |= UInt64(byte) << (56 - i * 8)
    }

    var lower: UInt64 = 0
    for i in 0..<8 {
      let byte = [
        bytes.8, bytes.9, bytes.10, bytes.11,
        bytes.12, bytes.13, bytes.14, bytes.15,
      ][i]
      lower |= UInt64(byte) << (56 - i * 8)
    }

    return (upper: upper, lower: lower)
  }

  /// Returns the UUID as a lowercase hexadecimal string without hyphens.
  var hex: String {
    uuid.uuidString.replacingOccurrences(of: "-", with: "").lowercased()
  }

  /// Returns a dictionary with "upper" and "lower" keys containing 64-bit values.
  var dict2: [String: UInt64] {
    let intValue = int
    return ["upper": intValue.upper, "lower": intValue.lower]
  }

  /// Returns a dictionary with four 32-bit word values.
  var dict4: [String: UInt32] {
    let intValue = int
    return [
      "uuid_w3": UInt32(intValue.upper >> 32),
      "uuid_w2": UInt32(intValue.upper & 0xFFFF_FFFF),
      "uuid_w1": UInt32(intValue.lower >> 32),
      "uuid_w0": UInt32(intValue.lower & 0xFFFF_FFFF),
    ]
  }

  /// Returns a TSP_UUID protobuf message with upper and lower 64-bit values.
  var protobuf2: TSP_UUID {
    var pb = TSP_UUID()
    let intValue = int
    pb.upper = intValue.upper
    pb.lower = intValue.lower
    return pb
  }

  /// Returns a TSP_CFUUIDArchive protobuf message with four 32-bit word values.
  var protobuf4: TSP_CFUUIDArchive {
    var pb = TSP_CFUUIDArchive()
    let intValue = int
    pb.uuidW3 = UInt32(intValue.upper >> 32)
    pb.uuidW2 = UInt32(intValue.upper & 0xFFFF_FFFF)
    pb.uuidW1 = UInt32(intValue.lower >> 32)
    pb.uuidW0 = UInt32(intValue.lower & 0xFFFF_FFFF)
    return pb
  }

  // MARK: - Static Methods

  /// Converts a TSP_UUID protobuf message to a hexadecimal string.
  ///
  /// - Parameter archive: A TSP_UUID protobuf message.
  /// - Returns: The UUID as a lowercase hexadecimal string without hyphens.
  static func toHex(archive: TSP_UUID) -> String {
    let uuid = IWorkUUID(tspUUID: archive)
    return uuid.hex
  }

  /// Converts a TSP_CFUUIDArchive protobuf message to a hexadecimal string.
  ///
  /// - Parameter archive: A TSP_CFUUIDArchive protobuf message.
  /// - Returns: The UUID as a lowercase hexadecimal string without hyphens.
  static func toHex(archive: TSP_CFUUIDArchive) -> String {
    let uuid = IWorkUUID(cfUUID: archive)
    return uuid.hex
  }
}
