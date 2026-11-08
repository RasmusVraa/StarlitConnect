package core

import (
	"context"
	"fmt"
	"net"
	"slices"
	"strings"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

const (
	delayTestConcurrency = 50
	// tcp://node → dial proxy.Addr() (server host:port). HTTP URLs still use URLTest.
	defaultTestURL          = "tcp://node"
	defaultDelayTestTimeout = 5 * time.Second
)

var (
	delayTestSlots     = make(slots, delayTestConcurrency)
	anyDelayTestStatus utils.IntRanges[uint16]

	testURL                 atomic.Pointer[string]
	missingDelayTestProxyAt atomic.Int64
)

func setTestURL(url string) {
	if url == "" {
		return
	}
	testURL.Store(&url)
	// mihomo health-checks call URLTest with DefaultTestURL; keep that HTTP-only.
	if !isTCPPingURL(url) {
		constant.DefaultTestURL = url
	}
}

func currentTestURL() string {
	if url := testURL.Load(); url != nil && *url != "" {
		return *url
	}
	return defaultTestURL
}

const (
	delayTimedOut int32 = -1
	delayFailed   int32 = -2
)

func delayValue(delay uint16, timedOut bool) int32 {
	switch {
	case delay > 0:
		return int32(delay)
	case timedOut:
		return delayTimedOut
	default:
		return delayFailed
	}
}

// A name the tunnel does not know is what an apply that fell back to the
// default config looks like: every node of the profile fails its test. Say so
// once a second, not once per node, so the log names the real failure.
func reportMissingDelayTestProxy(name string) {
	now := time.Now().UnixNano()
	last := missingDelayTestProxyAt.Load()
	if last != 0 && now-last < int64(time.Second) {
		return
	}
	if !missingDelayTestProxyAt.CompareAndSwap(last, now) {
		return
	}
	logError("delay test: %q is not part of the applied config", name)
}

// A nil answer means the test never got a slot, which says nothing about the proxy.
func handleTestDelay(params *TestDelayParams) *Delay {
	url := params.TestUrl
	if url == "" {
		url = currentTestURL()
	}
	result := &Delay{Name: params.ProxyName, Url: url, Value: delayFailed}

	proxy := lookupProxy(params.ProxyName)
	if proxy == nil {
		reportMissingDelayTestProxy(params.ProxyName)
		return result
	}

	timeout, configured := configuredTestTimeout(proxy.Name(), url)
	if !configured {
		timeout = timeoutFromMillis(params.Timeout, defaultDelayTestTimeout)
	}
	if !delayTestSlots.acquireWithin(context.Background(), timeout) {
		return nil
	}
	defer delayTestSlots.release()

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	var delay uint16
	var err error
	if isTCPPingURL(url) {
		if isUDPNativeProxy(proxy) {
			// Hysteria/TUIC listen on UDP — TCP to Addr always times out.
			delay, err = proxy.URLTest(ctx, hysteriaProbeURL, anyDelayTestStatus)
		} else {
			delay, err = tcpPingNode(ctx, proxy)
		}
	} else {
		delay, err = proxy.URLTest(ctx, url, anyDelayTestStatus)
	}
	if err != nil {
		delay = 0
	}
	result.Value = delayValue(delay, ctx.Err() != nil)
	return result
}

const hysteriaProbeURL = "https://cp.cloudflare.com/generate_204"

func isTCPPingURL(url string) bool {
	return strings.HasPrefix(strings.ToLower(url), "tcp://")
}

func isUDPNativeProxy(proxy constant.Proxy) bool {
	switch proxy.Type() {
	case constant.Hysteria, constant.Hysteria2, constant.Tuic:
		return true
	default:
		n := strings.ToUpper(proxy.Name())
		return strings.Contains(n, "HY2") ||
			strings.Contains(n, "HYSTERIA") ||
			strings.Contains(n, "TUIC")
	}
}

// tcpPingNode dials the outbound's own server host:port — no tunnel, no HTTP.
func tcpPingNode(ctx context.Context, proxy constant.Proxy) (uint16, error) {
	addr := strings.TrimSpace(proxy.Addr())
	if addr == "" {
		return 0, fmt.Errorf("proxy %q has empty Addr", proxy.Name())
	}
	if _, _, err := net.SplitHostPort(addr); err != nil {
		addr = net.JoinHostPort(addr, "443")
	}
	start := time.Now()
	var d net.Dialer
	conn, err := d.DialContext(ctx, "tcp", addr)
	if err != nil {
		return 0, err
	}
	_ = conn.Close()
	ms := time.Since(start) / time.Millisecond
	if ms <= 0 {
		return 1, nil
	}
	if ms > 0xffff {
		return 0xffff, nil
	}
	return uint16(ms), nil
}

type testTimeoutProvider interface {
	TestTimeout(url string) (time.Duration, bool)
}

// The longest stands, so no scheduled check passes a node the manual test fails.
func configuredTestTimeout(name, url string) (time.Duration, bool) {
	var longest time.Duration
	for _, pd := range tunnel.ProvidersSnapshot() {
		timed, ok := pd.(testTimeoutProvider)
		if !ok {
			continue
		}
		timeout, ok := timed.TestTimeout(url)
		if !ok || timeout <= longest {
			continue
		}
		if slices.ContainsFunc(pd.Proxies(), func(p constant.Proxy) bool { return p.Name() == name }) {
			longest = timeout
		}
	}
	return longest, longest > 0
}
