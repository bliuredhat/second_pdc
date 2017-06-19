(function($) {

  $(function(){
    $('#nitrate_test_plans').on('click', '.btn-remove-plan', function() {
      return confirm('Are you sure you want to remove test plan ' + $(this).data('id') + '?');
    });
  });

}(jQuery));
