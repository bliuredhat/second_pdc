$LOAD_PATH.unshift File.expand_path('../../../../test', __FILE__)

# TODO: refactor test_helper modules and use World(HelperModule) instead
# of including everything from test_helper
require 'test_helper'

# TODO: HACK: shut up Test::Unit automatic runner
Test::Unit.run = true

def symbolize(key)
  key.parameterize.underscore.to_sym
end
