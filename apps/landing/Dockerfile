# Build context is apps/landing (own bun.lock, no workspace deps).
#
# next start wants node, so deps are installed with bun and the built app runs
# on a node runtime. No NEXT_PUBLIC_* exist here, so nothing has to be baked in
# at build time: AIRTABLE_* are read server-side at request time.

FROM oven/bun:1.3.13 AS build
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

# Not --frozen-lockfile: the committed lockfile satisfies package.json locally,
# but Orchard's builder resolves it differently and fails frozen, which takes the
# site down on a routine rebuild. Same reason apps/dashboard installs unfrozen.
COPY package.json bun.lock ./
RUN bun install

COPY . .
RUN bun run build

FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/.next ./.next
COPY --from=build /app/public ./public
COPY --from=build /app/next.config.ts /app/package.json ./

EXPOSE 3000
CMD ["node", "node_modules/next/dist/bin/next", "start"]
