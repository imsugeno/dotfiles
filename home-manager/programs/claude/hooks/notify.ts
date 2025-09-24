#!/usr/bin/env node

// Simple notification hook for Claude session events
// This is a basic version - can be extended with actual notification logic

interface HookData {
  session_id: string
  transcript_path: string
  hook_event_name: "Stop" | "Notification"
  stop_hook_active?: boolean
}

async function main() {
  try {
    // Read input from stdin
    let input = ""
    process.stdin.on('data', (chunk) => {
      input += chunk.toString()
    })

    process.stdin.on('end', () => {
      try {
        const data: HookData = JSON.parse(input)

        // Log the event
        const timestamp = new Date().toISOString()
        console.log(`[${timestamp}] Claude session ${data.hook_event_name} event`)
        console.log(`Session ID: ${data.session_id}`)
        console.log(`Transcript: ${data.transcript_path}`)

        // You can add actual notification logic here
        // For example:
        // - Send desktop notification
        // - Log to a file
        // - Send webhook
        // - etc.

      } catch (error) {
        console.error('Failed to parse hook data:', error)
      }
    })

  } catch (error) {
    console.error('Hook error:', error)
    process.exit(1)
  }
}

main()