;(function($){

window.FF = window.FilterForm = {
  // Will store a filter_id here..
  remember_filter_id: '',

  // Update the filter dropdown select
  // Because of chosen.js, this is a bit trickier than normal..
  // Return the original value (since it's useful for remembering
  // the id to restore it later..)
  set_selected_filter: function(filter_id) {
    $('#filter_select')
      .val(filter_id)            // doesn't trigger change event..
      .trigger("liszt:updated"); // make chosen refresh
  },

  // Set the filter select to nothing, ie 'Unsaved Filter'
  clear_selected_filter: function() {
    this.set_selected_filter('');
  },

  currently_selected_filter_id: function() {
    return $('#filter_select').val();
  },

  remember_selected_filter: function() {
    this.remember_filter_id = this.currently_selected_filter_id();
  },

  // If we remembered a selected filter earlier, restore it to the filter select
  restore_selected_filter: function() {
    // Only do it if we saved a filter id previously
    if (this.remember_filter_id !== '') {
      this.set_selected_filter(this.remember_filter_id);
      this.remember_filter_id = '';
    }
  },

  remember_and_clear_selected_filter: function() {
    this.remember_selected_filter();
    this.clear_selected_filter();
  },

  // Look in the select. (Hacky)
  filter_id_is_system_filter: function(filter_id) {
    return ($('#system_filters_optgroup option[value='+filter_id+']').length > 0);
  },

  current_filter_is_system_filter: function() {
    return this.filter_id_is_system_filter(this.currently_selected_filter_id());
  },

  // Currenty we only do this when about to reload, so don't need a please_wait_off method..
  // (which we would need if we ever make the filter loading more ajaxy)
  please_wait: function() {
    // actually it's not disabled, but let's pretend it is..
    $('.filter_select_div').find('.chzn-single').addClass('disabled');
    $('.filter_buttons_div').find('a').attr('disabled', true);
    $('.please_wait_div').show();
  },

  // Opens the filter modal
  open_filter_options: function() {
    // modal_position_fix is my hack to move the dialog into
    // view if it opens partly off screen in a small browser window
    $('#filter_form').modal({ dynamic: true }).parent().addClass('modal-lg');
  },

  // Opens the filter modal in 'Edit' mode.
  // Means user is editing an existing filter.
  open_for_edit: function() {
    if (this.current_filter_is_system_filter()) {
      $('#delete_submit_btn, #update_submit_btn').hide();
    }
    else {
      $('#delete_submit_btn, #update_submit_btn').show();
    }
    $('#filter_form').addClass('edit_mode').removeClass('create_mode');
    this.open_filter_options();
  },

  // Opens the filter modal in 'Create' mode.
  // Means user is editing an unsaved filter.
  open_for_create: function() {
    $('#filter_form').addClass('create_mode').removeClass('edit_mode');
    this.open_filter_options();
    this.remember_and_clear_selected_filter();
  },

  // Reload helper
  js_reload: function() {
    this.please_wait();
    window.location.reload();
  },

  // Load a filter (seems a bit inelegant, but go with it for now)
  js_load_filter: function(filter_id) {
    this.please_wait();
    window.location = '/filter/' + filter_id;
  },

  // Indicate to the server that we want to update.
  do_post: function() {
    $('#filter_form_form').attr('method','POST');
  },

  // See if the name user entered is okay to use
  // (Beware multiple return statements)
  // Returns the id if a dupe is found..
  check_dupe_filter_name: function(new_name) {
    var existing_id = '';
    $('#user_filters_optgroup').find('option').each(function(){
      if (this.text === new_name) {
        existing_id = this.value;
      }
    });
    return existing_id;
  },


  // (In these handler methods 'this' means the element clicked).
  event_handlers: {

    // When the user changes the filter select drop down
    changed_filter_select: function() {
      var selected = this.value;
      if (selected === '') {
        // If user chooses 'Unsaved Filter' open up the filter form.
        FF.open_for_create();
      }
      else {
        // If user chooses a filter, load it immediately
        FF.js_load_filter(selected);
      }
    },

    // The default when user presses enter is the delete submit button,
    // so let's deal with that here..
    catch_enter_on_new_filter: function(e) {
      if (e.which === 13) {
        // Enter key pressed
        // Supress default submit
        e.preventDefault();

        // Pretend the user clicked save...
        $('#save_submit_btn').click();
      }
    },

    // Also need to catch it for synopsis text entry
    catch_enter_on_synopsis_text: function(e) {
      if (e.which === 13) {
        // Enter key pressed
        // Supress default submit
        e.preventDefault();

        // Pretend the user clicked apply...
        $('#apply_submit_btn').click();
      }
    },

    //
    filter_btn_refresh: function() {
      if (!$(this).attr('disabled')) {
        // Might be nicer to submit the form here. Not sure.
        FF.js_reload();
      }
      return false;
    },

    //
    filter_btn_modify: function() {
      if (!$(this).attr('disabled')) {
        if (FF.currently_selected_filter_id() === '') {
          // If user is not currently looking at a saved filter, then
          // clicking 'Modify' acts as though you clicked 'New'
          FF.open_for_create();
        }
        else {
          FF.open_for_edit();
        }
      }
      return false;
    },

    //
    filter_btn_new: function() {
      if (!$(this).attr('disabled')) {
        FF.open_for_create();
      }
      return false;
    },

    // Close the filter modal. Restores original selected filter if appropriate.
    close_modal: function() {
      FF.restore_selected_filter();
      $('#filter_form').modal('hide');
      return false;
    },

    apply_button_click: function() {
      // Clear this so the adhoc filter params are
      // used and not the saved filter.
      FF.clear_selected_filter();

      // Submit will happen.
      // Note, this is a GET since we didn't change it to a POST.
      return true;
    },

    // Submits form to do an update
    update_filter_click: function() {
      // Submit form as POST to indicate we are updating
      FF.do_post();
      return true;
    },

    // Submits form to delete a filter
    delete_filter_click: function() {
      if (confirm("Are you sure you want to delete this filter?")) {
        // Adjust the form action.
        // This seems hacky, but should be alright I guess..
        $('#filter_form_form').attr('action','/errata/delete_filter');
        // Submit form as POST to indicate we are updating
        FF.do_post();
        return true;
      }
      return false;
    },

    //
    show_filter_name_field: function() {
      $('#name_field_container').show();
      $('.hide_if_adding_name').hide();
      return false;
    },

    //
    hide_filter_name_field: function() {
      $('#name_field_container').hide();
      $('.hide_if_adding_name').show();
      // Clear any text they might have typed in the name field..
      $('#filter_name').val('');
      return false;
    },

    //
    save_now_button_clicked: function() {
      var new_name = $.trim( $('#filter_name').val() );

      if (new_name === '') {
        // Don't submit. Make user try again to enter a name.
        alert('Please enter a filter name.');
        return false;
      }
      var existing_id = FF.check_dupe_filter_name(new_name);
      if (existing_id) {
        // Name exists already. Was that intentional?
        if (confirm('A filter called "' + new_name + '" already exists. Do you want to replace it?')) {
          // Have to set the filter id in the drop down to make it update an existing filter..
          FF.set_selected_filter(existing_id);
          FF.do_post();
          return true;
        }
        else {
          // Don't submit. User can try again with a different name.
          return false;
        }
      }
      else {
        // For 'Save as...' this clear is needed otherwise it will update the origin filter not create a new one
        FF.clear_selected_filter();
        FF.do_post();
        return true;
      }
    },

    you_checkbox_click: function() {
      // Kinda tricky because the checkbox is actually in
      // the label. '+ td' means next sibling..
      var neighbour_td = $(this).closest('td').find('+ td');
      var $select = neighbour_td.find('.select_container');
      var $name = neighbour_td.find('.is_you');
      // Doesn't matter about the value of the select
      // since the filter will ignore it anyway
      if (this.checked) {
        $select.hide();
        $name.show();
      }
      else {
        $select.show();
        $name.hide();
      }
    },

    // Note, method allows toggling, but currently user
    // can only click it once to show all values.
    current_or_all_toggle: function() {
      var param = $(this).data('param');
      var all = $('.all_' + param + '_container');
      var current = $('.current_' + param + '_container');
      var show_this, hide_this, link_text;
      if (current.is(':visible')) {
        // show all including inactive
        show_this = all;
        hide_this = current;
        link_text = 'current';
      }
      else {
        // show the current (active) values only
        hide_this = all;
        show_this = current;
        link_text = 'show all';
      }

      // Show the correct one
      hide_this.hide();
      show_this.fadeIn();

      // Need to tweak the select name so when the the form gets submitted
      // we know which field needs to be used.
      hide_this.find('select').attr('name','_disregard_' + param);
      show_this.find('select').attr('name','errata_filter[filter_params][' + param + '][]');

      // Update text
      $(this).text(link_text);

      // This is what makes it a one way trip, ie can't toggle back:
      // Comment this out and we are back to a toggle...
      // Use visibility:hidden so the label doesn't move around..
      $(this).css('visibility','hidden');
    }
  },

  apply_form_behaviours: function() {
    // When user changes the filter using the drop down
    $('#filter_select').change(FF.event_handlers.changed_filter_select);
    // The three initially visible buttons, Refresh, Edit, New
    $('#filter_btn_refresh').click(FF.event_handlers.filter_btn_refresh);
    $('#filter_btn_modify').click(FF.event_handlers.filter_btn_modify);
    $('#filter_btn_new').click(FF.event_handlers.filter_btn_new);
    // Close the form modal
    $('#cancel_filter_btn').click(FF.event_handlers.close_modal);
    // Giving a name to a new filter before saving it
    $('#show_name_field_btn').click(FF.event_handlers.show_filter_name_field);
    $('#save_as_btn').click(FF.event_handlers.show_filter_name_field);
    $('#cancel_save_btn').click(FF.event_handlers.hide_filter_name_field);
    // Four ways to actually submit the form
    $('#save_submit_btn').click(FF.event_handlers.save_now_button_clicked);
    $('#update_submit_btn').click(FF.event_handlers.update_filter_click);
    $('#apply_submit_btn').click(FF.event_handlers.apply_button_click);
    $('#delete_submit_btn').click(FF.event_handlers.delete_filter_click);
    // Catch enter key (5th and 6th way)
    $('#filter_name').keypress(FF.event_handlers.catch_enter_on_new_filter);
    $('#errata_filter_filter_params_synopsis_text').keypress(FF.event_handlers.catch_enter_on_synopsis_text);

    // Special "is you checkboxes" the filter fields
    $('.you_check_box').change(FF.event_handlers.you_checkbox_click);

    // Toggle active/current lists (for releases or batches)
    $('.filter_inactive_toggle').click(FF.event_handlers.current_or_all_toggle);
  },

  // Main setup functon
  init: function() {
    FF.apply_form_behaviours();
  }
};

$(document).ready(function(){
  FF.init();
});

})(jQuery);
