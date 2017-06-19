(function($) {
// Sort based on data in td element
// e.x. <td data-sort='foo'>
$.tablesorter.addParser({
  id: 'cellDataTextSort',
  is: function(s, table, cell) {
    return false;
  },
  format: function(s, table, cell, cellIndex) {
    return cell.dataset.sort;
  },
  type: 'text'
});

// e.x. <td data-sort='90210'>
$.tablesorter.addParser({
    id: 'cellDataNumberSort',
    is: function(s, table, cell) {
        return false;
    },
    format: function(s, table, cell, cellIndex) {
        return cell.dataset.sort;
    },
    type: 'number'
});

}(jQuery));
