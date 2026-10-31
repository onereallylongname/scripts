# Pager for external commands help text BetterhELP -> belp
#
# External Dependencies
# - bat : used for highlighting and pagination
def belp [cmd: string@command-completer, --no-help, --no-highlight, ...other: string@path-completer] {

  if ($no_help) {
    ^$cmd ...$other | ^bat -l help -f --paging=always
  }

   let help_txt = do -c {^$cmd ...$other --help} | complete

   if ($help_txt.exit_code != 0 ) {
      do {^$cmd ...$other -h} | ^bat -l help -f --paging=always
      return
   }

   $help_txt.stdout | ^bat -l help -f --paging=always
}

def command-completer [token: record] {
  ($token.text | commandline complete --type command)
}

def path-completer [token: record] {
  ($token.text | commandline complete --type path)
}

