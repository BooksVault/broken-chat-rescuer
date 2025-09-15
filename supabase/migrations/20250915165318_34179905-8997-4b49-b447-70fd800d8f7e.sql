-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table for user information
CREATE TABLE public.profiles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  full_name TEXT,
  username TEXT UNIQUE,
  avatar_url TEXT,
  status TEXT DEFAULT 'Available',
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create contacts table
CREATE TABLE public.contacts (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  contact_id UUID NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, contact_id)
);

-- Create conversations table
CREATE TABLE public.conversations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT,
  avatar_url TEXT,
  is_group BOOLEAN DEFAULT false,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create conversation_participants table
CREATE TABLE public.conversation_participants (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL,
  user_id UUID NOT NULL,
  joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  left_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(conversation_id, user_id)
);

-- Create messages table
CREATE TABLE public.messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL,
  sender_id UUID NOT NULL,
  content TEXT,
  message_type TEXT DEFAULT 'text',
  file_url TEXT,
  file_name TEXT,
  file_size INTEGER,
  reply_to UUID,
  voice_duration INTEGER,
  edited_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create message_status table
CREATE TABLE public.message_status (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id UUID NOT NULL,
  user_id UUID NOT NULL,
  status TEXT DEFAULT 'sent',
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(message_id, user_id)
);

-- Create message_reactions table
CREATE TABLE public.message_reactions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  message_id UUID NOT NULL,
  user_id UUID NOT NULL,
  emoji TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(message_id, user_id, emoji)
);

-- Create typing_indicators table
CREATE TABLE public.typing_indicators (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL,
  user_id UUID NOT NULL,
  is_typing BOOLEAN DEFAULT true,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(conversation_id, user_id)
);

-- Create user_presence table
CREATE TABLE public.user_presence (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL UNIQUE,
  status TEXT DEFAULT 'offline',
  last_seen TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create feedback table
CREATE TABLE public.feedback (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  email TEXT NOT NULL,
  subject TEXT,
  message TEXT NOT NULL,
  rating INTEGER,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create conversation_settings table
CREATE TABLE public.conversation_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL UNIQUE,
  notifications_enabled BOOLEAN DEFAULT true,
  sound_enabled BOOLEAN DEFAULT true,
  theme TEXT DEFAULT 'default',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.typing_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_settings ENABLE ROW LEVEL SECURITY;

-- Create function to check if user is conversation participant
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

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SET search_path = public;

-- Create function to handle new user profiles
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (user_id, full_name, username)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'username'
  );
  RETURN new;
END;
$$;

-- Create triggers for updated_at columns
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at
  BEFORE UPDATE ON public.contacts
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_conversations_updated_at
  BEFORE UPDATE ON public.conversations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_messages_updated_at
  BEFORE UPDATE ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_message_status_updated_at
  BEFORE UPDATE ON public.message_status
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

-- Create trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- RLS Policies for profiles
CREATE POLICY "Users can view all profiles" 
  ON public.profiles 
  FOR SELECT 
  USING (true);

CREATE POLICY "Users can insert own profile" 
  ON public.profiles 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own profile" 
  ON public.profiles 
  FOR UPDATE 
  USING (auth.uid() = user_id);

-- RLS Policies for contacts
CREATE POLICY "Users can view their contacts" 
  ON public.contacts 
  FOR SELECT 
  USING ((auth.uid() = user_id) OR (auth.uid() = contact_id));

CREATE POLICY "Users can add contacts" 
  ON public.contacts 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their contact requests" 
  ON public.contacts 
  FOR UPDATE 
  USING ((auth.uid() = user_id) OR (auth.uid() = contact_id));

-- RLS Policies for conversations
CREATE POLICY "Users can view conversations they participate in" 
  ON public.conversations 
  FOR SELECT 
  USING (is_conversation_participant(id, auth.uid()));

CREATE POLICY "Users can create conversations" 
  ON public.conversations 
  FOR INSERT 
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Users can update conversations they created" 
  ON public.conversations 
  FOR UPDATE 
  USING (auth.uid() = created_by);

-- RLS Policies for conversation_participants
CREATE POLICY "Users can view participants in their conversations" 
  ON public.conversation_participants 
  FOR SELECT 
  USING (is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY "Users can add participants to conversations they created" 
  ON public.conversation_participants 
  FOR INSERT 
  WITH CHECK (EXISTS (
    SELECT 1 FROM conversations 
    WHERE id = conversation_id AND created_by = auth.uid()
  ));

-- RLS Policies for messages
CREATE POLICY "Users can view messages in their conversations" 
  ON public.messages 
  FOR SELECT 
  USING (EXISTS (
    SELECT 1 FROM conversation_participants 
    WHERE conversation_id = messages.conversation_id 
    AND user_id = auth.uid() 
    AND left_at IS NULL
  ));

CREATE POLICY "Users can send messages to their conversations" 
  ON public.messages 
  FOR INSERT 
  WITH CHECK (
    auth.uid() = sender_id 
    AND EXISTS (
      SELECT 1 FROM conversation_participants 
      WHERE conversation_id = messages.conversation_id 
      AND user_id = auth.uid() 
      AND left_at IS NULL
    )
  );

-- RLS Policies for message_status
CREATE POLICY "Users can view message status for their messages" 
  ON public.message_status 
  FOR SELECT 
  USING (EXISTS (
    SELECT 1 FROM messages m
    JOIN conversation_participants cp ON m.conversation_id = cp.conversation_id
    WHERE m.id = message_status.message_id 
    AND cp.user_id = auth.uid() 
    AND cp.left_at IS NULL
  ));

CREATE POLICY "Users can update message status" 
  ON public.message_status 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can modify message status" 
  ON public.message_status 
  FOR UPDATE 
  USING (auth.uid() = user_id);

-- RLS Policies for message_reactions
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

CREATE POLICY "Users can remove their own reactions" 
  ON public.message_reactions 
  FOR DELETE 
  USING (auth.uid() = user_id);

-- RLS Policies for typing_indicators
CREATE POLICY "Users can view typing indicators in their conversations" 
  ON public.typing_indicators 
  FOR SELECT 
  USING (is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY "Users can update their typing status" 
  ON public.typing_indicators 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can modify their typing status" 
  ON public.typing_indicators 
  FOR UPDATE 
  USING (auth.uid() = user_id);

CREATE POLICY "Users can remove their typing status" 
  ON public.typing_indicators 
  FOR DELETE 
  USING (auth.uid() = user_id);

-- RLS Policies for user_presence
CREATE POLICY "Users can view all user presence" 
  ON public.user_presence 
  FOR SELECT 
  USING (true);

CREATE POLICY "Users can update their own presence" 
  ON public.user_presence 
  FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can modify their own presence" 
  ON public.user_presence 
  FOR UPDATE 
  USING (auth.uid() = user_id);

-- RLS Policies for feedback
CREATE POLICY "Users can submit feedback" 
  ON public.feedback 
  FOR INSERT 
  WITH CHECK (true);

-- RLS Policies for conversation_settings
CREATE POLICY "Users can view settings for their conversations" 
  ON public.conversation_settings 
  FOR SELECT 
  USING (is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY "Users can update settings for their conversations" 
  ON public.conversation_settings 
  FOR INSERT 
  WITH CHECK (is_conversation_participant(conversation_id, auth.uid()));

CREATE POLICY "Users can modify settings for their conversations" 
  ON public.conversation_settings 
  FOR UPDATE 
  USING (is_conversation_participant(conversation_id, auth.uid()));

-- Enable real-time for all tables
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.typing_indicators;
ALTER PUBLICATION supabase_realtime ADD TABLE public.user_presence;
ALTER PUBLICATION supabase_realtime ADD TABLE public.message_reactions;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;