# Change request: booking modification

From: Product, CampusReserve
Status: approved for the next release

## Why

Bookers cannot change a booking they already hold. Today they cancel and rebook,
which loses their slot to whoever is waiting and generates a support ticket
roughly once a day. We want them to be able to adjust a booking in place.

## What we want

A booker may change the time interval, the attendee count, or both, on an
upcoming booking they own. The room stays the same.

The full behavior we are asking for:

1. **Ownership and timing.** Only the booker may modify their own booking, and
   only while the booking is still upcoming. A booking that has started or that
   has been cancelled cannot be modified.
2. **Conflict re-check.** A modification re-runs the room conflict check against
   the new interval. If the new interval collides with another booking, the
   modification is rejected and the original booking stands unchanged. A
   rejected modification changes nothing at all. The check ignores the booking
   being modified. A booking does not collide with itself, so nudging a booking
   by fifteen minutes, one slot, has to be allowed. The booker's own calendar is
   checked the same way, ignoring the booking being modified, so a booker still
   cannot end up holding two rooms at once. The cap on how many bookings a person
   may hold does not come into it. The booking already has its place in that
   count.
3. **The rules still apply.** A modified booking has to satisfy every rule in the
   booking request check, and that list is the whole list: the minimum and
   maximum duration, slot alignment, opening hours, staying inside one UTC day,
   the room's capacity against the new attendee count, the advance window,
   starting in the future rather than the past, and the room still being in
   service. The room conflict re-check and the booker's own calendar are clause
   2's business, and the cap on bookings held stays waived
   there.
4. **Freed time goes to the waitlist.** Time that a successful modification
   frees up triggers the same first in, first out waitlist promotion that a
   cancellation triggers today, with the same no-double-booking re-check. The
   promotion pass runs when a successful modification changed the interval. A
   change to the attendee count alone frees no time and starts no promotion. A
   modification that only lengthens a booking frees nothing either. Running the
   pass and promoting nobody is the right outcome there.
5. **History.** The booking retains its modification history: what changed and
   when. A booker or an administrator can see what a booking used to be, on the
   read surface the booking already has, without a new endpoint to ask for it.
   A modification that changes nothing succeeds and records nothing at all (no
   history entry, no notification to the owner, and no event in the log).
6. **Notification.** The owner gets a notification carrying both the old details
   and the new ones. Anyone promoted off the waitlist gets the promotion notice
   that already exists.
7. **HTTP.** The change is exposed as `PATCH` on the booking resource,
   owner-only, alongside the endpoints that already exist.
8. **Event log.** A `booking-modified` event goes in the event log. The
   utilization report must count a booking whose interval changed at its
   current length only.
9. **The conventions files stay true.** `AGENTS.md` and `ARCHITECTURE.md` both
   promise to describe the platform as it is, but this change makes three of
   their statements false (the event-type list in each file, and the table of the
   HTTP surface in `ARCHITECTURE.md`, which will be missing the new endpoint).
   Correcting them is part of this change.

## What is explicitly out of scope

These are decisions. Do not do them.

- **The price does not change.** A modified booking keeps the price it was
  booked at. Billing is not part of this change request. Do not re-price,
  re-issue, or void and re-invoice.
- **The room does not change.** Moving a booking to a different room is a
  separate request that we have not approved.
- **Nothing in the CLI.** The administrative commands render fields that already
  exist and do not need a new command.
- **Nothing in account management.** Modification uses the token and ownership
  checks that already exist. Accounts does not change.
- **The revenue report is not part of this change.** It prices time from the
  event stream, so after a modification it can disagree with the invoice we
  actually issued, which the price rule above freezes. We accept that for this
  release. Do not filter modified bookings out of it either, and do
  not fork the reading to keep them apart. The ledger learns the new event once,
  and both reports go on reading the same fold of it. The utilization report is
  the only report in scope.

## How we will know it works

- A booker can shorten, lengthen, or move a booking within the same room and see
  the new times.
- A modification into a taken slot is refused and the original booking survives
  intact.
- Someone on the waitlist for the time that was freed gets that time.
- The owner's notification names both the old and the new details. There is no
  HTTP surface on the outbox, so a notifications test is the evidence for this
  one.
- The utilization report over a window containing a modified booking reports its
  current length.
