#include "kpkg.h"
char repo[256] = "/var/db/repos/kpkg-recipes";
char distdir[256] = "/var/cache/kpkg/distfiles";
char workdir[256] = "/var/tmp/kpkg-build";
char recipes_url[512] = RECIPES_URL;
int jobs; int keep_workdir; int allow_host; int sn_keep = 5;
char cfg_cflags[512]; char cfg_cxxflags[512]; char cfg_ldflags[512];
int cfg_nice; int cfg_ask = 1; int cfg_min_battery = 10; int cfg_config_loaded;
void *xcalloc(size_t n, size_t m)
{
	void *p = calloc(n, m);
	if (!p) { fputs("kpkg: out of memory\n", stderr); exit(1); }
	return p;
}
void *xrealloc(void *p, size_t n)
{
	void *r = realloc(p, n);
	if (!r) { fputs("kpkg: out of memory\n", stderr); exit(1); }
	return r;
}
char *xstrdup(const char *s)
{
	char *p = strdup(s);
	if (!p) { fputs("kpkg: out of memory\n", stderr); exit(1); }
	return p;
}
int run(char *const av[])
{
	pid_t p = fork();
	int st;
	if (p < 0) return -1;
	if (p == 0) {
		execvp(av[0], av);
		fprintf(stderr, "kpkg: command not found: %s\n", av[0]);
		_exit(127);
	}
	if (waitpid(p, &st, 0) < 0) return -1;
	return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}
int capture(char *const av[], char *out, size_t n)
{
	int fd[2], st;
	pid_t p;
	size_t len = 0;
	ssize_t r;
	if (pipe(fd) < 0) return -1;
	p = fork();
	if (p < 0) { close(fd[0]); close(fd[1]); return -1; }
	if (p == 0) {
		close(fd[0]);
		dup2(fd[1], 1);
		close(fd[1]);
		execvp(av[0], av);
		_exit(127);
	}
	close(fd[1]);
	while (len + 1 < n) {
		r = read(fd[0], out + len, n - len - 1);
		if (r < 0 && errno == EINTR) continue;
		if (r <= 0) break;
		len += (size_t)r;
	}
	out[len] = 0;
	close(fd[0]);
	if (waitpid(p, &st, 0) < 0) return -1;
	return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}
char *trim(char *s)
{
	char *e;
	while (*s == ' ' || *s == '\t') s++;
	e = s + strlen(s);
	while (e > s && (e[-1] == '\n' || e[-1] == '\r' || e[-1] == ' ' || e[-1] == '\t')) *--e = 0;
	return s;
}
int exists(const char *p)
{
	struct stat st;
	return stat(p, &st) == 0;
}
int is_dir(const char *p)
{
	struct stat st;
	return stat(p, &st) == 0 && S_ISDIR(st.st_mode);
}
int mkdirs(const char *path)
{
	char buf[BUF], *p;
	snprintf(buf, sizeof buf, "%s", path);
	for (p = buf + 1; *p; p++) {
		if (*p != '/') continue;
		*p = 0;
		if (mkdir(buf, 0755) < 0 && errno != EEXIST) return 0;
		*p = '/';
	}
	if (mkdir(buf, 0755) < 0 && errno != EEXIST) return 0;
	return is_dir(buf);
}
int safe_dir(const char *p)
{
	static const char *bad[] = {
		"/", "/usr", "/etc", "/bin", "/sbin", "/lib", "/lib64", "/boot",
		"/root", "/home", "/dev", "/proc", "/sys", "/var", "/run", "/opt",
		"/tmp", "/srv", "/mnt", "/var/db", "/var/lib", "/var/cache", "/var/log",
		"/var/tmp", "/var/db/kpkg", "/var/db/repos", "/usr/local", "/usr/lib",
		"/usr/share", "/usr/bin", "/usr/sbin", NULL
	};
	size_t n = strlen(p), j, depth = 0;
	int i;
	while (n > 1 && p[n - 1] == '/') n--;
	if (p[0] != '/' || strstr(p, "..")) return 0;
	for (j = 0; j < n; j++)
		if (p[j] != '/' && (j == 0 || p[j - 1] == '/')) depth++;
	if (depth < 3) return 0;
	for (i = 0; bad[i]; i++)
		if (strlen(bad[i]) == n && !strncmp(p, bad[i], n)) return 0;
	return 1;
}
void rm_tree(const char *path)
{
	char *a[4];
	if (!safe_dir(path)) {
		fprintf(stderr, "kpkg: refusing to remove unsafe path: %s\n", path);
		return;
	}
	a[0] = "rm"; a[1] = "-rf"; a[2] = (char *)path; a[3] = NULL;
	run(a);
}
int flags_ok(const char *v)
{
	static const char *const deny[] = { "-wrapper", "-fplugin", "-specs", "-B", "-Wa,--execstack", NULL };
	char buf[512], *tok, *save = NULL;
	const char *p;
	int i;
	if (strlen(v) >= sizeof buf) return 0;
	for (p = v; *p; p++)
		if (!(isalnum((unsigned char)*p) || strchr(" -_=+.,/:%", *p))) return 0;
	snprintf(buf, sizeof buf, "%s", v);
	for (tok = strtok_r(buf, " ", &save); tok; tok = strtok_r(NULL, " ", &save))
		for (i = 0; deny[i]; i++)
			if (!strncmp(tok, deny[i], strlen(deny[i]))) return 0;
	return 1;
}
static int yesno(const char *v, int *out)
{
	if (!strcmp(v, "yes") || !strcmp(v, "1") || !strcmp(v, "true")) { *out = 1; return 1; }
	if (!strcmp(v, "no") || !strcmp(v, "0") || !strcmp(v, "false")) { *out = 0; return 1; }
	return 0;
}
static void load_userconf(void)
{
	FILE *f = fopen(USERCONF, "r");
	struct stat st;
	char line[BUF], *k, *v, *eq, *h;
	size_t l;
	long lv;
	int n = 0, b;
	if (!f) return;
	if (fstat(fileno(f), &st) != 0 || (geteuid() == 0 && (st.st_uid != 0 || (st.st_mode & (S_IWGRP | S_IWOTH))))) {
		fprintf(stderr, "kpkg: %s must be owned by root and not writable by others, the file is ignored\n", USERCONF);
		fclose(f);
		return;
	}
	cfg_config_loaded = 1;
	while (fgets(line, sizeof line, f)) {
		n++;
		h = strchr(line, '#');
		if (h) *h = 0;
		k = trim(line);
		if (!*k) continue;
		eq = strchr(k, '=');
		if (!eq) {
			fprintf(stderr, "kpkg: %s:%d: expected KEY=value, ignored\n", USERCONF, n);
			continue;
		}
		*eq = 0;
		v = trim(eq + 1);
		k = trim(k);
		l = strlen(v);
		if (l >= 2 && v[0] == '"' && v[l - 1] == '"') { v[l - 1] = 0; v++; }
		if (!strcmp(k, "JOBS")) {
			lv = strtol(v, NULL, 10);
			if (lv < 0 || lv > 256) { fprintf(stderr, "kpkg: %s:%d: JOBS must be 0 to 256, ignored\n", USERCONF, n); continue; }
			jobs = (int)lv;
		} else if (!strcmp(k, "CFLAGS") || !strcmp(k, "CXXFLAGS") || !strcmp(k, "LDFLAGS")) {
			if (!flags_ok(v)) { fprintf(stderr, "kpkg: %s:%d: %s has unsupported characters or options, ignored\n", USERCONF, n, k); continue; }
			snprintf(!strcmp(k, "CFLAGS") ? cfg_cflags : !strcmp(k, "CXXFLAGS") ? cfg_cxxflags : cfg_ldflags, 512, "%s", v);
		} else if (!strcmp(k, "NICE")) {
			lv = strtol(v, NULL, 10);
			if (lv < 0 || lv > 19) { fprintf(stderr, "kpkg: %s:%d: NICE must be 0 to 19, ignored\n", USERCONF, n); continue; }
			cfg_nice = (int)lv;
		} else if (!strcmp(k, "SNAPSHOTS")) {
			lv = strtol(v, NULL, 10);
			sn_keep = lv < 0 ? 0 : lv > 50 ? 50 : (int)lv;
		} else if (!strcmp(k, "MIN_BATTERY")) {
			lv = strtol(v, NULL, 10);
			cfg_min_battery = lv < 0 ? 0 : lv > 90 ? 90 : (int)lv;
		} else if (!strcmp(k, "ASK")) {
			if (!yesno(v, &b)) fprintf(stderr, "kpkg: %s:%d: ASK must be yes or no, ignored\n", USERCONF, n);
			else cfg_ask = b;
		} else if (!strcmp(k, "KEEP_WORKDIR")) {
			if (!yesno(v, &b)) fprintf(stderr, "kpkg: %s:%d: KEEP_WORKDIR must be yes or no, ignored\n", USERCONF, n);
			else keep_workdir = b;
		} else {
			fprintf(stderr, "kpkg: %s:%d: unknown option %s, ignored\n", USERCONF, n, k);
		}
	}
	fclose(f);
}
void loadconf(void)
{
	FILE *f = fopen(CONF, "r");
	char line[BUF], *k, *v, *eq;
	size_t sl;
	long lv;
	if (f) {
		while (fgets(line, sizeof line, f)) {
			k = trim(line);
			if (!*k || *k == '#') continue;
			eq = strchr(k, '=');
			if (!eq) continue;
			*eq = 0;
			v = trim(eq + 1);
			k = trim(k);
			if (!strcmp(k, "repo")) snprintf(repo, sizeof repo, "%s", v);
			else if (!strcmp(k, "recipes_url")) snprintf(recipes_url, sizeof recipes_url, "%s", v);
			else if (!strcmp(k, "distdir")) snprintf(distdir, sizeof distdir, "%s", v);
			else if (!strcmp(k, "workdir")) snprintf(workdir, sizeof workdir, "%s", v);
			else if (!strcmp(k, "jobs")) {
				lv = strtol(v, NULL, 10);
				jobs = lv < 0 ? 0 : lv > 256 ? 256 : (int)lv;
			} else if (!strcmp(k, "snapshots")) {
				lv = strtol(v, NULL, 10);
				sn_keep = lv < 0 ? 0 : lv > 50 ? 50 : (int)lv;
			} else if (!strcmp(k, "keep_workdir")) keep_workdir = !strcmp(v, "yes") || !strcmp(v, "1");
			else if (!strcmp(k, "allow_host")) allow_host = !strcmp(v, "yes") || !strcmp(v, "1");
		}
		fclose(f);
	}
	load_userconf();
	for (sl = strlen(repo); sl > 1 && repo[sl - 1] == '/'; sl--) repo[sl - 1] = 0;
	for (sl = strlen(distdir); sl > 1 && distdir[sl - 1] == '/'; sl--) distdir[sl - 1] = 0;
	for (sl = strlen(workdir); sl > 1 && workdir[sl - 1] == '/'; sl--) workdir[sl - 1] = 0;
	if (!safe_dir(repo) || !safe_dir(distdir) || !safe_dir(workdir)) {
		fprintf(stderr, "kpkg: unsafe path in %s (repo=%s distdir=%s workdir=%s)\n", CONF, repo, distdir, workdir);
		exit(1);
	}
}
void osid(char *out, size_t n)
{
	FILE *f = fopen("/etc/os-release", "r");
	char line[BUF], *v;
	size_t l;
	snprintf(out, n, "unknown");
	if (!f) return;
	while (fgets(line, sizeof line, f)) {
		if (strncmp(line, "ID=", 3)) continue;
		v = trim(line + 3);
		l = strlen(v);
		if (l >= 2 && (v[0] == '"' || v[0] == '\'') && v[l - 1] == v[0]) { v[l - 1] = 0; v++; }
		snprintf(out, n, "%s", v);
		break;
	}
	fclose(f);
}
int host_allowed(char *id, size_t n)
{
	const char *f = getenv("KPKG_FORCE");
	osid(id, n);
	if (allow_host || (f && *f && strcmp(f, "0"))) return 1;
	return !strcmp(id, "kryonux");
}
int host_ok(void)
{
	char id[64];
	if (host_allowed(id, sizeof id)) return 1;
	fprintf(stderr, "kpkg: this system is not Kryonux (ID=%s)\n", id);
	fprintf(stderr, "kpkg: installing into / would break the package manager of this system\n");
	fprintf(stderr, "kpkg: use the isolated box mode, or set KPKG_FORCE=1 if you know what you are doing\n");
	return 0;
}
int need_root(void)
{
	if (geteuid() != 0) { fputs("kpkg: root privileges are required\n", stderr); return 0; }
	return 1;
}
int have(const char *cmd)
{
	const char *path = getenv("PATH");
	char *dup, *d, *save = NULL;
	char p[BUF];
	int ok = 0;
	if (!path || !*path) path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin";
	dup = xstrdup(path);
	for (d = strtok_r(dup, ":", &save); d && !ok; d = strtok_r(NULL, ":", &save)) {
		snprintf(p, sizeof p, "%s/%s", d, cmd);
		ok = access(p, X_OK) == 0;
	}
	free(dup);
	return ok;
}
static int fetch_one_url(const char *url, const char *out);
int fetch(const char *url, const char *out)
{
	static const char *const gnu[] = {"https://ftpmirror.gnu.org/gnu/", "https://mirrors.kernel.org/gnu/", "https://ftp.gnu.org/gnu/", NULL};
	const char *pre[] = {"https://ftp.gnu.org/gnu/", "https://ftpmirror.gnu.org/gnu/", NULL};
	int i, j;
	if (fetch_one_url(url, out) == 0) return 0;
	for (i = 0; pre[i]; i++) {
		size_t l = strlen(pre[i]);
		if (strncmp(url, pre[i], l)) continue;
		for (j = 0; gnu[j]; j++) {
			char alt[BUF];
			if (!strcmp(gnu[j], pre[i])) continue;
			snprintf(alt, sizeof alt, "%s%s", gnu[j], url + l);
			fprintf(stderr, "kpkg: retrying from %s\n", gnu[j]);
			if (fetch_one_url(alt, out) == 0) return 0;
		}
	}
	return 1;
}
static int fetch_one_url(const char *url, const char *out)
{
	char *a[24];
	int n = 0;
	a[n++] = "curl"; a[n++] = "-fL";
	if (!isatty(2)) a[n++] = "-sS";
	a[n++] = "--proto"; a[n++] = "=https";
	a[n++] = "--proto-redir"; a[n++] = "=https";
	a[n++] = "--retry"; a[n++] = "1";
	a[n++] = "--connect-timeout"; a[n++] = "10";
	a[n++] = "--speed-limit"; a[n++] = "10000";
	a[n++] = "--speed-time"; a[n++] = "30";
	a[n++] = "-o"; a[n++] = (char *)out;
	a[n++] = (char *)url;
	a[n] = NULL;
	return run(a);
}
int vercmp(const char *a, const char *b)
{
	long x, y;
	char *ea, *eb;
	while (*a || *b) {
		while (*a == '.' || *a == '-' || *a == '_') a++;
		while (*b == '.' || *b == '-' || *b == '_') b++;
		if (!*a && !*b) return 0;
		if (!*a) return -1;
		if (!*b) return 1;
		if (isdigit((unsigned char)*a) && isdigit((unsigned char)*b)) {
			x = strtol(a, &ea, 10);
			y = strtol(b, &eb, 10);
			a = ea; b = eb;
			if (x != y) return x < y ? -1 : 1;
		} else {
			if (*a != *b) return (unsigned char)*a < (unsigned char)*b ? -1 : 1;
			a++; b++;
		}
	}
	return 0;
}
void list_add(char ***v, int *n, const char *s)
{
	*v = xrealloc(*v, ((size_t)*n + 1) * sizeof **v);
	(*v)[(*n)++] = xstrdup(s);
}
void list_free(char **v, int n)
{
	int i;
	for (i = 0; i < n; i++) free(v[i]);
	free(v);
}
int list_has(char **v, int n, const char *s)
{
	int i;
	for (i = 0; i < n; i++)
		if (!strcmp(v[i], s)) return 1;
	return 0;
}

int use_color;
const char *C(char k)
{
	if (!use_color) return "";
	switch (k) {
	case 'b': return "\033[1;36m";
	case 'g': return "\033[1;32m";
	case 'y': return "\033[1;33m";
	case 'r': return "\033[1;31m";
	case 'd': return "\033[2m";
	default: return "\033[0m";
	}
}
void ui_init(void)
{
	const char *t = getenv("TERM");
	use_color = isatty(1) && !getenv("NO_COLOR") && t && strcmp(t, "dumb");
}
