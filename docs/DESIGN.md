# Design rationale

Attune was designed backwards from a feeling: the end of a workday where
focus never quite arrived, nothing seems finished, and the response to that
feeling is to keep sitting there. Every design decision below exists to make
that evening end differently — with an honest picture of the day and a
decision made from evidence instead of anxiety.

The research citations referenced here are expanded in
[RESEARCH.md](RESEARCH.md).

## Principles

### 1. Externalize what ADHD internalizes badly

ADHD is, in Barkley's framing, a disorder of self-directed executive
functions — internal timekeeping, internal prompts, internal monitoring.
The compensations that work are *external*: clocks you can see, cues that
arrive on their own, records that don't depend on memory.

Attune externalizes three things:
- **Time** — break timers, sprint timers, the activity counter.
- **Interoception** — the "And your body?" question, asked because the
  body's own signals measurably under-report in ADHD (`kutscheidt2019`).
- **Metacognition** — the check-in itself: a recurring outside prompt to
  notice your own state, which self-monitoring research says is the active
  ingredient (`reid2005`).

### 2. The check-in is the intervention

The guidance card is useful, but the ten seconds of *noticing* is where the
mechanism lives. This drives several choices:

- Two questions plus one optional, all single-click, under ten seconds.
- A missed check-in records silently and never re-alerts. The next one
  comes at its normal time. Noticing can't be homework.
- "Not now" is a first-class answer with a dedicated button and zero
  consequence.

### 3. Shame-free is a hard requirement, not a tone preference

ADHD adults arrive with decades of "you're not living up to your potential."
Emotional dysregulation and rejection sensitivity are common; a tool that
grades its user gets deleted in week two, *and deserves it*.

Copy rules enforced in the codebase (there is a unit test that scans the
catalog for banned shaming vocabulary):

- Describe **states**, never grade the person. "Scattered" is weather, not
  character.
- Data over verdicts: "your brain just told you something."
- Concrete over abstract: "fill your water glass" beats "practice
  self-care."
- No streaks, no scores, no grades, no comparisons to other users, no
  "productivity percentage." The Insights page counts *moments of noticing*
  and *times you acted* — things done, not things owed.

### 4. Protect focus with the ferocity of someone who rarely gets it

When a user reports high focus, the correct intervention is almost always
nothing (`mark2008`). Attune says so explicitly, lengthens its own interval
(adaptive cadence, ×1.6 up to a 90-minute cap), and offers only a
half-sentence "mark your trail" note (`leroy2009`). The single exception is
the hyperfocus guard: high focus sustained past ~100 minutes without a break
earns a body-care nudge, because hyperfocus routinely overrides hunger,
thirst, and posture (`hupfeld2019`) — and the nudge is designed to preserve
the streak, not end it.

### 5. Legitimize the trade

The signature move. For a parent working flexibly from home, low focus plus
a pile of home tasks is not a productivity failure — it's an arbitrage
opportunity. Twenty minutes of laundry while the brain idles *banks* value
that twenty minutes of desk-sitting would burn.

What makes it a strategy instead of a drift:
1. **A timer** — the boundary is external and definite.
2. **An if-then return plan said before standing up** ("When the timer
   rings, I sit down and open ___") — implementation intentions measurably
   improve follow-through in ADHD (`gawrilow2008`).
3. **A welcome-back prompt** that hands the user the smallest possible
   re-entry step — because re-entry is where switches fail
   (`leroy2009`).

### 6. Interrupt at boundaries, never mid-battle

Check-ins hold during Zoom meetings and arrive a couple of minutes after
the call ends (`iqbal2010`) — a moment that is both cheap to interrupt and
unusually valuable for a reset. Meeting detection is deliberately local and
dumb: Zoom running + microphone in use, no calendar access, no network, no
screen reading. The failure mode is a *deferred* check-in, never an
interrupted meeting.

### 7. Hours are evidence; use them against anxiety, not for surveillance

The activity monitor answers one question: "did I actually work today?"
ADHD time blindness compresses the memory of a scattered day into "I barely
worked" (`ptacek2019`), and performance anxiety answers with overtime.
An objective, local count of at-keyboard hours lets the evening decision be
made from evidence.

Boundaries that keep this feature on the right side of the line:
- **Presence only.** Seconds-since-last-input from Quartz event counters —
  no app names, no window titles, no keystroke contents, ever.
- **The number advocates for the user, never against them.** It appears in
  "you've already done a full day" guidance and in Insights. There is no
  daily quota, no under-hours warning, and there never will be.
- Local file, user-deletable, 120-day retention.

### 8. Autonomy or abandonment

Self-determination theory, and common sense about who this app is for:
every cadence, window, and detection behavior is user-tunable; pause is one
click from the menu bar; the whole thing quits cleanly. A tool for people
who've been micromanaged by their own brains must not become another
micromanager.

## Deliberate omissions

Each of these was considered and rejected on design grounds, not forgotten:

- **Streaks and gamification** — punishes exactly the variability that
  defines ADHD; extrinsic rewards can crowd out the intrinsic motivation
  the tool is trying to grow.
- **App/website tracking and "distraction scores"** — surveillance framing,
  privacy cost, and it answers a question ("what did you do?") that the
  mental-health goal doesn't ask.
- **Cloud sync / accounts / analytics** — attention and body-state history
  is health-adjacent data. The strongest privacy policy is architecture:
  the app has no servers and nothing phones home. (The two away-from-Mac
  bridges honor this: the iPhone/Watch ring rides the user's *own* iCloud
  via a Reminder, and the break-end webhook is one opt-in POST to a URL the
  user typed in themselves — inspectable, off by default, off when empty.)
- **Calendar integration for meeting detection** — would work, but requires
  broad calendar permission for marginal benefit over the local heuristic.
- **AI-generated advice** — the catalog is hand-written and research-keyed;
  a language model would trade auditability for variety, in copy where
  wrong tone does actual harm.

## UI decisions worth recording

- **Menu bar accessory app** (no Dock icon): peripheral presence for a
  peripheral tool. macOS-native so nothing about it feels like another
  work app.
- **Non-activating floating panel** for check-ins: it never steals keyboard
  focus from the user's work. Found and fixed in testing: such panels
  reject the first click by default (`acceptsFirstMouse`), which would have
  made every check-in a double-click — the fix is a one-line hosting-view
  override, and the "one click, no wrong answers" promise depends on it.
- **The panel auto-dismisses after 150 seconds** and records "missed" —
  chosen over persistent nagging because an ignorable prompt the user
  trusts beats an insistent one the user resents.
- **Soft sound, on by default** ("Glass"): lets the check-in be noticed
  without eyes-on-screen; one toggle to silence.
- **Chart follows a validated accessibility spec**: single validated hue in
  both light and dark modes, direct label on the peak bar only, hover
  tooltips, and no meaning carried by color alone.
