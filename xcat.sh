xcat() {
    # If no arguments provided, print a description and usage message.
    if [ "$#" -eq 0 ]; then
        cat << EOF
xcat: A wrapper for cat that prefixes each file's contents with a header showing the file name and a separator,
      then copies the entire output to the clipboard using xclip.
Usage: xcat [FILE]...
       Example: xcat *.py
EOF
        return 1
    fi

    # Loop through all provided files and print their header and contents.
    for file in "$@"; do
        echo "==> ${file} <=="
        echo "----------------"
        cat "$file"
    done | tee >(xclip -selection clipboard)
}

