# Подпись ZIGGA (iOS) своим сертификатом

Подписать `.ipa` можно только сертификатом Apple, выпущенным на аккаунт разработчика.
Сертификат нельзя сгенерировать или «найти»: iOS проверяет цепочку до Apple, а VPN-расширение
дополнительно требует, чтобы профиль разрешал `packet-tunnel-provider`. Поэтому подпись
делает workflow `.github/workflows/ios-signed-ipa.yml` вашим сертификатом.

## Что нужно

1. **Apple Developer Program** — 99 $/год. Бесплатный Apple ID не даёт Network Extensions,
   то есть приложение установится, а VPN не включится.
2. **Capability Network Extensions** у обоих App ID:
   `com.zigga.vpn` и `com.zigga.vpn.tunnel`
   (developer.apple.com/account → Certificates, IDs & Profiles → Identifiers → App ID →
   Capabilities → Network Extensions).
3. **Два профиля** (Profiles → +):
   - для `com.zigga.vpn`;
   - для `com.zigga.vpn.tunnel`.
   Тип: iOS App Development (свой телефон) или Ad Hoc (до 100 устройств).
   Профили создавать **после** включения Network Extensions, иначе capability в них не попадёт.
4. **UDID телефона** в портале (Devices → +). UDID видно в Finder/iTunes, 3uTools, iMazing
   или на udid.tech.
5. **Сертификат** (Certificates → + → Apple Development) + приватный ключ, экспортированный
   в `.p12` с паролем.

## Секреты репозитория

Settings → Secrets and variables → Actions → New repository secret:

| Имя | Значение |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | `.p12` в base64 |
| `P12_PASSWORD` | пароль от `.p12` |
| `PROFILE_APP_BASE64` | профиль приложения в base64 |
| `PROFILE_TUNNEL_BASE64` | профиль расширения в base64 |
| `DEVELOPMENT_TEAM` | Team ID (10 символов) |

base64 без переносов строк:

- macOS: `base64 -i cert.p12 | pbcopy`
- Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12")) | Set-Clipboard`

## Запуск

Actions → **iOS signed IPA** → **Run workflow** → метод:

- `development` — установка на свой iPhone;
- `ad-hoc` — до 100 UDID из профиля;
- `app-store` — TestFlight/App Store.

Результат: артефакт `ZIGGA-signed-ipa` → `ZIGGA-signed.ipa` + `.sha256`.
Workflow сам проверяет, что в профилях есть `packet-tunnel-provider` и что entitlement остался
в подписанных бандлах приложения и расширения.

## Установка

Подписанный `.ipa` ставится без переподписи: 3uTools, iMazing, Apple Configurator 2 (Mac)
или Sideloadly с вашим `.p12`. Переподписывать чужим сертификатом нельзя — подпись сломается
вместе с entitlement VPN.

## Почему не подходят «подписанные» `.ipa` из сервисов подписи

ESign, KSign, Scarlet, Signulous и подобные подписывают своим сертификатом. Их профили
не выдают `packet-tunnel-provider`, поэтому приложение запустится, но VPN не включится
(`NEVPNErrorDomain 1/5`). Кроме того, такие сертификаты регулярно отзывают.
