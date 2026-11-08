import os
import sys
import json
import time
import uuid
import base64
import hashlib
import tempfile
import subprocess
import urllib.request
import urllib.parse
import http.cookiejar

ALL_PAGES = 'ARPTable_handle,ARP_Table,Backup_Restore,Broadband,CallHistory_id,Call_Rule,Certificates,DNS,Diagnostic_id,Email_Notify,Firewall,Firmware_Upgrade,Home_Connectivity,Home_Networking,IGMP_MLD,IPsec_VPN,Interface_Grouping,Log,Log_Setting,MAC_Filter,McastSt,NAT,NATSession_handle,PPTP_VPN,Parental_Control,Phone,QoS,Reboot,Remote_MGMT,Routing,RoutingTable_handle,Routing_Table,SIP,SNMP,SP_Domain,Scheduler_Rule,Status,Steering_Status,System,TR-064,TR-069_Client,Time,Traffic_Status,Tunnel_Setting,USB_Service,User_Account,VPN_Status,Vlan_Group,VoIP_Status,WLAN_Table,Wireless,wps_status_handle,Power_Monitor'

try:
    try:
        from cryptography.hazmat.decrepit.ciphers.algorithms import TripleDES
    except Exception:
        from cryptography.hazmat.primitives.ciphers.algorithms import TripleDES
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    from cryptography.hazmat.primitives import padding, serialization
    from cryptography.hazmat.primitives.asymmetric import padding as asym_padding
    import warnings
    warnings.filterwarnings("ignore")
    HAS_CRYPTOGRAPHY = True
except Exception:
    HAS_CRYPTOGRAPHY = False

def evp_bytes_to_key(secret: bytes, salt: bytes, key_len=24, iv_len=8):
    d = b""
    d_i = b""
    while len(d) < (key_len + iv_len):
        d_i = hashlib.md5(d_i + secret + salt).digest()
        d += d_i
    return d[:key_len], d[key_len:key_len + iv_len]

def run_openssl(args, input_bytes=None):
    res = subprocess.run(["openssl"] + args, input=input_bytes, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return res.stdout

def des3_decrypt(data: bytes, key: bytes, iv: bytes) -> bytes:
    if HAS_CRYPTOGRAPHY:
        c = Cipher(TripleDES(key), modes.CBC(iv)).decryptor()
        padded = c.update(data) + c.finalize()
        u = padding.PKCS7(64).unpadder()
        return u.update(padded) + u.finalize()
    return run_openssl(["enc", "-d", "-des-ede3-cbc", "-K", key.hex(), "-iv", iv.hex()], data)

def des3_encrypt(data: bytes, key: bytes, iv: bytes) -> bytes:
    if HAS_CRYPTOGRAPHY:
        padder = padding.PKCS7(64).padder()
        body = padder.update(data) + padder.finalize()
        c = Cipher(TripleDES(key), modes.CBC(iv)).encryptor()
        return c.update(body) + c.finalize()
    return run_openssl(["enc", "-e", "-des-ede3-cbc", "-K", key.hex(), "-iv", iv.hex()], data)

def aes_cbc_encrypt(data: bytes, key: bytes, iv: bytes) -> bytes:
    if HAS_CRYPTOGRAPHY:
        padder = padding.PKCS7(128).padder()
        body = padder.update(data) + padder.finalize()
        c = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
        return c.update(body) + c.finalize()
    return run_openssl(["enc", "-e", "-aes-256-cbc", "-K", key.hex(), "-iv", iv.hex()], data)

def aes_cbc_decrypt(data: bytes, key: bytes, iv: bytes) -> bytes:
    if HAS_CRYPTOGRAPHY:
        c = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
        padded = c.update(data) + c.finalize()
        u = padding.PKCS7(128).unpadder()
        return u.update(padded) + u.finalize()
    return run_openssl(["enc", "-d", "-aes-256-cbc", "-K", key.hex(), "-iv", iv.hex()], data)

def rsa_encrypt(data: bytes, pem_str: str) -> bytes:
    if HAS_CRYPTOGRAPHY:
        pub = serialization.load_pem_public_key(pem_str.encode("utf-8"))
        return pub.encrypt(data, asym_padding.PKCS1v15())
    with tempfile.NamedTemporaryFile("w", delete=False) as tf:
        tf.write(pem_str)
        tname = tf.name
    try:
        return run_openssl(["pkeyutl", "-encrypt", "-pubin", "-inkey", tname], data)
    finally:
        if os.path.exists(tname):
            os.remove(tname)

def convert_from_zyxel_bin(data: bytes, secret: str = "N3z0y93") -> dict:
    salt = data[8:16]
    cipher_bytes = data[16:]
    key, iv = evp_bytes_to_key(secret.encode("utf-8"), salt, 24, 8)
    plain_bytes = des3_decrypt(cipher_bytes, key, iv)
    return json.loads(plain_bytes.decode("utf-8"))

def convert_to_zyxel_bin(obj: dict, secret: str = "N3z0y93") -> bytes:
    raw = json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    salt = os.urandom(8)
    key, iv = evp_bytes_to_key(secret.encode("utf-8"), salt, 24, 8)
    cipher_bytes = des3_encrypt(raw, key, iv)
    return b"Salted__" + salt + cipher_bytes

def http_req(opener, url, method="GET", data=None, headers=None, timeout=15):
    h = headers.copy() if headers else {}
    req = urllib.request.Request(url, data=data, headers=h, method=method)
    try:
        with opener.open(req, timeout=timeout) as resp:
            body = resp.read()
            return {"status": resp.status, "data": body, "text": body.decode("utf-8", errors="replace")}
    except Exception:
        return {"status": 0, "data": b"", "text": ""}

def get_modem_session(host, password, opener, cj):
    sha_hex = hashlib.sha512(password.encode("utf-8")).hexdigest().lower()
    b64_pass = base64.b64encode(password.encode("utf-8")).decode("utf-8")
    plain_json = json.dumps({
        "Input_Account": "admin",
        "Input_Passwd": b64_pass,
        "currLang": "tr",
        "SHA512_password": sha_hex
    }, separators=(",", ":"))

    try:
        ts = int(time.time() * 1000)
        rsa_res = http_req(opener, f"http://{host}/getRSAPublickKey?t={ts}")
        if rsa_res["status"] == 200 and "-----BEGIN PUBLIC KEY-----" in rsa_res["text"]:
            t = rsa_res["text"]
            s = t.find("-----BEGIN PUBLIC KEY-----")
            end_mark = "-----END PUBLIC KEY-----"
            e = t.find(end_mark, s)
            if s >= 0 and e > s:
                pem = t[s:e + len(end_mark)].replace("\\n", "\n").replace("\\/", "/")
                aes_key = os.urandom(32)
                iv_full = os.urandom(32)
                iv16 = iv_full[:16]

                cb = aes_cbc_encrypt(plain_json.encode("utf-8"), aes_key, iv16)
                key_enc = rsa_encrypt(base64.b64encode(aes_key), pem)

                enc_body = json.dumps({
                    "content": base64.b64encode(cb).decode("utf-8"),
                    "iv": base64.b64encode(iv_full).decode("utf-8"),
                    "key": base64.b64encode(key_enc).decode("utf-8")
                }, separators=(",", ":")).encode("utf-8")

                l_res = http_req(opener, f"http://{host}/UserLogin", method="POST", data=enc_body, headers={"Content-Type": "application/json"})
                if l_res["status"] == 200:
                    text = l_res["text"]
                    if '"content"' in text and '"iv"' in text:
                        try:
                            l_obj = json.loads(text)
                            iv_d = base64.b64decode(l_obj["iv"])[:16]
                            raw_dec = aes_cbc_decrypt(base64.b64decode(l_obj["content"]), aes_key, iv_d)
                            text = raw_dec.decode("utf-8", errors="replace")
                        except Exception:
                            pass
                    import re
                    m = re.search(r'"sessionkey"\s*:\s*"([^"]+)"', text)
                    if m:
                        return m.group(1)
                    for c in cj:
                        if c.name == "sessionkey":
                            return c.value
    except Exception:
        pass

    try:
        l_res2 = http_req(opener, f"http://{host}/UserLogin", method="POST", data=plain_json.encode("utf-8"), headers={"Content-Type": "application/json"})
        if l_res2["status"] == 200:
            import re
            m = re.search(r'"sessionkey"\s*:\s*"([^"]+)"', l_res2["text"])
            if m:
                return m.group(1)
            for c in cj:
                if c.name == "sessionkey":
                    return c.value
    except Exception:
        pass

    return None

def optimize_config(cfg, all_pages):
    print(" [*] Yapilandirma Alanlari Yerel Varsayilanlara Uyarlaniyor:")
    if "X_ZYXEL_LoginCfg" in cfg and isinstance(cfg["X_ZYXEL_LoginCfg"], dict):
        adm_pass = None
        adm_def = None
        for gp in cfg["X_ZYXEL_LoginCfg"].get("LogGp", []):
            for acc in gp.get("Account", []):
                if acc.get("Username") == "admin":
                    adm_pass = acc.get("Password")
                    adm_def = acc.get("DefaultPassword")
                    break
            if adm_pass:
                break
        cfg["X_ZYXEL_LoginCfg"]["LoginGroupConfigurable"] = True
        for gp in cfg["X_ZYXEL_LoginCfg"].get("LogGp", []):
            gp["Level"] = "high"
            gp["Page"] = all_pages
            gp["HiddenPage"] = ""
            for acc in gp.get("Account", []):
                acc["Enabled"] = True
                acc["RemoteAccessPrivilege"] = "LAN,WAN"
                acc["GetConfigByFtp"] = True
                acc["ConfigAccountFromWAN"] = True
                acc["Page"] = all_pages
                acc["HiddenPage"] = ""
                if acc.get("Username") in ("sUser", "root") and adm_pass:
                    acc["Password"] = adm_pass
                    if adm_def:
                        acc["DefaultPassword"] = adm_def
        print("   -> [X_ZYXEL_LoginCfg]     : Yonetim sayfa erisimleri ve teshis yetkileri varsayilana esitlendi.")

    if "X_ZYXEL_RemoteManagement" in cfg and isinstance(cfg["X_ZYXEL_RemoteManagement"], dict):
        for sg in (cfg["X_ZYXEL_RemoteManagement"].get("Service", []), cfg["X_ZYXEL_RemoteManagement"].get("SPService", [])):
            if isinstance(sg, list):
                for s in sg:
                    name = s.get("Name")
                    if name in ("SSH", "TELNET", "FTP", "HTTP", "HTTPS", "PING"):
                        s["Enable"] = True
                        if "Mode" in s:
                            s["Mode"] = "LAN_WAN"
                        if "TrustAll" in s:
                            s["TrustAll"] = True
                        if name == "SSH":
                            s["Port"] = 22
                        elif name == "FTP":
                            s["Port"] = 21
                        elif name == "TELNET":
                            s["Port"] = 23
                    elif name == "TR069":
                        s["Enable"] = False
                        s["Port"] = 0
        print("   -> [RemoteManagement]     : Yerel teshis portlari etkinlestirildi (SSH:22, Telnet:23, FTP:21, Web:80/443).")

    if "ManagementServer" in cfg and isinstance(cfg["ManagementServer"], dict):
        ms = cfg["ManagementServer"]
        ms["EnableCWMP"] = False
        ms["PeriodicInformEnable"] = False
        ms["UpgradesManaged"] = False
        ms["URL"] = "http://127.0.0.1:0"
        ms["Username"] = ""
        ms["Password"] = ""
        ms["ConnectionRequestUsername"] = ""
        ms["ConnectionRequestPassword"] = ""
        ms["X_ZYXEL_ConnectionRequestPort"] = 0
        ms["STUNEnable"] = False
        print("   -> [ManagementServer]     : TR-069 (CWMP) sunucu ve istek adresi yerel varsayilana (127.0.0.1:0) sifirlandi.")

    if "LocalAgent" in cfg and isinstance(cfg["LocalAgent"], dict):
        for ag in ("Subscription", "Controller", "MTP"):
            for item in cfg["LocalAgent"].get(ag, []):
                item["Enable"] = False
        print("   -> [LocalAgent]           : TR-369 (USP) telemetri servis parametreleri pasif konuma alindi.")

    if "MQTT" in cfg and isinstance(cfg["MQTT"], dict):
        for client in cfg["MQTT"].get("Client", []):
            client["Enable"] = False
            client["BrokerAddress"] = "127.0.0.1"
        print("   -> [MQTT]                 : Telemetri araci yonlendirmesi yerel varsayilana (127.0.0.1) yonlendirildi.")

def clear_screen():
    try:
        os.system("cls" if os.name == "nt" else "clear")
    except Exception:
        pass

def show_app_banner(status_text=""):
    clear_screen()
    print("")
    print("=========================================================================")
    print("  Zyxel-Local-Toolkit - Local Diagnostic & Configuration Tool            ")
    print("  Zyxel Modem ve Router Cihazlari Icin Yerel Teshis ve Yonetim Araci     ")
    print("=========================================================================")
    if status_text:
        print(f"  {status_text}")
        print("-------------------------------------------------------------------------")
    print("")

def main():
    show_app_banner()
    print("  DIL SECIMI / LANGUAGE SELECTION:")
    print("  -----------------------------------------------------------------------")
    print("    [1] English   - International Documentation & English Menus")
    print("    [2] Turkce    - Turkce Yonergeler ve Menuler")
    print("  -----------------------------------------------------------------------")
    print("")

    is_en = False
    while True:
        raw_lang = input("  Select Language / Dil Seciniz [1: EN, 2: TR, Enter = 2]: ").strip().lower()
        if not raw_lang or raw_lang in ("2", "tr", "turkce", "turkce", "t"):
            is_en = False
            break
        elif raw_lang in ("1", "en", "eng", "english", "e"):
            is_en = True
            break
        else:
            print("  [!] Invalid choice / Gecersiz secim. Please enter 1 or 2 (Lutfen 1 veya 2 girin).")

    lang_tag = "[+] Language: English" if is_en else "[+] Dil: Turkce"
    show_app_banner(lang_tag)

    if is_en:
        print("  [i] Disclaimer:")
        print("      This toolkit is for educational, maintenance, and security research.")
        print("      Modifications may affect warranty status; user assumes all responsibility.")
        print("  [i] Responsible Disclosure:")
        print("      Diagnostic parameters are adapted to local area network defaults.")
        print("  -----------------------------------------------------------------------")
        print("  OPERATION MODES:")
        print("    [1] Enable SSH/Telnet & Disable Remote CWMP (auto-backups first)")
        print("        ~90-120s (device reboots automatically after applying)")
        print("    [2] Export Current Configuration as Readable JSON")
        print("        ~5s (device configuration unmodified, no reboot)")
        print("    [3] Restore Modified JSON Configuration to Device")
        print("        ~90-120s (device reboots automatically after applying)")
        print("  -----------------------------------------------------------------------\n")
    else:
        print("  [i] Feragatname:")
        print("      Bu aractaki yapilandirmalar egitim ve donanim bakimi amaclidir.")
        print("      Yapilacak islemler garanti durumunu etkileyebilir; sorumluluk kullaniciya aittir.")
        print("  [i] Sorumlu Ifsa:")
        print("      Teshis portlari yerel ag varsayilanlarina uyarlanmaktadir.")
        print("  -----------------------------------------------------------------------")
        print("  ISLEM MODLARI:")
        print("    [1] SSH/Telnet Etkinlestir & Uzak Yonetimi Kapat (Once otomatik yedek alir)")
        print("        ~90-120 sn (Cihaz ayarlar yuklenince otomatik yeniden baslar)")
        print("    [2] Mevcut Ayarlari JSON Olarak Kaydet")
        print("        ~5 sn (Cihazda ayar degistirmez, yeniden baslamaz)")
        print("    [3] Duzenledigin JSON'u Cihaza Yukle")
        print("        ~90-120 sn (Cihaz ayarlar yuklenince otomatik yeniden baslar)")
        print("  -----------------------------------------------------------------------\n")

    selected = 1
    while True:
        choice_prompt = "  Select Mode [1 / 2 / 3, Enter = 1]: " if is_en else "  Islem Seciniz [1 / 2 / 3, Enter = 1]: "
        choice = input(choice_prompt).strip()
        if not choice or choice == "1":
            selected = 1
            break
        elif choice == "2":
            selected = 2
            break
        elif choice == "3":
            selected = 3
            break
        else:
            err_msg = "  [!] Please enter 1, 2, or 3." if is_en else "  [!] Lutfen 1, 2 veya 3 giriniz."
            print(err_msg)

    mode_labels_en = {1: "[+] Mode 1: Enable SSH/Telnet", 2: "[+] Mode 2: Export JSON", 3: "[+] Mode 3: Restore JSON"}
    mode_labels_tr = {1: "[+] Mod 1: SSH/Telnet Etkinlestir & Uzak Yonetimi Kapat", 2: "[+] Mod 2: JSON Olarak Kaydet", 3: "[+] Mod 3: JSON Geri Yukle"}
    mode_tag = mode_labels_en[selected] if is_en else mode_labels_tr[selected]

    show_app_banner(f"{lang_tag}  |  {mode_tag}")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    if os.path.basename(script_dir) == "core":
        script_dir = os.path.dirname(script_dir)
    json_path = os.path.join(script_dir, "zcfg_config.json")

    if selected == 3:
        if not os.path.exists(json_path):
            subdirs = sorted([d for d in os.listdir(script_dir) if d.startswith("yedek_") and os.path.isdir(os.path.join(script_dir, d))], reverse=True)
            if subdirs:
                cand = os.path.join(script_dir, subdirs[0], "zcfg_config.json")
                if os.path.exists(cand):
                    json_path = cand
        if not os.path.exists(json_path):
            err_not_found = "  [!] Error: 'zcfg_config.json' not found.\n      Export current config first with option [2] and edit it." if is_en else "  [!] Hata: 'zcfg_config.json' dosyasi bulunamadi.\n      Once [2] secenegi ile mevcut paketi acip duzenlemeniz gerekir."
            print(err_not_found)
            sys.exit(1)
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                cfg = json.load(f)
            ok_loaded = f"  [+] '{json_path}' verified and loaded." if is_en else f"  [+] '{json_path}' dosyasi okundu ve dogrulandi."
            print(ok_loaded)
        except Exception:
            err_json = "  [!] Error: 'zcfg_config.json' is not valid JSON." if is_en else "  [!] Hata: 'zcfg_config.json' gecerli bir JSON biciminde degil."
            print(err_json)
            sys.exit(1)

    default_ip = "192.168.1.1"
    cred_header = "  DEVICE CONNECTION CREDENTIALS:" if is_en else "  BAGLANTI VE GIRIS BILGILERI:"
    print(cred_header)
    print("  -----------------------------------------------------------------------")

    ip_prompt = f"    Router IP Address [Enter = {default_ip}]: " if is_en else f"    Modem IP Adresi [Enter = {default_ip}]: "
    ip_in = input(ip_prompt).strip()
    ip = ip_in if ip_in else default_ip

    pass_prompt = "    Device Web Password (User: admin): " if is_en else "    Modem Yonetim Sifresi (Kullanici: admin): "
    while True:
        pass_in = input(pass_prompt).strip()
        if pass_in:
            break
        empty_pass = "    [!] Password cannot be empty." if is_en else "    [!] Sifre bos birakilamaz."
        print(empty_pass)

    show_app_banner(f"{lang_tag}  |  {mode_tag}  |  [+] {ip}")

    auth_msg = f"  [*] Authenticating ({ip})..." if is_en else f"  [*] Kimlik dogrulaniyor ({ip})..."
    print(auth_msg)
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

    sk = get_modem_session(ip, pass_in, opener, cj)
    if not sk:
        login_err = "[!] Error: Could not connect to router or login failed." if is_en else "[!] Hata: Modeme erisilemedi veya oturum acilamadi."
        print(login_err)
        sys.exit(1)
    auth_ok = "[+] Authentication successful (admin). Session token obtained." if is_en else "[+] Kimlik dogrulandi (admin). Oturum anahtari alindi."
    print(auth_ok)

    if selected in (1, 2):
        fetch_msg = "\n[*] Downloading configuration package from device..." if is_en else "\n[*] Donanim yapilandirma paketi aliniyor..."
        print(fetch_msg)
        http_req(opener, f"http://{ip}/cgi-bin/UserLoginCheck")
        b_res = http_req(opener, f"http://{ip}/cgi-bin/Backup_Restore?action=Backup&sessionkey={urllib.parse.quote(sk)}")
        if b_res["status"] != 200 or len(b_res["data"]) < 400:
            dl_err = "[!] Error: Failed to retrieve configuration package." if is_en else "[!] Hata: Yapilandirma paketi alinamadi."
            print(dl_err)
            sys.exit(1)
        dl_ok = f"[+] Configuration package received ({len(b_res['data'])} bytes)." if is_en else f"[+] Yapilandirma paketi alindi ({len(b_res['data'])} bayt)."
        print(dl_ok)

        time_tag = time.strftime("%Y-%m-%d_%H-%M-%S")
        backup_dir = os.path.join(script_dir, f"yedek_{time_tag}")
        os.makedirs(backup_dir, exist_ok=True)

        bin_path = os.path.join(backup_dir, "backup.bin")
        with open(bin_path, "wb") as f:
            f.write(b_res["data"])

        unpack_msg = "\n[*] Unpacking binary package and parsing ZCFG object model..." if is_en else "\n[*] Donanim paketi aciliyor ve nesne modeli cozumleniyor..."
        print(unpack_msg)
        cfg = convert_from_zyxel_bin(b_res["data"])
        model_ok = "[+] Object model loaded into memory." if is_en else "[+] Nesne modeli bellege aktarildi."
        print(model_ok)

        if selected == 2:
            json_out = os.path.join(backup_dir, "zcfg_config.json")
            with open(json_out, "w", encoding="utf-8") as f:
                json.dump(cfg, f, indent=2, ensure_ascii=False)
            print("\n=========================================================================")
            if is_en:
                print(" [OK] CONFIGURATION PACKAGE EXTRACTED AND SAVED")
                print("=========================================================================")
                print(f"\n   - Archive Folder   : {backup_dir}")
                print(f"   - Raw Binary (.bin): {bin_path}")
                print(f"   - Open JSON (.json): {json_out}\n")
                print(" Device configuration has not been modified.")
                print(" You can inspect or edit this JSON file for research or customization.")
                print(" After editing, use option [3] to restore it back to the device.")
            else:
                print(" [OK] YAPILANDIRMA PAKETI BASARIYLA ACILDI VE KAYDEDILDI")
                print("=========================================================================")
                print(f"\n   - Arsiv Klasoru     : {backup_dir}")
                print(f"   - Ham Paket (.bin)  : {bin_path}")
                print(f"   - Acik Nesne (.json): {json_out}\n")
                print(" Cihaz uzerinde herhangi bir durum degisikligi yapilmadi.")
                print(" JSON dosyasini egitim ve guvenlik analizi amaciyla inceleyebilirsiniz.")
                print(" Duzenleme sonrasi [3] secenegi ile modeminize geri yukleyebilirsiniz.")
            print("=========================================================================\n")
            sys.exit(0)
        else:
            arch_ok = f" [+] Original backup archived safely to '{bin_path}'." if is_en else f" [+] Orijinal donanim paketi '{bin_path}' yoluna guvenle arsivlendi."
            print(arch_ok)

    if selected == 1:
        opt_msg = "\n[*] Applying interoperability and local diagnostic parameters..." if is_en else "\n[*] Birlikte calisabilirlik ve yerel servis parametreleri uyarlaniyor..."
        print(opt_msg)
        optimize_config(cfg, ALL_PAGES)

    pack_msg = "\n[*] Repacking configuration into hardware binary format..." if is_en else "\n[*] Yeni donanim paketi hazirlaniyor ve paketleniyor..."
    print(pack_msg)
    enc_bytes = convert_to_zyxel_bin(cfg)
    pack_ok = f"[+] Package generated ({len(enc_bytes)} bytes)." if is_en else f"[+] Paket hazirlandi ({len(enc_bytes)} bayt)."
    print(pack_ok)

    upload_msg = "\n[*] Uploading configuration package to router..." if is_en else "\n[*] Yeni yapilandirma paketi cihaza yukleniyor..."
    print(upload_msg)
    boundary = "----ZyxelBoundary" + uuid.uuid4().hex
    h_bytes = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="mtenRestoreCfg"; filename="backup.bin"\r\n'
        f"Content-Type: application/octet-stream\r\n\r\n"
    ).encode("utf-8")
    f_bytes = f"\r\n--{boundary}--\r\n".encode("utf-8")
    payload = h_bytes + enc_bytes + f_bytes

    restore_url = f"http://{ip}/cgi-bin/Backup_Restore?action=Restore&sessionkey={urllib.parse.quote(sk)}"
    http_req(opener, restore_url, method="POST", data=payload, headers={"Content-Type": f"multipart/form-data; boundary={boundary}"})

    print("\n=========================================================================")
    if is_en:
        print(" [INFO] CONFIGURATION PACKAGE APPLIED TO DEVICE")
        print("=========================================================================")
        print("\n [*] New configuration applied. The router is now rebooting to load settings.")
        print(" [*] Establishing 5G/cellular link and Wi-Fi broadcast takes ~90-120 seconds. Please wait patiently.")
        print(" [*] To revert to factory defaults, hold the Reset pinhole on the back for 10-15 seconds or use the Web GUI.\n")
        if selected == 1:
            print(" Local Diagnostic Endpoints:")
            print(f"   - Web Management GUI : http://{ip} (user: admin)")
            print(f"   - Local SSH Shell    : ssh root@{ip} -p 22")
            print(f"   - Local FTP Service  : ftp://{ip} (port: 21)")
            print(f"   - Local Telnet       : telnet {ip} 23")
            print("\n Account Roles (Password: Your Router Web Password):")
            print("   - admin : Default privileged web interface account")
            print("   - root  : Privileged shell and FTP account")
            print("   - sUser : Elevated system account")
        else:
            print("   - Custom configuration package restored successfully.")
        print("\n Info: For educational, maintenance, and interoperability research only.")
    else:
        print(" [BILGI] YAPILANDIRMA PAKETI CIHAZA AKTARILDI")
        print("=========================================================================")
        print("\n [*] Yeni yapilandirma cihaza uygulandi. Cihaz ayarlari yuklemek uzere yeniden baslatiliyor.")
        print(" [*] Servislerin ve ag baglantisinin hazir hale gelmesi yaklasik 90-120 saniye surecektir. Lutfen sabirla bekleyiniz.")
        print(" [*] Orijinal fabrika ayarlarina donmek isterseniz modemin arkasindaki Reset butonuna 10-15 saniye basili tutabilir veya web arayuzunden sifirlayabilirsiniz.\n")
        if selected == 1:
            print(" Yerel Teshis Arabirimleri:")
            print(f"   - Web Yonetim Arayuzu : http://{ip} (kullanici: admin)")
            print(f"   - Yerel SSH Konsolu   : ssh root@{ip} -p 22")
            print(f"   - Yerel FTP Servisi   : ftp://{ip} (port: 21)")
            print(f"   - Yerel Telnet        : telnet {ip} 23")
            print("\n Hesap Yapisi (Mod 1 Sonrasi - Sifre: Modem Web Sifreniz):")
            print("   - admin : Varsayilan yetkili web hesabi")
            print("   - root  : SSH ve FTP yetkili erisim hesabi")
            print("   - sUser : Yetkili sistem hesabi")
        else:
            print("   - Ozel yapilandirma paketi basariyla cihaza iletildi.")
        print("\n Bilgi: Bu arac egitim, donanim bakimi ve guvenlik arastirmasi amaclidir.")
    print("=========================================================================\n")

if __name__ == "__main__":
    main()

