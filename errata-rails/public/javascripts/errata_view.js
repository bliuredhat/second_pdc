(function($){

  // There are  some rjs helpers that do this same thing,
  // should maybe get rid of them??
  window.hide_all_comment_groups = function(event) {
    if (event) {
      event.preventDefault();
    }
    $('.state_comments').hide();
    $('.show_hide_link').addClass('currently_hiding');
  };

  window.show_all_comment_groups = function(event) {
    if (event) {
      event.preventDefault();
    }
    $('.state_comments').show();
    $('.show_hide_link').removeClass('currently_hiding');
  };

  window.ensure_current_group_open = function() {
    $('.current-state-group').find('.state_comments').show();
    $('.current-state-group').find('.show_hide_link').removeClass('currently_hiding');
  };

  window.hide_most_comment_groups = function(event) {
    if (event) {
      event.preventDefault();
    }
    hide_all_comment_groups();
    ensure_current_group_open();
  };

  window.add_comment_click = function(event) {
    event.preventDefault();
    ensure_current_group_open();
    $('#add_comment_link').hide();
    $('#state_comment_form').show();
    // So it scrolls into view when it is way down the bottom...
    $('#state_comment_field').focus();
  };

  // The user preference could be done server side but then we'd still need
  // to do some javascript to detect the hash comment anchor. Might as well
  // do it all here. (Server renders all comments expanded, this method decides
  // what to do from there...)
  window.hide_comments_if_no_anchor = function() {
    // Won't hide comments if there is a comment hash anchor in the url
    // The comment anchors start with a c, eg #c22
    var has_comment_anchor = (window.location.hash && window.location.hash.match(/^#c[0-9]/));

    // Detect the users's preference for comment collapsing..
    var comments_expand_all = $('#state_group_list').hasClass('comment_collapse_opt_expand');
    var comments_collapse_all = $('#state_group_list').hasClass('comment_collapse_opt_collapse');

    // Hide comment groups except the current one.
    if (has_comment_anchor || comments_expand_all) {
      // Do nothing, ie leave them all open
    }
    else if (comments_collapse_all) {
      // Hide them all
      hide_all_comment_groups();
    }
    else {
      // Default is to expand only the current group.
      hide_most_comment_groups();
    }
  };

  window.toggle_section = function(elem) {
    var $clicked = $(elem);
    $clicked.toggleClass('down');
    var container = $clicked.closest('.section_container');
    container.toggleClass('collapsed');
    container.find('.btn-group').toggle();
    container.find('.section_content_inner').toggle();
    container.find('.section_content_placeholder').toggle();
  };

  window.hide_approval_progress_if_user_pref = function() {
    // Will be one only if user_pref(:workflow_hide_fully) is set...
    $('.workflow_hide_fully').each(function(){ toggle_section(this); });
  };

  // Needs to be moved?
  window.open_modal_and_fix_height = function(selector) {
    $(selector).modal({ dynamic: true });
  };

  window.prevent_comment_truncate = function() {
    $('#add_comment_btn').click(function(e){
      var comment = $('#state_comment_field').val();
      var tooLong = comment.length > 4000;
      var tooShort = comment.trim().length === 0;

      if (tooLong) {
        alert("Comment is longer than the 4000 chararacter limit.\nPlease shorten it or cut it up into multiple comments.");
      } else if (tooShort) {
        alert("Can't submit comment, since it appears to be empty.");
      }

      if (tooLong || tooShort) {
        // Don't submit form
        e.preventDefault();
        return false;
      }
      else {
        // All good, submit form
        return true;
      }
    });
  };

  window.open_related_advisories = function(selector, remote_url) {
    $(selector).modal({ dynamic: true }).parent().addClass('modal-lg').end()
      .load(remote_url, function() {
        $('table.tablesorter').tablesorter({
          widgets: ["zebra"],
          widgetOptions : { zebra : [ "bz_even", "bz_odd" ] }
        });
      });
  };

  function full_brief_toggle(event) {
    event.preventDefault();
    $('.info_full_brief_details').toggle();
  }

  function initBindings() {
    $('.workflow-toggle-btn').on('click', function(event) {
      event.preventDefault();
      $($(this).closest('.btn-group').data('hidden-content') + ',.workflow-toggle-btn').toggle();
    });

    $('.btn-related-advisory').on('click', function(event) {
      event.preventDefault();
      open_related_advisories('#related_advisories_by_package_modal',$(this).data('remote-url'));
    });

    $('.open-modal').on('click', function(event) {
      $("body").addClass("loading");
      event.preventDefault();
      var modal = $('#' + $(this).data('modal-id'));
      modal.load(modal.data('remote-url'), function(response, status, xhr) {
          if (status !== 'success') {
            window.displayFlashNotice('error', "Error: " + xhr.status + " " + xhr.statusText);
          }
          else {
            modal.modal({ dynamic: true }).parent().addClass('modal-lg');
            Eso.initAll(modal);
          }
        });
    });

    $('.eso-tab-content').on('click', '.btn-cancel-modal', function(event) {
      event.preventDefault();
      $(this).closest('.modal').modal('hide');
    });

    $('.btn-add-comment').on('click', add_comment_click);

    $('#btn-group-comment').find('.btn-collapse-noncurrent').on('click', hide_most_comment_groups);

    $('#btn-group-comment').find('.btn-collapse-all').on('click', hide_all_comment_groups);

    $('#btn-group-comment').find('.btn-expand-all').on('click', show_all_comment_groups);

    $('.details-toggle').on('click', full_brief_toggle);

    $('#info-btn-group').find('[data-modalid]').add('#btn-change-state').on('click', function(event) {
      event.preventDefault();
      open_modal_and_fix_height('#' + $(this).data('modalid'));
    });

    $('#btn-cancel-add-comment').on('click', function(event) {
      event.preventDefault();
      $("#add_comment_link").show();
      $("#state_comment_field").val("");
      $("#counter-state_comment_field").html("0/4000");
      toggle_div('state_comment_form');
    });

    $('.btn-toggle-comment').on('click', function(event) {
      event.preventDefault();
      toggle_div($(this).data('target'), this.id);
    });
  }

  $(document).ready(function() {
    hide_comments_if_no_anchor();
    hide_approval_progress_if_user_pref();
    prevent_comment_truncate();
    if ($('#state_comment_field').length > 0) makeItCount('state_comment_field', 4000);
    initBindings();
  });


})(jQuery);
