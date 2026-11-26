import Foundation
import UIKit

/// Fotoğraftaki satranç tahtasını Claude'un görüntü modeliyle okur ve taş dizilişini (FEN) çıkarır.
enum BoardReader {
  struct Result {
    let placement: String  // FEN'in ilk alanı: 8. sıradan 1. sıraya
    let note: String
  }

  enum ReadError: LocalizedError {
    case http(Int, String)
    case noBoard(String)
    case badAnswer(String)

    var errorDescription: String? {
      switch self {
      case .http(let code, let message):
        return code == 401
          ? "API anahtarı geçersiz (401). Ayarlardan kontrol edin."
          : "Claude API hatası \(code): \(message)"
      case .noBoard(let note):
        return "Fotoğrafta tahta bulunamadı. \(note)"
      case .badAnswer(let text):
        return "Tahta okunamadı: \(text)"
      }
    }
  }

  static func read(image: UIImage, apiKey: String, model: String, playerIsWhite: Bool) async throws -> Result {
    guard let jpeg = resized(image, maxSide: 1568).jpegData(compressionQuality: 0.85) else {
      throw ReadError.badAnswer("fotoğraf hazırlanamadı")
    }
    let side = playerIsWhite ? "White" : "Black"
    let prompt = """
      You read chess positions from photos. The photo shows a chess position: either a physical \
      board or a chess program on a computer/phone screen, taken from the player's point of view. \
      The player plays \(side), so the \(side.lowercased()) pieces are probably nearest to the camera, \
      unless the board's printed coordinates (a–h, 1–8) show otherwise — trust visible coordinates first. \
      On screens, white pieces are the light ones and black pieces the dark ones.
      Identify the piece on every square, carefully, rank by rank.
      Reply with ONLY one JSON object and nothing else:
      {"board": "<FEN piece-placement field from White's side: rank 8 first, rank 1 last, files a to h>", \
      "confident": true or false, "note": "<one short sentence in Turkish about anything unclear, or empty>"}
      If no chess board is visible, reply {"board": null, "confident": false, "note": "<Turkish reason>"}.
      """

    let body: [String: Any] = [
      "model": model,
      "max_tokens": 600,
      "messages": [
        [
          "role": "user",
          "content": [
            ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                          "data": jpeg.base64EncodedString()]],
            ["type": "text", "text": prompt],
          ],
        ]
      ],
    ]
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.timeoutInterval = 90
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)
    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
    let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    guard code == 200 else {
      let message = ((json?["error"] as? [String: Any])?["message"] as? String)
        ?? String(data: data, encoding: .utf8) ?? ""
      throw ReadError.http(code, String(message.prefix(200)))
    }
    let text = ((json?["content"] as? [[String: Any]]) ?? [])
      .compactMap { $0["text"] as? String }
      .joined()
    guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"),
      let obj = try? JSONSerialization.jsonObject(with: Data(text[start...end].utf8)) as? [String: Any]
    else {
      throw ReadError.badAnswer(String(text.prefix(120)))
    }
    let note = (obj["note"] as? String) ?? ""
    guard let board = obj["board"] as? String, !board.isEmpty else {
      throw ReadError.noBoard(note)
    }
    let cleaned = board.trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: " ").first ?? board
    guard expand(cleaned) != nil else {
      throw ReadError.badAnswer("geçersiz diziliş (\(cleaned))")
    }
    let confident = (obj["confident"] as? Bool) ?? true
    return Result(placement: cleaned, note: confident ? note : ("Emin değilim. " + note))
  }

  /// "rnbqkbnr/pppppppp/8/..." → 8×8 karakter (boş kare ".")
  static func expand(_ placement: String) -> [[Character]]? {
    let ranks = placement.split(separator: "/")
    guard ranks.count == 8 else { return nil }
    var rows: [[Character]] = []
    for rank in ranks {
      var row: [Character] = []
      for ch in rank {
        if let n = ch.wholeNumberValue {
          row += Array(repeating: ".", count: n)
        } else if "prnbqkPRNBQK".contains(ch) {
          row.append(ch)
        } else {
          return nil
        }
      }
      guard row.count == 8 else { return nil }
      rows.append(row)
    }
    return rows
  }

  /// Tam FEN: sıra kullanıcıda; rok hakları şah/kale başlangıç karelerindeyse varsayılır.
  static func makeFEN(placement: String, whiteToMove: Bool) -> String {
    var castling = ""
    if let rows = expand(placement) {
      if rows[7][4] == "K" {
        if rows[7][7] == "R" { castling += "K" }
        if rows[7][0] == "R" { castling += "Q" }
      }
      if rows[0][4] == "k" {
        if rows[0][7] == "r" { castling += "k" }
        if rows[0][0] == "r" { castling += "q" }
      }
    }
    return "\(placement) \(whiteToMove ? "w" : "b") \(castling.isEmpty ? "-" : castling) - 0 1"
  }

  private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let size = image.size
    let scale = min(1, maxSide / max(size.width, size.height))
    let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: target, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
