#
# Some scripts for dumping/loading the database and for fetching
# data from qestage.
#
# Note: There is some overlap here with functionality in the
# dataset plugin rake tasks, see dataset_tasks.rake, in
# particular the dump and load tasks.
#
# But this version is lets you load from any file. It does gzipping
# and uses mysql directly for loading instead of going through active record
# (which in theory in could be faster...).
#
namespace :db do
  namespace :sync do
    #
    # These things run for a long time so let's show start time and end time.
    # This takes a block. (Todo: could just use say_with_time method probably)
    #
    def show_time_taken
      puts "** Started: #{(started=Time.now).strftime('%H:%M:%S')}"
      yield
      puts "** Started:    #{started.strftime('%H:%M:%S')}"
      puts "** Finished:   #{(finished=Time.now).strftime('%H:%M:%S')}"
      puts "** Time taken: #{Time.at((finished - started).to_i).utc.strftime("%H:%M:%S")}"
    end

    #
    # A mysqldump command line.
    # The --net_buffer_length option is intended to keeps lines down to a sensible length
    # (probably not needed now, plus the super long rpmdiff rows still come out super long anyway).
    # Will always gzip. Use zcat if you want to look at the file.
    #
    def sql_dump_command(db_conf)
      "mysqldump --net_buffer_length=80000 #{sql_user_opts(db_conf)} #{db_conf['database']} | gzip -"
    end

    #
    # A mysql command line to load a gzipped sql dump.
    #
    def sql_load_command(db_conf,dump_file)
      # Because this takes ages, added -v for verbose so you can see where it's up to.
      %{ zcat #{dump_file} |
         sed 's/`errata`/`#{db_conf['database']}`/' |
         mysql -v #{sql_user_opts(db_conf)} \
           --database=#{db_conf['database']} \
           --host=#{db_conf['host']}  \
           --port=#{db_conf['port']} |
         grep '^CREATE TABLE'
      }.gsub(/\s+/, ' ')
    end

    #
    # Make sure dbdumps dir is there.
    #
    DB_DUMPS_DIR = './dbdumps'
    directory DB_DUMPS_DIR
    task :ensure_dir_exists => DB_DUMPS_DIR

    #
    # Dump the local database to a gzipped file
    #
    desc "Dump local database to a gzipped sql file"
    task :dump => [:environment, :development_only, :ensure_dir_exists] do
      # Dump sql to a file
      show_time_taken do
        sh "#{sql_dump_command(get_db_conf)} > #{DB_DUMPS_DIR}/local_dump.#{Time.now.to_i}.sql.gz"
      end
    end

    #
    # Show warning about database name
    #
    task :warn_db_name do
      if (db_conf=get_db_conf)['database'] != 'errata'
        ask_to_continue_or_cancel(
          "Using:\n\n\t`#{db_conf['database']}`\n\n instead of the default `errata` database. " +
          "Cancel if the wrong database is selected.")
      end
    end

    #
    # Try to scp a fresh db dump from DB_DEVEL_HOST
    #
    DB_DEVEL_HOST = 'errata-devel-db.app.eng.bos.redhat.com'
    desc "Scp a db dump from #{DB_DEVEL_HOST} (and optionally load it)"
    task :fetch_new_dump => [:development_only, :ensure_dir_exists] do
      latest_file_details = `ssh #{DB_DEVEL_HOST} ls -lt /database-dump/*.sql.gz | head -1`.strip
      latest_file = latest_file_details.split[-1]
      puts "Found #{DB_DEVEL_HOST}:#{latest_file}\n#{latest_file_details}"
      exit unless ask_for_yes_no("Start scp now?")
      sh "scp #{DB_DEVEL_HOST}:#{latest_file} #{DB_DUMPS_DIR}"

      puts "To load: #{load_command = "DUMP_FILE=#{DB_DUMPS_DIR}/#{File.basename(latest_file)} rake db:sync:load"}"
      exit unless ask_for_yes_no("Start load now?")
      sh load_command
    end

    #
    # Drop and recreate the local database, then load data from a gzipped sql dump
    # WARNING: destructive to your local database obviously...
    #
    desc "Load database from a gzipped sql dump"
    task :load => [:environment, :development_only, :warn_db_name, :ensure_dir_exists] do
      dump_file = ENV['DUMP_FILE'] or raise "Must specify DUMP_FILE=filename on command line"
      # Drop the database and recreate it using built in rake tasks
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
      show_time_taken do
        sh sql_load_command(get_db_conf,dump_file)
      end
    end

    #
    # Update build's volume name to 'prod' where volume name is null or ''.
    # This task is needed to run when import ET production db to ET stage.
    # So that can support all the builds from both Brew prod and staging
    # environments.
    # See Bug: 1344160
    #
    desc "Update Brew builds volume name"
    task :update_brew_volume_name => [:environment, :not_production] do
      affected_rows = ActiveRecord::Base.connection.
                      update(
                        'update brew_builds set volume_name = "prod" where volume_name is null or volume_name = ""')
      puts "#{affected_rows} brew #{affected_rows > 1?'builds have':'build has'} been updated volume name to 'prod'."
    end

    #
    # Was just wondering how many rows were in each table...
    #
    desc "Show row counts"
    task :show_row_counts => :environment do
      counts = {}
      ActiveRecord::Base.connection.tap do |conn|
        conn.execute('show tables').each do |table_name_row|
          table_name = table_name_row.first
          conn.execute("select count(*) from %s" % table_name).each do |table_count_row|
            count = table_count_row.first
            counts[table_name] = count
          end
        end
      end
      puts counts.sort_by{|k,v|v.to_i}.reverse.map{|k,v|"%8s - %s" % [v, k]}.join("\n")
    end
  end
end
