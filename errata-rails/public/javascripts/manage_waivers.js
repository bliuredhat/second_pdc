(function ($) {

  window.et_toggle_rpmdiff_log = function(id) {
    var logdiv = $('.result_log[data-id="' + id + '"]');
    var expand = (logdiv.css('display') === 'none');
    logdiv.toggle();
    var icon = "ui-icon-carat-1-" + (expand ? 's' : 'e');
    $("#rpmdiff_log_icon_" + id).removeClass().addClass('ui-icon').addClass(icon);
  };

  window.et_rpmdiff_logs_visible = function(evt, show) {
    var table = $(evt.target).parents('table')[0];
    $('.result_log', table).each(function(){
      var el = $(this);
      var visible = (el.css('display') !== 'none');
      if (show != visible) {
        et_toggle_rpmdiff_log(el.data('id'));
      }
    });
  };

  window.et_waiver_checkbox_changed = function(evt) {
    var checkbox = evt.target,
      id = $(checkbox).data('id'),
      tr = $('tr.waive_text[data-id="' + id + '"]');
    tr.toggle(checkbox.checked);
  };

  window.et_waiver_checkboxes_enabled = function(evt, show) {
    var table = $(evt.target).parents('table')[0];
    $('input[type="checkbox"].request_waiver', table).each(function() {
      this.checked = show;
      et_waiver_checkbox_changed({target:this});
    });
  };

  window.et_waiver_ack_button_clicked = function(evt) {
    var btn = $(evt.target),
      enabling = !btn.hasClass('active'),
      id = btn.data('id'),
      value = btn.data('value'),
      ack_text = $('tr.ack_text[data-id="' + id + '"]');

    if (enabling) {
      // We want zero or one of (approve,reject) to be active at any time, and we want to
      // support deactivating the buttons on click (which is not supported by radio buttons).
      // To do this, we used buttons-checkbox for the buttons, and we trigger the radio-like
      // behavior here: if any option is activated, deactivate all other options first.
      btn.closest('.btn-group').find('.active').removeClass('active');

      $('#ack_' + id).val(value);

      $('.approve-only', ack_text).toggle(value == 'approve');
      $('.reject-only', ack_text) .toggle(value == 'reject');
    } else {
      $('#ack_' + id).val('');
    }

    ack_text.toggle(enabling);
  };

  window.et_waiver_ack_buttons_init = function() {
    // after the page loads, if the browser filled in hidden input values,
    // make sure the buttons match
    $('input.ack').each(function() {
      var el = $(this),
        id = el.data('id'),
        val = el.val(),
        button = $('button[data-id="' + id + '"][data-value="' + val + '"]');

      button.click();
      // bootstrap click handler seems not active yet (presumably it is onload),
      // so adjust the class manually
      button.addClass('active');
    });
  };

  window.et_waiver_ack_buttons_set = function(evt, val) {
    var table = $(evt.target).parents('table')[0];
    if (val === null) {
      $('button.ack.active', table).click();
    } else {
      $('button.ack:not(.active)[data-value="' + val + '"]', table).click();
    }
  };

  $(function() {
    $('#clear-waive-text').on('click', function(event) {
      event.preventDefault();
      $('#waive_text_textarea').val('');
    });
    $('#revert-waive-text').on('click', function(event) {
      event.preventDefault();
      $('#waive_text_textarea').val($(this).data('placeholder'));
    });
  });

}(jQuery));