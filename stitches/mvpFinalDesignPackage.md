# Leagify MVP Final Design Package

This package contains the final, school-focused high-fidelity designs for the Leagify Fantasy Auction MVP. These screens follow the "Gridiron Prime" theatrical broadcast aesthetic and the established whole-dollar, school-based bidding rules.

## 1. Entry & Preparation
- **Join Auction Flow ({{DATA:SCREEN:SCREEN_9}}):** The clean, branded entry point for coaches.
- **Auction Lobby - Coach ({{DATA:SCREEN:SCREEN_15}}):** Pre-draft gathering space with a practice bidding zone and dual status indicators.
- **Auction Lobby - Admin ({{DATA:SCREEN:SCREEN_67}}):** The admin's version of the lobby with "Start Draft" controls.

## 2. The Live Draft (The War Room)
- **Live Bidding Console ({{DATA:SCREEN:SCREEN_18}}):** The core interactive dashboard with an "Admin Mode" toggle.
- **"The Pick is In" Sting ({{DATA:SCREEN:SCREEN_21}}):** High-impact broadcast announcement triggered after a win.
- **Position Assignment Modal ({{DATA:SCREEN:SCREEN_22}}):** The decision point for assigning won schools to roster slots.
- **School Nomination Grid ({{DATA:SCREEN:SCREEN_16}}):** Data-rich catalog for selecting the next school to bid on.

## 3. Roster & Standings
- **Roster Dashboard ({{DATA:SCREEN:SCREEN_5}}):** Rectangular 8-slot layout with a "Switch Roster" dropdown for scouting.
- **Post-Auction Predictions ({{DATA:SCREEN:SCREEN_73}}):** The final broadcast-style leaderboard based on projected points.
- **Final Squad Recap ({{DATA:SCREEN:SCREEN_36}}):** The definitive summary of a coach's won schools and total points.
- **Official Draft Log ({{DATA:SCREEN:SCREEN_56}}):** A chronological record of all bids and high/low value highlights.

## 4. Administration & Support
- **System Admin Registry ({{DATA:SCREEN:SCREEN_11}}):** Hub for managing multiple auction instances.
- **Create New Auction ({{DATA:SCREEN:SCREEN_58}}):** The setup wizard with MVP defaults ($200 budget, 6 coaches).
- **Maintain Schools ({{DATA:SCREEN:SCREEN_24}}):** Database manager for school info and icons.
- **Auction Command Center ({{DATA:SCREEN:SCREEN_66}}):** The admin's master control panel for live draft overrides.
- **Auction Rules & Protocol ({{DATA:SCREEN:SCREEN_90}}):** Scannable reference guide for scoring and bidding rules.

## 5. Interactive System States
- **On the Clock Alert ({{DATA:SCREEN:SCREEN_62}}):** Mandatory nomination prompt for the active coach.
- **Out of Budget State ({{DATA:SCREEN:SCREEN_8}}):** Automatic "Pass" locking when $1-per-slot budget reserve is reached.
- **Connection Lost Overlay ({{DATA:SCREEN:SCREEN_6}}):** Thematic "Signal Interrupted" screen for connectivity issues.
