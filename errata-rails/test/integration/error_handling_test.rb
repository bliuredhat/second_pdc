require 'test_helper'

class ErrorHandlingTest < ActionDispatch::IntegrationTest

  test "flash error is rendered by default layout" do
    auth_as admin_user

    error = 'simulated error from error handling autotest'
    visit_page_with_error error
    assert page.has_text?(error), page.html
  end

  test "huge flash errors are automatically truncated on line break" do
    auth_as admin_user

    error = ['begin<br/>', 'this is a long error message<br/>' * 5000, 'end of simulated error'].join

    visit_page_with_error error
    html = page.html

    assert_match %r{
      begin<br\ ?/>
      # a heuristic should keep the lines intact, the number of lines should be reduced a lot
      (?-x:this is a long error message<br ?/>){10,100}
      (?-x:\.\.\.additional messages were hidden\. Too many errors to display!)
    }x, html, html

    assert_no_match %r{end of simulated error}, html, html
  end

  # Don't want to waste time repeating all tests for both :alert and :error since the code is
  # the same.  This one arbitrarily uses :alert.
  test "huge flash alerts are truncated anywhere if a line break is not available" do
    auth_as admin_user

    error = ['begin<br/>', 'abcd' * 5000, 'end of simulated error'].join

    visit_page_with_error error, :alert
    html = page.html

    assert_match %r{
      begin<br\ ?/>
      (abcd){10,1000}
      (a(b(cd?)?)?)?
      (?-x:<br ?/>\.\.\.additional messages were hidden\. Too many errors to display!)
    }x, html, html

    assert_no_match %r{end of simulated error}, html, html
  end

  # Visit an arbitrary page with a flash message simulated.
  def visit_page_with_error(message, type=:error)
    # AdminController#index is chosen since its implementation is empty,
    # and likely to stay that way.
    old_index = AdminController.instance_method(:index)
    begin
      AdminController.send(:define_method, :index, lambda{flash[type] = message})
      visit '/admin'
    ensure
      AdminController.send(:define_method, :index, old_index)
    end
  end
end
