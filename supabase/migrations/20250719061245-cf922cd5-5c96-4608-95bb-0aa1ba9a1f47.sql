-- Fix RLS policies for proper chat functionality

-- Update conversations policies to allow participants to view conversations
DROP POLICY IF EXISTS "Users can view conversations they participate in" ON public.conversations;
CREATE POLICY "Users can view conversations they participate in" 
ON public.conversations 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.conversation_participants 
    WHERE conversation_id = conversations.id 
    AND user_id = auth.uid() 
    AND left_at IS NULL
  )
);

-- Allow users to create conversations
DROP POLICY IF EXISTS "Users can create conversations" ON public.conversations;
CREATE POLICY "Users can create conversations" 
ON public.conversations 
FOR INSERT 
WITH CHECK (auth.uid() = created_by);

-- Allow conversation creators to update conversations
DROP POLICY IF EXISTS "Users can update conversations they created" ON public.conversations;
CREATE POLICY "Users can update conversations they created" 
ON public.conversations 
FOR UPDATE 
USING (auth.uid() = created_by);

-- Fix conversation participants policies
DROP POLICY IF EXISTS "Users can add participants to conversations they created" ON public.conversation_participants;
CREATE POLICY "Users can add participants to conversations they created" 
ON public.conversation_participants 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.conversations 
    WHERE id = conversation_id 
    AND created_by = auth.uid()
  )
  OR 
  user_id = auth.uid()
);

-- Enable realtime for all chat tables
ALTER TABLE public.conversations REPLICA IDENTITY FULL;
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.conversation_participants REPLICA IDENTITY FULL;
ALTER TABLE public.profiles REPLICA IDENTITY FULL;
ALTER TABLE public.contacts REPLICA IDENTITY FULL;

-- Add tables to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.conversation_participants;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
ALTER PUBLICATION supabase_realtime ADD TABLE public.contacts;