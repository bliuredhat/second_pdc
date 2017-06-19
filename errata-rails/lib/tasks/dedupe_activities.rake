#
# See Bug 841304
# We have a bunch of duplicate change state records in the activity table.
# This script attempts to locate and remove the most obvious ones.
#
# It will miss some probably. It seems like the more you increase the
# thresholds, the more you find.. But it will get the majority of them.
#
# There are some strange dupes that are thousands of ids apart that this
# script will not detect. It's as though the rows were recreated at some point.
# Might need to revisit this later if those rows are causing problems.
#
#
namespace :one_time_scripts do

  SECONDS_THRESHOLD = 10
  ID_DIFF_THRESHOLD = 10

  def dupe_sql
    #
    # You can tune what rows are detected as dupes by tweaking
    # these settings...
    #
    # If you don't limit by id then we are basically comparing
    # timestamps of every row with every row and the query takes a
    # very very long time...
    #

    %{
      SELECT
        orig.id as id,
        dupe.id as dupe_id
      FROM
        errata_activities orig,
        errata_activities dupe
      WHERE
        -- Consider the first one to be the original
        --
        -- Consider it a dupe only if its id is within ID_DIFF_THRESHOLD of original
        --
        (
          -- I think this way is faster than comparing with > and <
          #{[*1..ID_DIFF_THRESHOLD].map{ |i| "orig.id = dupe.id - #{i}" }.join("        OR\n")}
        )
        --
        -- Consider it a dupe only if it occurred within SECONDS_THRESHOLD seconds of original
        -- Apparently we have older records with higher ids.. no idea how.. :(
        --
        AND ABS( CAST(UNIX_TIMESTAMP(dupe.created_at) AS SIGNED) -
          CAST(UNIX_TIMESTAMP(orig.created_at) AS SIGNED) ) < #{SECONDS_THRESHOLD}
        --
        -- Currently look at status changes only (though perhaps we have other kinds of dupes..)
        --
        AND orig.what = 'status'
        --
        -- Obviously it's only a dupe if it is the same activity
        --
        AND orig.errata_id  = dupe.errata_id
        AND orig.who_id     = dupe.who_id
        AND orig.what       = dupe.what
        AND (orig.removed = dupe.removed OR (orig.removed IS NULL AND dupe.removed IS NULL))
        AND (orig.added   = dupe.added   OR (orig.added   IS NULL AND dupe.added   IS NULL))
      }
    end

  desc "Remove duplicate rows in errata_activities. See Bz 841304 and Bz 799836."
  task :remove_dupes => :environment do
    #
    # Beware these are not full ErrataActivity records, the sql
    # just returns two columns, an id and a dupe_id.
    # It's just easier to use find_by_sql here rather than
    # ActiveRecord::Base.execute..
    #
    seconds_diffs = Hash.new{0}
    id_diffs = Hash.new{0}
    records = ErrataActivity.find_by_sql(dupe_sql)
    created_ats = []

    records.each do |record|
      orig = ErrataActivity.find(record.id)
      dupe = ErrataActivity.find(record.dupe_id)
      seconds_diff = (dupe.created_at - orig.created_at).abs
      id_diff = dupe.id - orig.id

      puts "ORIG: #{orig.inspect}"
      puts "DUPE: #{dupe.inspect}"
      puts ""

      created_ats << dupe.created_at
      seconds_diffs[seconds_diff] += 1
      id_diffs[id_diff] += 1
    end

    puts ""
    puts "Seconds apart threshold: #{SECONDS_THRESHOLD}"
    puts "Ids apart threshold: #{ID_DIFF_THRESHOLD}"
    puts "Dupes found #{records.length}"
    puts "Seconds apart counts: #{seconds_diffs.sort_by{|k,v|k}.map{|k,v|"#{k.to_i} => #{v}, "}}"
    puts "Ids apart counts: #{id_diffs.sort_by{|k,v|k}.map{|k,v|"#{k} => #{v}, "}}"
    puts "Oldest: #{created_ats.min}"
    puts "Newest: #{created_ats.max}"
    puts ""
    puts "Please pipe that into a file and make sure it looks okay."
    puts ""
    puts "***********************************************"
    puts "To really delete the above list of dupes, run this rake task:"
    puts ""
    puts "  rake one_time_scripts:remove_dupes_really_delete_them"
    puts ""
    puts "***********************************************"
    puts ""
  end

  task :remove_dupes_really_delete_them => :environment do
    puts "THIS DESTROYS RECORDS PERMANENTLY. ARE YOU SURE?"
    ask_to_continue_or_cancel
    ErrataActivity.find_by_sql(dupe_sql).each do |record|
      puts "Deleting ErrataActivity record #{record.dupe_id}..."
      ErrataActivity.find(record.dupe_id).delete
    end
  end
end
