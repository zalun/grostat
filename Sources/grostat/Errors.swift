import Foundation

enum GrostatError: Error, LocalizedError {
    case api(String)
    case database(String)
    case config(String)

    var errorDescription: String? {
        switch self {
        case .api(let msg): return "API error: \(msg)"
        case .database(let msg): return "Database error: \(msg)"
        case .config(let msg): return "Config error: \(msg)"
        }
    }
}
