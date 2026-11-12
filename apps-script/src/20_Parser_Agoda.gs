/**
 * Agoda email parser.
 *
 * NOT IMPLEMENTED YET. It will be written against real (anonymised) sample
 * emails in samples/agoda/ rather than guessed. Until then every Agoda
 * booking email is sent to "Unparsed emails" so nothing is lost.
 *
 * Contract: see 10_Parsers.gs. Return a ParsedEmail or throw.
 */
function parseAgodaEmail(email) {
  throw new ParserNotReadyError('Agoda');
}
