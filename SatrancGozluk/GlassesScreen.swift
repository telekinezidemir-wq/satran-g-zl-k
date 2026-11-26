import Foundation
import MWDATCore
import MWDATDisplay

/// Gözlüğün ekranı. Her gönderim ekranın tamamını değiştirir (kısmi güncelleme yok),
/// bu yüzden durum her değiştiğinde tüm görünüm yeniden gönderilir.
@MainActor
final class GlassesScreen {
  private weak var model: AppModel?
  private var display: Display?
  private var ready = false
  private var tokens = ListenerTokenBag()
  private var sending = false
  private var resendPending = false

  init(model: AppModel) {
    self.model = model
  }

  /// Ekran yeteneğini oturuma ekler (zaten ekliyse ve açıksa bir şey yapmaz).
  func attachIfNeeded(to session: DeviceSession) {
    if let display, display.state == .started || display.state == .starting { return }
    detach()
    do {
      let newDisplay = try session.addDisplay()
      display = newDisplay
      newDisplay.statePublisher.listen { [weak self] state in
        Task { @MainActor in self?.stateChanged(state) }
      }.store(in: tokens)
      newDisplay.start()
    } catch {
      model?.errorText = "Gözlük ekranı eklenemedi: \(error)"
    }
  }

  func detach() {
    ready = false
    display = nil
    let old = tokens
    tokens = ListenerTokenBag()
    Task { await old.cancelAll() }
  }

  private func stateChanged(_ state: DisplayState) {
    switch state {
    case .started:
      ready = true
      refresh()
    case .stopped:
      ready = false
    default:
      break
    }
  }

  /// Güncel durumu gözlüğe çiz.
  func refresh() {
    guard ready, let display, let model else { return }
    if sending { resendPending = true; return }
    sending = true
    let view = makeView(model)
    Task {
      do {
        try await display.send(view)
      } catch {
        model.errorText = "Gözlüğe gönderilemedi: \(error)"
      }
      self.sending = false
      if self.resendPending {
        self.resendPending = false
        self.refresh()
      }
    }
  }

  private func makeView(_ model: AppModel) -> FlexBox {
    let side = model.playWhite ? "Ben: Beyaz" : "Ben: Siyah"
    let headline: String
    let detail: String
    let meta: String
    if model.busy {
      headline = "…"
      detail = model.phase
      meta = side
    } else if let a = model.analysis, let san = a.san {
      headline = san
      detail = a.desc ?? ""
      meta = [a.evalText, "derinlik \(a.depth ?? 0)", side].joined(separator: " · ")
    } else if let a = model.analysis, let res = a.result {
      headline = res
      detail = "Oyun bitti."
      meta = side
    } else {
      headline = "♞ Satranç Asistanı"
      detail = model.phase
      meta = side
    }
    let note = model.recognitionNote

    return FlexBox(direction: .column, spacing: 12) {
      FlexBox(direction: .column, spacing: 6) {
        Text(headline, style: .heading)
        Text(detail, style: .body)
        Text(meta, style: .meta, color: .secondary)
        if !note.isEmpty && !model.busy {
          Text(note, style: .meta, color: .secondary)
        }
      }
      .padding(24)
      .background(.card)

      FlexBox(direction: .row, spacing: 8, alignment: .center, crossAlignment: .center) {
        ButtonGroup {
          Button(label: "Tahtayı oku", style: .primary, onClick: { [weak model] in
            Task { @MainActor in model?.captureFromGlasses() }
          })
          Button(label: model.playWhite ? "Siyah ol" : "Beyaz ol", style: .secondary, onClick: { [weak model] in
            Task { @MainActor in model?.toggleSide() }
          })
        }
      }
    }
  }
}
