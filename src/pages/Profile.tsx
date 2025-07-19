import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '@/integrations/supabase/client';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { ArrowLeft, MessageSquare, UserPlus, Calendar } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import { format } from 'date-fns';

interface UserProfile {
  id: string;
  user_id: string;
  full_name: string;
  username: string;
  avatar_url: string;
  status: string;
  last_seen: string;
  created_at: string;
}

export const Profile = () => {
  const { userId } = useParams();
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [isContact, setIsContact] = useState(false);
  const [addingContact, setAddingContact] = useState(false);
  const { user } = useAuth();
  const { toast } = useToast();
  const navigate = useNavigate();

  useEffect(() => {
    if (userId) {
      fetchProfile();
      checkIfContact();
    }
  }, [userId]);

  const fetchProfile = async () => {
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .eq('user_id', userId)
        .single();

      if (error) throw error;
      setProfile(data);
    } catch (error) {
      console.error('Error fetching profile:', error);
      toast({
        title: 'Error',
        description: 'Failed to load profile',
        variant: 'destructive',
      });
    } finally {
      setLoading(false);
    }
  };

  const checkIfContact = async () => {
    try {
      const { data } = await supabase
        .from('contacts')
        .select('id')
        .eq('user_id', user?.id)
        .eq('contact_id', userId)
        .single();

      setIsContact(!!data);
    } catch (error) {
      // Not a contact, which is fine
      setIsContact(false);
    }
  };

  const addContact = async () => {
    if (!profile) return;
    
    setAddingContact(true);
    try {
      const { error } = await supabase.from('contacts').insert({
        user_id: user?.id,
        contact_id: profile.user_id,
        status: 'accepted',
      });

      if (error) throw error;

      setIsContact(true);
      toast({
        title: 'Contact added',
        description: `${profile.full_name} has been added to your contacts`,
      });
    } catch (error) {
      console.error('Error adding contact:', error);
      toast({
        title: 'Error',
        description: 'Failed to add contact',
        variant: 'destructive',
      });
    } finally {
      setAddingContact(false);
    }
  };

  const startConversation = async () => {
    if (!profile) return;

    try {
      // Add as contact first if not already
      if (!isContact) {
        await addContact();
      }

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
          user_id: profile.user_id,
        },
      ]);

      toast({
        title: 'Conversation started',
        description: `You can now chat with ${profile.full_name}`,
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
        <div className="max-w-2xl mx-auto">
          <Button variant="ghost" onClick={() => navigate(-1)} className="mb-6">
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back
          </Button>
          <Card className="animate-pulse">
            <CardContent className="p-8 text-center">
              <div className="w-32 h-32 bg-muted rounded-full mx-auto mb-4" />
              <div className="h-6 bg-muted rounded w-48 mx-auto mb-2" />
              <div className="h-4 bg-muted rounded w-32 mx-auto" />
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-background p-6">
        <div className="max-w-2xl mx-auto">
          <Button variant="ghost" onClick={() => navigate(-1)} className="mb-6">
            <ArrowLeft className="h-4 w-4 mr-2" />
            Back
          </Button>
          <Card>
            <CardContent className="p-8 text-center">
              <h3 className="text-lg font-semibold mb-2">Profile not found</h3>
              <p className="text-muted-foreground">The user profile you're looking for doesn't exist.</p>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background p-6">
      <div className="max-w-2xl mx-auto">
        {/* Header */}
        <Button variant="ghost" onClick={() => navigate(-1)} className="mb-6">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back
        </Button>

        {/* Profile Card */}
        <Card>
          <CardHeader className="text-center pb-2">
            <div className="relative mx-auto">
              <Avatar className="h-32 w-32 mx-auto">
                <AvatarImage src={profile.avatar_url || ''} />
                <AvatarFallback className="bg-primary text-primary-foreground text-3xl">
                  {getInitials(profile.full_name || profile.username || 'U')}
                </AvatarFallback>
              </Avatar>
              <div className={`absolute bottom-2 right-2 w-8 h-8 rounded-full border-4 border-white ${getStatusColor(profile.status)}`} />
            </div>
          </CardHeader>
          <CardContent className="text-center space-y-6">
            <div>
              <CardTitle className="text-2xl mb-2">{profile.full_name}</CardTitle>
              <p className="text-muted-foreground text-lg">@{profile.username}</p>
              <Badge variant="secondary" className="mt-2">
                {profile.status}
              </Badge>
            </div>

            <div className="flex items-center justify-center text-sm text-muted-foreground">
              <Calendar className="h-4 w-4 mr-2" />
              Joined {format(new Date(profile.created_at), 'MMMM yyyy')}
            </div>

            {profile.last_seen && (
              <div className="text-sm text-muted-foreground">
                Last seen {format(new Date(profile.last_seen), 'PPp')}
              </div>
            )}

            {/* Action Buttons */}
            <div className="flex space-x-4 pt-4">
              {!isContact && (
                <Button
                  onClick={addContact}
                  disabled={addingContact}
                  variant="outline"
                  className="flex-1"
                >
                  <UserPlus className="h-4 w-4 mr-2" />
                  {addingContact ? 'Adding...' : 'Add Contact'}
                </Button>
              )}
              
              <Button onClick={startConversation} className="flex-1">
                <MessageSquare className="h-4 w-4 mr-2" />
                {isContact ? 'Send Message' : 'Start Chat'}
              </Button>
            </div>

            {isContact && (
              <div className="text-sm text-green-600 font-medium">
                ✓ Already in your contacts
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
};