# RunLog

Logging your runs and view useful statistics.
The goal of this app is to have an as easy-to-use as possible app which
saves your runs.

Current implementation:
- lists past runs
- exports / imports gpx files
- various graphs with speed / slope / altitude
- pruning beginning and end of runs to remove unuseful data
- update altitude data for Switzerland

Future features:
- modify graphs directly in the phone

Dream features:
- upload a gpx file, give a target pace, and the app uses past runs to guide you
through the run - slower when uphill, faster when downhill
- better tagging of runs when preparing for a challenge
- use a web interface to configure the app
- use hear-rate monitor (need to buy a watch first :)

## Current Bugs

- UI bugs when graphs don't fit

## Motivation

I'm running for a bit more than 10 years now, and I'm always motivated by looking
at past runs, and trying to do better.
So graphs are important to me, but I want them to be useful.
I only used Google Fit and Runtastic, but neither gives good graphs:
- Google Fit makes them too small
- Runtastic has an awful filter which distorts the runs

In addition I wanted to be able to export / import runs, and to have more functionalities
like guiding through runs, comparing runs over time, adding your own training, and much more.

# Musings while developing the app

## Altitude

I was surprised to find that the altitude was mostly off by +-30m.
There seem to be multiple reference geoids, and now I set it to use
MSL from the received NMEA messages from GPS.
However, to calculate slopes and pace comparisons, this was not enough.
As the longitude / latitude were much more accurate, +-2m or so, I'm now
requesting the altitude through a service.
I set up my own service described in https://www.opentopodata.org/, with
data from https://www.swisstopo.admin.ch/en/height-model-swissalti3d.
For Switzerland, there is a dataset available with a 0.3m precise datapoint
every 0.5m!
But this dataset is more than a TB in size!
So I took the one with one datapoint every 2m...

## Filtering

With some background in wireless signals, it was interesting to see
the bad filtering of Runtastaic.
I mean, taking a rectangular window is _really_ bad :)
So I went all the way to the other side and did a Lanczos filtering.
But I have yet to check whether I can spot the difference with a triangular filtering.
Probably not...

# Bugs

# Changelog

2026-01-14:
- wrong y-axis limits for runs with "pace"
- add an evaluation of the pace/inclination curve 
- when first creating a ReRun, it is not shown, only on the second invocation
  -> starting with "Running"
- "pace" not exported or imported
  
2026-01-11:
- starting GPS at the beginning, and show accuracy and current speed
- add a "cancel" button in the waiting screens

2026-01-10:
- adding maps to history
- small maps for overview
- added ReRun feature: base the pace on a previous run
- allow to not announce changes in targetSpeed 
- toneFeedback is now 0-2s, 2-4s, 4-8s, ...

2025-09-20:
- adding targetPace stats to the figures
- making nicer y-axis labels for pace
- correctly storing feedback in the Run

2025-09-18:
- Using 1 second intervals
- Improving display and adding scrollviews
- Adding feedback elements
- Speeding up figures
- Better feedback when fetching heights
- Allow to choose the filter length
- Fixing milliseconds and seconds
- Fixing all tests

2025-08-08:
- Rewriting creation of dummy-entries
- Add "Export all" and test it
- Add "Export to file / Share" for both exports
2025-07-16:
- Fixed bug: when running, then stop, it adds an empty run
- Sound Feedback:
  - Using logarithm of the difference for the number of tones
  - Feedback frequency inversely proportional to number of tones 
2025-07-14:
- Added configurable feedback speed
2025-07-14:
- Fixed sound feedback
- Fixed fetching of height
- Fixed some off-by-one errors and crash when working on empty lists
- Added GPS simulation for phone
2025-07-05:
- Added sound feedback, but need to make it configurable
2025-06-28:
- Stable enough to use for running
2025-05-19:
- Initial first version
