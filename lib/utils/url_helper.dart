String getFullImageUrl(String? filePath) {
  if (filePath == null || filePath.isEmpty) return '';
  return 'http://192.168.0.101:5001$filePath';
}