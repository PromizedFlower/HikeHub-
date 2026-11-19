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
