import Flutter
import UIKit
import FirebaseCore
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let notificationsChannel = FlutterMethodChannel(
        name: "com.fruitcarepro/notifications",
        binaryMessenger: controller.binaryMessenger
      )
      notificationsChannel.setMethodCallHandler { call, result in
        guard call.method == "clearNotificationsForThread",
              let args = call.arguments as? [String: Any],
              let threadId = args["chatId"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }

        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
          let idsToRemove = notifications
            .filter { $0.request.content.threadIdentifier == threadId }
            .map { $0.request.identifier }
          if !idsToRemove.isEmpty {
            UNUserNotificationCenter.current()
              .removeDeliveredNotifications(withIdentifiers: idsToRemove)
          }
          result(nil)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
