import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    registerCallChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Screen handling during calls: proximity sensor for earpiece audio,
  // keep-screen-on for video.
  private func registerCallChannel() {
    guard let registrar = self.registrar(forPlugin: "ChatspotCallChannel") else { return }
    let channel = FlutterMethodChannel(name: "chatspot/call", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      let enabled = (call.arguments as? Bool) ?? false
      switch call.method {
      case "setProximitySensor":
        UIDevice.current.isProximityMonitoringEnabled = enabled
        result(nil)
      case "setKeepScreenOn":
        UIApplication.shared.isIdleTimerDisabled = enabled
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
