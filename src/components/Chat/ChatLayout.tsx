import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ConversationsList } from './ConversationsList';
import { WelcomeGuide } from '../Welcome/WelcomeGuide';
import { ChatWindow } from './ChatWindow';
import { ContactsList } from './ContactsList';
import { ProfileSettings } from './ProfileSettings';
import { useAuth } from '@/hooks/useAuth';
import { Button } from '@/components/ui/button';
import { LogOut, MessageSquare, Users, Settings, Search } from 'lucide-react';
import { cn } from '@/lib/utils';

type ActiveView = 'chat' | 'contacts' | 'settings' | 'welcome';

export const ChatLayout = () => {
  const [activeView, setActiveView] = useState<ActiveView>('welcome');
  const [selectedConversationId, setSelectedConversationId] = useState<string | null>(null);
  
  const { signOut } = useAuth();
  const navigate = useNavigate();

  const handleSignOut = async () => {
    await signOut();
  };

  return (
    <div className="flex h-screen bg-background">
      {/* Sidebar */}
      <div className="w-80 bg-chat-sidebar border-r border-border flex flex-col">
        {/* Sidebar Header */}
        <div className="p-4 border-b border-border">
          <div className="flex items-center justify-between">
            <h1 className="text-lg font-semibold text-chat-sidebar-foreground">
              Chat Rescuer
            </h1>
            <div className="flex items-center space-x-2">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate('/discover')}
                className="text-chat-sidebar-foreground hover:bg-chat-sidebar-hover"
                title="Discover People"
              >
                <Search className="h-4 w-4" />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={handleSignOut}
                className="text-chat-sidebar-foreground hover:bg-chat-sidebar-hover"
                title="Sign Out"
              >
                <LogOut className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>

        {/* Navigation */}
        <div className="flex border-b border-border">
          <Button
            variant="ghost"
            className={cn(
              "flex-1 rounded-none text-chat-sidebar-foreground hover:bg-chat-sidebar-hover",
              activeView === 'chat' && "bg-chat-sidebar-hover"
            )}
            onClick={() => setActiveView('chat')}
          >
            <MessageSquare className="h-4 w-4 mr-2" />
            Chats
          </Button>
          <Button
            variant="ghost"
            className={cn(
              "flex-1 rounded-none text-chat-sidebar-foreground hover:bg-chat-sidebar-hover",
              activeView === 'contacts' && "bg-chat-sidebar-hover"
            )}
            onClick={() => setActiveView('contacts')}
          >
            <Users className="h-4 w-4 mr-2" />
            Contacts
          </Button>
          <Button
            variant="ghost"
            className={cn(
              "flex-1 rounded-none text-chat-sidebar-foreground hover:bg-chat-sidebar-hover",
              activeView === 'settings' && "bg-chat-sidebar-hover"
            )}
            onClick={() => setActiveView('settings')}
          >
            <Settings className="h-4 w-4 mr-2" />
            Settings
          </Button>
        </div>

        {/* Sidebar Content */}
        <div className="flex-1 overflow-hidden">
          {activeView === 'welcome' && (
            <div className="p-4 text-center">
              <h3 className="font-semibold text-chat-sidebar-foreground mb-2">Getting Started</h3>
              <p className="text-sm text-muted-foreground mb-4">Welcome to Chat Rescuer! Use the tabs to navigate.</p>
              <Button 
                onClick={() => navigate('/discover')} 
                className="w-full mb-2"
              >
                Discover People
              </Button>
            </div>
          )}
          {activeView === 'chat' && (
            <ConversationsList
              selectedConversationId={selectedConversationId}
              onSelectConversation={setSelectedConversationId}
            />
          )}
          {activeView === 'contacts' && <ContactsList />}
          {activeView === 'settings' && <ProfileSettings />}
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col">
        {activeView === 'welcome' ? (
          <WelcomeGuide />
        ) : selectedConversationId ? (
          <ChatWindow conversationId={selectedConversationId} />
        ) : (
          <div className="flex-1 flex items-center justify-center bg-muted/30">
            <div className="text-center">
              <MessageSquare className="h-16 w-16 mx-auto text-muted-foreground mb-4" />
              <h2 className="text-xl font-semibold text-muted-foreground mb-2">
                Select a conversation
              </h2>
              <p className="text-muted-foreground">
                Choose a conversation from the sidebar to start chatting
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};