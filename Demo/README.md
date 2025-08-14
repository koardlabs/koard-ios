# KoardMerchantSDK Demo Configuration

## Setup

To run the demo app, you need to configure your API credentials:

1. **Copy the template file:**
   ```bash
   cp KoardMerchantSDK-Demo/Config.plist.template KoardMerchantSDK-Demo/Config.plist
   ```

2. **Edit the configuration:**
   Open `KoardMerchantSDK-Demo/Config.plist` and replace the placeholder values:
   - `YOUR_API_KEY_HERE` - Your Koard API key
   - `YOUR_MERCHANT_CODE_HERE` - Your merchant code
   - `YOUR_MERCHANT_PIN_HERE` - Your merchant PIN

3. **Add to Xcode project:**
   - Open the Demo project in Xcode
   - Drag `Config.plist` into the project navigator
   - Ensure it's added to the app target
   - **Important:** The app will crash on startup if Config.plist is missing or contains template values

The demo app automatically reads credentials from Config.plist at startup. If the file is missing or contains placeholder values, the app will display an error message and fail to initialize.

## Security Notes

- `Config.plist` is gitignored to prevent accidentally committing credentials
- Never commit the actual `Config.plist` file to version control
- Only commit the `Config.plist.template` file for reference
- Consider using environment variables or secure credential management in production

## Configuration Format

The `Config.plist` file should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>apiKey</key>
    <string>your_api_key</string>
    <key>merchantCode</key>
    <string>your_merchant_code</string>
    <key>merchantPin</key>
    <string>your_merchant_pin</string>
</dict>
</plist>
```