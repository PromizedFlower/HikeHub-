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

## 6. Team Contributions (English) — Scope, Modules, Collaboration Interfaces & Deliverables

> **Ownership rule — no overlap, no gaps:** every tracked source / configuration file has exactly *one* owner. A "collaboration interface" describes the contract that other members call; it is **not** shared file ownership. Shared documents (`README.md`, `docs/01`, `02`, `03`, `05`, `留档.md`, the architecture DOCX) are maintained jointly by all four members.

### Member A — Data Architect & Backend Services
- **Scope:** database design, data-access layer, service contracts, data models, verification scripts and the Windows build recipe.
- **Owned files:**
  - `supabase/`: `schema.sql`, `policies.sql`, `seed.sql`, `all_in_one.sql`, `EXECUTE.md`, `create_auth_users.ps1`
  - `app/backend/`: `supabase_client.py`, `remote_store.py`, `trail_service.py`, `post_service.py`, `social_service.py`, `models.py`
  - `tests/`: `test_01..04.py`, `verify_db.sql`
  - root / assets: `build.spec`, `.env.example`, `assets/*`, `docs/erd.png`, `dist/HikeHub.exe` (build output)
- **Collaboration interfaces:**
  - Exposes `get_db().get_status_summary()` (online / offline / mode) and `get_remote_store()` with `WriteResult(ok, offline, data, error)` — consumed by Member B's `bridge.py` and, indirectly, by all C/D pages.
  - Defines and implements the service signatures `list_trails()`, `get_trail_detail()`, `get_home_feed()`, `create_post()`, `update_post()`, `delete_post()`, `toggle_like()`, `toggle_favorite()`, `add_comment()`, `accept_comment()` — invoked **only** through B's `api.*` slots.
  - Owns the 9-table schema, the `trails.path` JSONB format `[[lat,lng],...]`, the fixed UUIDs, the RLS policies and the three counter Triggers that keep `like_count` / `comment_count` / `favorite_count` consistent.
  - Defines the `LocationProvider` contract that Member C implements in `location_service.py`; supplies the `trails` / `checkpoints` geometry that C renders on the map.
- **Deliverables:** ERD (`docs/erd.png`), 9-table schema + RLS + seed + `all_in_one.sql`, 6 Auth accounts, backend service layer, offline mirror sync, 4 DB verification scripts, `HikeHub.exe` build configuration.
- **Report chapters:** §3 Database Design; §4.1 Service Layer & Triggers.

### Member B — Application Framework, Bridge & Identity
- **Scope:** process entry, QML shell, navigation, theme system, the QML↔Python bridge, authentication / session, background workers, shared UI components and the sign-in experience.
- **Owned files:**
  - root: `main.py`, `requirements.txt`, `启动Demo.bat`
  - `app/`: `main.qml`, `theme/Theme.qml`
  - `app/backend/`: `bridge.py`, `auth_service.py`, `workers.py`
  - `app/pages/`: `SignInPage.qml`
  - `app/components/`: `BottomTabBar.qml`, `PrimaryButton.qml`, `SegmentedTabs.qml`, `TagChip.qml`, `DifficultyBadge.qml`, `EmptyState.qml`, `StatPill.qml`, `LoadingOverlay.qml`, `TrailCard.qml`, `PhotoTile.qml`
- **Collaboration interfaces:**
  - Owns the single `api.*` `@Slot` contract (`signIn`, `publishPost`, `toggleLike`, `toggleFavorite`, `addComment`, `acceptAnswer`, `filterTrails`, `startHike`, `checkInNextPoint`, `updateProfile`, `editMyPost`, `deleteMyPost`, …) that **all** C/D pages call; pages never import backend Python directly.
  - Exposes `@Property` data and `@Signal` refresh events (`refreshHome`, `refreshCommunity`, `refreshProfileData`, `toastMessage`) to QML; translates between QML `QUrl` values and plain strings before delegating to A's services.
  - Consumes A's `auth_service` / service layer and `workers.run_in_background` for non-blocking tasks; applies the `Theme.qml` tokens (6 colours, 3 font sizes) used by every page.
  - Provides the 5 independent `StackView` navigation shell and the `openTrailDetail` / `openPostDetail` / `openComposePage` page transitions used by C and D.
- **Deliverables:** app entry + 5-Tab navigation shell, theme system, frozen API bridge contract, preset 6-account sign-in, 10 shared components, one-click demo launcher, dependency manifest.
- **Report chapters:** §1 Background & Four-Layer Architecture.

### Member C — Trails, Departure & Map
- **Scope:** route discovery, filtering, trail detail, OSM map rendering, dual-source location, check-in and post composition with photo upload.
- **Owned files:**
  - `app/pages/`: `HomePage.qml`, `RouteListPage.qml`, `RouteDetailPage.qml`, `StartPage.qml`, `ComposePage.qml`
  - `app/backend/`: `location_service.py` (full implementation of the contract defined by A)
  - `app/components/`: `MapCanvas.qml`, `CheckpointMarker.qml`, `TrackPolyline.qml`
  - `tests/`: `test_05_osm_map.py`, `test_06_location_source.py`
- **Collaboration interfaces:**
  - Calls B's `api.filterTrails()` / `loadTrailDetail()` / `startHike()` / `checkInNextPoint()` / `completeHikeSettlement()`; never accesses A's services directly.
  - Consumes A's `trails.path` JSONB polyline and `checkpoints` coordinates; renders them through the map components it owns.
  - Implements A's `LocationProvider` contract with `SystemProvider` (Windows `winrt`) and `SimulatedProvider`, including the 3-second no-notice fallback.
  - Hands the hike-settlement payload to A's `post_service.create_post(type="trip")` through B's bridge, then relies on B's navigation signal to route the new post to D's community feed.
- **Deliverables:** 5 pages, OSM map with walked/unwalked polyline + checkpoint markers, dual-source location with 3-second fallback, compose/publish page with photo upload, 2 verification scripts.
- **Report chapters:** §4.2 OSM Map & Dual-Source Location.

### Member D — Social Interaction & Profile
- **Scope:** community feed, Q&A, post detail interactions (like / favorite / comment / accept), personal centre and the interface flow diagram.
- **Owned files:**
  - `app/pages/`: `CommunityPage.qml`, `PostDetailPage.qml`, `ProfilePage.qml`, `EditProfilePage.qml`
  - `docs/flow.png` (interface / navigation flow diagram)
- **Collaboration interfaces:**
  - Calls B's `api.toggleLike()` / `toggleFavorite()` / `addComment()` / `acceptAnswer()` / `editMyPost()` / `deleteMyPost()` / `updateProfile()`; the write path lands in A's `social_service` / `post_service` / `auth_service`.
  - Reads A's Trigger-maintained counters (`like_count`, `comment_count`, `favorite_count`) via B's `@Property` mirror bindings and refreshes on B's `refreshCommunity` / `refreshProfileData` signals.
  - Receives newly published posts from C's `ComposePage` via B's navigation signal — no direct C→D file dependency.
  - Owns the delete-confirmation overlay and the one-tap interaction state machine (accepted answer is irreversible).
- **Deliverables:** 4 pages, two-column waterfall feed + Q&A tabs, full like/favorite/comment/accept chain, profile stats + my-post management with delete confirmation, flow diagram, 5-minute demo script.
- **Report chapters:** §2 Functional Specification; §5 Interface Flow; §6 Testing & Demo.

> **Coverage check:** every tracked code/config file in `app/`, `supabase/`, `tests/`, `assets/` and the repository root appears exactly once in the four "Owned files" lists above; jointly maintained documents are the only exception. No file is co-owned, and no module is unassigned.
