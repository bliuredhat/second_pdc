require 'capybara/cucumber'
require 'capybara/poltergeist'

Capybara.register_driver :poltergeist do |app|
  options = {
    js_errors: true,
    timeout: 120,
    phantomjs_options: ['--load-images=no', '--disk-cache=false'],
    # NOTE: enable for debugging
    # debug: true,
    # inspector: true,
  }

  Capybara::Poltergeist::Driver.new(app, options)
end

# all tests will be run in a headless browser
Capybara.default_driver = :poltergeist
