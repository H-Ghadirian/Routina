# 0208 — Preserve the meaning of parsed task dates

Date: 2026-08-20

## Symptom

After Quick Add learned to recognize `Physiotherapist Tuesday, 25 August 15:00`, it removed the scheduling words from the title but set both a deadline and reminder. The resulting task still showed `Any date` and `Any time` availability.

## Root Cause

The parser represented every one-off date with the older `deadline` and `reminderAt` fields instead of preserving the person's semantic intent. Recognition tests asserted that storage shortcut, so they protected token extraction while encoding the wrong product meaning. The Quick Add save boundary also failed to carry the parser's calendar into date normalization, which could shift a parsed availability day when the parser and system calendars differed.

## Fix

Unqualified one-off dates now populate date availability, accompanying times populate time availability, and reminder creation requires an explicit choice. `due` and `by` remain explicit deadline syntax. Relative reminder controls now use exact availability as their event reference, and Quick Add preserves the parsing calendar through save normalization.

## Prevention Rule

Natural-language tests must assert the user-facing scheduling concept—not merely that some date field was populated. Availability, planning, deadline, and reminder must remain independently asserted at parser, form, and persistence boundaries.

## Regression Safeguard

`RoutinaQuickAddParserTests` protects the exact phrase, explicit deadline wording, persisted availability, and chosen reminder. `AddRoutineFeatureTests` protects form application and relative reminder anchoring. The Quick Add explicit-date scenario records the cross-platform contract.
