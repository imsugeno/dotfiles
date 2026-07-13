#!/usr/bin/env -S deno run --allow-run --allow-env

interface HookData {
  session_id: string
  transcript_path: string
  hook_event_name: "Notification"
  notification_type?:
    | "permission_prompt"
    | "idle_prompt"
    | "auth_success"
    | "elicitation_dialog"
    | "elicitation_complete"
    | "elicitation_response"
    | "agent_needs_input"
    | "agent_completed"
  message?: string
}

const main = async () => {
  const input = await new Response(Deno.stdin.readable).text()

  try {
    const data: HookData = JSON.parse(input)

    const currentDir = Deno.cwd()

    // Check if current directory is a git repository
    const gitCheckProcess = new Deno.Command("git", {
      args: ["rev-parse", "--is-inside-work-tree"],
      stdout: "piped",
      stderr: "piped",
    })

    const gitCheckResult = await gitCheckProcess.output()
    const isGitRepo =
      gitCheckResult.success && new TextDecoder().decode(gitCheckResult.stdout).trim() === "true"

    let repoInfo = ""

    if (isGitRepo) {
      // Get repository name from git remote
      const remoteProcess = new Deno.Command("git", {
        args: ["remote", "get-url", "origin"],
        stdout: "piped",
        stderr: "piped",
      })

      const remoteResult = await remoteProcess.output()
      const remoteUrl = new TextDecoder().decode(remoteResult.stdout).trim()

      let repoName = ""
      if (remoteUrl && remoteResult.success) {
        // Extract repo name from URL (supports both HTTPS and SSH formats)
        const match = remoteUrl.match(/[/:]([^/]+?)(?:\.git)?$/)
        repoName = match ? match[1] : ""
      }

      // Fallback to directory name if no git remote
      if (!repoName) {
        repoName = currentDir.split("/").pop() || ""
      }

      // Get current branch name
      const branchProcess = new Deno.Command("git", {
        args: ["branch", "--show-current"],
        stdout: "piped",
        stderr: "piped",
      })

      const branchResult = await branchProcess.output()
      const branchName = new TextDecoder().decode(branchResult.stdout).trim()

      repoInfo = branchName ? `${repoName} (${branchName})` : repoName
    } else {
      // Not a git repository, use directory name
      repoInfo = currentDir.split("/").pop() || ""
    }

    const body = data.message ?? "Notification 🔔"

    const process = new Deno.Command("osascript", {
      args: [
        "-e",
        `display notification "${body}" with title "⚡ Claude Code" subtitle "${repoInfo} 📦" sound name "Glass"`,
      ],
      stdout: "piped",
      stderr: "piped",
    })

    const result = await process.output()

    // Debug: log the osascript execution result
    console.error(`Debug: osascript exit code: ${result.code}`)
    if (result.stdout.length > 0) {
      console.error(`Debug: osascript stdout: ${new TextDecoder().decode(result.stdout)}`)
    }
    if (result.stderr.length > 0) {
      console.error(`Debug: osascript stderr: ${new TextDecoder().decode(result.stderr)}`)
    }

    console.log(JSON.stringify({ success: true }))
  } catch (error) {
    console.log(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
    )

    const process = new Deno.Command("osascript", {
      args: ["-e", 'display notification "Hook Failed !" with title "Claude Code Error 🚨" sound name "Glass"'],
      stdout: "piped",
      stderr: "piped",
    })

    await process.output()
  }
}

await main()