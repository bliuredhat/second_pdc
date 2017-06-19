(function($) {

  $(function() {

    // Show alert if input element has property set
    $('input.change-alert').change(function() {
      if ($(this).prop($(this).data('change-alert-property')) ===
          $(this).data('change-alert-value')) {
        $('#'+$(this).data('change-alert-modal')).modal()
      }
    });

    // Enable modal cancel button
    $('.modal').find('.btn-cancel-modal').on('click', function(event) {
      event.preventDefault();
      $(this).closest('.modal').modal('hide');
    });

  });

}(jQuery));
