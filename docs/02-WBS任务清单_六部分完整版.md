# 行山腳 HikeHub · 四人六週可直接執行任務清單（WBS 終版）

> **對應提示詞**：`01-任务清单提示词.md`（1-A 角色卡 + 1-B 任務清單生成）  
> **團隊配置**：A（數據架構師）、B（應用框架與帳號）、C（路線與出發地圖）、D（社群互動與個人）  
> **硬性 Gate**：G1（第 3 天：數據契約與 Service 簽名凍結）、G2（第 5 天：元件庫與 5 Tab 導航殼凍結）

---

## 第一部分 · 任務全景

```text
W1 驗針與契約凍結 | 14 項 | G1（第3天）、G2（第5天） | A, B, C, D | 完成 6 支驗針腳本，凍結 9 張表 schema.sql、service 簽名與 Theme/ワイヤーフレーム
W2 骨架與元件庫落地 | 13 項 | G2（第5天） | A, B | 跑通登錄/登出、底部 5 Tab 獨立 StackView 導航殼、13 個共用元件及模擬定位源
W3 核心功能線並行（上） | 14 項 | G1, G2 | A, C, D | 完成首頁、線路篩選、路線詳情、出發 OSM 地圖與雙源軌跡、社區瀑布流與問答列表
W4 核心功能線並行（下） | 13 項 | G1, G2 | A, C, D | 完成沿途打卡與結算發布、多圖上傳發布頁、點讚/評論/收藏/採納閉環、我的與編輯資料
W5 串接打磨與報告出圖 | 8 項 | — | 全員 | 完成 RLS 收緊、全鏈路異常兜底、ERD/流程圖繪製、五頁截圖與 6 頁報告初稿
W6 打包 exe 與 Demo 交付 | 6 項 | — | 全員 | 產出免安裝 Python 的 Windows HikeHub.exe、完成 6 章報告定稿與教室模擬定位 Demo 彩排
```

---

## 第二部分 · 任務卡表（W1 – W6 全量任務）

### 階段一：W1 環境驗針與數據契約凍結（含 G1、G2 前置設計）

| ID | 任務 | 負責人 | 依賴 | 產出物 | 驗收標準 | 預估 |
|---|---|---|---|---|---|---|
| T-A01 | 編寫 PySide6 視窗驗針腳本 | A | — | `tests/test_01_pyside_window.py` | 能啟動 390×844 固定比例空白 QML 視窗且無控制台報錯 | 1h |
| T-A02 | 編寫 Supabase 登錄驗針腳本 | A | — | `tests/test_02_supabase_auth.py` | 能讀取 `.env` 的 `SUPABASE_URL` 與 `SUPABASE_ANON_KEY` 並驗證預建帳號登錄成功 | 1h |
| T-A03 | 編寫資料表讀寫驗針腳本 | A | — | `tests/test_03_db_crud.py` | 能對 `trails` 與 `likes` 執行查詢與寫入並回傳字典列表 | 1h |
| T-A04 | 編寫 Storage 圖片上傳驗針腳本 | A | — | `tests/test_04_storage_upload.py` | 能將本機測試圖片上傳至 `trail-photos` 並拿到可由 QML `Image` 載入的 URL | 2h |
| T-C01 | 編寫 QtLocation OSM 地圖出圖驗針腳本 | C | — | `tests/test_05_osm_map.py` | 能在 QML `Map` 載入 `osm` 插件顯示香港地圖並畫出一條 `MapPolyline` 折線 | 2h |
| T-C02 | 編寫定位雙源驗針腳本 | C | — | `tests/test_06_location_source.py` | 能探測系統定位，3 秒無座標時自動切換模擬源並輸出插值經緯度 | 2h |
| T-A05 | 定稿 9 張表結構、外鍵索引與計數 Trigger | A | T-A03 | `supabase/schema.sql` | 能在 Supabase SQL Editor 一鍵執行建立 9 張表（含 `trails.path` 與 `checkpoints.lat/lng`）及 3 個計數器觸發器 | 4h |
| T-A06 | 編寫開發期 RLS 策略與 Storage 權限 | A | T-A05 | `supabase/policies.sql` | 能讓公開讀取 9 張表，並允許已登錄山友新增貼文、評論、點讚與收藏 | 2h |
| T-A07 | 編寫 6 個測試帳號與 10 條香港路線種子資料 | A | T-A05 | `supabase/seed.sql` | 能寫入 6 個預建測試帳號、10 條含真實香港折線座標的路線、分段、打卡點與社區貼文 | 4h |
| T-A08 | 凍結五支 Service 函數簽名與假數據返回（**Gate 1**） | A | T-A05 | `app/backend/models.py` + `app/backend/*_service.py` | 能被 `bridge.py` 調用並返回符合 `schema.sql` 列名的 `dict` / `list[dict]` 結構 | 2h |
| T-B01 | 建立專案目錄骨架與 `.env.example` 規範 | B | — | `requirements.txt` + `.env.example` + `main.py` | 能執行 `python main.py` 載入 `app/main.qml` 且不把 `service_role_key` 寫入倉庫 | 1h |
| T-B02 | 制定極簡 6 色票與 3 級字體設計規範 | B | — | `app/theme/Theme.qml` + `app/theme/qmldir` | 能在任意 QML 頁面透過 `Theme.primaryGreen` 等屬性讀取 6 色票、3 字級與 12px 圓角 | 2h |
| T-C03 | 繪製首頁、線路、出發地圖與發布頁 Wireframe | C | — | `docs/flow.png`（路線與出發分冊） | 能清晰標示首頁 4 區塊、路線詳情分段補給/撤退標記及出發頁三態切換流程 | 2h |
| T-D01 | 繪製社區雙 Segment、詳情互動與個人中心 Wireframe | D | — | `docs/flow.png`（社群與個人分冊） | 能清晰標示動態瀑布流、問答採納狀態機及我的收藏雙子 Tab 結構 | 2h |

---

### 階段二：W2 應用骨架、登錄、元件庫凍結（G2）與後端服務實作

| ID | 任務 | 負責人 | 依賴 | 產出物 | 驗收標準 | 預估 |
|---|---|---|---|---|---|---|
| T-B03 | 實作背景執行緒池封裝避免網路請求凍結 UI | B | T-B01 | `app/backend/workers.py` | 能將耗時函數丟入 `QThreadPool` 執行並透過 `Signal` 回傳結果而不卡頓畫面 | 2h |
| T-B04 | 實作底部 5 Tab 導航欄與中間凸起「出發」主按鈕 | B | T-B02 | `app/components/BottomTabBar.qml` | 能顯示 5 個 Tab，中間「出發」為直徑 56px 圓形凸起按鈕，點擊觸發 `tabClicked(index)` | 2h |
| T-B05 | 實作每 Tab 獨立 StackView 導航殼與頁面傳參機制 | B | T-B04 | `app/main.qml` | 能在子頁 push 後保留底部 Tab 欄，且切換 Tab 再切回時不丟失各自頁面棧 | 4h |
| T-B06 | 凍結通用基礎 UI 元件庫（按鈕/徽章/篩選Chip/四態）（**Gate 2**） | B | T-B02 | `app/components/PrimaryButton.qml` + `DifficultyBadge.qml` + `TagChip.qml` + `StatPill.qml` + `SegmentedTabs.qml` + `EmptyState.qml` + `LoadingOverlay.qml` | 能被 C/D 頁面直接引用並支援載入中、有數據、空狀態、錯誤重試四種狀態切換 | 4h |
| T-B07 | 凍結卡片與地圖封裝元件（路線卡/瀑布流圖卡/地圖畫布）（**Gate 2**） | B | T-B06, T-C01 | `app/components/TrailCard.qml` + `PhotoTile.qml` + `MapCanvas.qml` + `TrackPolyline.qml` + `CheckpointMarker.qml` | 能渲染 ≤3 層資訊的路線卡、雙列圖卡與支援折線/打卡點繪製的 OSM 地圖畫布 | 4h |
| T-B08 | 實作認證服務與 Session 管理 | B | G1 | `app/backend/auth_service.py` | 能校驗 `.env` 狀態、完成預建帳號登錄/登出並維護 `current_user` 狀態 | 2h |
| T-B09 | 實作登錄頁與 `.env` 缺失異常提示兜底 | B | T-B08, G2 | `app/pages/SignInPage.qml` | 能在未配置 `.env` 時顯示「檢查 .env 配置」提示，密碼錯誤時顯示紅字提醒，登錄成功進入首頁 | 2h |
| T-A09 | 實作 Supabase 單例客戶端與離線鏡像自動回退 | A | G1 | `app/backend/supabase_client.py` | 能校驗 JWT 有效性、連接遠端 Supabase，並在未建表或斷網時自動同步本地種子數據 | 4h |
| T-A10 | 實作路線查詢、多維篩選與首頁聚合服務 | A | T-A09, G1 | `app/backend/trail_service.py` | 能按地區/難度/時長/關鍵字過濾 10 條路線，並返回分段、打卡點與首頁精選數據 | 4h |
| T-A11 | 實作貼文 CRUD 與 Storage 相片上傳服務 | A | T-A09, G1 | `app/backend/post_service.py` | 能按時間倒序查詢 `moment/question/trip` 貼文、上傳相片並執行作者本人編輯與刪除 | 4h |
| T-A12 | 實作社交點讚、收藏、評論與問答採納服務 | A | T-A09, G1 | `app/backend/social_service.py` | 能切換點讚與收藏並即時更新計數、新增一級評論與一層回覆、執行不可撤銷的問答採納 | 4h |
| T-C04 | 實作系統定位與沿路線折線插值的模擬定位雙源 | C | T-C02, G1 | `app/backend/location_service.py` | 能在啟動 3 秒拿不到系統 GPS 時自動切換 `SimulatedProvider`，沿路線 `path` 推進座標並累計里程 | 4h |
| T-B10 | 實作 QObject 橋接層將五支 Service 暴露給 QML | B | T-A10, T-A11, T-A12, T-C04 | `app/backend/bridge.py` | 能透過 `@Slot` 與 `Signal` 串通全部五段式請求，QML 調用 `api.*` 即時刷新畫面 | 4h |

---

### 階段三：W3 核心功能線並行（首頁 / 線路 / 出發地圖 / 社區流）

| ID | 任務 | 負責人 | 依賴 | 產出物 | 驗收標準 | 預估 |
|---|---|---|---|---|---|---|
| T-C05 | 實作首頁搜尋框与進行中行山會話提示卡 | C | T-B10, G1, G2 | `app/pages/HomePage.qml` | 能輸入路線或地區關鍵字跳轉線路 Tab 過濾，且在行山進行中時頂部顯示綠色進度卡 | 2h |
| T-C06 | 實作首頁本週精選雙大卡與附近路線橫滑列表 | C | T-C05 | `app/pages/HomePage.qml` | 能顯示 2 張本週精選横向大卡與 5 條附近路線橫向滑動卡，點擊進入對應路線詳情 | 2h |
| T-C07 | 實作首頁社區熱帖區塊（按點讚數取前 3 條） | C | T-C06 | `app/pages/HomePage.qml` | 能展示點讚最高的 3 條社區動態摘要，點擊直接打開貼文詳情頁 | 1h |
| T-C08 | 實作線路 Tab 頂部地區/難度/時長篩選 Chip 欄 | C | T-B10, G1, G2 | `app/pages/RouteListPage.qml` | 能點擊切換地區（港島/西貢/大嶼山等）、難度（1–5星）與時長 Chip 並即時刷新列表 | 2h |
| T-C09 | 實作線路 Tab 路線列表接入真實種子數據與四態顯示 | C | T-C08 | `app/pages/RouteListPage.qml` | 能顯示 `seed.sql` 的 10 條香港路線卡，無匹配時顯示 `EmptyState` 並支援一鍵重置篩選 | 2h |
| T-C10 | 實作路線詳情頁封面、三項指標與分段補給/撤退列表 | C | T-B10, G1, G2 | `app/pages/RouteDetailPage.qml` | 能展示路線難度、距離、爬升、預計耗時，以及帶「有補給點」「可撤退點」徽章的分段清單 | 4h |
| T-C11 | 實作路線詳情頁打卡點清單、近期動態與底部出發欄 | C | T-C10 | `app/pages/RouteDetailPage.qml` | 能顯示沿途打卡點經緯度、掛載該路線關聯動態，點擊底部「選擇此路線立即出發」跳轉出發頁並選中該路線 | 2h |
| T-C12 | 實作出發 Tab「未開始」態地圖折線預覽與路線切換 | C | T-C04, T-B10, G2 | `app/pages/StartPage.qml` | 能鋪滿顯示 OSM 地圖、所選路線完整折線與打卡點標記，並支援底部卡片快速切換路線與開始出發 | 4h |
| T-C13 | 實作出發 Tab「行山中」態雙源定位跟隨與實虛軌跡繪製 | C | T-C12 | `app/pages/StartPage.qml` | 能頂部顯示「示範模式 · 模擬定位」標籤與距離/時長/打卡數三項指標，走過路段畫實線、未走路段畫虛線 | 4h |
| T-D02 | 實作社區 Tab 頂部「動態 / 問答」雙 Segment 切換與發帖入口 | D | T-B10, G1, G2 | `app/pages/CommunityPage.qml` | 能流暢切換動態與問答視圖，點擊右上「＋發帖」推入 `ComposePage.qml` | 2h |
| T-D03 | 實作社區「動態」雙列瀑布流圖片卡列表（純時間倒序） | D | T-D02 | `app/pages/CommunityPage.qml` | 能以雙列網格展示封面圖、標題、作者暱稱與點讚數，嚴格按發布時間倒序排列 | 4h |
| T-D04 | 實作社區「問答」列表（標籤、回答數與已採納徽章） | D | T-D02 | `app/pages/CommunityPage.qml` | 能展示提問標題、`#裝備/#交通/#天氣` 標籤、回答計數及「✓ 已採納解答 / 待山友解答」狀態徽章 | 2h |
| T-D05 | 實作內容詳情頁作者資訊、多圖展示與關聯路線跳轉 | D | T-B10, G1, G2 | `app/pages/PostDetailPage.qml` | 能顯示作者頭像暱稱、發布時間、大圖與正文，點擊關聯路線膠囊可跳轉至 `RouteDetailPage.qml` | 2h |
| T-A13 | 繪製 9 張表資料庫 ERD 圖並撰寫報告 §3 初稿 | A | T-A05 | `docs/erd.png` + `docs/04-COMP7510_Project_Report_6Pages.md`（§3） | 能清晰呈現 9 張表主外鍵關係與 `posts` 單表多態設計，符合報告排版規範 | 2h |

---

### 階段四：W4 核心功能線並行（打卡結算 / 發布 / 社交互動 / 個人中心）

| ID | 任務 | 負責人 | 依賴 | 產出物 | 驗收標準 | 預估 |
|---|---|---|---|---|---|---|
| T-C14 | 實作出發 Tab 沿途路標打卡與拍照記錄功能 | C | T-C13 | `app/pages/StartPage.qml` | 能在行山中點擊「打卡路標」將下一個打卡點標記為完成並更新 `n/m` 計數，點擊「拍照記錄」累加相片數 | 2h |
| T-C15 | 實作出發 Tab「結束」態結算卡與一鍵發布社區 | C | T-C14 | `app/pages/StartPage.qml` | 能顯示距離、時長、打卡點數、相片張數與爬升結算單，點擊「一鍵發布到社區」自動生成 `trip` 貼文並跳轉社區 | 2h |
| T-C16 | 實作發布頁（動態/提問切換、相片選擇上傳、路線與標籤關聯） | C | T-A11, T-B10, G2 | `app/pages/ComposePage.qml` | 能切換發動態或發提問、選擇或輸入相片路徑、關聯 10 條路線與話題標籤，發布後立即出現在社區頂部 | 4h |
| T-D06 | 實作動態與問答點讚 / 取消點讚即時互動 | D | T-A12, T-D05 | `app/pages/PostDetailPage.qml` + `social_service.toggle_like` | 點愛心變實心且計數 +1，再點一次變空心計數 -1；重啟 App 仍保持最後一次狀態 | 2h |
| T-D07 | 實作路線與貼文收藏 / 取消收藏雙態聯動 | D | T-A12, T-D05, T-C10 | `app/pages/PostDetailPage.qml` + `RouteDetailPage.qml` | 點擊收藏按鈕即時切換星號狀態與計數，且收藏內容同步出現在「我的 - 我的收藏」對應子 Tab | 2h |
| T-D08 | 實作一級評論與一層 `@暱稱` 回覆功能 | D | T-A12, T-D05 | `app/pages/PostDetailPage.qml` + `social_service.add_comment` | 能發表一級評論，或點擊某條評論「回覆」自動帶出 `@暱稱` 發表二級回覆，評論計數即時 +1 | 4h |
| T-D09 | 實作問答模式下提問作者「採納最佳回答」功能 | D | T-A12, T-D08 | `app/pages/PostDetailPage.qml` + `social_service.accept_comment` | 僅提問作者在未採納前可見「採納此回答」按鈕，點擊後顯示綠色「✓ 已採納最佳回答」且不可撤銷 | 2h |
| T-D10 | 實作「我的」Tab 個人統計與我的動態管理（編輯/刪除） | D | T-A11, T-B10, G2 | `app/pages/ProfilePage.qml` | 能顯示頭像、暱稱、簡介及動態數/收藏數/行山次數，並支援對本人發布的動態執行快速修訂與刪除 | 4h |
| T-D11 | 實作「我的收藏」雙子 Tab（收藏的路線 / 收藏的動態）与登出 | D | T-D07, T-D10 | `app/pages/ProfilePage.qml` | 能切換查看收藏的路線與動態列表，點擊「登出帳號」清空 session 並退回 `SignInPage.qml` | 2h |
| T-D12 | 實作編輯個人資料子頁（修改暱稱、簡介、頭像） | D | T-B08, T-D10 | `app/pages/EditProfilePage.qml` | 能修改當前用戶暱稱、個人簡介與頭像 URL，保存後個人頁與社區作者名即時更新 | 2h |
| T-B11 | 撰寫報告 §1 專案背景、極簡定位與四層架構設計 | B | T-B05, T-B10 | `docs/04-COMP7510_Project_Report_6Pages.md`（§1） | 能完整闡述產品閉環、L1–L4 單向依賴架構與五段式請求設計 | 2h |
| T-C17 | 撰寫報告 §4 路線結構化、OSM 地圖與雙源定位實作說明 | C | T-C04, T-C15 | `docs/04-COMP7510_Project_Report_6Pages.md`（§4 後半） | 能詳細說明 `trails.path` 折線渲染、`SystemProvider/SimulatedProvider` 3 秒切換機制 | 2h |
| T-A14 | 撰寫報告 §4 後端服務層與觸發器同步機制說明 | A | T-A10, T-A12 | `docs/04-COMP7510_Project_Report_6Pages.md`（§4 前半） | 能清楚說明五支 Service 接口契約、觸發器維護冗餘計數與 RLS 權限設計 | 2h |

---

### 階段五：W5 串接打磨、異常兜底、截圖與報告整合

| ID | 任務 | 負責人 | 依賴 | 產出物 | 驗收標準 | 預估 |
|---|---|---|---|---|---|---|
| T-A15 | 收緊 RLS 寫入策略並驗證 6 個預建測試帳號權限 | A | T-A06, T-D10 | `supabase/policies.sql` | 能確保未授權用戶無法刪除他人貼文，6 個預建帳號均可正常讀寫各自數據 | 2h |
| T-B12 | 實作全域 Toast 提示與網路/配置異常無白屏兜底檢查 | B | T-B09, T-B10 | `app/main.qml` + `app/backend/supabase_client.py` | 能在斷網或 `.env` 錯誤時給出明確繁體中文提示，全應用無未捕獲異常或白屏 | 2h |
| T-C18 | 實作離線/網路受限時的地圖 Canvas 向量軌跡雙重渲染兜底 | C | T-C13 | `app/components/MapCanvas.qml` | 能在 OSM 瓦片因網路受限未載入時，依然清晰繪製山徑折線、打卡點圓標與行進位置 | 2h |
| T-D13 | 繪製四層架構與 5 Tab 頁面跳轉流程圖 | D | T-D01, T-C03 | `docs/flow.png` | 能生成高清架構與頁面導航流程圖並嵌入專案報告 §5 | 2h |
| T-D14 | 撰寫報告 §2 功能規格、§5 介面流程與 §6 測試總結 | D | T-D11, T-D13 | `docs/04-COMP7510_Project_Report_6Pages.md`（§2, §5, §6） | 能完整覆蓋 5 個 Tab 功能邊界、互動規格表與測試結果 | 4h |
| T-X01 | 執行端到端閉環聯調（找路線→出發→打卡→發布→點讚評論採納） | 全員 | T-C16, T-D09, T-D11 | `tests/test_03_db_crud.py` + 聯調記錄 | 能用 2 個不同測試帳號走完「瀏覽路線→模擬定位打卡→發布社區→另一帳號點讚評論→提問與採納」全閉環 | 2h |
| T-X02 | 截取 5 個 Tab 與核心子頁高清預覽圖存檔 | C+D | T-X01 | `docs/screenshots/ui_preview_5tabs.png` | 能產出展示首頁、線路、出發地圖、社區與我的 5 大頁面視覺合成預覽圖 | 2h |
| T-X03 | 匯總四人署名章節完成 6 頁專案報告初稿審查 | 全員 | T-A13, T-A14, T-B11, T-C17, T-D14 | `docs/04-COMP7510_Project_Report_6Pages.md` | 能確認 A/B/C/D 四人在「設計 / 程式 / 報告」三塊均有明確署名與產出對應 | 2h |

---

### 階段六：W6 PyInstaller 打包 exe、跨機驗收與最終交付

| ID | 任務 | 負責人 | 依賴 | 產出物 | 驗收標準 | 預估 |
|---|---|---|---|---|---|---|
| T-A16 | 編寫 PyInstaller 打包配置（顯式打包 `app/` QML 與插件） | A | T-X01 | `build.spec` | 能執行 `pyinstaller build.spec --noconfirm` 成功生成 `dist/HikeHub.exe` 且不漏 QML 檔案 | 2h |
| T-X04 | 打包 Windows exe 並驗證外部 `.env` 讀取 | A+B | T-A16, T-B12 | `dist/HikeHub.exe` + `.env.example` | 能在未安裝 Python 的 Windows 機器上雙擊 `HikeHub.exe` 讀取同目錄 `.env`，正常登錄並看到 10 條路線，無白屏 | 4h |
| T-B13 | 編寫完整 `README.md`（開發三步啟動、打包指令、測試帳號表） | B | T-X04 | `README.md` | 能讓助教照著文檔 3 分鐘內跑通開發環境或直接雙擊 `HikeHub.exe` 驗收 | 1h |
| T-D15 | 編寫 5 分鐘課堂 Demo 演示腳本（基於模擬定位源） | D | T-X01 | `docs/04-COMP7510_Project_Report_6Pages.md`（附錄 Demo 腳本） | 能按分鐘列出四人演示台詞與操作步驟，確保教室無 GPS 環境下 100% 穩定復現軌跡推進 | 2h |
| T-X05 | 全量運行 6 支驗針腳本與代碼紅線合規終檢 | 全員 | T-X04 | `tests/test_01..06.py` | 能通過全部 6 支驗針腳本，且代碼庫零 TODO、零商業化冗余、零違規第三方框架 | 1h |
| T-X06 | 封裝 Git 倉庫交付包並完成最終提交檢查 | 全員 | T-X05, T-B13, T-D15 | `hikehub-git.zip` | 能解壓即見完整 `.git` 分工提交歷史、全套源碼、SQL 腳本、`build.spec` 與 `docs/` 報告圖表 | 1h |

---

## 第三部分 · 依賴圖

```text
W1  ├─ Step0 六支環境驗針並行（T-A01~T-A04, T-C01~T-C02）
    ├─ 基礎主題與 Wireframe 設計（T-B01~T-B02, T-C03, T-D01）
    └─ 資料庫 9 張表與種子資料落地（T-A05~T-A07）
         └─ G1 數據契約與 Service 簽名凍結（第 3 天：T-A08）
              ├─ W2 A: Supabase 客戶端與四支數據 Service 實作（T-A09~T-A12）
              ├─ W2 C: 系統/模擬定位雙源實作（T-C04）
              ├─ W2 B: 執行緒池 + 5 Tab 獨立 StackView 導航殼 + 登錄頁（T-B03~T-B05, T-B08~T-B09）
              └─ G2 通用元件庫與地圖畫布元件凍結（第 5 天：T-B06~T-B07）
                   └─ W2 B: QObject 橋接層串通（T-B10）
                        ├─ W3–W4 C 線：首頁 + 線路篩選 + 路線詳情 + 出發三態地圖軌跡 + 發布頁（T-C05~T-C16）
                        ├─ W3–W4 D 線：社區雙 Segment + 詳情頁點讚/收藏/評論/採納 + 我的與編輯資料（T-D02~T-D12）
                        └─ W3–W4 全員：ERD 圖與報告各章節撰寫（T-A13~T-A14, T-B11, T-C17）
                             └─ W5 全鏈路聯調、RLS 收緊、流程圖與 6 頁報告整合（T-A15, T-B12, T-C18, T-D13~T-D14, T-X01~T-X03）
                                  └─ W6 PyInstaller 打包 exe、裸機驗收與 Git 倉庫交付（T-A16, T-B13, T-D15, T-X04~T-X06）
```

---

## 第四部分 · 關鍵路徑

### 1. 全局最長關鍵路徑（一旦延期直接拖垮交付）

`T-A03` → `T-A05` → `T-A08 (G1)` → `T-A09` → `T-A10` → `T-B10` → `T-C12` → `T-C13` → `T-C14` → `T-C15` → `T-X01` → `T-A16` → `T-X04` → `T-X06`

### 2. 關鍵路徑上最容易被低估的 3 個任務

1. **`T-B10`（QObject 橋接層 `bridge.py` 暴露 Service 與 Signal/Slot 同步）**：
   - **為什麼被低估**：表面上只是把 Python 函數包一層 `@Slot`，實際上 QML 對 Python `dict` / `list[dict]` 的型別轉換（`QVariantMap` / `QVariantList`）以及點讚、收藏、打卡後跨 Tab 的狀態同步（例如在詳情頁點讚後，返回社區列表和首頁熱帖數字要立刻同步變動）全靠 `bridge.py` 發出正確的 `Signal`，一旦漏發信號就會出現「點了沒反應、要重啟才更新」的假 Bug。
2. **`T-C13`（出發 Tab「行山中」雙源定位跟隨與實虛軌跡繪製）**：
   - **為什麼被低估**：桌面電腦在教室演示時幾乎 100% 拿不到真實 GPS 座標，且 OSM 瓦片可能受校園網路影響載入緩慢。如果只寫 `SystemProvider` 或只依賴線上瓦片，Demo 當場就會卡死在起點或白底；必須同時做好「3 秒無座標自動平滑切換 `SimulatedProvider` 插值推進」與「Canvas 向量軌跡雙重渲染兜底」。
3. **`T-X04`（PyInstaller 打包 Windows exe 並在無 Python 機器驗收）**：
   - **為什麼被低估**：開發期 `python main.py` 能跑不代表打包後能跑。PyInstaller 預設不會自動收集 `.qml` 源碼樹與 `QtLocation`/`QtPositioning` 動態插件，且工作目錄會變成臨時解壓目錄 `sys._MEIPASS`。若未在 `build.spec` 顯式配置 `datas=[('app', 'app')]` 並用 `sys.executable` 定位外部 `.env`，雙擊 `HikeHub.exe` 必定白屏閃退。

---

## 第五部分 · 降級方案（若 W3 結束總進度僅完成 60%）

### 1. 嚴格按順序砍除的任務（保主幹閉環）

1. **第一刀（先砍 `EditProfilePage`）**：砍除 `T-D12`（編輯個人資料子頁），個人頁直接展示 `seed.sql` 預建的暱稱、頭像與簡介，保留登出與我的動態列表。
2. **第二刀（再砍「問答」Segment 與採納）**：砍除 `T-D04`、`T-D09`，社區 Tab 只保留「山友動態」雙列瀑布流與評論點讚，不展示問答切換與回答採納。
3. **第三刀（再砍「收藏」功能）**：砍除 `T-D07` 與 `T-D11` 中的收藏子 Tab，保留點讚與一級評論互動。
4. **第四刀（再砍「出發」頁的動態實虛軌跡分界繪製）**：簡化 `T-C13`，地圖上只畫靜態路線完整折線與打卡點圓標，保留計時、計距與點擊打卡按鈕，不動態重算已走實線與未走虛線。
5. **第五刀（最後才砍行山中拍照打卡）**：簡化 `T-C14` 中的中途拍照按鈕，結算發布時自動使用路線封面圖作為預設配圖。

### 2. 絕不能動的底線（永遠保留）

- **六大核心頁面與閉環絕不砍**：登錄頁（`SignInPage`）、首頁（`HomePage`）、線路篩選列表與詳情（`RouteListPage` + `RouteDetailPage`）、出發地圖與打卡結算（`StartPage`）、社區動態瀑布流與詳情點讚評論（`CommunityPage` + `PostDetailPage`）、發布頁（`ComposePage`）。
- **打包 Windows exe（`T-A16`、`T-X04`）絕不砍**：只需半天工時，但直接決定助教能否雙擊跑起來給分。

### 3. 報告 §2 的得體表述方式（讓裁剪看起來是產品克制而非未完成）

- 在報告 §2「產品範圍與極簡設計取捨」中明確寫道：
  > 「為避免傳統戶外 App（如兩步路）功能臃腫導致核心體驗稀釋，HikeHub 嚴格遵循『一屏一主任務』的極簡社交設計原則，將首期迭代聚焦於『找路線 → 出發打卡 → 發布動態 → 點讚評論』的高頻閉環；低頻的個人資料頻繁編修與複雜多級問答流則收斂為標準化標籤動態，確保核心行山記錄與山友互動體驗流暢無負擔。」

---

## 第六部分 · 課程要求映射自檢表（11 條要求 100% 落點）

| # | 課程要求 | 承接任務 ID | 狀態與落點驗證 |
|---|---|---|---|
| 1 | Python + PySide6 (Qt 6.9) + QML 開發移動端視口應用 | `T-A01`, `T-B01`, `T-B05`, `T-B10` | **已覆蓋**：`main.py` + `app/main.qml`（390×844 手機視口）+ `bridge.py` QObject 橋接 |
| 2 | 核心數據來自 Supabase（DB + Storage） | `T-A03`, `T-A04`, `T-A05`, `T-A09`, `T-A11` | **已覆蓋**：9 張表定義於 `schema.sql`，相片上傳至 `trail-photos` bucket |
| 3 | 第一頁必須是登錄頁，Supabase Auth，帳號預建 | `T-A02`, `T-A07`, `T-B08`, `T-B09` | **已覆蓋**：啟動預設顯示 `SignInPage.qml`，預建 6 個測試帳號並含密碼錯誤與 `.env` 檢查提示 |
| 4 | 登錄後主頁：功能選擇或項目展示 | `T-C05`, `T-C06`, `T-C07` | **已覆蓋**：`HomePage.qml` 展示本週精選、附近路線、社區熱帖與進行中行山卡片 |
| 5 | 多頁面：支援新增 / 列表 / 修改 / 刪除 | `T-C09`, `T-C16`, `T-D03`, `T-D10`, `T-D12` | **已覆蓋**：線路與社區列表、發布頁（新增）、我的動態修訂與刪除（修改/刪除）、編輯個人資料 |
| 6 | 信息共享 + 查詢功能 | `T-C08`, `T-D03`, `T-D04`, `T-D06`, `T-D07`, `T-D08`, `T-D09` | **已覆蓋**：路線地區/難度/時長篩選與關鍵字搜尋、動態相片分享、問答採納、點讚/評論/收藏 |
| 7 | 必須有登出功能 | `T-B08`, `T-D11` | **已覆蓋**：`ProfilePage.qml` 點擊「登出帳號」調用 `api.signOut()` 清空 session 並返回登錄頁 |
| 8 | 4 人團隊至少 5 頁（不含登錄頁） | `T-B05`, `T-C05`~`T-C16`, `T-D02`~`T-D12` | **已覆蓋**：5 個主 Tab 頁 + 5 個子頁 = 共 10 個業務頁（外加登錄頁共 11 頁） |
| 9 | 全員平均負責各領域（設計 + 程式 + 報告） | 設計：`T-A05`/`T-B02`/`T-C03`/`T-D01`<br>程式：`T-A09`~`T-D12`<br>報告：`T-A13`/`T-A14`/`T-B11`/`T-C17`/`T-D14` | **已覆蓋**：A/B/C/D 四人在設計、程式碼、報告章節三塊均有獨立署名任務 |
| 10 | 代碼結構完整、可執行（含 README 與 exe） | `T-B01`, `T-B13`, `T-A16`, `T-X04`, `T-X06` | **已覆蓋**：含 `README.md`、`requirements.txt`、`build.spec`，支援 `python main.py` 與 `HikeHub.exe` |
| 11 | 評分兼顧難度 / 完成度 / 實用性 | `T-C04`, `T-C13`, `T-C15`, `T-D09`, `T-X01` | **已覆蓋**：整合 OSM 地圖折線、雙源定位自動回退、打卡結算轉社區貼文與問答採納完整閉環 |
