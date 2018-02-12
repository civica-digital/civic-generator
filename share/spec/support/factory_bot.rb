# Use the methods inside FactoryBot without the namespace
#   FactoryBot.create(:factory) -> create(:factory)

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
