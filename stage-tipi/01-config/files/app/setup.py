#!/usr/bin/env python3
"""
RuntipiOS — Script d'installation système
Lancé par app.py via subprocess. Toutes les sorties sont capturées et
relayées en temps réel vers le portail web.

Protocole de sortie :
  TIPI_STEP:<message>   → étape en cours (badge coloré)
  TIPI_DONE:<message>   → étape réussie (badge vert)
  TIPI_ERROR:<message>  → erreur non fatale (badge rouge)
  TIPI_IP:<adresse>     → IP finale de Runtipi
  <autre>               → log brut (affiché en gris)
"""

import json
import os
import pwd
import re
import subprocess
import sys
import time

from translations import get_t

# ---------------------------------------------------------------------------
# Nettoyage des codes ANSI (couleurs terminal) dans les sorties subprocess
# ---------------------------------------------------------------------------
_ANSI_RE = re.compile(r'\x1b\[[0-9;]*[mGKHFABCDJr]')

# ---------------------------------------------------------------------------
# Patterns d'erreurs Docker fatales dans le flux de sortie du script Runtipi
# ---------------------------------------------------------------------------
_DOCKER_FATAL_RE = re.compile(
    r'failed to copy|TLS handshake timeout|no space left|pull access denied',
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Traductions — initialisées dans main() après lecture de la config
# ---------------------------------------------------------------------------
T: dict = {}

# ---------------------------------------------------------------------------
# Helpers de log
# ---------------------------------------------------------------------------

def step(msg: str):  print(f"TIPI_STEP:{msg}",  flush=True)
def done(msg: str):  print(f"TIPI_DONE:{msg}",  flush=True)
def err(msg: str):   print(f"TIPI_ERROR:{msg}", flush=True)
def out(msg: str):   print(msg,                 flush=True)


def run_cmd(cmd: list, env=None, check=True) -> subprocess.CompletedProcess:
    """Exécute une commande et streame sa sortie ligne par ligne."""
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        env=env,
    )
    for line in iter(proc.stdout.readline, ""):
        line = line.rstrip()
        if line:
            out(line)
    proc.wait()
    if check and proc.returncode != 0:
        raise subprocess.CalledProcessError(proc.returncode, cmd)
    return proc


def validate_ip(ip: str) -> bool:
    pattern = re.compile(r"^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$")
    if not pattern.match(ip):
        return False
    return all(0 <= int(p) <= 255 for p in ip.split("/")[0].split("."))


# ---------------------------------------------------------------------------
# Étapes de configuration
# ---------------------------------------------------------------------------

def configure_hostname(hostname: str):
    step(T["hostname_step"])
    subprocess.run(["hostnamectl", "set-hostname", hostname], check=True)

    with open("/etc/hosts", "r") as f:
        hosts = f.read()
    if "127.0.1.1" in hosts:
        hosts = re.sub(r"127\.0\.1\.1\s+\S+", f"127.0.1.1\t{hostname}", hosts)
    else:
        hosts += f"\n127.0.1.1\t{hostname}\n"
    with open("/etc/hosts", "w") as f:
        f.write(hosts)

    done(T["hostname_done"].format(hostname=hostname))


def configure_timezone(timezone: str):
    step(T["timezone_step"].format(timezone=timezone))
    subprocess.run(["timedatectl", "set-timezone", timezone], check=True)
    done(T["timezone_done"].format(timezone=timezone))


def configure_locale(locale: str):
    step(T["locale_step"].format(locale=locale))
    try:
        locale_gen_path = "/etc/locale.gen"
        with open(locale_gen_path, "r") as f:
            content = f.read()
        content = content.replace(f"# {locale} ", f"{locale} ")
        with open(locale_gen_path, "w") as f:
            f.write(content)
        run_cmd(["locale-gen"])
        run_cmd(["update-locale", f"LANG={locale}"])
        done(T["locale_done"].format(locale=locale))
    except Exception as e:
        err(T["locale_err"].format(e=e))


def create_user(username: str, password: str):
    step(T["user_step"].format(username=username))

    result = subprocess.run(["id", username], capture_output=True)
    if result.returncode != 0:
        subprocess.run(
            ["useradd", "-m", "-s", "/bin/bash", "-G", "sudo", username],
            check=True,
        )

    proc = subprocess.Popen(
        ["chpasswd"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    _, stderr = proc.communicate(input=f"{username}:{password}".encode())
    if proc.returncode != 0:
        raise RuntimeError(f"chpasswd a échoué : {stderr.decode()}")

    done(T["user_done"].format(username=username))


def remove_build_user(keep_username: str):
    """Remove the temporary pi-gen build user (default: 'tipi/tipipassword').
    Skipped if the user chose the same username to avoid self-deletion."""
    build_user = "tipi"
    if build_user == keep_username:
        return
    result = subprocess.run(["id", build_user], capture_output=True)
    if result.returncode == 0:
        subprocess.run(["userdel", "-r", build_user], check=False, capture_output=True)


def add_ssh_key(username: str, ssh_key: str):
    if not ssh_key:
        return
    step(T["sshkey_step"])
    try:
        pw = pwd.getpwnam(username)
        ssh_dir = f"/home/{username}/.ssh"
        auth_keys = f"{ssh_dir}/authorized_keys"

        os.makedirs(ssh_dir, mode=0o700, exist_ok=True)
        with open(auth_keys, "a") as f:
            f.write(ssh_key.strip() + "\n")
        os.chmod(auth_keys, 0o600)
        os.chown(ssh_dir, pw.pw_uid, pw.pw_gid)
        os.chown(auth_keys, pw.pw_uid, pw.pw_gid)
        done(T["sshkey_done"])
    except Exception as e:
        err(T["sshkey_err"].format(e=e))


def configure_ssh(ssh_port: str, disable_password_auth: bool, ssh_key: str):
    step(T["ssh_step"].format(ssh_port=ssh_port))
    try:
        with open("/etc/ssh/sshd_config", "r") as f:
            sshd = f.read()

        if re.search(r"^#?Port\s+\d+", sshd, re.MULTILINE):
            sshd = re.sub(r"^#?Port\s+\d+", f"Port {ssh_port}", sshd, flags=re.MULTILINE)
        else:
            sshd = f"Port {ssh_port}\n" + sshd

        if disable_password_auth and ssh_key:
            sshd = re.sub(
                r"^#?PasswordAuthentication\s+\w+",
                "PasswordAuthentication no",
                sshd,
                flags=re.MULTILINE,
            )

        sshd = re.sub(r"^#?PermitRootLogin\s+[\w-]+", "PermitRootLogin no", sshd, flags=re.MULTILINE)

        with open("/etc/ssh/sshd_config", "w") as f:
            f.write(sshd)

        subprocess.run(["ssh-keygen", "-A"], check=False)

        test = subprocess.run(["sshd", "-t"], capture_output=True, text=True)
        if test.returncode != 0:
            err(T["ssh_invalid"].format(stderr=test.stderr.strip()))
            return

        subprocess.run(["systemctl", "enable", "ssh"], check=True)
        subprocess.run(["systemctl", "restart", "ssh"], check=True)
        done(T["ssh_done"].format(ssh_port=ssh_port))
    except Exception as e:
        err(T["ssh_err"].format(e=e))


def configure_static_ip(static_ip: str, static_gw: str, static_dns: str):
    if not static_ip or not static_gw:
        return
    if not validate_ip(static_ip) or not validate_ip(static_gw):
        err(T["staticip_invalid"])
        return

    step(T["staticip_step"].format(static_ip=static_ip))
    try:
        result = subprocess.run(
            ["nmcli", "-t", "-f", "NAME,DEVICE", "con", "show", "--active"],
            capture_output=True, text=True,
        )
        eth_con = None
        for line in result.stdout.strip().splitlines():
            parts = line.split(":")
            if len(parts) >= 2 and parts[1] == "eth0":
                eth_con = parts[0]
                break

        if not eth_con:
            err(T["staticip_nociface"])
            return

        ip_cidr = static_ip if "/" in static_ip else f"{static_ip}/24"
        subprocess.run(["nmcli", "con", "mod", eth_con, "ipv4.addresses", ip_cidr], check=True)
        subprocess.run(["nmcli", "con", "mod", eth_con, "ipv4.gateway", static_gw], check=True)
        subprocess.run(["nmcli", "con", "mod", eth_con, "ipv4.dns", static_dns], check=True)
        subprocess.run(["nmcli", "con", "mod", eth_con, "ipv4.method", "manual"], check=True)
        subprocess.run(["nmcli", "con", "up", eth_con], check=True)
        done(T["staticip_done"].format(static_ip=static_ip))
    except Exception as e:
        err(T["staticip_err"].format(e=e))


def system_update():
    step(T["update_step"])
    env = {**os.environ, "DEBIAN_FRONTEND": "noninteractive"}
    run_cmd(["apt-get", "update", "-y"], env=env, check=False)
    done(T["update_done"])

    step(T["upgrade_step"])
    run_cmd([
        "apt-get", "upgrade", "-y",
        "-o", "Dpkg::Options::=--force-confdef",
        "-o", "Dpkg::Options::=--force-confold",
    ], env=env, check=False)
    done(T["upgrade_done"])


def _write_wifi_error(ssid: str, msg: str):
    """Write WiFi error to /boot/firmware so it's readable from any OS."""
    try:
        with open("/boot/firmware/tipi-wifi-error.txt", "w") as f:
            f.write(f"RuntipiOS — WiFi connection error\n")
            f.write(f"SSID : {ssid}\n")
            f.write(f"Error: {msg}\n")
    except Exception:
        pass


def connect_wifi(wifi_ssid: str, wifi_password: str):
    """Connecte wlan0 au WiFi choisi — appelé EN DERNIER (coupe le hotspot)."""
    if not wifi_ssid:
        return
    step(T["wifi_step"].format(wifi_ssid=wifi_ssid))
    try:
        subprocess.run(["pkill", "-f", "tipi-hostapd.conf"], capture_output=True)
        subprocess.run(["pkill", "-f", "tipi-dnsmasq"], capture_output=True)
        subprocess.run(["pkill", "hostapd"], capture_output=True)
        time.sleep(1)
        subprocess.run(["nmcli", "dev", "set", "wlan0", "managed", "yes"],
                       capture_output=True)
        time.sleep(2)

        subprocess.run(["nmcli", "con", "delete", "tipi-wifi"],
                       capture_output=True)

        if wifi_password:
            add_cmd = [
                "nmcli", "con", "add",
                "type", "wifi",
                "ifname", "wlan0",
                "con-name", "tipi-wifi",
                "ssid", wifi_ssid,
                "wifi-sec.key-mgmt", "wpa-psk",
                "wifi-sec.psk", wifi_password,
            ]
        else:
            add_cmd = [
                "nmcli", "con", "add",
                "type", "wifi",
                "ifname", "wlan0",
                "con-name", "tipi-wifi",
                "ssid", wifi_ssid,
            ]

        result = subprocess.run(add_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            msg = T["wifi_profile_err"].format(e=(result.stderr or result.stdout).strip())
            err(msg)
            _write_wifi_error(wifi_ssid, msg)
            return

        result = subprocess.run(
            ["nmcli", "con", "up", "tipi-wifi"],
            capture_output=True, text=True, timeout=40,
        )
        if result.returncode == 0:
            done(T["wifi_done"].format(wifi_ssid=wifi_ssid))
        else:
            msg = T["wifi_fail"].format(e=(result.stderr or result.stdout).strip())
            err(msg)
            _write_wifi_error(wifi_ssid, msg)
    except subprocess.TimeoutExpired:
        msg = T["wifi_timeout"]
        err(msg)
        _write_wifi_error(wifi_ssid, msg)
    except Exception as e:
        msg = T["wifi_err"].format(e=e)
        err(msg)
        _write_wifi_error(wifi_ssid, msg)


def _runtipi_service_running() -> bool:
    """Vérifie que Runtipi tourne via Docker (pas de service systemd dédié)."""
    try:
        result = subprocess.run(
            ["docker", "ps", "--filter", "name=runtipi", "--format", "{{.Names}}"],
            capture_output=True, text=True, timeout=15,
        )
        return bool(result.stdout.strip())
    except Exception:
        return False


def install_runtipi(max_attempts: int = 3) -> bool:
    step(T["runtipi_step"])
    for attempt in range(1, max_attempts + 1):
        if attempt > 1:
            out(T["runtipi_retry"].format(attempt=attempt, total=max_attempts))
            time.sleep(30)
        try:
            curl = subprocess.Popen(
                ["curl", "-L", "--max-time", "120", "https://setup.runtipi.io"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            bash = subprocess.Popen(
                ["bash"],
                stdin=curl.stdout,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
            curl.stdout.close()

            docker_errors = []
            for line in iter(bash.stdout.readline, ""):
                line = _ANSI_RE.sub("", line).rstrip()
                if line:
                    out(line)
                    if _DOCKER_FATAL_RE.search(line):
                        docker_errors.append(line)

            bash.wait()
            curl.wait()

            if bash.returncode != 0:
                err(T["runtipi_fail"].format(code=bash.returncode))
                continue

            # bash a retourné 0, mais vérifier que les containers tournent vraiment
            # Runtipi peut mettre jusqu'à 3 minutes pour démarrer ses containers
            out("Vérification du démarrage des containers Runtipi (jusqu'à 3 min)…")
            for _ in range(18):  # 18 × 10s = 3 minutes max
                time.sleep(10)
                if _runtipi_service_running():
                    break
            if not _runtipi_service_running():
                err("Runtipi installé mais service inactif — nouvelle tentative.")
                continue

            if docker_errors:
                out(f"Avertissement : {len(docker_errors)} erreur(s) Docker ignorée(s) par le script d'installation.")

            done(T["runtipi_done"])
            return True

        except Exception as e:
            err(T["runtipi_err"].format(e=e))

    return False


def get_final_ip() -> str | None:
    for iface in ["eth0", "wlan0"]:
        try:
            r = subprocess.run(
                ["ip", "-4", "addr", "show", iface],
                capture_output=True, text=True,
            )
            m = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)", r.stdout)
            if m and not m.group(1).startswith("10.42."):
                return m.group(1)
        except Exception:
            pass
    return None


def configure_cockpit(enabled: bool):
    if enabled:
        step(T["cockpit_step"])
        subprocess.run(["systemctl", "enable", "--now", "cockpit.socket"], check=False)
        done(T["cockpit_done"])
    else:
        subprocess.run(["systemctl", "disable", "--now", "cockpit.socket"],
                       check=False, capture_output=True)


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

def main():
    global T
    if len(sys.argv) != 2:
        print("Usage: setup.py <config.json>", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    try:
        with open(config_path) as f:
            cfg = json.load(f)
    except Exception as e:
        # T pas encore initialisé ici, message en anglais par défaut
        print(f"TIPI_ERROR:Cannot read configuration: {e}", flush=True)
        sys.exit(1)
    finally:
        try:
            os.remove(config_path)
        except Exception:
            pass

    # Initialiser les traductions dès que la langue est connue
    T = get_t(cfg.get("lang", "en"))

    hostname             = cfg.get("hostname", "runtipios")
    username             = cfg.get("username", "")
    password             = cfg.get("password", "")
    ssh_port             = str(cfg.get("ssh_port", "22"))
    ssh_key              = cfg.get("ssh_key", "").strip()
    disable_password_auth = bool(cfg.get("disable_password_auth", False))
    timezone             = cfg.get("timezone", "Europe/Paris")
    locale               = cfg.get("locale", "fr_FR.UTF-8")
    static_ip            = cfg.get("static_ip", "")
    static_gw            = cfg.get("static_gw", "")
    static_dns           = cfg.get("static_dns", "8.8.8.8")
    wifi_ssid             = cfg.get("wifi_ssid", "").strip()
    wifi_password         = cfg.get("wifi_password", "").strip()
    cockpit_enabled       = bool(cfg.get("cockpit_enabled", False))

    # Validation minimale
    if not username or not password:
        err(T["config_missing"])
        sys.exit(1)

    # --- Pipeline d'installation ---
    configure_hostname(hostname)
    configure_timezone(timezone)
    configure_locale(locale)
    create_user(username, password)
    remove_build_user(username)
    add_ssh_key(username, ssh_key)
    configure_ssh(ssh_port, disable_password_auth, ssh_key)
    configure_static_ip(static_ip, static_gw, static_dns)
    if wifi_ssid:
        step("⚠️ " + T["wifi_hotspot_warn"])
    connect_wifi(wifi_ssid, wifi_password)
    system_update()
    if not install_runtipi():
        try:
            with open("/boot/firmware/tipi-install-failed.flag", "w") as f:
                f.write("1")
        except Exception:
            pass
        err(T["runtipi_retry_boot"].format(hostname=hostname))

    configure_cockpit(cockpit_enabled)

    final_ip = get_final_ip()
    if final_ip:
        print(f"TIPI_IP:{final_ip}", flush=True)
    done(T["config_done"])


if __name__ == "__main__":
    main()
