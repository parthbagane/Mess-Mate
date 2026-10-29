-- ============================================================
-- MessMate: multi-day leave ("until a date" and "until I'm back")
-- Run ONCE in Supabase: SQL Editor > New query > paste all > Run.
-- Safe to run again. Does not touch existing leave records.
-- ============================================================
create table if not exists leave_periods(
  id bigint generated always as identity primary key,
  student_id uuid not null references profiles(id) on delete cascade,
  start_date date not null,
  end_date date,                       -- null = open-ended, until the student confirms they are back
  reason text not null,
  note text,
  applied_at timestamptz not null default now(),
  check (end_date is null or (end_date >= start_date and end_date <= start_date + 60))
);
-- only one open-ended leave at a time per student
create unique index if not exists lp_one_open on leave_periods(student_id) where end_date is null;

alter table leave_periods enable row level security;
drop policy if exists lp_sel on leave_periods;
drop policy if exists lp_ins on leave_periods;
create policy lp_sel on leave_periods for select to authenticated
  using (student_id = auth.uid() or is_owner());
-- start today only before 5:00 PM India time, or any later day
create policy lp_ins on leave_periods for insert to authenticated
  with check (
    student_id = auth.uid() and not is_owner()
    and (start_date > (now() at time zone 'Asia/Kolkata')::date
         or (start_date = (now() at time zone 'Asia/Kolkata')::date
             and (now() at time zone 'Asia/Kolkata')::time < time '17:00'))
  );
-- no UPDATE/DELETE policy: changes only through end_leave() below

-- "I'm back" / cancel: the last leave day becomes yesterday (so you are present from today).
-- If that is before the leave started, the leave is cancelled completely.
create or replace function end_leave(p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
declare r leave_periods%rowtype; d date := ((now() at time zone 'Asia/Kolkata')::date - 1);
begin
  select * into r from leave_periods where id = p_id and student_id = auth.uid() for update;
  if not found then raise exception 'Leave not found'; end if;
  if r.end_date is not null and r.end_date <= d then return; end if;   -- already over
  if d < r.start_date then delete from leave_periods where id = p_id;
  else update leave_periods set end_date = d where id = p_id; end if;
end $$;
revoke all on function end_leave(bigint) from public, anon;
grant execute on function end_leave(bigint) to authenticated;
