FROM node:24-bookworm-slim@sha256:a9f5f7c91a432850b2a8a7797adf5eadb6c733ceed61167806cee7ea7fbc29df

# python3 + build-essential: @tobilu/qmd 的 tree-sitter 原生模块编译
# git: vault 自动 commit/pull/push
# ripgrep: search_grep 全文搜索
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 build-essential \
    git ripgrep ca-certificates openssh-client curl \
  && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
WORKDIR /app
