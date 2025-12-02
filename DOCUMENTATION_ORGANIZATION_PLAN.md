# Documentation Organization Plan

> **Purpose**: Organize claude_rix documentation between main repository (high-level) and wiki (detailed)
> **Date**: December 2, 2025
> **Status**: Ready for implementation

---

## Overview

Split documentation into two tiers:
- **Main Repository**: Executive summaries, quick reference, decision matrices
- **Wiki Pages**: Detailed guides, FAQs, troubleshooting steps, examples

Both heavily cross-linked for easy navigation.

---

## Content Split Strategy

### Principle: Information Hierarchy

```
Main Repo (*.md)           Wiki Pages
════════════════           ══════════
High-level overview    →   Detailed implementation
Quick decision matrix  →   Step-by-step guides
When to use what       →   How to use it
Problem identification →   Complete troubleshooting
Key concepts           →   FAQs and examples
```

### Cross-Linking Pattern

```
┌─────────────────────────────────────────────────────────────┐
│ Main Repo File (NIX_WORKFLOW.md)                           │
│                                                             │
│ ## Quick Start                                              │
│ [5-minute quickstart] - basic concepts only                 │
│                                                             │
│ → **For detailed steps**: See [Wiki: Complete Setup Guide] │
│ → **Troubleshooting**: See [Wiki: Common Issues]           │
│ → **Examples**: See [Wiki: Real-World Workflows]           │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ Wiki: Complete Setup Guide                                  │
│                                                             │
│ [Detailed 30-step setup with screenshots and commands]      │
│ [Common pitfalls and solutions]                             │
│ [Advanced configuration options]                            │
│                                                             │
│ ← **Back to**: [Main Repo: NIX_WORKFLOW.md]                │
└─────────────────────────────────────────────────────────────┘
```

---

## File Mapping

### 1. TARGETS_PKGDOWN_SOLUTION.md (720 lines)

**Main Repo** (150 lines) - `TARGETS_PKGDOWN_OVERVIEW.md`:
- What it is (1 paragraph)
- When to use it (decision matrix)
- Quick architecture diagram
- Benefits vs trade-offs table
- Links to wiki for details

**Wiki Pages**:
- **Complete Implementation Guide** (300 lines)
  - Step-by-step setup
  - All code examples
  - File structure
  - GitHub Actions configuration

- **Troubleshooting & Monitoring** (200 lines)
  - Common issues
  - How to check pipeline status
  - Force rebuild procedures
  - Debugging tips

- **Real-World Examples** (200 lines)
  - statues_named_john case study
  - Multiple vignette setup
  - Parallel rendering
  - Advanced configurations

### 2. NIX_VS_NATIVE_R_WORKFLOWS.md (523 lines)

**Main Repo** (100 lines) - `NIX_VS_NATIVE_R_QUICKREF.md`:
- Decision matrix (table only)
- 3 common scenarios
- Links to detailed workflows

**Wiki Pages**:
- **Complete Decision Guide** (250 lines)
  - All decision criteria explained
  - Detailed comparison tables
  - When NOT to use each approach

- **Workflow Templates Library** (250 lines)
  - Template 1: Pure Nix
  - Template 2: Hybrid
  - Template 3: Pure r-lib/actions
  - Copy-paste ready code

### 3. NIX_TROUBLESHOOTING.md

**Main Repo** (50 lines) - `NIX_QUICKREF.md`:
- 5 most common issues
- Quick fixes (1-2 commands each)
- Links to wiki for details

**Wiki Pages**:
- **Complete Troubleshooting Guide** (split by category)
  - Environment Degradation (full details)
  - Package Installation Issues
  - Build Failures
  - Performance Problems

- **FAQs** (new page)
  - 20-30 common questions
  - Links to detailed troubleshooting

### 4. NIX_WORKFLOW.md

**Main Repo** (100 lines) - Keep existing, simplify:
- Remove detailed examples (→ wiki)
- Keep decision criteria
- Add prominent wiki links

**Wiki Pages**:
- **Complete Workflow Guide**
  - All 9 steps with examples
  - Screenshots where helpful
  - Command-by-command walkthrough

### 5. AGENTS.md (context_claude.md)

**Main Repo** - Keep mostly as-is:
- Core principles and rules
- Quick reference commands
- Links to wiki for detailed guides

**Wiki Pages**:
- **Agent Workflow Examples**
  - Example sessions
  - Common patterns
  - Best practices in detail

### 6. WIKI_NIX_PKGDOWN_ISSUE.md (311 lines)

**Already wiki-ready** - Use as-is:
- Comprehensive explanation
- Copy directly to wiki

---

## Proposed Wiki Structure

### claude_rix Repository Wiki

```
Home
├─ Overview and Navigation
│
Setup & Configuration
├─ Complete Nix Setup Guide
├─ First-Time Project Setup
├─ Environment Configuration
│
Workflows
├─ Complete Development Workflow (9 steps detailed)
├─ Workflow Templates Library
│  ├─ Pure Nix Template
│  ├─ Hybrid Nix + Native R Template
│  └─ Pure r-lib/actions Template
├─ Targets Pipeline Workflows
├─ GitHub Actions Configuration
│
Pkgdown & Documentation
├─ Known Issue: Pkgdown + Quarto + Nix
├─ Targets-Based Pkgdown Solution
│  ├─ Complete Implementation Guide
│  ├─ Troubleshooting & Monitoring
│  └─ Real-World Examples
├─ Pre-building Vignettes
│
Decision Guides
├─ Nix vs Native R: Complete Guide
├─ When to Use Hybrid Workflows
├─ Choosing CI/CD Strategy
│
Troubleshooting
├─ Complete Troubleshooting Guide
│  ├─ Environment Degradation
│  ├─ Package Installation
│  ├─ Build Failures
│  └─ Performance Issues
├─ Common Error Messages
├─ FAQs
│
Examples & Case Studies
├─ statues_named_john: Pkgdown Solution
├─ random_walk: Shinylive Setup
├─ Real-World Multi-Project Setups
│
Reference
├─ Command Reference
├─ Tool Comparison Tables
├─ Package Lists
```

### statues_named_john Repository Wiki

```
Home
├─ Project Overview
│
Known Issues
├─ Pkgdown + Quarto + Nix Incompatibility
│  ├─ Problem Description
│  ├─ Failed Solutions
│  ├─ Working Solution
│  └─ Workflow Diagram
│
Technical Documentation
├─ Data Sources & APIs
│  ├─ GLHER API
│  ├─ Wikidata
│  └─ OpenStreetMap
├─ Targets Pipeline
├─ Vignette Pre-building
│
Development
├─ Getting Started
├─ Local Development Setup
├─ CI/CD Workflows
│
FAQs
├─ Project-Specific Questions
├─ Data Update Frequency
```

---

## Implementation Steps

### Phase 1: Create Wiki Content Files (This PR)

Create wiki-ready markdown files in `/Users/johngavin/docs_gh/claude_rix/WIKI_CONTENT/`:

1. `Home.md` - Wiki landing page
2. `Complete-Nix-Setup-Guide.md`
3. `Workflow-Templates-Library.md`
4. `Targets-Pkgdown-Complete-Guide.md`
5. `Troubleshooting-Complete-Guide.md`
6. `FAQs.md`
7. `Real-World-Examples.md`

### Phase 2: Simplify Main Repo Files

Update existing files to be high-level overviews:

1. `TARGETS_PKGDOWN_SOLUTION.md` → `TARGETS_PKGDOWN_OVERVIEW.md` (150 lines)
2. `NIX_VS_NATIVE_R_WORKFLOWS.md` → `NIX_VS_NATIVE_R_QUICKREF.md` (100 lines)
3. `NIX_TROUBLESHOOTING.md` → `NIX_QUICKREF.md` (50 lines)
4. Update `NIX_WORKFLOW.md` with wiki links
5. Update `AGENTS.md` with wiki links

### Phase 3: User Creates Wiki (Manual)

**User must do this via GitHub web UI**:

1. Go to https://github.com/JohnGavin/claude_rix/wiki
2. Click "Create the first page"
3. Copy content from `WIKI_CONTENT/*.md` files
4. Create wiki pages following proposed structure
5. Enable wiki in repository settings if needed

### Phase 4: Repeat for statues_named_john

Copy `WIKI_NIX_PKGDOWN_ISSUE.md` to statues_named_john wiki.

### Phase 5: Verify Cross-Links

Test all links between repo and wiki work correctly.

---

## Benefits of This Organization

### For New Users

✅ Quick start from main repo
✅ Detailed guidance available in wiki
✅ Clear progression from basics to advanced

### For Experienced Users

✅ Quick reference in repo
✅ Jump straight to specific wiki pages
✅ Find answers faster

### For Maintainers

✅ Main repo stays concise
✅ Wiki can grow without cluttering repo
✅ Easier to update detailed docs

---

## Example: Before vs After

### Before (Current)

```
NIX_TROUBLESHOOTING.md (500 lines)
├─ 1. Environment Degradation (150 lines)
│  ├─ Symptoms (20 lines)
│  ├─ Root Cause (30 lines)
│  ├─ Solutions (50 lines)
│  └─ Examples (50 lines)
├─ 2. Package Installation (150 lines)
├─ 3. Build Failures (100 lines)
└─ 4. Performance (100 lines)

→ User must scroll through 500 lines to find their issue
```

### After (Proposed)

```
Main Repo: NIX_QUICKREF.md (50 lines)
┌─────────────────────────────────────────┐
│ ## Top 5 Issues                         │
│                                         │
│ 1. "command not found"                  │
│    Quick fix: exit; nix-shell           │
│    → [Detailed guide](wiki link)        │
│                                         │
│ 2. Package won't install                │
│    Quick fix: Check DESCRIPTION         │
│    → [Detailed guide](wiki link)        │
│ ...                                     │
└─────────────────────────────────────────┘

Wiki: Complete Troubleshooting Guide
├─ Environment Degradation (full 150 lines)
├─ Package Installation (full 150 lines)
├─ Build Failures (full 100 lines)
└─ Performance (full 100 lines)

→ Quick answer in repo, details in wiki
→ Each issue has dedicated page
→ Easier to find and navigate
```

---

## Next Steps

1. ✅ Create this plan document
2. 🔄 Generate wiki-ready content files
3. 🔄 Simplify main repo files
4. ⏳ User creates wiki pages (manual)
5. ⏳ Verify all cross-links work

---

**Created**: December 2, 2025
**Purpose**: Organize documentation for better discoverability
**Status**: Ready for Phase 1 implementation
