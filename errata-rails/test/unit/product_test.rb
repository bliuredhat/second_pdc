require 'test_helper'

class ProductTest < ActiveSupport::TestCase

  test "allow ftp" do
    p = Product.new(:name => 'Allow FTP Test')
    refute p.allow_ftp?
    assert_not_nil p.allow_ftp?

    p.push_targets = [PushTarget.new(:name => 'Test CDN',
                                     :description => 'Test',
                                     :push_type => :cdn)]
    refute p.allow_ftp?

    p.push_targets << PushTarget.new(:name => 'Test FTP',
                                     :description => 'Test',
                                     :push_type => :ftp)
    assert p.allow_ftp?
  end

  test "can't set null rule set" do
    p = Product.last
    assert_valid p

    p.state_machine_rule_set = nil
    refute p.valid?
  end

end
