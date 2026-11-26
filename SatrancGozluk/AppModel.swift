import Combine
import Foundation
import MWDATCamera
import MWDATCore
import UIKit

/// Uygulamanın beyni: gözlük bağlantısı, kamera, ekran, tahta tanıma ve motor.
/// (SwiftUI burada içe aktarılmıyor: MWDATDisplay'deki Text/Button adlarıyla çakışmasın.)
@MainActor
final class AppModel: ObservableObject {
  // MARK: - Ekranda görünen durum
  @Published var registration: RegistrationState = .unavailable
  @Published var sessionText = "Bağlı değil"
  @Published var phase = "Gözlüğe bağlanın, sonra tahtaya bakıp “Tahtayı oku”ya basın."
  @Published var errorText = ""
  @Published var lastPhoto: UIImage?
  @Published var fen = ""
  @Published var recognitionNote = ""
  @Published var analysis: Analysis?
  @Published var busy = false
  @Published var isSessionActive = false
  @Published var isCameraReady = false

  // MARK: - Ayarlar (telefonda saklanır)
  @Published var apiKey: String { didSet { defaults.set(apiKey, forKey: "apiKey") } }
  @Published var modelName: String { didSet { defaults.set(modelName, forKey: "modelName") } }
  @Published var playWhite: Bool {
    didSet { defaults.set(playWhite, forKey: "playWhite"); glasses.refresh() }
  }
  @Published var level: Int { didSet { defaults.set(level, forKey: "level") } }

  private let defaults = UserDefaults.standard
  let wearables: any WearablesInterface = Wearables.shared
  private var session: DeviceSession?
  private var camera: Camera?
  private var tokens = ListenerTokenBag()
  private var sessionTasks: [Task<Void, Never>] = []
  private var registrationTask: Task<Void, Never>?
  private var photoTimeout: Task<Void, Never>?
  private(set) var glasses: GlassesScreen!

  init() {
    apiKey = defaults.string(forKey: "apiKey") ?? ""
    modelName = defaults.string(forKey: "modelName") ?? "claude-opus-5-5"
    playWhite = (defaults.object(forKey: "playWhite") as? Bool) ?? true
    level = (defaults.object(forKey: "level") as? Int) ?? 3
    glasses = GlassesScreen(model: self)
    registration = wearables.registrationState
    let stream = wearables.registrationStateStream()
    registrationTask = Task { [weak self] in
      for await state in stream {
        self?.registration = state
      }
    }
  }

  // MARK: - Kayıt (Meta AI uygulaması üzerinden)

  func handleURL(_ url: URL) {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
      parts.queryItems?.contains(where: { $0.name == "metaWearablesAction" }) == true
    else { return }
    Task {
      do {
        _ = try await wearables.handleUrl(url)
      } catch {
        errorText = "Meta AI dönüşü işlenemedi: \(error)"
      }
    }
  }

  func register() {
    errorText = ""
    Task {
      do {
        try await wearables.startRegistration()
      } catch {
        errorText = "Kayıt başlatılamadı: \(error)"
      }
    }
  }

  func unregister() {
    Task {
      do { try await wearables.startUnregistration() } catch { errorText = "Kayıt silinemedi: \(error)" }
    }
  }

  // MARK: - Gözlük oturumu: kamera + ekran

  func startGlasses() {
    guard session == nil else { return }
    errorText = ""
    Task {
      // Kamera izni Meta AI uygulamasından istenir (gerekirse oraya yönlendirir).
      do {
        if try await wearables.checkPermissionStatus(.camera) != .granted {
          guard try await wearables.requestPermission(.camera) == .granted else {
            errorText = "Gözlük kamerası için izin verilmedi."
            return
          }
        }
      } catch {
        errorText = "Kamera izni kontrol edilemedi: \(error)"
        return
      }

      do {
        let selector = AutoDeviceSelector(wearables: wearables, filter: { $0.supportsDisplay() })
        let newSession = try wearables.createSession(deviceSelector: selector)
        session = newSession
        sessionText = "Bağlanıyor…"
        let states = newSession.stateStream()
        let errors = newSession.errorStream()
        sessionTasks.append(Task { [weak self] in
          for await state in states { self?.sessionChanged(state) }
        })
        sessionTasks.append(Task { [weak self] in
          for await error in errors { self?.errorText = "Oturum hatası: \(error)" }
        })
        try newSession.start()
      } catch {
        session = nil
        sessionText = "Bağlı değil"
        errorText = "Gözlük oturumu açılamadı: \(error)"
      }
    }
  }

  func stopGlasses() {
    session?.stop()
  }

  private func sessionChanged(_ state: DeviceSessionState) {
    switch state {
    case .starting:
      sessionText = "Bağlanıyor…"
    case .started:
      sessionText = "Bağlandı"
      isSessionActive = true
      attachCamera()
    case .paused:
      sessionText = "Duraklatıldı"
    case .stopping:
      sessionText = "Kapanıyor…"
    case .stopped:
      cleanupSession()
    default:
      break
    }
  }

  private func cleanupSession() {
    for task in sessionTasks { task.cancel() }
    sessionTasks = []
    let oldTokens = tokens
    tokens = ListenerTokenBag()
    Task { await oldTokens.cancelAll() }
    camera = nil
    session = nil
    glasses.detach()
    isSessionActive = false
    isCameraReady = false
    sessionText = "Bağlı değil"
  }

  /// Kamera akışı açılır (düşük hız: sadece kamerayı uyanık tutmak için);
  /// fotoğraf bu akıştan JPEG olarak alınır.
  private func attachCamera() {
    guard camera == nil, let session else { return }
    let config = StreamConfiguration(videoCodec: .hvc1, resolution: .medium, frameRate: 7)
    do {
      guard let cam = try session.addCamera(config: config) else {
        errorText = "Gözlük kamerası eklenemedi."
        return
      }
      camera = cam
      cam.stream.statePublisher.listen { [weak self] state in
        Task { @MainActor in self?.streamChanged(state) }
      }.store(in: tokens)
      cam.stream.photoDataPublisher.listen { [weak self] photo in
        let data = photo.data
        Task { @MainActor in self?.gotPhoto(data) }
      }.store(in: tokens)
      cam.stream.errorPublisher.listen { [weak self] error in
        let text = "\(error)"
        Task { @MainActor in self?.cameraError(text) }
      }.store(in: tokens)
      cam.stream.start()
    } catch {
      errorText = "Gözlük kamerası eklenemedi: \(error)"
    }
  }

  private func streamChanged(_ state: StreamState) {
    switch state {
    case .streaming:
      isCameraReady = true
      // Cihaz gerçekten hazır: ekranı şimdi ekle (Meta örneğindeki sıra).
      if let session { glasses.attachIfNeeded(to: session) }
    case .stopped:
      isCameraReady = false
      camera = nil
      // Oturum hâlâ açıksa kamerayı yeniden iste.
      if isSessionActive {
        Task {
          try? await Task.sleep(nanoseconds: 1_000_000_000)
          self.attachCamera()
        }
      }
    default:
      isCameraReady = false
    }
  }

  private func cameraError(_ text: String) {
    if busy, phase.hasPrefix("Fotoğraf") {
      finish(error: "Fotoğraf çekilemedi (\(text)). Tekrar deneyin.")
    } else {
      errorText = "Kamera: \(text)"
    }
  }

  // MARK: - Tahtayı oku → tanı → hesapla

  /// Gözlükteki ya da telefondaki "Tahtayı oku" düğmesi.
  func captureFromGlasses() {
    guard !busy else { return }
    guard let cam = camera, isCameraReady else {
      phase = "Gözlük kamerası hazır değil. Telefonda “Gözlüğe bağlan”a basın."
      glasses.refresh()
      return
    }
    busy = true
    errorText = ""
    phase = "Fotoğraf çekiliyor…"
    glasses.refresh()
    guard cam.stream.capturePhoto(format: .jpeg) else {
      finish(error: "Fotoğraf çekilemedi. Tekrar deneyin.")
      return
    }
    photoTimeout?.cancel()
    photoTimeout = Task {
      try? await Task.sleep(nanoseconds: 20_000_000_000)
      if !Task.isCancelled, self.busy, self.phase == "Fotoğraf çekiliyor…" {
        self.finish(error: "Fotoğraf gelmedi (zaman aşımı). Tekrar deneyin.")
      }
    }
  }

  private func gotPhoto(_ data: Data) {
    photoTimeout?.cancel()
    guard let image = UIImage(data: data) else {
      finish(error: "Fotoğraf okunamadı.")
      return
    }
    // Fotoğraf aktarımı bazen ekranı kapatır: gerekirse yeniden bağla.
    if let session { glasses.attachIfNeeded(to: session) }
    analyzePhoto(image)
  }

  /// Telefondan seçilen bir fotoğraf (gözlüksüz test için) ya da gözlük fotoğrafı.
  func analyzePhoto(_ image: UIImage) {
    lastPhoto = image
    busy = true
    errorText = ""
    phase = "Tahta okunuyor…"
    analysis = nil
    glasses.refresh()
    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else {
      finish(error: "API anahtarı yok. Telefonda Ayarlar bölümüne Claude API anahtarını girin.")
      return
    }
    let side = playWhite
    let model = modelName
    Task {
      do {
        let read = try await BoardReader.read(image: image, apiKey: key, model: model, playerIsWhite: side)
        recognitionNote = read.note
        fen = BoardReader.makeFEN(placement: read.placement, whiteToMove: side)
        await runEngine()
      } catch {
        finish(error: "\(error.localizedDescription)")
      }
    }
  }

  /// Telefonda elle düzeltilen FEN için.
  func analyzeCurrentFEN() {
    guard !busy else { return }
    busy = true
    errorText = ""
    Task { await runEngine() }
  }

  private func runEngine() async {
    phase = "Hesaplanıyor…"
    glasses.refresh()
    let f = fen
    let (depth, ms) = ChessEngine.levels[level] ?? (4, 1000)
    let result = await Task.detached(priority: .userInitiated) {
      ChessEngine.analyze(fen: f, depth: depth, ms: ms)
    }.value
    if let err = result.error {
      finish(error: "Pozisyon hatalı: \(err). Telefonda FEN'i düzeltip tekrar deneyin.")
      return
    }
    analysis = result
    busy = false
    phase = result.result ?? "Önerim hazır."
    glasses.refresh()
  }

  private func finish(error: String) {
    busy = false
    phase = error
    errorText = error
    glasses.refresh()
  }

  func toggleSide() {
    playWhite.toggle()
  }
}
