const http = require('http');
const app = require('./app');
const { connectDb } = require('./config/db');
const env = require('./config/env');
const { initializeSocket } = require('./socket/socket');

const startServer = async () => {
  await connectDb();

  const server = http.createServer(app);
  initializeSocket(server);

  server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
      console.error(
        `Port ${env.port} is already in use. Set PORT to a free port in backend/.env or stop the process using that port.`,
      );
      process.exit(1);
    }
    console.error('Backend server failed to start:', error);
    process.exit(1);
  });

  server.listen(env.port, () => {
    console.log(`TrailLink API running on port ${env.port} (${env.nodeEnv})`);
  });
};

startServer();
