_default:
    @just --list

alias i := paste-input
paste-input day:
    #!/bin/bash
    set -xeuo pipefail
    FILENAME='input/{{day}}.txt'
    if [[ -f "$FILENAME" ]]; then echo "$FILENAME already exists"; exit 1; fi
    wl-paste > "$FILENAME"

alias e := paste-example
paste-example day:
    #!/bin/bash
    set -xeuo pipefail
    FILENAME='input/{{day}}.example.txt'
    if [[ -f "$FILENAME" ]]; then echo "$FILENAME already exists"; exit 1; fi
    wl-paste > "$FILENAME"

alias t := install-template
install-template day:
    #!/bin/bash
    set -xeuo pipefail
    FILENAME='src/{{day}}.zig'
    if [[ -f "$FILENAME" ]]; then echo "$FILENAME already exists"; exit 1; fi
    cp src/tmpl.zig src/{{day}}.zig
    sed -i 's/const DAY = 0;/const DAY = {{day}};/' "$FILENAME"
