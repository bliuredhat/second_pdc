class ContainerRepo < ActiveRecord::Base

  belongs_to :container_content

  has_many :container_repo_errata, :class_name => 'ContainerRepoErrata', :dependent => :destroy
  has_many :errata, :through => :container_repo_errata

  def cdn_repo
    @cdn_repo ||= CdnDockerRepo.for_docker_repo_name(name)
  end

  def tag_list
    tags.try(:split, ' ') || []
  end

  def comparison
    @comparison ||= JSON.parse(read_attribute(:comparison) || '{}', symbolize_names: true)
  end

  def has_comparison?
    comparison[:reason] == 'OK'
  end

  def comparison_reason_text
    comparison[:reason_text] || 'No comparison is available'
  end

  #
  # Returns a Hash:
  #  - keys are [:new, :upgrade, :downgrade, :remove]
  #  - values are Hashes:
  #    - keys are RPM names with Arch, as returned by Lightblue
  #    - values are BrewRpm objects, or nil if not found in ET
  #
  # For example:
  # {
  #   :new => {
  #     "libX11-1.6.3-3.el7.x86_64" => #<BrewRpm ...>
  #     ...
  #   }
  #   ...
  # }
  #
  def rpms
    return @rpms if @rpms
    @rpms = {}
    return @rpms if comparison[:rpms].blank?

    # This ensures consistent key and rpm order
    [:new, :upgrade, :downgrade, :remove].each do |key|
      rpm_list = comparison[:rpms][key]
      next if rpm_list.empty?
      rpm_list.sort!
      brew_rpms = rpm_list.map{|x| brew_rpm_for_name(x)}
      @rpms[key] = Hash[rpm_list.zip(brew_rpms)]
    end
    @rpms
  end

  def comparison_build
    @comparison_build ||= BrewBuild.find_by_nvr(comparison[:with_nvr])
  end

  private

  def brew_rpm_for_name(name)
    (rpm_name, _, arch_name) = name.rpartition('.')
    BrewRpm.joins(:arch).where(:name => rpm_name, 'errata_arches.name' => arch_name).first
  end

end
