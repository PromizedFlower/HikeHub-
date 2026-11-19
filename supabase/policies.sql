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
