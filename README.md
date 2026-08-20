# act-athon signup site

- `index.html` — the whole site. edit text directly.
- `thanks.html` — post-submit page.
- `server.py` — optional. `python3 server.py` serves the site on :8490 and appends form posts to `signups.csv`.

For static hosting (github pages / cloudflare pages / netlify), drop `index.html` in and change the
form's `action` to a form backend (formspree, netlify forms, a google form, etc). The static file
alone has no way to store submissions.
