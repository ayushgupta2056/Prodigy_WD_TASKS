/**
 * Booking & Profit Manager — backend configuration.
 *
 * Everything that is fixed by the app lives here. Everything YOU may want to
 * change (properties, which emails to read, search window) lives in the
 * "Settings" tab of the Google Sheet and is seeded from DEFAULT_SETTINGS below
 * the first time you run setup().
 */
var APP = {
  VERSION: '0.2.0',

  /** Bump whenever a parser changes: emails that failed to parse with an older
   *  version are automatically tried again on the next run. */
  PARSER_VERSION: 1,

  SHEETS: {
    BOOKINGS: 'Bookings',
    BLOCKS: 'Blocks',
    SETTINGS: 'Settings',
    PARSER_LOG: 'ParserLog'
  },

  LABEL_PROCESSED: 'BookingApp/Processed',
  LABEL_UNPARSED: 'BookingApp/Unparsed',

  PLATFORMS: ['Airbnb', 'MakeMyTrip', 'Goibibo', 'Agoda', 'Booking.com', 'Direct', 'Other'],
  EMAIL_PLATFORMS: ['Airbnb', 'MakeMyTrip', 'Goibibo', 'Agoda', 'Booking.com'],
  STATUSES: ['confirmed', 'cancelled', 'completed'],
  SOURCES: ['email', 'manual'],
  BLOCK_REASONS: ['personal use', 'maintenance', 'held', 'other'],
  EMAIL_TYPES: ['new', 'modification', 'cancellation'],

  /** Column order of each tab. Code reads/writes by header name, so the order
   *  only matters when the tab is first created. */
  COLUMNS: {
    Bookings: [
      'id', 'property', 'platform', 'platform_booking_id', 'guest_name', 'guests_count',
      'check_in', 'check_out', 'nights',
      'guest_total_paid', 'in_hand_amount', 'costs',
      'status', 'source', 'edited_fields',
      'email_message_id', 'created_at', 'updated_at', 'notes'
    ],
    Blocks: ['id', 'property', 'start_date', 'end_date', 'reason', 'notes', 'created_at', 'updated_at'],
    Settings: ['key', 'value', 'notes'],
    ParserLog: [
      'email_message_id', 'thread_id', 'platform', 'result', 'type',
      'platform_booking_id', 'booking_id', 'error',
      'subject', 'from', 'received_at', 'timestamp', 'resolved', 'parser_version'
    ]
  },

  /** Columns stored as plain text so Sheets never auto-converts them. */
  TEXT_COLUMNS: {
    Bookings: ['id', 'platform_booking_id', 'check_in', 'check_out', 'email_message_id',
      'created_at', 'updated_at', 'edited_fields'],
    Blocks: ['id', 'start_date', 'end_date', 'created_at', 'updated_at'],
    Settings: ['key', 'value'],
    ParserLog: ['email_message_id', 'thread_id', 'platform_booking_id', 'booking_id',
      'received_at', 'timestamp']
  },

  /** Booking fields an email may set or change. Anything listed in a booking's
   *  edited_fields is never touched by the email parser. in_hand_amount, costs
   *  and notes are never set from email at all. */
  EMAIL_OWNED_FIELDS: ['guest_name', 'guests_count', 'check_in', 'check_out', 'guest_total_paid', 'status'],

  /** Stop processing before Apps Script's 6-minute limit. */
  MAX_RUNTIME_MS: 4.5 * 60 * 1000,

  TRIGGER_FUNCTION: 'processNewEmails',
  TRIGGER_EVERY_MINUTES: 5
};

/**
 * Defaults written into the Settings tab on first setup. Edit them in the
 * Sheet afterwards, not here.
 *
 * filter.<Platform>.senders        comma-separated sender domains/addresses
 * filter.<Platform>.subject_regex  an email must ALSO match this subject pattern
 *                                  (case-insensitive) to count as a booking email.
 *
 * NOTE: the subject patterns are deliberately broad placeholders. They will be
 * tightened once real sample emails are in samples/.
 */
var DEFAULT_SETTINGS = [
  ['currency', 'INR', 'Fixed'],
  ['properties', 'My Homestay', 'Comma-separated list of your properties'],
  ['default_property', 'My Homestay', 'Property used for emailed bookings when the email does not say which one'],
  ['search_window_days', '30', 'How many days back each 5-minute run looks in Gmail'],
  ['filter.Airbnb.senders', 'airbnb.com', ''],
  ['filter.Airbnb.subject_regex', 'reservation|booking|cancel', 'Provisional'],
  ['filter.MakeMyTrip.senders', 'makemytrip.com', ''],
  ['filter.MakeMyTrip.subject_regex', 'booking|reservation|cancel', 'Provisional'],
  ['filter.Goibibo.senders', 'goibibo.com', ''],
  ['filter.Goibibo.subject_regex', 'booking|reservation|cancel', 'Provisional'],
  ['filter.Agoda.senders', 'agoda.com', ''],
  ['filter.Agoda.subject_regex', 'booking|reservation|cancel', 'Provisional'],
  ['filter.Booking.com.senders', 'booking.com', ''],
  ['filter.Booking.com.subject_regex', 'booking|reservation|cancel', 'Provisional']
];
