# Zyxel-Local-Toolkit

**Zyxel modem ve router cihazları için yerel tanılama, yapılandırma yönetimi ve birlikte çalışabilirlik aracı**

[![Lisans: MIT](https://img.shields.io/badge/Lisans-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-blue.svg)](#kullanım)
[![Sürüm: v1.0.0](https://img.shields.io/badge/Surum-v1.0.0-brightgreen.svg)](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases)
[![Donanım](https://img.shields.io/badge/Donanım-Zyxel%20NR%20Serisi-green.svg)](#desteklenen-donanım)

> 🌐 **Dil / Language:** &nbsp; [ **Türkçe** ](README_TR.md) &nbsp;•&nbsp; [ **English** ](README.md)

---

## 📌 Hakkında

Kullanıcının kendi Zyxel cihazında yerel ağ üzerinden tanılama, yapılandırma yedekleme/geri yükleme ve bağımsız yönetim yapmasını sağlayan açık kaynaklı araçtır.  
Harici sunucu veya telemetri yoktur. Amacı, kullanıcının kendi donanımı üzerinde birlikte çalışabilirlik ve bakım hakkını kolaylaştırmaktır.

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
├── README.md              # İngilizce dokümantasyon
└── README_TR.md           # Türkçe dokümantasyon
```

---

## ⚡ Temel Özellikler

* `backup.bin` → okunabilir `zcfg_config.json` dönüşümü  
* Düzenlenmiş JSON’u cihaz standartlarında geri yükleme  
* AES-256-CBC + RSA-2048 hibrit oturum (`/UserLogin`)  
* SSH (22), Telnet (23), FTP (21) ve Web (80/443) servislerini yerel erişime açma  
* TR-069 ve TR-369 uzak yönetim adreslerini `127.0.0.1:0`’a alma  
* Otomatik zaman damgalı arşivleme (`yedek_YYYY-MM-DD_HH-mm-ss/`)  

---

<a id="desteklenen-donanım"></a>
## 📋 Desteklenen Donanım

| Model Ailesi | Örnek / Test Edilen Modeller | Mimari | Durum |
|:---|:---|:---|:---|
| **NR Indoor Serisi** | **Zyxel NR5313** (Wi-Fi 7) | ZCFG / 5G Indoor | 🟢&nbsp;**Test Edildi & Doğrulandı** |
| **Wi-Fi 7 Serisi** | NR5307 · NR5331 · NR5731 · NR5333 | ZCFG Ortak WebAPI | 🔵&nbsp;**Platform Uyumlu** |
| **NR Indoor Serisi** | NR5103 · NR5101 · NR5103EV3 · NR5309 | ZCFG Ortak WebAPI | 🔵&nbsp;**Platform Uyumlu** |
| **NR Outdoor Serisi** | NR7101 · NR7102 · NR7103 · NR7301 · NR7501 | ZCFG Ortak WebAPI | 🟡&nbsp;**Topluluk Testine Açık** |
| **Gateway Serisi** | VMG3625 · VMG8623 · DX3301 · EX3300 · EX5401 | ZCFG Ortak WebAPI | 🟡&nbsp;**Topluluk Testine Açık** |

> Bu modeller aynı yazılım altyapısını kullandığı için büyük olasılıkla uyumludur. Kesin sonuç firmware sürümüne göre değişebilir.  
> **Test ettiğiniz cihazlar hakkında bilgi vermek veya katkıda bulunmak isterseniz issue açabilirsiniz.**

---

<a id="indirme"></a>
## 📥 İndirme

Kullanıma hazır paketi aşağıdaki yöntemlerden biriyle edinebilirsiniz:

| Yöntem | Bağlantı / Komut | Açıklama |
|:---|:---|:---|
| **v1.0.0 Paketi (ZIP)** | [**Zyxel-Local-Toolkit-v1.0.0.zip İndir**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/archive/refs/tags/v1.0.0.zip) | Doğrulanmış kararlı sürüm, indir ve çalıştır |
| **En Güncel Kod (ZIP)** | [**Güncel ZIP Paketini İndir**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/archive/refs/heads/main.zip) | `main` dalındaki en son dosyaları tek tıkla indirir |
| **GitHub Sürümleri** | [**Releases Sayfası**](https://github.com/iamfahrig/Zyxel-Local-Toolkit/releases) | Paketlenmiş resmi sürümler ve sürüm notları |
| **Git ile Klonlama** | `git clone https://github.com/iamfahrig/Zyxel-Local-Toolkit.git` | Geliştiriciler ve terminal kullanıcıları için |

---

<a id="kullanım"></a>
## 🚀 Kullanım

### 1. Kurulum
1. İndirdiğiniz `Zyxel-Local-Toolkit.zip` arşivini bir klasöre çıkartın.
2. Bilgisayarınızı modeme **Ethernet** veya **Wi-Fi** ile bağlayın.
3. Modem yönetim şifrenizi hazır bulundurun (cihazın altındaki etikette yazar).

### 2. Çalıştırma
* **Windows:** **`START.bat`** dosyasına çift tıkla.  
* **macOS:** **`start.command`** dosyasına çift tıkla.  
* **Linux:** Terminal’de **`./start.sh`** çalıştır.

### 3. Mod Seçimi
Program açılınca dilinizi ve ardından menüden yapmak istediğiniz işlemi seçin:

| Mod | Ne Yapar? | İşlem Süresi & Cihaz Durumu |
|:---:|---|:---:|
| **1** | SSH/Telnet etkinleştirir, uzak yönetimi kapatır (önce yedek alır) | ~90-120 sn (cihaz yeniden başlar) |
| **2** | Mevcut ayarları JSON olarak kaydeder | ~5 sn (cihaz yeniden başlamaz) |
| **3** | Düzenlediğin JSON’u cihaza yükler | ~90-120 sn (cihaz yeniden başlar) |

Ardından modem IP’sini (varsayılan `192.168.1.1`) ve şifreni gir.  
Varsayılan giriş kullanıcı adı: **admin**

### 4. İşlem Sonrası
* **Mod 1 veya 3:** Cihaz yeniden başlar. 5G ve Wi-Fi bağlantısının oturması **90-120 saniye** sürer. Bu sürede fişi çekmeyin.  
* **Mod 1 sonrası erişim örnekleri:**  
  * SSH: `ssh root@192.168.1.1` (port: 22, şifre: modem web şifreniz)  
  * Web: `http://192.168.1.1` (kullanıcı: admin)  
  * FTP: `ftp://192.168.1.1` (port: 21)  
* **Hesap yapısı (Mod 1 sonrası):**  
  * `admin` → Varsayılan yetkili web hesabı  
  * `sUser` → Yetkili hesap  
  * `root` → SSH, FTP gibi servislerde kullanılan hesap  
* **Mod 2:** Cihaz yeniden başlamaz. `yedek_*/zcfg_config.json` dosyası oluşur.

---

## 🔄 Fabrika Ayarlarına Dönüş

* **Reset tuşu:** Arkadaki Reset deliğine **10-15 saniye** basılı tutun.  
* **Web arayüzü:** Bakım → Yeniden Başlatma → Fabrika Ayarlarına Sıfırla.  
* **Yedekten:** İlk alınan `zcfg_config.json` dosyasını Mod 3 ile geri yükleyin.

---

## 🔒 Güvenlik ve Gizlilik

* Tüm işlemler yerel ağda kalır, harici sunucu iletişimi yoktur.  
* Alınan yedekler (`yedek_*/`, `*.bin`, `*.json`) tamamen kendi yerel çalışma dizininizde saklanır, hiçbir şekilde dışarı aktarılmaz.  
* Parolalar bellekte geçici tutulur, kaydedilmez.

---

## ⚖️ Yasal Çerçeve

Bu proje, kullanıcının kendi donanımı üzerinde **birlikte çalışabilirlik** ve **bakım hakkı** kapsamında yürütülen bir araştırma ve yazılım çalışmasıdır. Aşağıdaki yasal dayanaklar çerçevesinde tasarlanmıştır:

* **AB Yazılım Direktifi (2009/24/EC) Madde 6** — Birlikte çalışabilirlik amacıyla arayüz bilgilerinin incelenmesine ve uyarlanmasına izin verir.
* **ABD DMCA § 1201(f)** — Bağımsız geliştirilen yazılımların diğer sistemlerle birlikte çalışabilmesi için tersine mühendislik muafiyeti tanır.
* **Onarım Hakkı (Right to Repair)** — Kullanıcının kendi mülkiyetindeki donanımı teşhis etme, yapılandırma ve bakımını yapma hakkını destekler.
* **Türk Fikir ve Sanat Eserleri Kanunu (FSEK) Madde 38** — Bilgisayar programının arayüzlerine ilişkin bilgilerin elde edilmesi ve birlikte çalışabilirliğin sağlanması amacıyla yapılan işlemleri hukuka uygun kabul eder.

> **Telif ve Veri Beyanı:** Bu depoda kapalı kaynak firmware ikili dosyaları, ticari sırlar veya üçüncü şahıslara ait özel veriler bulunmaz. Araç yalnızca kullanıcının kendi yerel ağındaki cihazından elde ettiği yapılandırma nesneleri üzerinde lokal olarak çalışır.

### Feragatname
Bu yazılım **eğitim, araştırma ve birlikte çalışabilirlik** amacıyla sunulmaktadır. Yapılan işlemler cihazı üretici garantisi kapsamı dışına çıkarabilir. Olası teknik veya donanımsal sonuçlardan tamamen kullanıcı sorumludur. Araç; yetkisiz erişim, servis aksatma veya yasadışı kullanım amacıyla tasarlanmamıştır.

### Sorumlu İfşa
Projedeki teknik bulgular, cihazın yerel ağ ortamında bağımsız yönetilebilmesi amacıyla analiz edilmiştir. Herhangi bir uzaktan sömürü veya dış servis etkileşimi amacı taşımamaktadır.

---

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) kapsamında yayınlanmaktadır.

---

*Son güncelleme: 2026*

