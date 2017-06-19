#
# See https://engineering.redhat.com/rt/Ticket/Display.html?id=276432#txn-5345168
#
# dmach's python script will spit out json like this:
#
# {
#    "15361": {
#        "add": [
#            "glibc-2.17-48.el7"
#        ],
#        "remove": [
#            "glibc-2.17-47.el7"
#        ]
#    },
#    ...
# }
#
# This task should read the json from a file and perform the required
# build removes and adds.
#
# Note: Bug 1028222 adds the ability to add and remove builds via the api,
# so in the future this kind of thing will no be needed.
#
namespace :bulk_update_builds do

  def _ensure_loaded(nvr)
    return puts "(Build #{nvr} already loaded)" if BrewBuild.find_by_nvr(nvr)
    begin
      puts "Fetching #{nvr} from brew"
      BrewBuild.make_from_rpc(nvr)
    rescue => e
      puts "Unable to fetch #{nvr} due to '#{e.message}'!"
    end
  end

  def _remove_build(errata, nvr)
    return puts "Build #{nvr} not found!" unless brew_build = BrewBuild.find_by_nvr(nvr)
    return puts "Build #{nvr} not attached to errata #{errata.id}!" unless errata_brew_mapping = errata.errata_brew_mappings.find_by_brew_build_id(brew_build.id)
    errata_brew_mapping.obsolete!
    errata.comments.create(:text => "Removed build '#{nvr}'.")
    puts "Removed #{nvr}"
  end

  def _add_build(errata, product_version, nvr)
    _ensure_loaded(nvr)
    return puts "Build #{nvr} not found!" unless brew_build = BrewBuild.find_by_nvr(nvr)
    return puts "Build #{nvr} already added!" if errata.brew_builds.include?(brew_build)
    ErrataBrewMapping.create!(
      :errata          => errata,
      :product_version => product_version,
      :brew_build      => brew_build,
      :package         => brew_build.package
    )
    errata.comments.create(:text => "Added build '#{nvr}'.")
    RpmdiffRun.schedule_runs(errata)
    puts "Added #{nvr}"
  end

  def _handle_errata(errata_id, remove_nvrs, add_nvrs)
    return puts "Errata #{errata_id} not found!" unless errata = Errata.find_by_id(errata_id)
    puts "Found errata id #{errata.id} - #{errata.status} #{errata.fulladvisory} #{errata.synopsis}"

    # Choosing which product version to use might not be trivial.
    # But in this particular case there will be just one (ie RHEL7).
    return puts "#{errata.available_product_versions.count} product versions!" if errata.available_product_versions.count != 1
    product_version = errata.available_product_versions.first

    return puts "Not QE or NEW_FILES!" unless errata.status_in?(:NEW_FILES, :QE)
    errata.change_state!('NEW_FILES', User.find_by_name(ENV['USER'])||User.default_qa_user) if !errata.status_is?(:NEW_FILES)

    remove_nvrs.each do |nvr|
      _remove_build(errata, nvr)
    end

    add_nvrs.each do |nvr|
      _add_build(errata, product_version, nvr)
    end
  end

  desc "Bulk update builds from json source file"
  task :from_json => :environment do
    raise "Please specify INPUT=somefile.json" unless json_file = ENV['INPUT']
    JSON.parse(File.read(json_file)).sort_by{|k,_|k}.each do|errata_id, actions|
      next if ENV['ONLY'] && ENV['ONLY'] != errata_id
      _handle_errata(errata_id, actions['remove'], actions['add'])
      puts "----"
    end
  end

end
