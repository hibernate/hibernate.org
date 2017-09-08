$( document ).ready(function() {
  var comboId = 'docVersion';
  var combo = $("<select></select>").attr('id', comboId).attr("onchange", 'location = this.options[this.selectedIndex].value;');

  $.each(displayed_series, function (i, version) {
    var option = $('<option value=/orm/documentation/' + version  + '>' + version + '</option>');
    if(document.location.href.match('^.*?\/' + version.replace('.', '\.') + '\/$')) {
      option.attr('selected', true);
    }
    combo.append(option);
  });

  var label = $('<label>Other versions</label>').attr('for', comboId).css('font-weight', 'bold');

  $('#ormDocVersionSelector').css('float', 'right').append(label).append(combo);
});
