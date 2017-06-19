#
# We need to sanitize data before sending it to teiid or staging
# and dev servers. Generally this is done in sql and not in
# a Rails environment so we can't use ActiveRecord stuff.
#
# Bernd (bgroh) has a perl script that uses foreign key constraints to
# derive sql that automatically delete objects and their related rows,
# but for some reason we have circular constraints and his perl script
# gets stuck in a loop and blows up.
#
# So the aim of this script is to spit out some sql that can be used to
# nuke an advisory from existence.
#
# NB: Nothing here actually touches the database. It will just
# output some sql.
#
namespace :sanitize_sql do

  #
  # There's probably a cool way to do this kind of with ActiveRecord.
  #
  # Look at this for example:
  #
  # irb(main):011:0> Errata.last.brew_builds.scoped.to_sql
  #  => "SELECT `brew_builds`.* FROM `brew_builds` INNER JOIN `errata_brew_mappings`
  #     ON `brew_builds`.id = `errata_brew_mappings`.brew_build_id WHERE
  #     ((`errata_brew_mappings`.errata_id = 13262) AND ((current = 1)))"
  #
  # irb(main):012:0> Errata.last.bugs.scoped.to_sql
  #  => "SELECT DISTINCT `bugs`.* FROM `bugs` INNER JOIN `filed_bugs` ON
  #     `bugs`.id = `filed_bugs`.bug_id WHERE ((`filed_bugs`.errata_id = 13262))"
  #
  # But never mind...
  #

  #
  # Spit out sql that does joins using an `in (select ...)` way.
  #
  def delete_sql_helper(errata_id, main_table, joins)
    if joins.empty?
      key = (main_table == :errata_main) ? 'id' : 'errata_id'
      "where #{main_table}.#{key} = #{errata_id}"
    else
      # let's get some tail recursion going here.. :)
      join_table, local_fkey, other_fkey = joins.shift

      # Leave out the local_fkey and it will guess it..
      local_fkey ||= "#{main_table.to_s.singularize}_id"
      # advisory_dependencies is the only one where the other key is different..
      other_fkey ||= local_fkey
      "where #{main_table}.#{local_fkey} in (select #{join_table}.#{other_fkey} from #{join_table} #{delete_sql_helper(errata_id, join_table, joins)})"
    end
  end

  def do_delete(errata_id, table, join_list)
    "delete from #{table} #{delete_sql_helper(errata_id, table, join_list)};\n"
  end

  def nuke_advisory_sql(errata_id)
    [
      # Order is significant since there are constraints in effect.

      [:rpmdiff_waivers,         [[:rpmdiff_results, :result_id], [:rpmdiff_runs, :run_id ]] ],
      [:rpmdiff_results,         [[:rpmdiff_runs, :run_id ]] ],
      [:tpsjobs,                 [[:tpsruns, :run_id]] ],
      [:cves,                    [[:errata_cve_maps, :id, :cve_id]] ],
      [:rhts_runs,               [] ],
      [:nitrate_test_plans,      [] ],
      [:tpsruns,                 [] ],
      [:carbon_copies,           [] ],
      [:rhn_push_jobs,           [] ],
      [:rpmdiff_runs,            [] ],

      [:blocking_issues,         [] ],
      [:info_requests,           [] ],
      [:comments,                [] ],

      [:released_packages,       [] ], # not sure, joins to brew_build and brew_rpm?? maybe doesn't matter..
      [:errata_activities,       [] ],

      #[:errata_bug_map,          [] ], # old and not used??

      [:md5sums,                 [[:brew_rpms, :brew_rpm_id, :id], [:errata_brew_mappings, :brew_build_id]] ],
      [:sha256sums,              [[:brew_rpms, :brew_rpm_id, :id], [:errata_brew_mappings, :brew_build_id]] ],
      [:brew_rpms,               [[:errata_brew_mappings, :brew_build_id]] ],
      [:product_listing_caches,  [[:errata_brew_mappings, :brew_build_id]] ],
      [:errata_brew_mappings,    [] ],
      [:brew_builds,             [[:errata_brew_mappings, :id, :brew_build_id]] ],

      [:text_diffs,              [] ],
      [:text_only_channel_lists, [] ],

      [:dropped_bugs,            [] ],
      [:filed_bugs,              [] ],
      [:bugs,                    [[:filed_bugs, :id, :bug_id]] ],

      # these are weird, (see output), but will work anyhow...
      [:advisory_dependencies,   [[:errata_main, :blocking_errata_id, :id]] ],
      [:advisory_dependencies,   [[:errata_main, :dependent_errata_id, :id]] ],

      [:errata_files,            [] ],
      [:errata_content,          [] ],
      [:errata_main,             [] ],

    ].map { |table, join_list| do_delete(errata_id, table, join_list) }.join
  end

  #
  # For debugging you can do this and actually test it in MySQL Workbench:
  #  rake sanitize_sql:go ERRATA_ID=12345
  #
  # Otherwise it just uses $errata_id which hopefully is useful to Bernd
  #
  desc "Show 'nuke sql' for an advisory"
  task :go do
    puts nuke_advisory_sql(ENV['ERRATA_ID'] || '$errata_id') 
  end

end
