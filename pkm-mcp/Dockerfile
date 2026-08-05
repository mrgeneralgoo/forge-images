FROM node:24-bookworm-slim@sha256:3638d9a6fe4030bd716be989438248074489337ba3275657f93595428be4fc03

# python3 + build-essential: @tobilu/qmd 的 tree-sitter 原生模块编译
# git: vault 自动 commit/pull/push
# ripgrep: search_grep 全文搜索
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 build-essential \
    git ripgrep ca-certificates openssh-client curl \
  && rm -rf /var/lib/apt/lists/*

ENV NODE_ENV=production
WORKDIR /app
