require 'test_helper'

class RoutesTest < ActionDispatch::IntegrationTest

  test "routes" do
    # Some of these are redirects now I think. Todo: Update for 2.3 UI.
    #assert_routing 'errata/showrequest.cgi',    { :controller => 'errata',   :action => 'show'           }
    #assert_routing 'errata/erratainfo.cgi',     { :controller => 'errata',   :action => 'info'           }
    #assert_routing 'errata/listrequest.cgi',    { :controller => 'errata',   :action => 'list'           }
    #assert_routing 'errata/listerrata.cgi',     { :controller => 'errata',   :action => 'list_errata'    }
    #assert_routing 'errata/showactivity.cgi',   { :controller => 'errata',   :action => 'show_activity'  }

    assert_routing 'errata/erratabugnav.cgi',   { :controller => 'bugs',     :action => 'erratabugs'     }
    assert_routing 'errata/qublockers.cgi',     { :controller => 'bugs',     :action => 'qublockers'     }
    assert_routing 'errata/bugzillasearch.cgi', { :controller => 'bugs',     :action => 'index'          }

    assert_routing 'errata/brewfiles.cgi',      { :controller => 'brew',     :action => 'list_files'     }
    assert_routing 'errata/rpmdiff.cgi',        { :controller => 'rpmdiff',  :action => 'list'           }
    assert_routing 'errata/rdiffcontrol.cgi',   { :controller => 'rpmdiff',  :action => 'control'        }
    assert_routing 'errata/fixcvenames.cgi',    { :controller => 'security', :action => 'fix_cve_names'  }
    assert_routing 'errata/approve.cgi',        { :controller => 'docs',     :action => 'reroute'        }
    assert_routing 'errata/new_qu',             { :controller => 'automatic_advisory',     :action => 'new_qu'     }
    assert_routing 'errata/new_qu_pdc',         { :controller => 'automatic_advisory',     :action => 'new_qu_pdc' }

    assert_routing 'errata/xmlrpc.cgi',         { :controller => 'noauth/xmlrpc',   :action => 'errata_service' }
    assert_routing 'errata/tps-xmlrpc.cgi',     { :controller => 'noauth/xmlrpc',      :action => 'tps_service'    }

    assert_routing 'errata/get_channel_packages/1', {:controller =>  'noauth/errata', :action => 'get_channel_packages', :id => '1'}
    assert_routing 'errata/get_released_channel_packages/1', {:controller =>  'noauth/errata', :action => 'get_released_channel_packages', :id => '1'}
    assert_routing 'errata/get_released_packages/1', {:controller =>  'noauth/errata', :action => 'get_released_packages', :id => '1'}
    assert_routing 'errata/get_tps_txt/1', {:controller =>  'noauth/errata', :action => 'get_tps_txt', :id => '1'}
    assert_routing 'push/get_ftp_paths/1', {:controller =>  'noauth/push', :action => 'get_ftp_paths', :id => '1'}
    assert_routing 'push/last_successful_stage_push/1', {:controller =>  'noauth/push', :action => 'last_successful_stage_push', :id => '1'}
    # Custom routes
    assert_routing 'rhn/push_to_live/1',        { :controller => 'push',    :action => 'live',  :id => '1' }
    assert_routing 'rhn/push_to_stage/2',       { :controller => 'push',    :action => 'stage', :id => '2' }

    # Both these paths should be recognized, but we prefer push/ in URLs
    assert_routing 'push/check_push_status/5',  { :controller => 'push', :action => 'check_push_status', :id => '5' }
    assert_recognizes({ :controller => 'push', :action => 'check_push_status', :id => '5' }, 'rhn/check_push_status/5')

    # This one uses a star so name can have slashes in it (or something like that, see config/routes.rb)
    assert_routing 'package/show/java-1.6.0-bea', { :controller => 'package', :action => 'show', :name => 'java-1.6.0-bea' }

    # Test a couple of default routes
    assert_routing 'docs/doc_text_info/123',    { :controller => 'docs',    :action => 'doc_text_info', :id => '123' }
    assert_routing 'advisory/6',                { :controller => 'errata',  :action => 'view', :id => '6' }

    # Test a format (not sure if this is a useful url, but just testing the route, so it doesn't really matter)
    # TODO, what does this look like in 2.3?
    #assert_routing 'errata/stateview/6.xml',    { :controller => 'errata',  :action => 'stateview', :id => '6', :format => 'xml' }
  end

  test "api routes" do
    %w[ add_bug remove_bug add_build reload_builds remove_build clone change_state change_docs_reviewer ].each do |action|
      assert_routing({ :path => "api/v1/erratum/123/#{action}", :method => :post }, { :controller => 'api/v1/erratum', :action => action, :id => '123', :format => 'json' })
    end

    assert_routing 'brew/reload_builds_for_errata/123', :controller => 'api/v1/erratum', :action => 'reload_builds', :id => '123', :redirect => 1
  end

  # there's two `resources :job_trackers' declarations; make sure they both work OK
  test "job_trackers api and controller don't interfere with each other" do
    assert_routing 'api/v1/job_trackers/123', :controller => 'api/v1/job_trackers', :action => 'show', :id => '123', :format => 'json'
    assert_routing 'job_trackers/123', :controller => 'job_trackers', :action => 'show', :id => '123'
  end

  test "routing jira api" do
    ['json', nil].each do |fmt|
      with_failure_message("with format #{fmt || 'nil'}") do
        (suffix,opts) = if fmt.nil?
          ['', {}]
        else
          [".#{fmt}", {:format => fmt}]
        end

        assert_routing "jira_issues/EPAS-11/advisories#{suffix}", opts.merge({:controller => 'jira_issues', :action => 'errata_for_issue', :key => 'EPAS-11'})

        assert_routing "jira_issues/EPAS-11#{suffix}", opts.merge({:controller => 'jira_issues', :action => 'show', :key => 'EPAS-11'})

        assert_routing "advisory/1234/jira_issues#{suffix}", opts.merge({:controller => 'jira_issues', :action => 'for_errata', :id => '1234'})
      end
    end
  end

  # Not sure the 'proper' way (probably somewhere in functional?) so will use capybara here.
  test "routing redirects" do
    auth_as admin_user
    visit '/errata/dashboard.cgi'; assert_match %r'/reports/dashboard$', current_url
    visit '/errata/docsqueue.cgi'; assert_match %r'/docs/list$',         current_url
    visit '/docsqueue.cgi';        assert_match %r'/docs/list$',         current_url
    visit '/errata/newerrata.cgi'; assert_match %r'/advisory/new',       current_url
  end

end
