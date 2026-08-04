-- Set demo passwords to 'Demo1234!' for admin/partner/customer test accounts.
-- pgcrypto is in extensions schema on Supabase.

DO $$
DECLARE
  v_pw TEXT := 'Demo1234!';
  v_uid UUID;
BEGIN
  UPDATE auth.users
    SET encrypted_password = extensions.crypt(v_pw, extensions.gen_salt('bf')),
        email_confirmed_at = COALESCE(email_confirmed_at, now())
  WHERE email = 'warehouse@applizonecentralja.com';

  UPDATE auth.users
    SET encrypted_password = extensions.crypt(v_pw, extensions.gen_salt('bf')),
        email_confirmed_at = COALESCE(email_confirmed_at, now())
  WHERE email = 'scottjoel850@gmail.com';

  SELECT id INTO v_uid FROM auth.users WHERE email = 'marcia.williams@example.com';
  IF v_uid IS NULL THEN
    v_uid := gen_random_uuid();
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change, email_change_token_new, is_sso_user
    ) VALUES (
      v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'marcia.williams@example.com',
      extensions.crypt(v_pw, extensions.gen_salt('bf')),
      now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(), '', '', '', '', false
    );
    INSERT INTO auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    )
    VALUES (
      gen_random_uuid(), v_uid,
      jsonb_build_object(
        'sub', v_uid::text,
        'email', 'marcia.williams@example.com',
        'email_verified', true
      ),
      'email', v_uid::text, now(), now(), now()
    );
  ELSE
    UPDATE auth.users
      SET encrypted_password = extensions.crypt(v_pw, extensions.gen_salt('bf')),
          email_confirmed_at = COALESCE(email_confirmed_at, now())
    WHERE id = v_uid;
  END IF;
END $$;
