#!/usr/bin/env -S deno run --allow-run=textutil,pbcopy

import { marked } from "marked"

// Read markdown from stdin
const input = await new Response(Deno.stdin.readable).text()

// --- Pre-processing for Slack ---

let md = input

// 1. Extract code blocks to protect from transformation
const codeBlocks: string[] = []
md = md.replace(/```[\s\S]*?```/g, (match) => {
  codeBlocks.push(match)
  return `%%CODEBLOCK_${codeBlocks.length - 1}%%`
})

// Also protect inline code
const inlineCodes: string[] = []
md = md.replace(/`[^`]+`/g, (match) => {
  inlineCodes.push(match)
  return `%%INLINECODE_${inlineCodes.length - 1}%%`
})

// 2. Tables → code blocks (before heading conversion)
md = md.replace(
  /^(\|.+\|)\n(\|[-| :]+\|)\n((?:\|.+\|\n?)*)/gm,
  (_match, header: string, _sep: string, body: string) => {
    const rows = [header, ...body.trim().split("\n")]
    return "```\n" + rows.join("\n") + "\n```"
  },
)

// 3. Images → links
md = md.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, "[$1]($2)")

// 4. Task lists → emoji
md = md.replace(/^(\s*[-*])\s+\[ \]/gm, "$1 ☐")
md = md.replace(/^(\s*[-*])\s+\[[xX]\]/gm, "$1 ✅")

// 5. Horizontal rules (line must be only dashes/asterisks/underscores, 3+)
md = md.replace(/^-{3,}\s*$/gm, "———")
md = md.replace(/^\*{3,}\s*$/gm, "———")
md = md.replace(/^_{3,}\s*$/gm, "———")

// 6. Headings → bold (Slack doesn't support headings)
md = md.replace(/^#{1,6}\s+(.+)$/gm, "**$1**")

// 7. Restore inline code
md = md.replace(/%%INLINECODE_(\d+)%%/g, (_match, i: string) => inlineCodes[parseInt(i)])

// 8. Restore code blocks
md = md.replace(/%%CODEBLOCK_(\d+)%%/g, (_match, i: string) => codeBlocks[parseInt(i)])

// --- Convert to HTML ---
const html = await marked(md)

// --- Copy as rich text to clipboard ---
// Slack reads the RTF flavor, not HTML. Convert HTML → RTF with textutil,
// then hand the RTF to pbcopy so the clipboard carries a real RTF flavor.
// The charset meta is required or textutil garbles non-ASCII text.
async function run(command: string, args: string[], stdin: Uint8Array) {
  const cmd = new Deno.Command(command, {
    args,
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  })
  const child = cmd.spawn()
  const writer = child.stdin.getWriter()
  await writer.write(stdin)
  await writer.close()
  const result = await child.output()
  if (!result.success) {
    const stderr = new TextDecoder().decode(result.stderr)
    console.error(`${command} failed: ${stderr}`)
    Deno.exit(1)
  }
  return result.stdout
}

const htmlBytes = new TextEncoder().encode(`<meta charset="utf-8">${html}`)
const rtf = await run("textutil", ["-stdin", "-format", "html", "-convert", "rtf", "-stdout"], htmlBytes)
await run("pbcopy", ["-Prefer", "rtf"], rtf)
