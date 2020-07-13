const express = require('express');
const http = require('http');
const socketio = require('socket.io');
const socketRedis = require('socket.io-redis');
const gracefulShutdown = require('http-graceful-shutdown');
const getenv = require('getenv');
const os = require('os');

const app = express();
const port = getenv.int('PORT');

const server = http.createServer(app);

// Serve static files for simple UI
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => res.send('Healthy'));

const io = socketio(server);

// Handling multiple nodes: https://socket.io/docs/using-multiple-nodes/
io.adapter(socketRedis({ host: getenv('REDIS_HOST'), port: getenv('REDIS_PORT') }));

// Socket emit
io.on('connection', (socket) => socket.emit('hostname', os.hostname()));

// Start server
server.listen(port, () => console.log(`app listening at http://localhost:${port}`));

// Handle SIGINT or SIGTERM and drain connections
gracefulShutdown(server);
