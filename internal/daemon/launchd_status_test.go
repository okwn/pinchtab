package daemon

import (
	"testing"
)

func TestLaunchdManagerStatusEmptyOutput(t *testing.T) {
	// When launchctl print returns empty output with no error,
	// Status() currently returns empty string and nil error.
	// This is ambiguous - it could mean "daemon not found" or "unknown state".
	runner := &fakeCommandRunner{
		outputs: map[string]string{
			"launchctl print gui/501/com.pinchtab.pinchtab": "",
		},
	}
	manager := &launchdManager{
		env:    environment{osName: "darwin", userID: "501"},
		runner: runner,
	}

	output, err := manager.Status()
	if err != nil {
		t.Fatalf("expected no error, got: %v", err)
	}
	// The current behavior returns an empty string for empty output.
	// This test documents the current behavior.
	if output != "Pinchtab daemon status returned no output." {
		t.Fatalf("got: %q", output)
	}
}

func TestLaunchdManagerPidNotRunning(t *testing.T) {
	// When the daemon is not running, launchctl print returns an error.
	// Pid() should return ("", nil) since no pid can be read.
	runner := &fakeCommandRunner{
		errors: map[string]error{
			"launchctl print gui/501/com.pinchtab.pinchtab": errors.New("daemon not running"),
		},
	}
	manager := &launchdManager{
		env:    environment{osName: "darwin", userID: "501"},
		runner: runner,
	}

	pid, err := manager.Pid()
	if err != nil {
		t.Fatalf("expected no error for not-running daemon, got: %v", err)
	}
	if pid != "" {
		t.Fatalf("expected empty pid for not-running daemon, got: %q", pid)
	}
}

func TestLaunchdManagerPidMalformedOutput(t *testing.T) {
	// When launchctl returns output without a "pid =" line,
	// Pid() should return ("", nil) rather than truncating or panicking.
	runner := &fakeCommandRunner{
		outputs: map[string]string{
			"launchctl print gui/501/com.pinchtab.pinchtab": "Something went wrong\nNo pid here\n",
		},
	}
	manager := &launchdManager{
		env:    environment{osName: "darwin", userID: "501"},
		runner: runner,
	}

	pid, err := manager.Pid()
	if err != nil {
		t.Fatalf("expected no error for malformed output, got: %v", err)
	}
	if pid != "" {
		t.Fatalf("expected empty pid for malformed output, got: %q", pid)
	}
}