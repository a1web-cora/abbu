<!-- docs/ALTERNATE_CALENDAR_EVIDENCE.md -->

# Alternate Calendars: Preserve Uncertainty

Research date: 2026-10-01. Issue [#36](https://github.com/scarver2/abbu/issues/36).
Proposed outcome: insufficient private-format evidence for new calendar,
leap-month or year-cycle decoding. Existing Gregorian and legacy lunar accessors
remain unchanged; this is documentation, not a conversion feature.

## What Apple Documents

Apple's public [birthday property](https://developer.apple.com/documentation/contacts/cncontact/birthday)
uses Gregorian date components with required month/day and optional year.
The [non-Gregorian birthday property](https://developer.apple.com/documentation/contacts/cncontact/nongregorianbirthday)
requires a non-Gregorian calendar and month/day, with optional year and leap-month
information. These are framework contracts, not a private SQLite/plist mapping.

The distinction matters: a label containing “LunarBirthday” and three numeric
components do not establish which calendar, leap-month state, cycle, era or
conversion rule applies. Do not default an unknown calendar to Chinese, treat
absence of a leap marker as false, or interpret a year as Gregorian merely
because its numeric range looks familiar.

Sources were inspected on the research date. No native framework calls,
real-address-book reads, or Apple import/export experiments were performed.
Third-party observations would remain hypotheses until independently reproduced.

## Repository Audit at Main `77eaeda`

- `SqliteParser` exposes rows from the known date-component table and selects
  `lunar_birthday` by the normalized `LunarBirthday` label. Existing tests use a
  synthetic `_$!<LunarBirthday>!$_` label with year/month/day and retain raw label.
- `PlistParser#extract_lunar_birthday` accepts a date-like `LunarBirthday` value
  and reads year/month/day. Its synthetic fixture is not an attributed Apple
  alternate-calendar export.
- Neither mapping establishes calendar identifier, leap month, era or year
  cycle. No reproducible version-attributed mapping for those components is in
  the [compatibility corpus](FORMAT_COMPATIBILITY.md).
- Current vCard/CSV/JSON exposure is legacy behavior, not evidence that a target
  app interprets alternate calendars correctly. Existing tests must remain; do
  not silently reinterpret or convert those numbers to improve presentation.

The normalized Contact model is not a complete raw database or plist copy.
Unknown columns/keys are not guaranteed to survive it. Keep original archives
as evidence; do not claim this docs-only decision makes current parsing lossless
for unmodeled metadata. Any future recognized representation must preserve its
original components alongside derived display values before conversion ships.

## Reproduction Gate

1. Use an explicitly approved disposable, unsynced test account with invented
   contacts. Record exact macOS and Contacts builds, calendar configuration,
   locale, export method and the UI value entered.
2. Vary one component at a time: calendar, optional year, leap month, ordinary
   month, era/cycle where supported, and missing versus false. Include Gregorian
   controls and dates sharing the same numeric components across calendars.
3. Observe exports without changing source stores. Capture raw representation,
   candidate links and original bytes. Record unavailable components as unknown;
   do not invent keys or table schemas for synthetic fixtures.
4. Reproduce the mapping independently, then create sanitized minimal fixtures
   retaining exact observed representation and version provenance. Test custom
   labels, malformed near-matches, Unicode, sparse/legacy schemas and duplicate
   records across sources. Keep every existing Gregorian regression passing.
5. Design raw and interpreted RBS/API fields together. Require explicit calendar
   identity and supported conversion rules before generating Gregorian dates or
   recurrences. A future exporter must diagnose or omit unsupported calendar
   data explicitly, never fabricate an age, date or leap state.
6. Validate any interchange claim by isolated export/import/re-export testing
   on each claimed target build; serialization alone is not import evidence.

No additional storage representation is accepted by this research. The outcome
is to defer decoding until concrete evidence meets these gates, not to remove
legacy data or declare all lunar support complete. Under the development-train
directive this evidence boundary resolves the research scope; a new proposal
must supply the missing reproducible corpus before implementation.

Return to [README](../README.md), [roadmap](TODO.md), or [format evidence](ABBU.md).

—
Stan Carver II
Made in Texas 🤠
https://stancarver.com
