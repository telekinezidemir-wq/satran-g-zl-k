# Satranç Asistanı — Meta Ray-Ban Display (iPhone)

Gözlüğün kamerasıyla tahtanın (gerçek tahta ya da bilgisayar ekranı) fotoğrafını çeker,
Claude ile taşların dizilişini okur, telefondaki motorla en iyi hamleyi bulur ve gözlüğün ekranına yazar.
Kendi analizleriniz ve bilgisayara karşı oyunlar için.

Mac gerekmez: uygulama GitHub'ın Mac sunucusunda derlenir, Windows'tan Sideloadly ile iPhone'a yüklenir.

## 1. GitHub'da derle

1. github.com'da ücretsiz hesap açın → sağ üstte **+ → New repository** → ad: `satranc-gozluk`,
   **Public** seçin (Mac sunucusu public depolarda ücretsiz) → **Create repository**.
2. Açılan sayfada **uploading an existing file** bağlantısına tıklayın. Bu klasörün **içindekileri**
   (`project.yml`, `README.md`, `SatrancGozluk` klasörü, `.github` klasörü) sürükleyip bırakın → **Commit changes**.
   - Windows `.github` klasörünü göstermiyorsa: depoda **Add file → Create new file**, ad olarak
     `.github/workflows/build.yml` yazın, bu dosyanın içeriğini yapıştırıp kaydedin.
3. Depoda **Actions** sekmesi → **iPhone uygulamasını derle** → **Run workflow**. 10–15 dakika sürer.
4. Bitince (yeşil tik) çalışmaya tıklayın, en altta **Artifacts → SatrancGozluk-ipa** indirin, zip'i açın:
   içinden `SatrancGozluk.ipa` çıkar.
   - Kırmızı çarpı çıkarsa: **Derleme hataları** adımındaki yazıları kopyalayıp Claude'a gönderin.

## 2. Windows'tan iPhone'a yükle (Sideloadly)

1. Apple'ın sitesinden **iTunes** ve **iCloud**'u kurun (Microsoft Store sürümü değil, apple.com'daki sürüm).
2. **sideloadly.io**'dan Sideloadly'yi kurun.
3. iPhone'u USB ile bağlayın, telefonda **Bu Bilgisayara Güven**'e basın.
4. Sideloadly'de `SatrancGozluk.ipa`'yı sürükleyin, Apple Kimliğinizi yazın → **Start**.
5. iPhone'da:
   - **Ayarlar → Gizlilik ve Güvenlik → Geliştirici Modu → Açık** (telefon yeniden başlar).
   - **Ayarlar → Genel → VPN ve Cihaz Yönetimi** → Apple Kimliğiniz → **Güven**.
6. Ücretsiz Apple hesabıyla yüklenen uygulama **7 gün** çalışır; sonra Sideloadly ile aynı adımı tekrarlayın.

## 3. Gözlüğü hazırla

1. Meta AI uygulaması → **Ayarlar → Uygulama Bilgisi** → **Uygulama Sürümü**'ne 5 kez dokunun (Developer Mode).
2. Developer Mode açılınca Meta AI'ın istediği **Device Access Toolkit** kurulumunu gözlüğe yapın
   (Meta AI açık kalsın, 5–10 sn sürer).
3. Satranç Asistanı'nı açın:
   - **1. Gözlüğü kaydet** → Meta AI açılır, onaylayın, uygulamaya geri döner.
   - **Ayarlar**'a Claude API anahtarınızı girin (console.anthropic.com → API Keys).
   - **2. Gözlüğe bağlan** → kamera izni için Meta AI açılabilir, onaylayın.
4. Gözlükte "Satranç Asistanı" kartı ve **Tahtayı oku** düğmesi görünür. Hamle sırası sizdeyken tahtaya bakın,
   bileklikle **Tahtayı oku**'ya çimdikleyin.

Gözlüksüz denemek için: **Telefondan fotoğraf seç** ile bir tahta fotoğrafı seçin.
Tanıma yanlışsa telefonda FEN'i düzeltip **Bu pozisyonu yeniden hesapla**'ya basın.
