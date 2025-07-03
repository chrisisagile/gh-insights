#!/bin/bash

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}GitHub Activity Report Generator${NC}"
echo "================================"

# Get current user
USER=$(gh api user -q .login)
echo "User: $USER"
echo "Generated: $(date)"
echo

# Create output directory with current date
OUTPUT_DIR="./insights/$(date +%Y-%m-%d)"
mkdir -p "$OUTPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo

# Search for PRs
echo -e "${GREEN}Searching for Pull Requests...${NC}"

# Use gh search prs command
gh search prs --author="$USER" --limit=1000 --json repository,number,state,createdAt,closedAt,title,labels,url > "$OUTPUT_DIR/prs.json"

# Convert to CSV with proper org/repo extraction
echo "org,repo,pr_number,state,created_at,closed_at,title,is_merged" > "$OUTPUT_DIR/prs.csv"
jq -r '.[] | 
    (.repository.nameWithOwner | split("/")) as $parts |
    [
        $parts[0], 
        $parts[1], 
        .number, 
        .state, 
        .createdAt, 
        .closedAt // "null", 
        .title,
        (if .state == "MERGED" then "yes" else "no" end)
    ] | @csv' "$OUTPUT_DIR/prs.json" >> "$OUTPUT_DIR/prs.csv"

PR_COUNT=$(jq '. | length' "$OUTPUT_DIR/prs.json")
echo "Found $PR_COUNT pull requests"

# Search for issues
echo
echo -e "${GREEN}Searching for Issues...${NC}"

gh search issues --author="$USER" --limit=1000 --json repository,number,state,createdAt,title,isPullRequest,url > "$OUTPUT_DIR/issues_raw.json"

# Filter out PRs and convert to CSV
echo "org,repo,issue_number,state,created_at,title" > "$OUTPUT_DIR/issues.csv"
jq -r '.[] | 
    select(.isPullRequest == false) | 
    (.repository.nameWithOwner | split("/")) as $parts |
    [
        $parts[0], 
        $parts[1], 
        .number, 
        .state, 
        .createdAt, 
        .title
    ] | @csv' "$OUTPUT_DIR/issues_raw.json" >> "$OUTPUT_DIR/issues.csv"

ISSUE_COUNT=$(jq '[.[] | select(.isPullRequest == false)] | length' "$OUTPUT_DIR/issues_raw.json")
echo "Found $ISSUE_COUNT issues"

# Generate report
echo
echo -e "${GREEN}Generating report...${NC}"

# PR statistics
OPEN_PRS=$(grep -c ',"OPEN",' "$OUTPUT_DIR/prs.csv" || echo 0)
CLOSED_PRS=$(grep -c ',"CLOSED",' "$OUTPUT_DIR/prs.csv" || echo 0)
MERGED_PRS=$(grep -c ',"yes"$' "$OUTPUT_DIR/prs.csv" || echo 0)

# Organization breakdown
echo
echo "Organizations with activity:"
tail -n +2 "$OUTPUT_DIR/prs.csv" | cut -d, -f1 | tr -d '"' | sort | uniq -c | sort -nr

# Repository breakdown
echo
echo "Top repositories by PR count:"
tail -n +2 "$OUTPUT_DIR/prs.csv" | cut -d, -f1,2 | tr -d '"' | sed 's/,/\//' | sort | uniq -c | sort -nr | head -15

# Generate comprehensive report
cat > "$OUTPUT_DIR/github_activity_report.txt" <<EOF
GITHUB ACTIVITY REPORT
======================
User: $USER
Generated: $(date)

EXECUTIVE SUMMARY
-----------------
Total Contributions: $((PR_COUNT + ISSUE_COUNT))
- Pull Requests: $PR_COUNT
- Issues: $ISSUE_COUNT

PR Success Rate: $(echo "scale=1; $MERGED_PRS * 100 / $PR_COUNT" | bc 2>/dev/null || echo "0")% merged

PULL REQUEST ANALYSIS
---------------------
Total: $PR_COUNT
- Open: $OPEN_PRS ($(echo "scale=1; $OPEN_PRS * 100 / $PR_COUNT" | bc 2>/dev/null || echo "0")%)
- Closed: $CLOSED_PRS ($(echo "scale=1; $CLOSED_PRS * 100 / $PR_COUNT" | bc 2>/dev/null || echo "0")%)
- Merged: $MERGED_PRS ($(echo "scale=1; $MERGED_PRS * 100 / $PR_COUNT" | bc 2>/dev/null || echo "0")%)

ORGANIZATIONS
-------------
$(tail -n +2 "$OUTPUT_DIR/prs.csv" | cut -d, -f1 | tr -d '"' | sort | uniq -c | sort -nr | awk '{printf "%-20s %d PRs\n", $2":", $1}')

TOP REPOSITORIES
----------------
$(tail -n +2 "$OUTPUT_DIR/prs.csv" | cut -d, -f1,2 | tr -d '"' | sed 's/,/\//' | sort | uniq -c | sort -nr | head -15 | awk '{printf "%3d PRs - %s\n", $1, $2}')

RECENT ACTIVITY (Last 30 PRs)
-----------------------------
$(tail -n +2 "$OUTPUT_DIR/prs.csv" | sort -t, -k5 -r | head -30 | while IFS=, read -r org repo pr state created closed title merged; do
    org=$(echo "$org" | tr -d '"')
    repo=$(echo "$repo" | tr -d '"')
    state=$(echo "$state" | tr -d '"')
    title=$(echo "$title" | tr -d '"' | cut -c1-70)
    created_date=$(echo "$created" | tr -d '"' | cut -dT -f1)
    merged=$(echo "$merged" | tr -d '"')
    
    if [[ "$merged" == "yes" ]]; then
        status="✓ MERGED"
    elif [[ "$state" == "OPEN" ]]; then
        status="● OPEN"
    else
        status="✗ CLOSED"
    fi
    
    printf "%s %s %s/%s #%-4s %s\n" "$created_date" "$status" "$org" "$repo" "$pr" "$title"
done)

MONTHLY ACTIVITY (Last 12 months)
---------------------------------
$(tail -n +2 "$OUTPUT_DIR/prs.csv" | awk -F, '{print substr($5,2,7)}' | sort | uniq -c | sort -k2 -r | head -12 | awk '{printf "%s: %3d PRs\n", $2, $1}')

ISSUE TRACKING
--------------
Total Issues: $ISSUE_COUNT
- Open: $(grep -c ',"OPEN"' "$OUTPUT_DIR/issues.csv" 2>/dev/null || echo 0)
- Closed: $(grep -c ',"CLOSED"' "$OUTPUT_DIR/issues.csv" 2>/dev/null || echo 0)

Recent Issues:
$(tail -n +2 "$OUTPUT_DIR/issues.csv" | sort -t, -k5 -r | head -10 | while IFS=, read -r org repo issue state created title; do
    org=$(echo "$org" | tr -d '"')
    repo=$(echo "$repo" | tr -d '"')
    state=$(echo "$state" | tr -d '"')
    title=$(echo "$title" | tr -d '"' | cut -c1-60)
    created_date=$(echo "$created" | tr -d '"' | cut -dT -f1)
    
    if [[ "$state" == "OPEN" ]]; then
        status="●"
    else
        status="✓"
    fi
    
    printf "%s %s %s/%s #%-4s %s\n" "$created_date" "$status" "$org" "$repo" "$issue" "$title"
done)

EOF

# Additional analysis files
echo
echo -e "${GREEN}Generating additional analysis files...${NC}"

# PR velocity by month
echo "month,count,merged,merge_rate" > "$OUTPUT_DIR/pr_velocity.csv"
tail -n +2 "$OUTPUT_DIR/prs.csv" | awk -F, '
{
    month = substr($5,2,7)
    months[month]++
    if ($8 == "\"yes\"") merged[month]++
}
END {
    for (m in months) {
        rate = merged[m] ? sprintf("%.1f", merged[m] * 100 / months[m]) : "0.0"
        print m "," months[m] "," (merged[m]+0) "," rate
    }
}' | sort -t, -k1 -r >> "$OUTPUT_DIR/pr_velocity.csv"

# Repository activity summary
echo "org,repo,total_prs,open_prs,merged_prs,merge_rate" > "$OUTPUT_DIR/repo_summary.csv"
tail -n +2 "$OUTPUT_DIR/prs.csv" | awk -F, '
{
    key = $1 "," $2
    total[key]++
    if ($4 == "\"OPEN\"") open[key]++
    if ($8 == "\"yes\"") merged[key]++
}
END {
    for (k in total) {
        rate = merged[k] ? sprintf("%.1f", merged[k] * 100 / total[k]) : "0.0"
        print k "," total[k] "," (open[k]+0) "," (merged[k]+0) "," rate
    }
}' | sort -t, -k3 -nr >> "$OUTPUT_DIR/repo_summary.csv"

# Cleanup temp files
rm -f "$OUTPUT_DIR/prs.json" "$OUTPUT_DIR/issues_raw.json"

echo
echo -e "${GREEN}✓ Report generation complete!${NC}"
echo
echo "Files generated:"
echo "  📄 github_activity_report.txt - Comprehensive report"
echo "  📊 prs.csv - All PR data"
echo "  📋 issues.csv - All issue data"
echo "  📈 pr_velocity.csv - Monthly PR velocity"
echo "  📁 repo_summary.csv - Repository statistics"
echo
echo "Summary: $PR_COUNT PRs ($MERGED_PRS merged, $(echo "scale=1; $MERGED_PRS * 100 / $PR_COUNT" | bc)% merge rate)"
echo
echo "To view the report: ${GREEN}cat $OUTPUT_DIR/github_activity_report.txt${NC}"