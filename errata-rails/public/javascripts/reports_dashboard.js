(function($) {

  $(function() {

    $('.nav-pills').find('a').on('click', function(e) {
      e.preventDefault();
      $(this).tab('show');
    });

  });

}(jQuery));