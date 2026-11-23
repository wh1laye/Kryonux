#include <limits.h>
#include "kpkg.h"
struct opts { int pretend; int ask; int yes; int oneshot; int force; int no_snapshot; };
struct plan_item { char cat[128]; char name[128]; char ver[64]; char oldver[64]; int explicit; int upgrade; };
static struct plan_item plan[MAXPLAN];
static int nplan;
static char **visiting;
static int nvisiting;
static char **visited;
static int nvisited;
static void plan_reset(void)
{
	nplan = 0;
	list_free(visiting, nvisiting);
	visiting = NULL;
	nvisiting = 0;
	list_free(visited, nvisited);
	visited = NULL;
	nvisited = 0;
}
static void visiting_pop(void)
{
	free(visiting[nvisiting - 1]);
	nvisiting--;
}
static int parse_opts(int argc, char **argv, struct opts *o, char ***pkgs, int *npk)
{
	int i;
	memset(o, 0, sizeof *o);
	*pkgs = NULL;
	*npk = 0;
	for (i = 0; i < argc; i++) {
		if (!strcmp(argv[i], "-p") || !strcmp(argv[i], "--pretend")) o->pretend = 1;
		else if (!strcmp(argv[i], "-a") || !strcmp(argv[i], "--ask")) o->ask = 1;
		else if (!strcmp(argv[i], "-y") || !strcmp(argv[i], "--yes")) o->yes = 1;
		else if (!strcmp(argv[i], "-o") || !strcmp(argv[i], "--oneshot")) o->oneshot = 1;
		else if (!strcmp(argv[i], "--force") || !strcmp(argv[i], "-f")) o->force = 1;
		else if (!strcmp(argv[i], "--no-snapshot")) o->no_snapshot = 1;
		else if (!strcmp(argv[i], "--jobs") && i + 1 < argc) {
			jobs = atoi(argv[++i]);
			if (jobs < 1) jobs = 1;
			if (jobs > 256) jobs = 256;
		}
		else if (argv[i][0] == '-') {
			fprintf(stderr, "kpkg: unknown option: %s\n", argv[i]);
			return 0;
		} else {
			list_add(pkgs, npk, argv[i]);
		}
	}
	if (getenv("KPKG_ASSUME_YES")) o->yes = 1;
	if (!o->yes && !o->pretend) o->ask = 1;
	return 1;
}
static int confirm(void)
{
	char ans[16];
	if (!isatty(0)) {
		fputs("kpkg: confirmation is required and there is no terminal, pass -y to proceed\n", stderr);
		return 0;
	}
	fprintf(stderr, "\n%s::%s Proceed? [Y/n] ", C('b'), C('0'));
	if (!fgets(ans, sizeof ans, stdin)) return 0;
	return !(ans[0] == 'n' || ans[0] == 'N');
}
static int find_category(const char *name, char *cat, size_t cn)
{
	char **cats = NULL, p[BUF];
	int nc, i, found = 0;
	nc = tree_categories(&cats);
	for (i = 0; i < nc && !found; i++) {
		snprintf(p, sizeof p, "%s/%s/%s", repo, cats[i], name);
		if (is_dir(p)) {
			snprintf(cat, cn, "%s", cats[i]);
			found = 1;
		}
	}
	list_free(cats, nc);
	return found;
}
#ifndef HOLDFILE
#define HOLDFILE "/etc/kpkg/hold"
#endif
static int is_held(const char *cat, const char *name)
{
	char line[300], key[260];
	FILE *f = fopen(HOLDFILE, "r");
	int held = 0;
	if (!f) return 0;
	snprintf(key, sizeof key, "%s/%s", cat, name);
	while (fgets(line, sizeof line, f)) {
		char *s = trim(line);
		if (!*s || *s == '#') continue;
		if (!strcmp(s, name) || !strcmp(s, key)) { held = 1; break; }
	}
	fclose(f);
	return held;
}
int cmd_hold(int argc, char **argv, int add)
{
	char line[300], **keep = NULL, dir[BUF], *sl;
	int i, n = 0, r = 0, j, found;
	FILE *f;
	if (add && argc == 0) {
		f = fopen(HOLDFILE, "r");
		if (!f) { puts("kpkg: no packages are held"); return 0; }
		while (fgets(line, sizeof line, f)) {
			char *s = trim(line);
			if (*s && *s != '#') puts(s);
		}
		fclose(f);
		return 0;
	}
	if (argc < 1) {
		fputs("kpkg: specify at least one package\n", stderr);
		return 1;
	}
	if (!need_root()) return 1;
	f = fopen(HOLDFILE, "r");
	if (f) {
		while (fgets(line, sizeof line, f)) {
			char *s = trim(line);
			char **grown;
			if (!*s) continue;
			grown = realloc(keep, sizeof *keep * (size_t)(n + 1));
			if (!grown) { fclose(f); return 1; }
			keep = grown;
			keep[n++] = strdup(s);
		}
		fclose(f);
	}
	for (i = 0; i < argc; i++) {
		if (!safe_id(argv[i]) && !strchr(argv[i], '/')) {
			fprintf(stderr, "kpkg: invalid package name %s\n", argv[i]);
			r = 1;
			continue;
		}
		found = 0;
		for (j = 0; j < n; j++) if (keep[j] && !strcmp(keep[j], argv[i])) found = 1;
		if (add && !found) {
			char **grown = realloc(keep, sizeof *keep * (size_t)(n + 1));
			if (!grown) return 1;
			keep = grown;
			keep[n++] = strdup(argv[i]);
			printf("kpkg: %s is held\n", argv[i]);
		} else if (!add && found) {
			for (j = 0; j < n; j++) if (keep[j] && !strcmp(keep[j], argv[i])) { free(keep[j]); keep[j] = NULL; }
			printf("kpkg: %s is released\n", argv[i]);
		}
	}
	snprintf(dir, sizeof dir, "%s", HOLDFILE);
	sl = strrchr(dir, '/');
	if (sl) { *sl = 0; mkdirs(dir); }
	f = fopen(HOLDFILE, "w");
	if (!f) {
		fprintf(stderr, "kpkg: cannot write %s\n", HOLDFILE);
		return 1;
	}
	for (j = 0; j < n; j++) if (keep[j]) { fprintf(f, "%s\n", keep[j]); free(keep[j]); }
	fclose(f);
	free(keep);
	return r;
}
static int visit(const char *cat, const char *name, const char *ver, int explicit)
{
	char key[260], inst[64] = "", path[BUF + 256], dcat[128], dname[128], dver[64];
	char **deps = NULL, *slash;
	int nd = 0, i, ok = 1;
	struct recipe r;
	recipe_init(&r);
	snprintf(key, sizeof key, "%s/%s", cat, name);
	if (list_has(visited, nvisited, key)) return 1;
	if (list_has(visiting, nvisiting, key)) {
		fprintf(stderr, "kpkg: dependency cycle at %s\n", key);
		return 0;
	}
	if (nplan >= MAXPLAN) {
		fputs("kpkg: too many packages in one transaction\n", stderr);
		return 0;
	}
	list_add(&visiting, &nvisiting, key);
	if (db_installed_version(cat, name, inst, sizeof inst) && !strcmp(inst, ver)) {
		list_add(&visited, &nvisited, key);
		visiting_pop();
		return 1;
	}
	if (inst[0] && is_held(cat, name)) {
		printf("kpkg: %s is held at %s, not changing it\n", key, inst);
		list_add(&visited, &nvisited, key);
		visiting_pop();
		return 1;
	}
	if (!recipe_path(cat, name, ver, path, sizeof path)) {
		fprintf(stderr, "kpkg: recipe not found: %s-%s\n", key, ver);
		ok = 0;
		goto done;
	}
	if (!recipe_load(path, &r)) {
		ok = 0;
		goto done;
	}
	snprintf(r.category, sizeof r.category, "%s", cat);
	snprintf(r.name, sizeof r.name, "%s", name);
	snprintf(r.version, sizeof r.version, "%s", ver);
	recipe_expand(&r);
	dep_split(r.depend, &deps, &nd);
	dep_split(r.rdepend, &deps, &nd);
	for (i = 0; i < nd && ok; i++) {
		slash = strchr(deps[i], '/');
		if (!strncmp(deps[i], "virtual/", 8)) {
			if (slash && find_category(slash + 1, dcat, sizeof dcat) && recipe_best(dcat, slash + 1, dver, sizeof dver)) {
				if (!visit(dcat, slash + 1, dver, 0)) ok = 0;
			} else {
				fprintf(stderr, "kpkg: virtual dependency %s has no recipe, skipped\n", deps[i]);
			}
			continue;
		}
		if (db_find_installed(slash ? slash + 1 : deps[i], dcat, sizeof dcat, dver, sizeof dver)) continue;
		if (!resolve_dep(deps[i], dcat, sizeof dcat, dname, sizeof dname, dver, sizeof dver)) {
			fprintf(stderr, "kpkg: missing dependency %s required by %s\n", deps[i], key);
			ok = 0;
			break;
		}
		if (!visit(dcat, dname, dver, 0)) ok = 0;
	}
	if (ok) {
		snprintf(plan[nplan].cat, sizeof plan[nplan].cat, "%s", cat);
		snprintf(plan[nplan].name, sizeof plan[nplan].name, "%s", name);
		snprintf(plan[nplan].ver, sizeof plan[nplan].ver, "%s", ver);
		snprintf(plan[nplan].oldver, sizeof plan[nplan].oldver, "%s", inst);
		plan[nplan].explicit = explicit;
		plan[nplan].upgrade = inst[0] ? 1 : 0;
		nplan++;
		list_add(&visited, &nvisited, key);
	}
done:
	recipe_free(&r);
	list_free(deps, nd);
	visiting_pop();
	return ok;
}
static void print_plan(void)
{
	int i;
	for (i = 0; i < nplan; i++) {
		if (plan[i].upgrade)
			printf("%supgrade%s  %s/%s %s -> %s%s\n", C('y'), C('0'), plan[i].cat, plan[i].name, plan[i].oldver, plan[i].ver, plan[i].explicit ? "" : " (dependency)");
		else
			printf("%sinstall%s  %s/%s-%s%s\n", C('g'), C('0'), plan[i].cat, plan[i].name, plan[i].ver, plan[i].explicit ? "" : " (dependency)");
	}
}
static int execute_plan(int force)
{
	int i, r = 0;
	for (i = 0; i < nplan; i++) {
		if (pkg_build_install(plan[i].cat, plan[i].name, plan[i].ver, plan[i].explicit, force)) {
			r = 1;
			break;
		}
	}
	ownership_free();
	if (!r) printf("kpkg: transaction finished: %d package(s)\n", nplan);
	return r;
}
static int local_recipe(const char *arg, char *cat, size_t cn, char *name, size_t nn, char *ver, size_t vn)
{
	size_t l = strlen(arg);
	struct recipe r;
	int ok = 0;
	if (l < 6 || strcmp(arg + l - 5, ".kpkg") || !exists(arg)) return 0;
	recipe_init(&r);
	if (recipe_load(arg, &r) && safe_id(r.name) && recipe_ver_ok(r.version)) {
		char rp[PATH_MAX];
		if (realpath(arg, rp)) snprintf(recipe_local, sizeof recipe_local, "%s", rp);
		else snprintf(recipe_local, sizeof recipe_local, "%s", arg);
		snprintf(recipe_local_name, sizeof recipe_local_name, "%s", r.name);
		snprintf(recipe_local_ver, sizeof recipe_local_ver, "%s", r.version);
		snprintf(cat, cn, "local");
		snprintf(name, nn, "%s", r.name);
		snprintf(ver, vn, "%s", r.version);
		ok = 1;
	} else {
		fprintf(stderr, "kpkg: %s is not a valid recipe\n", arg);
	}
	recipe_free(&r);
	return ok;
}
static int sum_source(const char *url, char *hash)
{
	char tmp[BUF], got[BUF];
	char *a[4];
	int ok = 0;
	snprintf(tmp, sizeof tmp, "/var/tmp/kpkg-checksum.%ld", (long)getpid());
	unlink(tmp);
	if (url[0] == '/') {
		a[0] = "cp"; a[1] = (char *)url; a[2] = tmp; a[3] = NULL;
		if (run(a) != 0) return 0;
	} else if (fetch(url, tmp) != 0) {
		fprintf(stderr, "kpkg: download failed: %s\n", url);
		unlink(tmp);
		return 0;
	}
	a[0] = "sha256sum"; a[1] = tmp; a[2] = NULL;
	if (capture(a, got, sizeof got) == 0 && strspn(got, "0123456789abcdef") >= 64) {
		memcpy(hash, got, 64);
		hash[64] = 0;
		ok = 1;
	}
	unlink(tmp);
	return ok;
}
static int checksum_file(const char *path)
{
	struct recipe r;
	char buf[2048], *tok, *save = NULL, line[1200], hash[65], sums[1024] = "";
	char *text, *p, *eol, *out;
	FILE *f;
	long len;
	int ok = 1, replaced = 0, has;
	size_t pos = 0;
	recipe_init(&r);
	if (!recipe_load(path, &r) || !r.src_uri[0]) {
		fprintf(stderr, "kpkg: %s: cannot read a recipe with SRC_URI\n", path);
		recipe_free(&r);
		return 0;
	}
	snprintf(buf, sizeof buf, "%s", r.src_uri);
	recipe_free(&r);
	for (tok = strtok_r(buf, " \t\n", &save); tok && ok; tok = strtok_r(NULL, " \t\n", &save)) {
		if (!strcmp(tok, "->")) {
			tok = strtok_r(NULL, " \t\n", &save);
			continue;
		}
		printf("kpkg: hashing %s\n", tok);
		if (!sum_source(tok, hash)) { ok = 0; break; }
		if (strlen(sums) + 66 >= sizeof sums) { ok = 0; break; }
		if (sums[0]) strcat(sums, " ");
		strcat(sums, hash);
	}
	if (!ok || !sums[0]) return 0;
	f = fopen(path, "r");
	if (!f) return 0;
	fseek(f, 0, SEEK_END);
	len = ftell(f);
	rewind(f);
	text = malloc((size_t)len + 1);
	out = malloc((size_t)len + 2048);
	if (!text || !out || fread(text, 1, (size_t)len, f) != (size_t)len) { fclose(f); free(text); free(out); return 0; }
	fclose(f);
	text[len] = 0;
	snprintf(line, sizeof line, "SHA256=\"%s\"\n", sums);
	has = !strncmp(text, "SHA256=", 7) || strstr(text, "\nSHA256=") != NULL;
	for (p = text; *p; p = eol) {
		eol = strchr(p, '\n');
		eol = eol ? eol + 1 : p + strlen(p);
		if (!strncmp(p, "SHA256=", 7)) {
			memcpy(out + pos, line, strlen(line)); pos += strlen(line); replaced = 1;
			continue;
		}
		memcpy(out + pos, p, (size_t)(eol - p)); pos += (size_t)(eol - p);
		if (!has && !replaced && !strncmp(p, "SRC_URI=", 8)) {
			memcpy(out + pos, line, strlen(line)); pos += strlen(line); replaced = 1;
		}
	}
	out[pos] = 0;
	f = fopen(path, "w");
	if (!f || fwrite(out, 1, pos, f) != pos) { if (f) fclose(f); free(text); free(out); return 0; }
	fclose(f);
	free(text);
	free(out);
	printf("kpkg: %s: SHA256 written\n", path);
	return 1;
}
int cmd_checksum(int argc, char **argv)
{
	int i, bad = 0;
	if (argc < 1) {
		fputs("kpkg: specify at least one .kpkg file\n", stderr);
		return 1;
	}
	for (i = 0; i < argc; i++)
		if (!checksum_file(argv[i])) bad++;
	return bad ? 1 : 0;
}
int cmd_lint(int argc, char **argv)
{
	int i, bad = 0;
	if (argc < 1) {
		fputs("kpkg: specify at least one .kpkg file\n", stderr);
		return 1;
	}
	for (i = 0; i < argc; i++) {
		int n = recipe_lint(argv[i]);
		if (n) bad += n;
		else printf("ok: %s\n", argv[i]);
	}
	return bad ? 1 : 0;
}
int cmd_install(int argc, char **argv)
{
	struct opts o;
	char **pkgs = NULL, cat[128], name[128], ver[64];
	int npk = 0, i, r = 1;
	if (!parse_opts(argc, argv, &o, &pkgs, &npk)) return 1;
	if (!npk) {
		fputs("kpkg: specify at least one package\n", stderr);
		goto out;
	}
	if (!o.pretend && !need_root()) goto out;
	if (!ensure_tree()) goto out;
	plan_reset();
	for (i = 0; i < npk; i++) {
		if (local_recipe(pkgs[i], cat, sizeof cat, name, sizeof name, ver, sizeof ver)) {
			if (!visit(cat, name, ver, !o.oneshot)) goto out;
			continue;
		}
		if (!resolve_name(pkgs[i], cat, sizeof cat, name, sizeof name, ver, sizeof ver)) goto out;
		if (!visit(cat, name, ver, !o.oneshot)) goto out;
	}
	if (!nplan) {
		puts("kpkg: nothing to do, requested packages are already installed");
		r = 0;
		goto out;
	}
	print_plan();
	if (o.pretend) {
		r = 0;
		goto out;
	}
	if (o.ask && !confirm()) goto out;
	r = execute_plan(o.force);
out:
	list_free(pkgs, npk);
	plan_reset();
	return r;
}
int cmd_remove(int argc, char **argv)
{
	struct opts o;
	char **pkgs = NULL, buf[512], cat[128], name[128], ver[64], *slash, *at, **rd;
	int npk = 0, i, j, nrd, r = 1;
	if (!parse_opts(argc, argv, &o, &pkgs, &npk)) return 1;
	if (!npk) {
		fputs("kpkg: specify at least one package\n", stderr);
		goto out;
	}
	if (!o.pretend && !need_root()) goto out;
	plan_reset();
	for (i = 0; i < npk; i++) {
		snprintf(buf, sizeof buf, "%s", pkgs[i]);
		at = strchr(buf, '@');
		if (at) *at = 0;
		slash = strchr(buf, '/');
		if (slash) {
			*slash = 0;
			snprintf(cat, sizeof cat, "%.127s", buf);
			snprintf(name, sizeof name, "%.127s", slash + 1);
			if (!db_installed_version(cat, name, ver, sizeof ver)) {
				fprintf(stderr, "kpkg: %s/%s is not installed\n", cat, name);
				goto out;
			}
		} else {
			snprintf(name, sizeof name, "%.127s", buf);
			if (!db_find_installed(name, cat, sizeof cat, ver, sizeof ver)) {
				fprintf(stderr, "kpkg: %s is not installed\n", name);
				goto out;
			}
		}
		if (at && strcmp(at + 1, ver)) {
			fprintf(stderr, "kpkg: version %s of %s/%s is not installed\n", at + 1, cat, name);
			goto out;
		}
		nrd = db_reverse_deps(name, &rd);
		if (nrd && !o.force) {
			fprintf(stderr, "kpkg: cannot remove %s/%s, required by:", cat, name);
			for (j = 0; j < nrd; j++) fprintf(stderr, " %s", rd[j]);
			fputc('\n', stderr);
			list_free(rd, nrd);
			goto out;
		}
		if (nrd) fprintf(stderr, "kpkg: removing %s/%s despite %d reverse dependencies (--force)\n", cat, name, nrd);
		list_free(rd, nrd);
		if (nplan >= MAXPLAN) {
			fputs("kpkg: too many packages in one transaction\n", stderr);
			goto out;
		}
		snprintf(plan[nplan].cat, sizeof plan[nplan].cat, "%s", cat);
		snprintf(plan[nplan].name, sizeof plan[nplan].name, "%s", name);
		snprintf(plan[nplan].ver, sizeof plan[nplan].ver, "%s", ver);
		nplan++;
	}
	if (o.pretend) {
		for (i = 0; i < nplan; i++) printf("remove   %s/%s-%s\n", plan[i].cat, plan[i].name, plan[i].ver);
		r = 0;
		goto out;
	}
	if (o.ask && !confirm()) goto out;
	for (i = 0; i < nplan; i++) {
		db_remove(plan[i].cat, plan[i].name, plan[i].ver, NULL, 0);
		world_del(plan[i].cat, plan[i].name);
	}
	r = 0;
out:
	list_free(pkgs, npk);
	plan_reset();
	return r;
}
int cmd_upgrade(int argc, char **argv)
{
	struct opts o;
	char **pkgs = NULL, best[64], cat2[128];
	int npk = 0, n, i, r = 1;
	struct db_pkg *all = NULL;
	if (!parse_opts(argc, argv, &o, &pkgs, &npk)) return 1;
	if (npk) {
		fputs("kpkg: upgrade takes no package arguments\n", stderr);
		list_free(pkgs, npk);
		return 1;
	}
	list_free(pkgs, npk);
	if (!o.pretend && !need_root()) return 1;
	if (!ensure_tree()) return 1;
	plan_reset();
	n = db_all(&all);
	for (i = 0; i < n; i++) {
		if (recipe_best(all[i].category, all[i].name, best, sizeof best)) {
			if (vercmp(best, all[i].version) > 0 && !visit(all[i].category, all[i].name, best, all[i].explicit)) goto out;
		} else if (find_category(all[i].name, cat2, sizeof cat2) && recipe_best(cat2, all[i].name, best, sizeof best)) {
			if (vercmp(best, all[i].version) > 0 && !visit(cat2, all[i].name, best, all[i].explicit)) goto out;
		} else {
			fprintf(stderr, "kpkg: no recipe for %s/%s, skipped\n", all[i].category, all[i].name);
		}
	}
	if (!nplan) {
		puts("kpkg: all packages are up to date");
		r = 0;
		goto out;
	}
	print_plan();
	if (o.pretend) {
		r = 0;
		goto out;
	}
	if (o.ask && !confirm()) goto out;
	if (!o.no_snapshot && sn_keep > 0 && sn_auto()) goto out;
	r = execute_plan(o.force);
out:
	free(all);
	plan_reset();
	return r;
}
int cmd_clean(int argc, char **argv)
{
	struct opts o;
	char **pkgs = NULL, **rd, *a[8];
	int npk = 0, n, i, pass, any, total = 0, nrd;
	struct db_pkg *all;
	if (!parse_opts(argc, argv, &o, &pkgs, &npk)) return 1;
	list_free(pkgs, npk);
	if (!o.pretend && !need_root()) return 1;
	if (o.pretend) {
		n = db_all(&all);
		for (i = 0; i < n; i++) {
			if (all[i].explicit) continue;
			nrd = db_reverse_deps(all[i].name, &rd);
			list_free(rd, nrd);
			if (!nrd) printf("remove   %s/%s-%s (orphan dependency)\n", all[i].category, all[i].name, all[i].version);
		}
		free(all);
		puts("kpkg: would clear distfiles and build directories");
		return 0;
	}
	if (o.ask && !confirm()) return 1;
	for (pass = 0; pass < 10; pass++) {
		n = db_all(&all);
		any = 0;
		for (i = 0; i < n; i++) {
			if (all[i].explicit) continue;
			nrd = db_reverse_deps(all[i].name, &rd);
			list_free(rd, nrd);
			if (nrd) continue;
			db_remove(all[i].category, all[i].name, all[i].version, NULL, 0);
			world_del(all[i].category, all[i].name);
			any = 1;
			total++;
			break;
		}
		free(all);
		if (!any) break;
	}
	if (exists(distdir)) {
		a[0] = "find"; a[1] = distdir; a[2] = "-mindepth"; a[3] = "1"; a[4] = "-delete"; a[5] = NULL;
		run(a);
	}
	if (exists(workdir)) {
		a[0] = "find"; a[1] = workdir; a[2] = "-mindepth"; a[3] = "1"; a[4] = "-delete"; a[5] = NULL;
		run(a);
	}
	printf("kpkg: cleaned %d orphan package(s), distfiles and build directories cleared\n", total);
	return 0;
}
int cmd_search(int argc, char **argv)
{
	char **cats = NULL, dir[BUF], ver[64];
	int nc, i, j, np, matches = 0, shown = 0;
	struct dirent **nl = NULL;
	if (argc != 1) {
		fputs("kpkg: usage: kpkg search term\n", stderr);
		return 1;
	}
	if (!ensure_tree()) return 1;
	nc = tree_categories(&cats);
	for (i = 0; i < nc; i++) {
		snprintf(dir, sizeof dir, "%s/%s", repo, cats[i]);
		np = scandir(dir, &nl, NULL, alphasort);
		for (j = 0; j < np; j++) {
			if (nl[j]->d_name[0] != '.' && strcasestr(nl[j]->d_name, argv[0]) && recipe_best(cats[i], nl[j]->d_name, ver, sizeof ver)) {
				matches++;
				if (shown < 100) {
					printf("%s/%s %s\n", cats[i], nl[j]->d_name, ver);
					shown++;
				}
			}
			free(nl[j]);
		}
		if (np >= 0) free(nl);
	}
	list_free(cats, nc);
	if (!matches) {
		puts("kpkg: no packages matched");
		return 1;
	}
	if (matches > shown) printf("kpkg: %d matches total, showing %d, refine the term\n", matches, shown);
	return 0;
}
int cmd_info(int argc, char **argv)
{
	char cat[128], name[128], ver[64], path[BUF + 256], inst[64];
	struct recipe r;
	int i;
	if (argc != 1) {
		fputs("kpkg: usage: kpkg info package\n", stderr);
		return 1;
	}
	if (!ensure_tree()) return 1;
	if (!resolve_name(argv[0], cat, sizeof cat, name, sizeof name, ver, sizeof ver)) return 1;
	recipe_init(&r);
	if (!recipe_path(cat, name, ver, path, sizeof path) || !recipe_load(path, &r)) {
		recipe_free(&r);
		return 1;
	}
	snprintf(r.category, sizeof r.category, "%s", cat);
	snprintf(r.name, sizeof r.name, "%s", name);
	snprintf(r.version, sizeof r.version, "%s", ver);
	recipe_expand(&r);
	printf("package:     %s/%s-%s\n", cat, name, ver);
	printf("description: %s\n", r.description);
	printf("homepage:    %s\n", r.homepage);
	printf("license:     %s\n", r.license);
	printf("slot:        %s\n", r.slot);
	printf("sources:     %s\n", r.src_uri);
	printf("depends:     %s\n", r.depend);
	printf("runtime:     %s\n", r.rdepend);
	printf("phases:     ");
	for (i = 0; i < r.nphases; i++) printf(" %s", r.phases[i].name);
	fputc('\n', stdout);
	if (db_installed_version(cat, name, inst, sizeof inst)) printf("installed:   %s\n", inst);
	else puts("installed:   no");
	recipe_free(&r);
	return 0;
}
int cmd_list(void)
{
	struct db_pkg *all;
	int n, i;
	n = db_all(&all);
	if (!n) {
		puts("kpkg: no packages installed");
		free(all);
		return 0;
	}
	for (i = 0; i < n; i++) printf("%s/%s-%s%s\n", all[i].category, all[i].name, all[i].version, all[i].explicit ? "" : " (dependency)");
	free(all);
	return 0;
}
int cmd_files(int argc, char **argv)
{
	char cat[128], name[128], ver[64], path[BUF], buf[512], **files, *sl;
	int n, i;
	if (argc != 1) {
		fputs("kpkg: usage: kpkg files package\n", stderr);
		return 1;
	}
	snprintf(buf, sizeof buf, "%s", argv[0]);
	sl = strchr(buf, '/');
	if (sl) {
		*sl = 0;
		snprintf(cat, sizeof cat, "%.127s", buf);
		snprintf(name, sizeof name, "%.127s", sl + 1);
		if (!db_installed_version(cat, name, ver, sizeof ver)) {
			fprintf(stderr, "kpkg: %s/%s is not installed\n", cat, name);
			return 1;
		}
	} else {
		snprintf(name, sizeof name, "%.127s", buf);
		if (!db_find_installed(name, cat, sizeof cat, ver, sizeof ver)) {
			fprintf(stderr, "kpkg: %s is not installed\n", name);
			return 1;
		}
	}
	snprintf(path, sizeof path, "%s/%s/%s/%s/files", INSTALLED, cat, name, ver);
	files = db_read_list(path, &n);
	for (i = 0; i < n; i++) printf("/%s\n", files[i]);
	list_free(files, n);
	return 0;
}
int cmd_owns(int argc, char **argv)
{
	char rel[BUF];
	const char *owner;
	if (argc != 1) {
		fputs("kpkg: usage: kpkg owns path\n", stderr);
		return 1;
	}
	snprintf(rel, sizeof rel, "%s", argv[0]);
	while (rel[0] == '/') memmove(rel, rel + 1, strlen(rel));
	owner = pkg_owner_of(rel);
	if (owner) {
		printf("%s\n", owner);
		return 0;
	}
	puts("untracked");
	return 1;
}
static void row(const char *name, const char *val)
{
	int w = 0;
	const char *s;
	for (s = name; *s; s++)
		if (((unsigned char)*s & 0xC0) != 0x80) w++;
	printf("%s%*s %s\n", name, w < 28 ? 28 - w : 0, "", val);
}
static int check(const char *name, int ok)
{
	row(name, ok ? "ok" : "MISSING");
	return ok;
}
int cmd_doctor(void)
{
	char id[64];
	int bad = 0, i;
	static const char *req[] = { "bash", "curl", "tar", "gcc", "make", "gzip", "xz", "sha512sum", "find", "cp", NULL };
	static const char *opt[] = { "unzip", "zstd", "minisign", "btrfs", "ldconfig", NULL };
	osid(id, sizeof id);
	row("system id", id);
	bad += !check("write access to /", access("/", W_OK) == 0);
	bad += !check("recipe tree", exists(repo));
	bad += !check("distfiles directory", exists(distdir));
	bad += !check("build directory", exists(workdir));
	bad += !check("installed database", exists(INSTALLED));
	for (i = 0; req[i]; i++) bad += !check(req[i], have(req[i]));
	for (i = 0; opt[i]; i++) row(opt[i], have(opt[i]) ? "present" : "absent (optional)");
	printf("%s\n", bad ? "problems found" : "all good");
	return bad ? 1 : 0;
}
int cmd_fix(void)
{
	if (!need_root()) return 1;
	puts("kpkg: repairing the environment");
	if (!mkdirs(distdir) || !mkdirs(workdir) || !mkdirs(INSTALLED)) {
		fputs("kpkg: cannot create required directories\n", stderr);
		return 1;
	}
	if (!ensure_tree()) return 1;
	return cmd_doctor();
}
static int count_tree(const char *dir, int *ncats, int *npkgs)
{
	struct dirent **nl, **pl = NULL;
	int nc, np, i, j, c = 0, p = 0;
	char sub[BUF + 256], probe[BUF + 512];
	nc = scandir(dir, &nl, NULL, alphasort);
	if (nc < 0) return 0;
	for (i = 0; i < nc; i++) {
		if (nl[i]->d_name[0] != '.' && strcmp(nl[i]->d_name, "metadata") && strcmp(nl[i]->d_name, "profiles")) {
			if (snprintf(sub, sizeof sub, "%s/%s", dir, nl[i]->d_name) >= (int)sizeof sub) {
				free(nl[i]);
				continue;
			}
			if (is_dir(sub)) {
				c++;
				np = scandir(sub, &pl, NULL, alphasort);
				for (j = 0; j < np; j++) {
					if (pl[j]->d_name[0] != '.') {
						if (snprintf(probe, sizeof probe, "%s/%s", sub, pl[j]->d_name) < (int)sizeof probe && is_dir(probe)) p++;
					}
					free(pl[j]);
				}
				if (np >= 0) free(pl);
			}
		}
		free(nl[i]);
	}
	free(nl);
	*ncats = c;
	*npkgs = p;
	return c > 0;
}
int cmd_sync(void)
{
	char part[BUF], fin[BUF], nw[BUF], old[BUF], sig[BUF + 16], sigurl[640];
	char *a[12];
	int ncats = 0, npkgs = 0;
	if (!need_root()) return 1;
	if (!have("curl") || !have("tar")) {
		fputs("kpkg: sync needs curl and tar\n", stderr);
		return 1;
	}
	if (!mkdirs(distdir)) {
		fprintf(stderr, "kpkg: cannot create %s\n", distdir);
		return 1;
	}
	snprintf(part, sizeof part, "%s/recipes.tar.gz.part", distdir);
	snprintf(fin, sizeof fin, "%s/recipes.tar.gz", distdir);
	printf("kpkg: downloading recipe tree: %s\n", recipes_url);
	fflush(stdout);
	unlink(part);
	if (fetch(recipes_url, part) != 0) {
		fputs("kpkg: recipe tree download failed, check the network and recipes_url\n", stderr);
		unlink(part);
		return 1;
	}
	snprintf(sigurl, sizeof sigurl, "%s.minisig", recipes_url);
	snprintf(sig, sizeof sig, "%s.minisig", part);
	if (fetch(sigurl, sig) == 0) {
		if (have("minisign") && exists(PUBKEY)) {
			if (!verify_sig(part, sig)) {
				fputs("kpkg: recipe tree signature mismatch, sync aborted\n", stderr);
				unlink(part);
				unlink(sig);
				return 1;
			}
			puts("kpkg: minisign signature verified");
		} else {
			fputs("kpkg: signature downloaded but minisign or the public key is missing, not verified\n", stderr);
		}
		unlink(sig);
	} else {
		fputs("kpkg: no detached signature published for the recipe tree, trusting HTTPS\n", stderr);
	}
	unlink(fin);
	if (rename(part, fin) != 0) {
		perror("kpkg: rename");
		return 1;
	}
	snprintf(nw, sizeof nw, "%s.new", repo);
	snprintf(old, sizeof old, "%s.old", repo);
	rm_tree(nw);
	if (!mkdirs(nw)) {
		fprintf(stderr, "kpkg: cannot create %s\n", nw);
		return 1;
	}
	puts("kpkg: extracting the recipe tree");
	fflush(stdout);
	a[0] = "tar"; a[1] = "xzf"; a[2] = fin; a[3] = "--strip-components=1"; a[4] = "--no-same-owner"; a[5] = "-C"; a[6] = nw; a[7] = NULL;
	if (run(a) != 0) {
		fputs("kpkg: cannot extract the recipe archive\n", stderr);
		return 1;
	}
	if (!count_tree(nw, &ncats, &npkgs)) {
		fputs("kpkg: the archive does not look like a recipe tree, the current tree was kept\n", stderr);
		rm_tree(nw);
		return 1;
	}
	rm_tree(old);
	if (exists(repo) && rename(repo, old) != 0) {
		perror("kpkg: rename");
		return 1;
	}
	if (rename(nw, repo) != 0) {
		perror("kpkg: rename");
		if (exists(old) && rename(old, repo) != 0) perror("kpkg: cannot restore the previous tree");
		return 1;
	}
	rm_tree(old);
	printf("kpkg: recipe tree updated: %d packages in %d categories\n", npkgs, ncats);
	return 0;
}
