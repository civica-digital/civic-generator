config = Timber::Config.instance
config.integrations.action_view.silence = Rails.env.production?
config.integrations.rack.http_events.collapse_into_single_event = Rails.env.production?

# Silence health checks
Timber.config.integrations.rack.http_events.silence_request = lambda do |rack_env, rack_request|
  rack_request.path == "/status"
end
