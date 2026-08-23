// Minimal tests for the viewer's transcript parsers.
// Extracts the <script> from index.html and exercises the regexes/logic.
import { readFileSync } from 'fs';

const html = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const js = html.split('<script>')[1].split('</script>')[0];

let pass = 0, fail = 0;
const ok = (name, cond) => cond ? (pass++, console.log('  ok  ' + name))
                                : (fail++, console.log('  FAIL ' + name));

// 1. the script must parse
try { new Function(js); ok('viewer script parses', true); }
catch (e) { ok('viewer script parses (' + e.message + ')', false); }

// 2. TL;DR tag regex accepts the documented variants, rejects prose
const TAG_RE = /^[>\s]*\**\s*TL;?DR\s*#?(\d+)\s*:?\**:?\s*(.*)$/i;
ok('tag: blockquote+bold', TAG_RE.test('> **TL;DR #7:** costs drop 40%'));
ok('tag: plain',            TAG_RE.test('> TL;DR #12: plain variant'));
ok('tag: no semicolon',     TAG_RE.test('TLDR #3: no blockquote'));
ok('tag: rejects prose',   !TAG_RE.test('random prose about tldr stuff'));
ok('tag: captures number',  '7' === '> **TL;DR #7:** x'.match(TAG_RE)[1]);

// 3. speaker-marker detection for mirror files
const SPEAK_RE = /^###\s*(?:\u{1F9D1}|\u{1F916})\s*(You|Claude)[^\n]*$/imu;
ok('mirror: detects speakers',
   SPEAK_RE.test('### \u{1F9D1} You - turn 1\nhi\n\n### \u{1F916} Claude - turn 1\nyo'));
ok('mirror: ignores plain text', !SPEAK_RE.test('just a normal paragraph'));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
