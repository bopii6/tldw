import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const requestUrl = new URL(request.url)
  const code = requestUrl.searchParams.get('code')
  const error = requestUrl.searchParams.get('error')
  const errorDescription = requestUrl.searchParams.get('error_description')
  const origin = process.env.NEXT_PUBLIC_APP_URL || requestUrl.origin

  console.log('Auth callback received:', {
    url: requestUrl.href,
    hasCode: !!code,
    error,
    errorDescription,
    origin
  })

  // Handle OAuth errors
  if (error) {
    const errorMessage = errorDescription || error
    console.error('OAuth error received:', { error, errorDescription })

    // Provide more user-friendly error messages
    let userMessage = errorMessage
    if (error === 'access_denied') {
      userMessage = 'Sign in was cancelled. Please try again.'
    } else if (error === 'invalid_request') {
      userMessage = 'Invalid authentication request. Please try again.'
    }

    return NextResponse.redirect(`${origin}?auth_error=${encodeURIComponent(userMessage)}`)
  }

  if (code) {
    try {
      const supabase = await createClient()
      console.log('Attempting to exchange code for session...')

      const { data, error: sessionError } = await supabase.auth.exchangeCodeForSession(code)

      if (sessionError) {
        console.error('Session exchange error:', {
          error: sessionError,
          message: sessionError.message,
          details: sessionError
        })

        // Provide more specific error messages for common issues
        let userMessage = sessionError.message
        if (sessionError.message?.includes('Invalid refresh token')) {
          userMessage = 'Authentication session expired. Please try signing in again.'
        } else if (sessionError.message?.includes('Invalid grant')) {
          userMessage = 'Authentication code expired. Please try signing in again.'
        }

        return NextResponse.redirect(`${origin}?auth_error=${encodeURIComponent(userMessage)}`)
      }

      console.log('Session exchange successful:', {
        userId: data.user?.id,
        email: data.user?.email,
        hasSession: !!data.session
      })

    } catch (err) {
      console.error('Unexpected error during auth callback:', err)
      return NextResponse.redirect(`${origin}?auth_error=Authentication%20failed%20-%20please%20try%20again`)
    }
  }

  // URL to redirect to after sign in process completes
  // The pending video will be linked via the useEffect in page.tsx
  console.log('Auth callback completed successfully, redirecting to:', origin)
  return NextResponse.redirect(origin)
}