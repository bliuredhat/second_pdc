require 'test_helper'

class Sha256sumTest < ActiveSupport::TestCase
  setup do
    @sha256_1 = Sha256sum.create(:brew_file => BrewRpm.first,
                                 :sig_key => BrewRpm.first.brew_build.sig_key,
                                 :value => 'cf80cd8aed482d5d1527d7dc72fceff84e6326592848447d2dc0b0e87dfc9a90')

    @sha256_2 = Sha256sum.create(:brew_file => BrewRpm.last,
                                 :sig_key => BrewRpm.last.brew_build.sig_key,
                                 :value => 'invalid_sha256_value')
    assert @sha256_1.valid?
    assert @sha256_2.valid?
  end

  test "sha256 validation" do
    assert @sha256_1.checksum_valid?
    refute @sha256_2.checksum_valid?
  end

  test "get brew rpm sha256 checksum" do
    result = Sha256sum.brew_file_checksum(BrewRpm.first, BrewRpm.first.brew_build.sig_key)
    assert_equal @sha256_1, result
  end

  test "test create a duplicate sha256 checksum" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      duplicate = Sha256sum.create!(:brew_file => BrewRpm.first,
                                    :sig_key => BrewRpm.first.brew_build.sig_key,
                                    :value => 'cf80cd8aed482d5d1527d7dc72fceff84e6326592848447d2dc0b0e87dfc9a90')
    end
    assert_match(/\bValue cf80cd8aed482d5d1527d7dc72fceff84e6326592848447d2dc0b0e87dfc9a90 has already been taken \(duplicate Sha256sum\)$/, error.message)
  end
end