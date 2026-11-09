# Zyxel-Local-Toolkit

**Zyxel modem ve router cihazları için yerel tanılama, yapılandırma yönetimi ve birlikte çalışabilirlik aracı**

[![Lisans: MIT](https://img.shields.io/badge/Lisans-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)](#-kullanım)
[![Sürüm: v1.0.0](https://img.shields.io/badge/Surum-v1.0.0-brightgreen.svg)](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases)
[![İndirme](https://img.shields.io/github/downloads/iamfahrig/Zyxel-Local-Toolkit/total?label=%C4%B0ndirme&color=blue)](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases)
[![Donanım](https://img.shields.io/badge/Donanım-Zyxel%20NR%20Serisi-green.svg)](#-desteklenen-donanım)

> 🌐 **Dil / Language:** &nbsp; [ **Türkçe** ](README_TR.md) &nbsp;•&nbsp; [ **English** ](README.md)

---

## 📌 Hakkında

Kullanıcının **kendi mülkiyetindeki** Zyxel cihazında, yerel ağ üzerinden tanılama, yapılandırma yedekleme/geri yükleme ve bağımsız yönetim yapmasını sağlayan açık kaynaklı bir araçtır.

Harici sunucu veya telemetri yoktur; tüm trafik yalnızca modemin yerel IP adresiyle gerçekleşir. Amaç, kullanıcının kendi donanımı üzerinde **birlikte çalışabilirlik** ve **bakım hakkını** kolaylaştırmaktır.

> ⚠️ **Önemli:** Bu araç yalnızca **size ait olan** cihazlarda kullanılmalıdır. ISP tarafından kiralanan/verilen cihazlarda kullanım, servis sağlayıcı sözleşmenizi ihlal edebilir. Sorumluluk tamamen kullanıcıya aittir.

---

## 📁 Proje Dosya Yapısı

```text
Zyxel-Local-Toolkit/
├── core/                  # Teşhis ve şifreleme motorları (PowerShell & Python)
│   ├── unlock.ps1         # Windows yerel teşhis motoru (sıfır bağımlılık)
│   └── unlock.py          # Linux & macOS yerel teşhis motoru
├── START.bat              # Windows başlatıcısı (çift tıkla çalıştır)
├── start.command          # macOS başlatıcısı (Finder üzerinden çift tıkla)
├── start.sh               # Linux başlatıcısı (terminal üzerinden çalıştır)
├── LICENSE                # MIT Lisansı
├── SECURITY.md            # Güvenlik politikası ve sorumlu ifşa
├── README.md              # İngilizce dokümantasyon
└── README_TR.md           # Türkçe dokümantasyon
```

---

## ⚡ Temel Özellikler

* `backup.bin` → okunabilir `zcfg_config.json` dönüşümü
* Düzenlenmiş JSON'u cihaz standartlarında geri yükleme
* AES-256-CBC + RSA-2048 hibrit oturum (`/UserLogin`) ile cihazın kendi giriş akışını kullanır
* SSH (22), Telnet (23), FTP (21) ve Web (80/443) servislerini etkinleştirme
* **Erişim kapsamı seçimi:** Varsayılan **yalnızca LAN** (güvenli); istenirse bilerek **LAN + WAN** seçilebilir
* TR-069, TR-369 ve MQTT uzak yönetim adreslerini `127.0.0.1`'e alarak dış yönetimi devre dışı bırakır
* Her işlemden önce otomatik, zaman damgalı yedekleme (`yedek_YYYY-MM-DD_HH-mm-ss/`)

---

## ⚙️ Nasıl Çalışır (Teknik Özet)

Araç, gizli hiçbir işlem yapmaz; tüm akış aşağıdaki gibidir:

1. **Kimlik doğrulama:** Cihazın web arayüzünün kullandığı hibrit şifreleme akışı taklit edilir. `/getRSAPublickKey` üzerinden RSA-2048 açık anahtarı alınır, rastgele bir AES-256 oturum anahtarı üretilir, giriş verisi AES-CBC ile şifrelenir, AES anahtarı RSA ile sarmalanıp `/UserLogin` adresine gönderilir. Başarısız olursa düz metin girişe geri düşer. Giriş için **sizin admin şifreniz** gereklidir.
2. **Yedek alma:** `/cgi-bin/Backup_Restore?action=Backup` ile şifreli `backup.bin` indirilir.
3. **Çözme:** ZCFG yedek biçimi, OpenSSL `EVP_BytesToKey` türetmesiyle elde edilen 3DES-CBC anahtarıyla çözülür ve JSON nesne modeline dönüştürülür.
4. **Düzenleme (yalnızca Mod 1):** İlgili yapılandırma alanları seçilen kapsama (LAN veya LAN+WAN) göre güncellenir.
5. **Paketleme ve geri yükleme:** JSON tekrar `.bin` biçimine paketlenir ve `/cgi-bin/Backup_Restore?action=Restore` ile cihaza yüklenir.

### Mod 1'in config üzerinde yaptığı değişiklikler

| Alan | Değişiklik | Amaç |
|:---|:---|:---|
| `X_ZYXEL_LoginCfg` | Yönetim sayfaları ve teşhis yetkileri açılır; `root`/`sUser` şifresi admin şifresine eşitlenir | Kabuk/FTP erişimi |
| `X_ZYXEL_RemoteManagement` | SSH/Telnet/FTP/Web servisleri seçilen kapsamda açılır (`Mode=LAN` veya `LAN_WAN`) | Yerel/uzak teşhis |
| `ManagementServer` | TR-069 (CWMP) kapatılır, URL `127.0.0.1:0`'a alınır | Dış yönetimi kesme |
| `LocalAgent` | TR-369 (USP) abonelik/kontrolcü servisleri pasifleştirilir | Dış telemetriyi kesme |
| `MQTT` | İstemci kapatılır, broker `127.0.0.1`'e yönlendirilir | Dış telemetriyi kesme |

---

<a id="-desteklenen-donanım"></a>
## 📋 Desteklenen Donanım

| Model Ailesi | Örnek / Test Edilen Modeller | Mimari | Durum |
|:---|:---|:---|:---|
| **NR Indoor Serisi** | **Zyxel NR5313** (Wi-Fi 7) | ZCFG / 5G Indoor | 🟢&nbsp;**Test Edildi & Doğrulandı** |
| **Wi-Fi 7 Serisi** | NR5307 · NR5331 · NR5731 · NR5333 | ZCFG Ortak WebAPI | 🔵&nbsp;**Platform Uyumlu** |
| **NR Indoor Serisi** | NR5103 · NR5101 · NR5103EV3 · NR5309 | ZCFG Ortak WebAPI | 🔵&nbsp;**Platform Uyumlu** |
| **NR Outdoor Serisi** | NR7101 · NR7102 · NR7103 · NR7301 · NR7501 | ZCFG Ortak WebAPI | 🟡&nbsp;**Topluluk Testine Açık** |
| **Gateway Serisi** | VMG3625 · VMG8623 · DX3301 · EX3300 · EX5401 | ZCFG Ortak WebAPI | 🟡&nbsp;**Topluluk Testine Açık** |

> Bu modeller aynı yazılım altyapısını kullandığı için büyük olasılıkla uyumludur. Kesin sonuç firmware sürümüne göre değişebilir.
> **Test ettiğiniz cihaz ve firmware sürümü hakkında bilgi vermek veya katkıda bulunmak isterseniz issue açabilirsiniz.**

---

<a id="-i̇ndirme"></a>
## 📥 İndirme

| Yöntem | Bağlantı / Komut | Açıklama |
|:---|:---|:---|
| **v1.0.0 Paketi (ZIP)** | [**Zyxel-Local-Toolkit-v1.0.0.zip İndir**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases/download/v1.0.0/Zyxel-Local-Toolkit-v1.0.0.zip) | Doğrulanmış resmi sürüm paketi |
| **En Güncel Kod (ZIP)** | [**Güncel ZIP Paketini İndir**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/archive/refs/heads/main.zip) | `main` dalındaki en son dosyalar |
| **GitHub Sürümleri** | [**Releases Sayfası**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases) | Paketlenmiş resmi sürümler ve notlar |
| **Git ile Klonlama** | `git clone https://github.com/iamfahrig/Zyxel-Local-Toolkit.git` | Geliştiriciler için |

> 🔐 **Bütünlük doğrulaması:** Her sürüm paketinin SHA-256 özeti ilgili Releases sayfasında yayınlanır. İndirdiğiniz dosyayı çalıştırmadan önce doğrulamanız önerilir:
> `sha256sum Zyxel-Local-Toolkit-v1.0.0.zip` (Linux/macOS) · `certutil -hashfile dosya.zip SHA256` (Windows)

---

<a id="-kullanım"></a>
## 🚀 Kullanım

### 1. Kurulum
1. İndirdiğiniz `Zyxel-Local-Toolkit.zip` arşivini bir klasöre çıkartın.
2. Bilgisayarınızı modeme **Ethernet** veya **Wi-Fi** ile bağlayın.
3. Modem yönetim şifrenizi hazır bulundurun (cihazın altındaki etikette yazar).

### 2. Çalıştırma
* **Windows:** **`START.bat`** dosyasına çift tıkla.
* **macOS:** **`start.command`** dosyasına çift tıkla.
* **Linux:** Terminal'de **`./start.sh`** çalıştır.

### 3. Mod Seçimi

| Mod | Ne Yapar? | İşlem Süresi & Cihaz Durumu |
|:---:|---|:---:|
| **1** | SSH/Telnet/FTP'yi etkinleştirir, uzak yönetimi kapatır (önce yedek alır) | ~90-120 sn (cihaz yeniden başlar) |
| **2** | Mevcut ayarları JSON olarak kaydeder | ~5 sn (cihaz yeniden başlamaz) |
| **3** | Düzenlediğin JSON'u cihaza yükler | ~90-120 sn (cihaz yeniden başlar) |

Mod 1'de araç ayrıca **erişim kapsamını** sorar:
* **[1] Yalnızca LAN (önerilen):** Servislere yalnızca yerel ağdan erişilir. Varsayılan ve güvenli seçenek.
* **[2] LAN + WAN (riskli):** Servisler internet tarafına da açılır. Yalnızca riski bilerek, özel bir ihtiyacınız varsa seçin.

Ardından modem IP'sini (varsayılan `192.168.1.1`) ve şifreni gir. Varsayılan giriş kullanıcı adı: **admin**

### 4. İşlem Sonrası
* **Mod 1 veya 3:** Cihaz yeniden başlar. Bağlantının oturması **90-120 saniye** sürer. Bu sürede fişi çekmeyin.
* **Mod 1 sonrası erişim (seçilen kapsama göre):**
  * **SSH:** `ssh root@192.168.1.1` (Port: 22, Şifre: modem web şifreniz)
  * **Web:** `http://192.168.1.1` (Kullanıcı: `admin`)
  * **FTP:** `ftp://192.168.1.1` (Port: 21)
  * **Telnet:** `telnet 192.168.1.1 23`
* **Hesap Rolleri (Mod 1 sonrası):**
  * `admin` → Varsayılan yetkili web hesabı
  * `root` → Yetkili kabuk (SSH) ve FTP hesabı
  * `sUser` → Yetkili sistem hesabı
* **Mod 2:** Cihaz yeniden başlamaz. `yedek_*/zcfg_config.json` dosyası oluşur.

---

## 🔄 Fabrika Ayarlarına Dönüş

* **Reset tuşu:** Arkadaki Reset deliğine **10-15 saniye** basılı tutun.
* **Web arayüzü:** Bakım → Yeniden Başlatma → Fabrika Ayarlarına Sıfırla.
* **Yedekten:** İlk alınan `zcfg_config.json` dosyasını Mod 3 ile geri yükleyin.

---

## 🔒 Güvenlik ve Gizlilik

* Tüm işlemler yerel ağda kalır; harici sunucu iletişimi yoktur.
* Mod 1 varsayılan olarak servisleri **yalnızca LAN** için açar. WAN'a açma yalnızca kullanıcının bilinçli seçimiyle gerçekleşir; sessizce yapılmaz.
* **⚠️ WAN'a açma riski:** LAN + WAN seçilirse SSH/Telnet/FTP internet tarafına açılır. Telnet ve FTP şifrelenmemiş protokollerdir; modemin dış IP'si varsa bu servisler dışarıdan erişilebilir hale gelir. Gerçekten gerekmedikçe LAN seçeneğinde kalın.
* **⚠️ Yedek dosyaları hassastır:** `backup.bin` ve `zcfg_config.json`, `root`/`sUser` hesap şifreleri dahil cihaz yapılandırmanızı içerir. Bu dosyaları **paylaşmayın** ve herkese açık bir yere (GitHub dahil) yüklemeyin. Depodaki `.gitignore` bu dosyaları hariç tutar.
* Parolanız bellekte geçici tutulur, araç tarafından ayrı bir dosyaya kaydedilmez.

---

## ⚖️ Yasal Çerçeve

Bu proje, kullanıcının kendi donanımı üzerinde **birlikte çalışabilirlik** ve **bakım hakkı** kapsamında yürütülen bir araştırma ve yazılım çalışmasıdır:

* **AB Yazılım Direktifi (2009/24/EC) Madde 6** — Birlikte çalışabilirlik amacıyla arayüz bilgilerinin incelenmesine ve uyarlanmasına izin verir.
* **ABD DMCA § 1201(f)** — Bağımsız geliştirilen yazılımların birlikte çalışabilmesi için tersine mühendislik muafiyeti tanır.
* **Onarım Hakkı (Right to Repair)** — Kullanıcının kendi mülkiyetindeki donanımı teşhis etme, yapılandırma ve bakımını yapma hakkını destekler.
* **Türk Fikir ve Sanat Eserleri Kanunu (FSEK) Madde 38** — Arayüz bilgilerinin elde edilmesi ve birlikte çalışabilirliğin sağlanması amacıyla yapılan işlemleri hukuka uygun kabul eder.

> **Telif ve Veri Beyanı:** Bu depoda kapalı kaynak firmware ikili dosyaları, ticari sırlar veya üçüncü şahıslara ait özel veriler bulunmaz. Araç yalnızca kullanıcının kendi yerel ağındaki cihazından elde ettiği yapılandırma nesneleri üzerinde lokal olarak çalışır.

### Feragatname
Bu yazılım **eğitim, araştırma ve birlikte çalışabilirlik** amacıyla sunulmaktadır. Yapılan işlemler cihazı üretici garantisi kapsamı dışına çıkarabilir ve ISP sözleşmenizi ihlal edebilir. Olası teknik, hukuki veya donanımsal sonuçlardan tamamen kullanıcı sorumludur. Araç; yetkisiz erişim, servis aksatma veya yasadışı kullanım amacıyla tasarlanmamıştır ve yalnızca kullanıcının sahibi olduğu cihazlarda kullanılmalıdır.

### Sorumlu İfşa
Projedeki teknik bulgular, cihazın yerel ağ ortamında bağımsız yönetilebilmesi amacıyla analiz edilmiştir. Güvenlikle ilgili bildirimler için [`SECURITY.md`](SECURITY.md) dosyasına bakınız.

---

## 🤝 Katkıda Bulunma

Test sonuçları, yeni model uyumlulukları ve hata bildirimleri memnuniyetle karşılanır. Issue açarken **cihaz modelini ve firmware sürümünü** belirtin. Yedek/yapılandırma dosyalarınızı (şifre içerdikleri için) issue veya PR'lara **eklemeyin**.

---

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) kapsamında yayınlanmaktadır.

---

*Son güncelleme: 2026*
