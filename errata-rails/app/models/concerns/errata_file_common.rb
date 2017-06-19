module ErrataFileCommon
  extend ActiveSupport::Concern

  included do |klass|
    belongs_to :package
    belongs_to :arch
    belongs_to :brew_rpm
    belongs_to :brew_build

    belongs_to :errata,
      :foreign_key => :errata_id

    belongs_to :who,
      :class_name => 'User', :foreign_key => :who

    belongs_to :variant,
      :class_name => klass.variant_class_name, :foreign_key => klass.variant_id_field

    before_validation(:on => :create) do
      self.who ||= User.current_user
      self.change_when = Time.now
      self.ftp_file = Push::Ftp.make_ftp_path(brew_rpm, variant, arch)
      self.brew_build = brew_rpm.brew_build
      self.signed = self.brew_build.sig_key.name
      self.md5sum = brew_rpm.md5sum
    end

    scope :current, where(:current => true)
    scope :for_variant, lambda { |variant| where(klass.variant_id_field => variant) }
    scope :for_package, lambda { |package| where(:package_id => package) }
  end

  module ClassMethods
    def for_build_mapping(build_mapping)
      self.where(
        :errata_id => build_mapping.errata,
        :brew_build_id => build_mapping.brew_build,
        self.variant_id_field => build_mapping.variants)
    end
  end

  def is_srpm?
    return self.arch.try(:name) == 'SRPMS'
  end

  def update_file_path
    self.devel_file = brew_rpm.file_path
    self.md5sum = brew_rpm.md5sum
    self.signed = brew_build.sig_key.name
  end

end
