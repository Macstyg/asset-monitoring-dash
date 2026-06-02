# Portfolio Presentation Guide

This guide is a practical talk track for presenting Asset Risk Cockpit as a
fullstack Phoenix LiveView portfolio project.

## One-Minute Pitch

Asset Risk Cockpit is a realtime risk dashboard for fictional cross-chain game
assets used as loan collateral.

The demo shows a complete operational loop:

1. Assets and market history are seeded in Postgres.
2. A supervised simulator applies a scenario.
3. The backend persists scenario, activity, and review-state changes.
4. Phoenix PubSub updates the dashboard and detail page.
5. An operator inspects the affected asset and records a decision.
6. The audit trail persists the outcome.

The project is intentionally local-first. It focuses on the hard fullstack parts
of an analytics product: data modeling, state transitions, realtime UI, and
review workflow.

## Three-Minute Demo Path

Start at `/`.

### 1. Baseline

Say:

> The app starts from a seeded Postgres catalog: chains, game ecosystems, assets,
> historical asset snapshots, and portfolio snapshots. The top cards, charts,
> table, and filters all read from backend contexts rather than hardcoded UI
> state.

Show:

- top metric cards,
- dashboard analytics,
- full-width asset table,
- filters and active filter chips.

### 2. Reset Runtime

Click **Reset runtime** in the Demo story panel.

Say:

> Runtime reset clears mutable demo state without reseeding the catalog. It
> removes active scenarios, generated activity events, and operator review
> decisions so the story is repeatable.

Call out:

- seeded catalog remains,
- mutable workflow state is isolated.

### 3. Run Scenario Tick

Click **Run scenario tick**.

Say:

> This goes through a supervised simulator process. The scenario operation
> persists an overlay for one eligible asset, records activity, resets stale
> operator review state, and broadcasts the change through PubSub.

Show:

- metric/card changes,
- event feed update,
- chart movement,
- impacted asset link in the walkthrough.

### 4. Read Portfolio Movement

Open analytics and feed from the Demo story panel.

Say:

> The same backend event fans out into multiple frontend surfaces. This is where
> LiveView shines: the user sees portfolio-level risk movement, event volume, and
> the detailed activity feed update without a full reload.

Show:

- portfolio value trend,
- risk trend,
- liquidation pressure,
- recent event volume,
- event feed.

### 5. Inspect Impacted Asset

Click the impacted asset link.

Say:

> The detail page separates four concepts that often get collapsed in demos:
> risk status, system recommendation, operator review state, and audit history.
> That separation matters because automated detection and human workflow are not
> the same state.

Show:

- presenter story context,
- risk drivers,
- LTV trend,
- system recommendation,
- operator decision form.

### 6. Close Review Loop

Click **Mark reviewed** or **Escalate**.

Say:

> This writes an append-only review decision and records an activity event. The
> story state changes because the persisted operator state changed, not because a
> tutorial flag was toggled.

Open the audit trail.

Show:

- review history count,
- activity event,
- reviewed/escalated state,
- audit reason and note.

### 7. Reset and Replay

Click **Reset and replay**.

Say:

> This returns the demo to a clean dashboard state, which is useful for live
> interviews because the same story can be repeated without dropping and
> reseeding the database.

## Five-Minute Architecture Explanation

Use this when the reviewer wants implementation depth.

### Data Boundary

The catalog is persistent:

- `chains`
- `game_ecosystems`
- `monitored_assets`
- `asset_market_snapshots`
- `portfolio_snapshots`

Mutable demo state is separate:

- `asset_scenarios`
- `review_decisions`
- generated `activity_events`

Why this matters:

> It gives the app a real database-backed shape while keeping the demo
> repeatable. Resetting runtime state does not destroy the seeded reference data.

### Simulator Boundary

`AssetMonitoringDash.Simulator` is supervised by the application.

It is responsible for:

- event ticks,
- scenario ticks,
- pause/resume state,
- scenario cap handling,
- broadcasting simulator activity.

Scenario writes go through `AssetMonitoringDash.DemoOperations`, not directly
from the LiveView. That keeps manual and automatic scenario paths consistent.

### LiveView Boundary

Dashboard and asset detail pages subscribe to simulator PubSub updates.

The dashboard owns:

- portfolio metrics,
- charts,
- table filters/sort/pagination,
- event feed,
- presenter walkthrough.

The asset detail page owns:

- asset-level risk explanation,
- scenario controls,
- operator decision form,
- activity filtering,
- review history,
- related asset navigation.

### Frontend Boundary

The UI split is intentional:

- generic primitives live in `components/ui`,
- dashboard-specific components live near `DashboardLive`,
- asset-detail components live near `AssetLive`.

This avoids turning the UI library into a product-specific dumping ground while
keeping product components close to their owning view.

## Questions to Expect

### Why fictional data?

Because the goal is to demonstrate system shape and product behavior without
being blocked by unreliable external APIs, rate limits, or provider-specific
credentials.

The architecture leaves room for external ingestion later, but this stage is
focused on persistence, workflow, and realtime UI.

### Why LiveView?

The app benefits from LiveView because most interactions are stateful and
operational:

- filters,
- table updates,
- simulator events,
- chart refreshes,
- review state,
- audit history.

LiveView keeps most workflow state server-side while still giving a responsive
browser experience.

### Why not store filters in the database?

Dashboard filters are URL-backed UI state. They describe the current view, not
domain state. Persisting them would add complexity without improving the core
demo.

The database stores catalog data, scenario state, activity events, market
history, portfolio snapshots, and operator decisions.

### What would you do next?

Good next steps:

- add scenario effect summaries,
- show baseline vs scenario values on asset detail,
- add richer scenario types and analytics explanations,
- split contexts further if external ingestion is added,
- add provider behaviours for CoinGecko, Reservoir, or marketplace data.

## What to Emphasize as Fullstack Work

- The app has real persistence, not just seeded assigns.
- The simulator is supervised and uses shared operations.
- Review decisions are audit-like append-only records.
- URL state is explicit and shareable.
- The table is paginated and streamed, not just rendering one small list.
- Charts are integrated through a real charting library.
- The UI component organization separates primitives from product components.
- Tests cover product workflows, not only pure functions.

## Short Closing

Say:

> I built this as a compact but realistic slice of an analytics product. The
> interesting part is not only the dashboard UI, but the fact that a single
> scenario touches the database, simulator, PubSub, LiveView streams, charts,
> detail pages, and audit workflow in a coherent way.
