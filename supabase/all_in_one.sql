-- HikeHub ONE-CLICK SQL : paste ALL into Supabase SQL Editor and click Run
-- PREREQUISITE: run supabase/create_auth_users.ps1 FIRST (Auth Admin API).
-- Order: schema -> policies -> seed -> verify. Safe to re-run (v5.1).
-- v5.1: counter-drift guards, Q&A acceptance constraints, RLS hardening,
--       idempotent post_photos seeding, and 0-count-aware verification.

-- ===== 1/4 schema.sql =====
-- ============================================================================
-- 行山腳 HikeHub · Supabase Database Schema (Frozen v5 - Gate 1)
-- Project: COMP 7510 Group Project
-- Author: Member A (Data Architect)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. profiles (1:1 linked with auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE,
    nickname TEXT NOT NULL,
    bio TEXT DEFAULT '熱愛香港山野，週末必出發行山！',
    avatar_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. trails (10 classic HK hiking routes, path stores [[lat, lng], ...] JSONB)
CREATE TABLE IF NOT EXISTS public.trails (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    region TEXT NOT NULL,              -- 港島 / 西貢 / 大嶼山 / 新界東北 / 九龍及新界中
    difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
    distance_km NUMERIC(5,2) NOT NULL,
    ascent_m INTEGER NOT NULL,
    duration_min INTEGER NOT NULL,
    cover_url TEXT NOT NULL,
    description TEXT NOT NULL,
    path JSONB NOT NULL DEFAULT '[]'::jsonb,
    favorite_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. trail_segments (Segments with supply & retreat markers)
CREATE TABLE IF NOT EXISTS public.trail_segments (
    id TEXT PRIMARY KEY,
    trail_id TEXT NOT NULL REFERENCES public.trails(id) ON DELETE CASCADE,
    seq INTEGER NOT NULL,
    name TEXT NOT NULL,
    distance_km NUMERIC(4,2) NOT NULL,
    ascent_m INTEGER NOT NULL DEFAULT 0,
    has_supply BOOLEAN NOT NULL DEFAULT FALSE,
    has_retreat BOOLEAN NOT NULL DEFAULT FALSE,
    note TEXT DEFAULT ''
);

-- 4. checkpoints (Map coordinates for check-ins along the trail)
CREATE TABLE IF NOT EXISTS public.checkpoints (
    id TEXT PRIMARY KEY,
    trail_id TEXT NOT NULL REFERENCES public.trails(id) ON DELETE CASCADE,
    segment_id TEXT REFERENCES public.trail_segments(id) ON DELETE SET NULL,
    seq INTEGER NOT NULL,
    name TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    note TEXT DEFAULT ''
);

-- 5. posts (Unified table for moment | question | trip)
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('moment', 'question', 'trip')),
    title TEXT DEFAULT '',
    body TEXT NOT NULL,
    trail_id TEXT REFERENCES public.trails(id) ON DELETE SET NULL,
    meta JSONB NOT NULL DEFAULT '{}'::jsonb,
    like_count INTEGER NOT NULL DEFAULT 0,
    comment_count INTEGER NOT NULL DEFAULT 0,
    favorite_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. post_photos (Storage paths in trail-photos bucket)
CREATE TABLE IF NOT EXISTS public.post_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,
    seq INTEGER NOT NULL DEFAULT 1
);

-- 7. comments (1-level comments + 1-layer reply via parent_id + QA acceptance)
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES public.comments(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    is_accepted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. likes (Composite PK on post_id + user_id)
CREATE TABLE IF NOT EXISTS public.likes (
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- 9. favorites (Polymorphic target_type IN ('trail', 'post'))
CREATE TABLE IF NOT EXISTS public.favorites (
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('trail', 'post')),
    target_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, target_type, target_id)
);

-- Indexes for high-frequency queries
CREATE INDEX IF NOT EXISTS idx_trails_region ON public.trails(region);
CREATE INDEX IF NOT EXISTS idx_trails_difficulty ON public.trails(difficulty);
CREATE INDEX IF NOT EXISTS idx_trail_segments_trail ON public.trail_segments(trail_id, seq);
CREATE INDEX IF NOT EXISTS idx_checkpoints_trail ON public.checkpoints(trail_id, seq);
CREATE INDEX IF NOT EXISTS idx_posts_type_created ON public.posts(type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_trail ON public.posts(trail_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_author ON public.posts(author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_comments_post ON public.comments(post_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON public.favorites(user_id, target_type);

-- v5.1 補強：相片列不重複（讓 seed.sql / all_in_one.sql 可安全重跑）
CREATE UNIQUE INDEX IF NOT EXISTS uq_post_photos_post_path
    ON public.post_photos(post_id, storage_path);
-- v5.1 補強：每題最多一個「已採納」回答，由資料庫強制而非只靠應用層
CREATE UNIQUE INDEX IF NOT EXISTS uq_one_accepted_answer_per_question
    ON public.comments(post_id) WHERE is_accepted;

-- ============================================================================
-- Triggers to automatically maintain redundant counters on posts & trails
-- ============================================================================

CREATE OR REPLACE FUNCTION public.fn_sync_post_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET like_count = GREATEST(0, like_count - 1) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_post_like_count ON public.likes;
CREATE TRIGGER trg_sync_post_like_count
AFTER INSERT OR DELETE ON public.likes
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_post_like_count();

CREATE OR REPLACE FUNCTION public.fn_sync_post_comment_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts SET comment_count = GREATEST(0, comment_count - 1) WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_post_comment_count ON public.comments;
CREATE TRIGGER trg_sync_post_comment_count
AFTER INSERT OR DELETE ON public.comments
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_post_comment_count();

CREATE OR REPLACE FUNCTION public.fn_sync_favorite_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.target_type = 'post' THEN
            UPDATE public.posts SET favorite_count = favorite_count + 1 WHERE id::text = NEW.target_id;
        ELSIF NEW.target_type = 'trail' THEN
            UPDATE public.trails SET favorite_count = favorite_count + 1 WHERE id = NEW.target_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.target_type = 'post' THEN
            UPDATE public.posts SET favorite_count = GREATEST(0, favorite_count - 1) WHERE id::text = OLD.target_id;
        ELSIF OLD.target_type = 'trail' THEN
            UPDATE public.trails SET favorite_count = GREATEST(0, favorite_count - 1) WHERE id = OLD.target_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_favorite_count ON public.favorites;
CREATE TRIGGER trg_sync_favorite_count
AFTER INSERT OR DELETE ON public.favorites
FOR EACH ROW EXECUTE FUNCTION public.fn_sync_favorite_count();

-- ============================================================================
-- v5.1 補強：防止計數漂移、清理孤兒收藏（可重跑）
-- ============================================================================

-- (1) 計數 Trigger 只處理 INSERT / DELETE。若允許 UPDATE 搬移 post_id /
--     target_id，舊貼文不會減、新貼文不會加，計數會永久漂移。
--     因此禁止更改這三張表的計數關聯欄位：先 DELETE 再 INSERT 即可。
CREATE OR REPLACE FUNCTION public.fn_block_counter_fk_update()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION '不允許更改 % 的計數關聯欄位，請先刪除再新增', TG_TABLE_NAME
        USING ERRCODE = '23514';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_block_likes_fk_update ON public.likes;
CREATE TRIGGER trg_block_likes_fk_update
BEFORE UPDATE OF post_id, user_id ON public.likes
FOR EACH ROW
WHEN (NEW.post_id IS DISTINCT FROM OLD.post_id OR NEW.user_id IS DISTINCT FROM OLD.user_id)
EXECUTE FUNCTION public.fn_block_counter_fk_update();

DROP TRIGGER IF EXISTS trg_block_comments_fk_update ON public.comments;
CREATE TRIGGER trg_block_comments_fk_update
BEFORE UPDATE OF post_id, author_id ON public.comments
FOR EACH ROW
WHEN (NEW.post_id IS DISTINCT FROM OLD.post_id OR NEW.author_id IS DISTINCT FROM OLD.author_id)
EXECUTE FUNCTION public.fn_block_counter_fk_update();

DROP TRIGGER IF EXISTS trg_block_favorites_fk_update ON public.favorites;
CREATE TRIGGER trg_block_favorites_fk_update
BEFORE UPDATE OF user_id, target_type, target_id ON public.favorites
FOR EACH ROW
WHEN (NEW.user_id IS DISTINCT FROM OLD.user_id
      OR NEW.target_type IS DISTINCT FROM OLD.target_type
      OR NEW.target_id IS DISTINCT FROM OLD.target_id)
EXECUTE FUNCTION public.fn_block_counter_fk_update();

-- (2) favorites.target_id 是 TEXT（無外鍵）。刪除貼文時以 SECURITY DEFINER
--     清掉指向它的收藏，避免留下孤立列。這個 DELETE 會再觸發計數 Trigger，
--     但 posts 列已刪除，不會造成任何計數變動。
CREATE OR REPLACE FUNCTION public.fn_cleanup_post_favorites()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM public.favorites
    WHERE target_type = 'post' AND target_id = OLD.id::text;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_cleanup_post_favorites ON public.posts;
CREATE TRIGGER trg_cleanup_post_favorites
AFTER DELETE ON public.posts
FOR EACH ROW EXECUTE FUNCTION public.fn_cleanup_post_favorites();

-- ===== 2/4 policies.sql =====
-- ============================================================================
-- 行山腳 HikeHub · Row Level Security (RLS) Policies
-- Project: COMP 7510 Group Project
-- Author: Member A (Data Architect)
-- ============================================================================
--
-- 設計原則（v5）：開發期「公開讀 + 歸屬寫」。
--   - 所有表對已登入 / 未登入用戶均可 SELECT（社群動態本就公開）。
--   - 寫入（INSERT/UPDATE/DELETE）一律要求 auth.uid() 歸屬校驗，不允許匿名亂寫。
--   - seed.sql 以 SQL Editor（owner 權限）執行，會繞過 RLS，不受本政策影響。
-- 重跑安全：每條政策先 DROP POLICY IF EXISTS，可重複執行。

-- 1. 啟用 RLS
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trails          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trail_segments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkpoints     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_photos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites       ENABLE ROW LEVEL SECURITY;

-- 2. 公開讀取（所有表）
DROP POLICY IF EXISTS "Public read profiles"       ON public.profiles;
DROP POLICY IF EXISTS "Public read trails"         ON public.trails;
DROP POLICY IF EXISTS "Public read trail_segments" ON public.trail_segments;
DROP POLICY IF EXISTS "Public read checkpoints"    ON public.checkpoints;
DROP POLICY IF EXISTS "Public read posts"          ON public.posts;
DROP POLICY IF EXISTS "Public read post_photos"    ON public.post_photos;
DROP POLICY IF EXISTS "Public read comments"       ON public.comments;
DROP POLICY IF EXISTS "Public read likes"          ON public.likes;
DROP POLICY IF EXISTS "Public read favorites"      ON public.favorites;

CREATE POLICY "Public read profiles"       ON public.profiles       FOR SELECT USING (true);
CREATE POLICY "Public read trails"         ON public.trails         FOR SELECT USING (true);
CREATE POLICY "Public read trail_segments" ON public.trail_segments FOR SELECT USING (true);
CREATE POLICY "Public read checkpoints"    ON public.checkpoints    FOR SELECT USING (true);
CREATE POLICY "Public read posts"          ON public.posts          FOR SELECT USING (true);
CREATE POLICY "Public read post_photos"    ON public.post_photos    FOR SELECT USING (true);
CREATE POLICY "Public read comments"       ON public.comments       FOR SELECT USING (true);
CREATE POLICY "Public read likes"          ON public.likes          FOR SELECT USING (true);
CREATE POLICY "Public read favorites"      ON public.favorites      FOR SELECT USING (true);

-- 3. 歸屬寫入

-- profiles：只能管理自己的資料
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- posts：作者管理自己的貼文
DROP POLICY IF EXISTS "Users can create posts"     ON public.posts;
DROP POLICY IF EXISTS "Authors can update own posts" ON public.posts;
DROP POLICY IF EXISTS "Authors can delete own posts" ON public.posts;
CREATE POLICY "Users can create posts"      ON public.posts FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors can update own posts" ON public.posts FOR UPDATE USING (auth.uid() = author_id);
CREATE POLICY "Authors can delete own posts" ON public.posts FOR DELETE USING (auth.uid() = author_id);

-- post_photos：僅貼文作者可新增 / 修改 / 刪除相片列（v5.1 補強）
DROP POLICY IF EXISTS "Authenticated users can insert post photos" ON public.post_photos;
DROP POLICY IF EXISTS "Authors can insert post photos" ON public.post_photos;
DROP POLICY IF EXISTS "Authors can update own post photos" ON public.post_photos;
DROP POLICY IF EXISTS "Authors can delete own post photos" ON public.post_photos;
CREATE POLICY "Authors can insert post photos" ON public.post_photos
  FOR INSERT WITH CHECK (
    auth.role() = 'authenticated'
    AND EXISTS (
      SELECT 1 FROM public.posts p
      WHERE p.id = post_id AND p.author_id = auth.uid()
    )
  );
CREATE POLICY "Authors can update own post photos" ON public.post_photos
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND p.author_id = auth.uid())
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND p.author_id = auth.uid())
  );
CREATE POLICY "Authors can delete own post photos" ON public.post_photos
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.posts p WHERE p.id = post_id AND p.author_id = auth.uid())
  );

-- comments：作者管理自己的留言；貼文作者可更新（用於「採納」回答）
DROP POLICY IF EXISTS "Users can create comments"        ON public.comments;
DROP POLICY IF EXISTS "Authors can update comments"      ON public.comments;
DROP POLICY IF EXISTS "Authors can delete comments"      ON public.comments;
CREATE POLICY "Users can create comments" ON public.comments
  FOR INSERT WITH CHECK (auth.uid() = author_id);
CREATE POLICY "Authors can update comments" ON public.comments
  FOR UPDATE USING (
    auth.uid() = author_id
    OR auth.uid() = (SELECT author_id FROM public.posts p WHERE p.id = post_id)
  ) WITH CHECK (
    -- 標為「已採納」僅限提問作者 + question 貼文；「每題一次」另由
    -- schema.sql 的 uq_one_accepted_answer_per_question 部分唯一索引強制。
    is_accepted = false
    OR (
      auth.uid() = (SELECT author_id FROM public.posts p WHERE p.id = post_id)
      AND (SELECT p.type FROM public.posts p WHERE p.id = post_id) = 'question'
    )
  );
CREATE POLICY "Authors can delete comments" ON public.comments
  FOR DELETE USING (
    auth.uid() = author_id
    OR auth.uid() = (SELECT author_id FROM public.posts p WHERE p.id = post_id)
  );

-- likes：只能操作自己的按讚
DROP POLICY IF EXISTS "Users can manage own likes" ON public.likes;
CREATE POLICY "Users can manage own likes"
  ON public.likes FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- favorites：只能操作自己的收藏，且 target_id 必須指向真實存在的路線 / 貼文
DROP POLICY IF EXISTS "Users can manage own favorites" ON public.favorites;
CREATE POLICY "Users can manage own favorites"
  ON public.favorites FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND (
      (target_type = 'trail' AND EXISTS (
        SELECT 1 FROM public.trails t WHERE t.id = target_id
      ))
      OR (target_type = 'post' AND EXISTS (
        SELECT 1 FROM public.posts p WHERE p.id::text = target_id
      ))
    )
  );

-- 4. Storage bucket 'trail-photos'
INSERT INTO storage.buckets (id, name, public)
VALUES ('trail-photos', 'trail-photos', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Public read trail-photos"     ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload trail-photos" ON storage.objects;
CREATE POLICY "Public read trail-photos" ON storage.objects
  FOR SELECT USING (bucket_id = 'trail-photos');
CREATE POLICY "Authenticated upload trail-photos" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'trail-photos' AND auth.role() = 'authenticated');

-- ===== 3/4 seed.sql =====
-- ============================================================================
-- 行山腳 HikeHub · Seed Data (6 Pre-built Accounts, 10 HK Trails, Community)
-- Project: COMP 7510 Group Project
-- Author: Member A (Data Architect)
-- ============================================================================
--
-- 執行順序：create_auth_users.ps1 → schema.sql → policies.sql → seed.sql（本檔）
-- 注意：
--   1. 計數欄位（posts.like_count / comment_count / favorite_count、trails.favorite_count）
--      不再於此手填，改由 schema.sql 的 Trigger 在 likes/comments/favorites 寫入時自動累加，
--      避免與手填值重複計算導致數字翻倍。
--   2. 6 個測試帳號的 Auth 身份（auth.users / auth.identities）**不可**用 SQL 手工 INSERT：
--      新版 Supabase 的 GoTrue 不認可直接寫入的列（即便補齊 instance_id、identity、
--      $2a$10$ bcrypt 仍回報 invalid_credentials）。必須透過 Auth Admin API 建立，
--      詳見 supabase/create_auth_users.ps1。本檔只負責 public.profiles 及其後的業務資料。
--   3. 固定 UUID 1111...101~106 由 create_auth_users.ps1 指定，與下方 profiles / 貼文作者一致。
--      密碼統一為 HikeHub2026!，email 已確認，可直接登入。

-- 0. Auth 帳號：請先執行 supabase/create_auth_users.ps1（Auth Admin API），此處不再寫入 auth schema

-- 1. Pre-built User Profiles (Password for all 6 Auth accounts: HikeHub2026!)
INSERT INTO public.profiles (id, email, nickname, bio, avatar_url, created_at) VALUES ('11111111-1111-4111-8111-111111111101', 'ahon@hikehub.hk', '阿瀚 · 山野行者', '行遍麥理浩徑全段，專攻西貢與大嶼山長線，最愛日出雲海。', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', '2026-10-01T08:30:00Z') ON CONFLICT (id) DO UPDATE SET nickname = EXCLUDED.nickname, bio = EXCLUDED.bio, avatar_url = EXCLUDED.avatar_url;
INSERT INTO public.profiles (id, email, nickname, bio, avatar_url, created_at) VALUES ('11111111-1111-4111-8111-111111111102', 'kaki@hikehub.hk', '嘉琪 KaKi', '港島週末輕鬆行，喜歡影相打卡同探索補給士多豆腐花。', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80', '2026-10-02T09:15:00Z') ON CONFLICT (id) DO UPDATE SET nickname = EXCLUDED.nickname, bio = EXCLUDED.bio, avatar_url = EXCLUDED.avatar_url;
INSERT INTO public.profiles (id, email, nickname, bio, avatar_url, created_at) VALUES ('11111111-1111-4111-8111-111111111103', 'fai@hikehub.hk', '輝哥 · 裝備控', '香港山藝二級，熟悉新界東北撤退路線與行山裝備實測。', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80', '2026-10-03T11:00:00Z') ON CONFLICT (id) DO UPDATE SET nickname = EXCLUDED.nickname, bio = EXCLUDED.bio, avatar_url = EXCLUDED.avatar_url;
INSERT INTO public.profiles (id, email, nickname, bio, avatar_url, created_at) VALUES ('11111111-1111-4111-8111-111111111104', 'yannes@hikehub.hk', 'Yannes 山系少女', '每週一條新手友善路線，整理最齊交通同打卡位資訊！', 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80', '2026-10-04T14:20:00Z') ON CONFLICT (id) DO UPDATE SET nickname = EXCLUDED.nickname, bio = EXCLUDED.bio, avatar_url = EXCLUDED.avatar_url;
INSERT INTO public.profiles (id, email, nickname, bio, avatar_url, created_at) VALUES ('11111111-1111-4111-8111-111111111105', 'kelvin@hikehub.hk', 'Kelvin 越野跑手', '逆走衛奕信、鳳凰徑サブ4練習中，歡迎山友湊人夜行。', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80', '2026-10-05T16:45:00Z') ON CONFLICT (id) DO UPDATE SET nickname = EXCLUDED.nickname, bio = EXCLUDED.bio, avatar_url = EXCLUDED.avatar_url;
INSERT INTO public.profiles (id, email, nickname, bio, avatar_url, created_at) VALUES ('11111111-1111-4111-8111-111111111106', 'mandy@hikehub.hk', 'Mandy 郊遊日記', '行山新手，常在問答區請教交通與天氣，多謝各位山友指路！', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80', '2026-10-06T19:00:00Z') ON CONFLICT (id) DO UPDATE SET nickname = EXCLUDED.nickname, bio = EXCLUDED.bio, avatar_url = EXCLUDED.avatar_url;

-- 2. 10 Classic Hong Kong Hiking Trails
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-01', '龍脊 Dragon''s Back（土地灣至大浪灣）', '港島', 2, 8.5, 285, 165, 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80', '曾獲選為亞洲最佳市區遠足徑。由石澳道土地灣出發，登上打爛埕頂山脊，360度飽覽石澳、大浪灣及東龍洲海景，終點大浪灣有士多補給。', '[[22.2268, 114.2422], [22.2315, 114.2435], [22.2369, 114.2431], [22.2425, 114.2448], [22.2458, 114.2495]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-02', '麥理浩徑第二段（北潭凹至浪茄灣）', '西貢', 4, 13.5, 580, 300, 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop&q=80', '香港最絕美海岸山徑，途經赤徑、大浪坳、鹹田灣、西灣及吹筒坳，水清沙幼，西灣村設有多間茶座士多可補給及乘街渡撤退。', '[[22.4192, 114.3318], [22.4165, 114.351], [22.408, 114.3745], [22.3982, 114.3712], [22.3765, 114.3752]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-03', '獅子山歷史山徑（天馬苑至沙田坳）', '九龍及新界中', 3, 6.2, 460, 180, 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800&auto=format&fit=crop&q=80', '香港精神地標！由黃大仙天馬苑經回歸亭拾級而上，登頂獅子山頭俯瞰九龍半島與維港全景，落山至沙田坳恆益商店嘆山水豆腐花。', '[[22.3452, 114.1856], [22.351, 114.1865], [22.3526, 114.1872], [22.3538, 114.195], [22.3551, 114.2015]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-04', '大東山芒草徑（伯公坳至梅窩）', '大嶼山', 4, 9.0, 620, 240, 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80', '秋冬限定金色芒草海與百年爛頭營石屋群。由東涌道伯公坳起步直上海拔869米大東山，再沿南山古道落梅窩碼頭補給。', '[[22.2485, 113.9432], [22.253, 113.9525], [22.2562, 113.961], [22.2588, 113.978], [22.2645, 113.9985]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-05', '八仙嶺自然教育徑（大美督至新娘潭）', '新界東北', 5, 10.8, 790, 310, 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=800&auto=format&fit=crop&q=80', '連走八座山峰（仙姑峰至純陽峰），氣勢磅礴，可遠眺船灣淡水湖與深圳鹽田港。體能要求較高，務必帶足2升飲用水。', '[[22.4735, 114.2345], [22.482, 114.231], [22.4885, 114.2225], [22.493, 114.215], [22.5025, 114.236]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-06', '城門水塘環塘白千層徑', '九龍及新界中', 1, 7.5, 120, 135, 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&auto=format&fit=crop&q=80', '全港最受歡迎的新手林蔭平路！菠蘿壩小巴總站出發，途經蝴蝶園、白千層水浸林打卡位及主壩，全程樹蔭涼爽。', '[[22.3792, 114.1425], [22.388, 114.145], [22.3935, 114.1512], [22.3845, 114.1558], [22.3765, 114.1492]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-07', '山頂盧吉道全景環迴徑', '港島', 1, 3.6, 60, 75, 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80', '百年棧道平坦易行，無遮擋俯瞰維多利亞港兩岸摩天大樓，黃昏及夜景一流，起終點凌霄閣補給交通極為便利。', '[[22.2712, 114.1498], [22.2768, 114.1475], [22.2795, 114.1432], [22.275, 114.1415], [22.2712, 114.1498]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-08', '大帽山郊野公園觀景台線', '九龍及新界中', 3, 6.8, 430, 165, 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=800&auto=format&fit=crop&q=80', '登上全港最高峰（海拔957米），由扶輪公園蓮姐茶水亭出發，沿大帽山道蜿蜒而上至天氣雷達站，雲海與日落勝地。', '[[22.4045, 114.1165], [22.4088, 114.121], [22.4112, 114.1232], [22.4088, 114.121], [22.4045, 114.1165]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-09', '印洲塘郊遊徑（烏蛟騰至荔枝窩）', '新界東北', 2, 8.2, 210, 170, 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800&auto=format&fit=crop&q=80', '穿越三椏涌紅樹林與三百年客家古村荔枝窩，可品嚐地道客家菜茶果，回程可於三椏村或荔枝窩碼頭乘街渡返回馬料水。', '[[22.5112, 114.242], [22.518, 114.2545], [22.5215, 114.265], [22.5268, 114.2595]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;
INSERT INTO public.trails (id, name, region, difficulty, distance_km, ascent_m, duration_min, cover_url, description, path) VALUES ('trail-10', '鳳凰山日出線（伯公坳至昂坪）', '大嶼山', 5, 6.5, 680, 210, 'https://images.unsplash.com/photo-1495616811223-4d98c6e9c869?w=800&auto=format&fit=crop&q=80', '香港第二高峰（海拔934米），鳳凰觀日為香港八景之一。天梯石級陡峭，登頂後沿心經簡林落昂坪市集補給。', '[[22.2485, 113.9432], [22.2452, 113.9325], [22.2428, 113.9225], [22.2512, 113.911], [22.2555, 113.9028]]'::jsonb) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, path = EXCLUDED.path;

-- 3. Trail Segments
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-01-1', 'trail-01', 1, '土地灣巴士站 → 打爛埕頂山觀景台', 2.4, 165, FALSE, TRUE, '起點有流動洗手間，沿石級緩步上山') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-01-2', 'trail-01', 2, '打爛埕頂山 → 龍脊山脊段 → 馬塘坳', 3.6, 95, FALSE, TRUE, '山脊無遮擋注意防曬，馬塘坳可撤退往柴灣') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-01-3', 'trail-01', 3, '馬塘坳 → 大浪灣泳灘士多', 2.5, 25, TRUE, TRUE, '林蔭下坡，終點大浪灣有餐室、士多及小巴往筲箕灣') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-02-1', 'trail-02', 1, '北潭凹 → 赤徑 → 大浪坳', 5.0, 210, FALSE, TRUE, '赤徑碼頭可乘街渡撤退往黃石碼頭') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-02-2', 'trail-02', 2, '大浪坳 → 鹹田灣 → 西灣村', 4.5, 130, TRUE, TRUE, '鹹田灣及西灣村均有士多餐廳，西灣亭可乘村巴撤退') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-02-3', 'trail-02', 3, '西灣村 → 吹筒坳 → 浪茄灣 → 東壩', 4.0, 240, FALSE, TRUE, '終點萬宜水庫東壩有9A小巴回北潭涌') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-03-1', 'trail-03', 1, '天馬苑 → 獅子山郊野公園 → 回歸亭', 2.3, 250, FALSE, TRUE, '回歸亭設涼亭，可向九龍塘方向撤退') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-03-2', 'trail-03', 2, '回歸亭 → 獅子山頂（海拔495米）', 1.2, 180, FALSE, FALSE, '石級較陡，山頂風大注意安全') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-03-3', 'trail-03', 3, '獅子山頂 → 麥理浩徑五段 → 沙田坳士多', 2.7, 30, TRUE, TRUE, '沙田坳有恆益商店豆腐花及小巴落黃大仙') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-04-1', 'trail-04', 1, '伯公坳 → 大東山跳板石', 3.2, 510, FALSE, FALSE, '連續石級爬升，秋冬芒草盛開') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-04-2', 'trail-04', 2, '大東山 → 爛頭營石屋 → 二東山', 2.5, 110, FALSE, FALSE, '高原山脊路段，傍晚氣溫驟降需備風褸') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-04-3', 'trail-04', 3, '二東山 → 南山營地 → 梅窩碼頭', 3.3, 0, TRUE, TRUE, '南山有巴士站可提早撤退，梅窩餐廳選擇豐富') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-05-1', 'trail-05', 1, '大美督 → 春風亭 → 仙姑峰', 3.5, 480, TRUE, TRUE, '大美督起點有士多補給，上仙姑峰石級密集') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-05-2', 'trail-05', 2, '八仙連峰（仙姑峰 → 純陽峰）', 3.8, 310, FALSE, FALSE, '全程山脊暴曬無補給，風景極佳') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-05-3', 'trail-05', 3, '純陽峰 → 橫山腳 → 新娘潭巴士站', 3.5, 0, FALSE, TRUE, '新娘潭周末有275R巴士直達大埔墟站') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-06-1', 'trail-06', 1, '菠蘿壩小巴站 → 賞蝶園 → 白千層夾道', 3.8, 60, TRUE, TRUE, '菠蘿壩有小食亭，全段平坦林蔭') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-06-2', 'trail-06', 2, '白千層水浸林 → 城門主壩 → 菠蘿壩', 3.7, 60, FALSE, TRUE, '主壩可撤退往梨木樹') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-07-1', 'trail-07', 1, '凌霄閣 → 盧吉道維港觀景台 → 西高山郊遊區', 2.0, 30, TRUE, TRUE, '無障礙水泥步道，老少咸宜') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-07-2', 'trail-07', 2, '夏力道林蔭段 → 山頂廣場', 1.6, 30, TRUE, TRUE, '終點商場餐廳及纜車巴士齊備') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-08-1', 'trail-08', 1, '大帽山郊野公園茶水亭 → 大帽山道閘口', 1.8, 150, TRUE, TRUE, '蓮姐茶水亭必食茶葉蛋及燒賣') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-08-2', 'trail-08', 2, '大帽山道閘口 → 天氣雷達站頂峰（折返）', 5.0, 280, FALSE, TRUE, '全段瀝青車路，髮夾彎視野開揚') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-09-1', 'trail-09', 1, '烏蛟騰 → 九担租 → 三椏村', 4.5, 140, TRUE, TRUE, '三椏村有福利茶座可嘆客家美食') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-09-2', 'trail-09', 2, '三椏村 → 荔枝窩古村廣場', 3.7, 70, TRUE, TRUE, '紅樹林海岸步道，假日有街渡回馬料水') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-10-1', 'trail-10', 1, '伯公坳 → 鳳凰山天梯 → 鳳凰山頂', 3.2, 610, FALSE, FALSE, '日出熱門路線，天梯段需備頭燈') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.trail_segments (id, trail_id, seq, name, distance_km, ascent_m, has_supply, has_retreat, note) VALUES ('seg-10-2', 'trail-10', 2, '鳳凰山頂 → 斬柴坳 → 心經簡林 → 昂坪', 3.3, 70, TRUE, TRUE, '昂坪市集設有多間餐廳及巴士纜車') ON CONFLICT (id) DO NOTHING;

-- 4. Checkpoints
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-01-1', 'trail-01', 'seg-01-1', 1, '土地灣登山口', 22.2268, 114.2422, '9號巴士土地灣站下車即達') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-01-2', 'trail-01', 'seg-01-1', 2, '石澳半島觀景台', 22.2315, 114.2435, '俯瞰石澳泳灘與五分洲最佳位置') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-01-3', 'trail-01', 'seg-01-2', 3, '打爛埕頂山（龍脊最高點 284m）', 22.2369, 114.2431, '標距柱 H085 打卡熱點') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-01-4', 'trail-01', 'seg-01-3', 4, '大浪灣滑浪沙灘終點', 22.2458, 114.2495, '士多冰凍汽水與餐蛋麵補給') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-02-1', 'trail-02', 'seg-02-1', 1, '北潭凹起點標距柱', 22.4192, 114.3318, '94號巴士北潭凹站') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-02-2', 'trail-02', 'seg-02-2', 2, '鹹田灣獨木橋', 22.408, 114.3745, '經典木橋打卡位') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-02-3', 'trail-02', 'seg-02-2', 3, '西灣村茶座', 22.3982, 114.3712, '中途補給與撤退點') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-02-4', 'trail-02', 'seg-02-3', 4, '浪茄灣玻璃水沙灘', 22.3765, 114.3752, '全港最美水質沙灘') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-03-1', 'trail-03', 'seg-03-1', 1, '獅子山回歸亭', 22.351, 114.1865, '上下山分岔口及休息涼亭') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-03-2', 'trail-03', 'seg-03-2', 2, '獅子山頂標高柱', 22.3526, 114.1872, '九龍半島全景打卡位') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-03-3', 'trail-03', 'seg-03-3', 3, '沙田坳恆益商店', 22.3551, 114.2015, '必食山水薑汁豆腐花') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-04-1', 'trail-04', 'seg-04-1', 1, '伯公坳涼亭', 22.2485, 113.9432, '東涌巴士3M/11號下車點') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-04-2', 'trail-04', 'seg-04-2', 2, '爛頭營石屋群', 22.2562, 113.961, '大東山芒草核心打卡區') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-04-3', 'trail-04', 'seg-04-3', 3, '梅窩碼頭終點', 22.2645, 113.9985, '可乘渡輪回中環') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-05-1', 'trail-05', 'seg-05-1', 1, '仙姑峰頂', 22.482, 114.231, '八仙嶺第一峰') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-05-2', 'trail-05', 'seg-05-2', 2, '純陽峰標高柱', 22.4885, 114.2225, '八仙嶺最高峰 590m') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-06-1', 'trail-06', 'seg-06-1', 1, '城門白千層水浸林', 22.3935, 114.1512, '天空之鏡倒影打卡位') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-07-1', 'trail-07', 'seg-07-1', 1, '盧吉道維港觀景台', 22.2768, 114.1475, '維港最佳全景位') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-08-1', 'trail-08', 'seg-08-1', 1, '蓮姐茶水亭', 22.4045, 114.1165, '大帽山起點補給站') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-08-2', 'trail-08', 'seg-08-2', 2, '大帽山天氣雷達站', 22.4112, 114.1232, '全港最高點打卡位') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-09-1', 'trail-09', 'seg-09-2', 1, '荔枝窩客家古村', 22.5268, 114.2595, '百年風水林與空心樹') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.checkpoints (id, trail_id, segment_id, seq, name, lat, lng, note) VALUES ('cp-10-1', 'trail-10', 'seg-10-1', 1, '鳳凰山頂（海拔934m）', 22.2428, 113.9225, '鳳凰觀日避風亭') ON CONFLICT (id) DO NOTHING;

-- 5. Posts (Moments, Questions, Trips) & Photos
INSERT INTO public.posts (id, author_id, type, title, body, trail_id, meta, created_at) VALUES ('22222222-2222-4222-8222-222222222201', '11111111-1111-4111-8111-111111111102', 'moment', '龍脊秋風超爽！石澳海景無敵', '今日天朗氣清同山友行龍脊，打爛埕頂山吹海風超舒服，全程兩個半鐘落到大浪灣食餐蛋麵！強烈推薦週末早啲出發避開人潮。', 'trail-01', '{"tags": ["風景", "補給", "週末好去處"]}'::jsonb, '2026-11-02T17:20:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222201', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80', 1) ON CONFLICT (post_id, storage_path) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222201', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80', 2) ON CONFLICT (post_id, storage_path) DO NOTHING;
INSERT INTO public.posts (id, author_id, type, title, body, trail_id, meta, created_at) VALUES ('22222222-2222-4222-8222-222222222202', '11111111-1111-4111-8111-111111111101', 'trip', '麥理浩徑二段全走打卡記錄', '北潭凹入、東壩出，鹹田灣同浪茄灣水質依然係玻璃水級數！西灣村士多食咗碗冰凍綠豆沙回血，全程 13.5km 順利完成 4 個打卡點。', 'trail-02', '{"distance_km": 13.5, "duration_sec": 16800, "ascent_m": 580, "checked_count": 4, "total_checkpoints": 4, "tags": ["行山記錄", "西貢", "海景"], "path": [[22.4192, 114.3318], [22.4165, 114.351], [22.408, 114.3745], [22.3982, 114.3712], [22.3765, 114.3752]]}'::jsonb, '2026-11-02T20:10:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222202', 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop&q=80', 1) ON CONFLICT (post_id, storage_path) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222202', 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80', 2) ON CONFLICT (post_id, storage_path) DO NOTHING;
INSERT INTO public.posts (id, author_id, type, title, body, trail_id, meta, created_at) VALUES ('22222222-2222-4222-8222-222222222203', '11111111-1111-4111-8111-111111111104', 'moment', '大東山芒草季開鑼！夕陽金光太震撼', '三點半由伯公坳上山，五點剛好趕到爛頭營石屋影日落芒草。提醒大家太陽落山後風好大，記得帶件防風外套同頭燈落梅窩！', 'trail-04', '{"tags": ["芒草", "日落", "大嶼山"]}'::jsonb, '2026-11-03T09:30:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222203', 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&auto=format&fit=crop&q=80', 1) ON CONFLICT (post_id, storage_path) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222203', 'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=800&auto=format&fit=crop&q=80', 2) ON CONFLICT (post_id, storage_path) DO NOTHING;
INSERT INTO public.posts (id, author_id, type, title, body, trail_id, meta, created_at) VALUES ('22222222-2222-4222-8222-222222222204', '11111111-1111-4111-8111-111111111106', 'question', '請問週末去麥徑二段，西灣亭村巴尾班車係幾點？', '各位山友師兄師姐好！我同朋友星期六打算由北潭凹行去西灣村，怕體力唔夠未必行到去東壩，想問下西灣亭返西貢市中心嘅29R村巴尾班車係幾點？另外鹹田灣有冇街渡直接返西貢？唔該晒！', 'trail-02', '{"tags": ["交通", "撤退點"]}'::jsonb, '2026-11-01T15:00:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, author_id, type, title, body, trail_id, meta, created_at) VALUES ('22222222-2222-4222-8222-222222222205', '11111111-1111-4111-8111-111111111105', 'question', '11月凌晨上鳳凰山睇日出，需要著羽絨定普通抓絨就夠？', '準備今個禮拜日凌晨3點半由伯公坳上鳳凰山，市區預報19度左右，想請教近期上過頂嘅山友，山頂避風亭等日出嗰陣會唔會好凍？裝備方面有咩建議？', 'trail-10', '{"tags": ["裝備", "天氣"]}'::jsonb, '2026-11-03T11:45:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.posts (id, author_id, type, title, body, trail_id, meta, created_at) VALUES ('22222222-2222-4222-8222-222222222206', '11111111-1111-4111-8111-111111111103', 'moment', '獅子山頂望九龍全景 + 沙田坳豆腐花', '天馬苑上獅子山段石級雖然急，但上到山頂望住九龍同維港真係超值。落山去沙田坳食返碗熱辣辣薑汁豆腐花，完美半日遊！', 'trail-03', '{"tags": ["九龍全景", "補給", "豆腐花"]}'::jsonb, '2026-11-03T13:15:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222206', 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=800&auto=format&fit=crop&q=80', 1) ON CONFLICT (post_id, storage_path) DO NOTHING;
INSERT INTO public.post_photos (post_id, storage_path, seq) VALUES ('22222222-2222-4222-8222-222222222206', 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800&auto=format&fit=crop&q=80', 2) ON CONFLICT (post_id, storage_path) DO NOTHING;

-- 6. Comments
INSERT INTO public.comments (id, post_id, author_id, parent_id, body, is_accepted, created_at) VALUES ('33333333-3333-4333-8333-333333333301', '22222222-2222-4222-8222-222222222201', '11111111-1111-4111-8111-111111111101', NULL, '相片影得好靚！大浪灣間士多啲蔥油豬扒麵都好正。', FALSE, '2026-11-02T18:00:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.comments (id, post_id, author_id, parent_id, body, is_accepted, created_at) VALUES ('33333333-3333-4333-8333-333333333302', '22222222-2222-4222-8222-222222222201', '11111111-1111-4111-8111-111111111102', '33333333-3333-4333-8333-333333333301', '多謝阿瀚！下次去試下豬扒麵先～', FALSE, '2026-11-02T18:15:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.comments (id, post_id, author_id, parent_id, body, is_accepted, created_at) VALUES ('33333333-3333-4333-8333-333333333303', '22222222-2222-4222-8222-222222222204', '11111111-1111-4111-8111-111111111103', NULL, '西灣亭去西貢市中心嘅NR29村巴，假日尾班車通常係下晝 6:00（由西灣村行上西灣亭約需45分鐘）。另外鹹田灣同西灣村士多都可以即時買街渡飛直返西貢碼頭，約下晝4:30-5:00開船，但要視乎當日風浪情況！', TRUE, '2026-11-01T15:40:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.comments (id, post_id, author_id, parent_id, body, is_accepted, created_at) VALUES ('33333333-3333-4333-8333-333333333304', '22222222-2222-4222-8222-222222222204', '11111111-1111-4111-8111-111111111106', '33333333-3333-4333-8333-333333333303', '太詳細啦輝哥！已採納，我哋到時早啲到西灣村睇下街渡情況先！', FALSE, '2026-11-01T16:05:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.comments (id, post_id, author_id, parent_id, body, is_accepted, created_at) VALUES ('33333333-3333-4333-8333-333333333305', '22222222-2222-4222-8222-222222222205', '11111111-1111-4111-8111-111111111101', NULL, '鳳凰山頂凌晨好大風，體感比市區低 7-8 度！上山時會出汗著排汗底衫，但上到頂等日出嗰45分鐘一定要有輕量羽絨 + 防風硬殼，仲有必備頭燈。', FALSE, '2026-11-03T12:10:00Z') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.comments (id, post_id, author_id, parent_id, body, is_accepted, created_at) VALUES ('33333333-3333-4333-8333-333333333306', '22222222-2222-4222-8222-222222222202', '11111111-1111-4111-8111-111111111104', NULL, '浪茄灣水色真係好治癒，下星期跟住你條路線打卡先！', FALSE, '2026-11-02T21:00:00Z') ON CONFLICT (id) DO NOTHING;

-- 7. Likes & Favorites
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222201', '11111111-1111-4111-8111-111111111101') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222201', '11111111-1111-4111-8111-111111111103') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222201', '11111111-1111-4111-8111-111111111104') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222202', '11111111-1111-4111-8111-111111111101') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222202', '11111111-1111-4111-8111-111111111102') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222202', '11111111-1111-4111-8111-111111111104') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222202', '11111111-1111-4111-8111-111111111105') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222203', '11111111-1111-4111-8111-111111111101') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222203', '11111111-1111-4111-8111-111111111102') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222203', '11111111-1111-4111-8111-111111111103') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222203', '11111111-1111-4111-8111-111111111105') ON CONFLICT DO NOTHING;
INSERT INTO public.likes (post_id, user_id) VALUES ('22222222-2222-4222-8222-222222222203', '11111111-1111-4111-8111-111111111106') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111101', 'trail', 'trail-01') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111101', 'trail', 'trail-02') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111101', 'trail', 'trail-04') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111101', 'post', '22222222-2222-4222-8222-222222222201') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111101', 'post', '22222222-2222-4222-8222-222222222203') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111102', 'trail', 'trail-01') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111102', 'trail', 'trail-06') ON CONFLICT DO NOTHING;
INSERT INTO public.favorites (user_id, target_type, target_id) VALUES ('11111111-1111-4111-8111-111111111102', 'post', '22222222-2222-4222-8222-222222222202') ON CONFLICT DO NOTHING;

-- ===== 4/4 verify_db.sql =====
-- ============================================================================
-- 行山腳 HikeHub · 資料庫驗證腳本
-- 在 Supabase SQL Editor 執行本檔，逐段查看結果。
-- 正常情況下：所有「計數一致性」段落應回傳 0 行（無不符）；RLS 段落 9 張表皆為 t。
-- ============================================================================

-- 1. 各表行數
SELECT 'profiles'        AS tbl, count(*) AS rows FROM public.profiles
UNION ALL SELECT 'trails',          count(*) FROM public.trails
UNION ALL SELECT 'trail_segments',  count(*) FROM public.trail_segments
UNION ALL SELECT 'checkpoints',     count(*) FROM public.checkpoints
UNION ALL SELECT 'posts',           count(*) FROM public.posts
UNION ALL SELECT 'post_photos',     count(*) FROM public.post_photos
UNION ALL SELECT 'comments',        count(*) FROM public.comments
UNION ALL SELECT 'likes',           count(*) FROM public.likes
UNION ALL SELECT 'favorites',       count(*) FROM public.favorites;

-- 2. 可登入帳號檢查（應有 6 筆，confirmed / has_pw / profile_linked / has_instance 皆為 t；identities 皆為 1）
--    instance_id 為 NULL 代表是直接用 SQL 寫入、GoTrue 不認的帳號 → 登入會失敗。
SELECT u.email,
       (u.email_confirmed_at IS NOT NULL)                  AS confirmed,
       (u.encrypted_password IS NOT NULL)                  AS has_pw,
       (u.id IN (SELECT id FROM public.profiles))          AS profile_linked,
       (u.instance_id IS NOT NULL)                         AS has_instance,
       (SELECT count(*) FROM auth.identities i WHERE i.user_id = u.id) AS identities
FROM auth.users u
ORDER BY u.email;

-- 3. 計數一致性：posts.like_count vs likes
--    LEFT JOIN + COALESCE：0 計數貼文（沒有任何 likes 列）也必須被檢查，
--    否則 stored > 0 的漂移會被 INNER JOIN 靜默漏掉。
SELECT p.id, p.like_count AS stored, COALESCE(real_counts.cnt, 0) AS actual
FROM public.posts p
LEFT JOIN (SELECT post_id, count(*) AS cnt FROM public.likes GROUP BY post_id) real_counts
  ON real_counts.post_id = p.id
WHERE p.like_count <> COALESCE(real_counts.cnt, 0);

-- 4. 計數一致性：posts.comment_count vs comments
SELECT p.id, p.comment_count AS stored, COALESCE(real_counts.cnt, 0) AS actual
FROM public.posts p
LEFT JOIN (SELECT post_id, count(*) AS cnt FROM public.comments GROUP BY post_id) real_counts
  ON real_counts.post_id = p.id
WHERE p.comment_count <> COALESCE(real_counts.cnt, 0);

-- 5. 計數一致性：posts.favorite_count vs favorites(target_type='post')
SELECT p.id, p.favorite_count AS stored, COALESCE(real_counts.cnt, 0) AS actual
FROM public.posts p
LEFT JOIN (SELECT target_id, count(*) AS cnt FROM public.favorites WHERE target_type='post' GROUP BY target_id) real_counts
  ON real_counts.target_id = p.id::text
WHERE p.favorite_count <> COALESCE(real_counts.cnt, 0);

-- 6. 計數一致性：trails.favorite_count vs favorites(target_type='trail')
SELECT t.id, t.favorite_count AS stored, COALESCE(real_counts.cnt, 0) AS actual
FROM public.trails t
LEFT JOIN (SELECT target_id, count(*) AS cnt FROM public.favorites WHERE target_type='trail' GROUP BY target_id) real_counts
  ON real_counts.target_id = t.id
WHERE t.favorite_count <> COALESCE(real_counts.cnt, 0);

-- 7. RLS 啟用狀態（9 張表 rowsecurity 皆應為 t）
SELECT tablename, rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 8. 外鍵 / 目標孤立檢查（應全部回傳 0 行）
SELECT 'orphan_posts'        AS check_name, count(*) AS bad FROM public.posts p LEFT JOIN public.profiles pr ON pr.id = p.author_id WHERE pr.id IS NULL
UNION ALL
SELECT 'orphan_checkpoints', count(*) FROM public.checkpoints c LEFT JOIN public.trails t ON t.id = c.trail_id WHERE t.id IS NULL
UNION ALL
SELECT 'orphan_likes',       count(*) FROM public.likes l LEFT JOIN public.posts p ON p.id = l.post_id WHERE p.id IS NULL
UNION ALL
SELECT 'orphan_favorites',   count(*) FROM public.favorites f
  WHERE (f.target_type = 'trail' AND NOT EXISTS (SELECT 1 FROM public.trails t WHERE t.id = f.target_id))
     OR (f.target_type = 'post'  AND NOT EXISTS (SELECT 1 FROM public.posts p WHERE p.id::text = f.target_id))
UNION ALL
SELECT 'orphan_post_photos', count(*) FROM public.post_photos pp LEFT JOIN public.posts p ON p.id = pp.post_id WHERE p.id IS NULL;

-- 9. v5.1 補強是否生效：應看到 2 個唯一索引、4 個新 Trigger
SELECT indexname FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN ('uq_post_photos_post_path', 'uq_one_accepted_answer_per_question')
ORDER BY indexname;

SELECT tgname FROM pg_trigger
WHERE NOT tgisinternal
  AND tgname IN ('trg_block_likes_fk_update', 'trg_block_comments_fk_update',
                 'trg_block_favorites_fk_update', 'trg_cleanup_post_favorites')
ORDER BY tgname;
