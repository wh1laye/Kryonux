# kpkg user settings

`/etc/kpkg/config.kpkg` holds optional settings. The file ships empty: an empty file means defaults, nothing is changed. It must be owned by root and not writable by others.

Format: one `KEY=value` per line, `#` starts a comment, values may be quoted.

| Key | Default | Meaning |
| :--- | :--- | :--- |
| `JOBS` | all cores | Parallel build jobs, 0 to 256 |
| `CFLAGS`, `CXXFLAGS`, `LDFLAGS` | unset | Passed to builds; only letters, digits and `- _ = + . , / : %` are allowed, `-wrapper`, `-fplugin`, `-specs` and `-B` are refused |
| `NICE` | 0 | Build priority, 0 to 19 |
| `ASK` | yes | Ask before installing; checksums and signatures are always verified |
| `SNAPSHOTS` | 5 | btrfs snapshots kept by `kpkg upgrade` |
| `MIN_BATTERY` | 10 | Refuse to change the system on a battery below this percent, 0 disables |
| `KEEP_WORKDIR` | no | Keep build directories |

Unknown keys and bad values are reported and ignored. Verification of SHA256 and minisign cannot be switched off.
