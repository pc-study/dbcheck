var API_BASE = (function() {
    var host = window.location.hostname;
    if (host.endsWith('.github.io') || host.endsWith('.pages.dev') || host === 'dbcheck2word.com' || host === 'www.dbcheck2word.com') {
        return 'https://api.dbcheck2word.com';
    }
    return '';
})();
document.getElementById('wechatQrImg').src = API_BASE ? 'wechat-qr.jpg' : '/static/wechat-qr.jpg';
if (!API_BASE) {
    document.querySelectorAll('.carousel-slide').forEach(function(img, i) {
        img.src = '/static/desktop-preview' + (i === 0 ? '' : '-' + (i + 1)) + '.jpg';
    });
}

function showSlide(idx) {
    var slides = document.querySelectorAll('.carousel-slide');
    var dots = document.querySelectorAll('.carousel-dot');
    slides.forEach(function(s, i) {
        s.classList.toggle('active', i === idx);
    });
    dots.forEach(function(d, i) {
        d.classList.toggle('active', i === idx);
    });
}

function toggleNav() {
    document.getElementById('navLinks').classList.toggle('open');
    document.getElementById('navBackdrop').classList.toggle('open');
    document.body.classList.toggle('nav-open');
}

function closeNav() {
    document.getElementById('navLinks').classList.remove('open');
    document.getElementById('navBackdrop').classList.remove('open');
    document.body.classList.remove('nav-open');
}
(function initTheme() {
    var saved = localStorage.getItem('theme');
    if (saved) {
        document.documentElement.setAttribute('data-theme', saved);
    } else {
        document.documentElement.setAttribute('data-theme', window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    }
    updateThemeIcon();
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(e) {
        if (!localStorage.getItem('theme')) {
            document.documentElement.setAttribute('data-theme', e.matches ? 'dark' : 'light');
            updateThemeIcon();
        }
    });
})();

function getEffectiveTheme() {
    var explicit = document.documentElement.getAttribute('data-theme');
    if (explicit) return explicit;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function updateThemeIcon() {
    var btn = document.getElementById('themeToggle');
    if (!btn) return;
    btn.innerHTML = getEffectiveTheme() === 'dark' ? '&#9788;' : '&#9790;';
}

function toggleTheme() {
    var current = getEffectiveTheme();
    var next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('theme', next);
    updateThemeIcon();
}
var _currentLang = (function() {
    var params = new URLSearchParams(window.location.search);
    if (params.get('lang') === 'en') return 'en';
    if (params.get('lang') === 'zh') return 'zh';
    return localStorage.getItem('lang') || 'zh';
})();

function toggleLang() {
    _currentLang = _currentLang === 'zh' ? 'en' : 'zh';
    localStorage.setItem('lang', _currentLang);
    applyLang();
}

function applyLang() {
    document.documentElement.lang = _currentLang === 'zh' ? 'zh-CN' : 'en';
    document.querySelectorAll('[data-' + _currentLang + ']').forEach(function(el) {
        var val = el.getAttribute('data-' + _currentLang);
        if (el.hasAttribute('data-i18n-html')) {
            el.innerHTML = val;
        } else if (el.tagName === 'INPUT') {
            el.placeholder = val;
        } else {
            el.textContent = val;
        }
    });
    var btn = document.getElementById('langToggle');
    if (btn) btn.textContent = _currentLang === 'zh' ? 'EN' : '中文';
    var metaDesc = document.getElementById('metaDesc');
    if (metaDesc) {
        metaDesc.content = _currentLang === 'zh' ? '上传巡检文件，一键生成专业 Word 巡检报告。支持 Oracle/MySQL/PostgreSQL/SQL Server，自动诊断健康指标。' : 'Upload inspection files to auto-generate professional Word reports. Supports Oracle, MySQL, PostgreSQL, SQL Server.';
    }
}
if (_currentLang !== 'zh') applyLang();

function openWechatModal() {
    var modal = document.getElementById('wechatModal');
    modal.style.display = 'flex';
    var focusable = modal.querySelectorAll('button, [href], input, [tabindex]:not([tabindex="-1"])');
    var first = focusable[0];
    var last = focusable[focusable.length - 1];
    if (first) first.focus();
    modal._trapHandler = function(e) {
        if (e.key === 'Tab') {
            if (e.shiftKey && document.activeElement === first) {
                e.preventDefault();
                last.focus();
            } else if (!e.shiftKey && document.activeElement === last) {
                e.preventDefault();
                first.focus();
            }
        }
    };
    modal.addEventListener('keydown', modal._trapHandler);
}

function closeWechatModal() {
    var modal = document.getElementById('wechatModal');
    modal.style.display = 'none';
    if (modal._trapHandler) modal.removeEventListener('keydown', modal._trapHandler);
}

function switchDbScriptTab(dbType, btn) {
    document.querySelectorAll('.scripts-db-tab').forEach(function(t) {
        t.classList.remove('active');
        t.setAttribute('aria-selected', 'false');
    });
    btn.classList.add('active');
    btn.setAttribute('aria-selected', 'true');
    document.querySelectorAll('.scripts-db-panel').forEach(function(p) {
        p.classList.remove('active');
    });
    var panel = document.getElementById('scripts-' + dbType);
    if (panel) panel.classList.add('active'); /* Update howto tabs: show only tabs for this db */
    var allHowtoTabs = document.querySelectorAll('#howtoTabs .scripts-howto-tab');
    allHowtoTabs.forEach(function(t) {
        t.style.display = t.getAttribute('data-db') === dbType ? '' : 'none';
        t.classList.remove('active');
    }); /* Hide all code blocks */
    document.querySelectorAll('.scripts-howto-code').forEach(function(c) {
        c.style.display = 'none';
    }); /* Activate first tab of this db */
    var firstTab = document.querySelector('#howtoTabs .scripts-howto-tab[data-db="' + dbType + '"]');
    if (firstTab) {
        firstTab.classList.add('active');
        var codeId = firstTab.getAttribute('data-code');
        var codeEl = document.getElementById(codeId);
        if (codeEl) codeEl.style.display = '';
    }
}

function switchScriptTab(btn, codeId) {
    btn.parentElement.querySelectorAll('.scripts-howto-tab').forEach(function(t) {
        t.classList.remove('active');
    });
    btn.classList.add('active');
    btn.closest('.scripts-howto').querySelectorAll('.scripts-howto-code').forEach(function(c) {
        c.style.display = 'none';
    });
    document.getElementById(codeId).style.display = '';
}
/* Report type descriptions per database type */
var _reportDescMap = {
    auto: {
        weekly: {
            zh: '常规健康巡检',
            en: 'Regular health check'
        },
        monthly: {
            zh: '深度性能分析',
            en: 'In-depth performance analysis'
        },
        quarterly: {
            zh: '全面巡检（含 OS 层）',
            en: 'Full inspection (incl. OS layer)'
        }
    },
    oracle: {
        weekly: {
            zh: '基础健康检查',
            en: 'Regular periodic inspection'
        },
        monthly: {
            zh: '含性能与 AWR 分析',
            en: 'With performance & AWR analysis'
        },
        quarterly: {
            zh: '含 OS 巡检 + 趋势图表',
            en: 'Includes OS inspection + trend charts'
        }
    },
    mysql: {
        weekly: {
            zh: '基础健康检查',
            en: 'Regular periodic inspection'
        },
        monthly: {
            zh: '含 InnoDB 与性能分析',
            en: 'With InnoDB & performance analysis'
        },
        quarterly: {
            zh: '含 OS 巡检 + 全面诊断',
            en: 'Includes OS inspection + full diagnostics'
        }
    },
    postgres: {
        weekly: {
            zh: '基础健康检查',
            en: 'Regular periodic inspection'
        },
        monthly: {
            zh: '含 Vacuum 与缓存分析',
            en: 'With Vacuum & cache analysis'
        },
        quarterly: {
            zh: '含 OS 巡检 + 全面诊断',
            en: 'Includes OS inspection + full diagnostics'
        }
    },
    sqlserver: {
        weekly: {
            zh: '基础健康检查',
            en: 'Regular periodic inspection'
        },
        monthly: {
            zh: '含等待统计与性能分析',
            en: 'With wait stats & performance analysis'
        },
        quarterly: {
            zh: '含 OS 巡检 + 全面诊断',
            en: 'Includes OS inspection + full diagnostics'
        }
    }
};

function updateReportDescs(dbType) {
    var desc = _reportDescMap[dbType] || _reportDescMap['oracle'];
    var lang = _currentLang || 'zh';
    var wEl = document.getElementById('weeklyDesc');
    var mEl = document.getElementById('monthlyDesc');
    var qEl = document.getElementById('quarterlyDesc');
    if (wEl) {
        wEl.textContent = desc.weekly[lang];
        wEl.setAttribute('data-zh', desc.weekly.zh);
        wEl.setAttribute('data-en', desc.weekly.en);
    }
    if (mEl) {
        mEl.textContent = desc.monthly[lang];
        mEl.setAttribute('data-zh', desc.monthly.zh);
        mEl.setAttribute('data-en', desc.monthly.en);
    }
    if (qEl) {
        qEl.textContent = desc.quarterly[lang];
        qEl.setAttribute('data-zh', desc.quarterly.zh);
        qEl.setAttribute('data-en', desc.quarterly.en);
    }
}
document.querySelectorAll('input[name="dbType"]').forEach(function(radio) {
    radio.addEventListener('change', function() {
        updateReportDescs(this.value);
    });
});
updateReportDescs('auto');
const dropZone = document.getElementById('dropZone');
const fileInput = document.getElementById('fileInput');
dropZone.addEventListener('dragover', function(e) {
    e.preventDefault();
    dropZone.classList.add('drag-over');
});
dropZone.addEventListener('dragleave', function() {
    dropZone.classList.remove('drag-over');
});
dropZone.addEventListener('drop', function(e) {
    e.preventDefault();
    dropZone.classList.remove('drag-over');
    if (e.dataTransfer.files.length) {
        fileInput.files = e.dataTransfer.files;
        updateFileNames(e.dataTransfer.files);
    }
});

var _isDemoFile = false;   // 标记当前文件是否由示例按钮加载

function updateFileNames(files) {
    if (!files || !files.length) return;
    var names = [];
    for (var i = 0; i < files.length; i++) {
        names.push(files[i].name);
    }
    document.getElementById('fileName').textContent = files.length > 1 ? (files.length + (_currentLang === 'en' ? ' files selected' : ' 个文件已选择')) : names[0];
    document.getElementById('fileNameDisplay').style.display = 'flex';
    dropZone.style.display = 'none';
    hideError();
    /* 用户自行上传文件时，清除演示邀请码 */
    if (!_isDemoFile) {
        var codeInput = document.getElementById('inviteCode');
        if (codeInput.value === 'DEMO-TRIAL') {
            codeInput.value = '';
            codeInput.style.borderColor = '#d0d5dd';
            codeInput.style.boxShadow = '';
            var hint = document.getElementById('inviteCodeHint');
            hint.style.display = 'none';
        }
    }
    _isDemoFile = false;
}

function clearFile() {
    fileInput.value = '';
    document.getElementById('fileNameDisplay').style.display = 'none';
    dropZone.style.display = '';
    /* 清除演示邀请码 */
    var codeInput = document.getElementById('inviteCode');
    if (codeInput.value === 'DEMO-TRIAL') {
        codeInput.value = '';
        codeInput.style.borderColor = '#d0d5dd';
        codeInput.style.boxShadow = '';
        document.getElementById('inviteCodeHint').style.display = 'none';
    }
}

function showError(msg) {
    var el = document.getElementById('errorMsg');
    document.getElementById('errorText').textContent = msg;
    el.style.display = 'flex';
    document.getElementById('uploadForm').style.display = '';
}

function hideError() {
    document.getElementById('errorMsg').style.display = 'none';
}
document.getElementById('inviteCode').addEventListener('input', function() {
    this.value = this.value.toUpperCase();
    this.style.borderColor = '#d0d5dd';
    this.style.boxShadow = '';
    document.getElementById('inviteCodeHint').style.display = 'none';
});

function showLoading(show) {
    document.getElementById('loadingOverlay').style.display = show ? 'flex' : 'none';
    if (show) {
        document.getElementById('uploadForm').style.display = 'none';
        var texts = _currentLang === 'en' ? ['Uploading file...', 'Parsing inspection data...', 'Running diagnostics...', 'Generating Word report...'] : ['正在上传文件...', '正在解析巡检数据...', '正在诊断分析...', '正在生成 Word 报告...'];
        var idx = 0;
        var el = document.getElementById('loadingText');
        el.textContent = texts[0];
        window._loadingInterval = setInterval(function() {
            idx = Math.min(idx + 1, texts.length - 1);
            el.textContent = texts[idx];
        }, 4000);
    } else if (window._loadingInterval) {
        clearInterval(window._loadingInterval);
    }
    var pbc = document.getElementById('progressBarContainer');
    if (pbc) {
        pbc.style.display = 'none';
    }
    var pb = document.getElementById('progressBar');
    if (pb) {
        pb.style.width = '0%';
    }
    var pp = document.getElementById('progressPercent');
    if (pp) {
        pp.textContent = '0%';
    }
}
var _isUploading = false;
var _uploadController = null;
async function handleUpload() {
    if (_isUploading) return;
    hideError();
    if (!fileInput.files.length) {
        showError(_currentLang === 'en' ? 'Please select an inspection file first' : '请先选择巡检文件');
        return;
    }
    var isBatch = fileInput.files.length > 1;
    if (!isBatch) {
        var file = fileInput.files[0];
        var name = file.name.toLowerCase();
        if (!name.endsWith('.html') && !name.endsWith('.tar.gz') && !name.endsWith('.tgz') && !name.endsWith('.gz')) {
            showError(_currentLang === 'en' ? 'Only .html, .tar.gz or .tgz files are supported' : '仅支持 .html、.tar.gz、.tgz 格式的文件');
            return;
        }
        if (file.size > 50 * 1024 * 1024) {
            showError(_currentLang === 'en' ? 'File size cannot exceed 50MB' : '文件大小不能超过 50MB');
            return;
        }
    } else {
        for (var fi = 0; fi < fileInput.files.length; fi++) {
            var fn = fileInput.files[fi].name.toLowerCase();
            if (!fn.endsWith('.html') && !fn.endsWith('.tar.gz') && !fn.endsWith('.tgz') && !fn.endsWith('.gz')) {
                showError((_currentLang === 'en' ? 'Unsupported file: ' : '不支持的文件格式: ') + fileInput.files[fi].name);
                return;
            }
        }
        if (fileInput.files.length > 20) {
            showError(_currentLang === 'en' ? 'Maximum 20 files per batch' : '单次最多上传 20 个文件');
            return;
        }
    }
    var reportType = document.querySelector('input[name="reportType"]:checked').value;
    var inviteCode = (document.getElementById('inviteCode').value || '').trim();
    var codeInput = document.getElementById('inviteCode');
    var codeHint = document.getElementById('inviteCodeHint');
    codeInput.style.borderColor = '#d0d5dd';
    codeInput.style.boxShadow = '';
    codeHint.style.display = 'none';
    if (!inviteCode) {
        codeInput.style.borderColor = '#dc2626';
        codeInput.style.boxShadow = '0 0 0 3px rgba(220,38,38,0.12)';
        codeHint.textContent = _currentLang === 'en' ? 'Please enter an invite code. Add WeChat for a free trial code' : '请先输入邀请码，添加微信可免费领取体验码';
        codeHint.style.display = 'block';
        codeInput.focus();
        codeInput.classList.add('shake');
        setTimeout(function() {
            codeInput.classList.remove('shake');
        }, 500);
        return;
    }
    if (!/^[A-Za-z0-9\-]{1,30}$/.test(inviteCode)) {
        codeInput.style.borderColor = '#dc2626';
        codeInput.style.boxShadow = '0 0 0 3px rgba(220,38,38,0.12)';
        codeHint.textContent = _currentLang === 'en' ? 'Invalid invite code format. Only letters, numbers and hyphens allowed' : '邀请码格式无效，仅支持字母、数字和横线';
        codeHint.style.display = 'block';
        codeInput.focus();
        return;
    }
    var btn = document.querySelector('.btn-upload');
    btn.disabled = true;
    btn.innerHTML = '<span class="spinner"></span> ' + (_currentLang === 'en' ? 'Analyzing...' : '正在分析...');
    _isUploading = true;
    if (API_BASE) {
        try {
            var healthCtrl = new AbortController();
            var healthTimeout = setTimeout(function() {
                healthCtrl.abort();
            }, 5000);
            var healthResp = await fetch(API_BASE + '/health', {
                signal: healthCtrl.signal
            });
            clearTimeout(healthTimeout);
        } catch (e) {
            btn.innerHTML = '<span class="spinner-inline"></span> ' + (_currentLang === 'en' ? 'Waking up service...' : '服务唤醒中...');
            btn.classList.add('btn-waking');
            var _wakeStart = Date.now();
            var _wakeTimer = setInterval(function() {
                var elapsed = Math.floor((Date.now() - _wakeStart) / 1000);
                btn.innerHTML = '<span class="spinner-inline"></span> ' + (_currentLang === 'en' ? 'Waking up service... ' + elapsed + 's' : '服务唤醒中... ' + elapsed + 's');
            }, 1000);
            try {
                await fetch(API_BASE + '/health', {
                    signal: AbortSignal.timeout(60000)
                });
                clearInterval(_wakeTimer);
                btn.classList.remove('btn-waking');
            } catch (e2) {
                clearInterval(_wakeTimer);
                btn.classList.remove('btn-waking');
                showError(_currentLang === 'en' ? 'Service temporarily unavailable, please try again later' : '服务暂时不可用，请稍后再试');
                _isUploading = false;
                btn.disabled = false;
                btn.innerHTML = '&#9654; 开始分析';
                document.getElementById('cancelUpload').style.display = 'none';
                _uploadController = null;
                return;
            }
        }
    }
    var formData = new FormData();
    var dbTypeVal = document.querySelector('input[name="dbType"]:checked').value;
    if (isBatch) {
        for (var bi = 0; bi < fileInput.files.length; bi++) {
            formData.append('files', fileInput.files[bi]);
        }
        formData.append('report_type', reportType);
        formData.append('invite_code', inviteCode);
        formData.append('db_type', dbTypeVal);
    } else {
        formData.append('file', file);
        formData.append('report_type', reportType);
        formData.append('invite_code', inviteCode);
        formData.append('db_type', dbTypeVal);
    }
    showLoading(true);
    document.getElementById('resultsPanel').innerHTML = '<div class="skeleton-loader" style="padding:24px;"><div style="height:20px;background:var(--border);border-radius:4px;margin-bottom:16px;animation:skeleton-pulse 1.5s ease-in-out infinite;"></div><div style="height:14px;background:var(--border);border-radius:4px;margin-bottom:12px;width:70%;animation:skeleton-pulse 1.5s ease-in-out infinite;animation-delay:0.2s;"></div><div style="height:14px;background:var(--border);border-radius:4px;margin-bottom:12px;width:85%;animation:skeleton-pulse 1.5s ease-in-out infinite;animation-delay:0.4s;"></div><div style="height:14px;background:var(--border);border-radius:4px;width:60%;animation:skeleton-pulse 1.5s ease-in-out infinite;animation-delay:0.6s;"></div></div>';
    document.getElementById('resultsPanel').style.display = ''; /* Single file: Try WebSocket first */
    if (!isBatch) {
        try {
            var wsResult = await handleUploadWS(file, reportType, inviteCode);
            showLoading(false);
            document.getElementById('cancelUpload').style.display = 'none';
            _uploadController = null;
            _isUploading = false;
            btn.disabled = false;
            btn.innerHTML = '&#9654; 开始分析';
            if (wsResult.success) {
                showResults(wsResult.reports, wsResult.detected_db_type);
            } else {
                showError(wsResult.error || '处理失败');
            }
            return;
        } catch (wsErr) {
            document.getElementById('progressBarContainer').style.display = 'none';
            _wsConnection = null;
        }
    }
    var controller = new AbortController();
    _uploadController = controller;
    document.getElementById('cancelUpload').style.display = '';
    var uploadTimeout = isBatch ? 300000 : 120000;
    var timeoutId = setTimeout(function() {
        controller.abort();
    }, uploadTimeout);
    var uploadUrl = isBatch ? (API_BASE + '/api/upload-batch') : (API_BASE + '/api/upload?report_type=' + encodeURIComponent(reportType));
    try {
        var resp = await fetch(uploadUrl, {
            method: 'POST',
            body: formData,
            signal: controller.signal
        });
        clearTimeout(timeoutId);
        var contentType = resp.headers.get('content-type') || '';
        if (!contentType.includes('application/json')) {
            if (!API_BASE) {
                showError('在线演示服务尚未配置。如需体验，请联系获取桌面专业版，或等待在线服务上线。');
            } else {
                showError('API 服务器返回了非预期的响应，请检查服务是否正常运行。');
            }
            return;
        }
        var data;
        try {
            data = await resp.json();
        } catch (jsonErr) {
            showError('服务器返回了无效的响应数据');
            return;
        }
        if (!resp.ok) {
            var errMsg = (typeof data.detail === 'string' ? data.detail : '') || (typeof data.error === 'string' ? data.error : '') || '请求失败 (' + resp.status + ')';
            showError(errMsg);
            return;
        }
        if (data.success) {
            showResults(data.reports, data.detected_db_type);
            if (isBatch && data.errors && data.errors.length > 0) {
                var errPanel = document.getElementById('resultsPanel');
                var errHtml = '<div class="results-error-panel">';
                errHtml += (_currentLang === 'en' ? '<b>Some files failed:</b><br>' : '<b>以下文件处理失败：</b><br>');
                data.errors.forEach(function(e) {
                    errHtml += escapeHtml(e.filename) + ': ' + escapeHtml(e.error) + '<br>';
                });
                errHtml += '</div>';
                errPanel.innerHTML += errHtml;
            }
        } else {
            showError(data.error || '处理失败，请稍后重试');
        }
    } catch (e) {
        clearTimeout(timeoutId);
        if (e.name === 'AbortError') {
            showError(isBatch ? (_currentLang === 'en' ? 'Request timeout (300s), please try with fewer files' : '请求超时（300秒），请减少文件数量后重试') : (_currentLang === 'en' ? 'Request timeout (120s)' : '请求超时（120秒），请检查网络连接后重试'));
        } else if (!API_BASE) {
            showError('在线演示服务尚未配置。如需体验，请联系获取桌面专业版，或等待在线服务上线。');
        } else {
            showError('网络连接失败，请检查互联网连接后重试');
        }
    } finally {
        showLoading(false);
        _isUploading = false;
        btn.disabled = false;
        btn.innerHTML = '&#9654; 开始分析';
        document.getElementById('cancelUpload').style.display = 'none';
        _uploadController = null;
    }
}

function cancelUpload() {
    if (_wsConnection) {
        try {
            _wsConnection.close();
        } catch (e) {}
        _wsConnection = null;
    }
    if (_uploadController) {
        _uploadController.abort();
        _uploadController = null;
    }
    document.getElementById('cancelUpload').style.display = 'none';
}
/* ITEM_NAMES: per-database check item display names */
var ITEM_NAMES_DB = {
    'oracle': {
        'tablespaces': '表空间使用率',
        'controlfiles': '控制文件',
        'recyleobj': '回收站对象',
        'top10tab': 'Top10 大表',
        'top10idx': 'Top10 大索引',
        'dbinvalid': '无效对象',
        'fknoidx': '外键缺失索引',
        'objsystem': '用户对象在SYSTEM表空间',
        'bitcoincheck': '比特币勒索病毒检查',
        'rmaninfo': 'RMAN 备份',
        'asmdiskinfo': 'ASM 磁盘组',
        'adrcierror': 'ALERT 日志 ORA 错误',
        'pdbstatus': 'PDB 状态',
        'pdbtbsusage': 'PDB 表空间',
        'unifiedaudit': '统一审计',
        'userpasswd': '用户密码安全',
        'seqmaxval': '序列最大值',
        'pwdexpiry': '密码过期检查',
        'stalestats': '统计信息过期',
        'resourcelimit': '资源限制',
        'redologfile': '在线重做日志',
        'redoswitch': '日志切换频率',
        'dgapply': 'DataGuard 同步',
        'dgdeststat': 'DG 目标状态',
        'awrinfo': 'AWR 负载概况',
        'top10event': 'Top10 等待事件',
        'top10sql': 'Top10 SQL',
        'isspfile': 'SPFILE 启动状态',
        'diskusage': '磁盘使用率',
        'freemem': '可用内存',
        'thp': '透明大页',
        'session_count': '会话连接数',
        'lock_waits': '锁等待检测',
        'long_transactions': '长事务检测',
        'temp_usage': '临时空间使用',
        'duplicate_indexes': '重复索引',
        'unused_indexes': '未使用索引',
        'table_fragmentation': '表碎片分析'
    },
    'mysql': {
        'max_connections': '最大连接数',
        'slow_query': '慢查询',
        'innodb_buffer': 'InnoDB 缓冲池',
        'binlog_status': 'Binlog 状态',
        'replication': '主从同步',
        'table_size': '大表检测',
        'index_usage': '索引使用率',
        'user_security': '用户安全',
        'backup_status': '备份状态',
        'diskusage': '磁盘使用率',
        'db_overview': '数据库概览',
        'important_params': '重要参数',
        'process_list': '活跃进程',
        'long_transactions': '长事务',
        'table_no_pk': '无主键表',
        'auto_increment': '自增列检测',
        'redundant_indexes': '冗余索引',
        'storage_engines': '存储引擎分布',
        'global_status_stats': '性能统计',
        'tmp_disk_tables': '临时磁盘表',
        'innodb_status': 'InnoDB 引擎状态',
        'table_fragmentation': '表碎片率',
        'top_sql': 'Top SQL',
        'wait_events': '等待事件',
        'charset_audit': '字符集审计',
        'binlog_summary': 'Binlog 概况',
        'lock_waits': '锁等待',
        'object_stats': '对象统计',
        'gtid_status': 'GTID 状态',
        'semisync_status': '半同步复制状态',
        'repl_filters': '复制过滤规则',
        'binlog_files': 'Binlog 文件',
        'slave_hosts': '从库连接',
        'group_replication': '组复制状态',
        'redo_log_config': 'Redo Log 配置',
        'buffer_pool_hit': '缓冲池命中率',
        'password_policy': '密码策略',
        'table_stats_age': '表统计信息时效',
        'fk_no_index': '外键无索引',
        'undo_history': 'Undo 历史',
        'thread_pool_status': '线程池状态',
        'deadlock_count': '死锁统计',
        'connection_hosts': '连接来源',
        'open_files_usage': '打开文件数',
        'binlog_disk_usage': 'Binlog 磁盘占用',
        'error_log_summary': '错误日志分析'
    },
    'postgres': {
        'tablespace_usage': '表空间使用',
        'connection_count': '连接数',
        'slow_query': '慢查询',
        'vacuum_status': 'Vacuum 状态',
        'replication': '流复制状态',
        'wal_archive': 'WAL 归档',
        'bloat_tables': '膨胀表检测',
        'index_usage': '索引使用率',
        'lock_conflicts': '锁冲突',
        'backup_status': '备份状态',
        'db_size': '数据库大小',
        'extension_list': '扩展列表',
        'diskusage': '磁盘使用率',
        'instance_info': '实例配置',
        'database_detail': '数据库详情',
        'object_count': '对象统计',
        'table_age': '表年龄检测',
        'top_tables_by_size': 'Top大表',
        'cache_hit_ratio': '缓存命中率',
        'bgwriter_stats': '后台写入统计',
        'user_roles': '用户角色',
        'pg_hba_rules': '访问控制规则',
        'unused_indexes_detail': '未使用索引详情',
        'database_stats': '数据库统计',
        'top_sql': 'Top SQL',
        'long_transactions': '长事务',
        'replication_slots': '复制槽',
        'seq_scan_ratio': '顺序扫描分析',
        'temp_file_usage': '临时文件',
        'invalid_indexes': '无效索引',
        'duplicate_indexes': '重复索引',
        'fk_no_index': '外键无索引',
        'autovacuum_running': 'Autovacuum进程',
        'wal_generation': 'WAL生成',
        'ssl_connections': 'SSL连接'
    },
    'sqlserver': {
        'filegroup_usage': '文件组使用',
        'connection_count': '连接数',
        'slow_query': '慢查询',
        'agent_jobs': '代理作业',
        'always_on': 'AlwaysOn 状态',
        'transaction_log': '事务日志',
        'index_fragmentation': '索引碎片',
        'wait_stats': '等待统计',
        'backup_status': '备份状态',
        'security_audit': '安全审计',
        'diskusage': '磁盘使用率',
        'server_config': '服务器配置',
        'database_info': '数据库信息',
        'disk_space': '磁盘IO统计',
        'tempdb_usage': 'TempDB使用',
        'blocking_sessions': '阻塞会话',
        'top_queries_by_cpu': 'Top CPU查询',
        'missing_indexes': '缺失索引',
        'error_log_recent': '错误日志',
        'database_users': '数据库用户',
        'page_life_expectancy': '页面生命周期',
        'buffer_cache_hit_ratio': '缓冲区命中率',
        'plan_cache_hit_ratio': '计划缓存命中率',
        'memory_usage': '内存使用',
        'vlf_counts': 'VLF数量',
        'orphaned_users': '孤立用户',
        'duplicate_indexes': '重复索引',
        'unused_indexes': '未使用索引',
        'statistics_staleness': '统计信息时效',
        'db_scoped_config': '数据库配置',
        'auto_growth_events': '自动增长事件',
        'cpu_usage_history': 'CPU使用历史',
        'io_pending_requests': 'IO挂起请求',
        'object_count': '对象统计',
        'table_no_pk': '无主键表',
        'top_tables_by_size': 'Top大表',
        'inode': 'Inode使用率',
        'thp': '透明大页',
        'sysctl': '内核参数',
        'loadaverage': '系统负载'
    }
};
var ITEM_NAMES = ITEM_NAMES_DB['oracle'];

function friendlyName(key) {
    var dbType = (document.querySelector('input[name="dbType"]:checked') || {}).value || 'oracle';
    if (dbType === 'auto') dbType = 'oracle';
    var names = ITEM_NAMES_DB[dbType] || ITEM_NAMES_DB['oracle'];
    return names[key] || ITEM_NAMES[key] || key;
}

function shortVersion(ver) {
    if (!ver || ver === '-') return '-';
    var m = ver.match(/(\d+[a-z]?)\s.*?(\d+[\d.]+)/i);
    if (m) return m[1] + ' (' + m[2] + ')';
    if (ver.length > 30) return ver.substring(0, 28) + '...';
    return ver;
}

function showResults(reports, detectedDbType) {
    var _DB_TYPE_LABELS = {oracle:'Oracle',mysql:'MySQL',mysql57:'MySQL 5.7',mariadb:'MariaDB',postgres:'PostgreSQL',sqlserver:'SQL Server'};
    document.getElementById('uploadForm').style.display = 'none';
    var panel = document.getElementById('resultsPanel');
    var html = '';
    if (detectedDbType) {
        var detectedLabel = _DB_TYPE_LABELS[detectedDbType] || detectedDbType;
        var isEn = _currentLang === 'en';
        html += '<div class="detected-db-banner">'
            + (isEn ? 'Auto-detected database type: ' : '自动识别数据库类型: ')
            + '<strong>' + escapeHtml(detectedLabel) + '</strong></div>';
    }
    if (!reports || !reports.length) {
        html = '<div class="results-empty"><div style="font-size:48px;opacity:0.3;margin-bottom:16px;">&#128203;</div><p style="font-size:15px;color:var(--text-secondary);">未获取到报告数据</p><p style="font-size:13px;margin-top:8px;color:var(--text-dim);">请检查上传的文件是否为有效的巡检文件</p></div>';
        panel.innerHTML = html;
        panel.style.display = 'block';
        return;
    }
    reports.forEach(function(r, idx) {
        var normalCount = r.normal_count || 0;
        var abnormalCount = r.abnormal_count || 0;
        var abnormals = r.abnormal_items || [];
        var descDetails = r.desc_details || {};
        var problems = r.db_desc || [];
        var downloadFile = r.report_file || '';
        html += '<div' + (idx > 0 ? ' style="margin-top:32px;padding-top:32px;border-top:1px solid var(--border-dim);"' : '') + '>';
        html += '<div class="results-header">';
        html += '<h3>&#128202; ' + (_currentLang === 'en' ? 'Analysis Results' : '分析结果') + (reports.length > 1 ? ' #' + (idx + 1) : '') + '</h3>';
        if (downloadFile) {
            html += '<a class="btn-download" href="' + API_BASE + '/api/download/' + encodeURIComponent(downloadFile) + '">&#11015; ' + (_currentLang === 'en' ? 'Download Report' : '下载 Word 报告') + '</a>';
        }
        html += '</div>';
        var dbType = detectedDbType || (document.querySelector('input[name="dbType"]:checked') || {}).value || 'oracle';
        if (dbType === 'auto') dbType = 'oracle';
        var infoItems = [{
            label: _currentLang === 'en' ? 'Database' : '数据库名称',
            value: r.dbname || '-'
        }];
        if (dbType === 'oracle') {
            infoItems.push({
                label: 'DBID',
                value: r.dbid || '-'
            });
        }
        infoItems.push({
            label: _currentLang === 'en' ? 'Version' : '版本',
            value: shortVersion(r.db_version)
        });
        if (dbType === 'oracle') {
            infoItems.push({
                label: 'RAC',
                value: r.rac || '-'
            });
        }
        infoItems.push({
            label: _currentLang === 'en' ? 'Check Date' : '巡检日期',
            value: r.check_date || '-'
        });
        infoItems.push({
            label: _currentLang === 'en' ? 'Report Type' : '报告类型',
            value: (r.report_type || '-') + (_currentLang === 'en' ? '' : '检')
        });
        html += '<div class="db-info-grid">';
        infoItems.forEach(function(item) {
            html += '<div class="db-info-item"><div class="label">' + item.label + '</div><div class="value">' + escapeHtml(String(item.value)) + '</div></div>';
        });
        html += '</div>';
        html += '<div class="diag-summary">';
        html += '<div class="diag-badge normal"><div class="count">' + normalCount + '</div><div class="desc">' + (_currentLang === 'en' ? 'Normal' : '正常项') + '</div></div>';
        html += '<div class="diag-badge abnormal"><div class="count">' + abnormalCount + '</div><div class="desc">' + (_currentLang === 'en' ? 'Abnormal' : '异常项') + '</div></div>';
        html += '</div>';
        if (abnormals.length) {
            html += '<div class="issue-list"><h4>&#9888; ' + (_currentLang === 'en' ? 'Abnormal Items' : '异常项') + '</h4>';
            abnormals.forEach(function(item) {
                var detail = descDetails[item] || '';
                html += '<div class="issue-item abnormal-item"><span class="issue-dot"></span><div class="issue-content"><span class="issue-name">' + escapeHtml(friendlyName(item)) + '</span>';
                if (detail) {
                    html += '<p class="issue-detail">' + escapeHtml(detail) + '</p>';
                }
                html += '</div></div>';
            });
            html += '</div>';
        }
        if (abnormalCount > 0) {
            var isEn = _currentLang === 'en';
            html += '<div class="summary-section"><h4>&#128161; ' + (isEn ? 'Optimization Recommendations' : '优化建议') + '</h4>';
            html += '<div class="summary-card">';
            html += '<p class="summary-intro">' + (isEn
                ? 'This inspection found <strong>' + abnormalCount + '</strong> abnormal item(s) out of <strong>' + (normalCount + abnormalCount) + '</strong> total checks. Recommended actions:'
                : '本次巡检共检查 <strong>' + (normalCount + abnormalCount) + '</strong> 项，发现 <strong>' + abnormalCount + '</strong> 项异常。建议按以下优先级处理：') + '</p>';
            html += '<div class="summary-priorities">';
            /* 根据异常项类型生成分级建议 */
            var _priorities = {high:[],medium:[],low:[]};
            var _issueAdvice = {
                'adrcierror':     {p:'high',  zh:'排查 ALERT 日志中的 ORA 错误，定位根因并修复，避免潜在的数据库故障',       en:'Investigate ORA errors in ALERT log to prevent potential database failures'},
                'tablespaces':    {p:'high',  zh:'扩展高使用率表空间或清理历史数据，防止空间耗尽导致业务中断',             en:'Expand high-usage tablespaces or purge historical data to prevent outages'},
                'lock_waits':     {p:'high',  zh:'分析当前锁等待链，终止阻塞会话或优化事务粒度',                         en:'Analyze lock wait chains, kill blocking sessions or optimize transaction granularity'},
                'long_transactions':{p:'high',zh:'检查长事务的 SQL 及业务逻辑，避免 UNDO 空间耗尽和锁资源长期占用',       en:'Review long-running transactions to prevent UNDO exhaustion and lock contention'},
                'dgapply':        {p:'high',  zh:'检查 Data Guard 日志传输和应用状态，确保主备库同步正常',                en:'Check Data Guard log transport and apply status for proper synchronization'},
                'userpasswd':     {p:'high',  zh:'立即修改使用默认密码的账户，消除安全隐患',                              en:'Change accounts using default passwords immediately to eliminate security risks'},
                'dbinvalid':      {p:'medium',zh:'重新编译无效对象（ALTER ... COMPILE），恢复依赖模块的正常执行',         en:'Recompile invalid objects to restore dependent module functionality'},
                'fknoidx':        {p:'medium',zh:'为缺失索引的外键列创建索引，避免级联操作导致全表锁等待',                en:'Create indexes on unindexed foreign key columns to avoid full table lock waits'},
                'stalestats':     {p:'medium',zh:'对统计信息过期的表执行 DBMS_STATS 采集，确保优化器生成最优执行计划',    en:'Gather statistics on stale tables to ensure optimal execution plans'},
                'pwdexpiry':      {p:'medium',zh:'处理即将过期的用户密码，避免账户锁定影响业务连接',                      en:'Renew expiring passwords to prevent account lockout'},
                'temp_usage':     {p:'medium',zh:'监控临时表空间使用趋势，必要时扩容以支撑排序和哈希操作',                en:'Monitor temp tablespace usage trend and expand if needed'},
                'session_count':  {p:'medium',zh:'关注会话使用率趋势，必要时调大 PROCESSES/SESSIONS 参数',                en:'Monitor session usage trend and adjust PROCESSES/SESSIONS if needed'},
                'redoswitch':     {p:'low',   zh:'评估日志切换频率，考虑增大 Redo Log 文件以减少切换开销',                en:'Evaluate redo log switch frequency and consider larger redo logs'},
                'unused_indexes': {p:'low',   zh:'评估未使用索引的业务必要性，确认后删除以释放空间和减少 DML 开销',       en:'Evaluate unused indexes and drop confirmed ones to save space and reduce DML overhead'},
                'bitcoincheck':   {p:'high',  zh:'发现勒索病毒特征，立即隔离数据库并启动应急响应',                        en:'Ransomware signatures detected — isolate database and initiate incident response'},
                'seqmaxval':      {p:'low',   zh:'关注高使用率序列，必要时调大 MAXVALUE 防止序列耗尽',                    en:'Monitor high-usage sequences and increase MAXVALUE if needed'},
                'duplicate_indexes':{p:'low', zh:'清理重复索引以减少存储开销和 DML 性能影响',                             en:'Remove duplicate indexes to reduce storage and DML overhead'},
                'table_fragmentation':{p:'low',zh:'对高碎片表执行在线重整（ALTER TABLE MOVE / SHRINK SPACE）',            en:'Defragment high-fragmentation tables with online reorg'}
            };
            abnormals.forEach(function(item) {
                var advice = _issueAdvice[item];
                if (advice) {
                    _priorities[advice.p].push(isEn ? advice.en : advice.zh);
                } else {
                    _priorities.medium.push(isEn ? ('Address: ' + friendlyName(item)) : ('处理 ' + friendlyName(item) + ' 相关异常'));
                }
            });
            var _levelLabels = {
                high:  {zh:'&#128308; 高优先级',  en:'&#128308; High Priority'},
                medium:{zh:'&#128992; 中优先级',  en:'&#128992; Medium Priority'},
                low:   {zh:'&#128311; 低优先级',  en:'&#128311; Low Priority'}
            };
            ['high','medium','low'].forEach(function(level) {
                if (!_priorities[level].length) return;
                var lb = _levelLabels[level];
                html += '<div class="priority-group"><div class="priority-label">' + (isEn ? lb.en : lb.zh) + '</div>';
                html += '<ul class="priority-list">';
                _priorities[level].forEach(function(text) {
                    html += '<li>' + escapeHtml(text) + '</li>';
                });
                html += '</ul></div>';
            });
            html += '</div>';
            html += '<p class="summary-footer">' + (isEn
                ? 'For detailed diagnostics and professional recommendations, download the Word report.'
                : '详细诊断结论和专业处置方案请下载 Word 报告查阅。') + '</p>';
            html += '</div></div>';
        }
        html += '</div>';
    });
    html += '<div class="results-promo-box">';
    html += '<p style="font-size:15px;font-weight:600;color:var(--text-primary);margin-bottom:8px;">' + (_currentLang === 'en' ? 'Need more reports?' : '需要更多报告？') + '</p>';
    html += '<p style="font-size:13px;color:var(--text-secondary);margin-bottom:16px;line-height:1.6;">' + (_currentLang === 'en' ? 'Batch processing, custom templates, offline — one-time purchase, forever' : '批量生成、自定义模板、离线运行 — 桌面专业版一次买断，永久使用') + '</p>';
    html += '<div style="display:flex;gap:12px;justify-content:center;flex-wrap:wrap;">';
    html += '<a href="#pricing" style="padding:8px 20px;background:var(--grad-accent);color:#fff;border-radius:6px;font-size:13px;font-weight:600;text-decoration:none;">' + (_currentLang === 'en' ? 'View Pricing' : '查看定价方案') + '</a>';
    html += '<a href="#desktop" style="padding:8px 20px;background:rgba(59,130,246,0.08);color:var(--text-accent);border-radius:6px;font-size:13px;font-weight:600;text-decoration:none;border:1px solid rgba(59,130,246,0.2);">' + (_currentLang === 'en' ? 'Learn Desktop' : '了解桌面版') + '</a>';
    html += '</div></div>';
    html += '<div style="text-align:center;margin-top:24px;"><button onclick="resetUploadForm()" class="btn btn-outline" style="color:var(--text-primary);border-color:var(--border-subtle);padding:10px 28px;font-size:14px;">' + (_currentLang === 'en' ? 'Generate Another' : '继续生成报告') + '</button></div>';
    panel.innerHTML = html;
    panel.style.display = 'block';
    panel.scrollIntoView({
        behavior: 'smooth',
        block: 'start'
    });
}

function escapeHtml(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
}

function resetUploadForm() {
    clearFile();
    hideError();
    document.getElementById('resultsPanel').style.display = 'none';
    document.getElementById('resultsPanel').innerHTML = '';
    document.getElementById('uploadForm').style.display = '';
    document.getElementById('loadingOverlay').style.display = 'none';
    document.querySelector('.upload-card').scrollIntoView({
        behavior: 'smooth',
        block: 'start'
    });
}
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        var modal = document.getElementById('wechatModal');
        if (modal.style.display === 'flex') {
            modal.style.display = 'none';
        }
    }
});
document.querySelectorAll('.nav-links a').forEach(function(a) {
    a.addEventListener('click', function() {
        closeNav();
    });
});
(function() {
    var el = document.getElementById('heroStats');
    var minDisplay = 10000;
    fetch(API_BASE + '/api/stats').then(function(r) {
        return r.json();
    }).then(function(d) {
        var count = d.total_reports || 0;
        var label = count >= minDisplay ? count + '+' : '1w+';
        var zhText = '已累计生成 ' + label + ' 份巡检报告';
        var enText = label + ' inspection reports generated';
        el.setAttribute('data-zh', zhText);
        el.setAttribute('data-en', enText);
        el.textContent = _currentLang === 'en' ? enText : zhText;
        el.style.display = '';
    }).catch(function() {
        var zhText = '已累计生成 1w+ 份巡检报告';
        var enText = '10,000+ inspection reports generated';
        el.setAttribute('data-zh', zhText);
        el.setAttribute('data-en', enText);
        el.textContent = _currentLang === 'en' ? enText : zhText;
        el.style.display = '';
    });
})();
(function() {
    var el = document.querySelector('.footer-bottom span');
    if (el) el.textContent = '\u00A9 ' + new Date().getFullYear() + ' DBCheck2Word';
})(); /* ===== WebSocket Upload ===== */
var _wsConnection = null;

function getWsUrl() {
    var base = API_BASE || window.location.origin;
    return base.replace(/^http/, 'ws') + '/ws/upload';
}

function updateProgress(percent, text) {
    var bar = document.getElementById('progressBar');
    var pct = document.getElementById('progressPercent');
    var container = document.getElementById('progressBarContainer');
    var lt = document.getElementById('loadingText');
    if (container) container.style.display = '';
    if (bar) bar.style.width = percent + '%';
    if (pct) pct.textContent = percent + '%';
    if (lt && text) lt.textContent = text;
}

function handleUploadWS(file, reportType, inviteCode) {
    return new Promise(function(resolve, reject) {
        var ws;
        try {
            ws = new WebSocket(getWsUrl());
        } catch (e) {
            reject(e);
            return;
        }
        var done = false;
        var timer = setTimeout(function() {
            if (!done) {
                ws.close();
                reject(new Error('timeout'));
            }
        }, 150000);
        ws.onopen = function() {
            ws.send(JSON.stringify({
                report_type: reportType,
                invite_code: inviteCode,
                filename: file.name,
                db_type: (document.querySelector('input[name="dbType"]:checked') || {}).value || 'auto'
            }));
        };
        ws.onmessage = function(ev) {
            try {
                var msg = JSON.parse(ev.data);
            } catch (parseErr) {
                return;
            }
            if (msg.type === 'progress') {
                updateProgress(msg.percent, typeof _currentLang !== 'undefined' && _currentLang === 'en' ? msg.msg_en : msg.msg_zh);
                if (msg.stage === 'ready') {
                    file.arrayBuffer().then(function(buf) {
                        ws.send(buf);
                    });
                }
            } else if (msg.type === 'result') {
                done = true;
                clearTimeout(timer);
                updateProgress(100, _currentLang === 'en' ? 'Complete!' : '完成！');
                resolve(msg);
            } else if (msg.type === 'error') {
                done = true;
                clearTimeout(timer);
                reject(new Error(msg.error));
            }
        };
        ws.onerror = function() {
            if (!done) {
                done = true;
                clearTimeout(timer);
                reject(new Error('ws_failed'));
            }
        };
        ws.onclose = function() {
            if (!done) {
                done = true;
                clearTimeout(timer);
                reject(new Error('ws_closed'));
            }
        };
        _wsConnection = ws;
    });
}
(function() {
    var sections = document.querySelectorAll('section[id]');
    var navLinks = document.querySelectorAll('.nav-links a[href^="#"]');
    var observer = new IntersectionObserver(function(entries) {
        entries.forEach(function(entry) {
            if (entry.isIntersecting) {
                navLinks.forEach(function(link) {
                    link.classList.remove('nav-active');
                    if (link.getAttribute('href') === '#' + entry.target.id) {
                        link.classList.add('nav-active');
                    }
                });
            }
        });
    }, {
        rootMargin: '-30% 0px -70% 0px'
    });
    sections.forEach(function(s) {
        observer.observe(s);
    });
})();

function useSampleFile() {
    fetch(API_BASE + '/api/sample/oracle_demo.html').then(function(r) {
        if (!r.ok) throw new Error('Failed to fetch sample');
        return r.blob();
    }).then(function(blob) {
        var file = new File([blob], 'oracle_demo.html', {
            type: 'text/html'
        });
        var dt = new DataTransfer();
        dt.items.add(file);
        fileInput.files = dt.files;
        _isDemoFile = true;
        updateFileNames(dt.files);
        /* 自动选择 Oracle 数据库类型 */
        var oracleRadio = document.querySelector('input[name="dbType"][value="oracle"]');
        if (oracleRadio) oracleRadio.checked = true;
        /* 自动选择季检报告类型 */
        var quarterlyRadio = document.querySelector('input[name="reportType"][value="季"]');
        if (quarterlyRadio) quarterlyRadio.checked = true;
        var codeInput = document.getElementById('inviteCode');
        codeInput.value = 'DEMO-TRIAL';
        codeInput.style.borderColor = 'var(--accent)';
        codeInput.style.boxShadow = '0 0 0 2px rgba(14,165,233,0.15)';
        var hint = document.getElementById('inviteCodeHint');
        hint.textContent = (_currentLang === 'en' ? 'Demo code auto-filled' : '已自动填入演示邀请码');
        hint.style.display = 'block';
        hint.style.color = 'var(--accent)';
    }).catch(function() {
        showError(_currentLang === 'en' ? 'Failed to load sample file' : '加载示例文件失败，请稍后重试');
    });
}
if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
        navigator.serviceWorker.register('/sw.js').catch(function() {});
    });
}

/* ===== Stats Counter Animation ===== */
(function() {
    var statNums = document.querySelectorAll('.stat-num[data-target]');
    if (!statNums.length) return;

    var animated = false;

    function animateCounters() {
        if (animated) return;
        animated = true;

        // Respect prefers-reduced-motion: show final values immediately
        var prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

        statNums.forEach(function(el) {
            var target = parseInt(el.getAttribute('data-target'), 10);
            var suffix = el.getAttribute('data-suffix') || '';

            if (prefersReduced) {
                el.textContent = target.toLocaleString() + suffix;
                return;
            }

            var duration = 1500;
            var startTime = null;

            function easeOutQuart(t) {
                return 1 - Math.pow(1 - t, 4);
            }

            function step(timestamp) {
                if (!startTime) startTime = timestamp;
                var progress = Math.min((timestamp - startTime) / duration, 1);
                var current = Math.round(easeOutQuart(progress) * target);
                el.textContent = current.toLocaleString() + suffix;
                if (progress < 1) {
                    requestAnimationFrame(step);
                }
            }

            requestAnimationFrame(step);
        });
    }

    if ('IntersectionObserver' in window) {
        var observer = new IntersectionObserver(function(entries) {
            entries.forEach(function(entry) {
                if (entry.isIntersecting) {
                    animateCounters();
                    observer.disconnect();
                }
            });
        }, { threshold: 0.3 });

        var statsBar = document.querySelector('.stats-bar');
        if (statsBar) observer.observe(statsBar);
    } else {
        // Fallback: animate immediately
        animateCounters();
    }
})();

/* ===== Cleanup on page unload ===== */
window.addEventListener('beforeunload', function() {
    if (window._loadingInterval) clearInterval(window._loadingInterval);
    if (_wsConnection) { try { _wsConnection.close(); } catch(e) {} }
});