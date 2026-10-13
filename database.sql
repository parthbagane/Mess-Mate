-- MessMate database setup. Paste ALL of this into Supabase > SQL Editor > Run.

create sequence if not exists student_seq start 1;

create table if not exists profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  student_code text unique not null,
  name text not null,
  mobile text unique not null,
  location text,
  room text,
  monthly_fee int not null default 3000,
  role text not null default 'student' check (role in ('student','owner')),
  created_at timestamptz default now()
);
create table if not exists attendance(
  id bigint generated always as identity primary key,
  student_id uuid not null references profiles(id) on delete cascade,
  date date not null,
  meal text not null check (meal in ('L','D')),
  status text not null check (status in ('P','A')),
  unique(student_id,date,meal)
);
create table if not exists leaves(
  id bigint generated always as identity primary key,
  student_id uuid not null references profiles(id) on delete cascade,
  date date not null,
  reason text not null,
  note text,
  applied_at timestamptz not null default now(),
  unique(student_id,date)
);
create table if not exists payments(
  id bigint generated always as identity primary key,
  student_id uuid not null references profiles(id) on delete cascade,
  amount int not null check (amount>0),
  mode text not null default 'UPI',
  paid_on date not null default ((now() at time zone 'Asia/Kolkata')::date)
);

create or replace function is_owner() returns boolean language sql security definer set search_path=public stable as
$$ select exists(select 1 from profiles where id=auth.uid() and role='owner') $$;

create or replace function server_now() returns timestamptz language sql stable as $$ select now() $$;

create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into profiles(id,student_code,name,mobile,location)
  values(new.id,'STU'||lpad(nextval('student_seq')::text,3,'0'),
         coalesce(new.raw_user_meta_data->>'name','Student'),
         coalesce(nullif(new.raw_user_meta_data->>'mobile',''),split_part(new.email,'@',1)),
         nullif(new.raw_user_meta_data->>'location',''));
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

alter table profiles enable row level security;
alter table attendance enable row level security;
alter table leaves enable row level security;
alter table payments enable row level security;

-- profiles: students read only themselves, owner reads and edits all. Students cannot edit (so they cannot change role/fee).
create policy p_sel on profiles for select using (id=auth.uid() or is_owner());
create policy p_upd on profiles for update using (is_owner()) with check (is_owner());

-- attendance: only the owner can write; students read their own
create policy a_sel on attendance for select using (student_id=auth.uid() or is_owner());
create policy a_ins on attendance for insert with check (is_owner());
create policy a_upd on attendance for update using (is_owner()) with check (is_owner());

-- leaves: student may apply for TODAY only, before 5:00 PM India time (checked by the server clock)
create policy l_sel on leaves for select using (student_id=auth.uid() or is_owner());
create policy l_ins on leaves for insert with check (
  student_id=auth.uid()
  and date=(now() at time zone 'Asia/Kolkata')::date
  and (now() at time zone 'Asia/Kolkata')::time < time '17:00'
);

-- payments: owner records, students read their own
create policy pay_sel on payments for select using (student_id=auth.uid() or is_owner());
create policy pay_ins on payments for insert with check (is_owner());
