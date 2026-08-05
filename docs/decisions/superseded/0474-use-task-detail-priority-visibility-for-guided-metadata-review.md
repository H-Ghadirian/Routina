# 0474: Use Task Detail Priority Visibility for Guided Metadata Review

## Status

Superseded by [0475 Separate Guided Importance and Urgency Reviews](../0475-separate-guided-importance-and-urgency-reviews.md)

## Date

2026-08-05

## Historical Decision

This record originally chose one compact iOS More procedure that collected both
Importance and Urgency together. It used the existing `showsTaskDetailPriority`
flag to distinguish untouched legacy `Medium` values from an explicit
`Medium` / `Medium` choice.

That aggregate flag cannot represent a person choosing only one field. The
replacement decision introduces independent explicitness markers and separate
procedures, while preserving this record as the compatibility rationale for
legacy tasks.

## Historical Debt Link

[Debt ticket 0001](../../debt/0001-make-importance-and-urgency-explicitly-optional.md)
