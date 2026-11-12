# Pager for external commands help text BetterhELP -> belp
#
# External Dependencies:
# - bat : used for highlighting and pagination
#
# Usage:
#  - source belp.nu
#  - belp [cmd]
#
# Version: 0.2.0
# Author: onerellylongname
# License: MIT


# Easily get help text for most cli programs. This script attempts to always get some info
#
# usage belp [cmd ...subcmds]
def belp [
    cmd: string@belp-command-completer             # The command to get the help for
    ...subs: string                                # The additional parameters
    --no-color                                     # Do not highlight output
    --no-paging                                    # Do not use pager
    --mode (-m) = "auto": string@belp-help-methods # Choose a help method. Default is auto, the less efficient mode.
                                                   # auto -> [cmd ...] : Try to all methods until one works
                                                   # help -> [cmd ...] --help
                                                   # h -> [cmd ...] -h
                                                   # help-cmd -> [cmd] help [...]
                                                   # help-sub -> [cmd ...] help
                                                   # help-flag -> [cmd] --help [...]
                                                   # man -> man [cmd ...]
                                                   # pass-through -> [cmd ...]
] {
  let bat_args = []

  let bat_args = if $no_color {
      ($bat_args | append "--plain")
  } else {
      ($bat_args | append "-l" | append "man")
  }

  let bat_args = if $no_paging {
      ($bat_args | append "--paging=never")
  } else {
      ($bat_args | append "--paging=always")
  }

  let help_txt = belp-run-command $mode $cmd $subs

  if ($help_txt.exit_code != 0) {
    print $help_txt.stdout
    print $help_txt.stderr
    return
  }

  [$help_txt.stdout $help_txt.stderr] | str join '\n' | ^bat ...$bat_args
}

def belp-run-command [mode: string, cmd: string, subs: list<string>] : nothing -> record {
  match $mode {
    "help" => (do -i {^$cmd ...$subs "--help" } | complete),
    "h" => (do -i {^$cmd ...$subs "-h" } | complete),
    "help-cmd" => (do -i {^$cmd help ...$subs } | complete),
    "help-sub" => (do -i {^$cmd ...$subs help } | complete),
    "help-flag" => (do -i {^$cmd "--help" ...$subs  } | complete),
    "man" => (do -i {^man $cmd ...$subs } | complete),
    "pass-through" => (do -i {^$cmd ...$subs } | complete),
    "auto" => {
          let methods = (belp-help-methods | where ($it != "auto" and $it != "pass-through"))
          for method in $methods {
            let result = (belp-run-command $method $cmd $subs)

            if (belp-looks-like-help $result) {
              return $result
            }
          }

          {
            exit_code: 1
            stdout: ""
            stderr: $"Could not find help for ($cmd)"
          }
        }
    _ => {exit_code: 1, stdout: "", stderr: "Nothing to do, no mode set"}
  }
}

def belp-help-methods [] {
  [
    "auto"
    "help"
    "h"
    "help-cmd"
    "help-sub"
    "help-flag"
    "man"
    "pass-through"
  ]
}

def belp-looks-like-help [result: record] {
  if ($result.exit_code != 0) {
    return false
  }

  let txt = ([
    $result.stdout
    $result.stderr?
  ] | str join "\n" | str lowercase)

  [
    "usage"
    "options"
    "commands"
    "examples"
    "flags"
    "synopsis"
    "available commands"
    "subcommands"
  ]
  | any {|p| $txt | str contains $p }
}

def belp-command-completer [token: record] {
  ($token.text | commandline complete --type command)
}

# def belp-path-completer [token: record] {
#   ($token.text | commandline complete --type path)
# }

