#
# Tasks to build and publish the Publican docs.
#
# Requirements:
#   To build you need publican, as well as the publican-redhat-engservices publican
#   brand. See here to get the rpm:
#     https://brewweb.engineering.redhat.com/brew/packageinfo?packageID=31635
#
#   You also need pandoc to convert the markdown to docbook xml.
#   It is available for Fedora. For RHEL you can get it from EPEL.
#     sudo yum install pandoc
#
#   To publish you should have rhpkg installed. See here for details:
#     https://home.corp.redhat.com/wiki/using-dist-git
#   And will also need ssh access and the right permissions on
#   pkgs.devel.redhat.com to publish.
#
namespace :publican do

  # Watch how I cleverly avoid having to rewrite this rake file to be multi-book aware.
  # Just set BOOK=Errata_Tool_Whatever_Book on command line to build a different book.
  # See also the all_books task.
  BOOK_NAME     = ENV['BOOK'] || 'User_Guide'

  BASE_DIR      = "#{Rails.root}/publican_docs"
  COMMON_DIR    = "#{BASE_DIR}/common"
  COMMON_CSS    = "#{COMMON_DIR}/html.css"
  BOOK_DIR      = "#{BASE_DIR}/#{BOOK_NAME}"
  CONTENT_DIR   = "#{BOOK_DIR}/en-US"
  MAIN_SRC      = "#{BOOK_DIR}/Main.erb"
  MAIN_XML      = "#{CONTENT_DIR}/Main.xml"
  BRAND_DIR     = "#{BOOK_DIR}/_brand"
  CUSTOM_CSS    = "#{BOOK_DIR}/html.css"
  MD_SRC        = "#{BOOK_DIR}/markdown"
  MD_OUTPUT     = "#{MD_SRC}/_generated"

  GIT_BRANCH    = 'eng-docs-rhel-6'

  BOOK_FORMATS = %w[html]
  # (Previously included html-single and pdf formats also)

  #
  # Apply some string replace on the contents of a file.
  # Pass in a list of regexp, replace_string pairs.
  #
  def sed_hack(file_name, replace_list)
    text = File.read(file_name)
    replace_list.each do |replace_regexp, replace_string|
      text.gsub! replace_regexp, replace_string
    end
    File.open(file_name, 'w') { |f| f.write(text) }
  end

  def source_file_to_xml(source_file, output_file)
    case source_file.pathmap('%x')
    when '.erb'
      basename = source_file.pathmap('%n')
      new_source_file = "#{MD_OUTPUT}/#{basename}"
      puts "Processing ERB for #{basename}"
      included_content_dir = "#{MD_SRC}/#{basename.pathmap('%n')}"
      write_content_to_file(new_source_file, parse_file_as_erb(source_file,
        :content_dir=>included_content_dir, :helpers=>DocbookErb::ReleaseNoteHelpers))
      source_file_to_xml(new_source_file, output_file)
    when '.md'
      markdown_to_xml(source_file, output_file)
    when '.adoc'
      asciidoc_to_xml(source_file, output_file)
    else
      raise "Can't convert source file #{source_file} to xml"
    end
  end

  #
  # Convert markdown to docbook xml.
  #
  # Requires pandoc.
  #
  def markdown_to_xml(input_file, output_file)
    basename = input_file.pathmap('%n')
    id_prefix = "#{basename.downcase.gsub(/_/,'-')}-"

    puts "Processing markdown for #{basename}"

    # Run pandoc
    verbose(false) do
      sh "pandoc " +
        "--chapters " +
        "--from=markdown --to=docbook " +
        "--id-prefix=#{id_prefix} " +
        "--variable=book_name:#{BOOK_NAME} " +
        "--output=#{output_file} " +
        "#{input_file}"
    end

    sed_hack(output_file, [

      # <section> tag hack.
      # Dan M says <section> is better than <sect1>, <sect2> etc
      # (He's right. <sect1> and <sect2> come out with a way too big font..)
      # I don't know how to make pandoc use <section> tags. Maybe it is possible.
      [/<sect[0-9] /,  '<section '],
      [%r{</sect[0-9]>}, '</section>'],

      # In newer pandocs the --id-prefix option does work properly.
      # Set NO_PANDOC_ID_PREFIX_HACK to disable the workaround.
      ([/id="/, %{id="#{id_prefix}}] unless ENV['NO_PANDOC_ID_PREFIX_HACK']),

    ].compact)
  end

  task :require_erb_helpers do
    require 'docbook_erb/helpers'
    require 'docbook_erb/release_note_helpers'
    require 'docbook_erb/template'
  end

  #
  # Try Asciidoctor instead of pandoc.
  # Experimental. Not using this yet.
  #
  def asciidoc_to_xml(input_file, output_file)
    basename = input_file.pathmap('%n')
    puts "Processing asciidoc for #{basename}"

    output = Asciidoctor.render_file(input_file, :attributes => {'backend' => 'docbook'})

    # Temporary hack just to get it working.
    # Todo: Find better way to add the chapter title
    chapter_id, chapter_title = basename.downcase, basename.titleize
    output = %{<chapter id="#{chapter_id}">\n<title>#{chapter_title}</title>\n#{output}\n</chapter>}

    File.open(output_file, 'w') { |f| f.write(output) }
  end

  # Creates a utility hash with the markdown file names as keys and the generated xml file names as values..
  # (Actually it might contain asciidoc files now also..)
  MD_TARGET_HASH = Hash[(FileList["#{MD_SRC}/*.erb"] + FileList["#{MD_SRC}/*.md"] + FileList["#{MD_SRC}/*.adoc"]).map { |f|
    # (calling pathmap twice here so it removes .erb and .md if both are present)
    [f, "#{MD_OUTPUT}/#{f.pathmap('%n').pathmap('%n')}.xml"]
  }]

  directory MD_OUTPUT

  # Setup a file task for each markdown file/generated xml file
  MD_TARGET_HASH.each do |md_file, xml_file|
    #
    # Rules to make the docbook xml files that publican will use.
    #
    file xml_file => [:require_erb_helpers, md_file, MD_OUTPUT]  do
      source_file_to_xml(md_file, xml_file)
    end

  end

  #
  # Create generated docbook files from markdown source files
  #
  task :pandoc_build => MD_TARGET_HASH.values

  #
  # This section requires rdoc to process API docs first
  #
  file MD_TARGET_HASH["#{MD_SRC}/API.md.erb"] => 'apidocs:prepare_md'

  #
  # Main.erb is parsed to generate en-US/_Main.xml
  #
  file MAIN_XML => [:require_erb_helpers, :pandoc_build, MAIN_SRC] do |f|
    DocbookErb::Template.new(MAIN_SRC, BOOK_NAME, MD_OUTPUT).render_to_file(MAIN_XML)
  end

  task :main_file_build => MAIN_XML

  def do_publican_build(formats=BOOK_FORMATS)
    cd BOOK_DIR do
      sh "publican build --brand_dir #{BRAND_DIR} --formats #{Array.wrap(formats).join(',')} --langs en-US"
    end
  end

  #
  # Brand hackery: Let's copy the brand directory entirely then insert our css.
  # (defaults.cfg is just an arbitrary file to indicate the brand is present)
  #
  file "#{BRAND_DIR}/defaults.cfg" do
    # Copy the real brand
    FileUtils.cp_r "/usr/share/publican/Common_Content/RedHat-EngServices", BRAND_DIR

    # Fix relative XSL paths.. D:
    BOOK_FORMATS.each do |format|
      sed_hack("#{BRAND_DIR}/xsl/#{format}.xsl",
        [[Regexp.new(Regexp.escape('"../../../xsl/')), '"/usr/share/publican/xsl/']])
    end

    # Add our custom css
    sh "cat #{COMMON_CSS} #{CUSTOM_CSS} >> #{BRAND_DIR}/en-US/css/overrides.css"

    # Add some images
    sh "cp #{COMMON_DIR}/*.png #{BRAND_DIR}/en-US/images/"
  end
  task :prepare_brand => "#{BRAND_DIR}/defaults.cfg"

  #
  # Build from xml source using publican
  #
  task :publican_build => :prepare_brand do
    do_publican_build 'html'
  end

  #
  # Same as the above but with extra formats
  #
  task :publican_build_all => :prepare_brand do
    do_publican_build
  end

  #
  # Take a look at it in browser
  # (Depending on your environment this may not work)
  #
  task :view_local do
    sh "xdg-open file://#{BOOK_DIR}/tmp/en-US/html/index.html"
  end

  #
  # Take a look at it in firefox (all formats)
  #
  task :view_local_all do
    # Take a look at it
    sh "firefox file://#{BOOK_DIR}/tmp/en-US/"
  end

  #
  # Create a local copy of the docs in publican_docs/Errata_Tool/tmp/
  #
  desc "Generate the book locally"
  task :build_only => [:pandoc_build, :main_file_build, :publican_build] # Use build_only to avoid opening 100 firefox tabs...
  desc "Generate the book locally and view it"
  task :build      => [:build_only, :view_local]
  task :clean_build => [:clean, :build_only]

  desc "Generate the book locally in all formats"
  task :build_all_only  => [:pandoc_build, :main_file_build, :publican_build_all]
  desc "Generate the book locally in all formats and view them"
  task :build_all  => [:build_all_only, :view_local_all]
  task :clean_build_all => [:clean, :build_all_only]

  desc "Build scratch rpm for book"
  task :scratch_build => [:ensure_local_kerb_ticket, :clean, :build_all_only] do
    cd BOOK_DIR do
      sh "rhpkg publican-build --publican-args '--brand_dir #{BRAND_DIR}' --scratch --lang en-US"
    end
  end

  #
  # Package up the book, check it into dist-git, and launch the brew build
  # in one easy command with rhpkg.
  #
  desc "Publish documentation to http://engineering.redhat.com/docs"
  task :publish_now => [:ensure_local_kerb_ticket, :clean, :build_all_only] do
    cd BOOK_DIR do

      # Show user a check list
      puts ""
      puts "Before publishing you should have done the following:"
      # Pretty sure it just uses the revnumber from Revision_History now..
      #puts " * Bumped the pubsnumber in Book_Info.xml."
      puts " * Added a changelog entry in Revision_History.xml."
      puts ""

      # Ask user for a commit message
      commit_message = ask_for_user_input "Please type a commit message for this update (or Ctrl-C to cancel)"

      # Are you sure?
      puts "Commit message is: #{commit_message.inspect}"
      ask_to_continue_or_cancel "Publish now?"

      # Doo it
      sh "rhpkg publican-build --publican-args '--brand_dir #{BRAND_DIR}' --branch #{GIT_BRANCH} --lang en-US --message #{commit_message.inspect}"

      # Show some info and some urls
      puts ""
      puts "It takes a while (30 minutes or so?), but once it has fully propagated the new version should be available here:"
      puts "https://engineering.redhat.com/docs/en-US/Application_Guide/#{book_to_dir(BOOK_NAME)}/html/Errata_Tool/"
      puts ""

    end
  end

  def is_draft_mode?
    ENV['DRAFT'].present? && ENV['DRAFT'] != '0'
  end

  def draft_file_host
    ENV['FILE_HOST'] || 'file.bne.redhat.com' # So you can use different host if needed..
  end

  def draft_file_scp_user
    ENV['SCP_USER'] || ENV['USER']
  end

  WIP_PUBLISH_DIR = 'WIP'
  REL_PUBLISH_DIR = 'pre'
  def draft_publish_dir
    is_draft_mode? ? WIP_PUBLISH_DIR : REL_PUBLISH_DIR
  end

  # Could read this from Book_Info.xml, but whatever..
  def book_to_dir(book)
    case book
    when 'User_Guide'
      '90.User'
    when 'Developer_Guide'
      '80.Developer'
    when 'Release_Notes'
      '60.Release'
    else
      book
    end
  end

  #
  # For previewing before a real publish.
  # You have to create the ~/public_html/et-docs/{WIP,pre} directories yourself.
  #
  desc "Publish documentation as draft for proofing etc"
  task :publish_draft => [:clean, :build_all_only, :draft_index] do
    draft_tmp_dir = "#{BOOK_DIR}/tmp/publish_draft/#{draft_publish_dir}/#{book_to_dir(BOOK_NAME)}"
    rm_rf draft_tmp_dir
    FileUtils.mkdir_p draft_tmp_dir
    BOOK_FORMATS.each do |format|
      FileUtils.mkdir_p "#{draft_tmp_dir}/#{format}"
      FileUtils.cp_r "#{BOOK_DIR}/tmp/en-US/#{format}/", "#{draft_tmp_dir}/#{format}/Errata_Tool"
    end
    sh "scp -qr #{draft_tmp_dir} #{draft_file_scp_user}@#{draft_file_host}:public_html/et-docs/#{draft_publish_dir}/"
  end

  task :ensure_no_uncommitted_files do
    uncommitted_files = `git status --porcelain | grep publican_docs/#{BOOK_NAME}`
    raise "Uncommitted book content found!\n#{uncommitted_files}" if uncommitted_files.present?
  end

  # Expected to be called from the deploy:build_src_rpm task. See deploy.rake.
  task :add_to_src_rpm => [:ensure_no_uncommitted_files, :clean, :build_all_only] do
    src_rpm_build_dir = "/tmp/errata_rails_build"
    FileUtils.cp_r "#{BOOK_DIR}/tmp/en-US/html/", "#{src_rpm_build_dir}/public/#{BOOK_NAME.downcase.gsub(/_/,'-')}"
  end

  desc "refresh the index at /~sbaird/et-docs/"
  task :draft_index do
    # This might be a bit over-engineered..
    write_content_to_file('/tmp/tmp.html', [
      "<!DOCTYPE html><html><head>",
      "<style>html{background-color:#ccc;}body{border-radius:2em;margin:3em 6em;",
      "background-color:white;padding:1.5em 3em 3em 3em;font-family:sans-serif;}</style>",
      "</head><body><h1>Errata Tool Documentation Index</h1>",
      [
        ['Live',        'https://engineering.redhat.com/docs/en-US/Application_Guide', 'Live in production now on e.r.c/docs.'],
        ['Pre-release', REL_PUBLISH_DIR, 'Pre-release version, should be publishable.'],
        ['WIP',         WIP_PUBLISH_DIR, 'Under construction version, may contain incomplete or placeholder content.'],
      ].map { |title, dir, descr| [
        "<h2>#{title}</h2><p>#{descr}</p><ul>",
        ALL_BOOKS.map { |book| [
          "<li><b>#{book.gsub(/_/,' ')}</b> <small>",
          BOOK_FORMATS.map{|format| %{<a href='#{dir}/#{book_to_dir(book)}/#{format}/Errata_Tool/'>#{format}</a>} }.join(" | "),
          "</small></li>",
        ]},
        "</ul>",
      ]},
      "<p style='font-size:85%;margin-top:5em;color:#999;'>Updated: #{Time.now}</p>",
      "</body></html>",
    ].flatten.join("\n"))

    sh "scp /tmp/tmp.html #{draft_file_scp_user}@#{draft_file_host}:public_html/et-docs/index.html"
    puts "Index updated at http://#{draft_file_host}/~#{ENV['USER']}/et-docs/"
  end

  #
  # Clean out the generated tmp dir
  #
  desc "Clean generated publican docs"
  task :clean do
    rm_rf "#{BOOK_DIR}/tmp"
    rm_rf BRAND_DIR
    rm_rf MD_OUTPUT
    rm_rf MAIN_XML
  end

  #ALL_BOOKS = FileList["#{Rails.root}/publican_docs/*"].map{ |dir| dir.pathmap('%n') }
  ALL_BOOKS = %w[User_Guide Release_Notes Developer_Guide]

  desc "Specify DO=sometask to do it for all books, eg `rake publican:all_books DO=clean`"
  task :all_books do
    ALL_BOOKS.each do |book|
      # (Maybe there's a nicer, less hacky way to do this)
      sh "rake publican:#{ENV['DO']||ENV['do']} BOOK=#{book}"
    end
  end

  desc "clean all books"
  task :clean_all do
    # Go deeper!
    sh "rake publican:all_books DO=clean"
  end

  desc "publish draft all books"
  task :publish_draft_all do
    # Go deeper!
    sh "rake publican:all_books DO=publish_draft"
    sh "rake publican:draft_index"
  end

  #
  # Simple helper for starting off a new set of release notes
  #
  desc "Create dir, move content and copy file for new release notes"
  task :release_note_init do
    raise "Wrong book!" unless BOOK_NAME == 'Release_Notes'

    # Determine some useful version numbers
    spec = RpmSpecFile.current
    x, y, z = spec.version.split('.')
    prev_xyz = latest_release_note_file.match(/Rel_Notes_(\d+)_(\d+)_(\d+)\.md/)[1..3].join(".")
    next_xyz = "#{x}.#{y}.#{z.to_i + 1}"
    next_xy = "#{x}.#{y.to_i + 1}"
    next_xyz = "#{next_xy}.0" if ENV['Y_INCREMENT_COMING'] == '1'

    # Create directory to hold per bug markdown snippets and move them into it
    next_release_dir = "#{MD_SRC}/next_release"
    new_dir = "#{MD_SRC}/Rel_Notes_#{x}_#{y}_#{z}"

    if File.exist?(new_dir)
      # If this dir exists already we'll do nothing
      # (Since we run this in CI now this will be the case for some
      # release branch commits).
      puts "Found existing directory for #{new_dir}, bailing out"
      next # (in a block so don't return)
    end

    FileUtils.mkdir_p(new_dir)
    sh "git mv -k #{next_release_dir}/*.md #{new_dir}"

    # Adjust path to screenshots
    Dir["#{new_dir}/*.md"].each do |md_file_name|
      sed_hack(md_file_name, [[%r{/next_release/}, "/#{x}.#{y}.#{z}/"]])
      sh "git add #{md_file_name}"
    end

    # Create directory to hold images and move them into it
    next_release_images_dir = "#{CONTENT_DIR}/images/next_release"
    new_images_dir = "#{CONTENT_DIR}/images/#{x}.#{y}.#{z}/"
    FileUtils.mkdir_p(new_images_dir)
    sh "git mv -k #{next_release_images_dir}/*.png #{next_release_images_dir}/*.gif #{new_images_dir}"

    # Create main template for release notes then git add it
    new_file = "#{MD_SRC}/Rel_Notes_#{x}_#{y}_#{z}.md.erb"
    write_content_to_file(new_file, render_template('release_notes',
      :xyz => "#{x}.#{y}.#{z}",
      :xy => "#{x}.#{y}",
      :z => z,
      :next_xy => next_xy,
      :prev_xyz => prev_xyz,
      :bug_list => get_bug_list_from_changelog,
      :bug_count => spec.changelog.length
    ))
    sh "git add #{new_file}"

    # Let's commit
    sh "git commit -m '#{x}.#{y}.#{z}: Initial release notes prep\n\nGenerated with rake publican:release_note_init'"

    puts "\nRelease note initial commit created."
    puts "See https://docs.engineering.redhat.com/x/ryrHAQ"
  end

  def latest_release_note_file
    `git ls-files --with-tree=HEAD #{MD_SRC}/Rel_Notes_*.md.erb`.split("\n").
      sort_by{|fn| fn.split(/[^0-9]/).reject(&:blank?).map(&:to_i)}.
      last
  end
end
