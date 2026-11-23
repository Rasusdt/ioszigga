import SwiftUI

struct HomeView: View {
    @ObservedObject var store: ConfigStore
    @ObservedObject var session: SessionStore
    @ObservedObject var tunnel: TunnelManager
    var onBot: () -> Void

    @State private var showLogoutConfirm = false
    @State private var connectError: String?

    private var mode: PowerButtonView.Mode {
        switch tunnel.status {
        case .connected: return .on
        case .connecting: return .connecting
        case .disconnected: return .off
        }
    }

    private var subtitle: String {
        switch tunnel.status {
        case .connected: return "Подключено · AmneziaWG"
        case .connecting: return "Подключение…"
        case .disconnected: return "AmneziaWG · WireGuard"
        }
    }

    private var subtitleColor: Color {
        switch tunnel.status {
        case .connected: return Zig.neon
        case .connecting: return Zig.gold
        case .disconnected: return Zig.muted
        }
    }

    private var statusError: String? {
        connectError ?? session.errorMessage
    }

    private var dotColor: Color {
        if statusError != nil { return Zig.danger }
        switch tunnel.status {
        case .connected: return Zig.neon
        case .connecting: return Zig.gold
        case .disconnected: return store.isValid ? Color(hex: 0x7C8570) : Zig.muted
        }
    }

    private var powerHint: String {
        switch tunnel.status {
        case .connected: return "Нажмите, чтобы отключить"
        case .connecting: return "Подключение…"
        case .disconnected:
            guard store.hasConfig else { return "Конфиг не получен — нажмите «Обновить»" }
            guard store.isValid else { return "Конфиг недействителен — обновите данные" }
            return "Нажмите, чтобы подключиться"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ZigCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        StatusDot(color: dotColor)
                        Text(store.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(store.isValid ? Zig.text : Zig.muted)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if session.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Zig.muted))
                        }
                    }

                    Text(store.summary)
                        .font(.system(size: 12.5))
                        .foregroundColor(Zig.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let nickname = session.nickname {
                        Text("Аккаунт: \(nickname)")
                            .font(.system(size: 12.5))
                            .foregroundColor(Zig.muted)
                    }

                    HStack(spacing: 12) {
                        if let balance = session.balanceText {
                            Text(balance)
                                .font(.system(size: 12.5))
                                .foregroundColor(Zig.text)
                        }
                        Text(session.subscriptionText)
                            .font(.system(size: 12.5))
                            .foregroundColor(session.isSubscribed ? Zig.neon : Zig.muted)
                    }

                    if let configStatus = session.configStatusText {
                        Text(configStatus)
                            .font(.system(size: 12.5))
                            .foregroundColor(Zig.gold)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let error = statusError {
                        Text("Ошибка: \(error)")
                            .font(.system(size: 12.5))
                            .foregroundColor(Zig.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let validationError = connectError {
                        Text(validationError)
                            .font(.system(size: 12.5))
                            .foregroundColor(Zig.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 20)

            Spacer(minLength: 8)

            PowerButtonView(mode: mode) {
                onPower()
            }

            Text(powerHint)
                .font(.system(size: 13))
                .foregroundColor(Zig.muted)
                .padding(.top, 6)

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                Button(action: {
                    connectError = nil
                    session.refresh()
                }) {
                    Text(session.isLoading ? "Обновляем…" : "Обновить")
                        .font(.system(size: 12.5))
                        .foregroundColor(Zig.text)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(session.isLoading)

                Text("·").foregroundColor(Zig.muted)

                Button(action: { showLogoutConfirm = true }) {
                    Text("Выйти")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color(hex: 0xA9B198))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .alert(isPresented: $showLogoutConfirm) {
            Alert(
                title: Text("Выйти из аккаунта?"),
                message: Text("Пароль и конфиг будут удалены с устройства."),
                primaryButton: .destructive(Text("Выйти")) {
                    tunnel.disconnect()
                    session.logout()
                    connectError = nil
                },
                secondaryButton: .cancel(Text("Отмена"))
            )
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            AvatarView(size: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.brandTitle)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Zig.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(subtitleColor)
            }
            .padding(.leading, 12)

            Spacer(minLength: 8)

            BotChip(action: onBot)
        }
    }

    private func onPower() {
        switch tunnel.status {
        case .connecting:
            return
        case .connected:
            tunnel.disconnect()
        case .disconnected:
            if !store.isValid {
                connectError = store.summary
                return
            }
            if let config = store.config {
                connectError = nil
                tunnel.connect(config: config) { message in
                    connectError = message
                }
            } else {
                connectError = "Конфиг не получен — нажмите «Обновить»"
            }
        }
    }
}