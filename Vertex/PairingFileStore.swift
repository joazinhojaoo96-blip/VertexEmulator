import Foundation
import Security

/// Stores an imported Remote Pairing plist as an opaque secret.
/// The app deliberately does not interpret undocumented private pairing fields.
enum PairingFileStore {
    private static let service = "com.vertex.emulator.remote-pairing"
    private static let account = "RPPairing"
    static let maximumFileSize = 1_048_576

    enum StoreError: LocalizedError {
        case tooLarge
        case invalidPropertyList
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .tooLarge:
                return "O arquivo excede o limite de 1 MB."
            case .invalidPropertyList:
                return "O arquivo não é um plist de pareamento válido."
            case .keychain(let status):
                return "O Keychain recusou o armazenamento (código \(status))."
            }
        }
    }

    static func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count <= maximumFileSize else {
            throw StoreError.tooLarge
        }
        guard let object = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ), let dictionary = object as? [String: Any], !dictionary.isEmpty else {
            throw StoreError.invalidPropertyList
        }
    }

    static func save(_ data: Data) throws {
        try validate(data)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.keychain(status) }
    }

    static func load() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw StoreError.keychain(status)
        }
        try validate(data)
        return data
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.keychain(status)
        }
    }
}
