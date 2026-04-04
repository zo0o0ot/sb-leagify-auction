# Leagify Fantasy Auction

A real-time fantasy auction draft application for sports leagues. Users join via a simple code, bid on schools in real-time, and build their rosters within budget constraints.

## Project Status

**Phase: Implementation In Progress (Phase 1 - Foundation)**

This project is a rebuild of an [earlier Azure-based implementation](https://github.com/zo0o0ot/cl-leagify-fantasy-auction) that proved too expensive and complex. The new version uses Supabase for a simpler, more cost-effective architecture.

## Tech Stack

- **Frontend:** Vue 3 (Composition API) + Vite + Tailwind CSS
- **Backend:** Supabase (PostgreSQL, Realtime, Edge Functions)
- **Hosting:** Vercel
- **Testing:** Vitest, Playwright, pgTAP

## Documentation

### Active Documentation

These documents define the current implementation:

| Document | Description |
|----------|-------------|
| [PRODUCT-DESIGN.md](./PRODUCT-DESIGN.md) | Architecture, user flows, business rules |
| [DATABASE-SCHEMA.md](./DATABASE-SCHEMA.md) | PostgreSQL schema, RLS policies, functions |
| [DEVELOPMENT-TASKS.md](./DEVELOPMENT-TASKS.md) | Phased implementation plan with 32 tasks |
| [TESTING-STRATEGY.md](./TESTING-STRATEGY.md) | Test-first approach, critical path tests |
| [UI-GENERATION-GUIDE.md](./UI-GENERATION-GUIDE.md) | Prompts for AI UI generation tools |

### Legacy Documentation

Reference materials from the previous Azure implementation:

| Document | Description |
|----------|-------------|
| [LEGACY-DATABASE-ERD.md](./LEGACY-DATABASE-ERD.md) | Original Azure SQL schema (12 entities) |
| [LEGACY-LESSONS-LEARNED.md](./LEGACY-LESSONS-LEARNED.md) | What went wrong and why we're rebuilding |
| [LEGACY-TECH-STACK-COMPARISON.md](./LEGACY-TECH-STACK-COMPARISON.md) | Analysis that led to choosing Supabase |

## Key Features

- **Join-code authentication** - No signup required, users join via 6-character code
- **Real-time bidding** - 6-20 concurrent users see updates instantly
- **Budget enforcement** - MaxBid = Budget - (EmptySlots - 1)
- **Position eligibility** - Schools assigned to matching roster positions
- **Auction Master controls** - Pause, override, bid for absent teams
- **CSV import/export** - Import schools, export results

## Getting Started

### Prerequisites

- Node.js 18+
- Docker Desktop (for Supabase local)
- Supabase CLI (`npm install -g supabase`)

### Local Development

```bash
# Clone repository
git clone https://github.com/zo0o0ot/sb-leagify-auction.git
cd sb-leagify-auction

# Install dependencies
npm install

# Start Vue dev server
npm run dev
```

The app will be available at http://localhost:5173

### Available Scripts

```bash
npm run dev          # Start dev server
npm run build        # Build for production
npm run preview      # Preview production build
npm run test:unit    # Run unit tests (Vitest)
npm run test:e2e     # Run E2E tests (Playwright)
npm run lint         # Lint and fix code
npm run format       # Format code with Prettier
npm run type-check   # TypeScript type checking
```

### Supabase Local (coming soon)

```bash
supabase start       # Start local Supabase stack
supabase db reset    # Apply migrations and seed data
supabase stop        # Stop local stack
supabase test db     # Run database tests (pgTAP)
```

## Development Approach

This project follows **test-first development**:

1. Write failing test
2. Implement feature
3. Verify test passes
4. Update documentation
5. Commit

See [TESTING-STRATEGY.md](./TESTING-STRATEGY.md) for details.

## License

MIT
