import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie_model.dart';
import '../models/showtime_model.dart';
import '../models/cinema_model.dart';


abstract class MovieRemoteDataSource {
  Future<List<MovieModel>> getPopularMovies();
  Future<List<MovieModel>> searchMovies(String query);
  Future<List<ShowtimeModel>> getShowtimes(int movieId);
  
  // 👉 1. ĐÃ THÊM: Khai báo hàm lấy rạp trong "cái vỏ" (abstract class)
  Future<List<CinemaModel>> getCinemasByBrand(String brand, {bool random = false}); 
}

class MovieRemoteDataSourceImpl implements MovieRemoteDataSource {
  final http.Client client;
  // Thay bằng IP Wifi máy tính của bạn + Cổng 3000 của Node.js
  final String baseUrl = 'http://192.168.1.4:3000/api'; 

  MovieRemoteDataSourceImpl({required this.client});

  @override
  Future<List<MovieModel>> getPopularMovies() async {
    // Gọi thẳng vào API Node.js của chúng ta
    final response = await client.get(Uri.parse('$baseUrl/movies'));

    if (response.statusCode == 200) {
      // Backend của chúng ta trả về list trực tiếp, không có mảng ['results'] như TMDB
      final List result = json.decode(response.body);
      return result.map((e) => MovieModel.fromJson(e)).toList();
    } else {
      throw Exception('Lỗi khi tải dữ liệu phim từ Backend');
    }
  }

  @override
  Future<List<MovieModel>> searchMovies(String query) async {
    // Gọi lấy toàn bộ phim từ server về
    final response = await client.get(Uri.parse('$baseUrl/movies'));

    if (response.statusCode == 200) {
      final List result = json.decode(response.body);
      List<MovieModel> allMovies = result.map((e) => MovieModel.fromJson(e)).toList();
      
      // Lọc danh sách phim ngay trên điện thoại dựa theo từ khóa nhập vào
      final searchResult = allMovies.where((movie) => 
          movie.title.toLowerCase().contains(query.toLowerCase())
      ).toList();

      return searchResult;
    } else {
      throw Exception('Lỗi khi tìm kiếm phim từ Backend');
    }
  }

  @override
  Future<List<ShowtimeModel>> getShowtimes(int movieId) async {
    final response = await client.get(Uri.parse('$baseUrl/showtimes/$movieId'));

    if (response.statusCode == 200) {
      final List result = json.decode(response.body);
      return result.map((e) => ShowtimeModel.fromJson(e)).toList();
    } else {
      throw Exception('Lỗi khi tải danh sách suất chiếu từ Backend');
    }
  }

 @override 
  Future<List<CinemaModel>> getCinemasByBrand(String brandId, {bool random = false}) async {
    final queryParameters = <String, String>{};

    if (random) {
      queryParameters['random'] = 'true';
    } else if (brandId.trim().isNotEmpty) {
      // ✅ ĐÃ SỬA: Gửi chìa khóa tên là 'brand_id' lên Node.js
      queryParameters['brand_id'] = brandId.trim();
    }

    final uri = Uri.parse('$baseUrl/cinemas').replace(queryParameters: queryParameters);
    final response = await client.get(uri);
    
    if (response.statusCode == 200) {
      final List decoded = json.decode(response.body);
      return decoded.map((e) => CinemaModel.fromJson(e)).toList();
    } else {
      throw Exception('Lỗi load rạp từ Backend Node.js');
    }
  }
}