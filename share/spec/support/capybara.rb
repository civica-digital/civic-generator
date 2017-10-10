# https://github.com/teampoltergeist/poltergeist

require 'capybara/poltergeist'

RSpec.configure do
  Capybara.javascript_driver = :poltergeist
end
