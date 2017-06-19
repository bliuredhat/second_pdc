(function($){

/*
  Caches job tracker promises so that multiple callers can get a handle
  to the same promise.
*/
var job_tracker_cache = {};

/*
  Given a job tracker object as produced by the API, returns an object
  with appropriate progress values.
*/
function parse_tracker(tracker) {
  var state = tracker.state,
    pending_jobs = tracker.pending_jobs,
    completed = (tracker.total_job_count - pending_jobs.length),
    out = {
      max: tracker.total_job_count*3,
      value: null,
      progress_text: null,
      job_errors: {},
    };

  if (state === 'FINISHED') {
    out.value = out.max;
  } else {
    // completed jobs are worth three points ...
    out.value = completed*3;

    jQuery.map(pending_jobs, function(job){
      if (job.state === 'RUNNING') {
        // running jobs are worth two points...
        out.value += 2;
        // and the name of the job is displayed in the progress
        // bar. (If we have more than one delayed job worker, it's
        // arbitrary which job is displayed)
        out.progress_text = job.name + "...";
      }
      if (job.state === 'FAILED') {
        // failed jobs are worth a single point
        ++out.value;
        // prepare some error text which may be displayed to the user
        out.job_errors[job.name + ' failed:'] = job.error||'(unknown error)';
      }
      // other jobs are worth nothing
    });
  }

  return out;
}

/*
  Returns the time (in milliseconds) until we should poll this tracker
  again.
*/
function next_poll(tracker) {
  var out;

  if (tracker.state === 'FINISHED' || tracker.state === 'FAILED') {
    return null;
  }

  var times = jQuery.map(tracker.pending_jobs, function(job) {
    if (job.state === 'RUNNING') {
      // A job is running right now.  Many jobs are very fast, so
      // update again soon
      return 2000;
    }

    // next poll around the time the job is expected to start
    return (new Date(job.run_at)).getTime() - Date.now() + 500;
  });

  out = Math.min.apply(undefined, times);
  if (out < 2000) {
    out = 2000;
  } else if (out > 60000) {
    out = 60000;
  }
  return out;
}

function append_error_panel(elem, error, header) {
  var panel = $('<div>').addClass('panel').addClass('panel-danger'),
    heading = $('<div>').addClass('panel-heading'),
    body = $('<div>').addClass('panel-body');

  heading.text(header);
  body.append($('<pre>').text(error));

  panel.append(heading).append(body);
  elem.append(panel);
}

function update_bar($el, args) {
  var bar = $el.find('.bar'),
    holder = $el.find('.progress'),
    text_holder = $el.find('.progress_text');

  if (args.progress) {
    bar.width(args.progress + "%");
  }

  text_holder.empty();
  if (args.text) {
    text_holder.append($('<p>').text(args.text));
  }

  // Only display the errors if the tracker is overall considered to
  // have failed.  We could easily display them while in progress, but
  // I think that may just be annoying at the moment since there's no
  // way to cancel the operation.  Reconsider when we have a
  // Stop/Cancel feature for job trackers.
  if (args.is_error) {
    jQuery.map(args.errors, append_error_panel.bind(null, text_holder));
  }

  // Adjust styling according to what's happening.
  // active/progress-danger are predefined by bootstrap.
  // We apply them to the text_holder as well so the text
  // style can be adjusted, e.g. when an error occurs.
  if (args.is_active) {
    holder.addClass('active');
    text_holder.addClass('active');
  } else {
    holder.removeClass('active');
    text_holder.removeClass('active');
  }
  if (args.is_error) {
    holder.addClass('progress-danger');
    text_holder.addClass('progress-danger');
  } else {
    holder.removeClass('progress-danger');
    text_holder.removeClass('progress-danger');
  }

  $el.show();
}

function update_bar_from_tracker($el, tracker) {
  var p = parse_tracker(tracker);

  // texts for failed, completed, waiting cases can be provided on
  // attributes on any parent element of the progress bar (or leave it
  // blank to use reasonable defaults)
  function get_text(key) {
    return $el.closest("[" + key + "]").attr(key);
  }

  if (!p.progress_text) {
    if (tracker.state === 'FAILED') {
      p.progress_text = get_text('job-tracker-failed-text') || 'Sorry, the operation failed.';
    } else if (p.value === p.max) {
      p.progress_text = [get_text('job-tracker-completed-text') || 'Done!'];
    } else {
      p.progress_text = [get_text('job-tracker-waiting-text') || "Please wait..."];
    }
  }

  update_bar($el, {
    progress: p.value/p.max*100.0,
    text: p.progress_text,
    errors: p.job_errors,
    is_error: (tracker.state === 'FAILED'),
    is_active: (tracker.state === 'RUNNING')
  });
}

/*
  Returns a promise for the job tracker with the given ID.

  The tracker is polled until it completes.  The semantics of the
  promise are:

  If the tracker completes successfully, resolve with (tracker).

  If the tracker fails, reject with (tracker).

  If polling of the tracker fails, reject with (null, error).

  When the tracker updates, notify with (tracker).
*/
function job_tracker_promise(id) {
  var tracker_url = '/api/v1/job_trackers/' + id,
    cached = job_tracker_cache[id],
    deferred,
    max_attempts = 5,
    poll;

  // If a request is made for a job tracker we're already polling,
  // return it from cache, don't make another one.
  if (cached && cached.state() === 'pending') {
    return cached.promise();
  } else {
    deferred = jQuery.Deferred();
    job_tracker_cache[id] = deferred;
  }

  function poll_max() {
    poll(max_attempts);
  }

  function on_success(data) {
    var tracker = data.job_tracker,
      state = tracker.state,
      timeout = next_poll(tracker);

    if (state === 'FINISHED') {
      deferred.resolve(tracker);
    } else if (state === 'FAILED') {
      deferred.reject(tracker);
    } else {
      deferred.notify(tracker);
    }

    if (timeout) {
      window.setTimeout(poll_max, timeout);
    }
  }

  function on_error_for_attempts(attempts) {
    return function(jqXHR) {
      var errorString = et_xhr_error_to_string(jqXHR);

      if (attempts > 0) {
        window.setTimeout(poll.bind(undefined, attempts-1), 5000);
      } else {
        deferred.reject(null, errorString);
      }
    };
  }

  poll = function(attempts) {
    jQuery.ajax(tracker_url, {
      dataType: "json",
      success: on_success,
      error: on_error_for_attempts(attempts),
    });
  };

  window.setTimeout(poll_max, 2000);

  return deferred.promise();
}

/*
  Set up a Bootstrap progress bar element to monitor the progress of a
  JobTracker.

  The element must contain the ID of a job tracker in 'job-tracker'
  data.

  If the status of the job tracker is already known, it may be passed
  as the "tracker" argument.  Otherwise the progress bar is not shown
  until the first poll of the tracker completes.
*/
function job_tracker_progressbar($el, tracker) {
  var tracker_id = $el.data('job-tracker'),
    promise;

  if (!tracker_id) {
    return;
  }

  promise = job_tracker_promise(tracker_id);

  // bail out if already initialized
  if ($el.data('job-tracker-promise') === promise) {
    return;
  }
  $el.data('job-tracker-promise', promise);

  function on_progress(tracker) {
    update_bar_from_tracker($el, tracker);
  }

  function on_failure(tracker, error) {
    if (tracker) {
      on_progress(tracker);
    } else {
      update_bar($el, {
        text: "An error occurred while monitoring the progress of this task. Please refresh the page and try again.",
        is_error: true,
      });
    }
  }

  // We can be called either with or without a tracker.  If called
  // with a tracker, it's immediately used to initialize the progress
  // bar state.
  if (tracker) {
    on_progress(tracker);
  }

  promise.progress(on_progress).done(on_progress).fail(on_failure);
}

/*
  Set up a form to add a pre-submit action whose progress is monitored
  using a job tracker.

  This function can be used to increase the responsiveness of a form
  which executes a slow action.  It performs some action
  asynchronously and provides a progress bar to monitor its status.

  To use it, follow these steps:

  - Start with a normal form tag with a valid "action"

  - Add a "job-tracker-action" attribute.

    This should be the URL of an action which, when POSTed to using
    the form's content, possibly creates a new job tracker.

    The action should return status 202 along with the job tracker if
    any background jobs were queued; status 200 otherwise (in which
    case the form immediately submits to the "action" as normal).

    The action should perform whatever (possibly slow) preparations
    are required in order to complete the form's primary action,
    e.g. fetching and caching data from remote systems.

  - Optionally add job-tracker-{waiting,completed,failed}-text
    attributes.

    These attributes, if set, can be used to customize the text
    displayed on the progress bar when the job tracker is waiting (not
    running any jobs), completed, or failed.

  - Ensure the form contains a wait spinner

  - Ensure the form contains an .et-ajax-form-error (or otherwise
    handles an error to the pre-submit action).

  - Ensure the form contains a Bootstrap-compatible progress bar
    component within a .job_tracker_progressbar (or just include
    _job_tracker_progress.html.erb partial).

  This function is automatically activated on any form with a
  job-tracker-action when the DOM is ready, so it's usually
  unnecessary to call it explicitly.
*/
function job_tracker_form($el) {
  var form = $el.closest('form[job-tracker-action]'),
    inputs = form.find(':input'),
    url = form.attr('job-tracker-action'),
    spinner = form.find('.wait-spinner'),
    progressbar = form.find('.job_tracker_progressbar'),
    jt_input = form.find('input#job_tracker_id'),
    button = form.find('input[type="submit"]'),
    allow_submit = false;

  if (!url) {
    return;
  }

  function enable_inputs() {
    inputs.prop('readonly', false);
    button.prop('disabled', false);
  }

  function disable_inputs() {
    inputs.prop('readonly', true);
    button.prop('disabled', true);
  }

  function do_real_submit() {
    try {
      allow_submit = true;
      form.submit();
    } finally {
      allow_submit = false;
    }

    // From this point, if the user refreshes or uses the back button,
    // don't re-use the already completed job tracker
    jt_input.val(null);
  }

  function init_tracker(jt_id, tracker) {
    var promise = job_tracker_promise(jt_id);

    // Store the ID in a hidden field; this allows to find the tracker
    // again over a refresh (if the browser remembers form contents)
    jt_input.val(jt_id);

    progressbar.data('job-tracker', jt_id);

    if (tracker) {
      // already have a job tracker
      job_tracker_progressbar(progressbar, tracker);
    } else {
      // don't have a tracker yet, so show the spinner
      // until the first fetch completes
      spinner.show();
      job_tracker_progressbar(progressbar);
    }

    promise.progress(function(){
      spinner.hide();
    }).fail(function(){
      enable_inputs();
      // If the tracker failed, refreshing the page should let the
      // user try the operation again and not just reload the same
      // failed tracker
      jt_input.val(null);
    }).always(function(){
      spinner.hide();
    }).done(do_real_submit);
  }

  function show_job_tracker_error(string) {
    form.find('.et-ajax-form-error').text(string);
  }

  function hide_job_tracker_error() {
    form.find('.et-ajax-form-error').text('');
  }

  function on_presubmit_success(data, textStatus, jqXHR) {
    hide_job_tracker_error();
    if (jqXHR.status === 202) {
      // Accepted and being processed asynchronously, use the tracker
      init_tracker(data.job_tracker.id, data.job_tracker);
    } else {
      // any other successful code implies presubmit already done,
      // so immediately proceed
      do_real_submit();
    }
  }

  function on_form_submit(event) {
    var data = form.serialize();

    if (allow_submit) {
      // Don't do anything, allow the "real" submit.
      return;
    }

    event.preventDefault();
    disable_inputs();

    // We might already have a progress bar from an earlier attempt.
    // If so, get rid of it until we have a new job tracker
    progressbar.hide();
    spinner.show();

    $.ajax(url, {
      data: data,
      processData: false,
      contentType: 'application/x-www-form-urlencoded; charset=UTF-8',
      type: 'POST',
      success: on_presubmit_success,
      error: function(jqXHR) {
        var error_string = et_xhr_error_to_string(jqXHR);
        spinner.hide();
        enable_inputs();
        show_job_tracker_error(error_string);
      }
    });
  }

  // hijack form submission to use the job tracker action
  form.on('submit', on_form_submit);
  var id = jt_input.val();
  if (id) {
    // When the page is loading, if there's already a job tracker id,
    // show the progress immediately.
    disable_inputs();
    init_tracker(Number(id));
  } else {
    enable_inputs();
  }
}

// Automatically set up appropriately declared elements
$(function(){
  $(".job_tracker_progressbar").each(function(idx,el){
    job_tracker_progressbar($(el));
  });
  $("form[job-tracker-action]").each(function(idx,el){
    job_tracker_form($(el));
  });
});

// exports
window.et_job_tracker_progressbar = job_tracker_progressbar;
window.et_job_tracker_promise = job_tracker_promise;
window.et_job_tracker_form = job_tracker_form;

})(jQuery);
