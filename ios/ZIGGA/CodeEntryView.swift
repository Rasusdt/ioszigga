import SwiftUI

/// Вход по 6-значному паролю: сервер отдаёт бренд, баланс, подписку и конфиг AmneziaWG.
struct CodeEntryView: View {
    @ObservedObject var session: SessionStore
    var onBot: () -> Void

    @State private var pin = ""
    @FocusState private var focused: Bool

    private var canSubmit: Bool { pin.count == 6 && !session.isLoading }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)

            AvatarView(size: 84)

            Text("ZIGGA VPN")
                .font(.system(size: 26, weight: .black))
                .foregroundColor(Zig.text)
                .padding(.top, 14)

            Text("Введите 6-значный пароль")
                .font(.system(size: 13))
                .foregroundColor(Zig.muted)
                .padding(.top, 6)

            pinBoxes
                .padding(.top, 26)

            if let error = session.errorMessage {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundColor(Zig.danger)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.horizontal, 8)
            }

            Button(action: submit) {
                HStack(spacing: 8) {
                    if session.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: 0x131A07)))
                    }
                    Text(session.isLoading ? "Проверяем…" : "Войти")
                }
            }
            .buttonStyle(ZigPillStyle(filled: true))
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.55)
            .padding(.top, 22)

            Spacer(minLength: 16)

            Text("Пароль выдаёт наш Telegram-бот. Данные обновляются при каждом запуске.")
                .font(.system(size: 11.5))
                .foregroundColor(Zig.muted)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            ZigGoldButton(title: "Нет пароля? Получи 👇", action: onBot)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .onAppear { focused = true }
        .onChange(of: pin) { _ in session.clearError() }
    }

    private var pinBoxes: some View {
        ZStack {
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    pinBox(at: index)
                }
            }

            TextField("", text: Binding(
                get: { pin },
                set: { pin = String($0.filter { $0.isNumber }.prefix(6)) }
            ))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focused)
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    private func pinBox(at index: Int) -> some View {
        let characters = Array(pin)
        let symbol = index < characters.count ? String(characters[index]) : ""
        let isFilled = !symbol.isEmpty

        return Text(symbol)
            .font(.system(size: 24, weight: .semibold))
            .foregroundColor(Zig.text)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFilled ? Zig.neon.opacity(0.7) : Zig.stroke, lineWidth: 1.2)
            )
    }

    private func submit() {
        guard canSubmit else { return }
        focused = false
        session.login(pin: pin)
    }
}
