#!/bin/bash

# Set up variables
USER="leo"
SERVER="root.noshado.ws"
SCRIPTS_DIRECTORY="/home/$USER/scripts"
APPS_DIRECTORY="/home/$USER/react-apps"
SERVICES_DIRECTORY="/home/$USER/services"
DOMAINS_DIRECTORY="/home/$USER/domains"

# Function to print the menu with minimal updates
print_menu() {
    local level=$1
    local header=$2
    local selected=$3
    local mode=$4
    shift 4
    local options=("$@")
    
    echo -e "\033[H\033[J" # Clear the screen
    
    echo "$(tput bold)$(tput smso)  $header  $(tput sgr0)"
    echo " "
    
    # Determine color based on mode
    if [ "$mode" == "add" ]; then
        selected_symbol="+"
        option_color=$(tput setaf 2) # Green
    elif [ "$mode" == "remove" ]; then
        selected_symbol="-"
        option_color=$(tput setaf 1) # Red
    else
        selected_symbol="→"
        option_color=$(tput sgr0) # Default color
    fi
    
    if [ $level -gt 1 ]; then
        for ((i = 0; i < ${#options[@]}; i++)); do
            if [ $i -eq $selected ]; then
                echo -e "$option_color$(tput bold)$selected_symbol ${options[i]}$(tput sgr0)"
            else
                echo -e "$(tput sgr0)  ${options[i]}$(tput sgr0)"
            fi
        done
        echo " "
        if [ $selected -eq ${#options[@]} ]; then
            echo -e "$(tput setaf 6)$(tput bold)← Back$(tput sgr0)"
        else
            echo "  Back"
        fi
    else
        for ((i = 0; i < ${#options[@]}; i++)); do
            if [ "${options[i]}" == "" ]; then
                echo " " # Print a blank line for the unselectable blank option
            elif [ $i -eq $selected ]; then
                if [ "${options[i]}" == "Create New Instance" ]; then
                    echo -e "$(tput setaf 2)$(tput bold)+ ${options[i]}$(tput sgr0)"
                elif [ "${options[i]}" == "Remove Existing Instance" ]; then
                    echo -e "$(tput setaf 1)$(tput bold)- ${options[i]}$(tput sgr0)"
                elif [ "${options[i]}" == "Exit" ]; then
                    echo -e "$(tput setaf 6)$(tput bold)✕ ${options[i]}$(tput sgr0)"
                else
                    echo -e "$(tput setaf 6)$(tput bold)→ ${options[i]}$(tput sgr0)"
                fi
            else
                echo -e "$(tput sgr0)  ${options[i]}$(tput sgr0)"
            fi
        done
    fi
      
    echo " "
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
                    if [ $level -eq 1 ] && [ $selected -eq 2 ]; then
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
                    if [ $level -eq 1 ] && [ $selected -eq 2 ]; then
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
      read -p "$(tput bold)DONE$(tput sgr0) Press enter to continue"
    else
      ssh -t $USER@$SERVER "$command"
    fi
}

# Function to display dynamic menu from remote directory with header and back option
display_remote_directory() {
    local level=$1
    local directory=$2
    local header=$3
    local remove_type=$4

    local folders=$(execute_ssh_command "find $directory -maxdepth 1 -mindepth 1 -type d" "false")

    echo "$folders" >&2

    # Check if the SSH command returned any directories
    if [ -z "$folders" ]; then
        echo "No ${remove_type}s found in $directory"
        echo " "
        read -p "$(tput bold)DONE$(tput sgr0) Press enter to continue"
        return 1 # Indicate that back was selected
    fi

    local options=()
    IFS=$'\n' read -rd '' -a options <<<"$folders"

    # Remove the specified paths and the trailing slash from the output
    for i in "${!options[@]}"; do
        options[i]=$(basename "${options[i]}")
    done

    printf "%s\n" "${options[@]}" >&2

    navigate_menu $level "$header" "remove" "${options[@]}"
    selected_folder=${options[$selected_option]}
    
    if [ $selected_option -eq ${#options[@]} ]; then
        return 1 # Indicate that back was selected
    else
        case $remove_type in
            "React App")
                echo "Removing React App: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/remove-react-app.sh --app-id $selected_folder" "true"
                ;;
            "Express Server")
                echo "Removing Express Server: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/remove-express-server.sh --service-id $selected_folder" "true"
                ;;
            "PHP/HTML Server")
                echo "Removing PHP/HTML Server: $selected_folder"
                execute_ssh_command "bash $SCRIPTS_DIRECTORY/remove-php-html-server.sh --domain-name $selected_folder" "true"
                ;;
        esac
        return 0
    fi
}

while true; do
    # Level 1 Menu
    level1_options=("Create New Instance" "Remove Existing Instance" "" "Exit")
    navigate_menu 1 "Host Manager" "" "${level1_options[@]}"
    level1_selection=$selected_option

    if [ $level1_selection -eq 3 ]; then
        break
    elif [ $level1_selection -eq 0 ]; then
        while true; do
            # Level 2 (Set Up)
            setup_options=("React App" "Express Server" "PHP/HTML Server")
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
                        execute_ssh_command "$SCRIPTS_DIRECTORY/setup-new-domain.sh" "true"
                        ;;
                esac
            fi
        done
    elif [ $level1_selection -eq 1 ]; then
        while true; do
            # Level 2 (Remove)
            remove_options=("React App" "Express Server")
            # remove_options=("React App" "Express Server" "PHP/HTML Server")
            navigate_menu 2 "Remove Existing Instance" "remove" "${remove_options[@]}"
            remove_selection=$selected_option
            
            if [ $remove_selection -eq ${#remove_options[@]} ]; then
                break
            else
                case $remove_selection in
                    0)
                        # Level 3 (Remove React App)
                        if ! display_remote_directory 3 "$APPS_DIRECTORY" "Remove React App" "React App"; then
                            continue
                        fi
                        ;;
                    1)
                        # Level 3 (Remove Express Server)
                        if ! display_remote_directory 3 "$SERVICES_DIRECTORY" "Remove Express Server" "Express Server"; then
                            continue
                        fi
                        ;;
                    2)
                        # Level 3 (Remove PHP/HTML Server)
                        if ! display_remote_directory 3 "$DOMAINS_DIRECTORY" "Remove PHP/HTML Server" "PHP/HTML Server"; then
                            continue
                        fi
                        ;;
                esac
            fi
        done
    fi
done
