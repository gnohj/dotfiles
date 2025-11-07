#!/usr/bin/env bash
# Wrapper for aic that adds gitmoji to commit messages

# Generate commit messages with aic (no args needed, defaults to 5)
if [ $# -eq 0 ]; then
  aic generate 2>&1 | while IFS= read -r line; do
    # Add gitmoji based on conventional commit type
    case "$line" in
      feat*) echo "✨ $line" ;;
      fix*) echo "🐛 $line" ;;
      docs*) echo "📝 $line" ;;
      style*) echo "💄 $line" ;;
      refactor*) echo "♻️ $line" ;;
      perf*) echo "⚡ $line" ;;
      test*) echo "✅ $line" ;;
      build*) echo "📦 $line" ;;
      ci*) echo "👷 $line" ;;
      chore*) echo "🔧 $line" ;;
      *) echo "$line" ;;
    esac
  done
else
  aic generate "$@" 2>&1 | while IFS= read -r line; do
    # Add gitmoji based on conventional commit type
    case "$line" in
      feat*) echo "✨ $line" ;;
      fix*) echo "🐛 $line" ;;
      docs*) echo "📝 $line" ;;
      style*) echo "💄 $line" ;;
      refactor*) echo "♻️ $line" ;;
      perf*) echo "⚡ $line" ;;
      test*) echo "✅ $line" ;;
      build*) echo "📦 $line" ;;
      ci*) echo "👷 $line" ;;
      chore*) echo "🔧 $line" ;;
      *) echo "$line" ;;
    esac
  done
fi
