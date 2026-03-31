import Foundation

enum Log {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static let stderrFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static var logFileHandle: FileHandle?

    /// Call once to enable file logging next to the database
    static func setupFileLog(dbPath: String) {
        let dir = (dbPath as NSString).deletingLastPathComponent
        let logPath = (dir as NSString).appendingPathComponent("grostat.log")
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        logFileHandle = FileHandle(forWritingAtPath: logPath)
        logFileHandle?.seekToEndOfFile()
    }

    private static func write(_ level: String, _ msg: String) {
        let stderrLine = "\(stderrFormatter.string(from: Date())) \(level) \(msg)\n"
        FileHandle.standardError.write(Data(stderrLine.utf8))

        if let fh = logFileHandle {
            let fileLine = "\(dateFormatter.string(from: Date())) \(level) \(msg)\n"
            fh.write(Data(fileLine.utf8))
        }
    }

    static func info(_ msg: String) { write("INFO    ", msg) }
    static func warning(_ msg: String) { write("WARNING ", msg) }
    static func error(_ msg: String) { write("ERROR   ", msg) }
    static func critical(_ msg: String) { write("CRITICAL", msg) }
}
