-- Fix rate_limits table structure to match rate limiter code
-- This migration updates the rate_limits table to have the correct schema

-- Drop existing rate_limits table and recreate with correct schema
DROP TABLE IF EXISTS public.rate_limits CASCADE;

-- Recreate rate_limits table with correct structure
CREATE TABLE IF NOT EXISTS public.rate_limits (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  key text NOT NULL,
  identifier text NOT NULL,
  timestamp timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create indexes for rate_limits
CREATE INDEX IF NOT EXISTS idx_rate_limits_key ON public.rate_limits(key);
CREATE INDEX IF NOT EXISTS idx_rate_limits_identifier ON public.rate_limits(identifier);
CREATE INDEX IF NOT EXISTS idx_rate_limits_timestamp ON public.rate_limits(timestamp);

-- Enable RLS for rate_limits
ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- Rate limits policies - only service role can access
CREATE POLICY "Service role full access to rate limits" ON public.rate_limits
  FOR ALL USING (auth.role() = 'service_role');

-- Grant permissions to service role
GRANT ALL ON public.rate_limits TO service_role;