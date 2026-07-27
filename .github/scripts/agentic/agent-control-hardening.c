#define _GNU_SOURCE

#include <sys/prctl.h>
#include <unistd.h>

/*
 * Agent CLI 与模型生成的仓库命令使用同一 UID。每次动态程序启动时都把进程
 * 设为不可转储，阻止同 UID 子进程通过 /proc/<pid>/fd 或 ptrace 访问 CLI 的
 * 控制面；同时禁止 exec 取得新增权限。失败时必须立即停止，不能退化运行。
 */
__attribute__((constructor)) static void ctex_agent_harden_control_process(void)
{
    if (prctl(PR_SET_DUMPABLE, 0, 0, 0, 0) != 0 ||
        prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0) {
        _exit(126);
    }
}
