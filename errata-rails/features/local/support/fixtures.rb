# Helper to load all fixtures
#
# This is copied from: cucumber/wiki: https://github.com/cucumber/cucumber/wiki/Fixtures
#
# NOTE: requiring 'test_helper' which contains fixtures(:all) does not
# actually load all fixtures

# support running without loading fixtures e.g.
#   NO_FIXTURE_LOAD=1 cucumber features/some.feature

unless ENV['NO_FIXTURE_LOAD']
  ActiveRecord::Fixtures.reset_cache
  fixtures_folder = File.join(Rails.root, 'test', 'fixtures')
  fixtures = Dir[File.join(fixtures_folder, '*.yml')].map { |f| File.basename(f, '.yml') }
  ActiveRecord::Fixtures.create_fixtures(fixtures_folder, fixtures)
end

