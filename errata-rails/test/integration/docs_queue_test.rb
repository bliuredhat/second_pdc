require 'test_helper'

class DocsQueueTest < ActionDispatch::IntegrationTest
  setup do
    # make a few advisories doc_complete 0 rather than adding new fixtures
    Errata.where(:id => [16384,16374]).each{|e| e.update_attribute(:doc_complete, 0)}

    # all advisories for the queue in the fixtures
    @docs_ready_errata = Errata.find(
      11065,
      11145,
      11105,
      11095,
      11152,
      11036,
      11112,
      10893,
      16384,
      16374
    )

    workflows_with_docs = DocsGuard.pluck('DISTINCT state_machine_rule_set_id')
    (@mandatory_errata, @non_mandatory_errata) = @docs_ready_errata.partition do |e|
      workflows_with_docs.include?(e.state_machine_rule_set.id)
    end
  end

  # would prefer to check this in setup, but assert in setup is harmful
  test 'fixture prerequisites' do
    refute @mandatory_errata.empty?, 'Fixtures must have some docs-ready advisories using a DocsGuard workflow'
    refute @non_mandatory_errata.empty?, 'Fixtures must have some docs-ready advisories not using a DocsGuard workflow'
  end

  test 'docs list with default settings shows mandatory advisories only' do
    auth_as devel_user
    visit '/docs/list'
    assert_shown @mandatory_errata
    assert_hidden @non_mandatory_errata
  end

  test 'docs list with mandatory_only=0 shows all docs-ready advisories' do
    auth_as devel_user
    visit "/docs/list?mandatory_only=0"
    assert_shown @mandatory_errata
    assert_shown @non_mandatory_errata
  end

  test 'my queue only shows my advisories' do
    user = User.find(3000624)
    auth_as user

    visit "/docs/my_queue"

    (shown,hidden) = @mandatory_errata.partition{|e| e.doc_reviewer == user }
    refute shown.empty? || hidden.empty?, "Fixtures problem: must have some docs ready, mandatory advisories for #{user} and some for other users"

    assert_shown shown
    assert_hidden hidden
  end

  test 'by_responsibility filters advisories by responsibility as expected' do
    auth_as devel_user
    visit '/docs/errata_by_responsibility/kde_(k_desktop_environment)'
    resp = DocsResponsibility.find_by_url_name!('kde_(k_desktop_environment)')

    (shown,hidden) = @mandatory_errata.partition{|e| e.docs_responsibility == resp }
    refute shown.empty? || hidden.empty?, "Fixtures problem: must have some KDE and some non-KDE advisories in docs queue"

    assert_shown shown
    assert_hidden hidden
  end

  def assert_shown(advisories)
    advisories.each do |e|
      name = e.advisory_name
      assert page.has_content?(name), "Missing advisory #{name} in docs list"
    end
  end

  def assert_hidden(advisories)
    advisories.each do |e|
      name = e.advisory_name
      refute page.has_content?(name), "Advisory #{name} was unexpectedly shown"
    end
  end
end
