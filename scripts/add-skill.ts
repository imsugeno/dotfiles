#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write
// GitHub 上で配布されている SKILL.md を直接 fetch して
// home-manager/programs/claude/skills/<name>/ に配置し、
// skills-lock.json を更新する。`npx skills add` は dotfiles の symlink 構造
// （~/.config/claude/skills → home-manager/programs/claude/skills）と噛み合わず
// .agents/skills/ など想定外の場所に配置するため自前で実装している。

import { dirname, fromFileUrl, join } from "jsr:@std/path@1";
import { encodeHex } from "jsr:@std/encoding@1/hex";

const SCRIPT_DIR = dirname(fromFileUrl(import.meta.url));
const REPO_ROOT = dirname(SCRIPT_DIR);
const SKILLS_DIR = join(REPO_ROOT, "home-manager/programs/claude/skills");
const LOCK_FILE = join(REPO_ROOT, "skills-lock.json");

type GithubRef = {
  owner: string;
  repo: string;
  ref: string;
  skillPath: string;
};

type LockEntry = {
  source: string;
  sourceType: "github";
  skillPath: string;
  computedHash: string;
};

type Lock = {
  version: 1;
  skills: Record<string, LockEntry>;
};

function parseGithubUrl(input: string): GithubRef {
  const url = new URL(input);
  if (url.hostname !== "github.com") {
    throw new Error(`unsupported host: ${url.hostname}`);
  }
  const parts = url.pathname.split("/").filter(Boolean);
  if (parts.length < 4 || (parts[2] !== "tree" && parts[2] !== "blob")) {
    throw new Error(
      `URL must be https://github.com/<owner>/<repo>/(tree|blob)/<ref>/<path>: ${input}`,
    );
  }
  const [owner, repo, kind, ref, ...rest] = parts;
  let skillPath = rest.join("/");
  if (kind === "tree") {
    skillPath = skillPath ? `${skillPath}/SKILL.md` : "SKILL.md";
  } else if (!skillPath.endsWith("SKILL.md")) {
    throw new Error(`blob URL must point to SKILL.md: ${input}`);
  }
  return { owner, repo, ref, skillPath };
}

async function fetchSkill(ref: GithubRef): Promise<string> {
  const url =
    `https://raw.githubusercontent.com/${ref.owner}/${ref.repo}/${ref.ref}/${ref.skillPath}`;
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`failed to fetch ${url}: ${res.status} ${res.statusText}`);
  }
  return await res.text();
}

function parseSkillName(content: string): string {
  const m = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n/);
  if (!m) throw new Error("SKILL.md does not contain YAML frontmatter");
  const nameMatch = m[1].match(/^name:\s*(.+?)\s*$/m);
  if (!nameMatch) throw new Error("frontmatter does not contain 'name'");
  return nameMatch[1].trim();
}

async function sha256Hex(content: string): Promise<string> {
  const buf = new TextEncoder().encode(content);
  const digest = await crypto.subtle.digest("SHA-256", buf);
  return encodeHex(new Uint8Array(digest));
}

async function loadLock(): Promise<Lock> {
  try {
    const text = await Deno.readTextFile(LOCK_FILE);
    return JSON.parse(text);
  } catch (e) {
    if (e instanceof Deno.errors.NotFound) return { version: 1, skills: {} };
    throw e;
  }
}

async function saveLock(lock: Lock): Promise<void> {
  const sorted: Lock = { version: lock.version, skills: {} };
  for (const k of Object.keys(lock.skills).sort()) sorted.skills[k] = lock.skills[k];
  await Deno.writeTextFile(LOCK_FILE, JSON.stringify(sorted, null, 2) + "\n");
}

async function main() {
  const [urlArg] = Deno.args;
  if (!urlArg) {
    console.error(
      "Usage: deno run --allow-net --allow-read --allow-write scripts/add-skill.ts <github-url>",
    );
    Deno.exit(2);
  }
  const ref = parseGithubUrl(urlArg);
  const content = await fetchSkill(ref);
  const name = parseSkillName(content);
  const hash = await sha256Hex(content);

  const dir = join(SKILLS_DIR, name);
  await Deno.mkdir(dir, { recursive: true });
  await Deno.writeTextFile(join(dir, "SKILL.md"), content);

  const lock = await loadLock();
  lock.skills[name] = {
    source: `${ref.owner}/${ref.repo}`,
    sourceType: "github",
    skillPath: ref.skillPath,
    computedHash: hash,
  };
  await saveLock(lock);
  console.log(
    `Installed skill '${name}' from ${ref.owner}/${ref.repo}@${ref.ref}:${ref.skillPath}`,
  );
}

if (import.meta.main) await main();
