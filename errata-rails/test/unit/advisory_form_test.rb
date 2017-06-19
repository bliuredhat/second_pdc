require 'test_helper'

class AdvisoryFormTest < ActiveSupport::TestCase

  test "keeps release date" do
    advisory = RHSA.first
    params = AdvisoryForm.errata_to_params RHSA.first
    params[:advisory].merge!({:enable_embargo_date => 'on'})

    form = CreateAdvisoryForm.new(secalert_user, params)
    #
    # patch the bugs validation, since in this case we only want to
    # check the date validation against the extracted parameters
    #
    form.expects(:issues_valid).returns(true)
    assert_valid form
    assert_equal CreateAdvisoryForm.format_date(advisory.release_date),
                 form.release_date
  end

  test "traverse parameters" do
    params = {:advisory => {:errata_type => "RHBA"}}
    form = CreateAdvisoryForm.new(User.current_user, params)
    assert_nil form.params[:product]
    assert_equal 'RHBA', form.params[:advisory][:errata_type]
    refute form.valid?
  end

  test "cloning RHSA advisory without secalert role will change type to RHBA" do
    params = {:errata => {:clone => RHSA.first.id}}
    clone_params = AdvisoryForm.clone_errata_by_params(User.current_user, params)
    assert_equal RHBA.name, clone_params[:advisory][:errata_type]
  end

  test "cloning RHSA advisory without secalert role will carry CVE names" do
    params = {:errata => {:clone => 5243}}
    clone_params = AdvisoryForm.clone_errata_by_params(User.current_user, params)
    assert_equal 'CVE-2007-1354', clone_params[:advisory][:cve]

    params = {:errata => {:clone => 8751}}
    clone_params = AdvisoryForm.clone_errata_by_params(User.current_user, params)
    assert_equal 'CVE-2009-1195 CVE-2009-1890 CVE-2009-1891',
      clone_params[:advisory][:cve]
  end

  test "cloning RHSA advisory with secalert role will keep type as RHSA" do
    params = {:errata => {:clone => RHSA.first.id}}
    clone_params = AdvisoryForm.clone_errata_by_params(secalert_user, params)
    assert_equal RHSA.name, clone_params[:advisory][:errata_type]
  end

  test "non security user can not create RHSA" do
    params = {:advisory => {:errata_type => "RHSA"}}
    form = CreateAdvisoryForm.new(User.current_user, params)
    refute form.valid?

    form = CreateAdvisoryForm.new(secalert_user, {:advisory => {:errata_type => "RHSA"}})
    assert_equal 'RHSA', form.params[:advisory][:errata_type]
    refute form.valid?
    refute form.errors.has_key? :errata_type
  end

  test "save! raises an error when invalid" do
    params = {
      :product => {:id => Product.find_by_short_name('RHEL').id},
      :release => {:id => Release.current.enabled.first.id },
      :advisory => {
        :synopsis => 'my synopsis',
        :topic => 'my topic',
        :solution => 'my solution',
        :description => 'my description',
        :errata_type => 'RHBA',

        # idsfixed empty is validated by AdvisoryForm, not the underlying
        # model.  This test needs to have a validation at the AdvisoryForm
        # layer failing, but validations everywhere else passing.
        :idsfixed => ''
      }}

    form = CreateAdvisoryForm.new(User.current_user, params)

    exception = nil
    begin
      form.save!
    rescue ActiveRecord::RecordInvalid => e
      exception = e
    end

    errors = form.errors
    assert errors.any?, "Setting empty idsfixed was expected to produce an error"
    assert_not_nil exception,
      "No exception was raised despite validation errors: #{errors.full_messages.join("\n")}"
  end

  # This behavior is required for error rendering on forms to work correctly;
  # see bug 1287399
  test 'synopsis error can be accessed by synopsis_sans_impact' do
    params = {:advisory => {:synopsis => ''}}

    form = CreateAdvisoryForm.new(User.current_user, params)

    refute form.save

    errors = form.errors
    assert errors.any?

    synopsis_error = errors[:synopsis]

    assert_equal ["can't be blank"], synopsis_error
    assert_equal synopsis_error,     errors[:synopsis_sans_impact]
  end

  test 'cloning advisory does not copy uncloneable fields' do
    params = {:errata => {:clone => 18894}}
    clone_params = AdvisoryForm.clone_errata_by_params(User.current_user, params)
    AdvisoryForm.errata_uncloneable_keys.each do |the_key|
      refute clone_params.key?(the_key), "#{the_key} should not be cloned"
    end
  end

  test "CVE list validation" do
    cve_id = 'CVE-2014-3615'

    not_in_description = "#{cve_id} appears in the CVE name list but not in the description"
    not_in_bug_summary = "The following CVE names appear in the CVE names list but not in the summary of any linked bugzilla bug: #{cve_id}"
    not_in_bug_aliases = "The following CVE names appear in the CVE names list but not in the aliases of any linked bugzilla bug: #{cve_id}"
    in_desc_not_in_cve = "#{cve_id} appears in the description but not in the 'CVE names' list"
    bugdesc_not_in_cve = "Your bug list references the following CVE names that are not included in the CVE list: #{cve_id}"
    alias_not_in_cve   = "Your bug list includes the following CVE aliases that are not included in the CVE list: #{cve_id}"

    description = "this bug fixed #{cve_id}"

    # Entry in CVE list but not in bug list or description
    form = rhsa_advisory_form(:cve => cve_id)
    assert_array_equal([not_in_description, not_in_bug_summary, not_in_bug_aliases], form.cve_problems.values.flatten)

    # Entry in CVE list but not in bug list
    form = rhsa_advisory_form(:cve => cve_id, :description => description)
    assert_array_equal([not_in_bug_summary, not_in_bug_aliases], form.cve_problems.values.flatten)

    # Bug 1139117 is a security tracking bug
    form = rhsa_advisory_form(:cve => cve_id, :description => description, :idsfixed => '1139117')
    assert_array_equal([not_in_bug_summary, not_in_bug_aliases], form.cve_problems.values.flatten)

    # Bug 1139115 is the CVE-aliased bug
    form = rhsa_advisory_form(:cve => cve_id, :description => description, :idsfixed => '1139115')
    assert form.cve_problems.empty?

    # Empty CVE list
    form = rhsa_advisory_form(:description => description, :idsfixed => '1139115')
    assert_array_equal([in_desc_not_in_cve, bugdesc_not_in_cve, alias_not_in_cve], form.cve_problems.values.flatten)
  end

  def rhsa_advisory_form(extra_params = {})
    params = {
      :product => {:id => Product.find_by_short_name('RHEL').id},
      :release => {:id => Release.current.enabled.first.id },
      :advisory => {
        :errata_type => 'RHSA',
        :synopsis => 'my synopsis',
        :topic => 'my topic',
        :solution => 'my solution',
        :description => 'my description',
        :idsfixed => ''
      }.merge(extra_params)
    }

    CreateAdvisoryForm.new(User.current_user, params)
  end

end
