require 'test_helper'

class UpdateAdvisoryFormTest < ActiveSupport::TestCase
  setup do
    @advisory = Errata.find 11152
    @params = UpdateAdvisoryForm.errata_to_params @advisory

    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries = []
  end

  test "errata to params" do
    [[:errata_read_keys, @advisory], [:content_keys, @advisory.content]].each do |klass_method, obj|
      keys = UpdateAdvisoryForm.send(klass_method)
      keys.each do |k|
        v = @params[:advisory][k]
        assert_equal v, obj.send(k)
      end
    end

    assert_equal @advisory.manager.login_name,       @params[:advisory][:manager_email]
    assert_equal @advisory.package_owner.login_name, @params[:advisory][:package_owner_email]
  end

  #
  # If the advisory has set release dates, we need to keep them set.
  # Since the AdvisoryForm resets dates if they are not explicitly
  # switched on before the advisory is persisted, we need to make sure
  # it is reflected correctly in the parameters.
  #
  test "errata to params keeps dates" do
    advisory = RHSA.last
    advisory.update_attribute('release_date', 1.day.from_now)
    advisory.update_attribute('publish_date_override', 1.day.from_now)

    params = UpdateAdvisoryForm.errata_to_params advisory
    assert_equal 'on', params[:advisory][:enable_embargo_date]
    assert_equal 'on', params[:advisory][:enable_release_date]
  end

  #
  # On form initialization, the parameters contain only a small part of
  # keys. The form object needs to handle this case.
  #
  test "create form object on init" do
    uf = UpdateAdvisoryForm.new(User.current_user, {:id => @advisory.id})
    assert_equal uf.manager_email,       @advisory.manager.login_name
    assert_equal uf.package_owner_email, @advisory.package_owner.login_name
  end

  test "keys in parameters can be strings" do
    params = {:id => @advisory.id, :advisory => {'package_owner_email' => User.last.login_name}}
    uf = UpdateAdvisoryForm.new(User.current_user, params)
    assert_equal User.last.login_name, uf.package_owner_email
    assert_equal @advisory.manager.login_name, uf.manager_email
  end

  test "advisory valid" do
    uf = UpdateAdvisoryForm.new(User.current_user, @params)
    assert_valid uf

    params = {
      :id => @advisory.id,
      :advisory => {:package_manager_email => User.first.login_name}
    }
    uf = UpdateAdvisoryForm.new(User.current_user, params)
    assert_valid uf
  end

  test "bugs have correct flags" do
    release = mock('Release')
    release.expects(:has_correct_flags?).with(instance_of(Bug)).at_least_once.returns(true)

    uf = UpdateAdvisoryForm.new(User.current_user, @params)
    uf.stubs(:release).returns(release)
    uf.errata.stubs(:group_id_changed?).once.returns(true)
    uf.send(:bugs_have_correct_flags)
    assert uf.errors.empty?
  end

  test "bugs have invalid flags" do
    @params[:release][:id] = Release.find_by_name('FAST5.7').id
    uf = UpdateAdvisoryForm.new(User.current_user, @params)
    uf.errata.stubs(:group_id_changed?).once.returns(true)
    uf.send(:bugs_have_correct_flags)
    assert uf.errors.any?
    assert_match /Bugs do not have flags/, uf.errors.full_messages.first
  end

  test "date fields valid" do
    uf = UpdateAdvisoryForm.new(User.current_user, @params)
    assert_nil   uf.enable_embargo_date
    assert_nil   uf.enable_release_date
    assert_valid uf

    [[:release_date, :enable_embargo_date],
     [:publish_date_override, :enable_release_date]].each do |attr, switch|
      params = UpdateAdvisoryForm.errata_to_params @advisory
      params[:advisory][attr] = '123123'
      params[:advisory][switch] = 'on'
      uf = UpdateAdvisoryForm.new(User.current_user, params)
      assert uf.send(switch)
      refute uf.valid?
      assert_match /not a valid date.*/, uf.errors.full_messages.first
    end
  end

  test "manager and package owner valid" do
    assert @advisory.package_owner
    assert @advisory.manager

    @params[:advisory][:package_owner_email] = ''
    uf = UpdateAdvisoryForm.new(User.current_user, @params)
    refute uf.valid?
    assert @advisory.package_owner
    assert_match /email cannot be blank/, uf.errors.full_messages.last
  end

  test "update docs reviewer" do
    uf = UpdateAdvisoryForm.new(User.current_user, @params)
    assert_not_equal User.first, uf.errata.content.doc_reviewer

    assert_difference("@advisory.comments.count") do
      uf.change_docs_reviewer User.first.id
    end
    Comment.notify_observers :after_commit, Comment.last
    assert_equal User.first, uf.errata.content.doc_reviewer
    mail = ActionMailer::Base.deliveries.pop
    assert_match /Changed docs reviewer/, mail.to_s

    refute uf.change_docs_reviewer 666
    refute uf.change_docs_reviewer User.first.id
  end

end
