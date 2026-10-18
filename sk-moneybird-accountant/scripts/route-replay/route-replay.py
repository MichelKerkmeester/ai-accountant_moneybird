#!/usr/bin/env python3
# ───────────────────────────────────────────────────────────────
# COMPONENT: ROUTE REPLAY
# ───────────────────────────────────────────────────────────────
"""Resolve the routing fixture corpus and score the routes offline.

The resolve mode builds a router snapshot out of the task-type table in
section 2 of the skill's ROUTER.md and the resource map under references/. A
revision from before the hub keeps the table in the skill's SKILL.md, so the
scorer falls back to that file when ROUTER.md holds no route table. It hashes
the snapshot, runs a connectivity gate over every routed path, resolves each
corpus prompt with a deterministic signal scorer and scores the row against
the gold mode, task type, path set, facts, file claims and token ceiling.
Output is results.csv and report.md. A file claim names one path and one text
that must appear in the scored revision, so a row can guard content its read
set does not load. A row that names `gold_packets` is also scored for the hub
packet chain, which stage one resolves from mode-registry.json,
hub-router.json and the winning tool route. No model answers a question, so
answer quality stays unscored. Time, environment and absolute paths never
enter an output.

The replay mode runs the guard in test mode against the stub CLI and asserts
the recorded command line and exit code of every refusal row and of every
hostile invoice case. The key file, the run journal and the stub log live in
one run-owned temp root, so no credential or workspace is read.

Token counts use the pinned o200k_base encoding that the token baseline
loads. A missing cache folder or a sha256 pin mismatch stops the run with
exit code 2 instead of starting a download.

Usage:
    TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve
    TIKTOKEN_CACHE_DIR=<cache> python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode resolve --out /tmp/route-replay
    python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode replay
    python3 -I sk-moneybird-accountant/scripts/route-replay/route-replay.py --mode replay --rev HEAD~1 --covers <tag>

Options:
    --mode       resolve scores pure route resolution. replay runs the guard
                 in test mode against the stub and scores the refusal rows.
    --corpus     Read the fixture corpus from this path. The default is
                 routing-gold.json next to this script.
    --out        Write results.csv and report.md into this folder. The
                 default is benchmark/reports/route-replay under the skill.
    --skill-root Read ROUTER.md and references/ from this folder. The default
                 is the skill folder that holds this script. It cannot be
                 combined with --rev.
    --rev SHA    Score a git worktree of that revision instead of the live
                 tree. The worktree is added in a temp folder and removed
                 after the run.
    --covers P/R Only score rows tagged with this phase and requirement.
                 Repeat the option to select more than one tag.
    --guard PATH Replay this guard instead of the one under the repo root.
    --stub PATH  Replay against this stub CLI instead of the one under the
                 repo root.

Output:
    results.csv with the columns scenario_id, lang, split, gold_mode,
    gold_task_type, score, verdict, reason, tokens_loaded, t7, destination,
    reads and packets,
    report.md with the scored dimensions, the accuracy lines, the per-type
    precision and recall with denominators, the read counts, the warning
    band sink and the additive T7 assertion, and a one-line summary on
    stdout. A replay run adds command, expected_exit and actual_exit
    columns. Exit 0 when every row passes, 1 on a row or parity finding and
    2 on a usage, corpus, encoding cache or connectivity error.
"""

# ───────────────────────────────────────────────────────────────
# 1. IMPORTS
# ───────────────────────────────────────────────────────────────

import argparse
import ast
import csv
import hashlib
import importlib.util
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import tempfile
from typing import Any, Dict, List, NoReturn, Optional, Sequence, Tuple

# ───────────────────────────────────────────────────────────────
# 2. CONFIGURATION
# ───────────────────────────────────────────────────────────────

PROGRAM = "route-replay"
GENERATOR = "sk-moneybird-accountant/scripts/route-replay/route-replay.py"
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_ROOT = os.path.dirname(os.path.dirname(HERE))
CORPUS_NAME = "routing-gold.json"
DEFAULT_OUT = os.path.join(SKILL_ROOT, "benchmark", "reports", "route-replay")
SKILL_MD_NAME = "SKILL.md"
ROUTER_MD_NAME = "ROUTER.md"
SKILL_FOLDER_NAME = "sk-moneybird-accountant"
HUB_ROUTER_NAME = "hub-router.json"
MODE_REGISTRY_NAME = "mode-registry.json"
SIGNALS_NAME = os.path.join("references", "routing-signals.md")
MIGRATION_INDEX = os.path.join("references", "migration", "README.md")
ROUTER_START = "<!-- router-block:start -->"
ROUTER_END = "<!-- router-block:end -->"
REFERENCE_INDEX = os.path.join("references", "index.json")
BASELINE_HELPER = os.path.join("scripts", "token-baseline.py")
HOSTILE_CASES = os.path.join("assets", "hostile-invoice-cases.json")
GUARD_RELATIVE = os.path.join("cli-moneybird", "cli", "moneybird-cli", "moneybird-guard")
STUB_RELATIVE = os.path.join("cli-moneybird", "cli", "moneybird-cli", "tests", "stub-moneybird-cli")
MISSING_WRITER_MARKER = "__MISSING_WRITER__"

START_MARKER = "<!-- route-table:start -->"
END_MARKER = "<!-- route-table:end -->"
TOC_START = "<!-- GENERATED:toc:start -->"
TOC_END = "<!-- GENERATED:toc:end -->"
ROW_RE = re.compile(r"^\|\s*(T\d+)\s*\|")
PHASE_ROW_RE = re.compile(r"^\|\s*(\d+)\s*\|[^|]*\|\s*\[[^\]]+\]\(\./([^)]+)\)\s*\|")
TOC_LINE_RE = re.compile(r"^-\s+(.+?):\s+lines\s+(\d+)-(\d+)\s*$")
BACKTICK_RE = re.compile(r"`([^`]*)`")
YEAR_TOKEN = "{year}"
PHASE_PLACEHOLDER = "{phase-file}"
TOPIC_PLACEHOLDER = "{topic-figures}"
YEAR_FOLDER_RE = re.compile(r"^\d{4}$")
YEAR_RE = re.compile(r"\b(19|20)\d{2}\b")
PHASE_RE = re.compile(r"(?:fase|phase)\s*(\d+)", re.IGNORECASE)
PASSED_RE = re.compile(r"(passed|gehaald|afgerond|doorlopen)\s+(?:fase|phase)?\s*$", re.IGNORECASE)

# WHY: the contract fixes these three rows as the preparation rows, so the
# filing precedence drops exactly these candidates when a T8 signal matches.
PREPARE_TYPES = ("T10", "T11", "T12")
REPORT_TYPES = tuple("T%d" % number for number in range(1, 13))

BASE_COLUMNS = (
    "scenario_id",
    "lang",
    "split",
    "gold_mode",
    "gold_task_type",
    "score",
    "verdict",
    "reason",
    "tokens_loaded",
    "t7",
    "destination",
    "reads",
)

# WHY: only resolve mode resolves a packet chain, so the replay columns omit it.
RESULT_COLUMNS = BASE_COLUMNS + ("packets", "tier")

REPLAY_COLUMNS = BASE_COLUMNS + (
    "command",
    "expected_exit",
    "actual_exit",
)

MODE_BY_TYPE = {
    "T1": "MIGRATION",
    "T2": "MIGRATION",
    "T3": "LIVE",
    "T4": "LIVE",
    "T5": "LIVE",
    "T6": "LIVE",
    "T9": "MIGRATION",
    "T10": "LIVE",
    "T11": "LIVE",
    "T12": "LIVE",
}

# WHY: the table names the signal families in prose, so a few fixtures need
# the same family in the other language or in a compound spelling.
EXTRA_SIGNALS = {
    "T1": (
        "write_intent",
        "write intent",
        "run journal",
        "read-back",
        "read back",
        "auditfile",
        "trial",
        "access window",
        "gated write",
        "m12",
        "agent_drafted",
        "proefperiode",
        "schrijfbatch",
        "leescontrole",
    ),
}

OUT_OF_SCOPE_PATTERNS = (
    r"file (?:my|the|our) [a-z ]*return",
    r"submit (?:my|the|our) [a-z ]*return",
    r"\bfiling\b",
    r"\baangifte\b",
    r"private database",
    r"personal database",
    r"persoonlijke database",
    r"priv[eé]database",
    r"non-dutch tax",
    r"german income tax",
)
NEGATION_RE = re.compile(
    r"(?:\bno\b|\bnot\b|\bnever\b|n['\u2019\u00b4`\u02bc]t\b|\bdont\b|\bwithout\b|\bgeen\b|\bniet\b|\bzonder\b"
    r"|\bniets\b|\bniks\b|\bnothing\b)\s*$",
    re.IGNORECASE,
)
# WHY: a CLI name keeps its negation across one verb, so "do not use jortt-cli"
# and "gebruik geen jortt-cli" name no CLI to start in.
TOOL_NEGATION_RE = re.compile(
    r"(?:\bno\b|\bnot\b|\bnever\b|n['\u2019\u00b4`\u02bc]t\b|\bdont\b|\bwithout\b|\bgeen\b|\bniet\b|\bzonder\b)"
    r"(?:\s+\w+)?\s*$",
    re.IGNORECASE,
)
# WHY: "not only", "niet alleen" and "don't forget" add a tool rather than
# exclude it, so they negate nothing.
NEGATION_EXEMPT_RE = re.compile(
    r"(?:\bnot\s+only|\bniet\s+alleen|\bniet\s+enkel|n['\u2019\u00b4`\u02bc]t\s+forget|\bnot\s+forget|\bnever\s+forget"
    r"|\bvergeet\s+niet|\bniet\s+vergeten)\b(?:\s+\w+)?\s*$",
    re.IGNORECASE,
)
# WHY: a boundary word such as "personal database" keeps its negation across a
# few words, so "without reading my personal database" names no boundary. A
# filing verb does not, because "don't forget to file it" asks to file.
BOUNDARY_NEGATION_RE = re.compile(
    r"(?:\bno\b|\bnot\b|\bnever\b|n['\u2019\u00b4`\u02bc]t\b|\bdont\b|\bwithout\b|\bgeen\b|\bniet\b|\bzonder\b)"
    r"(?:\s+\S+){0,4}\s*$",
    re.IGNORECASE,
)
# WHY: a gap of up to sixty characters inside one clause lets a few words
# stand between two grammar parts without crossing a clause break.
CLAUSE_GAP_CHARS = 60
CLAUSE_GAP = r"[^,.;:!?]{0,%d}" % CLAUSE_GAP_CHARS
# WHY: "I can't file it myself" says the user cannot file, and negates no request.
USER_CANNOT_RE = re.compile(
    r"\b(?:i|we)\s+can['\u2019\u00b4`\u02bc]?t(?:\s+\w+)?\s*$"
    r"|\b(?:ik|wij|we)\s+(?:kan|kunnen|durf|durven)\b" + CLAUSE_GAP + r"\bniet(?:\s+zelf)?\s*$",
    re.IGNORECASE,
)
BOUNDARY_SIGNAL_RE = re.compile(r"\b(?:database|non dutch tax)\b")
# WHY: a filing verb keeps its negation across adverbs, a wish such as "want
# you to" and an alternative verb, so "do not ever submit it", "I don't want you
# to submit it" and "do not file or submit it" request no filing. An "and"
# starts a new request, as in "don't wait and submit it".
FILING_NEGATION_RE = re.compile(
    r"(?:\bno\b|\bnot\b|\bnever\b|n['\u2019\u00b4`\u02bc]t\b|\bdont\b|\bwithout\b|\bgeen\b|\bniet\b|\bzonder\b"
    r"|\bniets\b|\bniks\b|\bnothing\b|\bunder no circumstances\b|\bin no case\b|\bonder geen beding\b"
    r"|\bin geen geval\b)"
    r"(?:\s+(?:ever|yet|now|actually|really|under any circumstances|in any case|ooit|nog|meer|zomaar))*"
    r"(?:\s+(?:want|need|wish|expect|ask|allowed|permitted|supposed)(?:\s+(?:you|u|je))?)?(?:\s+to)?"
    r"(?:\s+dat(?:\s+(?:je|u|jij|jullie|de|het|ze|hij|zij))?)?"
    r"(?:\s+(?:it|them|hem|het|die|iets|anything))?(?:\s+\S+\s+(?:or|of))?\s*$",
    re.IGNORECASE,
)
# WHY: each guard is anchored to the filing verb. A question word, a time word,
# a purpose or a deadline counts only when it governs the verb, so "after I
# approve, please submit it" and "the deadline is Friday so file it" still ask
# to file while "before I send it in" and "the deadline to file" do not.
FILING_FRAME_RE = re.compile(
    r"\b(?:when|how|what|which|where|wanneer|hoe|wat|welke|waar)\b(?:\s+\S+){0,3}?\s+"
    r"(?:do|does|did|must|should|can|could|shall|will|would|have|has|am|is|are|need"
    r"|moet|moeten|kan|kunnen|mag|mogen|zal|zullen|hoef|hoeven)\s+(?:i|we|ik|wij|je|u|one)\b(?:\s+\S+){0,5}\s*$"
    r"|\b(?:wanneer|hoe|waar)\s+(?:ik|wij|we)"
    r"(?:\s+(?!(?:ben|bent|is|zijn|was|waren|heb|hebt|heeft|hebben|had|word|wordt)\b)\S+){0,4}\s*$"
    r"|\b(?:when|how|where|wanneer|hoe|waar)\s+(?:to|i|we|ik|wij)(?:\s+(?:am|are|is|have|has|had|do|does|did|can|could|should|must|need|needs|ought|supposed|allowed"
    r"|going|to|will|would|shall|may|might|always|usually|actually|ever|then|also|just|even|moet"
    r"|moeten|kan|kunnen|mag|mogen|hoef|hoeven|zal|zullen|ga|gaan|nu|dan|ook|zelf|altijd|meestal)){0,4}\s*$"
    r"|\b(?:hoe|wanneer|waar)\s*$"
    r"|^\s*(?:do|does|did|am|is|are|must|should|shall|need|have|moet|moeten|ben|hoef|hoeven|mag|mogen)"
    r"\s+(?:i|ik|one|it|het)\b(?![^?]*\b(?:you|je|jij|u|jullie)\b)(?:\s+\S+){0,6}\s*$"
    r"|^\s*(?:do|does|did|are|must|need|have|moeten|hoeven)\s+(?:we|wij)\b(?:\s+\S+){0,6}\s*$"
    r"|\b(?:before|after|until|once|if|when|voor|voordat|nadat|totdat|als|zodra|wanneer)"
    r"\s+(?:i|we|ik|wij|he|she|they|hij|zij|ze|(?:my|our|the|mijn|onze|de)\s+\w+)"
    r"(?:\s+(?:can|will|have|do|kan|ga|it|them|hem|het|die|zelf|then|daarna|actually))*\s*$"
    r"|\b(?:when|wanneer)\s+(?:you|je|u)\s*$"
    r"|\bso\s+(?:that\s+)?(?:i|we|he|she|they|my\s+\w+|our\s+\w+|the\s+\w+)\s+(?:can|could|may|will)"
    r"(?:\s+(?:then|later|also|still|easily|myself|ourselves|herself|himself|get|have|\S+\s+(?:and|en)))*\s*$"
    r"|\b(?:the|my|our|de|mijn|onze)\s+(?!assistant\b|assistent\b)\w+\s+"
    r"(?:will|can|could|may|shall|kan|zal|gaat|moet|is going to|has to|needs to)"
    r"(?:\s+(?:hem|het|die|zelf|morgen|vandaag|nog|\w+dag))*\s*$"
    r"|^\s*(?!(?:you|je|jij|u|who|wie|assistant|assistent|claude|it|this|that|there)\b)\w+\s+"
    r"(?:will|shall|zal|gaat|is going to|has to|needs to)"
    r"(?:\s+(?:hem|het|die|zelf|morgen|vandaag|nog|\w+dag))*\s*$"
    r"|\b(?:prepare|check|review|bereid|controleer)\b[^,.;:!?]*\bin order to\s*$"
    r"|\bzodat\s+(?:ik|we|wij|hij|zij|ze|mijn\s+\w+|onze\s+\w+)(?:\s+\S+){0,4}\s*$"
    r"|\bfor\s+(?:me|us|my\s+\w+)\s+to\s*$|\bvoor\s+(?:mij|ons)\s+om(?:\s+\S+){0,4}\s*$"
    r"|\b(?:deadline|due date|last date|date|datum|uiterste datum|termijn|aangiftetermijn)\s+(?:to|for|om|voor)"
    r"(?:\s+\S+){0,5}\s*$"
    r"|(?<!\bnow\s)(?<!\bso\s)(?<!\bnu\s)\b(?:that|which|die|dat)\s+(?:i|ik|we|wij|my\s+\w+|our\s+\w+|mijn\s+\w+|onze\s+\w+|the\s+\w+|de\s+\w+)"
    r"(?:\s+(?!and\b|en\b|or\b|of\b)\S+){0,3}\s*$"
    r"|\b(?:forgot|forgotten|vergeten|vergat|missed|failed)\b(?:\s+(?!so\b|dus\b|and\b|en\b|but\b|maar\b)\S+){0,5}\s*$"
    r"|\b(?:steps?|stappen|checklist|documents?|documenten|stukken|needed|required"
    r"|(?<!\bje\s)(?<!\bjou\s)(?<!\bu\s)nodig|instructions|instructies)\b"
    r"(?:\s+(?!(?:is|are|was|wordt)\b)\S+){0,4}?\s+(?:om|to)\b(?:\s+\S+){0,5}\s*$"
    r"|\b(?:(?:tell|show|vertel|laat)\s+(?:me|mij|us|ons)(?:\s+(?:weten|know|zien))?|laat\s+zien|show|explain"
    r"|leg\s+uit|uitleggen)\s+(?:when|how|what|where|who|why|whether|if|wanneer|hoe|wat|waar|wie|waarom|of)\b"
    r"(?:\s+(?!and\b|en\b|then\b|dan\b|daarna\b|but\b|maar\b)\S+){0,8}\s*$"
    r"|\b(?:remind|herinner|ask|vraag|tell|vertel)\s+(?:my|mijn|the|de|our|onze)\s+\w+\b"
    r"(?:\s+(?!and\b|en\b|then\b|dan\b)\S+){0,8}\s*$"
    r"|\b(?:not\s+(?:yet\s+)?|almost\s+|nearly\s+)ready\s+to\s*$|\b(?:bijna|nog niet)\s+klaar\s+om\b(?:\s+\S+){0,5}\s*$"
    r"|\bop het punt\b(?:\s+\S+){0,5}\s*$"
    r"|\b(?:remind|herinner)\s+(?:me|mij|us|ons)\b(?:\s+(?!and\b|en\b|then\b|dan\b|daarna\b|but\b|maar\b)\S+){0,8}\s*$"
    r"|\b(?:add|create|make|set|schedule|plan|new|maak|zet|voeg)\b(?:\s+\S+){0,3}?\s+"
    r"(?:reminder|herinnering|task|taak|todo|to do)\b(?:\s+\S+){0,8}\s*$"
    r"|\b(?:reminder|herinnering)\s*$"
    r"|\b(?:i|we|ik)\s+(?:remember|onthoud|onthouden)\s+(?:to|om)\s*$"
    r"|\bhelp\s+(?:me|us|mij|ons)\s+(?:prepare|get ready|voorbereiden|klaar)\b(?:\s+\S+){0,6}\s*$"
    r"|\b(?:i want to know|i wonder|i would like to know|ik wil weten|ik vraag me af|ik wil graag weten)"
    r"\s+(?:when|how|what|where|whether|if|wanneer|hoe|wat|waar|of)\b(?:\s+\S+){0,8}\s*$",
    re.IGNORECASE,
)
# WHY: a user subject right before the verb, or right after it in a Dutch
# inversion, names the user as the one who files, as does a third person.
# An auxiliary before the subject asks the question "can we file it?".
FILING_SUBJECT_BEFORE_RE = re.compile(
    r"(?:\b(?:i|ik)|(?<!\bcan\s)(?<!\bcould\s)(?<!\bshall\s)(?<!\bshould\s)(?<!\bmay\s)(?<!\bwill\s)(?<!\bdon't\s)(?<!\bdont\s)"
    r"\b(?:we|wij|he|she|they|hij|zij|ze))(?:['\u2019\u00b4`\u02bc](?:ll|d|m|re))?"
    r"(?:\s+(?:then|daarna|zelf|myself|ourselves|always|altijd|usually|meestal|will|shall|ga|gaan|can|kan"
    r"|kunnen|zal|zullen|moet|moeten|wil|willen|am|are|is|going|to|plan|plans|want|wants|intend|have|has"
    r"|need|needs|should|must|would|like|prefer|rather|just|also|ook|ourselves|himself|herself|hem|het|die"
    r"|morgen|vandaag|nog|straks|later|tomorrow|today|about|ready|hoping|trying|planning|aiming|looking|getting"
    r"|starting|preparing|not|bijna|klaar|probably|maybe|eventually|soon))*\s*$",
    re.IGNORECASE,
)
# WHY: a note or a reminder before a colon, as in "reminder: file it in May",
# writes the filing down and asks for none, while "todo:" and "task:" assign it.
FILING_NOTE_RE = re.compile(r"\b(?:reminder|herinnering|note|notitie)\s*:\s*$")
# WHY: a Dutch subclause puts its verb last, so a finite filing verb after one,
# as in "wanneer ik akkoord geef dien de aangifte in", opens the main clause.
DUTCH_FINITE_VERBS = ("dien", "stuur", "verstuur", "verzend", "lever", "betaal", "vergrendel", "sluit", "meld", "doe")
DUTCH_SUBCLAUSE_RE = re.compile(r"\b(?:wanneer|als|zodra|voordat|nadat|totdat|zodat)\s+\S+(?:\s+\S+)*\s*$")
FILING_SUBJECT_AFTER_RE = re.compile(r"^\s+(?:ik|wij|we)\b", re.IGNORECASE)
# WHY: a filing noun after a preposition, such as "before filing" or "voor het
# indienen", names the act and requests none. So does a noun that the user owns
# or that is the subject, as in "leave the filing to me" or "filing happens later".
FILING_NOUN_BEFORE_RE = re.compile(
    r"\b(?:before|prior to|after|(?<!how\s)(?<!what\s)about|on|of|for|with|until|without|how|voor|na|van|over|bij|tot|met|zonder|hoe)"
    r"(?:\s+(?:the|het|de|een|a|niet|op tijd))*\s*$",
    re.IGNORECASE,
)
FILING_NOUN_AFTER_RE = re.compile(
    r"^(?:\s+\S+){0,3}?\s+(?:to me|aan mij|myself|ik zelf|doe ik|is up to me|up to me)\b"
    r"|^\s+(?:happens|gebeurt|comes|follows|volgt|is|stays|remains|rests|blijft|ligt|doet|does)\b",
    re.IGNORECASE,
)
FILING_NOUN_SIGNALS = ("filing", "indienen", "het indienen")
FILING_REQUEST_LEAD_RE = re.compile(
    r"^\s*(?:(?:please|graag|gewoon|even|now|nu)\s+)*(?:go ahead|go on|proceed|continue|start|begin|get started|take care|carry on"
    r"|ga door|ga verder|zorg|regel|neem|verzorg)\b",
    re.IGNORECASE,
)
# WHY: a real question asks about filing unless it asks the assistant to file,
# as in "can you file it?", "can we file it today?" or "how about you file it".
QUESTION_REQUEST_RE = re.compile(
    r"\b(?:can|could|would|will|kun|kunt|kan|wil|zou|zal)\s+(?:you|je|jij|u)\b"
    r"|\b(?:you|jij|jullie)\b|\b(?:wilt|kunt|dient|heeft|bent|zou|zouden|willen|kunnen)\s+(?:u|je|jij|jullie)\b"
    r"|\b(?:dat|als)\s+(?:u|je)\b|\b(?:heb|durf|ga|doe|dien)\s+je\b|\blukt het\b|\bfor me\b|\bvoor (?:mij|me)\b"
    r"|\b(?:can|could|shall|should|kunnen|mogen|gaan|zullen)\s+(?:we|wij)\b"
    r"|\b(?:u|je)\s+(?:vragen|verzoeken)\b|\bwould it be possible\b|\b(?:ok|okay|oke|ok\u00e9|yes|right|goed|ja)\s*\?"
    r"|\b(?:ga|gaat)\s+(?:je|jij|u)\b|\bare you going to\b|\bwhat if you\b|\bwat als je\b"
    r"|\bhow about\b|\bwhat about\b|\bwhy (?:don't|dont|not)\b|\bplease\b|\balsjeblieft\b|\bgraag\b",
    re.IGNORECASE,
)
SENTENCE_BREAK_RE = re.compile(r"[.!?]")
# WHY: a bounded clause keeps one long request without punctuation from
# scanning the whole text for each filing verb.
CLAUSE_SPAN_CHARS = 200
FILING_DEADLINE_RE = re.compile(r"^\s*(?:deadline|date|datum|termijn)\b", re.IGNORECASE)
CLAUSE_BREAK_RE = re.compile(r"[,.;:!?]")
# WHY: a conjunction or a subordinator starts a new clause part, so the "niet"
# in "dien hem in en vergeet niet de bijlagen" and in "dien hem in als ik niet
# reageer" negates another verb.
CLAUSE_CONJUNCTION_RE = re.compile(
    r"\b(?:en|maar|of|zodat|want|omdat|terwijl|dan|als|zodra|nu|aangezien|tenzij|voordat|nadat|dat"
    r"|and|but|or|so|if|when|unless|because|since|before|after)\b"
)
# WHY: a Dutch separable verb puts its negation before the particle, as in
# "dien daarna mijn aangifte niet in", and "hand in nothing" negates the object.
POST_NEGATION_RE = re.compile(
    r"^(?:\s+\S+){0,4}?\s+(?:niet(?:\s+(?:in|op|af|aan))?|niets(?:\s+(?:in|op|af|aan))?|niks|nothing"
    r"|geen(?:\s+\S+){0,2}?(?:\s+(?:in|op|af|aan))?)(?:\s+(?:naar|bij|aan|to)\b[^,.;:!?]*)?\s*$",
    re.IGNORECASE,
)
# WHY: the direct object follows the verb with at most a separable particle and
# a few modifiers, so a preposition or a recipient before the object, as in
# "send me a summary of the VAT return", names another object.
GRAMMAR_PARTICLE_RE = re.compile(r"^\s*(?:in|op|af|aan|door)\b")
GRAMMAR_GAP_STOP_RE = re.compile(
    r"\b(?:of|van|for|from|uit|about|over|with|met|on|me|mij|us|ons|him|her|haar|een samenvatting|a summary)\b"
)
# WHY: a recipient that is no filing destination, as in "send it to the
# accountant", "stuur hem naar Jan", "file it in the archive folder" or "send it
# via email", names another receiver. A "to" before a verb, as in "file it to
# meet the deadline", states a purpose and names none.
GRAMMAR_RECIPIENT_RE = re.compile(
    r"\b(?:to\s+(?:(?:the|a|an|my|our|your|his|her|their|this|that)\s+\w+|(?:me|us|him|her|them)\b|\S*@|\w+['\u2019]s\b"
    r"|(?!(?:meet|avoid|make|get|be|keep|stay|prevent|ensure|comply|finish|save|beat|catch|hit|reach|do|have"
    r"|start|close|pay|file|submit|stop)\b)\w+(?:\s+\w+){0,3}\s*$)|(?:over|along|door|verder|terug)\s*$|(?:into|onto|naar|aan)\s+\S+|bij\s+\w+|(?:under|onder)\s+\w+"
    r"|(?:in)\s+(?:the|de|het|a|een|my|mijn|our|onze|map|folder)\b"
    r"|(?:via|by|per|as|als|through)\s+(?:an?\s+|the\s+)?(?:e-?mail|mail|post|pdf|attachment|bijlage|whatsapp|slack|teams|link|zip|csv|excel)\b"
    r"|ter\s+(?:controle|review|inzage|goedkeuring)\b|for\s+(?:review|approval|checking|a check|your review)\b"
    r"|here\b|back\b)[^,.;:!?]*"
)
# WHY: a negation or a second clause between a want, status or passive trigger
# and the filed state, as in "make sure it is not filed" or "markeer de aangifte
# als klaar en de facturen als verstuurd", sets no filing object to a filed state.
GRAMMAR_SPAN_STOP_RE = re.compile(
    r"\b(?:not|niet|geen|never|nooit|nothing|niets|niks|and|en|but|maar)\b|n['\u2019\u00b4`\u02bc]t\b"
)
# WHY: a quarter or a period followed by another noun, as in "betaal de Q3
# factuur" and "pay the period's rent", is no filing object.
PERIOD_FILLER = frozenset((
    "the", "het", "de", "een", "a", "an", "this", "that", "these", "those", "dit", "deze", "die", "my", "mijn", "our",
    "onze", "your", "jouw", "last", "previous", "vorig", "vorige", "laatste", "current", "huidige", "next", "volgend",
    "volgende", "whole", "hele", "complete", "gehele", "entire", "all", "alle", "first", "second", "third", "fourth",
    "eerste", "tweede", "derde", "vierde", "1st", "2nd", "3rd", "4th", "1e", "2e", "3e", "4e", "1de", "2de", "3de", "4de",
))
GRAMMAR_PERIOD_OBJECTS = ("period", "periode", "quarter", "kwartaal", "q1", "q2", "q3", "q4")
GRAMMAR_PERIOD_FOLLOW = (
    r"(?=\s*(?:$|[,.;:!?]|(?:in|op|af|aan|door|for|of|van|voor|over|from|to|met|with|as|als|bij|on|at|and|en"
    r"|then|dan|now|today|nu|vandaag|morgen|tomorrow|ook|too|please|graag|\d{4})\b))"
)
# WHY: "return" heads no filing object in a compound such as "return label".
GRAMMAR_RETURN_COMPOUND_RE = re.compile(
    r"^\s+(?:form|label|deposit|policy|shipment|request|flight|ticket|trip|journey|address|package|parcel"
    r"|item|items|order|slip|value|email|mail)\b"
)
# WHY: "stuur hem als PDF" names a format, and "als" also starts a clause, so
# the format is read past the clause cut.
GRAMMAR_CHANNEL_RE = re.compile(
    r"^[^,.;:!?]*?\b(?:als|as)\s+(?:an?\s+|een\s+)?(?:pdf|bijlage|attachment|e-?mail|csv|excel|zip)\b"
)
GRAMMAR_SERVICE_RE = re.compile(
    r"^\s+(?:helpdesk|help desk|support|klantenservice|customer service|chat|website|site|newsletter|nieuwsbrief)\b"
)
# WHY: a verb at the start of its clause gives an order, so "file the VAT
# return, ok?" asks to file however the sentence ends.
GRAMMAR_LEAD_RE = re.compile(r"^\s*(?:(?:please|now|just|so|then|ok|okay|gewoon|even|nu|dus|graag)\s+)*$")
GRAMMAR_LABELS = {
    "filing verbs": "verbs",
    "verb-final forms": "finals",
    "filing objects": "objects",
    "object pronouns": "pronouns",
    "filing destinations": "destinations",
    "status verbs": "status",
    "want verbs": "want",
    "filed states": "states",
}
GRAMMAR_HEADING_RE = re.compile(r"^## \d+\. FILING GRAMMAR\s*$", re.M)
# WHY: a tool name is no task signal, so "jortt-cli" scores no point for the
# migration signal Jortt.
TOOL_NAME_RE = re.compile(
    r"(?<!\w)(?:jortt[- ]cli|cli[- ]jortt|cli[- ]moneybird|moneybird[- ]guard|moneybird[- ]cli)(?!\w)",
    re.IGNORECASE,
)
JORTT_TOOL_RE = re.compile(r"(?<!\w)(?:jortt[- ]cli|cli[- ]jortt)(?!\w)", re.IGNORECASE)
# WHY: a move verb next to a CLI name moves records between the systems, and a
# write verb next to the Jortt CLI asks for a Jortt write.
MIGRATION_VERB_RE = re.compile(
    r"\b(?:migrat\w*|migreer\w*|move|moving|copy|copies|copying|import\w*|transfer\w*|push\w*|book|boek"
    r"|overzet\w*|verplaats\w*|kopieer\w*|kopi[e\u00eb]ren|across|new (?:administration|system)"
    r"|nieuwe (?:administratie|systeem))\b"
    r"|\bzet\w*\s+(?:\S+\s+){0,5}?over\b(?!\s+\d)",
    re.IGNORECASE,
)
JORTT_WRITE_RE = re.compile(
    r"(?<![\w-])(?:write|update|delete|edit|change|create|remove|add|modify|cancel|post|approve|schrijf\w*"
    r"|wijzig\w*|verwijder\w*|bewerk\w*|aanmaken|aan te maken|toevoegen|toe te voegen|voeg|annuleer\w*"
    r"|keur\w*)(?![\w-])",
    re.IGNORECASE,
)
# WHY: a write verb with a local output, as in "write the summary to a file",
# or a write word used as a noun, as in "the change history" or "the latest
# update", writes nothing to Jortt.
JORTT_LOCAL_OUTPUT_RE = re.compile(
    r"^(?:\s+\S+){0,3}?\s+(?:summary|samenvatting|file|bestand|report|rapport|csv|overview|overzicht|note|notes"
    r"|notitie|list|lijst|table|tabel)\b"
    r"|^\s+(?:history|log|logboek|geschiedenis|date|datum)\b",
    re.IGNORECASE,
)
JORTT_WRITE_NOUN_RE = re.compile(r"\b(?:the|a|an|de|het|een|latest|last|recent|laatste)\s*$", re.IGNORECASE)
MONEYBIRD_NAME_RE = re.compile(r"(?<!\w)moneybird(?!\w)", re.IGNORECASE)
# WHY: "edit nothing" and "wijzig niets" name a write only to rule it out.
JORTT_WRITE_NEGATED_RE = re.compile(r"^\s+(?:nothing|anything|niets|niks)\b", re.IGNORECASE)

INVOICE_RE = re.compile(r"\b(inkoopfactuur|bonnetje|invoice|receipt|supplier|leverancier)\b", re.IGNORECASE)
GATE_RE = re.compile(r"\b(gate|poort)\b", re.IGNORECASE)
CANCEL_RE = re.compile(r"(?<!\w)(?:cancel|opzeg|opgezeg)", re.IGNORECASE)
JORTT_OP_RE = re.compile(r"\bjortt\b[^.]*\bop\b", re.IGNORECASE)

SOURCE_TERMS = ("official text", "officiële tekst", "officiele tekst", "source library", "law text", "wetstekst")

# WHY: a term request names the Dutch term inside an ask frame, so a request
# that only answers in English or asks what a figure means reads no glossary.
# A frame's `t` group holds the words that must start with a Dutch glossary
# term, or for the "in English" frames must be that term and nothing more.
# WHY: a bounded span keeps one long request from scanning far past the ask words.
GLOSSARY_SPAN_CHARS = 80
GLOSSARY_SPAN = "[^?.!]{1,%d}" % GLOSSARY_SPAN_CHARS
GLOSSARY_CLAUSE = "[^?.!,:;]{1,%d}" % GLOSSARY_SPAN_CHARS
GLOSSARY_FRAMES = (
    re.compile(r"\bwhat does (?P<t>" + GLOSSARY_SPAN + r"?) (?:mean|stand for)\b"),
    re.compile(r"\bwhat is the meaning of (?P<t>" + GLOSSARY_SPAN + r")"),
    re.compile(r"\benglish (?:name|term|word) (?:for|of) (?P<t>" + GLOSSARY_SPAN + r")"),
    re.compile(r"\btranslate (?P<t>" + GLOSSARY_SPAN + r")"),
    re.compile(r"\bwat betekent (?P<t>" + GLOSSARY_SPAN + r")"),
    re.compile(r"\bbetekenis van (?P<t>" + GLOSSARY_SPAN + r")"),
    re.compile(r"\bengelse (?:naam|term|woord) (?:van|voor) (?P<t>" + GLOSSARY_SPAN + r")"),
    re.compile(r"\bhoe heet (?P<t>" + GLOSSARY_SPAN + r"?) in het engels\b"),
)
GLOSSARY_END_FRAMES = (
    re.compile(r"(?:^|[,:;]\s*|\band\s+|\bis\s+)(?P<t>" + GLOSSARY_CLAUSE + r"?) in english\b"),
    re.compile(r"(?:^|[,:;]\s*|\ben\s+|\bis\s+)(?P<t>" + GLOSSARY_CLAUSE + r"?) in het engels\b"),
)
GLOSSARY_LEADING_WORDS = frozenset(("the", "a", "an", "de", "het", "een", "term", "word", "woord"))
# WHY: an "in English" clause may open on a joining or question word before the term it asks about.
GLOSSARY_END_LEADING_WORDS = GLOSSARY_LEADING_WORDS | frozenset(("and", "en", "what", "wat", "is"))
GLOSSARY_DIR = "references/glossary"
GLOSSARY_ROUTER = "references/glossary/README.md"
GLOSSARY_BOOKKEEPING = "references/glossary/bookkeeping.md"
GLOSSARY_GENERAL = "references/glossary/general.md"
GLOSSARY_VAT = "references/glossary/vat.md"
GLOSSARY_YEAR_RE = re.compile(r"^references/tax-rules/\d{4}/([a-z0-9-]+)/")
GLOSSARY_ROW_RE = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|[^|]*\|\s*$")
# WHY: a general topic file restates the year topics it covers, so it shares their glossaries.
GLOSSARY_GENERAL_TOPICS = {
    "box-2-and-the-substantial-interest.md": ("box-2",),
    "box-3-savings-and-investments.md": ("box-3",),
    "business-deductions-and-sme-profit-exemption.md": ("business-deductions",),
    "costs-and-the-car.md": ("costs-and-car",),
    "income-tax-box-1-and-the-health-insurance-contribution.md": ("income-tax", "health-insurance-contribution"),
    "investment-deductions-and-depreciation.md": ("investments",),
    "pension-annuities-and-disability-insurance.md": ("pension-and-disability-insurance",),
    "the-private-company-and-corporate-tax.md": ("private-company-and-corporate-tax",),
    "vat.md": ("vat",),
    "work-relationship-and-procedure.md": ("work-relationship", "procedure"),
}

# WHY: the yearly-overview README authors these ten close signals, so the
# T11 row carries them and the resolver loads the year README on a close
# request. route-replay-test.sh fails when one is missing from the T11 cells.
CLOSE_SIGNALS = (
    "jaaroverzicht",
    "jaarrekening",
    "jaarafsluiting",
    "eindejaar",
    "balans opmaken",
    "winst-en-verliesrekening",
    "overlopende posten",
    "vooruitbetaalde kosten",
    "toerekenen",
    "privé-opnamen",
)

# WHY: the additive row names the sibling skill it appends, so an answer
# says which tool owns the read and a refused request stays blocked.
JORTT_DESTINATION_TERMS = ("jortt", "jortt-cli", "cli-jortt", "read jortt", "haal op")
MONEYBIRD_DESTINATION_TERMS = ("moneybird", "moneybird-guard", "cli-moneybird", "boek in", "synchroniseer")

# WHY: routing-signals.md section 4 documents one clause per tie pair, so
# the resolver, the corpus tie list and the prose must name the same pairs.
SPECIFICITY_PAIRS = (
    ("T4", "T3"),
    ("T4", "T2"),
    ("T5", "T6"),
    ("T5", "T4"),
    ("T6", "T4"),
    ("T1", "T2"),
    ("T1", "T3"),
    ("T1", "T4"),
    ("T10", "T3"),
    ("T11", "T3"),
    ("T12", "T5"),
)

FOLD_RE = re.compile(r"[-\s]+")
SIGNAL_SEPARATOR_RE = re.compile(r"[-\s]+")
MONITORING_TERMS = ("monitoring", "post-cutover", "post cutover", "monitoring_active", "monitoring_lapsed_phase22_open")
VAT_TERMS = ("btw", "vat", "quarter", "kwartaal")
ACCESS_TERMS = ("trial", "access window", "proefperiode", "auditfile", "read-only", "read only", "read_only", "lock", "workspace", "setup")

# WHY: the T4 read set carries two conditional references, so the resolver
# keeps the table's mixed-use and asset signal families to decide whether a
# winning T4 request also loads them. route-replay-test.sh fails when a term
# here is missing from the T4 signal cells.
MIXED_USE_TERMS = (
    "privégebruik",
    "zakelijk en privé",
    "deels privé",
    "gemengde kosten",
    "telefoonabonnement",
    "private use",
    "partly private",
    "mixed use",
    "phone subscription",
)
FIXED_ASSET_TERMS = (
    "afschrijven",
    "afschrijving",
    "inventaris",
    "activeren",
    "activeer",
    "depreciation",
    "depreciate",
    "fixed asset",
    "capitalise",
    "capitalize",
)
# These terms name what is booked, not the kind of request, so together they
# add one point to T4 at most. Otherwise a tax figure or rule question that
# names an asset twice outscores T5 or T6 before the tie clauses can apply.
T4_TOPIC_TERMS = MIXED_USE_TERMS + FIXED_ASSET_TERMS

# WHY: stage one sets the CLI signals and the system names aside before it asks
# whether a request holds an accountant task, so "my Jortt customers with
# jortt-cli" names a CLI operation and nothing else, not a migration.
HUB_SYSTEM_NAMES = ("jortt", "moneybird")
TOOL_ROUTE_SPLIT_RE = re.compile(r"\s*\+\s*")

TOPIC_SIGNALS = (
    (("kilometer", "mileage", "auto", "car", "thuiswerk", "home office", "kosten", "costs", "study", "studie"), "costs-and-car"),
    (("zelfstandigenaftrek", "ondernemersaftrek", "urencriterium", "mkb", "startersaftrek"), "business-deductions"),
    (("btw", "vat", "tarief", "rate", "voorbelasting", "kor", "kleineondernemersregeling"), "vat"),
    (("box 3", "box3", "heffingsvrij", "vermogen", "savings"), "box-3"),
    (("box 2", "aanmerkelijk belang", "gebruikelijk loon"), "box-2"),
    (("vennootschapsbelasting", "vpb", "bv "), "private-company-and-corporate-tax"),
    (("pensioen", "lijfrente", "jaarruimte", "aov"), "pension-and-disability-insurance"),
    (("arbeidsrelatie", "dba", "opdracht", "loondienst"), "work-relationship"),
    (("investering", "kleinschaligheidsinvesteringsaftrek", "kia", "eia", "mia", "afschrijving"), "investments"),
    (("zvw",), "health-insurance-contribution"),
    (("bewaarplicht", "deadline", "aangifte", "bezwaar", "procedure"), "procedure"),
    (("box 1", "inkomstenbelasting", "heffingskorting"), "income-tax"),
)

# ───────────────────────────────────────────────────────────────
# 3. HELPERS
# ───────────────────────────────────────────────────────────────

def fail(message: str) -> NoReturn:
    """Print an error and stop with exit code 2.

    Args:
        message: Error text for stderr.

    Raises:
        SystemExit: Always, with code 2.
    """
    print("%s: %s" % (PROGRAM, message), file=sys.stderr)
    sys.exit(2)


def read_text(path: str) -> str:
    """Read one file as UTF-8 text.

    Args:
        path: File to read.

    Returns:
        The file text.

    Raises:
        SystemExit: When the file cannot be read.
    """
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return handle.read()
    except OSError as exc:
        fail("cannot read %s: %s" % (os.path.basename(path), exc))


def join_skill(skill_root: str, relative: str) -> str:
    """Return one path under the skill folder.

    Args:
        skill_root: Absolute skill folder.
        relative: Path relative to that folder.

    Returns:
        The joined path.
    """
    return os.path.join(skill_root, relative.replace("/", os.sep))


def strip_anchor(path: str) -> str:
    """Return the file part of one path address.

    Args:
        path: Path that may carry a #anchor suffix.

    Returns:
        The path without the suffix.
    """
    return path.split("#", 1)[0]


def plain_path(address: str) -> str:
    """Return the file part of one read-set address.

    The table grammar writes an anchor as `@section`, the resolved read set
    as `#section`, so both separators are stripped.

    Args:
        address: Path with an optional @anchor or #anchor suffix.

    Returns:
        The path without the suffix.
    """
    return strip_anchor(address.replace("@", "#"))


def read_set_items(cell: str) -> List[Tuple[str, str]]:
    """Read the marked items of one read-set cell.

    Args:
        cell: Raw read-set cell text.

    Returns:
        One (mark, item) pair per backticked item, with the mark `!` or `?`
        and the item text after the mark, anchor included.
    """
    items: List[Tuple[str, str]] = []
    for span in BACKTICK_RE.findall(cell):
        span = span.strip()
        if not span or span == "-" or span[0] not in "!?":
            continue
        item = span[1:].strip()
        if item:
            items.append((span[0], item))
    return items


def year_folders(skill_root: str) -> List[str]:
    """List the four-digit year folders under the tax-rules folder.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        Sorted folder names such as 2020.
    """
    base = join_skill(skill_root, "references/tax-rules")
    if not os.path.isdir(base):
        return []
    return sorted(
        name
        for name in os.listdir(base)
        if YEAR_FOLDER_RE.fullmatch(name) and os.path.isdir(os.path.join(base, name))
    )


def expand_read_item(
    item: str,
    years: Sequence[str],
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
) -> List[str]:
    """Expand the map tokens and the year token of one read item.

    Args:
        item: Read item text after its mark, with the anchor attached.
        years: Year folders to expand the year token over.
        phase_map: Phase number to phase file from the generated block.
        topic_map: Topic slug to figures file from the generated block.

    Returns:
        The expansion in map and year order, or the item itself when it
        carries no token.
    """
    items = [item]
    if PHASE_PLACEHOLDER in item:
        items = [part.replace(PHASE_PLACEHOLDER, value) for part in items for value in phase_map.values()]
    if TOPIC_PLACEHOLDER in item:
        items = [part.replace(TOPIC_PLACEHOLDER, value) for part in items for value in topic_map.values()]
    expanded: List[str] = []
    for part in items:
        if YEAR_TOKEN in part:
            expanded.extend(part.replace(YEAR_TOKEN, year) for year in years)
        else:
            expanded.append(part)
    return expanded


def split_cells(line: str) -> List[str]:
    """Split a markdown table line into stripped cells.

    Args:
        line: One table line with leading and trailing pipes.

    Returns:
        The cell texts without their surrounding whitespace.
    """
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def signal_phrases(cell: str) -> List[str]:
    """Return the signal phrases of one table cell.

    A cell with backticked spans uses those spans. A plain prose cell is
    split on commas.

    Args:
        cell: Raw Dutch or English signal cell.

    Returns:
        The phrases in file order.
    """
    spans = BACKTICK_RE.findall(cell)
    if spans:
        return [span.strip() for span in spans if span.strip()]
    return [part.strip() for part in cell.split(",") if part.strip()]


def fold_text(text: str) -> str:
    """Fold hyphens and whitespace runs to one space for signal matching.

    Args:
        text: Request text or signal phrase.

    Returns:
        Lower case text with each hyphen and whitespace run as one space.
    """
    return FOLD_RE.sub(" ", text.lower())


def signal_pattern(phrase: str) -> str:
    """Build the match pattern of one signal phrase.

    A hyphen or a space in the phrase matches a space in the text, so
    `btw-aangifte` matches `btw aangifte`. A space in the phrase stays a
    space, so `reverse charge` does not match `reverse-charged`.

    Args:
        phrase: Signal phrase.

    Returns:
        The regular expression body of the phrase.
    """
    parts: List[str] = []
    last = 0
    for match in SIGNAL_SEPARATOR_RE.finditer(phrase):
        parts.append(re.escape(phrase[last:match.start()].lower()))
        parts.append(r"[-\s]+" if "-" in match.group(0) else r"\s+")
        last = match.end()
    parts.append(re.escape(phrase[last:].lower()))
    return "".join(parts)


def phrase_matches(text: str, phrase: str) -> bool:
    """Tell whether a signal phrase starts a word in one text.

    Matching folds a hyphen and a space, so `btw aangifte` equals
    `btw-aangifte`. The phrase needs a non-word character before it and may
    run on into a compound or an inflection, so `inkoopfactuur` stays one
    match and `partly private` stays a match inside `partly privately`.

    Args:
        text: Lower case request text.
        phrase: Signal phrase.

    Returns:
        True when the phrase starts a word in the text.
    """
    pattern = r"(?<!\w)" + signal_pattern(phrase)
    return re.search(pattern, text.lower()) is not None


def is_replay_row(row: Dict[str, Any]) -> bool:
    """Tell whether a corpus row is scored by the replay mode.

    Args:
        row: One corpus row.

    Returns:
        True when the row carries an expected_exit code.
    """
    return "expected_exit" in row


def select_rows(rows: List[Dict[str, Any]], covers: Sequence[str], mode: str) -> List[Dict[str, Any]]:
    """Select the rows one mode scores and one covers filter keeps.

    Args:
        rows: Corpus rows in file order.
        covers: Phase and requirement tags to keep, empty means all.
        mode: resolve or replay.

    Returns:
        The selected rows in file order.
    """
    selected: List[Dict[str, Any]] = []
    for row in rows:
        replay = is_replay_row(row)
        if mode == "resolve" and replay:
            continue
        if mode == "replay" and not replay:
            continue
        if covers:
            tags = [str(tag) for tag in row.get("covers", [])]
            if not any(tag in tags for tag in covers):
                continue
        selected.append(row)
    return selected


def run_process(command: Sequence[str], env: Dict[str, str]) -> Tuple[int, str]:
    """Run one command and capture its merged output.

    Args:
        command: Command and arguments.
        env: Complete environment for the child process.

    Returns:
        The exit code and the merged output text.

    Raises:
        SystemExit: When the command cannot be started at all.
    """
    try:
        completed = subprocess.run(
            list(command),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=120,
        )
    except OSError as exc:
        fail("cannot run %s: %s" % (command[0], exc))
    except subprocess.SubprocessError as exc:
        fail("command failed to finish: %s" % exc)
    return completed.returncode, completed.stdout.decode("utf-8", "replace")


def parse_preview(output: str) -> Tuple[str, str]:
    """Read the dry-run line and the payload digest out of guard output.

    Args:
        output: Merged stdout and stderr of one guard run.

    Returns:
        The METHOD URL line and the digest, either one empty when absent.
    """
    dry_line = ""
    digest = ""
    for line in output.splitlines():
        stripped = line.strip()
        if not dry_line and re.match(r"^[A-Z]+ https?://", stripped):
            dry_line = stripped
        match = re.match(r"^payload-digest: ([0-9a-f]{64})$", stripped)
        if match:
            digest = match.group(1)
    return dry_line, digest


def flip_digest(digest: str) -> str:
    """Return a digest that cannot match the given one.

    Args:
        digest: Hex digest, empty when the guard cannot print one.

    Returns:
        A changed digest of the same length.
    """
    if not digest:
        return "0" * 64
    last = "0" if digest[-1] != "0" else "1"
    return digest[:-1] + last

# ───────────────────────────────────────────────────────────────
# 4. ROUTER SNAPSHOT
# ───────────────────────────────────────────────────────────────

def parse_route_table(text: str) -> List[Dict[str, str]]:
    """Parse the task-type table between its markers.

    Args:
        text: Routing markdown text.

    Returns:
        One row per task type with its cells.

    Raises:
        SystemExit: When a marker or a row is missing.
    """
    lines = text.splitlines()
    try:
        start = lines.index(START_MARKER)
        end = lines.index(END_MARKER, start + 1)
    except ValueError:
        fail("route table markers missing in the routing markdown")
    rows: List[Dict[str, str]] = []
    for line in lines[start + 1:end]:
        stripped = line.strip()
        match = ROW_RE.match(stripped)
        if not match:
            continue
        cells = split_cells(stripped)
        if len(cells) != 8:
            fail("route row %s has %d cells, expected 8" % (match.group(1), len(cells)))
        rows.append(
            {
                "type": cells[0],
                "name": cells[1],
                "dutch": cells[2],
                "english": cells[3],
                "tool_route": cells[4],
                "read_set": cells[5],
                "budget": cells[6],
                "on_tie": cells[7],
            }
        )
    if not rows:
        fail("route table holds no rows in the routing markdown")
    return rows


def parse_constants(skill_text: str, signals_text: str) -> Dict[str, Any]:
    """Read the routing constants out of the skill prose.

    The table in the routing markdown is the single source of truth for the frozen
    floor. The signal file still carries the warning band, and the pending
    marker in the table applies while the table states no number.

    Args:
        skill_text: Routing markdown text.
        signals_text: routing-signals.md text.

    Returns:
        The margin, the warning band and the fallback floor state.
    """
    margin = 0.25
    match = re.search(r"ROUTE_MARGIN\s*=\s*([0-9.]+)", skill_text)
    if match:
        margin = float(match.group(1))
    warning = 0.08
    match = re.search(r"([0-9.]+)\s*warning band", signals_text)
    if match:
        warning = float(match.group(1))
    floor: Optional[float] = None
    pending = False
    match = re.search(r"FALLBACK_FLOOR[^\n]*?([0-9]+(?:\.[0-9]+)?)", skill_text)
    if match:
        floor = float(match.group(1))
    else:
        pending = "calibration: pending" in skill_text
        floor = 0.0
    return {
        "route_margin": margin,
        "warning_band": warning,
        "fallback_floor": floor,
        "fallback_floor_pending": pending,
    }


def parse_migration_index(text: str) -> Dict[str, str]:
    """Read the phase map out of the migration index.

    The generated block in the routing markdown is the map the scorer uses. This parse
    exists only to prove the block and the authored index still agree.

    Args:
        text: Migration index text.

    Returns:
        Mapping of phase number to its reference path.
    """
    mapping: Dict[str, str] = {}
    for line in text.splitlines():
        match = PHASE_ROW_RE.match(line.strip())
        if not match:
            continue
        mapping[match.group(1)] = "references/migration/" + match.group(2)
    return mapping


def parse_generated_map(text: str, name: str) -> Dict[str, str]:
    """Read one generated map out of the router block.

    Args:
        text: Routing markdown text.
        name: Generated map name, such as PHASE_FILES.

    Returns:
        The mapping, string to string.

    Raises:
        SystemExit: When the markers, the map or a value is malformed.
    """
    if ROUTER_START not in text or ROUTER_END not in text:
        fail("router block markers missing in the routing markdown")
    pattern = re.compile(r"^%s = \{$" % re.escape(name), re.MULTILINE)
    match = pattern.search(text)
    if not match:
        fail("generated router block is missing %s" % name)
    stop = text.find("\n}", match.end())
    if stop == -1:
        fail("generated %s has no closing brace" % name)
    literal = text[match.start():stop + 2]
    try:
        value = ast.literal_eval(literal[literal.index("{"):])
    except (SyntaxError, ValueError):
        fail("generated %s is not a literal map" % name)
    if not isinstance(value, dict) or any(
        not isinstance(key, str) or not isinstance(item, str) for key, item in value.items()
    ):
        fail("generated %s must map strings to strings" % name)
    return dict(value)


def parse_weak_signals(signals_text: str) -> Tuple[str, ...]:
    """Read the weak signal terms out of the signal reference.

    The reference names a term as a weak signal, so only the backticked
    spans before the words weak signal on that line count.

    Args:
        signals_text: routing-signals.md text.

    Returns:
        The weak signal phrases in file order.

    Raises:
        SystemExit: When the file names none.
    """
    for line in signals_text.splitlines():
        index = line.lower().find("weak signal")
        if index == -1:
            continue
        spans = [span.strip() for span in BACKTICK_RE.findall(line[:index]) if span.strip()]
        if spans:
            return tuple(fold_text(span) for span in spans)
    fail("no weak signal named in %s" % os.path.basename(SIGNALS_NAME))


def check_phase_agreement(skill_root: str, phase_map: Dict[str, str]) -> None:
    """Prove the generated phase map still matches the migration index.

    Args:
        skill_root: Absolute skill folder.
        phase_map: Phase map read from the generated router block.

    Raises:
        SystemExit: When the two disagree.
    """
    index_path = join_skill(skill_root, MIGRATION_INDEX)
    if not os.path.isfile(index_path):
        return
    index_map = parse_migration_index(read_text(index_path))
    if index_map == phase_map:
        return
    detail = ""
    keys = sorted(set(index_map) | set(phase_map), key=lambda value: int(value))
    for key in keys:
        if index_map.get(key) != phase_map.get(key):
            detail = " (phase %s: %s in the block, %s in the index)" % (
                key,
                phase_map.get(key, "missing"),
                index_map.get(key, "missing"),
            )
            break
    fail("constants disagree: PHASE_FILES does not match references/migration/README.md%s" % detail)


def parse_toc_ranges(text: str) -> Dict[str, Tuple[int, int]]:
    """Read the generated section list of one reference file.

    The list carries H3 subsections with their line ranges, which the
    reference index does not hold.

    Args:
        text: Reference file text.

    Returns:
        Mapping of anchor to the first and last line of the subsection.
    """
    ranges: Dict[str, Tuple[int, int]] = {}
    inside = False
    for line in text.splitlines():
        if line.strip() == TOC_START:
            inside = True
            continue
        if line.strip() == TOC_END:
            break
        if not inside:
            continue
        match = TOC_LINE_RE.match(line.strip())
        if not match:
            continue
        label = match.group(1).strip()
        anchor = re.sub(r"[^\w\s-]", "", label.lower(), flags=re.UNICODE)
        anchor = re.sub(r"\s+", "-", anchor.strip())
        ranges[anchor] = (int(match.group(2)), int(match.group(3)))
    return ranges


def reference_files(skill_root: str) -> List[str]:
    """List every markdown file under the references root.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        Paths relative to the skill folder, sorted.
    """
    base = join_skill(skill_root, "references")
    found: List[str] = []
    for directory, _, names in os.walk(base):
        for name in names:
            if name.endswith(".md"):
                absolute = os.path.join(directory, name)
                found.append(os.path.relpath(absolute, skill_root).replace(os.sep, "/"))
    return sorted(found)


def load_resource_map(skill_root: str) -> List[str]:
    """Load the resource map of the references root.

    The generated index is the map. A missing or unreadable index falls back
    to the live file walk so a fixture copy still resolves.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        Reference paths relative to the skill folder, sorted.
    """
    index_path = join_skill(skill_root, REFERENCE_INDEX)
    if os.path.isfile(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as handle:
                data = json.load(handle)
            paths = [
                "references/" + item["path"]
                for item in data.get("files", [])
                if isinstance(item, dict) and item.get("path")
            ]
            if paths:
                return sorted(paths)
        except (OSError, ValueError):
            pass
    return reference_files(skill_root)


def build_snapshot(
    route_rows: List[Dict[str, str]],
    constants: Dict[str, Any],
    phase_map: Dict[str, str],
    resources: List[str],
) -> Tuple[Dict[str, Any], str]:
    """Build the frozen router snapshot and its content hash.

    The snapshot holds relative paths and table text only, so time,
    environment and absolute paths cannot reach the hash.

    Args:
        route_rows: Parsed task-type rows.
        constants: Routing constants.
        phase_map: Phase number to reference path.
        resources: Reference paths from the resource map.

    Returns:
        The snapshot and its sha256 hex digest.
    """
    snapshot = {
        "route_rows": route_rows,
        "constants": constants,
        "phase_map": phase_map,
        "resources": resources,
        "specificity_clauses": [
            "an invoice named makes T4 beat T3",
            "one year named makes T5 beat T6",
            "a phase number or gate named makes T1 beat T2",
            "a phase number or gate named makes T1 beat T3",
            "a request for the official source text makes T5 beat T4",
            "T7 is additive and never wins alone",
            "a named VAT return makes T10 beat T3",
            "a named yearly overview makes T11 beat T3",
            "a named income tax return makes T12 beat T5",
        ],
        "fallback_tiers": {
            "A": "refuse with the out-of-scope boundary, load nothing",
            "B": "ask one question, print the candidate route per answer",
            "C": "name the missing tax year, resolve it before loading",
        },
    }
    canonical = json.dumps(snapshot, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    digest = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    return snapshot, digest


def routed_paths(
    route_rows: List[Dict[str, str]],
    skill_root: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
) -> Tuple[List[str], List[str]]:
    """Read the marked read paths of the route table.

    A year token expands over the year folders under the tax-rules folder,
    a map token expands over the generated map, an anchor is stripped and a
    dash cell holds no path.

    Args:
        route_rows: Parsed task-type rows.
        skill_root: Absolute skill folder.
        phase_map: Phase number to phase file from the generated block.
        topic_map: Topic slug to figures file from the generated block.

    Returns:
        Two sorted path lists, the required reads and the conditional
        reads, relative to the skill folder.
    """
    years = year_folders(skill_root)
    required: List[str] = []
    conditional: List[str] = []
    for row in route_rows:
        for mark, item in read_set_items(row["read_set"]):
            bucket = required if mark == "!" else conditional
            for address in expand_read_item(item, years, phase_map, topic_map):
                path = plain_path(address)
                if path and path not in bucket:
                    bucket.append(path)
    return sorted(required), sorted(conditional)

# ───────────────────────────────────────────────────────────────
# 5. CONNECTIVITY GATE
# ───────────────────────────────────────────────────────────────

def connectivity_report(skill_root: str, rows: List[Dict[str, Any]], required: Sequence[str]) -> List[str]:
    """List every required routed path that does not exist on disk.

    A conditional read is never passed here, so a `?` path that does not
    exist is not a connectivity failure.

    Args:
        skill_root: Absolute skill folder.
        rows: Corpus rows.
        required: Required paths named by the route table.

    Returns:
        One message per missing path, relative to the skill folder.
    """
    wanted = list(required)
    for row in rows:
        wanted.extend(str(path) for path in row.get("expected_paths", []))
    missing: List[str] = []
    seen: Dict[str, bool] = {}
    for address in wanted:
        path = plain_path(address)
        if path in seen:
            continue
        seen[path] = True
        if not os.path.isfile(join_skill(skill_root, path)):
            missing.append("missing routed path: %s" % path)
    return sorted(missing)

# ───────────────────────────────────────────────────────────────
# 6. ENCODING CACHE PIN
# ───────────────────────────────────────────────────────────────

def open_encoder(baseline_root: str) -> Any:
    """Load the pinned lead encoding through the token baseline helpers.

    Args:
        baseline_root: Skill folder that holds scripts/token-baseline.py.

    Returns:
        The o200k_base encoder.

    Raises:
        SystemExit: When the helper, the cache folder or the pin is missing.
    """
    helper = join_skill(baseline_root, BASELINE_HELPER)
    if not os.path.isfile(helper):
        fail("missing token baseline helper: %s" % BASELINE_HELPER)
    spec = importlib.util.spec_from_file_location("route_replay_token_baseline", helper)
    if spec is None or spec.loader is None:
        fail("cannot load token baseline helper: %s" % BASELINE_HELPER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    def token_fail(message: str) -> NoReturn:
        fail(message)

    module.fail = token_fail
    directory = module.cache_dir()
    module.check_cache(directory)
    encoders = module.load_encoders()
    return encoders[module.LEAD_ENCODING]

# ───────────────────────────────────────────────────────────────
# 7. ROUTE RESOLUTION
# ───────────────────────────────────────────────────────────────

def glossary_files(path: str) -> List[str]:
    """Name the glossary files that hold the terms of one read.

    Args:
        path: A read path relative to the skill folder, anchor removed.

    Returns:
        The glossary file paths relative to the skill folder.
    """
    match = GLOSSARY_YEAR_RE.match(path)
    if match:
        return ["%s/%s.md" % (GLOSSARY_DIR, match.group(1))]
    if path.startswith("references/tax-rules/general/"):
        topics = GLOSSARY_GENERAL_TOPICS.get(os.path.basename(path), ())
        return ["%s/%s.md" % (GLOSSARY_DIR, topic) for topic in topics] or [GLOSSARY_GENERAL]
    if path.startswith("references/tax-rules/"):
        return [GLOSSARY_GENERAL]
    if path.startswith("references/vat-return/"):
        return [GLOSSARY_VAT]
    return [GLOSSARY_BOOKKEEPING]


_GLOSSARY_INDEX: Dict[str, Dict[str, str]] = {}


def glossary_index(skill_root: str) -> Dict[str, str]:
    """Map every Dutch glossary term to the category file that holds it.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        Lower case Dutch term to the glossary files that hold it, read once
        per folder.
    """
    if skill_root in _GLOSSARY_INDEX:
        return _GLOSSARY_INDEX[skill_root]
    index: Dict[str, List[str]] = {}
    folder = join_skill(skill_root, GLOSSARY_DIR)
    names = sorted(os.listdir(folder)) if os.path.isdir(folder) else []
    for name in names:
        if not name.endswith(".md") or name == "README.md":
            continue
        relative = "%s/%s" % (GLOSSARY_DIR, name)
        with open(os.path.join(folder, name), encoding="utf-8") as handle:
            for line in handle:
                match = GLOSSARY_ROW_RE.match(line.strip())
                if not match or match.group(1).lower() == "english" or set(match.group(1)) <= set("-: "):
                    continue
                files = index.setdefault(match.group(2).lower(), [])
                if relative not in files:
                    files.append(relative)
    _GLOSSARY_INDEX[skill_root] = index
    return index


def glossary_term(words: str, index: Dict[str, List[str]], at_end: bool) -> str:
    """Find the Dutch glossary term an ask frame names.

    Args:
        words: The words the frame captured, lower case.
        index: Dutch term to glossary files.
        at_end: True when the term must fill the words after an optional
            article, False when it must start them.

    Returns:
        The longest matching Dutch term, or an empty string.
    """
    # WHY: a comma, semicolon or colon ends the asked term, so the words after it never join a span.
    words = re.split(r"[,;:]", words, maxsplit=1)[0]
    parts = [part.strip("\"'`()") for part in words.split()]
    parts = [part for part in parts if part]
    leading = GLOSSARY_END_LEADING_WORDS if at_end else GLOSSARY_LEADING_WORDS
    while parts and parts[0] in leading:
        parts = parts[1:]
    best = ""
    sizes = [len(parts)] if at_end else range(1, min(len(parts), 6) + 1)
    for size in sizes:
        span = parts[:size]
        for joiner in (" ", "-"):
            candidate = joiner.join(span)
            if candidate in index and len(candidate) > len(best):
                best = candidate
    return best


def asked_terms(text: str, index: Dict[str, List[str]]) -> List[str]:
    """List the Dutch glossary terms a request asks about.

    Args:
        text: Lower case request text.
        index: Dutch term to glossary files.

    Returns:
        The named terms in request order, without repeats.
    """
    found: List[str] = []
    for frames, at_end in ((GLOSSARY_FRAMES, False), (GLOSSARY_END_FRAMES, True)):
        for frame in frames:
            for match in frame.finditer(text.lower()):
                term = glossary_term(match.group("t"), index, at_end)
                if term and term not in found:
                    found.append(term)
    return found


def glossary_reads(skill_root: str, paths: List[str], text: str) -> List[str]:
    """Add the glossary reads a term request asks for.

    Args:
        skill_root: Absolute skill folder.
        paths: The route's resolved reads, anchors in # form.
        text: Lower case request text.

    Returns:
        The reads, followed on a term request by the glossary router, the
        file that holds each named term and the glossary files of each read.
    """
    index = glossary_index(skill_root)
    terms = asked_terms(text, index)
    if not terms:
        return paths
    extended = list(paths)
    wanted = [GLOSSARY_ROUTER] + [path for term in terms for path in index[term]]
    for address in paths:
        wanted.extend(glossary_files(plain_path(address)))
    for path in wanted:
        if path not in extended:
            extended.append(path)
    return extended


def resolve_paths(
    skill_root: str,
    route_type: str,
    text: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
    route_rows: List[Dict[str, str]],
) -> List[str]:
    """Resolve the read set of one winning task type with its glossary reads.

    Args:
        skill_root: Absolute skill folder.
        route_type: Winning task type.
        text: Lower case request text.
        year: Fixture year for the read set, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.
        route_rows: Parsed task-type rows for the table-driven fallback.

    Returns:
        Reference paths relative to the skill folder.
    """
    paths = resolve_route_reads(
        skill_root, route_type, text, year, phase_map, topic_map, route_rows
    )
    return glossary_reads(skill_root, paths, text)


def resolve_route_reads(
    skill_root: str,
    route_type: str,
    text: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
    route_rows: List[Dict[str, str]],
) -> List[str]:
    """Resolve the read set of one winning task type.

    Args:
        skill_root: Absolute skill folder.
        route_type: Winning task type.
        text: Lower case request text.
        year: Fixture year for the read set, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.
        route_rows: Parsed task-type rows for the table-driven fallback.

    Returns:
        Reference paths relative to the skill folder.
    """
    if route_type == "T1":
        paths = [
            "references/migration/shared-mechanisms.md",
            "references/migration/control-framework.md",
        ]
        phases: List[str] = []
        for match in PHASE_RE.finditer(text):
            number = match.group(1)
            before = text[max(0, match.start() - 24):match.start()]
            after = text[match.end():match.end() + 16]
            if PASSED_RE.search(before) or re.match(r"\s+(gehaald|passed|afgerond|doorlopen)\b", after):
                number = str(int(number) + 1)
            phases.append(number)
        if CANCEL_RE.search(text) and "jortt" in text:
            phases.append("22")
        if JORTT_OP_RE.search(text):
            phases.append("22")
        for number in phases:
            phase_path = phase_map.get(number)
            if phase_path and phase_path not in paths:
                paths.append(phase_path)
        # The phase map reaches a named phase directly, so the migration
        # index is read only as the fallback when no phase is named.
        if not phases:
            paths.insert(0, "references/migration/README.md")
        if any(phrase_matches(text, term) for term in ACCESS_TERMS):
            setup = "references/migration/overview-and-setup.md"
            if setup not in paths:
                paths.append(setup)
        return paths
    if route_type == "T2":
        return ["references/migration/jortt-to-moneybird-mapping.md"]
    if route_type == "T3":
        paths = ["references/moneybird-bookkeeping.md"]
        if year:
            paths.append("references/tax-rules/%s/README.md" % year)
        if any(phrase_matches(text, term) for term in VAT_TERMS):
            if year:
                paths.append("references/tax-rules/%s/vat/figures.md" % year)
        if any(phrase_matches(text, term) for term in MONITORING_TERMS):
            paths.extend(["references/migration/README.md", "references/migration/phases-19-to-21.md"])
        return paths
    if route_type == "T4":
        paths = ["references/purchase-invoices.md"]
        if year:
            paths.extend(["references/tax-rules/%s/vat/figures.md" % year, "references/moneybird-bookkeeping.md"])
        if any(phrase_matches(text, term) for term in MIXED_USE_TERMS):
            paths.append("references/mixed-use-costs.md")
        if any(phrase_matches(text, term) for term in FIXED_ASSET_TERMS):
            paths.append("references/fixed-assets.md")
        return paths
    if route_type == "T5":
        source_hit = any(phrase_matches(text, term) for term in SOURCE_TERMS)
        figure_hit = t5_figure_hit(text, route_rows)
        if figure_hit and year:
            paths = ["references/tax-rules/%s/README.md" % year]
            topic = topic_file(text)
            target = topic_map.get(topic)
            if target:
                paths.append(target.replace(YEAR_TOKEN, year).replace("@", "#", 1))
            if source_hit:
                paths.append("references/tax-rules/source-library.md#2-how-to-reach-a-source")
            return paths
        if source_hit:
            return ["references/tax-rules/source-library.md#2-how-to-reach-a-source"]
        return []
    if route_type == "T6":
        return ["references/tax-rules/general/work-relationship-and-procedure.md#310-work-relationship-and-procedure"]
    if route_type == "T9":
        return ["references/migration/overview-and-setup.md"]
    return resolve_table_reads(route_rows, route_type, skill_root, year, phase_map, topic_map, text)


def resolve_table_reads(
    route_rows: List[Dict[str, str]],
    route_type: str,
    skill_root: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
    text: str,
) -> List[str]:
    """Resolve the reads of a row the fixed rules do not cover.

    The preparation rows carry their procedure README and figure reads as
    `!` items, so a required item always loads. A `?` item loads only when
    its condition terms match. The fixture year pins the year token, and
    the year folders pin it when the row carries no year.

    Args:
        route_rows: Parsed task-type rows.
        route_type: Winning task type.
        skill_root: Absolute skill folder.
        year: Fixture year, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.
        text: Lower case request text for the conditional reads.

    Returns:
        The expanded read addresses, anchors in # form.
    """
    row: Optional[Dict[str, str]] = None
    for item in route_rows:
        if item["type"] == route_type:
            row = item
            break
    if row is None:
        return []
    years = [year] if year else year_folders(skill_root)
    paths: List[str] = []
    for mark, item in read_set_items(row["read_set"]):
        if mark != "!":
            continue
        for address in expand_read_item(item, years, phase_map, topic_map):
            converted = address.replace("@", "#", 1)
            if converted and converted not in paths:
                paths.append(converted)
    # WHY: the preparation rows keep the source guide, the close year README
    # and the fixed-asset read conditional. A T11 route is a close route, so
    # it always reads the year file before a year figure.
    for mark, item in read_set_items(row["read_set"]):
        if mark != "?":
            continue
        for address in expand_read_item(item, years, phase_map, topic_map):
            converted = address.replace("@", "#", 1)
            if not converted or converted in paths:
                continue
            path = plain_path(converted)
            if path == "references/tax-rules/source-library.md" and any(
                phrase_matches(text, term) for term in SOURCE_TERMS
            ):
                paths.append(converted)
            elif path == "references/fixed-assets.md" and any(
                phrase_matches(text, term) for term in FIXED_ASSET_TERMS
            ):
                paths.append(converted)
            elif (
                route_type == "T11"
                and year
                and path == "references/tax-rules/%s/README.md" % year
            ):
                # WHY: the yearly-overview README makes the year file read
                # conditional on a close route, and every T11 route is one.
                paths.append(converted)
    return paths


def topic_file(text: str) -> str:
    """Pick the year topic folder named by a tax question.

    Args:
        text: Lower case request text.

    Returns:
        One topic folder name.
    """
    for terms, name in TOPIC_SIGNALS:
        for term in terms:
            if phrase_matches(text, term):
                return name
    return "costs-and-car"


def row_signal_hit(route_rows: List[Dict[str, str]], route_type: str, text: str) -> bool:
    """Tell whether one request names a row through its own signal cells.

    Args:
        route_rows: Parsed task-type rows.
        route_type: Task type whose signals to match.
        text: Lower case request text.

    Returns:
        True when one signal of that row matches the text.
    """
    for row in route_rows:
        if row["type"] != route_type:
            continue
        return any(
            phrase_matches(text, phrase)
            for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"])
        )
    return False


def t5_figure_hit(text: str, route_rows: List[Dict[str, str]]) -> bool:
    """Tell whether one request names a tax figure or topic.

    The source terms stay out of this test, so a source-only request reaches
    the source guide without the year README or a figures part.

    Args:
        text: Lower case request text.
        route_rows: Parsed task-type rows.

    Returns:
        True when one non-source T5 signal matches.
    """
    source = {fold_text(term) for term in SOURCE_TERMS}
    for row in route_rows:
        if row["type"] != "T5":
            continue
        for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"]):
            if fold_text(phrase) in source:
                continue
            if phrase_matches(text, phrase):
                return True
    return False


def specificity_winner(
    text: str,
    first: str,
    second: str,
    route_rows: List[Dict[str, str]],
) -> Optional[str]:
    """Apply the specificity clauses to one tied pair.

    Args:
        text: Lower case request text.
        first: One tied task type.
        second: The other tied task type.
        route_rows: Parsed task-type rows for the preparation clauses.

    Returns:
        The decided task type, or None when no clause covers the pair.
    """
    pair = {first, second}
    if pair == {"T4", "T3"} and INVOICE_RE.search(text):
        return "T4"
    if pair == {"T4", "T3"}:
        return "T3"
    if pair == {"T4", "T2"} and INVOICE_RE.search(text):
        return "T4"
    if pair == {"T5", "T6"} and YEAR_RE.search(text):
        return "T5"
    if pair == {"T6", "T4"}:
        return "T6"
    if pair == {"T5", "T4"}:
        # WHY: an invoice named keeps the invoice route, even when the
        # request also asks for the official source text.
        if INVOICE_RE.search(text):
            return "T4"
        return "T5"
    if pair == {"T1", "T2"} and (PHASE_RE.search(text) or GATE_RE.search(text)):
        return "T1"
    if pair == {"T1", "T3"} and (PHASE_RE.search(text) or GATE_RE.search(text)):
        return "T1"
    if pair == {"T1", "T4"} and (PHASE_RE.search(text) or GATE_RE.search(text)):
        return "T1"
    if pair == {"T10", "T3"}:
        return "T10" if row_signal_hit(route_rows, "T10", text) else "T3"
    if pair == {"T11", "T3"}:
        return "T11" if row_signal_hit(route_rows, "T11", text) else "T3"
    if pair == {"T12", "T5"}:
        return "T12" if row_signal_hit(route_rows, "T12", text) else "T5"
    return None


def jortt_write_named(text: str) -> bool:
    """Tell whether a request names a write it does not rule out.

    Args:
        text: Lower case request text.

    Returns:
        True when a write verb stands without a negation before it,
        without `nothing` or `niets` after it, without a local output such
        as a summary or a file and not as a noun.
    """
    for match in JORTT_WRITE_RE.finditer(text):
        before = text[max(0, match.start() - 32):match.start()]
        after = text[match.end():match.end() + 80]
        if TOOL_NEGATION_RE.search(before) or JORTT_WRITE_NEGATED_RE.search(after):
            continue
        if JORTT_LOCAL_OUTPUT_RE.match(after) or JORTT_WRITE_NOUN_RE.search(before):
            continue
        return True
    return False


def tool_negated(text: str, start: int) -> bool:
    """Tell whether a negation governs the tool name that starts at one index.

    Args:
        text: Lower case request text.
        start: Start of the tool name.

    Returns:
        True when a negation stands up to one word before the name and is no
        phrase such as `not only` that adds the tool.
    """
    window = text[max(0, start - 32):start]
    return TOOL_NEGATION_RE.search(window) is not None and NEGATION_EXEMPT_RE.search(window) is None


def mask_negated_tools(text: str) -> str:
    """Blank every tool name a negation governs.

    Args:
        text: Lower case request text.

    Returns:
        The text with each negated tool name replaced by a space, so
        "do not use jortt-cli" names no tool to hand off to.
    """
    spans = [
        match.span()
        for match in TOOL_NAME_RE.finditer(text)
        if tool_negated(text, match.start())
    ]
    for start, end in reversed(spans):
        text = text[:start] + " " + text[end:]
    return text


def scoring_text(text: str) -> str:
    """Return the text the task rows are scored on.

    A tool name scores no row. When the request names the Jortt CLI and
    neither Moneybird, a move verb, a phase number nor a write it does not
    rule out, the word Jortt names the source the CLI reads, not a
    migration, so it scores no row either.

    Args:
        text: Lower case request text.

    Returns:
        The text with the tool names, and with the Jortt CLI the system name
        Jortt, replaced by a space.
    """
    jortt_tool = JORTT_TOOL_RE.search(text) is not None
    text = TOOL_NAME_RE.sub(" ", text)
    moves = (
        MONEYBIRD_NAME_RE.search(text)
        or MIGRATION_VERB_RE.search(text)
        or PHASE_RE.search(text)
        or jortt_write_named(text)
    )
    if jortt_tool and not moves:
        text = re.sub(r"(?<!\w)jortt(?!\w)", " ", text)
    return text


def out_of_scope_hit(text: str) -> bool:
    """Tell whether a request names the out-of-scope boundary.

    A negated mention, as in `do not submit a return`, is not a hit.

    Args:
        text: Lower case request text.

    Returns:
        True when the boundary is named.
    """
    folded = fold_text(text)
    for pattern in OUT_OF_SCOPE_PATTERNS:
        match = re.search(pattern, text)
        if not match:
            continue
        boundary = BOUNDARY_SIGNAL_RE.search(fold_text(match.group(0))) is not None
        if not boundary:
            # WHY: a question, a frame or a user subject keeps the fallback
            # as it keeps a table signal.
            hit = re.search(pattern, folded)
            if hit and filing_clause_kept(folded, hit.start(), hit.end(), False):
                continue
        clause_start = text[:match.start()]
        breaks = list(CLAUSE_BREAK_RE.finditer(clause_start))
        before = (clause_start[breaks[-1].end():] if breaks else clause_start)[-48:]
        negation = BOUNDARY_NEGATION_RE if boundary else NEGATION_RE
        if negation.search(before) and not NEGATION_EXEMPT_RE.search(before):
            continue
        rest = text[match.end():]
        stop = CLAUSE_BREAK_RE.search(rest)
        after = rest[:stop.start()] if stop else rest
        joint = CLAUSE_CONJUNCTION_RE.search(after)
        if re.search(r"\b(?:niet|geen)\b", (after[:joint.start()] if joint else after)[:48]):
            continue
        return True
    return False


def t8_pattern(phrase: str) -> str:
    """Build the whole-word pattern of one refusal signal.

    Args:
        phrase: Refusal signal from the T8 row.

    Returns:
        The regular expression of the phrase on folded text.
    """
    return r"(?<!\w)" + re.escape(fold_text(phrase)) + r"(?!\w)"


def parse_filing_grammar(signals_text: str) -> Dict[str, Tuple[str, ...]]:
    """Read the filing grammar out of the signal reference.

    Args:
        signals_text: routing-signals.md text.

    Returns:
        Mapping of each grammar part to its folded terms, empty when the
        reference holds no filing grammar section.

    Raises:
        SystemExit: When the section exists but misses a part.
    """
    heading = GRAMMAR_HEADING_RE.search(signals_text)
    if heading is None:
        return {}
    body = signals_text[heading.end():]
    stop = re.search(r"^## ", body, re.M)
    body = body[:stop.start()] if stop else body
    grammar: Dict[str, Tuple[str, ...]] = {}
    for line in body.splitlines():
        match = re.match(r"^- ([A-Za-z -]+): (.+)$", line.strip())
        if match and match.group(1).lower() in GRAMMAR_LABELS:
            spans = [fold_text(span.strip()) for span in BACKTICK_RE.findall(match.group(2)) if span.strip()]
            grammar[GRAMMAR_LABELS[match.group(1).lower()]] = tuple(spans)
    missing = [label for label, key in GRAMMAR_LABELS.items() if not grammar.get(key)]
    if missing:
        fail("filing grammar in %s misses: %s" % (os.path.basename(SIGNALS_NAME), ", ".join(missing)))
    return grammar


_GRAMMAR_CACHE: Dict[str, Dict[str, Tuple[str, ...]]] = {}


def load_filing_grammar(skill_root: str) -> Dict[str, Tuple[str, ...]]:
    """Read the filing grammar of one skill folder once.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        The parsed grammar, empty when the reference has none.
    """
    if skill_root not in _GRAMMAR_CACHE:
        path = join_skill(skill_root, SIGNALS_NAME)
        text = read_text(path) if os.path.isfile(path) else ""
        _GRAMMAR_CACHE[skill_root] = parse_filing_grammar(text)
    return _GRAMMAR_CACHE[skill_root]


def term_pattern(terms: Sequence[str], plural: bool = False) -> str:
    """Build one whole-word alternation over folded terms.

    Args:
        terms: Folded terms.
        plural: True to let each term take a plural s.

    Returns:
        The regular expression body, longest term first.
    """
    ordered = sorted(terms, key=len, reverse=True)
    tail = r"s?(?!\w)" if plural else r"(?!\w)"
    return r"(?<!\w)(?:" + "|".join(re.escape(term) for term in ordered) + r")" + tail


def clause_part(folded: str, start: int, end: int) -> Tuple[str, str]:
    """Return the clause part before and after one match.

    Args:
        folded: Folded request text.
        start: Start of the match.
        end: End of the match.

    Returns:
        The text from the last clause break or conjunction up to the match,
        and the text after the match up to the next one.
    """
    head = folded[max(0, start - CLAUSE_SPAN_CHARS):start]
    breaks = list(CLAUSE_BREAK_RE.finditer(head)) + list(CLAUSE_CONJUNCTION_RE.finditer(head))
    cut = max((item.end() for item in breaks), default=0)
    rest = folded[end:end + CLAUSE_SPAN_CHARS]
    stops = [item.start() for item in (CLAUSE_BREAK_RE.search(rest), CLAUSE_CONJUNCTION_RE.search(rest)) if item]
    return head[cut:], rest[:min(stops)] if stops else rest


def other_recipient(text: str, destinations: str) -> bool:
    """Tell whether a text names a receiver that is no filing destination.

    Args:
        text: Folded clause text after a filing object or pronoun.
        destinations: Pattern of the filing destinations.

    Returns:
        True when one recipient phrase is not a destination.
    """
    heads = {term.split()[-1] for term in re.findall(r"[a-z][a-z ]+[a-z]", destinations.replace("\\", ""))}
    for match in GRAMMAR_RECIPIENT_RE.finditer(text):
        landed = re.match(destinations, text[match.start():])
        if landed and not GRAMMAR_SERVICE_RE.match(text[match.start() + landed.end():]):
            continue
        if not landed and heads & set(re.findall(r"\w+", match.group(0))[:3]):
            continue
        if not landed and re.search(r"\b(?:portal|portaal|online)\b", match.group(0)):
            continue
        return True
    return False


def grammar_hits(folded: str, grammar: Dict[str, Tuple[str, ...]]) -> List[Tuple[int, int, str]]:
    """List the filing requests the grammar finds in one request.

    Args:
        folded: Folded request text.
        grammar: Parsed filing grammar.

    Returns:
        One (start, end, kind) entry per hit, anchored on its verb. The kind
        is `action` for a verb, `want` for a want or passive request.
    """
    if not grammar:
        return []
    period = [term for term in grammar["objects"] if term in GRAMMAR_PERIOD_OBJECTS]
    plain = [term for term in grammar["objects"] if term not in period]
    objects = r"(?:" + term_pattern(plain, plural=True) + r"(?!['\u2019]s\b)"
    if period:
        objects += "|" + term_pattern(period, plural=True) + GRAMMAR_PERIOD_FOLLOW
    objects += ")"
    pronouns = term_pattern(grammar["pronouns"])
    destinations = term_pattern(grammar["destinations"])
    states = term_pattern(grammar["states"])
    # WHY: a quarter alone names no return, so "stuur hem in Q3" files nothing.
    named = re.search(term_pattern(plain, plural=True), folded) is not None
    hits: List[Tuple[int, int, str]] = []
    for match in re.finditer(term_pattern(grammar["verbs"]), folded):
        _, after = clause_part(folded, match.start(), match.end())
        target = re.search(destinations, after)
        if target and not GRAMMAR_SERVICE_RE.match(after[target.end():]):
            hits.append((match.start(), match.end(), "action"))
            continue
        wide = folded[match.end():match.end() + CLAUSE_SPAN_CHARS]
        if GRAMMAR_CHANNEL_RE.match(wide):
            continue
        tail = GRAMMAR_PARTICLE_RE.sub("", after, count=1)
        found = re.match(r"^\s*((?:\S+\s+){0,3}?)(" + objects + r")", tail)
        if found and re.match(term_pattern(period, plural=True), found.group(2)) and any(
            word not in PERIOD_FILLER and not re.fullmatch(r"\d{1,4}|q[1-4]", word) for word in re.findall(r"[\w']+", found.group(1))
        ):
            found = None
        if found and GRAMMAR_RETURN_COMPOUND_RE.match(tail[found.end():]):
            found = None
        if found and not GRAMMAR_GAP_STOP_RE.search(found.group(1)):
            if not other_recipient(tail[found.end():], destinations):
                hits.append((match.start(), match.end(), "action"))
                continue
        if named and re.match(r"^\s*" + pronouns, tail):
            if not other_recipient(tail, destinations):
                hits.append((match.start(), match.end(), "action"))
    for match in re.finditer(term_pattern(grammar["finals"]), folded):
        before, after = clause_part(folded, match.start(), match.end())
        nominal = not before.strip() and re.match(r"^\s+van\s+(?:\S+\s+){0,3}?" + objects, after)
        object_before = re.search(objects, before) or re.search(pronouns + r"\s*$", before)
        if (nominal or object_before) and not other_recipient(before + after, destinations):
            hits.append((match.start(), match.end(), "action"))
    gap = CLAUSE_GAP + "?"
    status_target = objects + "|" + pronouns if named else objects
    status = r"(?P<t>" + term_pattern(grammar["status"]) + r")" + gap + r"(?:" + status_target + r")" + gap + r"(?P<s>" + states + r")"
    want = (
        r"(?P<t>" + term_pattern(grammar["want"]) + r"(?:\s+dat)?)(?:\s+\S+){0,3}?\s+" + objects
        + r"(?:\s+\S+){0,4}?\s+(?P<s>" + states + r")"
    )
    passive = r"(?P<t>" + objects + r")(?:\s+\S+){0,2}?\s+(?:moet|must|has to|needs to)(?:\s+\S+){0,3}?\s+(?P<s>" + states + r")"
    for pattern, kind in ((status, "action"), (want, "want"), (passive, "want")):
        for match in re.finditer(pattern, folded):
            if not GRAMMAR_SPAN_STOP_RE.search(folded[match.end("t"):match.end()]):
                tail = folded[match.end():match.end() + CLAUSE_SPAN_CHARS]
                stop = CLAUSE_BREAK_RE.search(tail)
                before = re.sub(r"\b(?:to|te)\s+(?:be|have|get|zijn|worden|hebben)\s*$", " ", folded[match.start():match.start("s")])
                scope = before + " " + (tail[:stop.start()] if stop else tail)
                if other_recipient(scope, destinations):
                    continue
                hits.append((match.start(), match.start() + 1, kind))
    return hits


def filing_clause_kept(folded: str, start: int, end: int, boundary: bool, kind: str = "action") -> bool:
    """Tell whether one refusal signal match keeps the request.

    Args:
        folded: Folded request text.
        start: Start of the signal match.
        end: End of the signal match.
        boundary: True for a boundary word, which keeps a wider negation.
        kind: `action` for a filing verb, `want` for a want or passive
            request, which skips the user subject guard.

    Returns:
        True when a negation, a question, a purpose, a time, a deadline, a
        relative clause or a user subject governs the match, so it requests
        no filing.
    """
    clause_start = folded[max(0, start - 4 * CLAUSE_SPAN_CHARS):start]
    breaks = list(CLAUSE_BREAK_RE.finditer(clause_start))
    clause = (clause_start[breaks[-1].end():] if breaks else clause_start)[-CLAUSE_SPAN_CHARS:]
    window = clause[-80:]
    if boundary:
        negated = BOUNDARY_NEGATION_RE.search(window) is not None
    else:
        negated = FILING_NEGATION_RE.search(window) is not None
    if negated and not NEGATION_EXEMPT_RE.search(window) and not USER_CANNOT_RE.search(window):
        return True
    window_start = max(0, start - 4 * CLAUSE_SPAN_CHARS)
    sentence_start = max((item.end() + window_start for item in SENTENCE_BREAK_RE.finditer(folded[window_start:start])), default=window_start)
    sentence_end = SENTENCE_BREAK_RE.search(folded, end, end + 4 * CLAUSE_SPAN_CHARS)
    if sentence_end and sentence_end.group(0) == "?":
        sentence = folded[sentence_start:sentence_end.end()]
        head, _ = clause_part(folded, start, end)
        ordered = kind == "action" and GRAMMAR_LEAD_RE.match(head) is not None
        if not ordered and not QUESTION_REQUEST_RE.search(sentence):
            return True
    if breaks and breaks[-1].group(0) == ":" and FILING_NOTE_RE.search(clause_start[:breaks[-1].end()]):
        return True
    main = folded[start:end] in DUTCH_FINITE_VERBS and DUTCH_SUBCLAUSE_RE.search(clause) is not None
    if not main and FILING_FRAME_RE.search(clause):
        return True
    if not main and kind == "action" and FILING_SUBJECT_BEFORE_RE.search(clause):
        return True
    rest = folded[end:end + 4 * CLAUSE_SPAN_CHARS]
    stop = CLAUSE_BREAK_RE.search(rest)
    after = rest[:stop.start()] if stop else rest
    if kind == "action" and FILING_SUBJECT_AFTER_RE.search(after):
        return True
    if FILING_DEADLINE_RE.search(after):
        return True
    if folded[start:end] in FILING_NOUN_SIGNALS:
        if (FILING_NOUN_BEFORE_RE.search(clause) and not FILING_REQUEST_LEAD_RE.match(clause)) or FILING_NOUN_AFTER_RE.search(after):
            return True
    joint = CLAUSE_CONJUNCTION_RE.search(after)
    governed = after[:joint.start()] if joint else after
    return POST_NEGATION_RE.search(governed) is not None


def table_recipient(folded: str, end: int, grammar: Dict[str, Tuple[str, ...]]) -> bool:
    """Tell whether a `file the` signal sends its object to another receiver.

    Args:
        folded: Folded request text.
        end: End of the signal match.
        grammar: Parsed filing grammar.

    Returns:
        True when the clause after the signal names a receiver that is no
        filing destination, as in `file the return in the archive folder`.
    """
    rest = folded[end:end + CLAUSE_SPAN_CHARS]
    stop = CLAUSE_BREAK_RE.search(rest)
    return other_recipient(rest[:stop.start()] if stop else rest, term_pattern(grammar["destinations"]))


def t8_signal_hit(
    route_rows: List[Dict[str, str]],
    text: str,
    grammar: Optional[Dict[str, Tuple[str, ...]]] = None,
) -> bool:
    """Tell whether one request asks to file, or names the boundary.

    The scorer reads the filing verbs and the boundary words from the T8
    signal cells and the filing grammar of the signal reference. A signal
    matches whole words on both sides, so `dien` misses `diensten` and
    `submit` misses `submitted`. A match keeps the request when a negation
    governs it, when its sentence is a question that asks the assistant to
    do nothing, and when its clause asks when, how or what the user files,
    names a deadline for it, states a purpose, sets a time the user acts
    in, holds a relative clause with another subject or names the user as
    the subject. A boundary word keeps a negation a few words away, as in
    `without reading my personal database`.

    Args:
        route_rows: Parsed task-type rows.
        text: Lower case request text.
        grammar: Parsed filing grammar, None for the table signals only.

    Returns:
        True when one signal or one grammar hit asks to file.
    """
    folded = fold_text(text)
    for row in route_rows:
        if row["type"] != "T8":
            continue
        for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"]):
            boundary = BOUNDARY_SIGNAL_RE.search(fold_text(phrase)) is not None
            for match in re.finditer(t8_pattern(phrase), folded):
                if grammar and phrase.lower().startswith("file ") and table_recipient(folded, match.end(), grammar):
                    continue
                if not filing_clause_kept(folded, match.start(), match.end(), boundary):
                    return True
    for start, end, kind in grammar_hits(folded, grammar or {}):
        if not filing_clause_kept(folded, start, end, False, kind):
            return True
    return False


def t7_destination(text: str, blocked: bool) -> str:
    """Name the sibling skill one additive T7 hit appends.

    Args:
        text: Lower case request text.
        blocked: True when the filing gate or the boundary refuses the request.

    Returns:
        `cli-jortt`, `cli-moneybird` or `blocked`, which a refusal and a
        write against Jortt alone return.
    """
    if blocked or out_of_scope_hit(text):
        return "blocked"
    if any(phrase_matches(text, term) for term in JORTT_DESTINATION_TERMS):
        # WHY: Jortt is read only, so a write that names no Moneybird target
        # asks for a Jortt write.
        if jortt_write_named(text) and not MONEYBIRD_NAME_RE.search(TOOL_NAME_RE.sub(" ", text)):
            return "blocked"
        return "cli-jortt"
    if any(phrase_matches(text, term) for term in MONEYBIRD_DESTINATION_TERMS):
        return "cli-moneybird"
    return "blocked"


def score_candidates(
    route_rows: List[Dict[str, str]],
    text: str,
    weak_signals: Sequence[str],
) -> Dict[str, int]:
    """Score every task type against one request.

    Args:
        route_rows: Parsed task-type rows.
        text: Lower case request text.
        weak_signals: Phrases that never decide a row.

    Returns:
        Mapping of task type to its matched signal count, zero-count types
        left out.
    """
    scores: Dict[str, int] = {}
    for row in route_rows:
        route_type = row["type"]
        if route_type in ("T7", "T8"):
            continue
        count = 0
        topic_hit = False
        seen: Dict[str, bool] = {}
        for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"]):
            folded = fold_text(phrase)
            if folded in weak_signals or folded in seen:
                continue
            seen[folded] = True
            if phrase_matches(text, phrase):
                if route_type == "T4" and phrase.lower() in T4_TOPIC_TERMS:
                    topic_hit = True
                    continue
                count += 1
        if topic_hit:
            count += 1
        for phrase in EXTRA_SIGNALS.get(route_type, ()):
            folded = fold_text(phrase)
            if folded in seen:
                continue
            seen[folded] = True
            if phrase_matches(text, phrase):
                count += 1
        if count:
            scores[route_type] = count
    if "T9" in scores and len(scores) > 1:
        del scores["T9"]
    return scores


def resolve_route(
    route_rows: List[Dict[str, str]],
    skill_root: str,
    prompt: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
    constants: Dict[str, Any],
    weak_signals: Sequence[str],
) -> Dict[str, Any]:
    """Resolve one request to a route and add the glossary reads of an abstain.

    Args:
        route_rows: Parsed task-type rows.
        skill_root: Absolute skill folder.
        prompt: Request text.
        year: Fixture year, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.
        constants: Routing constants.
        weak_signals: Phrases that never decide a row.

    Returns:
        The route record of `decide_route`. An abstain that names a Dutch
        term in an ask frame reads the glossary router and the files that
        hold the term, because a term question needs no task row. A refusal
        reads none.
    """
    route = decide_route(
        route_rows, skill_root, prompt, year, phase_map, topic_map, constants, weak_signals
    )
    if route.get("abstain") and route.get("type") != "T8" and not route.get("paths"):
        route["paths"] = glossary_reads(skill_root, [], prompt.lower())
    return route


def decide_route(
    route_rows: List[Dict[str, str]],
    skill_root: str,
    prompt: str,
    year: str,
    phase_map: Dict[str, str],
    topic_map: Dict[str, str],
    constants: Dict[str, Any],
    weak_signals: Sequence[str],
) -> Dict[str, Any]:
    """Resolve one request to a route, a tier and a read set.

    Args:
        route_rows: Parsed task-type rows.
        skill_root: Absolute skill folder.
        prompt: Request text.
        year: Fixture year, empty when unresolved.
        phase_map: Phase number to reference path.
        topic_map: Topic slug to figures file from the generated block.
        constants: Routing constants.
        weak_signals: Phrases that never decide a row.

    Returns:
        A route record with mode, type, tier, paths, abstain state, the
        additive flag, the destination, the warning band gap and the
        candidate types.
    """
    text = mask_negated_tools(prompt.lower())
    explicit_year = YEAR_RE.search(text) is not None
    scores = score_candidates(route_rows, scoring_text(text), weak_signals)
    t7_hit = any(
        phrase_matches(text, phrase)
        for row in route_rows
        if row["type"] == "T7"
        for phrase in signal_phrases(row["dutch"]) + signal_phrases(row["english"])
    )
    t8_hit = t8_signal_hit(route_rows, text, load_filing_grammar(skill_root))
    destination = t7_destination(text, t8_hit) if t7_hit else ""
    # WHY: a filing signal wins over the preparation rows whatever they score,
    # and over every row once the request names the deliverable it would file.
    if t8_hit:
        if any(route_type in scores for route_type in PREPARE_TYPES):
            scores = {}
        for route_type in PREPARE_TYPES:
            scores.pop(route_type, None)
    ordered = sorted(scores.items(), key=lambda item: (-item[1], item[0]))
    margin = float(constants.get("route_margin") or 0.25)
    warning = float(constants.get("warning_band") or 0.08)
    floor = float(constants.get("fallback_floor") or 0.0)
    band_gap: Optional[float] = None
    if len(ordered) > 1:
        gap = ordered[0][1] - ordered[1][1]
        if margin <= gap < margin + warning:
            band_gap = round(gap - margin, 6)
    if not ordered:
        if t8_hit or out_of_scope_hit(text):
            return {
                "mode": "ABSTAIN",
                "type": "T8",
                "tier": "A",
                "paths": [],
                "abstain": True,
                "candidates": ["T8"],
                "t7": t7_hit,
                "destination": destination,
                "band_gap": None,
            }
        return {
            "mode": "ABSTAIN",
            "type": "abstain",
            "tier": "B",
            "paths": [],
            "abstain": True,
            "candidates": [],
            "t7": t7_hit,
            "destination": destination,
            "band_gap": None,
        }
    winner = ordered[0][0]
    if ordered[0][1] < floor:
        if out_of_scope_hit(text):
            return {
                "mode": "ABSTAIN",
                "type": "T8",
                "tier": "A",
                "paths": [],
                "abstain": True,
                "candidates": ["T8"],
                "t7": t7_hit,
                "destination": destination,
                "band_gap": None,
            }
        return {
            "mode": "ABSTAIN",
            "type": "abstain",
            "tier": "B",
            "paths": [],
            "abstain": True,
            "candidates": [ordered[0][0]],
            "t7": t7_hit,
            "destination": destination,
            "band_gap": None,
        }
    if len(ordered) > 1 and ordered[0][1] - ordered[1][1] < margin:
        decided = specificity_winner(text, ordered[0][0], ordered[1][0], route_rows)
        if decided is None:
            return {
                "mode": "ABSTAIN",
                "type": "abstain",
                "tier": "B",
                "paths": [],
                "abstain": True,
                "candidates": sorted([ordered[0][0], ordered[1][0]]),
                "t7": t7_hit,
                "destination": destination,
                "band_gap": None,
            }
        winner = decided
    if winner in ("T5", "T6") and not explicit_year and not year:
        if not any(phrase_matches(text, term) for term in SOURCE_TERMS):
            return {
                "mode": "LIVE",
                "type": winner,
                "tier": "C",
                "paths": [],
                "abstain": True,
                "candidates": [winner],
                "t7": t7_hit,
                "destination": destination,
                "band_gap": band_gap,
            }
    mode = MODE_BY_TYPE.get(winner, "MIGRATION" if t7_hit else "LIVE")
    paths = resolve_paths(skill_root, winner, text, year, phase_map, topic_map, route_rows)
    return {
        "mode": mode,
        "type": winner,
        "tier": "",
        "paths": paths,
        "abstain": False,
        "candidates": [winner],
        "t7": t7_hit,
        "destination": destination,
        "band_gap": band_gap,
    }

# ───────────────────────────────────────────────────────────────
# 8. HUB STAGE ONE
# ───────────────────────────────────────────────────────────────

def load_hub(repo_root: str) -> Optional[Dict[str, Any]]:
    """Read the stage one files of the hub above the skill folder.

    Args:
        repo_root: Folder that holds the hub `SKILL.md`.

    Returns:
        The registry modes in order, the default mode and the signals of
        each mode, or None when a hub file is missing or malformed.
    """
    try:
        with open(os.path.join(repo_root, MODE_REGISTRY_NAME), "r", encoding="utf-8") as handle:
            registry = json.load(handle)
        with open(os.path.join(repo_root, HUB_ROUTER_NAME), "r", encoding="utf-8") as handle:
            router = json.load(handle)
    except (OSError, ValueError):
        return None
    if not isinstance(registry, dict) or not isinstance(router, dict):
        return None
    modes = [
        str(entry.get("workflowMode", ""))
        for entry in registry.get("modes", [])
        if isinstance(entry, dict) and entry.get("workflowMode")
    ]
    policy = router.get("routerPolicy")
    signals = router.get("signals")
    if not isinstance(policy, dict) or not isinstance(signals, dict):
        return None
    default = str(policy.get("defaultMode", ""))
    if default not in modes:
        return None
    phrases: Dict[str, List[str]] = {}
    for mode in modes:
        listed = signals.get(mode, [])
        if not isinstance(listed, list):
            return None
        phrases[mode] = [str(phrase) for phrase in listed]
    return {"modes": modes, "default": default, "signals": phrases}


def hub_signal_pattern(phrase: str) -> str:
    """Build the whole word pattern of one stage one signal.

    A stage one signal names a tool, so unlike a task row signal it may not
    run on into a longer word: `jortt cli` misses `jortt clients`.

    Args:
        phrase: Signal phrase.

    Returns:
        The regular expression of the phrase, bounded on both sides.
    """
    return r"(?<!\w)" + signal_pattern(phrase) + r"(?!\w)"


def hub_signal_named(text: str, phrase: str) -> bool:
    """Tell whether one request names a stage one signal it does not negate.

    Args:
        text: Lower case request text.
        phrase: Signal phrase.

    Returns:
        True when one match of the phrase has no negation before it.
    """
    for match in re.finditer(hub_signal_pattern(phrase), text):
        if not tool_negated(text, match.start()):
            return True
    return False


def strip_phrase(text: str, phrase: str) -> str:
    """Blank every match of one signal phrase in a text.

    Args:
        text: Lower case request text.
        phrase: Signal phrase.

    Returns:
        The text with each match of the phrase replaced by a space.
    """
    return re.sub(hub_signal_pattern(phrase), " ", text)


def tool_route_modes(route_rows: List[Dict[str, str]], route_type: str, modes: Sequence[str]) -> List[str]:
    """List the hub modes the tool route of one task row names.

    Args:
        route_rows: Parsed task-type rows.
        route_type: Winning task type.
        modes: Registry modes.

    Returns:
        The named modes, in the order the cell names them.
    """
    named: List[str] = []
    for row in route_rows:
        if row["type"] != route_type:
            continue
        for cell in BACKTICK_RE.findall(row["tool_route"]) or [row["tool_route"]]:
            for part in TOOL_ROUTE_SPLIT_RE.split(cell.strip()):
                if part in modes and part not in named:
                    named.append(part)
    return named


def resolve_packets(
    hub: Optional[Dict[str, Any]],
    prompt: str,
    route: Dict[str, Any],
    route_rows: List[Dict[str, str]],
    resolve_rest: Any,
) -> List[str]:
    """Pick the packets one request reads, in the order it reads them.

    A request that names a CLI signal it does not negate and holds no
    accountant task once the CLI signals and the system names are set aside
    starts in that CLI packet, or in each named CLI packet in registry
    order. A request that names both systems, where a CLI name stands for
    its system, and holds a bare system name or a move verb, that names a
    phase number or whose route is a migration row with a move verb, holds
    a migration task. Every other request starts in the default packet, which hands
    off to each packet its winning tool route names and to the destination
    of an additive T7 hit. A refusal stays in the default packet with no
    handoff, and so does a request that names a CLI and is a refusal once
    the CLI signals and the system names are set aside. An abstain hands
    off to none.

    Args:
        hub: Stage one data from `load_hub`, None when the hub is absent.
        prompt: Request text.
        route: Resolved accountant route of the full request.
        route_rows: Parsed task-type rows.
        resolve_rest: Resolves the request text left after the strip.

    Returns:
        The packet chain, empty when the hub is absent.
    """
    if hub is None:
        return []
    text = prompt.lower()
    default = hub["default"]
    if route.get("type") == "T8":
        return [default]
    others = [mode for mode in hub["modes"] if mode != default]
    named = [
        mode
        for mode in others
        if any(hub_signal_named(text, phrase) for phrase in hub["signals"][mode])
    ]
    if named:
        rest = text
        for mode in others:
            for phrase in hub["signals"][mode]:
                rest = strip_phrase(rest, phrase)
        # WHY: a request that names both systems or a phase number moves records
        # between them, which is a migration task for the accountant. A CLI
        # name stands for its system, so "jortt-cli ... into Moneybird" names
        # both. Two CLI names alone need a move verb, because "list my contacts
        # with both CLIs" moves nothing.
        unnegated = mask_negated_tools(text)
        bare = TOOL_NAME_RE.sub(" ", unnegated)
        both_systems = all(re.search(hub_signal_pattern(name), unnegated) for name in HUB_SYSTEM_NAMES)
        bare_name = any(re.search(hub_signal_pattern(name), bare) for name in HUB_SYSTEM_NAMES)
        migration_route = route.get("type") in ("T1", "T2") and MIGRATION_VERB_RE.search(text)
        if (both_systems and (bare_name or MIGRATION_VERB_RE.search(text))) or PHASE_RE.search(rest) or migration_route:
            named = []
        for name in HUB_SYSTEM_NAMES:
            rest = strip_phrase(rest, name)
    if named:
        remainder = resolve_rest(rest)
        # WHY: a filing request that names a CLI can route to a task row on the
        # system name, so the refusal is read on the text left after the strip.
        if remainder.get("type") == "T8":
            return [default]
        if remainder.get("type") == "abstain" and not remainder.get("candidates"):
            return named
    chain = [default]
    if route.get("abstain"):
        return chain
    handoffs = tool_route_modes(route_rows, str(route.get("type", "")), others)
    destination = str(route.get("destination", ""))
    if destination in others and destination not in handoffs:
        handoffs.append(destination)
    chain.extend(handoffs)
    return chain


def cli_start_route(route: Dict[str, Any], packets: List[str], default: str) -> Dict[str, Any]:
    """Replace the accountant route of a request that starts in a CLI packet.

    Args:
        route: Resolved accountant route of the full request.
        packets: Packet chain from `resolve_packets`.
        default: Default mode of the hub.

    Returns:
        The route unchanged when the chain starts in the default packet,
        else a CLI route that reads no accountant reference.
    """
    if not packets or packets[0] == default:
        return route
    return {
        "mode": "CLI",
        "type": "cli",
        "tier": "",
        "paths": [],
        "abstain": False,
        "candidates": [],
        "t7": route.get("t7", False),
        "destination": route.get("destination", ""),
        "band_gap": None,
        "packets": packets,
    }

# ───────────────────────────────────────────────────────────────
# 9. LOADED TEXT AND TOKENS
# ───────────────────────────────────────────────────────────────

def section_text(
    skill_root: str,
    address: str,
    cache: Dict[str, Dict[str, Any]],
    encoder: Any,
    strict: bool = True,
) -> str:
    """Return the text of one file read or one section read.

    Args:
        skill_root: Absolute skill folder.
        address: Path with an optional #anchor suffix.
        cache: Per-run cache of file texts and section ranges.
        encoder: Pinned encoder.
        strict: Stop with exit 2 on an unreadable file. False returns an
            empty text so a revision run can score the row as a finding.

    Returns:
        The text of the read.
    """
    path, _, anchor = address.partition("#")
    absolute = join_skill(skill_root, path)
    if path not in cache:
        if strict:
            text = read_text(absolute)
        else:
            try:
                with open(absolute, "r", encoding="utf-8") as handle:
                    text = handle.read()
            except OSError:
                text = ""
        h2 = {}
        for section in section_index(text):
            h2[section["anchor"]] = section["text"]
        cache[path] = {"text": text, "sections": h2, "toc": parse_toc_ranges(text)}
    entry = cache[path]
    if not anchor:
        return entry["text"]
    if anchor in entry["sections"]:
        return entry["sections"][anchor]
    if anchor in entry["toc"]:
        start, end = entry["toc"][anchor]
        lines = entry["text"].splitlines(keepends=True)
        return "".join(lines[start - 1:end])
    return entry["text"]


def section_index(text: str) -> List[Dict[str, Any]]:
    """Split one markdown file into its H2 sections.

    Args:
        text: File text.

    Returns:
        Rows with the anchor and the section text, in file order.
    """
    spans: List[Tuple[int, str, int]] = []
    start = 0
    number = 0
    while start < len(text):
        newline = text.find("\n", start)
        if newline == -1:
            number += 1
            spans.append((number, text[start:].rstrip("\r"), start))
            break
        number += 1
        spans.append((number, text[start:newline].rstrip("\r"), start))
        start = newline + 1
    in_code = False
    headings: List[Tuple[int, str, int]] = []
    for line_number, content, offset in spans:
        if content.strip().startswith("```") or content.strip().startswith("~~~"):
            in_code = not in_code
            continue
        if in_code:
            continue
        match = re.match(r"^##\s+(.*?)\s*$", content)
        if not match:
            continue
        title = match.group(1).strip()
        anchor = re.sub(r"[^\w\s-]", "", title.lower(), flags=re.UNICODE)
        anchor = re.sub(r"\s+", "-", anchor.strip())
        headings.append((line_number, anchor, offset))
    rows: List[Dict[str, Any]] = []
    for index, (line_number, anchor, offset) in enumerate(headings):
        stop = headings[index + 1][2] if index + 1 < len(headings) else len(text)
        rows.append({"anchor": anchor, "line": line_number, "text": text[offset:stop]})
    return rows


def count_tokens(encoder: Any, text: str) -> int:
    """Count the tokens of one text in the pinned encoding.

    Args:
        encoder: Pinned encoder.
        text: Text to count.

    Returns:
        The token count.
    """
    return len(encoder.encode_ordinary(text))


def loaded_material(
    skill_root: str,
    paths: Sequence[str],
    cache: Dict[str, Dict[str, Any]],
    encoder: Any,
    strict: bool = True,
) -> Tuple[int, List[str]]:
    """Count and collect the loaded material of one read set.

    Args:
        skill_root: Absolute skill folder.
        paths: Read set addresses.
        cache: Per-run cache of file texts and section ranges.
        encoder: Pinned encoder.
        strict: Stop with exit 2 on a missing read file.

    Returns:
        The token sum and the loaded texts in read-set order.
    """
    tokens = 0
    texts: List[str] = []
    for address in paths:
        text = section_text(skill_root, address, cache, encoder, strict)
        tokens += count_tokens(encoder, text)
        texts.append(text)
    return tokens, texts

# ───────────────────────────────────────────────────────────────
# 10. ROW SCORING
# ───────────────────────────────────────────────────────────────

def base_path(address: str) -> str:
    """Return the file part of one read address.

    Args:
        address: Path with an optional #anchor suffix.

    Returns:
        The path without the suffix.
    """
    return strip_anchor(address)


def check_claims(skill_root: str, row: Dict[str, Any]) -> List[str]:
    """Check the file claims one corpus row asserts against the revision.

    A claim names a path and a text. The text must appear in that file of
    the scored revision, so a row can guard content its read set does not
    load, such as a route class line or a section of the skill markdown.

    Args:
        skill_root: Absolute skill folder of the scored revision.
        row: Corpus row with an expected_claims list.

    Returns:
        One message per claim whose file or text is not present.
    """
    missing: List[str] = []
    for claim in row.get("expected_claims", []):
        if not isinstance(claim, dict):
            missing.append(str(claim))
            continue
        path = strip_anchor(str(claim.get("path", "")))
        wanted = str(claim.get("text", ""))
        try:
            with open(join_skill(skill_root, path), "r", encoding="utf-8") as handle:
                content = handle.read()
        except OSError:
            missing.append("%s: %s" % (path, wanted))
            continue
        if wanted not in content:
            missing.append("%s: %s" % (path, wanted))
    return missing


def score_row(
    skill_root: str,
    row: Dict[str, Any],
    route: Dict[str, Any],
    cache: Dict[str, Dict[str, Any]],
    encoder: Any,
    strict: bool = True,
) -> Dict[str, Any]:
    """Score one corpus row against its resolved route.

    Args:
        skill_root: Absolute skill folder.
        row: Corpus row.
        route: Resolved route.
        cache: Per-run cache of file texts and section ranges.
        encoder: Pinned encoder.
        strict: Stop with exit 2 on a missing read file. False reports the
            missing path as a row problem instead.

    Returns:
        The row result with score, verdict, reason, tokens and facts found.
    """
    expected_paths = [str(path) for path in row.get("expected_paths", [])]
    forbidden = [base_path(str(path)) for path in row.get("forbidden_paths", [])]
    loaded = [base_path(str(path)) for path in route["paths"]]
    tokens_loaded, texts = loaded_material(skill_root, route["paths"], cache, encoder, strict)
    combined = "\n".join(texts).lower()
    facts = [str(fact) for fact in row.get("expected_facts", [])]
    facts_found = [fact for fact in facts if fact.lower() in combined]
    missing_claims = check_claims(skill_root, row)
    missing_paths = [path for path in expected_paths if path not in route["paths"]]
    hit_forbidden = [path for path in forbidden if path in loaded]
    ceiling = int(row.get("token_ceiling", 0))

    problems: List[str] = []
    if not strict:
        missing_reads = [path for path in loaded if not os.path.isfile(join_skill(skill_root, path))]
        if missing_reads:
            problems.append("read paths missing on disk %s" % ", ".join(missing_reads))
    if route["mode"] != row.get("gold_mode"):
        problems.append("mode %s expected %s" % (route["mode"], row.get("gold_mode")))
    if route["type"] != row.get("gold_task_type"):
        problems.append("task type %s expected %s" % (route["type"], row.get("gold_task_type")))
    # WHY: tier C has the mode and type of a normal answer, so only the tier
    # tells a missing-year question from an answer that skipped it.
    if "tier" in row and str(route.get("tier", "")) != str(row.get("tier", "")):
        problems.append("tier %s expected %s" % (route.get("tier", "") or "none", row.get("tier", "") or "none"))
    if missing_paths:
        problems.append("paths not loaded %s" % ", ".join(missing_paths))
    if hit_forbidden:
        problems.append("forbidden paths loaded %s" % ", ".join(hit_forbidden))
    if len(facts_found) != len(facts):
        missing_facts = [fact for fact in facts if fact not in facts_found]
        problems.append("facts not found %s" % ", ".join(missing_facts))
    if missing_claims:
        problems.append("claims not met %s" % ", ".join(missing_claims))
    if tokens_loaded > ceiling:
        problems.append("tokens %d above ceiling %d" % (tokens_loaded, ceiling))
    if route["type"] == "T7":
        problems.append("additive row T7 won alone")
    if "t7" in row and bool(route.get("t7")) != bool(row.get("t7")):
        problems.append("t7 additive hit %s expected %s" % (bool(route.get("t7")), bool(row.get("t7"))))
    if "destination" in row and str(route.get("destination", "")) != str(row.get("destination", "")):
        problems.append("destination %s expected %s" % (route.get("destination", ""), row.get("destination", "")))
    packets = [str(packet) for packet in route.get("packets", [])]
    if "gold_packets" in row:
        gold_packets = [str(packet) for packet in row.get("gold_packets", [])]
        if not packets:
            problems.append("hub files missing or malformed for the packet chain")
        elif packets != gold_packets:
            problems.append("packets %s expected %s" % ("+".join(packets), "+".join(gold_packets)))
    score = 5 - len(problems)
    if problems:
        reason = ". ".join(problems)
    else:
        reason = "route, read set, facts, claims and tokens match"
    return {
        "scenario_id": row.get("id", ""),
        "lang": row.get("lang", ""),
        "split": row.get("split", ""),
        "gold_mode": row.get("gold_mode", ""),
        "gold_task_type": row.get("gold_task_type", ""),
        "score": str(score),
        "verdict": "PASS" if not problems else "FAIL",
        "reason": reason,
        "tokens_loaded": str(tokens_loaded),
        "t7": "1" if route.get("t7") else "0",
        "destination": route.get("destination", ""),
        "reads": str(len(route.get("paths", []))),
        "packets": "+".join(packets),
        "band_gap": route.get("band_gap"),
        "facts_found": len(facts_found),
        "expected_facts": len(facts),
        "tier": route["tier"],
        "route": "%s/%s" % (route["mode"], route["type"]),
        "abstain": bool(route["abstain"]),
    }

# ───────────────────────────────────────────────────────────────
# 11. PARITY
# ───────────────────────────────────────────────────────────────

def parity_findings(
    rows: List[Dict[str, Any]],
    resolutions: Dict[str, Dict[str, Any]],
    strict: bool = True,
) -> List[str]:
    """Compare every Dutch twin with its English pair.

    Route equality covers the gold route, the resolved route, the tier and
    the resolved read set. It never compares answer text. A filtered run
    skips a pair whose other half is not selected, because that half is out
    of scope for the run.

    Args:
        rows: Corpus rows.
        resolutions: Resolved route per row id.
        strict: Report a pair whose other half is missing from the selection.

    Returns:
        One finding line per mismatched twin pair.
    """
    by_id = {str(row.get("id", "")): row for row in rows}
    findings: List[str] = []
    for row in rows:
        twin_id = str(row.get("parityOf", "") or "")
        if not twin_id:
            continue
        twin = by_id.get(twin_id)
        if twin is None:
            if strict:
                findings.append("parity pair %s names a missing twin %s" % (row.get("id", ""), twin_id))
            continue
        matches = (
            row.get("gold_mode") == twin.get("gold_mode")
            and row.get("gold_task_type") == twin.get("gold_task_type")
            and resolutions[str(row.get("id", ""))]["mode"] == resolutions[twin_id]["mode"]
            and resolutions[str(row.get("id", ""))]["type"] == resolutions[twin_id]["type"]
            and resolutions[str(row.get("id", ""))]["tier"] == resolutions[twin_id]["tier"]
            and sorted(resolutions[str(row.get("id", ""))]["paths"]) == sorted(resolutions[twin_id]["paths"])
            and resolutions[str(row.get("id", ""))].get("packets", []) == resolutions[twin_id].get("packets", [])
        )
        if not matches:
            findings.append(
                "parity mismatch %s against %s" % (row.get("id", ""), twin_id)
            )
    return findings

# ───────────────────────────────────────────────────────────────
# 12. RESOLVE MODE
# ───────────────────────────────────────────────────────────────

def load_corpus(path: str) -> List[Dict[str, Any]]:
    """Read the fixture corpus.

    Args:
        path: Corpus file.

    Returns:
        The corpus rows.

    Raises:
        SystemExit: When the file is unreadable, is not an object with rows
        or holds no row.
    """
    if not os.path.isfile(path):
        fail("corpus not found: %s" % os.path.basename(path))
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        fail("cannot read corpus: %s" % exc)
    rows = data.get("rows") if isinstance(data, dict) else None
    if not isinstance(rows, list) or not rows:
        fail("corpus holds no rows: %s" % os.path.basename(path))
    return rows


def accuracy(rows: List[Dict[str, Any]], results: List[Dict[str, Any]], predicate: Any) -> Tuple[int, int]:
    """Count the route matches over a row subset.

    Args:
        rows: Corpus rows.
        results: Scored rows in corpus order.
        predicate: Callable that selects the subset.

    Returns:
        The matched count and the subset count.
    """
    matched = 0
    total = 0
    for row, result in zip(rows, results):
        if not predicate(row, result):
            continue
        total += 1
        if result["route"] == "%s/%s" % (row.get("gold_mode"), row.get("gold_task_type")):
            matched += 1
    return matched, total


def ratio_text(matched: int, total: int) -> str:
    """Render one accuracy fraction.

    Args:
        matched: Matched rows.
        total: Rows in the subset.

    Returns:
        A text such as 12/12 (1.000).
    """
    value = 1.0 if total == 0 else round(matched / total, 3)
    return "%d/%d (%.3f)" % (matched, total, value)


def metric_text(matched: int, total: int) -> str:
    """Render one precision or recall fraction with its denominator.

    Args:
        matched: Correct rows.
        total: Denominator rows, zero when no row covers the type.

    Returns:
        A text such as 12/15 (0.800), or 0/0 (n/a) when no row covers the
        type.
    """
    if total == 0:
        return "0/0 (n/a)"
    return "%d/%d (%.3f)" % (matched, total, matched / total)


def write_results(path: str, results: List[Dict[str, Any]], columns: Sequence[str] = RESULT_COLUMNS) -> None:
    """Write results.csv with a fixed column order.

    Args:
        path: Output file.
        results: Scored rows.
        columns: Column names in output order.

    Raises:
        SystemExit: When the file cannot be written.
    """
    try:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(columns), lineterminator="\n")
            writer.writeheader()
            for result in results:
                writer.writerow({column: result.get(column, "") for column in columns})
    except OSError as exc:
        fail("cannot write results: %s" % exc)


def write_report(
    path: str,
    snapshot_hash: str,
    corpus_name: str,
    rows: List[Dict[str, Any]],
    results: List[Dict[str, Any]],
    parity: List[str],
    constants: Dict[str, Any],
    revision: str = "",
) -> None:
    """Write report.md with the accuracy lines and the four metric sections.

    Args:
        path: Output file.
        snapshot_hash: Router snapshot hash.
        corpus_name: Corpus file name.
        rows: Corpus rows.
        results: Scored rows in corpus order.
        parity: Parity findings.
        constants: Routing constants.
        revision: Full revision text, empty on a live run.

    Raises:
        SystemExit: When the file cannot be written.
    """
    total = len(results)
    passed = sum(1 for result in results if result["verdict"] == "PASS")
    abstained = sum(1 for result in results if result["tier"] in ("A", "B"))
    tier_c = sum(1 for result in results if result["tier"] == "C")
    false_abstain = sum(
        1
        for row, result in zip(rows, results)
        if result["tier"] in ("A", "B") and row.get("gold_mode") != "ABSTAIN"
    )
    monthly = "calibration: pending" if constants.get("fallback_floor_pending") else str(constants.get("fallback_floor"))
    languages = ("en", "nl", "mixed")
    splits = ("calibration", "held-out", "regression")
    languages_accuracy = {
        language: accuracy(rows, results, lambda row, _result, value=language: row.get("lang") == value)
        for language in languages
    }
    splits_accuracy = {
        split: accuracy(rows, results, lambda row, _result, value=split: row.get("split") == value)
        for split in splits
    }
    lines: List[str] = []
    lines.append("# Route replay report")
    lines.append("")
    lines.append("Router snapshot: sha256:%s" % snapshot_hash)
    lines.append("Mode: resolve")
    if revision:
        lines.append("Revision: %s" % revision[:12])
    lines.append("Corpus: %s with %d rows" % (corpus_name, total))
    lines.append("Token encoding: o200k_base from the pinned cache")
    lines.append("Route margin: %s. Warning band: %s. Fallback floor: %s." % (
        constants.get("route_margin"),
        constants.get("warning_band"),
        monthly,
    ))
    lines.append("")
    lines.append("## Scored dimensions")
    lines.append("")
    lines.append("- Route: scored, mode and task type against the gold route.")
    lines.append("- Read set: scored, expected paths loaded and forbidden paths absent.")
    lines.append("- Connectivity: scored by the gate before any row is scored.")
    lines.append("- Hub packet: scored on the rows that name a gold packet chain.")
    lines.append("- Answer quality: unscored. No judge model grades an answer.")
    lines.append("")
    lines.append("## Accuracy")
    lines.append("")
    for language in languages:
        matched, size = languages_accuracy[language]
        lines.append("- route accuracy %s: %s" % (language, ratio_text(matched, size)))
    for split in splits:
        matched, size = splits_accuracy[split]
        lines.append("- route accuracy %s: %s" % (split, ratio_text(matched, size)))
    held_matched, held_total = splits_accuracy["held-out"]
    lines.append("- held-out route accuracy: %s" % ratio_text(held_matched, held_total))
    lines.append("- rows passed: %d of %d" % (passed, total))
    lines.append("- abstain: %d of %d expected" % (
        abstained,
        sum(1 for row in rows if row.get("gold_mode") == "ABSTAIN"),
    ))
    lines.append("- missing tax year, tier C: %d" % tier_c)
    lines.append("- false abstain: %d" % false_abstain)
    hub_pairs = [(row, result) for row, result in zip(rows, results) if "gold_packets" in row]
    hub_total = len(hub_pairs)
    hub_matched = sum(
        1
        for row, result in hub_pairs
        if result.get("packets", "") == "+".join(str(packet) for packet in row.get("gold_packets", []))
    )
    lines.append("- hub packet chain: %s" % ratio_text(hub_matched, hub_total))
    pair_total = sum(1 for row in rows if row.get("parityOf"))
    lines.append("- Dutch parity: %d of %d twin pairs match" % (pair_total - len(parity), pair_total))
    for finding in parity:
        lines.append("- %s" % finding)
    lines.append("")
    lines.append("## Additive T7 assertion")
    lines.append("")
    lines.append(
        "The additive CLI row never wins alone. A row whose prompt matches a T7 signal keeps the row it matched and appends the sibling tool skill."
    )
    lines.append("")
    t7_rows = [result for result in results if result.get("t7") == "1"]
    t7_alone = [result for result in results if result["route"].endswith("/T7")]
    lines.append("- rows matching a T7 signal: %d" % len(t7_rows))
    lines.append("- additive row wins alone: %d" % len(t7_alone))
    for result in t7_rows:
        lines.append("- %s: T7 signal with route %s" % (result["scenario_id"], result["route"]))
    lines.append("")
    lines.append("## Per-type precision and recall")
    lines.append("")
    lines.append(
        "Precision divides the correct routes by the rows routed to that type. Recall divides them by the rows whose gold type it is."
    )
    lines.append("")
    gold_types: Dict[str, int] = {route_type: 0 for route_type in REPORT_TYPES}
    routed_types: Dict[str, int] = {route_type: 0 for route_type in REPORT_TYPES}
    correct_types: Dict[str, int] = {route_type: 0 for route_type in REPORT_TYPES}
    for row, result in zip(rows, results):
        gold_type = str(row.get("gold_task_type", ""))
        resolved = result["route"].split("/", 1)[1] if "/" in result["route"] else ""
        if gold_type in gold_types:
            gold_types[gold_type] += 1
        if resolved in routed_types:
            routed_types[resolved] += 1
        if resolved in correct_types and gold_type == resolved:
            correct_types[resolved] += 1
    for route_type in REPORT_TYPES:
        correct = correct_types[route_type]
        lines.append(
            "- %s precision %s, recall %s"
            % (
                route_type,
                metric_text(correct, routed_types[route_type]),
                metric_text(correct, gold_types[route_type]),
            )
        )
    lines.append("")
    lines.append("## Read counts")
    lines.append("")
    lines.append("| scenario | route | reads |")
    lines.append("|---|---|---:|")
    for result in results:
        lines.append("| %s | %s | %s |" % (result["scenario_id"], result["route"], result["reads"]))
    lines.append("")
    lines.append("## Warning band sink")
    lines.append("")
    lines.append(
        "Rows whose winning gap sits in the %s warning band above the route margin. Telemetry only, the route never changes."
        % constants.get("warning_band")
    )
    lines.append("")
    band_rows = [result for result in results if result.get("band_gap") is not None]
    if band_rows:
        for result in band_rows:
            lines.append("- %s: %.3f above the margin" % (result["scenario_id"], float(result["band_gap"])))
    else:
        lines.append("- none")
    lines.append("")
    lines.append("## Rows")
    lines.append("")
    lines.append("| scenario | lang | split | route | tokens loaded | facts found | verdict |")
    lines.append("|---|---|---|---|---:|---|---|")
    for row, result in zip(rows, results):
        lines.append("| %s | %s | %s | %s | %s | %d of %d | %s |" % (
            result["scenario_id"],
            result["lang"],
            result["split"],
            result["route"],
            result["tokens_loaded"],
            result["facts_found"],
            result["expected_facts"],
            result["verdict"],
        ))
    lines.append("")
    try:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write("\n".join(lines))
    except OSError as exc:
        fail("cannot write report: %s" % exc)


def write_unscorable(
    args: argparse.Namespace,
    rows: List[Dict[str, Any]],
    reason: str,
    revision: str,
) -> int:
    """Write a failure result for every selected row.

    The revision run reaches this path when the worktree of an older commit
    holds no route table or no signal file, because that missing content is
    the regression the row guards.

    Args:
        args: Parsed command line.
        rows: Selected resolve rows.
        reason: Why the rows cannot be scored.
        revision: Full revision text, empty on a live run.

    Returns:
        1, because every selected row is a finding.
    """
    problems = "unscorable: %s" % reason
    if revision:
        problems = "%s at revision %s" % (problems, revision[:12])
    results: List[Dict[str, Any]] = []
    for row in rows:
        results.append(
            {
                "scenario_id": row.get("id", ""),
                "lang": row.get("lang", ""),
                "split": row.get("split", ""),
                "gold_mode": row.get("gold_mode", ""),
                "gold_task_type": row.get("gold_task_type", ""),
                "score": "0",
                "verdict": "FAIL",
                "reason": problems,
                "tokens_loaded": "0",
            }
        )
    out_dir = os.path.abspath(args.out)
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        fail("cannot create output folder: %s" % os.path.basename(out_dir))
    write_results(os.path.join(out_dir, "results.csv"), results)
    lines = [
        "# Route replay report",
        "",
        "Mode: resolve",
    ]
    if revision:
        lines.append("Revision: %s" % revision[:12])
    lines.append("Corpus: %s with %d rows" % (os.path.basename(args.corpus), len(results)))
    lines.append("")
    lines.append("## Findings")
    lines.append("")
    lines.append("- %s" % problems)
    lines.append("- rows passed: 0 of %d" % len(results))
    lines.append("")
    try:
        with open(os.path.join(out_dir, "report.md"), "w", encoding="utf-8", newline="") as handle:
            handle.write("\n".join(lines))
    except OSError as exc:
        fail("cannot write report: %s" % exc)
    print("%s: %s" % (PROGRAM, problems))
    return 1


def routing_markdown(skill_root: str) -> str:
    """Name the file that holds the route table for one skill folder.

    Args:
        skill_root: Absolute skill folder.

    Returns:
        The skill's ROUTER.md when it holds the route table, else its
        SKILL.md, where a revision from before the hub keeps it.
    """
    router = join_skill(skill_root, ROUTER_MD_NAME)
    if os.path.isfile(router) and START_MARKER in read_text(router):
        return router
    return join_skill(skill_root, SKILL_MD_NAME)


def run_resolve(args: argparse.Namespace) -> int:
    """Score the corpus in resolve mode and write the outputs.

    Args:
        args: Parsed command line.

    Returns:
        0 when every row passes, 1 on a row or parity finding.
    """
    skill_root = os.path.abspath(args.skill_root)
    revision = str(getattr(args, "rev_sha", "") or "")
    rev_mode = bool(revision)
    skill_md = routing_markdown(skill_root)
    signals_md = join_skill(skill_root, SIGNALS_NAME)
    if not os.path.isfile(skill_md):
        fail("routing markdown not found for %s" % os.path.basename(skill_root))
    rows = select_rows(load_corpus(args.corpus), args.covers, "resolve")
    if not rows:
        fail("no resolve rows match the covers filter")
    skill_text = read_text(skill_md)
    if rev_mode and (START_MARKER not in skill_text or END_MARKER not in skill_text):
        return write_unscorable(args, rows, "route table markers missing", revision)
    # WHY: the parsers report a missing marker without a path, so the file the
    # loader picked is named here, before the parsers run. A revision run keeps
    # its own unscorable path for an old tree that lacks a marker.
    if not rev_mode:
        source_name = os.path.relpath(skill_md, os.path.dirname(skill_root))
        for start, end, label in ((START_MARKER, END_MARKER, "route table"), (ROUTER_START, ROUTER_END, "router block")):
            if start not in skill_text or end not in skill_text:
                fail("%s markers missing in %s" % (label, source_name))
    if not os.path.isfile(signals_md):
        if rev_mode:
            return write_unscorable(args, rows, "routing signals file missing", revision)
        fail("routing signals file not found in %s" % os.path.basename(skill_root))
    signals_text = read_text(signals_md)
    weak_signals = parse_weak_signals(signals_text)
    route_rows = parse_route_table(skill_text)
    constants = parse_constants(skill_text, signals_text)
    if rev_mode and ("PHASE_FILES = {" not in skill_text or "TOPIC_FILES = {" not in skill_text):
        return write_unscorable(args, rows, "generated router maps missing", revision)
    phase_map = parse_generated_map(skill_text, "PHASE_FILES")
    topic_map = parse_generated_map(skill_text, "TOPIC_FILES")
    if not rev_mode:
        check_phase_agreement(skill_root, phase_map)
    resources = load_resource_map(skill_root)
    snapshot, snapshot_hash = build_snapshot(route_rows, constants, phase_map, resources)
    del snapshot

    required, _conditional = routed_paths(route_rows, skill_root, phase_map, topic_map)
    if not rev_mode:
        missing = connectivity_report(skill_root, rows, required)
        if missing:
            for line in missing:
                print(line)
            print("connectivity gate failed: %d missing path(s)" % len(missing))
            return 2

    baseline_root = str(getattr(args, "baseline_root", "") or skill_root)
    encoder = open_encoder(baseline_root)
    hub = load_hub(os.path.dirname(skill_root))
    cache: Dict[str, Dict[str, Any]] = {}
    resolutions: Dict[str, Dict[str, Any]] = {}
    results: List[Dict[str, Any]] = []
    for row in rows:
        prompt = str(row.get("prompt", ""))
        previous = str(row.get("previous_prompt", "") or "")
        if previous:
            prompt = previous + " " + prompt
        year = str(row.get("year", ""))
        route = resolve_route(route_rows, skill_root, prompt, year, phase_map, topic_map, constants, weak_signals)
        route["packets"] = resolve_packets(
            hub,
            prompt,
            route,
            route_rows,
            lambda rest: decide_route(route_rows, skill_root, rest, year, phase_map, topic_map, constants, weak_signals),
        )
        if hub is not None:
            route = cli_start_route(route, route["packets"], hub["default"])
        result = score_row(skill_root, row, route, cache, encoder, strict=not rev_mode)
        if previous:
            first = resolve_route(route_rows, skill_root, previous, year, phase_map, topic_map, constants, weak_signals)
            expected_type = str(row.get("previous_gold_task_type", "") or "")
            expected_mode = str(row.get("previous_gold_mode", "") or "")
            turn_problems: List[str] = []
            if expected_type and first["type"] != expected_type:
                turn_problems.append("first turn type %s expected %s" % (first["type"], expected_type))
            if expected_mode and first["mode"] != expected_mode:
                turn_problems.append("first turn mode %s expected %s" % (first["mode"], expected_mode))
            if not expected_type and not expected_mode and not first["abstain"]:
                turn_problems.append("first turn did not abstain")
            if turn_problems:
                result["verdict"] = "FAIL"
                result["score"] = str(max(0, int(result["score"]) - 1))
                result["reason"] = ". ".join(turn_problems) + ". " + result["reason"]
        resolutions[str(row.get("id", ""))] = route
        results.append(result)

    parity = parity_findings(rows, resolutions, strict=not args.covers)
    out_dir = os.path.abspath(args.out)
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        fail("cannot create output folder: %s" % os.path.basename(out_dir))
    write_results(os.path.join(out_dir, "results.csv"), results)
    write_report(
        os.path.join(out_dir, "report.md"),
        snapshot_hash,
        os.path.basename(args.corpus),
        rows,
        results,
        parity,
        constants,
        revision,
    )
    failed = sum(1 for result in results if result["verdict"] == "FAIL")
    if failed or parity:
        for finding in parity:
            print(finding)
        print("%s: %d row finding(s), %d parity finding(s)" % (PROGRAM, failed, len(parity)))
        return 1
    print("%s: ok, %d rows passed" % (PROGRAM, len(results)))
    return 0

# ───────────────────────────────────────────────────────────────
# 13. REPLAY MODE
# ───────────────────────────────────────────────────────────────

def guard_and_stub(args: argparse.Namespace) -> Tuple[str, str]:
    """Resolve the guard and the stub CLI to replay.

    Args:
        args: Parsed command line.

    Returns:
        The guard path and the stub path.
    """
    repo_root = os.path.abspath(str(getattr(args, "repo_root", os.path.dirname(SKILL_ROOT))))
    guard = str(getattr(args, "guard", "") or "")
    stub = str(getattr(args, "stub", "") or "")
    if not guard:
        guard = os.path.join(repo_root, GUARD_RELATIVE)
    if not stub:
        stub = os.path.join(repo_root, STUB_RELATIVE)
    return guard, stub


def hostile_body(skill_root: str, case_id: str) -> Tuple[Optional[str], str]:
    """Build the dry-run body of one hostile invoice case.

    Every placeholder is replaced with a run-time generated token, so the
    template never carries a literal value.

    Args:
        skill_root: Absolute skill folder.
        case_id: Case id from the hostile invoice set.

    Returns:
        The body text and an empty error text, or None and the error text.
    """
    path = join_skill(skill_root, HOSTILE_CASES)
    if not os.path.isfile(path):
        return None, "hostile case set missing"
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError) as exc:
        return None, "cannot read the hostile case set: %s" % exc
    case = None
    for item in data.get("cases", []):
        if isinstance(item, dict) and str(item.get("id")) == case_id:
            case = item
            break
    if case is None:
        return None, "hostile case missing: %s" % case_id
    body = str(case.get("template", ""))
    for placeholder in data.get("placeholders", []):
        body = body.replace(str(placeholder), "x" + secrets.token_hex(6))
    return body, ""


def approval_reference(command: Sequence[str]) -> str:
    """Read the approval reference out of one guard command line.

    Args:
        command: Guard arguments for one replay row.

    Returns:
        The reference after --approval, or APPROVED-1 when absent.
    """
    parts = [str(part) for part in command]
    for index, part in enumerate(parts):
        if part == "--approval" and index + 1 < len(parts):
            return parts[index + 1]
    return "APPROVED-1"


def write_journal(path: str, row: Dict[str, Any], digest: str) -> None:
    """Write the run journal entry one replay row needs.

    Args:
        path: Journal file under the run-owned temp root.
        row: Corpus row.
        digest: Digest of the approved payload, computed at run time.
    """
    intent = row.get("intent")
    if intent is None:
        if os.path.exists(path):
            os.remove(path)
        return
    reference = approval_reference(row.get("command", []))
    entry: Dict[str, str] = {
        "approval_reference": reference,
        "new_state": "WRITE_INTENT",
        "batch_key": "batch-replay",
    }
    if intent in ("match", "mismatch"):
        entry["payload_digest"] = digest
        entry["attachment_digest"] = ""
    directory = os.path.dirname(path)
    if not os.path.isdir(directory):
        os.makedirs(directory, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(entry) + "\n")


def replay_row(
    row: Dict[str, Any],
    guard: str,
    base_env: Dict[str, str],
    stub_log: str,
    journal: str,
    key_file: str,
    skill_root: str,
    temp_root: str,
) -> Dict[str, Any]:
    """Replay one refusal or hostile row and score its exit code.

    Args:
        row: Corpus row with an expected_exit code.
        guard: Guard script to run.
        base_env: Test environment for the guard.
        stub_log: Stub invocation log.
        journal: Run journal under the temp root.
        key_file: Generated HMAC key file.
        skill_root: Skill folder that holds the hostile case set.
        temp_root: Run-owned temp root.

    Returns:
        The replay result row.
    """
    env = dict(base_env)
    row_env = row.get("env", {})
    if isinstance(row_env, dict):
        for name, value in row_env.items():
            text = str(value)
            if text == MISSING_WRITER_MARKER:
                text = os.path.join(temp_root, "missing-writer-config")
            env[str(name)] = text
    command = [str(part) for part in row.get("command", [])]
    expected_exit = int(row.get("expected_exit", 0))
    dry_body = row.get("dry_body")
    problems: List[str] = []
    if row.get("kind") == "hostile":
        dry_body, error = hostile_body(skill_root, str(row.get("case_id", "")))
        if error:
            problems.append(error)
    if dry_body is not None:
        env["MONEYBIRD_TEST_DRY_BODY"] = str(dry_body)
    preview_line = ""
    preview_digest = ""
    if row.get("intent") is not None:
        preview_command = [part for part in command if part != "--confirm-write"]
        _preview_status, preview_output = run_process([guard] + preview_command, env)
        preview_line, preview_digest = parse_preview(preview_output)
    digest = preview_digest
    if row.get("intent") == "mismatch":
        digest = flip_digest(preview_digest)
    write_journal(journal, row, digest)
    key_backup = ""
    if row.get("remove_key") and os.path.isfile(key_file):
        key_backup = key_file + ".away"
        os.rename(key_file, key_backup)
    try:
        if row.get("warmup"):
            run_process([guard] + command, env)
        try:
            before_size = os.path.getsize(stub_log)
        except OSError:
            before_size = 0
        status, output = run_process([guard] + command, env)
    finally:
        if key_backup and not os.path.isfile(key_file):
            os.rename(key_backup, key_file)
    new_log = ""
    try:
        with open(stub_log, "r", encoding="utf-8", errors="replace") as handle:
            handle.seek(before_size)
            new_log = handle.read()
    except OSError:
        new_log = ""

    if status != expected_exit:
        problems.append("exit %d, expected %d" % (status, expected_exit))
    expected_stderr = str(row.get("expect_stderr", "") or "")
    if expected_stderr and expected_stderr not in output:
        problems.append("output does not name %r" % expected_stderr)
    if row.get("expect_digest") and not re.search(r"(?m)^payload-digest: [0-9a-f]{64}$", output):
        problems.append("no payload-digest line")
    expected_cli = str(row.get("expect_cli", "") or "")
    if row.get("expect_cli_printed") and expected_cli and expected_cli not in output:
        problems.append("dry-run line %r not printed" % expected_cli)
    if row.get("expect_real"):
        if expected_cli and ("REAL " + expected_cli) not in new_log:
            problems.append("real call %r not recorded" % expected_cli)
        elif not expected_cli and "REAL " not in new_log:
            problems.append("no real call recorded")
    elif "REAL " in new_log:
        problems.append("real call reached")
    if not preview_line and expected_cli and row.get("intent") is not None:
        problems.append("dry run printed no command line")

    return {
        "scenario_id": str(row.get("id", "")),
        "lang": str(row.get("lang", "")),
        "split": str(row.get("split", "")),
        "gold_mode": "REPLAY",
        "gold_task_type": str(row.get("kind", "")),
        "score": "1" if not problems else "0",
        "verdict": "PASS" if not problems else "FAIL",
        "reason": "; ".join(problems) if problems else "exit and command line match",
        "tokens_loaded": "0",
        "t7": "0",
        "reads": "0",
        "command": " ".join(command),
        "expected_exit": str(expected_exit),
        "actual_exit": str(status),
    }


def write_replay_report(
    path: str,
    rows: List[Dict[str, Any]],
    results: List[Dict[str, Any]],
    revision: str,
    guard: str,
    stub: str,
) -> None:
    """Write the replay report with one row per refusal and its exit code.

    Args:
        path: Output file.
        rows: Replay rows.
        results: Replay results in row order.
        revision: Full revision text, empty on a live run.
        guard: Guard that was replayed, as a display path.
        stub: Stub that was replayed, as a display path.

    Raises:
        SystemExit: When the file cannot be written.
    """
    passed = sum(1 for result in results if result["verdict"] == "PASS")
    lines: List[str] = ["# Route replay report", "", "Mode: replay"]
    if revision:
        lines.append("Revision: %s" % revision[:12])
    lines.append("Corpus: %d replay rows" % len(results))
    lines.append("Guard: %s" % os.path.basename(guard))
    lines.append("Stub: %s" % os.path.basename(stub))
    lines.append("")
    lines.append("## Rows")
    lines.append("")
    lines.append("| scenario | kind | command | expected exit | actual exit | verdict |")
    lines.append("|---|---|---|---:|---:|---|")
    for row, result in zip(rows, results):
        lines.append(
            "| %s | %s | %s | %s | %s | %s |"
            % (
                result["scenario_id"],
                result["gold_task_type"],
                result["command"],
                result["expected_exit"],
                result["actual_exit"],
                result["verdict"],
            )
        )
    hostile = [result for result in results if result["gold_task_type"] == "hostile"]
    refused = sum(1 for result in results if result["expected_exit"] != "0")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("- rows passed: %d of %d" % (passed, len(results)))
    lines.append("- refusal rows: %d" % refused)
    lines.append("- hostile case rows: %d" % len(hostile))
    for result in results:
        if result["verdict"] != "PASS":
            lines.append("- %s: %s" % (result["scenario_id"], result["reason"]))
    lines.append("")
    try:
        with open(path, "w", encoding="utf-8", newline="") as handle:
            handle.write("\n".join(lines))
    except OSError as exc:
        fail("cannot write report: %s" % exc)


def run_replay(args: argparse.Namespace) -> int:
    """Replay refusal fixtures through the guard stub.

    Args:
        args: Parsed command line.

    Returns:
        0 when every row returns its recorded exit, 1 on a row finding and
        2 when the guard or the stub is missing.
    """
    skill_root = os.path.abspath(args.skill_root)
    revision = str(getattr(args, "rev_sha", "") or "")
    rows = select_rows(load_corpus(args.corpus), args.covers, "replay")
    if not rows:
        fail("no replay rows match the covers filter")
    guard, stub = guard_and_stub(args)
    if not os.path.isfile(guard):
        fail("guard not found: %s" % guard)
    if not os.path.isfile(stub):
        fail("stub not found: %s" % stub)
    temp_root = tempfile.mkdtemp(prefix="route-replay-replay.", dir=os.environ.get("TMPDIR") or "/tmp")
    try:
        home = os.path.join(temp_root, "home")
        accountant = os.path.join(temp_root, "accountant")
        writer_config = os.path.join(temp_root, "writer-config")
        workspace = os.path.join(accountant, "migration-workspace")
        os.makedirs(os.path.join(home, ".config", "moneybird-cli-writer"))
        os.makedirs(os.path.join(workspace, "RunJournal"))
        os.makedirs(writer_config)
        key_dir = os.path.join(workspace, ".secrets")
        os.makedirs(key_dir, mode=0o700)
        key_file = os.path.join(key_dir, "alias-hmac.key")
        with open(key_file, "w", encoding="utf-8") as handle:
            handle.write(secrets.token_hex(32))
        os.chmod(key_file, 0o600)
        journal = os.path.join(workspace, "RunJournal", "run-journal.jsonl")
        stub_log = os.path.join(temp_root, "invocations.log")
        with open(stub_log, "w", encoding="utf-8"):
            pass
        base_env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": home,
            "LANG": os.environ.get("LANG", "C"),
            "MONEYBIRD_GUARD_TEST": "1",
            "MONEYBIRD_ENV_DIR": accountant,
            "MONEYBIRD_CLI": stub,
            "MONEYBIRD_TEST_LOG": stub_log,
            "MONEYBIRD_TEST_ADMINISTRATION_ID": "PILOT_ADMIN",
            "MONEYBIRD_WRITER_CONFIG_DIR": writer_config,
            "MONEYBIRD_HMAC_KEY_FILE": key_file,
            "MONEYBIRD_PILOT_ADMINISTRATION_ID": "PILOT_ADMIN",
        }
        results: List[Dict[str, Any]] = []
        for row in rows:
            results.append(replay_row(row, guard, base_env, stub_log, journal, key_file, skill_root, temp_root))
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)
    out_dir = os.path.abspath(args.out)
    try:
        os.makedirs(out_dir, exist_ok=True)
    except OSError as exc:
        fail("cannot create output folder: %s" % os.path.basename(out_dir))
    write_results(os.path.join(out_dir, "results.csv"), results, REPLAY_COLUMNS)
    write_replay_report(
        os.path.join(out_dir, "report.md"),
        rows,
        results,
        revision,
        guard,
        stub,
    )
    failed = sum(1 for result in results if result["verdict"] == "FAIL")
    if failed:
        for result in results:
            if result["verdict"] == "FAIL":
                print("%s: %s" % (result["scenario_id"], result["reason"]))
        print("%s: %d replay row finding(s)" % (PROGRAM, failed))
        return 1
    print("%s: ok, %d replay rows passed" % (PROGRAM, len(results)))
    return 0

# ───────────────────────────────────────────────────────────────
# 14. REVISION WORKTREE
# ───────────────────────────────────────────────────────────────

def add_revision_worktree(revision: str) -> Dict[str, str]:
    """Add a temp worktree for one revision.

    Args:
        revision: Revision argument from the command line.

    Returns:
        The worktree root, the temp root, the full revision and the repo.

    Raises:
        SystemExit: When the revision is unknown or the worktree fails.
    """
    repo = os.path.dirname(SKILL_ROOT)
    temp_root = tempfile.mkdtemp(prefix="route-replay-rev.", dir=os.environ.get("TMPDIR") or "/tmp")
    try:
        probe = subprocess.run(
            ["git", "-C", repo, "rev-parse", "--verify", "%s^{commit}" % revision],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("cannot read the revision %s: %s" % (revision, exc))
    if probe.returncode != 0:
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("unknown revision: %s" % revision)
    full = probe.stdout.decode("utf-8", "replace").strip()
    target = os.path.join(temp_root, "worktree")
    try:
        added = subprocess.run(
            ["git", "-C", repo, "worktree", "add", "--detach", target, full],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("cannot add a worktree for %s: %s" % (full[:12], exc))
    if added.returncode != 0:
        detail = added.stderr.decode("utf-8", "replace").strip()
        shutil.rmtree(temp_root, ignore_errors=True)
        fail("cannot add a worktree for %s: %s" % (full[:12], detail))
    return {"root": target, "temp": temp_root, "sha": full, "repo": repo}


def remove_revision_worktree(context: Dict[str, str]) -> None:
    """Remove the temp worktree and its temp root.

    Args:
        context: Mapping returned by add_revision_worktree.
    """
    try:
        subprocess.run(
            ["git", "-C", context["repo"], "worktree", "remove", "--force", context["root"]],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=120,
        )
        subprocess.run(
            ["git", "-C", context["repo"], "worktree", "prune"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=60,
        )
    except (OSError, subprocess.SubprocessError):
        pass
    shutil.rmtree(context["temp"], ignore_errors=True)

# ───────────────────────────────────────────────────────────────
# 15. ENTRY POINT
# ───────────────────────────────────────────────────────────────

def main(argv: List[str]) -> int:
    """Parse arguments and run the selected mode.

    Args:
        argv: Command line arguments without the program name.

    Returns:
        The exit code of the selected mode.
    """
    parser = argparse.ArgumentParser(
        prog=GENERATOR,
        description="Resolve the routing fixture corpus and score the routes offline.",
    )
    parser.add_argument(
        "--mode",
        choices=("resolve", "replay"),
        default="resolve",
        help="resolve scores pure route resolution, replay runs the guard against the stub",
    )
    parser.add_argument(
        "--corpus",
        metavar="PATH",
        default=os.path.join(HERE, CORPUS_NAME),
        help="fixture corpus, default %s" % CORPUS_NAME,
    )
    parser.add_argument(
        "--out",
        metavar="DIR",
        default=DEFAULT_OUT,
        help="output folder for results.csv and report.md",
    )
    parser.add_argument(
        "--skill-root",
        metavar="DIR",
        default=None,
        help="skill folder that holds ROUTER.md and references",
    )
    parser.add_argument(
        "--rev",
        metavar="SHA",
        default="",
        help="score a git worktree of this revision instead of the live tree",
    )
    parser.add_argument(
        "--covers",
        metavar="PHASE/REQ",
        action="append",
        default=[],
        help="only score rows tagged with this covers value, repeatable",
    )
    parser.add_argument(
        "--guard",
        metavar="PATH",
        default="",
        help="guard script to replay, default from the repository root",
    )
    parser.add_argument(
        "--stub",
        metavar="PATH",
        default="",
        help="stub CLI to replay, default from the repository root",
    )
    args = parser.parse_args(argv)
    if args.rev and args.skill_root is not None:
        fail("--rev scores a worktree, so --skill-root is not allowed")
    context: Optional[Dict[str, str]] = None
    try:
        if args.rev:
            context = add_revision_worktree(args.rev)
            args.skill_root = os.path.join(context["root"], SKILL_FOLDER_NAME)
            args.repo_root = context["root"]
            args.baseline_root = SKILL_ROOT
            args.rev_sha = context["sha"]
        else:
            args.skill_root = os.path.abspath(args.skill_root or SKILL_ROOT)
            args.repo_root = os.path.dirname(SKILL_ROOT)
            args.baseline_root = args.skill_root
            args.rev_sha = ""
        if args.mode == "replay":
            return run_replay(args)
        return run_resolve(args)
    finally:
        if context is not None:
            remove_revision_worktree(context)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
