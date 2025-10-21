import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { withSecurity, SECURITY_PRESETS } from '@/lib/security-middleware';
import { z } from 'zod';
import { formatValidationError } from '@/lib/validation';

const saveAnalysisSchema = z.object({
  videoId: z.string().min(1, 'Video ID is required'),
  videoInfo: z.object({
    title: z.string(),
    author: z.string().optional(),
    duration: z.number().optional(),
    thumbnail: z.string().optional(),
    description: z.string().optional(),
    tags: z.array(z.string()).optional()
  }),
  transcript: z.array(z.object({
    text: z.string(),
    start: z.number(),
    duration: z.number()
  })),
  topics: z.array(z.any()),
  summary: z.string().nullable().optional(),
  suggestedQuestions: z.array(z.string()).nullable().optional(),
  model: z.string().default('gemini-2.5-flash')
});

async function handler(req: NextRequest) {
  try {
    const body = await req.json();

    let validatedData;
    try {
      validatedData = saveAnalysisSchema.parse(body);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          {
            error: 'Validation failed',
            details: formatValidationError(error)
          },
          { status: 400 }
        );
      }
      throw error;
    }

    const {
      videoId,
      videoInfo,
      transcript,
      topics,
      summary,
      suggestedQuestions,
      model
    } = validatedData;

    const supabase = await createClient();

    const { data: { user } } = await supabase.auth.getUser();

    // First try to use the RPC function
    let result, saveError;

    try {
      const rpcResult = await supabase
        .rpc('upsert_video_analysis_with_user_link', {
          p_youtube_id: videoId,
          p_title: videoInfo.title,
          p_author: videoInfo.author || null,
          p_duration: videoInfo.duration || null,
          p_thumbnail_url: videoInfo.thumbnail || null,
          p_description: videoInfo.description || null,
          p_tags: videoInfo.tags || [],
          p_transcript: transcript,
          p_topics: topics,
          p_summary: summary || null,
          p_suggested_questions: suggestedQuestions || null,
          p_model_used: model,
          p_user_id: user?.id || null
        })
        .single();

      result = rpcResult.data;
      saveError = rpcResult.error;
    } catch (rpcError) {
      console.error('RPC function failed, falling back to direct insert:', rpcError);
      saveError = rpcError;
    }

    // If RPC fails, try direct upsert
    if (saveError) {
      console.log('Attempting direct upsert as fallback...');
      const upsertData = {
        youtube_id: videoId,
        user_id: user?.id || null,
        title: videoInfo.title,
        author: videoInfo.author || null,
        duration: videoInfo.duration || null,
        thumbnail_url: videoInfo.thumbnail || null,
        description: videoInfo.description || null,
        tags: videoInfo.tags || [],
        transcript: transcript,
        topics: topics,
        summary: summary || null,
        suggested_questions: suggestedQuestions || null,
        model_used: model,
        updated_at: new Date().toISOString()
      };

      const upsertResult = await supabase
        .from('video_analyses')
        .upsert(upsertData, {
          onConflict: 'youtube_id',
          ignoreDuplicates: false
        })
        .select('id')
        .single();

      result = upsertResult.data;
      saveError = upsertResult.error;
    }

    if (saveError) {
      console.error('Error saving video analysis:', saveError);
      return NextResponse.json(
        {
          error: 'Failed to save video analysis',
          details: saveError.message
        },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      saved: true,
      data: result
    });

  } catch (error) {
    console.error('Error in save analysis:', error);
    return NextResponse.json(
      { error: 'An error occurred while saving your analysis' },
      { status: 500 }
    );
  }
}

export const POST = withSecurity(handler, SECURITY_PRESETS.PUBLIC);