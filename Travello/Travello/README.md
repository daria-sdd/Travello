# Travello iOS

Frontend для приложения путешествий travello.

## Требования

- Xcode 15.4+
- iOS 17.0+ (используем `@Observable` где возможно, но в этом коде ещё `ObservableObject` для совместимости)
- Swift 5.10+

## Запуск

1. Открыть `Travello.xcodeproj` в Xcode
2. Скачать шрифты и положить в `Resources/Fonts/`:
   - **Fraunces** — https://fonts.google.com/specimen/Fraunces
     Нужны файлы: `Fraunces-Light.ttf`, `Fraunces-Regular.ttf`, `Fraunces-Medium.ttf`, `Fraunces-LightItalic.ttf`, `Fraunces-RegularItalic.ttf`
   - **Inter** — https://fonts.google.com/specimen/Inter
     Нужны файлы: `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`
3. В `Info.plist` добавить ключ `UIAppFonts` (Fonts provided by application) с массивом всех `.ttf` файлов
4. Build → Run

## Структура

```
Travello/
├── TravelloApp.swift          точка входа + AppState
├── Design/                    дизайн-система
│   ├── Colors.swift           цвета travello (light/dark)
│   ├── Typography.swift       Fraunces serif + Inter sans
│   ├── Tokens.swift           отступы, радиусы, тени, haptics
│   ├── Components.swift       PrimaryButton, Card, EditorialTag и др.
│   └── TabBar.swift           кастомный TabBar в editorial-стиле
├── Core/                      инфраструктура
│   ├── Network/               API клиент + SSE
│   ├── Storage/               Keychain
│   └── Extensions/            Swift extensions
└── Features/                  фичи (TCA-style)
    ├── Auth/
    ├── Onboarding/
    ├── Survey/
    ├── Generation/
    ├── Routes/
    ├── Home/
    ├── ActiveTrip/
    ├── Profile/
    ├── Settings/
    └── Booking/
```

## Дизайн-система

### Цвета — `Color.Travello.*`

- `cream` — основной фон (FAF6F1 / 1A1410)
- `sand` — карточки (F5EBDC / 231C13)
- `paper` — приподнятые поверхности (FFF / 2D2419)
- `ink` — основной текст (2A1F12 / F4EBDD)
- `terra` — главный акцент (D8743A / E89968)
- `olive` — успех / online
- `mute`, `tertiary` — оттенки текста

### Шрифты — `Font.Travello.*`

- `display`, `h1`, `h2`, `h3` — заголовки на Fraunces
- `h1Italic`, `italic`, `numeral` — Fraunces italic для акцентов
- `body`, `bodySmall`, `caption` — Inter для тела
- `eyebrow`, `eyebrowSmall` — мелкие caps надписи

### Компоненты

- `PrimaryButton` — capsule, terracotta, haptic
- `DarkButton` — для Apple Sign In
- `LinkButton` — italic-ссылка
- `Card`, `SoftCard` — карточки-обёртки
- `EditorialTag` — теги с тонкой границей
- `EyebrowLine` — фирменная eyebrow с дефисом
- `Rule`, `SoftRule` — линейки-разделители
- `EditorialProgress` — тонкий progress 0.5px
- `PageDots` — индикатор страниц онбординга
- `EditorialNumeral` — декоративная нумерация в italic
- `TravelloTabBar` — кастомный TabBar

### Анимации — `Anim.*`

- `spring` — основная (response 0.5, damping 0.75)
- `microSpring` — для кнопок и tab
- `smooth` — для переходов
- `quick` — для tap feedback
- `cardCascade` — задержка для лесенки появления карточек

### Haptics — `Haptics.*`

- `tap()` — лёгкий feedback на нажатие
- `select()` — выбор / переключение
- `success()` / `warning()` / `error()` — уведомления
- `medium()` — подтверждение важного действия

## Что дальше

- [x] Дизайн-система (Colors, Typography, Tokens, Components, TabBar)
- [ ] Network layer (APIClient, SSEClient, KeychainService)
- [ ] Auth + AppleSignIn
- [ ] Onboarding с book-flip анимацией
- [ ] Survey (5 шагов)
- [ ] Generation (Lottie + SSE)
- [ ] Routes — варианты в шторке + детальный
- [ ] Home, ActiveTrip, Profile, Settings
- [ ] Booking cards (5 типов)
