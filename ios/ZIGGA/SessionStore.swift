import Combine
import Foundation

/// Сессия: вход по PIN, обновление при каждом запуске и хранение последнего ответа.
/// PIN живёт только в Keychain, конфиг — в ConfigStore (App Group).
final class SessionStore: ObservableObject {
    @Published private(set) var response: LoginResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasPin: Bool

    private let configStore: ConfigStore
    private let defaults: UserDefaults
    private static let cacheKey = "zigga.session.response"

    init(configStore: ConfigStore = .shared) {
        self.configStore = configStore
        self.defaults = UserDefaults(suiteName: ZConst.appGroupID) ?? .standard
        self.hasPin = Keychain.pin() != nil
        self.response = defaults.data(forKey: Self.cacheKey)
            .flatMap { try? JSONDecoder().decode(LoginResponse.self, from: $0) }
    }

    // MARK: - Тексты для экрана

    var brandTitle: String {
        let brand = response?.brand?.uppercased() ?? ""
        return brand.isEmpty ? "ZIGGA VPN" : "\(brand) VPN"
    }

    var nickname: String? {
        let value = response?.user?.nickname ?? ""
        return value.isEmpty ? nil : value
    }

    var balanceText: String? {
        guard let balance = response?.balance else { return nil }
        let rounded = (balance * 100).rounded() / 100
        let text = rounded == rounded.rounded()
            ? String(Int(rounded))
            : String(format: "%.2f", rounded)
        return "Баланс: \(text) ₽"
    }

    var isSubscribed: Bool {
        response?.subscription?.active == true
    }

    var subscriptionText: String {
        guard let subscription = response?.subscription, let active = subscription.active else {
            return ""
        }
        guard active else { return "Подписка неактивна" }
        if let days = subscription.daysLeft {
            return "Подписка активна · \(days) дн."
        }
        if let expires = subscription.expiresAt, !expires.isEmpty {
            return "Подписка активна до \(expires)"
        }
        return "Подписка активна"
    }

    /// Причина, по которой сервер не выдал конфиг (nil — причины нет).
    var configStatusText: String? {
        if let error = response?.configError, !error.isEmpty {
            switch error {
            case "no_device": return "Нет устройства — получите его в боте"
            case "subscription_expired": return "Подписка закончилась — продлите в боте"
            default: return "Конфиг недоступен: \(error)"
            }
        }
        if response != nil, response?.config == nil {
            return "Сервер не выдал конфиг — нажмите «Обновить»"
        }
        return nil
    }

    // MARK: - Действия

    func login(pin: String) {
        request(pin: pin) { [weak self] in
            Keychain.save(pin: pin)
            self?.hasPin = true
        }
    }

    func refresh() {
        guard let pin = Keychain.pin() else {
            hasPin = false
            response = nil
            return
        }
        request(pin: pin)
    }

    func clearError() {
        errorMessage = nil
    }

    func logout() {
        Keychain.delete()
        defaults.removeObject(forKey: Self.cacheKey)
        configStore.clear()
        response = nil
        hasPin = false
        errorMessage = nil
    }

    // MARK: - Private

    private func request(pin: String, onSuccess: (() -> Void)? = nil) {
        isLoading = true
        errorMessage = nil

        ApiClient.shared.login(pin: pin) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.errorDescription
                case .success(let response):
                    onSuccess?()
                    self.apply(response)
                }
            }
        }
    }

    private func apply(_ response: LoginResponse) {
        self.response = response
        if let data = try? JSONEncoder().encode(response) {
            defaults.set(data, forKey: Self.cacheKey)
        }

        if let content = response.config?.content, !content.isEmpty {
            let prepared = content.replacingOccurrences(of: "\r\n", with: "\n")
            let label = [response.config?.name, response.config?.filename]
                .compactMap { $0 }
                .first { !$0.isEmpty }
            configStore.save(config: prepared, label: label)
        } else {
            // Сервер ответил без конфига: старый не удаляем, но рабочим больше не считаем.
            configStore.invalidate()
        }
    }
}
