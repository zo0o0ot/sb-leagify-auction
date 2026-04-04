# Lessons Learned - Leagify Fantasy Auction

## Overview

This document captures the struggles and lessons learned during development of the Leagify Fantasy Auction system, built with Blazor WebAssembly, Azure Functions, Azure SignalR Service, and Azure SQL Database. The goal is to avoid repeating these mistakes in future projects.

---

## Azure Free Tier Limitations

### SignalR Service - Free Tier

**The Problem:**
- Free tier limit: **20 concurrent connections** and **20,000 messages/day**
- A single auction with 6-8 participants can easily exceed connection limits
- Real-time bidding generates many messages quickly (bid updates, status changes, heartbeats)
- No graceful degradation - once limits hit, connections are refused

**Impact:**
- Cannot run realistic test auctions without hitting limits
- Production use would require paid tier ($50+/month minimum)
- Development testing was constrained and unrealistic

**Lesson:**
- For real-time applications, Azure SignalR free tier is essentially unusable
- Evaluate real-time service costs early, not after building the system
- Consider alternatives with more generous free tiers (Supabase, Firebase, self-hosted Socket.io)

### Azure SQL Database - Serverless

**The Problem:**
- Serverless tier auto-pauses after inactivity to save costs
- Cold start takes 30-60 seconds when database wakes up
- During active development, database stays active = unexpected costs
- Connection cleanup required to allow auto-pause

**Impact:**
- Users experience long delays on first request after inactivity
- Development costs higher than expected due to database staying active
- Required implementing connection cleanup infrastructure (Task 7.1)

**Lesson:**
- Serverless databases have hidden UX costs (cold starts)
- Budget for always-on database or accept cold start delays
- Implement connection cleanup early, not as an afterthought

### Azure Static Web Apps

**The Problem:**
- `/admin` route is reserved by Azure - cannot use for admin interface
- Had to use `/management` instead, causing confusion
- Limited control over routing and middleware

**Impact:**
- Documentation and code had to work around Azure's reserved routes
- Minor but annoying constraint discovered mid-development

**Lesson:**
- Research platform-specific restrictions before designing URL structure
- Test deployment constraints early in development

---

## Testing Failures

### What Went Wrong

**Tests Were Treated as Checkboxes:**
- Tests were written after features, not before or alongside
- Test coverage was uneven - some areas well-tested, others not at all
- When deadlines loomed, testing was skipped "just this once"

**Missing Critical Path Tests:**
- Budget calculation edge cases discovered during user testing
- Bid validation gaps found in live auctions
- Turn advancement bugs not caught until multi-user testing

**Integration Tests Neglected:**
- Unit tests existed but API endpoint behavior wasn't systematically tested
- Errors only discovered when deployed and manually tested

### What Should Have Been Done

**Test-First Development:**
```
1. Write test defining expected behavior
2. Verify test fails
3. Implement feature
4. Verify test passes
5. Commit
```

**Mandatory Pre-Commit Testing:**
```bash
# This should be non-negotiable
dotnet test && dotnet build && git commit
```

**Bug Fix Protocol:**
```
1. Bug reported
2. Write test that reproduces bug (verify it fails)
3. Fix bug
4. Verify test passes
5. Commit test + fix together
```

### Specific Bugs That Tests Should Have Caught

| Bug | Test That Should Have Existed |
|-----|------------------------------|
| Budget calculation wrong with 1 slot remaining | `CalculateMaxBid_OneSlotRemaining_ReturnsFullBudget` |
| User could bid more than MaxBid | `PlaceBid_ExceedsMaxBid_ReturnsError` |
| Turn didn't advance when user had full roster | `AdvanceTurn_UserRosterFull_SkipsToNextUser` |
| Duplicate school names in CSV caused crash | `ImportCsv_DuplicateSchoolNames_ReturnsValidationError` |
| Simultaneous passes caused race condition | `PassOnSchool_AllUsersPassSimultaneously_CompletesOnce` |

---

## Architecture Decisions to Reconsider

### SignalR vs Simpler Real-Time Solutions

**What We Used:** Azure SignalR Service with complex hub methods

**Problems:**
- Tight coupling to Azure ecosystem
- Expensive at scale
- Complex debugging (messages disappear into the cloud)
- Cannot test locally with multiple users

**Alternative Approaches:**
- Supabase Realtime (database change subscriptions)
- Firebase Realtime Database (document listeners)
- Self-hosted Socket.io on Railway/Render/Fly.io

### Blazor WebAssembly Complexity

**What We Used:** Full Blazor WASM with SignalR client integration

**Problems:**
- Large bundle size (~2MB+ initial download)
- Complex state management between SignalR and Blazor components
- Debugging across WASM boundary is difficult
- Limited ecosystem compared to React/Vue

**Alternative Approaches:**
- React/Vue with simpler mental model
- Server-side rendering with real-time sprinkles
- Simpler SPA frameworks with better tooling

### Entity Framework in Azure Functions

**What We Used:** EF Core in Azure Functions with migrations

**Problems:**
- Cold starts compounded by EF initialization
- Migration management in serverless environment is awkward
- Connection pooling issues with serverless

**Alternative Approaches:**
- Direct SQL with Dapper for simpler queries
- Managed database with built-in API (Supabase, Firebase)
- Dedicated API server instead of Functions

---

## Development Process Issues

### Single Environment Strategy

**The Idea:** Use production Azure environment for all testing

**Problems:**
- Test data mixed with real data
- No safe place to experiment
- Breaking changes affected "production" immediately
- Cleanup overhead to remove test auctions

**Better Approach:**
- Local development with test database (SQLite or Docker)
- Staging environment for integration testing
- Production only for real users

### Documentation Drift

**What Happened:**
- Documentation written at start, then not updated
- Features implemented but not documented
- Fields added to database but not to ERD
- Success criteria checkboxes not updated

**Better Approach:**
- Update documentation in same commit as code changes
- Documentation review as part of PR process
- Automated checks for documentation staleness

---

## Cost Surprises

### Expected vs Actual Costs

| Service | Expected (Free Tier) | Actual |
|---------|---------------------|--------|
| SignalR | Free (20 connections) | Unusable for real testing |
| SQL Database | ~$5/month serverless | $15-25/month with activity |
| Static Web Apps | Free | Free (worked as expected) |
| Storage | Free tier | Minimal |

### Hidden Costs

- **Development database activity:** Database stayed active during coding sessions
- **SignalR overage:** Had to upgrade tier for any realistic testing
- **Time cost:** Debugging Azure-specific issues took significant hours

---

## Recommendations for Future Projects

### Choose Hosting Based on Free Tier Generosity

| Service | Free Tier Reality |
|---------|-------------------|
| Supabase | 500MB DB, 5GB bandwidth, 50K MAU - genuinely usable |
| Firebase | 1GB storage, 50K reads/day - watch read limits |
| Railway | $5 free credits/month - small but predictable |
| Render | 750 hours/month - good for small apps |
| Vercel/Netlify | Generous for frontend, limited backend |
| Azure | Free tiers too restrictive for real-time apps |

### Test Locally First, Always

```bash
# Non-negotiable pre-commit workflow
dotnet test           # All tests pass
dotnet build          # No warnings
git commit            # Only then
```

### Budget for Real Costs Early

- Real-time features need paid tiers - budget $20-50/month minimum
- Serverless databases have cold start UX cost
- "Free" often means "free to start, pay to use"

### Keep Documentation Updated

- Update docs in same PR as code changes
- Review documentation monthly for drift
- Use documentation as onboarding test - if new developer is confused, docs need updating

---

## Summary

The biggest lessons:
1. **Azure free tier is not viable for real-time multi-user applications**
2. **Tests must be written before/alongside code, not after**
3. **Local testing should catch 80%+ of bugs before deployment**
4. **Documentation must be updated with every feature change**
5. **Budget for real hosting costs from day one**

These lessons informed the decision to explore alternative tech stacks (Supabase, Firebase, Node.js) that offer more generous free tiers and simpler real-time patterns.
