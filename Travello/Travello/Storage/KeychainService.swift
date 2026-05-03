import Foundation
import Security

// ============================================================
// KEYCHAIN SERVICE
// Безопасное хранение JWT токенов и user_id в iOS Keychain.
// Никогда не использовать UserDefaults для секретов.
// ============================================================

enum KeychainKey: String {
    case authToken      = "travello.auth.token"
    case refreshToken   = "travello.auth.refresh"
    case userId         = "travello.user.id"
    case firebaseUid    = "travello.user.firebaseUid"
}

enum KeychainService {

    // ── Save ─────────────────────────────────────────────────

    static func save(_ value: String, for key: KeychainKey) {
        guard let data = value.data(using: .utf8) else { return }

        // Удалим существующую запись если есть
        delete(key)

        let query: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     key.rawValue,
            kSecValueData as String:       data,
            // Доступно только когда устройство разблокировано — стандарт безопасности
            kSecAttrAccessible as String:  kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Keychain save failed for \(key.rawValue): \(status)")
        }
    }

    // ── Read ─────────────────────────────────────────────────

    static func read(_ key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrAccount as String:  key.rawValue,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    // ── Delete ───────────────────────────────────────────────

    static func delete(_ key: KeychainKey) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrAccount as String:  key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Полная очистка — при logout.
    static func clearAll() {
        for key in [KeychainKey.authToken, .refreshToken, .userId, .firebaseUid] {
            delete(key)
        }
    }

    // ── Convenience ──────────────────────────────────────────

    static var hasToken: Bool {
        read(.authToken) != nil
    }
}
