class CdnRepoPackage < ActiveRecord::Base
  include Audited

  belongs_to :cdn_repo
  belongs_to :package
  belongs_to :who,
    :class_name => "User",
    :foreign_key => "who_id"

  has_many :cdn_repo_package_tags, :dependent => :destroy

  validate :valid_cdn_repo_type
  validates_associated :package
  validates_uniqueness_of :package_id, :scope => :cdn_repo_id,
    :message => 'is already mapped to this CDN repository'

  before_destroy :can_destroy?

  def valid_cdn_repo_type
    if !cdn_repo.supports_package_mappings?
      errors.add(:cdn_repo, 'does not support package mappings')
    end
  end

  def tag_templates
    cdn_repo_package_tags.map(&:tag_template).sort
  end

  def can_destroy?
    check_if_mapping_is_in_use
    errors.empty?
  end

  def check_if_mapping_is_in_use
    errata_in_push = get_advisories_using_mapping
    if errata_in_push.any?
      errata = errata_in_push.map(&:fulladvisory).join(', ')
      errors.add("Error:", "CDN repo package mapping with package #{package.name} is currently in use by<br>#{errata}")
    end
  end

  def get_advisories_using_mapping
    errata_in_push = []
    package.errata_brew_mappings.tar_files.each do |m|
      next unless m.errata.status == State::IN_PUSH && m.errata.has_docker?
      docker_repos = m.
                     product_version.
                     active_cdn_repos.
                     where(:type => 'CdnDockerRepo')
      errata_in_push << m.errata if docker_repos.include?(cdn_repo)
    end
    errata_in_push
  end
end
