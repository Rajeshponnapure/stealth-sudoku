# Stealth Push Edge Function

This function polls `push_requests` and sends FCM notifications to devices listed in the `devices` table.

Quick deploy steps (run from project root):

```powershell
# Create supabase/functions/stealth-push/.env with:
# SERVICE_ROLE_KEY=<service_role_key>
# SUPABASE_URL=https://<project-ref>.supabase.co

# Put your downloaded Firebase service-account JSON somewhere locally,
# then run the deploy script from the repo root.
.\supabase\deploy_stealth_push.ps1
```

If you want to run the commands manually, prefix every Supabase command with `npx`:

```powershell
npx supabase secrets set --env-file .\supabase\functions\stealth-push\.env --project-ref <ref>
npx supabase functions deploy stealth-push --project-ref <ref>
npx supabase functions invoke stealth-push --project-ref <ref>
```

Notes:
- The function uses Firebase service-account JSON (`FIREBASE_SERVICE_ACCOUNT`) and FCM HTTP v1 by default.
- The function still polls `push_requests` and marks rows processed. You can adapt it to use realtime subscriptions or an HTTP trigger later.
