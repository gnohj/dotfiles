#!/usr/bin/env bash
# Generate plain, brief commit messages without conventional commit format or emojis

# Get the staged diff
DIFF=$(git diff --cached --stat)
DIFF_CONTENT=$(git diff --cached)

if [ -z "$DIFF" ]; then
  echo "No staged changes"
  exit 1
fi

# Get GitHub token for API
TOKEN=$(gh auth token 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "Failed to get GitHub token"
  exit 1
fi

# Create the prompt for plain commit messages
read -r -d '' PROMPT << 'EOF'
Generate 5 brief, plain commit messages for these changes. Rules:
- NO conventional commit prefixes (no feat:, fix:, chore:, etc.)
- NO emojis
- Keep it simple and descriptive like: "updated header styles", "fixed login button alignment", "added user validation"
- Use lowercase
- Be brief (under 50 chars if possible)
- Each message on its own line, nothing else

Changes:
EOF

# Call the API
RESPONSE=$(curl -s "https://models.inference.ai.azure.com/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "$(jq -n \
    --arg prompt "$PROMPT" \
    --arg diff "$DIFF_CONTENT" \
    '{
      model: "gpt-4o",
      messages: [
        {role: "system", content: "You generate brief, plain git commit messages. No emojis. No conventional commit prefixes. Just simple descriptions."},
        {role: "user", content: ($prompt + "\n\n" + $diff)}
      ],
      max_tokens: 256,
      temperature: 0.7
    }')" 2>/dev/null)

# Extract and output the messages
echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null | grep -v '^$' | head -5
