#!/usr/bin/env node
'use strict';

// Installs the StayTab release matching this package's version. The download
// is trusted only after codesign proves it carries StayTab's Developer ID and
// Gatekeeper accepts it, so a tampered or swapped asset never reaches the
// Applications folder.

const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');
const { parseArgs } = require('node:util');

const { version } = require('../package.json');

const REPO = 'kang1027/StayTab';
const APP = 'StayTab.app';
const MIN_MACOS = 13;
// Developer ID Application certificate for team GGR9HG6DB8, issued under
// Apple's Developer ID CA, signing the shipped bundle identifier.
const REQUIREMENT =
  'anchor apple generic' +
  ' and certificate 1[field.1.2.840.113635.100.6.2.6] exists' +
  ' and certificate leaf[field.1.2.840.113635.100.6.1.13] exists' +
  ' and certificate leaf[subject.OU] = "GGR9HG6DB8"' +
  ' and identifier "com.kdh.StayTab"';

const HELP = `Usage: npx staytab [options]

Downloads StayTab ${version} from GitHub Releases, checks its Developer ID
signature and notarization, and installs it into /Applications.

Options:
  --dir <path>   Install into another folder, such as ~/Applications
  --force        Reinstall even if this version is already installed
  --no-open      Don't launch StayTab afterwards
  -v, --version  Print the StayTab version this installer fetches
  -h, --help     Show this help

After the first install, StayTab updates itself from Settings → General.`;

class InstallError extends Error {}

function fail(message) {
  throw new InstallError(message);
}

function step(message) {
  console.log(`• ${message}`);
}

function run(command, args) {
  const result = spawnSync(command, args, { encoding: 'utf8' });
  if (result.error) fail(`Couldn't run ${command}: ${result.error.message}`);
  return result;
}

function expandHome(value) {
  return value === '~' || value.startsWith('~/') ? path.join(os.homedir(), value.slice(1)) : value;
}

function options() {
  try {
    return parseArgs({
      options: {
        dir: { type: 'string' },
        force: { type: 'boolean' },
        'no-open': { type: 'boolean' },
        version: { type: 'boolean', short: 'v' },
        help: { type: 'boolean', short: 'h' },
      },
    }).values;
  } catch (error) {
    fail(`${error.message}\n\n${HELP}`);
  }
}

function checkMac() {
  if (process.platform !== 'darwin') fail('StayTab runs on macOS only.');
  const release = run('sw_vers', ['-productVersion']).stdout.trim();
  if (Number.parseInt(release, 10) < MIN_MACOS) {
    fail(`StayTab needs macOS ${MIN_MACOS} or later; this Mac runs ${release}.`);
  }
}

function installedVersion(app) {
  const plist = path.join(app, 'Contents', 'Info.plist');
  if (!fs.existsSync(plist)) return null;
  const result = run('plutil', ['-extract', 'CFBundleShortVersionString', 'raw', '-o', '-', plist]);
  return result.status === 0 ? result.stdout.trim() : null;
}

async function findZip(tag) {
  const response = await fetch(`https://api.github.com/repos/${REPO}/releases/tags/${tag}`, {
    headers: { Accept: 'application/vnd.github+json', 'User-Agent': `staytab-npm/${version}` },
  });
  if (response.status === 404) fail(`GitHub has no StayTab release ${tag}.`);
  if (response.status === 403 || response.status === 429) {
    fail('GitHub is rate-limiting this network. Try again in a few minutes.');
  }
  if (!response.ok) fail(`GitHub answered ${response.status} for release ${tag}.`);
  const release = await response.json();
  const zips = (release.assets || []).filter((asset) => /^StayTab-.+\.zip$/.test(asset.name));
  if (zips.length !== 1) fail(`Release ${tag} should carry one StayTab zip; found ${zips.length}.`);
  return zips[0];
}

async function download(asset, file) {
  const response = await fetch(asset.browser_download_url, {
    headers: { 'User-Agent': `staytab-npm/${version}` },
  });
  if (!response.ok || !response.body) fail(`Download failed with ${response.status}.`);
  await pipeline(Readable.fromWeb(response.body), fs.createWriteStream(file));
  const size = fs.statSync(file).size;
  if (size !== asset.size) fail(`Download was cut short (${size} of ${asset.size} bytes).`);
}

function verify(app) {
  const signature = run('codesign', ['--verify', '--deep', '--strict', `-R=${REQUIREMENT}`, app]);
  if (signature.status !== 0) {
    fail(`The download isn't signed by StayTab's developer, so it wasn't installed.\n${signature.stderr.trim()}`);
  }
  const gatekeeper = run('spctl', ['--assess', '--type', 'execute', app]);
  if (gatekeeper.status !== 0) {
    fail(`Gatekeeper rejected the download, so it wasn't installed.\n${gatekeeper.stderr.trim()}`);
  }
}

function isRunning(app) {
  const executable = path.join(app, 'Contents', 'MacOS', 'StayTab');
  return run('ps', ['-axo', 'comm=']).stdout.split('\n').some((line) => line.trim() === executable);
}

async function quit(app) {
  // An AppleScript quit lets StayTab hand ⌘Tab back to macOS; a signal would not.
  const target = app.replace(/[\\"]/g, '\\$&');
  run('osascript', ['-e', `tell application "${target}" to quit`]);
  for (let tries = 0; tries < 50 && isRunning(app); tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  if (isRunning(app)) fail('StayTab is still running. Quit it from the menu bar, then run this again.');
}

function install(source, destination) {
  const previous = `${destination}.previous-${process.pid}`;
  const hadPrevious = fs.existsSync(destination);
  try {
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    if (hadPrevious) fs.renameSync(destination, previous);
    const copy = run('ditto', [source, destination]);
    if (copy.status !== 0) throw new Error(copy.stderr.trim());
  } catch (error) {
    fs.rmSync(destination, { recursive: true, force: true });
    if (hadPrevious && fs.existsSync(previous)) fs.renameSync(previous, destination);
    if (error.code === 'EACCES' || error.code === 'EPERM') {
      fail(`No permission to write to ${path.dirname(destination)}. Try: npx staytab --dir ~/Applications`);
    }
    fail(`Couldn't install StayTab: ${error.message}`);
  }
  if (hadPrevious) fs.rmSync(previous, { recursive: true, force: true });
}

async function main() {
  const args = options();
  if (args.help) return console.log(HELP);
  if (args.version) return console.log(version);
  checkMac();

  const folder = path.resolve(expandHome(args.dir || '/Applications'));
  const destination = path.join(folder, APP);
  const tag = `v${version}`;
  const firstInstall = installedVersion(destination) === null;

  if (!args.force && installedVersion(destination) === version) {
    step(`StayTab ${version} is already installed in ${folder}.`);
  } else {
    step(`Looking up StayTab ${version} on GitHub`);
    const asset = await findZip(tag);
    const work = fs.mkdtempSync(path.join(os.tmpdir(), 'staytab-'));
    try {
      const zip = path.join(work, asset.name);
      step(`Downloading ${asset.name} (${(asset.size / 1048576).toFixed(1)} MB)`);
      await download(asset, zip);
      const unpacked = path.join(work, 'unpacked');
      if (run('ditto', ['-x', '-k', zip, unpacked]).status !== 0) fail('The download is not a valid zip.');
      const app = path.join(unpacked, APP);
      if (!fs.existsSync(app)) fail(`The zip doesn't contain ${APP}.`);

      step('Checking the Developer ID signature and notarization');
      verify(app);
      if (isRunning(destination)) {
        step('Quitting the running StayTab');
        await quit(destination);
      }
      install(app, destination);
      step(`Installed ${destination}`);
    } finally {
      fs.rmSync(work, { recursive: true, force: true });
    }
  }

  if (!args['no-open']) {
    run('open', [destination]);
    step(firstInstall ? 'Opened StayTab. Grant Accessibility access when macOS asks.' : 'Opened StayTab.');
  }
}

main().catch((error) => {
  console.error(`✗ ${error instanceof InstallError ? error.message : error.stack || error}`);
  process.exitCode = 1;
});
