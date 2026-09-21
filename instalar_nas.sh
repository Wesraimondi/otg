#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
#   Script Tudo-em-Um: Instalação e Inicialização do NAS
# ==========================================================

clear
echo -e "\033[1;36m========================================================\033[0m"
echo -e "\033[1;32m      🚀 CONFIGURANDO SERVIDOR NAS NO ANDROID           \033[0m"
echo -e "\033[1;36m========================================================\033[0m"
echo ""

# 1. Permissões de armazenamento
echo -e "\033[1;33m[*] Verificando permissões de armazenamento...\033[0m"
termux-setup-storage
sleep 2

# 2. Instalar Python caso não esteja instalado
echo -e "\033[1;33m[*] Verificando Python...\033[0m"
pkg update -y
pkg install -y python

# 3. Ativar wake-lock para não suspender com a tela apagada
echo -e "\033[1;33m[*] Ativando segundo plano (Wake-Lock)...\033[0m"
termux-wake-lock 2>/dev/null || true

# 4. Gerar o arquivo app.py 100% nativo (sem erros de dependência)
echo -e "\033[1;33m[*] Gerando app.py nativo...\033[0m"
cat << 'EOF' > app.py
#!/usr/bin/env python3
import os, sys, json, shutil, urllib.parse, mimetypes, zipfile, tempfile, re
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler

PORT = int(os.environ.get("PORT", 8080))
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

def get_storage_drives():
    drives = []
    android_internal = "/storage/emulated/0"
    if os.path.exists(android_internal):
        try:
            u = shutil.disk_usage(android_internal)
            drives.append({"id": "internal", "name": "Armazenamento Interno", "path": android_internal, "type": "internal", "total": u.total, "used": u.used, "free": u.free, "percent": round((u.used/u.total)*100, 1) if u.total>0 else 0})
        except Exception: pass

    if os.path.exists("/storage"):
        try:
            for item in os.listdir("/storage"):
                if item not in ["emulated", "self", "knox", "container"]:
                    p = os.path.join("/storage", item)
                    if os.path.isdir(p) and os.access(p, os.R_OK):
                        try:
                            u = shutil.disk_usage(p)
                            drives.append({"id": f"otg_{item}", "name": f"USB OTG / SD ({item})", "path": p, "type": "otg", "total": u.total, "used": u.used, "free": u.free, "percent": round((u.used/u.total)*100, 1) if u.total>0 else 0})
                        except Exception: pass
        except Exception: pass

    if os.path.exists("/mnt/media_rw"):
        try:
            for item in os.listdir("/mnt/media_rw"):
                p = os.path.join("/mnt/media_rw", item)
                if os.path.isdir(p) and not any(d["path"] == p for d in drives):
                    try:
                        u = shutil.disk_usage(p)
                        drives.append({"id": f"media_rw_{item}", "name": f"USB Drive OTG ({item})", "path": p, "type": "otg", "total": u.total, "used": u.used, "free": u.free, "percent": round((u.used/u.total)*100, 1) if u.total>0 else 0})
                    except Exception: pass
        except Exception: pass

    home = os.environ.get("HOME", "/data/data/com.termux/files/home")
    if os.path.exists(home) and not any(d["path"] == home for d in drives):
        try:
            u = shutil.disk_usage(home)
            drives.append({"id": "home", "name": "Termux Home", "path": home, "type": "home", "total": u.total, "used": u.used, "free": u.free, "percent": round((u.used/u.total)*100, 1) if u.total>0 else 0})
        except Exception: pass

    if not drives:
        cwd = os.getcwd()
        u = shutil.disk_usage(cwd)
        drives.append({"id": "default", "name": "Diretório Principal", "path": cwd, "type": "fixed", "total": u.total, "used": u.used, "free": u.free, "percent": round((u.used/u.total)*100, 1) if u.total>0 else 0})

    return drives

def get_cat(fn, is_d):
    if is_d: return "folder"
    e = os.path.splitext(fn)[1].lower()
    if e in ['.mp4','.mkv','.webm','.avi','.mov','.flv','.wmv','.3gp','.m4v']: return "video"
    if e in ['.mp3','.wav','.flac','.ogg','.aac','.m4a','.opus']: return "audio"
    if e in ['.jpg','.jpeg','.png','.gif','.webp','.svg','.bmp','.ico']: return "image"
    if e in ['.pdf']: return "pdf"
    if e in ['.zip','.rar','.7z','.tar','.gz','.bz2','.xz','.apk']: return "archive"
    if e in ['.txt','.md','.log','.json','.xml','.html','.css','.js','.py','.sh']: return "code"
    return "document" if e in ['.doc','.docx','.xls','.xlsx','.ppt','.pptx'] else "file"

def get_sys():
    b = {"percent": None, "charging": False, "present": False}
    try:
        if os.path.exists("/sys/class/power_supply/battery/capacity"):
            with open("/sys/class/power_supply/battery/capacity") as f: cap = int(f.read().strip())
            chg = False
            if os.path.exists("/sys/class/power_supply/battery/status"):
                with open("/sys/class/power_supply/battery/status") as f: chg = f.read().strip().lower() in ["charging","full"]
            b = {"percent": cap, "charging": chg, "present": True}
    except Exception: pass
    m = {"total": 0, "used": 0, "free": 0, "percent": 0}
    if os.path.exists("/proc/meminfo"):
        try:
            md = {}
            with open("/proc/meminfo") as f:
                for line in f:
                    p = line.split(":")
                    if len(p)==2: md[p[0].strip()] = int(p[1].split()[0])*1024
            t, av = md.get("MemTotal",0), md.get("MemAvailable", md.get("MemFree",0))
            m = {"total": t, "used": t-av, "free": av, "percent": round(((t-av)/t)*100,1) if t>0 else 0}
        except Exception: pass
    return {"battery": b, "memory": m, "cpu_percent": 0, "drives": get_storage_drives()}

class Handler(BaseHTTPRequestHandler):
    def send_j(self, d, s=200):
        b = json.dumps(d).encode("utf-8")
        self.send_response(s)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(b)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):
        pr = urllib.parse.urlparse(self.path)
        p, q = pr.path, urllib.parse.parse_qs(pr.query)
        if p in ["/", "/index.html"]:
            idx = os.path.join(STATIC_DIR, "index.html")
            if os.path.exists(idx):
                with open(idx, "rb") as f: ct = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(ct)))
                self.end_headers()
                self.wfile.write(ct)
            else: self.send_j({"error": "Index not found"}, 404)
            return
        if p.startswith("/static/"):
            fp = os.path.join(STATIC_DIR, p[8:])
            if os.path.exists(fp) and os.path.isfile(fp):
                mime, _ = mimetypes.guess_type(fp)
                with open(fp, "rb") as f: ct = f.read()
                self.send_response(200)
                self.send_header("Content-Type", mime or "application/octet-stream")
                self.send_header("Content-Length", str(len(ct)))
                self.end_headers()
                self.wfile.write(ct)
            else: self.send_j({"error": "Static not found"}, 404)
            return
        if p == "/api/drives": return self.send_j(get_storage_drives())
        if p == "/api/system-status": return self.send_j(get_sys())
        if p == "/api/files":
            dp = q.get("path", [""])[0]
            if not dp or not os.path.exists(dp): return self.send_j({"detail": "Não encontrado"}, 404)
            try:
                items = []
                with os.scandir(dp) as sc:
                    for e in sc:
                        try:
                            st = e.stat()
                            is_d = e.is_dir(follow_symlinks=True)
                            items.append({"name": e.name, "path": os.path.abspath(e.path), "is_dir": is_d, "size": st.st_size if not is_d else 0, "modified": st.st_mtime, "category": get_cat(e.name, is_d)})
                        except Exception: pass
                items.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
                parent = os.path.dirname(os.path.abspath(dp))
                if parent == os.path.abspath(dp): parent = None
                return self.send_j({"current_path": os.path.abspath(dp), "parent_path": parent, "items": items, "count": len(items)})
            except Exception as e: return self.send_j({"detail": str(e)}, 500)
        if p == "/api/stream":
            fp = q.get("path", [""])[0]
            if not fp or not os.path.exists(fp) or os.path.isdir(fp): return self.send_j({"detail": "Não encontrado"}, 404)
            sz = os.path.getsize(fp)
            mime, _ = mimetypes.guess_type(fp)
            mime = mime or "application/octet-stream"
            rng = self.headers.get("Range")
            if rng and rng.startswith("bytes="):
                parts = rng[6:].split("-")
                s = int(parts[0]) if parts[0] else 0
                e = int(parts[1]) if len(parts)>1 and parts[1] else sz - 1
                s, e = max(0, s), min(sz - 1, e)
                l = e - s + 1
                self.send_response(206)
                self.send_header("Content-Type", mime)
                self.send_header("Content-Range", f"bytes {s}-{e}/{sz}")
                self.send_header("Content-Length", str(l))
                self.send_header("Accept-Ranges", "bytes")
                self.end_headers()
                with open(fp, "rb") as f:
                    f.seek(s)
                    left = l
                    while left > 0:
                        ck = f.read(min(64*1024, left))
                        if not ck: break
                        try: self.wfile.write(ck)
                        except Exception: break
                        left -= len(ck)
            else:
                self.send_response(200)
                self.send_header("Content-Type", mime)
                self.send_header("Content-Length", str(sz))
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Content-Disposition", f'inline; filename="{os.path.basename(fp)}"')
                self.end_headers()
                with open(fp, "rb") as f:
                    while ck := f.read(64*1024):
                        try: self.wfile.write(ck)
                        except Exception: break
            return
        if p == "/api/download-zip":
            dp = q.get("path", [""])[0]
            if not dp or not os.path.exists(dp): return self.send_j({"detail": "Não encontrado"}, 404)
            tz = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
            try:
                with zipfile.ZipFile(tz.name, 'w', zipfile.ZIP_DEFLATED) as zf:
                    for r, d, fls in os.walk(dp):
                        for file in fls:
                            fa = os.path.join(r, file)
                            zf.write(fa, arcname=os.path.relpath(fa, dp))
                sz = os.path.getsize(tz.name)
                self.send_response(200)
                self.send_header("Content-Type", "application/zip")
                self.send_header("Content-Disposition", f'attachment; filename="{os.path.basename(dp) or "download"}.zip"')
                self.send_header("Content-Length", str(sz))
                self.end_headers()
                with open(tz.name, "rb") as f: shutil.copyfileobj(f, self.wfile)
            finally:
                if os.path.exists(tz.name): os.remove(tz.name)
            return
        if p == "/api/text-content":
            fp = q.get("path", [""])[0]
            if not fp or not os.path.exists(fp): return self.send_j({"detail": "Não encontrado"}, 404)
            with open(fp, "r", encoding="utf-8", errors="replace") as f: ct = f.read(5*1024*1024)
            return self.send_j({"content": ct, "filename": os.path.basename(fp)})
        self.send_j({"error": "404"}, 404)

    def do_POST(self):
        pr = urllib.parse.urlparse(self.path)
        p = pr.path
        cl = int(self.headers.get("Content-Length", 0))
        raw = self.rfile.read(cl)
        ct = self.headers.get("Content-Type", "")

        if p == "/api/mkdir":
            params = urllib.parse.parse_qs(raw.decode("utf-8")) if "multipart" not in ct else self.parse_mp_fields(raw, ct)
            parent = params.get("parent_path", [""])[0] if isinstance(params.get("parent_path"), list) else params.get("parent_path", "")
            name = params.get("name", [""])[0] if isinstance(params.get("name"), list) else params.get("name", "")
            os.makedirs(os.path.join(parent, name.strip()), exist_ok=True)
            return self.send_j({"success": True})
        if p == "/api/rename":
            params = urllib.parse.parse_qs(raw.decode("utf-8")) if "multipart" not in ct else self.parse_mp_fields(raw, ct)
            old_p = params.get("old_path", [""])[0] if isinstance(params.get("old_path"), list) else params.get("old_path", "")
            new_n = params.get("new_name", [""])[0] if isinstance(params.get("new_name"), list) else params.get("new_name", "")
            os.rename(old_p, os.path.join(os.path.dirname(old_p), new_n.strip()))
            return self.send_j({"success": True})
        if p == "/api/delete":
            params = urllib.parse.parse_qs(raw.decode("utf-8")) if "multipart" not in ct else self.parse_mp_fields(raw, ct)
            paths = params.get("paths", [])
            if isinstance(paths, str): paths = [paths]
            for itm in paths:
                if os.path.isdir(itm): shutil.rmtree(itm)
                elif os.path.exists(itm): os.remove(itm)
            return self.send_j({"deleted": paths})
        if p == "/api/upload":
            bd = ct.split("boundary=")[-1].strip().encode()
            parts = raw.split(b"--" + bd)
            target = None
            saved = []
            for part in parts:
                if b'name="target_path"' in part:
                    _, _, bdy = part.partition(b"\r\n\r\n")
                    target = bdy.rstrip(b"\r\n").decode("utf-8", errors="replace").strip()
                    break
            if target and os.path.exists(target):
                for part in parts:
                    if b'filename="' in part:
                        hdr, _, bdy = part.partition(b"\r\n\r\n")
                        m = re.search(rb'filename="([^"]+)"', hdr)
                        if m:
                            fn = m.group(1).decode("utf-8", errors="replace").strip()
                            if fn:
                                with open(os.path.join(target, fn), "wb") as f: f.write(bdy.rstrip(b"\r\n"))
                                saved.append(fn)
            return self.send_j({"success": True, "saved": saved})
        self.send_j({"error": "404"}, 404)

    def parse_mp_fields(self, raw, ct):
        bd = ct.split("boundary=")[-1].strip().encode()
        parts = raw.split(b"--" + bd)
        flds = {}
        for part in parts:
            if b'name="' in part:
                hdr, _, bdy = part.partition(b"\r\n\r\n")
                m = re.search(rb'name="([^"]+)"', hdr)
                if m: flds[m.group(1).decode("utf-8")] = bdy.rstrip(b"\r\n").decode("utf-8", errors="replace")
        return flds

if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[*] Servidor NAS Nativo iniciado em http://0.0.0.0:{PORT}")
    try: server.serve_forever()
    except KeyboardInterrupt: server.server_close()
EOF

# 5. Iniciar o Servidor e exibir IP
IP_LOCAL=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

echo ""
echo -e "\033[1;32m========================================================\033[0m"
echo -e "\033[1;32m   🚀 SERVIDOR NAS ANDROID INICIADO COM SUCESSO!        \033[0m"
echo -e "\033[1;32m========================================================\033[0m"
echo -e " Acesse pelo navegador em qualquer aparelho na mesma rede:"
if [ -n "$IP_LOCAL" ]; then
    echo -e " 👉 \033[1;33mhttp://${IP_LOCAL}:8080\033[0m"
else
    echo -e " 👉 \033[1;33mhttp://127.0.0.1:8080\033[0m"
fi
echo -e "\033[1;36m========================================================\033[0m"
echo -e " Pressione \033[1;31mCTRL + C\033[0m para encerrar."
echo ""

python app.py
