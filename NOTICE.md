# Third-party notice

These skills started from [t3dotgg/tstack](https://github.com/t3dotgg/tstack)
at commit `11e37a74d0a6868c121cd0910ab2b3bd9873b92a` (2026-11-11), MIT
License, Copyright (c) 2026 Theo Browne. Its license text is in
[`LICENSES-tstack`](LICENSES-tstack).

Vendored from tstack and adapted: `full-send`, `full-stop`, `sol-loop`,
`council`, `file-pr`, `babysit-pr` (including `scripts/pr-wait`),
`modernize`, `leaving-pr-comments`.

To see what upstream changed since the import:

```bash
git clone https://github.com/t3dotgg/tstack /tmp/tstack
git -C /tmp/tstack diff 11e37a74d0a6868c121cd0910ab2b3bd9873b92a HEAD -- skills
```
