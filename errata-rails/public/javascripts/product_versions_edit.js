(function($) {

  $(function() {
    $('.modal').find('.btn-cancel-modal').on('click', function(event) {
      event.preventDefault();
      $(this).closest('.modal').modal('hide');
    });

  });

}(jQuery));