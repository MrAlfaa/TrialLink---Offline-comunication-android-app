const cors = require('cors');
const express = require('express');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');

const healthRoutes = require('./routes/health.routes');
const authRoutes = require('./modules/auth/auth.routes');
const groupRoutes = require('./modules/groups/group.routes');
const identityRoutes = require('./modules/identity/identity.routes');
const tripContextRoutes = require('./modules/tripContext/tripContext.routes');
const { errorHandler, notFound } = require('./middleware/error.middleware');

const app = express();

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan('dev'));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

app.get('/', (_req, res) => {
  res.json({ message: 'TrailLink API' });
});

app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/identity', identityRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/trip-context', tripContextRoutes);

app.use(notFound);
app.use(errorHandler);

module.exports = app;
