"""Rediff bridge: copies booking emails from a Rediffmail inbox into Gmail.

Agoda and MakeMyTrip send booking emails to Rediffmail, and free Rediffmail
cannot auto-forward. This script reads the Rediff inbox over POP3 (or IMAP),
picks the emails sent by the booking sites, and puts an exact copy into the
Gmail inbox over IMAP. The copy keeps its original sender, so the Apps Script
reads it like any other booking email.

- Nothing is deleted or changed in Rediffmail.
- An email already in Gmail (same Message-ID) is never copied twice.
- It prints counts only, never names, subjects or addresses (CI logs are public).

Settings come from environment variables:
  REDIFF_USER, REDIFF_PASSWORD           your Rediffmail login
  GMAIL_USER, GMAIL_APP_PASSWORD         your Gmail address + a Google app password
  BRIDGE_SENDERS   sender domains to copy  (default: agoda.com,makemytrip.com)
  REDIFF_PROTOCOL  pop3 or imap            (default: pop3)
  REDIFF_HOST      server                  (default: pop.rediffmail.com / imap.rediffmail.com)
  BRIDGE_SCAN      newest N emails to check each run (default: 60)
"""

import email
import email.policy
import email.utils
import imaplib
import os
import poplib
import re
import sys
import time

GMAIL_HOST = 'imap.gmail.com'


def sender_matches(from_header, domains):
    addr = (email.utils.parseaddr(from_header or '')[1] or '').lower()
    return any(addr.endswith('@' + d) or addr.endswith('.' + d) for d in domains)


def headers_of(raw):
    return email.message_from_bytes(raw, policy=email.policy.compat32)


# ---- Rediff side: yields (headers, fetch_full) for the newest N emails ----

def rediff_pop3(host, user, password, scan):
    box = poplib.POP3_SSL(host, 995, timeout=60)
    box.user(user)
    box.pass_(password)
    try:
        count = len(box.list()[1])
        for n in range(count, max(0, count - scan), -1):
            head = b'\r\n'.join(box.top(n, 0)[1])
            yield headers_of(head), (lambda n=n: b'\r\n'.join(box.retr(n)[1]) + b'\r\n')
    finally:
        box.quit()  # POP3 only deletes on QUIT if DELE was sent; we never send it


def rediff_imap(host, user, password, scan):
    box = imaplib.IMAP4_SSL(host, 993)
    box.login(user, password)
    try:
        box.select('INBOX', readonly=True)
        ids = box.search(None, 'ALL')[1][0].split()
        for i in reversed(ids[-scan:]):
            head = box.fetch(i, '(BODY.PEEK[HEADER])')[1][0][1]
            yield headers_of(head), (lambda i=i: box.fetch(i, '(BODY.PEEK[])')[1][0][1])
    finally:
        box.logout()


# ---- Gmail side ----

class Gmail:
    def __init__(self, user, password, host=GMAIL_HOST):
        self.box = imaplib.IMAP4_SSL(host, 993)
        self.box.login(user, password)
        self.box.select('INBOX')

    def has(self, message_id):
        mid = message_id.strip().strip('<>')
        # Gmail search across all mail, so an email you archived is not copied back.
        typ, data = self.box.uid('SEARCH', 'X-GM-RAW', '"rfc822msgid:%s"' % mid.replace('"', ''))
        return typ == 'OK' and bool(data and data[0].split())

    def add(self, raw, date_header):
        when = email.utils.parsedate_to_datetime(date_header) if date_header else None
        stamp = imaplib.Time2Internaldate(when.timestamp() if when else time.time())
        self.box.append('INBOX', None, stamp, raw)

    def close(self):
        try:
            self.box.logout()
        except Exception:
            pass


def run(rediff_messages, gmail, domains):
    copied = skipped = 0
    for head, fetch in rediff_messages:
        if not sender_matches(head.get('From'), domains):
            continue
        mid = head.get('Message-ID')
        if not mid or gmail.has(mid):
            skipped += 1
            continue
        gmail.add(fetch(), head.get('Date'))
        copied += 1
    return copied, skipped


def main():
    need = ['REDIFF_USER', 'REDIFF_PASSWORD', 'GMAIL_USER', 'GMAIL_APP_PASSWORD']
    missing = [k for k in need if not os.environ.get(k)]
    if missing:
        print('Rediff bridge not set up yet (missing: %s). Nothing to do.' % ', '.join(missing))
        return 0
    domains = [d.strip().lower() for d in (os.environ.get('BRIDGE_SENDERS') or 'agoda.com,makemytrip.com').split(',') if d.strip()]
    protocol = (os.environ.get('REDIFF_PROTOCOL') or 'pop3').lower()
    host = os.environ.get('REDIFF_HOST') or ('imap.rediffmail.com' if protocol == 'imap' else 'pop.rediffmail.com')
    scan = int(os.environ.get('BRIDGE_SCAN') or '60')
    reader = rediff_imap if protocol == 'imap' else rediff_pop3

    try:
        gmail = Gmail(os.environ['GMAIL_USER'], os.environ['GMAIL_APP_PASSWORD'])
    except Exception as e:
        print('Could not sign in to Gmail (%s). Check GMAIL_USER and GMAIL_APP_PASSWORD.' % type(e).__name__)
        return 1
    try:
        copied, skipped = run(reader(host, os.environ['REDIFF_USER'], os.environ['REDIFF_PASSWORD'], scan), gmail, domains)
    except (poplib.error_proto, imaplib.IMAP4.error, OSError) as e:
        print('Could not read Rediffmail over %s (%s). Check REDIFF_USER / REDIFF_PASSWORD; if they are right, '
              'this Rediff account does not allow outside programs (free accounts may need Rediffmail Pro).'
              % (protocol.upper(), type(e).__name__))
        return 1
    finally:
        gmail.close()
    print('Copied %d new booking email(s) to Gmail; %d already there.' % (copied, skipped))
    return 0


if __name__ == '__main__':
    sys.exit(main())
