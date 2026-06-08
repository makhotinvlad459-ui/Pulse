import 'file_download_helper_interface.dart';
import 'file_download_helper_mobile.dart'
    if (dart.library.html) 'file_download_helper_web.dart';

FileDownloadHelperPlatform createFileDownloadHelper() {
  return FileDownloadHelperPlatformImpl();
}