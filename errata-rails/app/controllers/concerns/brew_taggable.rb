module BrewTaggable
  extend ActiveSupport::Concern
  include ReplaceHtml
  def add_tag
    klass = Kernel.const_get(controller_name.camelize.singularize)
    obj = klass.find(params[:id])
    name = params[:tag][:name].strip
    if name.present?
      tag = BrewTag.find_or_create_by_name(name)
    end

    if name.blank? || obj.brew_tags.include?(tag)
      render :text => ''
      return
    end

    obj.brew_tags << tag
    render_tag_html obj
  end

  def remove_tag
    klass = Kernel.const_get(controller_name.camelize.singularize)
    obj = klass.find(params[:id])
    tag = BrewTag.find(params[:tag_id])
    obj.brew_tags.delete(tag)
    render_tag_html obj
  end

  def render_tag_html(obj)
    js = js_for_template('brew_tag_admin',
                         '/shared/brew_tag_admin',
                         {:object => obj})
    #
    # TODO: This hack is unfinished business. The management of brew
    # tags is also used in the ReleaseController. With the
    # refactoring of the admin UI, this `klass` distinction should
    # become obsolete.
    # Bug: 999317
    #
    if obj.instance_of? ProductVersion
      js += js_for_template('brew_tags_and_edit_btn',
                            '/shared/brew_tags_and_edit_btn',
                            {:locals => { :brew_tags => obj.brew_tags}})
    end
    render_js js
  end
end
