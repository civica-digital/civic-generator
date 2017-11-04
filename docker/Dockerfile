FROM ruby:2.4.2

ENV LANG=C.UTF-8 \
    TERM=xterm-256color \
    HOME=/usr/src

WORKDIR $HOME

# Dependencies
RUN set -ex \
    && apt-get update -y \
    && apt-get install -y \
      tzdata \
      postgresql \
      nodejs \
      git

# Keybase
RUN set -x \
    && curl -O https://prerelease.keybase.io/keybase_amd64.deb \
    && dpkg -i keybase_amd64.deb; true \
    && apt-get install -y -f \
    && rm -f keybase_amd64.deb

# Git Crypt
RUN set -x \
    && git clone https://github.com/AGWA/git-crypt.git \
    && cd git-crypt \
    && make \
    && make install \
    && cd \
    && rm -rf git-crypt

# Rails
RUN gem install rails

COPY entrypoint.sh /usr/local/bin/

RUN adduser generator \
      --disabled-password \
      --gecos none \
      --no-create-home

USER generator

ENTRYPOINT ["entrypoint.sh"]
