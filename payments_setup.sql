-- ============================================================
-- MessMate: payments, payment-proof verification, owner settings,
-- mess closing date and roll numbers.
-- Run ONCE in Supabase: SQL Editor > New query > paste all > Run.
-- Safe to run again (it is idempotent). It does not delete any data.
-- ============================================================

-- 1) Roll number on the existing student profile (no second student table)
alter table profiles add column if not exists roll_no text;

-- 2) Owner settings: one single row (id = 1)
create table if not exists mess_settings(
  id int primary key default 1 check (id = 1),
  owner_name text,
  upi_id text,
  pay_phone text,
  bank_details text,
  instructions text,
  modes text[] not null default '{UPI,Cash}',
  qr_data text,                 -- the owner's QR image (small, resized in the browser)
  closing_date date,
  closing_note text,
  updated_at timestamptz not null default now()
);
insert into mess_settings(id) values (1) on conflict (id) do nothing;
alter table mess_settings enable row level security;
drop policy if exists ms_sel on mess_settings;
drop policy if exists ms_ins on mess_settings;
drop policy if exists ms_upd on mess_settings;
create policy ms_sel on mess_settings for select to authenticated using (true);
create policy ms_ins on mess_settings for insert to authenticated with check (is_owner());
create policy ms_upd on mess_settings for update to authenticated using (is_owner()) with check (is_owner());

-- 3) Payment submissions (what students CLAIM). Kept separate from verified payments.
create table if not exists payment_submissions(
  id bigint generated always as identity primary key,
  student_id uuid not null references profiles(id) on delete cascade,
  fee_month text not null check (fee_month ~ '^\d{4}-\d{2}$'),
  amount int not null check (amount > 0 and amount <= 1000000),
  paid_on date not null,
  txn_ref text not null check (length(txn_ref) between 6 and 40),
  note text,
  proof_path text not null,
  status text not null default 'PENDING' check (status in ('PENDING','APPROVED','REJECTED')),
  reject_reason text,
  submitted_at timestamptz not null default now(),
  verified_at timestamptz,
  verified_by uuid
);
-- a student cannot submit the same reference twice (unless the first was rejected)
create unique index if not exists ps_student_ref_uq
  on payment_submissions (student_id, lower(txn_ref)) where status <> 'REJECTED';
-- one transaction reference can only ever be APPROVED once (never counted twice)
create unique index if not exists ps_approved_ref_uq
  on payment_submissions (lower(txn_ref)) where status = 'APPROVED';
create index if not exists ps_status_idx on payment_submissions (status, submitted_at desc);

alter table payment_submissions enable row level security;
drop policy if exists ps_sel on payment_submissions;
drop policy if exists ps_ins on payment_submissions;
create policy ps_sel on payment_submissions for select to authenticated
  using (student_id = auth.uid() or is_owner());
-- students may only insert their OWN submission, and only as PENDING
create policy ps_ins on payment_submissions for insert to authenticated
  with check (student_id = auth.uid() and status = 'PENDING'
              and verified_at is null and verified_by is null and reject_reason is null
              and not is_owner());
-- no UPDATE / DELETE policy: status can only change through the two functions below.

-- 4) Verified payments get a fee month and a link to the submission
alter table payments add column if not exists fee_month text;
alter table payments add column if not exists submission_id bigint references payment_submissions(id);
create unique index if not exists pay_submission_uq on payments(submission_id) where submission_id is not null;

-- 5) Audit trail (owner can read; written only by the functions below)
create table if not exists payment_audit(
  id bigint generated always as identity primary key,
  submission_id bigint,
  action text not null,
  actor uuid,
  detail text,
  at timestamptz not null default now()
);
alter table payment_audit enable row level security;
drop policy if exists pa_sel on payment_audit;
create policy pa_sel on payment_audit for select to authenticated using (is_owner());

-- 6) Approve / reject: owner only
create or replace function approve_payment(p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
declare s payment_submissions%rowtype;
begin
  if not is_owner() then raise exception 'Only the mess owner can approve payments'; end if;
  select * into s from payment_submissions where id = p_id for update;
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'PENDING' then raise exception 'ALREADY_DONE'; end if;
  if exists (select 1 from payment_submissions
             where status = 'APPROVED' and lower(txn_ref) = lower(s.txn_ref)) then
    raise exception 'DUPLICATE_REF';
  end if;
  insert into payments(student_id, amount, mode, paid_on, fee_month, submission_id)
    values (s.student_id, s.amount, 'UPI', s.paid_on, s.fee_month, s.id);
  update payment_submissions
     set status = 'APPROVED', verified_at = now(), verified_by = auth.uid(), reject_reason = null
   where id = p_id;
  insert into payment_audit(submission_id, action, actor, detail)
    values (p_id, 'APPROVED', auth.uid(), 'Rs ' || s.amount || ' for ' || s.fee_month || ', ref ' || s.txn_ref);
end $$;

create or replace function reject_payment(p_id bigint, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare s payment_submissions%rowtype;
begin
  if not is_owner() then raise exception 'Only the mess owner can reject payments'; end if;
  if p_reason is null or length(trim(p_reason)) < 3 then raise exception 'REASON_REQUIRED'; end if;
  select * into s from payment_submissions where id = p_id for update;
  if not found then raise exception 'Submission not found'; end if;
  if s.status <> 'PENDING' then raise exception 'ALREADY_DONE'; end if;
  update payment_submissions
     set status = 'REJECTED', verified_at = now(), verified_by = auth.uid(), reject_reason = trim(p_reason)
   where id = p_id;
  insert into payment_audit(submission_id, action, actor, detail)
    values (p_id, 'REJECTED', auth.uid(), 'Rs ' || s.amount || ' ref ' || s.txn_ref || ': ' || trim(p_reason));
end $$;

revoke all on function approve_payment(bigint) from public, anon;
revoke all on function reject_payment(bigint, text) from public, anon;
grant execute on function approve_payment(bigint) to authenticated;
grant execute on function reject_payment(bigint, text) to authenticated;

-- 7) Private storage bucket for payment screenshots
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-proofs', 'payment-proofs', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists pp_ins on storage.objects;
drop policy if exists pp_sel on storage.objects;
-- a student can upload only inside a folder named with their own user id
create policy pp_ins on storage.objects for insert to authenticated
  with check (bucket_id = 'payment-proofs' and (storage.foldername(name))[1] = auth.uid()::text);
-- a student can read only their own folder; the owner can read all
create policy pp_sel on storage.objects for select to authenticated
  using (bucket_id = 'payment-proofs' and ((storage.foldername(name))[1] = auth.uid()::text or is_owner()));
-- a student may remove an uploaded file only if no submission uses it (cleans up failed uploads)
drop policy if exists pp_del on storage.objects;
create policy pp_del on storage.objects for delete to authenticated
  using (bucket_id = 'payment-proofs' and (storage.foldername(name))[1] = auth.uid()::text
         and not exists (select 1 from public.payment_submissions p where p.proof_path = name));
