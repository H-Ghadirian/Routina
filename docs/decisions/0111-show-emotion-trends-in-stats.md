# 0111: Show Emotion Trends in Stats

## Status

Accepted

## Date

2026-05-31

## Context

Emotion logs store pleasantness, energy, intensity, and emotion families. Stats already surfaces factual emotion summary cards, but those cards do not show how pleasantness or energy changes over time.

## Decision

Stats includes an Emotion Trends chart that plots daily average pleasantness and energy for emotion logs in the selected range. The chart also surfaces the highest average-intensity day as a factual highlight.

The chart uses only stored emotion log values and remains separate from generated or narrative insight features.

## Consequences

- Users can see emotional direction and energy shifts over the same Stats ranges used for other activity.
- Multiple emotion logs on the same day are averaged into one daily point.
- Days without emotion logs are omitted from the line series instead of implying a neutral mood.
