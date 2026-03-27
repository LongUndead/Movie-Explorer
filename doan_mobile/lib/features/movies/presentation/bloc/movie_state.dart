import 'package:equatable/equatable.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/cinema.dart';

abstract class MovieState extends Equatable {
  const MovieState();
  
  @override
  List<Object> get props => [];
}

// 1. Trạng thái ban đầu khi chưa làm gì cả
class MovieInitial extends MovieState {}

// 2. Trạng thái đang gọi API (Để UI hiện vòng xoay loading)
class MovieLoading extends MovieState {}

// 3. Trạng thái gọi API thành công, mang theo danh sách phim
class MovieLoaded extends MovieState {
  final List<Movie> movies;

  const MovieLoaded(this.movies);

  @override
  List<Object> get props => [movies];
}

// 4. Trạng thái lỗi (Rớt mạng, server sập...)
class MovieError extends MovieState {
  final String message;

  const MovieError(this.message);

  @override
  List<Object> get props => [message];
}
class CinemasLoading extends MovieState {}

class CinemasLoaded extends MovieState {
  final List<Cinema> cinemas;
  CinemasLoaded(this.cinemas);
}

class CinemasError extends MovieState {
  final String message;
  CinemasError(this.message);
}