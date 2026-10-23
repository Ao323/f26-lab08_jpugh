# PLAN.md

One section per milestone. Fill them in order, with the plan before you run
anything, the guardrail before you run a task, and the run after.

Keep it short and specific. Point at modules, gates, and file paths.

---

## Milestone 1: The plan

### Task 1: Modify an upcoming booking in place

**Behavior and scope.** In `core-domain`, add an owner-only modification flow
in `BookingService`, with supporting domain types and policy/conflict checks.
Allow changes to the interval, attendee count, or both; keep the booking ID,
room, and booked price. Reject cancelled bookings and bookings whose start is
at or before the clock's current instant. Validate the proposed details before
saving: duration bounds, slot alignment, opening hours, one UTC day, capacity,
advance window, future start, and room in service. Re-check room and owner
conflicts through `TimeInterval.overlaps`, excluding only this booking ID;
waive the held-booking cap. Rejection leaves all state unchanged. An authorized,
upcoming booking's unchanged request succeeds without writes or events.
Retain immutable old/new details and a modification timestamp in its history,
and publish a `booking-modified` domain event for a real change. Depends on
nothing; Task 2 completes waitlist behavior and Task 3 completes log delivery.

**Checkpoint.** From the repository root, run
`mvn -pl core-domain -am test`. New tests beside the existing service/policy
tests must show a fifteen-minute self-overlapping move succeeds, a distinct
room booking and a distinct owner booking each block a move, adjacent half-open
intervals succeed, and modification succeeds at the held-booking cap. Cover
each request rule, ownership, cancelled status, and the exact start-time
boundary. Compare stored state, history, and recorded events before/after a
rejection or no-op; assert a real change records one accurate history entry
and event, preserves price/identity/room, and cannot mutate prior snapshots.
Review the conflict call paths to confirm they reach `TimeInterval.overlaps`.

**Green-but-wrong risk.** Correct conflict examples can pass even if an agent
duplicates the overlap formula; the call-path review is needed to catch that
rule 3 violation.

### Task 2: Promote waiters after interval changes

**Behavior and scope.** In `core-domain/BookingService`, reuse cancellation's
FIFO promotion flow after saving a successful interval change, so candidates
are checked against the updated booking and their own calendars. Run the pass
for shortening, moving, and lengthening; pure lengthening frees nothing and
promotes nobody. Attendee-only changes, no-ops, and rejected changes start no
pass. All waitlist writes remain in `BookingService`, and promoted bookings
publish the existing promotion event. Depends on Task 1.

**Checkpoint.** Run `mvn -pl core-domain -am test` from the repository root.
New service tests queue multiple waiters and prove that shortening and moving
promote the first eligible waiter into the freed interval, skip a waiter who
now holds another room, and never overlap the retained portion. Assert booking
and waitlist store contents and promotion events, including that a newly
promoted booking blocks a later conflicting candidate. Observe pass invocation
in a focused test: lengthening runs it without promotions; attendee-only,
no-op, and rejected changes do not. Review production waitlist save/remove
call sites to confirm only `BookingService` writes them.

**Green-but-wrong risk.** Store/event assertions alone cannot distinguish a
lengthening that runs an empty promotion pass from one that skips it entirely;
the invocation check is necessary.

### Task 3: Deliver modification notifications and update the shared event ledger

**Behavior and scope.** In `notifications`, deliver the owner's old/new details
and preserve existing promotion notices and fire-and-forget failures. In
`storage/EventLogFormat`, serialize the domain event using the existing manual
JSON writer. In `analytics/campusreserve_analytics/events.py`, parse the event
and update the existing shared ledger so utilization counts the latest interval
once. Keep both reports on that same ledger; do not special-case revenue.
Update event-type lists in `AGENTS.md` and `ARCHITECTURE.md` together with the
contract. Depends on Tasks 1 and 2.

**Checkpoint.** This contract crosses module boundaries: its gate requires
all of `mvn -pl notifications -am test`, `mvn -pl storage -am test` from the
repository root, and `pytest` from `analytics/`. Add tests beside the shipped
tests in every owning module. Inspect the notification outbox for both old/new
times and attendee counts, the existing promotion notice, and no notice on
no-op/rejection; failing delivery must not undo modification or suppress later
subscribers. Verify one correctly escaped log line per real change and none
for no-op/rejection. Feed a Java-produced modification log fixture to Python:
creation followed by multiple modifications must count only the latest length,
including a move across report-window boundaries; a later cancellation removes
the holding. Confirm both reports still consume the same fold and review both
conventions files' event lists.

**Green-but-wrong risk.** Independently handwritten Java and Python fixtures
can agree with their own tests while disagreeing on the wire format; the
Java-produced fixture check must bridge that boundary.

### Task 4: Expose PATCH and history through the existing HTTP resource

**Behavior and scope.** In `http-api`, add owner-only
`PATCH /bookings/{bookingId}` using existing authentication and the modification
service. Accept interval and/or attendee-count changes; do not permit a room
change. Return history on the existing booking read surface for owners and
administrators; administrator read access does not grant modification rights.
Update the HTTP surface table in `ARCHITECTURE.md`. Depends on Tasks 1-3.

**Checkpoint.** Run `mvn -pl http-api -am test` from the repository root.
New HTTP tests PATCH each supported change and fetch the same resource to
verify current details and ordered history, including multiple modifications.
Verify owner and administrator reads, denied unrelated-user reads, denied
non-owner PATCH (including administrator), missing authentication, room-change
attempts, invalid input, started/cancelled bookings, and conflicts. After a
rejected PATCH, GET must show the original booking and history unchanged;
after a no-op PATCH, GET must show no new history. Check that the documented
route and authorization match the implemented resource.

**Green-but-wrong risk.** HTTP responses can look correct while notifications
omit old details: the API has no outbox endpoint, so Task 3's notifications
gate remains required evidence.

## Rule 3

In order to recheck if a modified booking doesn't overlap with anything, instead of usingt he current TimeInterval.overlaps program, the agents creates new overlap code just to recheck modified Bookings. This is caught by Checkpoint 1: Review the conflict call paths to confirm they reach `TimeInterval.overlaps`.

## Rule 4

The agent doesn't use BookingService to write the new waitlist rows when a waitlisted booking is promoted by a modification. This is caught by Checkpoint 2: Review production waitlist save/removecall sites to confirm only `BookingService` writes them.

## Unchanged Modules

- `billing` and invoice/pricing: the booked price is frozen
- No changes to `accounts`: reuse existing tokens and ownership checks
- No changes to `cli`: the request explicitly excludes commands. No room reassignment: it requires the normal booking flow.
- No revenue-specific logic, separate ledger, or filtering modified bookings: the request accepts revenue/invoice disagreement and requires a shared fold
- No new history endpoint: extend the existing read surface


## Milestone 3:

Takeover point & trigger: If the agent introduces a second overlap implementation—comparing booking start/end times to determine room or owner booking conflicts instead of routing through TimeInterval.overlaps—I will stop the run. I will take over the affected conflict-checking code, replace the duplicate predicate with the existing overlap path, and rerun mvn -pl core-domain -am test.

Line:

```python
  public Booking modified(TimeInterval replacement, int partySize, Instant occurredAt)
```

Looked to confirm it uses TimeInterval

- mvn -B clean test: BUILD FAILURE in notifications/NotificationKind.java:55. Its exhaustive switch needs support for the new event, planned for Task 3.

Files:
- core-domain/src/main/java/edu/cmu/cs214/campusreserve/core/domain/Booking.javacore-domain/src/main/java/edu/cmu/cs214/campusreserve/core/domain/Booking.java+22-2
- core-domain/src/main/java/edu/cmu/cs214/campusreserve/core/domain/BookingModification.javacore-domain/src/main/java/edu/cmu/cs214/campusreserve/core/domain/BookingModification.java+17-0
- core-domain/src/main/java/edu/cmu/cs214/campusreserve/core/domain/ModificationResult.javacore-domain/src/main/java/edu/cmu/cs214/campusreserve/core/domain/ModificationResult.java+23-0
- core-domain/src/main/java/edu/cmu/cs214/campusreserve/core/events/BookingModifiedEvent.javacore-domain/src/main/java/edu/cmu/cs214/campusreserve/core/events/BookingModifiedEvent.java+27-0
- core-domain/src/main/java/edu/cmu/cs214/campusreserve/core/events/DomainEvent.javacore-domain/src/main/java/edu/cmu/cs214/campusreserve/core/events/DomainEvent.java+1-1
- core-domain/src/main/java/edu/cmu/cs214/campusreserve/core/service/BookingService.javacore-domain/src/main/java/edu/cmu/cs214/campusreserve/core/service/BookingService.java+44-0
- core-domain/src/test/java/edu/cmu/cs214/campusreserve/core/service/BookingServiceModifyTest.javacore-domain/src/test/java/edu/cmu/cs214/campusreserve/core/service/BookingServiceModifyTest.java+143-0


## Finding:
0 Nonpositive attendee counts throw instead of returning a rejection. At [BookingService.java (line 157)](/C:/Users/Jenny/Desktop/AgenticAI/f26-lab08_jpugh/core-domain/src/main/java/edu/cmu/cs214/campusreserve/core/service/BookingService.java:157), constructing BookingRequest throws before rules.checkRequest runs.

- Test: Fix the clock at 2026-10-19T09:00:00Z. Create an owned booking for October 20, 10:00–11:00, with four attendees in a ten-seat room. Call:
service.modifyBooking(id, "u-1", original.interval(), 0); Repeat with -1.

- Both calls throw IllegalArgumentException: Attendees must be positive. By comparison, 11 returns Rejected[reason=ATTENDEES_EXCEED_CAPACITY].

- Requirement: Task 1 validates proposed details before saving; change-request clause 3 requires the request-level attendee check. This is an inconsistent invalid-input response, not state corruption: booking, history, waitlist, and events remain unchanged. If nonpositive counts are intended as caller precondition violations, the contract needs to say so.