require 'jira'

module Jira
  class Rpc

    CLOSE_COMMENT = <<"eos"
Since the problem described in this issue should be \
resolved in a recent advisory, it has been closed.

For information on the advisory, and where to find the updated \
files, follow the link below.

If the solution does not work for you, open a new bug report.
eos

    # Returns an instance of Jira::ErrataClient connected to the configured JIRA instance.
    def self.get_connection
      Jira::ErrataClient.new(get_config)
    end

    # Execute a block.  If it raises an HTTP error, log details of the error and propagate.
    def self.with_log
      begin
        yield
      rescue JIRA::HTTPError => e
        JIRALOG.error "Error response from JIRA: #{e.message}\n#{e.response.body}"
        raise "Error response from JIRA: #{e.response.code} #{e.message}"
      rescue Exception => e
        # Catch other exceptions, such as connection refused
        JIRALOG.error "Error response from JIRA: #{e.message}"
        raise e
      end
    end

    private
    def self.get_config
      uri = URI.parse(Jira::JIRA_URL)
      use_ssl = uri.scheme == 'https'

      # sanity check to avoid leaks when somebody is not paying attention.
      raise ArgumentError, <<-'eos' if !use_ssl && ENV['ET_INSECURE_JIRA'] != '1' && Jira::JIRA_USER != Jira::JIRA_PASSWORD
Refusing to send JIRA username/password over cleartext connection.
Set the environment variable ET_INSECURE_JIRA=1 if you want to do this.
eos

      {
        :site => "#{uri.scheme}://#{uri.host}:#{uri.port}",
        :context_path => uri.path,
        :use_ssl => use_ssl,
        :username => Jira::JIRA_USER,
        :password => Jira::JIRA_PASSWORD,
        :auth_type => :basic
      }
    end
  end

  # A JIRA REST client.
  # Most functionality is provided by JIRA::Client; see the documentation at https://github.com/sumoheavy/jira-ruby
  class ErrataClient < JIRA::Client
    include Jira::Rpc::Transitions

    def initialize(*args)
      super(*args)

      # Let the default SSL paths be used for this client.
      # JIRA::Client misses the API for this, so we need to monkey patch
      request_client.instance_eval do
        @_real_http_conn = self.method(:http_conn)
        def http_conn(uri)
          out = @_real_http_conn.call(uri)
          out.cert_store = OpenSSL::X509::Store.new.tap{|s|s.set_default_paths}
          out
        end
      end
    end

    # Returns an enumerable search for JIRA issues.
    #
    # Use this method to enumerate through JIRA issues returned by a JIRA search.
    # The search will be automatically batched into several requests if the search results
    # cannot fit into a single response.
    #
    # Each enumerated object is an instance of JIRA::Resource::Issue.
    #
    # Example: get the issue key of every open issue:
    #
    #   keys = jira.searched_issues(:jql => "status = Open").map{|iss| iss.key}
    #
    # Options:
    #
    # [:batch_size] maximum number of issues processed per request to JIRA.
    #               The actual number of issues per request may be less, according to
    #               the configuration of the JIRA server.
    #
    # [:jql, :validateQuery, :fields, :expand]
    #        parameters for the JIRA search request,
    #        as described at https://docs.atlassian.com/jira/REST/6.1.5/#d2e2497 .
    #
    def searched_issues(options)
      options = default_search_options.merge(options)
      batch_size = options[:batch_size]
      raise ArgumentError("Need a strictly positive :batch_size") unless batch_size > 0

      options[:maxResults] = batch_size
      params = options.except(:batch_size)

      BatchedSearch.new(self, params)
    end

    def add_issue_addressed_comment(issue, errata, options={})
      comment = "This issue has been addressed in the following products:\n\n"
      comment += errata.product_versions.map { |ver| "  #{ver.description}" }.uniq.join("\n")
      comment += "\n\nVia #{errata.advisory_name} #{errata.errata_public_url}\n"

      add_comment_to_issue(issue, comment, options)
    end

    def add_security_resolve_comment(issue, errata)
      unless issue.is_security_restricted?
        JIRALOG.error "Issue #{issue.display_id} is not a security issue! Not adding comment"
        return false
      end

      add_issue_addressed_comment(issue, errata, :private => true)
    end

    def add_comment_to_issue(issue, comment, options={})
      options = {:private => true}.merge(options)

      # private => true is a shortcut to the predefined "private"
      # visibility, but passing in another visibility takes precedence
      if options[:private] && !options.include?(:visibility)
        options[:visibility] = Settings.jira_private_comment_visibility
      end

      # Note usage of 'build' rather than 'find' saves a pointless round trip to the server
      rpc_issue = self.Issue.build('id' => issue.id_jira.to_s)

      comment_post = {:body => comment}
      if vis=options[:visibility]
        comment_post.merge!(:visibility => vis)
      end
      JIRALOG.info "Posting comment #{rpc_issue.url}: #{comment_post.inspect}"
      comments = rpc_issue.comments.build

      Jira::Rpc.with_log{ comments.save!(comment_post) }
    end

    # Close a JIRA issue due to an advisory state change.
    #
    # Raises Jira::IllegalTransitionError if there is no legal
    # transition to Settings.jira_closed_status.
    def close_issue(issue, errata)
      unless issue.can_close?
        JIRALOG.error "Issue #{issue.display_id} for advisory #{errata.id} cannot be closed. Status #{issue.status} security? #{issue.is_security_restricted?}"
        return false
      end

      comment = Jira::Rpc::CLOSE_COMMENT + errata.errata_public_url
      JIRALOG.debug "Closing #{issue.display_id} for advisory #{errata.advisory_name} - #{errata.id}\n#{comment}"

      (transition, fields) = get_transition_with_fields(issue, Settings.jira_closed_status)

      post_body = {
        :fields => fields,
        :transition => {:id => transition['id']},
        :update => { :comment => [
          {:add => { :body => comment } }
        ] }
      }
      unless (vis=Settings.jira_close_comment_visibility).nil?
        post_body[:update][:comment][0][:add][:visibility] = vis
      end

      Jira::Rpc.with_log do
        url = transitions_rest_url(issue)
        JIRALOG.debug("Post to #{url}: #{post_body.inspect}")
        response = self.post url, post_body.to_json

        issue.status = Settings.jira_closed_status
        issue.save(:validate => false)
      end

    end

    # Like +close_issue+, but if the issue is unable to be closed due
    # to workflow restrictions, a comment is posted instead.
    def close_issue_or_comment(issue, errata)
      begin
        close_issue(issue, errata)
      rescue Jira::IllegalTransitionError => error
        JIRALOG.warn "Can't close #{issue.display_id} - #{error.inspect}\nPosting a comment instead."
        add_issue_addressed_comment(issue, errata, :visibility => Settings.jira_close_comment_visibility)
      end
    end

    private

    def issue_rest_url(issue)
      "#{self.options[:rest_base_path]}/issue/#{issue.id_jira}"
    end

    # An ongoing JIRA search.  See Jira::ErrataClient#searched_issues
    class BatchedSearch
      include Enumerable

      def initialize(client,params)
        @client = client
        @params = params
      end

      def each(&block)
        startAt = 0
        url = @client.options[:rest_base_path] + '/search'
        while true
          JIRALOG.debug "post #{url} - startAt #{startAt}, jql #{@params[:jql]}, validateQuery #{@params[:validateQuery]}"
          response = Jira::Rpc.with_log{ @client.post(url, {:startAt => startAt}.merge(@params).to_json) }
          result = JSON.parse(response.body)
          issues = result['issues']

          issues.each do |issue|
            block.call(@client.Issue.build(issue))
          end

          if startAt + issues.size >= result['total'].to_i
            break
          end
          startAt += issues.size
        end
      end
    end

    def default_search_options
      {:batch_size => 200}
    end
  end

end
