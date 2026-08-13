# Build context is apps/pixorpheus.
#
# Bun-native with no build step - Bolt runs the TypeScript entry directly, so
# the image just needs the deps and the source. Bolt listens in HTTP mode
# (app.start(PORT)), so this needs an ingress for Slack events and for the
# dashboard's /api/external/tickets calls.
#
# --production is safe here: every @slack/web-api and @slack/types import in
# src/ is `import type`, which Bun erases, so nothing resolves them at runtime.
# There is no bun.lock in this app, so the install resolves fresh.

FROM oven/bun:1.3.13
WORKDIR /app

COPY package.json ./
RUN bun install --production

COPY . .
RUN chown -R bun:bun /app

ENV NODE_ENV=production
ENV PORT=3000

USER bun
EXPOSE 3000
CMD ["bun", "run", "src/index.ts"]
