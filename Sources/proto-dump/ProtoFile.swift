import Foundation
import Logging
import SwiftProtobuf

/// Represents a Protocol Buffer `.proto` file extracted from compiled data.
///
/// A `ProtoFile` contains the file descriptor information and can generate
/// human-readable `.proto` source code from the compiled descriptor.
final class ProtoFile {
  /// The file's path as specified in the descriptor.
  let path: String

  /// The paths to proto files on which this file depends.
  let dependencies: [String]

  /// The compiled file descriptor proto.
  private let fileDescriptorProto: Google_Protobuf_FileDescriptorProto

  /// Logger for tracking generation progress and issues.
  private let logger: Logger

  /// The file's generated source code.
  ///
  /// This property is `nil` until `generateSource()` is called successfully.
  private(set) var source: String?

  /// Creates a proto file from compiled descriptor data.
  ///
  /// - Parameters:
  ///   - data: The serialized `FileDescriptorProto` data
  ///   - logger: Logger instance for tracking generation progress
  /// - Throws: An error if the data cannot be parsed as a valid descriptor
  init(compiledData data: Data, logger: Logger = Logger(label: "com.protofile")) throws {
    self.fileDescriptorProto = try Google_Protobuf_FileDescriptorProto(serializedBytes: data)
    self.path = fileDescriptorProto.name
    self.dependencies = fileDescriptorProto.dependency
    self.source = nil
    self.logger = logger
  }

  /// Generates the human-readable `.proto` source code for this file.
  ///
  /// This method will fail if any of the file's dependencies have not had their
  /// sources generated first. Dependencies must be processed in order.
  ///
  /// - Throws: An error if source generation fails
  func generateSource() throws {
    guard source == nil else {
      logger.trace("Source already generated for \(path)")
      return
    }

    logger.info("Generating source for proto file", metadata: ["path": .string(path)])

    var renderer = ProtoRenderer(logger: logger)
    try fileDescriptorProto.traverse(visitor: &renderer)
    source = renderer.result

    logger.info(
      "Successfully generated source",
      metadata: [
        "path": .string(path),
        "lines": .stringConvertible(renderer.result.components(separatedBy: "\n").count),
      ])
  }
}

extension ProtoFile: CustomStringConvertible {
  var description: String {
    "ProtoFile(path: \(path))"
  }
}

// MARK: - Proto Renderer

/// Visitor that renders a FileDescriptorProto back to .proto source format
private struct ProtoRenderer: SwiftProtobuf.Visitor {
  private var output: [String] = []
  private var indent: Int = 0
  private let logger: Logger

  private var syntax: String = ""
  private var packageName: String = ""
  private var imports: [String] = []

  var result: String {
    var lines: [String] = []

    let syntaxValue = syntax.isEmpty ? "proto2" : syntax
    lines.append("syntax = \"\(syntaxValue)\";")
    lines.append("")

    if !imports.isEmpty {
      for imp in imports {
        lines.append("import \"\(imp)\";")
      }
      lines.append("")
    }

    if !packageName.isEmpty {
      lines.append("package \(packageName);")
      lines.append("")
    }

    lines.append(contentsOf: output)

    return lines.joined(separator: "\n")
  }

  init(logger: Logger) {
    self.logger = logger
  }

  private mutating func emit(_ line: String) {
    let indentStr = String(repeating: "  ", count: indent)
    output.append(indentStr + line)
  }

  private mutating func emitBlankLine() {
    output.append("")
  }

  // MARK: - Visitor Protocol

  mutating func visitSingularFloatField(value: Float, fieldNumber: Int) throws {
    logger.trace(
      "Visiting float field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularDoubleField(value: Double, fieldNumber: Int) throws {
    logger.trace(
      "Visiting double field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularInt32Field(value: Int32, fieldNumber: Int) throws {
    logger.trace(
      "Visiting int32 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularInt64Field(value: Int64, fieldNumber: Int) throws {
    logger.trace(
      "Visiting int64 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularUInt32Field(value: UInt32, fieldNumber: Int) throws {
    logger.trace(
      "Visiting uint32 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularUInt64Field(value: UInt64, fieldNumber: Int) throws {
    logger.trace(
      "Visiting uint64 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularSInt32Field(value: Int32, fieldNumber: Int) throws {
    logger.trace(
      "Visiting sint32 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularSInt64Field(value: Int64, fieldNumber: Int) throws {
    logger.trace(
      "Visiting sint64 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularFixed32Field(value: UInt32, fieldNumber: Int) throws {
    logger.trace(
      "Visiting fixed32 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularFixed64Field(value: UInt64, fieldNumber: Int) throws {
    logger.trace(
      "Visiting fixed64 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularSFixed32Field(value: Int32, fieldNumber: Int) throws {
    logger.trace(
      "Visiting sfixed32 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularSFixed64Field(value: Int64, fieldNumber: Int) throws {
    logger.trace(
      "Visiting sfixed64 field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularBoolField(value: Bool, fieldNumber: Int) throws {
    logger.trace(
      "Visiting bool field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularStringField(value: String, fieldNumber: Int) throws {
    logger.trace(
      "Visiting string field",
      metadata: [
        "fieldNumber": .stringConvertible(fieldNumber),
        "value": .string(value),
      ])

    switch fieldNumber {
    case 1:
      break
    case 2:
      packageName = value
    case 12:
      syntax = value
    default:
      break
    }
  }

  mutating func visitSingularBytesField(value: Data, fieldNumber: Int) throws {
    logger.trace(
      "Visiting bytes field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitSingularEnumField<E: Enum>(value: E, fieldNumber: Int) throws {
    logger.trace(
      "Visiting enum field",
      metadata: [
        "fieldNumber": .stringConvertible(fieldNumber),
        "value": .stringConvertible(value.rawValue),
      ])
  }

  mutating func visitSingularMessageField<M: Message>(value: M, fieldNumber: Int) throws {
    logger.trace(
      "Visiting message field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedFloatField(value: [Float], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated float field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedDoubleField(value: [Double], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated double field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedInt32Field(value: [Int32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated int32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedInt64Field(value: [Int64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated int64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedUInt32Field(value: [UInt32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated uint32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedUInt64Field(value: [UInt64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated uint64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedSInt32Field(value: [Int32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated sint32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedSInt64Field(value: [Int64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated sint64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedFixed32Field(value: [UInt32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated fixed32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedFixed64Field(value: [UInt64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated fixed64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedSFixed32Field(value: [Int32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated sfixed32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedSFixed64Field(value: [Int64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated sfixed64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedBoolField(value: [Bool], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated bool field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedStringField(value: [String], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated string field",
      metadata: [
        "fieldNumber": .stringConvertible(fieldNumber),
        "count": .stringConvertible(value.count),
      ])

    switch fieldNumber {
    case 3:
      imports = value
    default:
      break
    }
  }

  mutating func visitRepeatedBytesField(value: [Data], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated bytes field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedEnumField<E: Enum>(value: [E], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated enum field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedMessageField<M: Message>(value: [M], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated message field",
      metadata: [
        "fieldNumber": .stringConvertible(fieldNumber),
        "count": .stringConvertible(value.count),
        "messageType": .string(String(describing: M.self)),
      ])

    switch fieldNumber {
    case 4:
      for msg in value {
        try renderMessage(msg)
      }
    case 5:
      for enumMsg in value {
        try renderEnum(enumMsg)
      }
    case 6:
      for svc in value {
        try renderService(svc)
      }
    case 7:  // NEW: top-level extensions
      for ext in value {
        try renderExtension(ext)
      }
    default:
      break
    }
  }

  mutating func visitPackedFloatField(value: [Float], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed float field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedDoubleField(value: [Double], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed double field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedInt32Field(value: [Int32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed int32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedInt64Field(value: [Int64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed int64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedUInt32Field(value: [UInt32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed uint32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedUInt64Field(value: [UInt64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed uint64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedSInt32Field(value: [Int32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed sint32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedSInt64Field(value: [Int64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed sint64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedFixed32Field(value: [UInt32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed fixed32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedFixed64Field(value: [UInt64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed fixed64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedSFixed32Field(value: [Int32], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed sfixed32 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedSFixed64Field(value: [Int64], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed sfixed64 field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitPackedBoolField(value: [Bool], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed bool field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)]
    )
  }

  mutating func visitPackedEnumField<E: Enum>(value: [E], fieldNumber: Int) throws {
    logger.trace(
      "Visiting packed enum field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)]
    )
  }

  mutating func visitSingularGroupField<G: Message>(value: G, fieldNumber: Int) throws {
    logger.trace(
      "Visiting singular group field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitRepeatedGroupField<G: Message>(value: [G], fieldNumber: Int) throws {
    logger.trace(
      "Visiting repeated group field",
      metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitMapField<KeyType, ValueType: MapValueType>(
    fieldType: _ProtobufMap<KeyType, ValueType>.Type,
    value: _ProtobufMap<KeyType, ValueType>.BaseType,
    fieldNumber: Int
  ) throws where KeyType: MapKeyType {
    logger.trace(
      "Visiting map field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitMapField<KeyType, ValueType>(
    fieldType: _ProtobufEnumMap<KeyType, ValueType>.Type,
    value: _ProtobufEnumMap<KeyType, ValueType>.BaseType,
    fieldNumber: Int
  ) throws where KeyType: MapKeyType, ValueType: Enum, ValueType.RawValue == Int {
    logger.trace(
      "Visiting enum map field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)])
  }

  mutating func visitMapField<KeyType, ValueType>(
    fieldType: _ProtobufMessageMap<KeyType, ValueType>.Type,
    value: _ProtobufMessageMap<KeyType, ValueType>.BaseType,
    fieldNumber: Int
  ) throws where KeyType: MapKeyType, ValueType: Message {
    logger.trace(
      "Visiting message map field", metadata: ["fieldNumber": .stringConvertible(fieldNumber)]
    )
  }

  mutating func visitExtensionFields(fields: ExtensionFieldValueSet, start: Int, end: Int) throws {
    logger.trace(
      "Visiting extension fields",
      metadata: [
        "start": .stringConvertible(start),
        "end": .stringConvertible(end),
      ])
  }

  mutating func visitUnknown(bytes: Data) throws {
    logger.trace(
      "Visiting unknown bytes", metadata: ["byteCount": .stringConvertible(bytes.count)])
  }

  // MARK: - Rendering

  private mutating func renderMessage<M: Message>(_ message: M) throws {
    guard let desc = message as? Google_Protobuf_DescriptorProto else {
      logger.warning("Unable to cast message to DescriptorProto")
      return
    }

    emit("message \(desc.name) {")
    indent += 1

    for enumType in desc.enumType {
      try renderEnum(enumType)
    }

    for nested in desc.nestedType {
      try renderMessage(nested)
    }

    for field in desc.field {
      try renderField(field)
    }

    for extRange in desc.extensionRange {
      let start = extRange.start
      let end = extRange.end
      emit("extensions \(start) to \(end - 1);")
    }

    for ext in desc.extension {
      let extendee = stripLeadingDot(from: ext.extendee)
      emit("extend \(extendee) {")
      indent += 1
      try renderField(ext)
      indent -= 1
      emit("}")
    }

    indent -= 1
    emit("}")
    emitBlankLine()
  }

  private mutating func renderField(_ field: Google_Protobuf_FieldDescriptorProto) throws {
    let label = fieldLabel(for: field.label)
    let type = fieldType(for: field.type, typeName: field.typeName)
    var fieldLine = "\(label)\(type) \(field.name) = \(field.number)"

    var options: [String] = []

    if field.hasDefaultValue && !field.defaultValue.isEmpty {
      options.append("default = \(formatDefaultValue(field.defaultValue, for: field.type))")
    }

    if field.hasOptions && field.options.hasDeprecated && field.options.deprecated {
      options.append("deprecated = true")
    }

    if !options.isEmpty {
      fieldLine += " [\(options.joined(separator: ", "))]"
    }

    fieldLine += ";"
    emit(fieldLine)
  }

  private mutating func renderExtension<E: Message>(_ extMessage: E) throws {
    guard let extDesc = extMessage as? Google_Protobuf_FieldDescriptorProto else {
      logger.warning("Unable to cast extension to FieldDescriptorProto")
      return
    }

    let extendee = stripLeadingDot(from: extDesc.extendee)
    emit("extend \(extendee) {")
    indent += 1

    try renderField(extDesc)

    indent -= 1
    emit("}")
    emitBlankLine()
  }

  private func formatDefaultValue(
    _ value: String, for type: Google_Protobuf_FieldDescriptorProto.TypeEnum
  ) -> String {
    switch type {
    case .string:
      return "\"\(value)\""
    case .bool, .double, .float, .int32, .int64, .uint32, .uint64, .sint32, .sint64, .fixed32,
      .fixed64, .sfixed32, .sfixed64, .enum:
      return value
    default:
      return value
    }
  }

  private func fieldLabel(for label: Google_Protobuf_FieldDescriptorProto.Label) -> String {
    switch label {
    case .optional: return "optional "
    case .required: return "required "
    case .repeated: return "repeated "
    }
  }

  private func fieldType(
    for type: Google_Protobuf_FieldDescriptorProto.TypeEnum, typeName: String
  ) -> String {
    switch type {
    case .double: return "double"
    case .float: return "float"
    case .int64: return "int64"
    case .uint64: return "uint64"
    case .int32: return "int32"
    case .fixed64: return "fixed64"
    case .fixed32: return "fixed32"
    case .bool: return "bool"
    case .string: return "string"
    case .group: return "group"
    case .message: return stripLeadingDot(from: typeName)
    case .bytes: return "bytes"
    case .uint32: return "uint32"
    case .enum: return stripLeadingDot(from: typeName)
    case .sfixed32: return "sfixed32"
    case .sfixed64: return "sfixed64"
    case .sint32: return "sint32"
    case .sint64: return "sint64"
    }
  }

  private func stripLeadingDot(from name: String) -> String {
    name.hasPrefix(".") ? String(name.dropFirst()) : name
  }

  private mutating func renderEnum<E: Message>(_ enumMessage: E) throws {
    guard let enumDesc = enumMessage as? Google_Protobuf_EnumDescriptorProto else {
      logger.warning("Unable to cast enum to EnumDescriptorProto")
      return
    }

    emit("enum \(enumDesc.name) {")
    indent += 1

    for value in enumDesc.value {
      emit("\(value.name) = \(value.number);")
    }

    indent -= 1
    emit("}")
    emitBlankLine()
  }

  private mutating func renderService<S: Message>(_ serviceMessage: S) throws {
    guard let svcDesc = serviceMessage as? Google_Protobuf_ServiceDescriptorProto else {
      logger.warning("Unable to cast service to ServiceDescriptorProto")
      return
    }

    emit("service \(svcDesc.name) {")
    indent += 1

    for method in svcDesc.method {
      let inputType = stripLeadingDot(from: method.inputType)
      let outputType = stripLeadingDot(from: method.outputType)
      emit("rpc \(method.name)(\(inputType)) returns (\(outputType));")
    }

    indent -= 1
    emit("}")
    emitBlankLine()
  }
}
