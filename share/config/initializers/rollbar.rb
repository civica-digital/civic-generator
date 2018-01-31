Rollbar.configure do |config|
  unless Rails.env.production? && ENV['ROLLBAR_ACCESS_TOKEN']
    config.enabled = false
  end

  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
  config.environment = ENV['ROLLBAR_ENV'] || Rails.env

  config.exception_level_filters.merge!({
    'ActionController::RoutingError' => 'ignore',
    'NoMethodError' => 'critical'
  })
end
