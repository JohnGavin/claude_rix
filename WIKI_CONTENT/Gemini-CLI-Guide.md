# Gemini CLI Guide for Large Codebase Analysis

When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive context window, where possible.
Use `gemini -p` as a tool to leverage Google Gemini's large context capacity.

## When to Use Gemini CLI

Use gemini -p when:
- Analyzing entire codebases or large directories
  - e.g. for R package codebases see https://nrennie.rbind.io/r-pharma-2025-r-packages and the references it cites
  - e.g. leverage https://cran.r-project.org/web/packages/btw/index.html where appropriate 
  - e.g. to connect to gemini via ellmer R package so R commands can be stored in R/setup for reproducibility.
- Comparing multiple large files
- Need to understand project-wide patterns or architecture
- Current context window is insufficient for the task
- Working with files totaling more than 100KB
- Verifying if specific features, patterns, or security measures are implemented
- Checking for the presence of certain coding patterns across the entire codebase
+ when Gemini's context window handles larger codebases than Claude's context
+ No need for --yolo flag for read-only analysis
+ When checking implementations, be specific about what you're looking for to get accurate results

## File and Directory Inclusion Syntax

Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the gemini command:

### Examples:

**Single file analysis:**
`gemini -p "@src/main.py Explain this file's purpose and structure"`

**Multiple files:**
`gemini -p "@package.json @src/index.js Analyze the dependencies used in the code"`

**Entire directory:**
`gemini -p "@src/ Summarize the architecture of this codebase"`

**Multiple directories:**
`gemini -p "@src/ @tests/ Analyze test coverage for the source code"`

**Current directory and subdirectories:**
`gemini -p "@./ Give me an overview of this entire project"`

**Or use --all_files flag:**
`gemini --all_files -p "Analyze the project structure and dependencies"`

### Implementation Verification Examples

**Check if a feature is implemented:**
`gemini -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"`

**Verify authentication implementation:**
`gemini -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"`

**Check for specific patterns:**
`gemini -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"`

**Verify error handling:**
`gemini -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"`

**Check for rate limiting:**
`gemini -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"`

**Verify caching strategy:**
`gemini -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"`

**Check for specific security measures:**
`gemini -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"`

**Verify test coverage for features:**
`gemini -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"`

## Important Notes

- Paths in `@` syntax are relative to your current working directory when invoking gemini
- The CLI will include file contents directly in the context
- No need for `--yolo` flag for read-only analysis
- Gemini's context window can handle entire codebases that would overflow Claude's context
- When checking implementations, be specific about what you're looking for to get accurate results

## References
+ https://ellmer.tidyverse.org/reference/chat_google_gemini.html 
  + leveraging ellmer R package to use gemini 
+ https://github.com/jamubc/gemini-mcp-tool
+ https://www.reddit.com/r/ChatGPTCoding/comments/1lm3fxq/gemini_cli_is_awesome_but_only_when_you_make/

## Gemini Added Memories
- To successfully deploy the Quarto dashboard to GitHub Pages, you need to perform a manual configuration step on GitHub:

1.  Go to your GitHub repository (JohnGavin/daily_dashboard).
2.  Click on 'Settings'.
3.  In the left sidebar, click on 'Pages'.
4.  Under 'Build and deployment', select 'GitHub Actions' as the 'Source'.
5.  Save the changes.
