# This module is intended as a workaround to remove RJS,
# especially patterns of the form
# render :update do |page|
#   page.replace_html 'foo'
#   page.some_function 'bar', 'baz'
# end
#
# Most of these usages should be replaced with proper
# javascript/coffeescript files once the Rails 3.2
# version of ET is deployed and stable.
module ReplaceHtml
  extend ActiveSupport::Concern

  def render_js(js)
    render :js => js
  end

  def replace_html_to_string(id, new_html)
    js_for_html(id, view_context.escape_javascript(new_html))
  end

  def replace_html(id, new_html)
    render_js replace_html_to_string(id, new_html)
  end

  def replace_with_partial(id, template, render_opts = {})
    render_js js_for_template(id, template, render_opts)
  end

  def partial_to_string(template, render_opts, escape_newlines=true)
    content = render_to_string({:partial => template}.merge(render_opts)).strip
    ["\r\n", "\n", "\r"].each {|v| content.gsub!(v, '\\\\n')} if escape_newlines
    content
  end

  def js_for_before(id, new_html)
    "$('##{id}').before('#{new_html}');"
  end

  def js_for_after(id, new_html)
    "$('##{id}').after('#{new_html}');"
  end

  def js_for_append(id, new_html)
    "$('##{id}').append('#{new_html}');"
  end

  def js_for_prepend(id, new_html)
    "$('##{id}').prepend('#{new_html}');"
  end

  def js_for_html(id, new_html, replace_method='html')
    "$('##{id}').#{replace_method}('#{new_html}');"
  end

  def js_hide(id)
    "$('##{id}').hide();"
  end

  def js_remove(id)
    "$('##{id}').remove();"
  end

  def js_show(id)
    "$('##{id}').show();"
  end

  def js_remove(id)
    "$('##{id}').remove();"
  end

  def js_clear(id)
    js_set_val(id, '')
  end

  # Set the +value+ of an element with the given +id+, using the .val() jQuery
  # method (e.g. form inputs).
  def js_set_val(id, value)
    value ||= ''
    escaped = view_context.escape_javascript(value);
    "$('##{id}').val('#{escaped}');"
  end

  def js_for_template(id, template, render_opts = {}, replace_method='html')
    new_html = partial_to_string template, render_opts, false
    new_html = view_context.escape_javascript(new_html)
    js = js_for_html id, new_html, replace_method
    # elements within the replaced fragment might need initialization
    js += "Eso.initAll('\##{id}');"
    js
  end
end
