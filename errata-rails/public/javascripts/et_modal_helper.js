(function($) {
  $(function() {
    $("#et_modal")
      .modal()
      .modal("hide")
      .on('hidden', function () {
        $(this).children(".modal-header").children("h3").text("Loading...");
        $(this).children(".modal-body").children(".body-content").empty();
        $(this).children(".modal-footer").children(".footer-content").empty();
      });

    $(".toggle-modal").on("click", function() {
      $("#et_modal").modal("toggle");
    });
  });
}(jQuery));