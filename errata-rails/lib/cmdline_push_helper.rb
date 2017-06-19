require 'optparse'

class CmdlinePushHelper

  DEFAULT_OPTIONS = [
                     { :args => ['--errata [ADVISORY]', 'Operate on [ADVISORY]. Full advisory name (RHBA-2009:1350) or numeric id both work.'], :name => :errata_ids, :array => true },
                     { :args => ['--release [RELEASE]', 'Operate on all errata belonging to a release. Only signed errata in SHIPPED_LIVE, and only for Quarterly Update releases.'], :name => :release },
                     { :args => ['--exclude-rhsa', 'Excludes RHSA advisories'], :name => :exclude_rhsa },
                     { :args => ['--dry-run', 'Shows which errata will be pushed'], :name => :dry_run }
  ]


  class << self

    def parse(args)
      res = Hash.new
      options = OptionParser.new do |opts|
        opts.banner = "Usage: #$0 [options]"
        parse_opts(opts, res)
        opts.on_tail('-h','--help', 'display this help and exit') do
          puts opts
          exit
        end
      end
      options.parse!(args)
      res
    end

    private

    def parse_opts(opts, res)
      parser_options.each do |option|
        opts.on(*option[:args]) do |arg|
          if option[:array]
            res[option[:name]] ||= []
            res[option[:name]] << arg
          else
            res[option[:name]] = arg
          end
        end
      end
    end

    def parser_options
      DEFAULT_OPTIONS
    end

  end


  def initialize(args, log, user)
    @parsed_args = self.class.parse(args)
    @log = log
    @user = user
  end

  def run!
    get_errata_from_release_or_ids
    if @parsed_args[:dry_run]
      puts @errata.collect { |e| e.advisory_name }.sort
    else
      create_jobs
    end
  end

  def die(msg)
    @log.fatal msg
    exit 1
  end

  protected

  def check
    if @parsed_args[:errata_ids].nil? and @parsed_args[:release].nil?
      die "Need a list of errata or a release name!"
    end
    if !@parsed_args[:errata_ids].nil? and @parsed_args[:release]
      die "--release and --errata are exclusive switches."
    end
  end

  def check_release(release)
    unless release
      die "Cannot find release with such name: #{@parsed_args[:release].inspect}"
    end
    if release.ship_date? && release.ship_date > Time.now
      die "#{release.name} ship date is in the future. You cannot push until #{release.ship_date}"
    end
  end

  def get_errata_from_release
    release = Release.find_by_name(@parsed_args[:release])
    check_release(release)
    @log.info "Finding errata for release #{release.name}"
    cond = self.release_conditions
    if @parsed_args[:exclude_rhsa]
      cond += " and errata_type != 'RHSA'"
    end
    @errata = release.errata.find(:all,
                                 :conditions => cond)
  end

  def get_errata_from_ids
    @parsed_args[:errata_ids].each do |id|
      e = Errata.find_by_advisory(id)
      @errata << e if check_can_push(e)
    end
  end

  def check_can_push_type(errata, type)
    policy = Push::Policy.policies[type].new(errata)
    if policy.push_possible? && policy.push_applicable?
      errata
    else
      @log.error "Cannot push errata #{errata.fulladvisory} to #{type}. Reasons:"
      policy.push_blockers.each { |b| @log.error b }
      @log.error "Not applicable for this advisory" if policy.push_possible? && !policy.push_applicable?
      false
    end
  end

  def get_errata_from_release_or_ids
    check
    @errata = []
    if @parsed_args[:errata_ids].nil?
      get_errata_from_release
    else
      get_errata_from_ids
    end
    if @errata.empty?
      die "Could not find any errata to operate on. Exiting"
    end
    @errata.delete_if { |e| !check_can_push(e) }
    @errata
  end

  def create_jobs
    @errata.each do |errata|
      @log.info "Creating job(s) for errata #{errata.fulladvisory} and user #{@user.login_name}"
      Array.wrap(create_push_job(errata)).each do |job|
        @log.info "Created #{job.class} #{job.id}"
        @log.info job.log
      end
    end
  end
end
