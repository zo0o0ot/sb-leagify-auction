# Contributing to Leagify Fantasy Auction

## Development Environment Setup (Ubuntu Linux)

### Prerequisites

#### 1. Node.js (v18+)

```bash
# Using NodeSource repository (recommended)
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify
node --version
npm --version
```

#### 2. Docker

```bash
# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2

# Add your user to docker group (avoids needing sudo)
sudo usermod -aG docker $USER

# IMPORTANT: Log out and back in (or reboot) for group membership to take effect
# Verify after re-login:
docker run hello-world
```

#### 3. Git

```bash
sudo apt-get install -y git

# Configure (use your own info)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

#### 4. Playwright System Dependencies

```bash
# Install dependencies for Playwright browsers
sudo apt-get install -y libavif16

# Or install all Playwright deps at once:
sudo npx playwright install-deps
```

#### 5. PostgreSQL Client (optional, for direct DB access)

```bash
sudo apt-get install -y postgresql-client
```

### Project Setup

```bash
# Clone repository
git clone https://github.com/zo0o0ot/sb-leagify-auction.git
cd sb-leagify-auction

# Install dependencies
npm install

# Install Playwright browsers
npx playwright install

# Copy environment file
cp .env.example .env

# Note: The application will refuse to compile or start the dev server
# if required environment variables (e.g. VITE_SUPABASE_URL) are missing.
```

### Start Development

```bash
# Start Supabase (requires Docker)
npm run db:start

# In another terminal, start Vue dev server
npm run dev

# Run tests
npm test
```

## Available Commands

| Command | Purpose |
|---------|---------|
| `npm run dev` | Start Vue dev server (localhost:5173) |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run test:unit` | Run unit tests (Vitest) |
| `npm run test:e2e` | Run E2E tests (Playwright) |
| `npm test` | Run all tests |
| `npm run lint` | Lint and fix code |
| `npm run format` | Format code with Prettier |
| `npm run type-check` | TypeScript type checking |

## Database Commands

| Command | Purpose |
|---------|---------|
| `npm run db:start` | Start local Supabase stack |
| `npm run db:stop` | Stop local Supabase stack |
| `npm run db:reset` | Reset DB with migrations + seed |
| `npm run db:migrate` | Run pending migrations |
| `npm run db:new` | Create a new local migration file |
| `npm run db:diff` | Diff local db changes and generate migration |
| `npm run db:push` | Push local migrations to remote production |

### Direct Database Access

```bash
# Using Docker (no psql install required)
docker exec -i supabase_db_sb-leagify-auction psql -U postgres

# Using psql (if installed)
psql "postgresql://postgres:postgres@localhost:54322/postgres"
```

### Supabase Studio

After running `npm run db:start`, access the database UI at http://localhost:54323

## Development Workflow

This project follows **test-first development**:

1. Write failing test
2. Implement feature
3. Verify test passes
4. Update documentation
5. Commit

**Pre-commit Hooks**:
Husky automatically runs `lint-staged` on your commit, ensuring that only modified files are formatted (Prettier) and linted (ESLint) before code is committed.

**Continuous Integration (CI)**:
A GitHub Actions CI pipeline `.github/workflows/ci.yml` analyzes every PR and push to `main` to ensure unit tests, E2E browser tests, type checking, and linting pass successfully.

## Project Structure

```
sb-leagify-auction/
├── src/
│   ├── components/     # Vue components
│   ├── lib/            # Utilities (Supabase client, etc.)
│   ├── router/         # Vue Router config
│   ├── stores/         # Pinia stores
│   └── views/          # Page components
├── supabase/
│   ├── migrations/     # Database migrations
│   ├── seed.sql        # Development seed data
│   └── config.toml     # Supabase local config
├── e2e/                # Playwright E2E tests
└── tests/              # Unit tests
```

## Seed Data

After running `npm run db:reset`, the database includes:

| Table | Records | Description |
|-------|---------|-------------|
| schools | 20 | College football schools |
| users | 1 | System admin user |
| auctions | 1 | Test auction (join code in seed.sql) |
| teams | 6 | Teams with $200 budget each |
| roster_positions | 5 | SEC, Big Ten, ACC, Big 12, Flex |
| auction_schools | 20 | Schools linked to test auction |
| participants | 1 | Auction master |

## Troubleshooting

### Docker permission denied

If you get "permission denied" errors with Docker:

```bash
# Make sure you're in the docker group
groups

# If docker isn't listed, you need to log out and back in
# after running: sudo usermod -aG docker $USER
```

### Playwright browsers missing

```bash
npx playwright install
```

### Supabase won't start

```bash
# Check Docker is running
docker ps

# If containers are stuck, try:
npm run db:stop
docker system prune -f
npm run db:start
```

### Database connection refused

Make sure Supabase is running:

```bash
npx supabase status
```

If not running, start it:

```bash
npm run db:start
```
