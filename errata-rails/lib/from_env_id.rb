#
# For use in rake tasks.
# Specify an object id on the command line as and environment variable
#
module FromEnvId
  module_function

  def get_object_from_env_id(klass, opts={})
    var_name = opts[:var_name] || 'ID'
    obj_id = ENV[var_name]
    raise "Please specify environment var for #{klass.name} id on command line, eg #{var_name}=123123" unless obj_id.present?
    result = klass.find(obj_id) # (throws exception if not found)
    puts "Found #{result.inspect}" unless opts[:quiet]
    result
  end

  # Todo: some meta programming might be nice here
  def get_errata(opts={});   get_object_from_env_id(Errata, opts);            end
  def get_mapping(opts={});  get_object_from_env_id(ErrataBrewMapping, opts); end
  def get_test_run(opts={}); get_object_from_env_id(ExternalTestRun, opts);   end

end
