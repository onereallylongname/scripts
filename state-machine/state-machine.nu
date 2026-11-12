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
# Version: 0.1.0
# Author: onerellylongname
# License: MIT


# This script takes a csv into mermaid state diagram.
#
# csv format:
#    From,Event,To
#
# The first line is assumed to be the entry point
# Any entry with from and no To is represented as an end node.
export def "to mermaid" [
  file_name?: path
  --direction (-d) = "TB" : string@["LR" "TB"]  # The diagram direction TB -> top down or LR -> left right. TODO Fail on invald direction
  --highlight (-h)        : list<string>        # List of nodes to highlight.
  --highlight-style = "stroke:#ffddaa,stroke-width:4px"      : string # Overwrite the default highlight
  --ignore (-i)           : list<string>        # List of nodes to hide from display.
  --rainbow                                     # Apply rainbow colors. Overrides --highlight.
] : any -> string {

  # Get Sdtin
  let in_txt = $in

  # Validate input
  if $direction not-in ["TB" "LR"] {
      error make {
          msg: $"Invalid direction '($direction)'. Allowed values: TB, LR"
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


# Make the highlight txt
  let highlight_section = if (($highlight | is-not-empty) and (not $rainbow)) {
    [
      $"classDef highlight ($highlight_style)"
      $"class ($highlight | str join ", ") highlight"
      ""
    ]
  } else if ($rainbow) {
    let states = (
        $filter_transitions
        | each {|t| [$t.From $t.To] }
        | flatten
        | uniq
        | sort
    )

    let count = ($states | length)

    let colors = [
        "#ffcccc"
        "#ffe5cc"
        "#ffffcc"
        "#e5ffcc"
        "#ccffcc"
        "#ccffe5"
        "#ccffff"
        "#cce5ff"
        "#ccccff"
        "#e5ccff"
        "#ffccff"
        "#ffcce5"
    ]

    let rainbow_defs = (
      $states
      | enumerate
      | each {|s|
          let color = ($colors | get ($s.index mod ($colors | length)))
          $"classDef c($s.index) fill:($color)"
      }
    )

    let rainbow_assignments = (
        $states
        | enumerate
        | each {|s|
            $"    class ($s.item) c($s.index)"
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

  # Get the first node, assume it is the begining
  let first_state = ($filter_transitions | take 1 | get --ignore-case from.0)

  # Apply transformation
  (
    $filter_transitions
      | each {|row|
          $"    ($row.From) --> (if $row.To == "" {"[*]"} else {$row.To}) : (if $row.Event == "" {"end"} else {$row.Event})"
      }
      | prepend $"    [*] --> ($first_state)"
      | prepend $highlight_section
      | prepend $"direction ($direction)"
      | prepend "stateDiagram-v2"
      | str join "\n"
  )
}
