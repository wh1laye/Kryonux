#include "kpkg.h"
int lock_fd = -1;
static char lock_file[BUF];
static char txn_file[BUF];
static sigset_t crit_old;
static int crit_depth;
static void lock_path(char *out, size_t n)
{
	if (geteuid() == 0)
		snprintf(out, n, "%s", LOCKFILE);
	else
		snprintf(out, n, "/tmp/kpkg-%ld.lock", (long)getuid());
}
static void boot_id(char *out, size_t n)
{
	FILE *f = fopen("/proc/sys/kernel/random/boot_id", "r");
	out[0] = 0;
	if (!f) return;
	if (fgets(out, (int)n, f)) out[strcspn(out, "\n")] = 0;
	fclose(f);
}
static int pid_alive(long pid)
{
	if (pid <= 0) return 0;
	return kill((pid_t)pid, 0) == 0 || errno == EPERM;
}
static void on_signal(int sig)
{
	static const char msg[] = "\nkpkg: interrupted, the package database was not left half written\n";
	if (write(2, msg, sizeof msg - 1) < 0) {}
	_exit(128 + sig);
}
void lock_signals(void)
{
	struct sigaction sa;
	memset(&sa, 0, sizeof sa);
	sa.sa_handler = on_signal;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGHUP, &sa, NULL);
	sigaction(SIGQUIT, &sa, NULL);
}
void crit_begin(void)
{
	sigset_t all;
	if (crit_depth++) return;
	sigemptyset(&all);
	sigaddset(&all, SIGINT);
	sigaddset(&all, SIGTERM);
	sigaddset(&all, SIGHUP);
	sigaddset(&all, SIGQUIT);
	sigprocmask(SIG_BLOCK, &all, &crit_old);
}
void crit_end(void)
{
	if (crit_depth == 0 || --crit_depth) return;
	sigprocmask(SIG_SETMASK, &crit_old, NULL);
}
static void holder_info(int fd, char *out, size_t n)
{
	char buf[128] = "";
	ssize_t r;
	out[0] = 0;
	if (lseek(fd, 0, SEEK_SET) != 0) return;
	r = read(fd, buf, sizeof buf - 1);
	if (r > 0) {
		buf[r] = 0;
		snprintf(out, n, "%s", buf);
		out[strcspn(out, "\n")] = 0;
	}
}
int acquire_lock(void)
{
	char info[128], line[160];
	long hp;
	int fd;
	lock_path(lock_file, sizeof lock_file);
	fd = open(lock_file, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0600);
	if (fd < 0) {
		fprintf(stderr, "kpkg: cannot open %s: %s\n", lock_file, strerror(errno));
		return 0;
	}
	if (flock(fd, LOCK_EX | LOCK_NB) < 0) {
		if (errno == EWOULDBLOCK || errno == EAGAIN) {
			holder_info(fd, info, sizeof info);
			hp = strtol(info, NULL, 10);
			if (hp > 0 && pid_alive(hp))
				fprintf(stderr, "kpkg: another instance is already running (pid %ld, %s)\n", hp, lock_file);
			else
				fprintf(stderr, "kpkg: another instance is already running (%s)\n", lock_file);
			fputs("kpkg: wait for it to finish\n", stderr);
		} else {
			fprintf(stderr, "kpkg: cannot lock %s: %s\n", lock_file, strerror(errno));
		}
		close(fd);
		return 0;
	}
	lock_fd = fd;
	snprintf(line, sizeof line, "%ld\n", (long)getpid());
	if (ftruncate(fd, 0) == 0 && lseek(fd, 0, SEEK_SET) == 0) {
		if (write(fd, line, strlen(line)) < 0) {}
	}
	snprintf(txn_file, sizeof txn_file, "%s/.transaction", DBDIR);
	return 1;
}
void release_lock(void)
{
	if (lock_fd >= 0) {
		flock(lock_fd, LOCK_UN);
		close(lock_fd);
		lock_fd = -1;
	}
}
void txn_begin(const char *what)
{
	char bid[64];
	FILE *f;
	if (!txn_file[0]) return;
	boot_id(bid, sizeof bid);
	f = fopen(txn_file, "w");
	if (!f) return;
	fprintf(f, "%ld\n%s\n%s\n", (long)getpid(), bid, what);
	fflush(f);
	fsync(fileno(f));
	fclose(f);
}
void txn_end(void)
{
	if (txn_file[0]) unlink(txn_file);
}
int txn_interrupted(char *what, size_t n)
{
	char path[BUF], l1[64] = "", l2[64] = "", l3[256] = "", bid[64];
	FILE *f;
	long pid;
	snprintf(path, sizeof path, "%s/.transaction", DBDIR);
	f = fopen(path, "r");
	if (!f) return 0;
	if (fgets(l1, sizeof l1, f)) l1[strcspn(l1, "\n")] = 0;
	if (fgets(l2, sizeof l2, f)) l2[strcspn(l2, "\n")] = 0;
	if (fgets(l3, sizeof l3, f)) l3[strcspn(l3, "\n")] = 0;
	fclose(f);
	pid = strtol(l1, NULL, 10);
	boot_id(bid, sizeof bid);
	if (pid > 0 && pid_alive(pid) && !strcmp(l2, bid)) return 0;
	snprintf(what, n, "%s", l3[0] ? l3 : "unknown package");
	return 1;
}
static long read_num(const char *path)
{
	char b[32] = "";
	FILE *f = fopen(path, "r");
	if (!f) return -1;
	if (!fgets(b, sizeof b, f)) { fclose(f); return -1; }
	fclose(f);
	return strtol(b, NULL, 10);
}
int power_ok(void)
{
	DIR *d = opendir("/sys/class/power_supply");
	struct dirent *e;
	char p[BUF], st[32];
	FILE *f;
	long cap;
	int bad = 0, ac = 0;
	if (cfg_min_battery <= 0 || !d) {
		if (d) closedir(d);
		return 1;
	}
	while ((e = readdir(d))) {
		if (e->d_name[0] == '.') continue;
		snprintf(p, sizeof p, "/sys/class/power_supply/%s/type", e->d_name);
		f = fopen(p, "r");
		if (!f) continue;
		st[0] = 0;
		if (fgets(st, sizeof st, f)) st[strcspn(st, "\n")] = 0;
		fclose(f);
		if (!strcmp(st, "Mains") || !strcmp(st, "USB")) {
			snprintf(p, sizeof p, "/sys/class/power_supply/%s/online", e->d_name);
			if (read_num(p) == 1) ac = 1;
			continue;
		}
		if (strcmp(st, "Battery")) continue;
		snprintf(p, sizeof p, "/sys/class/power_supply/%s/status", e->d_name);
		f = fopen(p, "r");
		if (!f) continue;
		st[0] = 0;
		if (fgets(st, sizeof st, f)) st[strcspn(st, "\n")] = 0;
		fclose(f);
		snprintf(p, sizeof p, "/sys/class/power_supply/%s/capacity", e->d_name);
		cap = read_num(p);
		if (!strcmp(st, "Discharging") && cap >= 0 && cap < cfg_min_battery) bad = 1;
	}
	closedir(d);
	if (bad && !ac) {
		fprintf(stderr, "kpkg: the battery is below %d%% and not charging, refusing to change the system\n", cfg_min_battery);
		fputs("kpkg: connect the charger, or lower MIN_BATTERY in /etc/kpkg/config.kpkg\n", stderr);
		return 0;
	}
	return 1;
}
