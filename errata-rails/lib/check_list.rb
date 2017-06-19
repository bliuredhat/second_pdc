#
# Utility class for defining a check list of pass/fail
# tests with user-friendly explanation messages.
#
# See check_list_test for example usage.
#
# (Note: Perhaps it would be possible (and cool) to use
# @_obj.instance_eval &block and have the blocks run
# against the actual object under test.)
#
module CheckList

  class Check
    extend DefineClassMethod

    def initialize(object_to_test, extra_ivars={})
      @_obj = object_to_test
      instance_variable_set("@#{ivar_name}", @_obj)
      extra_ivars.each { |key, val| instance_variable_set("@#{key}", val) }
      setup
    end

    def message
      pass? ? pass_message : fail_message
    end

    # Class methods to create instance methods (DSL style).
    # Note: The class methods have the same name as the instance methods but
    # that's okay. (Don't get confused!)
    def self.pass(&block);         define_method(:pass?,          &block); end
    def self.pass_message(&block); define_method(:pass_message,   &block); end
    def self.fail_message(&block); define_method(:fail_message,   &block); end
    def self.setup(&block);        define_method(:setup,          &block); end
    def self.ivar_name(val);       define_method(:ivar_name)      { val }; end
    def self.title(val);           define_method(:title)          { val }; end
    def self.note(val);            define_method(:note)           { val }; end
    def self.order(val);           define_class_method(:order_by) { val }; end

    # You probably want to over-ride this one.. ;)
    def pass?
      false
    end

    def fail?
      !pass?
    end

    def pass_message
      "'#{title}' check passed for #{@_obj}"
    end

    def fail_message
      "'#{title}' check failed for #{@_obj}"
    end

    # Get default instance var name for the object being tested from
    # the class of the object being test. Eg, for a Bug use @bug
    def ivar_name
      @_obj.class.name.demodulize.underscore
    end

    def setup
    end

    def title
      self.class.name.demodulize.titleize
    end

    def note
      nil
    end

    def self.order_by
      0
    end

    # (Mainly for debugging)
    def to_s
      "#{title}: #{pass? ? 'PASS' : 'FAIL'} - #{message}"
    end

  end

  class List
    attr_reader :checks

    def initialize(object_to_test=nil, extra_ivars={})
      check(object_to_test, extra_ivars)
    end

    def check(object_to_test, extra_ivars={})
      @checks = check_classes.map { |check_class| check_class.new(object_to_test, extra_ivars) }
      self
    end

    def pass_all?
      @checks.all?(&:pass?)
    end

    def pass_count
      @checks.select(&:pass?).count
    end

    def fail_count
      @checks.select(&:fail?).count
    end

    def fail_messages
      @checks.select(&:fail?).map(&:fail_message)
    end

    def fail_text
      fail_messages.join(' ')
    end

    # Class method to create instance method (DSL style)
    # Use this optionally to manually specify the check classes
    def self.check_classes(*classes); define_method(:check_classes) { classes }; end

    # If you don't specify them manually then find check classes that are defined in our local namespace
    def self.find_local_checks
      self.constants.map{ |const_name| const_get(const_name) }.select{ |const| const.ancestors.include?(Check) }.sort_by(&:order_by)
    end

    # Default is to use the check classes defined locally
    def check_classes
      self.class.find_local_checks
    end

    def result_list(*pick_list)
      pick_list = [:pass?, :message, :title] if pick_list.empty?
      @checks.map { |check| pick_list.map{ |pick| check.send(pick) } }
    end

    def unzipped_result_list(*pick_list)
      result_list(*pick_list).transpose
    end

    # (Mainly for debugging)
    def to_s
      @checks.map(&:to_s).join("\n")
    end
  end

end
