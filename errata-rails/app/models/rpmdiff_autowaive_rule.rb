class RpmdiffAutowaiveRule < ActiveRecord::Base
  include Audited

  self.table_name = 'rpmdiff_autowaive_rule'
  self.primary_key = 'autowaive_rule_id'

  # Only fail, if we activate this rule without content for the
  # mandatory fields provided.
  validates_presence_of :test_id, :package_name, :content_pattern, :reason,
    :if => :validation_required?
  validates_presence_of :product_versions,
    :if => :active?
  validate :package_exists
  validate :user_allowed_to_activate_rule, :if => :validation_required?

  belongs_to :rpmdiff_score,
    :foreign_key => 'score'

  belongs_to :approved_by,
    :class_name => 'User',
    :foreign_key => 'approved_by'

  belongs_to :who,
    :class_name => 'User',
    :foreign_key => 'created_by'

  belongs_to :rpmdiff_test,
    :foreign_key => 'test_id'

  has_many :rpmdiff_autowaive_product_versions,
    :foreign_key => 'autowaive_rule_id',
    :dependent => :destroy

  has_many :product_versions,
    :through => :rpmdiff_autowaive_product_versions,
    :order => 'name ASC'

  has_many :rpmdiff_autowaived_result_details,
    :foreign_key => 'autowaive_rule_id'

  has_many :result_details,
    :class_name => 'RpmdiffResultDetail',
    :through => :rpmdiff_autowaived_result_details,
    :source => :rpmdiff_result_details

  # If this is present it is the result detail that was used to create the autowaive rule
  belongs_to :created_from_rpmdiff_result_detail,
    :class_name => 'RpmdiffResultDetail'

  # If the rule was created from a particular result detail then
  # only a user who can waive that result can activate the rule
  def can_activate?
    return true if created_from_rpmdiff_result_detail.nil?
    created_from_rpmdiff_result_detail.rpmdiff_result.can_waive?
  end

  private

  def package_exists
    unless Package.find_by_name(package_name)
      errors.add(
        :package_name,
        "`#{package_name}` is not a valid package."
      )
    end
  end

  def user_allowed_to_activate_rule
    #
    # Users without permission to activate autowaiving rules should not be
    # able to activate rules and change active rules.
    #
    unless can_activate?
      errors.add(
        :active,
        "You don't have permission to update an active rule. " +
        "Please find the right role to do a request to activate/edit this rule in Note section of this page. "
      )
    end
  end

  def validation_required?
    active? && changed?
  end

  # For converting a string to a regexp that will match it
  # Default is to escape the spaces, we want to leave them alone so it looks nicer
  def self.content_to_regexp(content)
    unless content.nil?
      Regexp.escape(content).gsub('\\ ', ' ')
    end
  end

end
