# Backend setup (Google Sheet + Apps Script)

Everything runs inside **your own Google account**. There's no server to rent and
nothing to pay for. It takes about 10 minutes, and you only do it once.

> **Email parsers status.** The parsers are still waiting for your sample
> emails (see `samples/README.md`). Until then, every booking email is listed
> in the app under **Unparsed emails**, where you can create the booking by
> hand. Nothing is lost: when the parsers are added, those emails are read
> again automatically.

## 1. Create the Google Sheet

1. Go to <https://sheets.google.com> while signed in to the Gmail account that
   receives your booking emails.
2. Click **Blank spreadsheet**.
3. Click "Untitled spreadsheet" (top left) and rename it, e.g. **Booking Manager**.

## 2. Open Apps Script

1. In the Sheet's menu: **Extensions → Apps Script**. A new tab opens.
2. Click "Untitled project" (top left) and rename it **Booking Manager**.

## 3. Paste the code

1. On the left you'll see a file called **Code.gs**. Click it, select everything
   in it (Ctrl+A) and delete it.
2. Open the file `apps-script/dist/BookingApp.gs` from this project. On GitHub,
   click the file, then the **Copy raw file** button (two overlapping squares).
3. Paste it into **Code.gs** and press **Ctrl+S** to save.

### Set the time zone and manifest

1. Click the **⚙ Project Settings** (gear icon) on the left.
2. Tick **Show "appsscript.json" manifest file in editor**.
3. Set **Time zone** to **(GMT+05:30) India Standard Time**.
4. Go back to the **Editor** (`< >` icon). Click `appsscript.json`, replace its
   contents with the file `apps-script/appsscript.json` from this project, then
   press **Ctrl+S**.

## 4. Run setup once and approve access

1. At the top of the editor, in the function drop-down next to **▷ Run**, choose
   **setup**.
2. Click **▷ Run**.
3. Google will ask for permission:
   - Click **Review permissions** and choose your account.
   - You'll see *"Google hasn't verified this app"*. That's expected, because
     the app is your own script. Click **Advanced → Go to Booking Manager (unsafe)**.
   - Click **Allow**. The script can now read your Gmail, add labels, edit this
     Sheet and run on a timer. It only ever runs as you, inside your account.
4. Wait for "Execution completed" at the bottom.

Setup is safe to run again at any time. It only adds what is missing and never
deletes your data.

## 5. Check what setup created

Go back to the Sheet tab and reload the page. You should now see:

- Tabs **Bookings**, **Blocks**, **Settings** and **ParserLog**
- A **Booking App** menu next to *Help*
- In Gmail, two new labels: **BookingApp/Processed** and **BookingApp/Unparsed**

## 6. Fill in Settings

Open the **Settings** tab and edit the **value** column:

| key | what to put |
|---|---|
| `properties` | your property names, separated by commas, e.g. `Hill View Cottage, Lake Room` |
| `default_property` | the property emailed bookings go to when the email doesn't say which |
| `search_window_days` | leave at `30` |
| `filter.<Platform>.senders` | the domain the platform's emails come from. Leave as is unless an email is missed |
| `filter.<Platform>.subject_regex` | words the subject must contain. These will be fine-tuned from your samples |

### The 5-minute check

Setup already turned this on. To confirm, in Apps Script click **⏰ Triggers**
(the alarm clock icon on the left). You should see `processNewEmails`,
*Time-based*, *Every 5 minutes*. You can also turn it on or off from the
**Booking App** menu in the Sheet.

To run it right away, use **Booking App → Process new emails now**.

## 7. Deploy the Web App (the link the apps use)

1. In Apps Script, click the blue **Deploy** button (top right), then **New deployment**.
2. Click the gear ⚙ next to *Select type* and choose **Web app**.
3. Fill in:
   - **Description**: `Booking app`
   - **Execute as**: **Me** (your email)
   - **Who has access**: **Anyone**
4. Click **Deploy**. If Google asks for permission again, approve it the same way as in step 4.
5. Copy the **Web app URL**. It looks like
   `https://script.google.com/macros/s/AKfy…/exec`.

> **Is "Anyone" safe?** The link does nothing without your secret API key, and
> the key is checked on every request. Never share the key. If you think it
> leaked, use **Booking App → Make a new API key** and paste the new key into
> the apps.

## 8. Connect the apps

1. Back in the Sheet, click **Booking App → Show Web App URL and API key**.
2. Open the app on Windows or Android. On the first screen, paste the
   **Web App URL** and the **API key**, then tap **Connect**.
3. The app loads your bookings. From then on it syncs by itself when it opens,
   when you pull down to refresh (Android), or when you click ↻ (Windows).

### When you update the code later

When you paste a new version of `BookingApp.gs`, go to **Deploy → Manage
deployments → ✏️ Edit**, set **Version** to **New version**, and click
**Deploy**. The URL stays the same, so nothing changes in the apps.

## Troubleshooting

- **"Missing tab …"**: run **Booking App → 1. Run setup** again.
- **An email wasn't picked up**: check the sender in Gmail matches
  `filter.<Platform>.senders`, and the subject matches `subject_regex`.
- **Errors from the timer**: in Apps Script, open **Executions** on the left to
  see each run and any error.
- **Editing in the Sheet directly** is fine. Keep dates as `YYYY-MM-DD`
  (e.g. `2026-11-12`). If you correct a value an email set, add the column name to
  that row's `edited_fields` (e.g. `guest_total_paid`) so future emails leave it
  alone. The app will do this for you automatically.

## For developers

```
cd apps-script
npm install
npm test          # unit tests + every sample in ../samples
npm run bundle    # rebuild dist/BookingApp.gs after editing src/
```

Source files live in `src/` (one file per parser). Apps Script shares a single
global scope across files, so `dist/BookingApp.gs` is simply all of them joined
together.
