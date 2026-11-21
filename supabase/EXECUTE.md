# 行山腳 HikeHub · 雲端資料庫建置與資料匯入執行說明

本說明對應 v5 設計：在 **Supabase 雲端新建一個獨立 HikeHub 專案**，依序執行三個 SQL 檔，
由你在 Supabase 雲端 SQL Editor 手動貼上執行（我方負責產出與校驗 SQL，不經手你的帳號）。

---

## 步驟 0 ｜ 新建獨立 Supabase 專案（雲端控制台）

1. 登入 https://supabase.com → New Project。
2. 專案名稱：`hikehub`（或任意可辨識名稱），**Region 選離你最近者**（如 `ap-southeast-1` 新加坡 / `eu-central-1`）。
   - 此專案與舊的 `freshfridge_hk`（ref: cjqmeypqkxvnyojpyexw）完全分離，互不影響。
3. 建立完成後，到 **Project Settings → API**：
   - 複製 `Project URL`（格式 `https://<project-ref>.supabase.co`）
   - 複製 `anon` / `public` key（JWT，前端公開安全，靠 RLS 保護）
4. 開啟本機 `hikehub/.env.example`：
   - 把 `SUPABASE_URL=https://<NEW_HUBEHUB_PROJECT_REF>.supabase.co` 改成你的 URL
   - 把 `SUPABASE_ANON_KEY=<PASTE_NEW_HUBEHUB_PROJECT_ANON_KEY>` 改成你的 anon key
   - 執行 `cp .env.example .env`（SERVICE_ROLE_KEY 永不進 repo）

---

## 步驟 0 ｜ 建立 6 個可登入測試帳號（create_auth_users.ps1）★ 不可省略

> **重要（新版 Supabase 行為）**：GoTrue 已不認可用 SQL 直接 `INSERT INTO auth.users` 建立的帳號
> （實測：即便補齊 `instance_id`、`auth.identities`、`$2a$10$` bcrypt，登入仍回 `invalid_credentials`，
> 且 Auth Admin 列表顯示 0 個用戶）。**必須透過 Auth Admin API 讓 GoTrue 自己建立。**

- 於專案根目錄執行（PowerShell）：
  ```powershell
  $env:SUPABASE_ACCESS_TOKEN = 'sbp_你的帳戶級Token'
  powershell -File supabase/create_auth_users.ps1
  ```
- Token 取得：Supabase 右上角頭像 → **Account Settings → Access Tokens → Generate new token**；**用完請 Revoke**。
- 腳本會：以**固定 UUID** 建立 6 個 `hikehub.hk` 帳號（密碼 `HikeHub2026!`、email 已確認），
  並逐一實測登入 + 校驗 UUID 與種子資料一致。可重複執行。
- 亦可在 Supabase 控制台 **Authentication → Users → Add user** 手動建立，但需指定相同 UUID 才對得上 profile。

## 步驟 1 ｜ 建立 9 張表結構（schema.sql）

- 雲端 SQL Editor → New query → 貼上 `supabase/schema.sql` 全文 → Run。
- 內容：9 張表（profiles / trails / trail_segments / checkpoints / posts / post_photos /
  comments / likes / favorites）、索引、外鍵（ON DELETE CASCADE）、以及維護計數的 Trigger。
- 預期：無報錯；Tables 頁面出現 9 張表。

## 步驟 2 ｜ 啟用 RLS 與 Storage（policies.sql）

- 貼上 `supabase/policies.sql` 全文 → Run。
- 內容：9 張表啟用 RLS（公開讀取 + 歸屬寫入）、建立 `trail-photos` public bucket 及讀取/上傳政策。
- 預期：無報錯；Storage 頁面出現 `trail-photos` bucket（public）。

## 步驟 3 ｜ 匯入真實種子資料（seed.sql）

- 貼上 `supabase/seed.sql` 全文 → Run。
- 內容（**不含 auth schema**，帳號已在步驟 0 建立）：
  - 6 個 `public.profiles`（固定 UUID，與步驟 0 的 Auth 帳號一一對應）。
  - 10 條香港經典路線（含 `path` 折線經緯度）、25 個路段、22 個打卡點。
  - 社群種子：動態 / 問答 / 行山記錄貼文、留言（含一則「已採納」回答）、按讚、收藏。
  - 計數欄位（like_count / comment_count / favorite_count）**不預填**，由 schema 的 Trigger 在
    likes/comments/favorites 寫入時自動累加，避免與手填值重複計算。
- 預期：無報錯；Tables 頁面各表有資料。

## 步驟 4 ｜ 驗證（verify_db.sql）

- 貼上 `tests/verify_db.sql` 全文 → Run，逐段確認：
  - 各表行數：profiles 6 / trails 10 / trail_segments 25 / checkpoints 22 / posts 6 /
    post_photos 8 / comments 6 / likes 12 / favorites 8（實測值）。
  - 計數一致性（段落 3–6）：**應全部回傳 0 行**（表示 stored = actual）。
  - RLS（段落 7）：9 張表 `rls_enabled` 皆為 `t`。
  - 外鍵孤立（段落 8）：全部 0 行。

## 步驟 5 ｜ SQL 補強 v5.1（既有專案請執行一次）

> 若專案是 **v5 之前**建立的，請在 Supabase SQL Editor 貼上 `supabase/all_in_one.sql`
> 全文執行一次；全新專案直接執行本檔即已包含所有補強。
> 本機沒有 Management API / 資料庫直連憑據，因此這一步需由你在 SQL Editor 執行
> （一次貼上、一次 Run，約數秒）。

補強項目（**不改动既有 9 表欄位、不更動固定 UUID 種子資料**）：

| # | 檔案 | 補強內容 |
|---|---|---|
| 1 | `schema.sql` | `uq_post_photos_post_path` 唯一索引：`seed.sql` / `all_in_one.sql` 重跑不再產生重複相片列 |
| 2 | `schema.sql` | `uq_one_accepted_answer_per_question` 部分唯一索引：每題最多一個「已採納」回答，由 DB 強制 |
| 3 | `schema.sql` | `trg_block_*_fk_update` 三個 Trigger：禁止 UPDATE 搬移 likes / comments / favorites 的關聯欄位，避免只處理 INSERT/DELETE 的計數 Trigger 無法追蹤而永久漂移 |
| 4 | `schema.sql` | `trg_cleanup_post_favorites`：刪除貼文時以 SECURITY DEFINER 清除指向它的收藏，避免 `favorites.target_id`（TEXT、無外鍵）留下孤立列 |
| 5 | `policies.sql` | `post_photos` 補 UPDATE / DELETE，且新增/修改/刪除一律校驗貼文歸屬 |
| 6 | `policies.sql` | `comments` 採納限定「提問作者 + question 貼文」；搭配唯一索引強制「每題一次」 |
| 7 | `policies.sql` | `favorites` 的 WITH CHECK 校驗 `target_id` 指向真實存在的路線 / 貼文 |
| 8 | `tests/verify_db.sql` | 四段計數一致性改 `LEFT JOIN + COALESCE`，0 計數貼文不再被漏檢；補 `orphan_favorites` / `orphan_post_photos`；新增段落 9 檢查補強是否生效 |

**可重跑性**：所有 `CREATE` 均為 `IF NOT EXISTS`、Trigger/Policy 先 `DROP IF EXISTS`、
種子貼文用 `ON CONFLICT (id) DO NOTHING`、相片用
`ON CONFLICT (post_id, storage_path) DO NOTHING`。重跑 `all_in_one.sql` 不會產生重複資料。

**驗證**：執行後看 `verify_db.sql` 段落 9，應回傳 2 個索引名稱與 4 個 Trigger 名稱；
段落 3–6 應全部 0 行，段落 8 的 `bad` 全部為 0。

**與應用程式的關係**：App 的核心寫入（點讚 / 評論 / 收藏 / 採納 / 發帖 / 改資料 / 相片表）
在補強前已實測可正常運作；補強是防止長期資料漂移與越權寫入的防線，不影響既有功能，
也不會改變 `dist/HikeHub.exe` 的操作方式。

---

## 常見問題

**Q1：登入失敗 / `Invalid login credentials`？**
- 九成是帳號**不是**用 Auth Admin API 建立的（例如曾用 SQL 直接 `INSERT INTO auth.users`）。
  新版 GoTrue 完全不認這種列。解法：於 SQL Editor 執行
  `DELETE FROM auth.users WHERE email LIKE '%@hikehub.hk';`（會 CASCADE 清掉 identities），
  再重跑步驟 0 的 `create_auth_users.ps1`。
- 檢查 `verify_db.sql` 段落 2：6 筆 `confirmed = t`、`has_pw = t`、`profile_linked = t`，
  並確認 `instance_id` 非 NULL（應為 `00000000-0000-0000-0000-000000000000`）。
- profiles 的 UUID 固定為 `1111...101~106`，與 Auth 帳號必須一致。

**Q2：`null value in column "provider_id" of relation "identities"`？**
- 新版 `auth.identities` 多了 NOT NULL 的 `provider_id`（且 `UNIQUE(provider_id, provider)`）。
  本專案已改由 Auth Admin API 建號，不會再遇到；勿再手工 INSERT identities。

**Q3：地圖/圖片讀不到？**
- 確認 `trail-photos` bucket 為 public（policies.sql 已建立）。貼文圖目前使用 Unsplash 公開連結，
  不受 bucket 限制；若自行上傳圖片請走 `trail-photos` bucket。

**Q4：執行順序可否調換？**
- 不可以。`create_auth_users.ps1 → schema → policies → seed`：表必先存在，seed 依賴表與 Trigger。
- 重跑任一 SQL 檔案皆安全（已使用 `IF NOT EXISTS` / `ON CONFLICT DO NOTHING` / `DROP POLICY IF EXISTS`）。
