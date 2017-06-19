(function($) {

  $(function() {
    $('#btn-change-bug').on('click', function(event) {
      event.preventDefault();
      $('#change_bug_modal').modal({ dynamic: true });
    });

    $('#change_bug_modal').find('.btn-cancel-modal').on('click', function(event) {
      event.preventDefault();
      $(this).closest('.modal').modal('hide');
    });
  });

}(jQuery));