class JiraSecurityLevel < ActiveRecord::Base
  EFFECTS = %w{PUBLIC PRIVATE SECURE}

  has_many :jira_issues

  validates_each :effect do |level,k,v|
    level.errors.add(k, "'#{v}' not a valid effect") unless EFFECTS.include? v
  end

  before_validation :set_default_effect

  def self.make_from_rpc(rpc_seclevel)
    return unless rpc_seclevel
    JiraSecurityLevel.where(:id_jira => rpc_seclevel['id'].to_i).first_or_create!(:name => rpc_seclevel['name'])
  end

  def is_private?
    effect != 'PUBLIC'
  end

  private

  def set_default_effect
    self.effect ||= default_effect(self.name) unless self.name.nil?
  end

  def default_effect(name)
    Settings.jira_security_level_effects[name] || 'SECURE'
  end
end
