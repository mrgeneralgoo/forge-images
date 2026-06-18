FROM node:24-bookworm-slim@sha256:c2d5ade763cacfb03fe9cb8e8af5d1be5041ff331921fa26a9b231ca3a4f780a

# python3 + build-essential: @tobilu/qmd 的 tree-sitter 原生模块编译
# git: vault 自动 commit/pull/push
# ripgrep: search_grep 全文搜索
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 build-essential \
    git ripgrep ca-certificates openssh-client curl \
  && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
WORKDIR /app
