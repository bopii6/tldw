-- Fix rate_limits table RLS policies to allow insertions
-- This migration updates the RLS policies to allow rate limiting functionality

-- Drop existing policies
DROP POLICY IF EXISTS "Service role full access to rate limits" ON public.rate_limits;

-- Create new policies that allow rate limiting to work
-- Allow anyone to insert rate limit records (for rate limiting to function)
CREATE POLICY "Allow insert for rate limiting" ON public.rate_limits
  FOR INSERT WITH CHECK (true);

-- Allow service role full access for management
CREATE POLICY "Service role full access" ON public.rate_limits
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Grant insert permissions to authenticated users for rate limiting
GRANT INSERT ON public.rate_limits TO authenticated;
GRANT INSERT ON public.rate_limits TO anon;