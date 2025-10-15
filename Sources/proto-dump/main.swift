import ArgumentParser
import CryptoKit
import Foundation
import Logging

/// Command-line tool for extracting Protocol Buffer descriptors from compiled binaries.
///
/// This tool searches through binary files (such as executables or libraries) to find
/// embedded Protocol Buffer file descriptors and extracts them as human-readable `.proto` files.
struct ProtoDump: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "proto-dump",
    abstract: "Extract Protocol Buffer descriptors from compiled binaries.",
    version: "0.1.0"
  )

  @Option(name: .shortAndLong, help: "Write the .proto files to the specified directory")
  var output: String?

  @Option(
    name: .long, help: "Deduplicate .proto files from multiple dumps in the specified directory")
  var deduplicate: String?

  @Argument(help: "Extract Protobuf descriptors from the input file")
  var input: String?

  private static let logger = Logger(label: "proto-dump")

  mutating func run() throws {
    // If deduplicate mode is specified
    if let deduplicateDir = deduplicate {
      guard let outputPath = output else {
        Self.logger.error("--output must be specified when using --deduplicate")
        throw ExitCode.failure
      }

      try deduplicateProtoFiles(from: deduplicateDir, to: outputPath)
      return
    }

    // Otherwise, run normal extraction mode
    guard let inputPath = input else {
      Self.logger.error("Input file/directory must be specified (or use --deduplicate)")
      throw ExitCode.failure
    }

    let inputURL = URL(fileURLWithPath: inputPath)
    let fileManager = FileManager.default

    // Check if input is a directory (like .app bundle)
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: inputPath, isDirectory: &isDirectory) else {
      Self.logger.error("Input path does not exist: \(inputPath)")
      throw ExitCode.failure
    }

    let filesToProcess: [URL]

    if isDirectory.boolValue {
      // Recursively scan for executable files
      Self.logger.info("Scanning directory for executable files: \(inputPath)")
      filesToProcess = try scanForExecutableFiles(at: inputURL)

      if filesToProcess.isEmpty {
        Self.logger.warning("No executable files found in: \(inputPath)")
        throw ExitCode.failure
      }

      Self.logger.info("Found \(filesToProcess.count) executable file(s)")
    } else {
      // Single file
      filesToProcess = [inputURL]
    }

    // Process each file
    var allProtoFiles: [String: [ProtoFile]] = [:]

    for fileURL in filesToProcess {
      Self.logger.info("Processing: \(fileURL.path)")

      let data: Data
      do {
        data = try Data(contentsOf: fileURL)
      } catch {
        Self.logger.error("Failed to read file: \(error.localizedDescription)")
        continue
      }

      // Extract the Protocol Buffer descriptors
      let protoFiles: [ProtoFile]
      do {
        protoFiles = try ProtoFileExtractor.extractProtoFiles(from: data)

        if !protoFiles.isEmpty {
          allProtoFiles[fileURL.lastPathComponent] = protoFiles
          Self.logger.info("  Found \(protoFiles.count) proto file(s)")
        }
      } catch let error as ProtoFileExtractor.Error {
        // Only log if it's not the "no descriptors" error
        if case .noProtobufDescriptors = error {
          Self.logger.debug("  No protobuf descriptors found")
        } else {
          Self.logger.error("  \(self.formatExtractionError(error, inputPath: fileURL.path))")
        }
        continue
      } catch {
        Self.logger.error("  An unknown error occurred while extracting: \(error)")
        continue
      }
    }

    // Check if we found any proto files
    if allProtoFiles.isEmpty {
      Self.logger.error("No Protobuf descriptors found in any files")
      throw ExitCode.failure
    }

    // Output the extracted sources
    if let outputPath = output {
      // Trim .app extension from directory name if present
      var outputName = inputURL.lastPathComponent
      if outputName.hasSuffix(".app") {
        outputName = String(outputName.dropLast(4))
      }
      try writeAllProtoFiles(allProtoFiles, to: outputPath, inputFileName: outputName)
    } else {
      printAllProtoFiles(allProtoFiles)
    }
  }

  /// Deduplicates proto files from multiple application dumps into a flat directory.
  ///
  /// - Parameters:
  ///   - sourceDir: Directory containing subdirectories with proto dumps (e.g., Keynote, Numbers, Pages)
  ///   - outputDir: Directory to write deduplicated proto files (flat structure)
  private func deduplicateProtoFiles(from sourceDir: String, to outputDir: String) throws {
    let fileManager = FileManager.default
    let sourceDirURL = URL(fileURLWithPath: sourceDir)

    // Verify source directory exists
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: sourceDir, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      Self.logger.error("Source directory does not exist: \(sourceDir)")
      throw ExitCode.failure
    }

    Self.logger.info("Deduplicating proto files from: \(sourceDir)")

    // Dictionary to track files by filename only: [filename: (hash, content, source_apps)]
    var protoFileMap: [String: (hash: String, content: String, sources: [String])] = [:]

    // Get all subdirectories (e.g., Keynote, Numbers, Pages)
    let appDirs = try fileManager.contentsOfDirectory(
      at: sourceDirURL, includingPropertiesForKeys: [.isDirectoryKey]
    )
    .filter { url in
      guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
        let isDir = resourceValues.isDirectory
      else {
        return false
      }
      return isDir
    }

    if appDirs.isEmpty {
      Self.logger.error("No application directories found in: \(sourceDir)")
      throw ExitCode.failure
    }

    Self.logger.info("Found \(appDirs.count) application directory(ies)")

    // Process each app directory
    for appDir in appDirs {
      let appName = appDir.lastPathComponent
      Self.logger.info("Processing: \(appName)")

      // Find all .proto files recursively
      guard
        let enumerator = fileManager.enumerator(
          at: appDir,
          includingPropertiesForKeys: [.isRegularFileKey],
          options: []
        )
      else {
        continue
      }

      var fileCount = 0
      for case let fileURL as URL in enumerator {
        guard fileURL.pathExtension == "proto" else { continue }

        // Use just the filename (not full path)
        let filename = fileURL.lastPathComponent

        // Read file content
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
          Self.logger.warning("  Failed to read: \(filename)")
          continue
        }

        // Calculate hash
        let hash = sha256Hash(of: content)

        // Check if we've seen this filename before
        if let existing = protoFileMap[filename] {
          // Verify hash matches
          if existing.hash != hash {
            Self.logger.error("Hash mismatch for \(filename)")
            Self.logger.error("  Already seen in: \(existing.sources.joined(separator: ", "))")
            Self.logger.error("  Current source: \(appName)")
            Self.logger.error("  This indicates different versions of the same proto file")
            throw ExitCode.failure
          }

          // Same file, just add source
          var updated = existing
          updated.sources.append(appName)
          protoFileMap[filename] = updated
        } else {
          // New file
          protoFileMap[filename] = (hash: hash, content: content, sources: [appName])
          fileCount += 1
        }
      }

      Self.logger.info("  Found \(fileCount) unique proto file(s)")
    }

    // Write deduplicated files to flat directory
    let outputDirURL = URL(fileURLWithPath: outputDir)
    try fileManager.createDirectory(
      at: outputDirURL, withIntermediateDirectories: true, attributes: nil)

    Self.logger.info("Writing \(protoFileMap.count) deduplicated proto file(s) to: \(outputDir)")

    for (filename, fileInfo) in protoFileMap {
      let outputFileURL = outputDirURL.appendingPathComponent(filename)

      // Write file directly to output directory (flat structure)
      try fileInfo.content.write(to: outputFileURL, atomically: true, encoding: .utf8)

      // Log which apps this file came from
      Self.logger.debug("  \(filename) (from: \(fileInfo.sources.joined(separator: ", ")))")
    }

    Self.logger.info("Successfully deduplicated \(protoFileMap.count) proto file(s)")

    // Summary
    let totalSourceFiles = protoFileMap.values.reduce(0) { $0 + $1.sources.count }
    let savedFiles = totalSourceFiles - protoFileMap.count
    Self.logger.info("Removed \(savedFiles) duplicate file(s)")
  }

  /// Calculates SHA-256 hash of a string.
  ///
  /// - Parameter content: The string content to hash
  /// - Returns: Hex-encoded hash string
  private func sha256Hash(of content: String) -> String {
    let data = Data(content.utf8)
    let hash = SHA256.hash(data: data)
    return hash.compactMap { String(format: "%02x", $0) }.joined()
  }

  /// Gets the relative path from a base directory to a file.
  ///
  /// - Parameters:
  ///   - baseURL: The base directory URL
  ///   - fileURL: The file URL
  /// - Returns: The relative path, or nil if the file is not within the base directory
  private func getRelativePath(from baseURL: URL, to fileURL: URL) -> String? {
    let basePath = baseURL.path
    let filePath = fileURL.path

    guard filePath.hasPrefix(basePath) else {
      return nil
    }

    var relativePath = String(filePath.dropFirst(basePath.count))
    if relativePath.hasPrefix("/") {
      relativePath = String(relativePath.dropFirst())
    }

    return relativePath
  }

  /// Recursively scans a directory for executable files.
  ///
  /// - Parameter url: The directory URL to scan
  /// - Returns: An array of URLs to executable files
  private func scanForExecutableFiles(at url: URL) throws -> [URL] {
    let fileManager = FileManager.default
    var executableFiles: [URL] = []

    guard
      let enumerator = fileManager.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    for case let fileURL as URL in enumerator {
      // Check if it's a regular file
      guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
        let isRegularFile = resourceValues.isRegularFile,
        isRegularFile
      else {
        continue
      }

      // Check if it's executable and readable
      let path = fileURL.path
      if fileManager.isExecutableFile(atPath: path) && fileManager.isReadableFile(atPath: path) {
        executableFiles.append(fileURL)
      }
    }

    return executableFiles
  }

  /// Writes proto files to the output directory.
  ///
  /// Output paths take the form: `<output>/<inputFilename>/<sourceFilename>/<descriptorName>.proto`
  ///
  /// - Parameters:
  ///   - allProtoFiles: Dictionary mapping source file names to their proto files
  ///   - outputPath: The base output directory
  ///   - inputFileName: The name of the input file/directory (used as subdirectory)
  private func writeAllProtoFiles(
    _ allProtoFiles: [String: [ProtoFile]],
    to outputPath: String,
    inputFileName: String
  ) throws {
    let outputURL = URL(fileURLWithPath: outputPath)
    let baseOutputURL = outputURL.appendingPathComponent(inputFileName)

    for (sourceFileName, protoFiles) in allProtoFiles {
      let adjustedOutputURL = baseOutputURL.appendingPathComponent(sourceFileName)

      // Create the output directory
      try FileManager.default.createDirectory(
        at: adjustedOutputURL,
        withIntermediateDirectories: true,
        attributes: nil
      )

      // Write each proto file
      for protoFile in protoFiles {
        guard let source = protoFile.source else { continue }

        let fileURL = adjustedOutputURL.appendingPathComponent(protoFile.path)

        // Create intermediate directories if needed
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
          at: directoryURL,
          withIntermediateDirectories: true,
          attributes: nil
        )

        try source.write(to: fileURL, atomically: true, encoding: .utf8)
      }
    }

    Self.logger.info("Successfully wrote proto files to: \(baseOutputURL.path)")
  }

  /// Writes proto files to the output directory (single source file).
  ///
  /// Output paths take the form: `<output>/<inputFilename>/<descriptorName>.proto`
  ///
  /// - Parameters:
  ///   - protoFiles: The proto files to write
  ///   - outputPath: The base output directory
  ///   - inputFileName: The name of the input file (used as subdirectory)
  private func writeProtoFiles(
    _ protoFiles: [ProtoFile],
    to outputPath: String,
    inputFileName: String
  ) throws {
    let outputURL = URL(fileURLWithPath: outputPath)
    let adjustedOutputURL = outputURL.appendingPathComponent(inputFileName)

    // Create the output directory
    try FileManager.default.createDirectory(
      at: adjustedOutputURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    // Write each proto file
    for protoFile in protoFiles {
      guard let source = protoFile.source else { continue }

      let fileURL = adjustedOutputURL.appendingPathComponent(protoFile.path)

      // Create intermediate directories if needed
      let directoryURL = fileURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )

      try source.write(to: fileURL, atomically: true, encoding: .utf8)
    }
  }

  /// Prints all proto files to standard output.
  ///
  /// - Parameter allProtoFiles: Dictionary mapping source file names to their proto files
  private func printAllProtoFiles(_ allProtoFiles: [String: [ProtoFile]]) {
    for (sourceFileName, protoFiles) in allProtoFiles {
      Self.logger.info("=== \(sourceFileName) ===")
      for protoFile in protoFiles {
        if let source = protoFile.source {
          Self.logger.info("\(source)")
        }
      }
    }
  }

  /// Prints proto files to standard output.
  ///
  /// - Parameter protoFiles: The proto files to print
  private func printProtoFiles(_ protoFiles: [ProtoFile]) {
    for protoFile in protoFiles {
      if let source = protoFile.source {
        Self.logger.info("\(source)")
      }
    }
  }

  /// Formats an extraction error with appropriate context.
  ///
  /// - Parameters:
  ///   - error: The extraction error
  ///   - inputPath: The path to the input file
  /// - Returns: A formatted error message
  private func formatExtractionError(_ error: ProtoFileExtractor.Error, inputPath: String) -> String
  {
    switch error {
    case .noProtobufDescriptors:
      // Include the filename in the error message
      let inputFileName = URL(fileURLWithPath: inputPath).lastPathComponent
      return "The file \"\(inputFileName)\" does not contain any Protobuf descriptors."
    case .dependencySortingFailed(let underlying):
      return "Unable to process dependencies: \(underlying)"
    case .sourceGenerationFailed(let path):
      return "Failed to generate source for \"\(path)\"."
    }
  }
}

// Entry point
ProtoDump.main()
