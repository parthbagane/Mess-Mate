# MessMate: setup (free, about 20 minutes)

## 1. Create the database (Supabase, free, no card)
1. Go to supabase.com, sign up, click **New project** (name it MessMate, pick a region near India, e.g. Mumbai, set any database password and save it).
2. Open **Authentication > Providers > Email** and turn **OFF "Confirm email"**. Save. (Required: the app signs people in with mobile number + PIN, not a real email.)
3. Open **SQL Editor > New query**, paste everything from `database.sql`, press **Run**. It should say "Success".
4. Open **Project Settings > API**. Copy the **Project URL** and the **anon public** key. Never use the service_role key.

## 2. Connect the app
Already done: your Supabase URL and key are in index.html.

## 3. Publish free
1. Go to app.netlify.com/drop (free account).
2. Drag the whole `messmate-live` folder onto the page.
3. You get a link like https://something.netlify.app. Send that link to students.

## 4. Make yourself the owner
1. Open your link, tap **New student? Sign up**, register with YOUR email, mobile number and a password (6+ characters).
2. In Supabase **SQL Editor** run (put your own number):
       update profiles set role='owner' where mobile='YOUR_MOBILE_NUMBER';
3. In the app, log out and log in again. You now see the owner screens.
Students just sign up with their own email, mobile number and password.

## 5. Install on Android
Open the link in Chrome > menu (3 dots) > **Add to Home screen**. It opens full screen like an app.
(Optional real APK: pwabuilder.com, paste your link.)

## Good to know
- Login is email + password (6+ characters). No email is sent, so there is no email limit.
- Time rules use the server clock in India time. Leave closes at 5:00 PM and the server enforces it.
- After 10 PM, meals with no mark and no leave count as Present. This is calculated when viewed.
- Free Supabase projects pause after about a week of no use. Log in to the dashboard and click Restore if it happens.
- If a student forgets the PIN, reset it in Supabase > Authentication > Users.

## Owner login
The login screen has two tabs: **Student** and **Mess Owner**. Owners use the Mess Owner tab; students use the Student tab. Each tab rejects the other kind of account.
Owner shortcut link (opens the owner tab directly): https://YOUR-SITE.netlify.app/?owner
Owner accounts are not created on the login screen. Sign up once on the Student tab, run the `update profiles set role='owner' ...` SQL from step 4, then use the Mess Owner tab.

## Android app that opens full screen (no browser)
The APK from PWABuilder only opens full screen if your website proves it belongs to the app. Otherwise Android opens it inside Chrome (with a browser bar or "redirected to the website").
1. In PWABuilder, generate the Android package again. Keep the signing key and note the Package ID you chose.
2. Open the downloaded zip and find the file `assetlinks.json`.
3. Copy it into the `wellknown` folder in this project.
4. Redeploy this folder on Netlify (Deploys > drag the folder).
5. Check that https://YOUR-SITE.netlify.app/.well-known/assetlinks.json shows text (not "page not found").
6. Uninstall the old APK from the phone, install the new one, open it.
The Package ID in assetlinks.json must match the APK. If you regenerate the package with a new key, copy the new assetlinks.json again.

## Email verification code (OTP) at sign-up
1. Set up a free email sender in Supabase: Project Settings > Authentication > SMTP Settings (Gmail App Password or Brevo). Without this, students will not receive the code.
2. Authentication > Sign In / Providers > Email: turn "Confirm email" ON.
3. Authentication > Email Templates > "Confirm signup": set the subject to "Your MessMate verification code" and replace the body with:
       <h2>Verify your email</h2>
       <p>Your MessMate verification code is:</p>
       <h1 style="letter-spacing:6px">{{ .Token }}</h1>
       <p>If you did not sign up, you can ignore this email.</p>
   (It must contain {{ .Token }}, not {{ .ConfirmationURL }}.)
4. SQL Editor: run otp_setup.sql once.
5. Redeploy this folder on Netlify.
Students sign up, get a code by email, type it into the app, and are logged in. If they close the app first, logging in asks for the code again and sends a new one.
