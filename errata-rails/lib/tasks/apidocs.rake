#
# Generate and publish RDoc docs
#
require 'rdoc/generator/errata_api'

namespace :apidocs do

  desc "Build API docs"
  task :build do
    # Show what version
    # (Todo: put this in the header/footer on each page. Perhaps a timestamp also..)
    ver_rel = RpmSpecFile.current.version_release
    sh %{echo "== Version #{ver_rel}" >> doc/README_FOR_APP}

    # This will put stuff in ./doc
    # (Running rake in a subshell like this instead of Rake::Task['doc:app'].invoke
    # because otherwise it doesn't notice ENV changes and we can't set the title.
    sh "rake doc:app title='Errata Tool'"

    # Remove that version line we added just a moment ago
    sh %{head -n -1 doc/README_FOR_APP > /tmp/README_FOR_APP.tmp; mv /tmp/README_FOR_APP.tmp doc/README_FOR_APP}

  end

  task :add_to_src_rpm => [:clean, :build] do
    src_rpm_build_dir = "/tmp/errata_rails_build"
    FileUtils.cp_r "./doc/app/", "#{src_rpm_build_dir}/public/rdoc"
  end

  RDocTaskWithoutDescriptions.new("prepare_md") { |rdoc|
    rdoc.rdoc_dir = 'publican_docs/Developer_Guide/markdown/API'
    rdoc.title    = 'Errata Tool API'
    rdoc.options << '--charset' << 'utf-8'
    rdoc.options << '--format' << 'errataapi'
    rdoc.rdoc_files.include('app/controllers/**/*.rb')
  }
  Rake::Task['apidocs:prepare_md'].comment = "Prepare API doc markdown for processing by publican"

  desc "Remove generated API docs"
  task :clean do
    rm_rf "./doc/app/"
  end

  # Put in a directory called 'current'
  task :publish_current do
    sh "rsync -r ./doc/app/. errata-devel.app.eng.bos.redhat.com:/var/www/apidocs/current"
  end

  # Put in a directory named with the version number
  task :publish_versioned do
    ver_rel = RpmSpecFile.current.version_release
    sh "rsync -r ./doc/app/. errata-devel.app.eng.bos.redhat.com:/var/www/apidocs/#{ver_rel}"
  end

  # Do-all tasks..
  desc "Clean, build and publish to versioned directory"
  task :build_publish_versioned => [:clean, :build, :publish_versioned]

  desc "Clean, build and publish as 'current'"
  task :build_publish => [:clean, :build, :publish_versioned]

  desc "Clean, build and publish to both versioned dir and 'current' dir"
  task :build_publish_all => [:clean, :build, :publish_current, :publish_versioned]

end
