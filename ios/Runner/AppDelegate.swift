import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let telegramChannel = FlutterMethodChannel(name: "com.example.uztexsoftclients/telegram",
                                               binaryMessenger: controller.binaryMessenger)

    telegramChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "openTelegram" {
        if let args = call.arguments as? [String: Any],
           let url = args["url"] as? String {
          if let telegramUrl = URL(string: url) {
            if UIApplication.shared.canOpenURL(telegramUrl) {
              UIApplication.shared.open(telegramUrl, options: [:], completionHandler: nil)
              result(true)
            } else {
              result(FlutterError(code: "UNAVAILABLE",
                                  message: "Telegram is not installed or the URL is invalid",
                                  details: nil))
            }
          }
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT",
                              message: "Expected URL as argument",
                              details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
