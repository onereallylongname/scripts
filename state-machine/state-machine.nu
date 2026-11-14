# This script takes a csv into state diagram.
#
# csv format:
#    From,Event,To
#
# The first line is assumed to be the entry point
# Any entry with from and no To is represented as an end node.
#
# example:
#    From,Event,To
#    Draft,Submit,Review
#    Review,Approve,Done
#    Review,Reject,Draft
#    Done,,
#
# Usage:
#  - use state-machine.nu
#
# Version: 0.2.0
# Author: onerellylongname
# License: MIT

const default_direction = "TB"
const default_directions = ["LR" "TB"]
const default_highlight_style = "stroke:#ffddaa,stroke-width:4px"
const default_start_str = "start"
const default_end_str = "end"
const rainbow_colors = ['#f57373', '#f57673', '#f57973', '#f57c73', '#f57f73', '#f58273', '#f58573', '#f58873', '#f58b73', '#f58f73', '#f59273', '#f59573', '#f59873', '#f59b73', '#f59e73', '#f5a173', '#f5a473', '#f5a773', '#f5aa73', '#f5ad73', '#f5b073', '#f5b373', '#f5b673', '#f5b973', '#f5bc73', '#f5bf73', '#f5c273', '#f5c573', '#f5c973', '#f5cc73', '#f5cf73', '#f5d273', '#f5d573', '#f5d873', '#f5db73', '#f5de73', '#f5e173', '#f5e473', '#f5e773', '#f5ea73', '#f5ed73', '#f5f073', '#f5f373', '#f3f573', '#f0f573', '#edf573', '#eaf573', '#e7f573', '#e4f573', '#e1f573', '#def573', '#dbf573', '#d8f573', '#d5f573', '#d2f573', '#cff573', '#ccf573', '#c9f573', '#c5f573', '#c2f573', '#bff573', '#bcf573', '#b9f573', '#b6f573', '#b3f573', '#b0f573', '#adf573', '#aaf573', '#a7f573', '#a4f573', '#a1f573', '#9ef573', '#9bf573', '#98f573', '#95f573', '#92f573', '#8ff573', '#8bf573', '#88f573', '#85f573', '#82f573', '#7ff573', '#7cf573', '#79f573', '#76f573', '#73f573', '#73f576', '#73f579', '#73f57c', '#73f57f', '#73f582', '#73f585', '#73f588', '#73f58b', '#73f58f', '#73f592', '#73f595', '#73f598', '#73f59b', '#73f59e', '#73f5a1', '#73f5a4', '#73f5a7', '#73f5aa', '#73f5ad', '#73f5b0', '#73f5b3', '#73f5b6', '#73f5b9', '#73f5bc', '#73f5bf', '#73f5c2', '#73f5c5', '#73f5c9', '#73f5cc', '#73f5cf', '#73f5d2', '#73f5d5', '#73f5d8', '#73f5db', '#73f5de', '#73f5e1', '#73f5e4', '#73f5e7', '#73f5ea', '#73f5ed', '#73f5f0', '#73f5f3', '#73f3f5', '#73f0f5', '#73edf5', '#73eaf5', '#73e7f5', '#73e4f5', '#73e1f5', '#73def5', '#73dbf5', '#73d8f5', '#73d5f5', '#73d2f5', '#73cff5', '#73ccf5', '#73c9f5', '#73c5f5', '#73c2f5', '#73bff5', '#73bcf5', '#73b9f5', '#73b6f5', '#73b3f5', '#73b0f5', '#73adf5', '#73aaf5', '#73a7f5', '#73a4f5', '#73a1f5', '#739ef5', '#739bf5', '#7398f5', '#7395f5', '#7392f5', '#738ff5', '#738bf5', '#7388f5', '#7385f5', '#7382f5', '#737ff5', '#737cf5', '#7379f5', '#7376f5', '#7373f5', '#7673f5', '#7973f5', '#7c73f5', '#7f73f5', '#8273f5', '#8573f5', '#8873f5', '#8b73f5', '#8f73f5', '#9273f5', '#9573f5', '#9873f5', '#9b73f5', '#9e73f5', '#a173f5', '#a473f5', '#a773f5', '#aa73f5', '#ad73f5', '#b073f5', '#b373f5', '#b673f5', '#b973f5', '#bc73f5', '#bf73f5', '#c273f5', '#c573f5', '#c973f5', '#cc73f5', '#cf73f5', '#d273f5', '#d573f5', '#d873f5', '#db73f5', '#de73f5', '#e173f5', '#e473f5', '#e773f5', '#ea73f5', '#ed73f5', '#f073f5', '#f373f5', '#f573f3', '#f573f0', '#f573ed', '#f573ea', '#f573e7', '#f573e4', '#f573e1', '#f573de', '#f573db', '#f573d8', '#f573d5', '#f573d2', '#f573cf', '#f573cc', '#f573c9', '#f573c5', '#f573c2', '#f573bf', '#f573bc', '#f573b9', '#f573b6', '#f573b3', '#f573b0', '#f573ad', '#f573aa', '#f573a7', '#f573a4', '#f573a1', '#f5739e', '#f5739b', '#f57398', '#f57395', '#f57392', '#f5738f', '#f5738b', '#f57388', '#f57385', '#f57382', '#f5737f', '#f5737c', '#f57379', '#f57376']
const default_csv = {"From": "", "Event": "Action", "To": "First", "Note": "Change Me"}

# This script takes a csv into mermaid state diagram.
#
# csv format:
#    From,Event,To
#
# The first line is assumed to be the entry point
# Any entry with from and no To is represented as an end node.

export def "seed csv" [dir=.: path, --name (-n)="state_machine" : string] {
  let clean_name = ([($name | str trim | str trim -c '/' | str trim -c '\') '.csv'] | str join)

  if (($dir | path type) != 'dir') {
    error make {msg: $"The path argument must be a valid directory. '($dir)' is not a valid directory" }
  }
   $default_csv | save ([$dir $clean_name] | path join)
}

export def "to mermaid" [
  file_name?: path
  --direction (-d) = $default_direction : string@$default_directions  # The diagram direction TB -> top down or LR -> left right.
  --highlight (-h)                             : list<string>                # List of nodes to highlight.
  --highlight-style = $default_highlight_style : string                      # Overwrite the default highlight
  --ignore (-i)           : list<string>                              # List of nodes to hide from display.
  --rainbow                                                           # Apply rainbow colors. Overrides --highlight.
] : any -> string {

  # Get Sdtin
  let in_txt = $in

  # Validate input
  if $direction not-in $default_directions {
      error make {
          msg: $"Invalid direction '($direction)'. Allowed values: ($default_directions | str join ', ')"
      }
  }

  let transitions = if ($in_txt | is-empty) and ($file_name | is-not-empty) { 
    open $file_name
  } else if ($file_name | is-empty) and ($in_txt | is-not-empty) {
    ($in_txt | from csv)
  } else {
    error make {msg: "One of arg file_name or stdin must be used as input" }
  }

  # Apply the ignore
  let filter_transitions = if ($ignore | is-not-empty) {
    (
      $transitions
        | where {|row|
            $row.From not-in $ignore and $row.To not-in $ignore
          }
    )
  } else {
    $transitions
  }

  # Check if the ignore left any node to render
  if ($filter_transitions | is-empty) {
    error make {msg: "All nodes were filtered out, nothing to show"}
  }

  let states = (
      $filter_transitions
      | each {|t| [$t.From $t.To] }
      | flatten
      | uniq
      | where ($it | is-not-empty)
  )

  # Create aliases to support spaces
  let aliases = (
    $states
    | enumerate
    | reduce --fold {} {|s, acc|
        $acc | upsert $s.item $"s($s.index)"
    }
  )

  # Make the highlight txt
  let highlight_section = if (($highlight | is-not-empty) and (not $rainbow)) {

    # Find ids not matched
    let missing = (
        $highlight
        | where {|h| $h not-in ($aliases | columns) }
    )

    if ($missing | is-not-empty) {
        error make {
            msg: $"Unknown --highlight states: [($missing | str join ', ')]"
        }
    }

    let highlight_ids = (
        $highlight
        | each {|h|
            $aliases | get $h
        }
    )

    [
      $"classDef highlight ($highlight_style)"
      $"class ($highlight_ids | str join ", ") highlight"
      ""
    ]
  } else if ($rainbow) {
    let count = ($states | length)
    let colors_count = ($rainbow_colors | length)

    let color_step = $colors_count / $count

    let rainbow_defs = (
      $states
      | enumerate
      | each {|s|
          let color = ($rainbow_colors | get ((($s.index * $color_step) | math round) mod $colors_count | into cell-path))
          $"classDef c($s.index) fill:($color),color:#aaaaaa"
      }
    )

    let rainbow_assignments = (
        $states
        | enumerate
        | each {|s|
            let id = ($aliases | get $s.item)
            $"    class ($id) c($s.index)"
        }
    )

    [
      ($rainbow_defs | str join "\n")
      ($rainbow_assignments | str join "\n")
      ""
    ]
  } else {
    [""]
  }

  # Generate alias text
  let alias_section = (
      $aliases
      | transpose name id
      | each {|r|
          $"state \"(escape-mermaid-label $r.name)\" as ($r.id)"
      }
  )

  # Apply transformation
  (
    $filter_transitions
      | each {|row|
          let row_from = if $row.From == "" {
              "[*]"
          } else {
              $aliases | get $row.From
          }

          let row_to = if $row.To == "" {
              "[*]"
          } else {
              $aliases | get $row.To
          }

          let row_strs = [$"   ($row_from) --> ($row_to) : (if $row.Event == "" {if $row.From == "" {$default_start_str} else {$default_end_str}} else {$row.Event})"]

          (
            if ( $row.Note? | is-not-empty ) {
              ($row_strs | append $"   note left of ($row_from) : ($row.Note)")
            } else {
              $row_strs
            } | str join "\n"
          )
      }
      | prepend $highlight_section
      | prepend $alias_section
      | prepend $"direction ($direction)"
      | prepend "stateDiagram-v2"
      | str join "\n"
  )
}

def escape-mermaid-label [s: string] {
    $s | str replace -a '"' '\"'
}
