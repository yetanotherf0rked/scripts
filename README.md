# scripts

Handy scripts that I use daily

## ww
Converts Linux paths to Windows paths and vice versa.

**Usage:** ww [--cd] [--copy] <path>

**Aliases:**
- **wwc:** 'ww --copy'
- **www:** 'ww --copy --cd'

## xcat
A wrapper for cat that prefixes each file's contents with a header showing the file name and a separator, then copies the entire output to the clipboard using xclip.

**Usage:** xcat [FILE]...
       Example: xcat *.py

## gluetun
A wrapper for gluetun and NordVPN.

Usage: gluetun <http|socks5> [-p <port>:1080] [-c <country>:Netherlands]
       gluetun --clean (to clean docker containers and sslocal clients)
