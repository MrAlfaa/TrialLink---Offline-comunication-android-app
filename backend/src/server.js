const http = require('http');
const app = require('./app');
const { connectDb } = require('./config/db');
const env = require('./config/env');
const { initializeSocket } = require('./socket/socket');

const startServer = async () => {
  await connectDb();

  const server = http.createServer(app);
  initializeSocket(server);

  server.listen(env.port, () => {
    console.log(`TrailLink API running on port ${env.port} (${env.nodeEnv})`);
  });
};

startServer();
