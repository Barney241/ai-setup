# Third-party notice

These skills started from [t3dotgg/tstack](https://github.com/t3dotgg/tstack)
at commit `7de017b3fc9d50c03cf3ecb98fb71e0ca65a78bd` (2026-10-24), MIT
License, Copyright (c) 2026 Theo Browne. Its license text is in
[`LICENSES-tstack`](LICENSES-tstack).

Vendored from tstack and adapted: `full-send`, `full-stop`, `sol-loop`,
`council`, `file-pr`, `babysit-pr` (including `scripts/pr-wait`),
`modernize`, `leaving-pr-comments`.

To see what upstream changed since the import:

```bash
git clone https://github.com/t3dotgg/tstack /tmp/tstack
git -C /tmp/tstack diff 7de017b3fc9d50c03cf3ecb98fb71e0ca65a78bd HEAD -- skills
```
