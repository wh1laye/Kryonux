What changed and why:

Checks:
- [ ] `make -C kpkg` builds without warnings.
- [ ] `node tools/test-site.js` passes.
- [ ] `shellcheck -S error` is clean on the changed scripts.
- [ ] The change adds no security risk (root, sudo, file downloads, user input).
- [ ] `CHANGELOG.md` is updated.
