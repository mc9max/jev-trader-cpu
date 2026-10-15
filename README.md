# Jev Trader CPU

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/jev-trader-cpu?utm_campaign=jev-trader-cpu)

**Jev Trader CPU** is a one-decision-per-block market-making bot for the Kuru MON-USDC book on Monad — a fork of [jarrodwatts/jev-trader](https://github.com/jarrodwatts/jev-trader) (MIT) whose brain is a **local JevOS model on your own CPU** instead of a hosted API. Every ~300 ms block the bot reads the live order book, asks JevOS buy-or-sell, and posts one post-only limit order just inside the touch. Fills happen when a taker hits it, so the bot earns the spread instead of paying it. A live dashboard streams every block, decision, quote, fill and P&L.

**Deploys in dry-run (paper trading):** real book, real local AI decisions, simulated fills. No private keys, no API keys, $0 inference.

## Deploy and Host

Click **Deploy on Railway** — zero form fields. The template provisions two services:

- **trader** (this repo) — the Bun bot + live SSE dashboard on `/`
- **jevos** ([mc9max/jevos](https://github.com/mc9max/jevos)) — the local CPU decision model, reachable only over Railway's private network (no public domain, no API key needed)

The trader finds the model at `http://${{jevos.RAILWAY_PRIVATE_DOMAIN}}:${{jevos.PORT}}` automatically.

## Why Deploy

Hosted decision APIs charge per token and add network latency to a 300 ms budget. Jev Trader CPU keeps the whole loop on your own hardware: the JevOS sidecar answers in tens of milliseconds on shared CPU, the book read is one `eth_call`, and the decision never leaves your Railway private network. You get the real upstream strategy — post-only quotes one tick inside the touch, adverse-selection-aware sizing via position caps — with a $0/month inference bill and nothing to sign up for.

## Common Use Cases

- Paper-trading a market-making strategy on live Monad book data with a real local model in the loop
- A latency lab: watch per-block read/decide/loop timings and `late` holds on the dashboard
- A starting point for your own JevOS-powered trading logic — `src/model.ts` (`LocalJevModel`) is the seam
- Demoing CPU-only AI decisions: the whole "brain" is a 630 MB INT8 model on shared vCPU

## How it decides

Upstream asks the hosted Jev a buy/sell *choice* question. JevOS (jevos-v3) answers yes/no (`noul`) questions, so this fork asks one boolean instead — *"Will MON be higher than the current mid after the horizon?"* — and treats P(yes) as the buy probability (`src/model.ts`). Same state, same market-making goal text, same 0.5 threshold. If a block's inference misses the window (or JevOS is unreachable) the bot safely holds that block instead of guessing.

## Going live (your key, your risk)

The template ships keyless and dry-runs. To place real orders, add `PRIVATE_KEY` (and `DRY_RUN=false`) in the trader service's **Variables** panel — never in the template form. Live quotes are fire-and-forget post-only limit orders drawn from the Kuru margin account; the bot deposits margin at startup. Start small, watch the dashboard, and understand the upstream strategy before funding it.

## Runtime

- **Port:** honors Railway's injected `PORT` (dashboard + JSON API on `/`, `/history`, `/events` SSE)
- **Memory:** trader is light (~100 MB); the jevos sidecar holds the ~630 MB model resident
- **Persistence:** none — block history is in-memory (last 1000 events); no volume
- **Healthcheck:** `GET /` returns the dashboard (200, unauthenticated)

### Deployment Dependencies

Two services, no database, no volume. The trader needs outbound HTTPS to the Monad public RPC (`https://rpc.monad.xyz`) for book reads and block polling. JevOS needs nothing at runtime — the model is baked into its image.

## Credits

Strategy, book reader and market code: [jarrodwatts/jev-trader](https://github.com/jarrodwatts/jev-trader) (MIT). Local inference: [feder-cr/jev](https://github.com/feder-cr/jev) via the [JevOS Railway template](https://github.com/mc9max/jevos).
