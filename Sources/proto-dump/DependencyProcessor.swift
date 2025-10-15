import Foundation

/// Processes dependencies between proto files to establish a valid build order.
///
/// This processor performs a topological sort on proto files based on their import dependencies,
/// ensuring that files are ordered such that all imports appear before the files that depend on them.
enum DependencyProcessor {

  /// Errors that can occur during dependency processing.
  enum Error: Swift.Error, CustomStringConvertible {
    case missingDependency(String)
    case circularDependency

    var description: String {
      switch self {
      case .missingDependency(let path):
        return "Missing dependency: \(path)"
      case .circularDependency:
        return "Circular dependency detected"
      }
    }
  }

  /// Sorts proto files according to their dependencies using topological sort.
  ///
  /// Files are ordered such that a file's imports always precede it in the returned array.
  /// This ensures that when generating source code, all dependencies are available before
  /// processing files that depend on them.
  ///
  /// - Parameter protoFiles: The proto files to sort
  /// - Returns: The sorted array of proto files
  /// - Throws: `Error.missingDependency` if a required import is not found,
  ///           or `Error.circularDependency` if there is a dependency cycle
  static func sortProtoFiles(accordingToDependencies protoFiles: [ProtoFile]) throws
    -> [ProtoFile]
  {
    var sortedFiles: [ProtoFile] = []

    // Build lookup structures
    var protoFilesByPath: [String: ProtoFile] = [:]
    var dependenciesByPath: [String: Set<String>] = [:]
    var remainingPaths = Set<String>()

    for protoFile in protoFiles {
      let path = protoFile.path
      protoFilesByPath[path] = protoFile
      dependenciesByPath[path] = Set(protoFile.dependencies)
      remainingPaths.insert(path)
    }

    // Topological sort: repeatedly process files with no remaining dependencies
    while !remainingPaths.isEmpty {
      var processedPaths = Set<String>()

      // Find all files whose dependencies have been satisfied
      for path in remainingPaths {
        guard let dependencies = dependenciesByPath[path] else { continue }

        // Filter dependencies to only those that are in our set of proto files
        // (external dependencies don't need to be in our build order)
        let internalDependencies = dependencies.filter { protoFilesByPath[$0] != nil }

        if internalDependencies.isEmpty {
          // All internal dependencies satisfied
          guard let protoFile = protoFilesByPath[path] else {
            throw Error.missingDependency(path)
          }
          sortedFiles.append(protoFile)
          processedPaths.insert(path)
        }
      }

      // If we couldn't process any files, we have a circular dependency
      if processedPaths.isEmpty {
        throw Error.circularDependency
      }

      // Remove processed files from remaining set
      remainingPaths.subtract(processedPaths)

      // Remove processed files from all dependency sets
      for path in dependenciesByPath.keys {
        dependenciesByPath[path]?.subtract(processedPaths)
      }
    }

    return sortedFiles
  }
}
