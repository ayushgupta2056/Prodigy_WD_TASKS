# Sample emails

The email parsers are built and tested against these files, so they need to be
**real emails** from your inbox, anonymised. Please don't retype them. The layout
and the HTML matter.

## What to collect

For **each** platform, if you have them:

| Email | Why |
|---|---|
| New booking confirmation | the main case |
| Cancellation | to free the dates |
| Modification (dates or guests changed) | to update a booking |
| Any other email from the platform you'd like ignored (payout, review request, reminder) | so the filters skip it |

Two different bookings per platform is ideal, because it shows which parts of the
email change and which stay fixed.

## How to save an email

1. Open the email in Gmail on a computer.
2. Click **⋮** (top right of the email) → **Download message**. You get a `.eml` file.
3. Put it in the right folder here and give it a clear name:

```
samples/
  airbnb/        booking-1.eml  booking-2.eml  cancellation-1.eml  modified-1.eml
  makemytrip/    ...
  goibibo/       ...
  agoda/         ...
  booking.com/   ...
```

## How to anonymise

Open the `.eml` in Notepad and use **Find & Replace** to change:

- guest names, phone numbers and email addresses → fake ones (e.g. `Rahul Sharma` → `Test Guest`)
- your own address, phone and bank details

Please **keep these as they are**, or change them only consistently:

- booking IDs (you can swap digits, but keep the same length and format)
- dates, amounts, ₹ signs, commas, labels and the overall layout

Some emails are encoded (long lines of letters ending in `=`, or `=E2=82=B9`).
If you can't see the guest name in Notepad, don't worry. Just tell me, and I'll
anonymise those parts here before anything is committed.

## Expected results

Next to each email I'll add `<name>.expected.json` with what the parser should
read from it, and you'll confirm the values are right. The test
(`apps-script/tests/samples.test.js`) runs every parser on every sample.
