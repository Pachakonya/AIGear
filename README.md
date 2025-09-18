## GearAI

AI-powered hiking assistant with iOS (SwiftUI) frontend and FastAPI backend. Features include authentication (email + OAuth), AI gear and hike suggestions, trail upload, websocket chat, and profile setup.

### Tech Stack
- Backend: FastAPI, Uvicorn, SQLAlchemy, Alembic, PostgreSQL, Redis, Celery, Flower
- Integrations: OpenAI, SMTP (Gmail/SendGrid), Google OAuth, OpenWeatherMap, Google Places
- Frontend (iOS): SwiftUI, URLSession networking, optional WebSocket client

---

## Backend
Location: `back/AIgyr`

### Prerequisites
- Python 3.10
- Docker and Docker Compose (recommended)
- Alternatively: local PostgreSQL and Redis

### Environment Variables
Create `back/AIgyr/.env` from `env.example` and fill values:

```env
# Database
DATABASE_URL=postgresql://username:password@localhost:5432/aigyr_db

# JWT
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080

# SMTP (for email verification)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_APP_PASSWORD=your-gmail-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false

# Email verification
EMAIL_VERIFICATION_VERIFICATION_CODE_LENGTH=6
EMAIL_VERIFICATION_VERIFICATION_CODE_EXPIRY_MINUTES=10
EMAIL_VERIFICATION_EMAIL_SUBJECT=Your Verification Code

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# OpenAI
OPENAI_API_KEY=your-openai-api-key

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

# External APIs
OPENWEATHER_API_KEY=your-openweathermap-api-key
GOOGLE_PLACES_API_KEY=your-google-places-api-key
```

### Run with Docker (recommended)
From `back/AIgyr`:

```bash
docker compose up --build
```

Services started:
- API: `http://localhost:8000`
- Postgres: `localhost:5433` (container port 5432)
- Redis: `localhost:6379`
- Celery worker and Flower (monitor): `http://localhost:5555`

Alembic migrations run via the `alembic` service automatically. To re-run manually:

```bash
docker compose run --rm alembic alembic upgrade head
```

### Run locally without Docker
From `back/AIgyr`:

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Ensure Postgres and Redis are running locally, then:
alembic upgrade head

uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload
```

### Notable Endpoints
- `GET /` health
- Auth: `POST /auth/register`, `POST /auth/login`, `POST /auth/send-code`, `POST /auth/verify-code`, `GET /auth/me`, `PUT /auth/profile`, `DELETE /auth/delete-account`, `POST /auth/google`, `POST /auth/apple`
- AI Engine: `POST /aiengine/gear-recommend`, `POST /aiengine/gear-and-hike-suggest`, `POST /aiengine/orchestrate`
- Peaks: mounted under `/peaks` (browse for filters/listing)
- WebSocket: `ws://<host>:8000/ws`
- Static legal pages: `GET /privacy-policy`, `GET /terms-of-service`

---

## iOS App (SwiftUI)
Location: `SwiftUIFront/AIGear`

### Requirements
- Xcode 15+
- iOS 17+ (recommended target)

### Configure API Base URL
Update the backend URL in these files if you are not using the default/hotspot IP:
- `AIGear/Network/NetworkService.swift` → `baseURL`
- `AIGear/Services/Auth/AuthService.swift` → `baseURL`

Example for local simulator connecting to Docker on the host:

```swift
private let baseURL = "http://localhost:8000"
```

If running on a physical device, set `baseURL` to your machine’s LAN IP, e.g. `http://192.168.1.10:8000`.

### Build & Run
1. Open `SwiftUIFront/AIGear/AIGear.xcodeproj` in Xcode
2. Select a simulator or your device
3. Build and run

## Demo

[![Demo Video](https://i.ytimg.com/vi/cvGSj4qQYmc/hqdefault.jpg)](https://youtube.com/shorts/cvGSj4qQYmc?feature=share)

*Click the image above to watch the demo video*

### Features
- Email/password sign up and login, email verification flow
- Google/Apple sign-in endpoints supported on backend
- AI gear and hike suggestions (calls `/aiengine/*`)
- Trail data upload
- Profile setup and update (`/auth/profile`)
- Optional WebSocket chat (`/ws`) – client scaffold present

---

## Development Notes
- CORS is open for development. Restrict `allow_origins` in `src/main.py` for production.
- Legal documents are served from `back/AIgyr/static/legal`.
- Background jobs use Celery + Redis; monitor with Flower (`:5555`).

## Testing
- Python tests: `pytest` (backend)

## License
Proprietary – All rights reserved.
