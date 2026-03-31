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
    private static var logPath: String = ""
    private static let maxLogSize: UInt64 = 5 * 1024 * 1024  // 5 MB
    private static let keepRotations = 3  // grostat.log.1, .2, .3

    /// Call once to enable file logging next to the database
    static func setupFileLog(dbPath: String) {
        let dir = (dbPath as NSString).deletingLastPathComponent
        logPath = (dir as NSString).appendingPathComponent("grostat.log")
        rotateIfNeeded()
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil)
        }
        logFileHandle = FileHandle(forWritingAtPath: logPath)
        logFileHandle?.seekToEndOfFile()
    }

    private static func rotateIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: logPath),
              let attrs = try? fm.attributesOfItem(atPath: logPath),
              let size = attrs[.size] as? UInt64,
              size >= maxLogSize
        else { return }

        // Shift existing rotations: .3 -> delete, .2 -> .3, .1 -> .2
        for i in stride(from: keepRotations, through: 1, by: -1) {
            let src = "\(logPath).\(i)"
            let dst = "\(logPath).\(i + 1)"
            if i == keepRotations {
                try? fm.removeItem(atPath: src)
            } else if fm.fileExists(atPath: src) {
                try? fm.moveItem(atPath: src, toPath: dst)
            }
        }

        // Current -> .1
        try? fm.moveItem(atPath: logPath, toPath: "\(logPath).1")
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
