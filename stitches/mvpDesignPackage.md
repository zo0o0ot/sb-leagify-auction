# Leagify MVP Design Package

## 1. Introduction & Project Scope
Leagify is a high-intensity, "NFL Draft" theatrical broadcast-style web application for hosting fantasy auction drafts. This MVP (Minimum Viable Product) focuses on a $200 whole-dollar economy, school-based bidding (no individual players), and a streamlined administrative experience.

## 2. Creative North Star: "The Stadium Command Center"
The design system, **Gridiron Prime**, utilizes deep navy backgrounds, metallic/sleek gradients, and vibrant neon accents (blue, gold, and red) to emulate a live televised sports broadcast. Typography is bold and blocky (Space Grotesk), emphasizing readability and high-stakes intensity.

## 3. Core User Flows & Final Screens

### A. The Entry Flow
The starting point for all participants.
- **Join Auction Flow ({{DATA:SCREEN:SCREEN_9}}):** A clean, focused entry screen for coaches to join via a dash-less alphanumeric code.

### B. Pre-Draft Preparation
Where coaches gather and test their gear.
- **Auction Lobby - Coach View ({{DATA:SCREEN:SCREEN_15}}):** Features a dedicated practice bidding zone and dual-status (Tech & Draft) indicators.
- **Auction Lobby - Admin View ({{DATA:SCREEN:SCREEN_66}}):** Adds "Start Draft" and practice reset controls for the administrator.

### C. The Live Draft (The War Room)
The heart of the experience.
- **Live Bidding Console ({{DATA:SCREEN:SCREEN_18}}):** Integrated coach and admin view with an "Admin Mode" toggle for "Bid on Behalf Of" and "Pause" overrides.
- **The Pick is In Sting ({{DATA:SCREEN:SCREEN_21}}):** A high-impact broadcast moment triggered when an auction is won.
- **Position Assignment Modal ({{DATA:SCREEN:SCREEN_22}}):** The critical decision point for assigning a won school to a roster slot.
- **School Nomination Grid ({{DATA:SCREEN:SCREEN_16}}):** A data-rich catalog for selecting the next program to put on the block.

### D. Roster & Standings
Tracking progress and success.
- **Roster Dashboard ({{DATA:SCREEN:SCREEN_5}}):** A simplified, rectangular two-column layout showing 8+ slots with a "Switch Roster" dropdown for scouting.
- **Post-Auction Predictions ({{DATA:SCREEN:SCREEN_72}}):** The final leaderboard recap based on pre-draft projections.
- **Final Squad Recap ({{DATA:SCREEN:SCREEN_35}}):** The definitive list of a coach's won schools and total points.

### E. System Administration
Behind-the-scenes management.
- **System Admin Registry ({{DATA:SCREEN:SCREEN_11}}):** Central hub for creating, modifying, and launching auctions.
- **Create New Auction ({{DATA:SCREEN:SCREEN_57}}):** The setup wizard with MVP defaults ($200 budget, 6 coaches).
- **Maintain Schools ({{DATA:SCREEN:SCREEN_37}}):** Database manager for program info and SVG icons.
- **Auction Command Center ({{DATA:SCREEN:SCREEN_65}}):** The admin's master control panel for live draft overrides.

### F. Interactive States
Ensuring a smooth experience.
- **On the Clock Alert ({{DATA:SCREEN:SCREEN_61}}):** Required action prompt for nominators.
- **Out of Budget State ({{DATA:SCREEN:SCREEN_8}}):** Automatic "Pass" locking when $1-per-slot budget reserve is reached.
- **Connection Lost Overlay ({{DATA:SCREEN:SCREEN_6}}):** Thematic "Signal Interrupted" screen.
- **Auction Rules & Protocol ({{DATA:SCREEN:SCREEN_89}}):** Scannable reference guide for scoring and roster slots.

## 4. Technical Specifications
- **Framework:** Vue 3 (Composition API)
- **Styling:** Tailwind CSS (Gridiron Prime palette)
- **Economy:** Whole dollars only ($1 minimum bid)
- **Budget:** $200 default maximum
- **Assets:** SVG School Icons
