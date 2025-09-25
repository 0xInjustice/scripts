#!/bin/bash
set -euo pipefail

echo "[*] Starting recon tools installation..."

# 1. Install system packages with pacman (official repos)
echo "[*] Installing core packages with pacman..."
sudo pacman -Sy --noconfirm amass findomain nmap masscan httpx ffuf nuclei naabu wpscan python go jq

# 2. Install AUR packages via yay
echo "[*] Installing AUR packages with yay..."
yay -Sy --noconfirm assetfinder hakrawler gau gf arjun dirsearch dalfox alterx aquatone asnmap alterx urlfinder-bin katana-git

# 3. Setup Go environment path
echo "[*] Setting up Go bin path in shell config..."
shell=$(basename "$SHELL")
rc_file="$HOME/.$shell"rc
if ! grep -q 'export PATH=$PATH:$HOME/go/bin' "$rc_file"; then
	echo 'export PATH=$PATH:$HOME/go/bin' >> "$rc_file"
	echo "Added Go bin path to $rc_file"
fi
export PATH=$PATH:$HOME/go/bin

# 4. Install Go tools
echo "[*] Installing Go tools..."
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install github.com/projectdiscovery/katana/cmd/katana@latest
go install github.com/hahwul/dalfox/v2@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/Emoe/kxss@latest
go install github.com/KathanP19/Gxss@latest

# 5. Setup workspace directories inside PWD
tools_dir="$(pwd)/tools"
venv_dir="$(pwd)/hackenv"

echo "[*] Creating tools and virtualenv directories inside PWD..."
mkdir -p "$tools_dir"
cd "$tools_dir"

python -m venv "$venv_dir"
source "$venv_dir/bin/activate"

# 6. Install python packages
echo "[*] Installing Python package 'arjun' in virtualenv..."
pip install --upgrade pip
pip install arjun

# 7. Clone and install Python projects with requirements.txt
clone_and_install() {
	local repo_url=$1
	local folder_name=$2
	echo "[*] Cloning $folder_name from $repo_url"
	git clone "$repo_url" "$folder_name"
	cd "$folder_name"
	if [ -f requirements.txt ]; then
		echo "[*] Installing requirements for $folder_name"
		pip install -r requirements.txt --break-system-packages
	fi

	if [ -f install.sh ]; then
		echo "[*] Installing requirements for $folder_name"
		chmod +x install.sh
		./install.sh
	fi
	cd ..
}

clone_and_install https://github.com/s0md3v/XSStrike XSStrike
clone_and_install https://github.com/s0md3v/Corsy.git Corsy
clone_and_install https://github.com/chenjj/CORScanner.git CORScanner
clone_and_install https://github.com/GerbenJavado/LinkFinder.git LinkFinder
clone_and_install https://github.com/robotshell/magicRecon magicRecon

echo "[*] All done! Remember to reload your shell or source your $rc_file for Go binaries."

echo "To activate your Python virtualenv later, run:"
echo "source \"$venv_dir/bin/activate\""
