#!/bin/sh

# Check if a project name is provided
if [ $# -eq 0 ]; then
    echo "Error: Please provide a project name."
    echo "Usage: $0 <project_name>"
    exit 1
fi

# Get the project name from the first argument
project_name="$1"

# Check if the project directory already exists
if [ -d "$project_name" ]; then
    echo "Error: A directory with the name '$project_name' already exists."
    exit 1
fi

# Create the new project directory
mkdir "$project_name"

# Copy flake.nix and .envrc from the new location to the new project directory
cp "$HOME/.local/share/new-project/flake.nix" "$project_name/flake.nix"
cp "$HOME/.local/share/new-project/.envrc" "$project_name/.envrc"

chmod u+w "$project_name/flake.nix"
chmod u+w "$project_name/.envrc"

echo "New project '$project_name' created successfully."
echo "flake.nix and .envrc have been copied to the new project directory."
