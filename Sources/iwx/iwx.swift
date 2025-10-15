import ArgumentParser
import Foundation
import WorkKit

@main
@available(macOS 12, iOS 15, visionOS 1, tvOS 15, watchOS 8, *)
struct IWX: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "iwx",
        abstract: "Convert iWork documents to Markdown or debug text format."
    )

    @Argument(help: "Path to the iWork document (.pages, .numbers, or .key).")
    var inputPath: String

    @Option(name: [.short, .long], help: "Output format: 'markdown' or 'debug'.")
    var format: OutputFormat = .markdown

    @Option(name: [.short, .long], help: "Output directory for converted files and assets.")
    var output: String?

    @Flag(name: .long, help: "Exclude slide/sheet titles from output.")
    var noTitles = false

    @Flag(name: .long, help: "Enable OCR for text recognition in images.")
    var ocr = false

    @Option(name: .long, help: "OCR recognition languages (comma-separated, e.g., 'en-US,es-ES').")
    var ocrLanguages: String?

    enum OutputFormat: String, ExpressibleByArgument {
        case markdown
        case debug
    }

    mutating func run() async throws {
        let document = try IWorkParser.open(at: inputPath)
        let outputDir = output ?? FileManager.default.currentDirectoryPath
        let inputURL = URL(fileURLWithPath: inputPath)
        let baseFilename = inputURL.deletingPathExtension().lastPathComponent

        let ocrProvider: OCRProvider?
        if ocr {
            let languages =
                ocrLanguages?
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty } ?? []
            ocrProvider = VisionOCRProvider(recognitionLanguages: languages)
        } else {
            ocrProvider = nil
        }

        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: outputDir),
            withIntermediateDirectories: true
        )

        let outputFilename: String
        let outputURL: URL

        switch format {
        case .markdown:
            let config = MarkdownVisitor.Configuration(
                outputDirectory: outputDir,
                includeSlideSheetTitles: !noTitles
            )
            let visitor = MarkdownVisitor(
                using: document,
                configuration: config,
                with: ocrProvider
            )
            try await visitor.accept()

            outputFilename = "\(baseFilename).md"
            outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent(outputFilename)
            try visitor.markdown.write(to: outputURL, atomically: true, encoding: .utf8)
            print("Converted: \(outputURL.path)")

        case .debug:
            let visitor = DebugTextExtractor(using: document, with: ocrProvider)
            try await visitor.accept()

            outputFilename = "\(baseFilename).txt"
            outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent(outputFilename)
            try visitor.text.write(to: outputURL, atomically: true, encoding: .utf8)
            print("Converted: \(outputURL.path)")
        }
    }
}
