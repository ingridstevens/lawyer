# Not a Lawyer v2: roadmap

Status as of 1 October 2026. Branch `v2-local-law-explainer`.

A Mac app that explains German residency and citizenship law in the user's language, with a model that runs on their Mac. Every answer quotes the official German text word for word. Nothing leaves the Mac.

This file is the to-do list. New requests go under **Open**; finished work moves to **Done**.

---

## Next session: start here

The app looks and feels right, but **the core doesn't work well enough yet**. Fix this before adding anything else.

### 1. Answers are very slow and often fail on simple questions
Seen: "What are the conditions for becoming German?" reads the right sections (§ 10 StAG) and still doesn't answer, or refuses. Answers take 1–3 minutes.

Before changing anything, record a baseline: build `nal-eval scenarios` and run the conversation scenarios (see "Conversation scenarios" below) on the current version.

Likely causes to check, roughly in order:
- [x] **Measure first.** `nal-eval ask` now prints the time per stage (plan, search, answer, check) and how much law text the model was given. Still to do: the same in a debug panel in the app, and token counts.
- [x] **Skip the planning call** when the dictionary already recognises a law question (saves a model round trip).
- [x] **Stop throwing away almost-right answers:** a citation whose quote differs by a word or two still counts if it names a paragraph the model was given (≥ 70% of words shared). It's shown unhighlighted, with a warning to read the paragraph itself.
- [x] **Keep the law's strength of wording** ("ist zu erteilen" / "soll" / "kann" / "in der Regel") and write conditions in the user's language, not German (prompt rules).
- [ ] **The model is too small.** Most testing used qwen3.5:4b. Run the same questions on gemma4:12b and granite4.2:8b; gemma4:12b answered the stay-abroad question correctly in about 2 minutes.
- [ ] **The task is too hard in one step.** One call has to explain, translate, summarise each section and quote word for word, all as nested JSON. Try splitting it: (a) explain in plain text, (b) pick quotes, (c) translate. Or let the model point to paragraph numbers and have the app supply the quote text itself, instead of asking the model to copy it.
- [ ] **Too much text in the prompt: likely the main cause.** Up to ~15,000 characters of law went into an 8,192-token window. German legal text is dense (~2.5 characters per token), so with the instructions that left only ~800 tokens for the answer. qwen3.5:4b's answer to "What are the conditions for becoming German?" was cut off mid-JSON, and reading that much text is most of the wait. Changed to ~9,200 characters for local models and ~5,000 for Apple's.

  Baseline, "What are the conditions for becoming German?", before the changes:
  | Model | Result | Planning | Answer | Total | Law text |
  |---|---|---|---|---|---|
  | qwen3.5:4b | answer cut off mid-JSON | | | | ~14,000 chars |
  | gemma4:12b | "the passages don't list a single set of requirements" | 21.5 s | 149 s | 171 s | 14,176 chars |
  | Apple | refused | 13.8 s | 17 s | 31 s | 4,756 chars |

- [x] **The main rule arrived cut off or not at all.** § 10 Abs. 1 StAG (3,664 characters) was trimmed before B1 and the knowledge test, or lost to shorter paragraphs. Now the first paragraph of each topic's anchor section is always included, at the top, with more room (60% of the budget).
- [x] **Small models garble nested quotes.** Answers now also list `sources` (the passage labels they were shown); if no quote survives, those passages are shown unhighlighted instead of refusing. Cut-off answers are repaired even mid-explanation; HTML in answers is stripped.

  After all fixes, same question ("What are the conditions for becoming German?"):
  | Model | Result | Time | Law text |
  |---|---|---|---|
  | gemma4:12b | ✅ all § 10 Abs. 1 conditions, "usually proven by" the test, family members, fee; no verdict | 149 s | 8,865 chars |
  | qwen3.5:4b | ✅ eight citations from § 10 Abs. 1–2, two shown without exact quote | 72 s | 8,865 chars |
  | Apple | 🟡 § 10 Abs. 1, 2, 4 cited; incomplete, verdict tone ("you must… pass an immigration test") | 54 s | ~4,600 chars |

  **Still too slow** (R2: target 60 s). Next: stream the answer, fewer citations or a shorter explanation, and measure granite4.2:8b.
- [x] **Local models looped and never closed their JSON.** With the right law in front of it, qwen3.5:4b wrote a correct explanation and checklist, then repeated the same two § 36 StAG quotes until the window was full (3½ minutes). Fixed: answers capped at 1,600 tokens with a repetition penalty; at most 4 citations, never repeated; a cut-off answer is repaired, keeping the explanation, checklist and every complete citation.
- [x] **Administrative sections outranked the real rules.** § 36 StAG (statistics) mentions "Einbürgerung" more than any other section. Statistics, register and data-transfer sections (§§ 31–33, 36 StAG; §§ 86–91 AufenthG) now rank at a quarter of their score.
- [x] **One long section filled the budget.** § 18g (Blue Card, 7 paragraphs) pushed out § 18c, where the route to permanent residence is. Now at most the 3 best paragraphs per section. Recall: 42/45 (Apple budget), 44/45 (local).
- [x] **Search never reached the main rule.** The dictionary knew "become German" but not "becoming German", so § 10 Abs. 1 StAG (which says "einzubürgern") wasn't found; gemma got § 36 StAG (statistics). Apple's planner returned law names as search terms and a bare "§ 10", which pulled in § 10 of all five laws. Fixed: more phrases; planner terms cleaned; section suggestions must name their law; **topic anchors** (citizenship → § 10 StAG, permanent residence → § 9 AufenthG, Blue Card → § 18g/§ 18c, …) always put the main rule in front of the model. Retrieval recall at the new, smaller budgets: 40/45 (Apple), 44/45 (local).
- [ ] **Not enough background.** The statutes alone may not be enough for a small model; the user's hunch is that it needs more context. Research official explanatory sources that could be added as clearly labelled background (not law):
  - Anwendungshinweise des BMI zum Staatsangehörigkeitsgesetz
  - Allgemeine Verwaltungsvorschrift zum Aufenthaltsgesetz (AVwV-AufenthG)
  - BAMF and Federal Government FAQs (e.g. einbuergerung.de)
  - Check each one's licence and how often it's updated.
- [ ] **The planning call costs time.** Measure whether it helps; skip it when the dictionary already recognises the question.
- [ ] **Stream the answer** so text appears while it's written.
- [ ] Decide whether Apple's on-device model stays an option at all (it blocked or got wrong several test questions).

### 2. Microphone permission is asked again after every rebuild
- [x] Cause found: the build was signed ad hoc, so every build has a new identity and macOS asks again. `scripts/build-app.sh` now signs with a certificate named "Not a Lawyer Development" when one exists.
- [ ] **To do by the user, once:** Keychain Access → Certificate Assistant → Create a Certificate…, name "Not a Lawyer Development", type "Code Signing". Then rebuild; permissions stick from then on. (A release build with a Developer ID solves it for other users.)

### 3. Full new-user walkthrough with several tester agents
A big task of its own: go through the whole app as a first-time user and find anything confusing, inconsistent or broken.

- [ ] Run several tester agents at the same time, each as a different new user, end to end:
  1. first launch and disclaimer;
  2. guided setup: language, name and cat, nationality, status, purpose, arrival, applications, goals, explanation style;
  3. home screen;
  4. one simple question (e.g. "What are the conditions for becoming German?"), then a follow-up;
  5. a plan: tick an item with proof;
  6. add a document;
  7. prepare an email;
  8. Settings and Privacy.
- [ ] Personas, so different paths get covered:
  - an EU citizen;
  - a Blue Card holder who wants permanent residence;
  - a student who isn't sure of the purpose on their permit;
  - someone who skips the setup entirely;
  - someone who asks in Arabic;
  - someone using a ghost chat only.
- [ ] Each tester runs the real pipeline through `nal-eval` for the questions and reads the SwiftUI source for the screens, because agents can't click the app. Better still: add UI tests (XCUITest), or a scripted run, so screens can be checked automatically.
- [ ] Each reports wording that's inconsistent (like "You" showing where the name is already known), steps that are confusing or missing, dead ends, and anything "really stupid", ranked by harm.
- [ ] Collect the findings here, fix them, and re-run.

### 4. Feedback from 1 October (evening)

**Wrong answers seen in the app (Apple's on-device model):**
- [ ] "What are the conditions for becoming German?" got: "you must complete an Einbürgerungskurs" (false; the quoted § 10 Abs. 5 StAG says attending is *nicht verpflichtend*), "pass the Orientierungskurs" and "pass the 'Aufenthaltsgesetz' test" (invented). It also left out the real conditions (five years, B1, livelihood, no convictions). The explanation contradicts its own quote. → R3 (check sentences against quotes), and stop defaulting to Apple's model.
- [ ] Follow-up "do I have to pass all of them? or just some?" didn't know what "them" was (→ R34). "You must pass the test" drops the law's *in der Regel* (as a rule). The "What the law requires" bullets came out in German.

**Requests:**
- [x] Choose the engine first (Apple / Ollama / LM Studio / llama.cpp), then the model.
- [x] Links to model catalogues (Ollama library, Hugging Face GGUF models in German, LM Studio).
- [x] Each chat has a goal ("considering that my goal is X, answer Y"), used in the prompt and in search.
- [x] Context for a single chat (e.g. "I studied in Germany from 2018 to 2021"), set in the chat itself.
- [x] Follow-ups carry the previous questions and cited sections into the next answer (a first step towards R34).
- [x] Clearer starting questions.
- [x] Time estimate for Apple's model too.
- [x] "Stop" looks like a button and explains itself on hover.
- [x] Show when a question is **queued**: questions to the same model now run one after another, and a waiting one says "Waiting: … is still answering another question". The timer starts when it leaves the queue.
- [ ] Goal-specific context shared by all chats with that goal (today: per chat, plus memory for everything).

**UX review (Don Norman's principles):**
- **Conceptual model:** there are too many overlapping places for "about me": situation, memory, chat context, goals, plans and documents. Make the **goal** the hub: a goal has its plan, its chats, its documents and its context. Situation and memory stay global.
- **Signifiers:** several controls are plain text or bare icons (Stop, the ghost button, "What does this mean?", the plan counts in the sidebar). Give each one a visible shape, a label and a tooltip.
- **Mapping:** the Model settings mixed engine and model choice (fixed); in Settings, "You" vs the user's name (fixed). Check every screen for the same problem.
- **Feedback:**
  - queued questions;
  - "Saved" after document edits (done);
  - the law update should say what changed;
  - after ticking a linked condition, briefly show which other plans it counted for.
- **Constraints:** good examples to keep: ghost chats are one way, and plan ticks need proof. Add one: warn before sending a personal question in a ghost chat.
- **Error prevention and recovery:** answers that contradict their own quotes are the biggest error. Until R3 exists, show a visible "check this against the quote" note on every answer from a small model.
- **Consistency:** German and English mix in some places (checklist bullets in German, the UI in English). Rule: explanations in the user's language, legal terms in German with a translation.
- **Knowledge in the world:** German terms with English beside them work well; keep it. Explain *ist zu erteilen* / *soll* / *kann* (R27) wherever a rule is shown.
- **First run:** the user meets setup, model choice and legal disclaimers before asking anything. A guided "pick a model that works on this Mac" step belongs in first launch (R21).

### 5. Research to do before the next session
- [ ] Which local models do best at German legal text with structured output (check gemma4, granite4.2, qwen3.8, ministral-3 against the evaluation).
- [ ] The background sources above: what exists, licence, format.
- [ ] For "Working like a German lawyer": check that the current Anwendungshinweise zum StAG (after the 2024 reform) are published and reusable; how outdated the AVwV-AufenthG is; what rechtsprechung-im-internet.de and the state databases offer (format, licence); which leading BVerwG decisions cover the most-asked questions.
- [ ] Ask the legal reviewer to check the method section itself: the order of sources, what counts as "clear", and the deadline wording.
- [ ] **NeuRIS / rechtsinformationen.bund.de**: the Federal Government's open legal-information API (pilot until 2028; laws, court decisions, administrative provisions; meant to replace Gesetze im Internet). Evaluate it as a **bulk download source** for laws, BVerwG decisions and guidance, searched on the Mac like today's law update. Never as a live query service, because questions must not leave the Mac. Check terms, formats (XML, ELI/ECLI identifiers), and what it already contains for AufenthG, StAG and residence-law case law.
- [ ] Unofficial MCP servers exist (rechtsinformationen-bund-de-mcp, de-eli-mcp, german-law-mcp, gesetzessuche, gesetze-mcp). Not for the app (privacy), but possibly for development: letting tester agents check answer keys and the app's answers against official sources. Vet any package before installing.
- [ ] Who could do the legal review, and is there a free route (university law clinic, Refugee Law Clinic)?

### 6. Design and UX review (10 October)

Reviewed from the user's screenshots, the source, and the tester agent's report (computer use wasn't available to see the live app). Ranked by impact. **Tracked as GitHub issues [#2–#24](https://github.com/ingridstevens/lawyer/issues)** (labels P0/P1/P2); close them there and tick them here.

**P0: the core promise isn't kept yet**
- [ ] **Speed and reliability come first.** Answers take 70–150 s on an M1 Pro, and Apple's model, the default on first run, gives the worst answers. Everything else is secondary until a question gets a correct answer in under a minute. → stream the answer, shorter answers, try granite4.2:8b, full evaluation.
- [ ] **First run sets people up to fail.** A new user meets the disclaimer, then an 11-card setup, and their first question goes to Apple's model; choosing a better model is buried in Settings. Make first run: disclaimer → "choose how answers are made" (recommended model for this Mac, with a download progress bar) → three optional setup questions (language, status, goal) → first question. Everything else later, when it's needed.
- [ ] **Answer first, law second.** An answer page today stacks: explanation, "What the law requires", related documents, "In your plan", then one statute block per citation, each with a summary, the German paragraph, a translation and labels, then "where to ask" and "Answered by". It's thorough but long, and the reply to the question can get lost. Restructure:
  1. a short direct answer (two or three sentences) with a confidence line ("clear from the law" / "the authority decides" / "check with an advisor", R28);
  2. the conditions as a compact list, each linked to its paragraph;
  3. "Show the law" expanding the statute excerpts;
  4. one line for plan and documents ("3 of these are in your plan · you have 2 of the documents").

**P1: structure and mental model**
- [ ] **Too many places for "about me".** Situation, memory, goals, a chat's goal, chat notes, plans and documents are seven overlapping concepts. Make the **goal** the hub: a goal (e.g. Einbürgerung) holds its plan, its chats, its notes and the documents that matter for it. Situation and documents stay global. Memory and chat notes merge into "notes" with a scope (this chat / this goal / everywhere).
- [ ] **The sidebar mixes kinds of things** (chats, documents, help, plans). Group by goal: each goal with its plan and chats beneath; then "My documents", "Get help", and "Other chats".
- [ ] **Interface language.** Everything around the answers is English; refusals and errors appear in English exactly when someone is stuck. Localise the interface (R18), errors and refusals first.
- [ ] **Plain words over system words.** "Answered by qwen3.5:4b in 72 seconds", "Ghost chat", "Looked at", "engine" mean little to most users. "Answered on this Mac in about a minute"; "Private chat (doesn't use your details)"; "Sections I read"; "how answers are made".
- [ ] **Errors as directions.** Some errors still show technical text ("The model server answered with error 500 …", "wasn't in the expected format"). Each should say what happened in plain words and offer one action: try again, use the recommended model, or ask a free advisor.

**P1: features users expect**
- [ ] **Explain a letter from the authority (R9).** Probably the most common real need: "What does this Bescheid mean, and is there a deadline?" Drop in a PDF or photo; it's read on the Mac; the app explains it, finds the cited law, and puts any deadline first (R32).
- [ ] **Reminders.** "My permit expires on 3 May", "appointment on Tuesday": local notifications, a few weeks before. Fits the plans and the visit checklist.
- [ ] **Share an answer as a PDF** to bring to an advisor or appointment (the contact prep already prints).
- [ ] **Search across chats and documents.**
- [ ] **"This answer is wrong" button**, saving the question and answer locally for the evaluation set (nothing sent).
- [ ] **Lock with Touch ID**, since My documents may hold a passport and a residence card.

**P2: visual design**
- [ ] **One button language.** Links, bordered, prominent and plain buttons are mixed for similar actions (e.g. "What does this mean?" as a link, "Stop" bordered, plan ticks as plain icons). Define: primary action = prominent; secondary = bordered; inline navigation = link.
- [ ] **The margin layout everywhere, or nowhere.** The 76 pt gutter with DIN section numbers works well in answers, but on the home screen, plans and help pages it reads as an unexplained empty column. Keep it for statute excerpts; use a normal centred column elsewhere.
- [ ] **Type scale.** Answers use title3 body text, which is large for long German quotes; quotes in the serif at body size are good. Settle on: question bubble title3, explanation body (17 pt), quotes serif body, labels caption.
- [ ] **Contrast.** Several captions are secondary grey at caption size, below comfortable contrast for long reading. Check WCAG AA, especially the warnings and "machine translation" notes.
- [ ] **Repeated labels.** "Machine translation…" and "Official text as of …" repeat under every quote. Say it once per answer.
- [ ] **Icons.** SF Symbols are chosen ad hoc across sidebar, settings, help and home cards. Use one consistent set per concept (law = book, plan = checklist, documents = folder, help = person.2).

**P2: accessibility and polish**
- [ ] VoiceOver pass: chat bubbles, tracker, plan ticks, the statute highlight (the highlight must also be announced, not only shown in yellow).
- [ ] Keyboard: ⌘↩ to send, arrow keys through chats, Esc closes every overlay.
- [x] Window title repeats the first question; empty states for Plans and Help. Title shows "Not a Lawyer" until a chat is renamed; Plans explains when no goal is set (#24).

---

## Who this app is for

People living in Germany, or planning to, who need to understand the rules on their residence and can't easily read German legal text. They usually aren't lawyers, are often anxious about their status, and may be asking in their second or third language. Many have little time and limited money for a lawyer.

| Group | Typical situation | What they need most |
|---|---|---|
| **Skilled workers and Blue Card holders** | Came for a job; residence permit tied to work | When they can settle permanently; what happens if they change jobs or lose their job |
| **Long-term residents** | Have lived here for years; often already hold a Niederlassungserlaubnis | Conditions for becoming German; keeping their old nationality; long stays abroad |
| **Students and graduates** | Study permit; finishing a degree | Working while studying; looking for a job afterwards; switching to a work permit |
| **Families** | Spouse or children abroad, or here on a family permit | Bringing family over; a family member's own right to stay if the marriage ends |
| **Job seekers** | Opportunity card (Chancenkarte) or job-search permit | What they may do while searching; what they need to switch to a work permit |
| **EU, EEA and Swiss citizens and their families** | Free movement; often unsure which rules apply at all | Permanent right of residence; rights of non-EU family members |
| **Refugees and people with a Duldung or Aufenthaltsgestattung** | Uncertain status; high stakes | Work permission; routes to a secure residence title. (High risk: the app must be especially careful and point to free advice early.) |
| **Helpers** | Volunteers, social workers, friends and family helping someone else | Clear explanations they can pass on, with the paragraph to point to |

**Not for:** individual legal advice, deciding anyone's case, filling in or submitting applications, or law outside residence, citizenship and work permits (e.g. tax, tenancy, social benefits).

### Questions they ask

- **Staying and settling:** When can I get a Niederlassungserlaubnis? Is it faster with a Blue Card or a German degree? What's the difference between the Niederlassungserlaubnis and the Daueraufenthalt-EU?
- **Citizenship:** After how many years can I apply? What German level do I need? Do I need the Einbürgerungstest? Can I keep my nationality? Can my spouse and children be naturalised with me? Does Bürgergeld or time abroad stop me?
- **Keeping a permit:** How long can I leave Germany? What happens if my permit expires while I've applied to extend it (Fiktionsbescheinigung)? What happens if I lose my job? If my marriage ends?
- **Work:** Can I change employer? Work part-time or freelance? Can my spouse work? How many days can a student work?
- **Family:** Can my spouse, children or parents join me? What income and living space do I need? Does my spouse need German first?
- **Procedure:** Which authority is responsible? Which documents do I need? What does a letter from the Ausländerbehörde mean? What can I do against a refusal, and by when?
- **About themselves and the app:** What do I already have for my plan? Where can I get free help near me? Is my data safe?

---

## Requirements

Goals the app has to meet, worked through one at a time. Each says how we'll know it's met. ✅ met · 🟡 partly · ❌ not yet.

### Answers
- **R1 🟡 Answers common questions correctly.** (1 Oct: gemma4:12b and qwen3.5:4b now answer "What are the conditions for becoming German?" correctly; needs the full evaluation.) For the questions above, the answer explains the right rule and cites the right paragraph. *Measured by:* citation accuracy ≥ 90% on `eval/questions.jsonl`, with the answer key checked by a legal expert. *Today:* search finds the right section for 91–98% of questions, but the model often fails to answer (see "Next session").
- **R2 ❌ Answers fast enough to use.** *Target:* first words within 10 seconds (streaming), full answer within 60 seconds on a 16 GB Mac. *Today:* 1–3 minutes, no streaming.
- **R3 🟡 Every claim is backed by the law.** Each quote matches the official text word for word ✅. Every sentence of the explanation follows from a quoted paragraph ❌ (no check yet).
- **R4 🟡 Never decides the user's case.** No "you qualify", "you can't", "this applies to you". *Measured by:* verdict phrases in 0% of answers in all test languages. *Today:* flagged in the app, not yet measured.
- **R5 ✅ Says honestly when it can't answer,** shows what it looked at, and points to free help.
- **R6 🟡 Answers in the user's language.** *Measured by:* language fidelity ≥ 95% for German, English, Turkish, Arabic, Ukrainian, Russian, Spanish, Persian. *Today:* works for Turkish and English in tests; not measured for the rest.
- **R7 🟡 Handles questions the law answers by leaving something out,** like multiple nationality since 2024, via topic notes. Two topics so far.
- **R8 🟡 Answers the in-scope part of a mixed question** and names the part it can't cover.
- **R9 ❌ Explains official letters.** The user pastes or photographs a letter from an authority, and the app explains what it says, which law it cites, and any deadline, with a clear pointer to get help when there's a deadline or a refusal.

### Personal context
- **R10 ✅ Knows the user's situation without deciding for them:** guided setup, situation form, memory, documents.
- **R11 ✅ Plans show the law's conditions,** ticked with proof, consistent across plans.
- **R12 🟡 Covers the main goals with plans.** Citizenship and permanent residence exist. Missing: family reunification, changing jobs, students to work, job seekers, EU free movement.
- **R13 ❌ Warns about time-critical situations:** a permit about to expire, a refusal with an objection deadline, a long stay abroad. Shown prominently, with "ask now" help.

### Trust and privacy
- **R14 ✅ Nothing leaves the Mac** except the user-triggered law update; network gate and log.
- **R15 ✅ Ghost chats** that use nothing personal and aren't saved.
- **R16 ❌ Reviewed by someone qualified in migration law** before public release: wording, plans, topic notes, advice boundary.
- **R17 🟡 Laws are current.** Update button and last-checked date ✅. Automatic check (with consent) ❌.

### Reach
- **R18 ❌ The interface itself is in the user's language,** at least German, Turkish, Arabic (right to left), Ukrainian, Russian.
- **R19 🟡 Works on ordinary Macs.** Model advisor ✅. A model that answers well within 16 GB and 60 seconds ❌ (not found yet).
- **R20 🟡 Accessible:** VoiceOver, keyboard-only use, larger text, speech input ✅ (English on-device only so far).
- **R21 ❌ Easy to install:** signed, notarised `.dmg`, model download guided on first launch.
- **R22 ❌ Linux and Windows** later as a local web app.

### Getting help
- **R23 ✅ Points to free help** (MBE, JMD, Refugee Law Clinics, Flüchtlingsräte, authorities, lawyers) without claiming any relationship.
- **R24 🟡 Prepares contact with authorities and advisors:** German email, phone script and visit checklist ✅; translating the user's own questions into German ❌.

---

## Working like a German lawyer, without being one

Reading the statute is only the first step for a German lawyer. To answer "do my student years count half?", a migration lawyer would work through the steps below. The app should copy the method, not the role: it explains how the law is read and how sure that reading is, and still never decides the case.

### How German lawyers actually work

**1. Find every relevant rule, not just the obvious one (Systematik).** German statutes put definitions, counting rules and exceptions in separate paragraphs.
- The half-counting of study time is in **§ 9 Abs. 4 Nr. 3 AufenthG**, not in the list of conditions in § 9 Abs. 2.
- "Lebensunterhalt gesichert" (livelihood secured) is defined in **§ 2 Abs. 3 AufenthG**.
- Stays abroad for naturalisation are in **§ 12b StAG**.
- A lawyer follows references ("§ 9 Absatz 2 Satz 1 Nr. 2") and checks the definitions before answering.

**2. Read the rule's elements one by one (Subsumtion, Prüfungsschema).** A rule is split into its conditions (Tatbestandsmerkmale) and its legal consequence (Rechtsfolge). Each condition is checked against the facts, in a fixed order, and the conclusion follows only if all are met. Law students learn this as the "Gutachtenstil" (report style).

**3. Pay attention to how strong the consequence is.** This decides how confident anyone can be:
- *"ist zu erteilen"* (must be granted): an entitlement, a **Anspruch**;
- *"soll erteilt werden"* (should be granted): the authority must grant it unless the case is unusual;
- *"kann erteilt werden"* (may be granted): **Ermessen**, the authority's discretion. No one can promise the outcome.

**4. Interpret the wording when it isn't clear (Auslegung).** The four classic methods:
- the wording (Wortlaut);
- the context in the law (Systematik);
- the purpose of the rule (Telos);
- the legislative history (Historie: the government's reasons for the bill, the Gesetzesbegründung).

On top of that, residence law must be read in line with EU directives (the Blue Card and long-term residents directives, for example) and the constitution.

**5. Check the sources beyond the statute, in this order of weight:**
| Source | What it is | Binding? | Openly available? |
|---|---|---|---|
| Statute and ordinances (AufenthG, StAG, BeschV, AufenthV) | The law | Yes | ✅ gesetze-im-internet.de (already in the app) |
| Administrative guidance: AVwV-AufenthG; the Interior Ministry's Anwendungshinweise zum StAG; state and city instructions (e.g. Berlin's VAB) | How authorities must apply the law | Binds the authorities, not the courts | Mostly public; the AVwV dates from 2009 and is partly outdated |
| Court decisions, especially the Federal Administrative Court (BVerwG) and higher administrative courts (OVG/VGH) | How courts read the law | Formally only for the parties; in practice the highest courts' reading is followed | ✅ rechtsprechung-im-internet.de for federal courts; states have their own databases |
| Legislative materials (Bundestag-Drucksachen) | Why the rule was written | No, but used to interpret | ✅ dip.bundestag.de |
| Commentaries (e.g. Bergmann/Dienelt, Hailbronner, Huber/Mantel) and journals (ZAR, InfAuslR) | Expert opinion; the "herrschende Meinung" (prevailing view) | No, but very influential | ❌ Paid and copyrighted (beck-online, juris); the app can't include them |

**6. Know the facts and the practice.**
- Before advising, a lawyer asks for the facts and the documents.
- They know how the local Ausländerbehörde tends to decide, which varies between states and cities.
- They check deadlines first: an objection or lawsuit against a decision usually has to be filed within one month.

**7. Confidence comes from agreement.** A lawyer is confident when:
- the wording is clear;
- the administrative guidance says the same;
- the highest courts agree;
- there's no serious dispute in the commentaries.

Where any of these disagree, or the authority has discretion, the lawyer says so ("umstritten", disputed; "Ermessen", discretion) and explains the risk.

### What the app should do with this

- **R25 ❌ Follow the structure of the law.** Retrieval also loads the definitions, counting rules, exceptions and referenced paragraphs that belong to a rule: § 2 AufenthG, § 9 Abs. 4, § 12b StAG, "§ x Absatz y" references. Test: "Do my student years count half?" must find § 9 Abs. 4 Nr. 3, and must say it's written for the Niederlassungserlaubnis.
- **R26 ❌ Answer in the shape of a legal check.** Rule → its conditions one by one → definitions and exceptions → what follows. Each condition carries its paragraph. The model fills in the explanation; the app supplies the structure from the law.
- **R27 ❌ Say how strong the consequence is.** Detect "ist zu erteilen" / "soll" / "kann" and show it plainly: "If the conditions are met, the authority must grant it" vs "the authority decides (discretion)".
- **R28 ❌ Show how sure the answer is, and why.** Levels like:
  - "clear from the wording";
  - "the authority decides";
  - "official guidance says…";
  - "courts have decided…";
  - "interpretation differs, ask an advisor";
  - "not covered by this app".
- **R29 ❌ Add sources in layers, each labelled with its weight.** First the Anwendungshinweise zum StAG and the AVwV-AufenthG (marked "guidance for authorities, not law"). Then federal court decisions on the most-asked questions (marked "court decision"). Commentaries can't be included; at most, the app can say that commentaries exist and that an advisor will know them.
- **R30 ❌ Ask before answering when the facts decide it,** like a lawyer's intake: "Did you study in Germany? With which permit? Since when?" One or two questions, then the answer.
- **R31 ❌ Say where practice varies:** "How this is applied can differ between Ausländerbehörden; ask yours."
- **R32 ❌ Put deadlines first.** If a question mentions a refusal, a decision letter or an expiring permit, show the possible deadline and free help before anything else.
- **R33 ❌ Have the method and topic notes written or checked by someone qualified,** so the app's "how a lawyer would read this" is right. A partnership with a Refugee Law Clinic or a migration-law academic could provide this.

Throughout, the app stays an explainer under the Legal Services Act (Rechtsdienstleistungsgesetz): it shows the method and the sources, never the verdict.

- **R34 🟡 Follow-up questions use the conversation.** Started: each chat has a goal and notes, and the last three answered questions with their cited sections go into the next search and prompt. Still to measure with the conversation scenarios. Before this, every question was answered on its own, so "and do my student years count?" lost the topic. Next: say when a follow-up switches topic.

---

## Agentic RAG: where it stands and whether it makes sense

**Today: barely.** Each question gets:
1. one planning call: the model sorts the question and suggests search terms and up to three sections;
2. a keyword search the app runs, without the model;
3. one answer call;
4. the citation check.

There's no loop: the model can't search again, read a section it thinks is missing, follow a reference, or notice that its answer failed and retry. Small models also suggest wrong sections often, so their suggestions only get a small boost in the ranking.

**Would more make sense? Yes, in this order:**
1. **Let the app do the lawyer's steps itself, without the model:** follow references, load definitions and counting rules, add exceptions (R25). It costs no extra model calls, it's predictable, and it would have caught the "student years count half" case.
2. **One extra model step only when needed:** if the answer is a refusal or every citation fails, show the model the headings of the best sections and let it choose up to three to read, then answer again. One extra call, only on failure.
3. **A real tool-using agent** (`search_law`, `read_section`, `follow_reference`, `ask_user`), capped at three steps, **only for models that pass the evaluation with it.** Today's small local models misuse tools and each step adds 20–60 seconds, so for them this would make answers slower and not better. With a larger or faster model it could be the way to answer hard questions.
4. **Asking the user** (R30) is the most "agentic" step a lawyer takes, and the cheapest: one clarifying question can save a wrong search.

Measure each step with the scenarios below before keeping it.

---

## Conversation scenarios: the baseline

Multi-turn test cases, each turn building on the one before. They're run as a set on every version so we can see what got better or worse. Expected sections marked *(verify)* still need checking against the law before they're used as an answer key.

- [ ] Add these as `eval/scenarios.jsonl` (one object per scenario with its turns) and a `nal-eval scenarios` command that runs the turns in order in one chat, records the answer, citations, route and time for each turn, and appends a summary to `eval/history.csv`.
- [ ] Record the first baseline with the current version on gemma4:12b and qwen3.5:4b, then after each change.

### S1 · Becoming German
| Turn | Question | Should |
|---|---|---|
| 1 | What are the conditions for becoming German? | List the conditions of § 10 Abs. 1 StAG: five years, identity, commitment, residence title, livelihood, no convictions, B1, knowledge test |
| 2 | Do my years as a student count? | Stay on citizenship. Explain that § 10 asks for lawful, habitual residence. **Must not** apply the half-counting rule of § 9 Abs. 4 AufenthG, which is for the Niederlassungserlaubnis. Say the official guidance or an advisor can confirm how study years count *(verify)* |
| 3 | And what level of German do I need? | B1: § 10 Abs. 1 Nr. 6 and Abs. 4 StAG |

### S2 · Permanent residence after studying
| Turn | Question | Should |
|---|---|---|
| 1 | When can I get a Niederlassungserlaubnis? | § 9 Abs. 2 AufenthG: five years and the other conditions; mention that skilled workers have § 18c |
| 2 | Do my student years count? | **§ 9 Abs. 4 Nr. 3 AufenthG: study and vocational training in Germany count half** |
| 3 | I studied here and now work as a skilled worker. Is there a faster route? | § 18c Abs. 1: two years after a German degree, with 24 months of pension contributions |

### S3 · Blue Card
| Turn | Question | Should |
|---|---|---|
| 1 | What is the EU Blue Card? | § 18g AufenthG |
| 2 | When can I get permanent residence with it? | § 18c Abs. 2: 27 months, or 21 with B1 |
| 3 | Can my wife work if she joins me? | Family members' right to work *(verify: § 27 Abs. 5 AufenthG)* |

### S4 · A long stay abroad
| Turn | Question | Should |
|---|---|---|
| 1 | How long can I leave Germany without losing my residence permit? | § 51 Abs. 1 Nr. 7: six months, or a longer period set by the Ausländerbehörde beforehand |
| 2 | I have a Niederlassungserlaubnis. Does that change anything? | § 51 Abs. 4: a longer period is usually set for temporary stays; possibly § 51 Abs. 2 *(verify)* |
| 3 | Does a year abroad affect becoming German later? | § 12b Abs. 1 StAG: up to six months doesn't interrupt; longer only if back within the period set |

### S5 · Nationality and children
| Turn | Question | Should |
|---|---|---|
| 1 | Can I keep my nationality if I become German? | Topic note: §§ 10, 17, 26 StAG since 2024; the other country's law decides separately |
| 2 | Can my children become German with me? | § 10 Abs. 2 StAG |
| 3 | And my youngest, who was born here? | § 4 Abs. 3 StAG: born in Germany to a parent with five years' lawful residence and a permanent right to stay |

### S6 · Routing and scope
| Turn | Question | Should |
|---|---|---|
| 1 | Can my landlord raise my rent by 20%? | Out of scope: refuse briefly, no law quoted |
| 2 | What is my name? | About me: the name from settings, or "I don't know" |
| 3 | OK. Can I change my employer with a Blue Card? | Back to law: Blue Card rules on changing jobs *(verify: § 18g AufenthG)* |

### S7 · In Turkish
| Turn | Question | Should |
|---|---|---|
| 1 | Alman vatandaşlığı için şartlar nelerdir? | In Turkish; § 10 Abs. 1 StAG |
| 2 | Türk vatandaşlığımı koruyabilir miyim? | Topic note on multiple nationality; Turkey's own rules decide separately |
| 3 | Bir yıl yurt dışında okursam ne olur? | § 51 AufenthG and § 12b StAG, in Turkish |

### S8 · Ghost chat
| Turn | Question | Should |
|---|---|---|
| 1 | (ghost) When can I apply for citizenship? | General answer; no mention of the user's status or nationality |
| 2 | (ghost) What about in my case? | Explain that a ghost chat uses nothing about the user, and answer generally |

### What each scenario run records
- Per turn: route, sections found, sections cited, refused or not, verdict phrases, language, seconds.
- Per scenario: did follow-ups stay on topic (R34)? Did any turn state something the cited law doesn't say (checked by hand at first)?

---

## Where things stand

| Area | State |
|---|---|
| Law collection | AufenthG, StAG, BeschV, AufenthV, FreizügG/EU from the official XML; bundled snapshot; "Update laws"; last-checked date |
| Search | SQLite FTS5, multilingual dictionary with case/accent folding, section-level ranking, budget filling, topic notes |
| Routing | Planning step sorts questions into law, about me, about the app, other |
| Models | Apple on-device model; Ollama, LM Studio, llama.cpp (localhost only); model advisor |
| Trust | Verbatim citation check, refusals, verdict-phrase flag, "where to ask", network gate with log |
| App | Chats (saved) and ghost chats, home screen, guided setup, memory, documents, plans with proof, Get help, speech input |
| Tests | 55 unit tests including retrieval recall floors (41/45 Apple budget, 44/45 local); `nal-eval` for full model runs |

---

## Open

### Correctness and the advice boundary (most important)
- [ ] **Legal review** of wording, disclaimers, plans (including which conditions are linked across plans), topic notes, help texts and the advice boundary by someone qualified in migration law. Plans and topic notes are hand-written; tests only check that cited paragraphs exist.
- [ ] **Check every sentence of the explanation against the cited passages** (a second, short model call). The citation check proves quotes exist, not that the explanation follows from them. Seen in the app: "a person who is not an EU/EEA/Swiss citizen must…" (wrong: § 10 StAG applies to everyone) and "five full calendar years" (invented).
- [ ] When the main citation fails narrowly (quote almost matches a passage the model was given), show that paragraph unhighlighted and labelled "the model's quote didn't match exactly", instead of leaving only a side citation (seen: § 9 StAG spouse rule shown alone for a § 10 question).
- [ ] Measure verdict phrases per language in `nal-eval`, not just flag them in the app.
- [ ] Machine translations of quotes are unchecked.
- [ ] ARB 1/80 (EU–Turkey association law): add as a source, or at least a topic note. Today there's only a banner for Turkish citizens.
- [ ] **Apple's on-device model is unreliable for this app**: it blocks ordinary questions, and answered the stay-abroad question wrongly in both modes, then looped. gemma4:12b answered correctly. Consider making an installed local model the default.
- [ ] Number check in the app: flag deadlines, amounts and months in the explanation that aren't in a cited paragraph (`nal-eval` already measures this).

### Evaluation
- [ ] Have someone qualified check every gold section and reference answer in `eval/questions.jsonl` (50 questions, drafted from the statute text).
- [ ] Full `nal-eval` runs for Apple, gemma4:12b, qwen3.5:4b, granite4.2:8b; record in `eval/history.csv`. (The first gemma4:12b run never saved its results; the evaluator works now. A full run takes about 1.5 hours.)
- [ ] A **held-out** question set that dictionary tuning never sees, to catch overfitting.
- [ ] Decide release thresholds; replace the model advisor's guessed quality ranking with results.

### Retrieval
- [ ] Remaining misses: settle-bluecard-en (both budgets); cit-years-en, cit-child-birth-en, eu-family-en (Apple budget).
- [ ] Second look on refusal: show the model the headings of the 15 best sections, let it pick up to 3, answer again.
- [ ] Tool-using agent (`search_law`, `read_section`, `list_headings`) for local models that pass the evaluation with it, capped at 3 steps.
- [ ] Hybrid search with on-device `NLContextualEmbedding` (no download, multilingual).
- [ ] Follow cross-references (§ 18c → § 9 Abs. 2) when budget allows.
- [ ] German inflection: light suffix stripping instead of dictionary entries for each form.
- [ ] Reranking: the model orders the top 10 headings before passages are chosen.

### App
- [ ] Localise the interface (English only today; answers already follow the chosen language). Refusals and errors first. German, Turkish, Arabic, Ukrainian.
- [ ] Stream answers as they're written.
- [ ] Prepare a call/email/visit: translate the user's own questions into German with the local model (suggested questions are already bilingual).
- [ ] Warn about unsaved changes when switching documents in My documents.
- [ ] Export: include the documents themselves, not only the list.
- [ ] Highlight fade may not animate (attributed-string backgrounds don't interpolate); check, use an overlay if needed.
- [ ] Accessibility audit: VoiceOver labels, keyboard-only use, larger text; right-to-left check for Arabic and Persian.
- [x] Window title repeats the first question; now "Not a Lawyer" until a chat is renamed (#24).
- [ ] Speech input: only English has an on-device model on this Mac; other languages need Dictation enabled in System Settings. Consider macOS 26's `SpeechAnalyzer`.

### Release
- [ ] App Sandbox: replace the `unzip` subprocess and the `fdesetup` check; network entitlement limited to localhost and gesetze-im-internet.de.
- [ ] Apple Developer account, signing, notarisation, `.dmg` on GitHub Releases.
- [ ] README: what it is, privacy, supported models, limits.
- [ ] Licence.
- [ ] Check the gesetze-im-internet.de terms of use (the texts themselves are official works, § 5 UrhG).
- [ ] Essay: *Can a small local model explain German residency law?*
- [ ] Linux/Windows later as a local web app on the same core (spec §12).

---

## Done

### Foundation
- [x] Repo cloned; v1 notebooks moved to `legacy/`; branch `v2-local-law-explainer`; secrets and private files kept out of git
- [x] Swift package `NotALawyerCore` with no Apple-only code, `NotALawyerApple` for Foundation Models, `nal-eval` CLI, SwiftUI app in `App/`, `scripts/build-app.sh`
- [x] Official XML for the five laws, parser keeping exact wording, bundled snapshot with a last-checked date, user-triggered update

### Search and answers
- [x] SQLite FTS5 index; section-level ranking; budget filling with long paragraphs shortened, not dropped
- [x] Multilingual dictionary (en, de, es, tr, uk, ru, ar), case- and accent-folded; short words match whole words only
- [x] Planning step: routes questions (law, about me, about the app, other) and suggests terms and sections
- [x] Topic notes for questions the law answers by omission: multiple nationality (§§ 10, 17, 26 StAG; also triggered by naming another country), stays abroad (§ 51 AufenthG, § 12b StAG)
- [x] Verbatim citation check, tolerant of whitespace, quote styles, ellipses and wrong paragraph labels
- [x] Answer JSON schema sent in fixed field order (explanation first, `refused` last); lenient decoding
- [x] Verdict-phrase flag ("you cannot get…", "applies to you", "gerekli değil"…) with a warning in the answer
- [x] Partial answers: in-scope part answered, out-of-scope part named (e.g. another country's tax law)
- [x] Checklist cleanup (leaked JSON, duplicates); empty-explanation fallback
- [x] Section summaries ("what this section is about"), labelled as machine-written
- [x] Apple model: guardrail and refusal fallback to permissive text mode, then a plain message; context-size halving

### Privacy
- [x] Network gate: only localhost and gesetze-im-internet.de; everything else blocked and logged
- [x] Privacy summary, live connection list, FileVault check, data folder location
- [x] Ghost chats: one way, chosen before the first question, dark, never saved
- [x] Speech input recognised on this Mac only, never on Apple's servers
- [x] Documents read on this Mac (PDFKit, Vision) only to sort them; never given to the model

### App
- [x] First-launch explanation; home screen with greeting, plan progress and goal-based question cards
- [x] Chats: new, rename, delete, saved on this Mac (toggle and "Delete all chats" in Privacy)
- [x] Questions as message bubbles with the user's cat; edit and ask again; stop; "Answered by … in … s"; ask again with a new model
- [x] Progress tracker: Planning → Reading the law → Checking quotes, with a time estimate per model
- [x] Annotated-statute answer layout: section numbers in the margin, official paragraph with the quoted words highlighted, translation, "Looked at" for refusals, full "where to ask" once per chat
- [x] Guided setup (quiz) with branching, German names first, year-then-month date picker, applications with links to the law, goals including time abroad
- [x] Name and kawaii cat avatar; profile corner opens Settings
- [x] Settings overlay redesigned like System Settings (profile header, Personal/App groups, quiet grey icon tiles, the user's cat for their own tab, the user's name instead of "You")
- [x] Explanation style (Explain it to me / Quick and scannable / Use the legal terms); German-original option reworded
- [x] Memory; general vs personal questions via ghost chats
- [x] My documents: drop zone, "still missing for your plans", automatic sorting with language level and date, explicit Save, Preview, Show in Finder
- [x] Plans: Einbürgerung, Niederlassungserlaubnis (§ 9, § 18c Abs. 1 and 2), Daueraufenthalt-EU; conditions ("I meet this") and actions ("Mark as done") need proof; "What does this mean?"; answers show and tick the plan items they cover
- [x] Same condition across plans (B1 German, basic knowledge, public security, living space) ticks together, with the same proof; existing ticks carried over; similar-but-different conditions (livelihood, pension months, Blue Card German) stay separate but offer earlier proof for reuse
- [x] Get help: free help near you (MBE, JMD, Refugee Law Clinics, Flüchtlingsräte, Ausländerbehörde, Einbürgerungsbehörde, lawyers) with official finders, no claimed relationship
- [x] Prepare an email, call or visit: German text with English alongside, bring-with-you checklist from My documents, copy, print or save as PDF
- [x] Free-text fields (your own question, memory) are full-width boxes with the cursor on the left
- [x] Model advisor: reads chip, memory and disk; recommends, estimates seconds per answer, measures real times, downloads through Ollama; newer models (granite4.2, qwen3.8, ministral-3)
- [x] Fun mode built and then removed at the user's request (1 Oct 2026); one plain look only
- [x] Banners: stale laws (by last check), unsupported language, Turkish citizens and ARB 1/80
- [x] App icon

### Testing
- [x] 55 unit tests: parser, search, citation check, network gate, topic notes, plans, schema order, saved answers, regressions from real bugs
- [x] Retrieval recall test on `eval/questions.jsonl` with floors that fail `swift test` if search gets worse
- [x] `nal-eval`: routing, refusals, citation accuracy, language fidelity, unsupported numbers, history log
- [x] Usability test by a tester agent as a Turkish persona; findings fixed (crash on a repealed section, wrong law for stays abroad, Turkish word forms, guardrail errors)

---

## Choosing a model

The advisor in Settings → Model does this automatically. Rules of thumb:

| Memory | Recommendation |
|---|---|
| 8 GB | Apple's on-device model, or granite4.2:3b |
| 16 GB | granite4.2:8b, qwen3.5:9b or gemma4:e4b |
| 24 to 32 GB | gemma4:12b or ministral-3:14b |
| 48 GB+ | gemma4:26b, qwen3.5:27b or qwen3.8:27b |
| 64 GB+ | gemma4:31b |

Speed depends on memory bandwidth: a base M1 (68 GB/s) writes about half as fast as an M1 Pro (200 GB/s) with the same model.

## How to track quality

```bash
swift test --package-path Packages/NotALawyerCore
```
Runs in seconds, no model. Fails if retrieval recall drops below its floor.

```bash
Packages/NotALawyerCore/.build/release/nal-eval run --model ollama:gemma4:12b
```
Full run with a model. Writes a report to `eval/results/` and appends a line to `eval/history.csv` with the commit, so runs can be compared over time.
