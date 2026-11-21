#define pr_fmt(fmt) "kryonk: " fmt

#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <generated/utsrelease.h>
#include "kryonk_version.h"

static int kryonk_show(struct seq_file *m, void *v)
{
	seq_printf(m, "kryonk %s\nrelease %s\n", KRYONK_VERSION, UTS_RELEASE);
	return 0;
}

static int __init kryonk_init(void)
{
	if (!proc_create_single("kryonk", 0444, NULL, kryonk_show))
		pr_warn("cannot create /proc/kryonk\n");
	pr_info("fork %s (%s)\n", KRYONK_VERSION, UTS_RELEASE);
	return 0;
}
device_initcall(kryonk_init);
