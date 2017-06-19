Then(/^I see Errata fetching data from Lightblue$/) do
  find('div.ajax_spinner')
  has_text? 'Fetching data from Lightblue'
end

Then(/^I see an alert message "([^"]*)"$/) do |msg|
  flash_alert = find('#flash_alert')
  within(flash_alert) { assert_text msg }
end

Then(/^^(?:|I see )?details of all Builds in the Advisory$/) do
  within_content do
    @advisory.brew_builds.each { |build| assert has_text? build.nvr }
  end
end

Then(/^(?:|I see )?details about Associated Advisories and CVE$/) do
  within_content do
    @advisory.container_cves.each { |cve| assert has_link? cve }
    @advisory.container_errata.each { |ce| assert has_link? ce.advisory_name }
  end
end

Then(/^I am able to see the details about Bugs$/) do
  bugs = @advisory.container_errata.map(&:bugs).flatten

  within_content do
    # handle shown/hidden
    click_on('Show Bugs/Issues') if has_link?('Show Bugs/Issues')

    bugs.each do |bug|
      assert has_link?(bug.id), "Unable to find link for Bug: #{bug.id}"
      assert has_text?(bug.short_desc),
             "Unable to find link for Bug: #{bug.short_desc}"
    end
  end
end

Then(/^I can view tags by clicking tags icon$/) do
  repo = @advisory.container_content.values.first.container_repos.first

  within_content { first(:css, '.fa-tags').click }

  within_popover do
    assert has_text? 'Docker Tags'
    repo.tags.split(' ').each do |tag|
      assert has_text? tag
    end
  end
end

Then(/^I can view comparison data by clicking info icon$/) do
  repo = @advisory.container_content.values.first.container_repos.first

  within_content { first(:css, '.fa-info-circle').click }

  within_popover do
    assert has_text? 'Comparison With Previous Version'
    assert has_text? repo.comparison[:with_nvr]

    repo.rpms.each do |key, rpms|
      header = "#{key.capitalize} (#{rpms.count})"
      assert has_text? header
      rpms.keys.each do |rpm|
        assert has_link? rpm
      end
    end
  end
end
