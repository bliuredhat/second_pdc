require 'test_helper'

class RHSATest  < ActiveSupport::TestCase
  def setup
    content = Content.new(
      :topic       => 'test',
      :description => 'test',
      :solution    => 'fix it'
    )

    @rhsa = RHSA.create(
      :reporter    => qa_user,
      :synopsis    => 'test advisory',
      :product     => Product.find_by_short_name('RHEL'),
      :release     => async_release,
      :assigned_to => qa_user,
      :content     => content
    )
  end

  test "rhsa basics" do

    # Test security impact validation
    assert !@rhsa.valid?
    @rhsa.security_impact = 'Foobar'
    assert !@rhsa.valid?
    @rhsa.security_impact = 'Moderate'
    assert @rhsa.valid?

    # Test release date
    initial_release_date = Time.now.utc
    @rhsa.release_date = initial_release_date
    @rhsa.save!
    reload_rhsa = RHSA.find @rhsa.id
    assert_equal initial_release_date.to_date, reload_rhsa.release_date.to_date
  end


  #
  # If user enters a blank text_only_cpe then it should
  # get converted to a nil by a before_save.
  #
  test "text_only_cpe becomes nil if empty" do
    rhsa = RHSA.where(:text_only=>true).last
    assert_nil rhsa.content.text_only_cpe

    rhsa.content.update_attributes(:text_only_cpe => 'foo')
    assert_equal 'foo', rhsa.content.text_only_cpe
    assert_equal 'foo', Content.find(rhsa.content.id).text_only_cpe

    rhsa.content.update_attributes(:text_only_cpe => '')
    assert_nil rhsa.content.text_only_cpe
    assert_nil Content.find(rhsa.content.id).text_only_cpe

    rhsa.content.update_attributes(:text_only_cpe => '   ')
    assert_nil rhsa.content.text_only_cpe
    assert_nil Content.find(rhsa.content.id).text_only_cpe
  end

  #
  # If type is changed to non RHSA then text_only_cpe should be
  # cleared.
  #
  test "text_only_cpe and cve is cleared if type changes" do
    rhsa = RHSA.where(:text_only=>true).last
    assert_nil rhsa.content.text_only_cpe
    assert rhsa.content.cve.present?

    rhsa.content.update_attributes(:text_only_cpe => 'foo')
    c = Content.find(rhsa.content.id)
    assert_equal 'foo', c.text_only_cpe

    rhsa.update_attribute(:errata_type,'RHBA')
    # Have to save the content record, won't update if you just save the rhsa.
    # errata_controller does that so it should be okay (I think?)
    c = Content.find(rhsa.content.id)
    c.save!

    # Make sure fields are cleared
    assert_nil c.text_only_cpe
    assert_blank c.cve
  end

  #
  # If type is changed to non-text only then text_only_cpe should be
  # cleared.
  #
  test "text_only_cpe is cleared if non-text only" do
    rhsa = RHSA.where(:text_only=>true).last
    assert_nil rhsa.content.text_only_cpe

    rhsa.content.update_attributes(:text_only_cpe => 'foo')
    c = Content.find(rhsa.content.id)
    assert_equal 'foo', c.text_only_cpe

    rhsa.update_attribute(:text_only,false)
    # Have to save the content record, won't update if you just save the rhsa.
    # errata_controller does that so it should be okay (I think?)
    c = Content.find(rhsa.content.id)
    c.save!

    # Make sure text_only_cpe is cleared
    assert_nil c.text_only_cpe
  end

  #
  # RHSA advisories get some auto reference links added.
  # Test that they work.
  #
  test "automatic reference links" do
    @rhsa.security_impact = 'Moderate'
    assert_nil @rhsa.content.reference

    # trigger before_save callbacks..
    @rhsa.save!

    # See if they added some auto reference links
    assert_match %r{https://access.redhat.com/security/updates/classification/#moderate}, @rhsa.content.reference

    # See if they get removed if type changes to a non RHSA
    @rhsa.update_attribute(:errata_type,'RHBA')
    c = Content.find(@rhsa.content.id)
    c.save!
    assert_equal "", c.reference
  end

  # Related to bug 738531 (but added while working on bug 740819)
  test "automatic reference links with additonal manual link" do
    @rhsa.security_impact = 'Moderate'
    @rhsa.content.reference = 'http://foo.com/'

    # trigger before_save callbacks..
    @rhsa.save!

    # See if they added some auto reference links
    assert_equal "https://access.redhat.com/security/updates/classification/#moderate\nhttp://foo.com/", @rhsa.content.reference

    # See if they get removed if type changes to a non RHSA
    @rhsa.update_attribute(:errata_type,'RHBA')
    c = Content.find(@rhsa.content.id)
    c.save!

    assert_equal "http://foo.com/", c.reference
  end

  test "unembargoed scope" do
    @rhsa.security_impact = 'Moderate'
    @rhsa.save!

    Errata.with_unembargoed_scope { Errata.find(@rhsa.id) }
    total_count = RHSA.count
    # Embargo advisory, should not be findable within unembargoed scope
    @rhsa.update_attribute(:release_date, 10.days.from_now)
    assert_raise(ActiveRecord::RecordNotFound) { Errata.with_unembargoed_scope { Errata.find(@rhsa.id) } }
  end

  test "impact in synopsis" do
    content = Content.new(
      :topic       => 'test',
      :description => 'test',
      :solution    => 'fix it'
    )
    rhsa = RHSA.create(
      :reporter    => qa_user,
      :synopsis    => 'test advisory',
      :product     => Product.find_by_short_name('RHEL'),
      :release     => async_release,
      :assigned_to => qa_user,
      :security_impact => 'Low',
      :content     => content
    )
    rhsa.save!

    assert_equal 'Low: test advisory', rhsa.synopsis
    assert_equal 'test advisory', rhsa.synopsis_sans_impact
  end
end
