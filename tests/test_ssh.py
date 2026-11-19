"""Tests for model/Ssh.mjs: host key fingerprints and authorized_keys parsing."""

import subprocess


class TestHostKeys:
    def test_fingerprint_line_is_parsed(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.parseHostKeyFingerprints('
            '"256 SHA256:abc123 root@vemberos (ED25519)\\n")))'
        )
        assert out == [
            {
                "bits": "256",
                "fingerprint": "SHA256:abc123",
                "comment": "root@vemberos",
                "type": "ED25519",
            }
        ]

    def test_multiple_keys_are_all_returned(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.parseHostKeyFingerprints('
            '"3072 SHA256:a a@h (RSA)\\n256 SHA256:b b@h (ED25519)\\n")))'
        )
        assert [k["type"] for k in out] == ["RSA", "ED25519"]

    def test_unparseable_lines_are_skipped(self, js):
        out = js('console.log(JSON.stringify(Ssh.parseHostKeyFingerprints("garbage\\n")))')
        assert out == []

    def test_command_scans_host_public_keys(self, js):
        cmd = js("console.log(JSON.stringify(Ssh.hostKeyFingerprintsCommand()))")
        assert cmd[0] == "sh"
        assert "/etc/ssh/ssh_host_*key.pub" in cmd[2]
        assert "ssh-keygen -lf" in cmd[2]
        result = subprocess.run(
            ["sh", "-n"], input=cmd[2], capture_output=True, text=True
        )
        assert result.returncode == 0, result.stderr


class TestAuthorizedKeys:
    def test_ed25519_key_is_parsed(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.parseAuthorizedKeys('
            '"ssh-ed25519 AAAAC3Nza me@host\\n")))'
        )
        assert len(out) == 1
        assert out[0]["type"] == "ssh-ed25519"
        assert out[0]["keyData"] == "AAAAC3Nza"
        assert out[0]["comment"] == "me@host"
        assert out[0]["lineNo"] == 1

    def test_comments_and_blank_lines_are_skipped(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.parseAuthorizedKeys('
            '"# a comment\\n\\nssh-ed25519 AAAA me\\n")))'
        )
        assert len(out) == 1
        assert out[0]["lineNo"] == 3

    def test_options_prefix_is_tolerated(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.parseAuthorizedKeys('
            '"from=\\"1.2.3.4\\" ssh-rsa AAAAB3 me@host\\n")))'
        )
        assert out[0]["type"] == "ssh-rsa"
        assert out[0]["keyData"] == "AAAAB3"

    def test_long_key_is_previewed(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.parseAuthorizedKeys('
            '"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabcdefgh me\\n")))'
        )
        assert "…" in out[0]["keyPreview"]
        assert len(out[0]["keyPreview"]) < len(out[0]["keyData"])

    def test_empty_file_yields_nothing(self, js):
        assert js('console.log(JSON.stringify(Ssh.parseAuthorizedKeys("")))') == []

    def test_path_lives_under_home(self, js):
        out = js('console.log(JSON.stringify(Ssh.authorizedKeysPath("/home/x")))')
        assert out == "/home/x/.ssh/authorized_keys"

    def test_read_command_targets_that_path(self, js):
        cmd = js('console.log(JSON.stringify(Ssh.authorizedKeysReadCommand("/home/x")))')
        assert cmd[-1] == "/home/x/.ssh/authorized_keys"
        assert "cat" in cmd[2]


class TestValidatePublicKeyLine:
    """A pasted key must be validated before it is appended to authorized_keys.

    Without validation a private key, a multi-line blob or a typo is written
    silently and reported as added, while it never authenticates — and a
    pasted private key must never touch disk at all.
    """

    def test_accepts_ed25519_key(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.validatePublicKeyLine('
            '"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIabc me@host")))'
        )
        assert out == {
            "ok": True,
            "type": "ssh-ed25519",
            "keyData": "AAAAC3NzaC1lZDI1NTE5AAAAIabc",
            "comment": "me@host",
        }

    def test_accepts_rsa_key_without_comment(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.validatePublicKeyLine('
            '"ssh-rsa AAAAB3NzaC1yc2E=")))'
        )
        assert out["ok"] is True
        assert out["type"] == "ssh-rsa"
        assert out["comment"] == ""

    def test_rejects_empty(self, js):
        out = js('console.log(JSON.stringify(Ssh.validatePublicKeyLine("   ")))')
        assert out["ok"] is False
        assert "Paste a public key" in out["reason"]

    def test_rejects_private_key(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.validatePublicKeyLine('
            '"-----BEGIN OPENSSH PRIVATE KEY-----\\\\nAAAA\\\\n-----END OPENSSH PRIVATE KEY-----")))'
        )
        assert out["ok"] is False
        # Multi-line is caught first, but either reason must mention private key
        # or single-line; the key point is that it is rejected.
        assert "private key" in out["reason"].lower() or "single line" in out["reason"].lower()

    def test_rejects_multiline(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.validatePublicKeyLine('
            '"ssh-ed25519 AAAA a\\nssh-ed25519 BBBB b")))'
        )
        assert out["ok"] is False
        assert "single line" in out["reason"].lower()

    def test_rejects_non_key_text(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.validatePublicKeyLine("hello world")))'
        )
        assert out["ok"] is False
        assert "not an ssh public key" in out["reason"].lower()

    def test_rejects_bad_base64(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.validatePublicKeyLine('
            '"ssh-ed25519 not!!base64 me")))'
        )
        assert out["ok"] is False
        assert "base64" in out["reason"].lower()

    def test_trims_surrounding_whitespace(self, js):
        out = js(
            'console.log(JSON.stringify(Ssh.validatePublicKeyLine('
            '"  ssh-ed25519 AAAA me@host  ")))'
        )
        assert out["ok"] is True
        assert out["type"] == "ssh-ed25519"
        assert out["comment"] == "me@host"
