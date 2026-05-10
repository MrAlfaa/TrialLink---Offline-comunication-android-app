# TrailLink Backend

Node.js and Express backend foundation for TrailLink Phase 01.

## Setup

```powershell
cd backend
cmd /c npm install
Copy-Item .env.example .env
```

Update `backend/.env` with your MongoDB Atlas connection string:

```env
PORT=5001
NODE_ENV=development
MONGO_URI=mongodb+srv://<user>:<password>@<cluster-url>/traillink
JWT_SECRET=replace_with_a_long_secure_random_secret
JWT_EXPIRES_IN=7d
```

## Run

```powershell
cmd /c npm run dev
```

The API will run at `http://localhost:5001`.

## Endpoints

- `GET /`
- `GET /api/health`
- `GET /api/health/ping`
- `GET /api/health/db`
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/groups`
- `GET /api/groups/my`
- `POST /api/groups/join`
- `GET /api/groups/:groupId`
- `GET /api/groups/:groupId/members`
- `GET /api/groups/:groupId/messages`
- `POST /api/groups/:groupId/messages/sync`

`/api/health/db` returns HTTP `503` until `MONGO_URI` is configured and MongoDB Atlas is connected.

Auth and group routes use JSON responses with `{ success, message, data }`. Group routes require `Authorization: Bearer <jwt_token>`.

## Phase 03 Chat

The backend runs Socket.IO on the same host and port as Express:

```text
http://localhost:5001
```

Socket clients authenticate with:

```js
auth: { token: "jwt_token" }
```

Supported events:

- `join_group`
- `leave_group`
- `send_group_message`
- `group_joined`
- `message_sent_ack`
- `new_group_message`
- `socket_error`

Message REST routes are protected and require active group membership:

```http
GET /api/groups/:groupId/messages?page=1&limit=30
POST /api/groups/:groupId/messages/sync
```

MongoDB stores messages in the `messages` collection with `clientMessageId`, `groupId`, `senderId`, `messageType`, `content`, `status`, and timestamps. A unique `{ clientMessageId, senderId }` index prevents duplicate messages when a mobile client retries queued offline messages.

## Phase 02 Smoke Test

Start the backend, then run:

```powershell
cmd /c npm run test:phase02
```

The smoke test registers users, logs in, verifies `/api/auth/me`, creates a group, joins it, checks duplicate joins, lists groups, and loads group members.

## Phase 03 Smoke Test

Start the backend, then run:

```powershell
cmd /c npm run test:phase03
```

The smoke test registers two group members and one stranger, creates a group, verifies socket room joining, sends a live message, checks MongoDB history, checks sync deduplication, and verifies a non-member cannot read the chat.
