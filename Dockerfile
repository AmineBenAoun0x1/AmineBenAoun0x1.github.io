# Use Ruby as the base image
FROM ruby:3.2

# Set working directory
WORKDIR /usr/src/app

# Copy Gemfile and Gemfile.lock first (for caching)
COPY Gemfile Gemfile.lock ./

# Install dependencies
RUN gem install bundler && bundle install

# Copy the rest of the website
COPY . .

# Build the Jekyll site (optional for testing)
RUN bundle exec jekyll build

# Expose port 4000 for the Jekyll server
EXPOSE 4000

# Command to serve the site
CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0"]
