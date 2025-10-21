import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { withSecurity, SECURITY_PRESETS } from '@/lib/security-middleware';
import { z } from 'zod';

const updateQuestionsSchema = z.object({
  videoId: z.string().min(1, 'Video ID is required'),
  suggestedQuestions: z.array(z.string())
});

async function handler(req: NextRequest) {
  try {
    const body = await req.json();

    let validatedData;
    try {
      validatedData = updateQuestionsSchema.parse(body);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return NextResponse.json(
          {
            error: 'Validation failed',
            details: error.errors
          },
          { status: 400 }
        );
      }
      throw error;
    }

    const { videoId, suggestedQuestions } = validatedData;

    const supabase = await createClient();

    // Try the specialized function first
    try {
      const { data, error } = await supabase
        .rpc('update_suggested_questions', {
          p_youtube_id: videoId,
          p_suggested_questions: suggestedQuestions
        });

      if (error) {
        throw error;
      }

      return NextResponse.json({
        success: true,
        updated: data
      });
    } catch (rpcError) {
      console.warn('RPC function failed, using direct update:', rpcError);

      // Fallback to direct update
      const { data: updateData, error: updateError } = await supabase
        .from('video_analyses')
        .update({
          suggested_questions: suggestedQuestions,
          updated_at: new Date().toISOString()
        })
        .eq('youtube_id', videoId)
        .select('id')
        .single();

      if (updateError) {
        console.error('Error updating suggested questions:', updateError);
        return NextResponse.json(
          {
            error: 'Failed to update suggested questions',
            details: updateError.message
          },
          { status: 500 }
        );
      }

      return NextResponse.json({
        success: true,
        updated: true,
        data: updateData
      });
    }

  } catch (error) {
    console.error('Error in update suggested questions:', error);
    return NextResponse.json(
      { error: 'Failed to process request' },
      { status: 500 }
    );
  }
}

export const POST = withSecurity(handler, SECURITY_PRESETS.PUBLIC);