# Recording restore performance

Version 1.1.3 improves restore efficiency without changing cloud formats or
requiring a backend migration:

- Fetch up to 64 chunk manifests per request instead of one.
- Prefetch at most three compressed objects, consuming and committing them in
  acquisition order. Checksums, sizes, ownership and chunk chains are verified.
- Resume at the last committed SQLite page after a disconnect or restart,
  instead of clearing staging and downloading the drive again.
- Use 1,000-row pages for legacy recordings. Both formats paginate until an
  empty response, including when the server caps pages below the requested size.
- Restore the newest drives first. Show each completed drive immediately,
  with reading-count progress for the drive currently being restored.
- Stop waiting for the pending upload queue before beginning downloads.

SQLite already inserts each page as a batch in a transaction. Partial drives
remain hidden until their exact expected sample count has been verified and
the full drive has been published atomically. Existing phone recordings are
not deleted. Prefetch errors remain handled when a restore is cancelled.
If validation detects an inconsistent staged prefix from an older attempt,
repair it once by downloading that drive from the start. Network interruptions
and corrupt downloads preserve valid checkpoints instead of discarding them.

## Synthetic measurement

`test/recordings/restore_performance_test.dart` restores 32,000 readings from
32 compressed objects, with a simulated 40 ms delay per HTTP request. Its timer
includes network simulation, decoding and SQLite staging/publication, and
excludes fixture construction and test compilation.

| Measurement | Previous version | Optimized version |
| --- | ---: | ---: |
| Metadata requests | 33 | 2 |
| Object downloads | 32 | 32 |
| Maximum concurrent downloads | 1 | 3 |
| End-to-end elapsed time | 4,246 ms | 1,342 ms |

This local synthetic run was approximately 3.2 times faster. It is not a phone
or live-network benchmark; actual results depend on latency, bandwidth, device
storage and the number of drives. Tests assert request counts, bounded
concurrency and lossless restoration, rather than fragile wall-clock limits.

Run validation with:

```powershell
flutter test test/recordings/restore_performance_test.dart test/recordings/restore_pipeline_test.dart
```

The pipeline tests cover out-of-order HTTP completion, interrupted restore and
retry, server-capped manifest pages, corrupt objects, account changes and
consumer cancellation. The existing long-recording test verifies 105,120
readings across bounded pages.
