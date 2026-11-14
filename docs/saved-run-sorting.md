# Saved-run sorting and DTC integration

This update combines Mateen's `main` changes through `5b0c9f4` with the DTC
feature through `a86ba60`, then adds saved-run sorting. It preserves both
branches' commits, including account continuation, full-session graphs,
branding updates, bounded parallel restores, and live DTC diagnostics.

## Using saved-run sorting

Open Saved runs from Live or Settings. The initial order is **Date / Descending**
(newest trip first). Use the two controls at the top of the list:

| Sort by | Ascending | Descending |
| --- | --- | --- |
| Date | Oldest trip first | Newest trip first |
| Duration | Shortest trip first | Longest trip first |

Duration is the elapsed time between a trip's start and end, not distance driven
or sample count. Cards show it as hours:minutes:seconds. Open runs or invalid end
times display **Duration unavailable** and sort last in either duration order.
Zero-length completed runs are valid. Ties use the local ID for a stable order.

Sorting applies to all visible runs in SQLite, including restored trips that
were inserted later than newer trips. **Load more recordings** follows the
chosen order across pages. Changing either control starts again at the first
page; refreshes retain the selection for the current screen. Reopening the
screen starts with newest first. Account visibility rules are unchanged.

## Why the previous order looked random

The old query ordered sessions by local database ID. A cloud-restored old trip
can receive a newer ID than a recently recorded trip. The new query orders by
the trip's actual start timestamp, comparing UTC instants even when timestamp
strings use different timezone offsets.

Pagination uses the previous page's final recording as a cursor for the selected
sort value and ID. It does not sort only the currently displayed page. Pending
results from an earlier sort selection are discarded, so a late response cannot
overwrite the newly selected order. No database migration or data rewrite is
required.

## Validation

- `test/recordings/recording_sort_test.dart` uses real SQLite to check restored
  trip order, timezone offsets, all four sort combinations, stable ties, 132-run
  pagination, incomplete durations, and account isolation.
- `test/recordings/recordings_screen_test.dart` checks the controls, refresh
  behavior, late-response handling, and usability at 320 px with enlarged text.
- The combined version is checked with `flutter analyze` and `flutter test`,
  including the existing DTC, full-session graph and restore performance tests.

## How to handle a feature branch when main has moved ahead

An older feature branch can still be merged. Git combines changes since the
branches' shared ancestor; replacing main's files with the older app is not
necessary. For this update, the integration branch starts at the latest main,
merges the DTC branch, and adds the sorting work. After validation, main advances
to that combined history. Existing author credits are preserved; the four new
integration, sorting, regression-test and documentation commits use Masab Tahir.

For future changes, start a new branch from current main, implement and test
there, fetch main again before merging, and resolve any conflicts before
publishing. This keeps the shared app's latest fixes alongside your work.
