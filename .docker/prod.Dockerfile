# Ruby version 2.7.4
FROM phusion/passenger-ruby27:2.0.1

SHELL ["/bin/bash", "-c"]

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# Enable nginx
RUN rm -f /etc/service/nginx/down

# Remove default nginx site
RUN rm /etc/nginx/sites-enabled/default

# Add nginx site for simple-server
ADD .docker/config/nginx/webapp.conf /etc/nginx/sites-enabled/webapp.conf

# Add logrotate config
ADD .docker/config/logrotate/* /etc/logrotate.d/
RUN chmod 644 /etc/logrotate.d/*

# Default directory setup
ENV INSTALL_PATH /home/app
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH

# Create cron logs directory
RUN mkdir -p /home/deploy/apps/simple-server/shared/log

# Copy application files
COPY --chown=app:app ./ ./

## Install dependencies
RUN apt-get update && apt-get upgrade -y && apt-get autoclean -y && apt-get autoremove -y && apt-get install -y \
  redis-server \
  jq \
  cron \
  vim \
  s3cmd
# Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg -o /root/yarn-pubkey.gpg && apt-key add /root/yarn-pubkey.gpg
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y --no-install-recommends yarn
# Node
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get update && apt-get install -y --no-install-recommends nodejs
# Postgres client 14
RUN apt policy postgresql && \
  curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
  echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  apt update && apt install -y postgresql-client-14 && apt autoremove -y

# Configure rails env
ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES true

# Build
RUN gem install bundler -v "$(grep -A 1 "BUNDLED WITH" Gemfile.lock | tail -n 1)"
RUN bundle install --without development test
RUN yarn install
RUN set -a && source .env.development && set +a && bundle exec rake assets:precompile
RUN chown -R app:app /home/app

ENTRYPOINT ["/home/app/bin/docker-entrypoint"]
