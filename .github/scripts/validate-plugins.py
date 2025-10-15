#!/usr/bin/env python3
"""
Validate Claude Code plugin marketplace and plugin configurations.

This script validates:
1. JSON syntax for marketplace.json and plugin.json files
2. YAML frontmatter in markdown agent and command files
3. File structure and naming conventions
"""

import json
import sys
import re
from pathlib import Path
from typing import Dict, List, Tuple


def validate_json_file(file_path: Path) -> Tuple[bool, List[str]]:
    """Validate JSON file syntax."""
    errors = []
    try:
        with open(file_path, 'r') as f:
            json.load(f)
        return True, []
    except json.JSONDecodeError as e:
        errors.append(f"JSON syntax error in {file_path}: {e}")
        return False, errors
    except Exception as e:
        errors.append(f"Error reading {file_path}: {e}")
        return False, errors


def validate_yaml_frontmatter(file_path: Path) -> Tuple[bool, List[str]]:
    """Validate YAML frontmatter in markdown files."""
    errors = []
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Check if file has YAML frontmatter
        if not content.startswith('---'):
            # Frontmatter is optional for commands but recommended
            if 'commands' in str(file_path):
                return True, []
            errors.append(f"Missing YAML frontmatter in {file_path}")
            return False, errors
        
        # Extract frontmatter
        parts = content.split('---', 2)
        if len(parts) < 3:
            errors.append(f"Malformed YAML frontmatter in {file_path}")
            return False, errors
        
        frontmatter = parts[1].strip()
        
        # Basic YAML validation - check for key-value pairs
        lines = frontmatter.split('\n')
        for line in lines:
            if line.strip() and not line.strip().startswith('#'):
                if ':' not in line:
                    errors.append(f"Invalid YAML line in {file_path}: {line}")
                    return False, errors
        
        # For agents, check required fields
        if 'agents' in str(file_path):
            required_fields = ['name', 'description']
            for field in required_fields:
                if not any(line.strip().startswith(f'{field}:') for line in lines):
                    errors.append(f"Missing required field '{field}' in agent {file_path}")
                    return False, errors
        
        return True, []
    
    except Exception as e:
        errors.append(f"Error reading {file_path}: {e}")
        return False, errors


def validate_plugin_json(file_path: Path) -> Tuple[bool, List[str]]:
    """Validate plugin.json structure."""
    errors = []
    
    valid, json_errors = validate_json_file(file_path)
    if not valid:
        return False, json_errors
    
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        # Check required fields
        required_fields = ['name', 'displayName', 'description', 'version']
        for field in required_fields:
            if field not in data:
                errors.append(f"Missing required field '{field}' in {file_path}")
        
        # Validate version format (semantic versioning)
        if 'version' in data:
            version = data['version']
            if not re.match(r'^\d+\.\d+\.\d+', version):
                errors.append(f"Invalid version format '{version}' in {file_path}. Use semantic versioning (e.g., '1.0.0')")
        
        # Validate name format (kebab-case)
        if 'name' in data:
            name = data['name']
            if not re.match(r'^[a-z0-9]+(-[a-z0-9]+)*$', name):
                errors.append(f"Invalid plugin name '{name}' in {file_path}. Use kebab-case")
        
        # Check that directories exist if specified
        plugin_dir = file_path.parent
        if 'agents' in data:
            agents_dir = plugin_dir / data['agents'].lstrip('./')
            if not agents_dir.exists():
                errors.append(f"Agents directory '{data['agents']}' does not exist in {file_path}")
        
        if 'commands' in data:
            commands_dir = plugin_dir / data['commands'].lstrip('./')
            if not commands_dir.exists():
                errors.append(f"Commands directory '{data['commands']}' does not exist in {file_path}")
        
        return len(errors) == 0, errors
    
    except Exception as e:
        errors.append(f"Error validating plugin.json {file_path}: {e}")
        return False, errors


def validate_marketplace_json(file_path: Path) -> Tuple[bool, List[str]]:
    """Validate marketplace.json structure."""
    errors = []
    
    valid, json_errors = validate_json_file(file_path)
    if not valid:
        return False, json_errors
    
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        # Check required fields
        required_fields = ['name', 'description', 'version', 'plugins']
        for field in required_fields:
            if field not in data:
                errors.append(f"Missing required field '{field}' in {file_path}")
        
        # Validate plugins list
        if 'plugins' in data:
            if not isinstance(data['plugins'], list):
                errors.append(f"'plugins' field must be a list in {file_path}")
            else:
                for i, plugin in enumerate(data['plugins']):
                    if not isinstance(plugin, dict):
                        errors.append(f"Plugin at index {i} must be an object in {file_path}")
                        continue
                    
                    if 'name' not in plugin:
                        errors.append(f"Plugin at index {i} missing 'name' field in {file_path}")
                    
                    if 'source' not in plugin:
                        errors.append(f"Plugin at index {i} missing 'source' field in {file_path}")
                    else:
                        # Check that source directory exists
                        marketplace_dir = file_path.parent.parent
                        plugin_path = marketplace_dir / plugin['source'].lstrip('./')
                        if not plugin_path.exists():
                            errors.append(f"Plugin source '{plugin['source']}' does not exist in {file_path}")
        
        return len(errors) == 0, errors
    
    except Exception as e:
        errors.append(f"Error validating marketplace.json {file_path}: {e}")
        return False, errors


def validate_naming_conventions(file_path: Path) -> Tuple[bool, List[str]]:
    """Validate naming conventions for files."""
    errors = []
    
    # Check for kebab-case in agent and command files
    if file_path.suffix == '.md':
        name = file_path.stem
        if 'agents' in str(file_path) or 'commands' in str(file_path):
            if not re.match(r'^[a-z0-9]+(-[a-z0-9]+)*$', name):
                errors.append(f"File name '{name}' should use kebab-case in {file_path}")
    
    return len(errors) == 0, errors


def main():
    """Main validation function."""
    repo_root = Path(__file__).parent.parent.parent
    all_errors = []
    total_files = 0
    
    print("🔍 Validating Claude Code plugin marketplace and configurations...")
    print()
    
    # Validate marketplace.json
    marketplace_json = repo_root / ".claude-plugin" / "marketplace.json"
    if marketplace_json.exists():
        print(f"Validating {marketplace_json.relative_to(repo_root)}...")
        total_files += 1
        valid, errors = validate_marketplace_json(marketplace_json)
        if not valid:
            all_errors.extend(errors)
        else:
            print("  ✓ Valid")
    else:
        print(f"⚠️  marketplace.json not found at {marketplace_json}")
    
    print()
    
    # Find and validate all plugin.json files
    plugin_jsons = list(repo_root.glob("plugins/*/plugin.json"))
    for plugin_json in plugin_jsons:
        print(f"Validating {plugin_json.relative_to(repo_root)}...")
        total_files += 1
        valid, errors = validate_plugin_json(plugin_json)
        if not valid:
            all_errors.extend(errors)
        else:
            print("  ✓ Valid")
    
    print()
    
    # Find and validate all agent markdown files
    agent_mds = list(repo_root.glob("plugins/*/agents/*.md"))
    for agent_md in agent_mds:
        print(f"Validating {agent_md.relative_to(repo_root)}...")
        total_files += 1
        valid, errors = validate_yaml_frontmatter(agent_md)
        if not valid:
            all_errors.extend(errors)
        else:
            print("  ✓ Valid YAML frontmatter")
        
        valid, errors = validate_naming_conventions(agent_md)
        if not valid:
            all_errors.extend(errors)
        else:
            print("  ✓ Valid naming convention")
    
    print()
    
    # Find and validate all command markdown files
    command_mds = list(repo_root.glob("plugins/*/commands/*.md"))
    for command_md in command_mds:
        print(f"Validating {command_md.relative_to(repo_root)}...")
        total_files += 1
        valid, errors = validate_yaml_frontmatter(command_md)
        if not valid:
            all_errors.extend(errors)
        else:
            print("  ✓ Valid YAML frontmatter (or optional)")
        
        valid, errors = validate_naming_conventions(command_md)
        if not valid:
            all_errors.extend(errors)
        else:
            print("  ✓ Valid naming convention")
    
    print()
    print("=" * 60)
    
    if all_errors:
        print(f"❌ Validation failed with {len(all_errors)} error(s):")
        print()
        for error in all_errors:
            print(f"  • {error}")
        print()
        print(f"Total files checked: {total_files}")
        return 1
    else:
        print(f"✅ All validations passed! ({total_files} files checked)")
        return 0


if __name__ == "__main__":
    sys.exit(main())
