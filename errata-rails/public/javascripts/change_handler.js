(function($) {

  $(function() {
    $('.submit-form-on-change').on('change', function() {
      this.form.submit();
    });
  });

}(jQuery));