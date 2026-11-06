#!/bin/zsh -f
# Prints each entry of the completion list that the _pont of this repository
# shows for the command line in $1, one on a line, in an interactive zsh.
# Options show as their display line. $COMPLETE_SETUP runs before compinit.
# With --insert as $2, it prints the command line after a TAB and an X instead.
zmodload zsh/zpty || exit 1
completion_dir=${0:A:h:h}
zpty -b complete zsh -f -i
zpty -w complete "PS1='complete> '
fpath=(${(q)completion_dir} \$fpath)
setopt no_list_types
LISTMAX=100000
$COMPLETE_SETUP
zmodload zsh/complist
autoload -Uz compinit && compinit -u -D
zstyle ':completion:*:default' list-colors lc='<LC>' rc='<RC>' ec='<EC>'
function save-line { saved_line=\$BUFFER; BUFFER= }
zle -N save-line
bindkey '^G' save-line
print RE''ADY"
# Line editing starts with the prompt after READY. Keys before it reach the
# terminal driver, which reads ^D as the end of input.
zpty -r complete output '*READY*complete> *'
if [[ $2 == --insert ]]; then
	# The X keeps the space, which a key that inserts nothing removes
	zpty -w -n complete "$1"$'\tX\C-g'
	zpty -w complete 'print -r -- "LI""NE[$saved_line]"'
else
	zpty -w -n complete "$1"$'\C-d\C-u'
fi
zpty -w complete "print DO''NE"
zpty -r complete output '*DONE*'
zpty -d complete
if [[ $2 == --insert ]]; then
	print -r -- "$output" | grep -a -o 'LINE\[.*\]' | tail -n 1 |
		sed -e 's/^LINE\[//' -e 's/\]$//'
else
	print -r -- "$output" | grep -o '<LC>[^<]*<RC>[^<]*<EC>' |
		sed -e 's/^<LC>[^<]*<RC>//' -e 's/<EC>$//' -e '/^ *$/d' | LC_ALL=C sort
fi
