# ============================================================================
# Railway Template: Jev Trader CPU (jarrodwatts/jev-trader fork)
# ----------------------------------------------------------------------------
# A TypeSafe-Jev decision bot that market-makes MON-USDC on Kuru (Monad):
# every ~300 ms block it reads the live order book, asks a local JevOS model
# buy-or-sell, and posts one post-only limit order just inside the touch.
# Fills earn the spread instead of paying it.
#
# Why this wrapper differs from upstream:
# - MODEL defaults to `jev-local`: decisions come from a JevOS sidecar over
#   Railway's private network (JEV_BASE_URL) instead of the hosted TypeSafe
#   API -- $0 inference, no TYPESAFE_AI_API_KEY.
# - JevOS answers yes/no (`noul`) questions, so the buy/sell choice is asked
#   as "will MON be higher than the mid after the horizon?" and P(yes) is the
#   buy probability. `src/model.ts` (LocalJevModel) does the mapping.
# - A self-contained SSE dashboard is served at / (public/index.html, no
#   build step, no external assets) so the template needs no separate
#   frontend service and no baked API URL.
# - No PRIVATE_KEY is ever in the deploy form: without one the bot dry-runs
#   (real book, real local decisions, simulated fills) -- the safe default
#   for a one-click template.
#
# Runtime notes:
# - Stateless: block history lives in memory (1000 events), nothing is
#   written to disk, so no volume is mounted.
# - Honors Railway's injected PORT (src/config.ts), binds 0.0.0.0 via
#   Bun.serve's default -- no extra host config needed.
# - Base image pinned by digest (oven/bun 1.3, amd64); deps locked with
#   bun.lock --frozen-lockfile.
# ============================================================================
FROM oven/bun:1.3@sha256:50317d83cd5a5ae1d8b35b3379c69f57ce1a0dbf4def91f0965653d767851834

WORKDIR /app

# Deps first for layer caching; production-only, lockfile-frozen.
COPY package.json bun.lock bunfig.toml ./
RUN bun install --frozen-lockfile --production

COPY src ./src
COPY public ./public

ENV NODE_ENV=production \
    # Sensible template defaults baked in: the deploy form stays at zero fields.
    # JEV_BASE_URL is overridden to the jevos sidecar via a Railway reference
    # when the template is generated (see template-vars.json).
    MODEL=jev-local \
    DRY_RUN=true \
    PORT=3000

EXPOSE 3000

LABEL org.opencontainers.image.source="https://github.com/mc9max/jev-trader-cpu"

CMD ["bun", "run", "src/index.ts"]
