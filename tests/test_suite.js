/**
 * RI Extension Manager — Automated Validation Test Suite
 */

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');
let passed = 0;
let failed = 0;
const results = [];

function assert(description, condition, details) {
  if (condition) {
    passed++;
    results.push({ status: 'PASS', description });
    console.log(`  [PASS] ${description}`);
  } else {
    failed++;
    results.push({ status: 'FAIL', description, details });
    console.error(`  [FAIL] ${description}`);
    if (details) console.error(`         -> ${details}`);
  }
}

console.log('====================================================');
console.log('  RI Extension Manager — Automated Test Suite');
console.log('====================================================\n');

// ── TEST 1: Manifest Validation ──
console.log('[1/4] Validating CSXS/manifest.xml...');
const manifestPath = path.join(ROOT_DIR, 'CSXS', 'manifest.xml');
assert('manifest.xml exists', fs.existsSync(manifestPath));
if (fs.existsSync(manifestPath)) {
  const content = fs.readFileSync(manifestPath, 'utf8');
  assert('ExtensionBundleId is "com.proscriptrunner.dualhost"', content.includes('ExtensionBundleId="com.proscriptrunner.dualhost"'));
  assert('Host PHXS is targeted', content.includes('<Host Name="PHXS"'));
  assert('Host PHSP is targeted', content.includes('<Host Name="PHSP"'));
  assert('Host ILST is targeted', content.includes('<Host Name="ILST"'));
  assert('MainPath is ./index.html', content.includes('<MainPath>./index.html</MainPath>'));
  assert('ScriptPath is ./jsx/host.jsx', content.includes('<ScriptPath>./jsx/host.jsx</ScriptPath>'));
  assert('Host version supports modern Photoshop', /<Host Name="PHXS" Version="\[[0-9.]+,99\.9\]"/.test(content));
}

// ── TEST 2: ExtendScript Files & Architecture ──
console.log('\n[2/4] Validating ExtendScript Engines & Bridges...');
const hostJsxPath = path.join(ROOT_DIR, 'jsx', 'host.jsx');
const psJsxPath = path.join(ROOT_DIR, 'jsx', 'photoshop.jsx');
const aiJsxPath = path.join(ROOT_DIR, 'jsx', 'illustrator.jsx');

assert('jsx/host.jsx exists', fs.existsSync(hostJsxPath));
assert('jsx/photoshop.jsx exists', fs.existsSync(psJsxPath));
assert('jsx/illustrator.jsx exists', fs.existsSync(aiJsxPath));

if (fs.existsSync(hostJsxPath)) {
  const hostContent = fs.readFileSync(hostJsxPath, 'utf8');
  assert('host.jsx does NOT contain isolated #targetengine "ProScriptRunnerHost"', !hostContent.includes('#targetengine "ProScriptRunnerHost"'));
  assert('host.jsx attaches to $.global.ProScriptRunner', hostContent.includes('$.global.ProScriptRunner = ProScriptRunner'));
  assert('host.jsx implements ProScriptRunner.getHostInfo', hostContent.includes('getHostInfo: function'));
  assert('host.jsx implements ProScriptRunner.run', hostContent.includes('run: function'));
}

if (fs.existsSync(psJsxPath)) {
  const psContent = fs.readFileSync(psJsxPath, 'utf8');
  assert('photoshop.jsx implements getHostInfo', psContent.includes('getHostInfo: getHostInfo'));
  assert('photoshop.jsx implements run dispatcher', psContent.includes('function run(payload)'));
  assert('photoshop.jsx exports PSR_Photoshop', psContent.includes('var PSR_Photoshop ='));
}

if (fs.existsSync(aiJsxPath)) {
  const aiContent = fs.readFileSync(aiJsxPath, 'utf8');
  assert('illustrator.jsx implements getHostInfo', aiContent.includes('getHostInfo: getHostInfo'));
  assert('illustrator.jsx implements run dispatcher', aiContent.includes('function run(payload)'));
  assert('illustrator.jsx exports PSR_Illustrator', aiContent.includes('var PSR_Illustrator ='));
}

// ── TEST 3: Script Registry Integrity ──
console.log('\n[3/4] Validating Script Registry Completeness...');
const mainJsPath = path.join(ROOT_DIR, 'js', 'main.js');
assert('js/main.js exists', fs.existsSync(mainJsPath));

if (fs.existsSync(mainJsPath) && fs.existsSync(psJsxPath) && fs.existsSync(aiJsxPath)) {
  const mainJs = fs.readFileSync(mainJsPath, 'utf8');
  const psJsx = fs.readFileSync(psJsxPath, 'utf8');
  const aiJsx = fs.readFileSync(aiJsxPath, 'utf8');

  // Extract all script IDs from main.js
  const psMatches = mainJs.match(/PHOTOSHOP_SCRIPTS\s*=\s*\[([\s\S]*?)\];/);
  const aiMatches = mainJs.match(/ILLUSTRATOR_SCRIPTS\s*=\s*\[([\s\S]*?)\];/);

  if (psMatches) {
    const ids = [];
    const idRegex = /id:\s*['"]([^'"]+)['"]/g;
    let m;
    while ((m = idRegex.exec(psMatches[1])) !== null) {
      ids.push(m[1]);
    }
    assert('Photoshop scripts count is 36', ids.length === 36, `Found: ${ids.length}`);

    // Verify each ID is implemented in photoshop.jsx switch
    let missingPs = [];
    ids.forEach(id => {
      if (!psJsx.includes(`case "${id}":`) && !psJsx.includes(`case '${id}':`)) {
        missingPs.push(id);
      }
    });
    assert('All 36 Photoshop script IDs handled in photoshop.jsx', missingPs.length === 0, `Missing: ${missingPs.join(', ')}`);
  }

  if (aiMatches) {
    const ids = [];
    const idRegex = /id:\s*['"]([^'"]+)['"]/g;
    let m;
    while ((m = idRegex.exec(aiMatches[1])) !== null) {
      ids.push(m[1]);
    }
    assert('Illustrator scripts count is 9', ids.length === 9, `Found: ${ids.length}`);

    let missingAi = [];
    ids.forEach(id => {
      if (!aiJsx.includes(`case "${id}":`) && !aiJsx.includes(`case '${id}':`)) {
        missingAi.push(id);
      }
    });
    assert('All 9 Illustrator script IDs handled in illustrator.jsx', missingAi.length === 0, `Missing: ${missingAi.join(', ')}`);
  }

  // Ensure no fake demo credits code
  assert('Demo credits deduction removed from main.js', !mainJs.includes("state.credits -= s.cost"));
}

// ── TEST 4: Distribution & Installer Files ──
console.log('\n[4/4] Validating Installer & Packaging...');
const installerExe = path.join(ROOT_DIR, 'RI-Extension-Installer.exe');
const installBat = path.join(ROOT_DIR, 'INSTALL-NOW.bat');
const zxpPath = path.join(ROOT_DIR, 'Installer', 'ProScriptRunner_Adobe_DualHost_v1.3.zxp');

assert('RI-Extension-Installer.exe compiled and exists', fs.existsSync(installerExe));
assert('INSTALL-NOW.bat exists', fs.existsSync(installBat));
assert('Installer ZXP package exists', fs.existsSync(zxpPath));

console.log('\n====================================================');
console.log(`  TEST RESULTS: ${passed} PASSED, ${failed} FAILED`);
console.log('====================================================\n');

process.exit(failed === 0 ? 0 : 1);
