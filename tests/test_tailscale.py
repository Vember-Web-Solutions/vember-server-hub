"""Tests for model/Tailscale.mjs: status commands and JSON parsing."""

import json


class TestCommands:
    def test_status_commands_are_argv_arrays(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Tailscale.statusCommand(), Tailscale.statusJsonCommand(), Tailscale.ipCommand()]))"
        )
        assert out[0] == ["tailscale", "status", "--self=false"]
        assert out[1] == ["tailscale", "status", "--json"]
        assert out[2] == ["tailscale", "ip", "-4"]


class TestParseStatus:
    def test_running_backend_and_self_are_parsed(self, js):
        payload = (
            '{"BackendState":"Running","MagicDNSSuffix":"tail.ts.net",'
            '"Self":{"HostName":"vemberos","DNSName":"vemberos.tail.ts.net.",'
            '"TailscaleIPs":["100.1.2.3"],"OS":"linux","Online":true,"Active":true}}'
        )
        out = js(
            "console.log(JSON.stringify(Tailscale.parseStatusJson(%s)))"
            % json.dumps(payload)
        )
        assert out["ok"] is True
        assert out["backendState"] == "Running"
        assert out["magicDnsSuffix"] == "tail.ts.net"
        assert out["tailnetName"] == "tail.ts.net"
        assert out["self"]["hostName"] == "vemberos"
        # The trailing dot is stripped so names are display-ready.
        assert out["self"]["dnsName"] == "vemberos.tail.ts.net"
        assert out["self"]["ips"] == ["100.1.2.3"]
        assert out["self"]["isSelf"] is True

    def test_empty_input_is_not_ok(self, js):
        out = js('console.log(JSON.stringify(Tailscale.parseStatusJson("")))')
        assert out["ok"] is False
        assert out["peers"] == []

    def test_invalid_json_is_not_ok(self, js):
        out = js('console.log(JSON.stringify(Tailscale.parseStatusJson("{oops")))')
        assert out["ok"] is False

    def test_online_peers_sort_before_offline(self, js):
        payload = (
            '{"BackendState":"Running","Peer":{'
            '"a":{"HostName":"zeta","Online":false},'
            '"b":{"HostName":"alpha","Online":true}}}'
        )
        out = js(
            "console.log(JSON.stringify(Tailscale.parseStatusJson(%s)))"
            % json.dumps(payload)
        )
        assert [p["hostName"] for p in out["peers"]] == ["alpha", "zeta"]

    def test_peers_are_sorted_by_name_within_a_group(self, js):
        payload = (
            '{"BackendState":"Running","Peer":{'
            '"a":{"HostName":"beta","Online":true},'
            '"b":{"HostName":"alpha","Online":true}}}'
        )
        out = js(
            "console.log(JSON.stringify(Tailscale.parseStatusJson(%s)))"
            % json.dumps(payload)
        )
        assert [p["hostName"] for p in out["peers"]] == ["alpha", "beta"]

    def test_peer_fields_are_normalised(self, js):
        payload = (
            '{"BackendState":"Running","Peer":{'
            '"k":{"HostName":"peer","DNSName":"peer.tail.ts.net.",'
            '"TailscaleIPs":["100.9.9.9"],"OS":"linux","Online":true,'
            '"Active":false,"LastSeen":"2026-01-01T00:00:00Z"}}}'
        )
        out = js(
            "console.log(JSON.stringify(Tailscale.parseStatusJson(%s)))"
            % json.dumps(payload)
        )
        peer = out["peers"][0]
        assert peer["dnsName"] == "peer.tail.ts.net"
        assert peer["ips"] == ["100.9.9.9"]
        assert peer["isSelf"] is False
        assert peer["lastSeen"] == "2026-01-01T00:00:00Z"

    def test_tailnet_name_falls_back_to_current_tailnet(self, js):
        payload = '{"BackendState":"Running","CurrentTailnet":{"Name":"my-tailnet"}}'
        out = js(
            "console.log(JSON.stringify(Tailscale.parseStatusJson(%s)))"
            % json.dumps(payload)
        )
        assert out["tailnetName"] == "my-tailnet"

    def test_status_text_is_accepted_by_tail(self, js):
        # The panel pipes `tailscale status` through the same trim helpers; a
        # stray newline must not break parsing.
        payload = '{"BackendState":"Stopped"}\n'
        out = js(
            "console.log(JSON.stringify(Tailscale.parseStatusJson(%s)))"
            % json.dumps(payload)
        )
        assert out["ok"] is True
        assert out["backendState"] == "Stopped"


class TestOnlinePeerCount:
    def test_counts_online_peers(self, js):
        out = js(
            "console.log(JSON.stringify(Tailscale.onlinePeerCount("
            "[{online:true},{online:false},{online:true}])))"
        )
        assert out == 2

    def test_empty_and_null_are_zero(self, js):
        out = js(
            "console.log(JSON.stringify(["
            "Tailscale.onlinePeerCount([]), Tailscale.onlinePeerCount(null)]))"
        )
        assert out == [0, 0]

    def test_malformed_rows_are_skipped(self, js):
        out = js(
            "console.log(JSON.stringify(Tailscale.onlinePeerCount("
            "[null,{online:true},{}])))"
        )
        assert out == 1
