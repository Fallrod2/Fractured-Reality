# Fractured Reality Master Server

Node.js backend server for account management, friends system, and WebRTC signaling.

## Features

- User registration and login
- Friends system (add, accept, reject)
- Online status tracking
- WebRTC signaling for P2P connections
- Lobby management

## Local Development

```bash
cd server
npm install
npm start
```

Server runs on `http://localhost:3000`

## Free Deployment Options

### Option 1: Render.com (Recommended)
1. Create account at https://render.com
2. Click "New +" → "Web Service"
3. Connect your GitHub repo
4. Settings:
   - Root Directory: `server`
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Instance Type: Free
5. Click "Create Web Service"
6. Copy the URL (e.g., `https://fractured-reality.onrender.com`)

### Option 2: Railway.app
1. Create account at https://railway.app
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your repo
4. Settings:
   - Root Directory: `server`
   - Start Command: `npm start`
5. Copy the URL

### Option 3: Fly.io
1. Install flyctl: https://fly.io/docs/hands-on/install-flyctl/
2. Login: `fly auth login`
3. Deploy:
```bash
cd server
fly launch
```

## Environment Variables

No environment variables required for basic setup. Database is SQLite (file-based).

## API Endpoints

### Authentication
- `POST /api/register` - Register new user
- `POST /api/login` - Login

### Friends
- `GET /api/friends/:userId` - Get friends list
- `POST /api/friends/add` - Send friend request
- `POST /api/friends/respond` - Accept/reject friend request

### Lobbies
- `GET /api/lobbies` - Get active lobbies

### WebSocket Events (Socket.IO)

**Client → Server:**
- `authenticate` - Authenticate user
- `create_lobby` - Create game lobby
- `join_lobby` - Join existing lobby
- `webrtc_offer` - Send WebRTC offer
- `webrtc_answer` - Send WebRTC answer
- `webrtc_ice_candidate` - Send ICE candidate

**Server → Client:**
- `friend_request` - New friend request received
- `friend_accepted` - Friend request accepted
- `friend_online` - Friend came online
- `friend_offline` - Friend went offline
- `lobby_created` - Lobby created successfully
- `lobby_joined` - Joined lobby successfully
- `player_joined` - Another player joined lobby
- `lobby_closed` - Lobby was closed
- `lobby_error` - Error with lobby operation
- `webrtc_offer` - Received WebRTC offer
- `webrtc_answer` - Received WebRTC answer
- `webrtc_ice_candidate` - Received ICE candidate

## Database Schema

**users**
- id (TEXT PRIMARY KEY)
- username (TEXT UNIQUE)
- password_hash (TEXT)
- created_at (INTEGER)

**friends**
- id (INTEGER PRIMARY KEY)
- user_id (TEXT)
- friend_id (TEXT)
- status (TEXT: 'pending' or 'accepted')
- created_at (INTEGER)

**lobbies**
- id (TEXT PRIMARY KEY)
- host_id (TEXT)
- host_username (TEXT)
- player_count (INTEGER)
- max_players (INTEGER)
- created_at (INTEGER)
