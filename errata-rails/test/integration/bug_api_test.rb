require 'test_helper'

class BugApiTest < ActionDispatch::IntegrationTest
  setup do
    auth_as devel_user
  end

  test 'refresh with bad request' do
    post_json '/api/v1/bug/refresh', {:foo => 'bar'}
    assert_response :bad_request
    assert_response_error 'request body must contain a valid JSON array of bug numbers or aliases'
  end

  test 'refresh one existing' do
    mock_bugs(130358, {'id' => 130358,
       'summary' => 'bug 130358',
       'status' => 'FOO'
    })
    assert_no_difference('Bug.count') do
      post_json '/api/v1/bug/refresh', [130358]
    end
    assert_response 204, response.body
    assert response.body.empty?
    assert_equal 'FOO', Bug.find(130358).bug_status
  end

  test 'refresh one new' do
    mock_bugs(130358666, {'id' => 130358666,
       'summary' => 'a new bug',
       'status' => 'QUUX'
    })
    assert_difference('Bug.count', 1) do
      post_json '/api/v1/bug/refresh', [130358666]
    end
    assert_response 204, response.body
    assert response.body.empty?
    assert_equal 'QUUX', Bug.find(130358666).bug_status
  end

  test 'refresh mixed' do
    bug_ids = [
      # update by ID
      130358,
      # update by ID as string
      '131142',
      # fetch by ID
      314159,
      # fetch by ID as string
      '141421',
      # update by alias
      'CVE-2011-0013',
      # update by alias (multi-alias bug)
      'CVE-2011-0542',
      # fetch by alias
      'some-new-alias'
    ]

    bug_data = [
        # use a generic response for bugs fetched by ID
        {'id' => 130358, 'summary' => "updated 130358", 'status' => 'CLOSED'},
        {'id' => 131142, 'summary' => "updated 131142", 'status' => 'CLOSED'},
        {'id' => 314159, 'summary' => "updated 314159", 'status' => 'CLOSED'},
        {'id' => 141421, 'summary' => "updated 141421", 'status' => 'CLOSED'},
        # be careful to match up the bug alias and ID correctly in these mocks
        {'id' => 675786, 'alias' => ['CVE-2011-0013'],
          'summary' => 'updated 675786', 'status' => 'CLOSED'},
        {'id' => 651183, 'alias' => %w[CVE-2010-3789 CVE-2011-0542 CVE-2011-0543],
          'summary' => 'updated 651183', 'status' => 'CLOSED'},
        {'id' => 888888, 'alias' => %w[some-new-alias other-alias],
          'summary' => 'updated 888888', 'status' => 'CLOSED'},
    ]

    # sanity check fixtures first
    (exist,notexist) = bug_data.partition{|b| Bug.find_by_id(b['id']).present?}
    assert_equal 3, notexist.length, "fixture problem, expected 3 nonexistent bugs, got: #{notexist.inspect}"

    mock_bugs(bug_ids, bug_data)

    assert_difference('Bug.count', 3) do
      post_json '/api/v1/bug/refresh', bug_ids

      assert_response 204, response.body
      assert response.body.empty?

      # ensure they were all really updated
      %w[130358 131142 314159 141421 675786 651183 888888].each do |id|
        assert_equal "updated #{id}", Bug.find(id).summary
      end
    end

  end

  test 'refresh complains if all bugs do not exist' do
    # request a couple of bugs but none of them exist
    bug_ids = [314159, 'notexist-alias']
    mock_bugs(bug_ids, [])
    assert_no_difference('Bug.count') do
      post_json '/api/v1/bug/refresh', bug_ids
    end
    assert_response 404, response.body
    assert_response_error '2 bugs not found: 314159 and notexist-alias'
  end

  test 'refresh complains if some bugs do not exist' do
    bug_ids = [888889, 'foo-alias', 888891, 888892, 888893, 888894, 888888]
    mock_bugs(bug_ids, {'id' => '888888', 'summary' => 'only existing bug in request', 'status' => 'CLOSED'})

    # the 1 existing bug _is_ created even though the request ultimately fails
    assert_difference('Bug.count', 1) do
      post_json '/api/v1/bug/refresh', bug_ids
    end
    assert_equal 'only existing bug in request', Bug.find(888888).summary

    assert_response 404, response.body
    assert_response_error '6 bugs not found: 888889, foo-alias, 888891, 888892 and 2 more'
  end

  def assert_response_error(message)
    parsed = JSON.parse(response.body)
    assert_equal message, parsed['error']
  end

  def mock_bugs(bug_ids, returned_bugs)
    bug_ids = Array.wrap(bug_ids)
    returned_bugs = Array.wrap(returned_bugs)

    Bugzilla::Rpc.any_instance.expects(:raw_get_bugs).once.with{|fetch_ids, opts|
      opts[:permissive] && (fetch_ids.sort_by(&:to_s) == bug_ids.sort_by(&:to_s))
    }.returns({'bugs' => returned_bugs})
  end
end
