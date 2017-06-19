module UserHelper
  def role_change_message(changes, old_roles, new_roles, user)
    updated_messages = []
    changes.each_pair do |field, vals|
      if vals[0].to_s.empty? || vals[1].to_s.empty?
        updated_messages << (
          vals[0].to_s.empty? ?
            "#{field.humanize} '#{vals[1]}' was added." :
            "#{field.humanize} '#{vals[0]}' was removed."
        )
      else
        updated_messages << "#{field.humanize} changed from '#{vals[0]}' to '#{vals[1]}'"
      end
    end

    removed = (old_roles - new_roles).map{ |r| "'#{r.name.titleize}'" }
    added   = (new_roles - old_roles).map{ |r| "'#{r.name.titleize}'" }

    removed_message = "The #{pluralize_based_on(removed,'role')} #{display_list_with_and(removed )} #{was_were(removed)} removed."
    added_message   = "The #{pluralize_based_on(added,'role'  )} #{display_list_with_and(added   )} #{was_were(added  )} added."

    with_email = user.email_address.present? ? "with a separate email #{user.email_address} " : ''
    current_message = "The user #{user} #{with_email}is currently #{user.enabled_txt.upcase} and has #{pluralize_based_on(new_roles,'role')} #{display_list_with_and(new_roles.map{ |r| "'#{r.name.titleize}'" })}."

    [
      (updated_messages.map(&:wrap_and_indent_bulleted) unless updated_messages.empty?),
      (removed_message.wrap_and_indent_bulleted unless removed.empty?),
      (added_message.wrap_and_indent_bulleted   unless added.empty?),
      ("\n#{current_message.wrap_text}"),
    ].flatten.compact.join("\n").html_safe
  end

  #
  # Used in user preferences
  # See also color_scheme_helper in application_helper
  #
  def color_schemes_for_select
    color_schemes = Settings.all_color_schemes + [('xmas' if is_holiday_season?)].compact
    color_schemes.map{ |s| [s.titleize.sub(/gray/,' Gray').sub(/Xmas/, "Holidays"), s] }
  end

end
