# From Tasks to Swarms: Agent Teams in Claude Code

import InternalLink from "@features/mdx-components/components/InternalLink.astro";
import Aside from "@features/mdx-components/components/Aside.astro";
import Alert from "@features/mdx-components/components/Alert.astro";
import Prompt from "@features/mdx-components/components/Prompt.astro";
import ExcalidrawSVG from "@features/mdx-components/components/ExcalidrawSVG.astro";
import evolutionDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/evolution.svg?raw";
import subagentsVsTeamsDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/subagents-vs-teams.svg?raw";
import teamPrimitivesDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/team-primitives.svg?raw";
import teamLifecycleDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/team-lifecycle.svg?raw";
import teamLeadControlDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/team-lead-control.svg?raw";
import featureSplitDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/feature-split.svg?raw";
import taskLifecycleDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/task-lifecycle.svg?raw";
import dependencyExecutionDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/dependency-execution.svg?raw";
import qaSwarmLifecycleDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/qa-swarm-lifecycle.svg?raw";
import costComparisonDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/cost-comparison.svg?raw";
import displayInprocessDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/display-inprocess.svg?raw";
import displaySplitpanesDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/display-splitpanes.svg?raw";
import leadSpawnDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/lead-spawn.svg?raw";
import autonomySpectrumDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/autonomy-spectrum.svg?raw";
import decisionGuideDiagram from "@assets/excalidraw/from-tasks-to-swarms-agent-teams-in-claude-code/decision-guide.svg?raw";

In my <InternalLink slug="spec-driven-development-claude-code-in-action">previous post</InternalLink> I covered spec-driven development with Claude Code—using the task system to break large refactors into subagent-driven work. Subagents are powerful, but they have one fundamental limitation: they can only report back to the parent. They can't talk to each other.

Agent teams remove that limitation. They're a new experimental feature in Claude Code where multiple sessions coordinate as a team—with a shared task list, direct messaging between teammates, and a team lead that orchestrates the whole thing.

## Table of Contents

## The Evolution: From Subagents to Agent Teams

This is the progression of delegation in Claude Code. Each step gives the AI more autonomy and less handholding:

<ExcalidrawSVG src={evolutionDiagram} alt="Evolution from solo sessions to subagents to agent teams" caption="Each level adds more AI autonomy and coordination capability" maxWidth="400px" />

<Alert type="info" title="Experimental feature">
Agent teams are disabled by default. Enable them by adding `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to your `settings.json` or environment.
</Alert>

## Subagents vs Agent Teams

The critical difference is communication. Subagents are fire-and-forget workers. Agent teams are collaborators.

<ExcalidrawSVG src={subagentsVsTeamsDiagram} alt="Subagents vs Agent Teams: subagents report one-way to the main agent, while agent teams communicate directly with each other" caption="Subagents report back to main only. Agent teams share findings and coordinate directly." />

|                   | Subagents                    | Agent Teams                           |
| :---------------- | :--------------------------- | :------------------------------------ |
| **Context**       | Own window, results return   | Own window, fully independent         |
| **Communication** | Report to main only          | Message each other directly           |
| **Coordination**  | Main manages everything      | Shared task list, self-claim          |
| **Token cost**    | Lower                        | Higher—each teammate is a full session |
| **Best for**      | Focused tasks, research      | Complex work needing collaboration    |

## The Seven Team Primitives

Agent teams aren't magic. They're built from seven tools that Claude can call. Understanding these tools is the key to understanding how teams actually work under the hood.

<ExcalidrawSVG src={teamPrimitivesDiagram} alt="The seven team primitives organized by category: Setup (TeamCreate), Work (TaskCreate, TaskUpdate, TaskList), Communicate (SendMessage), and Teardown (TeamDelete)" caption="Each primitive maps to a tool call. Together they form the coordination layer." />

Here's each one, with the real calls from my QA session.

### TeamCreate — Start a Team

Creates the team directory and config file. This is always the first call.

```json
// Tool call
TeamCreate({ "team_name": "blog-qa", "description": "QA team testing the blog" })

// Creates on disk:
// ~/.claude/teams/blog-qa/config.json
// ~/.claude/tasks/blog-qa/
```

The `team_name` is the namespace that links everything together—tasks, messages, and the config file all live under it.

### TaskCreate — Define a Unit of Work

Each task is a JSON file on disk. The lead creates these before spawning any teammates.

```json
// Tool call
TaskCreate({
  "subject": "QA: Core pages respond with 200 and valid HTML",
  "description": "Fetch all major pages at localhost:4321 and verify
    they return HTTP 200. Test: /, /posts, /tags, /notes, /tils,
    /search, /projects, /404 (should be 404), /rss.xml...",
  "activeForm": "Testing core page responses"
})

// Creates: ~/.claude/tasks/blog-qa/1.json
```

The `description` is what the teammate actually reads to know what to do. It's essentially a prompt for the agent. The more detail you pack in here (or the lead packs in), the better the agent performs.

### TaskUpdate — Claim and Complete Work

Teammates use this to change task status. It's how work moves through the pipeline.

```json
// Teammate claims a task
TaskUpdate({ "taskId": "1", "status": "in_progress", "owner": "qa-pages" })

// Teammate finishes
TaskUpdate({ "taskId": "1", "status": "completed" })
```

The status field prevents two agents from working on the same thing. When a task is `in_progress` with an owner, other agents skip it.

### TaskList — Find Available Work

Returns all tasks with their current status. Teammates call this after completing a task to find what's next.

```json
// Tool call
TaskList()

// Returns:
// { id: "1", subject: "Core pages...",  status: "completed",   owner: "qa-pages" }
// { id: "2", subject: "Blog posts...",  status: "in_progress", owner: "qa-posts" }
// { id: "3", subject: "Links...",       status: "pending",     owner: ""         }
```

This is the shared coordination mechanism. No centralized scheduler—each teammate polls `TaskList`, finds unowned pending tasks, and claims one.

### Task (with team_name) — Spawn a Teammate

The existing `Task` tool gets a `team_name` parameter that turns a regular subagent into a team member. Once spawned, the teammate can see the shared task list and message other teammates.

```json
// Tool call
Task({
  "description": "QA: Core page responses",
  "subagent_type": "general-purpose",
  "name": "qa-pages",
  "team_name": "blog-qa",
  "model": "sonnet",
  "prompt": "You are a QA agent testing a blog at localhost:4321.
    Your task is Task #1: verify all core pages respond correctly..."
})
```

Notice the `model: "sonnet"` — the lead ran on Opus but spawned all teammates on Sonnet. This is a common cost optimization pattern: expensive model for coordination, cheaper model for execution.

### SendMessage — Talk to Each Other

This is what makes teams different from subagents. Any teammate can message any other teammate directly.

```json
// Teammate → Lead: report findings
SendMessage({
  "type": "message",
  "recipient": "team-lead",
  "content": "Task #1 complete. 16/16 pages pass. No issues found.",
  "summary": "All core pages pass"
})

// Lead → Teammate: request shutdown
SendMessage({
  "type": "shutdown_request",
  "recipient": "qa-pages",
  "content": "All tasks complete, shutting down team."
})

// Teammate → Lead: acknowledge shutdown
SendMessage({
  "type": "shutdown_response",
  "request_id": "shutdown-123",
  "approve": true
})
```

`SendMessage` supports several message types: `message` for direct messages, `broadcast` to reach all teammates at once, `shutdown_request`/`shutdown_response` for graceful teardown, and `plan_approval_response` for quality gates.

### TeamDelete — Clean Up

Removes the team config and all task files from disk. Called after all teammates have shut down.

```json
// Tool call
TeamDelete()

// Removes:
// ~/.claude/teams/blog-qa/
// ~/.claude/tasks/blog-qa/
```

### How They Fit Together

Every team session follows the same tool sequence:

<ExcalidrawSVG src={teamLifecycleDiagram} alt="Team lifecycle: Setup phase creates team and tasks, Execution phase loops through claiming and completing work, Teardown phase shuts down agents and cleans up" caption="Every team session follows this three-phase tool sequence" maxWidth="480px" />

Each teammate is a full Claude Code session with its own context window. They load the same project context (CLAUDE.md, MCP servers, skills) but don't inherit the lead's conversation history. The task files on disk and `SendMessage` are the only coordination channels—there's no shared memory.

## The Team Lead's Control Layer

What makes agent teams more than "just parallel subagents" is the team lead. The lead is an abstraction layer that gives AI more control over coordination:

<ExcalidrawSVG src={teamLeadControlDiagram} alt="Team lead control layer with four quadrants: Observe (who's idle, stuck, done), Coordinate (break work, assign, manage dependencies), Enforce (plan approval, quality gates), and Synthesize (collect findings, resolve conflicts, report, shut down)" caption="The team lead observes, coordinates, enforces quality, and synthesizes results. In delegate mode it only coordinates—otherwise it may implement too." />

## Task Lifecycle in a Team

<ExcalidrawSVG src={taskLifecycleDiagram} alt="Task lifecycle state machine: PENDING to IN_PROGRESS to COMPLETED, with annotations showing teammate claims, work, and dependency unblocking" caption="Tasks move through three states. Teammates self-claim or get assigned by the lead." />

<ExcalidrawSVG src={dependencyExecutionDiagram} alt="Dependency-aware execution showing three waves: Wave 1 runs T1, T2, T3 in parallel, Wave 2 runs T4 and T5 after their dependencies complete, Wave 3 runs T6 last" caption="Tasks execute in waves based on dependency chains. File locking prevents double-claiming." maxWidth="480px" />

## Use Case: Building a Large Feature

When you ask Claude Code to implement something big, agent teams let it parallelize the work the way a real engineering team would:

<Prompt>
Create an agent team to build the new dashboard feature.
One teammate on the API layer, one on the frontend components,
one on the test suite. Use Sonnet for each teammate.
</Prompt>

<ExcalidrawSVG src={featureSplitDiagram} alt="Team lead plans the feature split into 3 tracks: API teammate (schema, endpoints, auth), UI teammate (layout, charts, state), and Test teammate (API tests, UI tests, E2E). Teammates message each other directly, then the lead synthesizes the final PR." caption="The lead breaks work into tracks. Teammates self-coordinate via direct messages." />

The key difference from subagents: when the API teammate finishes the type definitions, it messages the UI teammate directly. No round-trip through the main agent. The test teammate can ask the API teammate to spin up a dev server. They self-coordinate.

## Real Example: QA Swarm Against My Blog

This isn't a hypothetical. I ran this against my own blog before a production deploy. Here's the exact prompt I used:

<Prompt>
Use a team of agents that will do QA against my blog.
It's running at http://localhost:4321/
</Prompt>

That's it. Claude took over from there.

### What the Lead Did

The lead verified the site was running (`curl` returned 200), created a team called `blog-qa`, then broke the work into 5 tasks and spawned 5 agents—all using Sonnet to keep costs down:

<ExcalidrawSVG src={leadSpawnDiagram} alt="The team lead creates the team, creates 5 tasks, and spawns 5 agents—qa-pages, qa-posts, qa-links, qa-seo, and qa-a11y—each assigned to one task" />

### What the Files Look Like

When `TeamCreate` runs, it writes two things to disk. Here's what they actually look like:

```json
// ~/.claude/teams/blog-qa/config.json
{
  "members": [
    { "name": "qa-pages", "agentId": "abc-123", "agentType": "general-purpose" },
    { "name": "qa-posts", "agentId": "def-456", "agentType": "general-purpose" },
    { "name": "qa-links", "agentId": "ghi-789", "agentType": "general-purpose" },
    { "name": "qa-seo",   "agentId": "jkl-012", "agentType": "general-purpose" },
    { "name": "qa-a11y",  "agentId": "mno-345", "agentType": "general-purpose" }
  ]
}
```

And the tasks lived as individual files under `~/.claude/tasks/blog-qa/`. Each task had a subject, a detailed description telling the agent exactly what to check, and a status field:

```json
// ~/.claude/tasks/blog-qa/1.json
{
  "id": "1",
  "subject": "QA: Core pages respond with 200 and valid HTML",
  "description": "Fetch all major pages on the blog at localhost:4321 and verify
    they return HTTP 200 with valid HTML content. Test: /, /posts, /tags, /notes,
    /tils, /search, /projects, /talks, /goals, /prompts, /404 (should be 404),
    /robots.txt, /rss.xml, /llms.txt, /llms-full.txt. Also check that the HTML
    contains expected elements (title, nav, footer).",
  "status": "completed",
  "owner": "qa-pages"
}
```

The lead created these 5 tasks:

| # | Task | Agent | What It Checked |
|---|------|-------|-----------------|
| 1 | Core page responses | `qa-pages` | 16 URLs return correct HTTP status codes |
| 2 | Blog post rendering | `qa-posts` | 83 posts have h1, meta tags, working images |
| 3 | Navigation & link integrity | `qa-links` | 146 internal URLs for broken links |
| 4 | RSS, sitemap, SEO metadata | `qa-seo` | RSS validity, robots.txt, og:tags, JSON-LD |
| 5 | Accessibility & HTML structure | `qa-a11y` | Heading hierarchy, ARIA, theme toggle, lang attr |

### How the Agents Reported Back

Each agent finished independently and sent a structured report back via `SendMessage`. Here's what `qa-pages` sent:

```
## Task #1 Complete: Core Page Response Testing

### Summary: ALL PAGES PASS

| URL         | Expected | Actual | Result |
|-------------|----------|--------|--------|
| /           | 200      | 200    | PASS   |
| /posts      | 200      | 200    | PASS   |
| /tags       | 200      | 200    | PASS   |
| /notes      | 200      | 200    | PASS   |
| /404        | 404      | 404    | PASS   |
| /rss.xml    | 200      | 200    | PASS   |
| /llms.txt   | 200      | 200    | PASS   |
  ...16 URLs tested, 0 failures.
```

Meanwhile `qa-posts` tested all 83 blog posts and found 2 with broken OG images. `qa-seo` found the `og:type` meta tag was missing. `qa-a11y` caught that `<html>` had `class="false"` (a boolean stringified as a class name) and a heading hierarchy issue.

### The Lead's Synthesis

Once all 5 agents reported back, the lead compiled a single prioritized report:

```
## QA Report — alexop.dev

5 agents | 146+ URLs tested | 83 blog posts checked

### Issues by Severity

MAJOR (4):
  1. <html class="false"> — boolean stringified as CSS class
  2. <h2> before <h1> — newsletter banner breaks heading order
  3. Theme toggle button missing from DOM
  4. Theme hardcoded to dark only

MEDIUM (2):
  5. og:type meta tag missing on all pages
  6. 2 blog posts with broken OG images

MINOR (4):
  7-10. Various small accessibility gaps
```

Then the lead sent `shutdown_request` to each agent, they acknowledged, and `TeamDelete` cleaned up the files.

### The Full Lifecycle

<ExcalidrawSVG src={qaSwarmLifecycleDiagram} alt="Full QA swarm lifecycle: user prompt flows to lead, lead fans out to 5 parallel agents (pages, posts, links, seo, a11y), results converge back, lead synthesizes 10 prioritized issues, then shuts down the team" caption="The full lifecycle from prompt to prioritized QA report" />

The whole thing—from prompt to final report—took about 3 minutes. Each agent used `curl` to fetch pages and parse the HTML. No browser automation, no test framework. Just 5 Claude sessions hammering a dev server in parallel.

## The Cost Trade-off

Agent teams are token-heavy. Every teammate is a full Claude Code session with its own context window.

<ExcalidrawSVG src={costComparisonDiagram} alt="Token cost comparison: Solo session uses ~200k tokens, 3 Subagents use ~440k tokens, 3-Person Team uses ~800k tokens" caption="More agents = more tokens = more cost. Each teammate is a full context window." />

The math is simple: more agents = more tokens = more cost. Use teams when the coordination benefit justifies it. For routine tasks, a single session or subagents are more cost-effective.

### When Teams Are Worth It

<ExcalidrawSVG src={decisionGuideDiagram} alt="Decision flowchart: small bug fix leads to solo session, report-back tasks lead to subagents, multi-file features lead to subagents with tasks, and when workers need to talk use agent teams" caption="Start simple — only reach for teams when workers genuinely need to coordinate" maxWidth="520px" />

## Getting Started

Enable agent teams:

```json
// .claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Then tell Claude what you want:

<Prompt>
Create an agent team to refactor the authentication module.
One teammate on the backend logic, one on the frontend hooks,
one running tests continuously. Require plan approval before
any teammate makes changes.
</Prompt>

### Recipe: Plan First, Parallelize Second

The most effective pattern I've found isn't jumping straight into a team. It's a two-step approach: **plan first with plan mode, then hand the plan to a team for parallel execution.**

Here's the workflow:

**Step 1 — Get a plan.** Start with plan mode (`/plan` or tell Claude to plan). Let it explore the codebase, identify files, and produce a step-by-step implementation plan. Review it. Adjust it. This is cheap—plan mode only reads files.

<Prompt>
Plan the refactor of our authentication module. I want to split the
monolithic auth.ts into separate files for JWT handling, session
management, and middleware. Show me the plan before doing anything.
</Prompt>

Claude produces something like:

```
Plan:
1. Create src/auth/jwt.ts — extract token signing/verification
2. Create src/auth/sessions.ts — extract session logic
3. Create src/auth/middleware.ts — extract Express middleware
4. Update src/auth/index.ts — re-export public API
5. Update 12 import sites across the codebase
6. Update tests in src/auth/__tests__/
```

**Step 2 — Parallelize the plan with a team.** Once you approve the plan, tell Claude to execute it as a team. The key insight: the plan already has the task breakdown. You're just telling Claude to run independent tracks in parallel instead of sequentially.

<Prompt>
Now execute this plan using an agent team. Parallelize where possible—
steps 1-3 can run in parallel since they're independent extractions.
Step 4-5 depends on 1-3. Step 6 depends on everything.
Use Sonnet for the teammates.
</Prompt>

The lead sees the dependency graph and spawns teammates accordingly:

```
Wave 1 (parallel):  jwt.ts + sessions.ts + middleware.ts  → 3 teammates
Wave 2 (after wave 1): index.ts barrel + update imports   → 1-2 teammates
Wave 3 (after wave 2): update tests                       → 1 teammate
```

This works because plan mode gives you the checkpoint to review before spending tokens on a full team. Without the plan step, the team lead has to figure out the task breakdown itself—which it can do, but you lose the chance to steer it. With the plan, you've already shaped the work. The team just executes it faster.

<Alert type="tip" title="Why this beats jumping straight to a team">
Plan mode costs ~10k tokens. A team that goes in the wrong direction costs 500k+. Spending a few seconds reviewing a plan saves you from expensive course corrections mid-swarm.
</Alert>

### Display Modes

<ExcalidrawSVG src={displayInprocessDiagram} alt="In-process display mode: all teammates in one terminal, switch with Shift+Up/Down, task list with Ctrl+T" caption="Works everywhere. All teammates share a single terminal." maxWidth="400px" />

<ExcalidrawSVG src={displaySplitpanesDiagram} alt="Split panes display mode: Lead, Teammate A, and Teammate B each in their own pane" caption="See all output at once. Requires tmux or iTerm2." maxWidth="480px" />

## The Abstraction Ladder

<ExcalidrawSVG src={autonomySpectrumDiagram} alt="Autonomy spectrum: Solo Session (you direct every step), Subagents + Task System (AI delegates, you monitor), Agent Teams (AI coordinates multiple sessions, you set goals)" caption="Each level trades control for compute" maxWidth="480px" />

Each level trades control for compute. Solo sessions give you full control but limited throughput. Agent teams give you maximum compute but you're trusting the AI to coordinate itself. The sweet spot depends on your task.

<Aside type="note" title="Limitations to Know">
Agent teams are experimental. Key limitations:
- No session resumption for in-process teammates
- Task status can lag—teammates sometimes forget to mark tasks complete
- One team per session, no nested teams
- Split panes require tmux or iTerm2 (not VS Code terminal)
- All teammates start with the lead's permission settings
</Aside>

## Conclusion

- Agent teams let multiple Claude Code sessions **communicate with each other**, not just report to a parent
- A team lead orchestrates, observes, and synthesizes—another abstraction layer where AI manages AI
- Best use cases: **large features** (parallel tracks), **QA swarms** (multiple testing perspectives), **competing hypotheses** (debate and converge)
- The trade-off is real: more agents = more tokens = more cost
- **Best recipe**: plan first with plan mode (cheap), then hand the plan to a team for parallel execution (expensive but fast). The plan gives you a checkpoint before committing tokens.
- Start with subagents for focused work, graduate to teams when workers need to coordinate
- For background on the task system that teams build on, see my <InternalLink slug="spec-driven-development-claude-code-in-action">spec-driven development post</InternalLink>