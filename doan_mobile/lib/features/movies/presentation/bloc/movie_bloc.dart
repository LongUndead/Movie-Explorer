import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_popular_movies.dart';
import '../../domain/usecases/search_movies.dart';
// 1. ĐÃ THÊM: Import UseCase lấy rạp
import '../../domain/usecases/get_cinemas_by_brand.dart'; 
import 'movie_event.dart';
import 'movie_state.dart';

class MovieBloc extends Bloc<MovieEvent, MovieState> {
  final GetPopularMovies getPopularMoviesUseCase;
  final SearchMovies searchMoviesUseCase;
  
  // 2. ĐÃ THÊM: Khai báo UseCase mới
  final GetCinemasByBrand getCinemasByBrandUseCase; 

  // 3. ĐÃ THÊM: Nhúng nó vào Constructor
  MovieBloc({
    required this.getPopularMoviesUseCase, 
    required this.searchMoviesUseCase,
    required this.getCinemasByBrandUseCase, 
  }) : super(MovieInitial()) {
    
    // Lắng nghe sự kiện GetPopularMoviesEvent
    on<GetPopularMoviesEvent>((event, emit) async {
      emit(MovieLoading());
      try {
        final movies = await getPopularMoviesUseCase.execute();
        emit(MovieLoaded(movies));
      } catch (e) {
        emit(MovieError(e.toString()));
      }
    });

    // Lắng nghe sự kiện SearchMoviesEvent
    on<SearchMoviesEvent>((event, emit) async {
      emit(MovieLoading()); 
      try {
        final movies = await searchMoviesUseCase.execute(event.query);
        emit(MovieLoaded(movies));
      } catch (e) {
        emit(MovieError(e.toString()));
      }
    });

    // 4. ĐÃ SỬA: Lắng nghe sự kiện lấy rạp (Thay repository bằng UseCase)
    on<GetCinemasByBrandEvent>((event, emit) async {
      emit(CinemasLoading());
      try {
        // Dùng UseCase thay vì repository
        final cinemas = await getCinemasByBrandUseCase.execute(event.brand); 
        emit(CinemasLoaded(cinemas));
      } catch (e) {
        emit(CinemasError("Lỗi kết nối CSDL: ${e.toString()}"));
      }
    });
  }
}