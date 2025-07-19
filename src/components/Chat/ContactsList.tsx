import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { UserPlus, Search, MessageSquare } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';

interface Contact {
  id: string;
  user_id: string;
  contact_id: string;
  status: string;
  created_at: string;
  contact_profile?: {
    id: string;
    full_name: string;
    username: string;
    avatar_url: string;
  };
}

interface Profile {
  id: string;
  full_name: string;
  username: string;
  avatar_url: string;
}

export const ContactsList = () => {
  const [contacts, setContacts] = useState<Contact[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [newContactEmail, setNewContactEmail] = useState('');
  const [loading, setLoading] = useState(true);
  const [isAddingContact, setIsAddingContact] = useState(false);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const { user } = useAuth();
  const { toast } = useToast();

  useEffect(() => {
    if (user) {
      fetchContacts();
    }
  }, [user]);

  const fetchContacts = async () => {
    try {
      // Get accepted contacts
      const { data: contactsData, error } = await supabase
        .from('contacts')
        .select('*')
        .eq('user_id', user?.id)
        .eq('status', 'accepted');

      if (error) throw error;

      // Get profiles for each contact
      const contactsWithProfiles = await Promise.all(
        (contactsData || []).map(async (contact) => {
          const { data: profile } = await supabase
            .from('profiles')
            .select('id, full_name, username, avatar_url')
            .eq('user_id', contact.contact_id)
            .single();

          return {
            ...contact,
            contact_profile: profile,
          };
        })
      );

      setContacts(contactsWithProfiles);
    } catch (error) {
      console.error('Error fetching contacts:', error);
      toast({
        title: 'Error',
        description: 'Failed to load contacts',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  const addContact = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newContactEmail.trim()) return;

    setIsAddingContact(true);
    try {
      // First, find the user by username or email
      const { data: profiles, error: profileError } = await supabase
        .from('profiles')
        .select('user_id, full_name, username')
        .or(`username.eq.${newContactEmail},full_name.ilike.%${newContactEmail}%`);

      if (profileError) throw profileError;

      if (!profiles || profiles.length === 0) {
        toast({
          title: 'User not found',
          description: 'No user found with that username or name',
          variant: 'destructive',
        });
        return;
      }

      const contactProfile = profiles[0];

      // Check if contact already exists
      const { data: existingContact } = await supabase
        .from('contacts')
        .select('id')
        .eq('user_id', user?.id)
        .eq('contact_id', contactProfile.user_id)
        .single();

      if (existingContact) {
        toast({
          title: 'Contact exists',
          description: 'This user is already in your contacts',
          variant: 'destructive',
        });
        return;
      }

      // Add contact
      const { error: insertError } = await supabase.from('contacts').insert({
        user_id: user?.id,
        contact_id: contactProfile.user_id,
        status: 'pending',
      });

      if (insertError) throw insertError;

      toast({
        title: 'Contact request sent',
        description: `Contact request sent to ${contactProfile.full_name || contactProfile.username}`,
      });

      setNewContactEmail('');
      setIsDialogOpen(false);
      fetchContacts();
    } catch (error) {
      console.error('Error adding contact:', error);
      toast({
        title: 'Error',
        description: 'Failed to send contact request',
        variant: 'destructive',
      });
    } finally {
      setIsAddingContact(false);
    }
  };

  const startConversation = async (contactId: string) => {
    try {
      // Check if conversation already exists
      const { data: existingConversations } = await supabase
        .from('conversation_participants')
        .select(`
          conversation_id,
          conversations (*)
        `)
        .eq('user_id', user?.id);

      if (existingConversations) {
        for (const conv of existingConversations) {
          const { data: participants } = await supabase
            .from('conversation_participants')
            .select('user_id')
            .eq('conversation_id', conv.conversation_id);

          const participantIds = participants?.map(p => p.user_id) || [];
          
          if (participantIds.length === 2 && participantIds.includes(contactId)) {
            toast({
              title: 'Conversation exists',
              description: 'A conversation with this contact already exists',
            });
            return;
          }
        }
      }

      // Create new conversation
      const { data: conversation, error: convError } = await supabase
        .from('conversations')
        .insert({
          is_group: false,
          created_by: user?.id,
        })
        .select()
        .single();

      if (convError) throw convError;

      // Add participants
      const { error: participantsError } = await supabase
        .from('conversation_participants')
        .insert([
          {
            conversation_id: conversation.id,
            user_id: user?.id,
          },
          {
            conversation_id: conversation.id,
            user_id: contactId,
          },
        ]);

      if (participantsError) throw participantsError;

      toast({
        title: 'Conversation started',
        description: 'You can now chat with this contact',
      });

      // Refresh contacts
      fetchContacts();
    } catch (error) {
      console.error('Error starting conversation:', error);
      toast({
        title: 'Error',
        description: 'Failed to start conversation',
        variant: 'destructive',
      });
    }
  };

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map((n) => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  const filteredContacts = contacts.filter((contact) =>
    contact.contact_profile?.full_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    contact.contact_profile?.username?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className="p-4">
        <div className="space-y-4">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="flex items-center space-x-3 animate-pulse">
              <div className="w-10 h-10 bg-muted rounded-full" />
              <div className="flex-1 space-y-2">
                <div className="h-4 bg-muted rounded w-3/4" />
                <div className="h-3 bg-muted rounded w-1/2" />
              </div>
            </div>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="p-4 border-b border-border">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-semibold text-chat-sidebar-foreground">Contacts</h3>
          <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
            <DialogTrigger asChild>
              <Button size="sm" variant="ghost" className="text-chat-sidebar-foreground hover:bg-chat-sidebar-hover">
                <UserPlus className="h-4 w-4" />
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Add New Contact</DialogTitle>
              </DialogHeader>
              <form onSubmit={addContact} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="contact-email">Username or Name</Label>
                  <Input
                    id="contact-email"
                    type="text"
                    placeholder="Enter username or name"
                    value={newContactEmail}
                    onChange={(e) => setNewContactEmail(e.target.value)}
                    required
                  />
                </div>
                <Button type="submit" className="w-full" disabled={isAddingContact}>
                  {isAddingContact ? 'Sending...' : 'Send Contact Request'}
                </Button>
              </form>
            </DialogContent>
          </Dialog>
        </div>

        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search contacts..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10 bg-background"
          />
        </div>
      </div>

      {/* Contacts List */}
      <div className="flex-1 overflow-y-auto">
        {filteredContacts.length === 0 ? (
          <div className="p-4 text-center text-chat-sidebar-foreground">
            <UserPlus className="h-8 w-8 mx-auto mb-2 opacity-50" />
            <p className="text-sm opacity-75">No contacts yet</p>
            <p className="text-xs opacity-50 mt-1">Add contacts to start chatting</p>
          </div>
        ) : (
          <div className="space-y-1 p-2">
            {filteredContacts.map((contact) => (
              <div
                key={contact.id}
                className="flex items-center justify-between p-3 rounded-lg hover:bg-chat-sidebar-hover"
              >
                <div className="flex items-center space-x-3">
                  <Avatar className="h-10 w-10">
                    <AvatarImage src={contact.contact_profile?.avatar_url || ''} />
                    <AvatarFallback className="bg-primary text-primary-foreground">
                      {getInitials(
                        contact.contact_profile?.full_name || 
                        contact.contact_profile?.username || 
                        'U'
                      )}
                    </AvatarFallback>
                  </Avatar>
                  <div>
                    <p className="font-medium text-chat-sidebar-foreground">
                      {contact.contact_profile?.full_name || contact.contact_profile?.username}
                    </p>
                    <p className="text-sm text-muted-foreground">
                      @{contact.contact_profile?.username}
                    </p>
                  </div>
                </div>
                <Button
                  size="sm"
                  variant="ghost"
                  onClick={() => startConversation(contact.contact_id)}
                  className="text-chat-sidebar-foreground hover:bg-chat-sidebar-hover"
                >
                  <MessageSquare className="h-4 w-4" />
                </Button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};