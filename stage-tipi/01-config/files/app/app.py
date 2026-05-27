#!/usr/bin/env python3
"""
RuntipiOS — Portail de configuration (premier démarrage)
Tourne sur le port 8080, accessible via :
  - http://tipisetup.local:8080   (mDNS Avahi, réseau local)
  - http://10.42.0.1:8080         (hotspot WiFi TipiSetup)
"""

import json
import os
import re
import subprocess
import threading
import time
from urllib.parse import quote
from flask import Flask, Response, jsonify, redirect, render_template, request, session
from translations import get_t, DEFAULT_LANG, SUPPORTED_LANGS, LANG_LABELS

# ---------------------------------------------------------------------------
# Init Flask
# ---------------------------------------------------------------------------
TEMPLATE_DIR = os.path.join(os.path.dirname(__file__), "templates")
STATIC_DIR  = os.path.join(os.path.dirname(__file__), "static")
app = Flask(__name__, template_folder=TEMPLATE_DIR, static_folder=STATIC_DIR)
app.secret_key = os.urandom(32)

# ---------------------------------------------------------------------------
# État global partagé (setup tourne dans un thread séparé)
# ---------------------------------------------------------------------------
_config: dict = {}
_progress_log: list = []
_setup_started = False
_setup_done = False
_setup_lock = threading.Lock()

LOCALES = [
    ("fr_FR.UTF-8", "Français (France)"),
    ("en_US.UTF-8", "English (US)"),
    ("en_GB.UTF-8", "English (UK)"),
    ("de_DE.UTF-8", "Deutsch"),
    ("es_ES.UTF-8", "Español"),
    ("it_IT.UTF-8", "Italiano"),
    ("pt_PT.UTF-8", "Português"),
    ("nl_NL.UTF-8", "Nederlands"),
    ("pl_PL.UTF-8", "Polski"),
    ("ja_JP.UTF-8", "日本語"),
    ("zh_CN.UTF-8", "中文 (简体)"),
]

# ---------------------------------------------------------------------------
# Utilitaires réseau
# ---------------------------------------------------------------------------

def ethernet_connected() -> bool:
    """Retourne True si eth0 est UP avec une adresse IP."""
    try:
        result = subprocess.run(
            ["ip", "-4", "addr", "show", "eth0"],
            capture_output=True, text=True, timeout=5,
        )
        return "inet " in result.stdout and "state UP" in subprocess.run(
            ["ip", "link", "show", "eth0"], capture_output=True, text=True, timeout=5
        ).stdout
    except Exception:
        return False


def get_wifi_networks() -> list:
    """Scanne les réseaux WiFi disponibles via nmcli."""
    try:
        subprocess.run(
            ["nmcli", "dev", "wifi", "rescan"],
            capture_output=True, timeout=10,
        )
        result = subprocess.run(
            ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list"],
            capture_output=True, text=True, timeout=10,
        )
        networks = []
        seen: set = set()
        for line in result.stdout.strip().splitlines():
            # SSID peut contenir ":", on découpe depuis la droite
            parts = line.rsplit(":", 2)
            if len(parts) != 3:
                continue
            ssid, signal_str, security = parts[0], parts[1], parts[2]
            if not ssid or ssid in seen or ssid == "TipiSetup":
                continue
            seen.add(ssid)
            networks.append({
                "ssid": ssid,
                "signal": int(signal_str) if signal_str.isdigit() else 0,
                "security": security,
                "has_password": bool(security and security not in ("--", "")),
            })
        return sorted(networks, key=lambda x: x["signal"], reverse=True)
    except Exception:
        return []


def get_current_ip() -> str | None:
    """Retourne la première IP non-loopback disponible."""
    for iface in ["eth0", "wlan0"]:
        try:
            r = subprocess.run(
                ["ip", "-4", "addr", "show", iface],
                capture_output=True, text=True, timeout=5,
            )
            m = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)", r.stdout)
            if m and not m.group(1).startswith("10.42."):
                return m.group(1)
        except Exception:
            pass
    return None


def get_timezones() -> list:
    try:
        from zoneinfo import available_timezones
        return sorted(available_timezones())
    except Exception:
        return ["Europe/Paris", "Europe/London", "America/New_York",
                "America/Los_Angeles", "Asia/Tokyo", "Asia/Shanghai"]

# ---------------------------------------------------------------------------
# Portail captif — iOS / Android / Windows ouvrent le navigateur auto
# ---------------------------------------------------------------------------
CAPTIVE_PORTAL_PATHS = {
    "/hotspot-detect.html",
    "/library/test/success.html",
    "/generate_204",
    "/gen_204",
    "/connecttest.txt",
    "/success.txt",
    "/ncsi.txt",
    "/redirect",
    "/chat",
    "/canonical.html",
}

@app.before_request
def handle_captive_portal():
    if request.path in CAPTIVE_PORTAL_PATHS:
        return redirect("http://10.42.0.1/", 302)


@app.context_processor
def inject_i18n():
    lang = session.get("lang", DEFAULT_LANG)
    T    = get_t(lang)
    def t(key, **kw):
        val = T.get(key, key)
        return val.format(**kw) if kw else val
    return {"t": t, "lang": lang, "lang_labels": LANG_LABELS, "supported_langs": SUPPORTED_LANGS}


@app.route("/lang")
def set_lang():
    lang = request.args.get("code", DEFAULT_LANG)
    if lang not in SUPPORTED_LANGS:
        lang = DEFAULT_LANG
    session["lang"] = lang
    referrer = request.referrer
    return redirect(referrer if referrer else "/configure")

# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.route("/")
def index():
    if _setup_started:
        return redirect("/progress")
    return redirect("/configure")


@app.route("/wifi")
def wifi_page():
    return render_template("wifi.html", networks=get_wifi_networks())


@app.route("/wifi/rescan")
def wifi_rescan():
    return jsonify(get_wifi_networks())


@app.route("/wifi/connect", methods=["POST"])
def wifi_connect():
    data = request.get_json(silent=True) or {}
    ssid = str(data.get("ssid", "")).strip()
    password = str(data.get("password", "")).strip()

    if not ssid or len(ssid) > 32:
        return jsonify({"success": False, "error": "SSID invalide"})

    try:
        cmd = ["nmcli", "dev", "wifi", "connect", ssid]
        if password:
            cmd += ["password", password]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return jsonify({"success": True})
        error = (result.stderr or result.stdout).strip()
        return jsonify({"success": False, "error": error})
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "error": "Délai de connexion dépassé (30 s)"})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})


@app.route("/configure")
def configure_page():
    error = request.args.get("error", "")
    return render_template(
        "configure.html",
        timezones=get_timezones(),
        locales=LOCALES,
        ethernet=ethernet_connected(),
        current_ip=get_current_ip(),
        error=error,
    )


@app.route("/configure/apply", methods=["POST"])
def apply_config():
    global _config

    # Validation et nettoyage
    T = get_t(session.get("lang", DEFAULT_LANG))

    hostname = re.sub(r"[^a-zA-Z0-9\-]", "", request.form.get("hostname", "runtipios"))[:63] or "runtipios"
    username = re.sub(r"[^a-zA-Z0-9_\-]", "", request.form.get("username", ""))[:32]
    password = request.form.get("password", "")
    confirm  = request.form.get("confirm_password", "")
    ssh_port_raw = request.form.get("ssh_port", "22").strip()

    if not username:
        return redirect(f"/configure?error={quote(T['err_username_required'])}")
    if not password or len(password) < 8:
        return redirect(f"/configure?error={quote(T['err_password_short'])}")
    if password != confirm:
        return redirect(f"/configure?error={quote(T['err_password_mismatch'])}")

    try:
        ssh_port_int = int(ssh_port_raw)
        if not (1 <= ssh_port_int <= 65535):
            raise ValueError
        ssh_port = str(ssh_port_int)
    except ValueError:
        return redirect(f"/configure?error={quote(T['err_ssh_port_invalid'])}")

    ssh_key = request.form.get("ssh_key", "").strip()
    disable_pass = request.form.get("disable_password_auth") == "on"

    # IP statique — validation basique
    static_ip = request.form.get("static_ip", "").strip()
    static_gw = request.form.get("static_gw", "").strip()
    static_dns = request.form.get("static_dns", "8.8.8.8").strip()
    ip_pattern = re.compile(r"^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$")
    if static_ip and not ip_pattern.match(static_ip):
        static_ip = ""
    if static_gw and not ip_pattern.match(static_gw):
        static_gw = ""

    wifi_ssid = request.form.get("wifi_ssid", "").strip()
    wifi_password = request.form.get("wifi_password", "").strip()
    cockpit_enabled = request.form.get("cockpit_enabled") == "1"

    _config = {
        "hostname":              hostname,
        "username":              username,
        "password":              password,
        "ssh_port":              ssh_port,
        "ssh_key":               ssh_key,
        "disable_password_auth": disable_pass and bool(ssh_key),
        "timezone":              request.form.get("timezone", "Europe/Paris"),
        "locale":                request.form.get("locale", "fr_FR.UTF-8"),
        "static_ip":             static_ip,
        "static_gw":             static_gw,
        "static_dns":            static_dns,
        "wifi_ssid":             wifi_ssid,
        "wifi_password":         wifi_password,
        "cockpit_enabled":       cockpit_enabled,
        "lang":                  session.get("lang", DEFAULT_LANG),
    }

    # Lancer le thread dès maintenant (ne pas attendre que le SSE se connecte)
    with _setup_lock:
        global _setup_started
        if not _setup_started:
            _setup_started = True
            t = threading.Thread(target=_run_setup, daemon=True)
            t.start()

    return redirect("/progress")


@app.route("/progress")
def progress_page():
    if not _config:
        return redirect("/")
    return render_template("progress.html", hostname=_config.get("hostname", "runtipios"))


# ---------------------------------------------------------------------------
# SSE — Progression en temps réel
# ---------------------------------------------------------------------------

def _append_log(msg: str, level: str = "log") -> dict:
    entry = {"msg": msg, "level": level}
    _progress_log.append(entry)
    return entry


def _run_setup():
    """Thread de configuration système — lit _config, écrit dans _progress_log."""
    global _setup_done

    def step(msg):  _append_log(msg, "step")
    def done(msg):  _append_log(msg, "success")
    def err(msg):   _append_log(msg, "error")
    def out(msg):   _append_log(msg, "log")

    try:
        _run_setup_inner(step, done, err, out)
    except Exception as e:
        _append_log(f"Erreur inattendue du thread : {e}", "error")
    finally:
        _setup_done = True


def _run_setup_inner(step, done, err, out):
    T = get_t(_config.get("lang", DEFAULT_LANG))

    # Écriture de la config dans un fichier temporaire (évite les env vars avec mdp)
    config_path = "/tmp/tipi-config.json"
    try:
        with open(config_path, "w") as f:
            json.dump(_config, f)
        os.chmod(config_path, 0o600)
    except Exception as e:
        err(T["setup_write_error"].format(e=e))
        return

    step(T["setup_starting"])

    try:
        process = subprocess.Popen(
            ["python3", "/opt/tipi-setup/setup.py", config_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
    except Exception as e:
        err(T["setup_launch_error"].format(e=e))
        return

    final_ip = None
    for raw_line in iter(process.stdout.readline, ""):
        line = raw_line.rstrip()
        if not line:
            continue
        if line.startswith("TIPI_IP:"):
            final_ip = line.split(":", 1)[1].strip()
        elif line.startswith("TIPI_STEP:"):
            step(line.split(":", 1)[1].strip())
        elif line.startswith("TIPI_DONE:"):
            done(line.split(":", 1)[1].strip())
        elif line.startswith("TIPI_ERROR:"):
            err(line.split(":", 1)[1].strip())
        else:
            out(line)

    process.wait()

    hostname = _config.get("hostname", "runtipios")
    ssh_port = _config.get("ssh_port", "22")

    # Nettoyage : on désactive le service (ne se relancera plus au prochain boot)
    subprocess.run(["systemctl", "disable", "tipi-setup.service"], capture_output=True)
    # Arrêter hostapd/dnsmasq si toujours actifs (cas sans WiFi configuré)
    subprocess.run(["pkill", "-f", "tipi-hostapd.conf"], capture_output=True)
    subprocess.run(["pkill", "-f", "tipi-dnsmasq"], capture_output=True)
    try:
        os.remove("/var/lib/tipi-setup/.not-configured")
    except FileNotFoundError:
        pass

    if process.returncode == 0:
        _progress_log.append({
            "level":    "final",
            "msg":      T["setup_complete"],
            "ip":       final_ip,
            "hostname": hostname,
            "ssh_port": ssh_port,
        })
    else:
        err(T["setup_error"])


@app.route("/progress/log")
def progress_log_poll():
    """Polling endpoint — retourne les entrées du log depuis l'index `from`."""
    since = request.args.get("from", 0, type=int)
    entries = _progress_log[since:]
    return jsonify({
        "entries": entries,
        "done":    _setup_done,
        "total":   len(_progress_log),
    })


@app.route("/reboot", methods=["POST"])
def reboot():
    """Redémarre le Pi après un court délai (laisse la réponse partir)."""
    def _do_reboot():
        time.sleep(2)
        subprocess.run(["systemctl", "reboot"], check=False)
    threading.Thread(target=_do_reboot, daemon=True).start()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=8080,
        debug=False,
        threaded=True,
        use_reloader=False,
    )
