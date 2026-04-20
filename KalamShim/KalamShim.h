#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Matches `typedef void (* on_cb_result_t)(char*);` in `kalam.h`.
typedef void (*KalamOnCbResult)(char *);

// Thin wrappers around `kalam.dylib` exports.
// We use `KalamOnCbResult` (function pointer) instead of `on_cb_result_t*`
// to keep the Swift callback interop straightforward.
void KalamFetchAvailableDevices(KalamOnCbResult onDone);
void KalamInitialize(const char *initInputJson, KalamOnCbResult onDone);
void KalamFetchStorages(const char *deviceInputJson, KalamOnCbResult onDone);
void KalamWalk(const char *walkInputJson, KalamOnCbResult onDone);
void KalamMakeDirectory(const char *makeDirectoryInputJson, KalamOnCbResult onDone);
void KalamFileExists(const char *fileExistsInputJson, KalamOnCbResult onDone);
void KalamDeleteFile(const char *deleteFileInputJson, KalamOnCbResult onDone);
void KalamRenameFile(const char *renameFileInputJson, KalamOnCbResult onDone);
void KalamUploadFiles(
    const char *uploadFilesInputJson,
    KalamOnCbResult onPreprocess,
    KalamOnCbResult onProgress,
    KalamOnCbResult onDone
);
void KalamDownloadFiles(
    const char *downloadFilesInputJson,
    KalamOnCbResult onPreprocess,
    KalamOnCbResult onProgress,
    KalamOnCbResult onDone
);
void KalamCancelTransfer(const char *cancelTransferInputJson, KalamOnCbResult onDone);
void KalamDispose(const char *deviceInputJson, KalamOnCbResult onDone);

#ifdef __cplusplus
} // extern "C"
#endif

