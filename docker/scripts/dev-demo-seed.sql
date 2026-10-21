-- Local-only demo seed (PostgreSQL part).
--
-- Creates a `tier = 'demo'` organization owned by an existing account, plus the
-- organization_member row that jawn requires for org-scoped queries
-- (OrganizationStore.checkUserBelongsToOrg). Mirrors the shape produced by
-- supabase/migrations/20241217202720_add_demo_org_constraint.sql.
--
-- Run it through ./dev-demo-seed.sh, which passes -v owner_email=... .
--
-- The owner is resolved from the better-auth `user` table via
-- `public.user.auth_user_id` (the link to auth.users, see
-- web/packages/common/toImplement/server/useBetterAuthClient.ts). That keeps
-- this script free of hardcoded user ids.

\set ON_ERROR_STOP on

SELECT u.auth_user_id AS owner_auth_user_id
FROM "user" u
WHERE u.email = :'owner_email'
\gset

\if :{?owner_auth_user_id}
\else
\echo 'ERROR: no account found for that email. Sign up / sign in once, then re-run.'
\quit 1
\endif

INSERT INTO organization (
  id, name, owner, tier, is_personal, has_onboarded, soft_delete, created_at, onboarding_status
) VALUES (
  'dddddddd-1111-4111-8111-111111111111',
  'Demo Org',
  :'owner_auth_user_id'::uuid,
  'demo',
  true,
  true,
  false,
  now(),
  '{
     "hasOnboarded": true,
     "hasCompletedQuickstart": true,
     "hasIntegrated": true,
     "currentStep": "REQUEST",
     "selectedTier": "pro",
     "demoDataSetup": true,
     "members": [],
     "addons": {"prompts": true, "experiments": true, "evals": true}
   }'::jsonb
)
ON CONFLICT (id) DO UPDATE
  SET owner = EXCLUDED.owner,
      tier = EXCLUDED.tier,
      has_onboarded = EXCLUDED.has_onboarded,
      onboarding_status = EXCLUDED.onboarding_status;

-- Re-running with a different -- owner would otherwise leave the previous
-- account attached to the demo organization.
DELETE FROM organization_member
WHERE organization = 'dddddddd-1111-4111-8111-111111111111'::uuid
  AND member <> :'owner_auth_user_id'::uuid;

INSERT INTO organization_member (id, member, organization, org_role)
SELECT gen_random_uuid(),
       :'owner_auth_user_id'::uuid,
       'dddddddd-1111-4111-8111-111111111111'::uuid,
       'owner'
WHERE NOT EXISTS (
  SELECT 1 FROM organization_member
  WHERE organization = 'dddddddd-1111-4111-8111-111111111111'::uuid
    AND member = :'owner_auth_user_id'::uuid
);

-- has_onboarded = true matters for more than the onboarding wizard: the
-- dashboard renders mock data while it is false (dashboardPage.tsx).
-- demoDataSetup = true stops the UI from calling POST /v1/organization/setup-demo,
-- which needs the proxy worker on :8787 plus real OpenAI keys.
