/* === PassProtect Dashboard — App Logic (Pentesting) === */

(function () {
    'use strict';

    var currentUser = null;
    var pentestData = null; // cache de los 6 JSONs

    /* === Login decorativo (demo manual) ==============================
     * Solo "admin" o "usuario" sin validar password real. Es un fallback
     * para demos sin SSO. La auth real va por oauth2-proxy + Keycloak
     * (tryAutoSSO mas abajo). Este form NUNCA es la unica capa: en prod,
     * oauth2-proxy intercepta cualquier peticion ANTES de servir el HTML.
     * ============================================================ */
    document.getElementById('login-form').addEventListener('submit', function (e) {
        e.preventDefault();
        var username = document.getElementById('username').value.trim().toLowerCase();
        var password = document.getElementById('password').value;
        if (!username || !password) return;
        if (username === 'admin') {
            currentUser = { name: 'dsegura', role: 'admin', label: 'Administrador' };
        } else if (username === 'usuario') {
            currentUser = { name: 'mgarcia', role: 'user', label: 'Usuario' };
        } else {
            alert('Usuario no reconocido. Usa "admin" o "usuario".');
            return;
        }
        initDashboard();
    });

    /* === Init Dashboard === */
    function initDashboard() {
        document.getElementById('login-screen').classList.add('hidden');
        document.getElementById('dashboard-screen').classList.remove('hidden');

        document.getElementById('user-display').textContent = currentUser.name;

        var badge = document.getElementById('user-role-badge');
        badge.textContent = currentUser.label;
        badge.className = 'badge ' + (currentUser.role === 'admin' ? 'badge-admin' : 'badge-user');

        showSection('overview');
        loadAndRenderPentest();
    }

    /* === Navigation === */
    var navItems = document.querySelectorAll('.nav-item');
    for (var ni = 0; ni < navItems.length; ni++) {
        navItems[ni].addEventListener('click', function () {
            showSection(this.getAttribute('data-section'));
        });
    }

    function showSection(name) {
        var sections = document.querySelectorAll('.section');
        for (var i = 0; i < sections.length; i++) sections[i].classList.add('hidden');
        var target = document.getElementById('section-' + name);
        if (target) target.classList.remove('hidden');
        var items = document.querySelectorAll('.nav-item');
        for (var j = 0; j < items.length; j++) {
            items[j].classList.remove('active');
            if (items[j].getAttribute('data-section') === name) items[j].classList.add('active');
        }
    }

    /* === SSO real via oauth2-proxy ============================
     * El dashboard está detrás de oauth2-proxy. Si hay sesión OIDC
     * activa, /oauth2/userinfo devuelve email + groups del JWT que
     * Keycloak emitió. Si no, redirige a /oauth2/sign_in.
     * ========================================================= */

    function ssoLogin() {
        window.location.href = '/oauth2/sign_in?rd=' +
            encodeURIComponent(window.location.pathname);
    }

    function ssoLogout() {
        var kcLogout = 'https://auth.passprotect.es/realms/corporativo/protocol/openid-connect/logout' +
                       '?post_logout_redirect_uri=' + encodeURIComponent('https://dashboard.passprotect.es/');
        window.location.href = '/oauth2/sign_out?rd=' + encodeURIComponent(kcLogout);
    }

    var ssoBtn = document.getElementById('sso-btn');
    if (ssoBtn) ssoBtn.addEventListener('click', ssoLogin);

    function tryAutoSSO() {
        fetch('/oauth2/userinfo', {
            headers: { 'Accept': 'application/json' },
            credentials: 'same-origin'
        })
        .then(function (r) {
            if (!r.ok) throw new Error('no-sso-session');
            return r.json();
        })
        .then(function (data) {
            var email = data.email || data.user || data.preferredUsername || 'sso-user';
            var username = (data.preferredUsername) ||
                           (typeof email === 'string' && email.indexOf('@') > -1
                              ? email.split('@')[0]
                              : email);
            var groups = data.groups || [];
            // Keycloak emite los groups con o sin "/" prefijo segun el mapper
            // (tree path vs nombre). Aceptamos las dos formas para no depender
            // de cual mapper este activo en el realm
            var isAdmin = groups.some(function (g) {
                return g === 'vw-admins' || g === '/vw-admins' ||
                       g === 'it-dept'   || g === '/it-dept';
            });
            currentUser = {
                name: username,
                email: email,
                role: isAdmin ? 'admin' : 'user',
                label: isAdmin ? 'Administrador (SSO)' : 'Usuario (SSO)'
            };
            initDashboard();
        })
        .catch(function () {
            console.log('[SSO] no active session — falling back to manual login');
        });
    }
    tryAutoSSO();

    /* === Logout === */
    document.getElementById('logout-btn').addEventListener('click', function () {
        if (currentUser && (currentUser.label || '').indexOf('SSO') > -1) {
            ssoLogout();
            return;
        }
        currentUser = null;
        document.getElementById('dashboard-screen').classList.add('hidden');
        document.getElementById('login-screen').classList.remove('hidden');
        document.getElementById('login-form').reset();
        showSection('overview');
    });

    /* ===========================================================
     * Pentesting: carga y render de los 6 JSONs en src/data/
     * =========================================================== */

    function loadAndRenderPentest() {
        var files = ['summary', 'ssl', 'trivy', 'nikto', 'waf', 'fail2ban'];
        Promise.all(files.map(function (f) {
            return fetch('data/' + f + '.json', { credentials: 'same-origin' })
                .then(function (r) {
                    if (!r.ok) throw new Error('No se pudo cargar ' + f);
                    return r.json();
                });
        }))
        .then(function (results) {
            pentestData = {
                summary:  results[0],
                ssl:      results[1],
                trivy:    results[2],
                nikto:    results[3],
                waf:      results[4],
                fail2ban: results[5]
            };
            renderOverview(pentestData.summary);
            renderSsl(pentestData.ssl);
            renderTrivy(pentestData.trivy);
            renderNikto(pentestData.nikto);
            renderWaf(pentestData.waf);
            renderFail2ban(pentestData.fail2ban);
        })
        .catch(function (err) {
            console.error('[Pentest] error cargando datos:', err);
            toast('Error cargando datos del pentest', 'err');
        });
    }

    /* === Overview === */
    function renderOverview(data) {
        if (!data) return;
        var kpis = data.kpi || {};
        var grid = document.getElementById('overview-kpis');
        if (grid) {
            var cards = [
                kpiCard('Calificacion SSL', kpis.sslGrade),
                kpiCard('CVEs criticos', kpis.criticalCves),
                kpiCard('CVEs altos', kpis.highCves),
                kpiCard('Hallazgos Nikto', kpis.niktoFindings),
                kpiCard('Bloqueos WAF', kpis.wafBlocks),
                kpiCard('Baneos Fail2ban', kpis.fail2banBans)
            ];
            grid.innerHTML = cards.join('');
        }
        var tbody = document.querySelector('#overview-tools tbody');
        if (tbody) {
            tbody.innerHTML = (data.tools || []).map(function (t) {
                var st = statusBadge(t.status);
                return '<tr>' +
                    '<td>' + escapeHtml(t.name) + '</td>' +
                    '<td>' + escapeHtml(t.category) + '</td>' +
                    '<td>' + st + '</td>' +
                  '</tr>';
            }).join('');
        }
        var note = document.getElementById('overview-note');
        if (note && data.note) {
            note.textContent = data.note;
        }
    }

    function kpiCard(label, kpi) {
        if (!kpi) return '';
        var status = kpi.status || 'ok';
        var cls = 'stat-card stat-' + (status === 'ok' ? 'green' : status === 'warn' ? 'yellow' : 'red');
        return '<div class="' + cls + '">' +
            '<div class="stat-number">' + escapeHtml(String(kpi.value)) + '</div>' +
            '<div class="stat-label">' + escapeHtml(label) + '</div>' +
        '</div>';
    }

    function statusBadge(status) {
        if (status === 'ok')      return '<span class="status-ok">OK</span>';
        if (status === 'warn')    return '<span class="status-warn">Aviso</span>';
        if (status === 'fail')    return '<span class="status-err">Fallo</span>';
        if (status === 'pending') return '<span class="status-warn">Pendiente</span>';
        return '<span>' + escapeHtml(status || '') + '</span>';
    }

    /* === SSL / TLS === */
    function renderSsl(data) {
        if (!data) return;
        var container = document.getElementById('ssl-cards');
        if (!container) return;
        container.innerHTML = (data.endpoints || []).map(function (ep) {
            var grade = ep.grade || '?';
            var gradeClass = grade.indexOf('A') === 0 ? 'grade-a' : grade === 'B' ? 'grade-b' : 'grade-c';
            var cert = ep.certificate || {};
            var vulns = ep.vulnerabilities || {};
            var vulnRows = Object.keys(vulns).map(function (k) {
                var ok = vulns[k] === false;
                return '<tr><td>' + escapeHtml(k) + '</td><td>' +
                    (ok ? '<span class="status-ok">No vulnerable</span>' : '<span class="status-err">VULNERABLE</span>') +
                    '</td></tr>';
            }).join('');
            return '<div class="ssl-card">' +
                '<div class="ssl-card-head">' +
                    '<div class="ssl-host">' + escapeHtml(ep.host) + '</div>' +
                    '<div class="ssl-grade ' + gradeClass + '">' + escapeHtml(grade) + '</div>' +
                '</div>' +
                '<div class="ssl-meta">' +
                    '<div><span>IP</span><strong>' + escapeHtml(ep.ip || '-') + '</strong></div>' +
                    '<div><span>Cifrado</span><strong>' + escapeHtml(ep.cipherStrength || '-') + '</strong></div>' +
                    '<div><span>HSTS</span><strong>' + (ep.hsts ? 'Si (' + (ep.hstsMaxAge || 0) + 's)' : 'No') + '</strong></div>' +
                    '<div><span>OCSP Stapling</span><strong>' + (ep.ocspStapling ? 'Si' : 'No') + '</strong></div>' +
                '</div>' +
                '<div class="ssl-section"><h4>Certificado</h4>' +
                    '<p><strong>Emisor:</strong> ' + escapeHtml(cert.issuer || '-') + '</p>' +
                    '<p><strong>Sujeto:</strong> ' + escapeHtml(cert.subject || '-') + '</p>' +
                    '<p><strong>Valido:</strong> ' + escapeHtml(cert.validFrom || '-') + ' &rarr; ' + escapeHtml(cert.validTo || '-') + '</p>' +
                    '<p><strong>Clave:</strong> ' + escapeHtml(cert.keyType || '') + ' ' + (cert.keySize || '') + ' bits</p>' +
                '</div>' +
                '<div class="ssl-section"><h4>Protocolos</h4>' +
                    '<p><strong>Activos:</strong> ' + (ep.protocols || []).map(escapeHtml).join(', ') + '</p>' +
                    '<p><strong>Deshabilitados:</strong> ' + (ep.protocolsDisabled || []).map(escapeHtml).join(', ') + '</p>' +
                '</div>' +
                '<div class="ssl-section"><h4>Vulnerabilidades probadas</h4>' +
                    '<table class="table-mini"><tbody>' + vulnRows + '</tbody></table>' +
                '</div>' +
            '</div>';
        }).join('');
        if (!container.innerHTML) {
            container.innerHTML = '<p class="info-text">Sin datos. Ejecuta el scan de SSL Labs para popular esta seccion.</p>';
        }
    }

    /* === Trivy === */
    function renderTrivy(data) {
        if (!data) return;
        var summary = data.summary || {};
        var grid = document.getElementById('trivy-summary');
        if (grid) {
            grid.innerHTML = [
                kpiCard('Critical', { value: summary.critical || 0, status: (summary.critical || 0) > 0 ? 'fail' : 'ok' }),
                kpiCard('High',     { value: summary.high     || 0, status: (summary.high     || 0) > 0 ? 'warn' : 'ok' }),
                kpiCard('Medium',   { value: summary.medium   || 0, status: 'ok' }),
                kpiCard('Low',      { value: summary.low      || 0, status: 'ok' }),
                kpiCard('Imagenes',  { value: summary.imagesScanned || 0, status: 'ok' })
            ].join('');
        }
        var tbody = document.querySelector('#trivy-table tbody');
        if (tbody) {
            tbody.innerHTML = (data.images || []).map(function (img) {
                var status = (img.critical || 0) > 0 ? 'fail' :
                             (img.high     || 0) > 0 ? 'warn' :
                             img.scanDate ? 'ok' : 'pending';
                return '<tr>' +
                    '<td><code>' + escapeHtml(img.name) + '</code></td>' +
                    '<td>' + escapeHtml(img.size || '-') + '</td>' +
                    '<td>' + sevCell(img.critical, 'red') + '</td>' +
                    '<td>' + sevCell(img.high, 'yellow') + '</td>' +
                    '<td>' + (img.medium || 0) + '</td>' +
                    '<td>' + (img.low || 0) + '</td>' +
                    '<td>' + statusBadge(status) + '</td>' +
                '</tr>';
            }).join('');
        }
    }

    function sevCell(n, color) {
        n = n || 0;
        if (n === 0) return '<span class="sev-zero">0</span>';
        return '<span class="sev sev-' + color + '">' + n + '</span>';
    }

    /* === Nikto === */
    function renderNikto(data) {
        if (!data) return;
        var container = document.getElementById('nikto-cards');
        if (!container) return;
        container.innerHTML = (data.scans || []).map(function (sc) {
            var findings = sc.findings || [];
            var findingsHtml = findings.length === 0
                ? '<p class="status-ok">Sin hallazgos.</p>'
                : '<table class="table-mini"><thead><tr><th>Severidad</th><th>OSVDB</th><th>Descripcion</th></tr></thead><tbody>' +
                    findings.map(function (f) {
                        return '<tr>' +
                            '<td>' + statusBadge(f.severity || 'warn') + '</td>' +
                            '<td>' + escapeHtml(f.id || '-') + '</td>' +
                            '<td>' + escapeHtml(f.description || '-') + '</td>' +
                        '</tr>';
                    }).join('') +
                  '</tbody></table>';
            var headers = (sc.headersOk || []).map(function (h) {
                return '<span class="chip chip-ok">' + escapeHtml(h) + '</span>';
            }).join(' ');
            return '<div class="panel">' +
                '<h3><code>' + escapeHtml(sc.host) + '</code></h3>' +
                '<p class="info-text"><strong>Scan:</strong> ' + escapeHtml(sc.scanDate || 'pendiente') +
                    (sc.duration ? ' &middot; <strong>Duracion:</strong> ' + escapeHtml(sc.duration) : '') + '</p>' +
                '<h4>Hallazgos</h4>' + findingsHtml +
                '<h4>Headers de seguridad presentes</h4>' +
                '<div class="chips-row">' + (headers || '<span class="info-text">Sin datos</span>') + '</div>' +
            '</div>';
        }).join('');
    }

    /* === WAF === */
    function renderWaf(data) {
        if (!data) return;
        var s = data.summary || {};
        var grid = document.getElementById('waf-summary');
        if (grid) {
            var byType = s.byType || {};
            grid.innerHTML = [
                kpiCard('Total peticiones', { value: s.totalRequests || 0, status: 'ok' }),
                kpiCard('Bloqueadas',       { value: s.blocked || 0,        status: 'ok' }),
                kpiCard('SQLi',             { value: byType.sqli || 0,      status: (byType.sqli || 0) > 0 ? 'warn' : 'ok' }),
                kpiCard('XSS',              { value: byType.xss || 0,       status: (byType.xss || 0) > 0 ? 'warn' : 'ok' }),
                kpiCard('Scanner detectado',{ value: byType.scanner || 0,   status: (byType.scanner || 0) > 0 ? 'warn' : 'ok' })
            ].join('');
        }
        var log = document.getElementById('waf-log');
        if (log) {
            var blocks = data.blocks || [];
            if (blocks.length === 0) {
                log.innerHTML = '<div class="log-line"><span class="log-time">--</span> <span class="log-ok">[INFO]</span> Sin bloqueos registrados aun.</div>';
            } else {
                log.innerHTML = blocks.map(function (b) {
                    return '<div class="log-line">' +
                        '<span class="log-time">' + escapeHtml(b.timestamp || '--') + '</span> ' +
                        '<span class="log-warn">[BLOCK]</span> ' +
                        escapeHtml((b.attackType || '?').toUpperCase()) + ' desde ' +
                        '<code>' + escapeHtml(b.sourceIp || '?') + '</code> ' +
                        '&mdash; rule ' + escapeHtml(String(b.ruleId || '?')) + ' ' +
                        '(severity ' + escapeHtml(String(b.severity || '?')) + ')' +
                    '</div>';
                }).join('');
            }
        }
    }

    /* === Fail2ban === */
    function renderFail2ban(data) {
        if (!data) return;
        var s = data.summary || {};
        var grid = document.getElementById('fail2ban-summary');
        if (grid) {
            grid.innerHTML = [
                kpiCard('Bans totales',  { value: s.totalBans  || 0, status: 'ok' }),
                kpiCard('Bans activos',  { value: s.activeBans || 0, status: (s.activeBans || 0) > 0 ? 'warn' : 'ok' }),
                kpiCard('Intentos',      { value: s.totalAttempts || 0, status: 'ok' }),
                kpiCard('Jails activos', { value: s.jailsActive || (data.jails || []).filter(function (j) { return j.active; }).length, status: 'ok' })
            ].join('');
        }
        var jails = document.querySelector('#fail2ban-jails tbody');
        if (jails) {
            jails.innerHTML = (data.jails || []).map(function (j) {
                return '<tr>' +
                    '<td><strong>' + escapeHtml(j.name) + '</strong></td>' +
                    '<td><code>' + escapeHtml(j.filter) + '</code></td>' +
                    '<td>' + (j.maxretry || '-') + '</td>' +
                    '<td>' + escapeHtml(j.findtime || '-') + '</td>' +
                    '<td>' + escapeHtml(j.bantime || '-') + '</td>' +
                    '<td>' + (j.currentBans || 0) + '</td>' +
                    '<td>' + (j.totalBans || 0) + '</td>' +
                '</tr>';
            }).join('');
        }
        var bans = document.querySelector('#fail2ban-bans tbody');
        if (bans) {
            var recent = data.recentBans || [];
            if (recent.length === 0) {
                bans.innerHTML = '<tr><td colspan="6" class="info-text">Sin baneos recientes.</td></tr>';
            } else {
                bans.innerHTML = recent.map(function (b) {
                    return '<tr>' +
                        '<td><code>' + escapeHtml(b.ip) + '</code></td>' +
                        '<td>' + escapeHtml(b.jail || '-') + '</td>' +
                        '<td>' + escapeHtml(b.bannedAt || '-') + '</td>' +
                        '<td>' + escapeHtml(b.country || '-') + '</td>' +
                        '<td>' + (b.attempts || '-') + '</td>' +
                        '<td>' + (b.active ? '<span class="status-warn">Activo</span>' : '<span class="status-ok">Liberado</span>') + '</td>' +
                    '</tr>';
                }).join('');
            }
        }
    }

    /* === Helpers === */
    // escapeHtml en TODA interpolacion de datos del JSON: los .json son fuentes
    // de datos confiables hoy, pero si maniana se generan desde herramientas
    // externas (trivy json, nikto json), un payload XSS en una descripcion CVE
    // podria ejecutarse en el browser sin esto
    function escapeHtml(s) {
        if (s == null) return '';
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function toast(msg, kind) {
        var container = document.querySelector('.toast-container');
        if (!container) {
            container = document.createElement('div');
            container.className = 'toast-container';
            document.body.appendChild(container);
        }
        var el = document.createElement('div');
        el.className = 'toast toast-' + (kind || 'ok');
        el.textContent = msg;
        container.appendChild(el);
        requestAnimationFrame(function () { el.classList.add('show'); });
        setTimeout(function () {
            el.classList.remove('show');
            setTimeout(function () { el.remove(); }, 250);
        }, 2400);
    }

})();
