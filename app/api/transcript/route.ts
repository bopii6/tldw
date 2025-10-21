import { NextRequest, NextResponse } from 'next/server';
import { extractVideoId } from '@/lib/utils';
import { withSecurity, SECURITY_PRESETS } from '@/lib/security-middleware';

async function handler(request: NextRequest) {
  try {
    const { url } = await request.json();

    if (!url) {
      return NextResponse.json(
        { error: 'YouTube URL is required' },
        { status: 400 }
      );
    }

    const videoId = extractVideoId(url);
    
    if (!videoId) {
      return NextResponse.json(
        { error: 'Invalid YouTube URL' },
        { status: 400 }
      );
    }

    const apiKey = process.env.SUPADATA_API_KEY;
    if (!apiKey) {
      return NextResponse.json(
        { error: 'API configuration error' },
        { status: 500 }
      );
    }

    let transcript;

  // Retry function for network requests
  async function fetchWithRetry(url: string, options: RequestInit, maxRetries = 3): Promise<Response> {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        console.log(`Attempt ${attempt}/${maxRetries} to fetch transcript`);

        const response = await fetch(url, {
          ...options,
          signal: AbortSignal.timeout(15000) // 15 second timeout per attempt
        });

        if (response.ok) {
          return response;
        }

        // If it's a 429 rate limit, wait longer before retry
        if (response.status === 429) {
          const waitTime = Math.min(5000 * attempt, 15000); // Max 15 seconds
          console.log(`Rate limit hit, waiting ${waitTime}ms before retry...`);
          await new Promise(resolve => setTimeout(resolve, waitTime));
          continue;
        }

        // For other client errors, don't retry
        if (response.status >= 400 && response.status < 500) {
          return response;
        }

        // For server errors, retry with exponential backoff
        if (attempt < maxRetries) {
          const waitTime = Math.min(1000 * Math.pow(2, attempt - 1), 5000);
          console.log(`Server error, waiting ${waitTime}ms before retry...`);
          await new Promise(resolve => setTimeout(resolve, waitTime));
        }
      } catch (error) {
        console.error(`Attempt ${attempt} failed:`, error);

        if (attempt === maxRetries) {
          throw error;
        }

        // Exponential backoff for network errors
        const waitTime = Math.min(1000 * Math.pow(2, attempt - 1), 3000);
        console.log(`Network error, waiting ${waitTime}ms before retry...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }

    throw new Error(`Failed after ${maxRetries} attempts`);
  }

  try {
    const apiUrl = `https://api.supadata.ai/v1/youtube/transcript?url=https://www.youtube.com/watch?v=${videoId}&lang=en`;

    console.log('Fetching transcript from:', apiUrl);

    const response = await fetchWithRetry(apiUrl, {
      method: 'GET',
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
        'User-Agent': 'TLDW-App/1.0'
      }
    });

    console.log('Response status:', response.status);
    console.log('Response headers:', Object.fromEntries(response.headers.entries()));

    const responseText = await response.text();
    console.log('Response text (first 500 chars):', responseText.substring(0, 500));

      if (!response.ok) {
        console.error('API request failed:', response.status, responseText);

        if (response.status === 404) {
          return NextResponse.json(
            { error: 'No transcript/captions available for this video. The video may not have subtitles enabled.' },
            { status: 404 }
          );
        }

        if (response.status === 401) {
          return NextResponse.json(
            { error: 'API key invalid or expired. Please check configuration.' },
            { status: 500 }
          );
        }

        if (response.status === 429) {
          return NextResponse.json(
            { error: 'Rate limit exceeded. Please try again later.' },
            { status: 429 }
          );
        }

        return NextResponse.json(
          {
            error: 'Failed to fetch transcript from external API',
            details: `Status: ${response.status}, Message: ${responseText}`
          },
          { status: 500 }
        );
      }

      let data;
      try {
        data = JSON.parse(responseText);
      } catch (parseError) {
        console.error('Failed to parse JSON response:', parseError);
        return NextResponse.json(
          {
            error: 'Invalid response format from transcript API',
            details: `Parse error: ${parseError instanceof Error ? parseError.message : 'Unknown error'}`
          },
          { status: 500 }
        );
      }

      // The API returns data with a 'content' array containing the transcript segments
      transcript = data.content || data.transcript || data;
      console.log('Transcript data type:', typeof transcript);
      console.log('Transcript length:', Array.isArray(transcript) ? transcript.length : 'Not an array');

    } catch (fetchError) {
      console.error('Error fetching transcript:', fetchError);
      const errorMessage = fetchError instanceof Error ? fetchError.message : 'Unknown error';

      return NextResponse.json(
        {
          error: 'Failed to fetch transcript',
          details: errorMessage
        },
        { status: 500 }
      );
    }
    
    if (!transcript || (Array.isArray(transcript) && transcript.length === 0)) {
      return NextResponse.json(
        { error: 'No transcript available for this video' },
        { status: 404 }
      );
    }

    // Log sample of transcript for debugging
    if (Array.isArray(transcript) && transcript.length > 0) {
    }

    const transformedTranscript = Array.isArray(transcript) ? transcript.map((item, idx) => {
      const transformed = {
        text: item.text || item.content || '',
        // Convert milliseconds to seconds for offset/start
        start: (item.offset !== undefined ? item.offset / 1000 : item.start) || 0,
        // Convert milliseconds to seconds for duration
        duration: (item.duration !== undefined ? item.duration / 1000 : 0) || 0
      };
      
      // Check for empty segments
      if (!transformed.text || transformed.text.trim() === '') {
      }
      
      // Debug segments around index 40-46
      if (idx >= 40 && idx <= 46) {
      }
      
      return transformed;
    }) : [];
    

    return NextResponse.json({
      videoId,
      transcript: transformedTranscript
    });
  } catch (error) {
    return NextResponse.json(
      { error: 'Failed to fetch transcript' },
      { status: 500 }
    );
  }
}

export const POST = withSecurity(handler, SECURITY_PRESETS.PUBLIC);