import UIKit
import Flutter

@UIApplicationMain
@objc class GeneratedPluginRegistrant: NSObject {
 public static func register(with registry: FlutterPluginRegistry) {
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
