module CdnReposHelper
  def new_cdn_repo_modal_title
    title = "New #{@cdn_repo.class.display_name}"
    title += " for #{@parent.class.name.titleize} '#{@parent.name}'" if @parent
    title.html_safe
  end

  def cdn_repo_form_content(cdn_repo, form)
    dn = cdn_repo.class.display_name
    message = safe_join([
      ("To link a #{dn} to a product version, please go to: " +
       "Product version page > 'Attached #{dn.pluralize}' tab > " +
       "Variant > 'Action' menu > Click 'Attach #{dn}' button."),
      (content_tag(:b, " '.' and '/' are illegal characters for Pulp Repo Labels" +
        " (for Docker repos, '.' is allowed).") +
        " The convention is to use '__' for '/', and '_DOT_' for '.'")
    ], content_tag(:br))

    contents = [panel_helper("Note", message)]
    contents << table_rows_helper([
      [ 'Pulp Repo Label',         form.text_field(:name) ],
      [ 'Release Type',            cdn_repo.new_record? ? form.select(:release_type, release_types_for_select) : "<b>#{cdn_repo.short_release_type}</b>".html_safe ],
      [ 'Content Type',            cdn_repo.new_record? ? form.select(:type, content_types_for_select) : "<b>#{cdn_repo.short_type}</b>".html_safe ],
      ([ 'Variant',                form.collection_select(:variant_id, @product_version.variants.order(:name), :id, :name) ]),
      [ 'Arch',                    form.collection_select(:arch_id, Arch.active_machine_arches, :id, :name) ],
      [ 'Use for TPS scheduling?', form.check_box(:has_stable_systems_subscribed) ],
    ], :labels=>true)

    content_tag(:table) do
      safe_join(contents)
    end
  end

  def cdn_repo_modal_body_content
    content_tag(:div, :class => "body-content") do
      form_for([@parent, @cdn_repo]) do |f|
        cdn_repo_form_content(@cdn_repo, f)
      end
    end
  end

  def cdn_repo_modal_footer_content
    if @cdn_repo.new_record?
      btn_caption = "Create"
      form_id = "new_cdn_repo"
    else
      btn_caption = "Update"
      form_id = "edit_cdn_repo_#{cdn_repo.id}"
    end

    cancel_btn = button_tag('Cancel', { :class => "btn", :data => { :dismiss => "modal" } })
    submit_btn = button_tag(btn_caption, :class => "btn btn-primary", :id => "save_cdn_repo", :data => {:'form-id' => form_id })

    content_tag(:div, :class => "footer-content") do
      safe_join([cancel_btn," ", submit_btn])
    end
  end

  private

  def content_types_for_select
    CdnRepo::CONTENT_TYPES.map{|t| [CdnRepo.short_content_type(t), t]}
  end

  def release_types_for_select
    CdnRepo::RELEASE_TYPES.map{|t| [CdnRepo.short_release_type(t), t]}
  end
end
