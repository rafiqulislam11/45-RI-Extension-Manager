(function () {
  'use strict';

  /* ════════════════════════════════════════════════════════════════════
     SCRIPT REGISTRY (44 Real ExtendScript Automations)
  ════════════════════════════════════════════════════════════════════ */
  var CATEGORY_META = {
    'Image':       { icon: '🖼', color: '#38bdf8', bg: '#0c2238' },
    'Stock':       { icon: '📊', color: '#2dd4bf', bg: '#082f2c' },
    'Layer':       { icon: '📋', color: '#c084fc', bg: '#291147' },
    'Export':      { icon: '📤', color: '#fb923c', bg: '#341a06' },
    'Batch':       { icon: '📦', color: '#4ade80', bg: '#0a2c16' },
    'Illustrator': { icon: '✏️', color: '#f43f5e', bg: '#360d17' }
  };

  var PHOTOSHOP_SCRIPTS = [
    { id: 'doc-info',            cat: 'Image',  name: 'Document Information',        desc: 'Reads active Photoshop document dimensions, resolution, mode and save state.' },
    { id: 'upscale-2x',         cat: 'Image',  name: 'Image Upscale 2×',             desc: 'Upscales image to 200% using Photoshop Bicubic Smoother resampling (preserves aspect ratio).' },
    { id: 'upscale-4k',         cat: 'Image',  name: 'Upscale to 4K UHD',            desc: 'Fits active image within 3840×2160 using Bicubic Smoother resampling.' },
    { id: 'upscale-8k',         cat: 'Image',  name: 'Upscale to 8K UHD',            desc: 'Fits active image within 7680×4320 using Bicubic Smoother resampling.' },
    { id: 'upscale-custom',     cat: 'Image',  name: 'Custom Long-Edge Upscale',     desc: 'Resizes document to a specified maximum long-edge size in pixels.', hasParams: 'longEdge' },
    { id: 'image-to-gradient',  cat: 'Image',  name: 'Image to Gradient',            desc: 'Creates a non-destructive Gradient Map adjustment layer for tonal styling.' },
    { id: 'enhance',            cat: 'Image',  name: 'Detail & Edge Enhance',        desc: 'Duplicates layer and applies controlled Unsharp Mask sharpening (45%, 1.2px).' },
    { id: 'auto-enhance',       cat: 'Image',  name: 'Auto Tone + Contrast + Color', desc: 'Applies native Photoshop Auto Tone, Auto Contrast, and Auto Color adjustments.' },
    { id: 'add-noise',          cat: 'Image',  name: 'Add Monochromatic Noise',      desc: 'Applies adjustable Gaussian monochromatic noise to active layer.', hasParams: 'noise' },
    { id: 'add-grain',          cat: 'Image',  name: 'Add Film Grain Layer',         desc: 'Creates a duplicate layer with subtle noise and Soft Light blend mode.', hasParams: 'noise' },
    { id: 'sharpen',            cat: 'Image',  name: 'Smart Sharpen',                desc: 'Applies crisp edge sharpening using Unsharp Mask (65%, 1.1px).' },
    { id: 'vibrance',           cat: 'Image',  name: 'Vibrance Adjustment Layer',    desc: 'Creates a non-destructive Vibrance adjustment layer.' },
    { id: 'grayscale',          cat: 'Image',  name: 'Black & White Conversion',     desc: 'Desaturates active pixel layer to neutral grayscale.' },
    { id: 'trim',               cat: 'Image',  name: 'Trim Transparent Pixels',      desc: 'Trims transparent and empty boundary pixels from all sides of the canvas.' },
    { id: 'fit-canvas',         cat: 'Image',  name: 'Fit Canvas to Preset',         desc: 'Resizes canvas to standard social/display aspect presets (1:1, 4:5, 9:16, 16:9).', hasParams: 'preset' },
    { id: 'resize-image',       cat: 'Image',  name: 'Resize Image (Custom)',        desc: 'Resizes document to exact width and height in pixels using Bicubic resampling.', hasParams: 'dimensions' },
    { id: 'convert-rgb8',       cat: 'Image',  name: 'Convert to RGB 8-bit',         desc: 'Ensures color mode is RGB and bit depth is 8-bit for standard export compatibility.' },

    { id: 'stock-quality-check',cat: 'Stock',  name: 'Adobe Stock Quality Check',    desc: 'Validates megapixel range (4–100 MP), RGB mode, 8-bit depth, and resolution.' },
    { id: 'stock-prep',         cat: 'Stock',  name: 'Stock Pre-Flight Prep',        desc: 'Runs full pre-flight inspection and normalizes color mode and bit depth.' },

    { id: 'remove-hidden',      cat: 'Layer',  name: 'Remove Hidden Layers',         desc: 'Deletes all non-visible layers to reduce file size.' },
    { id: 'cleanup-empty',      cat: 'Layer',  name: 'Cleanup Empty Layers',         desc: 'Removes empty top-level art layers with zero pixel bounds.' },
    { id: 'duplicate-layer',    cat: 'Layer',  name: 'Duplicate Active Layer',       desc: 'Creates an exact duplicate copy of currently selected layer.' },
    { id: 'flatten',            cat: 'Layer',  name: 'Flatten Image',                desc: 'Flattens all visible layers into a single background layer.' },
    { id: 'watermark',          cat: 'Layer',  name: 'Add Text Watermark',           desc: 'Adds a customizable text watermark layer in bottom-right corner.', hasParams: 'watermark' },

    { id: 'export-jpg',         cat: 'Export', name: 'Export Active as JPG',         desc: 'Exports current document as high-quality JPG beside source file.' },
    { id: 'export-png',         cat: 'Export', name: 'Export Active as PNG',         desc: 'Exports current document as PNG beside source file.' },
    { id: 'export-web',         cat: 'Export', name: 'Quick Web JPG Export',         desc: 'Exports a compressed web-friendly JPG at quality 8 with sRGB profile.' },
    { id: 'export-stock-jpg',   cat: 'Export', name: 'Stock-Ready High-Quality JPG', desc: 'Validates MP requirements and exports maximum quality sRGB JPG copy.' },
    { id: 'save-copy-psd',      cat: 'Export', name: 'Save Copy as PSD',             desc: 'Saves a duplicate copy of active document as PSD.' },

    { id: 'batch-jpg',          cat: 'Batch',  name: 'Batch PSD/PSB to JPG',         desc: 'Processes a selected folder of PSD/PSB files and exports JPG copies.' },
    { id: 'batch-upscale',      cat: 'Batch',  name: 'Batch Upscale 2×',             desc: 'Upscales all supported images in a folder to 200% and exports JPGs.' },
    { id: 'batch-upscale-4k',   cat: 'Batch',  name: 'Batch Upscale to 4K UHD',      desc: 'Fits all images in a folder within 3840×2160 frame.' },
    { id: 'batch-upscale-8k',   cat: 'Batch',  name: 'Batch Upscale to 8K UHD',      desc: 'Fits all images in a folder within 7680×4320 frame.' },
    { id: 'batch-web',          cat: 'Batch',  name: 'Batch Web JPG Converter',      desc: 'Converts all images in a folder to web-optimized JPGs.' },
    { id: 'batch-rename',       cat: 'Batch',  name: 'Batch Sequential Rename',      desc: 'Renames all image files in a folder with prefix and 3-digit numbering.' },
    { id: 'contact-sheet',      cat: 'Batch',  name: 'Create Contact Sheet',         desc: 'Generates a thumbnail grid contact sheet from images in a folder.' }
  ];

  var ILLUSTRATOR_SCRIPTS = [
    { id: 'ai-doc-info',          cat: 'Illustrator', name: 'Document Information',   desc: 'Reports active artboard dimensions, total artboards and page items count.' },
    { id: 'ai-upscale-2x',        cat: 'Illustrator', name: 'Scale Artwork 2×',       desc: 'Scales all vector objects on active artboard to 200% from center.' },
    { id: 'ai-fit-artboard',      cat: 'Illustrator', name: 'Fit Artboard to Artwork',desc: 'Resizes active artboard to tightly fit outer bounds of artwork.' },
    { id: 'ai-center-artwork',    cat: 'Illustrator', name: 'Center Artwork',         desc: 'Centers all artwork on active artboard.' },
    { id: 'ai-outline-text',      cat: 'Illustrator', name: 'Convert Text to Outlines',desc: 'Converts text frame objects on active artboard into vector outlines.' },
    { id: 'ai-expand-appearance', cat: 'Illustrator', name: 'Expand Appearance',      desc: 'Expands dynamic effects and appearance styles on active artboard items.' },
    { id: 'ai-save-copy',         cat: 'Illustrator', name: 'Save Copy as AI',        desc: 'Saves a copy of the active Illustrator document.' },
    { id: 'ai-export-svg',        cat: 'Illustrator', name: 'Export SVG File',        desc: 'Exports current document as clean SVG with subset fonts.' },
    { id: 'ai-export-png',        cat: 'Illustrator', name: 'Export Transparent PNG', desc: 'Exports active document as PNG-24 with transparency.' }
  ];

  /* ════════════════════════════════════════════════════════════════════
     CEP / CSINTERFACE INITIALIZATION
  ════════════════════════════════════════════════════════════════════ */
  var csInterface = null;
  var isCEP = false;
  try {
    if (typeof CSInterface !== 'undefined') {
      csInterface = new CSInterface();
      isCEP = true;
    }
  } catch (e) {
    isCEP = false;
  }

  var appId = '';
  var appVersion = '';
  try {
    if (csInterface) {
      if (typeof csInterface.getApplicationID === 'function') {
        appId = csInterface.getApplicationID();
      }
      if (csInterface.hostEnvironment) {
        if (!appId) appId = csInterface.hostEnvironment.appId || '';
        appVersion = csInterface.hostEnvironment.appVersion || '';
      }
    }
    if (!appId && window.__adobe_cep__ && window.__adobe_cep__.getHostEnvironment) {
      var env = JSON.parse(window.__adobe_cep__.getHostEnvironment());
      if (env) {
        appId = env.appId || '';
        appVersion = env.appVersion || '';
      }
    }
  } catch (e) {}

  var isIllustrator = (appId === 'ILST');
  var isPhotoshop = (appId === 'PHXS' || appId === 'PHSP');
  var activeScriptList = isIllustrator ? ILLUSTRATOR_SCRIPTS : (isPhotoshop ? PHOTOSHOP_SCRIPTS : PHOTOSHOP_SCRIPTS.concat(ILLUSTRATOR_SCRIPTS));

  /* ════════════════════════════════════════════════════════════════════
     DOM REFERENCES
  ════════════════════════════════════════════════════════════════════ */
  var $ = function (id) { return document.getElementById(id); };

  var hostStatusBadge       = $('hostStatusBadge');
  var docName               = $('docName');
  var docSaveBadge          = $('docSaveBadge');
  var docDetails            = $('docDetails');
  var refreshDocBtn         = $('refreshDocBtn');
  var scriptSearchInput     = $('scriptSearchInput');
  var clearSearchBtn        = $('clearSearchBtn');
  var categorySelect        = $('categorySelect');
  var workflowCount         = $('workflowCount');
  var hostNotice            = $('hostNotice');
  var workflowGrid          = $('workflowGrid');
  var actionFooter          = $('actionFooter');
  var selectedActionName    = $('selectedActionName');
  var selectedActionCat     = $('selectedActionCat');
  var selectedActionDesc    = $('selectedActionDesc');
  var closeActionBtn        = $('closeActionBtn');
  var runBtn                = $('runBtn');
  var runBtnText            = $('runBtnText');
  var resultLog             = $('resultLog');
  var clearLogBtn           = $('clearLogBtn');
  var logToggleHeader       = $('logToggleHeader');
  var modalOverlay          = $('modalOverlay');
  var modalTitle            = $('modalTitle');
  var modalMsg              = $('modalMsg');
  var modalCancel           = $('modalCancel');
  var modalOk               = $('modalOk');
  var settingsBtn           = $('settingsBtn');
  var settingsModal         = $('settingsModal');
  var closeSettings         = $('closeSettings');
  var saveSettings          = $('saveSettings');
  var defaultWatermarkInput = $('defaultWatermarkInput');
  var autoRefreshCheck      = $('autoRefreshCheck');
  var settingsHostInfo      = $('settingsHostInfo');

  // Parameter elements
  var paramContainer        = $('paramContainer');
  var paramWatermark        = $('paramWatermark');
  var watermarkTextInput    = $('watermarkTextInput');
  var paramPreset           = $('paramPreset');
  var presetSelect          = $('presetSelect');
  var paramDimensions       = $('paramDimensions');
  var resizeWidthInput      = $('resizeWidthInput');
  var resizeHeightInput     = $('resizeHeightInput');
  var paramLongEdge         = $('paramLongEdge');
  var longEdgeInput         = $('longEdgeInput');
  var paramNoise            = $('paramNoise');
  var noiseAmountInput      = $('noiseAmountInput');

  /* ════════════════════════════════════════════════════════════════════
     APP STATE
  ════════════════════════════════════════════════════════════════════ */
  var state = {
    selectedScript: null,
    activeDoc: null,
    watermarkText: localStorage.getItem('psr_watermark') || 'Rafiqul Islam',
    autoRefresh: localStorage.getItem('psr_autorefresh') !== 'false',
    isExecuting: false
  };

  /* ════════════════════════════════════════════════════════════════════
     EXTENDSCRIPT EVALUATION BRIDGE
  ════════════════════════════════════════════════════════════════════ */
  function evalInHost(code, cb) {
    if (csInterface && typeof csInterface.evalScript === 'function') {
      csInterface.evalScript(code, function (result) {
        if (cb) cb(result);
      });
      return true;
    }
    if (window.__adobe_cep__ && window.__adobe_cep__.evalScript) {
      window.__adobe_cep__.evalScript(code, function (result) {
        if (cb) cb(result);
      });
      return true;
    }
    if (cb) cb(null);
    return false;
  }

  function ensureHostReady(callback) {
    if (!isCEP && !window.__adobe_cep__) {
      if (callback) callback(false);
      return;
    }

    evalInHost('(typeof ProScriptRunner !== "undefined" && ProScriptRunner.isReady && ProScriptRunner.isReady())', function (res) {
      if (res === 'true' || res === true) {
        if (callback) callback(true);
        return;
      }

      // Try loading host bootstrap
      try {
        var extPath = '';
        if (csInterface && typeof csInterface.getSystemPath === 'function') {
          extPath = csInterface.getSystemPath(SystemPath.EXTENSION);
        }
        if (extPath) {
          extPath = extPath.replace(/\\/g, '/');
          var loadCmd = '$.evalFile(new File("' + extPath + '/jsx/host.jsx"))';
          evalInHost(loadCmd, function () {
            evalInHost('(typeof ProScriptRunner !== "undefined" && ProScriptRunner.isReady && ProScriptRunner.isReady())', function (res2) {
              if (callback) callback(res2 === 'true' || res2 === true);
            });
          });
          return;
        }
      } catch (e) {}

      if (callback) callback(false);
    });
  }

  /* ════════════════════════════════════════════════════════════════════
     ACTIVE DOCUMENT SYNCHRONIZATION
  ════════════════════════════════════════════════════════════════════ */
  function queryHostDocumentInfo() {
    if (!isCEP && !window.__adobe_cep__) {
      docName.textContent = 'Standalone Preview Mode';
      docDetails.textContent = 'Running outside Adobe host application. No live document available.';
      docSaveBadge.style.display = 'none';
      return;
    }

    ensureHostReady(function (ready) {
      if (!ready) {
        docName.textContent = isIllustrator ? 'Adobe Illustrator' : 'Adobe Photoshop';
        docDetails.textContent = 'Engine bootstrap in progress. Click refresh to retry.';
        docSaveBadge.style.display = 'none';
        return;
      }

      evalInHost('ProScriptRunner.getHostInfo()', function (raw) {
        if (!raw) return;
        try {
          var data = JSON.parse(raw);
          if (data && data.hasDoc && data.doc) {
            state.activeDoc = data.doc;
            docName.textContent = data.doc.name;
            docSaveBadge.style.display = 'inline-block';
            if (data.doc.saved) {
              docSaveBadge.textContent = 'Saved';
              docSaveBadge.className = 'doc-badge badge-saved';
            } else {
              docSaveBadge.textContent = 'Unsaved';
              docSaveBadge.className = 'doc-badge badge-unsaved';
            }

            if (isIllustrator) {
              docDetails.textContent = data.doc.width + ' × ' + data.doc.height + ' pt • ' +
                                       data.doc.artboards + ' Artboard(s) • ' +
                                       data.doc.items + ' Items';
            } else {
              docDetails.textContent = data.doc.width + ' × ' + data.doc.height + ' px @ ' +
                                       data.doc.resolution + ' ppi • ' +
                                       data.doc.mode + ' (' + data.doc.bits + '-bit)';
            }

            // Prefill resize inputs if open
            if (resizeWidthInput && !resizeWidthInput.value) resizeWidthInput.value = data.doc.width;
            if (resizeHeightInput && !resizeHeightInput.value) resizeHeightInput.value = data.doc.height;
          } else {
            state.activeDoc = null;
            docName.textContent = 'No document open';
            docDetails.textContent = 'Open an image or project in ' + (isIllustrator ? 'Illustrator' : 'Photoshop') + ' to run scripts.';
            docSaveBadge.style.display = 'none';
          }
        } catch (e) {
          docDetails.textContent = 'Status received: ' + String(raw).substring(0, 50);
        }
      });
    });
  }

  /* ════════════════════════════════════════════════════════════════════
     WORKFLOW LIST RENDERING & SEARCH
  ════════════════════════════════════════════════════════════════════ */
  function renderWorkflowList(category, searchQuery) {
    workflowGrid.innerHTML = '';

    var filtered = activeScriptList.filter(function (s) {
      if (category && category !== 'all' && s.cat !== category) return false;
      if (searchQuery) {
        var q = searchQuery.toLowerCase();
        return s.name.toLowerCase().indexOf(q) !== -1 ||
               s.desc.toLowerCase().indexOf(q) !== -1 ||
               s.cat.toLowerCase().indexOf(q) !== -1;
      }
      return true;
    });

    workflowCount.textContent = filtered.length + ' automation(s) available';

    filtered.forEach(function (s) {
      var meta = CATEGORY_META[s.cat] || { icon: '⚙', color: '#94a3b8', bg: '#1e293b' };
      var card = document.createElement('div');
      var isSelected = (state.selectedScript && state.selectedScript.id === s.id);
      card.className = 'workflow-card' + (isSelected ? ' selected' : '');

      card.innerHTML =
        '<div class="wf-icon-box" style="background:' + meta.bg + ';color:' + meta.color + '">' + meta.icon + '</div>' +
        '<div class="wf-text-wrap">' +
          '<div class="wf-name-row">' +
            '<span class="wf-name">' + s.name + '</span>' +
            '<span class="wf-cat-tag" style="background:' + meta.bg + ';color:' + meta.color + '">' + s.cat + '</span>' +
          '</div>' +
          '<div class="wf-desc">' + s.desc + '</div>' +
        '</div>';

      card.addEventListener('click', function () {
        selectScript(s);
      });

      workflowGrid.appendChild(card);
    });
  }

  function selectScript(s) {
    state.selectedScript = s;
    renderWorkflowList(categorySelect.value, scriptSearchInput.value);

    selectedActionName.textContent = s.name;
    selectedActionCat.textContent = s.cat;
    selectedActionDesc.textContent = s.desc;

    // Show/hide parameter controls based on script capabilities
    paramContainer.style.display = s.hasParams ? 'flex' : 'none';
    paramWatermark.style.display = (s.hasParams === 'watermark') ? 'flex' : 'none';
    paramPreset.style.display = (s.hasParams === 'preset') ? 'flex' : 'none';
    paramDimensions.style.display = (s.hasParams === 'dimensions') ? 'flex' : 'none';
    paramLongEdge.style.display = (s.hasParams === 'longEdge') ? 'flex' : 'none';
    paramNoise.style.display = (s.hasParams === 'noise') ? 'flex' : 'none';

    if (s.hasParams === 'watermark') {
      watermarkTextInput.value = state.watermarkText;
    }
    if (s.hasParams === 'dimensions' && state.activeDoc) {
      resizeWidthInput.value = state.activeDoc.width;
      resizeHeightInput.value = state.activeDoc.height;
    }

    actionFooter.style.display = 'block';
  }

  function deselectScript() {
    state.selectedScript = null;
    actionFooter.style.display = 'none';
    renderWorkflowList(categorySelect.value, scriptSearchInput.value);
  }

  /* ════════════════════════════════════════════════════════════════════
     SCRIPT EXECUTION
  ════════════════════════════════════════════════════════════════════ */
  function runSelectedScript() {
    var s = state.selectedScript;
    if (!s) {
      showModal('Notice', 'Please select an automation first.', false);
      return;
    }
    if (state.isExecuting) return;

    // Standalone browser guard
    if (!isCEP && !window.__adobe_cep__) {
      showModal(
        'Standalone Preview Mode',
        'You are viewing this panel in an external web browser.\n\nTo execute "' + s.name + '" on live Photoshop/Illustrator documents, open this panel inside Adobe Photoshop (Window > Extensions > Pro Script Runner).',
        false
      );
      logResult('[STANDALONE] Script requested: ' + s.name + ' (Adobe host not connected)', 'warn');
      return;
    }

    // Build payload with parameters
    var payload = { id: s.id };
    if (s.hasParams === 'watermark') {
      payload.text = watermarkTextInput.value.trim() || state.watermarkText;
    } else if (s.hasParams === 'preset') {
      payload.preset = presetSelect.value;
    } else if (s.hasParams === 'dimensions') {
      payload.width = parseFloat(resizeWidthInput.value) || 1920;
      payload.height = parseFloat(resizeHeightInput.value) || 1080;
    } else if (s.hasParams === 'longEdge') {
      payload.edge = parseFloat(longEdgeInput.value) || 3840;
    } else if (s.hasParams === 'noise') {
      payload.amount = parseFloat(noiseAmountInput.value) || 4;
    }

    state.isExecuting = true;
    runBtn.disabled = true;
    runBtnText.textContent = 'RUNNING...';
    logResult('Executing: ' + s.name + '...', 'info');

    ensureHostReady(function (ready) {
      if (!ready) {
        state.isExecuting = false;
        runBtn.disabled = false;
        runBtnText.textContent = 'RUN AUTOMATION';
        logResult('Failed: ExtendScript host engine not responding.', 'error');
        showModal('Host Error', 'The Adobe ExtendScript engine is not ready. Try restarting Photoshop/Illustrator.', false);
        return;
      }

      var cmd = 'ProScriptRunner.run(' + JSON.stringify(JSON.stringify(payload)) + ')';
      evalInHost(cmd, function (response) {
        state.isExecuting = false;
        runBtn.disabled = false;
        runBtnText.textContent = 'RUN AUTOMATION';

        if (!response) {
          logResult('No response returned from Adobe host.', 'error');
          return;
        }

        if (response.indexOf('PSR_OK') === 0) {
          var successMsg = response.replace(/^PSR_OK\|?/, '');
          logResult(s.name + ' SUCCESS:\n' + (successMsg || 'Operation completed.'), 'success');
          // Re-query document info to reflect changes (e.g. upscaled dimensions, layer count, mode)
          setTimeout(queryHostDocumentInfo, 300);
        } else {
          var errMsg = response.replace(/^PSR_ERR\|?/, '');
          logResult(s.name + ' ERROR: ' + (errMsg || 'Operation failed.'), 'error');
          showModal('Execution Notice', errMsg || 'Operation could not be completed.', false);
        }
      });
    });
  }

  /* ════════════════════════════════════════════════════════════════════
     ACTIVITY LOG
  ════════════════════════════════════════════════════════════════════ */
  function logResult(text, type) {
    if (!resultLog) return;
    var line = document.createElement('div');
    line.className = 'log-line ' + (type || 'info');
    var ts = new Date().toLocaleTimeString();
    line.textContent = '[' + ts + '] ' + text;
    resultLog.appendChild(line);
    resultLog.scrollTop = resultLog.scrollHeight;
  }

  /* ════════════════════════════════════════════════════════════════════
     MODAL DIALOG
  ════════════════════════════════════════════════════════════════════ */
  function showModal(title, msg, showCancel, onOk) {
    modalTitle.textContent = title;
    modalMsg.textContent = msg;
    modalCancel.style.display = showCancel ? 'inline-flex' : 'none';
    modalOverlay.classList.remove('hidden');

    var okHandler = function () {
      modalOverlay.classList.add('hidden');
      modalOk.removeEventListener('click', okHandler);
      if (onOk) onOk();
    };
    modalOk.addEventListener('click', okHandler);
  }

  modalCancel.addEventListener('click', function () {
    modalOverlay.classList.add('hidden');
  });

  /* ════════════════════════════════════════════════════════════════════
     EVENT WIRING
  ════════════════════════════════════════════════════════════════════ */
  // Refresh Document button
  refreshDocBtn.addEventListener('click', function () {
    queryHostDocumentInfo();
    logResult('Document status refreshed.', 'info');
  });

  // Search input
  scriptSearchInput.addEventListener('input', function () {
    clearSearchBtn.style.display = scriptSearchInput.value ? 'inline-block' : 'none';
    renderWorkflowList(categorySelect.value, scriptSearchInput.value);
  });

  clearSearchBtn.addEventListener('click', function () {
    scriptSearchInput.value = '';
    clearSearchBtn.style.display = 'none';
    renderWorkflowList(categorySelect.value, '');
  });

  // Category select
  categorySelect.addEventListener('change', function () {
    renderWorkflowList(categorySelect.value, scriptSearchInput.value);
  });

  // Action Footer controls
  closeActionBtn.addEventListener('click', deselectScript);
  runBtn.addEventListener('click', runSelectedScript);

  // Activity Log Drawer
  clearLogBtn.addEventListener('click', function (e) {
    e.stopPropagation();
    resultLog.innerHTML = '';
  });

  logToggleHeader.addEventListener('click', function () {
    $('logToggleHeader').parentElement.classList.toggle('collapsed');
  });

  // Settings Modal
  settingsBtn.addEventListener('click', function () {
    defaultWatermarkInput.value = state.watermarkText;
    autoRefreshCheck.checked = state.autoRefresh;
    var hostStr = isPhotoshop ? ('Photoshop (' + (appVersion || 'Active') + ')') :
                  (isIllustrator ? ('Illustrator (' + (appVersion || 'Active') + ')') : 'Standalone Browser Preview');
    settingsHostInfo.textContent = hostStr;
    settingsModal.classList.remove('hidden');
  });

  closeSettings.addEventListener('click', function () {
    settingsModal.classList.add('hidden');
  });

  saveSettings.addEventListener('click', function () {
    state.watermarkText = defaultWatermarkInput.value.trim() || 'Rafiqul Islam';
    state.autoRefresh = autoRefreshCheck.checked;
    localStorage.setItem('psr_watermark', state.watermarkText);
    localStorage.setItem('psr_autorefresh', state.autoRefresh ? 'true' : 'false');
    watermarkTextInput.value = state.watermarkText;
    settingsModal.classList.add('hidden');
    logResult('Preferences saved.', 'info');
  });

  // Window Focus event (auto-refresh document info)
  window.addEventListener('focus', function () {
    if (state.autoRefresh) {
      queryHostDocumentInfo();
    }
  });

  /* ════════════════════════════════════════════════════════════════════
     INITIALIZATION
  ════════════════════════════════════════════════════════════════════ */
  function init() {
    defaultWatermarkInput.value = state.watermarkText;

    if (isPhotoshop) {
      hostStatusBadge.textContent = '● Photoshop ' + (appVersion ? appVersion.split('.')[0] : '');
      hostStatusBadge.className = 'host-badge status-online';
      hostNotice.textContent = 'Photoshop Mode';
      categorySelect.value = 'all';
    } else if (isIllustrator) {
      hostStatusBadge.textContent = '● Illustrator ' + (appVersion ? appVersion.split('.')[0] : '');
      hostStatusBadge.className = 'host-badge status-online';
      hostNotice.textContent = 'Illustrator Mode';
      categorySelect.value = 'Illustrator';
    } else {
      hostStatusBadge.textContent = '● Standalone Preview';
      hostStatusBadge.className = 'host-badge status-offline';
      hostNotice.textContent = 'Preview Mode';
    }

    renderWorkflowList(categorySelect.value, '');
    queryHostDocumentInfo();
    logResult('Pro Script Runner v3.1 initialized (' + (appId || 'Standalone') + ').', 'info');
  }

  init();

})();
