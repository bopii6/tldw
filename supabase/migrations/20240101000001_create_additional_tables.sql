-- Additional tables and updates for TLDW application
-- This migration adds supporting tables and ensures completeness

-- Create csrf_tokens table for CSRF protection
CREATE TABLE IF NOT EXISTS public.csrf_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  token_hash text NOT NULL UNIQUE,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for csrf_tokens
CREATE INDEX IF NOT EXISTS idx_csrf_tokens_token_hash ON public.csrf_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_csrf_tokens_user_id ON public.csrf_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_csrf_tokens_expires_at ON public.csrf_tokens(expires_at);

-- Enable RLS for csrf_tokens
ALTER TABLE public.csrf_tokens ENABLE ROW LEVEL SECURITY;

-- CSRF tokens policies - users can only access their own tokens
CREATE POLICY "Users can manage own csrf tokens" ON public.csrf_tokens
  FOR ALL USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON public.csrf_tokens TO authenticated;

-- Create function to clean up expired CSRF tokens
CREATE OR REPLACE FUNCTION public.cleanup_expired_csrf_tokens()
RETURNS void AS $$
BEGIN
  DELETE FROM public.csrf_tokens WHERE expires_at < timezone('utc'::text, now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create rate_limits table for more comprehensive rate limiting
CREATE TABLE IF NOT EXISTS public.rate_limits (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  identifier text NOT NULL,
  action text NOT NULL,
  count integer NOT NULL DEFAULT 1,
  window_start timestamp with time zone NOT NULL,
  window_end timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(identifier, action, window_start, window_end)
);

-- Create indexes for rate_limits
CREATE INDEX IF NOT EXISTS idx_rate_limits_identifier_action ON public.rate_limits(identifier, action);
CREATE INDEX IF NOT EXISTS idx_rate_limits_window_end ON public.rate_limits(window_end);

-- Add trigger for rate_limits
CREATE TRIGGER handle_rate_limits_updated_at
  BEFORE UPDATE ON public.rate_limits
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable RLS for rate_limits
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Rate limits policies - only service role can access
CREATE POLICY "Service role full access to rate limits" ON public.rate_limits
  FOR ALL USING (auth.role() = 'service_role');

-- Grant permissions to service role
GRANT ALL ON public.rate_limits TO service_role;

-- Create audit_logs table for security auditing
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  resource_type text,
  resource_id text,
  ip_address inet,
  user_agent text,
  details jsonb,
  success boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for audit_logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON public.audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON public.audit_logs(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_success ON public.audit_logs(success);

-- Enable RLS for audit_logs
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Audit logs policies - users can view their own audit logs
CREATE POLICY "Users can view own audit logs" ON public.audit_logs
  FOR SELECT USING (auth.uid() = user_id);

-- Service role can manage all audit logs
CREATE POLICY "Service role full access to audit logs" ON public.audit_logs
  FOR ALL USING (auth.role() = 'service_role');

-- Grant permissions
GRANT SELECT ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO service_role;

-- Add helpful function to get or create user profile automatically
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, avatar_url)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    new.raw_user_meta_data->>'avatar_url'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create profile on user signup
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create function to sync user_videos with favorites (for backward compatibility)
CREATE OR REPLACE FUNCTION public.sync_favorites_to_user_videos()
RETURNS void AS $$
BEGIN
  -- Insert any favorites that don't exist in user_videos
  INSERT INTO public.user_videos (user_id, video_id, is_favorite, accessed_at)
  SELECT
    uf.user_id,
    va.id as video_id,
    true as is_favorite,
    uf.created_at as accessed_at
  FROM public.user_favorites uf
  JOIN public.video_analyses va ON uf.video_analysis_id = va.id
  LEFT JOIN public.user_videos uv ON uf.user_id = uv.user_id AND va.id = uv.video_id
  WHERE uv.id IS NULL
  ON CONFLICT (user_id, video_id)
  DO UPDATE SET
    is_favorite = true,
    accessed_at = EXCLUDED.accessed_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create view for simplified video history access
CREATE OR REPLACE VIEW public.user_video_history AS
SELECT
  uv.id as user_video_id,
  uv.user_id,
  uv.is_favorite,
  uv.accessed_at,
  uv.created_at as link_created_at,
  va.id as video_id,
  va.youtube_id,
  va.title,
  va.author,
  va.thumbnail_url,
  va.duration,
  va.description,
  va.tags,
  va.created_at as video_created_at,
  va.updated_at as video_updated_at
FROM public.user_videos uv
JOIN public.video_analyses va ON uv.video_id = va.id;

-- Grant permissions on the view (views don't support RLS, but we can control access through permissions)
GRANT SELECT ON public.user_video_history TO authenticated;