#!/usr/bin/env bash

# Define the list of directories to back up and restore
CONFIG_ITEMS=(
    "$HOME/.zshrc"
    "$HOME/.gf"
    "$HOME/.zsh_history"
    "$HOME/.oh-my-zsh"
    "$HOME/.config"
    "$HOME/nucleibomber.sh"
    "$HOME/categorized_templates"
    "/etc"
    "/var"
)

# Define the exclusion list
EXCLUDE_ITEMS=(
    "/var/tmp"
    "/var/run"
    "/var/lock"
    "/var/log"
    "/var/cache"
    "/var/lib/apt"
    "/var/lib/snapd"
    "/etc/hostname"
    "/etc/hosts"
)

# Define the backup directory and the tar file name
BACKUP_DIR="$HOME/config_backup"
BACKUP_TAR="$HOME/config_backup.tar.gz"

# Function to back up configuration files and directories
backup_configs() {
    # Remove existing backup directory and tar archive without error if not present
    sudo rm -rf "$BACKUP_DIR"
    sudo rm -f "$BACKUP_TAR"

    mkdir -p "$BACKUP_DIR"

    # Build exclude options for rsync
    EXCLUDE_RSYNC=()
    for EXCLUDE in "${EXCLUDE_ITEMS[@]}"; do
        EXCLUDE_RSYNC+=("--exclude=${EXCLUDE}")
    done

    # Copy each item with proper logging and exit on error
    for ITEM in "${CONFIG_ITEMS[@]}"; do
        if [ -e "$ITEM" ]; then
            sudo rsync -a "${EXCLUDE_RSYNC[@]}" "$ITEM" "$BACKUP_DIR" || {
                echo "Error backing up $ITEM"; exit 1;
            }
            echo "Backed up: $ITEM"
        else
            echo "Warning: $ITEM not found"
        fi
    done

    echo -e "\nArchiving backup..."
    sudo tar -czvf "$BACKUP_TAR" -C "$BACKUP_DIR" . > /dev/null || {
        echo "Error during archiving"; exit 1;
    }
    
    # Optionally remove the temporary backup directory after creating the archive
    sudo rm -rf "$BACKUP_DIR"

    echo -e "\nBackup archived to $BACKUP_TAR."
}

# Function to restore configuration files and directories
restore_configs() {
    if [ ! -f "$BACKUP_TAR" ]; then
        echo "Backup archive $BACKUP_TAR does not exist. Aborting restore."
        exit 1
    fi

    # Recreate backup directory to extract the archive
    mkdir -p "$BACKUP_DIR"
    sudo tar -xzvf "$BACKUP_TAR" -C "$BACKUP_DIR" || {
        echo "Error extracting archive"; exit 1;
    }

    for ITEM in "${CONFIG_ITEMS[@]}"; do
        ITEM_NAME=$(basename "$ITEM")
        if [ -e "$BACKUP_DIR/$ITEM_NAME" ]; then
            if [[ "$ITEM" == "$HOME"* ]]; then
                rsync -a "$BACKUP_DIR/$ITEM_NAME" "$HOME/" && \
                    echo "Restored $ITEM to $HOME" || echo "Error restoring $ITEM"
            else
                sudo rsync -a "$BACKUP_DIR/$ITEM_NAME" "$ITEM" && \
                    echo "Restored $ITEM" || echo "Error restoring $ITEM"
            fi
        else
            echo "Warning: $ITEM not found in backup."
        fi
    done
    
    # Optionally clean up the temporary restore directory
    sudo rm -rf "$BACKUP_DIR"

    echo -e "\nRestore completed."
}

# Function to install tools
install_tools() {
    # OS detection and package manager configuration
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi
    if [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
        PM_UPDATE="sudo pacman -Syu --noconfirm"
        PM_INSTALL="sudo pacman -S --noconfirm"
        PYTHON_PKG="python"
        PIP_PKG="pip"
        VENV_PKG="python-virtualenv"
    elif [[ "$ID" == "debian" ]] || [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        PM_UPDATE="sudo apt update"
        PM_INSTALL="sudo apt install -y"
        PYTHON_PKG="python3"
        PIP_PKG="pip"
        VENV_PKG="python3-venv"
    elif [[ "$ID" == "rocky" ]] || [[ "$ID_LIKE" == *"rhel"* ]]; then
        PM_UPDATE="sudo dnf update -y"
        PM_INSTALL="sudo dnf install -y"
        PYTHON_PKG="python3"
        PIP_PKG="pip"
        VENV_PKG="python3-virtualenv"
    else
        echo "Unsupported OS."
        exit 1
    fi

    # Update and install basic requirements
    echo "Installing basic requirements..."
    $PM_UPDATE
    $PM_INSTALL $PYTHON_PKG $PIP_PKG $VENV_PKG cmake zsh git curl wget
    # New: Install libpcap development package to provide pcap.h
    if [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
        $PM_INSTALL libpcap
    elif [[ "$ID" == "debian" ]] || [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        $PM_INSTALL libpcap-dev
    elif [[ "$ID" == "rocky" ]] || [[ "$ID_LIKE" == *"rhel"* ]]; then
        $PM_INSTALL libpcap-devel
    fi

    PIP_INSTALLS=(
        "uro"
        "xsrfprobe"
    )

    if [[ "$ID" == "debian" ]] || [[ "$ID" == "ubuntu" ]] || [[ "$ID_LIKE" == *"debian"* ]]; then
        echo "Installing Python tools with pip..."
        for TOOL in "${PIP_INSTALLS[@]}"; do
            $PIP_PKG install "$TOOL" --break-system-packages || echo "Failed to install $TOOL"
        done
    else
        echo "Setting up pipx..."
        $PM_INSTALL python3-pipx || $PIP_PKG install --user pipx
        python3 -m pipx ensurepath
        echo "Installing Python tools with pipx..."
        for TOOL in "${PIP_INSTALLS[@]}"; do
            pipx install "$TOOL" || echo "Failed to install $TOOL"
        done
    fi

    # Check and install the latest GO-Lang
    read -p "Do you want to install or update Go? (y/n): " install_go_prompt
    if [[ "$install_go_prompt" == "y" ]]; then
        update_go=false
        latest_go=$(curl -s https://go.dev/VERSION?m=text | head -n1)  # e.g. go1.24.1
        latest_go_num=$(echo "$latest_go" | sed -e 's/^go//' -e 's/[^0-9.]*$//')
        
        if ! command -v go &> /dev/null; then
            echo "Go is not installed. Installing Go $latest_go_num..."
            update_go=true
        else
            installed_go=$(go version | awk '{print $3}' | sed -e 's/^go//' -e 's/[^0-9.]*$//')
            if [ "$installed_go" != "$latest_go_num" ]; then
                lower=$(printf '%s\n' "$installed_go" "$latest_go_num" | sort -V | head -n1)
                if [ "$lower" = "$installed_go" ]; then
                    echo "Newer Go version available: $latest_go_num (installed: $installed_go). Updating Go..."
                    update_go=true
                else
                    echo "Installed Go version ($installed_go) is newer than the official latest ($latest_go_num)."
                fi
            else
                echo "Go is already up-to-date (version $installed_go)."
            fi
        fi

        if [ "$update_go" = true ]; then
            echo "Installing GO-Lang $latest_go..."
            wget https://go.dev/dl/${latest_go}.linux-amd64.tar.gz -O ${latest_go}.linux-amd64.tar.gz
            sudo rm -rf /usr/local/go
            sudo tar -C /usr/local -xzf ${latest_go}.linux-amd64.tar.gz
            rm ${latest_go}.linux-amd64.tar.gz

            # Set up GO environment and update command lookup
            export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
            hash -r
            grep -qxF 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' "$HOME/.bashrc" || echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$HOME/.bashrc"
            grep -qxF 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' "$HOME/.zshrc" || echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$HOME/.zshrc"
        fi
    else
        echo "Skipping Go installation/update."
    fi

    # Install GO tools
    echo "Installing GO tools..."
    # Check if Go is available in PATH before installing tools
    if ! command -v go &> /dev/null; then
        echo "Error: Go is not installed or not in PATH. Cannot install Go tools."
    else
        GO_INSTALLS=(
            "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
            "github.com/shuffledns/shuffledns/cmd/shuffledns@latest"
            "github.com/tomnomnom/anew@latest"
            "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
            "github.com/tomnomnom/waybackurls@latest"
            "github.com/lc/gau/v2/cmd/gau@latest"
            "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
            #"github.com/ethicalhackingplayground/bxss@latest" #Problematic module
            "github.com/PentestPad/subzy@latest"
            "github.com/Emoe/kxss@latest"
            "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
            "github.com/projectdiscovery/katana/cmd/katana@latest"
            "github.com/hahwul/dalfox/v2@latest"
            "github.com/projectdiscovery/httpx/cmd/httpx@latest"
            "github.com/jaeles-project/gospider@latest"
            "github.com/tomnomnom/qsreplace@latest"
            "github.com/tomnomnom/gf@latest"
            "github.com/tomnomnom/httprobe@latest"
            "github.com/003random/getJS@latest"
            "github.com/zan8in/afrog/v3/cmd/afrog@latest"
        )
        for TOOL in "${GO_INSTALLS[@]}"; do
            echo "Installing $TOOL..."
            go install -v "$TOOL" || echo "Failed to install $TOOL"
        done
    fi

    # Clone and install Git repositories
    echo "Installing Git-based tools..."
    mkdir -p "$HOME/tools"
    cd "$HOME/tools" || { echo "Error: Could not access $HOME/tools directory"; exit 1; }

    GIT_CLONES=(
        "https://github.com/sqlmapproject/sqlmap.git sqlmap-dev"
        "https://github.com/r0oth3x49/ghauri.git ghauri"
        "https://github.com/maurosoria/dirsearch.git dirsearch"
        "https://github.com/0xKayala/NucleiScanner.git NucleiScanner"
        "https://github.com/0xKayala/NucleiFuzzer.git NucleiFuzzer"
        "https://github.com/ameenmaali/urldedupe.git urldedupe"
        "https://github.com/aldo-moreno-leon/ORtester.git ORtester"
        "https://github.com/r0075h3ll/Oralyzer.git Oralyzer"
        "https://github.com/siimsek/AORT-Dev.git AORT-Dev"
        "https://github.com/devanshbatham/paramspider"
    )
    for REPO in "${GIT_CLONES[@]}"; do
        REPO_URL=$(echo $REPO | awk '{print $1}')
        REPO_DIR=$(echo $REPO | awk '{print $2}')
        
        # If REPO_DIR is empty, extract directory name from URL
        if [ -z "$REPO_DIR" ]; then
            REPO_DIR=$(basename "$REPO_URL" .git)
        fi
        
        echo "Installing $REPO_DIR..."
        
        # Skip if directory already exists
        if [ -d "$REPO_DIR" ]; then
            echo "$REPO_DIR already exists. Updating..."
            cd "$REPO_DIR" || continue
            git pull
            cd ..
        else
            git clone --depth 1 "$REPO_URL" "$REPO_DIR" || { echo "Failed to clone $REPO_URL"; continue; }
            cd "$REPO_DIR" || continue
        
            # Create virtual environment for Python projects
            if [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
                echo "Setting up Python environment for $REPO_DIR..."
                python3 -m venv venv || { echo "Failed to create virtual environment for $REPO_DIR"; cd ..; continue; }
                source venv/bin/activate
                pip install --upgrade pip
                if [ -f "requirements.txt" ]; then
                    pip install -r requirements.txt || echo "Warning: Some requirements failed to install for $REPO_DIR"
                fi
                if [ -f "setup.py" ]; then
                    pip install . || echo "Warning: Setup installation failed for $REPO_DIR"
                fi
                deactivate
            elif [ -f "install.sh" ]; then
                chmod +x install.sh
                ./install.sh || echo "Warning: Install script failed for $REPO_DIR"
            fi
            cd ..
        fi
    done

    # Build and install urldedupe
    cd urldedupe || exit
    cmake CMakeLists.txt
    make
    sudo cp urldedupe /usr/bin/
    cd ..

    # Install gf patterns
    echo "Installing gf patterns..."
    rm -rf "$HOME/Gf-Patterns"
    rm -rf "$HOME/.gf"
    mkdir -p "$HOME/.gf"
    git clone https://github.com/1ndianl33t/Gf-Patterns "$HOME/Gf-Patterns" || { echo "Failed to clone gf patterns"; }
    if [ -d "$HOME/Gf-Patterns" ]; then
        mv $HOME/Gf-Patterns/*.json $HOME/.gf/ || echo "Moving gf patterns failed"
    fi
    rm -rf "$HOME/Gf-Patterns"

    # Optional ZSH and Oh My Zsh installation
    read -p "Do you want to install ZSH and Oh My Zsh? (y/n): " INSTALL_ZSH
    if [ "$INSTALL_ZSH" = "y" ]; then
        if ! command -v zsh &> /dev/null; then
            echo "Zsh not found. Installing zsh..."
            $PM_INSTALL zsh
        fi

        if [ "$SHELL" != "$(which zsh)" ]; then
            sudo chsh -s "$(which zsh)" "$USER"
        fi

        if [ ! -d "$HOME/.oh-my-zsh" ]; then
            echo "Installing Oh My Zsh..."
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        else
            echo "Oh My Zsh already installed. Skipping installation."
        fi
    else
        echo "Skipping ZSH and Oh My Zsh installation."
    fi

}


# Display menu options to the user
echo "Select an option:"
echo "1. Backup configuration files and directories"
echo "2. Restore configuration files and directories"
echo "3. Install tools"
read -p "Enter your choice (1, 2, or 3): " CHOICE

# Execute the chosen option
case $CHOICE in
    1)
        echo ""
        backup_configs
        ;;
    2)
        echo ""
        restore_configs
        ;;
    3)
        echo ""
        install_tools
        ;;
    *)
        echo ""
        echo "Invalid choice. Please enter 1, 2, or 3."
        ;;
esac