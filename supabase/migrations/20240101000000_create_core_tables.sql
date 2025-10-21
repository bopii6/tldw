-- Create core tables for TLDW application
-- This migration creates all the necessary tables for the application to function

-- Create profiles table (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name text,
  email text,
  avatar_url text,
  topic_generation_mode text NOT NULL DEFAULT 'smart' CHECK (topic_generation_mode IN ('smart', 'fast')),
  free_generations_used integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create video_analyses table
CREATE TABLE IF NOT EXISTS public.video_analyses (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  youtube_id text NOT NULL UNIQUE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  title text NOT NULL,
  author text NOT NULL,
  thumbnail_url text NOT NULL,
  duration integer,
  description text,
  tags text[],
  transcript jsonb NOT NULL,
  topics jsonb NOT NULL,
  summary jsonb,
  suggested_questions jsonb,
  topic_candidates jsonb,
  theme_topics_map jsonb,
  generation_mode text NOT NULL DEFAULT 'smart' CHECK (generation_mode IN ('smart', 'fast')),
  model_used text,
  processing_status text DEFAULT 'completed' CHECK (processing_status IN ('pending', 'processing', 'completed', 'failed')),
  error_message text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create user_videos table (comprehensive user video management)
CREATE TABLE IF NOT EXISTS public.user_videos (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.video_analyses(id) ON DELETE CASCADE,
  is_favorite boolean DEFAULT false,
  accessed_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, video_id)
);

-- Create user_favorites table (legacy support - redirects to user_videos)
CREATE TABLE IF NOT EXISTS public.user_favorites (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_analysis_id uuid NOT NULL REFERENCES public.video_analyses(id) ON DELETE CASCADE,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(user_id, video_analysis_id)
);

-- Create notes table
CREATE TABLE IF NOT EXISTS public.notes (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.video_analyses(id) ON DELETE CASCADE,
  source text NOT NULL CHECK (source IN ('chat', 'takeaways', 'transcript', 'custom')),
  source_id text,
  text text NOT NULL,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create user_notes table (alias for notes - supports both names)
CREATE TABLE IF NOT EXISTS public.user_notes (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id uuid NOT NULL REFERENCES public.video_analyses(id) ON DELETE CASCADE,
  source text NOT NULL CHECK (source IN ('chat', 'takeaways', 'transcript', 'custom')),
  source_id text,
  note_text text NOT NULL,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create rate_limit_logs table
CREATE TABLE IF NOT EXISTS public.rate_limit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  identifier text NOT NULL, -- Can be IP address or user ID
  action text NOT NULL, -- e.g., 'analyze_video', 'generate_topics'
  timestamp timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_video_analyses_youtube_id ON public.video_analyses(youtube_id);
CREATE INDEX IF NOT EXISTS idx_video_analyses_user_id ON public.video_analyses(user_id);
CREATE INDEX IF NOT EXISTS idx_video_analyses_created_at ON public.video_analyses(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_videos_user_id ON public.user_videos(user_id);
CREATE INDEX IF NOT EXISTS idx_user_videos_video_id ON public.user_videos(video_id);
CREATE INDEX IF NOT EXISTS idx_user_videos_accessed_at ON public.user_videos(accessed_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id ON public.user_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_video_analysis_id ON public.user_favorites(video_analysis_id);
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON public.notes(user_id);
CREATE INDEX IF NOT EXISTS idx_notes_video_id ON public.notes(video_id);
CREATE INDEX IF NOT EXISTS idx_notes_source ON public.notes(source);
CREATE INDEX IF NOT EXISTS idx_notes_created_at ON public.notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_notes_user_id ON public.user_notes(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notes_video_id ON public.user_notes(video_id);
CREATE INDEX IF NOT EXISTS idx_user_notes_source ON public.user_notes(source);
CREATE INDEX IF NOT EXISTS idx_user_notes_created_at ON public.user_notes(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rate_limit_logs_identifier ON public.rate_limit_logs(identifier);
CREATE INDEX IF NOT EXISTS idx_rate_limit_logs_timestamp ON public.rate_limit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_rate_limit_logs_action ON public.rate_limit_logs(action);

-- Add updated_at trigger for all tables
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER handle_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_video_analyses_updated_at
  BEFORE UPDATE ON public.video_analyses
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_user_videos_updated_at
  BEFORE UPDATE ON public.user_videos
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_notes_updated_at
  BEFORE UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_user_notes_updated_at
  BEFORE UPDATE ON public.user_notes
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Row Level Security (RLS) policies

-- Profiles table policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Video analyses table policies
ALTER TABLE public.video_analyses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own video analyses" ON public.video_analyses
  FOR SELECT USING (user_id IS NULL OR user_id = auth.uid());

CREATE POLICY "Users can insert video analyses" ON public.video_analyses
  FOR INSERT WITH CHECK (user_id IS NULL OR user_id = auth.uid());

CREATE POLICY "Users can update own video analyses" ON public.video_analyses
  FOR UPDATE USING (user_id = auth.uid());

-- User videos table policies
ALTER TABLE public.user_videos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own user videos" ON public.user_videos
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own user videos" ON public.user_videos
  FOR ALL USING (auth.uid() = user_id);

-- User favorites table policies
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own favorites" ON public.user_favorites
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own favorites" ON public.user_favorites
  FOR ALL USING (auth.uid() = user_id);

-- Notes table policies
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notes" ON public.notes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own notes" ON public.notes
  FOR ALL USING (auth.uid() = user_id);

-- User notes table policies
ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own user notes" ON public.user_notes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own user notes" ON public.user_notes
  FOR ALL USING (auth.uid() = user_id);

-- Rate limit logs table policies
ALTER TABLE public.rate_limit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own rate limit logs" ON public.rate_limit_logs
  FOR SELECT USING (false); -- Only service roles can access rate limit logs

-- Grant permissions to authenticated users
GRANT ALL ON public.profiles TO authenticated;
GRANT ALL ON public.video_analyses TO authenticated;
GRANT ALL ON public.user_videos TO authenticated;
GRANT ALL ON public.user_favorites TO authenticated;
GRANT ALL ON public.notes TO authenticated;
GRANT ALL ON public.user_notes TO authenticated;

-- Grant permissions to anonymous users for video_analyses (read-only)
GRANT SELECT ON public.video_analyses TO anon;

-- Grant permissions to service role for rate limit logs
GRANT ALL ON public.rate_limit_logs TO service_role;

-- Create function to upsert video analysis with user link
CREATE OR REPLACE FUNCTION public.upsert_video_analysis_with_user_link(
  p_youtube_id text,
  p_user_id uuid,
  p_title text,
  p_author text,
  p_thumbnail_url text,
  p_duration integer,
  p_description text,
  p_tags text[],
  p_transcript jsonb,
  p_topics jsonb,
  p_summary jsonb DEFAULT NULL,
  p_suggested_questions jsonb DEFAULT NULL,
  p_topic_candidates jsonb DEFAULT NULL,
  p_theme_topics_map jsonb DEFAULT NULL,
  p_generation_mode text DEFAULT 'smart',
  p_model_used text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_analysis_id uuid;
BEGIN
  -- Upsert the video analysis
  INSERT INTO public.video_analyses (
    youtube_id, user_id, title, author, thumbnail_url, duration,
    description, tags, transcript, topics, summary, suggested_questions,
    topic_candidates, theme_topics_map, generation_mode, model_used
  ) VALUES (
    p_youtube_id, p_user_id, p_title, p_author, p_thumbnail_url, p_duration,
    p_description, p_tags, p_transcript, p_topics, p_summary, p_suggested_questions,
    p_topic_candidates, p_theme_topics_map, p_generation_mode, p_model_used
  )
  ON CONFLICT (youtube_id)
  DO UPDATE SET
    user_id = p_user_id,
    title = EXCLUDED.title,
    author = EXCLUDED.author,
    thumbnail_url = EXCLUDED.thumbnail_url,
    duration = EXCLUDED.duration,
    description = EXCLUDED.description,
    tags = EXCLUDED.tags,
    transcript = EXCLUDED.transcript,
    topics = EXCLUDED.topics,
    summary = COALESCE(EXCLUDED.summary, video_analyses.summary),
    suggested_questions = COALESCE(EXCLUDED.suggested_questions, video_analyses.suggested_questions),
    topic_candidates = COALESCE(EXCLUDED.topic_candidates, video_analyses.topic_candidates),
    theme_topics_map = COALESCE(EXCLUDED.theme_topics_map, video_analyses.theme_topics_map),
    generation_mode = EXCLUDED.generation_mode,
    model_used = COALESCE(EXCLUDED.model_used, video_analyses.model_used),
    updated_at = timezone('utc'::text, now())
  RETURNING id INTO v_analysis_id;

  RETURN v_analysis_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create helper function to get user's video analysis history
CREATE OR REPLACE FUNCTION public.get_user_video_history(p_user_id uuid, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
RETURNS TABLE (
  id uuid,
  youtube_id text,
  title text,
  author text,
  thumbnail_url text,
  duration integer,
  created_at timestamp with time zone,
  is_favorited boolean,
  accessed_at timestamp with time zone
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    va.id,
    va.youtube_id,
    va.title,
    va.author,
    va.thumbnail_url,
    va.duration,
    va.created_at,
    COALESCE(uv.is_favorite, false) as is_favorited,
    uv.accessed_at
  FROM public.video_analyses va
  LEFT JOIN public.user_videos uv ON va.id = uv.video_id AND uv.user_id = p_user_id
  WHERE va.user_id = p_user_id
  ORDER BY COALESCE(uv.accessed_at, va.created_at) DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;