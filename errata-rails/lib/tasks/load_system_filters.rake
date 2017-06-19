
namespace :filters do

  #
  # Warning: if you run this it resets the ids.
  # So if users have their default filter set to one
  # of the system filters then it will stop working and
  # they will have to set their preference again.
  #
  # (In other words, don't run this script unless you really
  # have to).
  #
  desc "Reload system filters"
  task :load_system_filters => :environment do

    # First remove any old ones...
    SystemErrataFilter.order('id DESC').each do |filter|
      filter.delete
    end

    #
    # Now add new ones...
    # (Maybe it would be better to import from a yaml file?)
    #
    all_types = {'show_type_RHBA' => '1', 'show_type_RHSA' => '1', 'show_type_RHEA' => '1'}

    SystemErrataFilter.create([
      {
        :name => 'Active Advisories (Default)',
        :filter_params => ErrataFilter::FILTER_DEFAULTS,
      },
      {
        :name => 'Active, assigned to you',
        :filter_params => ErrataFilter::FILTER_DEFAULTS.merge({'qe_owner_is_me' => '1'}),
      },
      {
        :name => 'Active, reported by you',
        :filter_params => ErrataFilter::FILTER_DEFAULTS.merge({'reporter_is_me' => '1'}),
      },

      #
      # TODO:
      #  What are some useful filters to add here?
      #
      {
        :name => 'All NEW_FILES',
        :filter_params => all_types.merge({'show_state_NEW_FILES' => '1'})
      },
      {
        :name => 'All SHIPPED_LIVE',
        :filter_params => all_types.merge({'show_state_SHIPPED_LIVE' => '1'})
      },
    ])
  end

end
