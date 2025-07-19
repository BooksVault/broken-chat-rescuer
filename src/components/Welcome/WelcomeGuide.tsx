import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { UserPlus, Search, MessageSquare, Users } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export const WelcomeGuide = () => {
  const navigate = useNavigate();

  const steps = [
    {
      icon: Search,
      title: 'Discover People',
      description: 'Browse and search for other users already using the platform',
      action: 'Start Discovering',
      onClick: () => navigate('/discover'),
      color: 'text-blue-500',
    },
    {
      icon: UserPlus,
      title: 'Add Contacts',
      description: 'Add people as contacts by searching their username or name',
      action: 'Manage Contacts',
      onClick: () => {}, // This will be handled by the parent
      color: 'text-green-500',
    },
    {
      icon: MessageSquare,
      title: 'Start Chatting',
      description: 'Begin real-time conversations with your contacts',
      action: 'View Chats',
      onClick: () => {}, // This will be handled by the parent
      color: 'text-purple-500',
    },
  ];

  return (
    <div className="max-w-4xl mx-auto p-6">
      <div className="text-center mb-8">
        <h2 className="text-3xl font-bold mb-4">Welcome to Chat Rescuer!</h2>
        <p className="text-lg text-muted-foreground">
          Connect with people and start meaningful conversations
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        {steps.map((step, index) => {
          const Icon = step.icon;
          return (
            <Card key={index} className="hover:shadow-lg transition-shadow">
              <CardHeader className="text-center">
                <div className={`mx-auto mb-4 ${step.color}`}>
                  <Icon className="h-12 w-12" />
                </div>
                <CardTitle className="text-xl">{step.title}</CardTitle>
              </CardHeader>
              <CardContent className="text-center space-y-4">
                <p className="text-muted-foreground">{step.description}</p>
                <Button onClick={step.onClick} className="w-full">
                  {step.action}
                </Button>
              </CardContent>
            </Card>
          );
        })}
      </div>

      <Card className="bg-muted/30">
        <CardContent className="p-6">
          <div className="flex items-center space-x-4">
            <Users className="h-8 w-8 text-primary" />
            <div>
              <h3 className="font-semibold mb-2">How to Connect with Others</h3>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>• Browse the Discover page to see all users</li>
                <li>• Search for specific people by name or username</li>
                <li>• Add them as contacts to start chatting</li>
                <li>• Real-time messaging keeps you connected instantly</li>
              </ul>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
};