# Wiki Content Source Files

> **Purpose**: Source markdown files for the claude_rix GitHub Wiki
> **Status**: Synced with https://github.com/JohnGavin/claude_rix/wiki
> **Last Updated**: December 2, 2025

---

## Overview

This directory contains the **source files** for the claude_rix wiki pages. These files are copied to the GitHub wiki repository when creating or updating wiki content.

---

## Current Wiki Pages

| File | Wiki Page | Status | Lines |
|------|-----------|--------|-------|
| `Home.md` | [Home](https://github.com/JohnGavin/claude_rix/wiki) | ✅ Published | 527 |
| `Pkgdown-Quarto-Nix-Issue.md` | [Pkgdown-Quarto-Nix-Issue](https://github.com/JohnGavin/claude_rix/wiki/Pkgdown-Quarto-Nix-Issue) | ✅ Published | 311 |
| `Targets-Pkgdown-Complete-Guide.md` | [Targets-Pkgdown-Complete-Guide](https://github.com/JohnGavin/claude_rix/wiki/Targets-Pkgdown-Complete-Guide) | ✅ Published | 800+ |
| `FAQs.md` | [FAQs](https://github.com/JohnGavin/claude_rix/wiki/FAQs) | ✅ Published | 500+ |
| `Nix-Environment-Troubleshooting.md` | [Nix-Environment-Troubleshooting](https://github.com/JohnGavin/claude_rix/wiki/Nix-Environment-Troubleshooting) | 🔄 Ready to Publish | 837 |

---

## How Wiki Syncing Works

### Publishing to Wiki

The wiki is a separate git repository at `https://github.com/JohnGavin/claude_rix.wiki.git`

**To update wiki pages**:

```bash
# 1. Clone wiki repo
git clone https://github.com/JohnGavin/claude_rix.wiki.git wiki_temp

# 2. Copy updated files
cp WIKI_CONTENT/*.md wiki_temp/

# 3. Commit and push
cd wiki_temp
git add *.md
git commit -m "Update wiki pages"
git push origin master

# 4. Clean up
cd ..
rm -rf wiki_temp
```

### Editing Workflow

1. **Edit source files here** (`WIKI_CONTENT/*.md`)
2. **Test links** in the markdown files
3. **Push to wiki** using the script above
4. **Verify** at https://github.com/JohnGavin/claude_rix/wiki

---

## Directory Structure

```
WIKI_CONTENT/
├── README.md                             (this file)
├── Home.md                               (wiki landing page)
├── Pkgdown-Quarto-Nix-Issue.md          (technical explanation)
├── Targets-Pkgdown-Complete-Guide.md    (implementation guide)
└── FAQs.md                               (common questions)
```

---

## Content Organization

### Main Repository vs Wiki

**Main Repository** (`*.md` files in repo root):
- High-level overviews
- Quick decision matrices
- 100-150 lines per file
- Links to wiki for details

**Wiki** (files in this directory):
- Complete implementation guides
- Detailed troubleshooting
- Step-by-step examples
- 300-800 lines per page

**See**: [DOCUMENTATION_ORGANIZATION_PLAN.md](../DOCUMENTATION_ORGANIZATION_PLAN.md)

---

## Cross-Linking

All files extensively cross-link:
- **Main repo → Wiki**: For detailed guides
- **Wiki → Main repo**: For quick reference
- **Wiki → Wiki**: Between related pages

Example links:
```markdown
# In main repo:
→ See [Wiki: Complete Guide](https://github.com/JohnGavin/claude_rix/wiki/Page-Name)

# In wiki:
→ Back to [Main Repo: QUICKREF.md](https://github.com/JohnGavin/claude_rix/blob/main/FILE.md)
```

---

## Adding New Wiki Pages

1. **Create markdown file** in this directory
2. **Follow naming convention**: Use hyphens, not spaces (e.g., `My-New-Page.md`)
3. **Add cross-links** to/from existing pages
4. **Update `Home.md`** navigation
5. **Push to wiki** using the sync script above

---

## Style Guidelines

- Use clear section headings (`##`, `###`)
- Include "Back to" links at top of page
- Add "Related Documentation" section at bottom
- Use code blocks with syntax highlighting
- Include tables for comparisons
- Add emoji for visual scanning (sparingly)

---

## Related Documentation

- [Main Repo: README.md](../README.md) - Project overview
- [DOCUMENTATION_ORGANIZATION_PLAN.md](../DOCUMENTATION_ORGANIZATION_PLAN.md) - Complete organization strategy
- [Wiki Home](https://github.com/JohnGavin/claude_rix/wiki) - Published wiki

---

**Created**: December 2, 2025
**Purpose**: Maintain wiki source files in version control
**Questions?** Open an issue at https://github.com/JohnGavin/claude_rix/issues
