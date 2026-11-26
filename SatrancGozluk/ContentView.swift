import MWDATCore
import PhotosUI
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AppModel
  @State private var pickedItem: PhotosPickerItem?

  var body: some View {
    NavigationStack {
      Form {
        Section("Gözlük") {
          LabeledContent("Kayıt", value: registrationText)
          LabeledContent("Bağlantı", value: model.sessionText)
          LabeledContent("Kamera", value: model.isCameraReady ? "Hazır" : "Hazır değil")
          if model.registration != .registered {
            Button("1. Gözlüğü kaydet (Meta AI açılır)") { model.register() }
          }
          if model.isSessionActive {
            Button("Bağlantıyı kes", role: .destructive) { model.stopGlasses() }
          } else {
            Button("2. Gözlüğe bağlan") { model.startGlasses() }
              .disabled(model.registration != .registered)
          }
        }

        Section("Analiz") {
          Button {
            model.captureFromGlasses()
          } label: {
            Label("Tahtayı oku (gözlük kamerası)", systemImage: "eyeglasses")
          }
          .disabled(model.busy || !model.isCameraReady)

          PhotosPicker(selection: $pickedItem, matching: .images) {
            Label("Telefondan fotoğraf seç (test için)", systemImage: "photo")
          }
          .disabled(model.busy)

          HStack {
            if model.busy { ProgressView().padding(.trailing, 6) }
            Text(model.phase).font(.callout)
          }

          if let a = model.analysis, let san = a.san {
            VStack(alignment: .leading, spacing: 4) {
              Text(san).font(.system(size: 40, weight: .heavy)).foregroundStyle(.green)
              Text(a.desc ?? "")
              Text("\(a.evalText) · derinlik \(a.depth ?? 0)").font(.caption).foregroundStyle(.secondary)
            }
          } else if let res = model.analysis?.result {
            Text(res).font(.title2.bold())
          }

          if !model.recognitionNote.isEmpty {
            Text(model.recognitionNote).font(.caption).foregroundStyle(.orange)
          }

          if let photo = model.lastPhoto {
            Image(uiImage: photo)
              .resizable().scaledToFit()
              .frame(maxHeight: 220)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
        }

        Section {
          if let rows = BoardReader.expand(model.fen.components(separatedBy: " ").first ?? "") {
            BoardView(rows: rows, flipped: !model.playWhite)
              .frame(maxWidth: .infinity)
          }
          TextField("FEN", text: $model.fen, axis: .vertical)
            .font(.system(.footnote, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          Button("Bu pozisyonu yeniden hesapla") { model.analyzeCurrentFEN() }
            .disabled(model.busy || model.fen.isEmpty)
        } header: {
          Text("Okunan tahta")
        } footer: {
          Text("Tanıma hatalıysa FEN'i düzeltip yeniden hesaplatabilirsiniz.")
        }

        Section {
          SecureField("Claude API anahtarı (sk-ant-…)", text: $model.apiKey)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          TextField("Model", text: $model.modelName)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
          Picker("Benim tarafım", selection: $model.playWhite) {
            Text("Beyaz").tag(true)
            Text("Siyah").tag(false)
          }
          Stepper("Motor seviyesi: \(model.level)", value: $model.level, in: 1...5)
        } header: {
          Text("Ayarlar")
        } footer: {
          Text("Sıra her zaman sizde kabul edilir: hamle sırası sizdeyken tahtayı okutun.")
        }

        if !model.errorText.isEmpty {
          Section("Hata") {
            Text(model.errorText).foregroundStyle(.red).font(.callout)
          }
        }
      }
      .navigationTitle("Satranç Asistanı")
    }
    .onChange(of: pickedItem) { _, item in
      guard let item else { return }
      Task {
        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
          model.analyzePhoto(image)
        }
        pickedItem = nil
      }
    }
  }

  private var registrationText: String {
    switch model.registration {
    case .registered: return "Kayıtlı"
    case .registering: return "Kaydediliyor…"
    case .available: return "Kayıtlı değil"
    case .unavailable: return "Kullanılamıyor (Meta AI / Developer Mode?)"
    @unknown default: return "?"
    }
  }
}

/// Okunan tahtanın küçük çizimi (tanımayı kontrol etmek için).
struct BoardView: View {
  let rows: [[Character]]
  let flipped: Bool

  private static let glyph: [Character: String] = [
    "K": "♔", "Q": "♕", "R": "♖", "B": "♗", "N": "♘", "P": "♙",
    "k": "♚", "q": "♛", "r": "♜", "b": "♝", "n": "♞", "p": "♟",
  ]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(0..<8, id: \.self) { dr in
        HStack(spacing: 0) {
          ForEach(0..<8, id: \.self) { dc in
            let r = flipped ? 7 - dr : dr
            let c = flipped ? 7 - dc : dc
            ZStack {
              Rectangle().fill((r + c) % 2 == 0 ? Color(white: 0.93) : Color(red: 0.46, green: 0.59, blue: 0.34))
              Text(Self.glyph[rows[r][c]] ?? "")
                .font(.system(size: 26))
                .foregroundStyle(.black)
            }
            .frame(width: 36, height: 36)
          }
        }
      }
    }
    .border(Color.gray)
  }
}
