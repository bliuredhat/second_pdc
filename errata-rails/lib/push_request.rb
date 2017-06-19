# This class represents a request from the user to push an advisory to one or
# more targets.
class PushRequest

  attr_accessor :errata, :policies
  # This represents a single target requested by the user, along with any
  # options and pre/post tasks.
  def initialize(errata, targets, policies)
    @errata = errata
    @targets = targets
    @policies = policies
  end

  class Target
    attr_accessor :target,
                  :options,
                  :append_options,
                  :exclude_options,
                  :pre_tasks,
                  :append_pre_tasks,
                  :exclude_pre_tasks,
                  :post_tasks,
                  :append_post_tasks,
                  :exclude_post_tasks
    # These aliases make API and internal model more consistent
    alias_method :name, :target
    alias_method :pre_push_tasks, :pre_tasks
    alias_method :post_push_tasks, :post_tasks

    def initialize(args = {})
      args.each do |k,v|
        next unless PushRequest::Target.method_defined?("#{k}=")
        self.send("#{k}=", v)
      end
    end
    # Get the options in the format suitable for pub.
    # Returns a hash, or nil.
    #
    # In our API, options may be passed as either:
    #
    #   {'opt1' => 'val1', 'opt2' => 'val2', ...}
    #
    # or:
    #
    #   ['opt1', 'opt2', ...]
    #
    # ... in which case the values are all "true".
    #
    # This method converts the second form into the first form, which is the format
    # used by pub.
    def pub_options
      PushRequest::Target.options_as_hash(options)
    end

    def self.options_as_hash(options)
      if !options || options.kind_of?(Hash)
        return options
      end
      Hash[ options.map{ |v| [v, true] } ]
    end

    # Construct a new instance from target-related parameters in +params+.
    def self.from_target_params(params)
      new(params)
    end
  end

  # Returns the targets requested by the user (array of PushRequest::Target).
  #
  # The returned values are sorted so that RHN-related targets come earlier
  # than CDN.  This is important due to validations on CDN push jobs which
  # check whether an RHN job exists.
  def targets
    unsorted = @targets
    unsorted.sort_by do |t|
      name = t.name.downcase
      key = name.include?('rhn') ? 0 : 1
      # RHN comes before others, but otherwise the order is as set by the user.
      [key, unsorted.index(t)]
    end
  end

  # Given a +target+ (which should be one of the +targets+ on this push request),
  # returns the corresponding policy.
  #
  # If the returned value is nil, it means the target is not applicable at this time.
  def policy_for_target(target)
    policies.find{ |p| p.push_target.to_s == target.name }
  end

  # Given one or more +errata+ to operate on, and request +params+, returns
  # an array of PushRequest.
  def self.from_errata_and_params(errata, params)
    target_params = target_params(params)

    errata_with_policies(errata, params).map do |e, policies|
      from_parsed_params(target_params, e, policies)
    end
  end

  ################### all private under here ##################################

  # Returns a single PushRequest
  def self.from_parsed_params(target_params, errata, policies)
    targets = if [:live, :stage].include?(target_params)
      # If our targets are the special values of live/stage, then policies was
      # already filtered to the applicable live or stage policies for this
      # errata, so we just use all of them.
      policies.map do |p|
        Target.from_target_params('target' => p.push_target.to_s)
      end
    else
      # If targets were explicitly specified then we need to do additional
      # checks; targets might be disabled, depending on the 'skip_*'
      # parameters
      target_params.
        select { |t| use_push_target?(t, policies) }.
        map(&Target.method(:from_target_params))
    end
    PushRequest.new(errata, targets, policies)
  end
  private_class_method :from_parsed_params

  # Returns either :stage, :live, or an array of targets.
  def self.target_params(params)
    default_target_params(params) || explicit_target_params(params)
  end
  private_class_method :target_params

  # Returns target params (not processing "defaults")
  def self.explicit_target_params(params)
    targets = raw_target_params(params)

    targets.each do |t|
      # Fix up any nested [] which were munged into nil
      %w[pre_tasks post_tasks].each do |key|
        if t.include?(key) && t[key].nil?
          t[key] = []
        end
      end

      # Raise if target name was not specified
      unless t.include?('target')
        raise DetailedArgumentError.new(:target => 'name is missing in request')
      end
    end

    targets
  end
  private_class_method :explicit_target_params

  # Returns "defaults" if it was set, or nil
  def self.default_target_params(params)
    defaults = params[:defaults]
    return unless defaults

    unless %w[live stage].include?(defaults)
      raise DetailedArgumentError.new(
        :defaults => "invalid value, expected 'live' or 'stage'")
    end

    if params[:_json] || params[:target]
      raise DetailedArgumentError.new(
        :request_body => "must be empty when using 'defaults'")
    end

    defaults.to_sym
  end
  private_class_method :default_target_params

  # Returns the raw parameters for targets, extracted from +params+.
  # Returns an array.
  def self.raw_target_params(params)
    if params.include?('_json')
      # An array has been passed in the POST data.  Incoming [] are
      # munged into nil on the way in, so we have to undo that.
      # https://github.com/rails/rails/issues/13420
      params['_json'] || []
    else
      # No defaults, nothing passed in _json.  We were probably passed
      # a single target whose attributes were spliced into params.
      [params.slice(*%w[target skip_pushed skip_in_progress
                        options append_options exclude_options
                        pre_tasks append_pre_tasks exclude_pre_tasks
                        post_tasks append_post_tasks exclude_post_tasks])]
    end
  end
  private_class_method :raw_target_params

  # Parse the request parameters to decide which push policies are applicable to
  # each advisory.
  #
  # Returns an array of:
  #
  #  +[errata, policies]+
  #
  def self.errata_with_policies(errata, params)
    defaults = params['defaults']

    # When defaults=stage or live is provided, only those policies
    # are applicable.  Otherwise, all policies are applicable.
    policy_stage_values = if defaults == 'live'
      [false]
    elsif defaults == 'stage'
      [true]
    else
      [true, false]
    end

    # We may be working on one or multiple errata.
    errata = Array.wrap(errata)

    errata.map do |e|
      policies = policy_stage_values.
        map{ |x| Push::Policy.policies_for_errata(e, :staging => x) }.
        inject(&:concat)

      # defaults doesn't re-push already successfully pushed targets or
      # targets already in progress, and should omit anything not
      # applicable.
      if defaults
        policies.reject!(&:has_pushed?)
        policies.reject!(&:in_progress?)
        policies = policies.select(&:push_applicable?)
      end

      [e, policies]
    end
  end
  private_class_method :errata_with_policies

  # Returns true if the given +target_param+ should be used. +policies+ is
  # needed to check the current status of this target.
  def self.use_push_target?(target_param, policies)
    policy = policies.find{ |p| target_param['target'] == p.push_target.to_s }
    unless policy
      # probably means user passed a bogus target - keep it for now, will be
      # validated elsewhere
      return true
    end

    if target_param['skip_pushed'] && policy.has_pushed?
      return false
    end

    if target_param['skip_in_progress'] && policy.in_progress?
      return false
    end

    true
  end
  private_class_method :use_push_target?
end
