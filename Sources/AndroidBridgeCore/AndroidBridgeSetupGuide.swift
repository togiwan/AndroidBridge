import Foundation

public struct SetupGuideSection: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let steps: [SetupGuideStep]

    public init(id: String, title: String, body: String, steps: [SetupGuideStep]) {
        self.id = id
        self.title = title
        self.body = body
        self.steps = steps
    }
}

public struct SetupGuideStep: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let command: String?

    public init(id: String, title: String, body: String, command: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.command = command
    }
}

public enum AndroidBridgeSetupGuide {
    public static let platformToolsURL = URL(string: "https://developer.android.com/tools/releases/platform-tools")!
    public static let adbDocsURL = URL(string: "https://developer.android.com/tools/adb")!

    public static let sections: [SetupGuideSection] = [
        SetupGuideSection(
            id: "platform-tools",
            title: "1. Mac'e Android Platform-Tools kur",
            body: "AndroidBridge, telefona ADB ile erişir. ADB, Google'ın Android SDK Platform-Tools paketinin içindedir.",
            steps: [
                SetupGuideStep(
                    id: "homebrew",
                    title: "Kolay yol: Homebrew ile kur",
                    body: "Terminal'i aç ve şu komutu çalıştır. Kurulum bittikten sonra AndroidBridge'i yeniden aç.",
                    command: "brew install android-platform-tools"
                ),
                SetupGuideStep(
                    id: "official-zip",
                    title: "Alternatif yol: Google'ın resmi zip dosyası",
                    body: "Android SDK Platform-Tools for Mac paketini indir, zip'i aç ve çıkan platform-tools klasörünü sakla. Sonra Terminal'de o klasöre gidip ./adb devices ile test edebilirsin."
                ),
                SetupGuideStep(
                    id: "verify-adb",
                    title: "Kurulumu kontrol et",
                    body: "Terminal'de adb version veya adb devices yaz. Komut bulunamıyorsa platform-tools PATH'e eklenmemiştir.",
                    command: "adb devices"
                )
            ]
        ),
        SetupGuideSection(
            id: "phone-debugging",
            title: "2. Telefonda USB debugging aç",
            body: "Android'de USB debugging, Mac'in telefonla ADB üzerinden konuşmasına izin verir. Telefon kilidi açıkken yapılmalıdır.",
            steps: [
                SetupGuideStep(
                    id: "developer-options",
                    title: "Developer Options'ı görünür yap",
                    body: "Telefonda Settings > About phone bölümüne gir. Build number satırına genelde 7 kez dokun. PIN istenirse gir; ekranda artık geliştirici olduğuna dair mesaj çıkar."
                ),
                SetupGuideStep(
                    id: "enable-usb-debugging",
                    title: "USB debugging'i aç",
                    body: "Settings içinde Developer Options bölümünü aç. Android sürümüne göre System > Advanced > Developer Options altında olabilir. USB debugging anahtarını aç."
                ),
                SetupGuideStep(
                    id: "security-note",
                    title: "Güvenlik notu",
                    body: "USB debugging'i sadece güvendiğin Mac'lerde kullan. İşin bitince Developer Options içinden kapatabilirsin."
                )
            ]
        ),
        SetupGuideSection(
            id: "connect",
            title: "3. Telefonu bağla ve izin ver",
            body: "İlk bağlantıda telefon Mac'i yetkilendirmek için güven penceresi gösterir.",
            steps: [
                SetupGuideStep(
                    id: "cable",
                    title: "Veri aktarabilen USB kablosu kullan",
                    body: "Bazı kablolar sadece şarj eder. Telefon görünmüyorsa farklı bir kablo veya port dene."
                ),
                SetupGuideStep(
                    id: "rsa",
                    title: "RSA güven penceresini onayla",
                    body: "Telefon kilidini aç. 'Allow USB debugging?' veya RSA fingerprint penceresi gelirse Allow seç. Kendi Mac'inse 'Always allow from this computer' işaretlenebilir."
                ),
                SetupGuideStep(
                    id: "check-state",
                    title: "Bağlantıyı doğrula",
                    body: "Terminal'de adb devices çalıştır. Satırın sonunda device yazıyorsa hazır. unauthorized yazıyorsa telefondaki izin penceresini onayla. offline yazıyorsa kabloyu çıkarıp tak veya telefonu yeniden başlat.",
                    command: "adb devices"
                )
            ]
        ),
        SetupGuideSection(
            id: "use-app",
            title: "4. AndroidBridge ile dosya aktar",
            body: "Cihaz hazır olduğunda AndroidBridge'de Refresh Devices'a bas. Uygulama varsayılan olarak /sdcard/Download klasörünü açar.",
            steps: [
                SetupGuideStep(
                    id: "download",
                    title: "Telefondan Mac'e indir",
                    body: "Telefondaki dosyayı seç ve Download'a bas. Dosya Mac'teki Downloads klasörüne iner."
                ),
                SetupGuideStep(
                    id: "upload",
                    title: "Mac'ten telefona gönder",
                    body: "Telefonda hedef klasöre gir, Upload'a bas ve Mac'ten bir dosya seç. Dosya açık olan Android klasörüne gönderilir."
                )
            ]
        )
    ]
}
