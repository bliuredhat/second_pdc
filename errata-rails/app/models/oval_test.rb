# Implements the OVAL definition of an errata.
# http://oval.mitre.org/
# Based on OVAL version 5 schema.
#
# Currently, OVAL only produced for RHEL 3 and RHEL 4 RHSAs.
#
require 'set'
class OvalTest

  # We can't use the errata_key_map table for this as it only contains
  # the msb of the keyid and OVAL requires the whole keyid.
  # TODO: Update to handle multiple signing keys in RHEL 5
  MASTER_KEY = "219180cddb42a60e"

  # VERSION needs to be incremented each time we change
  # the template or this script in such a way that the it changes
  # the tests, objects, states.  It must be an integer.
  VERSION = '6'

  attr_reader :rhsa, :states, :tests, :oval_version, :oval_ns, :oval_id, :criteria, :cpe_list

  def initialize(rhsa)
    @rhsa = rhsa
    # Now that we push the OVAL query in advance we need to preincrement the push count
    @oval_version = VERSION + sprintf("%.2d", @rhsa.pushcount + 1)
    @oval_ns = 'oval:com.redhat.' + @rhsa.errata_type.downcase

    @errata_id = @rhsa.oval_errata_id
    @oval_id = @oval_ns + ':def:' + @errata_id

    @object_count = 1
    @state_count = 1
    @test_count = 1
    @states = []
    @tests = []
    @unique_objects = { }
    @sig_states = Hash.new
    rhsa.brew_builds.order(:nvr).each do |b|
      next if @sig_states.has_key?(b.sig_key.name)
      state = new_state('signature_keyid', 'equals', b.sig_key.full_keyid)
      @sig_states[b.sig_key.name] = state
    end
    @criteria = []
    # Iterate over each rhel product in the erratum, adding OVAL tests & criteria for each build
    @rhsa.brew_builds_by_product_version.sort.each do  |version, builds|
      next unless version.is_oval_product?
      version_number = version.rhel_version_number
      state = new_state('version','pattern match',"^#{version_number}\[^\\d\]")

      rhel_criteria = Criteria.new('AND')
      if version_number.to_i < 6
        @redhat_release ||= new_info_object('redhat-release')
        rhel_criteria.add_test(new_test(@redhat_release, state, "Red Hat Enterprise Linux #{version_number} is installed"))
      else
        or_crit = Criteria.new('OR')
        @redhat_release_client ||= new_info_object('redhat-release-client')
        @redhat_release_server ||= new_info_object('redhat-release-server')
        @redhat_release_workstation ||= new_info_object('redhat-release-workstation')
        @redhat_release_computenode ||= new_info_object('redhat-release-computenode')
        or_crit.add_test(new_test(@redhat_release_client, state, "Red Hat Enterprise Linux #{version_number} Client is installed"))
        or_crit.add_test(new_test(@redhat_release_server, state, "Red Hat Enterprise Linux #{version_number} Server is installed"))
        or_crit.add_test(new_test(@redhat_release_workstation, state, "Red Hat Enterprise Linux #{version_number} Workstation is installed"))
        or_crit.add_test(new_test(@redhat_release_computenode, state, "Red Hat Enterprise Linux #{version_number} ComputeNode is installed"))
        rhel_criteria.add_criteria(or_crit)
      end
      @criteria << rhel_criteria
      objects = builds.each_with_object([]) {|b, arry| arry.concat(create_object_criteria(b))}
      next if objects.empty?

      # OR together all the object criteria, adding to the overall criteria for the product.
      # This will render something like:
      #  <criterion test_ref="oval:com.redhat.rhsa:tst:20060666001" comment="Red Hat Enterprise Linux 3 is installed"/>
      #    <criteria operator="OR">
      #      <criteria operator="AND">
      #        <criterion test_ref="oval:com.redhat.rhsa:tst:20060666002" comment="foobar is earlier than 9:02.1.0"/>
      #        <criterion test_ref="oval:com.redhat.rhsa:tst:20060666003" comment="foobar is signed with Red Hat master key"/>
      #      </criteria>
      #      <criteria operator="AND">
      #        <criterion test_ref="oval:com.redhat.rhsa:tst:20060666004" comment="foobar-devel is earlier than 9:02.1.0"/>
      #        etc...
      if objects.length > 1
        or_crit = Criteria.new('OR')
        rhel_criteria.add_criteria(or_crit)
        objects.each { |o| or_crit.add_criteria(o)}
      else
        # Only a single base package in the errata, so add only the tests to the rhel_criteria
        # Will thus render something like:
        # <criteria operator="AND">
        #   <criterion test_ref="oval:com.redhat.rhsa:tst:20060666001" comment="Red Hat Enterprise Linux 4 is installed"/>
        #   <criterion test_ref="oval:com.redhat.rhsa:tst:20060666002" comment="foobar is earlier than 9:02.1.0"/>
        #   <criterion test_ref="oval:com.redhat.rhsa:tst:20060666003" comment="foobar is signed with Red Hat master key"/>
        # </criteria>
        obj_criteria = objects[0]
        obj_criteria.tests.each { |t| rhel_criteria.add_test(t.test)}
      end
    end

    @cpe_list = Set.new
    @rhsa.get_variants.each do |v|
      cpe = v.cpe_for_oval
      @cpe_list << cpe if cpe.present?
    end

    # Join multiple release criteria with OR
    # Maintain the criteria as a list for simplicity of template processing
    if @criteria.length > 1
      or_crit = Criteria.new('OR')
      @criteria.each { |c| or_crit.add_criteria(c)}
      @criteria = [or_crit]
    end
  end


  def packages
    return @unique_objects.values
  end

  private


  def create_object_criteria(build)
    unique_build_rpms = Hash.new
    evr_states = { }
    build.brew_rpms.each do |r|
      next if r.is_debuginfo?
        rpm_name = r.name_nonvr
        object = get_info_object(rpm_name)
        unless unique_build_rpms.has_key?(rpm_name)
          evr = "#{r.epoch}:#{[r.version,r.release].join('-')}"
          evr_states[evr] ||= new_state('evr', 'less than', evr)
          evr_state = evr_states[evr]
          object_criteria = Criteria.new('AND')
          object_criteria.add_test(new_test(object, evr_state, "#{rpm_name} is earlier than #{evr}"))
          object_criteria.add_test(new_signed_test(object, build.sig_key.name)) if r.is_signed?
          unique_build_rpms[rpm_name] = object_criteria
        end
    end

    return unique_build_rpms.sort.map(&:second)
  end

  # Returns the rpm_info object for the given package name
  # Creates a new one if it does not yet exist
  def get_info_object(rpm_name)
    unless @unique_objects.has_key?(rpm_name)
      new_info_object(rpm_name)
    end
    object = @unique_objects[rpm_name]
    return object
  end

  # Creates a new rpm_info object for the given pacakge name
  def new_info_object(rpm_name)
    @unique_objects = Hash.new unless @unique_objects
    id = gen_id('obj', @object_count)
    obj = InfoObject.new(id, rpm_name)
    @unique_objects[rpm_name] = obj
    @object_count += 1
    return obj
  end

  def new_state(type,operation,value)
    id = gen_id('ste', @state_count)
    state = RPMInfoState.new(id, type,operation,value)
    @states << state
    @state_count += 1
    return state
  end

  def new_test(object, state, comment)
    id = gen_id('tst', @test_count)
    test = RPMInfoTest.new(id, object, state, comment)
    @test_count += 1
    @tests << test
    return test
  end

  def new_signed_test(object, sig_name)
    @signed_tests = Hash.new unless @signed_tests
    key = "#{object.id}-#{sig_name}"
    unless @signed_tests.has_key?(key)
      @signed_tests[key] = new_test(object, @sig_states[sig_name], "#{object.rpm_name} is signed with Red Hat #{sig_name} key")
    end
    return @signed_tests[key]
  end

  def gen_id(type, count)
    id = @oval_ns + ":#{type}:" + @errata_id + sprintf("%.3d", count);
  end

  class Criteria
    attr_reader :operator, :criteria, :tests
    def initialize(operator)
      @tests = []
      @criteria = []
      @operator = operator
    end

    def add_criteria(crit)
      @criteria << crit
    end

    def add_test(test)
      @tests << Criterion.new(test)
    end

    class Criterion
      attr_reader :test

      def initialize(test)
        @test = test
      end

      def test_ref
        return @test.id
      end

      def comment
        return @test.comment
      end
    end
  end

  # Represents rpminfo_object. Renders like:
  #  <rpminfo_object id="oval:com.redhat.rhsa:obj:20060666001" version="201">
  #    <name>foobar</name>
  #  </rpminfo_object>
  class InfoObject
    attr_reader :id,:rpm_name
    def initialize(id,name)
      @id = id
      @rpm_name = name
    end
  end

  # Represents rpminfo_state. Renders like:
  #  <rpminfo_state id="oval:com.redhat.rhsa:ste:20060666003" version="201">
  #    <evr datatype="evr_string" operation="less than">9:02.1.0</evr>
  #  </rpminfo_state>
  #
  class RPMInfoState
    attr_reader :id,:type,:operation,:value,:datatype
    def initialize(id,type,operation,value)
      @id = id
      @type = type
      @operation = operation
      @value = value
      if @type == 'evr'
        @datatype = 'evr_string'
      end
    end
  end

  # Represents rpminfo_state. Renders like:
  #  <rpminfo_test id="oval:com.redhat.rhsa:tst:20060666006" version="201" comment="redhat-release is version 4" check="at least one">
  #    <object object_ref="oval:com.redhat.rhsa:obj:20060666001"/>
  #    <state state_ref="oval:com.redhat.rhsa:ste:20060666004"/>
  #  </rpminfo_test>
  class RPMInfoTest
    attr_reader :comment, :id, :state, :rpm_object
    def initialize(id,object,state,comment)
      @id = id
      @rpm_object = object
      @state = state
      @comment = comment
    end
  end

end
