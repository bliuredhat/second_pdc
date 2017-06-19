(function($) {
/*
  Reapply the bz_even/bz_odd classes appropriately after a table's
  rows have been reordered.
*/
function et_restyle_rows(event) {
  $('tr', event.target).each(function(idx,elem) {
    var $el = $(elem),
      even =   (idx % 2) === 0,
      remove = even ? 'bz_odd'  : 'bz_even',
      add =    even ? 'bz_even' : 'bz_odd';

    // don't do anything to unstyled rows
    if (!$el.hasClass(remove) && !$el.hasClass(add)) {
      return;
    }

    $el.removeClass(remove).addClass(add);
  });
}

/*
  Saves the order of tr within a tbody, for later restoration.
*/
window.et_save_row_order = function(tbody) {
  var ids = tbody.children('tr').map(function(){
    return this.id;
  }).get();
  tbody.data('original-row-order', ids);
};

/*
  Restores the order of tr within a tbody previously saved by
  et_save_row_order.

  Please note that only rows which have an ID are saved/restored.
  Rows without an ID will always end up at the end of the table.
*/
window.et_restore_row_order = function(tbody) {
  var ids = tbody.data('original-row-order');

  // slice() to make a deep copy, otherwise reverse() modifies the
  // stored data
  ids = ids.slice();
  ids.reverse();

  ids.forEach(function(id){
    var elem = document.getElementById(id);
    if (!elem) {
      return;
    }

    tbody.prepend($(elem).detach());
  });

  tbody.sortable('refreshPositions').trigger('sortupdate');
};

/*
  Freeze/thaw will fix/unfix the width of td in a table.

  See commentary near helper: below for the purpose of this.
*/
function et_freeze_table(evt) {
  // Do two passes - grab all the widths first, because modifying
  // width of td earlier in the table can change the width of td later
  // in the table
  var td = $('td', $(evt.target).closest('table')),
    widths = td.map(function(){ return $(this).width(); });

  td.each(function(idx){
    $(this).css({ 'min-width': widths[idx], 'max-width': widths[idx] });
  });
}

function et_thaw_table(evt, ui) {
  $('td', ui.item.closest('table')).each(function(){
    $(this).css({ 'min-width': '', 'max-width': '' });
  });
}

/* Looks convoluted, but it's to make the row being dragged and the
 * rest of the table render consistently with each other.
 *
 * The default implementation of jQuery UI sortable will set the
 * dragged row to position:absolute and adjust its position during the
 * drag.  The problem with this is that it means the content of the
 * row is no longer taken into consideration when calculating the
 * preferred table layout.  So:
 *
 * - the row being dragged will not render with the same width as the
 *   rest of the table
 *
 * - the other rows in the table may "pop" when sort begins and ends
 *
 * To fix this, we make our own helper, which instead of rendering a
 * <tr> for the element being dragged, renders a table containing only
 * the row to be dragged.  The width of each cell in the original
 * table and the helper table is frozen before the drag begins.
 */
function et_sortable_helper(evt,tr) {
  var $tr = $(tr),
    new_tr,
    new_tbody = $('<tbody>'),
    new_table = $('<table>').append(new_tbody);

  // freezing the table prevents it from popping ...
  et_freeze_table(evt);

  // ...and ensures our cloned table with one row will have exactly the same width
  new_tr = $tr.clone();

  // copy over the class so it is appropriately styled
  new_table.addClass($tr.closest('table').get(0).getAttribute('class'));
  new_tbody.append(new_tr);

  return new_table;
}

/*
  Initialize any table with the "et-sortable" class to be "sortable",
  which means that users can drag/drop the rows within the table.
  (It's not related to tablesort.)
*/
function et_init_sortable_tables() {
  var tbody = $('table.et-sortable').find('tbody');

  tbody.sortable({
    axis: 'y',
    delay: 200,
    distance: 5,
    helper: et_sortable_helper,
    // our helper is a table; insert it as a sibling of the sortable
    // table, which may be relevant for styling.
    appendTo: tbody.closest('table').parent()
  });

  tbody.on('sortstop', et_thaw_table);
  tbody.on('sortupdate', et_restyle_rows);
}

$(et_init_sortable_tables);

}(jQuery));
