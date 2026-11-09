# Güvenlik Politikası / Security Policy

## Kapsam / Scope

Bu araç, kullanıcının **kendi mülkiyetindeki** Zyxel cihazında, yerel ağ üzerinde çalışır. Harici sunucu veya telemetri içermez. Araç, erişim için kullanıcının kendi admin şifresini gerektirir; herhangi bir kimlik doğrulama açığı sömürmez.

This tool runs on the user's **own** Zyxel device over the local network. It contains no external servers or telemetry. It requires the user's own admin password and does not exploit any authentication vulnerability.

## Kullanıcılar için güvenlik notları / Notes for users

- **Yedek dosyaları hassastır.** `backup.bin` ve `zcfg_config.json` dosyaları, `root`/`sUser` dahil hesap şifrelerini içerir. Bu dosyaları paylaşmayın ve herkese açık yerlere (GitHub issue/PR dahil) yüklemeyin.
- **WAN erişimi.** Mod 1 varsayılan olarak servisleri yalnızca LAN için açar. "LAN + WAN" seçeneği, SSH/Telnet/FTP'yi internet tarafına açar ve risklidir. Gerçekten gerekmedikçe LAN seçeneğinde kalın.
- **Şifreli olmayan protokoller.** Telnet ve FTP şifrelenmez. Uzaktan yönetim gerekiyorsa SSH tercih edin.

## Zafiyet bildirimi / Reporting a vulnerability

Bu araçta veya cihaz yapılandırma mantığında bir güvenlik sorunu bulursanız, lütfen herkese açık bir issue açmadan önce bir **private security advisory** (GitHub → Security → Report a vulnerability) oluşturun ya da depo sahibiyle iletişime geçin. Mümkünse şunları ekleyin:

- Etkilenen dosya/fonksiyon
- Yeniden üretme adımları
- Cihaz modeli ve firmware sürümü
- Olası etki

If you find a security issue in this tool or in the device configuration logic, please open a **private security advisory** (GitHub → Security → Report a vulnerability) or contact the repository owner before filing a public issue.

## Kapsam dışı / Out of scope

- Kullanıcının sahibi olmadığı cihazlarda kullanım.
- Üretici firmware'inin kapalı kaynak bileşenleri.
- Fiziksel erişim gerektiren senaryolar.
