#!/usr/bin/env -S deno run --allow-run=osascript

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
const hex = Array.from(new TextEncoder().encode(html))
  .map((b) => b.toString(16).padStart(2, "0"))
  .join("")

const osascript = `set the clipboard to {text:" ", «class HTML»:«data HTML${hex}»}`

const cmd = new Deno.Command("osascript", {
  args: ["-e", osascript],
  stdout: "piped",
  stderr: "piped",
})

const result = await cmd.output()

if (!result.success) {
  const stderr = new TextDecoder().decode(result.stderr)
  console.error(`Failed to copy to clipboard: ${stderr}`)
  Deno.exit(1)
}
