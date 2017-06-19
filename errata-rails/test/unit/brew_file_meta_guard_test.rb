require 'test_helper'

class BrewFileMetaGuardTest < ActiveSupport::TestCase

  def setup
    qr = StateTransition.find_by_from_and_to('NEW_FILES', 'QE')
    @guard = BrewFileMetaGuard.new(
      :state_machine_rule_set => StateMachineRuleSet.last,
      :state_transition => qr
    )
  end

  test "non-rpm advisory with meta" do
    errata = Errata.find(19029)
    assert errata.has_brew_files_requiring_meta?
    assert errata.brew_file_meta.any?
    assert @guard.transition_ok?(errata)
  end

  test "non-rpm advisory without meta" do
    errata = Errata.find(16396)
    assert errata.has_brew_files_requiring_meta?
    assert errata.brew_file_meta.none?
    refute @guard.transition_ok?(errata)
    assert_equal 'Must set attributes on non-RPM files', @guard.failure_message(errata)
  end

  test "docker images do not require metadata" do
    errata = Errata.find(21100)
    assert errata.has_docker?
    assert errata.brew_file_meta.none?
    refute errata.has_brew_files_requiring_meta?
    assert @guard.transition_ok?(errata)

    docker_mapping = errata.build_mappings.first
    assert_equal BrewArchiveType::TAR_ID, docker_mapping.brew_archive_type_id

    # Add .ks files to advisory
    ErrataBrewMapping.create!(
      :product_version => docker_mapping.product_version,
      :errata => errata,
      :brew_build => docker_mapping.brew_build,
      :package => docker_mapping.package,
      :brew_archive_type => BrewArchiveType.find_by_name('ks')
    )

    errata.reload
    assert errata.has_brew_files_requiring_meta?

    # No longer OK, as .ks files do need brew_file_meta
    refute @guard.transition_ok?(errata)
    assert_equal 'Must set attributes on non-RPM files', @guard.failure_message(errata)
  end

end
