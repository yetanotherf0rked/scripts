#!/bin/bash
# ww.sh - Convert paths between Linux and Windows in WSL using wslpath.
#
# Usage:
#   ww [--cd] [--copy] <path>
#
#   - Converts a Linux path to a Windows path.
#   - Converts a Windows path to a Linux path.
#   - With the --cd option and a Windows path, changes directory to the Linux equivalent.
#   - With the --copy option, copies the conversion result to the clipboard.
#
# Aliases defined:
#   wwc  -> ww --copy
#   www  -> ww --copy --cd
#
# Notes:
# - All paths passed to wslpath are quoted to handle spaces correctly.
# - The final output is printed using printf to reliably preserve spaces and backslashes.

ww() {
  # If no arguments are provided, display usage.
  if [ "$#" -eq 0 ]; then
    echo "Usage: ww [--cd] [--copy] <path>"
    echo "Converts Linux paths to Windows paths and vice versa."
    echo "  --cd    Change directory (requires a Windows path input)."
    echo "  --copy  Copy the conversion result to the clipboard."
    return 0
  fi

  local cd_flag=0
  local copy_flag=0
  local input_path=""
  local converted=""

  # Process options and path argument.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --cd)
        cd_flag=1
        ;;
      --copy)
        copy_flag=1
        ;;
      *)
        if [ -z "$input_path" ]; then
          input_path="$1"
        else
          echo "Error: Too many arguments" >&2
          return 1
        fi
        ;;
    esac
    shift
  done

  # Determine conversion direction:
  # If the path starts with a drive letter (e.g., C:), assume it's a Windows path.
  if [[ "$input_path" =~ ^[A-Za-z]: ]]; then
    # Convert Windows -> Linux.
    converted=$(wslpath -u "$input_path" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$converted" ]; then
      echo "Error: Failed to convert Windows path" >&2
      return 1
    fi
  else
    # Convert Linux -> Windows.
    converted=$(wslpath -w "$input_path" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$converted" ]; then
      echo "Error: Failed to convert Linux path" >&2
      return 1
    fi
  fi

  # Handle --cd: Only valid when converting a Windows path.
  if [ $cd_flag -eq 1 ]; then
    if [[ "$input_path" =~ ^[A-Za-z]: ]]; then
      cd "$converted" || { echo "Error: Failed to cd into directory" >&2; return 1; }
    else
      echo "Error: --cd flag requires a Windows path" >&2
      return 1
    fi
  fi

  # Handle --copy: Copy the result to the clipboard using clip.exe.
  if [ $copy_flag -eq 1 ]; then
    echo -n "$converted" | clip.exe || { echo "Error: Failed to copy to clipboard" >&2; return 1; }
  fi

  # Output the result between double quotes.
  printf '"%s"\n' "$converted"
}

# Create convenient aliases.
alias wwc='ww --copy'
alias www='ww --copy --cd'

