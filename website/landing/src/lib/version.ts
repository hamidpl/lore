import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

/**
 * Resolved at build time. Prefers the latest git tag (e.g. `v0.7.0`), and falls
 * back to the plugin manifest version.
 *
 * There is deliberately no third, hard-coded fallback. It used to return `'0.3.1'`,
 * which is a real past release — so a broken checkout shipped a plausible-looking
 * wrong version badge instead of failing. Both paths above are reliable (CI checks
 * out with `fetch-depth: 0` for tags, and the manifest is always in the repo), so
 * reaching the end means the checkout is broken and the build should say so.
 */
export function getVersion(): string {
  try {
    const tag = execSync('git describe --tags --abbrev=0', {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    if (tag) return tag.replace(/^v/, '');
  } catch {
    /* no git / no tags — fall through */
  }
  try {
    const manifest = JSON.parse(
      readFileSync(
        new URL('../../../../plugins/lore/.claude-plugin/plugin.json', import.meta.url),
        'utf8',
      ),
    );
    if (manifest.version) return String(manifest.version);
  } catch {
    /* manifest unavailable — fall through */
  }
  throw new Error(
    'getVersion(): could not resolve a version from either a git tag or ' +
      'plugins/lore/.claude-plugin/plugin.json. Refusing to guess — a wrong version ' +
      'badge on the site is worse than a failed build.',
  );
}
