# UI Generation Guide (for AI Tools like Google Stitch)

Use the following prompts and data payloads to incrementally build the Vue 3 UI for the Leagify Fantasy Auction. 
Provide this document as overall context if the AI tool allows file uploads, or simply copy/paste the individual prompts as you generate each view sequentially.

## 1. Technical & Styling Constraints (System Prompt)

Always provide this baseline constraint to the UI generator so it knows exactly what stack and aesthetic to target:

**Prompt to copy:**
> "I am building a real-time web application for a fantasy auction draft. Please generate UI components using **Vue 3 (Composition API)**, **Tailwind CSS**, and **Headless UI** for accessibility where needed.
>
> **Aesthetic Guidelines:**
> - Feel premium, dynamic, and modern.
> - Default to a sleek dark mode.
> - Incorporate glassmorphism effects for floating panels (like the bidding UI).
> - Use subtle micro-animations/transitions for state changes (e.g., when bids update or a new school is nominated, numbers should smoothly tick or pulse).
> - Typography should be clean and highly readable (use modern sans-serif like Inter, Roboto, or Outfit).
> - Use robust, vibrant accent colors for categorizations (e.g., #DC2626 for SEC, #2563EB for Big Ten). 
> 
> Keep components modular and cleanly separated. Provide clean, ready-to-use `<template>`, `<script setup>`, and `<style>` sections."

### Alternative Aesthetic: "NFL Draft" Theatrical Theme
If you want to emulate the intense, theatrical feel of the NFL Draft, replace the Aesthetic Guidelines above with this:

> **Aesthetic Guidelines (NFL Draft Theme):**
> - The theme must feel highly theatrical, intense, and sporty, mirroring a live televised broadcast (like the NFL Draft).
> - Use deep, rich navy blues or stark blacks for the background with metallic/sleek gradients.
> - Accents should use vibrant, glowing neon blues, bright reds, or gold for high-contrast impact.
> - Typography should be bold, blocky, and industrial (e.g., use Google Fonts like 'Oswald', 'Teko', or heavy weights of 'Roboto Condensed' for headers and numbers).
> - Introduce theatrical UI elements: 'The Pick is In' style banners, a persistent scrolling ticker at the top or bottom, and spotlight or glowing effects behind the active school card.
> - Display player/school profile cards using a 'broadcast chyron' or 'trading card' motif.

---

## 2. View: The Join Flow

**Goal:** Create a simple but beautiful entry point.

**Prompt to copy:**
> "Create the 'Join Auction' view component. This should be a clean, centered card on a modern, dark gradient background. It needs an input for a 6-character 'Join Code' and another input for 'Display Name'. Include a visually distinct 'Join Draft' submit button. Add a subtle hover effect to the button and soft focus rings to the inputs. No actual authentication logic is needed, just accept the props and emit an event on submission."

**State / Mock Data to provide:**
```json
{
  "joinCode": "",
  "displayName": "",
  "hasError": true,
  "errorMsg": "Invalid join code."
}
```

---

## 3. View: Live Auction Lobby - The Bidding Console

**Goal:** This is the core piece of the app. It must look highly interactive.

**Prompt to copy:**
> "Create the core 'Live Auction Bidding Console' component. This is the main interactive dashboard used during the draft. 
> 
> **Layout & Elements:**
> 1. Showcase the 'Active School' prominently (School Name, Logo placeholder, Conference, Projected Points).
> 2. Show the 'Current High Bid' and the name of the winning bidder prominently. Include a glowing or pulsing aesthetic for when this number updates.
> 3. Show the 'Logged-in User Status' including their 'Max Bid' limit softly beneath.
> 4. Display a row of quick-action bidding buttons: '+$1', '+$5', '+$10', 'Custom Input', and 'Pass'.
> 5. Disable bidding buttons if a bid would exceed the user's Max Bid. 
> 6. Below the buttons, show a small status list of opponents (e.g. who is waiting, who has passed, who was auto-passed).
>
> Apply glassmorphism to this bidding card since it anchors the screen."

**State / Mock Data to provide:**
```json
{
  "activeSchool": { "name": "Ohio State", "position": "Big Ten", "projectedPoints": 225 },
  "currentBid": { "amount": 45, "bidder": "Tilo" },
  "user": { "maxBid": 72, "isTurn": false, "hasPassed": false },
  "opponents": [
    { "name": "Sarah", "status": "waiting" },
    { "name": "Ross", "status": "nominated" },
    { "name": "Jordan", "status": "auto-passed (max $40)" }
  ]
}
```

---

## 4. View: Roster and Team Standings Dashboard

**Goal:** Allow users to see their progress and budget cleanly.

**Prompt to copy:**
> "Create a 'Roster Dashboard' component to sit alongside the bidding console. This should gracefully display a team's roster slots and filled players. 
> 
> It should present a list of 'Positions' (e.g. SEC, Big Ten, Flex). For each position:
> - Show if a school has been assigned along with its winning cost.
> - Make empty slots look visibly distinct from filled slots (e.g. dashed borders or faded opacity).
> 
> Include the team name and remaining budget prominently at the top. Utilize the color codes provided in the data payload for position tags."

**State / Mock Data to provide:**
```json
{
  "teamName": "Ross's Squad",
  "remainingBudget": 155,
  "roster": [
    { "slot": "SEC", "filledBy": "Alabama", "cost": 69, "colorCode": "#DC2626" },
    { "slot": "Big Ten", "filledBy": null, "cost": null, "colorCode": "#2563EB" },
    { "slot": "Flex", "filledBy": "Notre Dame", "cost": 25, "colorCode": "#6B7280" }
  ]
}
```

---

## 5. View: School Nomination Grid

**Goal:** Let the nominator browse and select a school to put up for auction.

**Prompt to copy:**
> "Create a 'School Nomination Grid' component for selecting which school to nominate. This appears when it's the user's turn to nominate.
>
> **Layout & Elements:**
> 1. A search/filter bar at the top to filter schools by name or position.
> 2. A grid or list of available schools, each showing: School Name, Logo placeholder, Position (with color badge), and Projected Points.
> 3. Schools should have a hover state and a clear 'Nominate' button or click-to-select behavior.
> 4. Already-drafted schools should NOT appear (they are filtered out).
> 5. Include position filter tabs/buttons (e.g., 'All', 'SEC', 'Big Ten', 'Flex') for quick filtering.
>
> Make this feel like browsing a catalog - clean, scannable, and fast to navigate."

**State / Mock Data to provide:**
```json
{
  "availableSchools": [
    { "id": 1, "name": "Ohio State", "position": "Big Ten", "projectedPoints": 225, "colorCode": "#2563EB" },
    { "id": 2, "name": "Alabama", "position": "SEC", "projectedPoints": 204, "colorCode": "#DC2626" },
    { "id": 3, "name": "Georgia", "position": "SEC", "projectedPoints": 198, "colorCode": "#DC2626" },
    { "id": 4, "name": "Notre Dame", "position": "Flex", "projectedPoints": 101, "colorCode": "#6B7280" },
    { "id": 5, "name": "Michigan", "position": "Big Ten", "projectedPoints": 185, "colorCode": "#2563EB" }
  ],
  "filterPosition": "All",
  "searchQuery": ""
}
```

---

## 6. View: Position Assignment Modal

**Goal:** After winning a bid, the user assigns the school to a roster position.

**Prompt to copy:**
> "Create a 'Position Assignment Modal' component. This appears after a user wins a school and must assign it to their roster.
>
> **Layout & Elements:**
> 1. Display the won school prominently at the top (name, logo placeholder, position, winning bid amount).
> 2. Show a congratulatory message like 'You won [School] for $[Amount]!'
> 3. List available roster positions as selectable options (radio buttons or cards).
> 4. The recommended position should be pre-selected and labeled '(Recommended)'.
> 5. Invalid positions (wrong conference or slot already full) should be visually disabled with a brief explanation.
> 6. Include a 'Confirm Assignment' button at the bottom.
>
> Use a modal or drawer overlay with a semi-transparent backdrop. Keep the focus on the decision."

**State / Mock Data to provide:**
```json
{
  "wonSchool": { "name": "Penn State", "position": "Big Ten", "winningBid": 35 },
  "availablePositions": [
    { "name": "Big Ten", "slotsRemaining": 1, "isEligible": true, "isRecommended": true, "colorCode": "#2563EB" },
    { "name": "SEC", "slotsRemaining": 2, "isEligible": false, "reason": "School is not SEC", "colorCode": "#DC2626" },
    { "name": "Flex", "slotsRemaining": 2, "isEligible": true, "isRecommended": false, "colorCode": "#6B7280" }
  ],
  "selectedPosition": "Big Ten"
}
```

---

## 7. View: Auction Master Controls Panel

**Goal:** Give the Auction Master powerful but clear admin controls.

**Prompt to copy:**
> "Create an 'Auction Master Controls Panel' component. This is a sidebar or collapsible panel visible only to the Auction Master during a live auction.
>
> **Layout & Elements:**
> 1. **Auction Status Controls:** Buttons for 'Pause Auction', 'Resume Auction', 'End Auction Early' (with confirmation).
> 2. **Current Bid Controls:** A 'Force End Bidding' button to immediately close the current school's bidding.
> 3. **Bid on Behalf Of:** A dropdown to select a team, with a toggle for 'Auto-Pass' for that team. When a team is selected, the Auction Master's bid buttons use that team's budget.
> 4. **Participant Status:** A compact list showing all participants with connection status indicators (green dot = connected, red = disconnected).
> 5. **Quick Actions:** Button to 'Reset Practice Bids' (only visible in practice mode).
>
> This panel should feel authoritative but not overwhelming. Use clear iconography and confirm destructive actions."

**State / Mock Data to provide:**
```json
{
  "auctionStatus": "in_progress",
  "selectedTeamToBidFor": null,
  "teams": [
    { "id": 1, "name": "Ross's Team", "autoPassEnabled": false },
    { "id": 2, "name": "Jordan's Team", "autoPassEnabled": true },
    { "id": 3, "name": "Sarah's Team", "autoPassEnabled": false }
  ],
  "participants": [
    { "name": "Ross", "role": "auction_master", "isConnected": true },
    { "name": "Jordan", "role": "team_coach", "isConnected": false },
    { "name": "Sarah", "role": "team_coach", "isConnected": true },
    { "name": "Mike", "role": "viewer", "isConnected": true }
  ]
}
```

---

## 8. View: System Admin Dashboard

**Goal:** Manage all auctions system-wide (for you, the system owner).

**Prompt to copy:**
> "Create a 'System Admin Dashboard' component for managing all auctions across the system.
>
> **Layout & Elements:**
> 1. A data table listing all auctions with columns: Join Code, Auction Name, Status, Teams Count, Created Date, Last Activity.
> 2. Status should be color-coded (e.g., green for 'in_progress', gray for 'completed', yellow for 'draft').
> 3. Row actions: 'View' (opens auction), 'Archive' (for completed), 'Delete' (with confirmation modal).
> 4. Filter controls: Filter by status dropdown, search by name/code.
> 5. Bulk action: 'Delete All Test Auctions' button (auctions with 'TEST' prefix).
> 6. A '+ Create New Auction' button in the header.
>
> This should feel like a professional admin console - clean, dense with information, but well-organized."

**State / Mock Data to provide:**
```json
{
  "auctions": [
    { "id": 1, "joinCode": "ABC123", "name": "2026 NFL Draft League", "status": "completed", "teamsCount": 6, "createdAt": "2026-03-15", "lastActivity": "2026-03-20" },
    { "id": 2, "joinCode": "XYZ789", "name": "Test Auction", "status": "draft", "teamsCount": 2, "createdAt": "2026-04-01", "lastActivity": "2026-04-01" },
    { "id": 3, "joinCode": "DEF456", "name": "Practice Run", "status": "in_progress", "teamsCount": 6, "createdAt": "2026-04-03", "lastActivity": "2026-04-04" }
  ],
  "statusFilter": "all",
  "searchQuery": ""
}
```

---

## 9. View: Auction Lobby / Waiting Room

**Goal:** Pre-auction gathering space where participants verify connections.

**Prompt to copy:**
> "Create an 'Auction Lobby' component for the pre-auction waiting room.
>
> **Layout & Elements:**
> 1. Show auction name and join code prominently at the top.
> 2. List all participants in a card grid or list, showing: Display Name, Role (badge), Team Assignment, Connection Status (icon), Ready Status (checkbox or indicator).
> 3. For Team Coaches: show a 'Ready' toggle button they can click when prepared.
> 4. For Auction Master: show 'Start Practice' and 'Start Auction' buttons (disabled until all coaches are ready).
> 5. A live activity feed or status message area (e.g., 'Sarah just connected', 'Waiting for 2 more players to be ready').
>
> The vibe should be anticipatory - like a pre-game locker room. Show clear progress toward starting."

**State / Mock Data to provide:**
```json
{
  "auctionName": "2026 NFL Draft League",
  "joinCode": "ABC123",
  "currentUserRole": "auction_master",
  "participants": [
    { "name": "Ross", "role": "auction_master", "team": "Team 1", "isConnected": true, "isReady": true },
    { "name": "Tilo", "role": "team_coach", "team": "Team 2", "isConnected": true, "isReady": true },
    { "name": "Sarah", "role": "team_coach", "team": "Team 3", "isConnected": true, "isReady": false },
    { "name": "Jordan", "role": "team_coach", "team": "Team 4", "isConnected": false, "isReady": false },
    { "name": "Mike", "role": "viewer", "team": null, "isConnected": true, "isReady": true }
  ],
  "allCoachesReady": false
}
```

---

# Working with Generated Output

## How to Use Generated Output

AI UI generators produce **visual prototypes**, not production code. Here's how to approach the output:

### What to Keep

| Output | Keep? | Notes |
|--------|-------|-------|
| Tailwind classes | Yes | The styling is the most valuable output |
| Layout structure | Yes | The HTML/template hierarchy is usually good |
| Color choices | Yes | If they match your design system |
| Animations/transitions | Yes | Often better than what you'd write quickly |
| Component logic | Partially | Keep simple computed properties, rewrite complex logic |
| Hardcoded data | No | Replace with props and store bindings |
| Event handlers | No | Rewrite to call your actual functions |

### What to Rewrite

1. **Props & Emits:** AI often uses local state. Convert to proper props/emits for parent-child communication.

2. **Store Integration:** Replace hardcoded data with Pinia store bindings:
   ```typescript
   // Generated (hardcoded)
   const currentBid = ref({ amount: 45, bidder: 'Tilo' })

   // Rewritten (store)
   const auctionStore = useAuctionStore()
   const currentBid = computed(() => auctionStore.currentBid)
   ```

3. **Event Handlers:** Replace stub handlers with real logic:
   ```typescript
   // Generated (stub)
   const handleBid = () => console.log('bid clicked')

   // Rewritten (real)
   const handleBid = async (amount: number) => {
     await auctionStore.placeBid(amount)
   }
   ```

4. **TypeScript Types:** AI often uses `any` or loose types. Add proper interfaces.

---

## Integration Checklist

Use this checklist when bringing generated code into your project:

### Before Starting
- [ ] Screenshot the generated UI for reference
- [ ] Identify which parts you're keeping vs. rewriting
- [ ] Check if similar components already exist in your codebase

### Extracting the Code
- [ ] Create new `.vue` file in appropriate directory (`src/components/` or `src/views/`)
- [ ] Copy template section
- [ ] Copy style section (or extract Tailwind classes)
- [ ] Start fresh with script section (don't copy logic verbatim)

### Adapting the Component
- [ ] Define proper TypeScript interface for props
- [ ] Replace hardcoded data with props
- [ ] Connect to Pinia store where needed
- [ ] Implement real event handlers (emit events or call store actions)
- [ ] Add `data-test` attributes for testing
- [ ] Verify Tailwind classes exist in your config (custom colors, etc.)

### Quality Checks
- [ ] Component renders without errors
- [ ] Props are properly typed
- [ ] Events emit correct payloads
- [ ] Responsive at tablet/desktop breakpoints
- [ ] Keyboard navigation works (focus states, tab order)
- [ ] Screen reader announces content sensibly

### Documentation
- [ ] Add JSDoc comment describing component purpose
- [ ] Document required props
- [ ] Add usage example if complex

---

## Iteration Tips

AI UI generation works best as a conversation. Here's how to iterate effectively:

### Be Specific About Problems

**Bad:** "Make it look better"

**Good:** "The bid buttons are too small on mobile. Increase their touch target to at least 44x44px and add more vertical spacing between them."

### Provide Context When Refining

When asking for changes, include:
1. What you're seeing (paste current code or describe)
2. What's wrong with it
3. What you want instead

**Example:**
> "The current roster grid uses a 3-column layout, but on tablet it gets cramped. Change it to:
> - 1 column on mobile (< 640px)
> - 2 columns on tablet (640-1024px)
> - 3 columns on desktop (> 1024px)"

### Ask for Variations

If you're not sure what style you want:
> "Generate 3 variations of the bid button row:
> 1. Horizontal row with equal-width buttons
> 2. Grid layout with the Pass button separated below
> 3. Floating action bar fixed to the bottom of the screen"

### Build Incrementally

Don't try to generate the entire page at once. Generate pieces and assemble:
1. Generate the school card
2. Generate the bid controls
3. Generate the opponent status list
4. Combine them into the full bidding console

### Save Good Outputs

When you get something you like:
1. Save the screenshot
2. Save the code in a `ui-references/` folder
3. Note what prompt produced it

This helps you reproduce the style for future components.

---

## Prompt Templates for Common Requests

### Requesting a Variant
> "Take the [Component Name] and create a variant that [specific change]. Keep all other styling the same."

### Adding Responsive Behavior
> "Update [Component Name] to be responsive:
> - Mobile (< 640px): [describe layout]
> - Tablet (640-1024px): [describe layout]
> - Desktop (> 1024px): [describe layout]"

### Adding a State
> "Add an [empty/loading/error/disabled] state to [Component Name]. When [condition], show [description of what to display]."

### Matching Existing Style
> "Here is an existing component from my app: [paste code]. Generate a new [Component Name] that matches this visual style exactly, but with [different content/purpose]."

### Extracting a Subcomponent
> "Extract the [specific part] from [Component Name] into its own reusable component. It should accept [props] and emit [events]."
