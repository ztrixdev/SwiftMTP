#include "GomtpShim.h"

#include "../lib/gomtp.h"


void GomtpFetchAvailableDevices(GomtpOnCbResult onDone) {
  FetchAvailableDevices((on_cb_result_t *)onDone);
}

void GomtpInitialize(const char *initInputJson, GomtpOnCbResult onDone) {
  Initialize((char *)initInputJson, (on_cb_result_t *)onDone);
}

void GomtpFetchStorages(const char *deviceInputJson, GomtpOnCbResult onDone) {
  FetchStorages((char *)deviceInputJson, (on_cb_result_t *)onDone);
}

void GomtpWalk(const char *walkInputJson, GomtpOnCbResult onDone) {
  Walk((char *)walkInputJson, (on_cb_result_t *)onDone);
}

void GomtpMakeDirectory(const char *makeDirectoryInputJson, GomtpOnCbResult onDone) {
  MakeDirectory((char *)makeDirectoryInputJson, (on_cb_result_t *)onDone);
}

void GomtpFileExists(const char *fileExistsInputJson, GomtpOnCbResult onDone) {
  FileExists((char *)fileExistsInputJson, (on_cb_result_t *)onDone);
}

void GomtpDeleteFile(const char *deleteFileInputJson, GomtpOnCbResult onDone) {
  DeleteFile((char *)deleteFileInputJson, (on_cb_result_t *)onDone);
}

void GomtpRenameFile(const char *renameFileInputJson, GomtpOnCbResult onDone) {
  RenameFile((char *)renameFileInputJson, (on_cb_result_t *)onDone);
}

void GomtpUploadFiles(
    const char *uploadFilesInputJson,
    GomtpOnCbResult onPreprocess,
    GomtpOnCbResult onProgress,
    GomtpOnCbResult onDone
) {
  UploadFiles((char *)uploadFilesInputJson,
               (on_cb_result_t *)onPreprocess,
               (on_cb_result_t *)onProgress,
               (on_cb_result_t *)onDone);
}

void GomtpDownloadFiles(
    const char *downloadFilesInputJson,
    GomtpOnCbResult onPreprocess,
    GomtpOnCbResult onProgress,
    GomtpOnCbResult onDone
) {
  DownloadFiles((char *)downloadFilesInputJson,
                  (on_cb_result_t *)onPreprocess,
                  (on_cb_result_t *)onProgress,
                  (on_cb_result_t *)onDone);
}

void GomtpCancelTransfer(const char *cancelTransferInputJson, GomtpOnCbResult onDone) {
  CancelTransfer((char *)cancelTransferInputJson, (on_cb_result_t *)onDone);
}

void GomtpDispose(const char *deviceInputJson, GomtpOnCbResult onDone) {
  Dispose((char *)deviceInputJson, (on_cb_result_t *)onDone);
}

