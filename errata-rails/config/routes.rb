ErrataSystem::Application.routes.draw do

  def resources_for_cdn_repos
    resources :cdn_repos do
      member do
        get :edit_packages
        post :link
        post :unlink
        post :update_packages
      end

      collection do
        get :search_by_keyword
        get :attach_form
        post :attach
        post :detach
      end
    end
  end

  resources :products do
    collection do
      get 'disabled'

      get 'rpm_prefixes', :constraints => {:format => 'html'}

      # rpm prefixes in machine-readable form shouldn't require auth.
      # Used by TPS
      %w[json txt].each do |format|
        get 'rpm_prefixes', :to => 'noauth/products#rpm_prefixes',
          :constraints => {:format => format}
      end
    end

    resources :product_versions
  end

  resources :product_versions do
    post :set_channels, :on => :collection

    member do
      post :add_tag
      post :remove_tag
    end

    resources :channels do
      collection do
        get :search_by_keyword
        get :attach_form
        post :attach
        post :detach
      end

      member do
        post :unlink
        post :link
      end
    end

    resources_for_cdn_repos

    resources :variants, :except => [:destroy] do
      member do
        post :disable
        post :enable
      end
      resources :package_restrictions
      resources_for_cdn_repos
    end
  end

  resources :channels, :cdn_repos, :user, :only => :search_by_name_like do
    collection do
      get :search_by_name_like
    end
  end

  resources :variants do
    resources :package_restrictions
    resources_for_cdn_repos
  end

  resources :default_solutions
  resources :job_trackers

  resources :batches do
    collection do
      get :released_batches
    end
  end

  # don't allow slash to prevent wrong url interpretion. e.g. /abc/blah+blah@redhat.com/edit
  resources :user, :constraints => { :id => /[^\/]+/ } do
    member do
      post :edit
    end

    collection do
      get :preferences
      get :list_users
      get :users_by_role
      get :my_requests
      get :my_errata
      get :update_products
      get :assigned_errata
      get :show_roles
      post :update_preferences
      post :add_user
    end
  end

  namespace :api, :defaults => { :format => 'json' } do
    # FIXMEs for v2:
    # - ensure CSRF protection - bug 1099315
    # - be consistent with singular vs plural in the URLs
    namespace :v1 do
      resources :user_organizations do
        collection do
          get :search
        end
      end

      resources :security do
        collection do
          get :cpes
        end
      end

      resources :user

      resources :erratum do
        member do
          post :add_bug
          post :remove_bug
          post :add_jira_issue
          post :remove_jira_issue
          post :add_build
          post :add_builds
          post :add_comment
          post :remove_build
          post :reload_builds
          post :clone
          post :change_state
          post :change_docs_reviewer
          post :change_batch
          get :buildflags
          get :get_variant_rpms
          put :buildflags, :to => :update_buildflags
        end
        resources :push, :controller => 'erratum_push'

        get :filemeta, :to => 'erratum_file_meta#index'
        put :filemeta, :to => 'erratum_file_meta#update_multi'

        [:channels,:repos].each do |type|
          get "text_only_#{type}", :to => "erratum_text_only##{type}_index"
          put "text_only_#{type}", :to => "erratum_text_only##{type}_update"
        end

        get :metadata_cdn_repos, :to => 'erratum_metadata_repos#repos_index'
        put :metadata_cdn_repos, :to => 'erratum_metadata_repos#repos_update'
      end
      resources :job_trackers
      resources :package_restrictions do
        collection do
          post :set
          post :delete
        end
      end

      resources :bug do
        collection do
          post :refresh
        end
      end

      # need custom constraint on id to accept . in nvr
      resources :build, :only => [:show], :constraints => {:id =>  %r{[a-zA-Z0-9_.-]+}}

      # api/v1/releases
      resources :releases, :only => [:index, :show]
      # api/v1/arches
      resources :arches,   :only => [:index, :show]
      # api/v1/packages
      resources :packages, :only => [:index, :show]

      resources :external_tests, :only => [:index, :show]

      # api/v1/batches
      resources :batches, :only => [:index, :show, :create, :update]

      # api/v1/cdn_repos
      resources :cdn_repos, :only => [:index, :show, :create, :update]

      # api/v1/channels
      resources :channels, :only => [:index, :show, :create, :update]

      resources :push, :only => [:index, :show, :create]

      # api/v1/cdn_repo_package/tags
      resources :cdn_repo_package_tags, :only => [:index, :show, :create, :destroy, :update]

      # api/v1/rpmdif_runs
      resources :rpmdiff_runs,   :only => [:show]

      # api/v1/rpmdif_results
      resources :rpmdiff_results,   :only => [:show]

      # api/v1/comments
      resources :comments, :only => [:index, :show]

      # api/v1/state_indices
      resources :state_indices,   :only => [:show]
    end
  end
  resource :rhba, :rhea, :rhsa
  # I removed this. Pretty sure the controller would throw
  # errors anyway since params[:variant_id] would not be set.
  #resources :cdn_repos

  resources :multi_product_mappings do
    member do
      post :add_subscription
      delete :remove_subscription
    end
  end

  resources :multi_product_channel_maps,
            :controller => 'multi_product_mappings',
            :path => '/multi_product_mappings'

  resources :multi_product_cdn_repo_maps,
            :controller => 'multi_product_mappings',
            :path => '/multi_product_mappings'

  # Redirect some old urls
  match 'errata/showrequest.cgi'    => 'errata#show' # redirected advisory/:id in controller
  match 'errata/erratainfo.cgi'     => 'errata#info' # redirected advisory/:id in controller
  match 'errata/listrequest.cgi'    => redirect('/errata') # was 'errata#list'
  match 'errata/listerrata.cgi'     => redirect('/errata') # was 'errata#list_errata'
  match 'errata/newerrata.cgi'      => redirect('/advisory/new')

  match 'errata/showactivity.cgi'   => 'errata#show_activity'

  match 'errata/erratabugnav.cgi'   => 'bugs#erratabugs'
  match 'errata/qublockers.cgi'     => 'bugs#qublockers'
  match 'errata/bugzillasearch.cgi' => 'bugs#index'

  match 'errata/brewfiles.cgi'      => 'brew#list_files'
  match 'errata/rpmdiff.cgi'        => 'rpmdiff#list'
  match 'errata/rdiffcontrol.cgi'   => 'rpmdiff#control'
  match 'errata/fixcvenames.cgi'    => 'security#fix_cve_names'
  match 'errata/fix_cpe'            => 'security#fix_cpe'
  match 'errata/approve.cgi'        => 'docs#reroute'
  match 'errata/new_qu'             => 'automatic_advisory#new_qu'
  match 'errata/new_qu_pdc'         => 'automatic_advisory#new_qu_pdc'

  match 'errata/xmlrpc.cgi'         => 'noauth/xmlrpc#errata_service'
  match 'errata/tps-xmlrpc.cgi'     => 'noauth/xmlrpc#tps_service'

  match 'tps/tps_service'         => 'noauth/xmlrpc#tps_service'
  match 'errata/errata_service'     => 'noauth/xmlrpc#errata_service'
  match 'errata/secure_service'     => 'secure_xmlrpc#secure_service'
  match 'errata/get_channel_packages/:id' => 'noauth/errata#get_channel_packages'
  match 'errata/get_released_channel_packages/:id' => 'noauth/errata#get_released_channel_packages'
  match 'errata/get_pulp_packages/:id' => 'noauth/errata#get_pulp_packages'
  match 'errata/get_released_pulp_packages/:id' => 'noauth/errata#get_released_pulp_packages'
  match 'errata/get_released_packages/:id' => 'noauth/errata#get_released_packages'
  match 'errata/get_tps_txt/:id' => 'noauth/errata#get_tps_txt'
  match 'errata/blocking_errata_for/:id' => 'noauth/errata#blocking_errata_for'
  match 'errata/depending_errata_for/:id' => 'noauth/errata#depending_errata_for'
  match 'push/get_ftp_paths/:id' => 'noauth/push#get_ftp_paths'
  match 'push/last_successful_stage_push/:id' => 'noauth/push#last_successful_stage_push'
  match 'cve/list' => 'noauth/cve#list'
  match 'cve/show/:id' => 'noauth/cve#show'

  match 'system_version' => 'noauth/errata#system_version'

  # Let's try converting some of these to redirects...
  match 'errata/dashboard.cgi'      => redirect('/reports/dashboard')
  match 'errata/docsqueue.cgi'      => redirect('/docs/list')
  match 'docsqueue.cgi'             => redirect('/docs/list')

  # Prefer push/ instead of rhn/ in URLs (bug 1204067)
  match 'push/:action/:id'          => 'push'

  # Other custom routes
  match 'rhn/push_to_live/:id'      => 'push#live'
  match 'rhn/push_to_stage/:id'     => 'push#stage'
  match 'rhn/:action/:id'           => 'push'
  match 'package/show/*name'        => 'package#show', :format => false
  match 'packages'                  => 'package#list'

  # Don't want to do full resource routing for errata (at least not yet)
  # Do this for nice urls. Use the new 'advisory' terminology.
  match 'advisory/new'              => 'errata#new_choose'
  match 'advisory/:id(.:format)'    => 'errata#view'
  match 'advisory/:id/bugs'         => 'bugs#for_errata'
  match 'advisory/:id/jira_issues'  => 'jira_issues#for_errata'
  match 'advisory/:id/builds'       => 'brew#list_files'
  match 'advisory/:id/rpmdiff_runs' => 'rpmdiff#list'
  match 'advisory/:id/tps_jobs'     => 'tps#jobs_for_errata'
  match 'advisory/:id/cpe_list'     => 'errata#cpe_list'

  match 'brew/reload_builds_for_errata/:id' => 'api/v1/erratum#reload_builds', :redirect => 1, :as => :erratum_reload_builds

  # Here's some fancy routing to get some pretty urls. (Maybe should use a nested controller?)
  match 'advisory/:id/test_run/:test_type'   => 'external_tests#list', :constraints => { :test_type => /[a-z_]+/ }
  # (If we get an id, no need to specify the type since we will find that out when we load the run).
  match 'advisory/:id/test_run/:test_run_id' => 'external_tests#show', :constraints => { :test_run_id => /[0-9]+/ }

  match 'filter/:id'                => 'errata#filter_permalink'

  match 'bugs/:id.:format' => 'bugs#show'
  match 'bugs/:id/advisories' => 'bugs#errata_for_bug'
  match 'jira_issues/:key' => 'jira_issues#show'
  match 'jira_issues/:key/advisories' => 'jira_issues#errata_for_issue'
  match 'release/:id.:format' => 'release#show'
  match 'release/:id/advisories' => 'errata#errata_for_release'
  match 'workflow_rules/:id(.:format)' => 'workflow_rules#show'

  # map old url to new url
  match 'bugs/sync_bug_list', :to => 'issues#sync_issue_list', :via => [:get, :post]

  resources :rhel_releases

  # Standard default route
  match ':controller(/:action(/:id(.:format)))'

end
