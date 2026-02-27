// 🔗 Base API URL
const String BASE_URL = "http://147.93.19.17:5002";

// 🔧 Helper to convert relative path → full URL
String getFullImageUrl(String? relativePath) {
  if (relativePath == null || relativePath.isEmpty) {
    return ""; // you can also return a placeholder image URL here
  }
  if (relativePath.startsWith("http")) {
    return relativePath; // Already a full URL
  }
  return "$BASE_URL$relativePath";
}