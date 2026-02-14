#!/usr/bin/env -S deno run --allow-read --allow-env

// Constants
const COMPACTION_THRESHOLD = 200000 // Opus 4.5の制限

// Nerd Font icons
const ICONS = {
  token: "󰓅",      // nf-md-speedometer
  cache: "󰜺",      // nf-md-cached
  warning: "󰀪",    // nf-md-alert_circle
  danger: "󰀦",     // nf-md-alert_octagon
  check: "󰗠",      // nf-md-check_circle
}

// Helper function to format token count
function formatTokenCount(tokens: number): string {
  if (tokens >= 1000000) {
    return `${(tokens / 1000000).toFixed(1)}M`
  } else if (tokens >= 1000) {
    return `${(tokens / 1000).toFixed(1)}K`
  }
  return tokens.toString()
}

// Generate progress bar
function generateProgressBar(percentage: number, width: number = 10): string {
  const filled = Math.round((percentage / 100) * width)
  const empty = width - filled

  const filledChar = "█"
  const emptyChar = "░"

  return filledChar.repeat(filled) + emptyChar.repeat(empty)
}

// Function to calculate tokens from transcript
async function calculateTokensFromTranscript(filePath: string): Promise<{
  totalTokens: number
  cacheTokens: number
}> {
  try {
    const content = await Deno.readTextFile(filePath)
    const lines = content.trim().split("\n")

    let lastUsage = null

    for (const line of lines) {
      try {
        const entry = JSON.parse(line)
        if (entry.type === "assistant" && entry.message?.usage) {
          lastUsage = entry.message.usage
        }
      } catch {
        // Skip invalid JSON lines
      }
    }

    if (lastUsage) {
      const totalTokens =
        (lastUsage.input_tokens || 0) +
        (lastUsage.output_tokens || 0) +
        (lastUsage.cache_creation_input_tokens || 0) +
        (lastUsage.cache_read_input_tokens || 0)

      const cacheTokens =
        (lastUsage.cache_creation_input_tokens || 0) +
        (lastUsage.cache_read_input_tokens || 0)

      return { totalTokens, cacheTokens }
    }

    return { totalTokens: 0, cacheTokens: 0 }
  } catch {
    return { totalTokens: 0, cacheTokens: 0 }
  }
}

// Read JSON input from stdin
const decoder = new TextDecoder()
const input = decoder.decode(
  await Deno.stdin.readable
    .getReader()
    .read()
    .then((r) => r.value),
)
const data = JSON.parse(input)

// Extract values
const sessionId = data.session_id
const transcriptPath = data.transcript_path

// Calculate token usage for current session
let result = { totalTokens: 0, cacheTokens: 0 }

// Try to get tokens from transcript file
if (transcriptPath) {
  try {
    const stat = await Deno.stat(transcriptPath)
    if (stat.isFile) {
      result = await calculateTokensFromTranscript(transcriptPath)
    }
  } catch {
    // Transcript file doesn't exist or can't be read
  }
} else if (sessionId) {
  // Fallback: Find transcript file for the current session
  const projectsDir = `${Deno.env.get("HOME")}/.claude/projects`

  try {
    for await (const entry of Deno.readDir(projectsDir)) {
      if (entry.isDirectory) {
        const transcriptFile = `${projectsDir}/${entry.name}/${sessionId}.jsonl`

        try {
          const stat = await Deno.stat(transcriptFile)
          if (stat.isFile) {
            result = await calculateTokensFromTranscript(transcriptFile)
            break
          }
        } catch {
          // File doesn't exist in this project, continue
        }
      }
    }
  } catch {
    // Projects directory doesn't exist or other error
  }
}

// Output with Nerd Font icons and progress bar
const { totalTokens, cacheTokens } = result

if (totalTokens > 0) {
  const tokenDisplay = formatTokenCount(totalTokens)
  const percentage = Math.min(100, Math.round((totalTokens / COMPACTION_THRESHOLD) * 100))
  const progressBar = generateProgressBar(percentage)

  const { color, icon } = (() => {
    if (percentage >= 90) {
      return { color: "\x1b[31m", icon: ICONS.danger }
    }
    if (percentage >= 70) {
      return { color: "\x1b[33m", icon: ICONS.warning }
    }
    return { color: "\x1b[32m", icon: ICONS.check }
  })()

  // Show cache info if cache tokens exist
  const cacheInfo = cacheTokens > 0
    ? ` ${ICONS.cache} ${formatTokenCount(cacheTokens)}`
    : ""

  console.log(
    `${icon} ${ICONS.token} ${tokenDisplay} ${color}[${progressBar}] ${percentage}%\x1b[0m${cacheInfo}`
  )
} else {
  console.log(`${ICONS.check} ${ICONS.token} 0 \x1b[32m[░░░░░░░░░░] 0%\x1b[0m`)
}
