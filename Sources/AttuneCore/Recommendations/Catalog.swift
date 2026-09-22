import Foundation

/// The full library of guidance Attune can offer, grouped by scenario.
/// Multiple variants exist per scenario and rotate, because novelty itself
/// carries weight for ADHD brains — the same advice repeated verbatim
/// stops registering.
///
/// Copy rules (see docs/DESIGN.md):
/// - Describe states, never grade the person.
/// - Concrete over abstract: "fill your water glass" beats "take care of
///   yourself".
/// - Every redirect away from work includes a *return plan* — an if-then
///   sentence — because re-entry is where task switches usually fail.
public enum Catalog {

    // MARK: High focus

    public static let keepGoing: [Recommendation] = [
        Recommendation(
            id: "keep-going.protect",
            kind: .keepGoing,
            title: "You're in it. I'll get out of the way.",
            body: "Nothing to fix here. I'll wait longer before the next check-in so this stretch can run. If something needs deferring — a ping, a chore thought — jot it on a sticky and stay in.",
            whyItWorks: "Interrupted work takes real time and stress to resume, so when focus is high the best intervention is none. The next check-in backs off automatically.",
            researchKeys: ["mark2008", "leroy2009"]
        ),
        Recommendation(
            id: "keep-going.anchor",
            kind: .keepGoing,
            title: "Good groove — mark your trail.",
            body: "Keep going. One tiny ask: write a half-sentence note about what you're doing right now (\"wiring the retry logic\"). If anything interrupts you later, that note is your way back in.",
            whyItWorks: "A \"ready-to-resume\" note dramatically cuts attention residue — the part of your mind that stays stuck on an interrupted task instead of moving with you.",
            researchKeys: ["leroy2009"]
        ),
    ]

    public static let bodyCare: [Recommendation] = [
        Recommendation(
            id: "body-care.hyperfocus",
            kind: .bodyCare,
            title: "Strong focus streak — your body's been carrying it.",
            body: "You've been locked in for a good while. Don't break the thread — just tend the machine: stand up, refill water, eat something if lunch slid by, and look out a window for 20 seconds. Then dive right back.",
            whyItWorks: "Hyperfocus is real and common in adult ADHD — and it routinely overrides hunger, thirst, and posture signals that ADHD brains under-detect in the first place. External reminders stand in for the interoception that isn't firing.",
            timerMinutes: 5,
            researchKeys: ["hupfeld2019", "kutscheidt2019"]
        ),
        Recommendation(
            id: "body-care.eyes",
            kind: .bodyCare,
            title: "Quick body pass, then back in.",
            body: "Three moves, ninety seconds: roll your shoulders, drink water, focus your eyes on something far away. Momentum survives a 90-second pit stop — it doesn't survive a headache at 3pm.",
            whyItWorks: "Long high-focus stretches are exactly when ADHD adults miss body signals; brief, structured body checks are the compensation. Micro-breaks this short measurably reduce fatigue without derailing the task.",
            timerMinutes: 2,
            researchKeys: ["kutscheidt2019", "albulescu2022"]
        ),
    ]

    // MARK: Mid focus

    public static let movementBreak: [Recommendation] = [
        Recommendation(
            id: "movement.stairs",
            kind: .movementBreak,
            title: "That restlessness is fuel — spend it.",
            body: "Five minutes, heart rate up: stairs, brisk walk around the block, or twenty squats and a hallway lap. Not exercise, just a spark. Then sit back down and re-read the last thing you wrote.",
            whyItWorks: "A single short bout of moderate exercise measurably sharpens attention and reaction speed in adults with ADHD — one of the most reliable non-medication effects in the literature.",
            timerMinutes: 5,
            researchKeys: ["mehren2019", "denheijer2017"]
        ),
        Recommendation(
            id: "movement.walk",
            kind: .movementBreak,
            title: "Take the engine for a lap.",
            body: "Wired but not landing on the work? Ten minutes outside, walking fast enough to notice your breath. Leave the phone. When you're back: one sentence — \"next, I will ___\" — then do exactly that.",
            whyItWorks: "Brief aerobic movement boosts the same catecholamine systems ADHD medications target, and a walk outdoors adds an attention-restoration effect on top. The if-then sentence at the end is what carries the benefit back to your desk.",
            timerMinutes: 10,
            researchKeys: ["mehren2019", "berman2008", "gollwitzer1999"]
        ),
    ]

    public static let microBreak: [Recommendation] = [
        Recommendation(
            id: "micro.reset",
            kind: .microBreak,
            title: "Coasting is fine. A tiny reset makes it better.",
            body: "Three minutes off-screen: stretch, water, stare out the window and let your eyes unfocus. Then pick the one thing that matters most in the next 25 minutes and name it out loud.",
            whyItWorks: "Micro-breaks of just a few minutes reliably restore vigor and reduce fatigue. Naming a single next target converts vague intention into an actual plan.",
            timerMinutes: 3,
            researchKeys: ["albulescu2022", "gollwitzer1999"]
        ),
        Recommendation(
            id: "micro.declutter",
            kind: .microBreak,
            title: "Two-minute runway clear.",
            body: "Close every tab and window that isn't the current task. Put the phone out of arm's reach. Two minutes of clearing buys the next hour of your attention back.",
            whyItWorks: "Every visible loose end is a cue competing for an attention system that's already generous with cues. Removing them is cheaper than resisting them.",
            timerMinutes: 2,
            researchKeys: ["gazzaley2016"]
        ),
    ]

    public static let sprintGame: [Recommendation] = [
        Recommendation(
            id: "sprint.race",
            kind: .sprintGame,
            title: "Boring task? Make it a race.",
            body: "Pick a finish line you can hit in 15 minutes (\"inbox to twenty\", \"first draft of the doc's intro\"). Set the timer. Beat it. Boring tasks can't hold ADHD attention on importance alone — but a clock and a finish line can.",
            whyItWorks: "ADHD motivation runs on interest, novelty, challenge, and urgency far more than on importance. A self-imposed sprint manufactures urgency and challenge on demand.",
            timerMinutes: 15,
            researchKeys: ["dodson-inb", "sonugabarke2003"]
        ),
        Recommendation(
            id: "sprint.stack",
            kind: .sprintGame,
            title: "Change the texture of the task.",
            body: "Same task, different container: stand up to do it, put one album on and finish before it ends, or narrate it out loud like a cooking show. Ridiculous is allowed. Ridiculous works.",
            whyItWorks: "Novelty recruits dopamine-driven attention that ADHD brains don't get from routine importance. Changing how a task feels is often enough to make it doable.",
            researchKeys: ["dodson-inb"]
        ),
    ]

    public static let worryTool: [Recommendation] = [
        Recommendation(
            id: "worry.parkinglot",
            kind: .worryTool,
            title: "The worry gets a parking spot, not the steering wheel.",
            body: "Grab paper. Two minutes: write every open loop that's circling — school forms, that email, the thing you said in standup. Then pick the earliest moment you'll actually deal with the top one (\"today, 4pm\") and write it next to it. Your head is for having ideas, not holding them.",
            whyItWorks: "Scheduled \"worry postponement\" reliably reduces intrusive worry: the mind lets go of a loop once it trusts there's a concrete time to come back to it. Unfinished tasks otherwise keep pinging working memory.",
            timerMinutes: 3,
            researchKeys: ["borkovec1983", "masicampo2011"]
        ),
        Recommendation(
            id: "worry.breath",
            kind: .worryTool,
            title: "Downshift, then decide.",
            body: "Ninety seconds of slow breathing — in for 4, out for 6, shoulders down. Then ask: is this worry something I can act on in the next hour? If yes, write the single next step. If no, write it on the parking-lot list and come back to work.",
            whyItWorks: "Extended exhales activate the parasympathetic brake, taking arousal down a notch so the prefrontal cortex can get a word in. Deciding \"actionable or not\" turns diffuse anxiety into a routable item.",
            timerMinutes: 2,
            researchKeys: ["borkovec1983", "zaccaro2018"]
        ),
    ]

    // MARK: Low focus

    public static let contextSwitch: [Recommendation] = [
        Recommendation(
            id: "context-switch.trade",
            kind: .contextSwitch,
            title: "Your brain just told you something. Trade the hour.",
            body: "Deep work isn't available right now — that's data, not a verdict. If your schedule allows it, spend the next 20 minutes on something real from home life: fold the laundry, prep dinner, knock out the school forms. Before you stand up, drop a note below — what you'll open when you sit back down — and start the timer.",
            whyItWorks: "Time spent unfocused at a desk is mostly lost; the same time spent on a low-demand task is banked. The timer plus if-then return plan is what makes this a strategy instead of a drift — if-then plans measurably improve follow-through in ADHD.",
            timerMinutes: 20,
            researchKeys: ["gawrilow2008", "leroy2009", "albulescu2022"]
        ),
        Recommendation(
            id: "context-switch.chore-sprint",
            kind: .contextSwitch,
            title: "Redirect the restlessness at the house.",
            body: "Pick one physical chore you can finish in 15 minutes — dishes, one room reset, taking out recycling. Moving your body while your mind idles is recovery, not slacking. Leave yourself a note below about where you're leaving off — it'll be waiting when the timer rings.",
            whyItWorks: "Physical, low-cognitive-load activity is exactly the kind of break that research shows restores performance — and finishing a visible task hands your brain a completion reward that a stuck work task hasn't paid out in a while.",
            timerMinutes: 15,
            researchKeys: ["albulescu2022", "mehren2019"]
        ),
        Recommendation(
            id: "context-switch.family",
            kind: .contextSwitch,
            title: "Be where you'd actually land.",
            body: "If the kids or home need you and the work isn't landing anyway, go be there properly for 20 minutes — present, phone down. That's not stolen work time; it's moving your effort to where it currently works. Jot your way back in the note below first, then go.",
            whyItWorks: "A flexible schedule means you can match tasks to your brain's current mode instead of fighting it. One fully-present block beats an hour of guilty half-attention in both directions.",
            timerMinutes: 20,
            researchKeys: ["leroy2009", "gawrilow2008"]
        ),
    ]

    public static let restorativeBreak: [Recommendation] = [
        Recommendation(
            id: "restore.outside",
            kind: .restorativeBreak,
            title: "Empty tank. Refill it properly.",
            body: "This calls for a real break, not a scroll: 10–15 minutes outside if you can, near anything green. Water and a snack on the way out. Scrolling swaps one attention drain for another — sky and trees actually give attention back.",
            whyItWorks: "Directed attention is a depletable resource. Natural environments restore it measurably (attention restoration theory) while feeds and inboxes keep spending it.",
            timerMinutes: 15,
            researchKeys: ["kaplan1995", "berman2008"]
        ),
        Recommendation(
            id: "restore.fuel",
            kind: .restorativeBreak,
            title: "Check the basics first.",
            body: "When did you last eat? Drink water? Depleted focus at a desk is often just a body running on fumes. Handle food and water, then give yourself 10 minutes off-screen before deciding anything about the work.",
            whyItWorks: "Basic body needs gate executive function before any productivity technique gets a vote — and ADHD brains are the least likely to notice the gauge until it's empty (interoception again).",
            timerMinutes: 10,
            researchKeys: ["kutscheidt2019", "hupfeld2019"]
        ),
    ]

    public static let environmentFix: [Recommendation] = [
        Recommendation(
            id: "env.fortress",
            kind: .environmentFix,
            title: "Don't fight the pings. Unplug them.",
            body: "Notifications are winning because they're designed to. Turn on Do Not Disturb for 25 minutes, close mail and chat, phone in another room. Then re-enter the task through the smallest door: re-read the last thing you did.",
            whyItWorks: "Willpower against notifications is a losing trade for any brain, and ADHD raises the cost of every interruption. Changing the environment once beats resisting it repeatedly.",
            timerMinutes: 25,
            researchKeys: ["mark2008", "gazzaley2016"]
        ),
        Recommendation(
            id: "env.body-double",
            kind: .environmentFix,
            title: "Borrow some accountability.",
            body: "If focus keeps sliding, add a person: sit where others are working, start a quiet video call with a colleague who's also heads-down, or just tell someone \"I'm doing X for the next half hour.\" Externalizing the commitment does the holding for you.",
            whyItWorks: "\"Body doubling\" is a widely used ADHD strategy: another person's presence supplies the external accountability structure that internal executive function isn't providing right now.",
            researchKeys: ["eagle-bodydoubling"]
        ),
    ]

    /// Shown when the tracked at-computer time already amounts to a full
    /// day and focus is gone. "{active}" is replaced with the real figure.
    /// This entry exists because ADHD time blindness plus performance
    /// anxiety reliably compresses the memory of a scattered day into
    /// "I barely worked" — and the usual response is to keep going. The
    /// counter is objective evidence to decide from instead.
    public static let enoughForToday: [Recommendation] = [
        Recommendation(
            id: "enough.banked",
            kind: .wrapUp,
            title: "The hours are already in the bank.",
            body: "You've put in {active} of real, at-the-keyboard time today — that's a full day, measured, not felt. Focus is spent, and pushing past this point buys very little except a worse tomorrow. Write down where you stopped and one first move for the morning, then close the lid with a clear conscience.",
            whyItWorks: "ADHD compresses the memory of a scattered day into \"I barely worked\", and anxiety answers with overtime. This number is the objective record: the time went in. Deciding from evidence instead of dread is the whole point of tracking it.",
            timerMinutes: 10,
            researchKeys: ["ptacek2019", "barkley1997", "masicampo2011"]
        ),
        Recommendation(
            id: "enough.diminishing",
            kind: .wrapUp,
            title: "Full day logged. This next hour is optional — actually optional.",
            body: "{active} at the computer so far. If something genuinely needs finishing tonight, take a real break first and come back once. Otherwise: the feeling that you haven't done enough is a feeling, and the counter disagrees with it. The laundry, the kids, the couch — all legitimate next moves.",
            whyItWorks: "Vigilance and executive function decline with hours on task; late low-focus work is slow and error-prone, then gets judged as personal failure. Stopping on evidence protects both the work and the person doing it.",
            researchKeys: ["ptacek2019", "warm2008"]
        ),
    ]

    /// Shown when the *span* of the day — first activity to last, with all
    /// the unprompted breaks and time away folded in — has stretched long
    /// (10+ hours) while focus fades. The point isn't the active hours (they
    /// may be modest); it's how long work has been in the picture. "{span}"
    /// and "{active}" are replaced with the real figures. This is the
    /// work/life-separation nudge: a bracket that wide usually means an
    /// early check-in, a late one, or both — the edges of the day bleeding
    /// into life.
    public static let longDay: [Recommendation] = [
        Recommendation(
            id: "long-day.separate",
            kind: .wrapUp,
            title: "Work's been in the room for {span}.",
            body: "First thing you touched to the last spans {span} today — only {active} of it actually at the keyboard, but work has been hovering the whole time. That's the early check-in, the after-dinner \"quick look\", the edges bleeding into life. If tonight can be different, draw the line here: note where you stopped, then step fully out. A real evening is a legitimate goal, not a reward you have to earn.",
            whyItWorks: "Psychologically detaching from work — not just stopping, but mentally clocking out — is what actually restores you for tomorrow; a day that never brackets shut keeps taxing you off the clock. And time blindness means the 10-hour tether doesn't feel like 10 hours until something names it.",
            timerMinutes: 10,
            researchKeys: ["sonnentag2007", "ptacek2019"]
        ),
        Recommendation(
            id: "long-day.boundary",
            kind: .wrapUp,
            title: "A {span} bracket is long. You're allowed to close it.",
            body: "Your day so far runs {span} end to end — breaks and all — with {active} truly at the keyboard. Long, fragmented days like this are their own kind of tired, separate from how much got done. Unless you're on call tonight, this is a fine place to stop: one line about where you're leaving off, then out. The work will keep.",
            whyItWorks: "Recovery research is clear that unbroken tether to work erodes wellbeing regardless of output; the win here is separation, not more hours. Naming the span turns a vague \"still going\" into a decision you can actually make.",
            researchKeys: ["sonnentag2007", "warm2008"]
        ),
    ]

    public static let wrapUp: [Recommendation] = [
        Recommendation(
            id: "wrapup.land",
            kind: .wrapUp,
            title: "The day's returns are diminishing. Land the plane.",
            body: "Low focus this late is your brain closing the register. Spend 10 minutes landing instead of grinding: note where you stopped, write tomorrow's first move as one sentence, close the tabs. Then be done — actually done.",
            whyItWorks: "A written stopping point and a named first move let your mind release the day's open loops instead of chewing on them all evening — and make tomorrow's cold start warm.",
            timerMinutes: 10,
            researchKeys: ["masicampo2011", "leroy2009"]
        ),
    ]

    /// Every recommendation in the catalog, for tests and documentation.
    public static var all: [Recommendation] {
        keepGoing + bodyCare + movementBreak + microBreak + sprintGame
            + worryTool + contextSwitch + restorativeBreak + environmentFix
            + enoughForToday + longDay + wrapUp
    }
}
