import React, { useState, useEffect, useMemo, useRef } from 'react';
import axios from 'axios';
import {ChevronDown, X, Search, Plus, MonitorPlay, ArrowLeft, Filter, Edit, Trash2, Building2, Film, Clapperboard, CalendarClock, Tags, Map, Save, Paintbrush, Eraser, Star, Armchair, Eye, EyeOff, UploadCloud, Info, Users, PlayCircle, FileText} from 'lucide-react';

import Swal from 'sweetalert2';

// 🚀 ĐẶT ĐOẠN NÀY NGAY DƯỚI CÁC DÒNG IMPORT, TRÊN DÒNG "export default function Rooms() {"
const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
  didOpen: (toast) => {
    toast.addEventListener('mouseenter', Swal.stopTimer);
    toast.addEventListener('mouseleave', Swal.resumeTimer);
  }
});

// ==========================================
// INTERFACES
// ==========================================
interface Cinema { id: number; name: string; address?: string; brand_id?: number; city_id?: number; Latitude?: number | string; Longitude?: number | string; latitude?: number | string; longitude?: number | string; rating?: number | string; }
interface City { id: number; name: string; latitude: number; longitude: number; }
interface Movie { id: number; title: string; posterUrl?: string; poster_path?: string; backdrop_path?: string; backdropUrl?: string; genre?: string; genres?: string; duration: number; releaseDate?: string; release_date?: string; language?: string; age_rating?: string; vote_average?: number; overview?: string; IsDeleted?: number; TrailerURL?: string; trailerUrl?: string; trailer_url?: string; cast?: string; castJson?: string; }
interface SeatType { SeatTypeID: number; TypeName: string; WidthSlots: number; ColorCode: string; PriceSurCharge?: number; } // Thêm PriceSurCharge
interface TicketPrice { PriceID: number; CinemaID: number | null; CinemaName?: string; SeatTypeID: number; ShowType: string; DayType: string; Price: number; }
interface Seat { id: string; type: number; isSpace: boolean; }
interface Genre { GenreID: number; GenreName: string; }
interface Actor { ActorID: number; Name: string; Avatar?: string; }
interface LayoutRow { rowLetter: string; seats: Seat[]; centerZone?: any; }
interface Room { RoomID: number; CinemaID: number; CinemaName: string; Name: string; TotalSeats: number; BufferMinutes: number; LayoutData?: string | null; }

export default function Rooms() {
  const API_URL = 'http://192.168.1.7:3000/api/admin'; 
  const PUBLIC_API_URL = 'http://192.168.1.7:3000/api'; 

  const [activeTab, setActiveTab] = useState<'cinemas' | 'movies' | 'seattypes' | 'genres' | 'actors' | 'ticketprices'>('cinemas');

  

  // Thêm 4 dòng này xuống dưới cùng khu vực khai báo State:
  const [ticketPrices, setTicketPrices] = useState<TicketPrice[]>([]);
  const [isPriceModalOpen, setIsPriceModalOpen] = useState(false);
  const [editingPriceId, setEditingPriceId] = useState<number | null>(null);
  const [priceFormData, setPriceFormData] = useState({ CinemaID: '', SeatTypeID: 1, ShowType: '2D', DayType: 'Ngày thường', Price: 85000 });
  
  const [searchModalCinemaTerm, setSearchModalCinemaTerm] = useState('');
  const [showModalCinemaDropdown, setShowModalCinemaDropdown] = useState(false);
  const modalCinemaDropdownRef = useRef<HTMLDivElement>(null);

  const [searchFilterCinemaTerm, setSearchFilterCinemaTerm] = useState('');
  const [showFilterCinemaDropdown, setShowFilterCinemaDropdown] = useState(false);
  const filterCinemaDropdownRef = useRef<HTMLDivElement>(null);

  const [priceFilterCinema, setPriceFilterCinema] = useState<string>('ALL');
  const [priceFilterSeatType, setPriceFilterSeatType] = useState<string>('ALL');
  const [priceFilterShowType, setPriceFilterShowType] = useState<string>('ALL');
  const [currentPricePage, setCurrentPricePage] = useState(1);
  const PRICES_PER_PAGE = 15;
  

  const [loading, setLoading] = useState<boolean>(false);

  const [rooms, setRooms] = useState<Room[]>([]);
  const [cinemas, setCinemas] = useState<Cinema[]>([]);
  const [movies, setMovies] = useState<Movie[]>([]); 
  const [cities, setCities] = useState<City[]>([]); 
  const [seatTypes, setSeatTypes] = useState<SeatType[]>([]); 

  // STATES THỂ LOẠI & DIỄN VIÊN
  const [genresList, setGenresList] = useState<Genre[]>([]);
  const [actorsList, setActorsList] = useState<Actor[]>([]);

  const [viewingActor, setViewingActor] = useState<Actor | null>(null);
  
  const [isGenreModalOpen, setIsGenreModalOpen] = useState(false);
  const [editingGenreId, setEditingGenreId] = useState<number | null>(null);
  const [genreFormData, setGenreFormData] = useState({ GenreName: '' });

  const [isActorModalOpen, setIsActorModalOpen] = useState(false);
  const [editingActorId, setEditingActorId] = useState<number | null>(null);
  const [actorFormData, setActorFormData] = useState({ Name: '', Avatar: '' });

  const [actorListSearch, setActorListSearch] = useState(''); // Ô tìm kiếm diễn viên
  const [actorAvatarFile, setActorAvatarFile] = useState<File | null>(null); // Chứa file tải lên
  const [actorSortOrder, setActorSortOrder] = useState('ALL');

  // STATES TÌM KIẾM & LỌC
  const [showGrid, setShowGrid] = useState<boolean>(true);
  const [filterCinemaId, setFilterCinemaId] = useState<string>('');
  const [gridSearchQuery, setGridSearchQuery] = useState('');
  const [gridSelectedBrand, setGridSelectedBrand] = useState('');
  const [movieSearchQuery, setMovieSearchQuery] = useState('');
  const [movieFilterStatus, setMovieFilterStatus] = useState('ALL');

  const [currentMoviePage, setCurrentMoviePage] = useState(1);
  const [currentActorPage, setCurrentActorPage] = useState(1);
  const MOVIES_PER_PAGE = 20;
  const ACTORS_PER_PAGE = 24;

  // STATES MODAL RẠP & LOẠI GHẾ
  const [isCinemaModalOpen, setIsCinemaModalOpen] = useState(false);
  const [editingCinemaId, setEditingCinemaId] = useState<number | null>(null);
  const [cinemaFormData, setCinemaFormData] = useState({ name: '', address: '', brand_id: '1', city_id: '1', latitude: '', longitude: '', rating: '5.0' });

  const [isSeatTypeModalOpen, setIsSeatTypeModalOpen] = useState(false);
  const [editingSeatTypeId, setEditingSeatTypeId] = useState<number | null>(null);
  const [seatTypeFormData, setSeatTypeFormData] = useState({ TypeName: '', WidthSlots: 1, ColorCode: '#e9d5ff', PriceSurCharge: 0 });

  // STATES ROOMS LƯỚI VẼ
  const [isRoomEditorOpen, setIsRoomEditorOpen] = useState(false);
  const [editingRoomId, setEditingRoomId] = useState<number | null>(null);
  const [roomFormData, setRoomFormData] = useState({ cinemaId: '', name: '', bufferMinutes: 10 });
  const [editableLayout, setEditableLayout] = useState<LayoutRow[]>([]);
  const [activeBrush, setActiveBrush] = useState<number>(1); 
  const [isPainting, setIsPainting] = useState<boolean>(false); 
  // Thêm State quản lý Vùng Trung Tâm
  const [centerZone, setCenterZone] = useState({ startRow: 4, startCol: 5, rowCount: 4, colCount: 8 });

  // ==========================================
  // STATES QUẢN LÝ PHIM 
  // ==========================================
  const [viewingMovie, setViewingMovie] = useState<Movie | null>(null); 
  const [isMovieModalOpen, setIsMovieModalOpen] = useState(false);
  const [editingMovieId, setEditingMovieId] = useState<number | null>(null);
  const [movieFormData, setMovieFormData] = useState({ 
    title: '', poster_path: '', backdrop_path: '', genres: 'Hành Động', duration: 120, release_date: '', language: 'Tiếng Việt', age_rating: 'P', vote_average: 0, overview: '', TrailerURL: '', cast: ''
  });
  const [posterFile, setPosterFile] = useState<File | null>(null);
  const [backdropFiles, setBackdropFiles] = useState<File[]>([]);

  // Thêm 3 biến này để làm Thanh tìm kiếm diễn viên thông minh
  const [actorSearch, setActorSearch] = useState('');
  const [showActorDropdown, setShowActorDropdown] = useState(false);
  const [selectedActor, setSelectedActor] = useState<Actor | null>(null);
  // Thêm 2 biến này ngay dưới các biến actorSearch
  const [genreSearch, setGenreSearch] = useState('');
  const [showGenreDropdown, setShowGenreDropdown] = useState(false);
  const filteredModalCinemas = cinemas.filter(c => 
  c.name.toLowerCase().includes(searchModalCinemaTerm.toLowerCase().replace('chỉ áp dụng cho: ', ''))
  );
  const filteredFilterCinemas = cinemas.filter(c => 
    c.name.toLowerCase().includes(searchFilterCinemaTerm.toLowerCase().replace('rạp: ', ''))
  );

  // Tìm hàm useEffect() và thêm fetchTicketPrices() vào trong đó:
  useEffect(() => { 
    fetchRooms(); fetchCinemas(); fetchMovies(); fetchCities(); fetchSeatTypes(); fetchGenresList(); fetchActorsList(); fetchTicketPrices(); // <== Thêm vào đây
  }, []);

  // Hiệu ứng click ra ngoài để đóng dropdown bộ lọc
  useEffect(() => {
    const handleFilterClickOutside = (event: MouseEvent) => {
      if (filterCinemaDropdownRef.current && !filterCinemaDropdownRef.current.contains(event.target as Node)) {
        setShowFilterCinemaDropdown(false);
        // Phục hồi lại tên nếu chưa chọn gì mà bấm ra ngoài
        if (priceFilterCinema === 'ALL') {
           setSearchFilterCinemaTerm('');
        } else if (priceFilterCinema === 'GLOBAL') {
           setSearchFilterCinemaTerm('Chỉ xem Giá Toàn Hệ Thống');
        } else {
           const currentCin = cinemas.find(c => c.id.toString() === priceFilterCinema);
           if (currentCin) setSearchFilterCinemaTerm(`Rạp: ${currentCin.name}`);
        }
      }
    };
    document.addEventListener('mousedown', handleFilterClickOutside);
    return () => document.removeEventListener('mousedown', handleFilterClickOutside);
  }, [priceFilterCinema, cinemas]);

  useEffect(() => {
  const handleClickOutside = (event: MouseEvent) => {
    if (modalCinemaDropdownRef.current && !modalCinemaDropdownRef.current.contains(event.target as Node)) {
      setShowModalCinemaDropdown(false);
      // Phục hồi lại tên rạp nếu click ra ngoài mà chưa chọn
      if (priceFormData.CinemaID === '') {
         setSearchModalCinemaTerm('');
      } else {
         const currentCin = cinemas.find(c => c.id.toString() === priceFormData.CinemaID);
         if (currentCin) setSearchModalCinemaTerm(`Chỉ áp dụng cho: ${currentCin.name}`);
      }
    }
  };
  document.addEventListener('mousedown', handleClickOutside);
  return () => document.removeEventListener('mousedown', handleClickOutside);
}, [priceFormData.CinemaID, cinemas]);

  // Viết thêm hàm fetchTicketPrices xuống dưới:
  const fetchTicketPrices = async () => { try { const res = await axios.get(`${API_URL}/ticketprices`); setTicketPrices(res.data); } catch (e) {} };

  // Viết thêm 2 hàm Thêm/Sửa/Xóa Giá:
  // ==========================================
  // 🚀 HÀM LƯU BẢNG GIÁ VÉ (ĐÃ BỌC THÉP BẢO VỆ MẠNH MẼ)
  // ==========================================
  const handlePriceSubmit = async (e: React.FormEvent) => { 
    e.preventDefault(); 

    const priceValue = Number(priceFormData.Price);
    const cinemaIdValue = priceFormData.CinemaID === '' ? null : Number(priceFormData.CinemaID);
    const seatTypeIdValue = Number(priceFormData.SeatTypeID);

    // 1. Kiểm tra giá tiền hợp lệ (Phải lớn hơn 0 và hợp lý)
    if (isNaN(priceValue) || priceValue <= 0) {
      return Swal.fire('Cảnh báo', 'Giá vé phải lớn hơn 0 đồng!', 'warning');
    }
    if (priceValue < 1000) {
      return Swal.fire('Cảnh báo', 'Giá vé quá thấp! Vui lòng nhập đúng mệnh giá (Ví dụ: 85000 chứ không phải 85).', 'warning');
    }

    // 2. Chống trùng lặp bảng giá
    // (Cùng Rạp + Cùng Loại Ghế + Cùng Định Dạng + Cùng Loại Ngày)
    const isDuplicate = ticketPrices.some(p => 
      p.PriceID !== editingPriceId && // Loại trừ chính mức giá đang sửa
      p.CinemaID === cinemaIdValue &&
      p.SeatTypeID === seatTypeIdValue &&
      p.ShowType === priceFormData.ShowType &&
      p.DayType === priceFormData.DayType
    );

    if (isDuplicate) {
      const cinemaStr = cinemaIdValue ? 'chi nhánh rạp này' : 'Toàn hệ thống';
      return Swal.fire({
        title: 'Trùng lặp Bảng Giá!',
        text: `Cấu hình giá cho: Loại ghế này + Định dạng ${priceFormData.ShowType} + ${priceFormData.DayType} ĐÃ TỒN TẠI ở ${cinemaStr}. Vui lòng cập nhật giá cũ thay vì tạo mới!`,
        icon: 'warning',
        confirmButtonColor: '#4f46e5'
      });
    }

    // 3. Mọi thứ hoàn hảo -> Bắt đầu gửi API
    setLoading(true); 

    const payload = {
      ...priceFormData,
      CinemaID: cinemaIdValue,
      SeatTypeID: seatTypeIdValue,
      Price: priceValue
    };

    try { 
      if (editingPriceId) {
        await axios.put(`${API_URL}/ticketprices/${editingPriceId}`, payload); 
      } else {
        await axios.post(`${API_URL}/ticketprices`, payload); 
      }
      
      fetchTicketPrices(); 
      setIsPriceModalOpen(false); 
      Toast.fire({icon: 'success', title: 'Đã lưu giá vé thành công!'}); 

    } catch (error: any) { 
      console.error("Chi tiết lỗi Backend:", error.response?.data || error);
      Swal.fire({
        icon: 'error',
        title: 'Lỗi lưu giá vé!',
        text: error.response?.data?.error || error.response?.data?.message || 'Có lỗi xảy ra, vui lòng mở Console (F12) để xem chi tiết.',
      });
    } finally { 
      setLoading(false); 
    } 
  };

  const handleDeletePrice = async (id: number) => { 
    Swal.fire({ title: `Xóa mức giá này?`, icon: 'warning', showCancelButton: true, confirmButtonColor: '#ef4444', confirmButtonText: 'Đồng ý' }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.delete(`${API_URL}/ticketprices/${id}`); Toast.fire({icon: 'success', title: 'Đã xóa!'}); fetchTicketPrices(); } 
        catch (e) { Swal.fire('Lỗi', 'Không thể xóa!', 'error'); }
      }
    });
  };

  useEffect(() => { setCurrentMoviePage(1); }, [movieSearchQuery, movieFilterStatus]);
  useEffect(() => { setCurrentActorPage(1); }, [actorListSearch, actorSortOrder]);
  useEffect(() => { setCurrentPricePage(1); }, [priceFilterCinema, priceFilterSeatType, priceFilterShowType]);

  const fetchCities = async () => { try { const res = await axios.get(`${PUBLIC_API_URL}/cities`); setCities(res.data); } catch (e) {} };
  const fetchRooms = async () => { try { const res = await axios.get(`${API_URL}/rooms`); setRooms(res.data); } catch (e) {} };
  const fetchCinemas = async () => { try { const res = await axios.get(`${API_URL}/showtimes/init-data`); if (res.data?.cinemas) setCinemas(res.data.cinemas); } catch (e) {} };
  const fetchMovies = async () => { try { const res = await axios.get(`${API_URL}/movies`); setMovies(res.data); } catch (error) {} };
  const fetchSeatTypes = async () => { try { const res = await axios.get(`${API_URL}/seattypes`); setSeatTypes(res.data); } catch (e) {} };
  const fetchGenresList = async () => { try { const res = await axios.get(`${API_URL}/genres`); setGenresList(res.data); } catch (e) {} };
  const fetchActorsList = async () => { try { const res = await axios.get(`${API_URL}/actors`); setActorsList(res.data); } catch (e) {} };

  const openAddCinemaModal = () => { setEditingCinemaId(null); setCinemaFormData({ name: '', address: '', brand_id: '1', city_id: '1', latitude: '', longitude: '', rating: '5.0' }); setIsCinemaModalOpen(true); };
  const openEditCinemaModal = (cinema: Cinema, e: React.MouseEvent) => { e.stopPropagation(); setEditingCinemaId(cinema.id); const lat = cinema.Latitude?.toString() || cinema.latitude?.toString() || ''; const lng = cinema.Longitude?.toString() || cinema.longitude?.toString() || ''; setCinemaFormData({ name: cinema.name, address: cinema.address || '', brand_id: cinema.brand_id?.toString() || '1', city_id: cinema.city_id?.toString() || '1', latitude: lat, longitude: lng, rating: cinema.rating?.toString() || '5.0' }); setIsCinemaModalOpen(true); };
  // ==========================================
  // 🚀 HÀM LƯU RẠP CHIẾU (ĐÃ BỌC THÉP RÀNG BUỘC)
  // ==========================================
  const handleCinemaSubmit = async (e: React.FormEvent) => { 
    e.preventDefault(); 
    
    // 1. Dọn dẹp khoảng trắng
    const trimmedName = cinemaFormData.name.trim();
    const trimmedAddress = cinemaFormData.address.trim();
    const ratingValue = Number(cinemaFormData.rating);

    // 2. Chặn lỗi nhập liệu rỗng và giới hạn
    if (!trimmedName) return Swal.fire('Cảnh báo', 'Tên rạp không được để trống!', 'warning');
    if (!trimmedAddress) return Swal.fire('Cảnh báo', 'Địa chỉ rạp không được để trống!', 'warning');
    if (isNaN(ratingValue) || ratingValue < 0 || ratingValue > 5) {
       return Swal.fire('Cảnh báo', 'Điểm đánh giá (Rating) phải từ 0 đến 5 sao!', 'warning');
    }

    // 3. Chống trùng tên rạp trên toàn hệ thống (Bỏ qua rạp đang sửa)
    const isDuplicate = cinemas.some(
      (c) => c.name.toLowerCase() === trimmedName.toLowerCase() && c.id !== editingCinemaId
    );
    if (isDuplicate) {
      return Swal.fire({
        title: 'Trùng lặp dữ liệu!',
        text: `Rạp mang tên "${trimmedName}" đã tồn tại. Vui lòng đổi tên khác.`,
        icon: 'warning',
        confirmButtonColor: '#4f46e5'
      });
    }

    // 4. Hợp lệ -> Gửi API
    setLoading(true); 
    const payload = {
        ...cinemaFormData,
        name: trimmedName,
        address: trimmedAddress,
        rating: ratingValue
    };

    try { 
      if (editingCinemaId) { 
        await axios.put(`${API_URL}/cinemas/${editingCinemaId}`, payload); 
      } else { 
        await axios.post(`${API_URL}/cinemas`, payload); 
      } 
      fetchCinemas(); 
      setIsCinemaModalOpen(false); 
      Toast.fire({icon: 'success', title: 'Lưu rạp chiếu thành công!'});
    } catch (error: any) { 
      Swal.fire('Lỗi', error.response?.data?.error || 'Không thể lưu rạp lúc này!', 'error');
    } finally { 
      setLoading(false); 
    } 
  };
  const handleDeleteCinema = async (id: number, name: string, e: React.MouseEvent) => { 
    e.stopPropagation(); 
    Swal.fire({
      title: `Xóa rạp "${name}"?`, icon: 'warning', showCancelButton: true, confirmButtonColor: '#ef4444', confirmButtonText: 'Đồng ý', cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.delete(`${API_URL}/cinemas/${id}`); Toast.fire({icon: 'success', title: 'Đã xóa rạp!'}); fetchCinemas(); fetchRooms(); } 
        catch (e) { Swal.fire('Lỗi', 'Không thể xóa rạp này!', 'error'); }
      }
    });
  };
  
  // ✅ XỬ LÝ API QUẢN LÝ LOẠI GHẾ (Đã được khôi phục)
  // ==========================================
  // 🚀 HÀM LƯU LOẠI GHẾ (ĐÃ BỌC THÉP BẢO VỆ)
  // ==========================================
  const handleSeatTypeSubmit = async (e: React.FormEvent) => { 
    e.preventDefault(); 
    
    // 1. Dọn dẹp khoảng trắng
    const trimmedTypeName = seatTypeFormData.TypeName.trim();
    const widthSlots = Number(seatTypeFormData.WidthSlots);
    const priceSurCharge = Number(seatTypeFormData.PriceSurCharge) || 0;

    // 2. Chặn lỗi rỗng và sai định dạng số
    if (!trimmedTypeName) {
      return Swal.fire('Cảnh báo', 'Tên loại ghế không được để trống!', 'warning');
    }
    if (isNaN(widthSlots) || widthSlots < 1) {
      return Swal.fire('Cảnh báo', 'Độ rộng của ghế (số ô chiếm dụng) phải từ 1 trở lên!', 'warning');
    }
    if (isNaN(priceSurCharge) || priceSurCharge < 0) {
      return Swal.fire('Cảnh báo', 'Giá phụ thu không hợp lệ (phải >= 0)!', 'warning');
    }

    // 3. Chống trùng lặp tên loại ghế (Bỏ qua chính nó khi đang sửa)
    const isDuplicate = seatTypes.some(
      (st) => st.TypeName.toLowerCase() === trimmedTypeName.toLowerCase() && st.SeatTypeID !== editingSeatTypeId
    );

    if (isDuplicate) {
      return Swal.fire({
        title: 'Trùng lặp dữ liệu!',
        text: `Loại ghế "${trimmedTypeName}" đã tồn tại. Vui lòng đặt tên khác để không bị nhầm lẫn.`,
        icon: 'warning',
        confirmButtonColor: '#4f46e5'
      });
    }

    // 4. Mọi thứ hợp lệ -> Gửi API
    setLoading(true); 
    try { 
      // Đóng gói lại data đã được làm sạch
      const payload = {
        ...seatTypeFormData,
        TypeName: trimmedTypeName,
        WidthSlots: widthSlots,
        PriceSurCharge: priceSurCharge
      };

      if (editingSeatTypeId) { 
        await axios.put(`${API_URL}/seattypes/${editingSeatTypeId}`, payload); 
      } else { 
        await axios.post(`${API_URL}/seattypes`, payload); 
      } 
      
      fetchSeatTypes(); 
      setIsSeatTypeModalOpen(false); 
      Toast.fire({icon: 'success', title: 'Lưu loại ghế thành công!'}); 
      
    } catch (error: any) { 
      Swal.fire('Lỗi', error.response?.data?.error || 'Không thể lưu loại ghế lúc này!', 'error'); 
    } finally { 
      setLoading(false); 
    } 
  };
  const handleDeleteSeatType = async (id: number, name: string) => { 
    Swal.fire({
      title: `Xóa loại ghế "${name}"?`, icon: 'warning', showCancelButton: true, confirmButtonColor: '#ef4444', confirmButtonText: 'Đồng ý', cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.delete(`${API_URL}/seattypes/${id}`); Toast.fire({icon: 'success', title: 'Đã xóa loại ghế!'}); fetchSeatTypes(); } 
        catch (e) { Swal.fire('Lỗi', 'Không thể xóa!', 'error'); }
      }
    });
  };

  // ==========================================
  // 🚀 HÀM LƯU THỂ LOẠI (ĐÃ BỌC THÉP BẢO VỆ)
  // ==========================================
  const handleGenreSubmit = async (e: React.FormEvent) => { 
    e.preventDefault(); 
    
    // 1. Dọn dẹp khoảng trắng dư thừa
    const trimmedName = genreFormData.GenreName.trim();
    
    // 2. Chặn lỗi gõ toàn dấu cách
    if (!trimmedName) {
      return Swal.fire('Cảnh báo', 'Tên thể loại không được để trống!', 'warning');
    }

    // 3. Thuật toán chặn trùng tên (Loại trừ chính thể loại đang sửa)
    const isDuplicate = genresList.some(
      (g) => g.GenreName.toLowerCase() === trimmedName.toLowerCase() && g.GenreID !== editingGenreId
    );

    if (isDuplicate) {
      return Swal.fire({
        title: 'Trùng lặp dữ liệu!',
        text: `Thể loại "${trimmedName}" đã có sẵn trong hệ thống.`,
        icon: 'warning',
        confirmButtonColor: '#4f46e5'
      });
    }

    // 4. Hợp lệ -> Cho phép gửi API
    setLoading(true); 
    try { 
      const payload = { GenreName: trimmedName }; // Gửi tên đã dọn dẹp sạch sẽ

      if (editingGenreId) { 
        await axios.put(`${API_URL}/genres/${editingGenreId}`, payload); 
      } else { 
        await axios.post(`${API_URL}/genres`, payload); 
      } 
      
      fetchGenresList(); 
      setIsGenreModalOpen(false); 
      Toast.fire({icon: 'success', title: 'Lưu thể loại thành công!'}); 
      
    } catch (e: any) { 
      Swal.fire('Lỗi', e.response?.data?.error || 'Lỗi hệ thống khi lưu thể loại!', 'error'); 
    } finally { 
      setLoading(false); 
    } 
  };

  const handleDeleteGenre = async (id: number, name: string) => { 
    Swal.fire({ title: `Xóa thể loại "${name}"?`, icon: 'warning', showCancelButton: true, confirmButtonColor: '#ef4444', confirmButtonText: 'Xóa'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.delete(`${API_URL}/genres/${id}`); Toast.fire({icon: 'success', title: 'Đã xóa!'}); fetchGenresList(); } 
        catch (e) { Swal.fire('Không thể xóa', 'Đang có phim dùng thể loại này!', 'error'); }
      }
    });
  };

  // ==========================================
  // 🚀 HÀM LƯU DIỄN VIÊN (ĐÃ BỌC THÉP BẢO VỆ)
  // ==========================================
  const handleActorSubmit = async (e: React.FormEvent) => { 
    e.preventDefault(); 
    
    // 1. Dọn dẹp khoảng trắng dư thừa ở hai đầu
    const trimmedName = actorFormData.Name.trim();
    
    // 2. Chặn lỗi gõ toàn dấu cách (Space)
    if (!trimmedName) {
      return Swal.fire('Cảnh báo', 'Tên diễn viên không được để trống!', 'warning');
    }

    // 3. Thuật toán chặn trùng tên (Loại trừ chính người đang sửa)
    const isDuplicate = actorsList.some(
      (a) => a.Name.toLowerCase() === trimmedName.toLowerCase() && a.ActorID !== editingActorId
    );

    if (isDuplicate) {
      return Swal.fire({
        title: 'Trùng lặp dữ liệu!',
        text: `Diễn viên "${trimmedName}" đã có sẵn trong kho. Bạn không thể thêm trùng tên.`,
        icon: 'warning',
        confirmButtonColor: '#4f46e5'
      });
    }

    // 4. Mọi thứ hợp lệ -> Cho phép gửi API
    setLoading(true); 
    const formData = new FormData();
    formData.append('Name', trimmedName); // Lưu tên đã dọn dẹp cho sạch sẽ
    formData.append('Avatar', actorFormData.Avatar.trim());
    if (actorAvatarFile) formData.append('avatar_file', actorAvatarFile);

    try { 
      if (editingActorId) {
        await axios.put(`${API_URL}/actors/${editingActorId}`, formData, { headers: { 'Content-Type': 'multipart/form-data' } }); 
      } else {
        await axios.post(`${API_URL}/actors`, formData, { headers: { 'Content-Type': 'multipart/form-data' } }); 
      }
      
      fetchActorsList(); 
      setIsActorModalOpen(false); 
      Toast.fire({icon: 'success', title: 'Lưu diễn viên thành công!'}); 
      
    } catch (e: any) { 
      Swal.fire('Lỗi', e.response?.data?.error || 'Lỗi hệ thống khi lưu diễn viên!', 'error');
    } finally { 
      setLoading(false); 
    } 
  };

  const handleDeleteActor = async (id: number, name: string) => { 
    Swal.fire({ title: `Xóa diễn viên "${name}"?`, icon: 'warning', showCancelButton: true, confirmButtonColor: '#ef4444', confirmButtonText: 'Xóa'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.delete(`${API_URL}/actors/${id}`); Toast.fire({icon: 'success', title: 'Đã xóa!'}); fetchActorsList(); } 
        catch (e) { Swal.fire('Không thể xóa', 'Đang có phim dùng diễn viên này!', 'error'); }
      }
    });
  };
  // ==========================================
  // XỬ LÝ SỰ KIỆN API PHIM
  // ==========================================
  const openAddMovieModal = () => {
    setEditingMovieId(null);
    setPosterFile(null);
    setBackdropFiles([]);
    setMovieFormData({ title: '', poster_path: '', backdrop_path: '', genres: 'Hành Động', duration: 120, release_date: '', language: 'Tiếng Việt', age_rating: 'P', vote_average: 0, overview: '', TrailerURL: '', cast: '' });
    setIsMovieModalOpen(true);
  };

  const openEditMovieModal = (movie: Movie) => {
    setEditingMovieId(movie.id);
    setPosterFile(null);
    setBackdropFiles([]);
    const rDate = movie.releaseDate || movie.release_date || '';
    let formattedDate = '';
    if (rDate) {
      const d = new Date(rDate);
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, '0');
      const day = String(d.getDate()).padStart(2, '0');
      formattedDate = `${year}-${month}-${day}`;
    }    
    const tUrl = movie.TrailerURL || movie.trailerUrl || movie.trailer_url || '';
    const castData = movie.cast || movie.castJson || '';
    
    let backPath = movie.backdrop_path || movie.backdropUrl || '';
    if (backPath === 'null' || backPath === 'undefined') backPath = '';
    
    // ✅ HIỂN THỊ NHIỀU ẢNH: Biến mảng JSON thành chuỗi cách nhau bằng dấu phẩy
    if (backPath.startsWith('[')) {
      try {
        const arr = JSON.parse(backPath);
        backPath = arr.join(', '); // Nối các link lại: link1, link2, link3...
      } catch(e) {
        backPath = backPath.replace(/[\[\]"]/g, ''); 
      }
    }
    
    let postPath = movie.poster_path || movie.posterUrl || '';
    if (postPath === 'null' || postPath === 'undefined') postPath = '';

    setMovieFormData({ 
      title: movie.title, 
      poster_path: postPath, 
      backdrop_path: backPath,
      genres: movie.genres || movie.genre || 'Hành Động', 
      duration: movie.duration, 
      release_date: formattedDate, 
      language: movie.language || 'Tiếng Việt', 
      age_rating: movie.age_rating || 'P', 
      vote_average: movie.vote_average || 0, 
      overview: movie.overview || '',
      TrailerURL: tUrl,
      cast: castData
    });
    setIsMovieModalOpen(true);
  };

  // ==========================================
  // 🚀 HÀM LƯU PHIM (ĐÃ BỌC THÉP BẢO VỆ 5 LỚP)
  // ==========================================
  const handleMovieSubmit = async (e: React.FormEvent) => { 
    e.preventDefault(); 
    
    // 1. Dọn dẹp dữ liệu
    const trimmedTitle = movieFormData.title.trim();
    const duration = Number(movieFormData.duration);
    
    // 2. Ràng buộc các trường bắt buộc không được rỗng
    if (!trimmedTitle) {
      return Swal.fire('Cảnh báo', 'Tên phim không được để trống!', 'warning');
    }
    if (duration <= 0 || isNaN(duration)) {
      return Swal.fire('Cảnh báo', 'Thời lượng phim phải lớn hơn 0 phút!', 'warning');
    }
    if (!movieFormData.release_date) {
      return Swal.fire('Cảnh báo', 'Vui lòng chọn ngày khởi chiếu cho phim!', 'warning');
    }
    if (!movieFormData.genres || movieFormData.genres.trim() === '') {
      return Swal.fire('Cảnh báo', 'Vui lòng chọn ít nhất 1 thể loại!', 'warning');
    }

    // 3. Chống trùng lặp tên phim (Trừ chính phim đang sửa)
    const isDuplicate = movies.some(
      (m) => m.title.toLowerCase() === trimmedTitle.toLowerCase() && m.id !== editingMovieId
    );

    if (isDuplicate) {
      return Swal.fire({
        title: 'Trùng lặp dữ liệu!',
        text: `Bộ phim "${trimmedTitle}" đã tồn tại trong kho dữ liệu.`,
        icon: 'warning',
        confirmButtonColor: '#4f46e5'
      });
    }

    // 4. Hợp lệ -> Bắt đầu đóng gói và gửi API
    setLoading(true); 

    const formData = new FormData();
    formData.append('title', trimmedTitle); // Gửi tên đã dọn dẹp
    formData.append('genres', movieFormData.genres);
    formData.append('duration', duration.toString());
    formData.append('release_date', movieFormData.release_date);
    formData.append('language', movieFormData.language);
    formData.append('age_rating', movieFormData.age_rating);
    formData.append('vote_average', movieFormData.vote_average.toString());
    formData.append('overview', movieFormData.overview);
    formData.append('poster_path', movieFormData.poster_path);
    
    // XỬ LÝ NHIỀU ẢNH BACKDROP
    let finalBackdropStr = movieFormData.backdrop_path;
    if (finalBackdropStr.includes(',')) {
        const arr = finalBackdropStr.split(',').map(s => s.trim()).filter(s => s !== '');
        finalBackdropStr = JSON.stringify(arr);
    }
    formData.append('backdrop_path', finalBackdropStr);
    formData.append('TrailerURL', movieFormData.TrailerURL);
    formData.append('cast', movieFormData.cast);
    
    if (posterFile) formData.append('poster_file', posterFile);
    if (backdropFiles.length > 0) {
      backdropFiles.forEach(file => {
        formData.append('backdrop_file', file);
      });
    }

    try { 
      if (editingMovieId) { 
        await axios.put(`${API_URL}/movies/${editingMovieId}`, formData, { headers: { 'Content-Type': 'multipart/form-data' } }); 
        
        // Cập nhật lại giao diện ngay lập tức nếu đang xem chi tiết phim
        if (viewingMovie) {
          const res = await axios.get(`${API_URL}/movies`); 
          setMovies(res.data);
          const updatedMovie = res.data.find((m: Movie) => m.id === editingMovieId);
          if (updatedMovie) setViewingMovie(updatedMovie);
        }
      } else { 
        await axios.post(`${API_URL}/movies`, formData, { headers: { 'Content-Type': 'multipart/form-data' } }); 
      } 
      
      if (!viewingMovie) fetchMovies(); 
      setIsMovieModalOpen(false); 
      Toast.fire({icon: 'success', title: 'Lưu phim thành công!'}); 
      
    } catch (e: any) { 
      Swal.fire('Lỗi', e.response?.data?.error || 'Có lỗi xảy ra, vui lòng thử lại!', 'error'); 
    } finally { 
      setLoading(false); 
    }
  };

  const handleDeleteMovie = async (id: number, title: string) => { 
    Swal.fire({ title: `Xóa vĩnh viễn phim "${title}"?`, icon: 'error', showCancelButton: true, confirmButtonColor: '#ef4444', confirmButtonText: 'Xóa Vĩnh Viễn'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.delete(`${API_URL}/movies/${id}`); if (viewingMovie?.id === id) setViewingMovie(null); fetchMovies(); Toast.fire({icon: 'success', title: 'Đã xóa phim!'}); } 
        catch (e) { Swal.fire('Lỗi', 'Không thể xóa phim này!', 'error'); }
      }
    });
  };

  const handleToggleMovieStatus = async (id: number, isDeleted: number | undefined, title: string) => {
    const action = isDeleted === 0 ? 'ẨN' : 'HIỆN'; 
    Swal.fire({ title: `Xác nhận ${action} phim "${title}"?`, icon: 'question', showCancelButton: true, confirmButtonColor: '#3b82f6', confirmButtonText: 'Xác nhận'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.put(`${API_URL}/movies/${id}/toggle-status`); fetchMovies(); Toast.fire({icon: 'success', title: `Đã ${action} phim!`}); } 
        catch (error) { Swal.fire('Lỗi', 'Thay đổi trạng thái thất bại!', 'error'); }
      }
    });
  };

  // ==========================================
  // THUẬT TOÁN ĐÁNH SỐ VÀ VẼ SƠ ĐỒ LƯỚI
  // ==========================================
  const recalculateSeatNumbers = (layout: LayoutRow[]) => {
    const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    return layout.map((row, rIndex) => {
      let seatCount = 1;
      const newSeats = row.seats.map((seat, cIndex) => {
        if (seat.type !== 0 && seat.type !== -1) { return { ...seat, id: `${letters[rIndex]}${seatCount++}`, isSpace: false }; } 
        else { return { ...seat, id: `space_${rIndex}_${cIndex}`, isSpace: true }; }
      });
      return { rowLetter: letters[rIndex], seats: newSeats };
    });
  };

  const generateBlankGrid = (rows = 14, cols = 18): LayoutRow[] => {
    const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    return Array.from({ length: rows }).map((_, r) => ({ rowLetter: letters[r], seats: Array.from({ length: cols }).map((_, c) => ({ id: `space_${r}_${c}`, type: 0, isSpace: true })) }));
  };

 const openRoomEditor = (room?: Room) => {
    setActiveBrush(1);
    if (room) {
      setEditingRoomId(room.RoomID); 
      setRoomFormData({ cinemaId: room.CinemaID.toString(), name: room.Name, bufferMinutes: room.BufferMinutes });
      
      if (room.LayoutData) { 
        try { 
          const parsed = JSON.parse(room.LayoutData);
          
          const MIN_ROWS = 14;
          const MIN_COLS = 18;
          const letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
          
          // 1. Bơm thêm cột (Làm rộng ra)
          let currentMaxCols = 0;
          parsed.forEach((row: any) => {
             if (row.seats.length > currentMaxCols) currentMaxCols = row.seats.length;
          });

          // Nếu số cột hiện tại bé hơn MIN_COLS (18), ta phải bù thêm vào cả bên trái lẫn bên phải để cân bằng
          let addedLeft = 0;
          if (currentMaxCols < MIN_COLS) {
              const diff = MIN_COLS - currentMaxCols;
              addedLeft = Math.floor(diff / 2); // Thêm một nửa số cột vào bên trái
              const addedRight = diff - addedLeft; // Phần còn lại thêm vào bên phải

              parsed.forEach((row: any, rIdx: number) => {
                  // Thêm ghế trống bên trái
                  const leftSeats = Array.from({ length: addedLeft }).map((_, c) => ({
                      id: `space_${rIdx}_left_${c}`, type: 0, isSpace: true
                  }));
                  // Thêm ghế trống bên phải
                  const rightSeats = Array.from({ length: addedRight }).map((_, c) => ({
                      id: `space_${rIdx}_right_${c}`, type: 0, isSpace: true
                  }));
                  
                  row.seats = [...leftSeats, ...row.seats, ...rightSeats];
              });
          }

          // 2. Bơm thêm dòng (Làm cao lên) - Thêm xuống dưới đáy
          const currentRows = parsed.length;
          if (currentRows < MIN_ROWS) {
            for (let r = currentRows; r < MIN_ROWS; r++) {
              const newRowSeats = Array.from({ length: Math.max(MIN_COLS, parsed[0]?.seats.length || MIN_COLS) }).map((_, c) => ({
                id: `space_${r}_${c}`, type: 0, isSpace: true
              }));
              parsed.push({ rowLetter: letters[r], seats: newRowSeats });
            }
          }

          setEditableLayout(parsed); 
          
          // 3. Cập nhật lại tọa độ Khung Trung Tâm (Center Zone)
          if (parsed[0] && parsed[0].centerZone) {
              const oldZone = parsed[0].centerZone;
              // Phải đẩy tọa độ cột (Col) sang phải một khoảng bằng số cột vừa thêm vào bên trái
              setCenterZone({ 
                startRow: oldZone.startRow, 
                startCol: oldZone.startCol + addedLeft, // 🚀 CHÍNH LÀ CHỖ NÀY
                rowCount: oldZone.rowCount, 
                colCount: oldZone.colCount 
              });
          } else {
              setCenterZone({ startRow: 4, startCol: 5, rowCount: 4, colCount: 8 });
          }
        } catch (e) { 
          setEditableLayout(generateBlankGrid()); 
          setCenterZone({ startRow: 4, startCol: 5, rowCount: 4, colCount: 8 });
        } 
      } else { 
        setEditableLayout(generateBlankGrid()); 
        setCenterZone({ startRow: 4, startCol: 5, rowCount: 4, colCount: 8 });
      }
    } else {
      setEditingRoomId(null); 
      setRoomFormData({ cinemaId: filterCinemaId || '', name: '', bufferMinutes: 10 }); 
      setEditableLayout(generateBlankGrid());
      setCenterZone({ startRow: 4, startCol: 5, rowCount: 4, colCount: 8 });
    }
    setIsRoomEditorOpen(true);
  };

  const applyBrushToSeat = (rowIndex: number, seatIndex: number) => {
    const newLayout = [...editableLayout];
    const row = [...newLayout[rowIndex].seats];
    let c = seatIndex;
    if (row[c].type === activeBrush) return;

    // ✅ FIX TÀNG HÌNH GHẾ: Nếu ko có ID trên DB thì mặc định chiếm 1 ô
    const currentBrush = seatTypes.find(t => t.SeatTypeID === activeBrush);
    const slotsNeeded = currentBrush ? currentBrush.WidthSlots : (activeBrush === 3 ? 2 : 1);

    const clearSlot = (idx: number) => {
       if (idx < 0 || idx >= row.length) return;
       if (row[idx].type === -1) {
           let left = idx - 1;
           while(left >= 0 && row[left].type === -1) left--;
           if (left >= 0 && row[left].type !== 0) { row[left].type = 0; row[left].isSpace = true; }
       } else if (row[idx].type !== 0) {
           let right = idx + 1;
           while(right < row.length && row[right].type === -1) {
               row[right].type = 0; row[right].isSpace = true; right++;
           }
       }
       row[idx].type = 0; row[idx].isSpace = true; 
    };

    if (activeBrush === 0) {
        clearSlot(c);
    } else {
        if (c + slotsNeeded - 1 >= row.length) return; 
        for (let i = 0; i < slotsNeeded; i++) clearSlot(c + i);
        row[c].type = activeBrush;
        row[c].isSpace = false;
        for (let i = 1; i < slotsNeeded; i++) {
            row[c+i].type = -1;
            row[c+i].isSpace = true;
        }
    }
    newLayout[rowIndex].seats = row;
    setEditableLayout(recalculateSeatNumbers(newLayout));
  };

  // ✅ FIX LỖI ĐẾM SỨC CHỨA = 0: 
  // Nếu ID ghế cũ trên JSON (vd: 1) bị mất trong bảng seattypes, nó vẫn tự tính là 1 ghế để ko hiển thị 0.
  const dynamicTotalSeats = useMemo(() => {
    return editableLayout.reduce((total, row) => total + row.seats.reduce((rTotal, seat) => {
        if (seat.type === 0 || seat.type === -1) return rTotal;
        const st = seatTypes.find(s => s.SeatTypeID === seat.type);
        const slots = st ? st.WidthSlots : (seat.type === 3 ? 2 : 1); 
        return rTotal + slots; 
      }, 0), 0);
  }, [editableLayout, seatTypes]);

  // ==========================================
  // 🚀 HÀM LƯU PHÒNG & SƠ ĐỒ (ĐÃ BỌC THÉP VÀ GẮN NGHE LÉN)
  // ==========================================
  const handleSaveRoomAndLayout = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // 1. Dọn dẹp dữ liệu cơ bản
    const trimmedName = roomFormData.name.trim();
    const bufferTime = Number(roomFormData.bufferMinutes);

    // 2. Chặn lỗi nhập liệu
    if (!roomFormData.cinemaId) return Swal.fire('Cảnh báo', 'Vui lòng chọn Rạp áp dụng!', 'warning');
    if (!trimmedName) return Swal.fire('Cảnh báo', 'Tên phòng không được để trống!', 'warning');
    if (isNaN(bufferTime) || bufferTime < 0) return Swal.fire('Cảnh báo', 'Thời gian dọn rạp phải lớn hơn hoặc bằng 0 phút!', 'warning');
    
    // 3. Ràng buộc Vẽ Ghế
    if (dynamicTotalSeats <= 0) {
        return Swal.fire({
            title: 'Sơ đồ trống!',
            text: 'Phòng chiếu phải có ít nhất 1 ghế. Vui lòng cầm cọ vẽ ghế lên sơ đồ trước khi lưu.',
            icon: 'warning',
            confirmButtonColor: '#4f46e5'
        });
    }

    // 4. Chống trùng lặp TÊN PHÒNG
    const isDuplicate = rooms.some(r => 
       r.CinemaID.toString() === roomFormData.cinemaId &&
       r.Name.toLowerCase() === trimmedName.toLowerCase() && 
       r.RoomID !== editingRoomId
    );

    if (isDuplicate) {
        return Swal.fire('Trùng lặp Tên Phòng!', `Phòng "${trimmedName}" đã tồn tại trong Rạp này.`, 'warning');
    }

    // 5. Hợp lệ -> Tiến hành lưu
    setLoading(true);
    try {
      // 🚀 BỌC THÉP: Nhét tọa độ Khung Trung Tâm (centerZone) vào dòng đầu tiên của layout trước khi ép sang JSON
      const layoutToSave = [...editableLayout];
      if (layoutToSave.length > 0) {
          layoutToSave[0] = { ...layoutToSave[0], centerZone: centerZone };
      }
      
      const layoutJsonString = JSON.stringify(layoutToSave);
      let targetRoomId = editingRoomId;
      
      const payloadInfo = { 
          cinemaId: roomFormData.cinemaId, 
          name: trimmedName, 
          bufferMinutes: bufferTime,
          totalSeats: dynamicTotalSeats 
      };

      if (!editingRoomId) {
        // Tạo phòng mới
        const res = await axios.post(`${API_URL}/rooms`, payloadInfo);
        targetRoomId = res.data.insertId; 
      } else {
        // Sửa tên phòng cũ trước
        await axios.put(`${API_URL}/rooms/${editingRoomId}`, payloadInfo);
      }

      // Cuối cùng: Cập nhật sơ đồ JSON vào phòng đó
      await axios.put(`${API_URL}/rooms/${targetRoomId}/layout`, { layoutData: layoutJsonString });
      
      Swal.fire('Thành công!', `Đã lưu phòng "${trimmedName}" với sức chứa ${dynamicTotalSeats} ghế!`, 'success');
      fetchRooms(); 
      setIsRoomEditorOpen(false); 
    } catch (e: any) { 
      // =======================================================
      // 🕵️ MÁY NGHE LÉN: BẮT VÀ IN LỖI CHI TIẾT RA MÀN HÌNH
      // =======================================================
      console.error("============= 🚨 LỖI LƯU SƠ ĐỒ ĐÃ BỊ BẮT =============");
      console.error("1. Mã lỗi (Status):", e.response?.status);
      console.error("2. Dữ liệu lỗi (Data):", e.response?.data);
      console.error("3. Thông báo lỗi thô (Message):", e.message);
      console.error("=========================================================");

      // Bóc tách nội dung lỗi để hiện Popup
      let errorMessage = "Không thể kết nối đến máy chủ. Vui lòng thử lại!";
      if (e.response?.data?.error) {
        errorMessage = e.response.data.error;
      } else if (typeof e.response?.data === 'string') {
        errorMessage = e.response.data; // Bắt luôn trường hợp nó quăng mã HTML hoặc Text thô
      } else if (e.message) {
        errorMessage = e.message;
      }

      Swal.fire({
        title: 'Lỗi Backend Trả Về!',
        text: errorMessage,
        icon: 'error',
        confirmButtonColor: '#ef4444'
      });
    } finally { 
      setLoading(false); 
    }
  };
  const handleDeleteRoom = async (id: number, name: string) => { 
    Swal.fire({
      title: `Xóa phòng "${name}"?`, icon: 'warning', showCancelButton: true, confirmButtonColor: '#ef4444', confirmButtonText: 'Đồng ý', cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try { await axios.delete(`${API_URL}/rooms/${id}`); Toast.fire({icon: 'success', title: 'Đã xóa phòng!'}); fetchRooms(); } 
        catch (e) { Swal.fire('Lỗi', 'Không thể xóa!', 'error'); }
      }
    });
  };

  // ✅ ĐÃ SỬA: KHÓA CỐ ĐỊNH KÍCH THƯỚC GHẾ ĐỂ KHUNG TRUNG TÂM LUÔN CHUẨN XÁC
  const getDynamicSeatStyles = (type: number) => {
    if (type === 0) return { className: 'w-8 h-8 border border-dashed border-slate-600 bg-slate-800/40 text-slate-500 opacity-30 hover:opacity-100 hover:bg-slate-700/50 cursor-pointer', style: {} };
    
    const st = seatTypes.find(s => s.SeatTypeID === type);
    const safeColor = st ? st.ColorCode : (type === 2 ? '#fda4af' : type === 3 ? '#d946ef' : '#e9d5ff');
    const safeWidth = st ? st.WidthSlots : (type === 3 ? 2 : 1);

    let baseClass = 'h-8 text-slate-900 font-bold shadow-sm hover:-translate-y-1 hover:brightness-110 border-[1.5px] border-black/20 flex items-center justify-center text-[11px] rounded-t-md border-b-[3px] transition-colors duration-100 cursor-pointer';
    
    if (safeWidth === 1) baseClass += ' w-8';
    else if (safeWidth === 2) baseClass += ' w-[70px]';
    else if (safeWidth === 3) baseClass += ' w-[108px]';
    else baseClass += ' w-8';

    return { className: baseClass, style: { backgroundColor: safeColor, borderBottomColor: 'rgba(0,0,0,0.3)' } };
  };
  const getImageUrl = (path: string | undefined, isBackdrop: boolean = false) => {
    if (!path || path === 'null' || path === 'undefined' || path.trim() === '') {
      return isBackdrop 
        ? 'https://via.placeholder.com/1280x720?text=Chua+Co+Anh+Nen' 
        : 'https://via.placeholder.com/300x450?text=Chua+Co+Poster';
    }
    
    let cleanPath = path.trim();
    
    // ✅ SỬA LỖI: Bóc tách nếu TMDB trả về mảng JSON (VD: '["/abc.jpg"]')
    if (cleanPath.startsWith('[')) {
      try {
        const arr = JSON.parse(cleanPath);
        cleanPath = arr.length > 0 ? arr[0] : '';
      } catch(e) {
        cleanPath = cleanPath.replace(/[\[\]"]/g, ''); // Xóa sạch dấu ngoặc
      }
    }

    // Nếu bóc tách xong mà rỗng thì trả về ảnh Placeholder
    if (!cleanPath) {
      return isBackdrop 
        ? 'https://via.placeholder.com/1280x720?text=Chua+Co+Anh+Nen' 
        : 'https://via.placeholder.com/300x450?text=Chua+Co+Poster';
    }

    if (cleanPath.startsWith('http')) return cleanPath; 
    if (cleanPath.startsWith('/uploads')) return `http://192.168.1.7:3000${cleanPath}`; 
    
    const tmdbPath = cleanPath.startsWith('/') ? cleanPath : `/${cleanPath}`;
    return isBackdrop ? `https://image.tmdb.org/t/p/w1280${tmdbPath}` : `https://image.tmdb.org/t/p/w500${tmdbPath}`; 
  };

  const getEmbedUrl = (url: string | undefined) => {
    if (!url) return '';
    if (url.includes('watch?v=')) return url.replace('watch?v=', 'embed/').split('&')[0];
    if (url.includes('youtu.be/')) return url.replace('youtu.be/', 'www.youtube.com/embed/').split('?')[0];
    return url;
  };

  // ==========================================
  // THUẬT TOÁN LỌC DỮ LIỆU
  // ==========================================
  const filteredRooms = rooms.filter(room => filterCinemaId === '' ? true : room.CinemaID.toString() === filterCinemaId);
  const filteredCinemasGrid = cinemas.filter(cinema => {
    if (gridSelectedBrand && cinema.brand_id?.toString() !== gridSelectedBrand) return false;
    if (gridSearchQuery && !cinema.name.toLowerCase().includes(gridSearchQuery.toLowerCase())) return false; 
    return true;
  });
  
  const filteredMovies = movies.filter(movie => {
    const matchesSearch = movie.title.toLowerCase().includes(movieSearchQuery.toLowerCase());
    const todayStr = new Date().toISOString().split('T')[0];
    const rDate = movie.releaseDate || movie.release_date || '';
    const movieDateStr = rDate ? rDate.split('T')[0] : '';
    const lang = movie.language?.toLowerCase() || '';

    let matchesFilter = true;
    if (movieFilterStatus === 'NOW_PLAYING') {
      matchesFilter = movie.IsDeleted === 0 && movieDateStr !== '' && movieDateStr <= todayStr;
    } else if (movieFilterStatus === 'UPCOMING') {
      matchesFilter = movie.IsDeleted === 0 && movieDateStr !== '' && movieDateStr > todayStr;
    } else if (movieFilterStatus === 'VIETNAMESE') {
      matchesFilter = movie.IsDeleted === 0 && (lang.includes('việt') || lang.includes('viet') || lang === 'vn');
    } else if (movieFilterStatus === 'HIDDEN') {
      matchesFilter = movie.IsDeleted === 1;
    }

    return matchesSearch && matchesFilter;
  });

  const getBrandInfo = (cinemaName: string) => {
    const name = cinemaName.toLowerCase();
    if (name.includes('cgv')) return { logo: '/assets/cgv1.png', color: 'bg-red-600', letter: 'C' };
    if (name.includes('lotte')) return { logo: '/assets/lotte.png', color: 'bg-rose-600', letter: 'L' };
    if (name.includes('galaxy')) return { logo: '/assets/galaxy.png', color: 'bg-orange-500', letter: 'G' };
    if (name.includes('bhd')) return { logo: '/assets/bhd.png', color: 'bg-green-600', letter: 'B' };
    if (name.includes('cinestar')) return { logo: '/assets/cinestar.png', color: 'bg-fuchsia-600', letter: 'C' };
    if (name.includes('mega gs') || name.includes('megags')) return { logo: '/assets/megags.png', color: 'bg-blue-600', letter: 'M' };
    if (name.includes('dcine')) return { logo: '/assets/dcine.png', color: 'bg-blue-800', letter: 'D' };
    if (name.includes('aeon beta') || name.includes('aeonbeta')) return { logo: '/assets/aeonbeta.png', color: 'bg-teal-500', letter: 'A' };
    if (name.includes('beta')) return { logo: '/assets/betacinema.png', color: 'bg-sky-500', letter: 'B' };
    return { logo: '/assets/dexuat.png', color: 'bg-slate-700', letter: 'R' };
  };
  // ==========================================
  // THUẬT TOÁN PHÂN TRANG CHO PHIM (20 Phim/Trang)
  // ==========================================
  const totalMoviePages = Math.ceil(filteredMovies.length / MOVIES_PER_PAGE);
  const currentMoviesSlice = filteredMovies.slice(
    (currentMoviePage - 1) * MOVIES_PER_PAGE, 
    currentMoviePage * MOVIES_PER_PAGE
  );

  // ==========================================
  // 🚀 THUẬT TOÁN PHÂN TRANG & SẮP XẾP CHO DIỄN VIÊN
  // ==========================================
  let processedActorsList = actorsList.map(actor => {
    // Đếm số phim diễn viên này tham gia trước khi đem đi lọc
    const joinedMoviesCount = movies.filter(m => (m.cast || m.castJson || '').includes(actor.Name)).length;
    return { ...actor, movieCount: joinedMoviesCount };
  });

  // Lọc theo tên tìm kiếm
  processedActorsList = processedActorsList.filter(a => a.Name.toLowerCase().includes(actorListSearch.toLowerCase()));

  // Sắp xếp theo bộ lọc
  if (actorSortOrder === 'MOST_MOVIES') {
    processedActorsList.sort((a, b) => b.movieCount - a.movieCount); // Nhiều phim nhất lên đầu
  } else if (actorSortOrder === 'LEAST_MOVIES') {
    processedActorsList.sort((a, b) => a.movieCount - b.movieCount); // Ít phim nhất lên đầu
  }

  const totalActorPages = Math.ceil(processedActorsList.length / ACTORS_PER_PAGE);
  const currentActorsSlice = processedActorsList.slice(
    (currentActorPage - 1) * ACTORS_PER_PAGE, 
    currentActorPage * ACTORS_PER_PAGE
  );

  const filteredTicketPrices = ticketPrices.filter(price => {
    let matchCinema = true;
    if (priceFilterCinema === 'GLOBAL') {
      matchCinema = price.CinemaID === null; // Chỉ lấy giá toàn hệ thống
    } else if (priceFilterCinema !== 'ALL') {
      matchCinema = price.CinemaID?.toString() === priceFilterCinema; // Lấy giá theo rạp cụ thể
    }

    let matchSeat = true;
    if (priceFilterSeatType !== 'ALL') {
      matchSeat = price.SeatTypeID.toString() === priceFilterSeatType;
    }

    let matchShow = true;
    if (priceFilterShowType !== 'ALL') {
      matchShow = price.ShowType === priceFilterShowType;
    }

    return matchCinema && matchSeat && matchShow;
  });

  const totalPricePages = Math.ceil(filteredTicketPrices.length / PRICES_PER_PAGE);
  const currentPricesSlice = filteredTicketPrices.slice(
    (currentPricePage - 1) * PRICES_PER_PAGE,
    currentPricePage * PRICES_PER_PAGE
  );

  return (
    <div className="p-6 bg-gray-50 min-h-screen relative select-none">
      
      {/* 🚀 TAB ĐIỀU HƯỚNG (ĐÃ CSS LẠI CHO GỌN GÀNG) */}
      <div className="flex flex-wrap gap-1 sm:gap-2 mb-6 border-b border-gray-200 pb-0">
        <button onClick={() => { setActiveTab('cinemas'); setViewingMovie(null); }} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-t-lg font-bold text-sm transition-all duration-300 ${activeTab === 'cinemas' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-500 hover:text-indigo-600 hover:bg-indigo-50'}`}>
          <Building2 size={18}/> Rạp & Phòng
        </button>
        <button onClick={() => { setActiveTab('seattypes'); setViewingMovie(null); }} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-t-lg font-bold text-sm transition-all duration-300 ${activeTab === 'seattypes' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-500 hover:text-indigo-600 hover:bg-indigo-50'}`}>
          <Armchair size={18}/> Loại Ghế
        </button>
        <button onClick={() => { setActiveTab('ticketprices'); setViewingMovie(null); }} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-t-lg font-bold text-sm transition-all duration-300 ${activeTab === 'ticketprices' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-500 hover:text-indigo-600 hover:bg-indigo-50'}`}>
          <Tags size={18}/> Bảng Giá
        </button>
        <button onClick={() => { setActiveTab('movies'); setViewingMovie(null); }} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-t-lg font-bold text-sm transition-all duration-300 ${activeTab === 'movies' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-500 hover:text-indigo-600 hover:bg-indigo-50'}`}>
          <Clapperboard size={18}/> Phim Điện Ảnh
        </button>
        <button onClick={() => { setActiveTab('genres'); setViewingMovie(null); }} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-t-lg font-bold text-sm transition-all duration-300 ${activeTab === 'genres' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-500 hover:text-indigo-600 hover:bg-indigo-50'}`}>
          <Tags size={18}/> Thể Loại
        </button>
        <button onClick={() => { setActiveTab('actors'); setViewingMovie(null); }} className={`flex items-center gap-1.5 px-4 py-2.5 rounded-t-lg font-bold text-sm transition-all duration-300 ${activeTab === 'actors' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-500 hover:text-indigo-600 hover:bg-indigo-50'}`}>
          <Users size={18}/> Diễn Viên
        </button>
      </div>

      {/* ========================================================================= */}
      {/* ✅ TRANG CHI TIẾT PHIM */}
      {/* ========================================================================= */}
      {viewingMovie && (
        <div className="animate-fade-in bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden pb-10">
          
          <div className="relative h-[400px] w-full bg-slate-900 flex items-center justify-center overflow-hidden">
            <div className="absolute inset-0 z-0">
              <img 
                src={getImageUrl(viewingMovie.backdrop_path && viewingMovie.backdrop_path !== 'null' ? viewingMovie.backdrop_path : (viewingMovie.poster_path || viewingMovie.posterUrl), true)} 
                alt="backdrop" 
                className="w-full h-full object-cover opacity-40 blur-[2px]" 
                onError={(e) => { e.currentTarget.src = 'https://via.placeholder.com/1280x720?text=Chua+Co+Anh+Nen'; }}
              />
              <div className="absolute inset-0 bg-gradient-to-t from-slate-900 via-transparent to-transparent"></div>
            </div>
            
            <div className="absolute top-6 left-6 z-20"><button onClick={() => setViewingMovie(null)} className="flex items-center gap-2 bg-white/10 hover:bg-white/20 backdrop-blur-md text-white px-4 py-2 rounded-lg font-bold transition"><ArrowLeft size={20}/> Quay lại danh sách</button></div>
            <div className="absolute top-6 right-6 z-20"><button onClick={() => openEditMovieModal(viewingMovie)} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white px-5 py-2 rounded-lg font-bold transition shadow-lg"><Edit size={18}/> Chỉnh Sửa Phim</button></div>

            <div className="relative z-10 w-full max-w-5xl px-8 flex items-end gap-8 translate-y-16">
              <img src={getImageUrl(viewingMovie.poster_path || viewingMovie.posterUrl)} alt="poster" className="w-48 h-72 object-cover rounded-xl shadow-2xl border-2 border-white/20" onError={(e) => { e.currentTarget.src = 'https://via.placeholder.com/300x450?text=Chua+Co+Poster'; }}/>
              <div className="pb-4">
                <div className="flex items-center gap-3 mb-2">
                  <span className="bg-amber-500 text-white font-black px-2 py-0.5 rounded text-sm">{viewingMovie.age_rating || 'P'}</span>
                  <span className="bg-white/20 backdrop-blur-md text-white font-medium px-3 py-0.5 rounded-full text-sm border border-white/10">{viewingMovie.language || 'Tiếng Việt'}</span>
                </div>
                <h1 className="text-4xl font-black text-white mb-2 leading-tight drop-shadow-lg">{viewingMovie.title}</h1>
                <div className="flex items-center gap-4 text-slate-300 font-medium text-sm">
                  <span className="flex items-center gap-1.5"><CalendarClock size={16}/> {viewingMovie.duration} Phút</span>
                  <span className="flex items-center gap-1.5"><Star size={16} className="text-amber-400"/> {viewingMovie.vote_average || '0.0'} IMDB</span>
                  <span className="flex items-center gap-1.5"><Tags size={16}/> {viewingMovie.genres || viewingMovie.genre}</span>
                </div>
              </div>
            </div>
          </div>

          <div className="max-w-5xl mx-auto px-8 mt-24 grid grid-cols-3 gap-10">
            <div className="col-span-2 flex flex-col gap-8">
              <div>
                <h3 className="text-xl font-bold text-slate-800 mb-3 flex items-center gap-2"><FileText className="text-indigo-600"/> Tóm tắt nội dung</h3>
                <p className="text-slate-600 leading-relaxed text-justify">{viewingMovie.overview || 'Chưa có thông tin mô tả cho bộ phim này.'}</p>
              </div>
              <div>
                <h3 className="text-xl font-bold text-slate-800 mb-4 flex items-center gap-2"><Users className="text-indigo-600"/> Đạo diễn & Dàn diễn viên (Cast)</h3>
                <div className="bg-slate-50 rounded-xl p-5 border border-slate-100">
                  {(() => {
                    const rawCast = viewingMovie.cast || viewingMovie.castJson || '';
                    if (!rawCast) return <p className="text-slate-700 leading-relaxed font-medium">Chưa cập nhật danh sách diễn viên. Bấm "Chỉnh Sửa Phim" ở góc trên để thêm.</p>;
                    try {
                      const parsedCast = JSON.parse(rawCast);
                      if (Array.isArray(parsedCast) && parsedCast.length > 0) {
                        return (
                          <div className="flex gap-4 overflow-x-auto pb-2 custom-scrollbar">
                            {parsedCast.map((actor: any, idx: number) => {
                              // 🚀 THUẬT TOÁN BỌC THÉP LINK ẢNH (Giống hệt bên Tab Diễn Viên)
                              let imgUrl = '';
                              if (actor.profile_path && String(actor.profile_path) !== 'null' && actor.profile_path.trim() !== '') {
                                let path = actor.profile_path.trim();
                                if (path.startsWith('http')) {
                                  imgUrl = path; // Link web ngoài
                                } else if (path.startsWith('/public') || path.startsWith('/avatars') || path.startsWith('/uploads')) {
                                  imgUrl = `http://192.168.1.7:3000${path}`; // Ảnh tải lên từ máy tính
                                } else {
                                  imgUrl = `https://image.tmdb.org/t/p/w200${path.startsWith('/') ? path : '/' + path}`; // Ảnh gốc TMDB
                                }
                              } else {
                                // Nếu không có ảnh, lấy chữ cái tên làm Avatar
                                imgUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(actor.name)}&background=e2e8f0&color=475569&size=150`;
                              }

                              return (
                                <div key={idx} className="w-[84px] flex-shrink-0 flex flex-col items-center">
                                  {/* Cập nhật thẻ IMG chống chớp nháy và lỗi link */}
                                  <img 
                                    src={imgUrl} 
                                    alt={actor.name} 
                                    className="w-full h-28 object-cover rounded-lg shadow-sm border border-slate-200 mb-1.5 bg-slate-50" 
                                    onError={(e) => { 
                                      if (!e.currentTarget.src.includes('ui-avatars')) {
                                        e.currentTarget.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(actor.name)}&background=e2e8f0&color=475569&size=150`;
                                      }
                                    }} 
                                  />
                                  <span className="text-xs font-bold text-slate-800 text-center line-clamp-1 w-full" title={actor.name}>{actor.name || 'Unknown'}</span>
                                  <span className="text-[10px] text-slate-500 text-center line-clamp-1 w-full" title={actor.character}>{actor.character || ''}</span>
                                </div>
                              );
                            })}
                          </div>
                        );
                      }
                    } catch (e) { return <p className="text-slate-700 leading-relaxed font-medium">{rawCast}</p>; }
                    return <p className="text-slate-700 leading-relaxed font-medium">{rawCast}</p>;
                  })()}
                </div>
              </div>
            </div>
            <div className="col-span-1">
              <h3 className="text-xl font-bold text-slate-800 mb-4 flex items-center gap-2"><PlayCircle className="text-indigo-600"/> Official Trailer</h3>
              {(viewingMovie.TrailerURL || viewingMovie.trailerUrl || viewingMovie.trailer_url) ? (
                <div className="rounded-xl overflow-hidden shadow-lg border border-slate-200 aspect-video bg-black">
                  <iframe width="100%" height="100%" src={getEmbedUrl(viewingMovie.TrailerURL || viewingMovie.trailerUrl || viewingMovie.trailer_url)} title="YouTube video player" frameBorder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowFullScreen></iframe>
                </div>
              ) : (
                <div className="aspect-video bg-slate-100 rounded-xl border-2 border-dashed border-slate-300 flex flex-col items-center justify-center text-slate-400"><PlayCircle size={40} className="mb-2 opacity-50"/><span className="text-sm font-medium">Chưa có Trailer</span></div>
              )}
            </div>
          </div>
          {/* ==================== BỘ SƯU TẬP BACKDROP (GALLERY) ==================== */}
          {(() => {
            let backdrops: string[] = [];
            const rawBackdrop = viewingMovie.backdrop_path || viewingMovie.backdropUrl || '';
            
            // Xử lý bóc tách mảng JSON
            if (rawBackdrop.startsWith('[')) {
              try { 
                backdrops = JSON.parse(rawBackdrop); 
              } catch(e) {}
            } else if (rawBackdrop && rawBackdrop !== 'null' && rawBackdrop.trim() !== '') {
              backdrops = [rawBackdrop];
            }

            if (backdrops.length > 0) {
              return (
                <div className="max-w-5xl mx-auto px-8 mt-10 mb-6 animate-fade-in">
                  <h3 className="text-xl font-bold text-slate-800 mb-4 flex items-center gap-2">
                    <Film className="text-indigo-600"/> Bộ sưu tập ảnh (Backdrops)
                  </h3>
                  <div className="flex gap-4 overflow-x-auto pb-4 custom-scrollbar">
                    {backdrops.map((img, idx) => {
                      let cleanImg = img.trim();
                      let finalUrl = cleanImg;
                      
                      // Xử lý link TMDB vs Link Upload nội bộ
                      if (!cleanImg.startsWith('http') && !cleanImg.startsWith('/uploads')) {
                         finalUrl = `https://image.tmdb.org/t/p/w500${cleanImg.startsWith('/') ? cleanImg : '/' + cleanImg}`;
                      } else if (cleanImg.startsWith('/uploads')) {
                         finalUrl = `http://192.168.1.7:3000${cleanImg}`;
                      }

                      return (
                        <img 
                          key={idx} 
                          src={finalUrl} 
                          alt={`backdrop-${idx}`} 
                          className="h-32 sm:h-40 w-auto object-cover rounded-xl shadow-sm border border-slate-200 hover:scale-[1.02] transition-transform cursor-pointer bg-slate-100"
                          onError={(e) => { e.currentTarget.style.display = 'none'; }} // Ẩn luôn nếu ảnh bị lỗi
                        />
                      );
                    })}
                  </div>
                </div>
              );
            }
            return null; // Không hiện khung này nếu không có ảnh
          })()}
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 3: QUẢN LÝ CÁC LOẠI GHẾ */}
      {/* ========================================================================= */}
      {!viewingMovie && activeTab === 'seattypes' && (
        <div className="animate-fade-in">
          <div className="flex justify-between items-center mb-6 gap-4 bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <h2 className="text-xl font-bold text-slate-800 flex items-center gap-2"><Armchair className="text-indigo-600" /> Cấu hình Cọ Vẽ & Loại Ghế</h2>
            
            {/* ✅ ĐÃ SỬA NÚT THÊM: PriceSurCharge mặc định là 0 */}
            <button onClick={() => { 
              setEditingSeatTypeId(null); 
              setSeatTypeFormData({ TypeName: '', WidthSlots: 1, ColorCode: '#e9d5ff', PriceSurCharge: 0 }); 
              setIsSeatTypeModalOpen(true); 
            }} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 px-4 rounded-lg shadow-md"><Plus size={20} /> Thêm Loại Ghế</button>
          </div>
          
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="w-full text-left border-collapse">
              <thead className="bg-slate-800 text-white">
                <tr>
                  <th className="p-4 text-sm font-semibold">Tên Loại Ghế</th>
                  <th className="p-4 text-sm font-semibold text-center">Chiếm dụng (Ô lưới)</th>
                  <th className="p-4 text-sm font-semibold text-center">Mã Màu (Hiển thị)</th>
                  <th className="p-4 text-sm font-semibold text-center">Thao Tác</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-200">
                {seatTypes.map((type) => (
                  <tr key={type.SeatTypeID} className="hover:bg-gray-50 transition-colors">
                    <td className="p-4 font-bold text-gray-800">{type.TypeName}</td>
                    <td className="p-4 text-center"><span className="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-xs font-bold">{type.WidthSlots} ô</span></td>
                    <td className="p-4 text-center"><div className="flex items-center justify-center gap-2"><div className="w-6 h-6 rounded border border-gray-300" style={{ backgroundColor: type.ColorCode }}></div><span className="text-sm font-mono text-gray-600">{type.ColorCode.toUpperCase()}</span></div></td>
                    

                    <td className="p-4 text-center">
                      <div className="flex items-center justify-center gap-2">
                        
                        {/* ✅ ĐÃ SỬA NÚT EDIT: Lấy PriceSurCharge từ type ra form */}
                        <button onClick={() => { 
                          setEditingSeatTypeId(type.SeatTypeID); 
                          setSeatTypeFormData({ 
                            TypeName: type.TypeName, 
                            WidthSlots: type.WidthSlots, 
                            ColorCode: type.ColorCode, 
                            PriceSurCharge: type.PriceSurCharge || 0 
                          }); 
                          setIsSeatTypeModalOpen(true); 
                        }} className="p-1.5 bg-blue-50 text-blue-600 hover:bg-blue-100 rounded-md transition"><Edit size={16} /></button>
                        
                        <button onClick={() => handleDeleteSeatType(type.SeatTypeID, type.TypeName)} className="p-1.5 bg-red-50 text-red-600 hover:bg-red-100 rounded-md transition"><Trash2 size={16} /></button>
                      </div>
                    </td>
                  </tr>
                ))}
                
                {/* ✅ Sửa colSpan từ 4 thành 5 vì bảng vừa thêm 1 cột */}
                {seatTypes.length === 0 && <tr><td colSpan={5} className="p-8 text-center text-gray-500">Chưa có dữ liệu loại ghế.</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB: QUẢN LÝ BẢNG GIÁ VÉ (TICKET PRICES MATRIX) */}
      {/* ========================================================================= */}
      {!viewingMovie && activeTab === 'ticketprices' && (
        <div className="animate-fade-in">
          {/* 🚀 HEADER: TITLE VÀ NÚT THÊM */}
          <div className="flex justify-between items-center mb-6 gap-4 bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <h2 className="text-xl font-bold text-slate-800 flex items-center gap-2"><FileText className="text-indigo-600" /> Quản Lý Giá Vé</h2>
            <button onClick={() => { 
              setEditingPriceId(null); 
              setPriceFormData({ CinemaID: '', SeatTypeID: seatTypes.length > 0 ? seatTypes[0].SeatTypeID : 1, ShowType: '2D', DayType: 'Ngày thường', Price: 85000 }); 
              setSearchModalCinemaTerm(''); 
              setIsPriceModalOpen(true); 
            }} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 px-4 rounded-lg shadow-md transition-transform hover:-translate-y-0.5"><Plus size={20} /> Thêm Giá Mới</button>
          </div>
          
          {/* 🚀 BỘ LỌC (FILTERS) */}
          <div className="flex flex-wrap gap-4 mb-6 bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            {/* 🚀 BỘ LỌC TÌM KIẾM RẠP THÔNG MINH */}
            <div className="flex-1 min-w-[250px] relative z-40" ref={filterCinemaDropdownRef}>
              <label className="block text-xs font-bold text-slate-500 mb-1 uppercase tracking-wider">Lọc theo Rạp</label>
              <div className="flex items-center border border-slate-200 rounded-lg px-3 bg-slate-50 focus-within:bg-white focus-within:border-indigo-400 focus-within:ring-2 focus-within:ring-indigo-100 transition-all">
                <Map size={16} className="text-indigo-500 shrink-0" />
                <input 
                  type="text" 
                  placeholder="Tất cả (Gõ để tìm rạp...)" 
                  value={searchFilterCinemaTerm} 
                  onChange={(e) => {
                    setSearchFilterCinemaTerm(e.target.value);
                    setShowFilterCinemaDropdown(true);
                  }}
                  onFocus={(e) => {
                    e.target.select();
                    setShowFilterCinemaDropdown(true);
                  }}
                  className="w-full bg-transparent border-none outline-none py-2 px-2 text-sm font-bold text-slate-700 placeholder-slate-400" 
                />
                {searchFilterCinemaTerm ? (
                  <X size={14} className="text-slate-400 hover:text-red-500 cursor-pointer shrink-0" onClick={() => { 
                    setSearchFilterCinemaTerm(''); 
                    setPriceFilterCinema('ALL'); 
                    setShowFilterCinemaDropdown(true); 
                  }} />
                ) : (
                  <ChevronDown size={16} className="text-slate-400 shrink-0 cursor-pointer" onClick={() => setShowFilterCinemaDropdown(!showFilterCinemaDropdown)} />
                )}
              </div>

              {showFilterCinemaDropdown && (
                <div className="absolute top-[100%] left-0 right-0 bg-white border border-slate-200 rounded-xl mt-1 max-h-[250px] overflow-y-auto shadow-xl animate-[slide-in-down_0.2s_ease-out]">
                  <div 
                    onMouseDown={() => {
                      setPriceFilterCinema('ALL');
                      setSearchFilterCinemaTerm('');
                      setShowFilterCinemaDropdown(false);
                    }}
                    className="p-3 cursor-pointer border-b border-slate-100 hover:bg-indigo-50 text-slate-700 font-bold text-sm transition-colors"
                  >
                    Tất cả (Bao gồm Giá riêng & Toàn quốc)
                  </div>
                  <div 
                    onMouseDown={() => {
                      setPriceFilterCinema('GLOBAL');
                      setSearchFilterCinemaTerm('Chỉ xem Giá Toàn Hệ Thống');
                      setShowFilterCinemaDropdown(false);
                    }}
                    className="p-3 cursor-pointer border-b border-slate-100 hover:bg-indigo-50 text-emerald-700 font-bold text-sm transition-colors"
                  >
                    Chỉ xem Giá Toàn Hệ Thống
                  </div>
                  {filteredFilterCinemas.length > 0 ? filteredFilterCinemas.map(c => (
                    <div 
                      key={c.id} 
                      onMouseDown={() => {
                        setPriceFilterCinema(c.id.toString());
                        setSearchFilterCinemaTerm(`Rạp: ${c.name}`);
                        setShowFilterCinemaDropdown(false);
                      }}
                      className="p-3 cursor-pointer border-b border-slate-50 hover:bg-indigo-50 transition-colors text-sm font-semibold text-slate-700"
                    >
                      Rạp: {c.name}
                    </div>
                  )) : (
                    <div className="p-4 text-center text-slate-500 text-sm">Không tìm thấy rạp</div>
                  )}
                </div>
              )}
            </div>

            <div className="flex-1 min-w-[150px]">
              <label className="block text-xs font-bold text-slate-500 mb-1 uppercase tracking-wider">Loại Ghế</label>
              <div className="relative">
                <Armchair className="absolute left-3 top-1/2 transform -translate-y-1/2 text-indigo-500" size={16} />
                <select value={priceFilterSeatType} onChange={(e) => setPriceFilterSeatType(e.target.value)} className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg outline-none text-sm font-bold text-slate-700 focus:ring-2 focus:ring-indigo-100 focus:border-indigo-400 transition-all cursor-pointer">
                  <option value="ALL">Tất cả loại ghế</option>
                  {seatTypes.map(st => <option key={st.SeatTypeID} value={st.SeatTypeID}>{st.TypeName}</option>)}
                </select>
              </div>
            </div>

            <div className="flex-1 min-w-[150px]">
              <label className="block text-xs font-bold text-slate-500 mb-1 uppercase tracking-wider">Định Dạng</label>
              <div className="relative">
                <Film className="absolute left-3 top-1/2 transform -translate-y-1/2 text-indigo-500" size={16} />
                <select value={priceFilterShowType} onChange={(e) => setPriceFilterShowType(e.target.value)} className="w-full pl-10 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg outline-none text-sm font-bold text-slate-700 focus:ring-2 focus:ring-indigo-100 focus:border-indigo-400 transition-all cursor-pointer">
                  <option value="ALL">Tất cả định dạng</option>
                  <option value="2D">Phim 2D</option>
                  <option value="3D">Phim 3D</option>
                  <option value="4DX">Phim 4DX</option>
                  <option value="IMAX">Phim IMAX</option>
                </select>
              </div>
            </div>
            
            {/* Nút Xóa Lọc */}
            {(priceFilterCinema !== 'ALL' || priceFilterSeatType !== 'ALL' || priceFilterShowType !== 'ALL') && (
              <div className="flex items-end">
                <button onClick={() => { 
                  setPriceFilterCinema('ALL'); 
                  setPriceFilterSeatType('ALL'); 
                  setPriceFilterShowType('ALL'); 
                  setSearchFilterCinemaTerm(''); // 🚀 THÊM DÒNG NÀY VÀO ĐÂY
                }} className="h-[38px] px-4 flex items-center gap-2 bg-red-50 hover:bg-red-100 text-red-600 text-sm font-bold rounded-lg transition-colors border border-red-100">
                  <X size={16} /> Xóa lọc
                </button>
              </div>
            )}
          </div>

          {/* 🚀 BẢNG DỮ LIỆU */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse min-w-[800px]">
                <thead className="bg-slate-800 text-white">
                  <tr>
                    <th className="p-4 text-sm font-semibold whitespace-nowrap">Phạm vi Rạp</th>
                    <th className="p-4 text-sm font-semibold">Loại Ghế</th>
                    <th className="p-4 text-sm font-semibold text-center whitespace-nowrap">Định Dạng</th>
                    <th className="p-4 text-sm font-semibold text-center whitespace-nowrap">Loại Ngày</th>
                    <th className="p-4 text-sm font-semibold text-center whitespace-nowrap">Mức Giá</th>
                    <th className="p-4 text-sm font-semibold text-center w-24">Thao Tác</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {currentPricesSlice.map((price) => {
                    const seatName = seatTypes.find(s => s.SeatTypeID === price.SeatTypeID)?.TypeName || `Ghế ID: ${price.SeatTypeID}`;
                    return (
                    <tr key={price.PriceID} className={`transition-colors ${price.CinemaID ? 'hover:bg-rose-50/30' : 'hover:bg-indigo-50/40 bg-slate-50/30'}`}>
                      <td className="p-4 text-sm font-bold text-slate-800">
                        {price.CinemaName ? <span className="text-rose-600 bg-rose-50 px-2.5 py-1 rounded-md border border-rose-100">{price.CinemaName}</span> : <span className="text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-md border border-emerald-100 shadow-sm flex items-center gap-1.5 w-max">Toàn Hệ Thống</span>}
                      </td>
                      <td className="p-4 font-bold text-indigo-700">{seatName}</td>
                      <td className="p-4 text-center"><span className="bg-slate-200 text-slate-800 px-3 py-1 rounded-full text-xs font-black shadow-sm border border-slate-300">{price.ShowType}</span></td>
                      <td className="p-4 text-center"><span className={price.DayType.includes('Cuối tuần') ? 'bg-amber-100 text-amber-700 px-3 py-1 rounded-md text-xs font-bold border border-amber-200' : 'bg-blue-100 text-blue-700 px-3 py-1 rounded-md text-xs font-bold border border-blue-200'}>{price.DayType}</span></td>
                      <td className="p-4 text-center font-black text-red-600 text-base">{Number(price.Price).toLocaleString('vi-VN')} đ</td>
                      <td className="p-4 text-center">
                        <div className="flex items-center justify-center gap-2">
                          <button onClick={() => { 
                            setEditingPriceId(price.PriceID); 
                            setPriceFormData({ 
                               CinemaID: price.CinemaID?.toString() || '', 
                               SeatTypeID: price.SeatTypeID, 
                               ShowType: price.ShowType, 
                               DayType: price.DayType, 
                               Price: Number(price.Price) 
                            }); 
                            setSearchModalCinemaTerm(price.CinemaID ? `Chỉ áp dụng cho: ${price.CinemaName}` : ''); 
                            setIsPriceModalOpen(true); 
                          }} className="p-1.5 bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white rounded-md transition-colors shadow-sm"><Edit size={16} /></button>
                          <button onClick={() => handleDeletePrice(price.PriceID)} className="p-1.5 bg-red-50 text-red-600 hover:bg-red-600 hover:text-white rounded-md transition-colors shadow-sm"><Trash2 size={16} /></button>
                        </div>
                      </td>
                    </tr>
                  )})}
                  {filteredTicketPrices.length === 0 && <tr><td colSpan={6} className="p-12 text-center text-slate-500 font-medium">Không tìm thấy mức giá nào phù hợp với bộ lọc.</td></tr>}
                </tbody>
              </table>
            </div>
          </div>

          {/* 🚀 THANH PHÂN TRANG */}
          {totalPricePages > 1 && (
            <div className="flex justify-center items-center gap-2 mt-6">
              <button onClick={() => setCurrentPricePage(p => Math.max(1, p - 1))} disabled={currentPricePage === 1} className="px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-gray-500 hover:bg-indigo-50 hover:text-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed transition font-semibold">
                Trước
              </button>
              <span className="px-4 py-1.5 text-sm font-bold text-slate-700 bg-white border border-gray-200 rounded-lg shadow-sm">
                Trang {currentPricePage} / {totalPricePages}
              </span>
              <button onClick={() => setCurrentPricePage(p => Math.min(totalPricePages, p + 1))} disabled={currentPricePage === totalPricePages} className="px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-gray-500 hover:bg-indigo-50 hover:text-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed transition font-semibold">
                Sau
              </button>
            </div>
          )}
        </div>
      )}

      {/* ========================================================= */}
      {/* MODAL THÊM / SỬA GIÁ VÉ */}
      {/* ========================================================= */}
      {isPriceModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md overflow-hidden animate-fade-in">
            <div className="flex justify-between items-center p-5 border-b bg-slate-50">
              <h3 className="font-bold text-lg flex items-center gap-2"><FileText className="text-indigo-600" /> {editingPriceId ? "Sửa Mức Giá" : "Tạo Mức Giá Mới"}</h3>
              <button onClick={() => setIsPriceModalOpen(false)} className="text-gray-400 hover:text-red-500"><X/></button>
            </div>
            <form onSubmit={handlePriceSubmit} className="p-6 flex flex-col gap-4">
              {/* 🚀 DÁN KHỐI COMBOBOX NÀY VÀO CHỖ VỪA XÓA */}
              <div className="relative group z-50" ref={modalCinemaDropdownRef}>
                <label className="block text-sm font-bold mb-1">Rạp Áp Dụng (Để trống = Toàn hệ thống)</label>
                <div className="flex items-center border border-slate-300 rounded-lg px-3 bg-emerald-50 focus-within:bg-white focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-100 transition-all">
                  <Search size={18} className="text-slate-400 shrink-0" />
                  <input 
                    type="text" 
                    placeholder="Áp dụng cho TẤT CẢ CÁC RẠP (Gõ để tìm...)" 
                    value={searchModalCinemaTerm} 
                    onChange={(e) => {
                      setSearchModalCinemaTerm(e.target.value);
                      setShowModalCinemaDropdown(true);
                    }}
                    onFocus={(e) => {
                      e.target.select();
                      setShowModalCinemaDropdown(true);
                    }}
                    className="w-full bg-transparent border-none outline-none py-2.5 px-3 text-sm font-bold text-emerald-900 placeholder-emerald-800/60" 
                  />
                  {searchModalCinemaTerm ? (
                    <X size={16} className="text-slate-400 hover:text-red-500 cursor-pointer shrink-0" onClick={() => { 
                      setSearchModalCinemaTerm(''); 
                      setPriceFormData({...priceFormData, CinemaID: ''}); 
                      setShowModalCinemaDropdown(true); 
                    }} />
                  ) : (
                    <ChevronDown size={18} className="text-slate-400 shrink-0 cursor-pointer" onClick={() => setShowModalCinemaDropdown(!showModalCinemaDropdown)} />
                  )}
                </div>

                {showModalCinemaDropdown && (
                  <div className="absolute top-[100%] left-0 right-0 bg-white border border-slate-200 rounded-xl mt-1 max-h-[200px] overflow-y-auto shadow-2xl animate-[slide-in-down_0.2s_ease-out]">
                    <div 
                      onMouseDown={() => {
                        setPriceFormData({...priceFormData, CinemaID: ''});
                        setSearchModalCinemaTerm('');
                        setShowModalCinemaDropdown(false);
                      }}
                      className="p-3 cursor-pointer border-b border-slate-100 hover:bg-emerald-50 text-emerald-700 font-bold text-sm transition-colors"
                    >
                      Áp dụng cho TẤT CẢ CÁC RẠP
                    </div>
                    {filteredModalCinemas.length > 0 ? filteredModalCinemas.map(c => (
                      <div 
                        key={c.id} 
                        onMouseDown={() => {
                          setPriceFormData({...priceFormData, CinemaID: c.id.toString()});
                          setSearchModalCinemaTerm(`Chỉ áp dụng cho: ${c.name}`);
                          setShowModalCinemaDropdown(false);
                        }}
                        className="p-3 cursor-pointer border-b border-slate-50 hover:bg-indigo-50 transition-colors text-sm font-semibold text-slate-700"
                      >
                        Chỉ áp dụng cho: {c.name}
                      </div>
                    )) : (
                      <div className="p-4 text-center text-slate-500 text-sm">Không tìm thấy rạp phù hợp</div>
                    )}
                  </div>
                )}
              </div>
              {/* 🚀 KẾT THÚC KHỐI COMBOBOX */}
              <div>
                <label className="block text-sm font-bold mb-1">Loại Ghế Áp Dụng</label>
                <select value={priceFormData.SeatTypeID} onChange={e=>setPriceFormData({...priceFormData, SeatTypeID: parseInt(e.target.value)})} className="w-full border rounded-lg p-2.5 outline-none focus:border-indigo-500 bg-white">
                  {seatTypes.map(st => <option key={st.SeatTypeID} value={st.SeatTypeID}>{st.TypeName}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1">Định dạng Phim</label>
                <select value={priceFormData.ShowType} onChange={e=>setPriceFormData({...priceFormData, ShowType: e.target.value})} className="w-full border rounded-lg p-2.5 outline-none focus:border-indigo-500 bg-white">
                  <option value="2D">Phim 2D</option>
                  <option value="3D">Phim 3D</option>
                  <option value="4DX">Phim 4DX</option>
                  <option value="IMAX">Phim IMAX</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1">Loại Ngày</label>
                <select value={priceFormData.DayType} onChange={e=>setPriceFormData({...priceFormData, DayType: e.target.value})} className="w-full border rounded-lg p-2.5 outline-none focus:border-indigo-500 bg-white">
                  <option value="Ngày thường">Ngày thường (T2 - T6)</option>
                  <option value="Cuối tuần">Cuối tuần / Lễ (T7 - CN)</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1">Giá Vé Cuối Cùng (VNĐ)</label>
                <input type="number" min="0" step="1000" value={priceFormData.Price} onChange={e=>setPriceFormData({...priceFormData, Price: parseInt(e.target.value) || 0})} className="w-full border rounded-lg p-2.5 outline-none focus:border-indigo-500" placeholder="VD: 85000" required/>
                <p className="text-xs text-red-500 font-medium mt-1">*Lưu ý: Nhập TỔNG SỐ TIỀN khách phải trả cho 1 vé loại này (Không phải phụ thu).</p>
              </div>

              <button type="submit" disabled={loading} className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-3 rounded-lg mt-2 transition">{loading ? 'Đang lưu...' : 'Lưu Lại'}</button>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 2: KHO PHIM ĐIỆN ẢNH */}
      {/* ========================================================================= */}
      {!viewingMovie && activeTab === 'movies' && (
        <div className="animate-fade-in">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4 bg-white p-4 rounded-xl shadow-sm border border-gray-100 mb-8">
            <div className="flex items-center gap-4 w-full md:w-auto flex-1">
              <div className="relative w-full md:max-w-xs"><Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} /><input type="text" placeholder="Tìm tên phim..." value={movieSearchQuery} onChange={(e) => setMovieSearchQuery(e.target.value)} className="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none text-sm bg-gray-50 focus:bg-white" /></div>
              <div className="relative w-full md:w-48 hidden sm:block"><Filter className="absolute left-4 top-1/2 transform -translate-y-1/2 text-indigo-500" size={18} /><select value={movieFilterStatus} onChange={(e) => setMovieFilterStatus(e.target.value)} className="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-xl outline-none font-bold text-indigo-900 bg-gray-50 focus:bg-white text-sm"><option value="ALL">Tất cả phim</option><option value="NOW_PLAYING">Đang Chiếu</option><option value="UPCOMING">Sắp Chiếu</option><option value="VIETNAMESE">Phim Việt Nam</option><option value="HIDDEN">Đã Ẩn</option></select></div>
            </div>
            <button onClick={openAddMovieModal} className="w-full md:w-auto flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-3 px-5 rounded-xl transition shadow-md whitespace-nowrap"><Plus size={20} /> Thêm Phim Mới</button>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6">
            {currentMoviesSlice.map(movie => {
              const isHidden = movie.IsDeleted === 1;
              const rDate = movie.releaseDate || movie.release_date || '';
              return (
                <div key={movie.id} className={`bg-white rounded-2xl shadow-sm hover:shadow-xl transition-all border border-gray-100 overflow-hidden flex flex-col group relative ${isHidden ? 'grayscale opacity-75' : ''}`}>
                  {isHidden && (<div className="absolute top-3 left-3 bg-red-600 text-white text-[10px] font-black px-2 py-1 rounded shadow-md z-20 tracking-wider">ĐÃ ẨN</div>)}
                  
                  <div className="aspect-[2/3] w-full overflow-hidden bg-gray-100 relative">
                    <img src={getImageUrl(movie.posterUrl || movie.poster_path)} alt={movie.title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" onError={(e) => { e.currentTarget.src = 'https://via.placeholder.com/300x450?text=No+Poster'; }}/>
                    <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center gap-3">
                      <button onClick={() => setViewingMovie(movie)} className="p-3 bg-white/20 hover:bg-indigo-500 text-white rounded-full transition" title="Xem chi tiết phim"><Info size={18}/></button>
                      <button onClick={() => openEditMovieModal(movie)} className="p-3 bg-white/20 hover:bg-blue-500 text-white rounded-full transition" title="Sửa thông tin"><Edit size={18}/></button>
                      <button onClick={() => handleToggleMovieStatus(movie.id, movie.IsDeleted, movie.title)} className={`p-3 bg-white/20 text-white rounded-full transition ${isHidden ? 'hover:bg-emerald-500' : 'hover:bg-amber-500'}`} title={isHidden ? "Hiện lại phim này" : "Tắt ẩn phim này"}>{isHidden ? <Eye size={18} /> : <EyeOff size={18} />}</button>
                      <button onClick={() => handleDeleteMovie(movie.id, movie.title)} className="p-3 bg-white/20 hover:bg-red-500 text-white rounded-full transition" title="Xóa vĩnh viễn"><Trash2 size={18}/></button>
                    </div>
                  </div>
                  
                  <div className="p-4 flex-1 flex flex-col">
                    <h3 className="font-bold text-slate-800 text-md leading-tight mb-2 line-clamp-2">{movie.title}</h3>
                    <div className="mt-auto flex flex-col gap-1.5 text-xs text-slate-500 font-medium">
                      <p className="flex items-center gap-1.5"><Tags size={14} className="text-emerald-500"/> {movie.genres || movie.genre}</p>
                      <p className="flex items-center gap-1.5"><CalendarClock size={14} className="text-amber-500"/> {movie.duration} phút • {rDate ? new Date(rDate).toLocaleDateString('vi-VN') : ''}</p>
                    </div>
                  </div>
                </div>
              );
            })}
            {filteredMovies.length === 0 && <div className="col-span-full py-12 text-center text-slate-500 font-medium">Không tìm thấy phim nào phù hợp với bộ lọc hiện tại.</div>}
          </div>
          {/* 🚀 ĐÃ THÊM: THANH PHÂN TRANG PHIM */}
          {totalMoviePages > 1 && (
            <div className="flex justify-center items-center gap-2 mt-8">
              <button 
                onClick={() => setCurrentMoviePage(p => Math.max(1, p - 1))} 
                disabled={currentMoviePage === 1}
                className="px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-gray-500 hover:bg-indigo-50 hover:text-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed transition font-semibold"
              >
                Trước
              </button>
              
              <span className="px-4 py-1.5 text-sm font-bold text-slate-700 bg-white border border-gray-200 rounded-lg shadow-sm">
                Trang {currentMoviePage} / {totalMoviePages}
              </span>

              <button 
                onClick={() => setCurrentMoviePage(p => Math.min(totalMoviePages, p + 1))} 
                disabled={currentMoviePage === totalMoviePages}
                className="px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-gray-500 hover:bg-indigo-50 hover:text-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed transition font-semibold"
              >
                Sau
              </button>
            </div>
          )}
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 1: HỆ THỐNG RẠP */}
      {/* ========================================================================= */}
      {!viewingMovie && activeTab === 'cinemas' && showGrid && (
        <div className="animate-fade-in">
          <div className="flex flex-col md:flex-row items-center gap-4 bg-white p-4 rounded-xl shadow-sm border border-gray-100 mb-8"><div className="relative w-full md:flex-1"><Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} /><input type="text" placeholder="Tìm tên chi nhánh..." value={gridSearchQuery} onChange={(e) => setGridSearchQuery(e.target.value)} className="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-xl outline-none text-sm bg-gray-50 focus:bg-white" />{gridSearchQuery && <X className="absolute right-4 top-1/2 transform -translate-y-1/2 text-gray-400 cursor-pointer hover:text-red-500" size={18} onClick={() => setGridSearchQuery('')} />}</div><div className="relative w-full md:w-1/4"><Filter className="absolute left-4 top-1/2 transform -translate-y-1/2 text-indigo-500" size={18} /><select value={gridSelectedBrand} onChange={(e) => setGridSelectedBrand(e.target.value)} className="w-full pl-12 pr-4 py-3 border border-gray-200 rounded-xl outline-none font-bold text-indigo-900"><option value="">Tất cả hệ thống rạp</option><option value="1">CGV Cinemas</option><option value="2">Lotte Cinema</option><option value="3">Galaxy Cinema</option><option value="4">BHD Star Cineplex</option><option value="5">Cinestar</option><option value="6">Mega GS</option><option value="7">DCine</option><option value="8">Beta Cinemas</option></select></div><button onClick={openAddCinemaModal} className="w-full md:w-auto flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-900 text-white font-semibold py-3 px-5 rounded-xl shadow-md whitespace-nowrap"><Building2 size={20} /> Tạo Rạp Mới</button></div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {filteredCinemasGrid.map((cinema) => {
              const brand = getBrandInfo(cinema.name); const roomCount = rooms.filter(r => r.CinemaID === cinema.id).length;
              return (
                <div key={cinema.id} onClick={() => { setFilterCinemaId(cinema.id.toString()); setRoomFormData({ ...roomFormData, cinemaId: cinema.id.toString() }); setShowGrid(false); }} className="bg-white rounded-2xl shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all duration-300 border border-gray-100 cursor-pointer overflow-hidden flex flex-col h-full group relative">
                  <div className="p-5 flex items-start gap-4 border-b border-gray-50 flex-1"><div className="flex flex-col items-center gap-2.5"><div className={`w-14 h-14 rounded-xl flex-shrink-0 flex items-center justify-center overflow-hidden shadow-inner relative ${brand.color}`}><img src={brand.logo} alt={cinema.name} className="w-full h-full object-contain bg-white p-1.5 relative z-10 rounded-xl" onError={(e) => { e.currentTarget.style.display = 'none'; }} /><span className="text-white font-black text-2xl absolute -z-10">{brand.letter}</span></div><div className="bg-amber-400 text-white text-[11px] font-black px-2.5 py-0.5 rounded-full flex items-center gap-1 shadow-sm w-max"><Star size={11} fill="currentColor" /> {cinema.rating || '5.0'}</div></div><div className="flex-1"><h3 className="font-bold text-slate-800 text-lg leading-tight group-hover:text-indigo-600 transition-colors">{cinema.name}</h3><p className="text-xs text-slate-500 mt-1.5 leading-relaxed line-clamp-2"><span className="font-semibold text-slate-600">📍 </span>{cinema.address || "Đang cập nhật địa chỉ"}</p></div></div>
                  <div className="p-4 bg-slate-50/50 flex justify-between items-center mt-auto"><span className={`px-3 py-1 rounded-full text-xs font-bold ${roomCount > 0 ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'}`}>{roomCount > 0 ? `${roomCount} Phòng chiếu` : 'Chưa có phòng'}</span><div className="flex items-center gap-2"><button onClick={(e) => openEditCinemaModal(cinema, e)} className="p-1.5 bg-blue-50 text-blue-600 hover:bg-blue-100 rounded-md transition"><Edit size={16} /></button><button onClick={(e) => handleDeleteCinema(cinema.id, cinema.name, e)} className="p-1.5 bg-red-50 text-red-600 hover:bg-red-100 rounded-md transition"><Trash2 size={16} /></button></div></div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {!viewingMovie && activeTab === 'cinemas' && !showGrid && (
        <div className="animate-fade-in">
          <div className="flex justify-between items-center mb-6 gap-4 bg-white p-4 rounded-xl shadow-sm border border-gray-100"><div className="flex items-center gap-4"><button onClick={() => setShowGrid(true)} className="bg-slate-100 hover:bg-slate-200 text-slate-700 p-2 rounded-lg transition"><ArrowLeft size={20} /></button><h2 className="text-xl font-bold text-slate-800 flex items-center gap-2"><MonitorPlay className="text-indigo-600" /> Quản lý Phòng Chiếu</h2></div><div className="flex items-center gap-4"><button onClick={() => openRoomEditor()} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2 px-4 rounded-lg shadow-md"><Plus size={20} /> Tạo Phòng Mới</button></div></div>
          <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
            <table className="w-full text-left border-collapse"><thead className="bg-slate-800 text-white"><tr><th className="p-4 text-sm font-semibold">Tên Phòng</th><th className="p-4 text-sm font-semibold text-center">Sức Chứa (Tự động)</th><th className="p-4 text-sm font-semibold text-center">Thao Tác</th></tr></thead>
              <tbody className="divide-y divide-gray-200">
                {filteredRooms.map((room) => (
                  <tr key={room.RoomID} className="hover:bg-gray-50 transition-colors"><td className="p-4 font-bold text-gray-800">{room.Name}</td><td className="p-4 text-center"><span className="bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-xs font-bold">{room.TotalSeats} ghế</span></td><td className="p-4 text-center"><div className="flex items-center justify-center gap-2"><button onClick={() => openRoomEditor(room)} className="flex items-center gap-1.5 bg-indigo-50 text-indigo-600 hover:bg-indigo-100 px-3 py-1.5 rounded-lg text-sm font-semibold transition"><Map size={16} /> Edit Sơ Đồ</button><button onClick={() => handleDeleteRoom(room.RoomID, room.Name)} className="bg-red-50 text-red-600 hover:bg-red-100 px-3 py-1.5 rounded-lg text-sm font-semibold transition">Xóa</button></div></td></tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ========================================================= */}
      {/* ✅ MODAL THÊM / SỬA PHIM */}
      {/* ========================================================= */}
      {isMovieModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/80 p-4">
          <div className="bg-white rounded-2xl w-full max-w-3xl overflow-hidden animate-fade-in shadow-2xl">
            <div className="flex justify-between items-center p-5 border-b bg-slate-50">
              <h3 className="font-bold text-lg flex items-center gap-2"><Film className="text-indigo-600"/> {editingMovieId ? "Sửa thông tin phim" : "Thêm phim mới"}</h3>
              <button onClick={() => setIsMovieModalOpen(false)} className="text-gray-400 hover:text-red-500"><X/></button>
            </div>
            
            <form onSubmit={handleMovieSubmit} className="p-6 flex flex-col gap-5 max-h-[75vh] overflow-y-auto custom-scrollbar">
              
              <div className="grid grid-cols-2 gap-4">
                <div className="col-span-2">
                  <label className="block text-sm font-bold text-gray-700 mb-1">Tên phim</label>
                  <input required type="text" value={movieFormData.title} onChange={(e) => setMovieFormData({...movieFormData, title: e.target.value})} className="w-full padding-3 border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                
                <div><label className="block text-sm font-bold text-gray-700 mb-1">Khởi chiếu</label><input type="date" value={movieFormData.release_date} onChange={(e) => setMovieFormData({...movieFormData, release_date: e.target.value})} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500" /></div>
                <div><label className="block text-sm font-bold text-gray-700 mb-1">Thời lượng (Phút)</label><input type="number" value={movieFormData.duration} onChange={(e) => setMovieFormData({...movieFormData, duration: Number(e.target.value)})} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500" /></div>
                
                <div>
                  <label className="block text-sm font-bold text-gray-700 mb-1">Độ tuổi (Age Rating)</label>
                  <select 
                    value={movieFormData.age_rating} 
                    onChange={(e) => setMovieFormData({...movieFormData, age_rating: e.target.value})} 
                    className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500 bg-white cursor-pointer"
                  >
                    <option value="P">P - Phổ biến đến mọi độ tuổi</option>
                    <option value="K">K - Dưới 13T phải xem cùng cha mẹ</option>
                    <option value="T13">T13 - Từ đủ 13 tuổi trở lên</option>
                    <option value="T16">T16 - Từ đủ 16 tuổi trở lên</option>
                    <option value="T18">T18 - Từ đủ 18 tuổi trở lên</option>
                    <option value="NR">NR - Chưa phân loại</option>
                  </select>
                </div>
                <div><label className="block text-sm font-bold text-gray-700 mb-1">Điểm IMDB</label><input type="number" step="0.1" max="10" value={movieFormData.vote_average} onChange={(e) => setMovieFormData({...movieFormData, vote_average: Number(e.target.value)})} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500" /></div>

                <div><label className="block text-sm font-bold text-gray-700 mb-1">Ngôn ngữ</label><input type="text" value={movieFormData.language} onChange={(e) => setMovieFormData({...movieFormData, language: e.target.value})} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500" placeholder="VD: Tiếng Việt, Tiếng Anh"/></div>
                {/* ======================= CÔNG CỤ CHỌN NHIỀU THỂ LOẠI ======================= */}
                <div className="relative">
                  <label className="block text-sm font-bold text-gray-700 mb-1">Thể loại (Genres)</label>
                  
                  {/* 1. Khung hiển thị các Thể loại đã chọn (Dạng Tags) */}
                  <div className="flex flex-wrap gap-1.5 mb-2">
                    {movieFormData.genres.split(',').map(g => g.trim()).filter(g => g !== '').map((genre, idx) => (
                      <span key={idx} className="bg-emerald-100 text-emerald-700 border border-emerald-200 px-2.5 py-1 rounded-md text-xs font-bold flex items-center gap-1.5 shadow-sm">
                        <Tags size={12}/> {genre}
                        <button type="button" onClick={() => {
                          // Thuật toán: Xóa thể loại khỏi chuỗi
                          const newGenres = movieFormData.genres.split(',').map(g => g.trim()).filter(g => g !== '' && g !== genre).join(', ');
                          setMovieFormData({...movieFormData, genres: newGenres});
                        }} className="hover:bg-emerald-200 rounded-full p-0.5 transition"><X size={12}/></button>
                      </span>
                    ))}
                  </div>

                  {/* 2. Thanh tìm kiếm Thể loại */}
                  <div className="relative flex-1">
                    <div className="flex items-center border border-gray-300 rounded-lg p-2 bg-white focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500 transition">
                      <Search size={16} className="text-slate-400 mr-2" />
                      <input 
                        type="text" 
                        placeholder="Tìm và chọn thể loại..." 
                        className="w-full text-sm outline-none bg-transparent"
                        value={genreSearch}
                        onChange={(e) => { setGenreSearch(e.target.value); setShowGenreDropdown(true); }}
                        onFocus={() => setShowGenreDropdown(true)}
                      />
                    </div>

                    {/* 3. Dropdown Gợi ý Thể loại (Chỉ hiện những cái chưa chọn) */}
                    {showGenreDropdown && (
                      <div className="absolute z-40 mt-1 w-full bg-white border border-slate-200 rounded-xl shadow-xl max-h-48 overflow-y-auto custom-scrollbar left-0">
                        <div className="sticky top-0 bg-slate-100 text-[10px] font-bold text-slate-500 px-3 py-2 border-b border-slate-200 z-10 flex justify-between items-center">
                          <span>CHỌN THỂ LOẠI (CLICK ĐỂ THÊM)</span>
                          <button type="button" onClick={() => setShowGenreDropdown(false)} className="hover:text-red-500"><X size={14}/></button>
                        </div>
                        
                        {genresList.filter(g => g.GenreName.toLowerCase().includes(genreSearch.toLowerCase())).filter(g => !movieFormData.genres.includes(g.GenreName)).length > 0 ? (
                          genresList
                            .filter(g => g.GenreName.toLowerCase().includes(genreSearch.toLowerCase()))
                            .filter(g => !movieFormData.genres.includes(g.GenreName)) // Ẩn các thể loại đã được chọn rồi
                            .map(g => (
                            <div 
                              key={g.GenreID} 
                              className="flex items-center gap-2 p-2.5 hover:bg-emerald-50 cursor-pointer border-b border-slate-50 last:border-0 transition text-sm font-medium text-slate-700"
                              onClick={() => {
                                // Thuật toán: Nối tên thể loại mới vào chuỗi
                                const currentArray = movieFormData.genres.split(',').map(x => x.trim()).filter(x => x !== '');
                                currentArray.push(g.GenreName);
                                setMovieFormData({...movieFormData, genres: currentArray.join(', ')});
                                setGenreSearch(''); // Reset tìm kiếm
                                setShowGenreDropdown(false); // Ẩn dropdown đi
                              }}
                            >
                              <Plus size={14} className="text-emerald-500"/> {g.GenreName}
                            </div>
                          ))
                        ) : (
                          <div className="p-4 text-xs text-slate-500 text-center">Không tìm thấy hoặc đã thêm hết.</div>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              </div>

              {/* ẢNH POSTER & BACKDROP */}
              <div className="grid grid-cols-2 gap-4 border-t border-gray-100 pt-4">
                <div className="bg-slate-50 p-4 rounded-xl border border-gray-200">
                  <label className="block text-sm font-bold text-gray-700 mb-2 border-b pb-2">Poster Phim (Khung Dọc)</label>
                  <div className="flex flex-col gap-3">
                    <div className="flex flex-col gap-1">
                      <span className="text-xs font-semibold text-slate-500">Link URL (TMDB/Website):</span>
                      <input type="text" value={movieFormData.poster_path} onChange={(e) => setMovieFormData({...movieFormData, poster_path: e.target.value})} placeholder="https://..." className="w-full border border-gray-300 rounded-lg p-2 text-sm outline-none" disabled={posterFile !== null} />
                    </div>
                    <div className="flex items-center gap-2">
                      <label className="flex-1 flex items-center justify-center gap-2 border border-dashed border-indigo-300 bg-indigo-50 text-indigo-700 rounded-lg p-2 cursor-pointer hover:bg-indigo-100 transition text-sm font-medium">
                        <UploadCloud size={18} /> {posterFile ? "Đã chọn file tải lên" : "Tải ảnh từ máy..."}
                        <input type="file" accept="image/*" className="hidden" onChange={(e) => setPosterFile(e.target.files?.[0] || null)} />
                      </label>
                      {posterFile && <button type="button" onClick={() => setPosterFile(null)} className="p-2 text-red-500 hover:bg-red-50 rounded-lg"><X size={18}/></button>}
                    </div>
                  </div>
                </div>

                <div className="bg-slate-50 p-4 rounded-xl border border-gray-200">
                  <label className="block text-sm font-bold text-gray-700 mb-2 border-b pb-2">Backdrop Phim (Khung Ngang)</label>
                  <div className="flex flex-col gap-3">
                    <div className="flex flex-col gap-1">
                     <span className="text-xs font-semibold text-slate-500">Link URL (Có thể nhập NHIỀU LINK cách nhau bằng dấu phẩy):</span>
                      <textarea rows={3} value={movieFormData.backdrop_path} onChange={(e) => setMovieFormData({...movieFormData, backdrop_path: e.target.value})} placeholder="https://anh1.jpg, https://anh2.jpg, ..." className="w-full border border-gray-300 rounded-lg p-2 text-sm outline-none resize-none" disabled={backdropFiles.length > 0}></textarea>
                    </div>
                    <div className="flex items-center gap-2 mt-2">
                      <label className="flex-1 flex items-center justify-center gap-2 border border-dashed border-indigo-300 bg-indigo-50 text-indigo-700 rounded-lg p-2 cursor-pointer hover:bg-indigo-100 transition text-sm font-medium">
                        <UploadCloud size={18} /> {backdropFiles.length > 0 ? `Đã chọn ${backdropFiles.length} file ảnh` : "Tải nhiều ảnh từ máy..."}
                        {/* 🚀 THÊM multiple VÀ ĐỔI CÁCH BẮT FILE THÀNH MẢNG */}
                        <input type="file" accept="image/*" multiple className="hidden" onChange={(e) => {
                            if (e.target.files) {
                                setBackdropFiles(Array.from(e.target.files));
                            }
                        }} />
                      </label>
                      {backdropFiles.length > 0 && <button type="button" onClick={() => setBackdropFiles([])} className="p-2 text-red-500 hover:bg-red-50 rounded-lg"><X size={18}/></button>}
                    </div>
                  </div>
                </div>
              </div>

              {/* TRAILER VÀ DIỄN VIÊN */}
              <div className="grid grid-cols-2 gap-4 border-t border-gray-100 pt-4">
                <div className="col-span-2">
                  <label className="block text-sm font-bold text-gray-700 mb-1">Youtube Trailer URL</label>
                  <input type="text" value={movieFormData.TrailerURL} onChange={(e) => setMovieFormData({...movieFormData, TrailerURL: e.target.value})} placeholder="Nhập Link Youtube (VD: https://www.youtube.com/watch?v=...)" className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                <div className="col-span-2 bg-slate-50 p-4 rounded-xl border border-slate-200 shadow-sm">
                  <label className="block text-sm font-bold text-slate-800 mb-3 border-b border-slate-200 pb-2">
                    <Users size={16} className="inline-block mr-1 text-indigo-600"/> Dàn diễn viên (Cast)
                  </label>
                  
                  {/* CÔNG CỤ CHỌN NHANH DIỄN VIÊN (CÓ THANH TÌM KIẾM + AVATAR) */}
                  <div className="flex flex-col sm:flex-row gap-2 mb-3 relative">
                    
                    {/* CỘT 1: THANH TÌM KIẾM THÔNG MINH */}
                    <div className="relative flex-1">
                      <div className="flex items-center border border-slate-300 rounded-lg p-1.5 bg-white cursor-text transition focus-within:border-indigo-500 focus-within:ring-1 focus-within:ring-indigo-500">
                        {selectedActor ? (
                          // Nếu đã chọn diễn viên -> Hiện thẻ Tên + Hình ảnh
                          <div className="flex items-center gap-2 bg-indigo-50 px-2 py-1 rounded-md w-full">
                            <img 
                              src={
                                (() => {
                                  const path = selectedActor.Avatar;
                                  if (path && String(path) !== 'null' && path.trim() !== '') {
                                    if (path.startsWith('http')) return path;
                                    if (path.startsWith('/public') || path.startsWith('/avatars') || path.startsWith('/uploads')) {
                                      return `http://192.168.1.7:3000${path}`;
                                    }
                                    return `https://image.tmdb.org/t/p/w200${path.startsWith('/') ? path : '/' + path}`;
                                  }
                                  return `https://ui-avatars.com/api/?name=${encodeURIComponent(selectedActor.Name)}&background=e2e8f0&color=475569`;
                                })()
                              } 
                              className="w-6 h-6 rounded-full object-cover border border-slate-200 bg-white" 
                              alt="avatar"
                              onError={(e) => { 
                                if (!e.currentTarget.src.includes('ui-avatars')) {
                                  e.currentTarget.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(selectedActor.Name)}&background=e2e8f0&color=475569`;
                                }
                              }}
                            />
                            <span className="text-sm font-bold text-indigo-700 flex-1 truncate">{selectedActor.Name}</span>
                            <button type="button" className="text-slate-400 hover:text-red-500 p-1" onClick={(e) => { e.stopPropagation(); setSelectedActor(null); setActorSearch(''); setShowActorDropdown(false); }}><X size={14}/></button>
                          </div>
                        ) : (
                          // Nếu chưa chọn -> Hiện thanh gõ chữ tìm kiếm
                          <div className="flex items-center w-full px-2" onClick={() => setShowActorDropdown(true)}>
                            <Search size={16} className="text-slate-400 mr-2" />
                            <input 
                              type="text" 
                              placeholder="Gõ tên để tìm diễn viên..." 
                              className="w-full text-sm outline-none bg-transparent py-1"
                              value={actorSearch}
                              onChange={(e) => { setActorSearch(e.target.value); setShowActorDropdown(true); }}
                              onFocus={() => setShowActorDropdown(true)}
                            />
                          </div>
                        )}
                      </div>

                      {/* DANH SÁCH DROPDOWN GỢI Ý KẾT QUẢ TÌM KIẾM */}
                      {showActorDropdown && !selectedActor && (
                        <div className="absolute z-50 mt-1 w-full bg-white border border-slate-200 rounded-xl shadow-xl max-h-56 overflow-y-auto custom-scrollbar left-0">
                          <div className="sticky top-0 bg-slate-100 text-xs font-bold text-slate-500 px-3 py-2 border-b border-slate-200 z-10 flex justify-between items-center">
                            <span>KẾT QUẢ TÌM KIẾM</span>
                            <button type="button" onClick={() => setShowActorDropdown(false)} className="hover:text-red-500"><X size={14}/></button>
                          </div>
                          {actorsList.filter(a => a.Name.toLowerCase().includes(actorSearch.toLowerCase())).length > 0 ? (
                            actorsList.filter(a => a.Name.toLowerCase().includes(actorSearch.toLowerCase())).map(a => {
                              // Chế link ảnh
                              let imgUrl = '';
                              if (a.Avatar && String(a.Avatar) !== 'null' && a.Avatar.trim() !== '') {
                                let path = a.Avatar.trim();
                                if (path.startsWith('http')) {
                                  imgUrl = path; // Link ngoài (Web khác)
                                } else if (path.startsWith('/public') || path.startsWith('/avatars') || path.startsWith('/uploads')) {
                                  imgUrl = `http://192.168.1.7:3000${path}`; // Link local tải lên máy chủ
                                } else {
                                  imgUrl = `https://image.tmdb.org/t/p/w200${path.startsWith('/') ? path : '/' + path}`; // Link TMDB
                                }
                              } else {
                                imgUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(a.Name)}&background=e2e8f0&color=475569`;
                              }

                              return (
                                <div 
                                  key={a.ActorID} 
                                  className="flex items-center gap-3 p-2 hover:bg-indigo-50 cursor-pointer border-b border-slate-50 last:border-0 transition"
                                  onClick={() => { setSelectedActor(a); setShowActorDropdown(false); }}
                                >
                                  <img src={imgUrl} alt={a.Name} className="w-10 h-10 rounded-full object-cover border border-slate-200 bg-white" />
                                  <span className="text-sm font-bold text-slate-700">{a.Name}</span>
                                </div>
                              );
                            })
                          ) : (
                            <div className="p-4 text-sm text-slate-500 text-center flex flex-col items-center">
                              <span className="text-2xl mb-1">🔍</span>
                              Không tìm thấy diễn viên nào tên "{actorSearch}"
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                    
                    {/* CỘT 2: TÊN NHÂN VẬT */}
                    <input type="text" id="characterInput" placeholder="Tên nhân vật trong phim..." className="w-full sm:w-1/3 border border-slate-300 rounded-lg p-2 text-sm outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition" />
                    
                    {/* CỘT 3: NÚT THÊM */}
                    <button type="button" onClick={() => {
                      const charEl = document.getElementById('characterInput') as HTMLInputElement;
                      if(!selectedActor) return alert("Vui lòng tìm và chọn 1 diễn viên từ kho!");
                      
                      const actorData = {
                        name: selectedActor.Name,
                        profile_path: selectedActor.Avatar,
                        character: charEl.value || '' // Cho phép để trống tên nhân vật
                      };
                      
                      let currentCast: any[] = [];
                      try { 
                        currentCast = JSON.parse(movieFormData.cast || '[]'); 
                        if(!Array.isArray(currentCast)) currentCast = []; 
                      } catch(e) { currentCast = []; }
                      
                      // Chống thêm trùng lặp
                      if (currentCast.some(c => c.name === selectedActor.Name)) {
                        return alert(`Diễn viên ${selectedActor.Name} đã có mặt trong danh sách Cast rồi!`);
                      }

                      currentCast.push(actorData);
                      setMovieFormData({...movieFormData, cast: JSON.stringify(currentCast)});
                      
                      // Xóa Form sau khi thêm thành công
                      setSelectedActor(null); setActorSearch(''); charEl.value = '';
                    }} className="bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2 rounded-lg font-bold text-sm transition shadow-md whitespace-nowrap flex items-center justify-center gap-1.5">
                      <Plus size={16}/> Thêm
                    </button>
                  </div>

                  {/* DANH SÁCH DIỄN VIÊN ĐÃ CHỌN (GIAO DIỆN TAGS) */}
                  <div className="flex flex-wrap gap-2 mt-4 pt-3 border-t border-slate-200">
                    {(() => {
                      let currentCast: any[] = [];
                      try { 
                        currentCast = JSON.parse(movieFormData.cast || '[]'); 
                        if(!Array.isArray(currentCast)) currentCast = []; 
                      } catch(e) { currentCast = []; }
                      
                      if (currentCast.length === 0) return <span className="text-xs text-slate-400 italic">Chưa có diễn viên nào được thêm.</span>;

                      return currentCast.map((c, idx) => {
                        // 🚀 Thuật toán lấy ảnh siêu chuẩn cho từng diễn viên trong mảng JSON
                        let castImg = '';
                        if (c.profile_path && String(c.profile_path) !== 'null' && c.profile_path.trim() !== '') {
                          let path = c.profile_path.trim();
                          if (path.startsWith('http')) castImg = path;
                          else if (path.startsWith('/public') || path.startsWith('/avatars') || path.startsWith('/uploads')) castImg = `http://192.168.1.7:3000${path}`;
                          else castImg = `https://image.tmdb.org/t/p/w200${path.startsWith('/') ? path : '/' + path}`;
                        } else {
                          castImg = `https://ui-avatars.com/api/?name=${encodeURIComponent(c.name)}&background=e2e8f0&color=475569`;
                        }

                        return (
                          <div key={idx} className="flex items-center gap-2 bg-white border border-indigo-100 px-2 py-1.5 rounded-lg shadow-sm hover:shadow transition pr-1">
                            <img 
                              src={castImg} 
                              alt={c.name} 
                              className="w-7 h-7 rounded-md object-cover border border-slate-100 bg-slate-50"
                              onError={(e) => { 
                                if (!e.currentTarget.src.includes('ui-avatars')) {
                                  e.currentTarget.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(c.name)}&background=e2e8f0&color=475569`;
                                }
                              }}
                            />
                            <div className="flex flex-col">
                              <span className="text-xs font-bold text-indigo-700 leading-tight">{c.name}</span>
                              {c.character && <span className="text-[9px] text-slate-500 leading-tight truncate max-w-[80px]">{c.character}</span>}
                            </div>
                            <button 
                              type="button" 
                              className="ml-1 text-slate-300 hover:text-red-500 hover:bg-red-50 rounded-md p-1 transition"
                              onClick={() => {
                                // Xóa diễn viên này khỏi danh sách
                                const newCast = currentCast.filter((_, i) => i !== idx);
                                setMovieFormData({...movieFormData, cast: JSON.stringify(newCast)});
                              }}
                            >
                              <X size={14}/>
                            </button>
                          </div>
                        );
                      });
                    })()}
                  </div>
                </div>
                <div className="col-span-2">
                  <label className="block text-sm font-bold text-gray-700 mb-1">Mô tả phim (Overview)</label>
                  <textarea rows={4} value={movieFormData.overview} onChange={(e) => setMovieFormData({...movieFormData, overview: e.target.value})} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none resize-none focus:ring-2 focus:ring-indigo-500"></textarea>
                </div>
              </div>

              <div className="flex justify-end gap-3 mt-2 pt-4 border-t border-gray-200 sticky bottom-0 bg-white">
                <button type="button" onClick={() => setIsMovieModalOpen(false)} className="px-6 py-2 rounded-lg text-gray-700 font-bold bg-gray-100 hover:bg-gray-200 transition">Hủy</button>
                <button type="submit" disabled={loading} className="px-6 py-2 rounded-lg text-white font-bold bg-indigo-600 hover:bg-indigo-700 transition shadow-md">{loading ? 'Đang lưu...' : 'Lưu Phim'}</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* CÁC MODAL CÒN LẠI (GIỮ NGUYÊN) */}
      {isCinemaModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg flex flex-col overflow-hidden animate-fade-in"><div className="flex justify-between items-center p-5 border-b border-gray-100 bg-slate-50"><h3 className="text-xl font-bold text-slate-800 flex items-center gap-2"><Building2 className="text-indigo-600"/> {editingCinemaId ? "Cập Nhật Rạp" : "Thêm Rạp Mới"}</h3><button onClick={() => setIsCinemaModalOpen(false)} className="text-gray-400 hover:text-red-500 transition"><X size={24} /></button></div><form onSubmit={handleCinemaSubmit} className="p-6 flex flex-col gap-4 max-h-[75vh] overflow-y-auto custom-scrollbar"><div className="grid grid-cols-2 gap-x-4 gap-y-5"><div className="col-span-2 sm:col-span-1"><label className="block text-sm font-bold text-gray-700 mb-1">Tên Rạp</label><input type="text" name="name" value={cinemaFormData.name} onChange={(e) => setCinemaFormData({ ...cinemaFormData, name: e.target.value })} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none" required /></div><div className="col-span-2 sm:col-span-1"><label className="block text-sm font-bold text-gray-700 mb-1">Rating</label><div className="relative"><Star className="absolute left-3 top-1/2 transform -translate-y-1/2 text-amber-400" size={18}/><input type="number" step="0.1" min="0" max="5" name="rating" value={cinemaFormData.rating} onChange={(e) => setCinemaFormData({ ...cinemaFormData, rating: e.target.value })} className="w-full pl-10 pr-3 py-2.5 border border-gray-300 rounded-lg outline-none"/></div></div><div className="col-span-2"><label className="block text-sm font-bold text-gray-700 mb-1">Địa chỉ chi tiết</label><input type="text" name="address" value={cinemaFormData.address} onChange={(e) => setCinemaFormData({ ...cinemaFormData, address: e.target.value })} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none"/></div><div className="col-span-2 sm:col-span-1"><label className="block text-sm font-bold text-gray-700 mb-1">Thương hiệu</label><select name="brand_id" value={cinemaFormData.brand_id} onChange={(e) => setCinemaFormData({ ...cinemaFormData, brand_id: e.target.value })} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none bg-white"><option value="1">CGV Cinemas</option><option value="2">Lotte Cinema</option><option value="3">Galaxy Cinema</option><option value="4">BHD Star Cineplex</option><option value="5">Cinestar</option><option value="6">Mega GS</option><option value="7">DCine</option><option value="8">Beta Cinemas</option></select></div><div className="col-span-2 sm:col-span-1"><label className="block text-sm font-bold text-gray-700 mb-1">Thành phố</label><select name="city_id" value={cinemaFormData.city_id} onChange={(e) => setCinemaFormData({ ...cinemaFormData, city_id: e.target.value })} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none bg-white">{cities.length > 0 ? (cities.map(city => <option key={city.id} value={city.id}>{city.name}</option>)) : (<option value="1">TP. Hồ Chí Minh</option> )}</select></div><div className="col-span-2 sm:col-span-1"><label className="block text-sm font-bold text-gray-700 mb-1">Vĩ độ (Latitude)</label><input type="text" name="latitude" value={cinemaFormData.latitude} onChange={(e) => setCinemaFormData({ ...cinemaFormData, latitude: e.target.value })} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none" /></div><div className="col-span-2 sm:col-span-1"><label className="block text-sm font-bold text-gray-700 mb-1">Kinh độ (Longitude)</label><input type="text" name="longitude" value={cinemaFormData.longitude} onChange={(e) => setCinemaFormData({ ...cinemaFormData, longitude: e.target.value })} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none" /></div></div><div className="mt-4 pt-4 border-t border-gray-200 flex justify-end gap-3 sticky bottom-0 bg-white"><button type="button" onClick={() => setIsCinemaModalOpen(false)} className="px-6 py-2 rounded-lg text-gray-700 font-bold bg-gray-100 hover:bg-gray-200">Hủy</button><button type="submit" disabled={loading} className="px-6 py-2 rounded-lg text-white font-bold bg-indigo-600 hover:bg-indigo-700">{loading ? "Đang xử lý..." : "Lưu Rạp Chiếu"}</button></div></form></div>
        </div>
      )}

      {/* ✅ MODAL SƠ ĐỒ GHẾ VỚI BỌC THÉP TÀNG HÌNH GHẾ VÀ VÙNG TRUNG TÂM */}
      {isRoomEditorOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/90 backdrop-blur-md p-4">
          <div className="bg-slate-900 rounded-2xl shadow-[0_0_40px_rgba(0,0,0,0.5)] w-full max-w-[1400px] flex flex-col max-h-[95vh] overflow-hidden border border-slate-700 animate-fade-in">
            
            {/* HEADER MODAL */}
            <div className="flex justify-between items-center p-5 border-b border-slate-700 bg-slate-800">
              <h3 className="text-xl font-bold text-white flex items-center gap-2"><Map className="text-indigo-400" size={24} /> {editingRoomId ? "Cập Nhật Sơ Đồ Ghế" : "Tạo Phòng Mới & Vẽ Sơ Đồ"}</h3>
              <div className="flex items-center gap-4">
                <button form="masterRoomForm" type="submit" disabled={loading} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white px-5 py-2.5 rounded-lg font-bold transition shadow-lg">{loading ? 'Đang lưu...' : <><Save size={18} /> Lưu Hệ Thống</>}</button>
                <button onClick={() => setIsRoomEditorOpen(false)} className="text-slate-400 hover:text-white transition bg-slate-700 p-2.5 rounded-lg"><X size={24} /></button>
              </div>
            </div>

            {/* NỘI DUNG CHÍNH (CHIA 2 CỘT) */}
            <div className="flex flex-col lg:flex-row flex-1 overflow-hidden">
              
              {/* CỘT TRÁI: FORM THÔNG TIN */}
              <div className="w-full lg:w-[320px] shrink-0 p-6 border-r border-slate-700 bg-slate-800 overflow-y-auto flex flex-col gap-6">
                <form id="masterRoomForm" onSubmit={handleSaveRoomAndLayout} className="flex flex-col gap-4">
                  <div><label className="block text-sm font-bold text-slate-300 mb-1">Thuộc Rạp</label><select value={roomFormData.cinemaId} onChange={e => setRoomFormData({...roomFormData, cinemaId: e.target.value})} className="w-full bg-slate-700 text-white border border-slate-600 rounded-lg p-2.5 outline-none disabled:opacity-50"><option value="">-- Chọn Rạp --</option>{cinemas.map(c => <option key={c.id} value={c.id}>{c.name}</option>)}</select></div>
                  <div><label className="block text-sm font-bold text-slate-300 mb-1">Tên Phòng</label><input type="text" value={roomFormData.name} onChange={e => setRoomFormData({...roomFormData, name: e.target.value})} className="w-full bg-slate-700 text-white border border-slate-600 rounded-lg p-2.5 outline-none" placeholder="VD: Rạp 1" required/></div>
                  <div><label className="block text-sm font-bold text-slate-300 mb-1">Dọn rạp (Phút)</label><input type="number" value={roomFormData.bufferMinutes} onChange={e => setRoomFormData({...roomFormData, bufferMinutes: parseInt(e.target.value)})} className="w-full bg-slate-700 text-white border border-slate-600 rounded-lg p-2.5 outline-none" required/></div>
                  <div className="bg-indigo-900/40 border border-indigo-500/30 rounded-xl p-4 mt-2 flex flex-col items-center justify-center"><span className="text-indigo-300 text-sm font-bold uppercase tracking-wider mb-1">Sức Chứa Thực Tế</span><span className="text-4xl font-black text-white">{dynamicTotalSeats} <span className="text-lg text-indigo-400 font-medium">ghế</span></span><p className="text-xs text-indigo-200/60 mt-2 text-center">Tự động đếm dựa trên bản vẽ</p></div>
                  {/* 🚀 FORM ĐIỀU CHỈNH VÙNG TRUNG TÂM */}
                  <div className="bg-slate-700/50 border border-slate-600 rounded-xl p-4 mt-2">
                    <span className="text-emerald-400 text-sm font-bold uppercase tracking-wider mb-3 flex items-center gap-2"><Map size={16}/> Khung Trung Tâm</span>
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] text-slate-400 mb-1">Dòng bắt đầu</label>
                        <input type="number" min="0" max="25" value={centerZone.startRow} onChange={e => setCenterZone({...centerZone, startRow: Number(e.target.value)})} className="w-full bg-slate-800 text-white border border-slate-600 rounded p-1.5 text-sm outline-none text-center focus:border-emerald-500" />
                      </div>
                      <div>
                        <label className="block text-[11px] text-slate-400 mb-1">Cột bắt đầu</label>
                        <input type="number" min="0" max="50" value={centerZone.startCol} onChange={e => setCenterZone({...centerZone, startCol: Number(e.target.value)})} className="w-full bg-slate-800 text-white border border-slate-600 rounded p-1.5 text-sm outline-none text-center focus:border-emerald-500" />
                      </div>
                      <div>
                        <label className="block text-[11px] text-slate-400 mb-1">Cao (Số dòng)</label>
                        <input type="number" min="1" max="25" value={centerZone.rowCount} onChange={e => setCenterZone({...centerZone, rowCount: Number(e.target.value)})} className="w-full bg-slate-800 text-white border border-slate-600 rounded p-1.5 text-sm outline-none text-center focus:border-emerald-500" />
                      </div>
                      <div>
                        <label className="block text-[11px] text-slate-400 mb-1">Rộng (Số cột)</label>
                        <input type="number" min="1" max="50" value={centerZone.colCount} onChange={e => setCenterZone({...centerZone, colCount: Number(e.target.value)})} className="w-full bg-slate-800 text-white border border-slate-600 rounded p-1.5 text-sm outline-none text-center focus:border-emerald-500" />
                      </div>
                    </div>
                  </div>
                </form>
              </div>

              {/* CỘT PHẢI: KHU VỰC VẼ SƠ ĐỒ */}
              <div className="flex-1 min-w-0 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] bg-opacity-10 cursor-crosshair select-none flex flex-col" onMouseUp={() => setIsPainting(false)} onMouseLeave={() => setIsPainting(false)}>
                
                {/* THANH CÔNG CỤ (BRUSHES) */}
                <div className="bg-slate-800/90 border-b border-slate-700 p-4 flex flex-col sm:flex-row items-center justify-between gap-4 z-10 shadow-md">
                  <div className="text-emerald-400 text-sm font-bold flex items-center gap-2 whitespace-nowrap"><Paintbrush size={18} /> CÔNG CỤ VẼ</div>
                  <div className="flex flex-wrap items-center justify-center gap-2 flex-1">
                    {seatTypes.length > 0 ? (
                      seatTypes.map(st => (<button key={st.SeatTypeID} type="button" onClick={() => setActiveBrush(st.SeatTypeID)} className={`flex items-center gap-2 px-3 py-2 rounded-lg transition border text-sm font-medium ${activeBrush === st.SeatTypeID ? 'bg-slate-700 shadow-lg text-white border-white/50' : 'border-transparent text-slate-400 hover:bg-slate-700/50 hover:text-white'}`}><div className="h-4 rounded border border-black/20" style={{ backgroundColor: st.ColorCode, width: st.WidthSlots > 1 ? `${st.WidthSlots * 1.2}rem` : '1rem' }}></div> {st.TypeName}</button>))
                    ) : (
                      <>
                        <button type="button" onClick={() => setActiveBrush(1)} className={`flex items-center gap-2 px-3 py-2 rounded-lg transition border text-sm font-medium ${activeBrush === 1 ? 'bg-slate-700 shadow-lg text-white border-white/50' : 'border-transparent text-slate-400 hover:bg-slate-700/50 hover:text-white'}`}><div className="h-4 w-4 rounded border border-black/20" style={{ backgroundColor: '#e9d5ff' }}></div> Standard</button>
                        <button type="button" onClick={() => setActiveBrush(2)} className={`flex items-center gap-2 px-3 py-2 rounded-lg transition border text-sm font-medium ${activeBrush === 2 ? 'bg-slate-700 shadow-lg text-white border-white/50' : 'border-transparent text-slate-400 hover:bg-slate-700/50 hover:text-white'}`}><div className="h-4 w-4 rounded border border-black/20" style={{ backgroundColor: '#fda4af' }}></div> VIP</button>
                        <button type="button" onClick={() => setActiveBrush(3)} className={`flex items-center gap-2 px-3 py-2 rounded-lg transition border text-sm font-medium ${activeBrush === 3 ? 'bg-slate-700 shadow-lg text-white border-white/50' : 'border-transparent text-slate-400 hover:bg-slate-700/50 hover:text-white'}`}><div className="h-4 w-8 rounded border border-black/20" style={{ backgroundColor: '#d946ef' }}></div> Sweetbox</button>
                      </>
                    )}
                    <div className="w-px h-6 bg-slate-700 mx-2"></div>
                    <button type="button" onClick={() => setActiveBrush(0)} className={`flex items-center gap-2 px-4 py-2 rounded-lg transition border text-sm font-medium ${activeBrush === 0 ? 'bg-red-500/20 border-red-500 text-red-400 shadow-lg' : 'border-transparent text-slate-400 hover:bg-red-500/10 hover:text-red-400'}`}><Eraser size={16} /> Lối đi (Tẩy)</button>
                  </div>
                </div>

                {/* MÀN HÌNH CHÍNH VÀ LƯỚI GHẾ */}
                <div className="p-6 flex-1 flex flex-col overflow-hidden">
                  <div className="bg-slate-800/80 rounded-xl p-3 mb-6 text-center border border-slate-700 flex-shrink-0">
                    <p className="text-slate-300 text-sm font-medium animate-pulse">
                      💡 Hướng dẫn: Chọn cọ ở thanh công cụ phía trên, sau đó <b className="text-emerald-400">NHẤN GIỮ CHUỘT VÀ QUÉT</b> qua các ô bên dưới để vẽ ghế.
                    </p>
                  </div>
                  
                  <h4 className="text-slate-500 text-center font-bold tracking-[0.4em] mb-4 text-sm pointer-events-none">MÀN HÌNH CHÍNH</h4>
                  <div className="w-[60%] h-2 bg-gradient-to-r from-slate-900 via-blue-500 to-slate-900 mx-auto rounded-full shadow-[0_10px_30px_rgba(59,130,246,0.2)] border-t border-blue-400/50 pointer-events-none mb-12"></div>
                  
                  <div className="flex-1 overflow-auto custom-scrollbar flex items-start pb-16 pl-6">
                    
                    {/* 🚀 ĐÃ SỬA: Thêm w-max để container ôm khít mảng lưới, không bị trôi đi */}
                    <div className="relative inline-block px-10 py-6 w-max">

                      {/* 🌟 OVERLAY: KHUNG VÙNG TRUNG TÂM CHUẨN XÁC 100% */}
                      <div 
                        className="absolute border-[2px] border-emerald-500/80 rounded-xl z-20 pointer-events-none shadow-[0_0_15px_rgba(16,185,129,0.15)] bg-emerald-500/5 transition-all duration-300"
                        style={{
                          top: `calc(${centerZone.startRow} * 38px + 20px)`, 
                          left: `calc(${centerZone.startCol} * 38px + 74px)`, 
                          width: `calc(${centerZone.colCount} * 38px + 2px)`, 
                          height: `calc(${centerZone.rowCount} * 38px + 2px)`, 
                        }}
                      >
                        <div className="absolute -top-[12px] left-1/2 -translate-x-1/2 bg-slate-900 px-3 text-emerald-400 text-[10px] font-black uppercase tracking-widest rounded shadow-sm border border-emerald-500/50 whitespace-nowrap">
                          Vùng Trung Tâm
                        </div>
                      </div>

                      {/* 🌟 LƯỚI GHẾ */}
                      <div className="relative z-10 flex flex-col gap-1.5 w-max">
                        {editableLayout.map((row, rIndex) => (
                          // 🚀 ĐÃ SỬA: Đổi justify-center thành justify-start để neo chặt tọa độ vào góc trái
                          <div key={rIndex} className="flex gap-1.5 items-center justify-start">
                            <span className="text-slate-500 w-6 font-bold text-sm text-center mr-2 pointer-events-none">{row.rowLetter}</span>
                            {row.seats.map((seat, sIndex) => {
                              if (seat.type === -1) return null; 
                              const styleProps = getDynamicSeatStyles(seat.type); 
                              return (
                                <div 
                                  key={seat.id} 
                                  onMouseDown={() => { setIsPainting(true); applyBrushToSeat(rIndex, sIndex); }} 
                                  onMouseEnter={() => { if (isPainting) applyBrushToSeat(rIndex, sIndex); }} 
                                  className={styleProps.className} 
                                  style={styleProps.style}
                                >
                                  {!seat.isSpace && seat.id}
                                </div>
                              );
                            })}
                            <span className="text-slate-500 w-6 font-bold text-sm text-center ml-2 pointer-events-none">{row.rowLetter}</span>
                          </div>
                        ))}
                      </div>

                    </div>
                  </div>
                </div>

              </div>
            </div>
          </div>
        </div>
      )}

     {/* ========================================================= */}
      {/* MODAL THÊM / SỬA LOẠI GHẾ */}
      {/* ========================================================= */}
      {isSeatTypeModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 p-4">
          <div className="bg-white rounded-2xl w-full max-w-md overflow-hidden animate-fade-in">
            <div className="flex justify-between items-center p-5 border-b bg-slate-50">
              <h3 className="font-bold text-lg flex items-center gap-2"><Armchair className="text-indigo-600" /> {editingSeatTypeId ? "Sửa Loại Ghế" : "Thêm Loại Ghế"}</h3>
              <button onClick={() => setIsSeatTypeModalOpen(false)} className="text-gray-400 hover:text-red-500"><X/></button>
            </div>
            <form onSubmit={handleSeatTypeSubmit} className="p-6 flex flex-col gap-4">
              <div>
                <label className="block text-sm font-bold mb-1">Tên loại ghế</label>
                <input type="text" value={seatTypeFormData.TypeName} onChange={e=>setSeatTypeFormData({...seatTypeFormData, TypeName: e.target.value})} className="w-full border rounded-lg p-2.5 outline-none focus:border-indigo-500" placeholder="VD: Giường nằm" required/>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1">Độ rộng (Số ô lưới chiếm dụng)</label>
                <input type="number" min="1" max="5" value={seatTypeFormData.WidthSlots} onChange={e=>setSeatTypeFormData({...seatTypeFormData, WidthSlots: parseInt(e.target.value) || 1})} className="w-full border rounded-lg p-2.5 outline-none focus:border-indigo-500" required/>
                <p className="text-xs text-gray-500 mt-1">Gợi ý: Ghế thường=1, Sweetbox=2, Giường=3.</p>
              </div>
              <div>
                <label className="block text-sm font-bold mb-1">Mã Màu Giao Diện</label>
                <div className="flex items-center gap-3 border rounded-lg p-2">
                  <input type="color" value={seatTypeFormData.ColorCode} onChange={e=>setSeatTypeFormData({...seatTypeFormData, ColorCode: e.target.value})} className="w-10 h-10 border-0 outline-none cursor-pointer" required/>
                  <input type="text" value={seatTypeFormData.ColorCode} onChange={e=>setSeatTypeFormData({...seatTypeFormData, ColorCode: e.target.value})} className="flex-1 outline-none font-mono uppercase text-sm" />
                </div>
              </div>
              <button type="submit" disabled={loading} className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-3 rounded-lg mt-2 transition">{loading ? 'Đang lưu...' : 'Lưu Lại'}</button>
            </form>
          </div>
        </div>
      )}


      {/* ========================================================================= */}
      {/* ✅ MÀN HÌNH XEM CHI TIẾT DIỄN VIÊN VÀ CÁC PHIM ĐÃ ĐÓNG */}
      {/* ========================================================================= */}
      {viewingActor && activeTab === 'actors' && (
        <div className="animate-fade-in bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden pb-10">
          {/* Header Bìa Diễn Viên */}
          <div className="relative h-[250px] w-full bg-slate-900 flex items-center justify-center overflow-hidden">
            <div className="absolute inset-0 z-0 bg-gradient-to-r from-indigo-900 to-slate-900"></div>
            
            <div className="absolute top-6 left-6 z-20"><button onClick={() => setViewingActor(null)} className="flex items-center gap-2 bg-white/10 hover:bg-white/20 backdrop-blur-md text-white px-4 py-2 rounded-lg font-bold transition"><ArrowLeft size={20}/> Quay lại</button></div>
            <div className="absolute top-6 right-6 z-20"><button onClick={() => { setEditingActorId(viewingActor.ActorID); setActorFormData({ Name: viewingActor.Name, Avatar: viewingActor.Avatar || '' }); setActorAvatarFile(null); setIsActorModalOpen(true); }} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white px-5 py-2 rounded-lg font-bold transition shadow-lg"><Edit size={18}/> Sửa Hồ Sơ</button></div>

            <div className="relative z-10 w-full max-w-5xl px-8 flex items-end gap-8 translate-y-12">
              {(() => {
                let imgUrl = '';
                if (viewingActor.Avatar && String(viewingActor.Avatar) !== 'null' && viewingActor.Avatar.trim() !== '') {
                  let path = viewingActor.Avatar.trim();
                  if (path.startsWith('http')) imgUrl = path; 
                  else if (path.startsWith('/public') || path.startsWith('/avatars') || path.startsWith('/uploads')) imgUrl = `http://192.168.1.7:3000${path}`; 
                  else imgUrl = `https://image.tmdb.org/t/p/w300${path.startsWith('/') ? path : '/' + path}`; 
                } else { imgUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(viewingActor.Name)}&background=e2e8f0&color=475569&size=200`; }
                return <img src={imgUrl} alt="actor" className="w-40 h-40 object-cover rounded-full shadow-2xl border-4 border-white bg-slate-100" onError={(e) => { if (!e.currentTarget.src.includes('ui-avatars')) e.currentTarget.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(viewingActor.Name)}&background=e2e8f0&color=475569&size=200`; }}/>
              })()}
              
              <div className="pb-6">
                <h1 className="text-4xl font-black text-white mb-2 leading-tight drop-shadow-lg">{viewingActor.Name}</h1>
                <div className="flex items-center gap-3">
                  <span className="bg-emerald-500 text-white font-bold px-3 py-1 rounded-md text-sm shadow-sm flex items-center gap-1.5"><Clapperboard size={14}/> {movies.filter(m => (m.cast || m.castJson || '').includes(viewingActor.Name)).length} Bộ Phim</span>
                  <span className="bg-white/20 backdrop-blur-md text-white font-medium px-3 py-1 rounded-md text-sm border border-white/10">Mã định danh: #{viewingActor.ActorID}</span>
                </div>
              </div>
            </div>
          </div>

          {/* Danh sách phim đã tham gia */}
          <div className="max-w-5xl mx-auto px-8 mt-24">
            <h3 className="text-xl font-bold text-slate-800 mb-6 flex items-center gap-2 border-b border-slate-100 pb-3"><Film className="text-indigo-600"/> Các bộ phim đã tham gia</h3>
            
            <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-6">
              {movies.filter(m => (m.cast || m.castJson || '').includes(viewingActor.Name)).length > 0 ? (
                movies.filter(m => (m.cast || m.castJson || '').includes(viewingActor.Name)).map(movie => {
                  
                  // Chế thuật toán lấy Vai Diễn ra để hiển thị luôn cho ngầu
                  let characterName = '';
                  try {
                    const castArr = JSON.parse(movie.cast || movie.castJson || '[]');
                    const foundObj = castArr.find((c: any) => c.name === viewingActor.Name);
                    if (foundObj && foundObj.character) characterName = foundObj.character;
                  } catch (e) {}

                  return (
                    <div key={movie.id} className="bg-white rounded-xl shadow-sm hover:shadow-lg transition-all border border-gray-100 overflow-hidden flex flex-col group cursor-pointer" onClick={() => { setActiveTab('movies'); setViewingActor(null); setViewingMovie(movie); }}>
                      <div className="aspect-[2/3] w-full overflow-hidden bg-gray-100 relative">
                        <img src={getImageUrl(movie.posterUrl || movie.poster_path)} alt={movie.title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500" onError={(e) => { e.currentTarget.src = 'https://via.placeholder.com/300x450?text=No+Poster'; }}/>
                        <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition flex items-center justify-center"><button className="bg-white text-slate-900 font-bold px-4 py-2 rounded-lg text-sm shadow-xl">Xem Phim</button></div>
                      </div>
                      <div className="p-3 flex flex-col items-center">
                        <h4 className="font-bold text-slate-800 text-sm leading-tight mb-1 text-center line-clamp-1 w-full" title={movie.title}>{movie.title}</h4>
                        <span className="text-[11px] font-bold text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded w-max line-clamp-1" title={characterName || 'Vai diễn'}>{characterName ? `Vai: ${characterName}` : 'Tham gia diễn xuất'}</span>
                      </div>
                    </div>
                  );
                })
              ) : (
                <div className="col-span-full py-12 text-center text-slate-500 font-medium bg-slate-50 rounded-xl border border-dashed border-slate-200">
                  <Clapperboard size={40} className="mx-auto text-slate-300 mb-3" />
                  Diễn viên này chưa có mặt trong bộ phim nào của hệ thống.
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 4 & 5: QUẢN LÝ THỂ LOẠI & DIỄN VIÊN */}
      {/* ========================================================================= */}
      {!viewingMovie && activeTab === 'genres' && (
        <div className="animate-fade-in">
          <div className="flex justify-between items-center mb-6 gap-4 bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <h2 className="text-xl font-bold text-slate-800 flex items-center gap-2"><Tags className="text-indigo-600" /> Quản lý Thể Loại Phim</h2>
            <button onClick={() => { setEditingGenreId(null); setGenreFormData({ GenreName: '' }); setIsGenreModalOpen(true); }} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2.5 px-5 rounded-xl shadow-md transition-all hover:-translate-y-0.5"><Plus size={20} /> Thêm Thể Loại</button>
          </div>

          {/* 🚀 CHIA LAYOUT LÀM 2 CỘT */}
          <div className="flex flex-col lg:flex-row gap-6">
            
            {/* CỘT TRÁI: BẢNG DATA (Chiếm 2/3) */}
            <div className="flex-[2] bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden self-start">
              <table className="w-full text-left border-collapse">
                <thead className="bg-slate-800 text-white">
                  <tr>
                    <th className="p-4 text-sm font-semibold w-24">ID</th>
                    <th className="p-4 text-sm font-semibold">Tên Thể Loại</th>
                    <th className="p-4 text-sm font-semibold text-center w-32">Thao Tác</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200">
                  {genresList.map((g) => (
                    <tr key={g.GenreID} className="hover:bg-indigo-50/50 transition-colors">
                      <td className="p-4 text-gray-500 font-mono text-sm">#{g.GenreID}</td>
                      <td className="p-4 font-bold text-gray-800">{g.GenreName}</td>
                      <td className="p-4 text-center">
                        <div className="flex items-center justify-center gap-2">
                          <button onClick={() => { setEditingGenreId(g.GenreID); setGenreFormData({ GenreName: g.GenreName }); setIsGenreModalOpen(true); }} className="p-2 bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white rounded-lg transition-colors shadow-sm"><Edit size={16}/></button>
                          <button onClick={() => handleDeleteGenre(g.GenreID, g.GenreName)} className="p-2 bg-red-50 text-red-600 hover:bg-red-600 hover:text-white rounded-lg transition-colors shadow-sm"><Trash2 size={16}/></button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {genresList.length === 0 && <tr><td colSpan={3} className="p-8 text-center text-gray-500 font-medium">Chưa có thể loại nào được thiết lập.</td></tr>}
                </tbody>
              </table>
            </div>

            {/* 🚀 CỘT PHẢI: WIDGET THỐNG KÊ (Lấp đầy khoảng trống cực xịn) */}
            <div className="flex-[1] flex flex-col gap-6">
               
               {/* Thẻ Thống kê tổng */}
               <div className="bg-gradient-to-br from-indigo-600 to-purple-700 rounded-xl p-6 shadow-md text-white relative overflow-hidden">
                  <div className="absolute top-0 right-0 -mr-6 -mt-6 opacity-10"><Tags size={140} /></div>
                  <h3 className="text-indigo-200 font-bold text-xs mb-1 uppercase tracking-wider relative z-10">Tổng Số Lượng Thể Loại</h3>
                  <div className="text-5xl font-black mb-3 relative z-10">{genresList.length}</div>
                  <p className="text-sm text-indigo-100 leading-relaxed relative z-10">Hệ thống đang hỗ trợ phân loại cho tổng cộng <b className="text-white bg-white/20 px-1.5 py-0.5 rounded">{movies.length}</b> bộ phim trong kho dữ liệu.</p>
               </div>

               {/* Thẻ Top Thể loại phổ biến */}
               <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-5">
                  <h3 className="text-slate-800 font-bold text-sm mb-4 flex items-center gap-2 border-b border-slate-100 pb-3"><Star size={18} className="text-amber-500"/> Top Thể Loại Phổ Biến Nhất</h3>
                  <div className="flex flex-col gap-3">
                     {(() => {
                        // Thuật toán: Quét qua kho phim và đếm số lượng phim của từng thể loại
                        const stats = genresList.map(g => {
                           const count = movies.filter(m => (m.genres || m.genre || '').includes(g.GenreName)).length;
                           return { name: g.GenreName, count };
                        }).sort((a,b) => b.count - a.count).slice(0, 5); // Lấy top 5

                        if(stats.length === 0 || movies.length === 0) return <div className="text-sm text-slate-500 text-center py-6 bg-slate-50 rounded-lg border border-dashed border-slate-200">Chưa có dữ liệu thống kê</div>;

                        return stats.map((s, idx) => (
                           <div key={idx} className="flex justify-between items-center bg-slate-50 p-2.5 rounded-lg border border-slate-100 hover:bg-indigo-50/50 hover:border-indigo-100 transition-colors group">
                              <div className="flex items-center gap-3">
                                 <span className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-black shadow-sm ${idx === 0 ? 'bg-gradient-to-br from-amber-300 to-amber-500 text-white' : idx === 1 ? 'bg-gradient-to-br from-slate-300 to-slate-400 text-white' : idx === 2 ? 'bg-gradient-to-br from-orange-300 to-orange-500 text-white' : 'bg-white text-slate-500 border border-slate-200'}`}>#{idx + 1}</span>
                                 <span className="text-sm font-bold text-slate-700 group-hover:text-indigo-700 transition-colors">{s.name}</span>
                              </div>
                              <span className="text-[11px] font-bold bg-indigo-100 text-indigo-700 px-2.5 py-1 rounded-md">{s.count} phim</span>
                           </div>
                        ));
                     })()}
                  </div>
               </div>
               
            </div>
          </div>
        </div>
      )}

      {!viewingMovie && activeTab === 'actors' && (
        <div className="animate-fade-in">
          {/* HEADER: THANH TÌM KIẾM, BỘ LỌC & NÚT THÊM */}
          <div className="flex flex-col md:flex-row justify-between items-center mb-6 gap-4 bg-white p-4 rounded-xl shadow-sm border border-gray-100">
            <h2 className="text-xl font-bold text-slate-800 flex items-center gap-2 w-full md:w-auto"><Users className="text-indigo-600" /> Danh sách Diễn Viên</h2>
            
            <div className="flex flex-col sm:flex-row items-center gap-3 w-full md:flex-1 justify-end">
              {/* Ô TÌM KIẾM TÊN */}
              <div className="relative w-full sm:max-w-xs flex-1">
                <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
                <input type="text" placeholder="Tìm tên diễn viên..." value={actorListSearch} onChange={(e) => setActorListSearch(e.target.value)} className="w-full pl-12 pr-4 py-2.5 border border-gray-200 rounded-xl focus:ring-2 focus:ring-indigo-500 outline-none text-sm bg-gray-50 focus:bg-white transition" />
                {actorListSearch && <X className="absolute right-4 top-1/2 transform -translate-y-1/2 text-gray-400 cursor-pointer hover:text-red-500" size={18} onClick={() => setActorListSearch('')} />}
              </div>

              {/* 🚀 ĐÃ THÊM: Ô CHỌN BỘ LỌC */}
              <div className="relative w-full sm:w-48 hidden sm:block">
                <Filter className="absolute left-4 top-1/2 transform -translate-y-1/2 text-indigo-500" size={18} />
                <select value={actorSortOrder} onChange={(e) => setActorSortOrder(e.target.value)} className="w-full pl-12 pr-4 py-2.5 border border-gray-200 rounded-xl outline-none font-bold text-indigo-900 bg-gray-50 focus:bg-white text-sm transition cursor-pointer">
                  <option value="ALL">Mặc định</option>
                  <option value="MOST_MOVIES">Nhiều phim nhất</option>
                  <option value="LEAST_MOVIES">Ít phim nhất</option>
                </select>
              </div>
            </div>

            <button onClick={() => { setEditingActorId(null); setActorFormData({ Name: '', Avatar: '' }); setActorAvatarFile(null); setIsActorModalOpen(true); }} className="w-full md:w-auto flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold py-2.5 px-5 rounded-xl shadow-md whitespace-nowrap"><Plus size={20} /> Thêm Diễn Viên</button>
          </div>

          {/* LƯỚI DIỄN VIÊN (CÓ TÍCH HỢP BỘ LỌC TÌM KIẾM) */}
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-5">
            {currentActorsSlice.map((actor) => {
              
              let imgUrl = '';
              if (actor.Avatar && String(actor.Avatar) !== 'null' && actor.Avatar.trim() !== '') {
                let path = actor.Avatar.trim();
                if (path.startsWith('http')) {
                  imgUrl = path; 
                } else if (path.startsWith('/public') || path.startsWith('/avatars') || path.startsWith('/uploads')) {
                  imgUrl = `http://192.168.1.7:3000${path}`; 
                } else {
                  imgUrl = `https://image.tmdb.org/t/p/w200${path.startsWith('/') ? path : '/' + path}`; 
                }
              } else {
                imgUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(actor.Name)}&background=e2e8f0&color=475569&size=150`;
              }

              const joinedMovies = movies.filter(m => {
                const castStr = m.cast || m.castJson || '';
                return castStr.includes(actor.Name);
              });

              return (
                <div 
                  key={actor.ActorID} 
                  onClick={() => setViewingActor(actor)} // 🚀 GẮN SỰ KIỆN XEM CHI TIẾT
                  className="bg-white rounded-xl shadow-sm border border-gray-200 p-4 flex flex-col items-center group relative overflow-hidden hover:shadow-lg hover:-translate-y-1 transition-all duration-300 cursor-pointer"
                >
                  <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition flex flex-col gap-1.5 z-10">
                    <button onClick={(e) => { e.stopPropagation(); setEditingActorId(actor.ActorID); setActorFormData({ Name: actor.Name, Avatar: actor.Avatar || '' }); setActorAvatarFile(null); setIsActorModalOpen(true); }} className="bg-blue-500 text-white p-2 rounded-full shadow-md hover:bg-blue-600"><Edit size={14}/></button>
                    <button onClick={(e) => { e.stopPropagation(); handleDeleteActor(actor.ActorID, actor.Name); }} className="bg-red-500 text-white p-2 rounded-full shadow-md hover:bg-red-600"><Trash2 size={14}/></button>
                  </div>
                  
                  <img src={imgUrl} alt={actor.Name} className="w-20 h-20 sm:w-24 sm:h-24 object-cover rounded-full shadow-inner border-4 border-slate-50 mb-3 bg-slate-100" onError={(e) => { if (!e.currentTarget.src.includes('ui-avatars')) { e.currentTarget.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(actor.Name)}&background=e2e8f0&color=475569&size=150`; } }} />
                  <h4 className="text-sm font-bold text-slate-800 text-center line-clamp-1 w-full mb-1" title={actor.Name}>{actor.Name}</h4>
                  
                  <div className="mt-auto flex flex-col items-center w-full">
                    <span className={`text-[11px] font-bold px-2.5 py-1 rounded-full mb-2.5 w-max ${joinedMovies.length > 0 ? 'bg-indigo-50 text-indigo-700 border border-indigo-100' : 'bg-gray-100 text-gray-500'}`}>
                      {joinedMovies.length > 0 ? `Đóng ${joinedMovies.length} phim` : 'Chưa đóng phim'}
                    </span>
                    {joinedMovies.length > 0 && (<div className="w-full text-[11px] text-slate-500 text-center line-clamp-2 border-t border-slate-100 pt-2 font-medium leading-relaxed" title={joinedMovies.map(m => m.title).join(', ')}>{joinedMovies.map(m => m.title).join(' • ')}</div>)}
                  </div>
                </div>
              );
            })}
            
            {/* Nếu tìm không thấy ai */}
            {actorsList.filter(a => a.Name.toLowerCase().includes(actorListSearch.toLowerCase())).length === 0 && (
               <div className="col-span-full py-10 text-center text-slate-500">Không tìm thấy diễn viên nào khớp với từ khóa "{actorListSearch}"</div>
            )}
          </div>
          {/* 🚀 ĐÃ THÊM: THANH PHÂN TRANG DIỄN VIÊN */}
          {totalActorPages > 1 && (
            <div className="flex justify-center items-center gap-2 mt-8">
              <button 
                onClick={() => setCurrentActorPage(p => Math.max(1, p - 1))} 
                disabled={currentActorPage === 1}
                className="px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-gray-500 hover:bg-indigo-50 hover:text-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed transition font-semibold"
              >
                Trước
              </button>
              
              <span className="px-4 py-1.5 text-sm font-bold text-slate-700 bg-white border border-gray-200 rounded-lg shadow-sm">
                Trang {currentActorPage} / {totalActorPages}
              </span>

              <button 
                onClick={() => setCurrentActorPage(p => Math.min(totalActorPages, p + 1))} 
                disabled={currentActorPage === totalActorPages}
                className="px-3 py-1.5 rounded-lg bg-white border border-gray-200 text-gray-500 hover:bg-indigo-50 hover:text-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed transition font-semibold"
              >
                Sau
              </button>
            </div>
          )}
        </div>
      )}

      {/* MODAL THỂ LOẠI & DIỄN VIÊN */}
      {isGenreModalOpen && (<div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 p-4"><div className="bg-white rounded-2xl w-full max-w-sm overflow-hidden animate-fade-in"><div className="flex justify-between items-center p-4 border-b bg-slate-50"><h3 className="font-bold flex items-center gap-2"><Tags className="text-indigo-600"/> {editingGenreId ? "Sửa Thể Loại" : "Thêm Thể Loại"}</h3><button onClick={() => setIsGenreModalOpen(false)}><X/></button></div><form onSubmit={handleGenreSubmit} className="p-5 flex flex-col gap-4"><div><label className="block text-sm font-bold mb-1">Tên Thể Loại</label><input type="text" value={genreFormData.GenreName} onChange={e=>setGenreFormData({GenreName: e.target.value})} className="w-full border rounded-lg p-2.5 outline-none focus:border-indigo-500" required/></div><button type="submit" disabled={loading} className="w-full bg-indigo-600 text-white font-bold py-2.5 rounded-lg">{loading ? 'Đang lưu...' : 'Lưu Lại'}</button></form></div></div>)}
      {isActorModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 p-4 backdrop-blur-sm">
          <div className="bg-white rounded-2xl w-full max-w-md overflow-hidden animate-fade-in shadow-2xl">
            <div className="flex justify-between items-center p-4 border-b bg-slate-50">
              <h3 className="font-bold flex items-center gap-2"><Users className="text-indigo-600"/> {editingActorId ? "Sửa Diễn Viên" : "Thêm Diễn Viên"}</h3>
              <button onClick={() => setIsActorModalOpen(false)} className="text-gray-400 hover:text-red-500 transition"><X/></button>
            </div>
            <form onSubmit={handleActorSubmit} className="p-5 flex flex-col gap-5">
              <div>
                <label className="block text-sm font-bold text-gray-700 mb-1">Tên Diễn Viên</label>
                <input type="text" value={actorFormData.Name} onChange={e=>setActorFormData({...actorFormData, Name: e.target.value})} className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-indigo-500" required/>
              </div>
              
              {/* KHU VỰC THÊM HÌNH ẢNH MỚI */}
              <div className="bg-slate-50 p-4 rounded-xl border border-gray-200">
                <label className="block text-sm font-bold text-gray-700 mb-2 border-b pb-2">Ảnh Đại Diện (Avatar)</label>
                <div className="flex flex-col gap-3">
                  <div className="flex flex-col gap-1">
                    <span className="text-xs font-semibold text-slate-500">Link URL (Từ Web hoặc TMDB):</span>
                    <input type="text" value={actorFormData.Avatar} onChange={e=>setActorFormData({...actorFormData, Avatar: e.target.value})} placeholder="https://..." className="w-full border border-gray-300 rounded-lg p-2 text-sm outline-none bg-white focus:border-indigo-500" disabled={actorAvatarFile !== null}/>
                  </div>
                  <div className="flex items-center gap-2">
                    <label className="flex-1 flex items-center justify-center gap-2 border border-dashed border-indigo-300 bg-indigo-50 text-indigo-700 rounded-lg p-2 cursor-pointer hover:bg-indigo-100 transition text-sm font-medium">
                      <UploadCloud size={18} /> {actorAvatarFile ? "Đã chọn file tải lên" : "Tải ảnh từ máy..."}
                      <input type="file" accept="image/*" className="hidden" onChange={(e) => setActorAvatarFile(e.target.files?.[0] || null)} />
                    </label>
                    {actorAvatarFile && <button type="button" onClick={() => setActorAvatarFile(null)} className="p-2 text-red-500 hover:bg-red-50 rounded-lg bg-white shadow-sm border border-gray-200"><X size={18}/></button>}
                  </div>
                </div>
              </div>

              <button type="submit" disabled={loading} className="w-full bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-3 rounded-lg shadow-md transition">
                {loading ? 'Đang lưu...' : 'Lưu Lại'}
              </button>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}