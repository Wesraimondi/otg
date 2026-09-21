#!/data/data/com.termux/files/usr/bin/bash

# ==========================================================
#   Script Tudo-em-Um: Instalação e Inicialização do NAS OS
#   Usuário: Wesley | Senha:  210769
# ==========================================================

clear
echo -e "\033[1;36m========================================================\033[0m"
echo -e "\033[1;32m   🛡️  WESLEY NAS OS (HD EXTERNO SAMSUNG CONECTADO)     \033[0m"
echo -e "\033[1;36m========================================================\033[0m"

# 1. Permissões de Armazenamento e Wake-Lock
echo -e "\033[1;33m[1/4] Configurando permissões do Android...\033[0m"
termux-setup-storage 2>/dev/null || true
termux-wake-lock 2>/dev/null || true

# 2. Instalar Python caso necessário
echo -e "\033[1;33m[2/4] Verificando ambiente Python...\033[0m"
pkg install -y python 2>/dev/null || true

DIR_BASE=$(dirname "$(realpath "$0")")
mkdir -p "$DIR_BASE/static"

# 3. Criar interface visual
echo -e "\033[1;33m[3/4] Atualizando interface visual...\033[0m"
cat << 'HTMLEOF' > "$DIR_BASE/static/index.html"
<!DOCTYPE html>
<html lang="pt-BR" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Wesley NAS OS | Armazenamento & OTG</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <script src="https://unpkg.com/lucide@latest"></script>
  <script>
    tailwind.config = {
      darkMode: 'class',
      theme: { extend: { colors: { brand: { 50: '#eef2ff', 500: '#6366f1', 600: '#4f46e5', 700: '#4338ca' } } } }
    }
  </script>
  <style>
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: rgba(15, 23, 42, 0.7); }
    ::-webkit-scrollbar-thumb { background: rgba(71, 85, 105, 0.7); border-radius: 9999px; }
    ::-webkit-scrollbar-thumb:hover { background: rgba(99, 102, 241, 0.9); }
    .file-card { transition: all 0.16s ease-in-out; }
    .file-card:hover { transform: translateY(-2px); }
    .glass-panel { background: rgba(30, 41, 59, 0.75); backdrop-filter: blur(12px); }
  </style>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen flex flex-col font-sans selection:bg-brand-500 selection:text-white">

  <!-- TELA DE LOGIN -->
  <div id="loginScreen" class="fixed inset-0 z-50 flex items-center justify-center bg-gradient-to-br from-slate-950 via-slate-900 to-indigo-950 p-4">
    <div class="glass-panel border border-slate-700/60 rounded-3xl p-8 max-w-md w-full shadow-2xl relative overflow-hidden">
      <div class="text-center mb-8 relative z-10">
        <div class="w-16 h-16 rounded-2xl bg-gradient-to-tr from-brand-600 to-indigo-400 mx-auto flex items-center justify-center shadow-xl shadow-brand-500/30 mb-4">
          <i data-lucide="server" class="w-9 h-9 text-white"></i>
        </div>
        <h2 class="text-2xl font-black text-white tracking-tight">Wesley NAS OS</h2>
        <p class="text-xs text-slate-400 mt-1 font-medium">Sistema de Armazenamento em Rede & OTG</p>
      </div>

      <form id="loginForm" class="space-y-4 relative z-10">
        <div id="loginError" class="hidden p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs font-semibold text-center"></div>
        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1.5">Usuário</label>
          <div class="relative">
            <i data-lucide="user" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
            <input type="text" id="loginUser" required value="Wesley" class="w-full bg-slate-900/90 border border-slate-700 rounded-xl pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-brand-500">
          </div>
        </div>
        <div>
          <label class="block text-xs font-semibold uppercase tracking-wider text-slate-400 mb-1.5">Senha</label>
          <div class="relative">
            <i data-lucide="lock" class="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"></i>
            <input type="password" id="loginPass" required placeholder="••••••" class="w-full bg-slate-900/90 border border-slate-700 rounded-xl pl-10 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-brand-500">
          </div>
        </div>
        <button type="submit" class="w-full bg-brand-600 hover:bg-brand-500 text-white font-bold py-3 px-4 rounded-xl shadow-lg shadow-brand-600/30 transition flex items-center justify-center space-x-2 mt-2">
          <span>Entrar no Sistema</span>
          <i data-lucide="arrow-right" class="w-4 h-4"></i>
        </button>
      </form>
    </div>
  </div>

  <!-- PAINEL PRINCIPAL -->
  <div id="appScreen" class="hidden flex-1 flex flex-col min-h-screen">
    <header class="bg-slate-900/90 backdrop-blur-md border-b border-slate-800 sticky top-0 z-30 px-4 py-2.5 flex items-center justify-between">
      <div class="flex items-center space-x-3">
        <div class="w-8 h-8 rounded-lg bg-brand-600 flex items-center justify-center shadow-md shadow-brand-600/30">
          <i data-lucide="server" class="w-4 h-4 text-white"></i>
        </div>
        <div>
          <h1 class="font-bold text-sm text-white flex items-center gap-1.5">
            Wesley NAS <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">Online</span>
          </h1>
          <p class="text-[10px] text-slate-400">Tablet Hub • OTG Ativo</p>
        </div>
      </div>

      <div class="flex items-center space-x-2.5">
        <div class="flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-slate-800/80 border border-slate-700/60 text-xs font-semibold">
          <i data-lucide="battery" class="w-4 h-4 text-emerald-400"></i>
          <span id="headerBatteryText" class="text-slate-200">--%</span>
        </div>
        <div class="flex items-center space-x-2 pl-2 border-l border-slate-800">
          <div class="w-7 h-7 rounded-lg bg-indigo-500/20 border border-indigo-500/30 flex items-center justify-center text-xs font-bold text-indigo-300">W</div>
          <span class="text-xs font-bold text-slate-200 hidden sm:inline">Wesley</span>
          <button onclick="handleLogout()" title="Sair" class="p-1.5 rounded-lg bg-slate-800 hover:bg-rose-600 text-slate-400 hover:text-white transition">
            <i data-lucide="log-out" class="w-4 h-4"></i>
          </button>
        </div>
      </div>
    </header>

    <div class="flex-1 flex overflow-hidden">
      <aside class="w-72 bg-slate-900 border-r border-slate-800 flex flex-col">
        <div class="p-4 border-b border-slate-800">
          <div class="flex items-center justify-between mb-2.5">
            <span class="text-[11px] font-bold uppercase tracking-wider text-slate-400">Armazenamento</span>
            <button onclick="fetchSystemTelemetry()" title="Recarregar" class="text-slate-400 hover:text-white"><i data-lucide="refresh-cw" class="w-3.5 h-3.5"></i></button>
          </div>
          <div id="sidebarDrives" class="space-y-2"></div>
        </div>
        <div class="flex-1 p-4 overflow-y-auto space-y-1">
          <span class="text-[11px] font-bold uppercase tracking-wider text-slate-400 block mb-2">Pastas do Sistema</span>
          <button onclick="quickNav('Download')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-xl text-sm font-medium text-slate-300 hover:bg-slate-800 transition"><i data-lucide="download" class="w-4 h-4 text-blue-400"></i><span>Downloads</span></button>
          <button onclick="quickNav('DCIM')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-xl text-sm font-medium text-slate-300 hover:bg-slate-800 transition"><i data-lucide="camera" class="w-4 h-4 text-rose-400"></i><span>Fotos (DCIM)</span></button>
          <button onclick="quickNav('Movies')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-xl text-sm font-medium text-slate-300 hover:bg-slate-800 transition"><i data-lucide="film" class="w-4 h-4 text-purple-400"></i><span>Vídeos</span></button>
          <button onclick="quickNav('Music')" class="w-full flex items-center space-x-3 px-3 py-2 rounded-xl text-sm font-medium text-slate-300 hover:bg-slate-800 transition"><i data-lucide="music" class="w-4 h-4 text-emerald-400"></i><span>Músicas</span></button>
        </div>
      </aside>

      <main class="flex-1 flex flex-col bg-slate-950 overflow-hidden">
        <div class="p-4 border-b border-slate-800/80 bg-slate-900/60 flex items-center justify-between gap-3">
          <div class="flex-1 flex items-center space-x-1.5 overflow-x-auto py-1.5 px-3 rounded-xl bg-slate-900 border border-slate-800 text-xs font-semibold" id="mainBreadcrumbs"></div>
          <div class="flex items-center space-x-2">
            <input type="text" id="mainSearchInput" oninput="filterFiles()" placeholder="Buscar..." class="w-36 sm:w-44 bg-slate-900 border border-slate-800 rounded-xl px-3 py-1.5 text-xs text-white">
            <button onclick="document.getElementById('mainFileInput').click()" class="flex items-center space-x-1 bg-brand-600 hover:bg-brand-500 text-white px-3 py-1.5 rounded-xl text-xs font-bold"><i data-lucide="upload-cloud" class="w-3.5 h-3.5"></i><span>Enviar</span></button>
            <button onclick="createNewFolder()" class="p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-300"><i data-lucide="folder-plus" class="w-4 h-4"></i></button>
            <button onclick="downloadCurrentFolderZip()" class="p-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-300"><i data-lucide="archive" class="w-4 h-4"></i></button>
          </div>
        </div>

        <div id="dropArea" class="flex-1 overflow-y-auto p-4 sm:p-6">
          <div id="fileContainer" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3 sm:gap-4"></div>
        </div>
        <div class="px-4 py-2 bg-slate-900 border-t border-slate-800 text-[11px] text-slate-400 flex justify-between">
          <span id="folderItemCount">0 itens</span>
          <span>NAS Ativo • Streaming Habilitado</span>
        </div>
      </main>
    </div>
  </div>

  <input type="file" id="mainFileInput" multiple class="hidden" onchange="handleFileUpload(this.files)">

  <!-- MODAL DE STATUS DE CÓPIA EM TEMPO REAL -->
  <div id="uploadStatusModal" class="fixed inset-0 z-50 bg-black/75 backdrop-blur-md hidden flex items-center justify-center p-4">
    <div class="bg-slate-900 border border-slate-700/80 rounded-3xl p-6 max-w-lg w-full shadow-2xl relative overflow-hidden">
      <div class="absolute -top-10 -right-10 w-32 h-32 bg-brand-500/20 rounded-full blur-2xl pointer-events-none"></div>

      <div class="flex items-center space-x-3 mb-5">
        <div class="w-12 h-12 rounded-2xl bg-brand-600/20 border border-brand-500/30 text-brand-400 flex items-center justify-center shadow-lg animate-pulse">
          <i data-lucide="copy" class="w-6 h-6"></i>
        </div>
        <div class="min-w-0 flex-1">
          <h3 class="text-base font-bold text-white flex items-center gap-2">
            <span>Copiando para o NAS</span>
            <span id="uploadBatchCount" class="text-xs font-normal text-slate-400 bg-slate-800 px-2 py-0.5 rounded-full">1/1</span>
          </h3>
          <p id="uploadCurrentFileName" class="text-xs text-slate-300 truncate font-medium mt-0.5">Preparando transferência...</p>
        </div>
      </div>

      <div class="w-full bg-slate-950 rounded-full h-3.5 overflow-hidden p-0.5 border border-slate-800 mb-3.5">
        <div id="uploadMainProgressBar" class="bg-gradient-to-r from-brand-600 via-indigo-500 to-emerald-400 h-full rounded-full transition-all duration-150" style="width: 0%"></div>
      </div>

      <div class="grid grid-cols-3 gap-2 bg-slate-950/80 border border-slate-800/80 rounded-2xl p-3 text-center mb-5">
        <div>
          <span class="text-[10px] uppercase font-bold text-slate-400 block">Progresso</span>
          <span id="uploadPercentNumber" class="text-sm font-black text-white">0%</span>
        </div>
        <div class="border-x border-slate-800">
          <span class="text-[10px] uppercase font-bold text-slate-400 block">Velocidade</span>
          <span id="uploadSpeedText" class="text-sm font-black text-emerald-400">0 MB/s</span>
        </div>
        <div>
          <span class="text-[10px] uppercase font-bold text-slate-400 block">Tempo Restante</span>
          <span id="uploadEtaText" class="text-sm font-black text-brand-400">Calculando...</span>
        </div>
      </div>

      <div class="flex items-center justify-between text-xs text-slate-400 font-medium px-1">
        <span id="uploadTransferredBytes">0 MB de 0 MB</span>
        <button onclick="cancelCurrentUpload()" class="px-3 py-1.5 rounded-xl bg-slate-800 hover:bg-rose-600/80 hover:text-white text-slate-300 transition text-xs font-semibold">
          Cancelar
        </button>
      </div>
    </div>
  </div>

  <!-- MODAL DE MÍDIA -->
  <div id="viewerModal" class="fixed inset-0 z-50 bg-black/90 hidden flex flex-col p-4">
    <div class="flex items-center justify-between pb-3 border-b border-slate-800">
      <span id="viewerTitle" class="text-sm font-bold text-white truncate"></span>
      <button onclick="closeViewerModal()" class="p-2 rounded-xl bg-slate-800 text-slate-300"><i data-lucide="x" class="w-4 h-4"></i></button>
    </div>
    <div class="flex-1 flex items-center justify-center p-4" id="viewerContentBox"></div>
  </div>

  <script>
    let authToken = localStorage.getItem("nas_token") || "";
    let currentDirectory = "", currentActiveDrive = null, folderContents = [];
    let currentUploadXhr = null;

    function authHeaders() { return { "Authorization": `Bearer ${authToken}` }; }
    function formatBytes(b, decimals = 1) {
      if(!b || b === 0) return '0 B';
      let k = 1024, s = ['B','KB','MB','GB','TB'], i = Math.floor(Math.log(b)/Math.log(k));
      return parseFloat((b/Math.pow(k,i)).toFixed(decimals)) + ' ' + s[i];
    }

    function formatTime(seconds) {
      if(isNaN(seconds) || seconds <= 0) return "Poucos segundos";
      if(seconds < 60) return `${Math.round(seconds)} seg`;
      const mins = Math.floor(seconds / 60);
      const secs = Math.round(seconds % 60);
      return `${mins} min ${secs > 0 ? secs + 's' : ''}`;
    }

    async function initApp() {
      lucide.createIcons();
      if(!authToken) return showLoginScreen();
      try {
        const res = await fetch('/api/check-auth', { headers: authHeaders() });
        if(res.ok) showAppScreen(); else showLoginScreen();
      } catch(e) { showLoginScreen(); }
    }

    function showLoginScreen() { document.getElementById('loginScreen').classList.remove('hidden'); document.getElementById('appScreen').classList.add('hidden'); }
    function showAppScreen() { document.getElementById('loginScreen').classList.add('hidden'); document.getElementById('appScreen').classList.remove('hidden'); fetchSystemTelemetry(); setInterval(fetchSystemTelemetry, 10000); }

    document.getElementById('loginForm').onsubmit = async (e) => {
      e.preventDefault();
      const u = document.getElementById('loginUser').value.trim();
      const p = document.getElementById('loginPass').value.trim();
      const err = document.getElementById('loginError');
      err.classList.add('hidden');

      try {
        const res = await fetch('/api/login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ username: u, password: p }) });
        const data = await res.json();
        if(data.success && data.token) {
          authToken = data.token;
          localStorage.setItem("nas_token", data.token);
          showAppScreen();
        } else {
          err.textContent = data.detail || "Usuário ou senha inválidos.";
          err.classList.remove('hidden');
        }
      } catch(err) {
        err.textContent = "Erro de conexão com o NAS.";
        err.classList.remove('hidden');
      }
    };

    function handleLogout() {
      if(!confirm("Sair do NAS?")) return;
      fetch('/api/logout', { method: 'POST', headers: authHeaders() }).catch(()=>{});
      authToken = "";
      localStorage.removeItem("nas_token");
      showLoginScreen();
    }

    async function fetchSystemTelemetry() {
      try {
        const res = await fetch('/api/system-status', { headers: authHeaders() });
        if(res.status === 401) return showLoginScreen();
        const data = await res.json();
        if(data.battery && data.battery.percent !== null) {
          document.getElementById('headerBatteryText').textContent = `${data.battery.percent}% ${data.battery.charging ? '⚡' : ''}`;
        }
        if(data.drives) renderDrivesList(data.drives);
      } catch(e){}
    }

    function renderDrivesList(drives) {
      document.getElementById('sidebarDrives').innerHTML = drives.map(d => `
        <div onclick="selectDrive('${d.path.replace(/\\/g, '\\\\')}')" class="p-3 rounded-2xl border cursor-pointer ${currentActiveDrive && currentActiveDrive.path===d.path ? 'bg-brand-600/20 border-brand-500' : 'bg-slate-800/50 border-slate-800'}">
          <div class="flex justify-between text-xs font-bold text-white mb-1.5">
            <span class="truncate">${d.name}</span>
            <span class="text-[10px] px-1.5 py-0.5 rounded font-bold uppercase ${d.type==='otg' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-slate-800 text-slate-300'}">${d.type.toUpperCase()}</span>
          </div>
          <div class="w-full bg-slate-950 rounded-full h-1.5 mb-1.5"><div class="h-1.5 rounded-full ${d.type==='otg'?'bg-emerald-500':'bg-brand-500'}" style="width: ${d.percent}%"></div></div>
          <div class="flex justify-between text-[10px] text-slate-400 font-medium"><span>${formatBytes(d.free)} livres</span><span>${formatBytes(d.total)}</span></div>
        </div>
      `).join('');
      lucide.createIcons();
      if(!currentActiveDrive && drives.length > 0) selectDrive(drives[0].path, drives[0]);
    }

    function selectDrive(path, driveObj) { currentActiveDrive = driveObj || { path }; loadFolder(path); }

    async function loadFolder(path) {
      try {
        const res = await fetch(`/api/files?path=${encodeURIComponent(path)}`, { headers: authHeaders() });
        if(res.status === 401) return showLoginScreen();
        const data = await res.json();
        currentDirectory = data.current_path;
        folderContents = data.items;
        renderBreadcrumbs(data.current_path);
        renderFiles(data.items);
        document.getElementById('folderItemCount').textContent = `${data.count} itens`;
      } catch(e){}
    }

    function renderBreadcrumbs(path) {
      const parts = path.replace(/\\/g, '/').split('/').filter(Boolean);
      let html = `<button onclick="loadFolder('/')" class="p-1 text-slate-400 hover:text-white"><i data-lucide="home" class="w-3.5 h-3.5"></i></button>`;
      let acc = "";
      parts.forEach((p, i) => {
        acc += "/" + p;
        const cur = acc;
        html += `<span class="text-slate-600">/</span><button onclick="loadFolder('${cur.replace(/\\/g, '\\\\')}')" class="text-slate-400 hover:text-white truncate max-w-[120px]">${p}</button>`;
      });
      document.getElementById('mainBreadcrumbs').innerHTML = html;
      lucide.createIcons();
    }

    function renderFiles(items) {
      const q = document.getElementById('mainSearchInput').value.toLowerCase();
      const filtered = q ? items.filter(i => i.name.toLowerCase().includes(q)) : items;
      document.getElementById('fileContainer').innerHTML = filtered.map(item => `
        <div onclick="openItem('${encodeURIComponent(item.path)}', ${item.is_dir}, '${item.category}', '${encodeURIComponent(item.name)}')" class="file-card relative bg-slate-900 border border-slate-800 hover:border-brand-500 rounded-2xl p-3 flex flex-col justify-between cursor-pointer">
          <div class="w-full aspect-square rounded-xl bg-slate-800/80 flex items-center justify-center mb-2">
            <i data-lucide="${item.is_dir ? 'folder' : (item.category==='video'?'film':(item.category==='audio'?'music':(item.category==='image'?'image':'file')))}" class="w-8 h-8 ${item.is_dir ? 'text-amber-400' : 'text-brand-400'}"></i>
          </div>
          <p class="text-xs font-bold text-white truncate">${item.name}</p>
          <span class="text-[10px] text-slate-400 mt-1 font-medium">${item.is_dir ? 'Pasta' : formatBytes(item.size)}</span>
        </div>
      `).join('');
      lucide.createIcons();
    }

    function filterFiles() { renderFiles(folderContents); }
    function quickNav(sub) { if (currentActiveDrive) loadFolder(`${currentActiveDrive.path}/${sub}`); }

    function openItem(encPath, isDir, category, encName) {
      const path = decodeURIComponent(encPath), name = decodeURIComponent(encName);
      if(isDir) return loadFolder(path);
      const streamUrl = `/api/stream?path=${encodeURIComponent(path)}&token=${authToken}`;
      const modal = document.getElementById('viewerModal');
      document.getElementById('viewerTitle').textContent = name;
      if(category === 'video') {
        document.getElementById('viewerContentBox').innerHTML = `<video controls autoplay class="max-h-[80vh] max-w-full rounded-2xl"><source src="${streamUrl}"></video>`;
        modal.classList.remove('hidden');
      } else if(category === 'image') {
        document.getElementById('viewerContentBox').innerHTML = `<img src="${streamUrl}" class="max-h-[80vh] max-w-full rounded-2xl object-contain">`;
        modal.classList.remove('hidden');
      } else {
        window.location.href = streamUrl;
      }
    }
    function closeViewerModal() { document.getElementById('viewerModal').classList.add('hidden'); document.getElementById('viewerContentBox').innerHTML = ''; }

    // UPLOAD COM PROGRESSO, VELOCIDADE E TEMPO ESTIMADO
    function handleFileUpload(files) {
      if(!files || !files.length || !currentDirectory) return;

      const modal = document.getElementById('uploadStatusModal');
      const progressBar = document.getElementById('uploadMainProgressBar');
      const percentNumber = document.getElementById('uploadPercentNumber');
      const speedText = document.getElementById('uploadSpeedText');
      const etaText = document.getElementById('uploadEtaText');
      const transferredBytes = document.getElementById('uploadTransferredBytes');
      const fileNameEl = document.getElementById('uploadCurrentFileName');
      const batchCount = document.getElementById('uploadBatchCount');

      batchCount.textContent = `${files.length} arquivo(s)`;
      fileNameEl.textContent = files.length === 1 ? files[0].name : `${files[0].name} e mais ${files.length - 1}...`;
      progressBar.style.width = "0%";
      percentNumber.textContent = "0%";
      speedText.textContent = "Calculando...";
      etaText.textContent = "Calculando...";
      transferredBytes.textContent = `0 B de ${formatBytes(Array.from(files).reduce((a, b) => a + b.size, 0))}`;
      modal.classList.remove('hidden');

      const fd = new FormData();
      fd.append("target_path", currentDirectory);
      for(let f of files) fd.append("files", f);

      const startTime = Date.now();
      let lastLoaded = 0;
      let lastTime = startTime;

      const xhr = new XMLHttpRequest();
      currentUploadXhr = xhr;

      xhr.open("POST", "/api/upload", true);
      xhr.setRequestHeader("Authorization", `Bearer ${authToken}`);

      xhr.upload.onprogress = (e) => {
        if(e.lengthComputable) {
          const now = Date.now();
          const percent = Math.round((e.loaded / e.total) * 100);
          progressBar.style.width = `${percent}%`;
          percentNumber.textContent = `${percent}%`;
          transferredBytes.textContent = `${formatBytes(e.loaded)} de ${formatBytes(e.total)}`;

          const timeDiff = (now - lastTime) / 1000;
          if (timeDiff >= 0.5 || e.loaded === e.total) {
            const bytesDiff = e.loaded - lastLoaded;
            const currentSpeed = bytesDiff / timeDiff;
            const totalElapsed = (now - startTime) / 1000;
            const avgSpeed = e.loaded / totalElapsed;

            const effectiveSpeed = currentSpeed > 0 ? currentSpeed : avgSpeed;
            speedText.textContent = `${formatBytes(effectiveSpeed)}/s`;

            const remainingBytes = e.total - e.loaded;
            if (effectiveSpeed > 0) {
              const secondsRemaining = remainingBytes / effectiveSpeed;
              etaText.textContent = formatTime(secondsRemaining);
            }

            lastLoaded = e.loaded;
            lastTime = now;
          }
        }
      };

      xhr.onload = () => {
        setTimeout(() => {
          modal.classList.add('hidden');
          currentUploadXhr = null;
          loadFolder(currentDirectory);
        }, 500);
      };

      xhr.onerror = () => {
        modal.classList.add('hidden');
        currentUploadXhr = null;
        alert("Erro na conexão durante o envio.");
      };

      xhr.send(fd);
    }

    function cancelCurrentUpload() {
      if(currentUploadXhr) {
        currentUploadXhr.abort();
        currentUploadXhr = null;
        document.getElementById('uploadStatusModal').classList.add('hidden');
      }
    }

    function createNewFolder() {
      const n = prompt("Nome da nova pasta:");
      if(!n) return;
      const fd = new FormData();
      fd.append("parent_path", currentDirectory);
      fd.append("name", n.trim());
      fetch('/api/mkdir', { method: 'POST', headers: authHeaders(), body: fd }).then(() => loadFolder(currentDirectory));
    }

    function downloadCurrentFolderZip() {
      if(currentDirectory) window.location.href = `/api/download-zip?path=${encodeURIComponent(currentDirectory)}&token=${authToken}`;
    }

    window.onload = initApp;
  </script>
</body>
</html>
HTMLEOF

# 4. Backend Python app.py
echo -e "\033[1;33m[4/4] Configurando backend Python com suporte ao HD FA0C-D005...\033[0m"
cat << 'PYEOF' > "$DIR_BASE/app.py"
#!/usr/bin/env python3
import os, sys, json, shutil, urllib.parse, mimetypes, zipfile, tempfile, re, secrets, time
from http.server import HTTPServer, ThreadingHTTPServer, BaseHTTPRequestHandler

PORT = int(os.environ.get("PORT", 8080))
STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")

AUTH_USER = os.environ.get("NAS_USER", "Wesley")
AUTH_PASS = os.environ.get("NAS_PASS", "210769")

ACTIVE_SESSIONS = {}
SESSION_EXPIRY = 7 * 24 * 3600

def is_valid_token(token):
    if not token: return False
    if token in ACTIVE_SESSIONS:
        if time.time() < ACTIVE_SESSIONS[token]: return True
        else: del ACTIVE_SESSIONS[token]
    return False

def get_storage_drives():
    drives = []
    seen_paths = set()

    def add_drive(drive_id, name, path, drive_type):
        if not path: return
        real_path = os.path.realpath(path)
        if not os.path.exists(real_path) or real_path in seen_paths: return
        try:
            usage = shutil.disk_usage(real_path)
            if usage.total < 100 * 1024 * 1024: return

            seen_paths.add(real_path)
            drives.append({
                "id": drive_id, "name": name, "path": real_path, "type": drive_type,
                "total": usage.total, "used": usage.used, "free": usage.free,
                "percent": round((usage.used/usage.total)*100, 1) if usage.total>0 else 0
            })
        except Exception: pass

    # 1. Armazenamento Interno
    add_drive("internal", "Armazenamento Interno", "/storage/emulated/0", "internal")

    # 2. Varredura Inteligente do /proc/mounts (Detecta o seu HD vold/sdfat/exfat)
    if os.path.exists("/proc/mounts"):
        try:
            with open("/proc/mounts", "r") as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 3:
                        dev, mp, fs = parts[0], parts[1], parts[2].lower()
                        if "vold" in dev or any(x in fs for x in ["sdfat", "exfat", "vfat", "ntfs", "fuseblk"]):
                            if not any(x in mp for x in ["/emulated", "/self", "/knox", "apex"]):
                                uuid = os.path.basename(mp)
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
        except Exception: pass

    # 3. Varredura /storage
    if os.path.exists("/storage"):
        try:
            for item in os.listdir("/storage"):
                if re.match(r'^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$', item):
                    p = os.path.join("/storage", item)
                    add_drive(f"storage_{item}", f"HD Externo USB ({item})", p, "otg")
        except Exception: pass

    # 4. Termux Storage
    termux_storage = os.path.expanduser("~/storage")
    if os.path.exists(termux_storage):
        try:
            for item in os.listdir(termux_storage):
                if item.startswith("external"):
                    target = os.path.realpath(os.path.join(termux_storage, item))
                    add_drive("termux_ext", "HD Externo USB", target, "otg")
        except Exception: pass

    return drives

def get_file_category(fn, is_d):
    if is_d: return "folder"
    e = os.path.splitext(fn)[1].lower()
    if e in ['.mp4','.mkv','.webm','.avi','.mov','.flv','.wmv','.3gp','.m4v']: return "video"
    if e in ['.mp3','.wav','.flac','.ogg','.aac','.m4a','.opus']: return "audio"
    if e in ['.jpg','.jpeg','.png','.gif','.webp','.svg','.bmp','.ico']: return "image"
    if e in ['.pdf']: return "pdf"
    if e in ['.zip','.rar','.7z','.tar','.gz','.bz2','.xz','.apk']: return "archive"
    if e in ['.txt','.md','.log','.json','.xml','.html','.css','.js','.py','.sh']: return "code"
    return "document" if e in ['.doc','.docx','.xls','.xlsx','.ppt','.pptx'] else "file"

def get_system_status():
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
    return {"user": AUTH_USER, "battery": b, "memory": m, "drives": get_storage_drives()}

class NASRequestHandler(BaseHTTPRequestHandler):
    def get_token(self):
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "): return auth[7:].strip()
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if "token" in q: return q["token"][0]
        cookie = self.headers.get("Cookie", "")
        for c in cookie.split(";"):
            if "nas_token=" in c: return c.split("nas_token=")[-1].strip()
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
                with open(idx, "rb") as f: ct = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(ct)))
                self.end_headers()
                self.wfile.write(ct)
            else: self.send_json({"error": "Index not found"}, 404)
            return

        if path == "/api/check-auth":
            if self.is_authenticated(): self.send_json({"authenticated": True, "user": AUTH_USER})
            else: self.send_json({"authenticated": False}, 401)
            return

        if not self.is_authenticated():
            self.send_json({"detail": "Não autorizado"}, 401)
            return

        if path == "/api/drives": return self.send_json(get_storage_drives())
        if path == "/api/system-status": return self.send_json(get_system_status())
        if path == "/api/files":
            dp = query.get("path", [""])[0]
            if not dp or not os.path.exists(dp): return self.send_json({"detail": "Não encontrado"}, 404)
            try:
                items = []
                with os.scandir(dp) as sc:
                    for e in sc:
                        try:
                            st = e.stat()
                            is_d = e.is_dir(follow_symlinks=True)
                            items.append({"name": e.name, "path": os.path.abspath(e.path), "is_dir": is_d, "size": st.st_size if not is_d else 0, "modified": st.st_mtime, "category": get_file_category(e.name, is_d)})
                        except Exception: pass
                items.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
                parent = os.path.dirname(os.path.abspath(dp))
                if parent == os.path.abspath(dp): parent = None
                return self.send_json({"current_path": os.path.abspath(dp), "parent_path": parent, "items": items, "count": len(items)})
            except Exception as e: return self.send_json({"detail": str(e)}, 500)
        if path == "/api/stream":
            fp = query.get("path", [""])[0]
            if not fp or not os.path.exists(fp) or os.path.isdir(fp): return self.send_json({"detail": "Não encontrado"}, 404)
            self.serve_file_with_range(fp)
            return
        if path == "/api/download-zip":
            dp = query.get("path", [""])[0]
            if not dp or not os.path.exists(dp): return self.send_json({"detail": "Não encontrado"}, 404)
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
            try: data = json.loads(raw.decode("utf-8"))
            except Exception: data = self.parse_form_dict(raw, ct)
            user, pwd = data.get("username", "").strip(), data.get("password", "").strip()
            if user == AUTH_USER and pwd == AUTH_PASS:
                token = secrets.token_hex(24)
                ACTIVE_SESSIONS[token] = time.time() + SESSION_EXPIRY
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Set-Cookie", f"nas_token={token}; Path=/; Max-Age={SESSION_EXPIRY}; SameSite=Lax")
                self.end_headers()
                self.wfile.write(json.dumps({"success": True, "token": token, "user": AUTH_USER}).encode("utf-8"))
            else: self.send_json({"success": False, "detail": "Usuário ou senha incorretos."}, 401)
            return

        if path == "/api/logout":
            token = self.get_token()
            if token in ACTIVE_SESSIONS: del ACTIVE_SESSIONS[token]
            self.send_json({"success": True})
            return

        if not self.is_authenticated(): return self.send_json({"detail": "Não autorizado"}, 401)

        if path == "/api/mkdir":
            params = self.parse_form_dict(raw, ct)
            parent, name = params.get("parent_path", ""), params.get("name", "").strip()
            if parent and name: os.makedirs(os.path.join(parent, name), exist_ok=True); return self.send_json({"success": True})
            return self.send_json({"detail": "Parâmetros inválidos"}, 400)
        if path == "/api/upload":
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
                    if m: flds[m.group(1).decode("utf-8")] = bdy.rstrip(b"\r\n").decode("utf-8", errors="replace")
            return flds
        parsed = urllib.parse.parse_qs(raw.decode("utf-8", errors="replace"))
        return {k: v[0] if len(v)==1 else v for k, v in parsed.items()}

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
            with open(tz.name, "rb") as f: shutil.copyfileobj(f, self.wfile)
        finally:
            if os.path.exists(tz.name): os.remove(tz.name)

    def serve_file_with_range(self, file_path):
        sz = os.path.getsize(file_path)
        mime, _ = mimetypes.guess_type(file_path)
        mime = mime or "application/octet-stream"
        fn = os.path.basename(file_path)
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
            with open(file_path, "rb") as f:
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
            self.send_header("Content-Disposition", f'inline; filename="{fn}"')
            self.end_headers()
            with open(file_path, "rb") as f:
                while ck := f.read(64*1024):
                    try: self.wfile.write(ck)
                    except Exception: break

if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), NASRequestHandler)
    print("==========================================================")
    print("       🛡️  SISTEMA NAS PROFISSIONAL ANDROID (OTG)         ")
    print("==========================================================")
    print(f" [*] Usuário Administrador : {AUTH_USER}")
    print(f" [*] Senha de Acesso       : {AUTH_PASS}")
    print(f" [*] Servidor Rodando em   : http://0.0.0.0:{PORT}")
    print("==========================================================")
    try: server.serve_forever()
    except KeyboardInterrupt: server.server_close()
PYEOF

chmod +x "$DIR_BASE/app.py" 2>/dev/null || true
IP_LOCAL=$(ifconfig 2>/dev/null | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)

echo ""
echo -e "\033[1;32m========================================================\033[0m"
echo -e "\033[1;32m   ✅ WESLEY NAS OS PRONTO E RODANDO!                  \033[0m"
echo -e "\033[1;32m========================================================\033[0m"
echo -e " 👤 Usuário: \033[1;37mWesley\033[0m"
echo -e " 🔑 Senha:   \033[1;37m210769\033[0m"
echo ""
if [ -n "$IP_LOCAL" ]; then
    echo -e " 👉 Acesse no navegador: \033[1;33mhttp://${IP_LOCAL}:8080\033[0m"
else
    echo -e " 👉 Acesse no navegador: \033[1;33mhttp://127.0.0.1:8080\033[0m"
fi
echo -e "\033[1;36m========================================================\033[0m"
echo ""

cd "$DIR_BASE" && python app.py
