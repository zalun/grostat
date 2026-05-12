import Foundation

enum GrostatError: Error, LocalizedError {
    case api(String)
    case rateLimited(String)
    case database(String)
    case config(String)

    var errorDescription: String? {
        switch self {
        case .api(let msg): return "API error: \(msg)"
        case .rateLimited(let msg): return "Rate limited: \(msg)"
        case .database(let msg): return "Database error: \(msg)"
        case .config(let msg): return "Config error: \(msg)"
        }
    }
}

extension Error {
    var shortDescription: String {
        let nsError = self as NSError
        if nsError.domain == NSURLErrorDomain {
            return nsError.localizedDescription
        }
        if let localized = (self as? LocalizedError)?.errorDescription {
            return localized
        }
        return localizedDescription
    }
}
