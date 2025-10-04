const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');
const bcrypt = require('bcrypt');
const sqlite3 = require('sqlite3').verbose();
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const io = socketIO(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Database setup
const db = new sqlite3.Database('./fractured_reality.db', (err) => {
  if (err) {
    console.error('Database error:', err);
  } else {
    console.log('Connected to SQLite database');
    initDatabase();
  }
});

function initDatabase() {
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS friends (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    friend_id TEXT NOT NULL,
    status TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (friend_id) REFERENCES users(id),
    UNIQUE(user_id, friend_id)
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS lobbies (
    id TEXT PRIMARY KEY,
    host_id TEXT NOT NULL,
    host_username TEXT NOT NULL,
    player_count INTEGER NOT NULL,
    max_players INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (host_id) REFERENCES users(id)
  )`);
}

// In-memory store for online users
const onlineUsers = new Map(); // userId -> socketId
const socketToUser = new Map(); // socketId -> userId

// ============ REST API ============

// Register new user
app.post('/api/register', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password required' });
  }

  if (username.length < 3 || username.length > 20) {
    return res.status(400).json({ error: 'Username must be 3-20 characters' });
  }

  if (password.length < 6) {
    return res.status(400).json({ error: 'Password must be at least 6 characters' });
  }

  try {
    const userId = uuidv4();
    const passwordHash = await bcrypt.hash(password, 10);
    const createdAt = Date.now();

    db.run(
      'INSERT INTO users (id, username, password_hash, created_at) VALUES (?, ?, ?, ?)',
      [userId, username, passwordHash, createdAt],
      (err) => {
        if (err) {
          if (err.message.includes('UNIQUE')) {
            return res.status(409).json({ error: 'Username already exists' });
          }
          console.error('Register error:', err);
          return res.status(500).json({ error: 'Server error' });
        }

        res.json({
          success: true,
          user: {
            id: userId,
            username: username
          }
        });
      }
    );
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Server error' });
  }
});

// Login
app.post('/api/login', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password required' });
  }

  db.get('SELECT * FROM users WHERE username = ?', [username], async (err, user) => {
    if (err) {
      console.error('Login error:', err);
      return res.status(500).json({ error: 'Server error' });
    }

    if (!user) {
      return res.status(401).json({ error: 'Invalid username or password' });
    }

    try {
      const match = await bcrypt.compare(password, user.password_hash);
      if (!match) {
        return res.status(401).json({ error: 'Invalid username or password' });
      }

      res.json({
        success: true,
        user: {
          id: user.id,
          username: user.username
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ error: 'Server error' });
    }
  });
});

// Get friends list
app.get('/api/friends/:userId', (req, res) => {
  const { userId } = req.params;

  const query = `
    SELECT u.id, u.username, f.status,
           CASE WHEN f.user_id = ? THEN 'sent' ELSE 'received' END as request_type
    FROM friends f
    JOIN users u ON (
      CASE
        WHEN f.user_id = ? THEN f.friend_id = u.id
        ELSE f.user_id = u.id
      END
    )
    WHERE (f.user_id = ? OR f.friend_id = ?)
  `;

  db.all(query, [userId, userId, userId, userId], (err, friends) => {
    if (err) {
      console.error('Get friends error:', err);
      return res.status(500).json({ error: 'Server error' });
    }

    const friendsList = friends.map(f => ({
      id: f.id,
      username: f.username,
      status: f.status,
      requestType: f.request_type,
      online: onlineUsers.has(f.id)
    }));

    res.json({ friends: friendsList });
  });
});

// Send friend request
app.post('/api/friends/add', (req, res) => {
  const { userId, friendUsername } = req.body;

  if (!userId || !friendUsername) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // Get friend user ID
  db.get('SELECT id FROM users WHERE username = ?', [friendUsername], (err, friend) => {
    if (err) {
      console.error('Add friend error:', err);
      return res.status(500).json({ error: 'Server error' });
    }

    if (!friend) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (friend.id === userId) {
      return res.status(400).json({ error: 'Cannot add yourself as friend' });
    }

    const createdAt = Date.now();

    db.run(
      'INSERT INTO friends (user_id, friend_id, status, created_at) VALUES (?, ?, ?, ?)',
      [userId, friend.id, 'pending', createdAt],
      (err) => {
        if (err) {
          if (err.message.includes('UNIQUE')) {
            return res.status(409).json({ error: 'Friend request already exists' });
          }
          console.error('Add friend error:', err);
          return res.status(500).json({ error: 'Server error' });
        }

        // Notify friend if online
        const friendSocketId = onlineUsers.get(friend.id);
        if (friendSocketId) {
          io.to(friendSocketId).emit('friend_request', {
            userId: userId
          });
        }

        res.json({ success: true });
      }
    );
  });
});

// Accept/reject friend request
app.post('/api/friends/respond', (req, res) => {
  const { userId, friendId, accept } = req.body;

  if (!userId || !friendId || accept === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (accept) {
    db.run(
      'UPDATE friends SET status = ? WHERE user_id = ? AND friend_id = ?',
      ['accepted', friendId, userId],
      (err) => {
        if (err) {
          console.error('Accept friend error:', err);
          return res.status(500).json({ error: 'Server error' });
        }

        // Notify requester if online
        const requesterSocketId = onlineUsers.get(friendId);
        if (requesterSocketId) {
          io.to(requesterSocketId).emit('friend_accepted', {
            userId: userId
          });
        }

        res.json({ success: true });
      }
    );
  } else {
    db.run(
      'DELETE FROM friends WHERE user_id = ? AND friend_id = ?',
      [friendId, userId],
      (err) => {
        if (err) {
          console.error('Reject friend error:', err);
          return res.status(500).json({ error: 'Server error' });
        }
        res.json({ success: true });
      }
    );
  }
});

// Get active lobbies
app.get('/api/lobbies', (req, res) => {
  db.all('SELECT * FROM lobbies ORDER BY created_at DESC', (err, lobbies) => {
    if (err) {
      console.error('Get lobbies error:', err);
      return res.status(500).json({ error: 'Server error' });
    }
    res.json({ lobbies });
  });
});

// ============ WebRTC Signaling (Socket.IO) ============

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  // User authentication
  socket.on('authenticate', (data) => {
    const { userId, username } = data;
    onlineUsers.set(userId, socket.id);
    socketToUser.set(socket.id, { userId, username });
    socket.userId = userId;
    socket.username = username;

    console.log(`User authenticated: ${username} (${userId})`);

    // Notify friends that user is online
    db.all(
      `SELECT friend_id FROM friends WHERE user_id = ? AND status = 'accepted'
       UNION
       SELECT user_id FROM friends WHERE friend_id = ? AND status = 'accepted'`,
      [userId, userId],
      (err, friends) => {
        if (!err && friends) {
          friends.forEach(f => {
            const friendSocketId = onlineUsers.get(f.friend_id || f.user_id);
            if (friendSocketId) {
              io.to(friendSocketId).emit('friend_online', {
                userId: userId,
                username: username
              });
            }
          });
        }
      }
    );
  });

  // Create lobby
  socket.on('create_lobby', (data) => {
    const { userId, username, maxPlayers } = data;
    const lobbyId = uuidv4();

    db.run(
      'INSERT INTO lobbies (id, host_id, host_username, player_count, max_players, created_at) VALUES (?, ?, ?, ?, ?, ?)',
      [lobbyId, userId, username, 1, maxPlayers || 5, Date.now()],
      (err) => {
        if (err) {
          console.error('Create lobby error:', err);
          socket.emit('lobby_error', { error: 'Failed to create lobby' });
          return;
        }

        socket.join(lobbyId);
        socket.lobbyId = lobbyId;

        socket.emit('lobby_created', {
          lobbyId: lobbyId,
          hostId: userId
        });

        console.log(`Lobby created: ${lobbyId} by ${username}`);
      }
    );
  });

  // Join lobby
  socket.on('join_lobby', (data) => {
    const { lobbyId, userId, username } = data;

    db.get('SELECT * FROM lobbies WHERE id = ?', [lobbyId], (err, lobby) => {
      if (err || !lobby) {
        socket.emit('lobby_error', { error: 'Lobby not found' });
        return;
      }

      if (lobby.player_count >= lobby.max_players) {
        socket.emit('lobby_error', { error: 'Lobby is full' });
        return;
      }

      socket.join(lobbyId);
      socket.lobbyId = lobbyId;

      // Update player count
      db.run(
        'UPDATE lobbies SET player_count = player_count + 1 WHERE id = ?',
        [lobbyId],
        (err) => {
          if (err) {
            console.error('Update lobby error:', err);
          }
        }
      );

      // Notify everyone in lobby
      io.to(lobbyId).emit('player_joined', {
        userId: userId,
        username: username
      });

      socket.emit('lobby_joined', {
        lobbyId: lobbyId,
        hostId: lobby.host_id
      });

      console.log(`${username} joined lobby ${lobbyId}`);
    });
  });

  // WebRTC signaling - offer
  socket.on('webrtc_offer', (data) => {
    const { targetId, offer } = data;
    const targetSocketId = onlineUsers.get(targetId);

    if (targetSocketId) {
      io.to(targetSocketId).emit('webrtc_offer', {
        fromId: socket.userId,
        fromUsername: socket.username,
        offer: offer
      });
    }
  });

  // WebRTC signaling - answer
  socket.on('webrtc_answer', (data) => {
    const { targetId, answer } = data;
    const targetSocketId = onlineUsers.get(targetId);

    if (targetSocketId) {
      io.to(targetSocketId).emit('webrtc_answer', {
        fromId: socket.userId,
        answer: answer
      });
    }
  });

  // WebRTC signaling - ICE candidate
  socket.on('webrtc_ice_candidate', (data) => {
    const { targetId, candidate } = data;
    const targetSocketId = onlineUsers.get(targetId);

    if (targetSocketId) {
      io.to(targetSocketId).emit('webrtc_ice_candidate', {
        fromId: socket.userId,
        candidate: candidate
      });
    }
  });

  // Disconnect
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);

    const userData = socketToUser.get(socket.id);
    if (userData) {
      const { userId, username } = userData;
      onlineUsers.delete(userId);
      socketToUser.delete(socket.id);

      // Notify friends that user is offline
      db.all(
        `SELECT friend_id FROM friends WHERE user_id = ? AND status = 'accepted'
         UNION
         SELECT user_id FROM friends WHERE friend_id = ? AND status = 'accepted'`,
        [userId, userId],
        (err, friends) => {
          if (!err && friends) {
            friends.forEach(f => {
              const friendSocketId = onlineUsers.get(f.friend_id || f.user_id);
              if (friendSocketId) {
                io.to(friendSocketId).emit('friend_offline', {
                  userId: userId
                });
              }
            });
          }
        }
      );

      // Clean up lobby if user was in one
      if (socket.lobbyId) {
        db.run('DELETE FROM lobbies WHERE id = ? AND host_id = ?', [socket.lobbyId, userId]);
        io.to(socket.lobbyId).emit('lobby_closed');
      }
    }
  });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Fractured Reality Master Server running on port ${PORT}`);
});
