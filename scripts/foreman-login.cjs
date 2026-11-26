'use strict';

// Captures a Foreman (foreman.mn) browser session token for use with
// `foreman-api --bearer`. Foreman logs in through SSO (Okta), so the
// credentials can't be scripted: this opens a real (headed) Chromium, you
// complete SSO by hand, and it watches the network for the first
// `Authorization: Bearer` header the dashboard sends to a *.foreman.mn
// backend. That token is written straight into the login Keychain; it is
// never printed (only its length is) and never leaves this machine.
// Restricting to foreman.mn hosts means the Okta bearer is ignored.
//
// The browser is ephemeral: a throwaway profile in a temp dir that Playwright
// removes on close, so no SSO session is left on disk (you log in each run).
// Background networking (Google component updates, safebrowsing, variations)
// is disabled so the throwaway profile only talks to the sites you visit.
//
// Driven by the `foreman-login` wrapper in home-darwin.nix, which sets
// PLAYWRIGHT_BROWSERS_PATH and NODE_PATH to the nix-provided Playwright.

const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const os = require('os');

const DASHBOARD = process.env.FOREMAN_DASHBOARD_URL || 'https://dashboard.foreman.mn';
const SERVICE = process.env.FOREMAN_SESSION_SERVICE || 'foreman-session';
const TIMEOUT_MS = (Number(process.env.FOREMAN_LOGIN_TIMEOUT) || 300) * 1000;

// Cut Chromium's chatter to Google so the throwaway profile only contacts the
// SSO and Foreman hosts you actually navigate to.
const CHROMIUM_ARGS = [
  '--disable-background-networking',
  '--disable-component-update',
  '--disable-domain-reliability',
  '--disable-sync',
  '--no-default-browser-check',
  '--no-first-run',
  '--metrics-recording-only',
  '--disable-features=OptimizationHints,MediaRouter',
];

function hostIsForeman(url) {
  try {
    return new URL(url).hostname.endsWith('foreman.mn');
  } catch {
    return false;
  }
}

function store(token) {
  execFileSync(
    '/usr/bin/security',
    ['add-generic-password', '-U', '-a', os.userInfo().username, '-s', SERVICE, '-w', token],
    { stdio: ['ignore', 'ignore', 'inherit'] },
  );
}

(async () => {
  // Ephemeral: launch() uses a throwaway profile dir that Playwright deletes
  // on close, so no SSO session persists on disk.
  const browser = await chromium.launch({ headless: false, args: CHROMIUM_ARGS });
  const ctx = await browser.newContext();
  let done = false;

  const finish = async (token, where) => {
    if (done) return;
    done = true;
    store(token);
    console.error(
      `foreman-login: captured bearer token (${token.length} chars) from ${where}; ` +
        `stored in Keychain service "${SERVICE}". Use it with: foreman-api --bearer <path>`,
    );
    await browser.close().catch(() => {});
    process.exit(0);
  };

  ctx.on('request', (req) => {
    const auth = req.headers()['authorization'];
    if (auth && /^Bearer\s+\S/i.test(auth) && hostIsForeman(req.url())) {
      let host = req.url();
      try { host = new URL(req.url()).host; } catch {}
      finish(auth.replace(/^Bearer\s+/i, '').trim(), `${req.method()} ${host}`);
    }
  });

  const page = await ctx.newPage();
  await page.goto(DASHBOARD, { waitUntil: 'domcontentloaded' }).catch(() => {});
  console.error(
    'foreman-login: complete the SSO login in the browser window. ' +
      'Waiting for the dashboard to make an authenticated foreman.mn API call…',
  );

  setTimeout(async () => {
    if (done) return;
    console.error(
      'foreman-login: timed out with no bearer token seen. If you were already ' +
        'logged in, click around the dashboard so it refetches, then re-run. If ' +
        'the token turns out to be a cookie rather than a header, tell the agent.',
    );
    await browser.close().catch(() => {});
    process.exit(1);
  }, TIMEOUT_MS).unref?.();
})().catch((err) => {
  console.error('foreman-login:', err && err.message ? err.message : err);
  process.exit(1);
});
