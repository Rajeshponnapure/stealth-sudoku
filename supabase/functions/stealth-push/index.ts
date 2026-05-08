import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface NotificationPayload {
  record: {
    chat_id: string
    sender_id: string
    content: string
  }
}

serve(async (req) => {
  try {
    const payload: NotificationPayload = await req.json()
    const { record } = payload

    // 1. Initialize Supabase Admin Client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 2. Find participants in this room (excluding the sender)
    const { data: session } = await supabaseAdmin
      .from('chat_sessions')
      .select('participant_ids')
      .eq('id', record.chat_id)
      .single()

    if (!session) return new Response("No session found", { status: 404 })

    const recipients = session.participant_ids.filter((id: string) => id !== record.sender_id)

    // 3. Get FCM tokens for recipients
    // NOTE: This assumes you have a table called 'profiles' with an 'fcm_token' column
    const { data: profiles } = await supabaseAdmin
      .from('profiles')
      .select('fcm_token')
      .in('id', recipients)

    const tokens = profiles?.map(p => p.fcm_token).filter(t => t) ?? []

    if (tokens.length === 0) return new Response("No tokens found", { status: 200 })

    // 4. Get Firebase Access Token
    const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
    const accessToken = await getAccessToken(serviceAccount)

    // 5. Send disguised notification to each token
    const results = await Promise.all(tokens.map(token => 
      sendFcmNotification(token, accessToken, serviceAccount.project_id)
    ))

    return new Response(JSON.stringify({ success: true, results }), {
      headers: { "Content-Type": "application/json" },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})

// Helper: Get Google OAuth2 Access Token
async function getAccessToken(serviceAccount: any): Promise<string> {
  const jwtHeader = b64(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  const now = Math.floor(Date.now() / 1000)
  const jwtClaim = b64(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  }))

  const key = await crypto.subtle.importKey(
    "pkcs8",
    str2ab(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${jwtHeader}.${jwtClaim}`))
  const jwt = `${jwtHeader}.${jwtClaim}.${b64ab(sig)}`

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: jwt }),
  })
  const data = await res.json()
  return data.access_token
}

async function sendFcmNotification(token: string, accessToken: string, projectId: string) {
  return fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token: token,
        notification: {
          title: "Sudoku Tournament Update!",
          body: "A new tournament match is ready. Join now!"
        },
        data: {
          type: "chat_message",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        }
      }
    })
  })
}

// Utility functions for JWT signing
function b64(str: string) { return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "") }
function b64ab(ab: ArrayBuffer) { return b64(String.fromCharCode(...new Uint8Array(ab))) }
function str2ab(str: string) {
  const content = str.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, "")
  return Uint8Array.from(atob(content), c => c.charCodeAt(0))
}
