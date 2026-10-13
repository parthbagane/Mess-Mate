# Mess-Mate
Mobile-first mess management app for college hostels: daily attendance, same-day leave, fees and a mess-owner dashboard. Built with vanilla JS and Supabase.


# MessMate

A mobile-first web app for managing daily meals in a college mess. Students track their attendance, leave and fees. The mess owner marks attendance and sees every student's records in one place. It installs on Android like an app.

## Features

**Students**
- Home dashboard with a circular gauge of present days, leave days and days left in the month
- Lunch and dinner status cards
- Same-day leave, open until 5:00 PM
- Meal history by date, leave history, and fee details with payment history
- Sign up with email verification, log in, and reset a forgotten password

**Mess owner (separate login)**
- Today view: who is on leave and who is eating
- Marks Present or Absent for each student's lunch and dinner
- Per-student account page: monthly and all-time attendance, leaves and fees
- Records payments and edits each student's room and monthly fee
- Downloads a monthly CSV report

**Rules built in**
- Leave can be applied only until 5:00 PM, and the database enforces the cutoff using server time (India time)
- Students cannot mark their own attendance
- After 10:00 PM, a student with no leave and no mark counts as Present
- A day with approved leave can't be marked Present or Absent

## Tech stack
- HTML, CSS and vanilla JavaScript in a single file, with no build step
- Supabase for the database, authentication and row-level security
- Hosted as a static site, for example on Netlify
- Installable as a PWA, with a manifest and service worker

## Project structure
```
index.html        the whole app (screens, logic, styles)
database.sql      tables, security rules and sign-up trigger
otp_setup.sql     triggers for email-code verification
update_login.sql  older login update (only needed on early setups)
manifest.json     install settings for Android
sw.js             service worker
wellknown/        assetlinks.json for the Android app link
_redirects        serves wellknown/ at /.well-known/
```

## Setup
1. Create a free project at supabase.com.
2. In **SQL Editor**, run `database.sql`, and then `otp_setup.sql` if you use email codes.
3. In `index.html`, set `SB_URL` and `SB_KEY` to your project URL and publishable (anon) key.
4. In **Authentication**, enable the Email provider. If you want verification codes, turn on **Confirm email**, add a custom SMTP sender, and set the "Confirm signup" template to show `{{ .Token }}`.
5. Deploy the folder to any static host.
6. Sign up once, then make that account the owner:
```sql
   update profiles set role='owner'
   where id=(select id from auth.users where email='you@example.com');
```
   Owners log in from the **Mess Owner** tab.

## Security notes
- The Supabase publishable (anon) key is meant to be public. Access is controlled by row-level security in `database.sql`.
- Never commit your `service_role` key or SMTP password.
- Students can read only their own records. Only the owner can write attendance, payments and student details.

## Roadmap
- Multi-day and future-dated leave
- Daily menu
- Push notifications
- Hindi and Marathi languages

## License
MIT (or your choice)
