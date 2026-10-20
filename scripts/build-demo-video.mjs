// Optional development tooling. Runtime remains Oracle Database + Oracle APEX.
// Uses actual successful browser footage; no generated or reconstructed UI.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFile, writeFile, mkdir, access } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { chromium } from 'playwright';

const args = process.argv.slice(2);
function option(name, fallback) {
  const index = args.indexOf(name);
  return index < 0 ? fallback : args[index + 1];
}
const ffmpeg = option('--ffmpeg', process.env.FFMPEG || 'ffmpeg');
const ffprobe = option('--ffprobe', process.env.FFPROBE || 'ffprobe');
const chrome = option('--chrome', process.env.CHROME_PATH);
const input = path.resolve(option('--input', '.local/ui-agent-workflow'));
const output = path.resolve(option('--output', '.local/video'));
const publicMedia = path.resolve('media');
const evidence = JSON.parse(await readFile(path.join(input, 'results.json'), 'utf8'));
if (!evidence.recording?.requested || evidence.tests.length < 16 ||
    evidence.tests.some(test => !test.passed) || evidence.pageErrors.length) {
  throw new Error('A complete passing recorded browser run without page errors is required.');
}
const narration = JSON.parse(await readFile('media/narration.json', 'utf8'));
const rawVideo = path.join(input, 'video/manager-workflow.webm');
const rawHash = createHash('sha256').update(await readFile(rawVideo)).digest('hex');
const stage = path.join(output, 'segments');
await mkdir(stage, { recursive: true });

// Render only the original vector title card. APEX screens come from the run.
const browser = await chromium.launch({ headless: true, ...(chrome && { executablePath: chrome }) });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  await page.goto(pathToFileURL(path.resolve('media/title-card.svg')).href);
  await page.screenshot({ path: path.join(publicMedia, 'demo-thumbnail.png') });
} finally { await browser.close(); }

const still = name => ({ kind: 'runtime screenshot / reading pause', file: `${name}.png` });
const clip = (start, end) => ({ kind: 'actual browser video / reading pause after clip', start, end });
// Seconds are relative to context creation in results.json, not an invented UI.
// Captions 6-7 show the actual independently imported synthetic fixture.
const scenes = [
  { kind: 'original title card', title: true },
  still('00-overview'),
  still('sample-baseline'),
  clip(3.2, 9.25),
  still('sample-baseline-review'),
  still('sample-changed-review'),
  still('sample-changed'),
  clip(19.3, 25.45),
  still('02-comparison'),
  clip(54.85, 58.8),
  still('03-preview-selected'),
  clip(60.05, 60.95),
  clip(61.08, 68.3),
  still('05-selected-verified'),
  still('05-selected-verified'),
  clip(75.7, 88.45),
  still('sample-recovered-eligible'),
  still('07-restore-preview'),
  clip(104.5, 113.5),
  still('sample-restored-definition'),
  clip(116.8, 120.3),
  still('00-overview'),
  { kind: 'original title card', title: true }
];
const flattened = narration.chapters.flatMap(chapter => chapter.captions.map(text => ({ chapter, text })));
if (flattened.length !== scenes.length) throw new Error('Narration and reviewed edit list differ.');
for (let index = 0; index < flattened.length; index++) {
  await access(path.join(output, `audio/${String(index + 1).padStart(2, '0')}.wav`));
  if (scenes[index].file) await access(path.join(input, scenes[index].file));
}
const probe = filename => JSON.parse(execFileSync(ffprobe,
  ['-v', 'error', '-show_format', '-show_streams', '-of', 'json', filename], { encoding: 'utf8' }));
const seconds = n => Number(n).toFixed(6);
function time(n, separator = '.') {
  const ms = Math.round(n * 1000);
  return `${String(Math.floor(ms / 3600000)).padStart(2, '0')}:${String(Math.floor(ms / 60000) % 60).padStart(2, '0')}:${String(Math.floor(ms / 1000) % 60).padStart(2, '0')}${separator}${String(ms % 1000).padStart(3, '0')}`;
}
function wrap(text) {
  const words = text.split(' '), lines = [];
  let line = '';
  for (const word of words) {
    if (line.length + word.length > 105) { lines.push(line); line = word; }
    else line += (line ? ' ' : '') + word;
  }
  lines.push(line);
  return lines.join('\\N');
}
const assHeader = `[Script Info]\nScriptType: v4.00+\nPlayResX: 1600\nPlayResY: 1200\nWrapStyle: 2\n\n[V4+ Styles]\nFormat: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding\nStyle: Default,Arial,24,&H00FFFFFF,&H00FFFFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,0,0,2,100,100,18,1\n\n[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n`;
const events = [], chapters = [], edits = [], concat = [];
let position = 0;
for (let index = 0; index < flattened.length; index++) {
  const number = String(index + 1).padStart(2, '0');
  const { chapter, text } = flattened[index], scene = scenes[index];
  const audio = path.join(output, `audio/${number}.wav`);
  const duration = Math.ceil(Math.max(Number(probe(audio).format.duration) + 0.7,
    (scene.end || 0) - (scene.start || 0) + 0.5) * 24) / 24;
  const segment = path.join(stage, `${number}.mp4`);
  const titleFile = `${number}-title.txt`, labelFile = `${number}-label.txt`, assFile = `${number}.ass`;
  await writeFile(path.join(stage, titleFile), `${chapter.title}  |  APEX 26.2.0\n`);
  await writeFile(path.join(stage, labelFile), scene.title ? 'ORIGINAL TITLE / SYNTHETIC NARRATION' : scene.start === undefined ? 'ACTUAL SCREENSHOT / READING PAUSE' : 'ACTUAL BROWSER / EDITED WITH PAUSES');
  const assEnd = `${String(Math.floor(duration / 3600))}:${String(Math.floor(duration / 60) % 60).padStart(2, '0')}:${seconds(duration % 60).padStart(9, '0').slice(0, 5)}`;
  await writeFile(path.join(stage, assFile), assHeader + `Dialogue: 0,0:00:00.00,${assEnd},Default,,0,0,0,,${wrap(text)}\n`);
  const source = scene.title ? path.join(publicMedia, 'demo-thumbnail.png') : scene.file ? path.join(input, scene.file) : rawVideo;
  const sourceArgs = scene.start === undefined ? ['-loop', '1', '-i', source] : [
    '-ss', seconds(scene.start - evidence.recording.videos[0].createdAtMs / 1000),
    '-t', seconds(scene.end - scene.start), '-i', source
  ];
  const filters = [
    'scale=1440:1080:force_original_aspect_ratio=decrease:flags=lanczos',
    'pad=1600:1200:(ow-iw)/2:30+(1080-ih)/2:color=0x07090C',
    'setsar=1', `tpad=stop_mode=clone:stop_duration=${seconds(duration)}`,
    `drawtext=font=Arial:textfile=${titleFile}:fontcolor=0xF5A640:fontsize=19:x=80:y=5`,
    `drawtext=font=Arial:textfile=${labelFile}:fontcolor=0xA1A1AA:fontsize=14:x=1110:y=8`,
    `ass=${assFile}`
  ].join(',');
  execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', ...sourceArgs, '-i', audio,
    '-vf', filters, '-af', 'apad', '-t', seconds(duration), '-r', '24',
    '-c:v', 'libx264', '-preset', 'fast', '-crf', '22', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '96k', '-ar', '48000', '-ac', '2', '-movflags', '+faststart', segment
  ], { cwd: stage, stdio: ['ignore', 'ignore', 'pipe'], maxBuffer: 4 * 1024 * 1024 });
  const actualDuration = Number(probe(segment).format.duration);
  if (chapters.at(-1)?.id !== chapter.id) chapters.push({ id: chapter.id, title: chapter.title, startSeconds: position });
  events.push({ start: position, end: position + actualDuration, text });
  edits.push({ caption: index + 1, chapter: chapter.id, ...scene, outputStartSeconds: position,
    outputDurationSeconds: actualDuration, sourceSha256: createHash('sha256').update(await readFile(source)).digest('hex') });
  concat.push(`file '${number}.mp4'`);
  position += actualDuration;
  console.log(`Encoded ${number}/${flattened.length}: ${chapter.id}`);
}
await writeFile(path.join(stage, 'concat.txt'), concat.join('\n') + '\n');
const finalFile = path.join(output, 'apex-theme-manager-demo.mp4');
execFileSync(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-y', '-f', 'concat', '-safe', '0',
  '-i', 'concat.txt', '-c', 'copy', '-movflags', '+faststart', finalFile],
  { cwd: stage, stdio: ['ignore', 'ignore', 'pipe'] });
const vtt = 'WEBVTT\n\n' + events.map((event, index) => `${index + 1}\n${time(event.start)} --> ${time(event.end)}\n${event.text}\n`).join('\n');
const srt = events.map((event, index) => `${index + 1}\n${time(event.start, ',')} --> ${time(event.end, ',')}\n${event.text}\n`).join('\n');
await writeFile(path.join(publicMedia, 'demo.en.vtt'), vtt);
await writeFile(path.join(publicMedia, 'demo.en.srt'), srt);
await writeFile(path.join(publicMedia, 'demo-chapters.json'), JSON.stringify(chapters, null, 2) + '\n');
const finalBytes = await readFile(finalFile), metadata = probe(finalFile);
const manifest = {
  recorded: evidence.started, built: new Date().toISOString(), testedApex: evidence.versions.apex,
  disclosure: narration.editingDisclosure, voice: narration.voiceDisclosure,
  runtimeScreensReconstructed: false, playbackSpeed: 1, pauses: 'Freeze frames and unchanged actual runtime screenshots are labeled.',
  rawManagerSha256: rawHash, successfulBrowserChecks: evidence.tests.length,
  output: { filename: path.basename(finalFile), bytes: finalBytes.length, sha256: createHash('sha256').update(finalBytes).digest('hex'),
    durationSeconds: Number(metadata.format.duration), width: 1600, height: 1200, video: 'H.264 yuv420p', audio: 'AAC', frameRate: 24 },
  chapters, edits
};
await writeFile(path.join(publicMedia, 'demo-edit-manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(JSON.stringify(manifest.output));
