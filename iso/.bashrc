#!/bin/bash

#===================================================================================
#
# FILE : .bashrc
#
# USAGE : N/A
#
# DESCRIPTION : BASHRC for the root user
#
# BUGS : ---
# NOTES : ---
# CONTRIBUTORS : Chevek, Wamuu, Maite, Passionlinux
# CREATED : July 2022
# REVISION: 31 October 2024
#
# LICENCE :
# Copyright (C) 2022 Yannick Defais aka Chevek, Wamuu-sudo, Maite
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with
# this program. If not, see https://www.gnu.org/licenses/.
#===================================================================================

if ! grep -q "nox" /proc/cmdline; then
    if [[ -x /usr/bin/X ]]; then
        if [[ -e /etc/startx && $(tty) == "/dev/tty1" ]]; then
            rm -f /etc/startx
            # STARTX
            [[ -f /etc/motd ]] && cat /etc/motd
        fi
    fi
fi

# Color and display settings
COLOR_WHITE=$'\033[1;37m'
COLOR_GREEN=$'\033[0;32m'
COLOR_RESET=$'\033[0m'
ERROR_IN_BRANCH_SELECTOR=" "

declare -a BRANCHES
declare -a CHOICES_BRANCH
REGEXP_BRANCH='[[:space:]]*"name":[[:space:]]*"(.*?)",'
CHOICES_BRANCH[0]="${COLOR_GREEN}*${COLOR_RESET}"

# Display branch selection menu
CLI_branch_selector() {
    echo "Select the branch to test:"
    for (( i = 0; i < ${#BRANCHES[@]}; i++ )); do
        echo "(${CHOICES_BRANCH[$i]:- }) ${COLOR_WHITE}$(($i+1))${COLOR_RESET}) ${BRANCHES[$i]}"
    done
    echo "$ERROR_IN_BRANCH_SELECTOR"
}

# Function to select branch
select_branch_to_test() {
    while CLI_branch_selector && read -rp "Select the branch with its number, ${COLOR_WHITE}[Enter]${COLOR_RESET} to validate: " num && [[ "$num" ]]; do
        clear
        if [[ "$num" =~ ^[0-9]+$ && $num -ge 1 && $num -le ${#BRANCHES[@]} ]]; then
            ((num--))
            for (( i = 0; i < ${#BRANCHES[@]}; i++ )); do
                CHOICES_BRANCH[$i]=$([[ $num -eq $i ]] && echo "${COLOR_GREEN}*${COLOR_RESET}" || echo "")
            done
            ERROR_IN_BRANCH_SELECTOR=" "
        else
            ERROR_IN_BRANCH_SELECTOR="Invalid input: $num"
        fi
    done
    for (( i = 0; i < ${#BRANCHES[@]}; i++ )); do
        if [[ "${CHOICES_BRANCH[$i]}" == "${COLOR_GREEN}*${COLOR_RESET}" ]]; then
            BRANCH_TO_LOAD=$i
        fi
    done
}

# Function to initialize developer mode
dev_mode() {
    reset
    echo "Welcome to the DEV mode."
    fetch_branches
    select_branch_to_test
    if wget "https://raw.githubusercontent.com/wamuu-sudo/orchid/${BRANCHES[$BRANCH_TO_LOAD]}/install/install.sh" -O /root/install.sh; then
        chmod +x /root/install.sh
        /root/install.sh
    else
        echo "Failed to download the install script."
    fi
    exit
}

# Fetch branches from the GitHub API
fetch_branches() {
    JSON_BRANCHES=$(curl -s https://api.github.com/repos/wamuu-sudo/orchid/branches)
    while IFS= read -r line; do
        if [[ "$line" =~ ${REGEXP_BRANCH} ]]; then
            BRANCHES+=("${BASH_REMATCH[1]}")
        fi
    done <<< "$JSON_BRANCHES"
}

# Check network connection
ping_server() {
    if ping -c 1 -W 1 82.65.199.131 &> /dev/null; then
        TEST_CONNECTION=1
    else
        TEST_CONNECTION=0
    fi
}

# Test internet connection and retry if necessary
test_connection() {
    TEST_CONNECTION=0
    local test_round=15

    while (( TEST_CONNECTION == 0 )); do
        echo -ne "$test_round "
        ping_server

        if (( test_round == 0 )); then
            if command -v net-setup &> /dev/null; then
                net-setup
                ping_server
                (( TEST_CONNECTION == 0 )) && test_round=15
            else
                echo "Network setup tool not found."
                break
            fi
        fi
        (( test_round-- ))
        sleep 1
    done
}

# Main execution if in TTY1
if [[ "$(tty)" == "/dev/tty1" ]]; then
    reset
    clear
    echo "Bienvenue, l'installation d'Orchid Linux va bientôt commencer."
    echo "Attente de la connexion à Internet."

    test_connection

    if wget https://raw.githubusercontent.com/wamuu-sudo/orchid/main/install/install.sh -O /root/install.sh; then
        chmod +x /root/install.sh
        /root/install.sh
    else
        echo "Failed to download the install script."
    fi
fi

# Set trap for developer mode
trap dev_mode 2
