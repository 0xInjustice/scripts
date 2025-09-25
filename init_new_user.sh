#!/bin/bash

# Prompt for username
read -p "Enter username: " username

# Prompt for shell selection
read -p "Enter which shell you want to use (1 for zsh and 2 for bash): " sh

if [[ $sh -eq 1 ]]; then
    shell=$(command -v zsh || echo "/bin/zsh")
elif [[ $sh -eq 2 ]]; then
    shell=$(command -v bash || echo "/bin/bash")
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Create user with additional groups
sudo useradd -m -G wheel,audio,video,power,storage,optical -s "$shell" "$username"
sudo passwd "$username"

# Create shared folder group
read -p "Enter new groupname for shared folder: " group
sudo groupadd -f "$group"  # -f will not fail if group exists

# Add current user and new user to the group
sudo usermod -aG "$group" "$(whoami)"
sudo usermod -aG "$group" "$username"

# Create shared folder
read -p "Enter shared folder name: " shared_folder
sudo mkdir -p /srv/"$shared_folder"

echo "Created $shared_folder at /srv"

# Assign permissions to the shared folder
sudo chown -R :"$group" /srv/"$shared_folder"
sudo chmod -R 2770 /srv/"$shared_folder"

# Optional access to user's home folder
read -p "Do you want access to $username's home? (1 for yes, 0 for no): " ownership

if [[ $ownership -eq 1 ]]; then
    echo "Adding ACL for your user to access $username's home..."
    sudo setfacl -R -m u:$(whoami):rwx /home/"$username"
    sudo setfacl -R -m d:u:$(whoami):rwx /home/"$username"
    echo "Access granted via ACL without changing ownership."
fi
