import unittest

import rediff_bridge as rb


def raw(frm, mid, subject='Booking'):
    return ('From: %s\r\nMessage-ID: <%s>\r\nDate: Sat, 21 Nov 2026 10:00:00 +0530\r\nSubject: %s\r\n\r\nbody\r\n'
            % (frm, mid, subject)).encode()


class FakeGmail:
    def __init__(self, existing=()):
        self.ids = set(existing)
        self.added = []

    def has(self, mid):
        return mid.strip('<>') in self.ids

    def add(self, data, date):
        self.added.append(data)
        self.ids.add(rb.headers_of(data).get('Message-ID').strip('<>'))


def inbox(*raws):
    return [(rb.headers_of(r), (lambda r=r: r)) for r in raws]


class BridgeTest(unittest.TestCase):
    domains = ['agoda.com', 'makemytrip.com']

    def test_copies_only_booking_site_emails(self):
        g = FakeGmail()
        c, s = rb.run(inbox(raw('Agoda <no-reply@agoda.com>', 'a1'),
                            raw('MakeMyTrip <noreply@email.makemytrip.com>', 'm1'),
                            raw('Friend <friend@rediffmail.com>', 'f1'),
                            raw('evil@notagoda.com', 'e1')), g, self.domains)
        self.assertEqual((c, s), (2, 0))
        self.assertEqual(g.ids, {'a1', 'm1'})

    def test_never_copies_twice(self):
        g = FakeGmail(existing={'a1'})
        self.assertEqual(rb.run(inbox(raw('no-reply@agoda.com', 'a1')), g, self.domains), (0, 1))
        msgs = inbox(raw('no-reply@agoda.com', 'a2'))
        rb.run(msgs, g, self.domains)
        self.assertEqual(rb.run(msgs, g, self.domains), (0, 1))
        self.assertEqual(len(g.added), 1)

    def test_copy_is_the_exact_original(self):
        g = FakeGmail()
        r = raw('no-reply@agoda.com', 'a3', 'Booking confirmed')
        rb.run(inbox(r), g, self.domains)
        self.assertEqual(g.added[0], r)


if __name__ == '__main__':
    unittest.main()
