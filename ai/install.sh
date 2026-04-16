#!/usr/bin/env bash

# Global installation script for AI CLI tools
# Required: node.js and npm

echo "Installing AI CLI tools globally..."

# Claude Code
echo "Installing Claude Code (@anthropic-ai/claude-code)..."
npm install -g @anthropic-ai/claude-code --force

# Qwen Code
echo "Installing Qwen Code (@qwen-code/qwen-code)..."
npm install -g @qwen-code/qwen-code --force

# Gemini CLI
echo "Installing Gemini CLI (@google/gemini-cli)..."
npm install -g @google/gemini-cli --force

echo "Installation complete!"
echo "You can now use 'claude', 'qwen', and 'gemini' commands."
