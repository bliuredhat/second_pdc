#
# Disclaimer:
#
#  Not sure if this is good or accurate but
#  thought I would commit it anyhow.
#
namespace :mem_profile do

  # (Copied from the example in the readme)
  def do_memory_profile

    # See lib/memory-profiler.rb
    require 'memory-profiler'

    # start the daemon, and let us know the file to which it reports
    puts MemoryProfiler.start_daemon( :limit=>5, :delay=>10, :marshall_size=>true, :sort_by=>:absdelta )

    # compare memory space before and after executing a block of code
    rpt = MemoryProfiler.start( :limit=>10 ) do
      yield
    end

    # display the report in a (slightly) readable form
    puts MemoryProfiler.format(rpt)

    # terminate the daemon
    MemoryProfiler.stop_daemon

  end

  #
  # See Bug 1021277
  #
  desc "memory profile for republishing cpe_map_2010"
  task :cpe_map_cache => :environment do
    do_memory_profile do
      Secalert::CpeMapper.publish_cache(2010)
    end
  end

end
