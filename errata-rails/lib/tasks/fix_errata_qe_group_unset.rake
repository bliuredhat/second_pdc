# See Bug 1431155 of 3.14.1.1-0 release
# https://bugzilla.redhat.com/show_bug.cgi?id=1431155
# The aim is to correct any advisories that were created with the QE Group unset after release 3.14.1.1-0
namespace :fix_errata_qe_group_unset do
  desc 'Fix the created errata with QE Group unset'
  task :run => :environment do

    really = ENV.fetch('REALLY', '0') == '1'

    created_on = Time.parse(ENV.fetch('CREATED_ON', '2017-03-02'))
    created_at = Time.utc(created_on.year, created_on.month, created_on.day)

    puts "CHECKING FROM: %s" %(created_at)
    unless really
      puts "== (Dryrun mode, set REALLY=1 if you want to apply updates.) =="
    end

    errata = Errata.
      where("quality_responsibility_id = ?", QualityResponsibility.find_by_name('Default').id).
      where("created_at > ?", created_at)
    errata.each do |erratum|
      puts "\nCHECKING ERRATUM: %s %s, CREATED_AT: %s" %[erratum.fulladvisory, erratum.synopsis, erratum.created_at]
      package = Package.find_by_name(erratum.synopsis)
      # Apply this change only for the erratum having QE Group defined in the corresponding package
      next unless package

      current_qe_group = erratum.quality_responsibility
      if erratum.quality_responsibility.name == 'Default' && package.quality_responsibility.name != 'Default'
        puts "AFFECTED ERRATUM: %s %s" %[erratum.fulladvisory, erratum.synopsis]
        puts "CURRENT QE GROUP: %s, PACKAGE QE GROUP: %s" %[erratum.quality_responsibility.name, package.quality_responsibility.name]
        next unless really
        erratum.quality_responsibility = package.quality_responsibility
        erratum.save!
        erratum.comments.create(:who => @user, :text => "Changed QE group from #{current_qe_group.name} to #{erratum.quality_responsibility.name}")
        puts "FIXED ERRATUM: %s %s\nSETTING QE GROUP: %s" %[erratum.fulladvisory, erratum.synopsis, erratum.quality_responsibility.name]
      end
    end
  end
end