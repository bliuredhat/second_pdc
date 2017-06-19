(function($) {
// The table holding all the BrewFileMeta
function $et_meta_tbody() {
  return $('table.et-sortable').find('tbody');
}

// Each element mapping to a BrewFileMeta (in order)
function $et_meta_rank() {
  return $et_meta_tbody().find('.meta-rank');
}

// Element to be shown only when file order is dirty
function $et_show_when_file_order_dirty() {
  return $('.show-when-rank-dirty');
}

// Element to be shown only after file order was successfully saved
function $et_show_when_file_order_persisted() {
  return $('.show-when-rank-persisted');
}

function $et_file_order_form() {
  return $('form.show-when-rank-dirty');
}

window.et_edit_all_title = function() {
  form_toggle_all(document, true);
  et_setup_input_focus_chain($('input[name="title"]'), {focus_now: true});
};

window.et_cancel_all_title = function() {
  form_toggle_all(document, false);
};

function et_init_title() {
  // The browser may remember the values for the title inputs based on
  // their order (FF does this, not sure about Chrome).
  //
  // That means if you fill in the first title on the page, then
  // change the order of the files and reload, a value for the wrong
  // file can be prefilled.
  //
  // To work around this, undo any browser prefill on the hidden
  // forms.
  $('input[name="title"]').each(function(){
    $(this).val(this.getAttribute('value'));
  });
}

// Sets up tab index on title inputs so that tab key tabs between the
// visible inputs
function et_set_title_tab_order() {
  var inputs = $('input[name="title"]');
  inputs.each(function(idx,elem) {
    elem.tabIndex = 10000 + idx;
  });
}

function et_save_hidden_file_order() {
  // Update the order to be persisted
  $('input[name="brew_file_order"]', $et_file_order_form()).val(et_get_files_in_order());
}

// Called after files are dragged/dropped to change the order.
function et_on_file_order_updated(event) {
  var dirty = et_file_order_is_dirty(),
    show_when_dirty = $et_show_when_file_order_dirty();

  // do not add slide-down class if element was already displayed
  if (dirty && show_when_dirty.css('display') === 'none') {
    show_when_dirty.addClass('slide-down');
  } else {
    show_when_dirty.removeClass('slide-down');
  }

  show_when_dirty.toggle(dirty);

  et_save_hidden_file_order();
}

// Reset the row order to the previously saved order.
window.et_reset_rank = function(event) {
  et_restore_row_order($et_meta_tbody());
};

// Get all brew file IDs in table order
function et_get_files_in_order() {
  return $et_meta_rank().map(function(){
    return $(this).data('brew-file');
  }).get();
}

// true if displayed order is different from persisted order
function et_file_order_is_dirty() {
  var
    saved_order = $et_meta_tbody().data('brew-file-order') || [],
    current_order = et_get_files_in_order();

  return (saved_order.join(',') !== current_order.join(','));
}

// Save the current row/file order as being equal to whatever is
// persisted in ET.
function et_set_file_order_persisted(loading) {
  var tbody = $et_meta_tbody(),
    order;

  et_save_row_order(tbody);

  // on document load, if any rank is not initialized, save a bogus
  // file order to force the data to be considered dirty until the
  // first persist.
  if (loading && $('[data-original-rank=""]').length > 0) {
    order = ['uninitialized'];
  } else {
    order = et_get_files_in_order();
  }

  // Save the current file order for later comparison
  $et_meta_tbody().data('brew-file-order', order);
}

// Called after successfully saving a new file order
function et_on_file_order_submitted() {
  et_set_file_order_persisted();
  $et_meta_tbody().trigger('sortupdate');
  $et_show_when_file_order_persisted().show();

  // After a successful persist, no rank is missing
  $('.show-when-rank-missing').hide();
  $('.show-when-rank-present').show();
}

function et_on_file_order_sort_start() {
  // If the user previously changed order and is starting to change it
  // again, hide any notice about the previous save
  $et_show_when_file_order_persisted().fadeOut();
}

function et_init_meta_events() {
  var form = $et_file_order_form(),
    tbody = $et_meta_tbody();

  tbody.on('sortupdate', et_on_file_order_updated);
  tbody.on('sortstart', et_on_file_order_sort_start);
  form.on('ajax:success', et_on_file_order_submitted);

  // make sure the rows cannot be dragged around during form submission
  form.on('ajax:beforeSend', function(){
    // add/remove class for any styling indicating that something is
    // draggable (e.g. cursor)
    var handle = $('.sort-handle', tbody);

    handle.removeClass('sort-handle');
    tbody.sortable('disable');

    form.one('ajax:complete', function(){
      tbody.sortable('enable');
      handle.addClass('sort-handle');
    });
  });

  $(document).on('click', '.btn-toggle-title', function(event) {
    event.preventDefault();
    form_toggle(this);
  });

  $('.btn-cancel-reorder').on('click', function(event) {
    event.preventDefault();
    et_reset_rank(event);
  });

}

function et_init_meta_table() {
  et_save_hidden_file_order();
  et_init_title();
  et_set_title_tab_order();
  et_set_file_order_persisted(true);
  et_init_meta_events();
}

// ======================== END FUNCTIONS ==================================

$(et_init_meta_table);

// redo setting tab order after form submission, because that destroys
// and recreates form elements
$(document).ajaxComplete(function(){
  window.setTimeout(et_set_title_tab_order, 0);
});

}(jQuery));
