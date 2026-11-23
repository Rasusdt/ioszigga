import Foundation

// MARK: - Ответ сервера

/// Один тип и на успех, и на ошибку: сервер всегда отвечает JSON с полем ok.
struct LoginResponse: Codable {
    let ok: Bool?
    let error: String?
    let message: String?

    let brand: String?
    let user: User?
    let balance: Double?
    let subscription: Subscription?
    let config: RemoteConfig?
    let configError: String?

    struct User: Codable {
        let nickname: String?
    }

    struct Subscription: Codable {
        let active: Bool?
        let expiresAt: String?
        let daysLeft: Int?
    }

    struct RemoteConfig: Codable {
        let name: String?
        let filename: String?
        let type: String?
        let content: String?
    }
}

enum ApiError: LocalizedError {
    case network
    case invalidPinFormat
    case wrongPin
    case tooManyAttempts
    case server(String)

    var errorDescription: String? {
        switch self {
        case .network:
            return "Нет связи с сервером. Проверьте интернет"
        case .invalidPinFormat:
            return "Пароль должен состоять из 6 цифр"
        case .wrongPin:
            return "Неверный пароль"
        case .tooManyAttempts:
            return "Слишком много попыток. Попробуйте через 15 минут"
        case .server(let message):
            return message
        }
    }
}

// MARK: - Клиент

/// POST {ZIGGA_API_BASE}/api/app/login  {"pin":"123456"}
final class ApiClient {
    static let shared = ApiClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    private var baseURL: String {
        let value = Bundle.main.object(forInfoDictionaryKey: "ZIGGA_API_BASE") as? String ?? ""
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func login(pin: String, completion: @escaping (Result<LoginResponse, ApiError>) -> Void) {
        guard baseURL.hasPrefix("http"), let url = URL(string: baseURL + "/api/app/login") else {
            completion(.failure(.server("Не задан адрес API (ZIGGA_API_BASE)")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(["pin": pin])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("ZIGGA-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let decoder = self.decoder

        session.dataTask(with: request) { data, response, error in
            guard error == nil, let http = response as? HTTPURLResponse else {
                completion(.failure(.network))
                return
            }

            guard let decoded = try? decoder.decode(LoginResponse.self, from: data ?? Data()) else {
                completion(.failure(.server(http.statusCode == 200
                    ? "Сервер вернул неожиданный ответ"
                    : "Сервер ответил ошибкой \(http.statusCode)")))
                return
            }

            guard http.statusCode == 200, decoded.ok == true else {
                completion(.failure(Self.error(from: decoded, status: http.statusCode)))
                return
            }
            completion(.success(decoded))
        }.resume()
    }

    /// Код ошибки от сервера важнее HTTP-статуса; статус — только запасной вариант.
    private static func error(from response: LoginResponse, status: Int) -> ApiError {
        switch (response.error ?? "").lowercased() {
        case "invalid_pin_format": return .invalidPinFormat
        case "wrong_pin": return .wrongPin
        case "too_many_attempts": return .tooManyAttempts
        default: break
        }

        switch status {
        case 401: return .wrongPin
        case 429: return .tooManyAttempts
        case 200: return .server(response.message ?? "Сервер вернул неожиданный ответ")
        default: break
        }

        if let message = response.message, !message.isEmpty {
            return .server(message)
        }
        return .server("Сервер ответил ошибкой \(status)")
    }
}
