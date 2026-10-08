# ProjectKIR — iOS Simulator Build (GitHub Actions)

Bu klasör, ProjectKIR iOS uygulamasını **macOS bulut ortamında derleyip iOS Simulator'da açan** hazır bir GitHub Actions workflow içerir. Bu Linux sunucusunda Xcode/Simulator olmadığı için workflow'u doğrudan buradan çalıştıramıyoruz; ama sen GitHub'a push'ladıktan sonra workflow otomatik olarak `macos-14` (M1 Apple Silicon) runner'ında çalışır.

## Neler oluşuyor

1. `xcodebuild` ProjectKIR.xcodeproj'yu Debug konfigürasyonunda iOS Simulator için derler
2. Seçtiğin cihaz (varsayılan: iPhone 15 Pro) boot edilir
3. `ProjectKIR.app` simülatöre kurulur
4. Uygulama başlatılır (`com.placeholder.projectkir`)
5. 5-6 saniye render etmesi için beklenir
6. İlk ekran görüntüsü alınır (`screenshot.png`)
7. 5 saniyelik video kaydı alınır (`recording.mp4`)
8. İkinci ekran görüntüsü alınır (`screenshot-after-5s.png`)
9. Hepsi artifact olarak `ios-simulator-capture` adıyla yüklenir

## Adım adım yapman gerekenler

### 1. Git repo'yu hazırla

Bu klasörün kök dizinindeyken (yani `ProjectKIR.xcodeproj`'nun yanında):

```bash
cd /path/to/ProjectKIR-MVP/ProjectKIR
git init
git add .
git commit -m "ProjectKIR MVP — iOS Simulator workflow"
```

### 2. GitHub'da boş repo aç

- https://github.com/new adresine git
- Repo adı: `ProjectKIR` (veya istediğin herhangi bir isim)
- **Public** seç — macOS runner dakikaları public repo'larda **ücretsiz**
- "Add README" vs. **seçme** (zaten içeride var)
- "Create repository"

### 3. Push'la

```bash
git remote add origin https://github.com/SENINKULLANICIADIN/ProjectKIR.git
git branch -M main
git push -u origin main
```

### 4. Workflow'u tetikle

GitHub repo sayfasında:
- **Actions** sekmesine git
- Sol menüden "Build & Run iOS Simulator" workflow'unu seç
- Sağ üstte **"Run workflow"** butonuna bas
- Cihaz seç (iPhone 15 Pro önerilir) → "Run workflow" ile onayla

### 5. ~5-10 dk bekle

Build + boot + install + launch + capture yaklaşık 5-10 dakika sürer. Loglar gerçek zamanlı akar.

### 6. Artifact'leri indir

Build tamamlanınca, workflow sayfasında en altta **Artifacts** bölümünde `ios-simulator-capture` görünür. Tıkla → indir. ZIP içinde:

- `screenshot.png` — ilk açılış ekranı (Main Menu: "PROJECT KIR", "Yeni Oyun", "Ayarlar", "Jenerik")
- `recording.mp4` — 5 saniyelik video (parallax, amber sinyal ışığı, titreşim animasyonu)
- `screenshot-after-5s.png` — 5 saniye sonraki durum
- `build.log` — tam build logu (hata varsa burada görürsün)

## Olası sorunlar ve çözümleri

| Sorun | Çözüm |
|---|---|
| `scheme 'ProjectKIR' not found` | Bu repo ile birlikte gelen `xcshareddata/xcschemes/ProjectKIR.xcscheme` dosyasını kontrol et — commit'lediğinden emin ol |
| `iPhone 15 Pro` bulunamadı | macos-14 runner'ında bazen cihaz adları değişiyor. Workflow_dispatch ile `iPhone 14 Pro` veya `iPhone SE (3rd generation)` dene |
| Build hatası: `Module 'SpriteKit' not found` | Olmaz — SpriteKit macOS runner'da da Apple SDK'sıyla gelir. Olursa Actions logundan build.log'u indirip incele |
| App açıldı ama ekran siyah | `delay` input'unu 10-15 sn'ye çıkar (cihazın ilk boot'u yavaş olabilir) |
| macOS dakikam bitti | Private repo'lar için aylık 2000 dk (macOS 10x harcar = 200 dk). Public repo'larda sınırsız |

## Manuel yerel test (eğer Mac'in varsa)

Workflow'un yaptığı şeyin aynısı yerelde:

```bash
cd ProjectKIR
./build.sh run        # build.sh zaten var — ilk simülatörde çalıştırır
```

ya da açık adımlarla:

```bash
xcodebuild -project ProjectKIR.xcodeproj -scheme ProjectKIR -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
xcrun simctl boot "iPhone 15 Pro"
xcrun simctl install booted build/DerivedData/.../ProjectKIR.app
xcrun simctl launch booted com.placeholder.projectkir
xcrun simctl io booted screenshot menu.png
```

## Bundle ID değişikliği

Eğer `com.placeholder.projectkir` bundle ID'ini değiştirirsen (`Product Bundle Identifier` setting), workflow'taki `xcrun simctl launch` satırını da güncelle. Şu an `build-simulator.yml`'de sabit kodlanmış:
```yaml
xcrun simctl launch "$UDID" com.placeholder.projectkir
```
