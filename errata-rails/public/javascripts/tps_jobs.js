(function($) {

  function open_repo_list_panel(event) {
    event.preventDefault();
    $.ajax({
      "url": $(this).data('remote-url'),
      "datatype": "script",
      "type": "get",
      "data": {},
      "beforeSend": function(xhr) {
        $("#wait_spinner").show();
        return true;
      },
      "complete": function(xhr, text_status) {
        $("#wait_spinner").hide();
      },
      "error": function(jqXHR, textStatus, errorThrown){
        alert(et_xhr_error_to_string(jqXHR));
      },
    });
  }

  $(function() {
    $('#btn-open-repolist').on('click', open_repo_list_panel);
    $('#repo_list_div').on('click', '#btn-close-repolist', function(event) {
      event.preventDefault();
      $('#repo_list_div').slideToggle();
    });

    $('.tps-schedule-job').click(function() {
      $(this).closest("td").find(".wait-spinner").show();
    });

    // Hack the popover to add a css class to increase the width
    // due to the limitation of boostrap 2.0 (no event listener)
    $('.popover-test').on('click', longer_popover);
  });

  function longer_popover(evt) {
    $('.tps_error').closest('.popover-inner').addClass("popover-long");
    evt.preventDefault();
  }

  window.on_tps_job_scheduled = function(action, notice, job_id, state_link, started_time, tps_stream, status_icon) {
    if (notice) {
      window.displayFlashNotice("notice", notice);
    }
    var row = $("#tps_job_" + job_id);
    if (row && action.match(/^(Scheduling|Rescheduling)$/)) {
      row.find(".tps-state").html(state_link);
      row.find(".tps-started").html('<strong>' + started_time +'</strong>');
      row.find(".tps-host").html('');
      row.find(".tps-finished").html('');
      row.find(".tps-link").html('');
      row.find(".tps-stream").html(tps_stream);
      row.find(".tps-valid").html(status_icon);
      // Reinitialize the boostrap popover
      row.find(".tps-valid .popover-test").popover().on('click', longer_popover);
      row.find(".wait-spinner").hide();
      if (action == "Scheduling") {
        row.find(".tps-schedule-job").html("Reschedule");
      }
    } else if (row) {
      row.remove();
    }
  }

}(jQuery));
