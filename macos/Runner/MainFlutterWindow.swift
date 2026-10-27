import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let backgroundChannel = FlutterMethodChannel(
      name: "com.cinemaradar.app/background_access",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    backgroundChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getStatus":
        if #available(macOS 13.0, *) {
          let status = SMAppService.mainApp.status
          result([
            "loginItemEnabled": status == .enabled,
            "settingsAvailable": true,
            "scheduledBackgroundSupported": true,
          ])
        } else {
          result([
            "loginItemEnabled": false,
            "settingsAvailable": false,
            "scheduledBackgroundSupported": true,
          ])
        }
      case "enablePersistentBackground":
        if #available(macOS 13.0, *) {
          do {
            if SMAppService.mainApp.status == .notRegistered {
              try SMAppService.mainApp.register()
            }
            result(SMAppService.mainApp.status == .enabled)
          } catch {
            result(false)
          }
        } else {
          result(false)
        }
      case "openBackgroundSettings", "openAppSettings":
        if #available(macOS 13.0, *) {
          SMAppService.openSystemSettingsLoginItems()
          result(true)
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
