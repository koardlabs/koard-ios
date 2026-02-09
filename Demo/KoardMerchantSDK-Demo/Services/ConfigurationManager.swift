import Foundation

struct AppConfiguration {
    let apiKey: String
    let environment: String
    let customURL: String?
    let merchantCode: String?
    let merchantPin: String?
}

class ConfigurationManager {
    private static let configFileKey = "KoardSDK_ConfigFile"

    static func loadConfiguration() -> AppConfiguration? {
        // First check if Xcode set an environment variable (only works when running from Xcode)
        let xcodeEnv = ProcessInfo.processInfo.environment["KOARD_ENV"]

        // Determine which config file to use:
        // 1. If running from Xcode with KOARD_ENV set, use that and persist it
        // 2. Otherwise, use the persisted config file name from last run
        let configFileName: String
        if let xcodeEnv = xcodeEnv, !xcodeEnv.isEmpty {
            // Running from Xcode - use the scheme's environment variable
            switch xcodeEnv.uppercased() {
            case "PRODUCTION", "PROD":
                configFileName = "Config-Production"
            case "PRODUCTION_CUSTOM":
                configFileName = "Config-ProductionCustom"
            case "UAT", "STAGING":
                configFileName = "Config-UAT"
            case "DEV", "DEVELOPMENT":
                configFileName = "Config-Dev"
            default:
                configFileName = "Config-UAT"
            }
            // Persist this choice so it survives app restarts without Xcode
            UserDefaults.standard.set(configFileName, forKey: configFileKey)
            print("[ConfigurationManager] Running from Xcode with \(xcodeEnv), using \(configFileName)")
        } else {
            // Not running from Xcode - use persisted config file
            configFileName = UserDefaults.standard.string(forKey: configFileKey) ?? "Config-UAT"
            print("[ConfigurationManager] Not running from Xcode, using persisted config: \(configFileName)")
        }

        // Load the config file
        guard let path = Bundle.main.path(forResource: configFileName, ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            print("[ConfigurationManager] ERROR: \(configFileName).plist not found!")
            return nil
        }

        guard let apiKey = plist["apiKey"] as? String else {
            print("[ConfigurationManager] ERROR: Missing apiKey in \(configFileName).plist")
            return nil
        }

        guard let environment = plist["environment"] as? String else {
            print("[ConfigurationManager] ERROR: Missing environment in \(configFileName).plist")
            return nil
        }

        let customURL = plist["customURL"] as? String

        print("[ConfigurationManager] Loaded config: environment=\(environment), hasCustomURL=\(customURL != nil)")

        return AppConfiguration(
            apiKey: apiKey,
            environment: environment,
            customURL: customURL,
            merchantCode: nil,
            merchantPin: nil
        )
    }
}
