# Development-oriented image: single stage, build tools kept, logs to stdout.
# A production image would be multi-stage with a precompiled bootsnap cache and no build tools.
FROM ruby:4.0-slim

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libpq-dev libyaml-dev git && \
    rm -rf /var/lib/apt/lists/*

ENV BUNDLE_PATH=/usr/local/bundle

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
