import Foundation

/// Extracts Protocol Buffer descriptors from compiled binary data.
///
/// This extractor searches through binary data (such as compiled executables or libraries)
/// to find embedded Protocol Buffer file descriptors, then extracts and processes them
/// into usable `.proto` source files.
enum ProtoFileExtractor {

  /// Errors that can occur during proto file extraction.
  enum Error: Swift.Error, CustomStringConvertible {
    case noProtobufDescriptors
    case dependencySortingFailed(underlying: Swift.Error)
    case sourceGenerationFailed(path: String)

    var description: String {
      switch self {
      case .noProtobufDescriptors:
        return "The data does not contain any Protobuf descriptors."
      case .dependencySortingFailed(let error):
        return "Unable to process dependencies: \(error)"
      case .sourceGenerationFailed(let path):
        return "Failed to generate source for \"\(path)\"."
      }
    }
  }

  /// Extracts proto files from binary data and returns them sorted by dependencies.
  ///
  /// This method performs the following steps:
  /// 1. Searches the binary data for embedded Protocol Buffer descriptors
  /// 2. Parses each descriptor into a `ProtoFile` object
  /// 3. Sorts the files according to their dependencies (topological sort)
  /// 4. Generates source code for each file in dependency order
  ///
  /// - Parameter data: Binary data that may contain embedded Protocol Buffer descriptors
  /// - Returns: An array of `ProtoFile` objects with generated source code
  /// - Throws: An `Error` if extraction, sorting, or source generation fails
  static func extractProtoFiles(from data: Data) throws -> [ProtoFile] {
    // Extract descriptors from binary data
    let unsortedProtoFiles = try extractUnsortedProtoFiles(from: data)

    guard !unsortedProtoFiles.isEmpty else {
      throw Error.noProtobufDescriptors
    }

    // Sort files according to dependencies
    let sortedProtoFiles: [ProtoFile]
    do {
      sortedProtoFiles = try DependencyProcessor.sortProtoFiles(
        accordingToDependencies: unsortedProtoFiles
      )
    } catch {
      throw Error.dependencySortingFailed(underlying: error)
    }

    // Generate source code for each file
    for protoFile in sortedProtoFiles {
      try protoFile.generateSource()
      if protoFile.source == nil {
        throw Error.sourceGenerationFailed(path: protoFile.path)
      }
    }

    return sortedProtoFiles
  }

  /// Extracts unsorted proto files from binary data.
  ///
  /// This method searches for Protocol Buffer descriptors embedded in compiled binaries.
  /// Descriptors are identified by searching for `.proto` filename extensions and validating
  /// the surrounding data matches the expected Protocol Buffer wire format.
  ///
  /// - Parameter data: Binary data to search
  /// - Returns: An array of unsorted `ProtoFile` objects
  /// - Throws: An error if descriptor parsing fails
  private static func extractUnsortedProtoFiles(from data: Data) throws -> [ProtoFile] {
    var protoFiles: [ProtoFile] = []

    let protoSuffix = ".proto".data(using: .utf8)!
    let protoStartMarker: UInt8 = 0x0A  // Protobuf tag for length-delimited field 1 (name)

    var offset = 0
    let length = data.count

    while offset < length {
      // Search for ".proto" suffix
      guard
        let suffixRange = data.range(
          of: protoSuffix,
          options: [],
          in: offset..<length
        )
      else {
        break
      }

      // Search backwards for the start marker (0x0A)
      guard
        let markerIndex = findMarkerBackwards(
          in: data,
          from: offset,
          to: suffixRange.lowerBound,
          marker: protoStartMarker
        )
      else {
        offset = suffixRange.upperBound
        continue
      }

      // Read the name length as a varint
      var nameLength: UInt64 = 0
      var nameLengthBytesConsumed = 0

      guard
        ProtobufInputStream.readVarint(
          &nameLength,
          from: data,
          offset: markerIndex + 1,
          bytesConsumed: &nameLengthBytesConsumed
        )
      else {
        offset = suffixRange.upperBound
        continue
      }

      // Verify the length matches
      let expectedLength = 1 + nameLengthBytesConsumed + Int(nameLength)
      let currentLength = suffixRange.upperBound - markerIndex

      guard currentLength == expectedLength else {
        offset = suffixRange.upperBound
        continue
      }

      // Extract the descriptor by reading until we hit a null tag
      let potentialDescriptorData = data.subdata(in: markerIndex..<length)
      let stream = ProtobufInputStream(data: potentialDescriptorData)
      let descriptorLength = stream.readUntilNullTag() - 1

      // Parse the descriptor
      let descriptorData = potentialDescriptorData.prefix(descriptorLength)

      if let protoFile = try? ProtoFile(compiledData: descriptorData),
        protoFile.path != "google/protobuf/descriptor.proto"
      {
        protoFiles.append(protoFile)
      }

      offset = markerIndex + descriptorLength
    }

    return protoFiles
  }

  /// Searches backwards in data for a specific marker byte.
  ///
  /// - Parameters:
  ///   - data: The data to search
  ///   - from: The starting index
  ///   - to: The ending index (exclusive)
  ///   - marker: The byte to search for
  /// - Returns: The index of the marker, or `nil` if not found
  private static func findMarkerBackwards(
    in data: Data,
    from: Int,
    to: Int,
    marker: UInt8
  ) -> Int? {
    guard from < to else { return nil }

    let searchRange = from..<to
    let markerData = Data([marker])

    guard
      let range = data.range(
        of: markerData,
        options: .backwards,
        in: searchRange
      )
    else {
      return nil
    }

    return range.lowerBound
  }
}
