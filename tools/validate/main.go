package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// MarketplaceConfig represents the marketplace.json structure
type MarketplaceConfig struct {
	Schema      string   `json:"$schema"`
	Name        string   `json:"name"`
	Owner       Owner    `json:"owner"`
	Description string   `json:"description"`
	Version     string   `json:"version"`
	Plugins     []Plugin `json:"plugins"`
}

type Owner struct {
	Name  string `json:"name"`
	Email string `json:"email"`
	URL   string `json:"url,omitempty"`
}

type Plugin struct {
	Name        string `json:"name"`
	Source      string `json:"source"`
	Description string `json:"description,omitempty"`
	Version     string `json:"version,omitempty"`
	Author      *Owner `json:"author,omitempty"`
	Category    string `json:"category,omitempty"`
}

// PluginConfig represents the plugin.json structure
type PluginConfig struct {
	Name        string                 `json:"name"`
	DisplayName string                 `json:"displayName,omitempty"`
	Description string                 `json:"description"`
	Version     string                 `json:"version"`
	Author      Owner                  `json:"author"`
	License     string                 `json:"license,omitempty"`
	Repository  string                 `json:"repository,omitempty"`
	Homepage    string                 `json:"homepage,omitempty"`
	Keywords    []string               `json:"keywords,omitempty"`
	Agents      string                 `json:"agents,omitempty"`
	Commands    string                 `json:"commands,omitempty"`
	MCPServers  map[string]interface{} `json:"mcpServers,omitempty"`
}

func validateMarketplace(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	var config MarketplaceConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}

	// Validate required fields
	if config.Name == "" {
		return fmt.Errorf("name is required")
	}
	if config.Owner.Name == "" {
		return fmt.Errorf("owner.name is required")
	}
	if config.Owner.Email == "" {
		return fmt.Errorf("owner.email is required")
	}
	if config.Version == "" {
		return fmt.Errorf("version is required")
	}
	if len(config.Plugins) == 0 {
		return fmt.Errorf("at least one plugin is required")
	}

	// Validate each plugin
	for i, plugin := range config.Plugins {
		if plugin.Name == "" {
			return fmt.Errorf("plugin[%d].name is required", i)
		}
		if plugin.Source == "" {
			return fmt.Errorf("plugin[%d].source is required", i)
		}
	}

	return nil
}

func validatePlugin(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	var config PluginConfig
	if err := json.Unmarshal(data, &config); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}

	// Validate required fields
	if config.Name == "" {
		return fmt.Errorf("name is required")
	}
	if config.Description == "" {
		return fmt.Errorf("description is required")
	}
	if config.Version == "" {
		return fmt.Errorf("version is required")
	}
	if config.Author.Name == "" {
		return fmt.Errorf("author.name is required")
	}
	if config.Author.Email == "" {
		return fmt.Errorf("author.email is required")
	}

	return nil
}

func validateYAMLFrontmatter(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read file: %w", err)
	}

	content := string(data)
	if !strings.HasPrefix(content, "---\n") {
		// Frontmatter is optional for commands
		if strings.Contains(path, "/commands/") {
			return nil
		}
		return fmt.Errorf("missing YAML frontmatter")
	}

	// Simple validation - just check that frontmatter closes
	parts := strings.SplitN(content, "---\n", 3)
	if len(parts) < 3 {
		return fmt.Errorf("YAML frontmatter not properly closed")
	}

	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <path>\n", os.Args[0])
		os.Exit(1)
	}

	rootPath := os.Args[1]
	hasErrors := false

	// Validate marketplace.json
	marketplacePath := filepath.Join(rootPath, ".claude-plugin", "marketplace.json")
	if _, err := os.Stat(marketplacePath); err == nil {
		fmt.Printf("Validating %s...\n", marketplacePath)
		if err := validateMarketplace(marketplacePath); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR in %s: %v\n", marketplacePath, err)
			hasErrors = true
		} else {
			fmt.Printf("✓ %s is valid\n", marketplacePath)
		}
	}

	// Find and validate all plugin.json files
	err := filepath.Walk(filepath.Join(rootPath, "plugins"), func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.IsDir() {
			return nil
		}

		switch {
		case info.Name() == "plugin.json":
			fmt.Printf("Validating %s...\n", path)
			if err := validatePlugin(path); err != nil {
				fmt.Fprintf(os.Stderr, "ERROR in %s: %v\n", path, err)
				hasErrors = true
			} else {
				fmt.Printf("✓ %s is valid\n", path)
			}

		case strings.HasSuffix(info.Name(), ".md"):
			if strings.Contains(path, "/agents/") || strings.Contains(path, "/commands/") {
				fmt.Printf("Validating %s...\n", path)
				if err := validateYAMLFrontmatter(path); err != nil {
					fmt.Fprintf(os.Stderr, "ERROR in %s: %v\n", path, err)
					hasErrors = true
				} else {
					fmt.Printf("✓ %s is valid\n", path)
				}
			}
		}

		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR walking directory: %v\n", err)
		os.Exit(1)
	}

	if hasErrors {
		os.Exit(1)
	}

	fmt.Println("\n✓ All validations passed!")
}
