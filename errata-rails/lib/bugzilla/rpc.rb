require 'xmlrpc/client'

module Bugzilla
  class Rpc
    attr_reader :last_call_time
    attr_reader :server

    INCLUDE_FIELDS = [:alias,
                      :blocks,
                      :cf_pm_score,
                      :cf_qa_whiteboard,
                      :cf_release_notes,
                      :cf_verified,
                      :classification,
                      :component,
                      :depends_on,
                      :flags,
                      :groups,
                      :id,
                      :keywords,
                      :last_change_time,
                      :priority,
                      :product,
                      :severity,
                      :status,
                      :summary]

    CLOSE_COMMENT = <<END_OF_STRING
Since the problem described in this bug report should be
resolved in a recent advisory, it has been closed with a
resolution of ERRATA.

For information on the advisory, and where to find the updated
files, follow the link below.

If the solution does not work for you, open a new bug report.

END_OF_STRING

    class RPCBug

      CF_KEYS = [:pm_score, :qa_whiteboard, :release_notes, :verified]
      KEYS = CF_KEYS + [:alias, :blocks, :bug_severity, :component,
                        :component_name, :depends_on, :issuetrackers,
                        :keywords, :priority]

      attr_accessor :flags, :errata_package

      def initialize(bug_hash)
        @hash = bug_hash
        @flags = ''
        unless @hash['flags'].blank?
          @flags = @hash['flags'].collect {|f| f['name'] + f['status']}.join(', ')
        end
      end

      # This method will override the method created by attr_accessor. This is done
      # on purpose, so that the errata package can be found or created automatically
      # if it is not explicitly set.
      def errata_package
        @errata_package ||= Package.find_or_create_by_name(@hash['component'])
      end

      def can_close?
        return false if is_security?
        return @hash['status'] != 'CLOSED'
      end

      def is_blocker?
        has_flags?(['blocker'])
      end

      def is_exception?
        has_flags?(['exception'])
      end

      def is_private?
        !@hash['groups'].blank?
      end

      def is_security?
        return @hash['product'] == 'Security Response'
      end

      def bug_id
        id = @hash['id']
        id ||= @hash['bug_id']
        id
      end

      def bug_status
        @hash['status']
      end

      def changeddate
        rpcdate = @hash['last_change_time']
        return nil unless rpcdate
        # Bugzilla xmlrpc returns UTC time not EST time. XMLRPC::DateTime doesn't have
        # timzone attribute, XMLRPC::DateTime.to_time call Time.gm which will return UTC time
        # by default
        # See:
        # http://www.ruby-doc.org/stdlib-1.8.7/libdoc/xmlrpc/rdoc/XMLRPC/DateTime.html#method-i-to_time
        # http://ruby-doc.org/core-1.8.7/Time.html#method-c-gm
        Time.zone.parse("#{rpcdate.to_time}")
      end

      def short_desc
        @hash['summary']
      end

      def to_hash
        return {
          :bug_status    => self.bug_status,
          :short_desc    => self.short_desc,
          :is_private    => self.is_private?   ? 1 : 0,
          :is_security   => self.is_security?  ? 1 : 0,
          :is_blocker    => self.is_blocker?   ? 1 : 0,
          :is_exception  => self.is_exception? ? 1 : 0,
          :flags         => self.flags,
          :alias         => self.alias,
          :priority      => self.priority,
          :bug_severity  => self.bug_severity,
          :qa_whiteboard => self.qa_whiteboard,
          :keywords      => self.keywords,
          :issuetrackers => self.issuetrackers,
          :pm_score      => self.pm_score,
          :last_updated  => self.changeddate,
          :release_notes => self.release_notes,
          :verified      => self.verified,
          # pass package object instead to prevent sql reload
          :package       => self.errata_package,
          :reconciled_at => Time.now
        }
      end

      def method_missing(name, *args)
        return super unless KEYS.include?(name)
        key = if CF_KEYS.include?(name)
                "cf_#{name}"
              elsif name == :component_name
                'component'
              else
                name.to_s
              end
        value = @hash[key]
        # Handle multi-component bugzilla. For any product we care about, it will
        # be restricted to a single component, but the value still comes as an
        # single element array in certain queries.
        if 'component' == key && value.is_a?(Array)
          value = value.first
        end
        value ||= ''
        if ['keywords', 'cf_verified', 'alias'].include?(key) && value.is_a?(Array)
          value = value.join(', ')
        end
        value
      end

      # TODO: maybe this can use the new code in lib/bz_flag.rb
      # NB: the flags arg here is an array of flag names
      def has_flags?(flags)
        bug_flags = @flags.split(',').collect{ |f| f.strip }.to_set
        flags.all? {|f| bug_flags.include?("#{f}+")}
      end
    end

    class BugzillaConnection < XMLRPC::Client
      # Sits between the server's proxy and method calls
      # ensures login before calling rpc methods
      class AuthProxy
        def initialize(server, prefix)
          @server = server
          @proxy = @server.proxy(prefix)
        end

        # Only allow update methods against bugzilla.redhat.com in production environment
        def can_perform_method_call?(rpc_method)
          return true if Rails.env.production?
          return true unless 'bugzilla.redhat.com' == @server.hostname
          return true if rpc_method.to_s =~ /^get|^search/
          false
        end

        # Ensure logged in, and method callable in environment
        # forward rpc method call on to proxy
        def method_missing(rpc_method, *args)
          return unless can_perform_method_call? rpc_method
          @server.login unless @server.authenticated?
          @proxy.send(rpc_method, *@server.add_auth_token_maybe(args))
        end
      end

      def initialize(host, verify_ssl = true)
        super(host, '/xmlrpc.cgi', port=nil, proxy_host=nil, proxy_port=nil, user=nil, password=nil, use_ssl=true, timeout=240)
        if verify_ssl
          @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          store = OpenSSL::X509::Store.new
          store.set_default_paths
          @http.cert_store = store
        else
          @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        @hostname = host
        @auth_token = nil

        def login
          @auth_token = nil
          resp = call('User.login', {'login' => BUGZILLA_USER, 'password' => BUGZILLA_PASSWORD})
          @auth_token = resp['token'] if resp && resp.is_a?(Hash) && resp.has_key?('token')
        end
      end
      attr_reader :hostname

      def auth_proxy(prefix)
        AuthProxy.new(self, prefix)
      end

      def authenticated?
        @auth_token || cookie =~ /Bugzilla_logincookie/
      end

      def add_auth_token_maybe(args)
        return args unless @auth_token
        token_pair = { 'Bugzilla_token' => @auth_token }
        if args.empty?
          args[0] = token_pair
        elsif args[0].is_a?(Hash)
          args[0].merge!(token_pair)
        end
        args
      end

    end

    def self.get_connection(unique = true)
      if Rails.env.test?
        return TestRpc.new
      end

      return Rpc.new if unique
      @@rpc ||= Rpc.new
    end

    # We know these hosts have a proper signed SSL certificates
    HOSTS_WITH_GOOD_CERTS = %w[
      bugzilla.redhat.com
      partner-bugzilla.redhat.com
    ]

    # The staging and QE bugzilla instances use self-signed SSL certs and hence
    # don't verify successfully. Let's skip the SSL cert verification if not
    # in production and we know it would fail. (Quick fix for Bug 920891).
    def self.really_verify_ssl?(verify_ssl, host)
      Rails.env.production? ? verify_ssl : (verify_ssl && HOSTS_WITH_GOOD_CERTS.include?(host))
    end

    def initialize(host = BUGZILLA_SERVER, verify_ssl = true)
      @server = BugzillaConnection.new(host, Rpc.really_verify_ssl?(verify_ssl, host))
      @bug = @server.auth_proxy('Bug')
      @releases = @server.auth_proxy('Releases')
    end

    def approved_components_for(release_flag)
      res = @releases.getReleaseComponents({:release => release_flag})
      approved = Set.new
      approved.merge res['approved'].collect {|a| a['name']}
      approved.merge res['capacity'].collect {|a| a['name']}
      approved
    end


    def add_comment(bug_id, comment, is_private = true)
      unless Rails.env.production?
        Rails.logger.info "Comment on Bug #{bug_id}: #{comment}"
      end
      @bug.add_comment({:id => bug_id, :comment => comment, :private => is_private})
    end

    # Fetches all bug ids from bugzilla that have changed
    # since a given time.
    def bugs_changed_since(last_update, options={})
      raise ArgumentError, "Missing last_update date" if last_update.nil?

      options = {'include_fields' => INCLUDE_FIELDS}.merge(options)

      from = last_update.localtime.to_s(:db)
      bz_boolean_chart = {:f1 => 'delta_ts', :o1 => 'greaterthan', :v1=> from}

      if to = options.delete('to_date')
        to = to.localtime.to_s(:db)
        bz_boolean_chart.merge!({:j_top => 'AND_G', :f2 => 'delta_ts', :o2 => 'lessthaneq', :v2 => to})
      end

      res = bug_search(options.merge(bz_boolean_chart))
      bugs = to_rpcbugs(res['bugs'])
      # Restrict bugs to those with a given classification
      classifications = Settings.bugzilla_classifications
      unless classifications.blank?
        bugs = bugs.select {|b| classifications.include?(b.classification)}
      end
      bugs
    end

    # Can't mock instance variable in the test, so I create a
    # method for it.
    def bug_search(options)
      @bug.search(options)
    end

    # returns the result of Bugzilla#get rpc as a Hash. If there was an
    # XMLRPC::FaultException when fetching the bugs a nil is returned.
    # The method also accepts an optional boolean parameter :permissive
    # which will be passed to Bugzilla#get.
    # All errors and faults are logged
    #
    # see: https://bugzilla.redhat.com/docs/en/html/api/Bugzilla/WebService/Bug.html#get
    def raw_get_bugs(bug_list, opts = {})
      params = { :ids => bug_list, :include_fields => INCLUDE_FIELDS }
      params.merge!(opts.slice(:permissive))

      ret = nil
      begin
        ret = @bug.get(params)
      rescue XMLRPC::FaultException => e
        BUGLOG.error "Failed when fetching bugs: [%s], Error: %s" % [
          bug_list.join(', '),
          e.message
        ]
      end
      return if ret.nil?

      # log the faults if any
      if (faults = ret.fetch('faults', [])).any?
        BUGLOG.error "Bugzilla returned faults when fetching bugs: [%s], faults: %s " % [
          bug_list.join(', '), faults
        ]
      end
      ret
    end

    def get_bugs(bug_list, opts = {})
      res = raw_get_bugs(bug_list, opts)
      res ? to_rpcbugs(res['bugs']) : []
    end

    def mark_bug_on_qa(bug, errata)
      Rails.logger.debug "Moving bug #{bug.id} to ON_QA for errata #{errata.id} " + "- #{errata.fulladvisory}"

      bz_comment = "Bug report changed to ON_QA status by Errata System.\n"
      bz_comment += "A QE request has been submitted for advisory #{errata.fulladvisory}\n"
      bz_comment += "https://errata.devel.redhat.com/advisory/#{errata.id}"

      if changeStatus(bug.id, 'ON_QA', bz_comment)
        bug = Bug.find(bug.bug_id)
        bug.bug_status = 'ON_QA'
        bug.was_marked_on_qa = 1
        bug.save
      end
    end

    def mark_bug_as_release_pending(errata, bug)
      return unless State::PUSH_READY == errata.status
      return if bug.is_security?
      return if ["RELEASE_PENDING", "CLOSED"].include?(bug.bug_status)

      bz_comment = "Bug report changed to RELEASE_PENDING status by Errata System.\n"
      bz_comment += "Advisory #{errata.fulladvisory} has been changed to #{errata.status} status.\n"
      bz_comment += "https://errata.devel.redhat.com/advisory/#{errata.id}"
      Rails.logger.info "Moving bug #{bug.bug_id} status into RELEASE_PENDING"
      changeStatus(bug.bug_id, 'RELEASE_PENDING', bz_comment)

      bug = Bug.find(bug.bug_id)
      bug.bug_status = 'RELEASE_PENDING'
      bug.save
    end

    def mark_bugs_as_release_pending(errata)
      return unless State::PUSH_READY == errata.status

      invalid_states = ["RELEASE_PENDING", "CLOSED"]
      bugs = errata.bugs.find(:all, :conditions => ['bug_status not in (?)',
                                                    invalid_states])

      if bugs.empty?
        Rails.logger.info "No bugs to mark as RELEASE_PENDING for errata #{errata.id} - #{errata.fulladvisory}"
        return
      end

      Rails.logger.info "Moving #{bugs.length} bugs into RELEASE_PENDING for errata #{errata.id} - #{errata.fulladvisory}"
      rpc_bugs = get_bugs(bugs.collect{ |b| b.id})
      rpc_bugs.each do |rpc_bug|
        mark_bug_as_release_pending(errata, rpc_bug)
      end
      Rails.logger.info "Done marking bugs as RELEASE_PENDING"
    end

    def reconcile_bugs(bug_ids, updated_since = nil)
      return if bug_ids.empty?

      bugs_from_rpc = get_bugs(bug_ids)

      Rails.logger.debug "Got back #{bugs_from_rpc.length} bugs from RPC"

      bugs_from_rpc.each do |b|
        Bug.update_from_rpc(b)
      end
    end

    def changeStatus(bug_id, newstatus, comment)
      Rails.logger.debug "Changing state of #{bug_id} to #{newstatus} #{comment}"
      @bug.update({:ids => [bug_id], :status => newstatus, :comment => {:body => comment, :is_private => true}})
    end

    def close_bugs(errata)
      ids = errata.bugs.collect {|b| b.bug_id}
      bugs = get_bugs(ids)
      bugs.each do |b|
        if b.can_close?
          closeBug(b, errata)
        elsif b.is_security?
          add_security_resolve_comment(b, errata)
        end
      end
    end

    def add_security_resolve_comment(bug, errata)
      unless bug.is_security?
        Rails.logger.error "Bug #{bug.bug_id} is not a security bug! Not adding comment"
        return false
      end
      comment = "This issue has been addressed in the following products:\n\n"
      errata.product_version_descriptions.each do |description|
        comment += "  #{description}\n"
      end
      comment += "\nVia #{errata.advisory_name} #{errata.errata_public_url}\n"

      Rails.logger.debug "add_security_resolve_comment\n#{comment}"

      add_comment bug.bug_id, comment, false
    end

    def closeBug(bug, errata)
      unless bug.can_close?
        Rails.logger.error "Bug #{bug.bug_id} for advisory #{errata.id} cannot be closed. Status #{bug.bug_status} security? #{bug.is_security?}"
        return false
      end

      Rails.logger.debug "Closing #{bug.bug_id} for advisory #{errata.advisory_name} - #{errata.id}"
      comment = CLOSE_COMMENT + errata.errata_public_url
      Rails.logger.debug comment
      begin
        @bug.update({:ids => [bug.bug_id], :status => 'CLOSED', :resolution => 'ERRATA', :comment => {:body => comment, :is_private => false}})
        bug.bug_status = 'CLOSED'
        bug.save(:validate => false)
      rescue Exception => e
        log_rpc_failure(e)
        return false
      end
    end

    def to_rpcbugs(bugs)
      bugs.collect {|b| RPCBug.new(b)}
    end

    def log_rpc_failure(error)
      Rails.logger.error "Bugzilla RPC error: " + error.message
      Rails.logger.error error.backtrace.join("\n")
    end
  end
end
