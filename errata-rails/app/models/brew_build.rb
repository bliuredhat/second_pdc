# == Schema Information
#
# Table name: brew_builds
#
#  id                  :integer       not null, primary key
#  package_id          :integer       not null
#  epoch               :string
#  sig_key_id          :integer       default(5), not null
#  signed_rpms_written :integer       default(0), not null
#  version             :string(50)    not null
#  release             :string(50)    not null
#

class BrewBuild < ActiveRecord::Base
  require 'brew'

  include BrewBuildImport
  include FindByIdOrName
  include RpmVersionCompare

  belongs_to :package
  belongs_to :sig_key

  has_many :brew_files, :include => [:package, :brew_build]
  has_many :brew_archives, :include => [:package, :brew_build]
  has_many :brew_rpms, :include => [:package, :arch, :brew_build]
  has_many :errata_brew_mappings, :conditions => {:current => 1}
  has_many :errata,
  :class_name => "Errata",
  :through => :errata_brew_mappings

  has_many :selectable_brew_files, :class_name => 'BrewFile',
    :conditions => proc { self.has_docker? ? { :brew_archive_type_id => BrewArchiveType::TAR_ID } : {} }

  belongs_to :released_errata,
  :class_name => "Errata",
  :foreign_key => 'released_errata_id'

  has_many :external_test_runs

  has_one :container_content

  validates_uniqueness_of :nvr
  validate :validate_docker

  def self.prepare_cached_files(brew_build_ids)
    BrewFile.
      where(:brew_build_id => brew_build_ids).
      includes(:package, :brew_build => [:sig_key]).
      group_by(&:brew_build_id)
  end

  def cached_brew_files
    cached = ThreadLocal.get(:cached_files) || {}
    # get cached files first if exists
    files = cached[self.id]
    # otherwise, look into database
    files ||= self.brew_files.to_a
  end

  def has_nonrpm?
    self.cached_brew_files.any?{|f| f.type != 'BrewRpm'}
  end

  def has_rpm?
    self.cached_brew_files.any?{|f| f.type == 'BrewRpm'}
  end

  def has_docker?
    @_has_docker ||= cached_brew_files.any?(&:is_docker?)
  end

  def tags(options = {})
    @_tags ||= (options[:brew] || Brew.get_connection).list_tags(self)
  end

  def reload(*args)
    @_tags = nil
    @_valid = nil
    @_listing_errors = nil
    @_has_docker = nil
    super
  end

  def epoch
    value = read_attribute('epoch')
    value = 0 if value.blank?
    return value
  end

  def is_signed?
    return sig_key.name != 'none'
  end

  def package_name
    return package.name
  end
  alias_method :name_nonvr, :package_name

  def revoke_signatures!
    self.sig_key = SigKey.find_by_name('none')
    self.signed_rpms_written = 0
    self.save

    rpms = brew_rpms.find(:all)
    rpms.each { |r| r.unsign! }
  end

  def mark_as_signed(key)
    raise "Cannot mark signed with the nil key" if key.name == 'none'
    self.sig_key = key
    self.save!

    rpms = brew_rpms.find(:all)
    rpms.each { |r| r.mark_as_signed }

    # Ensure signed files actually exist
    if Rails.env.production?
      begin
        rpms.each do |r|
          File.stat(r.file_path)
        end
      rescue Errno::ENOENT => e
        # If any file does not exist, revoke signatures and log an error
        errata_ids = errata.pluck(:id).join(', ')
        logger.error("Error updating sig state for build: #{nvr} errata: [#{errata_ids}] - #{e}")
        revoke_signatures!
        return false
      end
    end

    rpms.each { |r| r.save! }
    self.signed_rpms_written = 1
    self.save!
  end

  def srpm
    brew_rpms.find(:first, :conditions => ['arch_id = ?', Arch.SRPM])
  end

  def BrewBuild.make_from_rpc(id_or_nvr, opts={})
    build = BrewBuild.find_by_id_or_nvr(id_or_nvr)
    return build if build

    if !opts.include?(:fail_on_missing)
      opts[:fail_on_missing] = true
    end

    # convert integer string to real integer (must be done before getBuild call)
    id_or_nvr = id_or_nvr.to_i if looks_like_build_id? id_or_nvr

    brew = Brew.get_connection
    build = brew.getBuild(id_or_nvr)
    unless build
      return nil if !opts[:fail_on_missing]
      raise "ERROR: No such build #{id_or_nvr}"
    end

    nvr = build['nvr']

    unless build['state'] == 1
      raise "ERROR: Build #{nvr} not yet completed"
    end


    if ['comps', 'redhat-release'].include?(build['package_name']) && build['package_name'] != 'redhat-release-notes'
      build['package_name'] = build['package_name'] + '!' + build['version']
      build['version'] = build['release']
      build['release'] = ''
    end

    package = Package.find(:first,
                           :conditions => ["name = ?",
                                           build['package_name']])

    unless package
      package = Package.new(:name => build['package_name'])
      package.save
    end

    brew_build = BrewBuild.new(:version => build['version'],
                               :release => build['release'],
                               :epoch => build['epoch'],
                               :package => package,
                               :nvr => nvr,
                               :volume_name => build['volume_name']
                              )

    brew_build.id = build['id']

    brew_build.import_files_from_rpc

    brew_build.save!

    # If any of the files are tar archives, check if brew task was a docker task
    if brew_build.brew_files.tar_files.any? && docker_build_task?(build['task_id'])
      # Mark tar files as docker images
      brew_build.brew_files.tar_files.each do |tar_file|
        tar_file.flags << 'docker'
        tar_file.save!
      end
      brew_build.reload
    end

    return brew_build
  end

  def has_valid_listing?(pv_or_pr, options = {})
    @_valid ||= {}
    @_listing_errors ||= {}
    return @_valid[pv_or_pr] unless @_valid[pv_or_pr].nil?

    is_pdc = pv_or_pr.is_pdc?
    # Todo: catch just specific exceptions we might get from PDC
    rescue_these = is_pdc ? [StandardError] : [XMLRPC::FaultException]

    @_valid[pv_or_pr] = begin
      listing = ProductListing.for_pdc(is_pdc).find_or_fetch(pv_or_pr, self, options)
      # If the build has no rpms then we consider an empty listing to be valid
      ProductListing.for_pdc(is_pdc).listings_present?(listing) || !has_rpm?
    rescue *rescue_these => e
      @_listing_errors[pv_or_pr] ||= {}
      @_listing_errors[pv_or_pr][:fatal] = e.message
      false
    end

  end

  def listing_error(pv_or_pr, options = {})
    has_valid_listing?(pv_or_pr, options)
    (@_listing_errors || {}).fetch(pv_or_pr, {}).fetch(:fatal, nil)
  end

  def validate_docker
    if has_docker? && has_rpm?
      errors.add(:docker, 'docker builds should not contain RPMs')
    end
  end

  def to_s
    nvr.present? ? nvr : super
  end

  # TODO: remove this once all users are updated to know about non-rpm builds.
  # Bug 660270
  def BrewBuild.make_from_rpc_with_mandatory_srpm(nvr, *args, &block)
    BrewBuild.make_from_rpc_without_mandatory_srpm(nvr, *args, &block).tap do |build|
      raise "ERROR: Build #{build.nvr} does not have an SRPM!" if build.srpm.nil?
    end
  end
  class << self; alias_method_chain :make_from_rpc, :mandatory_srpm; end

  # returns details of released builds. A brew_build is released if it in
  # the released_packages tables and is current.
  #
  # Optional details include:
  #   - user_id, realname, login_name of user who added the build
  #   - reason
  #   - created_at - datetime when the build was added to released_package
  def self.released_builds(product_version)
    query = <<-EOSQL
      SELECT DISTINCT
        bb.id,
        bb.nvr,
        bb.released_errata_id,
        u.id as user_id,
        u.realname,
        u.login_name,
        ru.reason,
        ru.created_at
      FROM released_packages as rp
      JOIN brew_builds as bb ON rp.brew_build_id = bb.id
      LEFT OUTER JOIN errata_main as et ON et.id = bb.released_errata_id
      LEFT OUTER JOIN released_package_audits  as ra ON rp.id = ra.released_package_id
      LEFT OUTER JOIN released_package_updates as ru ON ru.id = ra.released_package_update_id
      LEFT OUTER JOIN users as u ON ru.who_id = u.id
      WHERE rp.current = 1
        AND rp.product_version_id = #{product_version.id}
      ORDER BY bb.nvr
    EOSQL
    BrewBuild.find_by_sql(query)
  end

  # Finds build, or returns nil if not found
  def self.find_by_id_or_nvr(id_or_nvr)
    return find_by_id(id_or_nvr) if looks_like_build_id? id_or_nvr
    find_by_nvr(id_or_nvr)
  end

  # Finds build, or raises exception if not found
  def self.find_by_id_or_nvr!(id_or_nvr)
    return find(id_or_nvr) if looks_like_build_id? id_or_nvr
    find_by_nvr!(id_or_nvr)
  end

  # Returns true if value is or can be converted to an integer
  def self.looks_like_build_id?(value)
    value.respond_to?(:to_i) && value.to_i.to_s == value.to_s
  end

  # Check if Brew task is a docker build task
  def self.docker_build_task?(task_id)
    return false if task_id.nil?

    brew = Brew.get_connection
    task_info = brew.getTaskInfo(task_id)
    return true if task_info['method'] == 'buildContainer'

    request = brew.getTaskRequest(task_id)
    if !request.kind_of?(Array)
      logger.error("Expected array response to Brew getTaskRequest #{task_id}: '#{request.inspect.truncate(80)}'")
      return false
    end

    brew_params = request.last
    format = brew_params['format'] || []
    format.include? 'docker'
  end

end
