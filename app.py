import os
import sys
import shutil
import mimetypes
import zipfile
import tempfile
from typing import List, Optional
from pathlib import Path
import psutil
from fastapi import FastAPI, HTTPException, Query, UploadFile, File, Form, Request
from fastapi.responses import FileResponse, StreamingResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Android Tablet NAS", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Helper function to detect available drives / storage locations
def get_storage_drives():
    drives = []
    
    # 1. Check Android specific paths
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

    # 2. Check Android OTG / SD Cards in /storage
    if os.path.exists("/storage"):
        try:
            for item in os.listdir("/storage"):
                if item not in ["emulated", "self", "knox", "container"]:
                    full_path = os.path.join("/storage", item)
                    if os.path.isdir(full_path) and os.access(full_path, os.R_OK):
                        try:
                            usage = shutil.disk_usage(full_path)
                            # Name it USB OTG or SD Card based on label / heuristic
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

    # 3. Check /mnt/media_rw for rooted/direct OTG mounts
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

    # 4. Termux Home Directory (if on Android)
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

    # 5. Fallback for Windows / Linux Desktop development & testing
    if not drives:
        for part in psutil.disk_partitions(all=False):
            try:
                if 'cdrom' in part.opts or part.fstype == '':
                    continue
                usage = psutil.disk_usage(part.mountpoint)
                drives.append({
                    "id": f"drive_{part.mountpoint.replace(':', '').replace('\\', '').replace('/', '')}",
                    "name": f"Unidade ({part.mountpoint})",
                    "path": part.mountpoint,
                    "type": "fixed",
                    "total": usage.total,
                    "used": usage.used,
                    "free": usage.free,
                    "percent": usage.percent
                })
            except Exception:
                continue

    # 6. Fallback to current working dir if still empty
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
    elif ext in ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.bmp', '.ico', '.tiff']:
        return "image"
    elif ext in ['.pdf']:
        return "pdf"
    elif ext in ['.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.apk', '.iso']:
        return "archive"
    elif ext in ['.txt', '.md', '.log', '.json', '.xml', '.html', '.css', '.js', '.py', '.sh', '.yaml', '.yml', '.csv', '.c', '.cpp', '.java', '.kt', '.php']:
        return "code"
    elif ext in ['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.odt', '.ods', '.odp']:
        return "document"
    return "file"


@app.get("/api/drives")
def api_get_drives():
    return get_storage_drives()


@app.get("/api/system-status")
def api_get_system_status():
    battery_info = {"percent": None, "charging": False, "present": False}
    
    # Check psutil battery
    try:
        batt = psutil.sensors_battery()
        if batt is not None:
            battery_info = {
                "percent": int(batt.percent),
                "charging": batt.power_plugged,
                "present": True
            }
    except Exception:
        pass

    # If psutil failed, try reading Android /sys/class/power_supply/battery
    if not battery_info["present"]:
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
                battery_info = {
                    "percent": cap,
                    "charging": charging,
                    "present": True
                }
        except Exception:
            pass

    # RAM and CPU
    mem = psutil.virtual_memory()
    cpu_usage = psutil.cpu_percent(interval=None)

    return {
        "battery": battery_info,
        "memory": {
            "total": mem.total,
            "used": mem.used,
            "free": mem.available,
            "percent": mem.percent
        },
        "cpu_percent": cpu_usage,
        "drives": get_storage_drives()
    }


@app.get("/api/files")
def list_files(path: str = Query(..., description="Caminho do diretório a listar")):
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Diretório não encontrado")
    
    if not os.path.isdir(path):
        raise HTTPException(status_code=400, detail="O caminho especificado não é um diretório")

    try:
        entries = []
        with os.scandir(path) as scanner:
            for entry in scanner:
                try:
                    stat = entry.stat()
                    is_dir = entry.is_dir(follow_symlinks=True)
                    size = stat.st_size if not is_dir else 0
                    mtime = stat.st_mtime
                    category = get_file_category(entry.name, is_dir)
                    
                    entries.append({
                        "name": entry.name,
                        "path": os.path.abspath(entry.path),
                        "is_dir": is_dir,
                        "size": size,
                        "modified": mtime,
                        "category": category,
                        "readable": True
                    })
                except (PermissionError, FileNotFoundError):
                    continue

        # Sort: directories first, then alphabetical case-insensitive
        entries.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
        
        # Parent directory
        parent = os.path.dirname(os.path.abspath(path))
        if parent == os.path.abspath(path):
            parent = None

        return {
            "current_path": os.path.abspath(path),
            "parent_path": parent,
            "items": entries,
            "count": len(entries)
        }
    except PermissionError:
        raise HTTPException(status_code=403, detail="Permissão negada ao acessar este diretório")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao listar arquivos: {str(e)}")


@app.post("/api/mkdir")
def create_directory(parent_path: str = Form(...), name: str = Form(...)):
    target = os.path.join(parent_path, name.strip())
    if os.path.exists(target):
        raise HTTPException(status_code=400, detail="Uma pasta ou arquivo com este nome já existe")
    try:
        os.makedirs(target, exist_ok=True)
        return {"success": True, "path": target}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao criar pasta: {str(e)}")


@app.post("/api/rename")
def rename_item(old_path: str = Form(...), new_name: str = Form(...)):
    if not os.path.exists(old_path):
        raise HTTPException(status_code=404, detail="Arquivo/pasta não encontrado")
    
    parent = os.path.dirname(old_path)
    target = os.path.join(parent, new_name.strip())
    if os.path.exists(target):
        raise HTTPException(status_code=400, detail="Já existe um item com este novo nome")
        
    try:
        os.rename(old_path, target)
        return {"success": True, "path": target}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao renomear: {str(e)}")


@app.post("/api/delete")
def delete_items(paths: List[str] = Form(...)):
    deleted = []
    errors = []
    for path in paths:
        try:
            if os.path.isdir(path):
                shutil.rmtree(path)
            elif os.path.exists(path):
                os.remove(path)
            deleted.append(path)
        except Exception as e:
            errors.append({"path": path, "error": str(e)})

    return {"deleted": deleted, "errors": errors}


@app.post("/api/upload")
async def upload_files(
    target_path: str = Form(...),
    files: List[UploadFile] = File(...)
):
    if not os.path.exists(target_path) or not os.path.isdir(target_path):
        raise HTTPException(status_code=400, detail="Diretório de destino inválido")

    saved_files = []
    for upload in files:
        file_path = os.path.join(target_path, upload.filename)
        # Handle duplicates if needed or overwrite
        try:
            with open(file_path, "wb") as buffer:
                while chunk := await upload.read(1024 * 1024):  # 1MB chunks
                    buffer.write(chunk)
            saved_files.append(upload.filename)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Erro ao salvar {upload.filename}: {str(e)}")
            
    return {"success": True, "saved": saved_files}


@app.get("/api/download-zip")
def download_folder_zip(path: str = Query(...)):
    if not os.path.exists(path) or not os.path.isdir(path):
        raise HTTPException(status_code=404, detail="Diretório não encontrado")

    folder_name = os.path.basename(os.path.abspath(path)) or "download"
    temp_zip = tempfile.NamedTemporaryFile(delete=False, suffix=".zip")
    
    try:
        with zipfile.ZipFile(temp_zip.name, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(path):
                for file in files:
                    file_abs = os.path.join(root, file)
                    rel_path = os.path.relpath(file_abs, path)
                    zipf.write(file_abs, arcname=rel_path)
        
        return FileResponse(
            temp_zip.name,
            media_type="application/zip",
            filename=f"{folder_name}.zip"
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao compactar: {str(e)}")


# Streaming endpoint with full HTTP Range support for video & audio playback
@app.get("/api/stream")
def stream_file(request: Request, path: str = Query(...)):
    if not os.path.exists(path) or os.path.isdir(path):
        raise HTTPException(status_code=404, detail="Arquivo não encontrado")

    file_size = os.path.getsize(path)
    mime_type, _ = mimetypes.guess_type(path)
    if not mime_type:
        mime_type = "application/octet-stream"

    range_header = request.headers.get("range")
    if range_header:
        range_value = range_header.strip().lower()
        if range_value.startswith("bytes="):
            parts = range_value[6:].split("-")
            start = int(parts[0]) if parts[0] else 0
            end = int(parts[1]) if len(parts) > 1 and parts[1] else file_size - 1
            start = max(0, start)
            end = min(file_size - 1, end)
            length = end - start + 1

            def iterfile():
                with open(path, "rb") as f:
                    f.seek(start)
                    bytes_left = length
                    while bytes_left > 0:
                        chunk_size = min(64 * 1024, bytes_left)
                        data = f.read(chunk_size)
                        if not data:
                            break
                        bytes_left -= len(data)
                        yield data

            headers = {
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Accept-Ranges": "bytes",
                "Content-Length": str(length),
                "Content-Type": mime_type,
            }
            return StreamingResponse(iterfile(), status_code=206, headers=headers)

    # Full file response if no range header
    return FileResponse(
        path,
        media_type=mime_type,
        filename=os.path.basename(path),
        headers={"Accept-Ranges": "bytes"}
    )


@app.get("/api/text-content")
def get_text_content(path: str = Query(...)):
    if not os.path.exists(path) or os.path.isdir(path):
        raise HTTPException(status_code=404, detail="Arquivo não encontrado")
    
    # Max 5MB for text preview
    if os.path.getsize(path) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Arquivo muito grande para visualização de texto (>5MB)")

    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
        return {"content": content, "filename": os.path.basename(path)}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao ler arquivo: {str(e)}")


# Mount Static Files (SPA Web Interface)
static_dir = os.path.join(os.path.dirname(__file__), "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")


@app.get("/")
def serve_index():
    index_file = os.path.join(static_dir, "index.html")
    if os.path.exists(index_file):
        return FileResponse(index_file)
    return {"message": "Android NAS API is running. static/index.html not found."}


if __name__ == "__main__":
    import uvicorn
    # Default port 8080 or custom port
    port = int(os.environ.get("PORT", 8080))
    print(f"[*] Iniciando Android Tablet NAS em http://0.0.0.0:{port}")
    uvicorn.run(app, host="0.0.0.0", port=port)
