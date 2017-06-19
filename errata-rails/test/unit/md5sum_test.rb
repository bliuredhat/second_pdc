require 'test_helper'

class Md5SumTest < ActiveSupport::TestCase
  setup do
    @md5_1 = Md5sum.create(:brew_file => BrewRpm.first,
                           :sig_key => BrewRpm.first.brew_build.sig_key,
                           :value => 'ae2b1fca515949e5d54fb22b8ed95575')

    @md5_2 = Md5sum.create(:brew_file => BrewRpm.last,
                           :sig_key => BrewRpm.last.brew_build.sig_key,
                           :value => 'invalid_md5_value')
    assert @md5_1.valid?
    assert @md5_2.valid?
  end

  test "md5 validation" do
    assert @md5_1.checksum_valid?
    refute @md5_2.checksum_valid?
  end

  test "get brew rpm md5 checksum" do
    result = Md5sum.brew_file_checksum(BrewRpm.first, BrewRpm.first.brew_build.sig_key)
    assert_equal @md5_1, result
  end

  test "test create a duplicate md5 checksum" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      duplicate = Md5sum.create!(:brew_file => BrewRpm.first,
                                 :sig_key => BrewRpm.first.brew_build.sig_key,
                                 :value => 'ae2b1fca515949e5d54fb22b8ed95575')
    end
    assert_match(/\bValue ae2b1fca515949e5d54fb22b8ed95575 has already been taken \(duplicate Md5sum\)$/, error.message)
  end
end