# Carrierwave configuration for S3 using the `fog-aws` gem
CarrierWave.configure do |config|
  if Rails.env.production? && ENV.key?('AWS_SECRET_KEY')
    config.fog_provider = 'fog/aws'
    config.fog_credentials = {
      provider:              'AWS',
      aws_access_key_id:     ENV.fetch('AWS_ACCESS_KEY'),
      aws_secret_access_key: ENV.fetch('AWS_SECRET_KEY'),
      region:                ENV.fetch('AWS_REGION') { 'us-east-1' },
      endpoint:              ENV.fetch('AWS_S3_HOST') { nil },
      path_style:            true,
    }
    config.storage = :fog
    config.fog_directory = ENV.fetch('AWS_S3_BUCKET')
  end

  if Rails.env.development?
    config.ignore_integrity_errors = false
    config.ignore_processing_errors = false
    config.ignore_download_errors = false
  end

  if Rails.env.test?
    config.storage = :file
    config.enable_processing = false
  end

  if Rails.env.production?
    config.fog_public = false
    config.fog_attributes = { 'Cache-Control' => "max-age=#{365.days.to_i}" }
  end
end
