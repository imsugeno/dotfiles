#!/usr/bin/env -S deno run

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

// Read JSON input from stdin
const decoder = new TextDecoder()
const input = decoder.decode(
  await Deno.stdin.readable
    .getReader()
    .read()
    .then((r) => r.value),
)
const data = JSON.parse(input)

// Extract context_window from stdin data
const ctx = data.context_window

const usedPercentage = ctx?.used_percentage ?? 0
const currentUsage = ctx?.current_usage ?? {}

// Input tokens (matching Claude Code's calculation: input_tokens + cache tokens)
const inputTokens = (currentUsage.input_tokens ?? 0)
  + (currentUsage.cache_creation_input_tokens ?? 0)
  + (currentUsage.cache_read_input_tokens ?? 0)

const cacheTokens = (currentUsage.cache_creation_input_tokens ?? 0)
  + (currentUsage.cache_read_input_tokens ?? 0)

// Output with Nerd Font icons and progress bar
if (inputTokens > 0) {
  const tokenDisplay = formatTokenCount(inputTokens)
  const percentage = Math.min(100, usedPercentage)
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
