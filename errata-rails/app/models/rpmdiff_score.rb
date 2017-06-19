# == Schema Information
#
# Table name: rpmdiff_scores
#
#  score       :integer       not null, primary key
#  description :string(240)   not null
#  html_color  :string(12)    not null
#

class RpmdiffScore < ActiveRecord::Base
  self.table_name = "rpmdiff_scores"
  self.primary_key = "score"

  PASSED = 0
  INFO = 1
  WAIVED = 2
  NEEDS_INSPECTION = 3
  FAILED = 4
  TEST_IN_PROGRESS = 498
  UNPACKING_FILES = 499
  QUEUED_FOR_TEST = 500
  DUPLICATE = -1

  # Scores for rpmdiff tests which are completed
  COMPLETED = [PASSED, INFO, WAIVED, NEEDS_INSPECTION, FAILED]

  # Scores for rpmdiff tests which are in progress
  NOT_COMPLETED = [TEST_IN_PROGRESS, UNPACKING_FILES, QUEUED_FOR_TEST]

  # Scores which are relevant to define autowaiving rules
  scope :for_autowaiving_rules, where('score > ? and score < ?', WAIVED, TEST_IN_PROGRESS)
end
