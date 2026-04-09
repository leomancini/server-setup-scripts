#!/bin/bash

# Set up variables
USER="leo"
SERVER="root.noshado.ws"
SCRIPTS_DIRECTORY="/home/$USER/scripts"
APPS_DIRECTORY="/home/$USER/react-apps"
SERVICES_DIRECTORY="/home/$USER/services"
FULL_STACK_APPS_DIRECTORY="/home/$USER/full-stack-apps"
DOMAINS_DIRECTORY="/home/$USER/domains"

# Cache tput values once to avoid forking on every redraw
BOLD=$(tput bold)
SMSO=$(tput smso)
RESET=$(tput sgr0)
COLOR_GREEN=$(tput setaf 2)
COLOR_RED=$(tput setaf 1)
COLOR_CYAN=$(tput setaf 6)
COLOR_BLUE=$(tput setaf 4)
COLOR_MAGENTA=$(tput setaf 5)
COLOR_WHITE=$(tput setaf 7)
CLR="\033[K"

# Function to print the menu with minimal updates
print_menu() {
    local level=$1
    local header=$2
    local selected=$3
    local mode=$4
    shift 4
    local options=("$@")

    local buf=""
    buf+="\033[?25l\033[H" # Hide cursor and move to top-left

    buf+="${BOLD}${SMSO}  $header  ${RESET}${CLR}\n"
    buf+=" ${CLR}\n"

    # Determine color based on mode
    local selected_symbol option_color
    case "$mode" in
        add)     selected_symbol="+"; option_color="$COLOR_GREEN" ;;
        remove)  selected_symbol="-"; option_color="$COLOR_RED" ;;
        reload)  selected_symbol="↻"; option_color="$COLOR_CYAN" ;;
        view)    selected_symbol="→"; option_color="$COLOR_BLUE" ;;
        *)       selected_symbol="→"; option_color="$RESET" ;;
    esac

    if [ $level -gt 1 ]; then
        for ((i = 0; i < ${#options[@]}; i++)); do
            if [ $i -eq $selected ]; then
                buf+="${option_color}${BOLD}$selected_symbol ${options[i]}${RESET}${CLR}\n"
            else
                buf+="${RESET}  ${options[i]}${RESET}${CLR}\n"
            fi
        done
        buf+=" ${CLR}\n"
        if [ $selected -eq ${#options[@]} ]; then
            buf+="${COLOR_MAGENTA}${BOLD}← Back${RESET}${CLR}\n"
        else
            buf+="  Back${CLR}\n"
        fi
    else
        for ((i = 0; i < ${#options[@]}; i++)); do
            if [ "${options[i]}" == "" ]; then
                buf+=" ${CLR}\n"
            elif [ $i -eq $selected ]; then
                case "${options[i]}" in
                    "Create New Instance")
                        buf+="${COLOR_GREEN}${BOLD}+ ${options[i]}${RESET}${CLR}\n" ;;
                    "Remove Existing Instance")
                        buf+="${COLOR_RED}${BOLD}- ${options[i]}${RESET}${CLR}\n" ;;
                    "Reload Existing Instance")
                        buf+="${COLOR_CYAN}${BOLD}↻ ${options[i]}${RESET}${CLR}\n" ;;
                    "View Git Remotes")
                        buf+="${COLOR_BLUE}${BOLD}→ ${options[i]}${RESET}${CLR}\n" ;;
                    "Exit")
                        buf+="${COLOR_MAGENTA}${BOLD}✕ ${options[i]}${RESET}${CLR}\n" ;;
                    *)
                        buf+="${COLOR_MAGENTA}${BOLD}→ ${options[i]}${RESET}${CLR}\n" ;;
                esac
            else
                buf+="${RESET}  ${options[i]}${RESET}${CLR}\n"
            fi
        done
    fi

    buf+=" ${CLR}\n"
    buf+="\033[J\033[?25h" # Clear leftover lines and show cursor

    printf "%b" "$buf"
}

# Function to handle the arrow key inputs and back option
navigate_menu() {
    local level=$1
    local header=$2
    local mode=$3
    shift 3
    local options=("$@")
    local selected=0

    while true; do
        print_menu $level "$header" $selected "$mode" "${options[@]}"

        read -rsn1 input
        if [[ $input == $'\x1b' ]]; then
            read -rsn2 input # read 2 more characters
            case $input in
                '[A') # Up arrow
                    ((selected--))
                    if [ $selected -lt 0 ]; then
                        selected=${#options[@]}
                    fi
                    # Skip the unselectable blank option
                    if [ $level -eq 1 ] && [ $selected -eq 4 ]; then
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=${#options[@]}
                        fi
                    fi
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    if [ $selected -gt ${#options[@]} ]; then
                        selected=0
                    fi
                    # Skip the unselectable blank option
                    if [ $level -eq 1 ] && [ $selected -eq 4 ]; then
                        ((selected++))
                        if [ $selected -gt ${#options[@]} ]; then
                            selected=0
                        fi
                    fi
                    ;;
            esac
        elif [[ $input == "" ]]; then # Enter key
            break
        fi
    done

    selected_option=$selected
}

# Function to execute SSH command and return the output
execute_ssh_command() {
    local command=$1
    local interactive=$2

    if [ "$interactive" == "true" ]; then
      ssh -t $USER@$SERVER "$command"
      echo " "
      read -p "${BOLD}DONE${RESET} Press enter to continue"
    else
      ssh $USER@$SERVER "$command"
    fi
}

# Function to display dynamic menu from remote directory with header and back option
display_remote_directory() {
    local level=$1
    local directory=$2
    local type=$3
    local action=$4

    local folders=$(execute_ssh_command "find $directory -maxdepth 1 -mindepth 1 -type d" "false")

    echo "$folders" >&2

    # Check if the SSH command returned any directories
    if [ -z "$folders" ]; then
        echo "Nothing found in $directory"
        echo " "
        read -p "${BOLD}DONE${RESET} Press enter to continue"
        return 1 # Indicate that back was selected
    fi

    local options=()
    IFS=$'\n' read -rd '' -a options <<<"$folders"

    # Remove the specified paths and the trailing slash from the output
    for i in "${!options[@]}"; do
        options[i]=$(basename "${options[i]}")
    done

    printf "%s\n" "${options[@]}" >&2

    navigate_menu $level "$action" "$type" "${options[@]}"
    selected_folder=${options[$selected_option]}

    if [ $selected_option -eq ${#options[@]} ]; then
        return 1 # Indicate that back was selected
    else
        case $action in
            "Remove React App")
                echo "Removing React App: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/remove-react-app.sh --app-id $selected_folder" "true"
                ;;
            "Remove Express Server")
                echo "Removing Express Server: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/remove-express-server.sh --service-id $selected_folder" "true"
                ;;
            "Rebuild React App")
                echo "Rebuilding React App: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/rebuild-react-app.sh --app-id $selected_folder" "true"
                ;;
            "Restart Express Server")
                echo "Restarting Express Server: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/restart-express-server.sh --service-id $selected_folder" "true"
                ;;
            "Remove Full Stack App")
                echo "Removing Full Stack App: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/remove-full-stack-app.sh --app-id $selected_folder" "true"
                ;;
            "Restart Full Stack App")
                echo "Restarting Full Stack App: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/restart-full-stack-app.sh --app-id $selected_folder" "true"
                ;;
        esac
        return 0
    fi
}

# Function to display git remotes for directories
display_git_remotes() {
    local level=$1
    local directory=$2
    local type=$3
    local action=$4

    local folders=$(execute_ssh_command "find $directory -maxdepth 1 -mindepth 1 -type d" "false")

    echo "$folders" >&2

    # Check if the SSH command returned any directories
    if [ -z "$folders" ]; then
        echo "Nothing found in $directory"
        echo " "
        read -p "${BOLD}DONE${RESET} Press enter to continue"
        return 1 # Indicate that back was selected
    fi

    local options=()
    IFS=$'\n' read -rd '' -a options <<<"$folders"

    # Remove the specified paths and the trailing slash from the output
    for i in "${!options[@]}"; do
        options[i]=$(basename "${options[i]}")
    done

    printf "%s\n" "${options[@]}" >&2

    # Pre-build display lines for git remotes
    local display_lines=()
    for option in "${options[@]}"; do
        if [ -n "$option" ]; then
            option=$(echo "$option" | tr -d '\r\n' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            local full_path="$directory/$option"
            local github_remote=$(execute_ssh_command "cd $full_path && git remote get-url origin 2>/dev/null" "false")
            github_remote=$(echo "$github_remote" | tr -d '\r\n')
            if [ -n "$github_remote" ]; then
                display_lines+=("  ${BOLD}${COLOR_BLUE}$option${RESET}: ${COLOR_WHITE}$github_remote${RESET}")
            else
                local server_remote="$USER@$SERVER:$full_path"
                display_lines+=("  ${BOLD}${COLOR_BLUE}$option${RESET}: ${COLOR_WHITE}$server_remote${RESET} ${COLOR_RED}(no GitHub remote)${RESET}")
            fi
        fi
    done

    # Display the git remotes with navigation
    local selected=0
    while true; do
        local buf=""
        buf+="\033[?25l\033[H"
        buf+="${BOLD}${SMSO}  $action  ${RESET}${CLR}\n"
        buf+=" ${CLR}\n"

        for display_line in "${display_lines[@]}"; do
            buf+="${display_line}${CLR}\n"
        done

        buf+=" ${CLR}\n"
        if [ $selected -eq 0 ]; then
            buf+="${COLOR_MAGENTA}${BOLD}← Back${RESET}${CLR}\n"
        else
            buf+="  Back${CLR}\n"
        fi
        buf+=" ${CLR}\n"
        buf+="\033[J\033[?25h"

        printf "%b" "$buf"

        read -rsn1 input
        if [[ $input == $'\x1b' ]]; then
            read -rsn2 input # read 2 more characters
            # For this menu, we don't need arrow key handling since there's only "Back"
        elif [[ $input == "" ]]; then # Enter key
            break
        fi
    done

    return 1 # Always return 1 to go back since this is just for viewing
}

while true; do
    # Level 1 Menu
    level1_options=("Create New Instance" "Remove Existing Instance" "Reload Existing Instance" "View Git Remotes" "" "Exit")
    navigate_menu 1 "Host Manager" "" "${level1_options[@]}"
    level1_selection=$selected_option

    if [ $level1_selection -eq 5 ]; then
        break
    elif [ $level1_selection -eq 0 ]; then
        while true; do
            # Level 2 (Set Up)
            setup_options=("React App" "Express Server" "Full Stack App")
            navigate_menu 2 "Create New Instance" "add" "${setup_options[@]}"
            setup_selection=$selected_option

            if [ $setup_selection -eq ${#setup_options[@]} ]; then
                break
            else
                case $setup_selection in
                    0)
                        execute_ssh_command "$SCRIPTS_DIRECTORY/setup-new-react-app.sh" "true"
                        ;;
                    1)
                        execute_ssh_command "$SCRIPTS_DIRECTORY/setup-new-express-server.sh" "true"
                        ;;
                    2)
                        execute_ssh_command "$SCRIPTS_DIRECTORY/setup-new-full-stack-app.sh" "true"
                        ;;
                esac
            fi
        done
    elif [ $level1_selection -eq 1 ]; then
        while true; do
            # Level 2 (Remove)
            remove_options=("React App" "Express Server" "Full Stack App")
            navigate_menu 2 "Remove Existing Instance" "remove" "${remove_options[@]}"
            remove_selection=$selected_option

            if [ $remove_selection -eq ${#remove_options[@]} ]; then
                break
            else
                case $remove_selection in
                    0)
                        # Level 3 (Remove React App)
                        if ! display_remote_directory 3 "$APPS_DIRECTORY" "remove" "Remove React App"; then
                            continue
                        fi
                        ;;
                    1)
                        # Level 3 (Remove Express Server)
                        if ! display_remote_directory 3 "$SERVICES_DIRECTORY" "remove" "Remove Express Server"; then
                            continue
                        fi
                        ;;
                    2)
                        # Level 3 (Remove Full Stack App)
                        if ! display_remote_directory 3 "$FULL_STACK_APPS_DIRECTORY" "remove" "Remove Full Stack App"; then
                            continue
                        fi
                        ;;
                esac
            fi
        done
    elif [ $level1_selection -eq 2 ]; then
        while true; do
            # Level 2 (Reload)
            reload_options=("React App" "Express Server" "Full Stack App")
            navigate_menu 2 "Reload Existing Instance" "reload" "${reload_options[@]}"
            reload_selection=$selected_option

            if [ $reload_selection -eq ${#reload_options[@]} ]; then
                break
            else
                case $reload_selection in
                    0)
                        # Level 3 (Rebuild React App)
                        if ! display_remote_directory 3 "$APPS_DIRECTORY" "reload" "Rebuild React App"; then
                            continue
                        fi
                        ;;
                    1)
                        # Level 3 (Restart Express Server)
                        if ! display_remote_directory 3 "$SERVICES_DIRECTORY" "reload" "Restart Express Server"; then
                            continue
                        fi
                        ;;
                    2)
                        # Level 3 (Restart Full Stack App)
                        if ! display_remote_directory 3 "$FULL_STACK_APPS_DIRECTORY" "reload" "Restart Full Stack App"; then
                            continue
                        fi
                        ;;
                esac
            fi
        done
    elif [ $level1_selection -eq 3 ]; then
        while true; do
            # Level 2 (View Git Remotes)
            view_options=("React App" "Express Server" "Full Stack App")
            navigate_menu 2 "View Git Remotes" "view" "${view_options[@]}"
            view_selection=$selected_option

            if [ $view_selection -eq ${#view_options[@]} ]; then
                break
            else
                case $view_selection in
                    0)
                        # Level 3 (View React App Git Remotes)
                        if ! display_git_remotes 3 "$APPS_DIRECTORY" "" "React App Git Remotes"; then
                            continue
                        fi
                        ;;
                    1)
                        # Level 3 (View Express Server Git Remotes)
                        if ! display_git_remotes 3 "$SERVICES_DIRECTORY" "" "Express Server Git Remotes"; then
                            continue
                        fi
                        ;;
                    2)
                        # Level 3 (View Full Stack App Git Remotes)
                        if ! display_git_remotes 3 "$FULL_STACK_APPS_DIRECTORY" "" "Full Stack App Git Remotes"; then
                            continue
                        fi
                        ;;
                esac
            fi
        done
    fi
done
