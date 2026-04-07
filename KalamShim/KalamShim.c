#include "KalamShim.h"

#include "../lib/kalam.h"

void KalamInitialize(KalamOnCbResult onDone) {
  Initialize((on_cb_result_t *)onDone);
}

void KalamFetchStorages(KalamOnCbResult onDone) {
  FetchStorages((on_cb_result_t *)onDone);
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

void KalamDispose(KalamOnCbResult onDone) {
  Dispose((on_cb_result_t *)onDone);
}

