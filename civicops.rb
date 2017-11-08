require 'open-uri'
require 'securerandom'

@app_name = app_name.gsub('_', '-')

def main
  welcome_message
  set_environment_variables
  configure_postgres
  configure_timezone

  web_stack           if yes?('> Web stack?', :green)
  devops_stack        if yes?('> DevOps stack?', :green)
  code_analysis_stack if yes?('> Code analysis stack?', :green)
  tests_stack         if yes?('> Tests stack?', :green)

  setup_sidekiq       if yes?('> Configure Sidekiq + Redis?', :green)
  file_upload_to_aws  if yes?('> Carrierwave + AWS S3?', :green)
  setup_aws_ses       if yes?('> Send mail with AWS SES?', :green)
  setup_recaptcha     if yes?('> Setup reCAPTCHA?', :green)

  clean_gemfile

  finish_message
end

def welcome_message
  message = <<~MESSAGE

    ===========================================

       ____ _       _       ___
      / ___(_)_   _(_) ___ / _ \\ _ __  ___
     | |   | \\ \\ / / |/ __| | | | '_ \\/ __|
     | |___| |\\ V /| | (__| |_| | |_) \\__ \\
      \\____|_| \\_/ |_|\\___|\\___/| .__/|___/
                                |_|

    ===========================================
              ® Cívica Digital 2017
    ===========================================


  MESSAGE

  say message, :blue
end

def set_environment_variables
  say 'Setting default environment variables...', :yellow

  environment_variables = <<~CONFIG
    AWS_ACCESS_KEY=changeme
    AWS_REGION=us-east-1
    AWS_SECRET_KEY=changeme
    RAILS_LOG_TO_STDOUT=true
    RAILS_SERVE_STATIC_FILES=true
    SECRET_KEY_BASE=#{SecureRandom.hex(64)}
  CONFIG

  create_file 'deploy/staging/provisions/.env', environment_variables
end

def clean_gemfile
  say 'Cleaning the Gemfile...', :yellow

  gsub_file('Gemfile', /^\s*#.*\n/, '')     # Remove commented lines
  gsub_file('Gemfile', /^\n\n/, '')         # Remove double newlines
  gsub_file('Gemfile', /gem 'tzinfo.*/, '') # Remove tzinfo-data gem
end

def configure_postgres
  say 'Configuring PostgreSQL...', :yellow

  gsub_file('Gemfile', /sqlite3/, 'pg') # Use PostgreSQL instead of SQLite
  gem 'pg'

  environment_variables = <<~CONFIG
    DATABASE_URL=postgresql://postgres@db/#{@app_name}_production
  CONFIG

  remove_file 'config/database.yml.example'
  download 'config/database.yml'
  append_to_file 'deploy/staging/provisions/.env', environment_variables
end

def configure_timezone
  say 'Configuring Timezone...', :yellow

  environment 'config.time_zone = "Mexico City"'
end

def web_stack
  gem 'bourbon'
  gem 'font-awesome-rails'
  gem 'haml'
  gem 'haml-rails'
  gem 'jquery-rails'
  gem 'neat'
  gem 'sass-rails'

  gem_group :development do
    gem 'better_errors'
  end
end

def devops_stack
  gem 'health_check'
  gem 'newrelic_rpm'
  gem 'rollbar'
  gem 'timber'

  download 'config/newrelic.yml'
  download 'config/initializers/health_check.rb'
  download 'config/initializers/rollbar.rb'
  download 'config/initializers/timber.rb'

  download '.gitignore'
  download 'Makefile'

  timber_config_development = <<~CONFIG
    # Install the Timber.io logger, but do not send logs.
    logger = Timber::Logger.new(nil)
    logger.level = config.log_level
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  CONFIG

  timber_config_production = <<~CONFIG
    # Install the Timber.io logger, send logs over HTTP or STDOUT
    if ENV['TIMBER_API_KEY'].present?
      log_device = Timber::LogDevices::HTTP.new(ENV['TIMBER_API_KEY'])
    else
      log_devise = STDOUT
    end

    logger = Timber::Logger.new(log_device)
    logger.level = config.log_level
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  CONFIG

  environment_variables = <<~CONFIG
    NEW_RELIC_ENV=staging
    NEW_RELIC_LICENSE_KEY=changeme
    ROLLBAR_ACCESS_TOKEN=changeme
    ROLLBAR_ENV=staging
    TIMBER_API_KEY=changeme
  CONFIG

  environment timber_config_development, env: 'development'
  environment timber_config_production, env: 'production'
  append_to_file 'deploy/staging/provisions/.env', environment_variables

  docker
  jenkins
  terraform
  configure_git_crypt
end

def code_analysis_stack
  gem_group :development do
    gem 'brakeman', require: false
    gem 'bundler-audit', require: false
    gem 'rails_best_practices', require: false
    gem 'reek', require: false
    gem 'rubocop', require: false
    gem 'rubocop-rspec', require: false
  end

  gem_group :test do
    gem 'bullet'
  end

  download 'config/initializers/bullet.rb'
  download 'config/rails_best_practices.yml'
  download '.reek'
  download '.rubocop.yml'
end

def tests_stack
  say 'Setting up RSpec and Factory Girl...', :yellow

  gem_group :development, :test do
    gem 'dotenv-rails'
    gem 'factory_girl_rails'
    gem 'pry-rails'
    gem 'rspec-rails'
  end

  say 'Use `json_body` to access the response body in tests.', :yellow
  download 'spec/support/api_helper.rb'

  say 'Use the FactoryGirl methods without the namespace.', :yellow
  download 'spec/support/factory_girl.rb'
end

def docker
  say 'Configuring Docker...', :yellow

  download '.dockerignore'
  download 'docker-compose.yml'
  download 'Dockerfile'
  download 'Dockerfile.dev'
end

def jenkins
  say 'Configuring Jenkins...', :yellow

  download 'Jenkinsfile'
end

def terraform
  say 'Adding scripts to setup the server...', :yellow
  download 'deploy/staging/scripts/setup-server.sh'
  download 'deploy/staging/scripts/update-container.sh'

  say 'Configuring Terraform to deploy a staging environment...', :yellow
  download 'deploy/staging/provisions/docker-compose.yml'
  download 'deploy/staging/main.tf'
  download 'deploy/staging/provisions/traefik.toml'
end

def file_upload_to_aws
  gem 'carrierwave'
  gem 'fog-aws'

  aws_bucket_config = <<~CONFIG
    # Create AWS S3 bucket
    resource "aws_s3_bucket" "storage" {
      bucket = "${var.project_name}"
      acl    = "private"

      tags {
        Environment = "staging"
      }

      lifecycle {
        prevent_destroy = true
      }
    }

  CONFIG

  aws_s3_user = <<~CONFIG
    # Create the S3 policy to access the project's bucket
    resource "aws_iam_user_policy" "s3" {
      name = "${var.project_name}-S3"
      user = "${aws_iam_user.project.name}"

      policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "s3:*",
          "Resource": [
            "${aws_s3_bucket.storage.arn}",
            "${aws_s3_bucket.storage.arn}/*"
          ]
        }
      ]
    }
    EOF
    }

  CONFIG

  bucket_output = <<~CONFIG

    output "bucket" {
      value = "${aws_s3_bucket.storage.bucket}"
    }
  CONFIG

  environment_variables = <<~CONFIG
    AWS_S3_BUCKET=changeme
  CONFIG

  download 'config/initializers/carrierwave.rb'
  insert_into_file 'deploy/staging/main.tf', aws_bucket_config, before: '# Data'
  insert_into_file 'deploy/staging/main.tf', aws_s3_user, before: '# Data'
  append_to_file 'deploy/staging/main.tf', bucket_output
  append_to_file 'deploy/staging/provisions/.env', environment_variables
end

def setup_aws_ses
  gem 'aws-ses', require: 'aws/ses'

  ses_policy = <<~CONFIG
    # Create the SES policy to send emails
    resource "aws_iam_user_policy" "ses" {
      name = "${var.project_name}-SES"
      user = "${aws_iam_user.project.name}"

      policy = <<EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": "ses:*",
          "Resource": "*"
        }
      ]
    }
    EOF
    }

  CONFIG

  environment_variables = <<~CONFIG
    AWS_SES_ACCESS_KEY=changeme
    AWS_SES_EMAIL_FROM=noreply+#{@app_name}@civica.digital
    AWS_SES_SECRET_KEY=changeme
  CONFIG

  mailer_config = "  config.mailer_sender = ENV.fetch('EMAIL_FROM') { 'noreply@civica.digital' }"

  download 'config/initializers/mailer.rb'
  environment 'config.action_mailer.delivery_method = :ses', env: 'production'
  insert_into_file 'deploy/staging/main.tf', ses_policy, before: '# Data'
  insert_into_file 'config/initializers/devise.rb', mailer_config, before: '  # ==> ORM configuration'
  append_to_file 'deploy/staging/provisions/.env', environment_variables
end

def setup_recaptcha
  gem 'recaptcha', require: 'recaptcha/rails'

  download 'config/initializers/recaptcha.rb'
end

def setup_sidekiq
  gem 'sidekiq'

  db_volume = '  db_data: {}'

  # Indentation is important, please, respect it
  redis_volume = "\n  redis: {}"
  redis_service = <<-YML

  redis:
    command: redis-server --appendonly no --save ""
    image: redis:3.2-alpine
    volumes:
      - redis:/var/lib/redis/data
YML

  sidekiq_service = <<-YML

  sidekiq:
    <<: *web
    command: bundle exec sidekiq
    depends_on:
      - redis
YML

  download 'config/initializers/sidekiq.rb'
  insert_into_file 'docker-compose.yml', redis_volume, after: db_volume
  insert_into_file 'docker-compose.yml', redis_service, after: 'services:'
  append_to_file 'docker-compose.yml', sidekiq_service

  insert_into_file 'deploy/staging/provisions/docker-compose.yml', redis_volume, after: db_volume
  insert_into_file 'deploy/staging/provisions/docker-compose.yml', redis_service, after: 'services:'
  append_to_file 'deploy/staging/provisions/docker-compose.yml', sidekiq_service
end

def download(file, &block)
  repository = 'https://raw.githubusercontent.com/civica-digital/civic-generator'
  source = "#{repository}/master/share/#{file}"
  render = open(source) { |input| input.binmode.read }

  render.gsub!('{{project_name}}', @app_name)

  create_file file, render
end

def configure_git_crypt
  say 'Configuring git-crypt...', :yellow

  team_members = %w(
    abisosa
    fercreek
    mikesaurio
    mroutis
    rafaelcr
    ricalanis
  )

  `git-crypt init`
  team_members.each { |user| `curl https://keybase.io/#{user}/pgp_keys.asc | gpg --import` }
  team_members.each { |user| `git-crypt add-gpg-user --trusted #{user[0..2]}` }

  gitattributes = <<~CONF
    secretfile filter=git-crypt diff=git-crypt
    .env filter=git-crypt diff=git-crypt
    *.secret
  CONF

  create_file '.gitattributes', gitattributes
end

def finish_message
  message = <<~MESSAGE

    ===========================================

    Awesome!

    Setup your local development environment
    with Docker using the command: `make dev`

    ===========================================
  MESSAGE

  say message, :blue
end

main
