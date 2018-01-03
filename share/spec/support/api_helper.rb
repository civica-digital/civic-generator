# Use json_body to access the response body serialized

module ApiHelper
  def json_body
    JSON.parse(response.body, symbolize_names: true)
  end
end

RSpec.configure do |config|
  config.include ApiHelper, type: :request
  config.include ApiHelper, type: :controller
end
