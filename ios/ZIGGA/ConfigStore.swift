import Combine
import Foundation

/// Конфиг в App Group: его читают и приложение, и расширение.
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published private(set) var config: String?
    @Published private(set) var label: String?
    /// false — конфиг остался с прошлого раза, но сервер его больше не подтвердил.
    @Published private(set) var isValid: Bool

    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: ZConst.appGroupID) ?? .standard
        config = defaults.string(forKey: ZConst.configKey)
        label = defaults.string(forKey: ZConst.labelKey)
        isValid = defaults.bool(forKey: ZConst.validKey)
    }

    var hasConfig: Bool { config != nil }

    func save(config: String, label: String?) {
        defaults.set(config, forKey: ZConst.configKey)
        defaults.set(label, forKey: ZConst.labelKey)
        defaults.set(true, forKey: ZConst.validKey)
        self.config = config
        self.label = label
        self.isValid = true
    }

    func invalidate() {
        guard config != nil, isValid else { return }
        defaults.set(false, forKey: ZConst.validKey)
        isValid = false
    }

    func clear() {
        defaults.removeObject(forKey: ZConst.configKey)
        defaults.removeObject(forKey: ZConst.labelKey)
        defaults.removeObject(forKey: ZConst.validKey)
        config = nil
        label = nil
        isValid = false
    }

    var title: String {
        if let label = label, !label.isEmpty { return label }
        return hasConfig ? "Мой конфиг" : "Конфиг не получен"
    }

    /// Например: «AmneziaWG · 1.2.3.4:51820» или «… · недействителен».
    var summary: String {
        guard let config = config else { return "Получите конфиг по паролю" }
        var parts = ["AmneziaWG"]
        if let endpoint = Self.endpoint(in: config) {
            parts.append(endpoint)
        }
        if !isValid {
            parts.append("недействителен")
        }
        return parts.joined(separator: " · ")
    }

    private static func endpoint(in config: String) -> String? {
        for line in config.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("endpoint") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 {
                return String(parts[1]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
