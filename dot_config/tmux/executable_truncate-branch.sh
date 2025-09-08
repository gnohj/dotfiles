#!/usr/bin/env bash

# Read gitmux output from stdin or as argument
input="${1:-$(cat)}"

if [ -n "$input" ]; then
  # Use perl to truncate branch names with 3 or more hyphens
  echo "$input" | perl -pe '
    # Find branch names after ] and before space
    if (/\]([A-Za-z0-9_-]+)(\s)/) {
      my $branch = $1;
      my $space = $2;
      
      # Count hyphens
      my $hyphen_count = ($branch =~ tr/-//);
      
      # If 3 or more hyphens, remove last segment
      if ($hyphen_count >= 3) {
        $branch =~ s/-[^-]*$//;
        s/\]([A-Za-z0-9_-]+)(\s)/]${branch}${space}/;
      }
    }
  '
fi
