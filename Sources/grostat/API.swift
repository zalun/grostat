import Foundation

struct GrowattClient {
    let config: Config

    func fetchLastData() throws -> InverterReading {
        let data = try apiCall(endpoint: "queryLastData")
        guard let inv = data["inv"] as? [[String: Any]], let first = inv.first else {
            throw GrostatError.api("Empty inv list in API response")
        }
        return InverterReading.fromAPI(first)
    }

    private func apiCall(endpoint: String, retries: Int = 2) throws -> [String: Any] {
        let urlString = "\(config.apiBase)/\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw GrostatError.api("Invalid URL: \(urlString)")
        }

        var lastError: Error?

        for attempt in 0...retries {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(config.token, forHTTPHeaderField: "token")
                request.setValue(
                    "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 15

                let body = "deviceType=inv&deviceSn=\(config.deviceSn)"
                request.httpBody = body.data(using: .utf8)

                let (data, response) = try syncRequest(request)

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw GrostatError.api("HTTP \(http.statusCode)")
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw GrostatError.api("Invalid JSON response")
                }

                let code = (json["code"] as? Int) ?? -1
                if code != 0 {
                    let msg = json["msg"] as? String ?? "unknown"
                    throw GrostatError.api("API error (code=\(code)): \(msg)")
                }

                return json["data"] as? [String: Any] ?? json
            } catch {
                lastError = error
                if attempt < retries {
                    Log.warning("Attempt \(attempt + 1) failed: \(error). Retrying in 10s...")
                    Thread.sleep(forTimeInterval: 10)
                }
            }
        }

        throw lastError ?? GrostatError.api("Unknown error")
    }

    private func syncRequest(_ request: URLRequest) throws -> (Data, URLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultResponse: URLResponse?
        var resultError: Error?

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            resultData = data
            resultResponse = response
            resultError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = resultError { throw error }
        guard let data = resultData, let response = resultResponse else {
            throw GrostatError.api("No response")
        }
        return (data, response)
    }
}
