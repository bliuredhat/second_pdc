class ExternalTestsGuardTestType < ActiveRecord::Base
  belongs_to :external_tests_guard
  belongs_to :external_test_type
end
