var ormVersions = [];

$( document ).ready(function() {
  displayed_releases.forEach(function(displayed_release) {
    var versionTokens = displayed_release.split(".");
    var majorMinorVersion = versionTokens[0] + "." + versionTokens[1];
    ormVersions.push(majorMinorVersion);
  });

  var comboId = 'docVersion';
  var combo = $("<select></select>").attr('id', comboId).attr("onchange", 'location = this.options[this.selectedIndex].value;');

  $.each(ormVersions, function (i, version) {
    var option = $('<option value=/orm/documentation/' + version  + '>' + version + '</option>');
    if(document.location.href.match('^.*?\/' + version.replace('.', '\.') + '\/$')) {
      option.attr('selected', true);
    }
    combo.append(option);
  });

  var label = $('<label>Other versions</label>').attr('for', comboId).css('font-weight', 'bold');

  $('#ormDocVersionSelector').css('float', 'right').append(label).append(combo);
});
