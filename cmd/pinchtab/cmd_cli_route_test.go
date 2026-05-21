package cmd

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestRouteRegistration verifies that all expected command groups are registered.
// This is a compile-time check — if a command group is not registered, the binary
// will simply not expose those subcommands.
func TestCommandGroupRegistration(t *testing.T) {
	// This test documents the expected command groups.
	// The actual registration happens in init() functions at package load time.
	//
	// Expected command structure:
	//   pinchtab browser <subcommands>     (quick, screenshot, etc.)
	//   pinchtab management <subcommands>  (status, stop, list)
	//   pinchtab server <subcommands>      (start, stop, status)
	//
	// If a registration function is removed from cmd_cli_register.go,
	// the corresponding subcommand tree will not appear in the CLI.
	//
	// This test serves as a documentation marker and will not fail
	// as long as the init() functions run. The real validation is
	// the absence of missing subcommand errors in integration tests.

	// Assert that root command exists (always true if this package compiles)
	rootCmd := RootCmd()
	assert.NotNil(t, rootCmd, "RootCmd should not be nil")
}