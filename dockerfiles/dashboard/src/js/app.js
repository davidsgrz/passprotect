/* === PassProtect Dashboard — App Logic === */

(function () {
    'use strict';

    var currentUser = null;

    /* --- Login --- */
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

    /* --- Init Dashboard --- */
    function initDashboard() {
        document.getElementById('login-screen').classList.add('hidden');
        document.getElementById('dashboard-screen').classList.remove('hidden');

        // User info
        document.getElementById('user-display').textContent = currentUser.name;
        document.getElementById('settings-user').textContent = currentUser.name;
        document.getElementById('settings-role').textContent = currentUser.label;

        var badge = document.getElementById('user-role-badge');
        badge.textContent = currentUser.label;
        badge.className = 'badge ' + (currentUser.role === 'admin' ? 'badge-admin' : 'badge-user');

        // Show/hide admin sections
        var adminElements = document.querySelectorAll('.admin-only');
        for (var i = 0; i < adminElements.length; i++) {
            if (currentUser.role === 'admin') {
                adminElements[i].classList.remove('hidden');
            } else {
                adminElements[i].classList.add('hidden');
            }
        }

        // Show overview by default
        showSection('overview');
    }

    /* --- Navigation --- */
    var navItems = document.querySelectorAll('.nav-item');
    for (var i = 0; i < navItems.length; i++) {
        navItems[i].addEventListener('click', function () {
            var section = this.getAttribute('data-section');
            showSection(section);
        });
    }

    function showSection(name) {
        // Hide all sections
        var sections = document.querySelectorAll('.section');
        for (var i = 0; i < sections.length; i++) {
            sections[i].classList.add('hidden');
        }

        // Show target
        var target = document.getElementById('section-' + name);
        if (target) target.classList.remove('hidden');

        // Update nav active state
        var items = document.querySelectorAll('.nav-item');
        for (var j = 0; j < items.length; j++) {
            items[j].classList.remove('active');
            if (items[j].getAttribute('data-section') === name) {
                items[j].classList.add('active');
            }
        }
    }

    /* --- SSO placeholder (demo) --- */
    var ssoBtn = document.getElementById('sso-btn');
    if (ssoBtn) {
        ssoBtn.addEventListener('click', function () {
            alert('SSO con Keycloak: en produccion te redirige a auth.passprotect.es\n\nPara la demo usa admin / usuario.');
        });
    }

    /* --- Filtros de boveda (visual) --- */
    var vaultFilters = document.querySelectorAll('.vault-filter');
    for (var f = 0; f < vaultFilters.length; f++) {
        vaultFilters[f].addEventListener('click', function () {
            for (var k = 0; k < vaultFilters.length; k++) {
                vaultFilters[k].classList.remove('active');
            }
            this.classList.add('active');
        });
    }

    /* --- Toggle favoritas --- */
    var favBtns = document.querySelectorAll('.vault-card-fav');
    for (var v = 0; v < favBtns.length; v++) {
        favBtns[v].addEventListener('click', function (e) {
            e.stopPropagation();
            this.classList.toggle('active');
            this.textContent = this.classList.contains('active') ? '\u2605' : '\u2606';
        });
    }

    /* --- Logout --- */
    document.getElementById('logout-btn').addEventListener('click', function () {
        currentUser = null;
        document.getElementById('dashboard-screen').classList.add('hidden');
        document.getElementById('login-screen').classList.remove('hidden');
        document.getElementById('login-form').reset();

        // Reset nav
        showSection('overview');
    });

})();
