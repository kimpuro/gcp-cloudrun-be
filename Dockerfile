# syntax=docker/dockerfile:1.7

# =========================================
# 1) Base: pnpm 활성화된 Node 이미지
# =========================================
FROM node:22-alpine AS base
ENV PNPM_HOME="/pnpm" \
    PATH="/pnpm:$PATH" \
    CI=true
RUN corepack enable
WORKDIR /app


# =========================================
# 2) Dependencies: 프로덕션 의존성만 설치
# =========================================
FROM base AS prod-deps
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile --prod


# =========================================
# 3) Builder: 전체 의존성 설치 후 NestJS 빌드
# =========================================
FROM base AS builder
COPY package.json pnpm-lock.yaml ./
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile
COPY tsconfig*.json nest-cli.json ./
COPY src ./src
RUN pnpm run build


# =========================================
# 4) Runner: 런타임 최소 이미지
# =========================================
FROM node:22-alpine AS runner
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app

RUN addgroup -S nodejs && adduser -S nestjs -G nodejs

COPY --chown=nestjs:nodejs package.json ./
COPY --from=prod-deps --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder  --chown=nestjs:nodejs /app/dist ./dist

USER nestjs

EXPOSE 3000

CMD ["node", "dist/main.js"]
