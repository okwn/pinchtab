package session

import (
	"testing"
	"time"
)

// Store nil-safety: all public methods on nil Store return zero values without panicking.
func TestStore_NilRevokeReturnsFalse(t *testing.T) {
	var s *Store
	if s.Revoke("any-id") {
		t.Error("nil.Revoke() expected false, got true")
	}
}

func TestStore_NilAuthenticateReturnsFalse(t *testing.T) {
	var s *Store
	if s.Authenticate("any-token") != nil {
		t.Error("nil.Authenticate() expected nil session")
	}
}

func TestStore_NilListReturnsNil(t *testing.T) {
	var s *Store
	if s.List() != nil {
		t.Error("nil.List() expected nil")
	}
}

// Empty store behavior: operations on a store with no sessions.
func TestStore_ListEmptyReturnsNil(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred"})
	if sessions := s.List(); sessions != nil {
		t.Errorf("List() on empty store = %v, want nil", sessions)
	}
}

func TestStore_RevokeNonexistentReturnsFalse(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred"})
	if s.Revoke("does-not-exist") {
		t.Error("Revoke(nonexistent) expected false")
	}
}

func TestStore_AuthenticateBadTokenReturnsNil(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred"})
	if s.Authenticate("not-a-real-token") != nil {
		t.Error("Authenticate(invalid) expected nil session")
	}
}

// Create with duplicate agent ID is allowed (agent can hold multiple sessions).
func TestStore_CreateDuplicateAgentAllowed(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred"})
	id1, tok1, err := s.Create("agent-dup", "label-1")
	if err != nil {
		t.Fatalf("Create first: %v", err)
	}
	id2, tok2, err := s.Create("agent-dup", "label-2")
	if err != nil {
		t.Fatalf("Create second: %v", err)
	}
	if id1 == id2 {
		t.Error("duplicate Create() should yield distinct session IDs")
	}
	if tok1 == tok2 {
		t.Error("duplicate Create() should yield distinct tokens")
	}
	// Both sessions should be valid
	if s.Authenticate(tok1) == nil {
		t.Error("first token should still be valid")
	}
	if s.Authenticate(tok2) == nil {
		t.Error("second token should be valid")
	}
}

// Idle timeout validation: zero and negative idle time should be accepted (means no idle timeout).
func TestStore_CreateWithZeroIdleTimeout(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred", IdleTimeout: 0})
	_, _, err := s.Create("agent-zero", "")
	if err != nil {
		t.Fatalf("Create with IdleTimeout=0: %v", err)
	}
}

func TestStore_CreateWithNegativeIdleTimeout(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred", IdleTimeout: -time.Hour})
	_, _, err := s.Create("agent-neg", "")
	if err != nil {
		t.Fatalf("Create with IdleTimeout=-1h: %v", err)
	}
}

// Max lifetime validation: zero and negative max lifetime should be accepted.
func TestStore_CreateWithZeroMaxLifetime(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred", MaxLifetime: 0})
	_, _, err := s.Create("agent-zero-ml", "")
	if err != nil {
		t.Fatalf("Create with MaxLifetime=0: %v", err)
	}
}

func TestStore_CreateWithNegativeMaxLifetime(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred", MaxLifetime: -time.Hour})
	_, _, err := s.Create("agent-neg-ml", "")
	if err != nil {
		t.Fatalf("Create with MaxLifetime=-1h: %v", err)
	}
}

// OnLifecycle with nil function is a no-op.
func TestStore_OnLifecycleNilFnIsSafe(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred"})
	s.OnLifecycle(nil) // must not panic
	_, tok, _ := s.Create("agent-hook-nil", "")
	sess, _ := s.Authenticate(tok)
	s.Revoke(sess.ID) // must not panic
}

// Revoke already-revoked session returns false.
func TestStore_RevokeTwiceReturnsFalse(t *testing.T) {
	s := NewStore(Config{Enabled: true, Mode: "preferred"})
	_, tok, _ := s.Create("agent-rev2", "")
	sess, _ := s.Authenticate(tok)
	if !s.Revoke(sess.ID) {
		t.Fatal("first Revoke should succeed")
	}
	if s.Revoke(sess.ID) {
		t.Error("second Revoke should return false")
	}
}