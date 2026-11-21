# 行山腳 HikeHub · 香港行山路線與山友社群桌面移動應用

> **課程項目**：COMP 7510 Group Project · 行山腳 HikeHub  
> **技術棧**：Python 3.11+（實測 3.13） · PySide6 (Qt 6.9+，實測 6.12) · Qt Quick (QML) · QtLocation (OSM) · Supabase (Postgres + Auth + Storage)  
> **視口規格**：390 × 844（iPhone 14 邏輯分辨率），底部 5 Tab 導航（首頁 / 線路 / 出發 / 社區 / 我的）

---

## 一、兩種啟動方式

### 方式 A：雙擊 `HikeHub.exe`（交付 / 驗收，免安裝任何環境）

- 適用：助教驗收、發給沒有 Python 環境的成員。
- 操作：直接**雙擊 `dist/HikeHub.exe`** 即可啟動，無需安裝 Python、無需 pip、也**無需手動放置 `.env`**（公開配置已打包進 exe）。
- 如需覆蓋雲端配置，可另將 `.env` 放到 `HikeHub.exe` 同目錄，程式會優先讀取（回退鏈：exe 同目錄 `.env` → 內置 `.env` → 內置 `.env.example`）。
- 產物為 64-bit Windows one-file（約 193 MB，PyInstaller 6.22.x / PySide6 6.12）。

### 方式 B：源碼 Demo 啟動（開發期，雙擊 `啟動Demo.bat` 或命令行）

適用：本機開發調試、需要改代碼後即時生效。

```bash
# 1. 安裝 Python 3.11+（實測 3.13）並在安裝時勾選 Add to PATH
# 2. 安裝依賴
pip install -r requirements.txt

# 3. 準備環境變數（倉庫已附帶可用於評分的 SUPABASE_URL 與 SUPABASE_ANON_KEY，
#    .env.example 內即為可直接使用的真實公開值；僅在自建專案時才需改填）
copy .env.example .env

# 4. 啟動（二選一）
python main.py
# 或直接雙擊「啟動Demo.bat」（其內部即執行 python main.py）
```

---

## 二、打包 Windows 執行檔

```bash
# 使用預置的 build.spec 打包（已顯式包含 app/ QML 資源與 QtLocation/QtPositioning 插件）
pyinstaller build.spec --noconfirm --clean
```

- 產出位置：`dist/HikeHub.exe`
- 分發方式：**只發 `HikeHub.exe` 這一個檔案**即可；對方雙擊即用，無需任何依賴或額外檔案。

---

## 三、預建 6 個測試帳號（密碼統一為 `HikeHub2026!`）

登錄頁（`SignInPage.qml`）已提供一鍵快捷填入按鈕，亦可手動輸入：

| # | 測試帳號 Email | 密碼 | 角色與暱稱 |
|---|---|---|---|
| 1 | `ahon@hikehub.hk` | `HikeHub2026!` | 阿瀚 · 山野行者（長線與打卡達人） |
| 2 | `kaki@hikehub.hk` | `HikeHub2026!` | 嘉琪 KaKi（港島風景與補給分享） |
| 3 | `fai@hikehub.hk` | `HikeHub2026!` | 輝哥 · 裝備控（撤退路線與問答解答） |
| 4 | `yannes@hikehub.hk` | `HikeHub2026!` | Yannes 山系少女（新手路線整理） |
| 5 | `kelvin@hikehub.hk` | `HikeHub2026!` | Kelvin 越野跑手（夜行與鳳凰徑） |
| 6 | `mandy@hikehub.hk` | `HikeHub2026!` | Mandy 郊遊日記（新手提問與採納示範） |

---

## 四、Supabase 資料庫初始化說明

1. **環境配置（新建獨立 HikeHub 專案時才需改動）**：
   - 倉庫的 `.env.example` 已內含**可直接使用的真實公開值**（`SUPABASE_URL` 與 anon public key，前端公開安全）。
   - 僅當你想改用「自己新建的 Supabase 專案」時，才需於 `Project Settings → API` 複製新 `Project URL` 與 `anon public key` 填入 `.env.example`，再 `copy .env.example .env`。
   - `SUPABASE_BUCKET`: `trail-photos`
   - 詳細建庫與匯入步驟見 **`supabase/EXECUTE.md`**。
2. **先建立 6 個可登入測試帳號**：`supabase/create_auth_users.ps1`（Auth Admin API）。
   > 新版 Supabase 的 GoTrue 不認可用 SQL 直接寫入 `auth.users` 的帳號，必須走 Auth Admin API；
   > 詳見 `supabase/EXECUTE.md` 步驟 0。
3. 於 Supabase SQL Editor 依序執行（雲端手動貼上）：
   - `supabase/schema.sql`（建立 9 張表、外鍵、索引與計數器 Trigger）
   - `supabase/policies.sql`（啟用 RLS 策略與 Storage bucket 權限）
   - `supabase/seed.sql`（寫入 6 個 Profile、10 條香港經典行山路線含折線座標 `path`、25 個路段、22 個打卡點及社區種子貼文）
4. 驗證：於 SQL Editor 執行 `tests/verify_db.sql`，確認 9 張表行數、計數一致性與 RLS 讀取通過。
5. **雙重連線韌性設計**：`app/backend/supabase_client.py` 啟動時會自動校驗 `.env` 中的 URL 與 JWT 簽名；若缺失 `.env` 會在登錄頁明確提示「請檢查 .env 配置」；若教室/評分環境網路受限或遠端未建表，會自動無縫切換至與 `seed.sql` 完全一致的本地持久化鏡像，確保所有頁面、篩選、打卡、發帖、點讚、評論與問答採納 100% 可交互。

---

## 五、Step 0 六支環境驗針腳本

```bash
python tests/test_01_pyside_window.py --headless-check
python tests/test_02_supabase_auth.py
python tests/test_03_db_crud.py
python tests/test_04_storage_upload.py
python tests/test_05_osm_map.py --headless-check
python tests/test_06_location_source.py
```

---

## 六、四人分工與署名產出（設計 / 程式 / 報告）

| 成員 | 角色 | 負責代碼與設計產出 | 報告主筆章節 |
|---|---|---|---|
| **Member A** | 數據架構師 | `supabase/*.sql`、`supabase_client.py`、`trail/post/social/location_service.py`、`models.py`、`tests/*`、`build.spec`、`docs/erd.png` | §3 數據庫設計、§4 后端服務層 |
| **Member B** | 應用框架與帳號 | `main.py`、`app/main.qml`、`Theme.qml`、`bridge.py`、`auth_service.py`、`workers.py`、`SignInPage.qml`、`app/components/*` | §1 專案背景與四層架構 |
| **Member C** | 路線、出發與地圖 | `HomePage.qml`、`RouteListPage.qml`、`RouteDetailPage.qml`、`StartPage.qml`（OSM地圖+軌跡+雙源定位）、`ComposePage.qml` | §4 路線與定位雙源實作 |
| **Member D** | 社群互動與個人 | `CommunityPage.qml`、`PostDetailPage.qml`（點讚/收藏/評論/採納）、`ProfilePage.qml`、`EditProfilePage.qml`、`docs/flow.png` | §2 功能規格、§5 介面流程、§6 測試與總結 |
