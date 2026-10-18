# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails
ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=""

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libpq5 && \
    rm -rf /var/lib/apt/lists/*

# ---- ビルド用（ネイティブ拡張のコンパイルに必要なものはここだけに入れる）----
FROM base AS build
ARG BUNDLE_WITHOUT=""
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Gemfile.lock は初回の bundle install で生成される（リポジトリには含めていない）
COPY Gemfile Gemfile.lock* ./
RUN bundle install && rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache
COPY . .
RUN bundle exec bootsnap precompile --gemfile app/ lib/ config/

# ---- 実行用 ----
FROM base
ARG BUNDLE_WITHOUT=""
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chmod +x bin/* && chown -R rails:rails log tmp 2>/dev/null || true
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
