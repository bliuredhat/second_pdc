#
# The ESO theme is a set of web assets (css, js, images) and some ERB templates
# that provide the main layout and look and feel for our rails app.
#
# For more information see: https://engineering.redhat.com/trac/eso-theme
#
namespace :eso_theme do
  #
  # To fetch the latest version of the ESO theme, use this task. It will
  # fetch a tar.gz file and unpack it.
  #
  # It should not overwrite anything important. (If it does you are doing it wrong...)
  #
  # In the future we might look at a better way to do this. Maybe the theme can
  # have it's own rpm. Or maybe we could use a git submodule.
  #
  THEME_SOURCE = 'http://file.bne.redhat.com/~sbaird/eso-theme/eso-theme-latest-rails.tar.gz'
  desc "Fetch latest ESO theme"
  task :update do
    sh "curl --silent #{THEME_SOURCE} | tar zvxf -"
  end

  #
  # As per the description...
  # (A way to purge files deleted from the theme)
  #
  desc "Nuke the ESO theme"
  task :nuke do
    rm_rf "./app/views/layouts/eso-theme"
    rm_rf "./public/javascripts/eso-theme"
    rm_rf "./public/stylesheets/eso-theme"
  end

end
