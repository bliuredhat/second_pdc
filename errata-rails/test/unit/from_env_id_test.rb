require 'test_helper'

class FromEnvIdTest < ActiveSupport::TestCase

  setup do
    @errata = Errata.first
    @errata_brew_mapping = ErrataBrewMapping.first
    ENV['ID'] = @errata.id.to_s
    ENV['MAP'] = @errata_brew_mapping.id.to_s
  end

  test "from env id rake task helper" do
    assert_equal @errata, FromEnvId.get_errata(:quiet=>true)
    assert_equal @errata_brew_mapping, FromEnvId.get_mapping(:var_name=>'MAP', :quiet=>true)
  end

  test "error if env var not set" do
    ENV.delete('ID')
    assert_raises(RuntimeError) { FromEnvId.get_errata }
  end

  test "error if record not found" do
    ENV['ID'] = 'blah'
    assert_raises(ActiveRecord::RecordNotFound) { FromEnvId.get_errata }
  end

end
