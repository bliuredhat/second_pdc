require 'test_helper'
require 'jira/rpc'

class ErrataControllerTest < ActionController::TestCase

  setup do
    @text_only = Errata.new_files.where(:text_only => 1).first
  end

  test 'ensure correctness of fixture data' do
    assert @text_only.text_only_channel_list.channel_list.empty?
  end

  test 'individual advisory views' do
    #
    # Note: This test is slow, memory intensive, and not very cost-effective in
    # terms of how long it takes. (I like to keep it anyway, but perhaps we could
    # disable it via an environment var for speedy test mode).
    #
    auth_as devel_user
    VCR.use_cassette 'pdc_individual_advisories' do
     VCR.use_cassettes_for(:pdc_ceph21) do
      Errata.all.each do |errata|
        errata_id = errata.id

        [:view, :details, :show_xml, :show_text, :show_activity, :change_state].each do |action|
          get action, :id => errata_id
          assert_response :success, "/#{action}/#{errata_id}: #{@response.body}"
        end

        get :edit, :id => errata_id
        assert_response (errata.is_open_state? ? :success : :redirect), "/edit/#{errata_id}: #{@response.body}"
      end
     end
    end
  end

  test "lists all advisories" do
    auth_as devel_user

    get :index
    assert_response :success
  end

  test 'add comment' do
    auth_as devel_user
    errata = Errata.new_files.last

    request.env['HTTP_ACCEPT'] = 'application/js'
    post :add_comment, :id => errata.id, :comment => 'Foo bar baz', :format => 'js'
    assert_response :success

    c = errata.comments.last

    assert(response.body.index("$('#state-comment-container').before('<div class=\"state-comment-header\" id=\"comment_#{c.id}\">"),
           response.body)

    assert(response.body.index("$('#state_comment_field').val('');charCounter('state_comment_field', 4000, false);"),
           response.body)

    refute(response.body.index("$('#cc_list_text').html"),
           response.body)

    refute(response.body.index("$('#add_cc_container').remove();"),
           response.body)

  end

  test 'add comment with cc' do
    auth_as devel_user
    errata = Errata.find(16396)

    request.env['HTTP_ACCEPT'] = 'application/js'
    post :add_comment, :id => errata.id, :comment => 'Foo bar baz', :format => 'js', :add_cc => '1'

    assert_response :success
    c = errata.comments.last

    assert(response.body.index("$('#state-comment-container').before('<div class=\"state-comment-header\" id=\"comment_#{c.id}\">"),
           response.body)

    assert(response.body.index("<div class=\"comment-body\">Foo bar baz</div>"),
           response.body)

    assert(response.body.index("$('#state_comment_field').val('');charCounter('state_comment_field', 4000, false);"),
           response.body)

    assert(response.body.index("$('#cc_list_text').html('devel');$('#add_cc_container').remove();"),
           response.body)


    post :add_comment, :id => errata.id, :comment => 'Should not add a cc again', :format => 'js', :add_cc => '1'
    assert_response :success

    refute(response.body.index("$('#cc_list_text').html"),
           response.body)

    refute(response.body.index("$('#add_cc_container').remove();"),
           response.body)

  end

  test 'errata text' do
   VCR.use_cassettes_for(:pdc_ceph21) do
    auth_as devel_user
    with_baselines('errata_text_baseline', /errata-(\d+)\.txt$/) do |filename,id|
      get :show_text, :id => id
      assert_response :success, response.body
      response.body
    end
   end
  end

  test 'errata xml' do
   VCR.use_cassettes_for(:pdc_ceph21) do
    auth_as devel_user
    with_xml_baselines('errata_xml_baseline', /errata-(\d+)\.xml$/) do |filename,id|
      get :show_xml, :id => id
      assert_response :success, response.body
      response.body
    end
   end
  end

  test 'errata xml with jira as references' do
    auth_as devel_user
    Settings.jira_as_references = true
    with_xml_baselines('errata_xml_baseline', /errata-jiraref-(\d+)\.xml$/) do |filename,id|
      get :show_xml, :id => id
      assert_response :success, response.body
      response.body
    end
  end

  test 'errata other xml' do
    auth_as devel_user
    with_xml_baselines('errata_other_xml_baseline', /errata-(\d+)\.xml$/) do |filename,id|
      get :other_xml, :id => id, :format => 'xml'
      assert_response :success, response.body
      response.body
    end
  end

  test 'errata other xml with jira as references' do
    auth_as devel_user
    Settings.jira_as_references = true
    with_xml_baselines('errata_other_xml_baseline', /errata-jiraref-(\d+)\.xml$/) do |filename,id|
      get :other_xml, :id => id, :format => 'xml'
      assert_response :success, response.body
      response.body
    end
  end

  test 'preview bad idsfixed' do
    auth_as devel_user

    e = Errata.where(:id => FiledJiraIssue.select(:errata_id)).where(:id => FiledBug.select(:errata_id)).first
    params = AdvisoryForm.errata_to_params(e)

    invalid_idsfixed = (params[:advisory][:idsfixed] += ' an-invalid-thing')

    # simulate attempting to add an invalid idsfixed
    post :preview, params
    assert_response :success, response.body
    assert_match /\bNot a valid bug number or JIRA issue key: an-invalid-thing\b/, response.body, response.body
    assert_match /\b1 error prohibited\b/, response.body, response.body
  end

  # Referring to a bug by alias works
  test 'preview bz alias' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' CVE-2011-1586'

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors nil

    assert_match /\b697042 - CVE-2011-1586 kdenetwork: incomplete fix for CVE-2010-1000\b/, response.body, response.body
  end

  # Referring to a bug by alias works, even if the alias looks like a JIRA issue
  test 'preview bz alias unambiguous jira-like' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' TST-123'

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors nil

    assert_match /\b698075 - Unambiguous JIRA-like alias\b/, response.body, response.body
  end

  # Referring to a bug by alias fails, if the alias is also an existing JIRA issue key
  test 'preview bz alias ambiguous jira-like - fail' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' TST-456'

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors /\bPlease review the highlighted fields below/
    assert_match /\bAmbiguous identifier\(s\): TST-456\. Prefix with bz: or jira: to disambiguate\b/, response.body
  end

  # Prefixing alias with bz: avoids failure due to ambiguity
  test 'preview bz alias ambiguous jira-like with bz prefix' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' bz:TST-456'

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors nil

    assert_match /\b698076 - Ambiguous JIRA-like alias\b/, response.body, response.body
  end

  # Prefixing alias with jira: avoids failure due to ambiguity
  test 'preview jira key ambiguous with jira prefix' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' jira:TST-456'

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors nil

    assert_match /\bTST-456 - Ambiguous with bug 698076\b/, response.body, response.body
  end

  # Unknown ids are fetched as expected
  test 'preview bz jira fetch behavior' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' 888888 some-alias XXX-123 jira:XXX-234'

    # note XXX-123 goes to both BZ and JIRA, since it could be a bug alias or an issue key

    Bugzilla::TestRpc.any_instance.expects(:get_bugs).with do |bugs,opts|
      bugs.to_set == %w{888888 some-alias XXX-123}.to_set
    end.returns([
      fakebug('id' => 888888),
      fakebug('id' => 999999, 'alias' => 'some-alias')
    ])

    Jira::ErrataClient.any_instance.expects(:searched_issues).with do |args|
      args[:jql] == 'key in (XXX-123, XXX-234)'
    end.returns([
      fakejira('key' => 'XXX-123'),
      fakejira('key' => 'XXX-234')
    ])

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors nil

    assert_match /\b888888 - test bug\b/, response.body, response.body
    assert_match /\b999999 - test bug\b/, response.body, response.body
    assert_match /\bXXX-123 - test issue\b/, response.body, response.body
    assert_match /\bXXX-234 - test issue\b/, response.body, response.body
  end

  # If both JIRA and Bugzilla are requested to find a certain string, and both of them
  # supply a result, it's ambiguous => fail
  test 'preview bz jira ambiguous after fetch' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' XXX-123'

    Bugzilla::TestRpc.any_instance.expects(:get_bugs).with(['XXX-123'], :permissive => true).returns([
      fakebug('id' => 999998, 'alias' => 'XXX-123')
    ])

    Jira::ErrataClient.any_instance.expects(:searched_issues).with do |args|
      args[:jql] == 'key in (XXX-123)'
    end.returns([
      fakejira('key' => 'XXX-123'),
    ])

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors /\bPlease review the highlighted fields below/
    assert_match /\bAmbiguous identifier\(s\): XXX-123\. Prefix with bz: or jira: to disambiguate\b/, response.body
  end

  # If both JIRA and Bugzilla are requested to find a certain string, and neither
  # can find it, fail
  test 'preview bz jira ambiguous no results' do
    auth_as secalert_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory][:idsfixed] += ' XXX-123'

    Bugzilla::TestRpc.any_instance.expects(:get_bugs).with(['XXX-123'], :permissive => true).returns([])

    Jira::ErrataClient.any_instance.expects(:searched_issues).with do |args|
      args[:jql] == 'key in (XXX-123)'
    end.returns([])

    post :preview, params
    assert_response :success, response.body
    assert_preview_errors /\bPlease review the highlighted fields below/
    assert_match /\bNot a valid bug number or JIRA issue key: XXX-123\b/, response.body
  end

  def fakebug(attr)
    out = {'status' => 'OPEN', 'summary' => 'test bug'}.merge(attr)
    Bugzilla::Rpc::RPCBug.new(out)
  end

  def fakejira(attr)
    out = {
      'summary' => 'test issue',
      'status' => {'name' => 'Open'},
      'priority' => {'name' => 'Low'},
      'updated' => Time.now.to_s
    }.merge(attr)
    id = out['id']
    unless id
      @fakejiraid ||= 0
      id = (@fakejiraid += 1)
    end
    JIRA::Resource::Issue.build(nil, 'id' => id, 'fields' => out)
  end

  def assert_preview_errors(like=nil)
    errors = if response.body =~ %r{<div class="errorExplanation"[^>]*>(.*)</div>}
      $1
    end
    if like.kind_of?(Regexp)
      assert_match like, errors
    else
      assert_equal like, errors
    end
  end

  test 'search for id or advisory name' do
    auth_as devel_user

    shipped_live_errata = Errata.shipped_live.last
    assert_not_nil shipped_live_errata.old_advisory

    new_files_errata = Errata.new_files.last
    assert_nil new_files_errata.old_advisory

    [shipped_live_errata, new_files_errata].each do |errata|

      get :index, :search => errata.shortadvisory
      assert_redirected_to :controller=>:errata, :action=>:view, :id=>errata
      assert_nil flash[:alert]

      get :index, :search => errata.advisory_name
      assert_redirected_to :controller=>:errata, :action=>:view, :id=>errata
      assert_nil flash[:alert]

      get :index, :search => "  #{errata.advisory_name}  " # extra spaces..
      assert_redirected_to :controller=>:errata, :action=>:view, :id=>errata
      assert_nil flash[:alert]

      get :index, :search => errata.id.to_s
      assert_redirected_to :controller=>:errata, :action=>:view, :id=>errata

      case errata
      when shipped_live_errata
        assert_match /is an old id for this errata/, flash[:alert]
        flash[:alert] = nil # prevent it lingering
      when new_files_errata
        assert_nil flash[:alert]
      end
    end
  end

  test 'text search of synopsis' do
    auth_as devel_user

    get :index, :search => 'perl'
    assert_response :success
    assert_not_nil assigns(:errata_filter)
    assert_equal 'perl', assigns(:errata_filter).synopsis_text_search
    # ..that's enough I guess

    # test redirect of old deprecated search url
    get :find, :advisory=>{:name=>'perl'}
    assert_redirected_to :controller=>:errata, :action=>:index, :search=>'perl'
    assert_not_nil assigns(:errata_filter)
    assert_equal 'perl', assigns(:errata_filter).synopsis_text_search

  end

  test 'read only cannot see embargoed advisories' do
    @async = Async.create!(:name => 'ASYNC', :description => 'async')
    @rhsa  = RHSA.create!(:reporter => qa_user,
                          :synopsis => 'test advisory',
                          :product => Product.find_by_short_name('RHEL'),
                          :release => @async,
                          :assigned_to => qa_user,
                          :security_impact => 'Moderate',
                          :release_date => 10.days.from_now,
                          :content =>
                          Content.new(:topic => 'test',
                                      :description => 'test',
                                      :solution => 'fix it')
                          )

    auth_as devel_user
    get :view, :id => @rhsa.id
    assert_response :success


    auth_as read_only_user
    get :view, :id => @rhsa.id
    assert_response :not_found
  end

  test 'redirect old advisory urls' do
    # This was failing for read_only user. See Bz 993430
    auth_as read_only_user
    [RHSA.last, RHBA.last].each do |errata|
      [:show, :info, :stateview].each do |action|
        get action, :id=>errata.id
        assert_redirected_to :controller=>:errata, :action=>:view, :id=>errata.id
      end
    end
  end

  test 'redirect old advisory list urls' do
    auth_as read_only_user
    [:list, :list_errata].each do |action|
      get action
      assert_redirected_to :controller=>:errata, :action=>:index
#      assert_match /Please update your bookmarks/, flash.delete(:alert).to_s
      assert_match /Please update your bookmarks/, flash[:alert].to_s
    end
  end

  test 'render related advisories partial' do
    auth_as devel_user
    get :modal_related_advisories, :id=>Errata.last.id
    assert_response :success
    assert_match /Related Advisories/, @response.body
  end

  test 'related advisory menu item changes' do
    auth_as devel_user

    get :view, :id=>Errata.first.id
    assert_response :success
    assert_match /No Related Advisories/, @response.body

    get :view, :id=>16384
    assert_match />Related Advisories/, @response.body
    assert_no_match /No Related Advisories/, @response.body
  end

  #
  # Should not be able to save an errata with nil manager or package owner, but just
  # in case it should ever happen again let's not throw exceptions. (See Bz 1007249).
  #
  test 'can view advisory with nil manager and package owner' do
    errata = RHBA.last # any one should do
    errata.update_attribute('manager', nil)
    errata.update_attribute('package_owner', nil)
    auth_as devel_user
    get :view, :id => errata.id
    assert_response :success
    get :details, :id => errata.id
    assert_response :success
  end

  test "should route to advisories" do
    assert_routing '/errata',
      :controller => 'errata', :action => 'index'
  end

  def _prep_release_lists
    product = Product.find_by_short_name('RHEL')
    releases = Release.current.enabled.for_products_plus_async(product).order('name')
    @any_releases = releases.reject(&:is_pdc)
    all_types_non_acl_releases = Release.current.enabled.for_products(product).no_approved_components.order('name')
    @non_acl_releases = all_types_non_acl_releases.reject(&:is_pdc)
    assert @any_releases.count > @non_acl_releases.count
  end

  test "secalert can choose any release on manual create" do
    _prep_release_lists
    auth_as secalert_user
    get :new_errata
    assert_response :success
    assert_equal @any_releases.to_json, assigns["releases"].to_json
    @any_releases.each { |release| assert_select "option[value=#{release.id}]" }
  end

  test "devel can choose only non acl release on manual create" do
    _prep_release_lists
    auth_as devel_user
    get :new_errata
    assert_response :success
    assert_equal @non_acl_releases.to_json, assigns["releases"].to_json
    @non_acl_releases.each { |release| assert_select "option[value=#{release.id}]" }
  end

  test "createasync can choose ASYNC release on manual create" do
    auth_as async_user
    get :new_errata
    assert_response :success
    assert_select "option:content('ASYNC')"
  end

  test "set form for product" do
    auth_as devel_user

    get :set_form_for_product, :product => {:id => Product.find_by_short_name('RHEL').id}
    assert_response :success

    # a basic check that the response refers to releases and solution for this
    # product
    assert_match /RHEL-6\.6\.z/, response.body
    assert_match /This update is available via the Red Hat Network/, response.body
  end

  test "errata for release" do
    auth_as devel_user

    get :errata_for_release, :id => Release.find_by_name('RHEV-H 6.4.0').id, :format => :json
    assert_response :success

    response_data = ActiveSupport::JSON.decode(response.body)
    response_data.each do |content|
      %w[qe_owner id advisory_name release_date status product qe_group release status_time synopsis].each do |field|
        assert content.has_key?(field), "Expected '#{field}' to be present in JSON response"
      end
    end
  end

  test "non-secalert users can not create RHSA advisories with non-low impact or embargo date" do
    auth_as devel_user
    post :preview, {
      :product => {:id => Product.find_by_short_name('RHEL').id},
      :release => {:id => Release.current.enabled.first.id },
      :errata => {:clone => '' },
      :advisory => {
        :errata_type => RHSA.name,
        :security_impact => 'Moderate',
        # n.b. the embargo/release mismatch here is correct
        :enable_embargo_date => 'on',
        :release_date => '2020-11-10',
        :reference => '',
      }
    }
    assert_response :success
    refute assigns['advisory'].valid?

    errors = assigns['advisory'].errors

    # selecting RHSA should not have been a problem...
    refute errors.has_key? :errata_type

    # ... but these two fields were unacceptable
    assert_equal ['cannot be set to Moderate by non-secalert users.'], errors['Security impact']
    assert_equal ['cannot be set on RHSA by non-secalert users.'], errors['Embargo date']
  end

  test "non-secalert users can create RHSA advisories with low impact and no embargo date" do
    # The release is ASYNC so need user with createasync role
    auth_as async_user
    post :preview, {
      :product => {:id => Product.find_by_short_name('RHEL').id},
      :release => {:id => Release.current.enabled.first.id },
      :errata => {:clone => '' },
      :advisory => {
        :synopsis => 'my synopsis',
        :topic => 'my topic',
        :solution => 'my solution',
        :description => 'my description',
        :idsfixed => '697835',
        :errata_type => RHSA.name,
        :security_impact => 'Low',
        :reference => '',
      }
    }
    assert_response :success
    assert_valid assigns['advisory']
  end

  test "non-secalert users can create PDC RHSA advisories with low impact and no embargo date" do
    auth_as async_user
    post :preview, {
      :product => {:id => Product.find_by_name('Product for PDC').id},
      :release => {:id => Release.find_by_name('ReleaseForPDC') },
      :errata => {:clone => '' },
      :advisory => {
        :synopsis => 'my synopsis',
        :topic => 'my topic',
        :solution => 'my solution',
        :description => 'my description',
        :idsfixed => '697835',
        :errata_type => PdcRHSA.name,
        :security_impact => 'Low',
        :reference => '',
      }
    }
    assert_response :success
    assert_valid assigns['advisory']
  end

  test "non-secalert users cannot modify impact or embargo date on RHSA" do
    auth_as devel_user
    e = Errata.find(11149)
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory].merge!(
      :security_impact => 'Critical',
      :enable_embargo_date => 'on',
      :release_date => '2020-11-10'
    )

    post :save_errata, params
    # 500 error is OK - this is not an API, and in reality, it's caught at the preview step
    assert_response :error, response.body

    errors = assigns['advisory'].errors
    ['Embargo Date', 'Security impact'].each do |key|
      assert_equal ['cannot be modified on RHSA by non-secalert users.'], errors[key], "missing/wrong error for #{key}"
    end
  end

  test "non-secalert users cannot modify impact or embargo date on PDC RHSA" do
    auth_as devel_user
    e = Errata.find(11150)
    assert_equal 'PdcRHSA', e.errata_type, 'Unexpected errata type!'
    params = AdvisoryForm.errata_to_params(e)

    params[:advisory].merge!(
      :security_impact => 'Critical',
      :enable_embargo_date => 'on',
      :release_date => '2020-11-10'
    )

    post :save_errata, params
    # 500 error is OK - this is not an API, and in reality, it's caught at the preview step
    assert_response :error, response.body

    errors = assigns['advisory'].errors
    ['Embargo Date', 'Security impact'].each do |key|
      assert_equal ['cannot be modified on RHSA by non-secalert users.'], errors[key], "missing/wrong error for #{key}"
    end
  end

  test "advisory displays warning if no QE owner is assigned" do
    auth_as devel_user
    advisory = Errata.find(16375) # unassigned, NEW_FILES
    assert advisory.assigned_to_default_qa_user?, "test requires advisory assigned to default qa user"

    %w{view details}.each do |page|
      post page, :id => advisory.id

      assert_response :success
      assert_match %r{Advisory is currently unassigned}, flash[:alert], "No flash message on #{page} page"
      # TODO - test this with poltergeist or other test framework
      # testing JavaScript
      assert_match %r{class='open-modal'}, flash[:alert]
    end
  end

  test "pdc advisory displays warning if no QE owner is assigned" do
    auth_as devel_user
    advisory = Errata.find(16376) # unassigned, NEW_FILES
    assert_equal 'PdcRHEA', advisory.errata_type, 'Unexpected errata type!'
    assert_equal 'NEW_FILES', advisory.status, 'Unexpected errata status!'
    assert_equal 'normal', advisory.severity, 'Unexpected errata severity!'

    assert advisory.assigned_to_default_qa_user?, "test requires advisory assigned to default qa user"

    %w{view details}.each do |page|
      post page, :id => advisory.id

      assert_response :success
      assert_match %r{Advisory is currently unassigned}, flash[:alert], "No flash message on #{page} page"
      # TODO - test this with poltergeist or other test framework
      # testing JavaScript
      assert_match %r{class='open-modal'}, flash[:alert]
    end
  end

  test 'bug and issue counts are combined correctly on index' do
    auth_as devel_user

    erratas = [
      # no issues or bugs
      RHBA.find(5028).tap{|e| assert e.filed_jira_issues.empty? }.tap{|e| assert e.filed_bugs.empty?},

      # no issues, some bugs
      RHBA.find(2128).tap{|e| assert e.filed_jira_issues.empty? }.tap{|e| refute e.filed_bugs.empty?},

      # some issues, no bugs
      RHBA.find(11020).tap{|e| refute e.filed_jira_issues.empty? }.tap{|e| assert e.filed_bugs.empty?},

      # some issues, some bugs
      RHBA.find(7517).tap{|e| refute e.filed_jira_issues.empty? }.tap{|e| refute e.filed_bugs.empty?},
    ]

    SystemErrataFilter.any_instance.stubs(:results => Errata.where(:id => erratas).paginate(:page => 1))

    get :index
    assert_response :success

    # collapse some lines to make patterns easier to deal with, then find only the lines relating to
    # issue counts
    lines = response.body.gsub(%r{</span>\n\s*}, '</span>').split("\n").grep(%r{ (issue|bug)s?\)})
    linestr = lines.join("\n")

    assert_match %r{\(7 bugs\).*\bGFS bug fix update}, linestr
    assert_match %r{\(0 bugs\).*\bdlm-kernel bug fix update}, linestr
    assert_match %r{\(8 issues\).*\bTest errata for MRG RHEL-4}, linestr
    assert_match %r{\(1 issue\).*\bmingw32-qpid-cpp bug-fix update}, linestr
  end

  test "successfully updates text only channels" do
    auth_as devel_user
    expected = Channel.find(6)

    post :text_only_channels,
      :id => @text_only,
      :channels => [expected.id]
    assert_redirected_to :controller=>:errata, :action=>:view, :id => @text_only

    @text_only.reload
    assert_equal expected.name, @text_only.text_only_channel_list.channel_list
  end

  test "successfully updates text only cdn repositories" do
    auth_as devel_user
    expected = CdnRepo.last

    post :text_only_channels,
      :id => @text_only,
      :cdnrepos => [expected.id]
    assert_redirected_to :controller=>:errata, :action=>:view, :id => @text_only

    @text_only.reload
    assert_equal [expected], @text_only.text_only_channel_list.get_cdn_repos
  end

  [
    'View bug list in Bugzilla',
    'Remove Bugs',
    'Update Bug Statuses',
    'Reconcile with Bugzilla',
    'View Issue list in JIRA',
    'Remove JIRA Issues',
    'Reconcile with JIRA',
  ].each do |action|
    [[5028, false], [7517, true]].each do |id,expected|
      test "advisory #{id} does #{expected ? '' : 'not '} show #{action}" do
        auth_as devel_user

        get :view, :id => id
        assert_response :success, response.body

        assert_equal expected, response.body.include?(action), response.body
      end
    end
  end

  test 'CPE Text field displayed as expected' do
    auth_as devel_user

    errata = Errata.find(9829)
    get :cpe_list, :id => errata, :format => :js

    expected = [
      "cpe:/a:redhat:jboss_web_framework_kit:1::el4",
      "cpe:/a:redhat:jboss_web_framework_kit:1::el5",
      "Variants with this CPE",
      "4AS-JBWFK-5.0.0, 4ES-JBWFK-5.0.0",
      "5Server-JBWFK-1.0.0"]

    expected.each do |expected_cpe|
      assert_match(/#{expected_cpe}/, response.body)
    end
  end

  test 'CPE Text field for docker container advisory' do
    auth_as devel_user

    errata = Errata.find(24604)
    get :cpe_list, :id => errata, :format => :js

    expected = [
      "cpe:/a:redhat:rhel_extras_other:7",
      "Variants with this CPE",
      "7Server-EXTRAS"]

    expected.each do |expected_cpe|
      assert_match(/#{expected_cpe}/, response.body)
    end
  end

  test "RHSA advisory without CPE should display NONE with highlight" do
    auth_as devel_user

    # This normally won't happen because variant with blank cpe will
    # always be replaced with "cpe:/unknown". This advisory is showing
    # NONE because it has no errata brew mappings.
    errata = Errata.find(5243)
    get :cpe_list, :id => errata, :format => :js
    # Should have this css class
    assert_match(/label label-important italic/, response.body)
    # Should display NONE
    assert_match(/NONE/, response.body)
  end

  test "non-RHSA advisory without CPE should display NONE without highlight" do
    auth_as devel_user

    errata = errata = Errata.find(2128)
    get :cpe_list, :id => errata, :format => :js

    # Should not have this css class
    assert_no_match(/label label-important italic/, response.body)
    # Should display NONE
    assert_match(/NONE/, response.body)
  end

  test "unknown CPE for RHSA advisory should be highlighted" do
    auth_as devel_user

    Variant.any_instance.stubs(:cpe).returns("")

    errata = Errata.find(19463)
    get :cpe_list, :id => errata, :format => :js

    # Should have this css class
    assert_match(/label label-important italic/, response.body)
    assert_match(/cpe:\/unknown/, response.body)
    # This appear in popover box
    assert_match(/Variants without CPE/, response.body)
    assert_match(/6Client, 6ComputeNode, 6Server, 6Workstation/, response.body)
  end

  test "GET /filter/id.json" do
    auth_as devel_user

    # So we can test an unpaginated filter returning too much
    Settings.max_filter_items = 50

    with_baselines('errata_filter', %r{\/(\d+).json$}) do |file, id|
      get :filter_permalink, :format => :json, :id => id
      formatted_json_response
    end
  end

  test "edit batch" do
    auth_as releng_user
    errata_id = 19829

    post :edit_batch, :id => errata_id, :batch => { :id => 2 }
    assert_response :redirect
    assert_equal(2, Errata.find(errata_id).batch_id)
  end

  test "ajax quick action menu links method" do
    errata = Errata.find(19829)
    assert errata.allow_edit?, "unexpected fixture data"

    asserts_for_user = lambda do |user, edit_links_expected|
      auth_as user
      get :ajax_quick_action_menu_links, :id => errata.id
      assert_response :success

      # Summary link should be there
      assert_select 'li a', :count => 1, :text=>'Summary'

      # Readonly user should not get the Edit link, devel user should
      assert_select 'li a', :count => edit_links_expected, :text=>'Edit'
    end

    asserts_for_user[devel_user, 1]
    asserts_for_user[read_only_user, 0]
  end

  test "clone errata chooses correct releases" do
    auth_as devel_user

    errata = Errata.find(16657)
    expected = ["RHEV-M 3.y-Async"]
    assert_equal expected, errata.product.releases.enabled.current.pluck(:name), "Unexpected fixture data"

    get :clone_errata, :id => errata.advisory_name, :format => 'js'
    assert_response :success
    assert_equal expected, assigns["releases"].map(&:name)
    assert_equal errata.release, assigns["release"]
  end

end
