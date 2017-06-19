(function($) {

  $(function() {
    $(document).on('click', '.open-help-modal', function(event) {
      event.preventDefault();
      $(this).closest('.help_modal_container').find('.modal').modal({ dynamic: true });
    });
  });

}(jQuery));