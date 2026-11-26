import MWDATCore
import SwiftUI

@main
struct SatrancGozlukApp: App {
  @StateObject private var model: AppModel

  init() {
    // Meta Wearables kitini uygulama açılırken bir kez yapılandır.
    do {
      try Wearables.configure()
    } catch {
      NSLog("[SatrancGozluk] Wearables.configure başarısız: \(error)")
    }
    _model = StateObject(wrappedValue: AppModel())
  }

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
        // Meta AI uygulaması kayıt/izin sonrası bu adresle geri döner.
        .onOpenURL { url in model.handleURL(url) }
    }
  }
}
