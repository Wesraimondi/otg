#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
#   Script Tudo-em-Um: Instalação e Inicialização do NAS
#   Repositório: https://github.com/Wesraimondi/otg
# ==========================================================

clear
echo -e "\033[1;36m========================================================\033[0m"
echo -e "\033[1;32m      🚀 INSTALANDO INTERFACE E SERVIDOR NAS (OTG)      \033[0m"
echo -e "\033[1;36m========================================================\033[0m"

# 1. Permissões de Armazenamento e Wake-Lock
echo -e "\033[1;33m[1/4] Configurando permissões do Android...\033[0m"
termux-setup-storage 2>/dev/null || true
termux-wake-lock 2>/dev/null || true

# 2. Instalar Python caso necessário
echo -e "\033[1;33m[2/4] Verificando ambiente Python...\033[0m"
pkg install -y python 2>/dev/null || true

# 3. Criar diretório static e interface visual
echo -e "\033[1;33m[3/4] Criando interface visual (HTML5/Tailwind/Lucide)...\033[0m"
DIR_BASE=$(dirname "$(realpath "$0")")
mkdir -p "$DIR_BASE/static"

cat << 'HTMLEOF' > "$DIR_BASE/static/index.html"
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Android NAS | Hub OTG</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://unpkg.com/lucide@latest"></script>
  <style>
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: rgba(15, 23, 42, 0.6); }
    ::-webkit-scrollbar-thumb { background: rgba(71, 85, 105, 0.6); border-radius: 9999px; }
    .file-card { transition: all 0.18s ease-in-out; }
    .file-card:hover { transform: translateY(-2px); }
  </style>
</head>
<body class="bg-slate-900 text-slate-100 min-h-screen flex flex-col font-sans">
  <header class="bg-slate-800/80 backdrop-blur-md border-b border-slate-700/60 sticky top-0 z-30 px-4 py-3 flex items-center justify-between">
    <div class="flex items-center space-x-3">
      <div class="w-9 h-9 rounded-xl bg-indigo-600 flex items-center justify-center shadow-lg">
        <i data-lucide="hard-drive" class="w-5 h-5 text-white"></i>
      </div>
      <div>
        <h1 class="font-bold text-base text-white flex items-center gap-1.5">
          Android NAS <span class="text-xs font-medium px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">Online</span>
        </h1>
        <p class="text-xs text-slate-400">Hub Multimídia & OTG</p>
      </div>
    </div>
    <div class="flex items-center space-x-3">
      <div id="batteryIndicator" class="flex items-center space-x-2 bg-slate-700/60 border border-slate-600 px-3 py-1.5 rounded-lg text-xs font-medium">
        <i data-lucide="battery" class="w-4 h-4 text-emerald-400"></i>
        <span id="batteryText">--%</span>
      </div>
      <button onclick="document.getElementById('fileInput').click()" class="flex items-center space-x-1.5 bg-indigo-600 hover:bg-indigo-500 text-white px-3.5 py-1.5 rounded-lg text-sm font-semibold transition">
        <i data-lucide="upload-cloud" class="w-4 h-4"></i>
        <span>Enviar</span>
      </button>
    </div>
  </header>

  <div class="flex-1 flex overflow-hidden">
    <aside class="w-72 bg-slate-800 border-r border-slate-700/60 flex flex-col p-4 space-y-4">
      <div>
        <span class="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">Unidades de Disco</span>
        <div id="drivesList" class="space-y-2"></div>
      </div>
      <div class="flex-1 overflow-y-auto space-y-1">
        <span class="text-xs font-semibold uppercase tracking-wider text-slate-400 block mb-2">Atalhos</span>
        <button onclick="quickNav('Download')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-sm text-slate-300 hover:bg-slate-700 transition"><i data-lucide="download" class="w-4 h-4 text-blue-400"></i><span>Downloads</span></button>
        <button onclick="quickNav('DCIM')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-sm text-slate-300 hover:bg-slate-700 transition"><i data-lucide="camera" class="w-4 h-4 text-rose-400"></i><span>Fotos (DCIM)</span></button>
        <button onclick="quickNav('Movies')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-sm text-slate-300 hover:bg-slate-700 transition"><i data-lucide="film" class="w-4 h-4 text-purple-400"></i><span>Vídeos</span></button>
        <button onclick="quickNav('Music')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-sm text-slate-300 hover:bg-slate-700 transition"><i data-lucide="music" class="w-4 h-4 text-emerald-400"></i><span>Músicas</span></button>
      </div>
    </aside>

    <main class="flex-1 flex flex-col bg-slate-900 overflow-hidden">
      <div class="p-4 border-b border-slate-800 bg-slate-900/90 flex items-center justify-between gap-3">
        <div class="flex-1 flex items-center space-x-1.5 overflow-x-auto py-1 px-2 rounded-lg bg-slate-800 border border-slate-700 text-sm" id="breadcrumbs"></div>
        <div class="flex items-center space-x-2">
          <input type="text" id="searchInput" oninput="filterFiles()" placeholder="Filtrar..." class="bg-slate-800 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-white focus:outline-none">
          <button onclick="createNewFolder()" class="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-300"><i data-lucide="folder-plus" class="w-4 h-4"></i></button>
          <button onclick="downloadFolderZip()" class="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-300"><i data-lucide="archive" class="w-4 h-4"></i></button>
          <button onclick="loadDir(currentPath)" class="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 border border-slate-700 text-slate-300"><i data-lucide="refresh-cw" class="w-4 h-4"></i></button>
        </div>
      </div>

      <div id="dropzone" class="flex-1 overflow-y-auto p-6">
        <div id="fileList" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4"></div>
      </div>
      <div class="px-4 py-2 bg-slate-800 border-t border-slate-700 text-xs text-slate-400 flex justify-between">
        <span id="folderStats">0 itens</span>
        <span>Conectado</span>
      </div>
    </main>
  </div>

  <input type="file" id="fileInput" multiple class="hidden" onchange="uploadFiles(this.files)">

  <div id="mediaModal" class="fixed inset-0 bg-black/90 z-50 hidden flex flex-col p-4">
    <div class="flex justify-between items-center pb-2 border-b border-slate-800">
      <span id="mediaTitle" class="text-sm font-bold text-white truncate"></span>
      <button onclick="closeMedia()" class="p-2 rounded-lg bg-slate-800 text-white"><i data-lucide="x" class="w-5 h-5"></i></button>
    </div>
    <div class="flex-1 flex items-center justify-center p-4" id="mediaContainer"></div>
  </div>

  <script>
    let currentPath = "", currentDrive = null, allItems = [];
    function formatBytes(b) { if(!b) return '0 B'; let k=1024, s=['B','KB','MB','GB','TB'], i=Math.floor(Math.log(b)/Math.log(k)); return parseFloat((b/Math.pow(k,i)).toFixed(1))+' '+s[i]; }

    async function fetchStatus() {
      try {
        const res = await fetch('/api/system-status');
        const d = await res.json();
        if(d.battery && d.battery.percent !== null) {
          document.getElementById('batteryText').textContent = `${d.battery.percent}% ${d.battery.charging ? '⚡' : ''}`;
        }
        if(d.drives) renderDrives(d.drives);
      }catch(e){}
    }

    function renderDrives(drives) {
      const el = document.getElementById('drivesList');
      el.innerHTML = drives.map(d => `
        <div onclick="selectDrive('${d.path.replace(/\\/g, '\\\\')}')" class="p-3 rounded-xl border cursor-pointer ${currentDrive && currentDrive.path===d.path ? 'bg-indigo-600/20 border-indigo-500' : 'bg-slate-700/40 border-slate-700'}">
          <div class="flex justify-between text-xs font-bold text-white mb-1">
            <span>${d.name}</span>
            <span class="text-[10px] px-1.5 py-0.5 rounded bg-slate-800 text-emerald-400">${d.type.toUpperCase()}</span>
          </div>
          <div class="w-full bg-slate-900 rounded-full h-1.5 mb-1"><div class="h-1.5 rounded-full bg-indigo-500" style="width: ${d.percent}%"></div></div>
          <div class="text-[10px] text-slate-400 flex justify-between"><span>${formatBytes(d.free)} livres</span><span>${formatBytes(d.total)}</span></div>
        </div>
      `).join('');
      lucide.createIcons();
      if(!currentDrive && drives.length > 0) selectDrive(drives[0].path, drives[0]);
    }

    function selectDrive(path, driveObj) {
      currentDrive = driveObj || { path };
      loadDir(path);
    }

    async function loadDir(path) {
      const res = await fetch(`/api/files?path=${encodeURIComponent(path)}`);
      if(!res.ok) return alert("Erro ao abrir pasta");
      const data = await res.json();
      currentPath = data.current_path;
      allItems = data.items;
      renderBreadcrumbs(data.current_path);
      renderFileList(data.items);
      document.getElementById('folderStats').textContent = `${data.count} itens`;
    }

    function renderBreadcrumbs(path) {
      const parts = path.replace(/\\/g, '/').split('/').filter(Boolean);
      let html = `<button onclick="loadDir('/')" class="p-1 text-slate-400 hover:text-white"><i data-lucide="home" class="w-4 h-4"></i></button>`;
      let acc = "";
      parts.forEach((p, idx) => {
        acc += "/" + p;
        const cur = acc;
        html += `<span class="text-slate-500">/</span><button onclick="loadDir('${cur.replace(/\\/g, '\\\\')}')" class="text-slate-300 hover:text-white truncate">${p}</button>`;
      });
      document.getElementById('breadcrumbs').innerHTML = html;
      lucide.createIcons();
    }

    function renderFileList(items) {
      const q = document.getElementById('searchInput').value.toLowerCase();
      const filtered = q ? items.filter(i => i.name.toLowerCase().includes(q)) : items;
      document.getElementById('fileList').innerHTML = filtered.map(i => `
        <div onclick="openItem('${encodeURIComponent(i.path)}', ${i.is_dir}, '${i.category}', '${encodeURIComponent(i.name)}')" class="file-card bg-slate-800 border border-slate-700/60 hover:border-indigo-500 rounded-2xl p-3 flex flex-col justify-between cursor-pointer">
          <div class="w-full aspect-square rounded-xl bg-slate-700/50 flex items-center justify-center mb-2">
            <i data-lucide="${i.is_dir ? 'folder' : (i.category==='video'?'film':(i.category==='audio'?'music':(i.category==='image'?'image':'file')))}" class="w-8 h-8 ${i.is_dir ? 'text-amber-400' : 'text-indigo-400'}"></i>
          </div>
          <p class="text-xs font-semibold text-white truncate">${i.name}</p>
          <span class="text-[10px] text-slate-400 mt-1">${i.is_dir ? 'Pasta' : formatBytes(i.size)}</span>
        </div>
      `).join('');
      lucide.createIcons();
    }

    function filterFiles() { renderFileList(allItems); }
    function quickNav(sub) { if(currentDrive) loadDir(`${currentDrive.path}/${sub}`); }

    function openItem(encPath, isDir, cat, encName) {
      const p = decodeURIComponent(encPath), n = decodeURIComponent(encName);
      if(isDir) return loadDir(p);
      const url = `/api/stream?path=${encodeURIComponent(p)}`;
      const modal = document.getElementById('mediaModal');
      const box = document.getElementById('mediaContainer');
      document.getElementById('mediaTitle').textContent = n;
      if(cat === 'video') {
        box.innerHTML = `<video controls autoplay class="max-h-[80vh] max-w-full rounded-xl"><source src="${url}">Seu navegador não suporta.</video>`;
        modal.classList.remove('hidden');
      } else if(cat === 'audio') {
        box.innerHTML = `<audio controls autoplay class="w-full max-w-md"><source src="${url}"></audio>`;
        modal.classList.remove('hidden');
      } else if(cat === 'image') {
        box.innerHTML = `<img src="${url}" class="max-h-[80vh] max-w-full rounded-xl object-contain">`;
        modal.classList.remove('hidden');
      } else {
        window.location.href = url;
      }
    }
    function closeMedia() { document.getElementById('mediaModal').classList.add('hidden'); document.getElementById('mediaContainer').innerHTML = ''; }

    function uploadFiles(files) {
      if(!files.length || !currentPath) return;
      const fd = new FormData();
      fd.append("target_path", currentPath);
      for(let f of files) fd.append("files", f);
      fetch('/api/upload', { method: 'POST', body: fd }).then(() => loadDir(currentPath));
    }

    function createNewFolder() {
      const n = prompt("Nome da nova pasta:");
      if(!n) return;
      const fd = new FormData();
      fd.append("parent_path", currentPath);
      fd.append("name", n);
      fetch('/api/mkdir', { method: 'POST', body: fd }).then(() => loadDir(currentPath));
    }

    function downloadFolderZip() {
      if(currentPath) window.location.href = `/api/download-zip?path=${encodeURIComponent(currentPath)}`;
    }

    window.onload = () => { lucide.createIcons(); fetchStatus(); setInterval(fetchStatus, 10000); };
  </script>
</body>
</html>
HTMLEOF

# 4. Criar o Servidor Python app.py
echo -e "\033[1;33m[4/4] Configurando backend Python nativo...\033[0m"
cat << 'PYEOF' > "$DIR_BASE/app.py"
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

    home = os.environ.get("HOME", "/data/data/com.termux/files/home")
    if os.path.exists(home) and not any(d["path"] == home for d in drives):
        try:
            u = shutil.disk_usage(home)
            drives.append({"id": "home", "name": "Termux Home", "path": home, "type": "home", "total": u.total, "used": u.used, "free": u.free, "percent": round((u.used/u.total)*100, 1) if u.total>0 else 0})
        except Exception: pass
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
        self.send_j({"error": "404"}, 404)

    def do_POST(self):
        pr = urllib.parse.urlparse(self.path)
        p, cl = pr.path, int(self.headers.get("Content-Length", 0))
        raw, ct = self.rfile.read(cl), self.headers.get("Content-Type", "")

        if p == "/api/mkdir":
            bd = ct.split("boundary=")[-1].strip().encode()
            parts = raw.split(b"--" + bd)
            parent, name = "", ""
            for pt in parts:
                if b'name="parent_path"' in pt: parent = pt.partition(b"\r\n\r\n")[2].rstrip(b"\r\n").decode("utf-8", errors="replace").strip()
                if b'name="name"' in pt: name = pt.partition(b"\r\n\r\n")[2].rstrip(b"\r\n").decode("utf-8", errors="replace").strip()
            if parent and name: os.makedirs(os.path.join(parent, name), exist_ok=True)
            return self.send_j({"success": True})
        if p == "/api/upload":
            bd = ct.split("boundary=")[-1].strip().encode()
            parts = raw.split(b"--" + bd)
            target = None
            for pt in parts:
                if b'name="target_path"' in pt: target = pt.partition(b"\r\n\r\n")[2].rstrip(b"\r\n").decode("utf-8", errors="replace").strip(); break
            if target and os.path.exists(target):
                for pt in parts:
                    if b'filename="' in pt:
                        hdr, _, bdy = pt.partition(b"\r\n\r\n")
                        m = re.search(rb'filename="([^"]+)"', hdr)
                        if m:
                            fn = m.group(1).decode("utf-8", errors="replace").strip()
                            if fn:
                                with open(os.path.join(target, fn), "wb") as f: f.write(bdy.rstrip(b"\r\n"))
            return self.send_j({"success": True})
        self.send_j({"error": "404"}, 404)

if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[*] Servidor NAS Iniciado em http://0.0.0.0:{PORT}")
    try: server.serve_forever()
    except KeyboardInterrupt: server.server_close()
PYEOF

# 5. Permissão de execução e início do servidor
chmod +x "$DIR_BASE/app.py" 2>/dev/null || true
IP_LOCAL=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

echo ""
echo -e "\033[1;32m========================================================\033[0m"
echo -e "\033[1;32m   ✅ SERVIDOR NAS PRONTO E RODANDO!                   \033[0m"
echo -e "\033[1;32m========================================================\033[0m"
echo -e " Acesse agora pelo navegador:"
if [ -n "$IP_LOCAL" ]; then
    echo -e " 👉 \033[1;33mhttp://${IP_LOCAL}:8080\033[0m"
else
    echo -e " 👉 \033[1;33mhttp://127.0.0.1:8080\033[0m"
fi
echo -e "\033[1;36m========================================================\033[0m"
echo -e " Pressione \033[1;31mCTRL + C\033[0m para pausar o servidor."
echo ""

cd "$DIR_BASE" && python app.py
