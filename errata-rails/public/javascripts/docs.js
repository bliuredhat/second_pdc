(function($) {

  $(function() {
    $('#btn-change-reviewer').on('click', function(event) {
      event.preventDefault();
      $('#change_docs_reviewer_modal').modal({ dynamic: true });
    });

    $('#change_docs_reviewer_modal').find('.btn-cancel-modal').on('click', function(event) {
      event.preventDefault();
      $(this).closest('.modal').modal('hide');
    });

    $('.btn-select-all').on('click', function(event) {
      event.preventDefault();
      $('.draft-release-notes').select();
    });

  });

}(jQuery));