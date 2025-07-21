-- Clear all user data to start fresh
-- Delete all data from related tables in proper order (respecting foreign keys)

-- Delete message status first
DELETE FROM public.message_status;

-- Delete messages
DELETE FROM public.messages;

-- Delete conversation participants
DELETE FROM public.conversation_participants;

-- Delete conversations
DELETE FROM public.conversations;

-- Delete contacts
DELETE FROM public.contacts;

-- Delete profiles
DELETE FROM public.profiles;

-- Delete users from auth.users (this will cascade to other tables if needed)
-- Note: This requires special permissions and will clear all authentication data
DELETE FROM auth.users;