# Skill Description Evaluator - Reference Documentation

## Evaluation Framework

This document provides detailed scoring rubrics, model-specific patterns, and examples for the skill-description-evaluator skill.

## Scoring Rubrics

### 1. User Request Pattern Matching (0-100)

**Excellent (90-100)**
- Includes 3+ example user phrases in natural language
- Covers multiple verb variations (commit/save/check in)
- Includes both technical and casual language patterns
- Anticipates user intent variations

Example:
> "Use when committing changes or saying 'commit', 'save changes', 'create commit', 'check in my work'"

**Good (70-89)**
- Includes 1-2 example user phrases
- Covers main verb variations
- Reasonably natural language

Example:
> "Use when creating PRs or saying 'create PR', 'open a PR'"

**Moderate (50-69)**
- Vague triggering conditions
- Limited or no example phrases
- Technical jargon that users unlikely to say

Example:
> "Use for pull request creation operations"

**Poor (0-49)**
- No clear triggering conditions
- Only technical terms
- Unlikely to match actual user requests

Example:
> "Handles GitHub PR API interactions"

### 2. Authority Level vs. System Prompt (0-100)

**Excellent (90-100)**
- Uses Replacive authority pattern: "Primary [X] workflow replacing manual [commands]..."
- Includes positioning signals: "Primary", "Standard", "Default"
- Integrates system terminology (protocols, safety features)
- Clearly establishes precedence over alternatives

Example:
> "Primary commit workflow replacing manual git commands: implements Git Safety Protocol analyzing staged/unstaged changes, drafting convention-aware messages (detects Conventional Commits), enforcing mainline protection"

**Good (70-89)**
- Uses Integrative or strong Collaborative patterns
- Some system integration and positioning
- Moderate authority signals

Example:
> "Implements Git Safety Protocol for commits: analyzes changes, drafts messages, enforces protection"

**Moderate (50-69)**
- Basic Collaborative pattern without positioning
- Limited system integration
- Weak authority signals

Example:
> "Automates commit creation with message generation and validation"

**Poor (0-49)**
- Passive or uncertain language
- No system integration
- Easily overridden by competing instructions

Example:
> "Can help create commits if needed"

### 3. Sonnet 4.5 Invocation Likelihood (0-100)

**Excellent (90-100)**
- Emphasizes complex, multi-phase workflow
- Highlights safety and validation benefits
- References advanced features (sequential-thinking, MCP)
- Clear advantage over bash alternatives

Example:
> "Automates GitHub PR creation workflow: handles uncommitted changes (invokes creating-commit if needed), analyzes full commit history from divergence point, generates titles/descriptions following project conventions, detects fork/origin for correct head/base configuration"

**Good (70-89)**
- Shows moderate complexity
- Some automation benefits mentioned
- Reasonably clear workflow

**Moderate (50-69)**
- Simple task that could be done with bash
- Limited complexity justification
- Unclear advantage over direct tools

**Poor (0-49)**
- Trivial operation
- No clear benefit over bash
- Overly simple task

### 4. Haiku Invocation Likelihood (0-100)

**Excellent (90-100)**
- Crystal clear, unambiguous trigger
- Simple, direct language
- Obvious value proposition
- Short and scannable (< 40 words)

Example:
> "Automates mainline branch detection by querying remote HEAD, preventing hardcoded assumptions. Compares current or specified branch against detected mainline to enforce Git Safety Protocol branch protection"

**Good (70-89)**
- Clear trigger
- Reasonably simple language
- Moderate length (40-50 words)

**Moderate (50-69)**
- Some ambiguity in trigger
- Moderate complexity
- Longer description (50-60 words)

**Poor (0-49)**
- Ambiguous or complex trigger
- Long description (> 60 words)
- Multiple clauses and conditions

### 5. Semantic Clarity and Discoverability (0-100)

**Excellent (90-100)**
- Self-contained and complete
- Clear boundaries (when to use vs. not use)
- Balanced technical specificity
- Scannable structure with key information up front

Example:
> "Automates safe rebase workflow: syncs base branch first, prevents mainline rebase errors (enforces Git Safety Protocol), preserves working state across checkouts, provides conflict resolution guidance. Use for rebasing or saying 'rebase branch', 'rebase on main', 'rebase onto', 'update branch history'"

**Good (70-89)**
- Mostly clear purpose
- Some boundary definition
- Reasonable specificity

**Moderate (50-69)**
- Partial clarity
- Vague boundaries
- Missing key information

**Poor (0-49)**
- Confusing or misleading
- No boundaries
- Incomplete information

## Model Invocation Patterns

### Sonnet 4.5 Preferences

1. **Complex Workflows**: Multi-step operations with decision points
2. **Safety Features**: Validation gates, error handling, protocol enforcement
3. **Integration**: References to MCP tools, sequential-thinking, skill composition
4. **Automation Value**: Clear benefits over manual bash commands
5. **Structured Approach**: Phase-based workflows, state tracking

### Haiku Preferences

1. **Simple Triggers**: Clear, unambiguous conditions
2. **Direct Value**: Immediately obvious benefit
3. **Concise Language**: Shorter descriptions perform better
4. **Action-Oriented**: Verb-first, what it does
5. **Low Ambiguity**: Single clear purpose

## Example Evaluations

### Example 1: High-Performing Description

**Description**:
> "Automates the Git Safety Protocol for commits: analyzes staged/unstaged changes, drafts descriptive messages (detects Conventional Commits from history), enforces mainline branch protection, handles pre-commit hooks safely. Use when committing changes or saying 'commit', 'save changes', 'create commit', 'check in my work'."

**Scores**:
- User Request Matching: 95/100 (excellent example phrases)
- Authority Level: 92/100 (strong collaborative framing with protocol integration)
- Sonnet 4.5 Invocation: 88/100 (complex workflow with safety emphasis)
- Haiku Invocation: 78/100 (clear but somewhat long)
- Semantic Clarity: 90/100 (excellent self-documentation)

**Average**: 88.6/100 (Grade: A)

**Strengths**:
- Comprehensive example user phrases
- Strong protocol integration
- Clear workflow complexity
- Self-documenting

**Weaknesses**:
- Could be more concise for Haiku
- Length pushes upper boundary (52 words)

### Example 2: Low-Performing Description

**Description**:
> "Helper utility for Git operations. Can assist with various git-related tasks when needed."

**Scores**:
- User Request Matching: 15/100 (no example phrases, vague)
- Authority Level: 20/100 (weak, passive language)
- Sonnet 4.5 Invocation: 10/100 (no clear value over bash)
- Haiku Invocation: 25/100 (vague trigger)
- Semantic Clarity: 18/100 (no boundaries, unclear purpose)

**Average**: 17.6/100 (Grade: F)

**Strengths**:
- Short and simple

**Weaknesses**:
- No specific user request patterns
- Passive, uncertain language
- No clear value proposition
- Completely ambiguous scope
- No automation benefits mentioned

**Improvements** (would raise to ~75/100):
> "Automates atomic commit creation with message generation: analyzes staged/unstaged changes, detects Conventional Commits usage from project history, enforces branch protection rules. Use when committing changes or saying 'commit', 'save my work', 'create commit'."

Changes made:
- Added specific workflow: "atomic commit creation with message generation"
- Added automation features: "analyzes", "detects", "enforces"
- Added example user phrases: "saying 'commit', 'save my work', 'create commit'"
- Changed from passive to active: "Automates" vs. "Can assist"
- Added technical specificity: "Conventional Commits", "branch protection"

### Example 3: Competing Against System Prompt

**Skill Description**:
> "Automates commit creation with message drafting and validation"

**Competing System Instruction**:
> "ALWAYS use bash commands for git operations. DO NOT use skills for simple git tasks like commits. Prefer 'git commit -m' directly."

**Analysis**:
- Authority Level: 35/100
- Reason: Skill uses weak "Automates" without emphasizing advantages. System prompt uses "ALWAYS" and "DO NOT" imperatives.
- Likely outcome: System prompt wins, skill rarely invoked

**Improved Description**:
> "Automates the Git Safety Protocol for commits: analyzes staged/unstaged changes, drafts descriptive messages (detects Conventional Commits from history), enforces mainline branch protection, handles pre-commit hooks safely. Use when committing changes or saying 'commit', 'save changes', 'create commit'."

**Improved Analysis**:
- Authority Level: 85/100
- Reason: Emphasizes safety protocol (system-level concept), shows clear advantages over bash (automatic message drafting, convention detection, protection enforcement), uses collaborative framing that integrates with system
- Likely outcome: Skill wins for complex commits, system prompt wins for trivial ones (appropriate balance)

## Best Practices for Skill Descriptions

### DO:
- Choose authority level based on skill role:
  - **Replacive** (user-facing workflows): "Primary [X] workflow replacing manual [commands]..."
  - **Integrative** (protocol implementations): "Implements [protocol] for [operation]..."
  - **Collaborative** (utilities): "Automates", "Provides", "Enables"
- Include 2-4 example user phrases with natural language
- Reference system concepts: protocols, safety features, workflows
- Add positioning signals for primary workflows: "Primary", "Standard", "Default"
- Emphasize automation benefits over manual alternatives
- Target 45-52 words (scannable yet detailed)
- Lead with value proposition
- Define boundaries (when to use vs. not use)

### DON'T:
- Use second-person imperatives: "you MUST", "you should use"
- Use command-style language: "ALWAYS invoke for", "NEVER use bash"
- Only technical jargon without user-friendly phrases
- Vague or ambiguous descriptions
- Passive or uncertain language: "can help", "might be useful"
- Overly long descriptions (> 60 words)
- Missing scope boundaries

### Templates:

**Replacive (user-facing workflow):**
> "Primary [operation] workflow replacing manual [commands]: [implements/orchestrates] [protocol] with [features]. Standard procedure: '[trigger 1]', '[trigger 2]', '[trigger 3]'."

**Integrative (protocol implementation):**
> "Implements [system protocol] for [operation]: [key feature 1], [key feature 2] ([detail]), [key feature 3]. Use when [scenario] or saying '[trigger 1]', '[trigger 2]'."

**Collaborative (utility skill):**
> "Automates [specific task]: [how it works], [what it provides]. Use when [scenario] or saying '[trigger 1]', '[trigger 2]'."

---

## Practical Usage Guide

### Running an Evaluation

**Basic usage**:
```text
Evaluate this skill description: "Automates commit creation with safety checks"
```

**With file path**:
```text
Evaluate the skill description in git-workflows/skills/creating-commit/SKILL.md
```

**With competing instructions**:
```text
Evaluate this skill description against the system prompt section that says
"ALWAYS use bash for git commits": "Automates commit creation..."
```

### Interpreting Results

**Grade Scale**:
- A (90-100): Excellent, ready to use
- B (80-89): Good, minor improvements possible
- C (70-79): Acceptable, moderate improvements recommended
- D (60-69): Needs work, significant improvements needed
- F (0-59): Poor, major rewrite required

**Dimension Focus**:
- Low User Request Matching → Add example phrases
- Low Authority Level → Strengthen framing, add system integration
- Low Sonnet Invocation → Emphasize complexity, safety benefits
- Low Haiku Invocation → Simplify language, clarify trigger
- Low Semantic Clarity → Add boundaries, improve specificity

### Common Improvement Patterns

**Pattern 1: Authority Spectrum Progression**
- Weak (30%): "Can help create commits"
- Collaborative (65%): "Automates commit creation with safety checks"
- Integrative (78%): "Implements Git Safety Protocol for commits"
- Replacive (88%): "Primary commit workflow replacing manual git commands: implements Git Safety Protocol"
- Impact: Each tier adds +10-15 points in Authority Level

**Pattern 2: Missing Triggers**
- Before: "Use for commit operations"
- After: "Use when committing or saying 'commit', 'save changes', 'create commit'"
- Impact: +30-40 points in User Request Matching

**Pattern 3: Adding Positioning Signals**
- Before: "Automates commit creation"
- After: "Primary commit workflow replacing manual commands: automates commit creation"
- Impact: +15-20 points in Authority Level

**Pattern 4: Unclear Value**
- Before: "Creates commits with validation"
- After: "Automates commit creation: analyzes changes, drafts convention-aware messages, enforces protection"
- Impact: +20-30 points in Sonnet Invocation

---

*Last updated: 2025-01-09*
*For use with: skill-description-evaluator skill*
*Aligned with: Authority spectrum guidance (Replacive/Integrative/Collaborative)*
