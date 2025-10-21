import { createClient } from '@/lib/supabase/server';
import { headers } from 'next/headers';
import { NextResponse } from 'next/server';
import crypto from 'crypto';

interface RateLimitConfig {
  windowMs: number; // Time window in milliseconds
  maxRequests: number; // Maximum requests per window
  identifier?: string; // Custom identifier (user ID, IP, etc.)
}

interface RateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: Date;
  retryAfter?: number; // Seconds until next request allowed
}

export class RateLimiter {
  private static async getIdentifier(customId?: string): Promise<string> {
    if (customId) return customId;

    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (user) {
      return `user:${user.id}`;
    }

    // For anonymous users, use IP address hash
    const headersList = await headers();
    const forwardedFor = headersList.get('x-forwarded-for');
    const realIp = headersList.get('x-real-ip');
    const ip = forwardedFor?.split(',')[0] || realIp || 'unknown';


    // Hash the IP for privacy
    const hash = crypto.createHash('sha256').update(ip).digest('hex');
    return `anon:${hash.substring(0, 16)}`;
  }

  static async peek(
    key: string,
    config: RateLimitConfig
  ): Promise<RateLimitResult> {
    const identifier = await this.getIdentifier(config.identifier);
    const rateLimitKey = `ratelimit:${key}:${identifier}`;

    const supabase = await createClient();
    const now = Date.now();
    const windowStart = now - config.windowMs;

    try {
      // Count recent requests without modifying
      const { data: recentRequests, error: countError } = await supabase
        .from('rate_limits')
        .select('id')
        .eq('key', rateLimitKey)
        .gte('timestamp', new Date(windowStart).toISOString());

      if (countError) throw countError;

      const requestCount = recentRequests?.length || 0;
      const remaining = Math.max(0, config.maxRequests - requestCount);
      const resetAt = new Date(now + config.windowMs);

      if (requestCount >= config.maxRequests) {
        // Calculate when the oldest request will expire
        const { data: oldestRequest } = await supabase
          .from('rate_limits')
          .select('timestamp')
          .eq('key', rateLimitKey)
          .order('timestamp', { ascending: true })
          .limit(1)
          .single();

        let retryAfter = Math.ceil(config.windowMs / 1000);
        if (oldestRequest) {
          const oldestTime = new Date(oldestRequest.timestamp).getTime();
          retryAfter = Math.ceil((oldestTime + config.windowMs - now) / 1000);
        }

        return {
          allowed: false,
          remaining: 0,
          resetAt,
          retryAfter
        };
      }

      return {
        allowed: true,
        remaining,
        resetAt
      };
    } catch (error) {
      console.error('Rate limiter peek error:', error);
      // On error, allow the request but log it
      return {
        allowed: true,
        remaining: config.maxRequests,
        resetAt: new Date(now + config.windowMs)
      };
    }
  }

  static async check(
    key: string,
    config: RateLimitConfig
  ): Promise<RateLimitResult> {
    const identifier = await this.getIdentifier(config.identifier);
    const rateLimitKey = `ratelimit:${key}:${identifier}`;

    const supabase = await createClient();
    const now = Date.now();
    const windowStart = now - config.windowMs;

    try {
      // First, clean up old entries with timeout
      const cleanupPromise = supabase
        .from('rate_limits')
        .delete()
        .lt('timestamp', new Date(windowStart).toISOString());

      // Add timeout to prevent hanging
      const cleanupResult = await Promise.race([
        cleanupPromise,
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Rate limit cleanup timeout')), 5000)
        )
      ]);

      // Count recent requests with timeout
      const countPromise = supabase
        .from('rate_limits')
        .select('id')
        .eq('key', rateLimitKey)
        .gte('timestamp', new Date(windowStart).toISOString());

      const { data: recentRequests, error: countError } = await Promise.race([
        countPromise,
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Rate limit query timeout')), 5000)
        )
      ]) as any;

      if (countError) throw countError;

      const requestCount = recentRequests?.length || 0;
      const remaining = Math.max(0, config.maxRequests - requestCount);
      const resetAt = new Date(now + config.windowMs);

      if (requestCount >= config.maxRequests) {
        // Calculate when the oldest request will expire
        const { data: oldestRequest } = await supabase
          .from('rate_limits')
          .select('timestamp')
          .eq('key', rateLimitKey)
          .order('timestamp', { ascending: true })
          .limit(1)
          .single();

        let retryAfter = Math.ceil(config.windowMs / 1000);
        if (oldestRequest) {
          const oldestTime = new Date(oldestRequest.timestamp).getTime();
          retryAfter = Math.ceil((oldestTime + config.windowMs - now) / 1000);
        }

        return {
          allowed: false,
          remaining: 0,
          resetAt,
          retryAfter
        };
      }

      // Record this request
      const { error: insertError } = await supabase
        .from('rate_limits')
        .insert({
          key: rateLimitKey,
          timestamp: new Date(now).toISOString(),
          identifier
        });

      if (insertError) {
        console.error('Failed to insert rate limit record:', insertError);
        console.error('Rate limit key:', rateLimitKey);
        console.error('Identifier:', identifier);
      }

      return {
        allowed: true,
        remaining: remaining - 1,
        resetAt
      };
    } catch (error) {
      console.error('Rate limiter error:', error);
      // On error, allow the request but log it
      return {
        allowed: true,
        remaining: config.maxRequests,
        resetAt: new Date(now + config.windowMs)
      };
    }
  }

  static async reset(key: string, identifier?: string): Promise<void> {
    const id = await this.getIdentifier(identifier);
    const rateLimitKey = `ratelimit:${key}:${id}`;

    const supabase = await createClient();
    await supabase
      .from('rate_limits')
      .delete()
      .eq('key', rateLimitKey);
  }
}

// Preset configurations for different endpoints
export const RATE_LIMITS = {
  // Anonymous users
  ANON_GENERATION: {
    windowMs: 24 * 60 * 60 * 1000, // 24 hours
    maxRequests: 1 // 1 generation per day
  },
  ANON_CHAT: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 10 // 10 messages per minute
  },

  // Authenticated users
  AUTH_GENERATION: {
    windowMs: 60 * 60 * 1000, // 1 hour
    maxRequests: 20 // 20 generations per hour
  },
  AUTH_VIDEO_GENERATION: {
    windowMs: 24 * 60 * 60 * 1000, // 24 hours
    maxRequests: 5 // 5 generations per day
  },
  AUTH_CHAT: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 30 // 30 messages per minute
  },

  // General API endpoints
  API_GENERAL: {
    windowMs: 60 * 1000, // 1 minute
    maxRequests: 60 // 60 requests per minute
  },

  // Sensitive operations
  AUTH_ATTEMPT: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    maxRequests: 5 // 5 login attempts per 15 minutes
  }
};

// Helper function for API responses
export function rateLimitResponse(result: RateLimitResult): NextResponse | null {
  const headers: HeadersInit = {
    'X-RateLimit-Remaining': result.remaining.toString(),
    'X-RateLimit-Reset': result.resetAt.toISOString()
  };

  if (!result.allowed && result.retryAfter) {
    headers['Retry-After'] = result.retryAfter.toString();

    return NextResponse.json(
      {
        error: 'Rate limit exceeded',
        message: `Too many requests. Please try again in ${result.retryAfter} seconds.`,
        retryAfter: result.retryAfter,
        resetAt: result.resetAt
      },
      {
        status: 429,
        headers
      }
    );
  }

  return null; // Request allowed
}