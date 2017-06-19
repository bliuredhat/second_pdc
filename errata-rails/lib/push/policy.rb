module Push

  #
  # A push policy is an encapsulation of push logic per push type.
  #
  module Policy

    def self.new(errata, type)
      klass = policies[type] or raise ArgumentError, "Wrong type. No Policy exist for #{type}"
      klass.new(errata)
    end

    #
    # Registry for policies. Keep in mind the order is important!
    #
    # E.g. Dependencies exist at the moment between cdn and rhn live. A
    # blocker exists that an advisory has to be pushed first to RHN Live
    # then of CDN.
    #
    def self.policies
      @registry ||= begin
        reg = ActiveSupport::OrderedHash.new
        [
          [:rhn_live, RhnLive],
          [:rhn_stage, RhnStage],
          [:ftp, Ftp],
          [:altsrc, Altsrc],
          [:cdn, CdnLive],
          [:cdn_docker, CdnDocker],
          [:cdn_docker_stage, CdnDockerStage],
          [:cdn_stage, CdnStage],
        ].each do |type, klass|
          reg[type] = klass
        end
        reg
      end
    end

    def self.policies_for_errata(errata, opts={})
      policies = errata.supported_push_types.map { |target| self.policies[target].new(errata) }
      policies = policies.select { |policy| policy.staging == opts.fetch(:staging, false) }
      # Return both mandatory and optional live pushes by default
      policies = policies.select { |policy| policy.mandatory == opts[:mandatory] } unless opts[:mandatory].nil?
      policies.sort_by(&:index)
    end

    #
    # Design decision:
    #
    # Push policies follow the ActiveModel::Errors interface in order to
    # provide uniform access to errors. The only current draw back is
    # the missing use for error keys, since the UI only renders the
    # messages.
    #
    # In order to decouple push targets from policies, each policy can
    # support a push_type (which is inferred from it's class name) and a
    # push target. The push target is used to query the advisory if we
    # can push the advisory to a certain target (e.g. rhn live, cdn
    # stage, etc). Usually we can get away by simply using the push
    # type, since they following the same naming. For inconsistencies
    # tho, it is possible to set :push_target_override, in order to
    # query for a supported push target, but keep a type as
    # uniforming accessible.
    #
    class Base
      extend ActiveModel::Naming
      attr_reader :errors

      class_attribute :job_klass, :push_blockers_attr, :staging, :push_target_override, :mandatory, :index

      self.job_klass = nil
      self.push_blockers_attr = nil
      self.staging = true
      self.push_target_override = nil
      # Job that must be completed for an advisory to ship live
      self.mandatory = true
      # Defines order in which pushes are displayed and performed
      self.index = 10000

      def initialize(errata)
        @errata = errata
        @errors = ActiveModel::Errors.new(self)
      end

      def push_type_supported?
        @errata.supported_push_types.include? push_target
      end

      def can_push?(options = {})
        push_blockers(options).empty?
      end

      def has_pushed?
        @errata.has_pushed_since_last_respin?(self.job_klass)
      end

      def in_progress?
        self.job_klass.active_jobs.for_errata(@errata).any?
      end

      def push_job_since_last_push_ready
        @errata.push_job_since_last_push_ready(self.job_klass)
      end

      #
      # Was previously located in push_controller. All conditionals
      # should be re-factored into a check list perhaps?
      #
      # See Bug 1099330
      #
      def push_possible?(options = {})
        unless push_type_supported?
          @errors.add(push_target, "#{push_type_name} not supported for '#{@errata.fulladvisory}'.")
          return false
        end

        unless can_push?(options)
          @errors.add(push_target, "Can't push advisory to #{push_type_name} now due to: #{push_blockers(options).join(", ")}")
          return false
        end

        if existing_job = self.job_klass.active_job_for(@errata)
          # Active job exists
          @errors.add(push_target, "An <a href='/push/push_results/#{existing_job.id}'>existing #{self.job_klass.name.titleize}</a> is already running. You will need to cancel it to schedule a new one.")
          return false
        end

        return true
      end

      # If push_type_supported? is true but push_applicable? is false,
      # it means that the advisory's release/product/variant generally
      # does include this target, but some condition means that the
      # push must be skipped.
      #
      # For example, FTP push should be skipped if all RPMs in the
      # advisory have FTP exclusions, or if the advisory is text-only.
      def push_applicable?
        return false unless push_type_supported?

        method = "has_#{self.push_target}?"
        return true unless @errata.respond_to?(method)

        @errata.send(method)
      end

      def create_new_push_job(pushed_by)
        self.job_klass.new(:errata => @errata, :pushed_by => pushed_by)
      end

      def self.push_type
        name.demodulize.underscore.to_sym
      end

      def push_type
        self.class.push_type
      end

      def self.push_target
        push_target_override or push_type
      end

      def push_target
        self.class.push_target
      end

      def push_type_name
        push_type.to_s.titleize
      end

      def push_blockers(options = {})
        @errata.send(self.push_blockers_attr, options)
      end

      #
      # Needed to implement ActiveModel::Errors
      #
      def self.human_attribute_name(attr, options={})
        attr
      end

    end


    class Ftp < Base

      self.job_klass = FtpPushJob
      self.push_blockers_attr = :push_ftp_blockers
      self.staging = false
      self.mandatory = false
      self.index = 40

      def push_possible?(options = {})
        return false unless super

        if ftp_paths.empty?
          errors.add(:ftp, "Cannot push '#{@errata.fulladvisory}' to ftp. File list is empty!")
          return false
        end

        return true
      end

      private

      def ftp_paths
        Push::Ftp.ftp_dev_file_map(@errata)
      end

    end


    class CdnStage < Base

      self.job_klass = CdnStagePushJob
      self.push_blockers_attr = :push_cdn_stage_blockers
      self.index = 10

    end


    #
    # Note: This policy uses not the default push blocker attribute
    # :push_cdn_blockers. Reason for this is the default blockers will
    # most likely block a cdn live push if the user kicks of the push
    # and pushes RHN Live and CDN Live sequentially.
    #
    class CdnLive < Base

      self.job_klass = CdnPushJob
      self.push_blockers_attr = :push_cdn_if_live_push_succeeds_blockers
      self.staging = false
      self.push_target_override = :cdn
      self.index = 30

    end

    class CdnDocker < Base

      self.job_klass = CdnDockerPushJob
      self.push_blockers_attr = :push_cdn_docker_blockers
      self.mandatory = true
      self.staging = false
      self.push_target_override = :cdn_docker
      self.index = 35

    end

    class CdnDockerStage < Base

      self.job_klass = CdnDockerStagePushJob
      self.push_blockers_attr = :push_cdn_docker_stage_blockers
      self.index = 15

    end

    class RhnLive < Base

      self.job_klass = RhnLivePushJob
      self.push_blockers_attr = :push_rhn_live_blockers
      self.staging = false
      self.index = 20

    end


    class RhnStage < Base

      self.job_klass = RhnStagePushJob
      self.push_blockers_attr = :push_rhn_stage_blockers
      self.index = 0

    end


    class Altsrc < Base
      self.job_klass = AltsrcPushJob
      self.push_blockers_attr = :push_altsrc_blockers
      self.staging = false
      self.mandatory = false
      self.index = 50
    end

  end
end
