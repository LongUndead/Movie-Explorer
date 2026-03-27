import 'package:equatable/equatable.dart';

abstract class MovieEvent extends Equatable {
  const MovieEvent();

  @override
  List<Object> get props => [];
}

// Sự kiện yêu cầu lấy danh sách phim phổ biến
class GetPopularMoviesEvent extends MovieEvent {}
class SearchMoviesEvent extends MovieEvent {
  final String query;

  const SearchMoviesEvent(this.query);

  @override
  List<Object> get props => [query];
}
class GetCinemasByBrandEvent extends MovieEvent {
  final String brand;
  GetCinemasByBrandEvent(this.brand);
}