package handlers

import (
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"testing"

	"github.com/pinchtab/pinchtab/internal/config"
)

func TestHandleRecordStart_Disabled(t *testing.T) {
	cfg := &config.RuntimeConfig{AllowScreencast: false}
	h := New(&mockBridge{}, cfg, nil, nil, nil)

	body := `{"format":"gif","fps":5}`
	req := httptest.NewRequest("POST", "/record/start", bytes.NewReader([]byte(body)))
	w := httptest.NewRecorder()
	h.HandleRecordStart(w, req)

	if w.Code != 403 {
		t.Errorf("expected 403 when recording disabled, got %d", w.Code)
	}
}

func TestHandleRecordStart_InvalidFormat(t *testing.T) {
	cfg := &config.RuntimeConfig{AllowScreencast: true}
	h := New(&mockBridge{}, cfg, nil, nil, nil)

	body := `{"format":"avi","fps":5}`
	req := httptest.NewRequest("POST", "/record/start", bytes.NewReader([]byte(body)))
	w := httptest.NewRecorder()
	h.HandleRecordStart(w, req)

	if w.Code != 400 {
		t.Errorf("expected 400 for invalid format, got %d", w.Code)
	}
}

func TestHandleRecordStart_TabNotFound(t *testing.T) {
	cfg := &config.RuntimeConfig{AllowScreencast: true}
	h := New(&mockBridge{failTab: true}, cfg, nil, nil, nil)

	body := `{"format":"gif","fps":5,"tabId":"missing"}`
	req := httptest.NewRequest("POST", "/record/start", bytes.NewReader([]byte(body)))
	w := httptest.NewRecorder()
	h.HandleRecordStart(w, req)

	if w.Code != 404 {
		t.Errorf("expected 404 for missing tab, got %d", w.Code)
	}
}

func TestHandleRecordStart_Success(t *testing.T) {
	cfg := &config.RuntimeConfig{AllowScreencast: true}
	h := New(&mockBridge{}, cfg, nil, nil, nil)

	body := `{"format":"gif","fps":5}`
	req := httptest.NewRequest("POST", "/record/start", bytes.NewReader([]byte(body)))
	w := httptest.NewRecorder()
	h.HandleRecordStart(w, req)

	if w.Code != 200 {
		t.Fatalf("expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp["status"] != "recording" {
		t.Errorf("expected status=recording, got %v", resp["status"])
	}
	if resp["format"] != "gif" {
		t.Errorf("expected format=gif, got %v", resp["format"])
	}
	if resp["fps"] != float64(5) {
		t.Errorf("expected fps=5, got %v", resp["fps"])
	}
	if resp["tabId"] == nil || resp["tabId"] == "" {
		t.Errorf("expected tabId to be set, got %v", resp["tabId"])
	}

	// Clean up: stop the recording (ignore error since no frames captured)
	_, _, _ = h.recorder.stop()
}

func TestHandleRecordStart_AlreadyRecording(t *testing.T) {
	cfg := &config.RuntimeConfig{AllowScreencast: true}
	h := New(&mockBridge{}, cfg, nil, nil, nil)

	// First start: should succeed
	body := `{"format":"gif","fps":5}`
	req := httptest.NewRequest("POST", "/record/start", bytes.NewReader([]byte(body)))
	w := httptest.NewRecorder()
	h.HandleRecordStart(w, req)

	if w.Code != 200 {
		t.Fatalf("first start: expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Second start: should return 409
	req = httptest.NewRequest("POST", "/record/start", bytes.NewReader([]byte(body)))
	w = httptest.NewRecorder()
	h.HandleRecordStart(w, req)

	if w.Code != 409 {
		t.Errorf("expected 409 for already recording, got %d: %s", w.Code, w.Body.String())
	}

	// Clean up: stop the recording (ignore error since no frames captured)
	_, _, _ = h.recorder.stop()
}

func TestHandleRecordStop_NoRecording(t *testing.T) {
	cfg := &config.RuntimeConfig{}
	h := New(&mockBridge{}, cfg, nil, nil, nil)

	req := httptest.NewRequest("POST", "/record/stop", nil)
	w := httptest.NewRecorder()
	h.HandleRecordStop(w, req)

	if w.Code != 400 {
		t.Errorf("expected 400 when no recording active, got %d", w.Code)
	}
}

func TestHandleRecordStatus_Inactive(t *testing.T) {
	cfg := &config.RuntimeConfig{}
	h := New(&mockBridge{}, cfg, nil, nil, nil)

	req := httptest.NewRequest("GET", "/record/status", nil)
	w := httptest.NewRecorder()
	h.HandleRecordStatus(w, req)

	if w.Code != 200 {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var resp RecordingStatus
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Active {
		t.Errorf("expected active=false, got true")
	}
}

func TestHandleRecordStatus_Active(t *testing.T) {
	cfg := &config.RuntimeConfig{AllowScreencast: true}
	h := New(&mockBridge{}, cfg, nil, nil, nil)

	// Start a recording first
	body := `{"format":"gif","fps":5}`
	req := httptest.NewRequest("POST", "/record/start", bytes.NewReader([]byte(body)))
	w := httptest.NewRecorder()
	h.HandleRecordStart(w, req)

	if w.Code != 200 {
		t.Fatalf("start: expected 200, got %d: %s", w.Code, w.Body.String())
	}

	// Check status
	req = httptest.NewRequest("GET", "/record/status", nil)
	w = httptest.NewRecorder()
	h.HandleRecordStatus(w, req)

	if w.Code != 200 {
		t.Fatalf("status: expected 200, got %d", w.Code)
	}

	var resp RecordingStatus
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !resp.Active {
		t.Errorf("expected active=true, got false")
	}
	if resp.Format != "gif" {
		t.Errorf("expected format=gif, got %q", resp.Format)
	}
	if resp.FPS != 5 {
		t.Errorf("expected fps=5, got %d", resp.FPS)
	}

	// Clean up: stop the recording (ignore error since no frames captured)
	_, _, _ = h.recorder.stop()
}

func TestFFmpegAvailable(t *testing.T) {
	// Just verify it doesn't panic; result depends on environment.
	_ = ffmpegAvailable()
}
