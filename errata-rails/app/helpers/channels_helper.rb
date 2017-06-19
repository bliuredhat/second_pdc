# Methods added to this helper will be available to all templates in the application.
module ChannelsHelper
  def new_channel_modal_title
    title = "New #{@channel.class.display_name}"
    title += " for #{@parent.class.name.titleize} '#{@parent.name}'" if @parent
    title.html_safe
  end

  def channel_form
    # Normally wouldn't have to specify the url in form_for here.
    # But what happens is the automagic paths use the sub class
    # eg eus_channel instead of just channel and the routing doesn't
    # work.
    #
    # So have to specify the url in form_for here. And it has to be
    # different depending on whether the channel is new or existing.
    #
    # (It took a while to figure this out, see Bug 876548).
    #
    form_path = @channel.new_record? ? product_version_channels_path : product_version_channel_path

    form_for(@channel, :as => :channel, :url => form_path) do |f|
      yield @channel, f
    end
  end

  def channel_form_content(channel,form)
    dn = channel.class.display_name
    message = "To link a #{dn} to a product version, please go to: " +
      "Product version page > 'Attached #{dn.pluralize}' tab > " +
      "Variant > 'Action' menu > Click 'Attach #{dn}' button."

    contents = [panel_helper("Note", message)]
    contents << table_rows_helper([
      [ 'Name',                    form.text_field(:name) ],
      [ 'Release Type',            channel.new_record? ? form.select(:type, [:PrimaryChannel, :EusChannel, :FastTrackChannel, :LongLifeChannel]) : "<b>#{@channel.short_type}</b>".html_safe ],
      ([ 'Variant',                form.collection_select(:variant_id, @product_version.variants.order(:name), :id, :name) ]),
      [ 'Arch',                    form.collection_select(:arch_id, Arch.active_machine_arches, :id, :name) ],
      [ 'Use for TPS scheduling?', form.check_box(:has_stable_systems_subscribed) ],
    ], :labels=>true)

    content_tag(:table) do
      safe_join(contents)
    end
  end

  def channel_modal_body_content
    content_tag(:div, :class => "body-content") do
      channel_form do |channel, f|
        channel_form_content(channel, f)
      end
    end
  end

  def channel_modal_footer_content
    if @channel.new_record?
      btn_caption = "Create"
      form_id = "new_channel"
    else
      btn_caption = "Update"
      form_id = "edit_channel"
    end

    cancel_btn = button_tag('Cancel', { :class => "btn", :data => { :dismiss => "modal" } })
    submit_btn = button_tag(btn_caption, :class => "btn btn-primary", :id => "save_channel", :data => {:'form-id' => form_id })

    content_tag(:div, :class => "footer-content") do
     safe_join([cancel_btn," ", submit_btn])
    end
  end
end
