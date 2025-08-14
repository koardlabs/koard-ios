import Foundation

struct AppConfiguration {
    let apiKey: String
    let merchantCode: String  
    let merchantPin: String
}

class ConfigurationManager {
    static func loadConfiguration() -> AppConfiguration? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            print("Config.plist file not found. Please copy Config.plist.template to Config.plist and fill in your credentials.")
            return nil
        }
        
        guard let apiKey = plist["apiKey"] as? String,
              let merchantCode = plist["merchantCode"] as? String,
              let merchantPin = plist["merchantPin"] as? String else {
            print("Invalid Config.plist format. Missing required keys: apiKey, merchantCode, merchantPin")
            return nil
        }
        
        guard !apiKey.contains("YOUR_API_KEY_HERE"),
              !merchantCode.contains("YOUR_MERCHANT_CODE_HERE"),
              !merchantPin.contains("YOUR_MERCHANT_PIN_HERE") else {
            print("Please update Config.plist with your actual credentials. Template values detected.")
            return nil
        }
        
        return AppConfiguration(
            apiKey: apiKey,
            merchantCode: merchantCode,
            merchantPin: merchantPin
        )
    }
}