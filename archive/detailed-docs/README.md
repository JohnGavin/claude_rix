# Archived: Detailed Documentation Files

> **Status**: Replaced by simplified versions + comprehensive wiki
> **Date Archived**: December 2, 2025
> **Reason**: Documentation reorganization for better discoverability

---

## What Happened

These detailed documentation files have been **replaced** by a two-tier system:

### 1. Main Repository (Simplified Quick References)
- **TARGETS_PKGDOWN_OVERVIEW.md** → Replaced `TARGETS_PKGDOWN_SOLUTION.md`
- **NIX_QUICKREF.md** → Replaced `NIX_TROUBLESHOOTING.md`
- **NIX_VS_NATIVE_R_QUICKREF.md** → Replaced `NIX_VS_NATIVE_R_WORKFLOWS.md`

### 2. Wiki (Complete Detailed Guides)
- **Wiki: Targets-Pkgdown-Complete-Guide** → All details from TARGETS_PKGDOWN_SOLUTION.md
- **Wiki: Troubleshooting-Complete-Guide** → All details from NIX_TROUBLESHOOTING.md
- **Wiki: Nix-vs-Native-R-Complete-Guide** → All details from NIX_VS_NATIVE_R_WORKFLOWS.md

---

## Why the Change

**Before** (❌ Problem):
- Main repo files were 500-700 lines each
- Hard to scan for quick answers
- Details buried in long documents

**After** (✅ Solution):
- Main repo: 100-150 lines per file (quick reference)
- Wiki: Full details when needed
- Clear navigation between both

---

## How to Find Content

### For Quick Reference
Look in main repo:
- [TARGETS_PKGDOWN_OVERVIEW.md](../../TARGETS_PKGDOWN_OVERVIEW.md)
- [NIX_QUICKREF.md](../../NIX_QUICKREF.md)
- [NIX_VS_NATIVE_R_QUICKREF.md](../../NIX_VS_NATIVE_R_QUICKREF.md)

### For Detailed Guides
Look in wiki:
- [Wiki: Targets-Pkgdown-Complete-Guide](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide)
- [Wiki: Troubleshooting-Complete-Guide](https://github.com/JohnGavin/claude_rix/wiki/Troubleshooting-Complete-Guide)
- [Wiki: FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs)

---

## Archived Files

| Old File | Lines | Replaced By (Repo) | Replaced By (Wiki) |
|----------|-------|-------------------|-------------------|
| TARGETS_PKGDOWN_SOLUTION.md | 720 | TARGETS_PKGDOWN_OVERVIEW.md | Targets-Pkgdown-Complete-Guide |
| NIX_TROUBLESHOOTING.md | 500+ | NIX_QUICKREF.md | Troubleshooting-Complete-Guide |
| NIX_VS_NATIVE_R_WORKFLOWS.md | 523 | NIX_VS_NATIVE_R_QUICKREF.md | Nix-vs-Native-R-Complete-Guide |

---

## Need the Old Content?

All content from these files has been:
1. ✅ Preserved in git history (commit 489db74 and earlier)
2. ✅ Migrated to wiki pages (nothing lost)
3. ✅ Reorganized for better discoverability

To view old versions:
```bash
git log --all --full-history -- old/detailed-docs/
git show 489db74:TARGETS_PKGDOWN_SOLUTION.md
```

---

**Archived**: December 2, 2025
**Migration**: [DOCUMENTATION_ORGANIZATION_PLAN.md](../../DOCUMENTATION_ORGANIZATION_PLAN.md)
**Questions?** See [Wiki: FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs)
