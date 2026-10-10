# Not a Lawyer

A Mac app that explains German residency and citizenship law in your own language. Every answer quotes the exact paragraph of the law it's based on, word for word from the official text, and the model that writes it runs on your Mac. Your questions, your details and your documents never leave it.

**This is not legal advice.** The app explains what the law says; it never decides whether you qualify. For a binding answer about your case, ask your Ausländerbehörde, a free Migrationsberatung, or a lawyer for migration law.

> **Status: early development (v2).** It works, but answers are slow (about 1–2½ minutes) and not yet reliable enough to depend on. The wording, plans and disclaimers haven't had a legal review yet. See [docs/ROADMAP.md](docs/ROADMAP.md).

## What it does

- **Answers with the law attached.** Ask in English, German, Turkish, Arabic, Ukrainian or another language. The answer explains the rule, lists its conditions, and shows the official German paragraph with the quoted words highlighted, plus a translation.
- **Checks every quote.** A citation is shown only if its quote appears word for word in the official text. If no rule answers the question, the app says so and points to free help.
- **Covers five laws:** Aufenthaltsgesetz, Staatsangehörigkeitsgesetz, Beschäftigungsverordnung, Aufenthaltsverordnung and Freizügigkeitsgesetz/EU, from the official XML on gesetze-im-internet.de.
- **Knows your situation without deciding for you.** Optional setup (status, goals, arrival date), plans for goals like naturalisation or permanent residence (ticked off with your own proof), and a private folder for your documents.
- **Helps you get help.** Lists free advice services and how to find the nearest one, and prepares a German email, phone script or visit checklist.
- **Private by design.** The app connects only to a model server on your own Mac and, when you choose "Update laws", to gesetze-im-internet.de. Every other connection is blocked, and each one is shown in Settings → Privacy. Ghost chats use nothing about you and are never saved.

## What you need

- A Mac with Apple silicon and macOS 26 or later.
- A model. Either:
  - **Ollama** (free, recommended): install from [ollama.com](https://ollama.com/download/mac). The app recommends and downloads a model that fits your Mac (for example `gemma4:12b` with 32 GB of memory).
  - **LM Studio** or **llama.cpp**, running on your Mac.
  - **Apple's on-device model** (Apple Intelligence). Nothing to install, but in testing it gives the weakest answers.

## Build and run

```bash
scripts/build-app.sh
```
```bash
open "build/Not a Lawyer.app"
```

The script builds a signed `.app` into `build/`. To stop macOS asking for microphone permission again after every build, create a code-signing certificate named "Not a Lawyer Development" once (Keychain Access → Certificate Assistant → Create a Certificate…, type "Code Signing"); the script uses it automatically.

## Tests and evaluation

```bash
swift test --package-path Packages/NotALawyerCore
```
Runs in seconds, without a model. It includes a retrieval test on `eval/questions.jsonl` that fails if search quality drops.

```bash
swift run --package-path Packages/NotALawyerCore nal-eval ask "What are the conditions for becoming German?" --model ollama:gemma4:12b
```
Asks one question through the full pipeline and prints the answer, citations and time per stage. `nal-eval run` runs the whole question set and appends the results to `eval/history.csv`.

## How it's built

```text
Packages/NotALawyerCore/      Swift package; the core has no Apple-only code
├── NotALawyerCore/           law parser, search (SQLite FTS5), citation check, prompts, plans
├── NotALawyerApple/          Apple's on-device model (Foundation Models)
└── nal-eval/                 command-line runner for questions and evaluations
App/                          the SwiftUI Mac app
data/snapshot/                bundled official law texts and the date they were checked
eval/questions.jsonl          test questions with the sections that should answer them
docs/ROADMAP.md               requirements, open issues and what's done
legacy/                       v1: the original Jupyter notebooks
```

An answer goes through four steps: search the laws on the Mac (keywords, a multilingual dictionary and the main rule for each topic), give the best passages to the model, check every quote against the official text, then show the answer or an honest refusal.

## Version 1

The original notebooks (a local version with Ollama and a hosted version) are in [`legacy/`](legacy/).

## Further reading

- [Gesetze im Internet](https://www.gesetze-im-internet.de/), the official source of the law texts
- [BAMF-NAVI](https://bamf-navi.bamf.de/de/Themen/Beratungsstellen/), to find free migration counselling near you
- [Einbürgerung in Deutschland](https://www.einbuergerung.de/), the Federal Government's guide to naturalisation
