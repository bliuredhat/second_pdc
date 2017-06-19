# This module has been extracted from test_helper.rb where similar methods
# are patched into  ActionDispatch::IntegrationTest
# This module overrides the methods in that IntegrationTest class as calling
# these methods in a cucumber step-definition get handled by rack_test which
# doesn't add the headers and doesn't set the intenal @request object causing
# tests that assert_response to fail
#
module HttpMethods

  # Make the simple get, post, put methods include the same headers
  # used by the page driver.  This allows auth_as/logout to work
  # also for these methods since auth_as and logout works by adding
  # HTTP headers.
  [:get, :post, :put].each do |method|
    define_method(method) do |*args|
      path       = args[0]
      parameters = args[1] || nil
      env        = args[2] || {}

      # include page headers when making http requests
      new_env = headers.merge(env)

      # Let the new arguments go via method_missing, as normal.
      method_missing(method, path, parameters, new_env)
    end
  end

  private

  def headers
    ret = case Capybara.current_driver
          when :rack_test
            page.driver.browser.options[:headers]
          when :poltergeist
            page.driver.headers
          else
            raise 'Unknown Capybara driver'
          end
    ret || {}
  end

end
World(HttpMethods)
