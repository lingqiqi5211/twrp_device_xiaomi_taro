// Copyright (C) 2026 The Android Open Source Project
// SPDX-License-Identifier: Apache-2.0

#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#include <grp.h>
#include <mntent.h>
#include <sched.h>
#include <sys/mount.h>
#include <sys/prctl.h>
#include <unistd.h>

namespace {
constexpr char kCache[] = "/tmp/device-runtime/haptics";
constexpr gid_t kSystem = 1000;
constexpr gid_t kInput = 1004;
constexpr gid_t kAudio = 1005;

int Fail(const char* operation) {
    std::fprintf(stderr, "taro-haptics: %s: %s\n", operation, std::strerror(errno));
    return 1;
}
}  // namespace

int main(int argc, char** argv) {
    if (argc != 2 || (std::strcmp(argv[1], "feature") && std::strcmp(argv[1], "alias"))) {
        std::fprintf(stderr, "usage: taro_haptics_launcher feature|alias\n");
        return 1;
    }
    if (unshare(CLONE_NEWNS) || mount(nullptr, "/", nullptr, MS_PRIVATE | MS_REC, nullptr)) {
        return Fail("isolate mounts");
    }

    // A service must neither retain ROM/data mounts nor observe subsequent
    // Recovery mounts. Detach children before their parents in this namespace.
    FILE* mounts = setmntent("/proc/mounts", "r");
    if (!mounts) return Fail("read mounts");
    std::vector<std::string> disk_mounts;
    while (mntent* entry = getmntent(mounts)) {
        if (std::strncmp(entry->mnt_fsname, "/dev/block/", 11) == 0) {
            disk_mounts.emplace_back(entry->mnt_dir);
        }
    }
    const bool read_failed = std::ferror(mounts);
    endmntent(mounts);
    if (read_failed) return Fail("read mounts");
    std::stable_sort(disk_mounts.begin(), disk_mounts.end(),
                     [](const auto& left, const auto& right) { return left.size() > right.size(); });
    for (const auto& path : disk_mounts) {
        if (umount2(path.c_str(), MNT_DETACH)) return Fail(path.c_str());
    }
    if (chdir("/")) return Fail("change directory");
    // This directory contains only cached firmware, never ROM libraries. The
    // HAL's absolute paths must not bypass its private linker namespaces.
    if (mount("/tmp/device-runtime/vendor", "/vendor", nullptr, MS_BIND, nullptr)) {
        return Fail("bind cached vendor");
    }
    if (mount(nullptr, "/vendor", nullptr, MS_BIND | MS_REMOUNT | MS_RDONLY | MS_NOSUID | MS_NODEV,
              nullptr)) {
        return Fail("protect cached vendor");
    }

    const gid_t groups[] = {kInput, kAudio};
    const size_t group_count = std::strcmp(argv[1], "feature") == 0 ? 2 : 1;
    if (prctl(PR_SET_KEEPCAPS, 0L) || setgroups(group_count, groups) || setgid(kSystem) || setuid(kSystem) ||
        prctl(PR_SET_NO_NEW_PRIVS, 1L, 0L, 0L, 0L)) {
        return Fail("drop privileges");
    }
    if (unsetenv("LD_LIBRARY_PATH") ||
        setenv("LD_CONFIG_FILE", "/system/etc/haptics.ld.config.txt", 1)) {
        return Fail("set linker configuration");
    }
    const std::string executable = std::string(kCache) + "/bin/" + argv[1];
    execl(executable.c_str(), executable.c_str(), nullptr);
    return Fail("exec HAL");
}
