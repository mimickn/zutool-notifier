# Base image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Enable corepack to use pnpm
RUN corepack enable

# Copy package definition files
COPY package.json pnpm-lock.yaml ./

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build TypeScript
RUN pnpm run build

# Run the compiled app
CMD ["node", "dist/index.js"]
