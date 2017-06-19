(function($) {

  $(function() {
    $(document).on('click', '.btn-add, .btn-edit, .btn-cancel', function(event) {
      event.preventDefault();
      form_toggle(this);
    });
  });

}(jQuery));
