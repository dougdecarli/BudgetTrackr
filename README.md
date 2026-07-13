# BudgetTrackr

BudgetTrackr is an iOS budgeting app built with SwiftUI and SwiftData. It stores
all data on-device and, optionally, syncs it through the user's own iCloud
account via CloudKit — there is no backend, no accounts, and no analytics.

This repository also contains the app's public support website, in
[`docs/`](docs), which is designed to be published with GitHub Pages and used
as the App Store **Support URL** and **Privacy Policy URL**.

## Publishing the site on GitHub Pages

1. Push this repository to GitHub (already configured as `origin` →
   `github.com/dougdecarli/BudgetTrackr`).
2. In the GitHub repo, go to **Settings → Pages**.
3. Under **Build and deployment → Source**, choose **Deploy from a branch**.
4. Set **Branch** to `main` (or your default branch) and the folder to
   **`/docs`**, then click **Save**.
5. GitHub publishes the site at:
   `https://dougdecarli.github.io/BudgetTrackr/`
   (first deploy can take a minute or two; re-check the Pages settings page
   for the live URL).
6. Use these URLs in App Store Connect:
   - Support URL: `https://dougdecarli.github.io/BudgetTrackr/`
   - Privacy Policy URL: `https://dougdecarli.github.io/BudgetTrackr/privacy.html`

No build step is required — the site is plain HTML/CSS/JS served as-is.

## Repository structure

```
FinanceApp/              Xcode project source (SwiftUI + SwiftData app)
FinanceAppTests/         Unit tests
FinanceAppUITests/       UI tests
docs/                    Public GitHub Pages site (support + legal pages)
  index.html             Support page (FAQ, contact)
  privacy.html           Privacy Policy
  terms.html             Terms of Use
  404.html               Custom not-found page
  assets/
    css/style.css        Shared styles (dark-mode-first, light-mode toggle)
    js/main.js            Nav menu, FAQ accordion, theme toggle, reveal animations
    img/                  App icon assets reused for the logo/favicon
```

## Updating the pages

- Edit the relevant `.html` file in `docs/` directly — each page repeats its
  own header/footer markup (there's no build system or templating).
- Shared visual changes (colors, spacing, components) go in
  `docs/assets/css/style.css`.
- The email address and "Last updated" date are hardcoded in each page;
  update them by hand when the content changes.
- Commit and push to `main` — GitHub Pages redeploys automatically within a
  minute or two of a push to the published branch/folder.
- If you rename or move a page, keep `404.html` and the shared nav links in
  every page in sync.
