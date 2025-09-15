-- Add missing columns to messages table for voice notes and editing
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'voice_duration') THEN
    ALTER TABLE public.messages ADD COLUMN voice_duration INTEGER;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'messages' AND column_name = 'edited_at') THEN
    ALTER TABLE public.messages ADD COLUMN edited_at TIMESTAMP WITH TIME ZONE;
  END IF;
END$$;

-- Create message_reactions table
CREATE TABLE IF NOT EXISTS public.message_reactions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id UUID NOT NULL,
  user_id UUID NOT NULL,
  emoji TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(message_id, user_id, emoji)
);

-- Create typing_indicators table
CREATE TABLE IF NOT EXISTS public.typing_indicators (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL,
  user_id UUID NOT NULL,
  is_typing BOOLEAN DEFAULT true,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Create user_presence table
CREATE TABLE IF NOT EXISTS public.user_presence (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  status TEXT DEFAULT 'offline',
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create feedback table
CREATE TABLE IF NOT EXISTS public.feedback (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  email TEXT NOT NULL,
  subject TEXT,
  message TEXT NOT NULL,
  rating INTEGER,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create conversation_settings table
CREATE TABLE IF NOT EXISTS public.conversation_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL UNIQUE,
  notifications_enabled BOOLEAN DEFAULT true,
  sound_enabled BOOLEAN DEFAULT true,
  theme TEXT DEFAULT 'default',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security on new tables (safe to run multiple times)
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_settings ENABLE ROW LEVEL SECURITY;

-- Create or replace function to check if user is conversation participant
CREATE OR REPLACE FUNCTION public.is_conversation_participant(conversation_uuid uuid, user_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.conversation_participants 
    WHERE conversation_id = conversation_uuid 
    AND user_id = user_uuid 
    AND left_at IS NULL
  );
END;
$$;

-- Create function to update timestamps if not exists
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Create triggers for new tables (safe with IF NOT EXISTS)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_user_presence_updated_at') THEN
    CREATE TRIGGER update_user_presence_updated_at
      BEFORE UPDATE ON public.user_presence
      FOR EACH ROW
      EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_conversation_settings_updated_at') THEN
    CREATE TRIGGER update_conversation_settings_updated_at
      BEFORE UPDATE ON public.conversation_settings
      FOR EACH ROW
      EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END$$;

-- Create RLS policies with safe IF NOT EXISTS pattern
DO $$
BEGIN
  -- Message reactions policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'message_reactions' AND policyname = 'Users can view reactions on messages they can see') THEN
    CREATE POLICY "Users can view reactions on messages they can see" 
      ON public.message_reactions 
      FOR SELECT 
      USING (EXISTS (
        SELECT 1 FROM messages m
        JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id
        WHERE m.id = message_reactions.message_id 
        AND cp.user_id = auth.uid() 
        AND cp.left_at IS NULL
      ));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'message_reactions' AND policyname = 'Users can add reactions to messages they can see') THEN
    CREATE POLICY "Users can add reactions to messages they can see" 
      ON public.message_reactions 
      FOR INSERT 
      WITH CHECK (
        auth.uid() = user_id 
        AND EXISTS (
          SELECT 1 FROM messages m
          JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id
          WHERE m.id = message_reactions.message_id 
          AND cp.user_id = auth.uid() 
          AND cp.left_at IS NULL
        )
      );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'message_reactions' AND policyname = 'Users can remove their own reactions') THEN
    CREATE POLICY "Users can remove their own reactions" 
      ON public.message_reactions 
      FOR DELETE 
      USING (auth.uid() = user_id);
  END IF;

  -- Typing indicators policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'typing_indicators' AND policyname = 'Users can view typing indicators in their conversations') THEN
    CREATE POLICY "Users can view typing indicators in their conversations" 
      ON public.typing_indicators 
      FOR SELECT 
      USING (is_conversation_participant(conversation_id, auth.uid()));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'typing_indicators' AND policyname = 'Users can update their typing status') THEN
    CREATE POLICY "Users can update their typing status" 
      ON public.typing_indicators 
      FOR INSERT 
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'typing_indicators' AND policyname = 'Users can modify their typing status') THEN
    CREATE POLICY "Users can modify their typing status" 
      ON public.typing_indicators 
      FOR UPDATE 
      USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'typing_indicators' AND policyname = 'Users can remove their typing status') THEN
    CREATE POLICY "Users can remove their typing status" 
      ON public.typing_indicators 
      FOR DELETE 
      USING (auth.uid() = user_id);
  END IF;

  -- User presence policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_presence' AND policyname = 'Users can view all user presence') THEN
    CREATE POLICY "Users can view all user presence" 
      ON public.user_presence 
      FOR SELECT 
      USING (true);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_presence' AND policyname = 'Users can update their own presence') THEN
    CREATE POLICY "Users can update their own presence" 
      ON public.user_presence 
      FOR INSERT 
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'user_presence' AND policyname = 'Users can modify their own presence') THEN
    CREATE POLICY "Users can modify their own presence" 
      ON public.user_presence 
      FOR UPDATE 
      USING (auth.uid() = user_id);
  END IF;

  -- Feedback policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'feedback' AND policyname = 'Users can submit feedback') THEN
    CREATE POLICY "Users can submit feedback" 
      ON public.feedback 
      FOR INSERT 
      WITH CHECK (true);
  END IF;

  -- Conversation settings policies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'conversation_settings' AND policyname = 'Users can view settings for their conversations') THEN
    CREATE POLICY "Users can view settings for their conversations" 
      ON public.conversation_settings 
      FOR SELECT 
      USING (is_conversation_participant(conversation_id, auth.uid()));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'conversation_settings' AND policyname = 'Users can update settings for their conversations') THEN
    CREATE POLICY "Users can update settings for their conversations" 
      ON public.conversation_settings 
      FOR INSERT 
      WITH CHECK (is_conversation_participant(conversation_id, auth.uid()));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'conversation_settings' AND policyname = 'Users can modify settings for their conversations') THEN
    CREATE POLICY "Users can modify settings for their conversations" 
      ON public.conversation_settings 
      FOR UPDATE 
      USING (is_conversation_participant(conversation_id, auth.uid()));
  END IF;
END$$;

-- Safely add new tables to realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'typing_indicators'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.typing_indicators;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'user_presence'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_presence;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'message_reactions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'conversation_participants'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;
  END IF;
END$$;