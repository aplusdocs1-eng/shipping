-- Create auth.users accounts for Devon Brown + Howdidship Sample Customer
-- Password: Demo1234!
DO $$
DECLARE
  v_devon_id  UUID := gen_random_uuid();
  v_sample_id UUID := gen_random_uuid();
BEGIN
  -- Devon Brown
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'devon.brown@example.com') THEN
    INSERT INTO auth.users (
      id, instance_id, aud, role, email,
      encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token
    ) VALUES (
      v_devon_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'devon.brown@example.com',
      extensions.crypt('Demo1234!', extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}', '{}',
      now(), now(), '', ''
    );
    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      gen_random_uuid(), v_devon_id::text, v_devon_id,
      jsonb_build_object('sub', v_devon_id::text, 'email', 'devon.brown@example.com'),
      'email', now(), now(), now()
    );
  END IF;

  -- Howdidship Sample Customer
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'sample.customer@howdidship.com') THEN
    INSERT INTO auth.users (
      id, instance_id, aud, role, email,
      encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token
    ) VALUES (
      v_sample_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'sample.customer@howdidship.com',
      extensions.crypt('Demo1234!', extensions.gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}', '{}',
      now(), now(), '', ''
    );
    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      gen_random_uuid(), v_sample_id::text, v_sample_id,
      jsonb_build_object('sub', v_sample_id::text, 'email', 'sample.customer@howdidship.com'),
      'email', now(), now(), now()
    );
  END IF;
END $$;
