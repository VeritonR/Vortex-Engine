// Vortex Engine - GitHub Pages site

(function () {
	// ------------------------------------------------------------------ menu on small screens
	var toggle = document.querySelector('.menu-toggle');
	var nav = document.querySelector('.nav');
	if (toggle && nav) {
		toggle.addEventListener('click', function () {
			var open = nav.classList.toggle('open');
			toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
		});
	}

	var sidebar = document.querySelector('.sidebar');
	var sidebarToggle = document.querySelector('.sidebar-toggle');
	if (sidebar && sidebarToggle) {
		sidebarToggle.addEventListener('click', function () {
			sidebar.classList.toggle('open');
		});
		sidebar.addEventListener('click', function (event) {
			if (event.target.tagName === 'A') sidebar.classList.remove('open');
		});
	}

	// ------------------------------------------------------------------ code: colors and a copy button
	var KEYWORDS = {
		lua: 'function end if then else elseif for in do while repeat until return local and or not nil true false break',
		haxe: 'function var final if else for in while do return new true false null this import class extends static public private override switch case default break continue try catch throw',
		json: 'true false null'
	};

	function escapeHtml(text) {
		return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
	}

	function highlight(code, language) {
		var words = (KEYWORDS[language] || KEYWORDS.lua).split(' ');
		var comment = language === 'lua' ? '--[^\\n]*' : '//[^\\n]*';
		var pattern = new RegExp('(' + comment + ')|("(?:[^"\\\\\\n]|\\\\.)*"|\'(?:[^\'\\\\\\n]|\\\\.)*\')|(\\b\\d+(?:\\.\\d+)?\\b)|([A-Za-z_][A-Za-z0-9_]*)(?=\\s*\\()|([A-Za-z_][A-Za-z0-9_]*)', 'g');
		var out = '';
		var last = 0;
		var match;
		while ((match = pattern.exec(code)) !== null) {
			out += escapeHtml(code.slice(last, match.index));
			if (match[1]) out += '<span class="tok-comment">' + escapeHtml(match[1]) + '</span>';
			else if (match[2]) out += '<span class="tok-string">' + escapeHtml(match[2]) + '</span>';
			else if (match[3]) out += '<span class="tok-number">' + match[3] + '</span>';
			else if (match[4]) out += words.indexOf(match[4]) >= 0 ? '<span class="tok-keyword">' + match[4] + '</span>' : '<span class="tok-func">' + match[4] + '</span>';
			else out += words.indexOf(match[5]) >= 0 ? '<span class="tok-keyword">' + match[5] + '</span>' : match[5];
			last = pattern.lastIndex;
		}
		return out + escapeHtml(code.slice(last));
	}

	document.querySelectorAll('pre > code').forEach(function (block) {
		var language = (block.className.match(/language-(\w+)/) || [])[1];
		var text = block.textContent;
		if (language && language !== 'text') block.innerHTML = highlight(text, language);

		var button = document.createElement('button');
		button.className = 'copy-button';
		button.type = 'button';
		button.textContent = 'Copy';
		button.addEventListener('click', function () {
			var done = function () {
				button.textContent = 'Copied!';
				button.classList.add('done');
				setTimeout(function () { button.textContent = 'Copy'; button.classList.remove('done'); }, 1400);
			};
			if (navigator.clipboard) navigator.clipboard.writeText(text).then(done, function () {});
		});
		block.parentNode.appendChild(button);
	});

	// ------------------------------------------------------------------ search (the Lua API page)
	var search = document.querySelector('.search');
	var empty = document.querySelector('.search-empty');
	if (search) {
		search.addEventListener('input', function () {
			var query = search.value.trim().toLowerCase();
			var shown = 0;
			document.querySelectorAll('.docs-section').forEach(function (section) {
				var entries = section.querySelectorAll('.fn');
				if (entries.length === 0) {
					section.style.display = query ? 'none' : '';
					return;
				}
				var any = false;
				entries.forEach(function (entry) {
					var match = !query || entry.textContent.toLowerCase().indexOf(query) >= 0;
					entry.style.display = match ? '' : 'none';
					if (match) { any = true; shown++; }
				});
				section.style.display = any ? '' : 'none';
			});
			if (empty) empty.style.display = (query && shown === 0) ? 'block' : 'none';
		});
	}

	// ------------------------------------------------------------------ the section being read, lit in the sidebar
	var links = document.querySelectorAll('.sidebar a[href^="#"]');
	if (links.length && 'IntersectionObserver' in window) {
		var byId = {};
		links.forEach(function (link) { byId[link.getAttribute('href').slice(1)] = link; });
		var observer = new IntersectionObserver(function (entries) {
			entries.forEach(function (entry) {
				if (!entry.isIntersecting) return;
				var link = byId[entry.target.id];
				if (!link) return;
				links.forEach(function (other) { other.classList.remove('current'); });
				link.classList.add('current');
			});
		}, { rootMargin: '-80px 0px -70% 0px' });
		Object.keys(byId).forEach(function (id) {
			var target = document.getElementById(id);
			if (target) observer.observe(target);
		});
	}
})();
