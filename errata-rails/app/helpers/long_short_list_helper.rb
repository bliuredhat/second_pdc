#
# Some common methods used when displaying toggleable short/long bug
# and build lists in the summary tab. (Put them here just because
# ErrataHelper is getting quite long and a bit messy).
#
module LongShortListHelper

  def long_short_toggle_button(list_type, things_name, things_count, opts={})
    case list_type
    when :long
      show_what = "fewer"
      up_down   = "up"
    when :short
      show_what = "all #{things_count}"
      up_down   = "down"
    else
      # Button is not shown at all when just a "normal" list
      return ''
    end

    # The long and short lists both have this class.
    # Since one is hidden and one is visible toggle is an easy way to flip them.
    # (Could possibly move this js into errata_view.js, but it doesn't matter much).
    toggle_long_short = "jQuery(this).closest('.section_container').find('.toggle_long_short').toggle();"

    # Scroll up to the top of the list when shortening the long list from the bottom
    # otherwise the user is left way down the page and it's confusing.
    scroll_tweak = "window.scrollTo(0, jQuery('h2 a[name=#{things_name}]').offset().top);"

    link_to_function(
      "Show #{show_what} #{things_name.gsub('_', ' ') }#{" <i style='opacity:0.2;' class='icon-chevron-#{up_down}'></i>" unless opts.delete(:no_icon)}".html_safe,
      "#{toggle_long_short}#{scroll_tweak if list_type == :long && opts.delete(:scroll_tweak)}",
      opts
    )
  end

  def more_not_shown_warning_maybe(list_type, things_name, how_many_not_shown)
    if list_type == :short
      content_tag(:span,
        "WARNING: THERE ARE #{how_many_not_shown} MORE #{things_name.gsub('_', ' ').upcase} CURRENTLY NOT SHOWN",
        :class => 'bold superlight small',
        :style => 'letter-spacing:4px; padding-left:1em;'
      )
    end
  end

end
