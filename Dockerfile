FROM ruby:2.3.4-alpine
MAINTAINER otwarchive

# Inspired by https://blog.codeship.com/running-rails-development-environment-docker/

RUN apk update && apk upgrade
# Application dependencies
RUN apk add git mariadb-dev imagemagick-dev tzdata
# Build dependencies
RUN apk add ruby-dev build-base linux-headers

# Clean APK cache
RUN rm -rf /var/cache/apk/*

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir -p /app
WORKDIR /app

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
COPY Gemfile Gemfile.lock .ruby-version ./
RUN gem install bundler && bundle install --jobs 20 --retry 5

# Copy the main application.
COPY . ./

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

# Configure an entry point, so we don't need to specify
# "bundle exec" for each of our commands.
ENTRYPOINT ["bundle", "exec"]

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
CMD ["rails", "server", "-b", "0.0.0.0"]