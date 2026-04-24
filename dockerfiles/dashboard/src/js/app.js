/* === PassProtect Dashboard — App Logic === */

(function () {
    'use strict';

    var currentUser = null;
    var currentFilter = 'all';
    var currentItemId = null;

    /* === Datos de la boveda (mock demo) === */
    var vaultItems = [
        {
            id: 'github',
            title: 'GitHub',
            icon: '\u{1F310}',
            username: 'dsegura97@github.com',
            password: 'gh_pat_2fY9kQx7vB3zN1mL8pQwR4tUe6',
            pwdLen: 24,
            strength: 'strong',
            otp: '930 657',
            website: 'https://github.com',
            backup: 'EXTH-1JQP-QLX2-MB6H-K4PZ',
            notes: 'Cuenta principal de desarrollo. 2FA via TOTP + clave de respaldo guardada en caja fuerte fisica.',
            category: 'work',
            tags: ['sso'],
            favorite: true,
            updated: '2026-04-12',
            created: '2024-09-03'
        },
        {
            id: 'email',
            title: 'Email corporativo',
            icon: '\u2709',
            username: 'david@passprotect.es',
            password: 'PP-email$Xk92mNpQrT4vB',
            pwdLen: 20,
            strength: 'strong',
            otp: '214 880',
            website: 'https://mail.passprotect.es',
            backup: 'MAIL-7KP2-LQR3-9XYZ-VBNM',
            notes: 'Cuenta IMAP corporativa. Rotacion obligatoria cada 90 dias.',
            category: 'work',
            tags: ['critical'],
            favorite: true,
            updated: '2026-04-21',
            created: '2024-09-03'
        },
        {
            id: 'vps',
            title: 'VPS Contabo (root)',
            icon: '\u{1F4BB}',
            username: 'root@vps.passprotect.es',
            password: 'contabo-root-!K92pQxRvBnM7zT4wLe8kYuI6',
            pwdLen: 32,
            strength: 'strong',
            otp: null,
            website: 'https://my.contabo.com',
            backup: null,
            notes: 'Acceso SSH solo por clave ed25519. Password de emergencia rotada cada 30 dias.',
            category: 'infra',
            tags: ['critical'],
            favorite: false,
            updated: '2026-04-17',
            created: '2024-10-11'
        },
        {
            id: 'dockerhub',
            title: 'Docker Hub',
            icon: '\u{1F4E6}',
            username: 'dsegura97',
            password: 'docker-push-mQp3Xr7vN',
            pwdLen: 14,
            strength: 'medium',
            otp: null,
            website: 'https://hub.docker.com/u/dsegura97',
            backup: null,
            notes: 'Registry de imagenes PassProtect. Considerar migrar a token con scope acotado.',
            category: 'work',
            tags: [],
            favorite: false,
            updated: '2026-02-20',
            created: '2024-09-15'
        },
        {
            id: 'campus',
            title: 'Campus Virtual ASIR',
            icon: '\u{1F4DA}',
            username: 'david.segura@edu.es',
            password: 'campus-asir-KpQ7mR3',
            pwdLen: 12,
            strength: 'medium',
            otp: null,
            website: null,
            backup: null,
            notes: 'Plataforma Moodle del centro. Rotar antes de fin de curso.',
            category: 'personal',
            tags: [],
            favorite: false,
            updated: '2026-03-22',
            created: '2023-09-14'
        },
        {
            id: 'keycloak',
            title: 'Keycloak Admin',
            icon: '\u{1F511}',
            username: 'admin@corp.local',
            password: 'kc-admin-#Xp9mQ3vBnR7zT4wLe2kYu',
            pwdLen: 28,
            strength: 'strong',
            otp: '476 129',
            website: 'https://auth.passprotect.es',
            backup: 'KCAD-3QP9-RLX7-MB6H-VBZK',
            notes: 'Realm master. Cualquier cambio requiere aprobacion de ambos autores.',
            category: 'infra',
            tags: ['sso', 'critical'],
            favorite: false,
            updated: '2026-04-19',
            created: '2024-11-02'
        },
        {
            id: 'cloudflare',
            title: 'Cloudflare DNS',
            icon: '\u{1F3DB}',
            username: 'devops@passprotect.es',
            password: 'cf-dns-!Kp3Xr7vN9mQ4zTwLe',
            pwdLen: 26,
            strength: 'strong',
            otp: '082 553',
            website: 'https://dash.cloudflare.com',
            backup: 'CFDN-7KP2-LQR3-9XYZ-VBNM',
            notes: 'Zona passprotect.es. Token API dedicado para cert-manager.',
            category: 'work',
            tags: [],
            favorite: false,
            updated: '2026-04-03',
            created: '2024-10-20'
        },
        {
            id: 'banco',
            title: 'Banco (personal)',
            icon: '\u{1F4F1}',
            username: '**** 1234',
            password: 'banco2023',
            pwdLen: 9,
            strength: 'weak',
            otp: null,
            website: null,
            backup: null,
            notes: 'Contrasena debil. Rotar urgente y activar TOTP.',
            category: 'personal',
            tags: [],
            favorite: false,
            updated: '2025-05-18',
            created: '2022-01-10'
        }
    ];

    /* === Login === */
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
        document.getElementById('settings-user').textContent = currentUser.name;
        document.getElementById('settings-role').textContent = currentUser.label;

        var badge = document.getElementById('user-role-badge');
        badge.textContent = currentUser.label;
        badge.className = 'badge ' + (currentUser.role === 'admin' ? 'badge-admin' : 'badge-user');

        var adminElements = document.querySelectorAll('.admin-only');
        for (var i = 0; i < adminElements.length; i++) {
            if (currentUser.role === 'admin') adminElements[i].classList.remove('hidden');
            else adminElements[i].classList.add('hidden');
        }

        showSection('overview');
        renderVault();
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

    /* === SSO placeholder === */
    var ssoBtn = document.getElementById('sso-btn');
    if (ssoBtn) {
        ssoBtn.addEventListener('click', function () {
            alert('SSO con Keycloak: en produccion te redirige a auth.passprotect.es\n\nPara la demo usa admin / usuario.');
        });
    }

    /* === Filtros sidebar === */
    var navEls = document.querySelectorAll('.vault-nav-item');
    for (var f = 0; f < navEls.length; f++) {
        (function (el) {
            el.addEventListener('click', function () {
                for (var k = 0; k < navEls.length; k++) navEls[k].classList.remove('active');
                el.classList.add('active');
                currentFilter = el.getAttribute('data-filter') || 'all';
                renderVault();
            });
        })(navEls[f]);
    }

    /* === Buscador === */
    var vaultSearch = document.getElementById('vault-search');
    if (vaultSearch) vaultSearch.addEventListener('input', renderList);

    /* === Filtrado === */
    function matchesFilter(item) {
        if (currentFilter === 'all') return true;
        if (currentFilter === 'fav') return !!item.favorite;
        if (currentFilter === 'watchtower') return item.strength === 'weak' || item.strength === 'medium';
        if (currentFilter === 'work' || currentFilter === 'personal' || currentFilter === 'infra') {
            return item.category === currentFilter;
        }
        if (currentFilter.indexOf('tag-') === 0) {
            var tag = currentFilter.slice(4);
            return item.tags && item.tags.indexOf(tag) !== -1;
        }
        return true;
    }

    function matchesQuery(item, q) {
        if (!q) return true;
        q = q.toLowerCase();
        return (item.title + ' ' + item.username + ' ' + (item.website || '')).toLowerCase().indexOf(q) !== -1;
    }

    function filteredItems() {
        var q = (vaultSearch && vaultSearch.value || '').trim();
        return vaultItems.filter(function (it) { return matchesFilter(it) && matchesQuery(it, q); });
    }

    /* === Render === */
    function renderVault() {
        renderCounts();
        renderList();
    }

    function renderCounts() {
        var counts = {
            all: vaultItems.length,
            fav: 0,
            watchtower: 0,
            work: 0,
            personal: 0,
            infra: 0,
            'tag-sso': 0,
            'tag-critical': 0
        };
        vaultItems.forEach(function (it) {
            if (it.favorite) counts.fav++;
            if (it.strength === 'weak' || it.strength === 'medium') counts.watchtower++;
            if (counts[it.category] != null) counts[it.category]++;
            (it.tags || []).forEach(function (t) {
                if (counts['tag-' + t] != null) counts['tag-' + t]++;
            });
        });
        for (var i = 0; i < navEls.length; i++) {
            var key = navEls[i].getAttribute('data-filter');
            var span = navEls[i].querySelector('.vault-nav-count');
            if (span && counts[key] != null) span.textContent = counts[key];
        }
    }

    function renderList() {
        var list = document.getElementById('vault-list');
        if (!list) return;
        var items = filteredItems();
        list.innerHTML = '';

        if (items.length === 0) {
            var empty = document.createElement('div');
            empty.className = 'vault-list-empty';
            empty.textContent = 'Sin resultados.';
            list.appendChild(empty);
            renderDetail(null);
            return;
        }

        items.forEach(function (it) {
            var row = document.createElement('div');
            row.className = 'vault-item-row';
            if (it.id === currentItemId) row.classList.add('selected');
            row.innerHTML =
                '<div class="vault-item-icon">' + it.icon +
                    (it.favorite ? '<span class="fav-marker">\u2605</span>' : '') +
                '</div>' +
                '<div class="vault-item-body">' +
                    '<div class="vault-item-title"></div>' +
                    '<div class="vault-item-sub"></div>' +
                '</div>';
            row.querySelector('.vault-item-title').textContent = it.title;
            row.querySelector('.vault-item-sub').textContent = it.username;
            row.addEventListener('click', function () {
                currentItemId = it.id;
                renderList();
                renderDetail(it);
            });
            list.appendChild(row);
        });

        if (!currentItemId || !items.some(function (i) { return i.id === currentItemId; })) {
            currentItemId = items[0].id;
            var first = list.querySelector('.vault-item-row');
            if (first) first.classList.add('selected');
            renderDetail(items[0]);
        }
    }

    function renderDetail(item) {
        var det = document.getElementById('vault-detail');
        if (!det) return;
        if (!item) {
            det.innerHTML = '<div class="vault-detail-empty">Selecciona una entrada para ver el detalle.</div>';
            return;
        }

        var strengthLabel = { strong: 'Fuerte', medium: 'Media', weak: 'Debil' }[item.strength] || '';
        var catLabel = { work: 'Trabajo', personal: 'Personal', infra: 'Infraestructura' }[item.category] || '';

        var html = '';
        html += '<div class="vault-detail-header">';
        html +=   '<div class="vault-detail-icon">' + item.icon +
                    (item.favorite ? '<span class="fav-marker">\u2605</span>' : '') + '</div>';
        html +=   '<div class="vault-detail-title">';
        html +=     '<h2></h2>';
        html +=     '<div class="vault-detail-tag">' + catLabel + '</div>';
        html +=   '</div>';
        html +=   '<button class="vault-detail-fav ' + (item.favorite ? 'active' : '') + '" data-action="toggle-fav">' +
                    (item.favorite ? '\u2605' : '\u2606') + '</button>';
        html += '</div>';

        html += field('username', 'Usuario', item.username, 'copy-user');

        html += '<div class="vault-field">' +
            '<div class="vault-field-label"><span>password</span>' +
              '<span class="vault-field-strength ' + item.strength + '"><span class="dot"></span>' + strengthLabel + ' &middot; ' + item.pwdLen + ' car.</span></div>' +
            '<div class="vault-field-value">' +
              '<span class="value-text secret" data-pwd="' + escapeAttr(item.password) + '">' + mask(item.pwdLen) + '</span>' +
              '<button class="vault-field-action" data-action="toggle-pwd" title="Mostrar">\u{1F441}</button>' +
              '<button class="vault-field-action" data-action="copy-pwd" title="Copiar">\u2398</button>' +
            '</div></div>';

        if (item.otp) {
            html += '<div class="vault-field">' +
              '<div class="vault-field-label"><span>otp</span><span class="vault-field-hint">cambia en <span id="otp-countdown">30</span>s</span></div>' +
              '<div class="vault-field-value">' +
                '<span class="value-text" id="otp-value">' + item.otp + '</span>' +
                '<button class="vault-field-action" data-action="copy-otp" title="Copiar OTP">\u2398</button>' +
              '</div></div>';
        }

        if (item.website) {
            html += '<div class="vault-field">' +
              '<div class="vault-field-label">website</div>' +
              '<div class="vault-field-value website">' +
                '<a class="value-text" href="' + escapeAttr(item.website) + '" target="_blank" rel="noopener"></a>' +
                '<button class="vault-field-action" data-action="copy-url" title="Copiar URL">\u2398</button>' +
              '</div></div>';
        }

        if (item.backup) {
            html += '<div class="vault-field">' +
              '<div class="vault-field-label">backup 2fa code</div>' +
              '<div class="vault-field-value">' +
                '<span class="value-text secret" data-pwd="' + escapeAttr(item.backup) + '">' + mask(item.backup.length) + '</span>' +
                '<button class="vault-field-action" data-action="toggle-backup" title="Mostrar">\u{1F441}</button>' +
                '<button class="vault-field-action" data-action="copy-backup" title="Copiar">\u2398</button>' +
              '</div></div>';
        }

        if (item.notes) {
            html += '<div class="vault-field notes">' +
              '<div class="vault-field-label">notes</div>' +
              '<div class="vault-field-value"></div></div>';
        }

        html += '<div class="vault-detail-footer">' +
            '<span>modified: ' + item.updated + '</span>' +
            '<span>created: ' + item.created + '</span>' +
          '</div>';

        det.innerHTML = html;

        // Inyectar texto como textContent para evitar XSS con títulos/URL/username.
        det.querySelector('.vault-detail-title h2').textContent = item.title;
        var userValue = det.querySelector('.vault-field.username .value-text');
        if (userValue) userValue.textContent = item.username;
        if (item.website) {
            det.querySelector('.vault-field-value.website .value-text').textContent = item.website;
        }
        if (item.notes) {
            det.querySelector('.vault-field.notes .vault-field-value').textContent = item.notes;
        }

        // Binder de acciones
        det.querySelectorAll('[data-action]').forEach(function (btn) {
            btn.addEventListener('click', function (e) { handleDetailAction(e, item); });
        });
    }

    function field(cls, label, value, action) {
        var v = value == null ? '' : String(value);
        return '<div class="vault-field ' + cls + '">' +
            '<div class="vault-field-label">' + label + '</div>' +
            '<div class="vault-field-value">' +
              '<span class="value-text"></span>' +
              (action ? '<button class="vault-field-action" data-action="' + action + '" title="Copiar">\u2398</button>' : '') +
            '</div></div>';
    }

    function handleDetailAction(e, item) {
        var btn = e.currentTarget;
        var act = btn.getAttribute('data-action');
        var valueEl = btn.parentElement.querySelector('.value-text');

        if (act === 'toggle-fav') {
            item.favorite = !item.favorite;
            renderVault();
            toast(item.favorite ? 'Añadida a favoritas' : 'Quitada de favoritas', 'ok');
        } else if (act === 'toggle-pwd' || act === 'toggle-backup') {
            var real = valueEl.getAttribute('data-pwd') || '';
            if (valueEl.classList.contains('secret')) {
                valueEl.textContent = real;
                valueEl.classList.remove('secret');
            } else {
                valueEl.textContent = mask(real.length);
                valueEl.classList.add('secret');
            }
        } else if (act === 'copy-user') {
            copyToClipboard(item.username, 'Usuario copiado');
        } else if (act === 'copy-pwd') {
            copyToClipboard(item.password, 'Contrasena copiada');
        } else if (act === 'copy-otp') {
            copyToClipboard((item.otp || '').replace(/\s/g, ''), 'OTP copiado');
        } else if (act === 'copy-url') {
            copyToClipboard(item.website || '', 'URL copiada');
        } else if (act === 'copy-backup') {
            copyToClipboard(item.backup || '', 'Codigo de respaldo copiado');
        }
    }

    function mask(len) {
        len = Math.max(8, Math.min(len || 12, 24));
        return new Array(len + 1).join('\u2022');
    }

    function escapeAttr(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;')
            .replace(/"/g, '&quot;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
    }

    /* === Toolbar === */
    var newEntryBtn = document.getElementById('new-entry-btn');
    if (newEntryBtn) newEntryBtn.addEventListener('click', function () {
        toast('Nueva entrada: en produccion abre el formulario de Vaultwarden', 'ok');
    });

    var generatorBtn = document.getElementById('generator-btn');
    if (generatorBtn) generatorBtn.addEventListener('click', function () {
        var pwd = generatePassword(20);
        copyToClipboard(pwd, 'Contrasena generada copiada (' + pwd.length + ' car.)');
    });

    var importBtn = document.getElementById('import-btn');
    if (importBtn) importBtn.addEventListener('click', function () {
        toast('Importar: en produccion acepta CSV/JSON de Bitwarden/1Password', 'ok');
    });

    /* === Clipboard + toast === */
    function copyToClipboard(text, okMsg) {
        if (!text) { toast('Campo vacio', 'warn'); return; }
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(text).then(function () {
                toast(okMsg, 'ok');
            }).catch(function () { fallbackCopy(text, okMsg); });
        } else {
            fallbackCopy(text, okMsg);
        }
    }

    function fallbackCopy(text, okMsg) {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand('copy'); toast(okMsg, 'ok'); }
        catch (e) { toast('No se pudo copiar', 'err'); }
        document.body.removeChild(ta);
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

    function generatePassword(len) {
        var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%&*';
        var out = '';
        if (window.crypto && window.crypto.getRandomValues) {
            var arr = new Uint32Array(len);
            window.crypto.getRandomValues(arr);
            for (var i = 0; i < len; i++) out += chars[arr[i] % chars.length];
        } else {
            for (var j = 0; j < len; j++) out += chars[Math.floor(Math.random() * chars.length)];
        }
        return out;
    }

    /* === Logout === */
    document.getElementById('logout-btn').addEventListener('click', function () {
        currentUser = null;
        currentItemId = null;
        document.getElementById('dashboard-screen').classList.add('hidden');
        document.getElementById('login-screen').classList.remove('hidden');
        document.getElementById('login-form').reset();
        showSection('overview');
    });

})();
