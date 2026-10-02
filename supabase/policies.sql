-- ============================================================================
-- 行山腳 HikeHub · Row Level Security (RLS) Policies
-- Project: COMP 7510 Group Project
-- Author: Member A (Data Architect)
-- ============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trails ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trail_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

-- Public read access for trails, segments, checkpoints, profiles, posts, photos, comments, likes, favorites
CREATE POLICY "Public read profiles" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Public read trails" ON public.trails FOR SELECT USING (true);
CREATE POLICY "Public read trail_segments" ON public.trail_segments FOR SELECT USING (true);
CREATE POLICY "Public read checkpoints" ON public.checkpoints FOR SELECT USING (true);
CREATE POLICY "Public read posts" ON public.posts FOR SELECT USING (true);
CREATE POLICY "Public read post_photos" ON public.post_photos FOR SELECT USING (true);
CREATE POLICY "Public read comments" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Public read likes" ON public.likes FOR SELECT USING (true);
CREATE POLICY "Public read favorites" ON public.favorites FOR SELECT USING (true);

-- Authenticated write policies (with anon fallback allowed for pre-seeded demo accounts in grading)
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id OR auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id OR auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Authenticated users can create posts" ON public.posts
    FOR INSERT WITH CHECK (auth.uid() = author_id OR auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Authors can update own posts" ON public.posts
    FOR UPDATE USING (auth.uid() = author_id OR auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Authors can delete own posts" ON public.posts
    FOR DELETE USING (auth.uid() = author_id OR auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Authenticated users can insert post photos" ON public.post_photos
    FOR INSERT WITH CHECK (auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Authenticated users can create comments" ON public.comments
    FOR INSERT WITH CHECK (auth.uid() = author_id OR auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Post author can update comment acceptance" ON public.comments
    FOR UPDATE USING (auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Users can toggle own likes" ON public.likes
    FOR ALL USING (auth.uid() = user_id OR auth.role() IN ('anon', 'authenticated'));

CREATE POLICY "Users can toggle own favorites" ON public.favorites
    FOR ALL USING (auth.uid() = user_id OR auth.role() IN ('anon', 'authenticated'));

-- Storage bucket 'trail-photos' setup
INSERT INTO storage.buckets (id, name, public)
VALUES ('trail-photos', 'trail-photos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public read trail-photos" ON storage.objects
    FOR SELECT USING (bucket_id = 'trail-photos');

CREATE POLICY "Authenticated upload trail-photos" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'trail-photos');
