/// free-exercise-db görselleri barındırılmıyor; veri setinin sabitlenmiş
/// commit'inden doğrudan yükleniyor. Storage'a taşımak için yalnızca bu sabit değişir.
const exerciseImageBaseUrl =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/a859101d633a01c4a1a920d6a8ce41dabba0705f/exercises/';

String exerciseImageUrl(String path) => '$exerciseImageBaseUrl$path';
