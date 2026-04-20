#include "KalamShim.h"

#include "../lib/kalam.h"


void KalamFetchAvailableDevices(KalamOnCbResult onDone) {
  FetchAvailableDevices((on_cb_result_t *)onDone);
}

void KalamInitialize(const char *initInputJson, KalamOnCbResult onDone) {
  Initialize((char *)initInputJson, (on_cb_result_t *)onDone);
}

void KalamFetchStorages(const char *deviceInputJson, KalamOnCbResult onDone) {
  FetchStorages((char *)deviceInputJson, (on_cb_result_t *)onDone);
}

void KalamWalk(const char *walkInputJson, KalamOnCbResult onDone) {
  Walk((char *)walkInputJson, (on_cb_result_t *)onDone);
}

void KalamMakeDirectory(const char *makeDirectoryInputJson, KalamOnCbResult onDone) {
  MakeDirectory((char *)makeDirectoryInputJson, (on_cb_result_t *)onDone);
}

void KalamFileExists(const char *fileExistsInputJson, KalamOnCbResult onDone) {
  FileExists((char *)fileExistsInputJson, (on_cb_result_t *)onDone);
}

void KalamDeleteFile(const char *deleteFileInputJson, KalamOnCbResult onDone) {
  DeleteFile((char *)deleteFileInputJson, (on_cb_result_t *)onDone);
}

void KalamRenameFile(const char *renameFileInputJson, KalamOnCbResult onDone) {
  RenameFile((char *)renameFileInputJson, (on_cb_result_t *)onDone);
}

void KalamUploadFiles(
    const char *uploadFilesInputJson,
    KalamOnCbResult onPreprocess,
    KalamOnCbResult onProgress,
    KalamOnCbResult onDone
) {
  UploadFiles((char *)uploadFilesInputJson,
               (on_cb_result_t *)onPreprocess,
               (on_cb_result_t *)onProgress,
               (on_cb_result_t *)onDone);
}

void KalamDownloadFiles(
    const char *downloadFilesInputJson,
    KalamOnCbResult onPreprocess,
    KalamOnCbResult onProgress,
    KalamOnCbResult onDone
) {
  DownloadFiles((char *)downloadFilesInputJson,
                  (on_cb_result_t *)onPreprocess,
                  (on_cb_result_t *)onProgress,
                  (on_cb_result_t *)onDone);
}

void KalamCancelTransfer(const char *cancelTransferInputJson, KalamOnCbResult onDone) {
  CancelTransfer((char *)cancelTransferInputJson, (on_cb_result_t *)onDone);
}

void KalamDispose(const char *deviceInputJson, KalamOnCbResult onDone) {
  Dispose((char *)deviceInputJson, (on_cb_result_t *)onDone);
}

