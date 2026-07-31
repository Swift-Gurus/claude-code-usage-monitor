/**
 solid-name: SessionPathEncoderAdapter
 solid-category: utility
 solid-description: Encodes project paths.
 */
struct SessionPathEncoderAdapter: SessionPathEncoding {
    func encodeProjectPath(_ path: String) -> String {
        SessionScanner.encodeProjectPath(path)
    }
}
