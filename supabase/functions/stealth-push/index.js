const { createClient } = require('@supabase/supabase-js');
const fetch = require('node-fetch');

const SUPABASE_URL = process.env.SUPABASE_URL;
// The CLI disallows secret names prefixed with SUPABASE_. Use SERVICE_ROLE_KEY instead.
const SUPABASE_SERVICE_ROLE_KEY = process.env.SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
const FCM_SERVER_KEY = process.env.FCM_SERVER_KEY || process.env.FIREBASE_SERVER_KEY; // legacy server key

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function sendFcm(token, body) {
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
          await sendFcm(d.fcm_token, { ...message, to: d.fcm_token });
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
