import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Safe Environment Variable Retrieval
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SERVICE_ROLE_KEY') || "";
const FIREBASE_SERVICE_ACCOUNT_RAW = Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || "";

Deno.serve(async (req) => {
  console.log("--- Stealth Push Worker Started ---");
  
  try {
    // 1. Validate Core Configuration
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return new Response(JSON.stringify({ error: "Missing Supabase configuration secrets" }), { status: 500 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 2. Poll for push requests
    const { data: rows, error: pollError } = await supabase
      .from('push_requests')
      .select('*')
      .eq('processed', false)
      .limit(5);

    if (pollError) {
      return new Response(JSON.stringify({ error: `Database Error: ${pollError.message}` }), { status: 500 });
    }

    if (!rows || rows.length === 0) {
      return new Response(JSON.stringify({ ok: true, message: "Queue empty", processed: 0 }), { status: 200 });
    }

    // 3. Validate Firebase Configuration
    if (!FIREBASE_SERVICE_ACCOUNT_RAW) {
      return new Response(JSON.stringify({ error: "FIREBASE_SERVICE_ACCOUNT secret is missing" }), { status: 500 });
    }

    let serviceAccount;
    try {
      serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_RAW);
    } catch (e) {
      return new Response(JSON.stringify({ error: "Malformed FIREBASE_SERVICE_ACCOUNT JSON" }), { status: 500 });
    }

    // 4. Process Batch
    const accessToken = await getAccessToken(serviceAccount);
    let processedCount = 0;

    for (const row of rows) {
      const payload = row.payload;
      const roomId = payload.room_id || payload.chat_id;
      const senderDeviceId = payload.sender_device_id;

      // 1. Get all user IDs in this room from profiles
      const { data: memberProfiles, error: memberError } = await supabase
        .from('profiles')
        .select('id')
        .eq('room_id', roomId);

      if (memberError || !memberProfiles) continue;
      const userIds = memberProfiles.map(p => p.id);

      // 2. Get tokens for these users from devices table (excluding the sender's device)
      const { data: devices, error: deviceError } = await supabase
        .from('devices')
        .select('fcm_token')
        .in('user_id', userIds)
        .neq('device_id', senderDeviceId);

      if (deviceError || !devices) continue;

      const tokens = devices
        .map(d => d.fcm_token)
        .filter(t => t && t.length > 10);

      // 3. Send to each token
      for (const token of tokens) {
        try {
          const fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: token,
                // ✅ Notification block wakes up "Killed" apps
                notification: {
                  title: "🎮 New Level Update", // Disguised
                  body: "You have a new challenge waiting!"
                },
                // ✅ Data block carries the real stealth content
                data: {
                  type: "stealth_message",
                  chat_id: roomId,
                  sender_id: payload.sender_id,
                  content: payload.content,
                },
                // ✅ High priority forces instant delivery
                android: {
                  priority: "high",
                  notification: {
                    channel_id: "game_updates",
                    priority: "high"
                  }
                },
                apns: {
                  payload: {
                    aps: {
                      contentAvailable: true,
                      priority: 10
                    }
                  }
                }
              }
            })
          });
          
          const result = await fcmResponse.json();
          console.log(`FCM Result for ${token.substring(0,10)}... :`, result);
        } catch (fcmErr) {
          console.error("FCM Send Error:", fcmErr);
        }
      }

      // Mark as processed
      await supabase.from('push_requests').update({ 
        processed: true, 
        processed_at: new Date().toISOString() 
      }).eq('id', row.id);
      
      processedCount++;
    }

    return new Response(JSON.stringify({ ok: true, processed: processedCount }), { 
      headers: { "Content-Type": "application/json" } 
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: `Internal Exception: ${e.message}` }), { status: 500 });
  }
});

// FCM Helper
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

function b64(str: string) { return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "") }
function b64ab(ab: ArrayBuffer) { return b64(String.fromCharCode(...new Uint8Array(ab))) }
function str2ab(str: string) {
  const content = str.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, "")
  return Uint8Array.from(atob(content), c => c.charCodeAt(0))
}
