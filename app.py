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

# Credenciais Padrão do NAS
AUTH_USER = os.environ.get("NAS_USER", "Wesley")
AUTH_PASS = os.environ.get("NAS_PASS", "210769")

# Armazenamento de Sessões Ativas (Token -> Timestamp de expiração)
ACTIVE_SESSIONS = {}
SESSION_EXPIRY = 7 * 24 * 3600  # 7 dias


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

    # 1. Armazenamento Interno do Android
    android_internal = "/storage/emulated/0"
    if os.path.exists(android_internal):
        try:
            u = shutil.disk_usage(android_internal)
            drives.append({
                "id": "internal",
                "name": "Armazenamento Interno",
                "path": android_internal,
                "type": "internal",
                "total": u.total,
                "used": u.used,
                "free": u.free,
                "percent": round((u.used / u.total) * 100, 1) if u.total > 0 else 0
            })
        except Exception:
            pass

    # 2. USB OTG / SD Cards em /storage
    if os.path.exists("/storage"):
        try:
            for item in os.listdir("/storage"):
                if item not in ["emulated", "self", "knox", "container"]:
                    p = os.path.join("/storage", item)
                    if os.path.isdir(p) and os.access(p, os.R_OK):
                        try:
                            u = shutil.disk_usage(p)
                            drives.append({
                                "id": f"otg_{item}",
                                "name": f"USB OTG / Drive ({item})",
                                "path": p,
                                "type": "otg",
                                "total": u.total,
                                "used": u.used,
                                "free": u.free,
                                "percent": round((u.used / u.total) * 100, 1) if u.total > 0 else 0
                            })
                        except Exception:
                            pass
        except Exception:
            pass

    # 3. /mnt/media_rw para HDs externos
    if os.path.exists("/mnt/media_rw"):
        try:
            for item in os.listdir("/mnt/media_rw"):
                p = os.path.join("/mnt/media_rw", item)
                if os.path.isdir(p) and not any(d["path"] == p for d in drives):
                    try:
                        u = shutil.disk_usage(p)
                        drives.append({
                            "id": f"media_rw_{item}",
                            "name": f"USB HD OTG ({item})",
                            "path": p,
                            "type": "otg",
                            "total": u.total,
                            "used": u.used,
                            "free": u.free,
                            "percent": round((u.used / u.total) * 100, 1) if u.total > 0 else 0
                        })
                    except Exception:
                        pass
        except Exception:
            pass

    # 4. Termux Home
    home = os.environ.get("HOME", "/data/data/com.termux/files/home")
    if os.path.exists(home) and not any(d["path"] == home for d in drives):
        try:
            u = shutil.disk_usage(home)
            drives.append({
                "id": "home",
                "name": "Termux Home",
                "path": home,
                "type": "home",
                "total": u.total,
                "used": u.used,
                "free": u.free,
                "percent": round((u.used / u.total) * 100, 1) if u.total > 0 else 0
            })
        except Exception:
            pass

    # 5. Fallback para diretório atual
    if not drives:
        cwd = os.getcwd()
        u = shutil.disk_usage(cwd)
        drives.append({
            "id": "default",
            "name": "Diretório Principal",
            "path": cwd,
            "type": "fixed",
            "total": u.total,
            "used": u.used,
            "free": u.free,
            "percent": round((u.used / u.total) * 100, 1) if u.total > 0 else 0
        })

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
    elif ext in ['.txt', '.md', '.log', '.json', '.xml', '.html', '.css', '.js', '.py', '.sh', '.yaml', '.yml', '.csv', '.c', '.cpp', '.java']:
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
                "percent": round((used / t) * 100, 1) if t > 0 else 0
            }
        except Exception:
            pass

    return {
        "user": AUTH_USER,
        "battery": battery_info,
        "memory": mem_info,
        "uptime": time.time(),
        "drives": get_storage_drives()
    }


class NASRequestHandler(BaseHTTPRequestHandler):
    def get_token(self):
        # 1. Header Authorization: Bearer <token>
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            return auth[7:].strip()
        # 2. Query param ?token=<token>
        parsed = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(parsed.query)
        if "token" in q:
            return q["token"][0]
        # 3. Cookie
        cookie_header = self.headers.get("Cookie", "")
        for c in cookie_header.split(";"):
            if "nas_token=" in c:
                return c.split("nas_token=")[-1].strip()
        return None

    def is_authenticated(self):
        token = self.get_token()
        return is_valid_token(token)

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
        path = pr.path
        query = urllib.parse.parse_qs(pr.query)

        # 1. Rotas públicas (Interface estática)
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

        if path.startswith("/static/"):
            fp = os.path.join(STATIC_DIR, path[8:])
            if os.path.exists(fp) and os.path.isfile(fp):
                mime, _ = mimetypes.guess_type(fp)
                with open(fp, "rb") as f:
                    ct = f.read()
                self.send_response(200)
                self.send_header("Content-Type", mime or "application/octet-stream")
                self.send_header("Content-Length", str(len(ct)))
                self.end_headers()
                self.wfile.write(ct)
            else:
                self.send_json({"error": "Static not found"}, 404)
            return

        # 2. Rota de verificação de autenticação
        if path == "/api/check-auth":
            if self.is_authenticated():
                self.send_json({"authenticated": True, "user": AUTH_USER})
            else:
                self.send_json({"authenticated": False}, 401)
            return

        # 3. Proteção das APIs com autenticação
        if not self.is_authenticated():
            self.send_json({"detail": "Não autorizado. Faça login primeiro."}, 401)
            return

        # 4. APIs Protegidas do NAS
        if path == "/api/drives":
            return self.send_json(get_storage_drives())

        if path == "/api/system-status":
            return self.send_json(get_system_status())

        if path == "/api/files":
            dp = query.get("path", [""])[0]
            if not dp or not os.path.exists(dp):
                return self.send_json({"detail": "Diretório não encontrado"}, 404)
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
                return self.send_json({"detail": "Arquivo não encontrado"}, 404)
            self.serve_file_with_range(fp)
            return

        if path == "/api/download-zip":
            dp = query.get("path", [""])[0]
            if not dp or not os.path.exists(dp):
                return self.send_json({"detail": "Diretório não encontrado"}, 404)
            self.serve_folder_zip(dp)
            return

        if path == "/api/text-content":
            fp = query.get("path", [""])[0]
            if not fp or not os.path.exists(fp):
                return self.send_json({"detail": "Arquivo não encontrado"}, 404)
            try:
                with open(fp, "r", encoding="utf-8", errors="replace") as f:
                    ct = f.read(5 * 1024 * 1024)
                return self.send_json({"content": ct, "filename": os.path.basename(fp)})
            except Exception as e:
                return self.send_json({"detail": str(e)}, 500)

        self.send_json({"error": "Endpoint não encontrado"}, 404)

    def do_POST(self):
        pr = urllib.parse.urlparse(self.path)
        path = pr.path
        cl = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(cl) if cl > 0 else b""
        ct = self.headers.get("Content-Type", "")

        # 1. Login Endpoint (Público)
        if path == "/api/login":
            try:
                data = json.loads(raw.decode("utf-8"))
            except Exception:
                data = self.parse_form_dict(raw, ct)
            user = data.get("username", "").strip()
            pwd = data.get("password", "").strip()

            if user == AUTH_USER and pwd == AUTH_PASS:
                token = secrets.token_hex(24)
                ACTIVE_SESSIONS[token] = time.time() + SESSION_EXPIRY
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Set-Cookie", f"nas_token={token}; Path=/; Max-Age={SESSION_EXPIRY}; SameSite=Lax")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps({"success": True, "token": token, "user": AUTH_USER}).encode("utf-8"))
                return
            else:
                return self.send_json({"success": False, "detail": "Usuário ou senha incorretos."}, 401)

        # 2. Logout Endpoint
        if path == "/api/logout":
            token = self.get_token()
            if token in ACTIVE_SESSIONS:
                del ACTIVE_SESSIONS[token]
            self.send_response(200)
            self.send_header("Set-Cookie", "nas_token=; Path=/; Max-Age=0")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(b'{"success": true}')
            return

        # 3. Proteção das demais APIs POST
        if not self.is_authenticated():
            return self.send_json({"detail": "Não autorizado"}, 401)

        if path == "/api/mkdir":
            params = self.parse_form_dict(raw, ct)
            parent = params.get("parent_path", "")
            name = params.get("name", "").strip()
            if parent and name:
                os.makedirs(os.path.join(parent, name), exist_ok=True)
                return self.send_json({"success": True})
            return self.send_json({"detail": "Parâmetros inválidos"}, 400)

        if path == "/api/rename":
            params = self.parse_form_dict(raw, ct)
            old_p = params.get("old_path", "")
            new_n = params.get("new_name", "").strip()
            if old_p and new_n and os.path.exists(old_p):
                os.rename(old_p, os.path.join(os.path.dirname(old_p), new_n))
                return self.send_json({"success": True})
            return self.send_json({"detail": "Item não encontrado"}, 404)

        if path == "/api/delete":
            params = self.parse_form_dict(raw, ct)
            paths = params.get("paths", [])
            if isinstance(paths, str):
                paths = [paths]
            for itm in paths:
                try:
                    if os.path.isdir(itm):
                        shutil.rmtree(itm)
                    elif os.path.exists(itm):
                        os.remove(itm)
                except Exception:
                    pass
            return self.send_json({"deleted": paths})

        if path == "/api/upload":
            bd = ct.split("boundary=")[-1].strip().encode()
            parts = raw.split(b"--" + bd)
            target = None
            saved = []
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
                                saved.append(fn)
            return self.send_json({"success": True, "saved": saved})

        self.send_json({"error": "Endpoint não encontrado"}, 404)

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
        folder_name = os.path.basename(os.path.abspath(dir_path)) or "download"
        temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        try:
            with zipfile.ZipFile(temp_zip.name, 'w', zipfile.ZIP_DEFLATED) as zf:
                for r, d, fls in os.walk(dir_path):
                    for file in fls:
                        fa = os.path.join(r, file)
                        zf.write(fa, arcname=os.path.relpath(fa, dir_path))
            sz = os.path.getsize(temp_zip.name)
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Disposition", f'attachment; filename="{folder_name}.zip"')
            self.send_header("Content-Length", str(sz))
            self.end_headers()
            with open(temp_zip.name, "rb") as f:
                shutil.copyfileobj(f, self.wfile)
        finally:
            if os.path.exists(temp_zip.name):
                try:
                    os.remove(temp_zip.name)
                except Exception:
                    pass

    def serve_file_with_range(self, file_path):
        file_size = os.path.getsize(file_path)
        mime, _ = mimetypes.guess_type(file_path)
        mime = mime or "application/octet-stream"
        filename = os.path.basename(file_path)

        rng = self.headers.get("Range")
        if rng and rng.startswith("bytes="):
            parts = rng[6:].split("-")
            s = int(parts[0]) if parts[0] else 0
            e = int(parts[1]) if len(parts) > 1 and parts[1] else file_size - 1
            s, e = max(0, s), min(file_size - 1, e)
            l = e - s + 1
            self.send_response(206)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Range", f"bytes {s}-{e}/{file_size}")
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
            self.send_header("Content-Length", str(file_size))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Disposition", f'inline; filename="{filename}"')
            self.end_headers()
            with open(file_path, "rb") as f:
                while ck := f.read(64 * 1024):
                    try:
                        self.wfile.write(ck)
                    except Exception:
                        break


def run():
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
        print("\n[*] Servidor encerrado.")
        server.server_close()


if __name__ == "__main__":
    run()