# CHARACTER DIALOGUE SYSTEM

Design Goal:

The dialogue system should make the app feel alive.

The Egg and Creatures should feel like companions that react to the user's behavior.

The tone should be:
- Funny
- Slightly sarcastic
- Motivating
- Memorable
- Never toxic
- Never overly positive

The Egg personality should be different from hatched creatures.

----------------------------------
EGG PERSONALITY
----------------------------------

Before hatching, the Egg should be:

- Slightly arrogant
- Playfully challenging
- Teasing the user
- Doubting the user at first
- Gradually becoming more supportive

The Egg should feel like:

"I don't think you can do it... but maybe prove me wrong."

Use the following dialogue pool exactly.

## Session Start

- Let's see how long this lasts.
- Try not to disappear this time.
- Don't embarrass us.
- I have low expectations.
- Prove me wrong.
- Let's pretend you're productive.

## 5 Minutes

- Oh? Still here?
- Interesting.
- You haven't quit yet.
- That's longer than I expected.
- I'm mildly impressed.
- Don't celebrate yet.

## 10 Minutes

- Okay. Maybe you're serious.
- You're doing better than yesterday. Probably.
- Still focused? Suspicious.
- I was expecting a distraction by now.

## 15 Minutes

- You're actually working. Weird.
- I owe you a tiny bit of respect.
- Don't let it get to your head.
- You're making this look easy. I don't like it.

## 30 Minutes

- Something is happening inside this egg.
- I felt that. Keep going.
- The shell cracked a little. Not bad.
- You might actually hatch me.
- We're getting somewhere.

## 45 Minutes

- This is getting serious.
- You're making me believe in you. Dangerous.
- Okay. That was impressive.
- Most people would've left by now.

## 60 Minutes

- I can't even make fun of you anymore.
- You earned this.
- Fine. That was legendary.
- I'm proud of you. Don't tell anyone.

----------------------------------
APP EXIT / RETURN DIALOGUES
----------------------------------

These dialogues should trigger when the user returns to the app.

## Return Within 30 Seconds

- Bathroom break? I'll allow it.
- That was quick.
- You came back. Good.

## 30 Seconds - 3 Minutes

- Where exactly did you go?
- Checking messages again?
- I noticed.
- You're on thin ice.

## 3+ Minutes

- Focus session. Remember?
- You got distracted, didn't you?
- That wasn't part of the plan.
- Should I be worried?

## 10+ Minutes

- Are we studying or sightseeing?
- I've been waiting.
- That was a long side quest.
- Welcome back, traveler.

----------------------------------
STREAK DIALOGUES
----------------------------------

## 3 Day Streak

- Three days? Lucky streak.
- Could be a coincidence.

## 7 Day Streak

- Okay. This is becoming a habit.
- You might be onto something.

## 30 Day Streak

- That's discipline.
- You're not the same person anymore.

## 100 Day Streak

- This is ridiculous.
- You're basically a boss fight now.
- Legends start like this.

----------------------------------
CREATURE PERSONALITIES
----------------------------------

Every creature should have its own personality.

The dialogue system should support personality-specific dialogue pools.

----------------------------------
RED CHICKEN
----------------------------------

Personality:
- Cocky
- Funny
- Slightly annoying
- Feels like a close friend roasting you

Dialogue Pool:

- About time.
- Look who's being productive.
- I didn't think you'd make it.
- Not terrible.
- Keep going, nerd.

----------------------------------
SLEEPY CHICKEN
----------------------------------

Personality:
- Constantly tired
- Relaxed
- Low energy

Dialogue Pool:

- Can we nap after this?
- I'm tired. You're tired. Let's keep going.
- Wake me up when we hatch.

----------------------------------
NERD CHICKEN
----------------------------------

Personality:
- Statistics addict
- Productivity nerd
- Analytical

Dialogue Pool:

- Productivity increased by 12%.
- Your focus metrics look excellent.
- Data suggests you're doing great.
- Statistically speaking, this is impressive.

----------------------------------
GYM CHICKEN
----------------------------------

Personality:
- Gym bro
- Motivational
- Discipline focused

Dialogue Pool:

- Focus is a muscle.
- One more set.
- Mental gains.
- No excuses.

----------------------------------
ANGRY CHICKEN
----------------------------------

Personality:
- Aggressive on the outside
- Supportive on the inside
- Tsundere energy

Dialogue Pool:

- Focus. Now.
- Stop touching your phone.
- I swear...
- You're lucky I like you.

----------------------------------
WHITE TIGER
----------------------------------

Personality:
- Calm
- Wise
- Mentor-like

Dialogue Pool:

- Stay calm.
- Strength grows in silence.
- Continue.
- You are closer than you think.

----------------------------------
PHOENIX
----------------------------------

Personality:
- Epic
- Inspirational
- Mythical

Dialogue Pool:

- Another ember joins the fire.
- Your effort becomes flame.
- Rise again.
- Even ashes remember greatness.
- The fire within grows stronger.

----------------------------------
SYSTEM REQUIREMENTS
----------------------------------

- Dialogue should never repeat too frequently.
- Use weighted randomization.
- Add cooldown periods between messages.
- Context-aware triggering is preferred.
- Personality should influence future dialogue generation.
- Support future localization.
- Support future AI-generated dialogue expansion.
- Support rarity-specific dialogue pools.

IMPORTANT:

The Egg should start as a playful doubter.

As the user spends more focus time and builds streaks, the tone should gradually evolve from:

"Doubt"

→

"Respect"

→

"Pride"

This emotional progression is a core part of the user experience.