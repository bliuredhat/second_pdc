require 'test_helper'

class QeControllerTest < ActionController::TestCase
  def setup
    @request.env['HTTP_X_REMOTE_USER'] = qa_user.login_name
  end

  def test_errata_for_qe_group
    get :errata_for_qe_group, :id => 'foo'
    assert_redirected_to :controller => :qe, :action => :errata_for_qe_group, :id => 'default'
    assert_equal "No such QE Group: foo", flash[:error]
  end
end
