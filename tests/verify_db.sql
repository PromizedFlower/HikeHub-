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
