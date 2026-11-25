#include "kpkg.h"
#define VERSION "0.0.1"
const char *cp_version = VERSION;
void usage(void)
{
	puts("kpkg " VERSION " (standalone source package manager for Kryonux)\n"
	     "usage: kpkg command [options]\n\n"
	     "  sync [--file tree.tar.gz]      download and verify the recipe tree (minisign is required)\n"
	     "  update [--force]               update kpkg itself from signed GitHub releases\n"
	     "  fix                            recreate directories, fetch recipes, run doctor\n"
	     "  install [-p] [-y] [-o] [--jobs N] [--force] package|file.kpkg...\n"
	     "  lint    file.kpkg...\n"
	     "  check   [tree]                 lint every recipe in the tree and check its layout and dependencies\n"
	     "  hold    [package...]            keep packages at the installed version\n"
	     "  unhold  package...             allow upgrades again\n"
	     "  checksum file.kpkg...         download the sources and write SHA256\n"
	     "  remove  [-p] [-a] [--force] package...\n"
	     "  upgrade [-p] [-a] [--jobs N] [--no-snapshot]\n"
	     "  clean   [-p] [-a]\n"
	     "  search  term\n"
	     "  info    package\n"
	     "  list\n"
	     "  files   package\n"
	     "  owns    path\n"
	     "  doctor\n"
	     "  snapshot [label]\n"
	     "  snapshots\n"
	     "  snapshot-rm name\n"
	     "  rollback [-y] [name]\n"
	     "  version, help\n\n"
	     "package forms: name, category/name, name@version\n"
	     "-p dry run, -y do not ask, -o keep the package out of the world set,\n"
	     "--jobs N parallel build jobs, --force overwrite conflicts and ignore reverse dependencies.\n"
	     "every source is verified by SHA256 and the recipe tree by minisign, there is no way to turn it off.\n"
	     "optional settings (JOBS, CFLAGS, ...) live in " USERCONF "; an empty file means defaults.\n"
	     "packages are built from source and tracked in " DBDIR ".\n"
	     "snapshots are btrfs filesystem snapshots for rollback, not Ubuntu Snap packages.");
}
static int mutating(const char *c)
{
	return !strcmp(c, "install") || !strcmp(c, "remove") || !strcmp(c, "upgrade") || !strcmp(c, "clean") || !strcmp(c, "fix") || !strcmp(c, "sync");
}
static void warn_interrupted(const char *c)
{
	char what[256];
	if (mutating(c) && txn_interrupted(what, sizeof what)) {
		fprintf(stderr, "kpkg: warning: the last change of %s did not finish, probably a power loss or a crash\n", what);
		fputs("kpkg: reinstall it with: kpkg install --force <package>\n", stderr);
		txn_end();
	}
}
static int args_pretend(int argc, char **argv)
{
	int i;
	for (i = 0; i < argc; i++)
		if (!strcmp(argv[i], "-p") || !strcmp(argv[i], "--pretend")) return 1;
	return 0;
}
int main(int argc, char **argv)
{
	ui_init();
	const char *c;
	int r = 1;
	if (argc < 2) {
		usage();
		return 1;
	}
	c = argv[1];
	loadconf();
	if (!acquire_lock()) return 1;
	lock_signals();
	warn_interrupted(c);
	if (!strcmp(c, "version") || !strcmp(c, "--version")) {
		puts("kpkg " VERSION);
		r = 0;
	} else if (!strcmp(c, "help") || !strcmp(c, "--help") || !strcmp(c, "-h")) {
		usage();
		r = 0;
	} else if (!strcmp(c, "update")) {
		r = host_ok() ? cmd_update(argc - 2, argv + 2) : 1;
	} else if (!strcmp(c, "hold")) {
		r = cmd_hold(argc - 2, argv + 2, 1);
	} else if (!strcmp(c, "unhold")) {
		r = cmd_hold(argc - 2, argv + 2, 0);
	} else if (!strcmp(c, "checksum")) {
		r = cmd_checksum(argc - 2, argv + 2);
	} else if (!strcmp(c, "lint")) {
		r = cmd_lint(argc - 2, argv + 2);
	} else if (!strcmp(c, "check")) {
		r = cmd_check(argc - 2, argv + 2);
	} else if (!strcmp(c, "fix")) {
		r = host_ok() ? cmd_fix() : 1;
	} else if (!strcmp(c, "sync")) {
		if (!host_ok()) r = 1;
		else if (argc == 4 && !strcmp(argv[2], "--file")) r = cmd_sync_file(argv[3]);
		else if (argc == 2) r = cmd_sync();
		else {
			fputs("kpkg: usage: kpkg sync [--file tree.tar.gz]\n", stderr);
			r = 1;
		}
	} else if (!strcmp(c, "install")) {
		r = (host_ok() || args_pretend(argc - 2, argv + 2)) ? cmd_install(argc - 2, argv + 2) : 1;
	} else if (!strcmp(c, "remove")) {
		r = (host_ok() || args_pretend(argc - 2, argv + 2)) ? cmd_remove(argc - 2, argv + 2) : 1;
	} else if (!strcmp(c, "upgrade")) {
		r = (host_ok() || args_pretend(argc - 2, argv + 2)) ? cmd_upgrade(argc - 2, argv + 2) : 1;
	} else if (!strcmp(c, "snapshot")) {
		r = cmd_snapshot(argc - 2, argv + 2);
	} else if (!strcmp(c, "snapshots")) {
		r = cmd_snapshots();
	} else if (!strcmp(c, "snapshot-rm")) {
		r = cmd_snapshot_rm(argc - 2, argv + 2);
	} else if (!strcmp(c, "rollback")) {
		r = cmd_rollback(argc - 2, argv + 2);
	} else if (!strcmp(c, "clean")) {
		r = (host_ok() || args_pretend(argc - 2, argv + 2)) ? cmd_clean(argc - 2, argv + 2) : 1;
	} else if (!strcmp(c, "search")) {
		r = cmd_search(argc - 2, argv + 2);
	} else if (!strcmp(c, "info")) {
		r = cmd_info(argc - 2, argv + 2);
	} else if (!strcmp(c, "list")) {
		r = cmd_list();
	} else if (!strcmp(c, "files")) {
		r = cmd_files(argc - 2, argv + 2);
	} else if (!strcmp(c, "owns")) {
		r = cmd_owns(argc - 2, argv + 2);
	} else if (!strcmp(c, "doctor")) {
		r = cmd_doctor();
	} else {
		fprintf(stderr, "kpkg: unknown command: %s\n", c);
		usage();
	}
	release_lock();
	return r;
}
