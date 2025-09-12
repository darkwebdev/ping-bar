import SwiftUI

@main struct
PingBar: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  var body: some Scene {
    Settings {
      Text("Settings or main app window")
    }
  }
}
