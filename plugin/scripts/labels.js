// labels.js — which launchd property lists carry a label. Used by res-diag.sh label.
//
// Runs under the JavaScript engine that ships with macOS:
//   osascript -l JavaScript labels.js LABEL SOURCE DIR [SOURCE DIR]...
//
// Prints one line per property list in the given folders whose parsed Label is LABEL:
//   SOURCE<TAB>path
// and, for every folder that exists but cannot be listed and every file that exists but
// is not a readable property list:
//   incomplete<TAB>path
//
// Every file is parsed and the parsed label is compared, so a label written with a
// character reference, or stored in the binary form, is found. A folder that does not
// exist and a symbolic link whose target does not exist are not items and are skipped.
// Nothing here writes a file or sends an Apple event.

ObjC.import('Foundation');

// A path is printed on one line: control characters would add a line or a column.
function printable(text) { return text.replace(/[\u0000-\u001f\u007f]/g, '?'); }

function run(argv) {
  var want = argv[0];
  var fm = $.NSFileManager.defaultManager;
  var lines = [];
  for (var i = 1; i + 1 < argv.length; i += 2) {
    var source = argv[i];
    var dir = argv[i + 1];
    if (!fm.fileExistsAtPath(dir)) { continue; }
    var listing = fm.contentsOfDirectoryAtPathError(dir, null);
    if (listing.isNil()) { lines.push('incomplete\t' + printable(dir)); continue; }
    ObjC.unwrap(listing).map(function (n) { return ObjC.unwrap(n); }).sort().forEach(function (name) {
      if (!/\.plist$/.test(name)) { return; }
      var path = dir + '/' + name;
      // fileExistsAtPath follows links: false here means a link whose target is gone.
      if (!fm.fileExistsAtPath(path)) { return; }
      var plist = $.NSDictionary.dictionaryWithContentsOfFile(path);
      if (plist.isNil()) { lines.push('incomplete\t' + printable(path)); return; }
      var label = plist.objectForKey('Label');
      if (!label.isNil() && ObjC.unwrap(label) === want) { lines.push(source + '\t' + printable(path)); }
    });
  }
  return lines.join('\n');
}
