#
# This logic used to be spread around in the Bug model and some other places.
# The aim is to put all flag related functionality here.
#
# This has a unit test. See bz_flags_test.rb
#

#
# Represents a single flag.
# Flags have a name and a state.
#
module BzFlag
  ACKED    = '+'
  NACKED   = '-'
  PROPOSED = '?'
  INVALID  = ''

  class Flag
    include Comparable

    attr_accessor :name, :state

    def initialize(flag_info)
      #
      # Parse a flag string, eg "foo+" or "bar?".
      # Be tolerant of whitespace before or after
      #
      if flag_info.is_a?(String) && flag_info =~ /^\s*(\S+)([\-\+\?])\s*$/
        @name = $1
        @state = $2

      #
      # Problem parsing the flag
      #
      else
        @name = flag_info
        @state = INVALID
      end
    end

    #
    # There are some css classes that let you display flags
    # with nice colours depending on their state.
    #
    def css_class
      "flag-status #{state_name}"
    end

    def state_name
      case state
      when ACKED;    'acked'
      when NACKED;   'nacked'
      when PROPOSED; 'proposed'
      when INVALID;  'invalid'
      end
    end

    #
    # Convert back to "foo+" when printing
    #
    def to_s
      "#{name}#{state}"
    end

    #
    # Comparison (just for fun)
    # (Makes the Comparable include work)
    #
    def <=>(other_flag)
      self.to_s <=> other_flag.to_s # (lazy but good)
    end
  end

  #
  # In Bugzilla flags are stored as a comma delimited text field.
  # This contains some methods for dealing with that.
  #
  class FlagList
    include Enumerable

    #
    # Parse flags field as it is stored by Bugzilla.
    # For example: "foo+, bar?".
    #
    def initialize(flags_text)
      @flags = flags_text.split(/,/).map{ |flag_text| Flag.new(flag_text) }
    end

    #
    # Returns true if one flag is in INVALID state.
    #
    def has_invalid_flag?
      @flags.reject{ |f| f.state != BzFlag::INVALID }.any?
    end

    # Find a flag by name and return it.
    # Must match the state also if one if given.
    # Returns nil if the flag can't be found.
    #
    def find_flag(flag_name, flag_state=nil)
      detect do |flag|
        flag.name == flag_name && (flag_state.nil? || flag.state == flag_state)
      end
    end

    #
    # Get the state of a given flag.
    # Will return nil if the flag isn't there.
    #
    def flag_state(flag_name)
      find_flag(flag_name).try(:state)
    end

    #
    # The old has_flag? method meant "has acked flag?"
    # so preserve that meaning.
    #
    def has_flag?(flag_name)
      find_flag(flag_name, ACKED).present?
    end

    #
    # Return true if all flags are acked
    #
    def has_all_flags?(flag_names)
      flag_names.all? { |flag_name| has_flag?(flag_name) }
    end

    #
    # If we define each then Enumerable will
    # take care of other handy iterators.
    #
    def each(&blk)
      @flags.each(&blk)
    end

    #
    # Convert back to string if needed
    #
    def to_s
      @flags.join(', ')
    end
  end
end
