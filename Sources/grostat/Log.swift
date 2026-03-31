import Foundation

enum Log {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static func timestamp() -> String {
        dateFormatter.string(from: Date())
    }

    static func info(_ msg: String) {
        FileHandle.standardError.write(
            Data("\(timestamp()) INFO     \(msg)\n".utf8))
    }

    static func warning(_ msg: String) {
        FileHandle.standardError.write(
            Data("\(timestamp()) WARNING  \(msg)\n".utf8))
    }

    static func error(_ msg: String) {
        FileHandle.standardError.write(
            Data("\(timestamp()) ERROR    \(msg)\n".utf8))
    }

    static func critical(_ msg: String) {
        FileHandle.standardError.write(
            Data("\(timestamp()) CRITICAL \(msg)\n".utf8))
    }
}
