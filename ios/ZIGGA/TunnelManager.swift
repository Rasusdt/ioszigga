import Combine
import Foundation
import NetworkExtension

/// Управление VPN-профилем и Packet Tunnel расширением.
final class TunnelManager: ObservableObject {
    enum Status: Equatable {
        case disconnected
        case connecting
        case connected
    }

    @Published private(set) var status: Status = .disconnected
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private var pendingCompletion: ((String?) -> Void)?
    private var pendingDeadline: DispatchWorkItem?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshStatus()
        }
        loadManager()
    }

    deinit {
        pendingDeadline?.cancel()
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Загружает уже сохранённый профиль ZIGGA, если он есть в системе.
    func loadManager(completion: (() -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            DispatchQueue.main.async {
                self?.manager = (managers ?? []).first { $0.isZiggaProfile }
                self?.refreshStatus()
                completion?()
            }
        }
    }

    func connect(config: String, completion: @escaping (String?) -> Void) {
        loadManager { [weak self] in
            guard let self = self else { return }
            let manager = self.manager ?? NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = ZConst.tunnelBundleID
            proto.serverAddress = "ZIGGA"
            proto.providerConfiguration = ["config": config]
            manager.protocolConfiguration = proto
            manager.localizedDescription = "ZIGGA VPN"
            manager.isEnabled = true
            manager.isOnDemandEnabled = false

            manager.saveToPreferences { error in
                guard error == nil else {
                    let message = TunnelManager.describe(error)
                    DispatchQueue.main.async { completion(message) }
                    return
                }
                // После сохранения профиль нужно перечитать, иначе iOS
                // отдаёт NEVPNErrorDomain 1 при запуске туннеля.
                manager.loadFromPreferences { loadError in
                    if let loadError = loadError {
                        DispatchQueue.main.async { completion(TunnelManager.describe(loadError)) }
                        return
                    }
                    do {
                        try manager.connection.startVPNTunnel()
                        DispatchQueue.main.async {
                            self.manager = manager
                            self.awaitConnection(completion)
                            self.refreshStatus()
                        }
                    } catch {
                        DispatchQueue.main.async { completion(TunnelManager.describe(error)) }
                    }
                }
            }
        }
    }

    func disconnect() {
        pendingDeadline?.cancel()
        pendingDeadline = nil
        pendingCompletion = nil
        manager?.connection.stopVPNTunnel()
        status = .disconnected
    }

    /// Туннель запускается асинхронно: если за 15 секунд он не поднялся,
    /// показываем причину, а не бесконечное «Подключение…».
    private func awaitConnection(_ completion: @escaping (String?) -> Void) {
        pendingCompletion = completion
        pendingDeadline?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, let completion = self.pendingCompletion else { return }
            guard self.status != .connected else { return }
            self.pendingCompletion = nil
            let message = "Туннель не подключился. Проверьте Настройки → VPN → ZIGGA VPN и права сертификата подписи."
            self.lastError = message
            self.status = .disconnected
            completion(message)
        }
        pendingDeadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: work)
    }

    private func refreshStatus() {
        guard let connection = manager?.connection else {
            status = .disconnected
            return
        }
        let newStatus: Status
        switch connection.status {
        case .connected:
            newStatus = .connected
        case .connecting, .reasserting:
            newStatus = .connecting
        case .disconnecting, .disconnected, .invalid:
            newStatus = .disconnected
        @unknown default:
            newStatus = .disconnected
        }
        status = newStatus

        if newStatus == .connected, let completion = pendingCompletion {
            pendingCompletion = nil
            pendingDeadline?.cancel()
            pendingDeadline = nil
            completion(nil)
        }
    }

    /// Понятный текст вместо голого «The operation couldn't be completed».
    private static func describe(_ error: Error?) -> String {
        guard let error = error else { return "Неизвестная ошибка VPN." }
        let ns = error as NSError
        if ns.domain == "NEVPNErrorDomain" {
            switch ns.code {
            case 1:
                return "iOS отклонил профиль VPN (NEVPNErrorDomain 1). Обычно подпись не содержит entitlement com.apple.developer.networking.networkextension (packet-tunnel-provider) — нужен сертификат с Network Extension."
            case 2:
                return "VPN-профиль отключён в настройках iOS (NEVPNErrorDomain 2)."
            case 3:
                return "iOS не смог запустить туннель (NEVPNErrorDomain 3). Расширение ZIGGATunnel должно быть подписано тем же сертификатом, что и приложение."
            case 4:
                return "VPN-профиль устарел (NEVPNErrorDomain 4). Нажмите «Обновить» и попробуйте снова."
            case 5:
                return "Нет разрешения на изменение VPN-профиля (NEVPNErrorDomain 5). Подпись приложения не содержит Network Extension."
            default:
                break
            }
        }
        return "\(ns.localizedDescription) [\(ns.domain) \(ns.code)]"
    }
}

private extension NETunnelProviderManager {
    var isZiggaProfile: Bool {
        (protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == ZConst.tunnelBundleID
    }
}
