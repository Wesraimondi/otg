cd ~/otg
cat << 'EOF' > app.py
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
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler

PORT = int(os.environ.get("PORT", 8080))
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")


def get_storage_drives():
    drives = []

    android_internal = "/storage/emulated/0"
    if os.path.exists(android_internal):
        try:
            usage = shutil.disk_usage(android_internal)
            drives.append({
                "id": "internal",
                "name": "Armazenamento Interno",
                "path": android_internal,
                "type": "internal",
                "total": usage.total,
                "used": usage.used,
                "free": usage.free,
                "percent": round((usage.used / usage.total) * 100, 1) if usage.total > 0 else 0
            })
        except Exception:
            pass

    if os.path.exists("/storage"):
        try:
            for item in os.listdir("/storage"):
                if item not in ["emulated", "self", "knox", "container"]:
                    full_path = os.path.join("/storage", item)
                    if os.path.isdir(full_path) and os.access(full_path, os.R_OK):
                        try:
                            usage = shutil.disk_usage(full_path)
                            drives.append({
                                "id": f"otg_{item}",
                                "name": f"USB OTG / SD ({item})",
                                "path": full_path,
                                "type": "otg",
                                "total": usage.total,
                                "used": usage.used,
                                "free": usage.free,
                                "percent": round((usage.used / usage.total) * 100, 1) if usage.total > 0 else 0
                            })
                        except Exception:
                            pass
        except Exception:
            pass

    if os.path.exists("/mnt/media_rw"):
        try:
            for item in os.listdir("/mnt/media_rw"):
                full_path = os.path.join("/mnt/media_rw", item)
                if os.path.isdir(full_path) and not any(d["path"] == full_path for d in drives):
                    try:
                        usage = shutil.disk_usage(full_path)
                        drives.append({
                            "id": f"media_rw_{item}",
                            "name": f"USB Drive OTG ({item})",
                            "path": full_path,
                            "type": "otg",
                            "total": usage.total,
                            "used": usage.used,
                            "free": usage.free,
                            "percent": round((usage.used / usage.total) * 100, 1) if usage.total > 0 else 0
                        })
                    except Exception:
                        pass
        except Exception:
            pass

    termux_home = os.environ.get("HOME", "/data/data/com.termux/files/home")
    if os.path.exists(termux_home) and not any(d["path"] == termux_home for d in drives):
        try:
            usage = shutil.disk_usage(termux_home)
            drives.append({
                "id": "termux_home",
                "name": "Termux Home",
                "path": termux_home,
                "type": "home",
                "total": usage.total,
                "used": usage.used,
                "free": usage.free,
                "percent": round((usage.used / usage.total) * 100, 1) if usage.total > 0 else 0
            })
        except Exception:
            pass

    if not drives:
        cwd = os.getcwd()
        usage = shutil.disk_usage(cwd)
        drives.append({
            "id": "default",
            "name": "Diretório Principal",
            "path": cwd,
            "type": "fixed",
            "total": usage.total,
            "used": usage.used,
            "free": usage.free,
            "percent": round((usage.used / usage.total) * 100, 1) if usage.total > 0 else 0
        })

    return drives


def get_file_category(filename: str, is_dir: bool) -> str:
    if is_dir:
        return "folder"
    ext = os.path.splitext(filename)[1].lower()
    if ext in ['.mp4', '.mkv', '.webm', '.avi', '.mov', '.flv', '.wmv', '.3gp', '.m4v']:
        return "video"
    elif ext in ['.mp3', '.wav', '.flac', '.ogg', '.aac', '.m4a', '.wma', '.opus']:
        return "audio"
    elif ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.ico']:
        return "image"
    elif ext in ['.pdf']:
        return "pdf"
    elif ext in ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.apk']:
        return "archive"
    elif ext in ['.txt', '.md', '.log', '.json', '.xml', '.html', '.css', '.js', '.py', '.sh', '.yaml', '.yml', '.csv']:
        return "code"
    elif ext in ['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx']:
        return "document"
    return "file"


def get_system_status():
    battery_info = {"percent": None, "charging": False, "present": False}
    try:
        capacity_path = "/sys/class/power_supply/battery/capacity"
        status_path = "/sys/class/power_supply/battery/status"
        if os.path.exists(capacity_path):
            with open(capacity_path, "r") as f:
                cap = int(f.read().strip())
            charging = False
            if os.path.exists(status_path):
                with open(status_path, "r") as f:
                    stat = f.read().strip().lower()
                    charging = (stat == "charging" or stat == "full")
            battery_info = {"percent": cap, "charging": charging, "present": True}
    except Exception:
        pass

    mem_info = {"total": 0, "used": 0, "free": 0, "percent": 0}
    if os.path.exists("/proc/meminfo"):
        try:
            mem_dict = {}
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        key = parts[0].strip()
                        val = int(parts[1].split()[0]) * 1024
                        mem_dict[key] = val
            total = mem_dict.get("MemTotal", 0)
            avail = mem_dict.get("MemAvailable", mem_dict.get("MemFree", 0))
            used = total - avail
            percent = round((used / total) * 100, 1) if total > 0 else 0
            mem_info = {"total": total, "used": used, "free": avail, "percent": percent}
        except Exception:
            pass

    return {
        "battery": battery_info,
        "memory": mem_info,
        "cpu_percent": 0,
        "drives": get_storage_drives()
    }


class NASRequestHandler(BaseHTTPRequestHandler):
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
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/" or path == "/index.html":
            index_file = os.path.join(STATIC_DIR, "index.html")
            if os.path.exists(index_file):
                self.serve_static(index_file, "text/html; charset=utf-8")
            else:
                self.send_json({"error": "Interface web não encontrada"}, 404)
            return

        if path.startswith("/static/"):
            rel_path = path[8:]
            file_path = os.path.join(STATIC_DIR, rel_path)
            if os.path.exists(file_path) and os.path.isfile(file_path):
                mime, _ = mimetypes.guess_type(file_path)
                self.serve_static(file_path, mime or "application/octet-stream")
            else:
                self.send_json({"error": "Arquivo estático não encontrado"}, 404)
            return

        if path == "/api/drives":
            self.send_json(get_storage_drives())
            return

        if path == "/api/system-status":
            self.send_json(get_system_status())
            return

        if path == "/api/files":
            dir_path = query.get("path", [""])[0]
            if not dir_path or not os.path.exists(dir_path):
                self.send_json({"detail": "Diretório não encontrado"}, 404)
                return
            if not os.path.isdir(dir_path):
                self.send_json({"detail": "O caminho não é um diretório"}, 400)
                return

            try:
                entries = []
                with os.scandir(dir_path) as scanner:
                    for entry in scanner:
                        try:
                            stat = entry.stat()
                            is_dir = entry.is_dir(follow_symlinks=True)
                            entries.append({
                                "name": entry.name,
                                "path": os.path.abspath(entry.path),
                                "is_dir": is_dir,
                                "size": stat.st_size if not is_dir else 0,
                                "modified": stat.st_mtime,
                                "category": get_file_category(entry.name, is_dir),
                                "readable": True
                            })
                        except (PermissionError, FileNotFoundError):
                            continue

                entries.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
                parent = os.path.dirname(os.path.abspath(dir_path))
                if parent == os.path.abspath(dir_path):
                    parent = None

                self.send_json({
                    "current_path": os.path.abspath(dir_path),
                    "parent_path": parent,
                    "items": entries,
                    "count": len(entries)
                })
            except PermissionError:
                self.send_json({"detail": "Permissão negada ao acessar este diretório"}, 403)
            except Exception as e:
                self.send_json({"detail": str(e)}, 500)
            return

        if path == "/api/stream":
            file_path = query.get("path", [""])[0]
            if not file_path or not os.path.exists(file_path) or os.path.isdir(file_path):
                self.send_json({"detail": "Arquivo não encontrado"}, 404)
                return
            self.serve_file_with_range(file_path)
            return

        if path == "/api/download-zip":
            dir_path = query.get("path", [""])[0]
            if not dir_path or not os.path.exists(dir_path) or not os.path.isdir(dir_path):
                self.send_json({"detail": "Diretório não encontrado"}, 404)
                return
            self.serve_folder_zip(dir_path)
            return

        if path == "/api/text-content":
            file_path = query.get("path", [""])[0]
            if not file_path or not os.path.exists(file_path) or os.path.isdir(file_path):
                self.send_json({"detail": "Arquivo não encontrado"}, 404)
                return
            try:
                with open(file_path, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read(5 * 1024 * 1024)
                self.send_json({"content": content, "filename": os.path.basename(file_path)})
            except Exception as e:
                self.send_json({"detail": str(e)}, 500)
            return

        self.send_json({"error": "Endpoint não encontrado"}, 404)

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/mkdir":
            params = self.parse_form_data()
            parent = params.get("parent_path", "")
            name = params.get("name", "").strip()
            if not parent or not name:
                self.send_json({"detail": "Nome da pasta inválido"}, 400)
                return
            target = os.path.join(parent, name)
            try:
                os.makedirs(target, exist_ok=True)
                self.send_json({"success": True, "path": target})
            except Exception as e:
                self.send_json({"detail": str(e)}, 500)
            return

        if path == "/api/rename":
            params = self.parse_form_data()
            old_path = params.get("old_path", "")
            new_name = params.get("new_name", "").strip()
            if not old_path or not new_name or not os.path.exists(old_path):
                self.send_json({"detail": "Item não encontrado"}, 404)
                return
            parent = os.path.dirname(old_path)
            target = os.path.join(parent, new_name)
            try:
                os.rename(old_path, target)
                self.send_json({"success": True, "path": target})
            except Exception as e:
                self.send_json({"detail": str(e)}, 500)
            return

        if path == "/api/delete":
            params = self.parse_form_data()
            paths = params.get("paths", [])
            if isinstance(paths, str):
                paths = [paths]
            deleted = []
            for p in paths:
                try:
                    if os.path.isdir(p):
                        shutil.rmtree(p)
                    elif os.path.exists(p):
                        os.remove(p)
                    deleted.append(p)
                except Exception:
                    pass
            self.send_json({"deleted": deleted})
            return

        if path == "/api/upload":
            content_type = self.headers.get("Content-Type", "")
            if "multipart/form-data" not in content_type:
                self.send_json({"detail": "Content-Type inválido"}, 400)
                return
            self.handle_multipart_upload()
            return

        self.send_json({"error": "Endpoint não encontrado"}, 404)

    def parse_form_data(self):
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length)
        content_type = self.headers.get("Content-Type", "")

        if "application/json" in content_type:
            return json.loads(post_data.decode("utf-8"))
        elif "multipart/form-data" in content_type:
            boundary = content_type.split("boundary=")[-1].strip().encode()
            parts = post_data.split(b"--" + boundary)
            fields = {}
            for part in parts:
                if b'name="' in part:
                    header, _, body = part.partition(b"\r\n\r\n")
                    body = body.rstrip(b"\r\n")
                    name_match = re.search(rb'name="([^"]+)"', header)
                    if name_match:
                        name = name_match.group(1).decode("utf-8")
                        fields[name] = body.decode("utf-8", errors="replace")
            return fields
        else:
            parsed = urllib.parse.parse_qs(post_data.decode("utf-8"))
            return {k: v[0] if len(v) == 1 else v for k, v in parsed.items()}

    def handle_multipart_upload(self):
        content_type = self.headers.get("Content-Type", "")
        content_length = int(self.headers.get("Content-Length", 0))
        boundary = content_type.split("boundary=")[-1].strip().encode()

        data = self.rfile.read(content_length)
        parts = data.split(b"--" + boundary)
        target_path = None
        saved_files = []

        for part in parts:
            if b'name="target_path"' in part:
                _, _, body = part.partition(b"\r\n\r\n")
                target_path = body.rstrip(b"\r\n").decode("utf-8", errors="replace").strip()
                break

        if not target_path or not os.path.exists(target_path):
            self.send_json({"detail": "Diretório de destino inválido"}, 400)
            return

        for part in parts:
            if b'filename="' in part:
                header, _, body = part.partition(b"\r\n\r\n")
                body = body.rstrip(b"\r\n")
                match = re.search(rb'filename="([^"]+)"', header)
                if match:
                    filename = match.group(1).decode("utf-8", errors="replace").strip()
                    if filename:
                        dest = os.path.join(target_path, filename)
                        with open(dest, "wb") as f:
                            f.write(body)
                        saved_files.append(filename)

        self.send_json({"success": True, "saved": saved_files})

    def serve_static(self, filepath, mime):
        with open(filepath, "rb") as f:
            content = f.read()
        self.send_response(200)
        self.send_header("Content-Type", mime)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(content)

    def serve_folder_zip(self, dir_path):
        folder_name = os.path.basename(os.path.abspath(dir_path)) or "download"
        temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
        try:
            with zipfile.ZipFile(temp_zip.name, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for root, dirs, files in os.walk(dir_path):
                    for file in files:
                        file_abs = os.path.join(root, file)
                        rel_path = os.path.relpath(file_abs, dir_path)
                        zipf.write(file_abs, arcname=rel_path)
            
            size = os.path.getsize(temp_zip.name)
            self.send_response(200)
            self.send_header("Content-Type", "application/zip")
            self.send_header("Content-Disposition", f'attachment; filename="{folder_name}.zip"')
            self.send_header("Content-Length", str(size))
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

        range_header = self.headers.get("Range")
        if range_header and range_header.startswith("bytes="):
            parts = range_header[6:].split("-")
            start = int(parts[0]) if parts[0] else 0
            end = int(parts[1]) if len(parts) > 1 and parts[1] else file_size - 1
            start = max(0, start)
            end = min(file_size - 1, end)
            length = end - start + 1

            self.send_response(206)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Range", f"bytes {start}-{end}/{file_size}")
            self.send_header("Content-Length", str(length))
            self.send_header("Accept-Ranges", "bytes")
            self.end_headers()

            with open(file_path, "rb") as f:
                f.seek(start)
                bytes_left = length
                while bytes_left > 0:
                    chunk = f.read(min(64 * 1024, bytes_left))
                    if not chunk:
                        break
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        break
                    bytes_left -= len(chunk)
        else:
            self.send_response(200)
            self.send_header("Content-Type", mime)
            self.send_header("Content-Length", str(file_size))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Disposition", f'inline; filename="{filename}"')
            self.end_headers()

            with open(file_path, "rb") as f:
                while chunk := f.read(64 * 1024):
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        break


def run():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), NASRequestHandler)
    print(f"[*] Servidor NAS Nativo iniciado em http://0.0.0.0:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Servidor encerrado.")
        server.server_close()


if __name__ == "__main__":
    run()
EOF