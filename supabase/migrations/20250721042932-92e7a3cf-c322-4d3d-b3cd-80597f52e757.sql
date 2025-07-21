-- Add essential tables and features for production-ready chat
-- 1. Enable realtime for all chat tables
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.conversations REPLICA IDENTITY FULL;
ALTER TABLE public.conversation_participants REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;

-- Add tables to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;

-- 2. Add message reactions table
CREATE TABLE public.message_reactions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  emoji text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(message_id, user_id, emoji)
);

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

-- RLS policies for message reactions
CREATE POLICY "Users can view reactions in their conversations"
ON public.message_reactions FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.conversation_participants cp ON m.conversation_id = cp.conversation_id
    WHERE m.id = message_reactions.message_id 
    AND cp.user_id = auth.uid() 
    AND cp.left_at IS NULL
  )
);

CREATE POLICY "Users can add reactions to messages in their conversations"
ON public.message_reactions FOR INSERT
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.conversation_participants cp ON m.conversation_id = cp.conversation_id
    WHERE m.id = message_reactions.message_id 
    AND cp.user_id = auth.uid() 
    AND cp.left_at IS NULL
  )
);

CREATE POLICY "Users can delete their own reactions"
ON public.message_reactions FOR DELETE
USING (auth.uid() = user_id);

-- 3. Add typing indicators table
CREATE TABLE public.typing_indicators (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  is_typing boolean NOT NULL DEFAULT false,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;

-- RLS policies for typing indicators
CREATE POLICY "Users can view typing in their conversations"
ON public.typing_indicators FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.conversation_participants cp
    WHERE cp.conversation_id = typing_indicators.conversation_id 
    AND cp.user_id = auth.uid() 
    AND cp.left_at IS NULL
  )
);

CREATE POLICY "Users can update their typing status"
ON public.typing_indicators FOR INSERT
WITH CHECK (
  auth.uid() = user_id AND
  EXISTS (
    SELECT 1 FROM public.conversation_participants cp
    WHERE cp.conversation_id = typing_indicators.conversation_id 
    AND cp.user_id = auth.uid() 
    AND cp.left_at IS NULL
  )
);

CREATE POLICY "Users can update their own typing status"
ON public.typing_indicators FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own typing status"
ON public.typing_indicators FOR DELETE
USING (auth.uid() = user_id);

-- 4. Add message edits table for edit history
CREATE TABLE public.message_edits (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id uuid NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  original_content text NOT NULL,
  edited_content text NOT NULL,
  edited_at timestamp with time zone NOT NULL DEFAULT now(),
  edited_by uuid NOT NULL
);

ALTER TABLE public.message_edits ENABLE ROW LEVEL SECURITY;

-- RLS policies for message edits
CREATE POLICY "Users can view edit history in their conversations"
ON public.message_edits FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.conversation_participants cp ON m.conversation_id = cp.conversation_id
    WHERE m.id = message_edits.message_id 
    AND cp.user_id = auth.uid() 
    AND cp.left_at IS NULL
  )
);

CREATE POLICY "Users can create edit history for their messages"
ON public.message_edits FOR INSERT
WITH CHECK (
  auth.uid() = edited_by AND
  EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.id = message_edits.message_id 
    AND m.sender_id = auth.uid()
  )
);

-- 5. Add feedback table
CREATE TABLE public.feedback (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid,
  email text,
  subject text NOT NULL,
  message text NOT NULL,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  status text NOT NULL DEFAULT 'pending',
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- RLS policies for feedback
CREATE POLICY "Users can submit feedback"
ON public.feedback FOR INSERT
WITH CHECK (
  (auth.uid() IS NULL AND email IS NOT NULL) OR 
  (auth.uid() = user_id)
);

CREATE POLICY "Users can view their own feedback"
ON public.feedback FOR SELECT
USING (auth.uid() = user_id);

-- 6. Add user presence table
CREATE TABLE public.user_presence (
  user_id uuid NOT NULL PRIMARY KEY,
  status text NOT NULL DEFAULT 'offline',
  last_seen timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;

-- RLS policies for user presence
CREATE POLICY "Users can view all presence"
ON public.user_presence FOR SELECT
USING (true);

CREATE POLICY "Users can update their own presence"
ON public.user_presence FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own presence status"
ON public.user_presence FOR UPDATE
USING (auth.uid() = user_id);

-- 7. Add voice notes support (extend messages table)
ALTER TABLE public.messages ADD COLUMN duration_seconds integer;
ALTER TABLE public.messages ADD COLUMN is_voice_note boolean DEFAULT false;

-- 8. Add edited flag to messages
ALTER TABLE public.messages ADD COLUMN is_edited boolean DEFAULT false;
ALTER TABLE public.messages ADD COLUMN edited_at timestamp with time zone;

-- 9. Add conversation settings
CREATE TABLE public.conversation_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  notifications_enabled boolean NOT NULL DEFAULT true,
  sound_enabled boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

ALTER TABLE public.conversation_settings ENABLE ROW LEVEL SECURITY;

-- RLS policies for conversation settings
CREATE POLICY "Users can manage their conversation settings"
ON public.conversation_settings FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 10. Create triggers for automatic timestamp updates
CREATE TRIGGER update_typing_indicators_updated_at
  BEFORE UPDATE ON public.typing_indicators
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_presence_updated_at
  BEFORE UPDATE ON public.user_presence
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_conversation_settings_updated_at
  BEFORE UPDATE ON public.conversation_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_feedback_updated_at
  BEFORE UPDATE ON public.feedback
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();