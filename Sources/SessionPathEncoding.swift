/**
 solid-name: SessionPathEncoding
 solid-category: abstraction
 solid-description: Contract for encoding a filesystem path into the project directory name format.
 */
protocol SessionPathEncoding {
    func encodeProjectPath(_ path: String) -> String
}
