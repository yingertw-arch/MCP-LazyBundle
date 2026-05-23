# AI Agent 共用懶人包設定說明

本資料夾是「下次可以一次安裝的 AI Agent / MCP 懶人包」。目標是讓 Codex、OpenCode，以及同一台電腦上的其他 AI Agent 用同一份本機 MCP 設定與本機登入狀態，避免每個專案、每個 Agent 都反覆建立 token。

## 目前包含的 4 個 MCP

| MCP | 設定方式 | 認證方式 |
|---|---|---|
| GitHub | `https://api.githubcopilot.com/mcp/` remote MCP | 讀取本機環境變數 `GITHUB_PAT_TOKEN`；不要把真實 token 寫進檔案 |
| Firebase | `npx.cmd -y firebase-tools@latest mcp` | 使用本機 `firebase login` 狀態 |
| Obsidian | `http://127.0.0.1:27123/mcp/` localhost remote MCP | 讀取本機環境變數 `OBSIDIAN_API_KEY`；Obsidian 端服務需開啟 |
| NotebookLM | `npx.cmd -y notebooklm-mcp@latest` | 第一次用 MCP `setup_auth` 開瀏覽器登入 |

你前面提到的 `mathruffian-dot/antigravity-lazy-pack` 做法，本質不是把 token 包進專案，而是：

- MCP / 工具設定用一鍵寫入。
- 需要登入的服務走瀏覽器登入或 CLI 登入。
- 登入後的 cookie / credential 留在本機。
- 專案檔只放設定，不放 token。

核心原則：

1. **不手動建立 GitHub PAT**：改用 `gh auth login --web`。
2. **不使用長效 `FIREBASE_TOKEN`**：改用 `firebase login`。
3. **每台電腦只登入一次 CLI**：之後所有 Agent 直接呼叫 CLI。
4. **專案只放公開設定**：例如 Firebase Web App config；真正秘密不得提交。
5. **MCP 登入狀態只存在本機**：不要把 cookie、profile、token 上傳 GitHub。

## 已建立的檔案

- `mcp-servers/all.codex.toml`：Codex CLI / Codex Desktop 可用的四合一 TOML 設定片段。
- `mcp-servers/all.mcp.json`：通用 MCP client 可參考的四合一 JSON 設定。
- `mcp-servers/*.codex.toml`：個別 MCP 的 Codex 設定片段。
- `install-mcp-lazybundle.ps1`：舊版 Codex-only 安裝器，一鍵把 4 個 MCP 加到 `$HOME\.codex\config.toml`。
- `install-agent-lazybundle.ps1`：新版跨 Agent 安裝器，可寫入 Codex、OpenCode、Claude Desktop 與專案級 `mcp.json`。
- `setup-agent-auth.ps1`：檢查 GitHub CLI / Firebase CLI 登入狀態，必要時引導瀏覽器登入。
- `agent-configs/`：不同 AI Agent 可參考的 MCP 設定片段。
- `bundle-manifest.json`：懶人包清單，下次要加更多 MCP 就加到這裡。

## 推薦：跨 Agent 一鍵安裝 MCP

在 PowerShell 執行：

```powershell
cd "C:\Users\User\OneDrive\桌面\Codex\MCP-LazyBundle"
powershell -ExecutionPolicy Bypass -File .\install-agent-lazybundle.ps1
```

預設會嘗試安裝到：

- Codex：`$HOME\.codex\config.toml`
- OpenCode：`$HOME\.opencode.json`
- Claude Desktop：`%APPDATA%\Claude\claude_desktop_config.json`
- 目前資料夾的專案級 `mcp.json`

如果只想安裝到 OpenCode：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-agent-lazybundle.ps1 -Targets OpenCode
```

如果要替某個專案產生通用 `mcp.json`：

```powershell
powershell -ExecutionPolicy Bypass -File .\install-agent-lazybundle.ps1 -Targets ProjectMcpJson -ProjectPath "C:\path\to\your\project"
```

安裝器會先備份既有設定檔，然後合併 GitHub、Firebase、Obsidian、NotebookLM 四個 MCP 設定。它不會寫入真實 token、API key、PAT 或密碼。

## 舊版：只安裝 Codex MCP

```powershell
cd "C:\Users\User\OneDrive\桌面\Codex\MCP-LazyBundle"
powershell -ExecutionPolicy Bypass -File .\install-mcp-lazybundle.ps1
```

## 每台新電腦第一次登入

這一步是為了讓 OpenCode、Codex、Claude Code 或其他本機 AI Agent 都能共用 CLI 登入狀態，不需要每次建立 token。

```powershell
cd "C:\Users\User\OneDrive\桌面\Codex\MCP-LazyBundle"
powershell -ExecutionPolicy Bypass -File .\setup-agent-auth.ps1
```

這個腳本會：

- 檢查 `gh auth status`。
- 若 GitHub CLI 未登入，引導執行 `gh auth login --web --git-protocol https`。
- 檢查 `firebase projects:list`。
- 若 Firebase CLI 未登入，引導執行 `cmd /c firebase login`。

它不會要求你貼 token，也不會把 token 寫進專案。

## 為什麼其他 Agent 會一直要求 token？

通常是因為你安裝的是「需要環境變數 token 的 MCP server」，例如 GitHub / Obsidian remote MCP 需要本機授權資訊。這個懶人包只寫入「環境變數名稱」，不寫入真實 token。

如果你想做成像 AntiGravity 懶人包那種體驗，原則是：

1. GitHub / Obsidian 若需要 token，只能讀本機環境變數，不可寫進設定檔。
2. Firebase 使用已登入的 `firebase` CLI 狀態。
3. NotebookLM 使用 MCP 的瀏覽器登入流程，例如 `setup_auth`。
4. MCP 設定只放 command / args / env var name，不放真實 `TOKEN` 值。

換句話說：一鍵安裝的是「設定與工具」，不是「憑證」。

## 手動設定 Codex

若要手動加入 `$HOME\.codex\config.toml`，加入：

```toml
[mcp_servers.github]
url = "https://api.githubcopilot.com/mcp/"
bearer_token_env_var = "GITHUB_PAT_TOKEN"

[mcp_servers.firebase]
command = "npx.cmd"
args = ["-y", "firebase-tools@latest", "mcp"]

[mcp_servers.obsidian]
url = "http://127.0.0.1:27123/mcp/"
bearer_token_env_var = "OBSIDIAN_API_KEY"

[mcp_servers.notebooklm]
command = "npx.cmd"
args = ["-y", "notebooklm-mcp@latest"]
```

> Windows PowerShell 可能會封鎖 `npx.ps1`，所以這裡使用 `npx.cmd`。

## 第一次登入 NotebookLM

1. 安裝後重啟或 reload Codex。
2. 在 Codex 裡呼叫 NotebookLM MCP 的 `setup_auth` 工具。
3. 會開啟 Chrome 視窗，登入你的 Google 帳號。
4. 登入狀態會存在本機 `%APPDATA%\notebooklm-mcp\chrome_profile\`，不要提交或上傳這個資料夾。

## GitHub 設定：不要手動建立 PAT

第一次設定：

```powershell
$env:GITHUB_TOKEN=""
gh auth login --web --git-protocol https
gh auth status
```

之後 AI Agent 可以直接使用：

```powershell
git status
git add .
git commit -m "update project"
git push
gh repo create
gh pr create
```

如果 `gh auth status` 顯示未登入或 token 無效，再重新執行 `gh auth login --web` 即可。

## Firebase 設定：不要建立 FIREBASE_TOKEN

第一次設定：

```powershell
npm install -g firebase-tools
cmd /c firebase login
cmd /c firebase projects:list
```

部署 Firestore Rules：

```powershell
cmd /c firebase deploy --only firestore:rules
```

不要使用 `firebase login:ci` 產生長效 token；一般本機 AI Agent 工作流使用 `firebase login` 即可。

## Firebase Web App config

純前端網站可以把 Firebase Web App config 放在 `firebase-config.js`。它是專案識別資訊，不是 service account 私鑰。

可以提交的範例：

```js
window.FIREBASE_CONFIG = {
  apiKey: "YOUR_FIREBASE_WEB_API_KEY",
  authDomain: "YOUR_PROJECT.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT.firebasestorage.app",
  messagingSenderId: "YOUR_SENDER_ID",
  appId: "YOUR_WEB_APP_ID",
  measurementId: "YOUR_MEASUREMENT_ID"
};
```

真正要保護的是 Firestore Security Rules、Authentication authorized domains、Google Cloud API key restrictions，以及任何 service account private key。

## 安全提醒

- 這個設定不保存 Google 密碼、API key 或 token。
- 不要把 `%APPDATA%\notebooklm-mcp`、`.env`、token、cookie、service account key 或任何憑證上傳到 GitHub。
- NotebookLM MCP 會透過瀏覽器自動化操作你的 NotebookLM，請只用在你信任的本機環境。
