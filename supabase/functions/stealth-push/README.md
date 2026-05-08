# Stealth Push Edge Function

This function polls `push_requests` and sends FCM notifications to devices listed in the `devices` table.

Quick deploy steps (run from project root):

```powershell
# Install deps
cd supabase/functions/stealth-push
npm install

# Set secrets (example)
supabase secrets set SERVICE_ROLE_KEY="<service_role_key>" --project-ref <ref>
supabase secrets set SUPABASE_URL="https://xyz.supabase.co" --project-ref <ref>
supabase secrets set FCM_SERVER_KEY="<fcm_server_key>" --project-ref <ref>

# Deploy
supabase functions deploy stealth-push --project-ref <ref>

# Invoke (test)
supabase functions invoke stealth-push --project-ref <ref>
```

Notes:
- Prefer using a Firebase service account and the new FCM HTTP v1 flow for production; the `FCM_SERVER_KEY` legacy key works for testing.
- The function currently polls `push_requests` and marks rows processed. You can adapt it to use realtime subscriptions or an HTTP trigger.
