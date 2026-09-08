FROM mcr.microsoft.com/playwright:v1.50.1-jammy

WORKDIR /app

ENV NODE_ENV=production \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY tsconfig.json ./
COPY src ./src
RUN npx tsc -p tsconfig.json

COPY .env.example ./

RUN mkdir -p /app/data /app/logs \
  && useradd --system --uid 10001 --home /app --shell /usr/sbin/nologin youtube-worker \
  && chown -R youtube-worker:youtube-worker /app

USER youtube-worker

EXPOSE 8080

CMD ["node", "dist/index.js"]
