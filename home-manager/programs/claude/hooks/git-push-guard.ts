#!/usr/bin/env -S deno run --allow-run=git

// Bash の git push のうち、force push と保護ブランチ宛ての push だけを deny する。
// 保護ブランチ = リモートのデフォルトブランチ（origin/HEAD）+ ベース・環境ブランチらしい名前。
// シェルラッパー（bash -c 等）経由は解析しない。autoMode.hard_deny の自然言語ルールで拾う。

interface HookData {
  cwd: string
  tool_input: { command?: string }
}

const PROTECTED =
  /^(main|master|trunk|develop|development|dev|staging|stage|stg|production|prod|release|qa|uat|demo|sandbox)$|^(release|releases|hotfix|env|deploy|production|prod|staging|stg)\//

// 引数を別トークンで取る git push のオプション
const PUSH_OPTS_WITH_ARG = new Set(["-o", "--push-option", "--repo", "--receive-pack", "--exec"])
// 引数を別トークンで取る git のグローバルオプション
const GIT_OPTS_WITH_ARG = new Set(["-C", "-c", "--git-dir", "--work-tree", "--namespace"])

const git = async (cwd: string, ...args: string[]): Promise<string | null> => {
  try {
    const out = await new Deno.Command("git", { args, cwd, stdout: "piped", stderr: "null" }).output()
    return out.success ? new TextDecoder().decode(out.stdout).trim() : null
  } catch {
    return null
  }
}

// 引用符を考慮してトークン化し、&& || ; | 改行 で単純コマンドに分割する
const splitCommands = (command: string): string[][] => {
  const commands: string[][] = []
  let tokens: string[] = []
  let cur = ""
  let inToken = false
  let quote: string | null = null
  const endToken = () => {
    if (inToken) tokens.push(cur)
    cur = ""
    inToken = false
  }
  const endCommand = () => {
    endToken()
    if (tokens.length) commands.push(tokens)
    tokens = []
  }
  for (let i = 0; i < command.length; i++) {
    const c = command[i]
    if (quote) {
      if (c === quote) quote = null
      else if (c === "\\" && quote === '"' && i + 1 < command.length) cur += command[++i]
      else cur += c
    } else if (c === "'" || c === '"') {
      quote = c
      inToken = true
    } else if (c === "\\" && i + 1 < command.length) {
      cur += command[++i]
      inToken = true
    } else if (c === " " || c === "\t") {
      endToken()
    } else if (c === ";" || c === "|" || c === "&" || c === "\n" || c === "(" || c === ")") {
      endCommand()
    } else {
      cur += c
      inToken = true
    }
  }
  endCommand()
  return commands
}

const stripHeads = (ref: string) => ref.replace(/^refs\/heads\//, "")

const isProtected = (branch: string, defaultBranch: string | null) =>
  branch === defaultBranch || PROTECTED.test(branch)

const checkPush = async (cwd: string, args: string[]): Promise<string | null> => {
  const positional: string[] = []
  for (let i = 0; i < args.length; i++) {
    const a = args[i]
    if (a === "--") {
      positional.push(...args.slice(i + 1))
      break
    }
    if (PUSH_OPTS_WITH_ARG.has(a)) {
      i++
      continue
    }
    if (a === "--force" || a.startsWith("--force-with-lease")) {
      return `force push (${a}) は禁止されています`
    }
    if (a === "--all" || a === "--branches" || a === "--mirror") {
      return `${a} は保護ブランチを含みうるため禁止されています`
    }
    if (/^-[^-]/.test(a) && a.slice(1).includes("f")) {
      return `force push (${a}) は禁止されています`
    }
    if (!a.startsWith("-")) positional.push(a)
  }

  const remote = positional[0] ?? "origin"
  const refspecs = positional.slice(1)
  const defaultBranch = (await git(cwd, "symbolic-ref", "--short", `refs/remotes/${remote}/HEAD`))
    ?.replace(new RegExp(`^${remote}/`), "") ?? null
  const current = await git(cwd, "symbolic-ref", "--short", "HEAD")

  const targets: string[] = []
  if (refspecs.length === 0) {
    // 引数なしは upstream（なければ同名ブランチ）へ push される
    if (current) targets.push(current)
    const upstream = await git(cwd, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
    if (upstream) targets.push(upstream.replace(/^[^/]+\//, ""))
  }
  for (const spec of refspecs) {
    if (spec.startsWith("+")) return `force push (${spec}) は禁止されています`
    const dst = spec.includes(":") ? spec.slice(spec.indexOf(":") + 1) : spec
    if (dst.startsWith("refs/tags/")) continue
    targets.push(dst === "HEAD" ? current ?? "HEAD" : stripHeads(dst))
  }

  const hit = targets.find((t) => isProtected(t, defaultBranch))
  return hit ? `保護ブランチ ${hit} への push は禁止されています` : null
}

const main = async () => {
  const input: HookData = JSON.parse(await new Response(Deno.stdin.readable).text())
  const command = input.tool_input.command ?? ""
  if (!/\bgit\b/.test(command) || !/\bpush\b/.test(command)) return

  let cwd = input.cwd
  for (const tokens of splitCommands(command)) {
    let i = 0
    while (i < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[i])) i++
    if (tokens[i] === "cd" && tokens[i + 1]) {
      cwd = tokens[i + 1].startsWith("/") ? tokens[i + 1] : `${cwd}/${tokens[i + 1]}`
      continue
    }
    if (tokens[i] !== "git") continue
    let gitCwd = cwd
    i++
    while (i < tokens.length && tokens[i].startsWith("-")) {
      if (tokens[i] === "-C" && tokens[i + 1]) {
        gitCwd = tokens[i + 1].startsWith("/") ? tokens[i + 1] : `${gitCwd}/${tokens[i + 1]}`
      }
      i += GIT_OPTS_WITH_ARG.has(tokens[i]) ? 2 : 1
    }
    if (tokens[i] !== "push") continue

    const reason = await checkPush(gitCwd, tokens.slice(i + 1))
    if (reason) {
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: `${reason}。ユーザーに実行を依頼してください。`,
        },
      }))
      return
    }
  }
}

await main()
