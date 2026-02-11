# PAI vs Claude Code Agent Teams - Comparative Analysis

> **Document Version:** 1.0
> **Last Updated:** 2026-02-11
> **Status:** Verified Against Official Documentation

## Executive Summary

This document provides a comprehensive technical comparison between two distinct agent orchestration systems:
- **PAI (Personal AI Infrastructure)** - Internal workflow orchestration using Task/subagent_type
- **Claude Code Agent Teams** - Experimental multi-instance collaboration system

Both systems enable parallel AI agent work but serve different use cases and operate with fundamentally different architectures.

---

## Quick Reference Comparison

| Aspect | PAI System | Agent Teams |
|--------|-----------|-------------|
| **Status** | Production Ready | Experimental (Research Preview) |
| **Enablement** | Built-in | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` |
| **Architecture** | Single context window | Multiple independent instances |
| **Communication** | Report to caller only | Peer-to-peer messaging |
| **Coordination** | Centralized (PAI Algorithm) | Self-coordination via task list |
| **Storage** | In-memory | `~/.claude/teams/` + `~/.claude/tasks/` |
| **Token Cost** | Lower (summaries) | Higher (separate instances) |
| **Best For** | Fast productive workflows | Complex collaborative tasks |

---

## Architecture Deep Dive

### PAI System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PAI Algorithm (7 Phases)                  │
│  OBSERVE → THINK → PLAN → BUILD → EXECUTE → VERIFY → LEARN  │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Two-Pass Capability Selection                    │
│  Pass 1: FormatReminder Hook (raw prompt analysis)           │
│  Pass 2: THINK Phase (ISC validation)                        │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Task Tool with subagent_type                │
│  Task({ subagent_type: "Engineer", model: "sonnet" })      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Composition Patterns                             │
│  • Pipeline: A → B → C                                      │
│  • TDD Loop: A ↔ B                                          │
│  • Fan-out: → [A, B, C]                                     │
│  • Fan-in: [A, B, C] → D                                    │
│  • Gate: A → check → B or retry                             │
└─────────────────────────────────────────────────────────────┘
```

**Key Characteristics:**
- All subagents work within **single context window**
- Results summarized back to caller
- Fast execution with model selection (haiku/sonnet/opus)
- No persistent identities
- File-based: `.claude/skills/PAI/`

### Agent Teams Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Team Lead Session                         │
│              (Main Claude Code Instance)                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Shared Coordination Layer                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Task List  │  │   Mailbox    │  │Team Config   │    │
│  │ ~/.claude/   │  │  Messaging   │  │ ~/.claude/    │    │
│  │   tasks/     │  │   System     │  │   teams/      │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Teammate Sessions (Independent)                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │ Teammate A  │  │ Teammate B  │  │ Teammate C  │        │
│  │Own Context  │  │Own Context  │  │Own Context  │        │
│  │Own Window   │  │Own Window   │  │Own Window   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Display Modes                               │
│  • In-process: Single terminal (Shift+Up/Down navigation)    │
│  • Split-pane: tmux/iTerm2 (independent panes)               │
└─────────────────────────────────────────────────────────────┘
```

**Key Characteristics:**
- Each teammate has **independent context window**
- Peer-to-peer messaging via Mailbox
- File-based coordination: `~/.claude/teams/`, `~/.claude/tasks/`
- Teammate selection: Shift+Up/Down (in-process) or click (split-pane)
- File locking for task claiming
- Automatic idle notifications

---

## Feature-by-Feature Comparison

### 1. Agent Creation & Spawning

| Feature | PAI | Agent Teams |
|---------|-----|-------------|
| **Syntax** | `Task({ subagent_type: "Engineer" })` | Natural language request to lead |
| **Agent Types** | Engineer, Architect, Designer, Explore, QATester, Pentester, ClaudeResearcher, GeminiResearcher, GrokResearcher, Intern | Any teammate with custom prompt |
| **Model Selection** | Explicit: `model: "haiku\|sonnet\|opus"` | Inherits from lead or specified |
| **Persistence** | Anonymous (no identity) | Persistent identity (name, voice, backstory) |
| **Spawn Speed** | Instant (same context) | Slower (new instance creation) |

### 2. Communication Patterns

**PAI Communication:**
```
┌──────────┐                    ┌──────────┐
│  Caller  │ ──────────────────→│ Subagent │
│          │ ←────────────────── │          │
└──────────┘   (Result Summary)  └──────────┘
```

**Agent Teams Communication:**
```
┌──────────────┐      ┌──────────────┐
│  Teammate A  │ ←───→│  Teammate B  │
└──────────────┘      └──────────────┘
       ↕                    ↕
┌──────────────┐      ┌──────────────┐
│  Team Lead   │ ←───→│  Teammate C  │
└──────────────┘      └──────────────┘
```

### 3. Task Coordination

**PAI Task System:**
- ISC (In Situ Criteria) created via `TaskCreate`
- Verification via `TaskUpdate`
- Manual coordination by caller
- No dependencies between tasks
- Fan-out pattern for parallel execution

**Agent Teams Task System:**
- Shared task list: `~/.claude/tasks/{team-name}/`
- Task states: Pending, In Progress, Completed
- Task dependencies with automatic unblocking
- File locking prevents race conditions
- Self-coordination: teammates claim unblocked tasks

### 4. Display & Interaction

| Aspect | PAI | Agent Teams |
|--------|-----|-------------|
| **Context Window** | Shared (all agents in same window) | Independent (each has own) |
| **Visibility** | Only summaries returned | Full output visible in panes |
| **Navigation** | N/A (single context) | Shift+Up/Down (in-process) or click (split-pane) |
| **Terminal Support** | Any terminal | tmux/iTerm2 required for split-pane |
| **Windows Support** | Full | Limited (no split-pane in Windows Terminal) |

### 5. Storage & State

**PAI:**
- In-memory task tracking
- No persistent state between sessions
- TaskList/TaskCreate/TaskUpdate for runtime only

**Agent Teams:**
```bash
~/.claude/teams/{team-name}/config.json  # Team configuration
~/.claude/tasks/{team-name}/              # Task list storage
```
- Persistent team configuration
- Task list survives session restarts
- Mailbox for inter-agent messaging

---

## Use Case Analysis

### When to Use PAI (Task/subagent_type)

✅ **Ideal For:**
- Quick research from multiple angles (Fan-out pattern)
- Pipeline workflows (Explore → Architect → Engineer)
- TDD loops (Engineer ↔ QA)
- Simple tasks where only result matters
- Cost-sensitive workflows
- Fast iteration cycles

❌ **Not Ideal For:**
- Complex peer discussion
- Tasks requiring inter-agent debate
- When agents need to challenge each other
- Long-running parallel exploration

**Example PAI Workflow:**
```typescript
// Research from 9 angles in parallel
Task({ subagent_type: "ClaudeResearcher", model: "haiku", description: "Security angle", ... })
Task({ subagent_type: "ClaudeResearcher", model: "haiku", description: "Performance angle", ... })
Task({ subagent_type: "GeminiResearcher", model: "haiku", description: "UX angle", ... })
// ... 6 more researchers

// Spotcheck synthesis
Task({ subagent_type: "Intern", description: "Spotcheck results", ... })
```

### When to Use Agent Teams

✅ **Ideal For:**
- Research requiring peer discussion and challenge
- Debugging with competing hypotheses
- Cross-layer coordination (frontend, backend, tests)
- Code review with multiple perspectives
- Complex feature implementation with clear boundaries
- When agents need to debate and converge

❌ **Not Ideal For:**
- Simple sequential tasks
- Same-file edits (causes conflicts)
- Cost-sensitive workflows
- Tasks with heavy dependencies

**Example Agent Teams Workflow:**
```
"Create an agent team to investigate the authentication bug.
Spawn 5 teammates with different hypotheses.
Have them debate and try to disprove each other's theories.
Update findings doc with consensus."
```

---

## Technical Implementation Details

### PAI Implementation

**Configuration:**
- File: `.claude/skills/PAI/SKILL.md`
- Algorithm: 7-phase structured approach
- Trigger: Automatic (all responses go through Algorithm)

**Key Files:**
```
.claude/skills/PAI/
├── SKILL.md                          # Core algorithm definition
├── Components/
│   ├── Algorithm/                    # ISC and verification
│   └── ...                           # Other components
└── SYSTEM/
    ├── PAIAGENTSYSTEM.md             # Agent system docs
    └── ...
```

**Parallel Execution Pattern:**
```typescript
// All Task calls in ONE message = parallel execution
Task({ subagent_type: "Intern", description: "Task 1" })
Task({ subagent_type: "Intern", description: "Task 2" })
Task({ subagent_type: "Intern", description: "Task 3" })
// ^ All start simultaneously

// Sequential execution requires await
await Task({ subagent_type: "Intern", description: "Task 1" })
await Task({ subagent_type: "Intern", description: "Task 2" })
// ^ Task 2 starts after Task 1 completes
```

### Agent Teams Implementation

**Configuration:**
- Environment: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Settings: `~/.claude/settings.json`
- Display: `teammateMode: "auto" | "in-process" | "tmux"`

**Storage Structure:**
```bash
~/.claude/
├── teams/
│   └── {team-name}/
│       └── config.json              # Members: [{name, agent_id, agent_type}]
└── tasks/
    └── {team-name}/
        └── {task-files}             # Task state with dependencies
```

**Team Config Example:**
```json
{
  "members": [
    {
      "name": "researcher-1",
      "agent_id": "abc123",
      "agent_type": "custom"
    },
    {
      "name": "security-reviewer",
      "agent_id": "def456",
      "agent_type": "custom"
    }
  ]
}
```

**Display Mode Configuration:**
```json
// settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "tmux"  // or "in-process" or "auto"
}
```

**Command-line override:**
```bash
claude --teammate-mode tmux
```

---

## Performance & Cost Analysis

### Token Usage

| Scenario | PAI | Agent Teams |
|----------|-----|-------------|
| **Single agent task** | ~1x (just the agent) | ~1x (just the teammate) |
| **3 parallel researchers** | ~3x (3 agents in shared context) | ~3x (3 independent instances) |
| **Inter-agent discussion** | N/A (not supported) | ~N×M (N agents × M rounds) |
| **Long-running task** | Efficient (shared context) | Expensive (separate contexts) |

**Rule of Thumb:** Agent Teams cost 2-5x more than PAI for similar workflows due to:
- Separate context windows for each teammate
- No summarization (full output retained)
- Inter-agent messaging overhead

### Latency

| Operation | PAI | Agent Teams |
|-----------|-----|-------------|
| **Spawn** | Instant (< 1s) | Slower (2-5s per teammate) |
| **Coordination** | Centralized (fast) | Distributed (slower) |
| **Communication** | Summarization delay | Messaging overhead |
| **Result synthesis** | Immediate (caller has results) | Lead must poll/wait for teammates |

---

## Limitations & Known Issues

### PAI Limitations

1. **No peer communication** - Subagents can't talk to each other
2. **Shared context bottleneck** - All agents share same context window
3. **No persistent identities** - Agents are anonymous
4. **Manual coordination** - Caller must manage agent workflows
5. **Single context window** - Limits complex multi-agent scenarios

### Agent Teams Limitations

1. **Experimental** - Internals may change, API not stable
2. **No session resumption** - `/resume` doesn't restore in-process teammates
3. **Task status lag** - Teammates sometimes fail to mark tasks completed
4. **Slow shutdown** - Teammates finish current request before exiting
5. **One team per session** - Lead can only manage one team
6. **No nested teams** - Teammates can't spawn their own teams
7. **Platform limitations** - Split-pane not supported in:
   - VS Code integrated terminal
   - Windows Terminal
   - Ghostty
8. **tmux dependencies** - Split-pane requires tmux or iTerm2

---

## Decision Tree

```
Need parallel agent work?
│
├─→ Simple, result-focused task?
│   └─→ Use PAI (Task/subagent_type)
│       - Fast, cheap
│       - No inter-agent discussion needed
│
├─→ Need peer discussion/debate?
│   └─→ Use Agent Teams
│       - Agents can message each other
│       - Adversarial investigation possible
│
├─→ Cost-sensitive?
│   └─→ Use PAI
│       - Shared context = lower token usage
│       - Agent Teams = separate contexts = 2-5x cost
│
└─→ Complex, long-running exploration?
    └─→ Use Agent Teams
        - Independent context windows
        - Better for deep parallel investigation
```

---

## Migration Guide

### Migrating from PAI to Agent Teams

**Before (PAI):**
```typescript
Task({ subagent_type: "Intern", description: "Research security", ... })
Task({ subagent_type: "Intern", description: "Research performance", ... })
Task({ subagent_type: "Intern", description: "Research UX", ... })
```

**After (Agent Teams):**
```
Enable: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

Prompt to lead:
"Create an agent team with 3 teammates:
- One researching security implications
- One researching performance impact
- One researching UX considerations

Have them share findings and debate.
Synthesize results into a summary document."
```

### Hybrid Approach

Use PAI within Agent Teams:
```
1. Team Lead spawns 3 teammates for high-level investigation
2. Each teammate uses PAI internally (Task/subagent_type) for subtasks
3. Teammates debate at peer level
4. Lead synthesizes final results
```

---

## Best Practices

### PAI Best Practices

1. **Always use parallel Task calls** - Multiple Task calls in one message = parallel execution
2. **Add Spotcheck agent** - After parallel execution, spawn spotcheck to validate
3. **Use model selection** - `haiku` for simple tasks, `opus` for complex
4. **Apply composition patterns** - Pipeline, TDD Loop, Fan-out based on task
5. **Think in ISC** - Create testable criteria via TaskCreate

### Agent Teams Best Practices

1. **Give enough context** - Teammates don't inherit lead's conversation history
2. **Size tasks appropriately** - Self-contained units with clear deliverables
3. **Avoid file conflicts** - Each teammate owns different files
4. **Monitor and steer** - Check progress, redirect approaches
5. **Use delegate mode** - Prevent lead from implementing (Shift+Tab to toggle)
6. **Start with research/review** - Get familiar with system before complex implementation

---

## Code Examples

### PAI: Pipeline Pattern

```typescript
// Sequential handoff through domains
Task({ subagent_type: "Explore", description: "Explore codebase structure", ... })
// Wait for result, then:
Task({ subagent_type: "Architect", description: "Design architecture", ... })
// Wait for result, then:
Task({ subagent_type: "Engineer", description: "Implement feature", ... })
```

### PAI: Fan-out Pattern

```typescript
// 9 researchers in parallel
Task({ subagent_type: "ClaudeResearcher", description: "Angle 1", model: "haiku" })
Task({ subagent_type: "ClaudeResearcher", description: "Angle 2", model: "haiku" })
Task({ subagent_type: "ClaudeResearcher", description: "Angle 3", model: "haiku" })
Task({ subagent_type: "GeminiResearcher", description: "Angle 4", model: "haiku" })
Task({ subagent_type: "GeminiResearcher", description: "Angle 5", model: "haiku" })
Task({ subagent_type: "GeminiResearcher", description: "Angle 6", model: "haiku" })
Task({ subagent_type: "GrokResearcher", description: "Angle 7", model: "haiku" })
Task({ subagent_type: "GrokResearcher", description: "Angle 8", model: "haiku" })
Task({ subagent_type: "GrokResearcher", description: "Angle 9", model: "haiku" })

// Spotcheck synthesis
Task({ subagent_type: "Intern", description: "Spotcheck results", model: "haiku" })
```

### Agent Teams: Adversarial Investigation

```bash
# Enable first
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Start Claude Code session
claude

# In Claude Code:
"Users report the app exits after one message.
Spawn 5 teammates to investigate different theories:
- Teammate 1: Database connection timeout
- Teammate 2: Memory leak in message handler
- Teammate 3: Unhandled exception in async code
- Teammate 4: WebSocket premature close
- Teammate 5: Authentication token expiry

Have them debate and try to disprove each other's theories.
Update findings doc with whatever consensus emerges."
```

---

## References & Sources

### Official Documentation

- **[Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)** - Complete guide to Agent Teams feature
- **[Settings Documentation](https://code.claude.com/docs/en/settings)** - Configuration reference for `teammateMode` and experimental flags
- **[Documentation Index](https://code.claude.com/docs/llms.txt)** - Full Claude Code documentation index

### Environment Variable

```bash
# Enable Agent Teams
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Display modes
claude --teammate-mode tmux        # Force tmux split-pane
claude --teammate-mode in-process   # Force in-process
```

### Local Documentation

- **PAI Core:** `.claude/skills/PAI/SKILL.md`
- **Agent Teams:** `docs/agent_teams_claudeCode_docs.md`
- **This Document:** `docs/pai_vs_agent_teams_comparison.md`

---

## Changelog

### v1.0 (2026-02-11)
- Initial comparative analysis
- Verified against official Claude Code documentation
- Included architecture diagrams and decision trees
- Added code examples and best practices
- Documented limitations and known issues

---

**Document Status:** ✅ Verified against [official documentation](https://code.claude.com/docs/en/agent-teams)

**Note:** Agent Teams is an experimental feature. Implementation details may change. Always refer to official documentation for latest updates.
