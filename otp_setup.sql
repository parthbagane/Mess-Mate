-- Run ONCE in Supabase > SQL Editor, only when you turn "Confirm email" ON.
-- Profiles are now created when the email is verified, so unverified sign-ups never appear in the owner's list.

-- Mobile numbers no longer have to be unique (this removes the "Database error saving new user" clash).
alter table profiles drop constraint if exists profiles_mobile_key;

create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,student_code,name,mobile,location)
  values(new.id,'STU'||lpad(nextval('student_seq')::text,3,'0'),
         coalesce(new.raw_user_meta_data->>'name','Student'),
         coalesce(nullif(new.raw_user_meta_data->>'mobile',''),split_part(new.email,'@',1)),
         nullif(new.raw_user_meta_data->>'location',''))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
drop trigger if exists on_auth_user_confirmed on auth.users;

-- accounts that are already verified when created (for example made by you in the Supabase dashboard)
create trigger on_auth_user_created after insert on auth.users
  for each row when (new.email_confirmed_at is not null) execute function handle_new_user();

-- accounts that become verified after the student enters the code
create trigger on_auth_user_confirmed after update of email_confirmed_at on auth.users
  for each row when (old.email_confirmed_at is null and new.email_confirmed_at is not null) execute function handle_new_user();
