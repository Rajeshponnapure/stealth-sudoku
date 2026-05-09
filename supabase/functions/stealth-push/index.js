const { createClient } = require('@supabase/supabase-js');
const fetch = require('node-fetch');
const { GoogleAuth } = require('google-auth-library');

const SUPABASE_URL = process.env.SUPABASE_URL;
// The CLI disallows secret names prefixed with SUPABASE_. Use SERVICE_ROLE_KEY instead.
const SUPABASE_SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
const FIREBASE_SERVICE_ACCOUNT_JSON = process.env.FIREBASE_SERVICE_ACCOUNT;
const FCM_SERVER_KEY = process.env.FCM_SERVER_KEY || process.env.FIREBASE_SERVER_KEY; // legacy fallback

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

function getFirebaseServiceAccount() {
  if (!FIREBASE_SERVICE_ACCOUNT_JSON) return null;
  try {
    return JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON);
  } catch (error) {
    throw new Error(`Invalid FIREBASE_SERVICE_ACCOUNT JSON: ${error.message}`);
  }
}

async function getAccessToken() {
  const serviceAccount = getFirebaseServiceAccount();
  if (!serviceAccount) return null;

  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });

  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  return typeof tokenResponse === 'string' ? tokenResponse : tokenResponse?.token;
}

async function sendFcm(token, body, projectId) {
  if (FIREBASE_SERVICE_ACCOUNT_JSON) {
    const accessToken = await getAccessToken();
    if (!accessToken) {
      throw new Error('Could not obtain Google access token from FIREBASE_SERVICE_ACCOUNT');
    }

    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: body.notification,
          data: body.data,
        },
      }),
    });
    return res.json();
  }

  const res = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify(body),
  });
  return res.json();
}

/**
 * This function is a simple worker: it polls push_requests table for unprocessed rows,
 * looks up device tokens (excluding sender_device_id), sends FCM, and marks processed.
 */
module.exports = async (req, res) => {
  try {
    const serviceAccount = getFirebaseServiceAccount();
    const projectId = serviceAccount?.project_id;

    if (serviceAccount && !projectId) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT is missing project_id');
    }

    // Poll for a small batch
    const { data: rows } = await supabase
      .from('push_requests')
      .select('*')
      .eq('processed', false)
      .order('created_at', { ascending: false })
      .limit(10);

    if (!rows || rows.length === 0) {
      return res.status(200).send({ ok: true, processed: 0 });
    }

    for (const row of rows) {
      const payload = row.payload;
      const senderDeviceId = payload.sender_device_id;
      // Lookup devices in the room or recipient users — here we look for all devices
      const { data: devices } = await supabase
        .from('devices')
        .select('fcm_token,device_id,user_id')
        .neq('device_id', senderDeviceId)
        .limit(100);

      if (!devices || devices.length === 0) {
        await supabase
          .from('push_requests')
          .update({ processed: true, processed_at: new Date().toISOString() })
          .eq('id', row.id);
        continue;
      }

      // Build FCM message with disguised notification and real data
      const message = {
        notification: { title: 'Note', body: 'You received a message' },
        data: { type: 'stealth_message', payload: JSON.stringify(payload) },
      };

      for (const d of devices) {
        try {
          await sendFcm(d.fcm_token, message, projectId);
        } catch (e) {
          console.error('FCM error', e);
        }
      }

      // Mark processed
      await supabase
        .from('push_requests')
        .update({ processed: true, processed_at: new Date().toISOString() })
        .eq('id', row.id);
    }

    return res.status(200).send({ ok: true, processed: rows.length });
  } catch (e) {
    console.error(e);
    return res.status(500).send({ error: String(e) });
  }
};
