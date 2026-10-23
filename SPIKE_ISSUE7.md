# Scheduled Live Activity spike — issue #7

Throwaway branch only. Every iOS Debug launch opens the probe, bypassing normal
timer publication/reconciliation so it cannot cancel the experimental activities.
Release behavior and the production publishing protocol are unchanged. No AlarmKit.

## Result: GO-pending-device-check

1. **GO (simulator): pending cancellation.** Three requests were confirmed pending,
   then ended immediately, after two seconds, and approximately one second before
   their scheduled start. All were dismissed and absent from `Activity.activities`
   after their original deadlines. `await end` can return while state is still
   pending: terminal state is eventually observed, not synchronous with return.
2. **GO (simulator): scheduled expanded presentation.** With Passata backgrounded
   behind Settings, a future request automatically displayed the existing green
   Short Break expanded Island at the boundary. No manual expansion or app-driven
   boundary update was used. Physical-device confirmation remains advisable.
3. **GO-pending-device-check: relevance.** The first pair used A=10 and B=100 and
   the new green activity appeared at the boundary, consistent with Apple's rule.
   A later update successfully changed A to 200, but subsequent simulator captures
   omitted Island content; a visual reversal was not established independently
   of B's alert presentation. Apple documents highest-score selection and ordering.
4. **GO-pending-device-check: sound, Silent, Focus.** `.default` is configured.
   No physical Silent switch exists here, and no audible/Focus result was verified.
   SDK availability is not proof of the desired sound policy.
5. **GO-pending-device-check: old Lock Screen card.** A remained enumerated/stale
   while B was active. Lock commands did not produce a usable Lock Screen capture,
   so actual card stacking/residency was not visually established. A stale date
   does not end A. Apple's upper bound is eight hours active, then up to four more
   on Lock Screen (12 from start), not four hours from countdown zero. An explicit
   end with default dismissal allows up to four hours from end; immediate removes it.

## Evidence

Local evidence: `/private/tmp/passata-issue7-spike/`.

- `cancellation.log`: original three passing cancellation cases.
- `cancellation-final.log`: repeat against final Debug artifact.
- `pair-scheduled.log`, `post-start-states.log`: IDs, dates, scores and old/new states.
- `frame-44.png`: old red countdown immediately before boundary.
- `frame-50.png`: automatically expanded green Short Break over Settings.
- `relevance-before.log`, `relevance-after.log`: successful score reversal at API level.
- `build.log`: iOS Debug build succeeded, Xcode 27.1 (27A9275), SDK 27.1;
  runtime iOS 27.0, iPhone 18 Pro Max B1ECDAD0-8EAF-465F-A0EC-365B0EE15CC6.
- Later blank-Island captures are inconclusive; the early process-termination
  experiment was contaminated by production reconciliation and is not evidence
  for or against survival after termination.

SDK `ActivityKit.swiftinterface` copied into evidence: line 68 is the current
future `start:` request; 69–75 deprecate `startDate:`; 185 is async `end`;
385 is `.pending`; 408–419 expose relevance; 436–445 expose alert/default sound.

Apple sources:

- [Displaying live data](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities):
  scheduling, highest-score Island selection, alert expanded presentation,
  eight-hour active/four-hour post-end lifetime and dismissal policies.
  Local downloaded `apple-guide.md` lines 49, 352–363, 406–410, 473, 517–519.
- [Pending state](https://developer.apple.com/documentation/activitykit/activitystate/pending).
- [Alert configuration](https://developer.apple.com/documentation/activitykit/alertconfiguration).

## Physical-device checklist

1. Open this floor's `Passata.xcodeproj`, branch `spike/scheduled-live-activity`;
   run scheme Passata **Debug** on a Dynamic Island iPhone with iOS 26.5 or newer
   using the existing signing setup. This is a probe, not a production timer.
   Enable Live Activities for Passata. Do not install this build for normal use.
2. Tap **End all spike activities**, then **Run cancellation gate**. Wait about
   42 seconds for GO; repeat with the device locked during the wait. Check that
   no cancelled activity appears at any original deadline. Save the screen/log.
3. Tap **Start A and schedule B in 45 seconds**, then leave Passata for Settings.
   At the boundary, record automatic green Short Break expanded presentation,
   not just a manually long-pressed compact activity. Repeat while locked.
4. After B starts, return to the probe and tap **Promote previous A to score 200**;
   leave the app and verify old red A wins the Island. Snapshot/log both scores.
5. Repeat the pair with audible volume under: Ring + Focus off; Silent + Focus
   off; Ring + Do Not Disturb with Passata not allowed; Silent + that Focus.
   Record sound and visual presentation for each. Desired: audible only in the
   first case. A contrary result blocks the intended calm sound contract.
6. On Lock Screen inspect A and B immediately, after one minute, and after five
   minutes. Record old A's stale/zero presentation and card order. The 12-hour
   bound above is documented, not an elapsed-time measurement from this spike.
   Decide whether this coexistence is acceptable or requires explicit A cleanup.
7. **End all spike activities**, confirm both cards disappear, then remove the
   probe or reinstall a normal build. Logs are in app Documents as
   `scheduled-activity-spike.log` (overwritten per probe process).

## Contract impact if device checks pass

Production `LiveActivityPublishing` cannot remain a single implicit-current
activity abstraction. It needs explicit identities for current A and pending B,
future request with alert/start/relevance, cancellation by identity with eventual
terminal confirmation, and reconciliation/adoption of B rather than arbitrary
`activities.first`. Pause, resume, skip, reset and duration changes must cancel or
replace pending B and coordinate completion notifications. Schedule only the next
boundary while foregrounded, for auto-start and not long-break completion, per the
approved design. Relevance alone does not retire A. Lifecycle and old-card policy
need implementation/design acceptance separately; this spike changes neither.
