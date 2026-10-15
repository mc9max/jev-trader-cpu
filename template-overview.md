# Deploy and Host

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.com/deploy/jev-trader-cpu?utm_campaign=jev-trader-cpu)

**Jev Trader CPU** — an AI market-making bot for the Kuru MON-USDC book on Monad, making one buy-or-sell decision per ~300 ms block with a **local JevOS model on CPU** ($0 inference, no API key). Every block it reads the live order book, asks the model, and posts one post-only limit order just inside the touch, so fills earn the spread instead of paying it. A live dashboard streams each block, decision, quote, fill and paper P&L.

Deploys in **dry-run (paper trading)**: real book, real local AI decisions, simulated fills. No private keys, no API keys, zero form fields.

## About Hosting

Two services, deployed together with one click:

- **trader** — the Bun bot plus a self-contained live dashboard (SSE, no build step, no external assets) on `/`
- **jevos** — the local CPU decision model ([mc9max/jevos](https://github.com/mc9max/jevos)), reachable only over Railway's private network; no public domain, no key required

The trader discovers the model at `http://${{jevos.RAILWAY_PRIVATE_DOMAIN}}:${{jevos.PORT}}` automatically. Stateless: block history is in-memory (last 1000 events), nothing is written to disk, no volume is mounted. The dashboard doubles as the healthcheck (`GET /`, 200, unauthenticated).

## Why Deploy

Hosted decision APIs charge per token and add network latency to a 300 ms block budget. Jev Trader CPU keeps the whole loop on your own hardware: the book read is a single `eth_call`, and the decision never leaves your Railway private network. You get the real upstream market-making strategy — post-only quotes one tick inside the touch, position caps, adverse-selection-aware quoting — with a $0/month inference bill and nothing to sign up for.

**Latency note (measured 2026-10-15):** on Railway's shared Hobby CPU the local JevOS model answers in ~0.5–1.9 s, not inside the ~300 ms block window — roughly 1 block in 4 gets a fresh decision and the rest safely hold (the dashboard shows `late` holds and per-decision latency honestly). The dry-run loop still paper-trades correctly: every decision posts a real sim quote and fills trigger on real taker prints.

## Common Use Cases

- Paper-trade a market-making strategy on live Monad book data with a real local model in the loop
- Run a latency lab: per-block read/decide/loop timings and `late` holds are visible on the dashboard
- Fork it into your own JevOS-powered trading logic — `src/model.ts` (`LocalJevModel`) is the seam
- Demo CPU-only AI decisions: the whole "brain" is a 630 MB INT8 model running on shared vCPU

## Dependencies for

### Deployment Dependencies

Two services, no database, no volume, no form fields. The trader needs outbound HTTPS to the Monad public RPC (`https://rpc.monad.xyz`) for book reads, block polling and trade logs. The jevos sidecar needs nothing at runtime — the model is baked into its image. To place real orders (off by default), add `PRIVATE_KEY` with `DRY_RUN=false` in the trader's Variables panel; live quotes draw from the Kuru margin account, which the bot funds at startup.
