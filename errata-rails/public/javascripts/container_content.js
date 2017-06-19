(function($) {

  // Used for Show Bugs / Hide Bugs button
  $(document).on("click", '.toggle-section', function(event) {
    event.preventDefault();
    var old_text = $(this).text();
    $(this).text($(this).data('toggled-text'));
    $(this).data('toggled-text', old_text);
    $($(this).data('selector')).toggleClass('hidden');
  });

  // Highlight all instances of same errata
  $(document).on('mouseenter', '.errata_list_keys', function() {
    $('*[data-errata="' + $(this).data('errata') + '"]').addClass("highlight");
  });
  $(document).on('mouseleave', '.errata_list_keys', function() {
    $('*[data-errata="' + $(this).data('errata') + '"]').removeClass("highlight");
  });

  // Expand/Collapse All button
  $(document).on("click", '.collapse-expand-all', function(event) {
    event.preventDefault();
    if ($(this).text() == 'Collapse All') {
      $('.section_container').addClass('section_container_collapsed');
      $(this).text('Expand All');
    } else {
      $('.section_container').removeClass('section_container_collapsed');
      $(this).text('Collapse All');
    }
  });

  // Expand/collapse chevron
  $(document).on("click", '.toggle-view-section', function(event) {
    event.preventDefault();
    $(this).closest('.section_container').toggleClass('section_container_collapsed');
  });

  // Load lightblue content through XHR
  $(document).ready(function() {
    var cc = $('#container_content');
    $("body").addClass("loading");
    cc.load(cc.data('remote-url'), function(response, status, xhr) {
      init_popovers();
      if (status !== 'success') {
        displayFlashNotice('error', "Failed to retrieve data from Lightblue (error: " + xhr.status + " " + xhr.statusText + ")");
      }
      var notice = xhr.getResponseHeader('X-ET-Alert');
      if (notice) {
        displayFlashNotice('alert', notice);
      }
    });
  });

  function init_popovers() {
    // standard popover init (already done on page load, but
    // also needed after we dynamically create popovers)
    Eso.initPopovers();

    // Make this popover wider, and scrollable if necessary
    $('.scrollable-popover').on('mousedown', function() {
      $(document).one('DOMNodeInserted', function(e) {
        $('.popover-inner').addClass('popover-xlong');
        $('.popover-content').addClass('popover-scroll');
      });
    });
  }

}(jQuery));
