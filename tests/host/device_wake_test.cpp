#include <cassert>
#include <cstdint>
#include <cstdio>

#include "device_wake.h"

int main() {
   int seconds = 0;
   assert(DeviceWake::parseSleepSeconds("60", seconds) && seconds == 60);
   assert(DeviceWake::parseSleepSeconds("3555", seconds) && seconds == 3555);
   assert(DeviceWake::parseSleepSeconds("86400", seconds) && seconds == 86400);
   assert(!DeviceWake::parseSleepSeconds("", seconds));
   assert(!DeviceWake::parseSleepSeconds("59", seconds));
   assert(!DeviceWake::parseSleepSeconds("86401", seconds));
   assert(!DeviceWake::parseSleepSeconds("99999999999999999999", seconds));
   assert(!DeviceWake::parseSleepSeconds("300s", seconds));
   assert(!DeviceWake::parseSleepSeconds(" 300", seconds));

   assert(DeviceWake::remainingSleepSeconds(3555, 1000, 28000) == 3528);
   assert(DeviceWake::remainingSleepSeconds(60, 1000, 28000) == 60);
   assert(DeviceWake::remainingSleepSeconds(3600, 0xfffffff0U, 26984U) == 3573);
   assert(DeviceWake::remainingSleepSeconds(0, 0, 0) == 0);

   assert(DeviceWake::retrySleepSeconds(30) == 60);
   assert(DeviceWake::retrySleepSeconds(100) == 100);
   assert(DeviceWake::retrySleepSeconds(3600) == 300);
   std::puts("PASS: dynamic wake parsing, elapsed-time correction and retry bounds");
}
