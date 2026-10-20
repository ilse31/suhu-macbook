#include "CSMC.h"
#include <IOKit/IOKitLib.h>
#include <stddef.h>
#include <string.h>

// AppleSMC user-client ABI. Only read-key-info (9) and read-bytes (5) are used.
typedef struct {
    uint8_t major, minor, build, reserved;
    uint16_t release;
} Version;
typedef struct {
    uint16_t version, length;
    uint32_t cpu, gpu, memory;
} Limits;
typedef struct {
    uint32_t size, type;
    uint8_t attributes;
} KeyInfo;
typedef struct {
    uint32_t key;
    Version version;
    Limits limits;
    KeyInfo info;
    uint8_t result, status, command;
    uint32_t index;
    uint8_t bytes[32];
} Request;

_Static_assert(sizeof(Request) == 80, "AppleSMC request size");
_Static_assert(offsetof(Request, result) == 40, "AppleSMC result offset");
_Static_assert(offsetof(Request, bytes) == 48, "AppleSMC payload offset");

uint32_t suhu_smc_open(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                       IOServiceMatching("AppleSMC"));
    if (!service) return 0;
    io_connect_t connection = 0;
    kern_return_t result = IOServiceOpen(service, mach_task_self(), 0, &connection);
    IOObjectRelease(service);
    return result == KERN_SUCCESS ? connection : 0;
}

void suhu_smc_close(uint32_t connection) {
    if (connection) IOServiceClose(connection);
}

static int call(uint32_t connection, Request *input, Request *output) {
    size_t size = sizeof(*output);
    memset(output, 0, size);
    return IOConnectCallStructMethod(connection, 2, input, sizeof(*input), output, &size)
               == KERN_SUCCESS && size == sizeof(*output) && output->result == 0;
}

int suhu_smc_read(uint32_t connection, const char *key, uint32_t *type,
                  uint8_t bytes[32], uint32_t *length) {
    *length = 0;
    *type = 0;
    memset(bytes, 0, 32);
    if (!connection || !key || strlen(key) != 4) return 0;
    Request input = {0}, output = {0};
    for (int i = 0; i < 4; i++) input.key = (input.key << 8) | (uint8_t)key[i];
    input.command = 9;
    if (!call(connection, &input, &output) || output.info.size == 0 || output.info.size > 32)
        return 0;
    input.info = output.info;
    input.command = 5;
    if (!call(connection, &input, &output)) return 0;
    *type = input.info.type;
    *length = input.info.size;
    memcpy(bytes, output.bytes, *length);
    return 1;
}
