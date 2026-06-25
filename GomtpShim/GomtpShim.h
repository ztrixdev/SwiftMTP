#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Matches `typedef void (* on_cb_result_t)(char*);` in `kalam.h`.
typedef void (*GomtpOnCbResult)(char *);

// Thin wrappers around `kalam.dylib` exports.
// We use `GomtpOnCbResult` (function pointer) instead of `on_cb_result_t*`
// to keep the Swift callback interop straightforward.
void GomtpFetchAvailableDevices(GomtpOnCbResult onDone);
void GomtpInitialize(const char *initInputJson, GomtpOnCbResult onDone);
void GomtpFetchStorages(const char *deviceInputJson, GomtpOnCbResult onDone);
void GomtpWalk(const char *walkInputJson, GomtpOnCbResult onDone);
void GomtpMakeDirectory(const char *makeDirectoryInputJson, GomtpOnCbResult onDone);
void GomtpFileExists(const char *fileExistsInputJson, GomtpOnCbResult onDone);
void GomtpDeleteFile(const char *deleteFileInputJson, GomtpOnCbResult onDone);
void GomtpRenameFile(const char *renameFileInputJson, GomtpOnCbResult onDone);
void GomtpUploadFiles(
    const char *uploadFilesInputJson,
    GomtpOnCbResult onPreprocess,
    GomtpOnCbResult onProgress,
    GomtpOnCbResult onDone
);
void GomtpDownloadFiles(
    const char *downloadFilesInputJson,
    GomtpOnCbResult onPreprocess,
    GomtpOnCbResult onProgress,
    GomtpOnCbResult onDone
);
void GomtpCancelTransfer(const char *cancelTransferInputJson, GomtpOnCbResult onDone);
void GomtpDispose(const char *deviceInputJson, GomtpOnCbResult onDone);

#ifdef __cplusplus
} // extern "C"
#endif

