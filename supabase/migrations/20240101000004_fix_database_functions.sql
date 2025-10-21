-- Fix ambiguous column reference in database functions

-- Drop and recreate the upsert_video_analysis_with_user_link function to fix any issues
DROP FUNCTION IF EXISTS public.upsert_video_analysis_with_user_link;

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
  RETURNING video_analyses.id INTO v_analysis_id;

  RETURN v_analysis_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fix the get_user_video_history function to avoid ambiguous column references
DROP FUNCTION IF EXISTS public.get_user_video_history;

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

-- Create a simpler function to update suggested questions
CREATE OR REPLACE FUNCTION public.update_suggested_questions(
  p_youtube_id text,
  p_suggested_questions jsonb
)
RETURNS boolean AS $$
BEGIN
  UPDATE public.video_analyses
  SET suggested_questions = p_suggested_questions,
      updated_at = timezone('utc'::text, now())
  WHERE youtube_id = p_youtube_id;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions to the new functions
GRANT EXECUTE ON FUNCTION public.upsert_video_analysis_with_user_link TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_video_analysis_with_user_link TO service_role;
GRANT EXECUTE ON FUNCTION public.get_user_video_history TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_suggested_questions TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_suggested_questions TO service_role;