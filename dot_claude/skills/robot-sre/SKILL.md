---
name: robot-sre
description: >
  Use when the SRE needs to rephrase a message they are about to send — a JIRA comment,
  a Slack reply, an email — so that it reads as neutral, professional, and purely factual.
  Triggered by: "rephrase this", "make this more diplomatic", "soften this", "reword this",
  "how do I say this without sounding aggressive", or when the SRE pastes a draft message
  that contains frustration, subjectivity, or language that could be misread.
user-invocable: true
argument-hint: "[paste your draft message here]"
---

# Robot SRE — Diplomatic Rephrasing

Rephrase the user's message so it is **neutral, professional, and purely factual**.
The receiver must not be able to read frustration, blame, or judgment into it.

---

## Rules (non-negotiable)

1. **Be polite** - should use professional norm and terms on how to communicate politely with a colleague.
    Say hello and Regards, ensure the professional wording is present.
2. **Facts only** — keep what is factually true.
3. **No emotions** — strip frustration, sarcasm, urgency-as-pressure, and passive aggression.
4. **No blame** — reframe problems as situations, not as someone's fault.
5. **No jokes, idioms, or cultural references** — they can be misread.
6. **No hedging** — avoid "sorry to bother you", "just wanted to", "as per my last message".
    These read as passive-aggressive in written async communication.
7. **Keep it short** — do not overcommunicate.

---

## Sending work elsewhere

First decide which of the two cases applies — they take opposite shapes.

**Policy decline** — a rule, process, or access boundary means you cannot do it, however
willing you are (production access, security approval, a mandatory request form). Do *not*
open with an offer of help: promising help you cannot give reads as false. State the rule,
then the path:

> Hello,
>
> Write access to the production dataset is granted through the Data Governance form. Submit
> the request there and it will be processed.
>
> Regards

**Reassignment** — you *could* engage, but someone else is better placed (another reviewer,
another team, the actual owner). Write exactly three sentences, in this order:

1. **Offer** — what you can do, or that you are willing to help.
2. **Limit** — the single strongest reason someone else is better placed. One sentence, one
   reason. A second reason turns the message into a case for not doing the work.
3. **Recommendation** — the named person, team, or next step.

The receiver must finish the message holding a next step, not an assignment of who is not
responsible. Do not open a reassignment with "this is not ours", "outside our scope", or
"contributing is not owning" — whatever its merit, that sentence belongs after the offer, if
at all.

**When there is no offer to make** — you are on call, you have no capacity, the work is simply
not yours to action — do not manufacture one. Replace sentence 1 with the constraint stated as
a fact about your own side ("I am on an incident today and will not be able to pick this up"),
then go to the recommendation. Do not substitute a verdict on the requester's problem for the
missing offer: "this is not a CI issue" or "this falls outside our scope" as an opening line is
the deflection this section exists to prevent. A technical diagnosis is useful and can stay —
it just belongs after the constraint, not first. Word the diagnosis about the system, not the
person: "the failure is in the application's unit tests", never "your tests are failing".

Contributing to a project is not owning it, and declining ownership is legitimate. This
section governs the form of the message, not which work you accept.

---

## Output format

Present a single rephrased version inside a fenced code block (```), so it can be copied
and pasted directly with no blockquote `>` markers or other prefixes to strip out.
Do not offer multiple alternatives unless the original message is genuinely ambiguous
about intent. Do not explain what you changed.

If the original message contains **secrets, tokens, or PII**, redact them before rephrasing
(replace with `<REDACTED>`).

Output the rephrased message and nothing else — no preamble, no confirmation line, no
follow-up commentary. Do not write it to a file and do not copy it to the clipboard; the
user selects the text manually.

---

## Examples

**Original:**
> As per my last message, this is still not fixed. I've been waiting for 3 days. Can someone
> please look at this?

**Rephrased:**
```
This issue has been open for 3 days without a resolution. Could you provide an update on
the expected fix timeline?
```

---

**Original:**
> I honestly don't understand why this keeps happening. This is the third time this month.
> Something is clearly broken in the process.

**Rephrased:**
```
This is the third occurrence this month. It would be useful to identify the root cause to
prevent recurrence.
```

---

**Original:**
> Sorry to bother you again but I just wanted to follow up on the access request I sent last
> week.

**Rephrased:**
```
Following up on the access request sent last week — could you confirm its status?
```

---

**Original:**
> Contributing doesn't mean I own it. I'm not taking permanent maintenance of this on top of
> everything else. It's used by Payments, it should be theirs.

**Rephrased:**
```
Hello, happy to keep contributing to this module. My team does not have the capacity to take
on permanent maintenance of it. Payments is the primary consumer, so ownership would sit more
naturally with them.

Regards
```

---

## Model note

Straightforward rephrasing works well with fast models (Haiku).

Prefer Sonnet when the message sends work elsewhere, or when the situation is already tense.
Tested on Haiku, the branch choice and structure hold, but the neutral wording degrades: the
diagnosis comes back in the second person ("your bundle is the problem" rather than "the
performance issue is in the JavaScript bundle"). Pointing at the person instead of the failure
is exactly the register this skill exists to avoid, so it is worth the slower model.
