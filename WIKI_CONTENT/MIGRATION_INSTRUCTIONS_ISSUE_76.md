# Migration Instructions for Issue #76

> **Issue**: [#76 - Chore: Migrate Nix Troubleshooting Wiki Content and Cross-Reference](https://github.com/JohnGavin/statues_named_john/issues/76)
> **Date**: December 5, 2025
> **Status**: Ready for Manual Execution

---

## Overview

This document provides step-by-step instructions to migrate Nix environment troubleshooting content from the `randomwalk` wiki to the centralized `claude_rix` wiki.

---

## Prerequisites

- Access to GitHub account with write permissions to both wikis
- Git installed and configured
- Terminal access

---

## Step 1: Publish to claude_rix Wiki

### 1.1 Clone the claude_rix Wiki Repository

```bash
cd /Users/johngavin/docs_gh/claude_rix

# Clone the wiki as a separate git repository
git clone https://github.com/JohnGavin/claude_rix.wiki.git wiki_temp
```

### 1.2 Copy the New Troubleshooting Page

```bash
# Copy the prepared wiki content
cp WIKI_CONTENT/Nix-Environment-Troubleshooting.md wiki_temp/
```

### 1.3 Commit and Push to Wiki

```bash
cd wiki_temp

# Add the new file
git add Nix-Environment-Troubleshooting.md

# Commit with descriptive message
git commit -m "Add comprehensive Nix Environment Troubleshooting guide

- Migrated from randomwalk wiki
- Consolidated content from multiple docs
- Addresses issue JohnGavin/statues_named_john#76"

# Push to wiki
git push origin master
```

### 1.4 Verify Publication

Visit: https://github.com/JohnGavin/claude_rix/wiki/Nix-Environment-Troubleshooting

Confirm the page displays correctly with:
- Table of contents
- All sections visible
- Code blocks formatted properly
- Internal links working

### 1.5 Clean Up

```bash
cd /Users/johngavin/docs_gh/claude_rix
rm -rf wiki_temp
```

---

## Step 2: Update randomwalk Wiki

### 2.1 Clone the randomwalk Wiki Repository

```bash
cd /Users/johngavin/docs_gh

# Clone randomwalk wiki
git clone https://github.com/JohnGavin/randomwalk.wiki.git randomwalk_wiki_temp
```

### 2.2 Replace Content with Cross-Reference

```bash
cd randomwalk_wiki_temp

# Backup existing content (optional)
cp Troubleshooting-Nix-Environment.md Troubleshooting-Nix-Environment.md.backup

# Replace content with cross-reference
cat > Troubleshooting-Nix-Environment.md << 'EOF'
# Nix Environment Troubleshooting

> **⚠️ This page has been moved**

## New Location

For up-to-date and comprehensive Nix environment troubleshooting documentation for `claude_rix` projects, please refer to:

**👉 [Nix Environment Troubleshooting (claude_rix wiki)](https://github.com/JohnGavin/claude_rix/wiki/Nix-Environment-Troubleshooting)**

---

## Why Was This Moved?

The Nix troubleshooting content has been consolidated into the main `claude_rix` wiki to:

1. **Centralize documentation** for all claude_rix projects
2. **Improve maintainability** by having a single source of truth
3. **Ensure consistency** across all R package projects using Nix
4. **Reduce duplication** and prevent outdated information

---

## What's in the New Location?

The consolidated guide includes:

- Quick diagnosis checklist
- Environment degradation troubleshooting
- Garbage collection best practices
- Prevention strategies
- Recovery procedures
- Long session management
- Advanced solutions (direnv, flakes)
- Package-specific issues (including pkgdown with Quarto)

---

## Related Documentation

- [claude_rix Wiki Home](https://github.com/JohnGavin/claude_rix/wiki)
- [claude_rix Main Repo](https://github.com/JohnGavin/claude_rix)
- [randomwalk Package](https://github.com/JohnGavin/randomwalk)

---

**Last Updated**: December 5, 2025
**Migration Issue**: [statues_named_john#76](https://github.com/JohnGavin/statues_named_john/issues/76)
EOF
```

### 2.3 Commit and Push

```bash
# Add the modified file
git add Troubleshooting-Nix-Environment.md

# Commit with message
git commit -m "Replace with cross-reference to claude_rix wiki

Content migrated to centralized location:
https://github.com/JohnGavin/claude_rix/wiki/Nix-Environment-Troubleshooting

Addresses issue JohnGavin/statues_named_john#76"

# Push to wiki
git push origin master
```

### 2.4 Verify Cross-Reference

Visit: https://github.com/JohnGavin/randomwalk/wiki/Troubleshooting-Nix-Environment

Confirm:
- Page displays cross-reference message
- Link to new location works
- No broken links

### 2.5 Clean Up

```bash
cd /Users/johngavin/docs_gh
rm -rf randomwalk_wiki_temp
```

---

## Step 3: Update claude_rix Wiki Home Page

### 3.1 Add Link to Navigation

Edit the `Home.md` page on the claude_rix wiki to include a link to the new troubleshooting page in the navigation section.

**Suggested location**: Under "Troubleshooting" or "Reference" section

**Link text**:
```markdown
- [Nix Environment Troubleshooting](Nix-Environment-Troubleshooting) - Complete guide for diagnosing and fixing Nix environment issues
```

---

## Step 4: Verification Checklist

After completing all steps, verify:

- [ ] New page published on claude_rix wiki
- [ ] All sections and formatting correct
- [ ] Code blocks display properly
- [ ] Internal links within page work
- [ ] randomwalk wiki page updated with cross-reference
- [ ] Cross-reference link to new location works
- [ ] Home page navigation updated (if applicable)
- [ ] No broken links on either wiki

---

## Step 5: Close Issue #76

Once all verification complete:

1. Navigate to: https://github.com/JohnGavin/statues_named_john/issues/76
2. Add comment summarizing what was done:

```markdown
## Migration Complete ✅

Successfully migrated Nix environment troubleshooting content:

**Actions Taken**:
- ✅ Created comprehensive troubleshooting page on claude_rix wiki
- ✅ Updated randomwalk wiki with cross-reference
- ✅ Added navigation link to claude_rix wiki home
- ✅ Verified all links working

**Links**:
- New location: https://github.com/JohnGavin/claude_rix/wiki/Nix-Environment-Troubleshooting
- Cross-reference: https://github.com/JohnGavin/randomwalk/wiki/Troubleshooting-Nix-Environment

**Documentation**:
- Source file: `/WIKI_CONTENT/Nix-Environment-Troubleshooting.md`
- Instructions: `/WIKI_CONTENT/MIGRATION_INSTRUCTIONS_ISSUE_76.md`
```

3. Close the issue

---

## Troubleshooting the Migration

### Wiki Clone Issues

**Problem**: `git clone` fails with permission error

**Solution**: Ensure you're authenticated with GitHub:
```bash
gh auth status
# If not authenticated:
gh auth login
```

### Push Permission Denied

**Problem**: Cannot push to wiki repository

**Solution**:
1. Verify you have write access to the repository
2. Check SSH keys are set up: https://github.com/settings/keys
3. Try HTTPS clone instead of SSH

### Content Not Displaying

**Problem**: Wiki page published but content looks wrong

**Solution**:
1. Check markdown syntax is valid
2. Ensure no conflicting filenames
3. Wait a few seconds and refresh (GitHub may cache)
4. Check GitHub wiki edit history for any issues

---

## Related Files

- **Wiki content source**: `/WIKI_CONTENT/Nix-Environment-Troubleshooting.md`
- **Original detailed doc**: `/archive/detailed-docs/NIX_TROUBLESHOOTING.md`
- **Session log**: `/R/setup/wiki_migration_issue_76.R` (to be created)
- **Wiki README**: `/WIKI_CONTENT/README.md`

---

## Questions or Issues?

If you encounter problems during migration:

1. Check the [GitHub wiki documentation](https://docs.github.com/en/communities/documenting-your-project-with-wikis)
2. Review existing wiki pages for reference
3. Open a new issue on statues_named_john repository

---

**Created**: December 5, 2025
**For Issue**: [#76](https://github.com/JohnGavin/statues_named_john/issues/76)
**Estimated Time**: 10-15 minutes
