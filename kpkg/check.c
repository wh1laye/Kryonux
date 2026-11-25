#include "kpkg.h"
static const char *const cats_ok[] = { "system", "fs", "network", "toolchain", "build", "tools", "libs", "boot", "init", "admin", NULL };
static int cat_ok(const char *c)
{
	int i;
	for (i = 0; cats_ok[i]; i++)
		if (!strcmp(cats_ok[i], c)) return 1;
	return 0;
}
static int skip(const char *n)
{
	return n[0] == '.' || !strcmp(n, "files") || !strcmp(n, "metadata") || !strcmp(n, "profiles");
}
static int check_deps(const char *root, const char *path, const struct recipe *r)
{
	char all[2048], buf[2048], *tok, *save = NULL, probe[BUF + 512];
	int bad = 0;
	snprintf(all, sizeof all, "%s %s", r->depend, r->rdepend);
	snprintf(buf, sizeof buf, "%s", all);
	for (tok = strtok_r(buf, " \t\n", &save); tok; tok = strtok_r(NULL, " \t\n", &save)) {
		if (!strchr(tok, '/')) {
			fprintf(stderr, "kpkg: %s: dependency %s must be category/name\n", path, tok);
			bad++;
			continue;
		}
		if (!strncmp(tok, "virtual/", 8)) continue;
		snprintf(probe, sizeof probe, "%s/%s", root, tok);
		if (!is_dir(probe)) {
			fprintf(stderr, "kpkg: %s: dependency %s has no recipe in this tree\n", path, tok);
			bad++;
		}
	}
	return bad;
}
static int check_pkg(const char *root, const char *cat, const char *name, const char *vdir)
{
	char path[BUF + 512], want[512];
	struct recipe r;
	int bad = 0, n;
	if (snprintf(path, sizeof path, "%s/%s/%s/%s/%s.kpkg", root, cat, name, vdir, vdir) >= (int)sizeof path) return 1;
	if (!exists(path)) {
		fprintf(stderr, "kpkg: %s/%s/%s: expected %s.kpkg inside\n", cat, name, vdir, vdir);
		return 1;
	}
	n = recipe_lint(path);
	if (n) return n;
	recipe_init(&r);
	if (!recipe_load(path, &r)) return 1;
	snprintf(want, sizeof want, "%s-%s", r.name, r.version);
	if (strcmp(r.name, name)) {
		fprintf(stderr, "kpkg: %s: PACKAGE is %s, the directory is %s\n", path, r.name, name);
		bad++;
	}
	if (strcmp(want, vdir)) {
		fprintf(stderr, "kpkg: %s: directory is %s, expected %s\n", path, vdir, want);
		bad++;
	}
	bad += check_deps(root, path, &r);
	recipe_free(&r);
	return bad;
}
int cmd_check(int argc, char **argv)
{
	const char *root = argc > 0 ? argv[0] : repo;
	struct dirent **cl = NULL, **nl = NULL, **vl = NULL;
	char p[BUF + 256], q[BUF + 512];
	int nc, nn, nv, i, j, k, bad = 0, pkgs = 0;
	if (argc > 1) {
		fputs("kpkg: usage: kpkg check [tree]\n", stderr);
		return 1;
	}
	nc = scandir(root, &cl, NULL, alphasort);
	if (nc < 0) {
		fprintf(stderr, "kpkg: cannot read %s\n", root);
		return 1;
	}
	for (i = 0; i < nc; i++) {
		if (skip(cl[i]->d_name)) { free(cl[i]); continue; }
		snprintf(p, sizeof p, "%s/%s", root, cl[i]->d_name);
		if (!is_dir(p)) { free(cl[i]); continue; }
		if (!cat_ok(cl[i]->d_name)) {
			fprintf(stderr, "kpkg: unknown category %s\n", cl[i]->d_name);
			bad++;
			free(cl[i]);
			continue;
		}
		nn = scandir(p, &nl, NULL, alphasort);
		for (j = 0; j < nn; j++) {
			if (nl[j]->d_name[0] != '.') {
				snprintf(q, sizeof q, "%s/%s", p, nl[j]->d_name);
				nv = scandir(q, &vl, NULL, alphasort);
				for (k = 0; k < nv; k++) {
					if (vl[k]->d_name[0] != '.') {
						pkgs++;
						bad += check_pkg(root, cl[i]->d_name, nl[j]->d_name, vl[k]->d_name);
					}
					free(vl[k]);
				}
				if (nv >= 0) free(vl);
			}
			free(nl[j]);
		}
		if (nn >= 0) free(nl);
		free(cl[i]);
	}
	free(cl);
	printf("kpkg: %d recipes checked, %d problems\n", pkgs, bad);
	return bad ? 1 : 0;
}
