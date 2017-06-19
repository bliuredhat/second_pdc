module PushHelper
  NOCHANNEL_HELP = <<-END_STR.strip_heredoc
    This push uploads files, but doesn't subscribe them to channels/repos,
    thus doesn't deliver the update to customers.
  END_STR

  TASKS_ONLY_HELP = <<-END_STR.strip_heredoc
    This push runs pre/post-push tasks only and does not have a pub task.
  END_STR

  METADATA_ONLY_HELP = <<-END_STR.strip_heredoc
    This push uploads metadata (e.g. advisory text) but does not upload files.
  END_STR

  def push_tasks(push_job, form)
    res = ['<div style="padding:2px;margin:2px;">']
    res.concat(add_tasks(push_job.valid_pre_push_tasks, form, :pre_tasks))
    res.concat(add_tasks(push_job.valid_post_push_tasks, form, :post_tasks))
    res << "</div>"
    res.join("\n").html_safe
  end

  def render_push_target(policy)
    result = [tag('p', {:class => 'checkbox'}, true)]
    #
    # if this target is not published, invert the result which means
    # we'll have to set the checkbox to checked.
    #
    result << hidden_field_tag(:stage, 1) if @stage_only
    result << check_box_tag(policy.push_type, '1', !policy.has_pushed?, :onchange => 'toggle_options(this);', :class => 'push_check_box')
    result << label_tag(policy.push_type, "<b>Do #{policy.push_type_name} push</b>".html_safe, :for => policy.push_type)
    result << last_push_link(policy.job_klass, @errata) if policy.has_pushed?

    result << tag('p')
    result.join.html_safe
  end

  def add_tasks(tasks, form, type)
    res = []
    form.fields_for type do |task_fields|
      tasks.each_pair do |name, task|
        next if task[:mandatory]
        res << field_render_helper(task_fields, name, task)
      end
    end
    res
  end

  def push_options(push_job, form)
    res = ['<div style="padding-bottom:4px;margin-bottom:4px;">']
    form.fields_for :options do |option_fields|
      push_job.valid_pub_options.each_pair do |name, opt|
        next if opt[:hidden]
        res << field_render_helper(option_fields, name, opt)
      end
    end
    res << "</div>"
    res.join("\n").html_safe
  end

  def field_render_helper(f, name, options)
    checked = options[:default] ? true : false
    description = f.label(name, options[:description])
    ("<div class='checkbox'><label>" + f.check_box(name, :checked => checked) + description + "</label></div>").html_safe
  end

  # Render summarized info regarding the most important options on the push
  # job. (This is more high-level than the raw pub options).
  def push_job_options_for_display(push_job)
    out = []

    add_label = lambda do |content, help|
      out << content_tag(:span, content, :class => 'label label-info',
                         :title => help)
    end

    if push_job.is_nochannel?
      add_label['nochannel', NOCHANNEL_HELP]
    end

    if push_job.skip_pub_task_and_post_process_only?
      add_label['tasks-only', TASKS_ONLY_HELP]
    end

    options = push_job.pub_options
    if options['push_metadata'] && !options['push_files']
      add_label['metadata-only', METADATA_ONLY_HELP]
    end

    if out.empty?
      out << '-'
    end

    safe_join(out, ' ')
  end
end
