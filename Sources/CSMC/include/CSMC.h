#include <stdint.h>

uint32_t suhu_smc_open(void);
void suhu_smc_close(uint32_t connection);
int suhu_smc_read(uint32_t connection, const char *key, uint32_t *type,
                  uint8_t bytes[32], uint32_t *length);
