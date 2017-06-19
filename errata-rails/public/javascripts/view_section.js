(function($) {

  $(function() {
    $('.toggle-view-section').on('click', function(event) {
      event.preventDefault();
      $(this).closest('.section_container').toggleClass('section_container_collapsed');
    });
  });

}(jQuery));