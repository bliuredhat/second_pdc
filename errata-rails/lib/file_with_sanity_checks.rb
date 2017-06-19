require 'fileutils'

module FileWithSanityChecks

  class ChecksFailedError < RuntimeError
    def initialize(file_name)
      super("Problem updating #{File.basename(file_name)}, keeping old version")
    end
  end

  class Base
    attr_reader :dest_name, :temp_name

    def initialize(dest)
      @dest_name = dest
      @temp_name = make_temp_name(dest)
    end

    def prepare_file(&block)
      File.open(temp_name, 'w') do |file|
        yield file
      end
      self
    end

    # Runs sanity checks and moves the temp_name to dest_name
    # Raises ChecksFailedError if sanity checks fail
    def check_and_move(&_block)
      is_ok = sanity_check_okay?
      is_ok &&= yield(temp_name) if block_given?
      fail ChecksFailedError, dest_name unless is_ok
      move_to_dest
    end

    def cleanup
      FileUtils.rm_f(temp_name)
    end

    protected

    def sanity_check_okay?(&block)
      non_empty?
    end

    private

    def non_empty?
      !File.zero?(temp_name)
    end

    def move_to_dest
      FileUtils.mv(temp_name, dest_name)
    end

    # Not the best temp file ever but should be good enough
    # (Didn't want to use Tempfile in case it gets cleaned up unexpectedly)
    #
    # Beware if you create it in /tmp you can get initrc_tmp_t selinux context
    # rather than httpd_sys_content_t and the file won't be readable by apache!
    def make_temp_name(file_name)
      "#{Rails.root}/tmp/_fwsc_#{File.basename(file_name)}.#{$$}.#{Time.now.to_f}"
    end
  end

  class CpeMapFile < Base
    ALLOWED_SHRINK_RATIO = 0.75

    def size_okay?
      old_size = File.exist?(dest_name) ? File.size(dest_name) : 0
      new_size = File.size(temp_name)
      if old_size == 0 || new_size >= old_size
        # Let's say getting bigger by any amount is okay
        true
      else
        # Let's say shrinking is only allowed by a certain ratio
        (new_size.to_f / old_size) > ALLOWED_SHRINK_RATIO
      end
    end

    def sanity_check_okay?
      super && size_okay?
    end
  end

  class TpsTxtFile < Base
    # An empty tps.txt is allowed so override the default
    def sanity_check_okay?
      true
    end
  end

end
