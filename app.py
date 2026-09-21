#!/usr/bin/env python3
import os
import sys
import json
import shutil
import urllib.parse
import mimetypes
import zipfile
import tempfile
import re
import secrets
import time
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler

PORT = int(os.environ.get("PORT", 8080))
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

AUTH_USER = os.environ.get("NAS_USER", "Wesley")
AUTH_PASS = os.environ.get("NAS_PASS", "210769")

ACTIVE_SESSIONS = {}
SESSION_EXPIRY = 7 * 24 * 3600


def is_valid_token(token):
    if not token:
        return False
    if token in ACTIVE_SESSIONS:
        if time.time() < ACTIVE_SESSIONS[token]:
            return True
        else:
            del ACTIVE_SESSIONS[token]
    return False


def get_storage_drives():
    drives = []
    seen_paths = set()
    seen_devs = set()

    def add_drive(drive_id, name, path, drive_type):
        if not path:
            return
        real_path = os.path.realpath(path)
        if not os.path.exists(real_path) or real_path in seen_paths:
            return
        try:
            usage = shutil.disk_usage(real_path)
            if usage.total < 100 * 1024 * 1024:  # Ignorar partições menores que 100MB
                return

            stat = os.stat(real_path)
            dev_id = stat.st_dev

            seen_paths.add(real_path)
            seen_devs.add(dev_id)

            drives.append({
                "id": drive_id,
                "name": name,
                "path": real_path,
                "type": drive_type,
                "total": usage.total,
                "used": usage.used,
                "free": usage.free,
                "percent": round((usage.used / usage.total) * 100, 1) if usage.total > 0 else 0
            })
        except Exception:
            pass

    # 1. Armazenamento Interno
    add_drive("internal", "Armazenamento Interno", "/storage/emulated/0", "internal")

    # 2. Varredura Inteligente do /proc/mounts (Detecta o seu HD vold/sdfat/exfat)
    if os.path.exists("/proc/mounts"):
        try:
            with open("/proc/mounts", "r") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 3:
                        dev = parts[0]
                        mp = parts[1]
                        fs = parts[2].lower()

                        # Detecta partições vold (ex: /dev/block/vold/public:8,2) ou exfat/sdfat/vfat/ntfs
                        if "vold" in dev or any(x in fs for x in ["sdfat", "exfat", "vfat", "ntfs", "fuseblk"]):
                            if not any(x in mp for x in ["/emulated", "/self", "/knox", "apex"]):
                                uuid = os.path.basename(mp)
                                # Tenta todos os caminhos onde o Android disponibiliza este HD
                                candidate_paths = [
                                    f"/storage/{uuid}",
                                    f"/mnt/user/0/{uuid}",
                                    f"/mnt/pass_through/0/{uuid}",
                                    f"/mnt/runtime/default/{uuid}",
                                    f"/mnt/media_rw/{uuid}",
                                    mp
                                ]
                                for cand in candidate_paths:
                                    if os.path.exists(cand):
                                        add_drive(f"otg_{uuid}", f"HD Externo USB ({uuid})", cand, "otg")
                                        break
        except Exception:
            pass

    # 3. Varredura direta na pasta /storage
    if os.path.exists("/storage"):
        try:
            for item in os.listdir("/storage"):
                if re.match(r'^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$', item):
                    p = os.path.join("/storage", item)
                    add_drive(f"storage_{item}", f"HD Externo USB ({item})", p, "otg")
        except Exception:
            pass

    # 4. Termux Storage
    termux_storage = os.path.expanduser("~/storage")
    if os.path.exists(termux_storage):
        try:
            for item in os.listdir(termux_storage):
                if item.startswith("external"):
                    target = os.path.realpath(os.path.join(termux_storage, item))
                    add_drive("termux_ext", "HD Externo USB", target, "otg")
        except Exception:
            pass

    return drives


def get_file_category(filename: str, is_dir: bool) -> str:
    if is_dir:
        return "folder"
    ext = os.path.splitext(filename)[1].lower()
    if ext in ['.mp4', '.mkv', '.webm', '.avi', '.mov', '.flv', '.wmv', '.3gp', '.m4v']:
        return "video"
    elif ext in ['.mp3', '.wav', '.flac', '.ogg', '.aac', '.m4a', '.opus', '.wma']:
        return "audio"
    elif ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.ico', '.tiff']:
        return "image"
    elif ext in ['.pdf']:
        return "pdf"
    elif ext in ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.apk', '.iso']:
        return "archive"
    elif ext in ['.txt', '.md', '.log', '.json', '.xml', '.html', '.css', '.js', '.py', '.sh', '.yaml', '.yml', '.csv']:
        return "code"
    elif ext in ['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.odt', '.ods']:
        return "document"
    return "file"


def get_system_status():
    battery_info = {"percent": None, "charging": False, "present": False}
    try:
        if os.path.exists("/sys/class/power_supply/battery/capacity"):
            with open("/sys/class/power_supply/battery/capacity") as f:
                cap = int(f.read().strip())
            chg = False
            if os.path.exists("/sys/class/power_supply/battery/status"):
                with open("/sys/class/power_supply/battery/status") as f:
                    chg = f.read().strip().lower() in ["charging", "full"]
            battery_info = {"percent": cap, "charging": chg, "present": True}
    except Exception:
        pass

    mem_info = {"total": 0, "used": 0, "free": 0, "percent": 0}
    if os.path.exists("/proc/meminfo"):
        try:
            md = {}
            with open("/proc/meminfo") as f:
                for line in f:
                    p = line.split(":")
                    if len(p) == 2:
                        md[p[0].strip()] = int(p[1].split()[0]) * 1024
            t = md.get("MemTotal", 0)
            av = md.get("MemAvailable", md.get("MemFree", 0))
            used = t - av
            mem_info = {
                "total": t,
                "used": used,
                "free": av,
                "percent": round(((t - av) / t) * 100, 1) if t > 0 else 0
            }
        except Exception:
            pass

    return {
        "user": AUTH_USER,
        "battery": battery_info,
        "memory": mem_info,
        "drives": get_storage_drives()
    }


class NASRequestHandler(BaseHTTPRequestHandler):
    def get_token(self):
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            return auth[7:].strip()
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if "token" in q:
            return q["token"][0]
        cookie = self.headers.get("Cookie", "")
        for c in cookie.split(";"):
            if "nas_token=" in c:
                return c.split("nas_token=")[-1].strip()
        return None

    def is_authenticated(self):
        return is_valid_token(self.get_token())

    def send_json(self, data, status_code=200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):
        pr = urllib.parse.urlparse(self.path)
        path, query = pr.path, urllib.parse.parse_qs(pr.query)

        if path in ["/", "/index.html"]:
            idx = os.path.join(STATIC_DIR, "index.html")
            if os.path.exists(idx):
                with open(idx, "rb") as f:
                    ct = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(ct)))
                self.end_headers()
                self.wfile.write(ct)
            else:
                self.send_json({"error": "Index not found"}, 404)
            return

        if path == "/api/check-auth":
            if self.is_authenticated():
                self.send_json({"authenticated": True, "user": AUTH_USER})
            else:
                self.send_json({"authenticated": False}, 401)
            return

        if not self.is_authenticated():
            self.send_json({"detail": "Não autorizado"}, 401)
            return

        if path == "/api/drives":
            return self.send_json(get_storage_drives())
        if path == "/api/system-status":
            return self.send_json(get_system_status())
        if path == "/api/files":
            dp = query.get("path", [""])[0]
            if not dp or not os.path.exists(dp):
                return self.send_json({"detail": "Não encontrado"}, 404)
            try:
                items = []
                with os.scandir(dp) as sc:
                    for e in sc:
                        try:
                            st = e.stat()
                            is_d = e.is_dir(follow_symlinks=True)
                            items.append({
                                "name": e.name,
                                "path": os.path.abspath(e.path),
                                "is_dir": is_d,
                                "size": st.st_size if not is_d else 0,
                                "modified": st.st_mtime,
                                "category": get_file_category(e.name, is_d)
                            })
                        except Exception:
                            pass
                items.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
                parent = os.path.dirname(os.path.abspath(dp))
                if parent == os.path.abspath(dp):
                    parent = None
                return self.send_json({
                    "current_path": os.path.abspath(dp),
                    "parent_path": parent,
                    "items": items,
                    "count": len(items)
                })
            except Exception as e:
                return self.send_json({"detail": str(e)}, 500)
        if path == "/api/stream":
            fp = query.get("path", [""])[0]
            if not fp or not os.path.exists(fp) or os.path.isdir(fp):
                return self.send_json({"detail": "Não encontrado"}, 404)
            self.serve_file_with_range(fp)
            return
        if path == "/api/download-zip":
            dp = query.get("path", [""])[0]
            if not dp or not os.path.exists(dp):
                return self.send_json({"detail": "Não encontrado"}, 404)
            self.serve_folder_zip(dp)
            return
        self.send_json({"error": "404"}, 404)

    def do_POST(self):
        pr = urllib.parse.urlparse(self.path)
        path = pr.path
        cl = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(cl) if cl > 0 else b""
        ct = self.headers.get("Content-Type", "")

        if path == "/api/login":
            try:
                data = json.loads(raw.decode("utf-8"))
            except Exception:
                data = self.parse_form_dict(raw, ct)
            user, pwd = data.get("username", "").strip(), data.get("password", "").strip()
            if user == AUTH_USER and pwd == AUTH_PASS:
                token = secrets.token_hex(24)
                ACTIVE_SESSIONS[token] = time.time() + SESSION_EXPIRY
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Set-Cookie", f"nas_token={token}; Path=/; Max-Age={SESSION_EXPIRY}; SameSite=Lax")
                self.end_headers()
                self.wfile.write(json.dumps({"success": True, "token": token, "user": AUTH_USER}).encode("utf-8"))
            else:
                self.send_json({"success": False, "detail": "Usuário ou senha incorretos."}, 401)
            return

        if path == "/api/logout":
            token = self.get_token()
            if token in ACTIVE_SESSIONS:
                del ACTIVE_SESSIONS[token]
            self.send_json({"success": True})
            return

        if not self.is_authenticated():
            return self.send_json({"detail": "Não autorizado"}, 401)

        if path == "/api/mkdir":
            params = self.parse_form_dict(raw, ct)
            parent, name = params.get("parent_path", ""), params.get("name", "").strip()
            if parent and name:
                os.makedirs(os.path.join(parent, name), exist_ok=True)
                return self.send_json({"success": True})
            return self.send_json({"detail": "Parâmetros inválidos"}, 400)
        if path == "/api/upload":
            bd = ct.split("boundary=")[-1].strip().encode()
            parts = raw.split(b"--" + bd)
            target = None
            for pt in parts:
                if b'name="target_path"' in pt:
                    target = pt.partition(b"\r\n\r\n")[2].rstrip(b"\r\n").decode("utf-8", errors="replace").strip()
                    break
            if target and os.path.exists(target):
                for pt in parts:
                    if b'filename="' in pt:
                        hdr, _, bdy = pt.partition(b"\r\n\r\n")
                        m = re.search(rb'filename="([^"]+)"', hdr)
                        if m:
                            fn = m.group(1).decode("utf-8", errors="replace").strip()
                            if fn:
                                with open(os.path.join(target, fn), "wb") as f:
                                    f.write(bdy.rstrip(b"\r\n"))
            return self.send_json({"success": True})
        self.send_json({"error": "404"}, 404)

    def parse_form_dict(self, raw, ct):
        if "multipart" in ct:
            bd = ct.split("boundary=")[-1].strip().encode()
            parts = raw.split(b"--" + bd)
            flds = {}
            for part in parts:
                if b'name="' in part:
                    hdr, _, bdy = part.partition(b"\r\n\r\n")
                    m = re.search(rb'name="([^"]+)"', hdr)
                    if m:
                        flds[m.group(1).decode("utf-8")] = bdy.rstrip(b"\r\n").decode("utf-8", errors="replace")
            return flds
        parsed = urllib.parse.parse_qs(raw.decode("utf-8", errors="replace"))
        return {k: v[0] if len(v) == 1 else v for k, v in parsed.items()}

    def serve_folder_zip(self, dir_path):
        fn = os.path.basename(os.path.abspath(dir_path)) or "download"
        tz = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        try:
            with zipfile.ZipFile(tz.name, 'w', zipfile.ZIP_DEFLATED) as zf:
                for r, d, fls in os.walk(dir_path):
                    for file in fls:
                        fa = os.path.join(r, file)
                        zf.write(fa, arcname=os.path.relpath(fa, dir_path))
            sz = os.path.getsize(tz.name)
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Disposition", f'attachment; filename="{fn}.zip"')
            self.send_header("Content-Length", str(sz))
            self.end_headers()
            with open(tz.name, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
        finally:
            if os.path.exists(tz.name):
                try:
                    os.remove(tz.name)
                except Exception:
                    pass

    def serve_file_with_range(self, file_path):
        sz = os.path.getsize(file_path)
        mime, _ = mimetypes.guess_type(file_path)
        mime = mime or "application/octet-stream"
        fn = os.path.basename(file_path)
        rng = self.headers.get("Range")
        if rng and rng.startswith("bytes="):
            parts = rng[6:].split("-")
            s = int(parts[0]) if parts[0] else 0
            e = int(parts[1]) if len(parts) > 1 and parts[1] else sz - 1
            s, e = max(0, s), min(sz - 1, e)
            l = e - s + 1
            self.send_response(206)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Range", f"bytes {s}-{e}/{sz}")
            self.send_header("Content-Length", str(l))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()
            with open(file_path, "rb") as f:
                f.seek(s)
                left = l
                while left > 0:
                    ck = f.read(min(64 * 1024, left))
                    if not ck:
                        break
                    try:
                        self.wfile.write(ck)
                    except Exception:
                        break
                    left -= len(ck)
        else:
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(sz))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Disposition", f'inline; filename="{fn}"')
            self.end_headers()
            with open(file_path, "rb") as f:
                while ck := f.read(64 * 1024):
                    try:
                        self.wfile.write(ck)
                    except Exception:
                        break


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), NASRequestHandler)
    print("==========================================================")
    print("       🛡️  SISTEMA NAS PROFISSIONAL ANDROID (OTG)         ")
    print("==========================================================")
    print(f" [*] Usuário Administrador : {AUTH_USER}")
    print(f" [*] Senha de Acesso       : {AUTH_PASS}")
    print(f" [*] Servidor Rodando em   : http://0.0.0.0:{PORT}")
    print("==========================================================")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()