(function($) {

  function show_hide_impact_select() {
    var show = $('input[value=RHSA]').is(':checked') ||
               $('input[value=PdcRHSA]').is(':checked');

    $('.only-rhsa').toggleClass('selected-rhsa', show);
  }

  // Keep left area on the screen when window scrolls
  function fixed_nav() {
    window_scroll = $(this).scrollTop();
    if ( window_scroll > 170 ) {
      $('.eso-greybox .option').css({'position': 'fixed', 'top': '0'});
    } else {
      $('.eso-greybox .option').css({'position': 'unset'});
    }
  }

  function update_select_all_checkbox() {
    var pkg_check_box     = $('.pkg_check_box:not(.not_pkg_check_box)'),
        pkg_check_box_all = $('.pkg_check_box_all'),
        any_exist         = false,
        all_checked       = true;

    pkg_check_box.each(function(){
      any_exist   = true;
      all_checked = all_checked && this.checked;
      return all_checked;
    });

    // Only show the "package option" section on left panel if there are some
    // packages
    $('.package-option').toggle(any_exist);

    pkg_check_box_all.attr('checked', any_exist && all_checked);
  }

  function init_popovers() {
    // standard popover init (already done on page load, but also needed after
    // we dynamically create popovers)
    Eso.initPopovers();

    // This popover needs to be wider, arrange for a different class.
    $('a.component-missing-help.popover-test').on('mousedown', function() {
      // Trying hard here to avoid a visible "pop" as the style changes after rendered.
      // 'click' is too late, 'mousedown' is too early.
      // First DOM node inserted after mousedown is just right ...
      $(document).one('DOMNodeInserted', function(e) {
        $('.popover-inner').addClass('popover-xlong');
      });
    });
  }

  $(window).scroll(fixed_nav);

  $(function(){
    /* Sometimes when you reload the browser "remembers" the checkboxes' state. The bug
     * lists don't reflect that though. So here's a hack to clear all the checkboxes after reload.
     */
    $('.pkg_check_box').attr('checked',false);

    /* Similarly when the browser "remembers" the selected product or release it becomes out of
     * sync with the displayed bug lists. Here's a hack to adjust the drop downs on page load also.
     * It works because @product and @release are used when rendering this view.
     */
    $('#product_id').val($('#product_id').data('value'));
    $('#release_id').val($('#release_id').data('value'));

    show_hide_impact_select();

    $('#product_id').on('change', function() {
      $("#qu_for_product_spinner").show();
    });

    $('input[type=radio][name=type]').on('change', show_hide_impact_select);

    $('#packages_for_release_list').on('change', '#release_id', function() {
      $("#packages_for_release_spinner").show();
    });

    $('.packages_container').on('change', '.pkg_check_box_all', function(event) {
      var checked = event.target.checked;
      // checking one pkg_check_box_all checks them all
      $('.pkg_check_box_all').attr('checked', checked);
      $('.available-package .pkg_check_box').attr('checked', checked);
      $('.available-package .pkg_bug_list').toggle(checked);
    });

    $('.packages_container').on('change', '.pkg_list_keys .pkg_check_box', function(event) {
      update_select_all_checkbox();
      $('#' + $(this).data('id')).toggle();
      return false;
    });

    // These two event handlers are applicable when ineligible packages have not
    // yet been loaded (and will be loaded via AJAX).
    $('.packages_container').on('ajax:beforeSend', '#show_ineligible_pkg', function(event) {
      $('#reload_no_elide').show();
      $(event.target).closest('.unavailable-package').addClass('active');
    });

    $('.packages_container').on('ajax:error', '#show_ineligible_pkg', function(event) {
      $('#reload_no_elide').hide();
      $(event.target).closest('.unavailable-package').removeClass('active');
    });

    // Need to update checkboxes and popovers after new package list loaded; we
    // can't use the UJS event as the above handlers do, because the elements
    // are destroyed as part of processing the response.
    $(document).on('ajaxComplete', function() {
      init_popovers();
      update_select_all_checkbox();
    });

    // This event handler is applicable when ineligible packages are already
    // loaded; clicking should show/hide the package list and not load anything
    // more.
    $('.packages_container').on('click', '#show_ineligible_pkg[href="#"]', function(event) {
      var container = $(event.target).closest('.unavailable-package');
      container.toggleClass('active');
      event.preventDefault();
    });

    $('.packages_container').on('change', '.not_pkg_check_box', function() {
      this.checked=false;
      return false;
    });

    // update "Select all" once on load in case browser remembered a value for
    // some checkboxes.
    init_popovers();
    update_select_all_checkbox();
  });

}(jQuery));