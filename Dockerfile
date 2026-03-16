FROM ruby:3.3.0-slim

# Install essential Linux packages
RUN apt-get update -qq && apt-get install -y build-essential git curl libvips && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Set application directory
WORKDIR /app

# Install application gems
COPY Gemfile Gemfile.lock ./
# Note: If your Gemfile uses local paths (e.g. `path: '/Users/.../descartes'`), 
# Railway's docker builder will fail because those paths don't exist in the container.
# You MUST change them to git dependencies in your Gemfile before pushing to Railway:
# gem 'descartes', git: 'https://github.com/your-username/descartes.git'
RUN bundle install

# Copy application code
COPY . .

# Expose port (Railway dynamically overrides this via the $PORT env var)
EXPOSE 9292

# Start server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
