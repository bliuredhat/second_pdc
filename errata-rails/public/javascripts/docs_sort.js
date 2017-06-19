/*
 * **
 * ** See bug 965922.
 * ** Designed for use in _doc_queue, but currently not in use.
 * ** The applicable columns are using the data-sort defined in
 * ** tablesort_parsers (along with the tablesort_helper method
 * ** to add the data-sort attribute to the table cell).
 * **
 */
$.tablesorter.addParser({
  // set a unique id
  id: 'advisory',
  is: function(s, table, cell) {
    // return false so this parser is not auto detected
    return false;
  },
  /*
   * Note: I think this needs some more work.
   * It should sort by the reset of the advisory name,
   * which this code doesn't seem to do.
   */
  format: function(s, table, cell, cellIndex) {
    // format your data for normalization
    if (s.match(/RHSA/)) {
      return 2;
    }
    else if (s.match(/RHBA/)) {
      return 1;
    }
    else {
      return 0;
    }
  },
  // set type, either numeric or text
  type: 'numeric'
});

$.tablesorter.addParser({
  id: 'reviewer',
  is: function(s, table, cell) {
    // return false so this parser is not auto detected
    return false;
  },
  format: function(s, table, cell, cellIndex) {
    var name = s.split(/\n/)[0];
    var order = '9';
    if('Unassigned' == name) {
      order = '0';
    }
    return order + name;
  },
  // set type, either numeric or text
  type: 'text'
});
