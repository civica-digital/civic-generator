# Use the motheds inside FactoryGirl without the namespace
#   FactoryGirl.create(:factory) -> create(:factory)

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
end
