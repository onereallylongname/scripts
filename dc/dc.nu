# Docker Compose project registry and launcher (Docker Compose Companion -> dc)
#
# dc keeps a registry of Docker Compose projects and provides
# convenient wrappers around docker compose and lazydocker.
#
# Projects are registered once and identified by a Compose
# project name (`docker compose -p <project>`), allowing stacks
# to be managed independently of their location on disk.
#
# Registered projects contain:
# - name    : docker compose project name
# - dir     : directory containing the compose file
# - compose : compose file name
#
# Features:
# - Persistent project registry
# - Project and service tab completion
# - Compose lifecycle wrappers (up/down/start/stop)
# - Structured `ps` output
# - Cross-project status dashboard
# - Lazydocker integration
# - Interactive container shell access
#
# External Dependencies:
# - docker      : Docker Engine and Docker Compose plugin
# - lazydocker  : optional TUI for Docker management
#
# Usage:
#   source dc.nu
#
#   dc add .
#   dc ls
#   dc up kafka
#   dc status
#   dc exec kafka broker
#   dc ld kafka
#
# Registry:
#   ~/.config/dc/projects.nuon
#
# Version: 0.1.0
# Author: onereallylongname
# License: MIT

const DryRun = false
const DEFAULT_COMPOSE_FILES = [
  compose.yaml
  compose.yml
  docker-compose.yaml
  docker-compose.yml
]

def --env config-path [] {
    $env.DC_CONFIG_PATH?
    | default (
        $env.HOME
        | path join ".config" "dc" "projects.nuon"
      )
}

def load-projects [] {
    let path = (config-path)

    if ($path | path exists) {
        open $path
    } else {
        []
    }
}

def save-projects [projects] {
    let path = (config-path)

    mkdir ($path | path dirname)

    $projects | to nuon | save -f $path
}

def inspect-compose-file [file:path, project_name?:string] {

  let dir = ($file | path expand | path dirname )

  {
    name: ($project_name | default ($dir | path basename))
    dir: $dir
    compose: ($file | path basename)
  }
}

def get-projects [
  name:string
  --dir(-d): path
] {
  let projects = (load-projects)

  let found = if $dir == null {
    $projects | where name == $name
  } else {
    $projects | where name == $name and dir == $dir
  }

  $found
}

def resolve-project [
  name:string
  --dir(-d): path
  --select (-s)
  --silent
] {

  let matches = if $dir == null {
      get-projects $name
  } else {
      get-projects $name --dir $dir
  }

  match ($matches | length) {
    0 => {
      if ($silent) {
        return []
      }

      error make {
        msg: $"Project '($name)' not found"
      }
    }
    1 => {
      $matches | first
    }
    _ => {
      if $select {
        # TODO: handle escape. Should it silently return and empty list, error, or just quit
        ($matches | input list --fuzzy -d {|it| $"($it.name): $($it.dir)"} "Choose project")
      } else {
        error make {
          msg: $"Project name '($name)' is ambiguous"
          help: (
            $matches
            | each {|p| $"  ($p.dir)" }
            | str join "\n"
          )
        }
      }
    }
  }
}

def complete_names [] {
  (load-projects | get name)
}

def complete_services [place: record] {
    dc services $place.command.1
}

def --wrapped --env compose-exec [
    project:string
    --live-out
    ...args
] {
    let p = (resolve-project $project)

    let compose_file = ($p.dir | path join $p.compose)

    if $live_out {
      compose-exec-any --live-out -p $p.name -f $compose_file ...$args
    } else {
      compose-exec-any -p $p.name -f $compose_file ...$args
    }

}

def --wrapped --env compose-exec-any [
    --live-out
    ...args
] {
    if ($DryRun) {
      print ([docker compose ...$args ] | str join " ")
      return
    }

    if $live_out {
      ^docker compose ...$args
    } else {
      let compose_out = (do {^docker compose ...$args} | complete)
      $compose_out.stdout
    }
}

def find-compose-files [target:path] {
  if ($target | path type) == file {
    let ext = ($target | path parse).extension

    if $ext not-in [yaml yml] {
        error make {
            msg: "Expected a compose yaml file"
        }
    }

    return [$target]
  } else {
    let matches = (
      $DEFAULT_COMPOSE_FILES
      | each {|name|
          let file = ($target | path join $name)

          if ($file | path exists) {
            $file
          }
      }
      | compact
    )

    if ($matches | length) == 0 {
      error make {
        msg: $"No compose file found in ($target)"
      }
    } else {
      return $matches
    }
  }
}

##############################
## Public functions        ##
##############################

# Register one or more Docker Compose configurations in the dc registry.
#
# The target may be:
# - a compose file
# - a directory containing one of the default compose file names
#
# The registered name is used as the docker compose project name
# (`docker compose -p <name>`).
export def add [
  target:path = "."             # The path to discover the compose at or the actual file path
  --name (-n):string            # Use an alias name for it. It is used as -p <project> when calling docker compose
  --error-on-many (-e) = false  # If set throw an erro if multiple files are found
  --all (-a) = false            # Add all with out prompting the select
] : nothing -> nothing {
  let files = (find-compose-files $target)

  let projects = if ($files | length) > 1 {
    if ($all) {
     ($files | each { |f| inspect-compose-file $f $name})
    } else if ($error_on_many) {
      error make {msg: $"Found files ($files | str join ",") but only one can be registered" }
    } else {
      ($files | input list --fuzzy -m "Choose files" | each { |f| inspect-compose-file $f $name})
    }
  } else {
    ($files | each { |f| inspect-compose-file $f $name})
  }

  let current_projects = load-projects
  save-projects (($current_projects | append $projects) | uniq-by name dir compose)
}

# Allow ls to have a long form
export alias list = dc ls

# List registered Docker Compose projects.
#
# Optionally filter by project name or directory path.
export def ls [
    pattern?: string  # Filter matching names of directories
] {
    let projects = (load-projects)

    if $pattern == null {
        $projects
    } else {
        $projects
        | where name =~ $pattern or dir =~ $pattern
    }
    | sort-by name dir
}

# Allow rm to have a long form
export alias remove = dc rm

# Remove a project registration from the dc registry.
#
# This only removes the registry entry and does not affect
# containers, images, volumes, or compose configurations.
export def rm [
    name:string@complete_names       # The name to remove
    --dir(-d): path   # The path to remove ambiguous names that can match multiple
    --select(-s)      # Open a select if multiple configurations match the name
    --silent         # Do not return the deleted
] : nothing -> any {

    let project = (if ($silent) {
        resolve-project $name
            --dir=$dir
            --select=$select
            --silent=$silent
      } else {
        resolve-project $name
            --dir=$dir
            --select=$select
      }
    )

    let remaining = (
        load-projects
        | where { |p| not (
            $p.name == $project.name
            and $p.dir == $project.dir
          )
        }
    )

    save-projects $remaining

    if (not $silent) {
      $project
    }
}


# Launch lazydocker for a registered project.
#
# Opens the compose project using the stored project name
# and compose file location.
export def ld [
  project:string@complete_names
] {
    let p = (resolve-project $project)

    let compose_file = ($p.dir | path join $p.compose)

    ^lazydocker --project $p.name --file $compose_file
}

alias std-cd = cd

# Change the current shell directory to a project's
# compose directory.
export def --env cd [
  project:string@complete_names
] {
  let p = (resolve-project $project)
  std-cd $p.dir
}

# Display containers belonging to a compose project.
#
# Returns structured Nushell data parsed from
# `docker compose ps --format json`.
#
# When no project is provided all compose projects known
# to Docker are returned.
export def --wrapped --env ps [
  project?:string@complete_names # The name of the configuration to filter by. If empry all are returned
  --all (-a)                     # Return all ps fields. The default is ID Name Prorts Status
  ...args
] : any -> table {
    let project_name = ($in | default $project)
    let compose_out = if $project_name != null {
      (compose-exec $project_name ps ...$args --format json | lines | each { |l| $l | from json})
    } else {
      (compose-exec-any ps ...$args --format json | lines | each { |l| $l | from json})
    }

    if $all {
      $compose_out
    } else {
      ($compose_out | select ID Name Ports Status)
    }
}

# Start stopped containers for a compose project.
#
# Equivalent to:
#   docker compose start
export def start [
    project:string@complete_names
    ...args
] {
    compose-exec --live-out $project start ...$args
}

# Stop running containers for a compose project.
#
# Equivalent to:
#   docker compose stop
export def --wrapped --env stop [
    project:string@complete_names
    ...args
] {
    compose-exec --live-out $project stop ...$args
}

# Create missing containers and start the compose project.
#
# Equivalent to:
#   docker compose up -d
export def --wrapped --env up [
    project:string@complete_names
    ...args
] {
    compose-exec --live-out $project up -d ...$args
}

# Stop and remove compose resources.
#
# Equivalent to:
#   docker compose down
export def --wrapped --env down [
    project:string@complete_names
    ...args
] {
    compose-exec --live-out $project down ...$args
}

# List services declared by a compose configuration.
#
# Returns the output of:
#   docker compose config --services
export def --env services [
  project:string@complete_names
] {
    let project = ($in | default $project)

    (compose-exec $project config --services | lines)
}

# Summarize the health of registered projects.
#
# Displays:
# - expected services
# - running services
# - stopped services
#
# When no projects are specified all registered projects
# are assessed.
export def --env status [
    ...projects:string@complete_names
] {
    let projects = if ($projects | is-empty) {
        dc ls
    } else {
        $projects
        | each {|p| resolve-project $p }
    }

    (
      $projects
      | each {|project|

        let services = (
            compose-exec $project.name config --services
            | lines
        )

        let running = (
            ps $project.name --all
        )

        let running_services = (
            $running
            | get Service
        )

        let stopped_services = (
            $services
            | where {|s| $s not-in $running_services }
        )
        {
            Project: $project.name
            Expected: ($services | length)
            Running: ($running_services | length)
            Stopped: ($stopped_services | length)
        }
    }
  )
}


# Execute a command inside a compose service container.
#
# Examples:
#   dc exec kafka broker bash
#   dc exec kafka connect env
#
# If no command is provided an interactive bash shell
# is started.
export def --env --wrapped exec [
    project:string@complete_names
    service:string@complete_services
    ...args
] {
    let cmd = if ($args | is-empty) {
        [bash]
    } else {
        $args
    }

    compose-exec --live-out $project exec $service ...$cmd
}
