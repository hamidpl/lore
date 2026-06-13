import { execSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

/**
 * Resolved at build time. Prefers the latest git tag (e.g. `v0.3.1`), and
 * falls back to the plugin manifest version, then a hard-coded default for
 * environments without git history.
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
  return '0.3.1';
}
