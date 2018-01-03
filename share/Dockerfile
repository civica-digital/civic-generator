FROM ruby:2.4.2-alpine

# Runtime
ENV APP_HOME=/usr/src \
    LANG=C.UTF-8 \
    PATH=/usr/src/bin:$PATH \
    TERM='xterm-256color' \
    RAILS_ENV=production

WORKDIR $APP_HOME

EXPOSE 3000

CMD rm -f tmp/pids/server.pid && rails server -b 0.0.0.0

STOPSIGNAL SIGKILL

RUN set -ex \
    && apk update \
    && apk upgrade \
    && apk add --no-cache --virtual .runtime \
      bash \
      imagemagick \
      less \
      nodejs \
      postgresql-dev \
      tzdata

# Build
COPY Gemfile* $APP_HOME/

RUN set -ex \
    && apk add --no-cache --virtual .build \
      ruby-dev \
      build-base \
      git \
    && bundle install --without test development --jobs 4 --retry 3 \
    && apk del .build

COPY . $APP_HOME

RUN SECRET_KEY_BASE=tmp \
    rake assets:precompile

RUN chown -R nobody:nogroup $APP_HOME
USER nobody

# Add Git release hash
ARG release_commit=none
ENV RELEASE_COMMIT $release_commit
