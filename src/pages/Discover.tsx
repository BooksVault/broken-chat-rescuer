import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Search, UserPlus, MessageSquare, ArrowLeft } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { useNavigate } from 'react-router-dom';

interface UserProfile {
  id: string;
  user_id: string;
  full_name: string;
  username: string;
  avatar_url: string;
  status: string;
  last_seen: string;
}

export const Discover = () => {
  const [users, setUsers] = useState<UserProfile[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [addingContact, setAddingContact] = useState<string | null>(null);
  const { user } = useAuth();
  const { toast } = useToast();
  const navigate = useNavigate();

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .neq('user_id', user?.id)
        .order('full_name');

      if (error) throw error;
      setUsers(data || []);
    } catch (error) {
      console.error('Error fetching users:', error);
      toast({
        title: 'Error',
        description: 'Failed to load users',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  const addContact = async (contactUserId: string, contactName: string) => {
    setAddingContact(contactUserId);
    try {
      // Check if contact already exists
      const { data: existingContact } = await supabase
        .from('contacts')
        .select('id')
        .eq('user_id', user?.id)
        .eq('contact_id', contactUserId)
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
      const { error } = await supabase.from('contacts').insert({
        user_id: user?.id,
        contact_id: contactUserId,
        status: 'accepted', // Auto-accept for discovery
      });

      if (error) throw error;

      toast({
        title: 'Contact added',
        description: `${contactName} has been added to your contacts`,
      });
    } catch (error) {
      console.error('Error adding contact:', error);
      toast({
        title: 'Error',
        description: 'Failed to add contact',
        variant: 'destructive',
      });
    } finally {
      setAddingContact(null);
    }
  };

  const startConversation = async (contactUserId: string, contactName: string) => {
    try {
      // First add as contact if not already
      await addContact(contactUserId, contactName);

      // Create conversation
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
      await supabase.from('conversation_participants').insert([
        {
          conversation_id: conversation.id,
          user_id: user?.id,
        },
        {
          conversation_id: conversation.id,
          user_id: contactUserId,
        },
      ]);

      toast({
        title: 'Conversation started',
        description: `You can now chat with ${contactName}`,
      });

      // Navigate back to main chat
      navigate('/');
    } catch (error) {
      console.error('Error starting conversation:', error);
      toast({
        title: 'Error',
        description: 'Failed to start conversation',
        variant: 'destructive',
      });
    }
  };

  const filteredUsers = users.filter(user =>
    user.full_name?.toLowerCase().includes(searchQuery.toLowerCase()) ||
    user.username?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Available':
        return 'bg-green-500';
      case 'Busy':
        return 'bg-red-500';
      case 'Away':
        return 'bg-yellow-500';
      default:
        return 'bg-gray-500';
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-background p-6">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center space-x-4 mb-6">
            <Button variant="ghost" onClick={() => navigate('/')}>
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Chat
            </Button>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[...Array(6)].map((_, i) => (
              <Card key={i} className="animate-pulse">
                <CardContent className="p-6">
                  <div className="flex items-center space-x-4">
                    <div className="w-16 h-16 bg-muted rounded-full" />
                    <div className="space-y-2">
                      <div className="h-4 bg-muted rounded w-24" />
                      <div className="h-3 bg-muted rounded w-16" />
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center space-x-4">
            <Button variant="ghost" onClick={() => navigate('/')}>
              <ArrowLeft className="h-4 w-4 mr-2" />
              Back to Chat
            </Button>
            <h1 className="text-2xl font-bold">Discover People</h1>
          </div>
        </div>

        {/* Search */}
        <div className="relative mb-6">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Search by name or username..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10"
          />
        </div>

        {/* Users Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredUsers.map((userProfile) => (
            <Card key={userProfile.id} className="hover:shadow-lg transition-shadow">
              <CardHeader className="text-center">
                <div className="relative mx-auto">
                  <Avatar className="h-20 w-20 mx-auto">
                    <AvatarImage src={userProfile.avatar_url || ''} />
                    <AvatarFallback className="bg-primary text-primary-foreground text-lg">
                      {getInitials(userProfile.full_name || userProfile.username || 'U')}
                    </AvatarFallback>
                  </Avatar>
                  <div className={`absolute bottom-0 right-0 w-6 h-6 rounded-full border-2 border-white ${getStatusColor(userProfile.status)}`} />
                </div>
                <CardTitle className="text-lg">{userProfile.full_name}</CardTitle>
                <p className="text-sm text-muted-foreground">@{userProfile.username}</p>
                <Badge variant="secondary" className="w-fit mx-auto">
                  {userProfile.status}
                </Badge>
              </CardHeader>
              <CardContent className="space-y-3">
                <Button
                  onClick={() => addContact(userProfile.user_id, userProfile.full_name)}
                  disabled={addingContact === userProfile.user_id}
                  className="w-full"
                  variant="outline"
                >
                  <UserPlus className="h-4 w-4 mr-2" />
                  {addingContact === userProfile.user_id ? 'Adding...' : 'Add Contact'}
                </Button>
                <Button
                  onClick={() => startConversation(userProfile.user_id, userProfile.full_name)}
                  className="w-full"
                >
                  <MessageSquare className="h-4 w-4 mr-2" />
                  Start Chat
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>

        {filteredUsers.length === 0 && (
          <div className="text-center py-12">
            <Search className="h-16 w-16 mx-auto text-muted-foreground mb-4" />
            <h3 className="text-lg font-semibold mb-2">No users found</h3>
            <p className="text-muted-foreground">
              {searchQuery ? 'Try adjusting your search terms' : 'No users available to discover'}
            </p>
          </div>
        )}
      </div>
    </div>
  );
};