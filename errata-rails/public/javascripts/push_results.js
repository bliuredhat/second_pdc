(function($) {

  function refreshPushLog() {
    $.ajax({
      url: '/rhn/check_push_status/' + $('#push_log').data('id'),
      data: 'last_update=' + $('#push_log').data('lastupdate'),
      dataType: 'script',
      complete: function() {
        setTimeout(refreshPushLog, 30000);
      }
    });
  }

  $(function() {
    $('#toggle-job-states').on('click', function(event) {
      event.preventDefault();
      $('#help').toggle(200);
    });

    if ($('#push_log').data('checkupdate')) {
      setTimeout(refreshPushLog, 30000);
    }
  });

}(jQuery));