require 'test_helper'

class VariantFormTest < ActionDispatch::IntegrationTest
  setup do
    auth_as admin_user
    @v_6server = Variant.find_by_name('6Server')
    @pv_rhel6 = @v_6server.product_version
    @v_7server = Variant.find_by_name('7Server')
    @pv_rhel7 = @v_7server.product_version
    @table_title = "Depending active errata with locked filelist"
    @noresult_title = "No #{@table_title.downcase}."
    @table_note = "NOTE: User is not allowed to amend the push target if the variant has active"\
      " errata with locked filelist."
  end

  test "edit variant push target with depending active errata" do
    errata = @v_6server.active_errata
    assert_equal 10, errata.count, "Fixture problem: The active errata count is no longer match."
    visit "/product_versions/#{@pv_rhel6.id}/variants/#{@v_6server.id}/edit"

    assert_active_errata_table(errata, @table_title, @table_note)

    uncheck 'Push To Rhn Live'
    click_on 'Update'

    expected_message =
      "Update push targets for variant that has active advisories with locked filelist"\
      " is not allowed. To amend the push targets, please make sure all depending active advisories"\
      " are either inactive or in unlocked state."
    assert page.has_content?(expected_message), page.html
  end

  test "edit variant push target without depending active errata" do
    errata = @v_7server.active_errata
    assert_equal [], errata, "Fixture problem: The active errata list is no longer empty."
    assert(
      @v_7server.supported_push_types.include?(:rhn_live),
      "Fixture problem: #{@v_7server.name} needs to support rhn_live in order to proceed this test."
    )

    visit "/product_versions/#{@pv_rhel7.id}/variants/#{@v_7server.id}/edit"

    assert_active_errata_table(errata, @noresult_title)

    uncheck 'Push To Rhn Live'
    click_on 'Update'

    expected_message = "Variant '#{@v_7server.name}' was successfully updated"
    assert page.find('#flash_notice').has_content?(expected_message), page.html
  end

  test "edit variant push target with more than 20 active errata" do
    # fake 30 depend active errata
    errata = Errata.limit(30).to_a
    Variant.any_instance.stubs(:active_errata).returns(errata)

    visit "/product_versions/#{@pv_rhel6.id}/variants/#{@v_6server.id}/edit"
    assert_active_errata_table(errata, @table_title, @table_note)
  end

  test "variant shows correct attached repositories" do
    visit "/product_versions/#{@pv_rhel6.id}/variants/#{@v_6server.id}"

    channels = [
      %w[rhel-i386-server-fastrack-6 FastTrack i386 -- Action Delete],
      %w[rhel-x86_64-server-fastrack-6 FastTrack x86_64 -- Action Delete],
      %w[rhel-s390x-server-fastrack-6 FastTrack s390x -- Action Delete],
      %w[rhel-ppc64-server-fastrack-6 FastTrack ppc64 -- Action Delete],
      %w[rhel-i386-server-6 Primary i386 -- Action Delete],
      %w[rhel-x86_64-server-6 Primary x86_64 -- Action Delete],
      %w[rhel-s390x-server-6 Primary s390x -- Action Delete],
      %w[rhel-ppc64-server-6 Primary ppc64 -- Action Delete]
    ]

    cdn_repos = [
      %w[rhel-6-server-debuginfo-rpms__6Server__i386 Primary i386 Debuginfo -- Action Delete],
      %w[rhel-6-server-rpms__6Server__i386 Primary i386 Binary -- Action Delete],
      %w[rhel-6-server-debuginfo-rpms__6Server__x86_64 Primary x86_64 Debuginfo -- Action Delete],
      %w[rhel-6-server-rpms__6Server__x86_64 Primary x86_64 Binary -- Action Delete],
      %w[rhel-6-server-source-rpms__6Server__x86_64 Primary x86_64 Source -- Action Delete],
      %w[test_rhel6_docker Primary x86_64 Docker -- Action Delete],
      %w[rhel-6-server-debuginfo-rpms__6Server__s390x Primary s390x Debuginfo -- Action Delete],
      %w[rhel-6-server-rpms__6Server__s390x Primary s390x Binary -- Action Delete],
      %w[rhel-6-server-debuginfo-rpms__6Server__ppc64 Primary ppc64 Debuginfo -- Action Delete],
      %w[rhel-6-server-rpms__6Server__ppc64 Primary ppc64 Binary -- Action Delete]
    ]

    [
      [Channel, channels, "RHN channels"],
      [CdnRepo, cdn_repos, "CDN repositories"]
    ].each do |klass,repos, caption|
      label = klass.name.pluralize.underscore
      within(".#{label}_tab") do
        # make sure the tabs are shown
        tab_title = "Attached #{caption}"
        assert find(:xpath, "a[@href='\##{label}_tab']").has_text?(tab_title), "Can't find '#{tab_title}' tab"
      end
      # make sure the correct repositories are shown in the table
      path = "//div[@id='#{label}_tab']/form/div[contains(@class, 'panel')]/table/tbody"
      assert find(:xpath, path).has_text?(repos.flatten.join(" ")), "#{caption} not match"
    end
  end

  channels = %w[
    rhel-x86_64-server-6
    rhel-s390x-server-6]

  cdn_repos = %w[
    rhel-6-server-debuginfo-rpms__6Server__i386
    rhel-6-server-debuginfo-rpms__6Server__ppc64]

  [
    [Channel, ChannelLink, channels],
    [Channel, ChannelLink, [channels.first]],
    [Channel, ChannelLink, []],
    [CdnRepo, CdnRepoLink, cdn_repos],
    [CdnRepo, CdnRepoLink, [cdn_repos.first]],
    [CdnRepo, CdnRepoLink, []],
  ].each_with_index do |(klass, link, list),i|
    test "detach #{klass.display_name.pluralize} #{i}" do
      test_detach_repos(klass, link, list)
    end
  end

  def test_detach_repos(klass, link, list)
    klass_name = klass.name.underscore
    label = klass.display_name.pluralize
    to_be_detached = klass.where(:name => list)
    pv_v_path = "/product_versions/#{@pv_rhel6.id}/variants/#{@v_6server.id}"
    visit pv_v_path
    click_link "Attached #{label}"

    assert_difference("link.count", list.size * -1) do
      within(:xpath, "//div[@id='#{klass_name.pluralize}_tab']") do
        to_be_detached.each do |repo|
          cid = "#{repo.class.name.underscore}_#{repo.id}"
          find("\##{cid}").check("#{klass_name}_id_")
        end
        click_on "Detach selected"
        # javascript not working, so submit form manually here
        submit_form(page.find("form"))
      end
    end

    if list.any?
      # RHN channel 'rhel-x86_64-server-6' has been...
      # 2 RHN channel have been detached..."
      name = list.size > 1 ? "#{list.size} #{label} have" : "#{label.singularize} '#{list.first}' has"
      expect = "#{name} been detached with product version 'RHEL-6' successfully."
      actual = page.find('#flash_notice').text
      assert_equal pv_v_path, current_path
    else
      actual =  find(:xpath, "//div[contains(@class,'alert-error')]/div").text
      expect = "No #{label} are selected to detach."
    end
    assert_match(/#{expect}/, actual)
  end

  def submit_form(form)
    # driver and native are protected method, use send() to override them
    Capybara::RackTest::Form.new(form.send(:driver), form.send(:native)).submit({})
  end
end
