import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { withSecurity, SECURITY_PRESETS } from '@/lib/security-middleware';

async function handler(req: NextRequest) {
  try {
    const {
      videoId,
      summary,
      suggestedQuestions
    } = await req.json();

    if (!videoId) {
      return NextResponse.json(
        { error: 'Video ID is required' },
        { status: 400 }
      );
    }

    const supabase = await createClient();

    // Update the existing video analysis with summary and/or suggested questions
    const updateData: any = {
      updated_at: new Date().toISOString()
    };

    if (summary !== undefined) {
      updateData.summary = summary;
    }

    if (suggestedQuestions !== undefined) {
      updateData.suggested_questions = suggestedQuestions;
    }

    console.log('Attempting to update video analysis:', { videoId, hasSummary: summary !== undefined, hasQuestions: suggestedQuestions !== undefined });

    const { data: updatedVideo, error: updateError } = await supabase
      .from('video_analyses')
      .update(updateData)
      .eq('youtube_id', videoId)
      .select('id, youtube_id, title')
      .single();

    if (updateError) {
      console.error('Error updating video analysis:', {
        error: updateError,
        code: updateError.code,
        details: updateError.details,
        message: updateError.message,
        videoId
      });

      // If no record found, it's not an error - just return success
      if (updateError.code === 'PGRST116') {
        console.log('No existing video analysis found to update, this is ok');
        return NextResponse.json({
          success: true,
          message: 'No existing analysis to update'
        });
      }

      return NextResponse.json(
        {
          error: 'Failed to update video analysis',
          details: updateError.message,
          code: updateError.code
        },
        { status: 500 }
      );
    }

    console.log('Successfully updated video analysis:', { videoId, updatedId: updatedVideo?.id });

    return NextResponse.json({
      success: true,
      data: updatedVideo
    });

  } catch (error) {
    console.error('Error in update video analysis:', error);
    return NextResponse.json(
      { error: 'Failed to process update request' },
      { status: 500 }
    );
  }
}

export const POST = withSecurity(handler, SECURITY_PRESETS.PUBLIC);