-- Run this ONCE in Supabase > SQL Editor if you already ran database.sql before.
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,student_code,name,mobile,location)
  values(new.id,'STU'||lpad(nextval('student_seq')::text,3,'0'),
         coalesce(new.raw_user_meta_data->>'name','Student'),
         coalesce(nullif(new.raw_user_meta_data->>'mobile',''),split_part(new.email,'@',1)),
         nullif(new.raw_user_meta_data->>'location',''));
  return new;
end $$;
