#pragma once

// Bridging header for exposing our C shim to Swift.
// This keeps Swift code independent from `module.modulemap`.

#include "GomtpShim/GomtpShim.h"
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
