package main

import (
	"fmt"

	"github.com/spf13/cobra"

	// Used by cgo
	_ "github.com/lxc/lxd/lxd/include"
)

/*
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include <fcntl.h>
#include <libgen.h>
#include <sched.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/types.h>
#include <unistd.h>

#include "include/memory_utils.h"
#include "include/mount_utils.h"
#include "include/syscall_numbers.h"
#include "include/syscall_wrappers.h"

extern char* advance_arg(bool required);

void forkcoresched(void)
{
	char *cur = NULL;
	int ret;
	__u64 cookie;

	// Check that we're root
	if (geteuid() != 0)
		_exit(EXIT_FAILURE);

	// Get the subcommand
	cur = advance_arg(false);
	if (cur == NULL ||
	    (strcmp(cur, "--help") == 0 ||
	     strcmp(cur, "--version") == 0 || strcmp(cur, "-h") == 0))
		_exit(EXIT_SUCCESS);

	ret = core_scheduling_cookie_create_thread(0);
	if (ret)
		_exit(EXIT_FAILURE);

	cookie = core_scheduling_cookie_get(0);
	if (!core_scheduling_cookie_valid(cookie))
		_exit(EXIT_FAILURE);

	for (const char *pidstr = cur; pidstr; pidstr = advance_arg(false)) {
		ret = core_scheduling_cookie_share_to(atoi(pidstr));
		if (ret)
			_exit(EXIT_FAILURE);

		cookie = core_scheduling_cookie_get(0);
		if (!core_scheduling_cookie_valid(cookie))
			_exit(EXIT_FAILURE);
	}

	_exit(EXIT_SUCCESS);
}
*/
import "C"

type cmdForkcoresched struct {
	global *cmdGlobal
}

func (c *cmdForkcoresched) Command() *cobra.Command {
	// Main subcommand
	cmd := &cobra.Command{}
	cmd.Use = "forkcoresched <PID> [...]"
	cmd.Short = "Create new core scheduling domain"
	cmd.Long = `Description:
  Create new core scheduling domain

  This command is used to move a set of processes into a new core scheduling
  domain.
`
	cmd.RunE = c.Run
	cmd.Hidden = true

	return cmd
}

func (c *cmdForkcoresched) Run(cmd *cobra.Command, args []string) error {
	return fmt.Errorf("This command should have been intercepted in cgo")
}