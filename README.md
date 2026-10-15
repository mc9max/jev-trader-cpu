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

Hosted decision APIs charge per token and add network latency to a 300 ms budget. Jev Trader CPU keeps the whole loop on your own hardware: the book read is a single `eth_call`, and the decision never leaves your Railway private network. You get the real upstream market-making strategy — post-only quotes one tick inside the touch, position caps, adverse-selection-aware quoting — with a $0/month inference bill and nothing to sign up for.

**Latency note (measured 2026-10-15):** on Railway's shared Hobby CPU the local JevOS model answers in ~0.5–1.9 s, not inside the ~300 ms block window — so roughly 1 block in 4 gets a fresh decision and the rest safely hold (the dashboard shows `late` holds and per-decision latency honestly). The dry-run loop still paper-trades correctly: every decision posts a real sim quote and fills trigger on real taker prints. If you need sub-block decisions, point `MODEL=jev` at the hosted TypeSafe API or run the jevos sidecar on a plan with dedicated CPU.

## Common Use Cases

- Paper-trading a market-making strategy on live Monad book data with a real local model in the loop
- A latency lab: watch per-block read/decide/loop timings and `late` holds on the dashboard
- A starting point for your own JevOS-powered trading logic — `src/model.ts` (`LocalJevModel`) is the seam
- Demoing CPU-only AI decisions: the whole "brain" is a 630 MB INT8 model on shared vCPU

## How it decides

Upstream asks the hosted Jev a buy/sell *choice* question. JevOS (jevos-v3) answers yes/no (`noul`) questions, so this fork asks one boolean instead — *"Will MON be higher than the current mid after the horizon?"* — and treats P(yes) as the buy probability (`src/model.ts`). Same state, same market-making goal text, same 0.5 threshold. If a block's inference misses the window (or JevOS is unreachable) the bot safely holds that block instead of guessing.

## Configuration

The deploy form has zero fields — the template wires everything. These are the knobs, only if you want to tune. Set them in the trader service's **Variables** panel after deploy (all optional; defaults are baked into the image).

**Model — leave alone unless you know why:**

| Variable | Default | What it does |
|---|---|---|
| `MODEL` | `jev-local` | `jev-local` = local JevOS sidecar ($0, no key); `jev` = hosted TypeSafe API (needs `TYPESAFE_AI_API_KEY`); `mock` = coin-flip decisions for testing |
| `JEV_BASE_URL` | auto-wired to the jevos sidecar over the private network | Where the trader finds the model; the template sets this via `${{jevos.RAILWAY_PRIVATE_DOMAIN}}` |
| `JEV_MODEL_ID` | `jev-latest` | Model ID sent with each decision request |
| `TYPESAFE_AI_API_KEY` | _(unset)_ | Only for `MODEL=jev` (hosted TypeSafe API) |
| `JEV_API_KEY` | _(unset)_ | Only if your JevOS sidecar requires auth |

**Trading knobs:**

| Variable | Default | What it does |
|---|---|---|
| `DRY_RUN` | `true` | Paper trading (simulated fills). Set `false` together with `PRIVATE_KEY` for live orders |
| `TRADE_SIZE_MON` | `200` | Order size in MON (200 is the Kuru minimum) |
| `MAX_POSITION_MON` | `1000` | Max net position; the bot stops quoting a side past this |
| `QUOTE_INSIDE_TICKS` | `1` | Ticks inside the touch to post (`0` = join best bid/ask; never crosses) |
| `HORIZON_BLOCKS` | `100` | How far ahead (~30 s) the model predicts the move |
| `BANKROLL_USD` | `100` | Virtual bankroll the dashboard uses for P&L % |

**Chain / RPC:**

| Variable | Default | What it does |
|---|---|---|
| `RPC_URL` / `READ_RPC_URL` | `https://rpc.monad.xyz` | Monad endpoints for transactions and book reads |
| `WS_URL` | _(unset)_ | Optional websocket feed; block polling always runs as backstop |
| `MARKET` | Kuru MON-USDC `0x065C…9C394` | The book it trades; don't change unless you're pointing at another Kuru market |

**Margin & gas (usually leave alone):**

| Variable | Default | What it does |
|---|---|---|
| `MARGIN_MON` / `MARGIN_USDC` | `600` / `20` | Target margin-account balances; the bot tops up at startup (live orders draw from margin, not the wallet) |
| `MARGIN_ACCOUNT` | Kuru MON-USDC account `0x2A68…D8E90c5` | Must match `MARKET`; only change if `MARKET` changes |
| `GAS_LIMIT` | _(unset = estimate once at startup)_ | Monad charges gas on the limit; hardcode to skip estimation |
| `MAX_FEE_GWEI` / `PRIORITY_FEE_GWEI` | `400` / `2` | EIP-1559 caps (Monad hardcodes priority fee at 2) |

**Going live:** add `PRIVATE_KEY` and set `DRY_RUN=false` in Variables — never in a template form. The bot funds its Kuru margin account at startup and places fire-and-forget post-only limit orders. Start small.

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
