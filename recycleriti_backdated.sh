#!/bin/bash

# ==== CONFIGURATION ====
TOTAL_COMMITS=80
START_DATE="2024-12-29"
END_DATE="2025-04-30"
PROJECT_DIR="."  # current directory
GIT_USER_NAME="Animeshhh7"
GIT_USER_EMAIL="animesh.bhattarai2019@gmail.com"
# ========================

git init
git config user.name "$GIT_USER_NAME"
git config user.email "$GIT_USER_EMAIL"

touch .backdate_seed.txt
git add .backdate_seed.txt
git commit -m "Initial commit" --date "$START_DATE"

echo "⌛ Creating backdated commits..."

# Date range
start=$(date -d "$START_DATE" +%s)
end=$(date -d "$END_DATE" +%s)
range=$(( (end - start) / TOTAL_COMMITS ))


declare -a MESSAGES=(
    "Initialize Flutter project structure"
    "Setup folder structure for lib/screens"
    "Design pickup scheduling screen UI"
    "Implement pickup type dropdown"
    "Add quantity selection widget"
    "Integrate calendar for pickup date"
    "Add location pin on map screen"
    "Fix map zoom on location select"
    "Integrate Google Maps Flutter plugin"
    "Handle user permissions for location"
    "Enable location marker drag"
    "Fix map re-centering bug"
    "Test map camera position update"
    "Send map location to backend"
    "Test pickup scheduling API"
    "Fix pickupRequest model mapping"
    "Create MyRequests screen"
    "Fix pickup status not updating"
    "Add loading spinner on schedule"
    "Show toast after pickup success"
    "Implement blog screen list UI"
    "Create blog model"
    "Integrate /educational-content API"
    "Add submit blog form with validation"
    "Fix multiline blog input overflow"
    "Show 'pending approval' status"
    "Display blogs only after approval"
    "Fetch blog list on init"
    "Design event screen layout"
    "Create event participation model"
    "Fix event date parsing error"
    "Enable event join button"
    "Add test for /pickup/schedule"
    "White-box test: auth/login"
    "Black-box test: schedule pickup"
    "Fix async issues with FutureBuilder"
    "UI polish: spacing & colors"
    "Fix bottom nav icons overflow"
    "Add hero animation to map screen"
    "Make map widget stateful"
)

for ((i = 1; i <= TOTAL_COMMITS; i++)); do
    # Calculate commit date
    offset=$(( i * range ))
    commit_date=$(date -d "@$((start + offset))" +"%Y-%m-%dT%H:%M:%S")

    # Random file to touch
    file=$(find lib -type f \( -name "*.dart" -o -name "*.json" \) | shuf -n 1)
    echo "// $RANDOM" >> "$file"

    # Random commit message (focus on pickup map integration in first 15 days)
    if [[ $i -le 25 ]]; then
        message=${MESSAGES[$((RANDOM % 15 + 5))]}  # heavily map-related
    else
        message=${MESSAGES[$((RANDOM % ${#MESSAGES[@]}))]}
    fi

    GIT_AUTHOR_DATE="$commit_date" \
    GIT_COMMITTER_DATE="$commit_date" \
    git commit -am "$message"
done

echo "✅ $TOTAL_COMMITS commits created and backdated from $START_DATE to $END_DATE"
echo "🛠️ Ready to push to GitHub!"
