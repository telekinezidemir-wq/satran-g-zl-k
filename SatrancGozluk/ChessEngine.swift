import Foundation
import JavaScriptCore

/// Motorun cevabı (JavaScript'ten JSON olarak gelir).
struct Analysis: Decodable, Sendable {
  var san: String?
  var uci: String?
  var desc: String?
  var cp: Int?
  var mate: Int?
  var depth: Int?
  var error: String?
  var result: String?

  /// "+0.4 · denge" / "Beyaz 2 hamlede mat eder"
  var evalText: String {
    if let mate { return (mate > 0 ? "Beyaz" : "Siyah") + " \(abs(mate)) hamlede mat eder" }
    let c = cp ?? 0
    let a = abs(c)
    let who = c > 0 ? "Beyaz" : "Siyah"
    let score = String(format: "%@%.1f", c > 0 ? "+" : "", Double(c) / 100)
    let word = a < 30 ? "denge" : a < 150 ? "\(who) hafif üstün" : a < 400 ? "\(who) üstün" : "\(who) çok üstün"
    return "\(score) · \(word)"
  }
}

/// Web sürümündeki motorun aynısı, JavaScriptCore içinde.
enum ChessEngine {
  /// Seviye → (derinlik, süre ms) — web sürümüyle aynı.
  static let levels: [Int: (Int, Int)] = [1: (1, 200), 2: (2, 500), 3: (4, 1000), 4: (6, 2200), 5: (9, 4500)]

  /// Her çağrıda yeni bir JSContext (iş parçacığı güvenliği için). Ana iş parçacığında çağırmayın.
  static func analyze(fen: String, depth: Int, ms: Int) -> Analysis {
    guard let ctx = JSContext() else { return Analysis(error: "motor başlatılamadı") }
    var jsError: String?
    ctx.exceptionHandler = { _, value in jsError = value?.toString() }
    ctx.evaluateScript(engineJavaScript)
    if let jsError { return Analysis(error: "motor yüklenemedi: \(jsError)") }
    let fn = ctx.objectForKeyedSubscript("analyze")
    let out = fn?.call(withArguments: [fen, ms, depth])?.toString() ?? ""
    if let jsError { return Analysis(error: "motor hatası: \(jsError)") }
    guard let data = out.data(using: .utf8),
      let result = try? JSONDecoder().decode(Analysis.self, from: data)
    else { return Analysis(error: "motorun cevabı okunamadı") }
    return result
  }
}
