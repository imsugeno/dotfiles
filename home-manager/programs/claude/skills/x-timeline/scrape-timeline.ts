#!/usr/bin/env -S deno run --allow-net --allow-read --allow-write --allow-run=security --allow-env --allow-ffi

/**
 * X (Twitter) タイムラインスクレイパー
 *
 * Arc または Chrome のブラウザ Cookie ストアから認証情報を自動取得し、
 * X の内部 GraphQL API でタイムラインを取得する。
 *
 * 注意: X の内部 API は非公式。queryId やフィーチャーフラグが変更される可能性がある。
 */

import { Database } from "jsr:@db/sqlite@^0.12"
import { ClientTransaction, handleXMigration } from "jsr:@lami/x-client-transaction-id"

// ─── 型定義 ────────────────────────────────────────────────────────────────────

interface Tweet {
  id: string
  url: string
  author: string
  authorName: string
  text: string
  likes: number
  retweets: number
  createdAt: string
  engagement: number
}

interface BrowserProfile {
  name: string
  cookieDbPath: string
  keychainService: string
  keychainAccount: string
}

// ─── 定数 ──────────────────────────────────────────────────────────────────────

// X Web App に埋め込まれた公開ベアラートークン（静的値、ユーザー固有ではない）
const X_BEARER_TOKEN =
  "AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA"

// HomeTimeline GraphQL クエリID（X が新しいコードをデプロイすると変わる場合がある）
const GRAPHQL_QUERY_ID = "J62e-zdBz8cxFVOjBcq1WA"

// SearchTimeline GraphQL クエリID
const SEARCH_QUERY_ID = "pCd62NDD9dlCDgEGgEVHMg"

// GraphQL エンドポイント
const TIMELINE_URL = `https://x.com/i/api/graphql/${GRAPHQL_QUERY_ID}/HomeTimeline`
const SEARCH_URL = `https://x.com/i/api/graphql/${SEARCH_QUERY_ID}/SearchTimeline`

// ブラウザプロファイル一覧（優先順）
const BROWSER_PROFILES: BrowserProfile[] = [
  {
    name: "Arc",
    cookieDbPath: `${Deno.env.get("HOME")}/Library/Application Support/Arc/User Data/Default/Cookies`,
    keychainService: "Arc Safe Storage",
    keychainAccount: "Arc",
  },
  {
    name: "Chrome",
    cookieDbPath: `${Deno.env.get("HOME")}/Library/Application Support/Google/Chrome/Default/Cookies`,
    keychainService: "Chrome Safe Storage",
    keychainAccount: "Chrome",
  },
]

// ─── Cookie 復号 ───────────────────────────────────────────────────────────────

/**
 * macOS Keychain から Chrome/Arc の Safe Storage パスワードを取得する
 */
async function getKeychainPassword(service: string, account: string): Promise<string> {
  const cmd = new Deno.Command("security", {
    args: ["find-generic-password", "-w", "-s", service, "-a", account],
    stdout: "piped",
    stderr: "piped",
  })
  const result = await cmd.output()

  if (!result.success) {
    const stderr = new TextDecoder().decode(result.stderr).trim()
    if (stderr.includes("could not be found") || stderr.includes("not found")) {
      throw new Error(
        `Keychain エントリ "${service}" が見つかりません。ブラウザがインストールされているか確認してください。`,
      )
    }
    throw new Error(
      `Keychain アクセスに失敗しました: ${stderr}\n` +
        "macOS のセキュリティダイアログで「常に許可」を選択してください。",
    )
  }

  return new TextDecoder().decode(result.stdout).trim()
}

/**
 * PBKDF2 で AES-128 キーを導出する（Chromium の Cookie 暗号化方式）
 */
async function deriveAesKey(password: string): Promise<CryptoKey> {
  const enc = new TextEncoder()
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    enc.encode(password),
    { name: "PBKDF2" },
    false,
    ["deriveKey"],
  )
  return crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      salt: enc.encode("saltysalt"),
      iterations: 1003,
      hash: "SHA-1",
    },
    keyMaterial,
    { name: "AES-CBC", length: 128 },
    false,
    ["decrypt"],
  )
}

/**
 * Chromium の暗号化 Cookie 値を復号する
 * v10/v11 プレフィックス付きの値を AES-128-CBC で復号する
 */
async function decryptCookieValue(encryptedValue: Uint8Array, aesKey: CryptoKey): Promise<string> {
  // v10 または v11 プレフィックス（3バイト）をスキップ
  const prefix = new TextDecoder().decode(encryptedValue.slice(0, 3))
  if (prefix !== "v10" && prefix !== "v11") {
    // 暗号化されていない値（古いフォーマット）
    return new TextDecoder().decode(encryptedValue)
  }

  const ciphertext = encryptedValue.slice(3)
  const iv = new Uint8Array(16).fill(0x20) // 16バイトのスペース文字

  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-CBC", iv },
    aesKey,
    ciphertext,
  )

  const decryptedBytes = new Uint8Array(decrypted)

  // PKCS#7 パディングを除去（最終バイトが 1-16 で、かつその数だけ同じ値が続く場合）
  let unpaddedBytes = decryptedBytes
  const lastByte = decryptedBytes[decryptedBytes.length - 1]
  if (lastByte > 0 && lastByte <= 16) {
    let validPadding = true
    for (let i = decryptedBytes.length - lastByte; i < decryptedBytes.length; i++) {
      if (decryptedBytes[i] !== lastByte) {
        validPadding = false
        break
      }
    }
    if (validPadding) {
      unpaddedBytes = decryptedBytes.slice(0, decryptedBytes.length - lastByte)
    }
  }

  // AES-CBC で IV がずれると最初のブロック（16バイト）がバイナリデータになる。
  // 実際のCookie値は2ブロック目以降の印刷可能ASCII文字として復号される。
  // 最初の長い印刷可能ASCII文字列の開始位置を見つけて抽出する。
  let startIdx = 0
  for (let i = 0; i < unpaddedBytes.length; i++) {
    if (unpaddedBytes[i] >= 0x30 && unpaddedBytes[i] <= 0x7a) {
      let runLen = 0
      for (let j = i; j < unpaddedBytes.length && unpaddedBytes[j] >= 0x20 && unpaddedBytes[j] <= 0x7e; j++) {
        runLen++
      }
      if (runLen >= 10) {
        startIdx = i
        break
      }
    }
  }
  const valueBytes = unpaddedBytes.slice(startIdx)
  return Array.from(valueBytes).map((b) => String.fromCharCode(b)).join("")
}

// ─── Cookie 取得 ────────────────────────────────────────────────────────────────

interface XCookies {
  ct0: string
  authToken: string
  browserName: string
}

/**
 * ブラウザの Cookie DB から x.com の認証 Cookie を取得する
 */
async function getXCookiesFromBrowser(): Promise<XCookies> {
  const errors: string[] = []

  for (const profile of BROWSER_PROFILES) {
    try {
      // Cookie DB の存在確認
      try {
        await Deno.stat(profile.cookieDbPath)
      } catch {
        errors.push(`${profile.name}: Cookie DB が見つかりません (${profile.cookieDbPath})`)
        continue
      }

      // Keychain からパスワード取得
      let aesKey: CryptoKey
      try {
        const password = await getKeychainPassword(profile.keychainService, profile.keychainAccount)
        aesKey = await deriveAesKey(password)
      } catch (e) {
        errors.push(`${profile.name}: ${(e as Error).message}`)
        continue
      }

      // SQLite DB をコピーして開く（ブラウザが開いている間はロックされている場合があるため）
      const tmpPath = await Deno.makeTempFile({ suffix: ".db" })
      try {
        await Deno.copyFile(profile.cookieDbPath, tmpPath)
        const db = new Database(tmpPath, { readonly: true })

        // x.com の Cookie を取得
        const rows = db.prepare(
          "SELECT name, encrypted_value FROM cookies WHERE host_key IN ('.x.com', 'x.com') AND (name = 'ct0' OR name = 'auth_token')",
        ).all() as Array<{ name: string; encrypted_value: Uint8Array }>

        db.close()

        // 値を復号
        const cookies: Record<string, string> = {}
        for (const row of rows) {
          const decrypted = await decryptCookieValue(row.encrypted_value, aesKey)
          cookies[row.name] = decrypted
        }

        if (!cookies["ct0"] || !cookies["auth_token"]) {
          errors.push(
            `${profile.name}: x.com の Cookie が見つかりません。ブラウザで x.com にログインしてください。`,
          )
          continue
        }

        return {
          ct0: cookies["ct0"],
          authToken: cookies["auth_token"],
          browserName: profile.name,
        }
      } finally {
        await Deno.remove(tmpPath).catch(() => {})
      }
    } catch (e) {
      errors.push(`${profile.name}: ${(e as Error).message}`)
    }
  }

  throw new Error(
    "ブラウザから認証情報を取得できませんでした:\n" +
      errors.map((e) => `  - ${e}`).join("\n") +
      "\n\nArc または Chrome で x.com にログインした状態で再実行してください。",
  )
}

// ─── X GraphQL API ──────────────────────────────────────────────────────────────

// 最低取得件数
const MIN_TWEET_COUNT = 100

// ページネーションの最大ページ数（安全弁）
const MAX_PAGES = 10

/**
 * X の HomeTimeline GraphQL API を呼び出す
 * cursor を渡すと次ページを取得する
 */
async function fetchTimeline(cookies: XCookies, cursor?: string): Promise<unknown> {
  // deno-lint-ignore no-explicit-any
  const variablesObj: Record<string, any> = {
    count: 40,
    includePromotedContent: false,
    latestControlAvailable: true,
    requestContext: "launch",
    withCommunity: true,
  }
  if (cursor) {
    variablesObj.cursor = cursor
  }
  const variables = JSON.stringify(variablesObj)

  const features = JSON.stringify({
    rweb_tipjar_consumption_enabled: true,
    responsive_web_graphql_exclude_directive_enabled: true,
    verified_phone_label_enabled: false,
    creator_subscriptions_tweet_preview_api_enabled: true,
    responsive_web_graphql_timeline_navigation_enabled: true,
    responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
    communities_web_enable_tweet_community_results_fetch: true,
    c9s_tweet_anatomy_moderator_badge_enabled: true,
    articles_preview_enabled: true,
    responsive_web_edit_tweet_api_enabled: true,
    graphql_is_translatable_rweb_tweet_is_translatable_enabled: true,
    view_counts_everywhere_api_enabled: true,
    longform_notetweets_consumption_enabled: true,
    responsive_web_twitter_article_tweet_consumption_enabled: true,
    tweet_awards_web_tipping_enabled: false,
    creator_subscriptions_quote_tweet_preview_enabled: false,
    freedom_of_speech_not_reach_fetch_enabled: true,
    standardized_nudges_misinfo: true,
    tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: true,
    rweb_video_timestamps_enabled: true,
    longform_notetweets_rich_text_read_enabled: true,
    longform_notetweets_inline_media_enabled: true,
    responsive_web_enhance_cards_enabled: false,
  })

  const url = new URL(TIMELINE_URL)
  url.searchParams.set("variables", variables)
  url.searchParams.set("features", features)

  const response = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${X_BEARER_TOKEN}`,
      cookie: `ct0=${cookies.ct0}; auth_token=${cookies.authToken}`,
      "x-csrf-token": cookies.ct0,
      "x-twitter-auth-type": "OAuth2Session",
      "x-twitter-active-user": "yes",
      "x-twitter-client-language": "ja",
      "content-type": "application/json",
      "user-agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
      accept: "*/*",
      "accept-language": "ja,en-US;q=0.9,en;q=0.8",
      referer: "https://x.com/home",
    },
  })

  if (response.status === 401 || response.status === 403) {
    throw new Error(
      `認証エラー (HTTP ${response.status})\n` +
        "Cookie が期限切れの可能性があります。ブラウザで x.com を再読み込みしてからもう一度試してください。",
    )
  }

  if (response.status === 429) {
    throw new Error("レートリミットに達しました。数分後に再実行してください。")
  }

  if (!response.ok) {
    throw new Error(`X API エラー: HTTP ${response.status} ${response.statusText}`)
  }

  const data = await response.json()

  // GraphQL エラーチェック
  // deno-lint-ignore no-explicit-any
  if ((data as any).errors && !(data as any).data) {
    // deno-lint-ignore no-explicit-any
    const errMsg = (data as any).errors.map((e: any) => e.message).join(", ")
    throw new Error(
      `GraphQL エラー: ${errMsg}\n` +
        `queryId (${GRAPHQL_QUERY_ID}) が古くなっている可能性があります。` +
        "scrape-timeline.ts の GRAPHQL_QUERY_ID を最新の値に更新してください。",
    )
  }

  return data
}

/**
 * X の SearchTimeline GraphQL API を呼び出す
 * cursor を渡すと次ページを取得する
 */
async function fetchSearchTimeline(
  cookies: XCookies,
  rawQuery: string,
  txn: ClientTransaction,
  cursor?: string,
): Promise<unknown> {
  // deno-lint-ignore no-explicit-any
  const variablesObj: Record<string, any> = {
    rawQuery,
    count: 20,
    querySource: "typed_query",
    product: "Top",
    withGrokTranslatedBio: false,
  }
  if (cursor) {
    variablesObj.cursor = cursor
  }
  const variables = JSON.stringify(variablesObj)

  // SearchTimeline 固有の features（ブラウザの実リクエストに合わせた値）
  const features = JSON.stringify({
    rweb_video_screen_enabled: false,
    profile_label_improvements_pcf_label_in_post_enabled: true,
    responsive_web_profile_redirect_enabled: false,
    rweb_tipjar_consumption_enabled: false,
    verified_phone_label_enabled: false,
    creator_subscriptions_tweet_preview_api_enabled: true,
    responsive_web_graphql_timeline_navigation_enabled: true,
    responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
    premium_content_api_read_enabled: false,
    communities_web_enable_tweet_community_results_fetch: true,
    c9s_tweet_anatomy_moderator_badge_enabled: true,
    responsive_web_grok_analyze_button_fetch_trends_enabled: false,
    responsive_web_grok_analyze_post_followups_enabled: true,
    responsive_web_jetfuel_frame: true,
    responsive_web_grok_share_attachment_enabled: true,
    responsive_web_grok_annotations_enabled: true,
    articles_preview_enabled: true,
    responsive_web_edit_tweet_api_enabled: true,
    graphql_is_translatable_rweb_tweet_is_translatable_enabled: true,
    view_counts_everywhere_api_enabled: true,
    longform_notetweets_consumption_enabled: true,
    responsive_web_twitter_article_tweet_consumption_enabled: true,
    content_disclosure_indicator_enabled: true,
    content_disclosure_ai_generated_indicator_enabled: true,
    responsive_web_grok_show_grok_translated_post: true,
    responsive_web_grok_analysis_button_from_backend: true,
    post_ctas_fetch_enabled: false,
    freedom_of_speech_not_reach_fetch_enabled: true,
    standardized_nudges_misinfo: true,
    tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: true,
    longform_notetweets_rich_text_read_enabled: true,
    longform_notetweets_inline_media_enabled: false,
    responsive_web_grok_image_annotation_enabled: true,
    responsive_web_grok_imagine_annotation_enabled: true,
    responsive_web_grok_community_note_auto_translation_is_enabled: false,
    responsive_web_enhance_cards_enabled: false,
  })

  const url = new URL(SEARCH_URL)
  url.searchParams.set("variables", variables)
  url.searchParams.set("features", features)

  // x-client-transaction-id を生成
  const apiPath = `/i/api/graphql/${SEARCH_QUERY_ID}/SearchTimeline`
  const txnId = await txn.generateTransactionId("GET", apiPath)

  const response = await fetch(url.toString(), {
    headers: {
      authorization: `Bearer ${X_BEARER_TOKEN}`,
      cookie: `ct0=${cookies.ct0}; auth_token=${cookies.authToken}`,
      "x-csrf-token": cookies.ct0,
      "x-twitter-auth-type": "OAuth2Session",
      "x-twitter-active-user": "yes",
      "x-twitter-client-language": "ja",
      "x-client-transaction-id": txnId,
      "content-type": "application/json",
      "user-agent":
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
      accept: "*/*",
      "accept-language": "ja,en-US;q=0.9,en;q=0.8",
      referer: `https://x.com/search?q=${encodeURIComponent(rawQuery)}&src=typed_query&f=live`,
      "sec-ch-ua": '"Not-A.Brand";v="24", "Chromium";v="146"',
      "sec-ch-ua-mobile": "?0",
      "sec-ch-ua-platform": '"macOS"',
      "sec-fetch-dest": "empty",
      "sec-fetch-mode": "cors",
      "sec-fetch-site": "same-origin",
    },
  })

  if (response.status === 401 || response.status === 403) {
    throw new Error(
      `認証エラー (HTTP ${response.status})\n` +
        "Cookie が期限切れの可能性があります。ブラウザで x.com を再読み込みしてからもう一度試してください。",
    )
  }

  if (response.status === 429) {
    throw new Error("レートリミットに達しました。数分後に再実行してください。")
  }

  if (!response.ok) {
    throw new Error(`X API エラー: HTTP ${response.status} ${response.statusText}`)
  }

  const data = await response.json()

  // deno-lint-ignore no-explicit-any
  if ((data as any).errors && !(data as any).data) {
    // deno-lint-ignore no-explicit-any
    const errMsg = (data as any).errors.map((e: any) => e.message).join(", ")
    throw new Error(
      `GraphQL エラー: ${errMsg}\n` +
        `queryId (${SEARCH_QUERY_ID}) が古くなっている可能性があります。` +
        "scrape-timeline.ts の SEARCH_QUERY_ID を最新の値に更新してください。",
    )
  }

  return data
}

// ─── レスポンスパース ────────────────────────────────────────────────────────────

/**
 * ネストしたオブジェクトから安全に値を取得する
 */
function getNestedValue(obj: unknown, path: string[]): unknown {
  let current = obj
  for (const key of path) {
    if (current == null || typeof current !== "object") return undefined
    current = (current as Record<string, unknown>)[key]
  }
  return current
}

/**
 * GraphQL レスポンスからモードに応じた instructions を抽出する
 */
function extractInstructions(data: unknown, mode: "home" | "search"): unknown[] | undefined {
  const path =
    mode === "home"
      ? ["data", "home", "home_timeline_urt", "instructions"]
      : ["data", "search_by_raw_query", "search_timeline", "timeline", "instructions"]
  const instructions = getNestedValue(data, path) as unknown[]
  return Array.isArray(instructions) ? instructions : undefined
}

/**
 * GraphQL レスポンスからページネーション用のボトムカーソルを抽出する
 */
function extractBottomCursor(instructions: unknown[]): string | undefined {
  for (const instruction of instructions) {
    // "addEntries" / "TimelineAddEntries" の entries からカーソルを探す
    const entries = getNestedValue(instruction as unknown, ["entries"]) as unknown[]
    if (!Array.isArray(entries)) continue

    for (const entry of entries) {
      // deno-lint-ignore no-explicit-any
      const entryId = (entry as any)?.entryId as string | undefined
      if (entryId?.startsWith("cursor-bottom-")) {
        const cursorValue = getNestedValue(entry as unknown, ["content", "value"]) as string | undefined
        if (cursorValue) return cursorValue
      }
    }
  }

  return undefined
}

/**
 * GraphQL レスポンスからツイートを抽出する
 */
function parseTweets(instructions: unknown[]): Tweet[] {
  const tweets: Tweet[] = []

  for (const instruction of instructions) {
    const entries = getNestedValue(instruction as unknown, ["entries"]) as unknown[]
    if (!Array.isArray(entries)) continue

    for (const entry of entries) {
      // ツイート結果を取得
      const tweetResult = getNestedValue(entry as unknown, [
        "content",
        "itemContent",
        "tweet_results",
        "result",
      ])

      if (!tweetResult) continue

      // リツイートの場合、元ツイートを取得
      // deno-lint-ignore no-explicit-any
      const finalResult = (tweetResult as any).__typename === "TweetWithVisibilityResults"
        ? getNestedValue(tweetResult, ["tweet"])
        : tweetResult

      if (!finalResult) continue

      const legacy = getNestedValue(finalResult, ["legacy"]) as Record<string, unknown>
      if (!legacy) continue

      // ツイートの基本情報を取得
      const fullText = legacy["full_text"] as string | undefined
      const likes = (legacy["favorite_count"] as number | undefined) ?? 0
      const retweets = (legacy["retweet_count"] as number | undefined) ?? 0
      const createdAtStr = legacy["created_at"] as string | undefined

      if (!fullText || !createdAtStr) continue

      // ユーザー情報を取得（HomeTimeline は legacy、SearchTimeline は core にある）
      const userResult = getNestedValue(finalResult, [
        "core",
        "user_results",
        "result",
      ]) as Record<string, unknown> | undefined
      const userLegacy = userResult?.["legacy"] as Record<string, unknown> | undefined
      const userCore = userResult?.["core"] as Record<string, unknown> | undefined

      const screenName = (userLegacy?.["screen_name"] as string | undefined)
        ?? (userCore?.["screen_name"] as string | undefined)
        ?? "unknown"
      const displayName = (userLegacy?.["name"] as string | undefined)
        ?? (userCore?.["name"] as string | undefined)
        ?? "Unknown"

      // ツイートID
      // deno-lint-ignore no-explicit-any
      const tweetId = (finalResult as any).rest_id as string | undefined
      if (!tweetId) continue

      const createdAt = new Date(createdAtStr).toISOString()

      tweets.push({
        id: tweetId,
        url: `https://x.com/${screenName}/status/${tweetId}`,
        author: `@${screenName}`,
        authorName: displayName,
        text: fullText,
        likes,
        retweets,
        createdAt,
        engagement: likes + retweets,
      })
    }
  }

  return tweets
}

// ─── メイン処理 ─────────────────────────────────────────────────────────────────

async function main() {
  const searchQuery = Deno.args[0]

  // 1. ブラウザから認証情報を取得
  let cookies: XCookies
  try {
    cookies = await getXCookiesFromBrowser()
    console.error(`✓ ${cookies.browserName} から認証情報を取得しました`)
  } catch (e) {
    console.error(`エラー: ${(e as Error).message}`)
    Deno.exit(1)
  }

  const mode: "home" | "search" = searchQuery ? "search" : "home"

  // 検索モードの場合、x-client-transaction-id 生成用に ClientTransaction を初期化
  let txn: ClientTransaction | undefined
  if (searchQuery) {
    console.error("✓ 検索モード: x-client-transaction-id を初期化中...")
    try {
      const doc = await handleXMigration()
      txn = await ClientTransaction.create(doc)
      console.error(`✓ 検索モード: "${searchQuery}"`)
    } catch (e) {
      console.error(`エラー: ClientTransaction 初期化失敗: ${(e as Error).message}`)
      Deno.exit(1)
    }
  } else {
    console.error("✓ ホームタイムラインモード")
  }

  // 2. ページネーションでツイートを取得（最低 MIN_TWEET_COUNT 件）
  const allTweets: Tweet[] = []
  const seenIds = new Set<string>()
  let cursor: string | undefined = undefined

  for (let page = 0; page < MAX_PAGES; page++) {
    let data: unknown
    try {
      data = searchQuery
        ? await fetchSearchTimeline(cookies, searchQuery, txn!, cursor)
        : await fetchTimeline(cookies, cursor)
      console.error(`✓ ページ ${page + 1} を取得しました`)
    } catch (e) {
      console.error(`エラー: ${(e as Error).message}`)
      if (page === 0) Deno.exit(1)
      break
    }

    // instructions を抽出
    const instructions = extractInstructions(data, mode)
    if (!instructions) {
      console.error("  → instructions が取得できないため終了")
      if (page === 0) Deno.exit(1)
      break
    }

    // ツイートをパース（重複除去）
    const pageTweets = parseTweets(instructions)
    let newCount = 0
    for (const tweet of pageTweets) {
      if (!seenIds.has(tweet.id)) {
        seenIds.add(tweet.id)
        allTweets.push(tweet)
        newCount++
      }
    }
    console.error(`  → ${pageTweets.length} 件パース、${newCount} 件追加（累計 ${allTweets.length} 件）`)

    // 最低件数に達したら終了
    if (allTweets.length >= MIN_TWEET_COUNT) break

    // 次ページのカーソルを取得
    const nextCursor = extractBottomCursor(instructions)
    if (!nextCursor) {
      console.error("  → カーソルが取得できないため終了")
      break
    }
    cursor = nextCursor

    // レートリミット対策の間隔
    await new Promise((r) => setTimeout(r, 1000))
  }

  console.error(`✓ 合計 ${allTweets.length} 件のツイートを取得しました`)

  // 3. ホームタイムラインの場合のみ直近24時間にフィルタ
  let resultTweets: Tweet[]
  if (mode === "home") {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000)
    resultTweets = allTweets.filter((t) => new Date(t.createdAt) >= cutoff)
    console.error(`✓ 直近24時間: ${resultTweets.length} 件`)
  } else {
    resultTweets = allTweets
  }

  // 4. エンゲージメント降順でソート
  resultTweets.sort((a, b) => b.engagement - a.engagement)

  // 5. JSON を stdout に出力
  console.log(JSON.stringify(resultTweets, null, 2))
}

main()
