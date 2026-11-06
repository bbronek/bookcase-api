# syntax=docker/dockerfile:1
# check=error=true

FROM docker.io/library/ruby:4.0.9-slim AS base

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libjemalloc2 libyaml-0-2 && \
    ln -s "/usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2" /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

ENV BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_FROZEN="1" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential libyaml-dev && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives

COPY Gemfile Gemfile.lock .ruby-version ./

FROM build AS production-gems

ENV BUNDLE_WITHOUT="development:test"
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache

FROM production-gems AS development-gems

ENV BUNDLE_WITHOUT=""
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache

FROM base AS development

ENV RAILS_ENV="development"
COPY --from=development-gems "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=1000:1000 . .
RUN chown 1000:1000 /app
USER 1000:1000
RUN mkdir -p tmp/mails

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-P", "/tmp/server.pid"]

FROM base AS production

ENV RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test"
COPY --from=production-gems "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY Gemfile Gemfile.lock .ruby-version config.ru Rakefile ./
COPY app app
COPY bin/rails bin/rake bin/jobs bin/
COPY config config
COPY db db
COPY lib lib
COPY public public
RUN bundle exec bootsnap precompile --gemfile app/ lib/ && \
    mkdir -p log tmp && \
    chown -R 1000:1000 log tmp
ENV BOOTSNAP_READONLY="1"
USER 1000:1000

EXPOSE 3000
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s \
  CMD ["ruby", "-rnet/http", "-e", "exit Net::HTTP.get_response(URI('http://localhost:3000/health')).is_a?(Net::HTTPSuccess)"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-P", "/tmp/server.pid"]
