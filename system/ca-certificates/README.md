# Homelab CA

`betalixt-root.crt` is the root CA from the step-ca instance at
`https://pca.betalixt.intra` (ACME directory:
`https://pca.betalixt.intra/acme/acme/directory`).

    subject  O=Betalixt CA, CN=Betalixt CA Root CA
    sha256   5A:39:DF:99:33:CD:5D:42:52:1C:BF:F0:BE:78:6F:53:92:C5:5B:7C:16:D3:D3:51:E5:AE:9C:B6:C2:D2:9A:3F
    expires  2036-01-30

This is a public certificate - it contains no private key and is safe to commit.

## Three separate trust stores need it

1. **System** (curl, openssl, git, most CLI tools)
   `install-sway-arch.sh` copies it to
   `/etc/ca-certificates/trust-source/anchors/` and runs `update-ca-trust`.

2. **Firefox / Zen** do NOT read the system store by default; they use their own
   NSS database per profile. Rather than importing into every profile's
   `cert9.db`, `zen/user.js` sets `security.enterprise_roots.enabled = true`,
   which makes them read the system store via p11-kit. One setting, and it picks
   up any future system-trusted CA automatically.

3. **Chromium family** (Brave, Edge) use the shared NSS DB at `~/.pki/nssdb`,
   which needs an explicit `certutil -A` import. `install-sway-arch.sh` does this.

## Refreshing it

If the CA is rotated, re-fetch and re-run the install script:

    curl -sk https://pca.betalixt.intra/roots.pem \
      -o ~/dotfiles/system/ca-certificates/betalixt-root.crt
    openssl x509 -in ~/dotfiles/system/ca-certificates/betalixt-root.crt \
      -noout -fingerprint -sha256      # verify before trusting

Verify the fingerprint out-of-band; the fetch above does not validate the
server it is fetching from.
