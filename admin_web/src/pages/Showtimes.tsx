import React, { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2';
import { Calendar as CalendarIcon, Plus, CheckCircle, Clock, MapPin, MonitorPlay, X, Save, DollarSign, Search, Trash2, ChevronDown, Film, Ticket, ChevronLeft, ChevronRight } from 'lucide-react';

import DatePicker, { registerLocale } from 'react-datepicker';
import 'react-datepicker/dist/react-datepicker.css';
import { vi } from 'date-fns/locale/vi';

registerLocale('vi', vi);

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

const Showtimes = () => {
  const [cinemas, setCinemas] = useState<any[]>([]);
  const [rooms, setRooms] = useState<any[]>([]);
  const [movies, setMovies] = useState<any[]>([]);
  const [showtimes, setShowtimes] = useState<any[]>([]);

  const [selectedCinema, setSelectedCinema] = useState<number | null>(null);
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingShowtimeId, setEditingShowtimeId] = useState<number | null>(null);
  const [newShowtime, setNewShowtime] = useState({ movieId: '', roomId: '', time: '09:00', format: '2D Phụ đề', price: 90000 });
  
  const [searchMovieTerm, setSearchMovieTerm] = useState('');
  const [showMovieDropdown, setShowMovieDropdown] = useState(false);
  const movieDropdownRef = useRef<HTMLDivElement>(null);

  const [searchCinemaTerm, setSearchCinemaTerm] = useState('');
  const [showCinemaDropdown, setShowCinemaDropdown] = useState(false);
  const cinemaDropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const fetchInitData = async () => {
      try {
        const res = await axios.get('http://192.168.1.7:3000/api/admin/showtimes/init-data');
        setCinemas(res.data.cinemas);
        setRooms(res.data.rooms);
        setMovies(res.data.movies);
        if (res.data.cinemas.length > 0) {
          setSelectedCinema(res.data.cinemas[0].id);
          setSearchCinemaTerm(res.data.cinemas[0].name || res.data.cinemas[0].Name);
        }
      } catch (error) { 
        Toast.fire({ icon: 'error', title: 'Lỗi tải dữ liệu ban đầu!' });
      }
    };
    fetchInitData();
  }, []);

  const fetchShowtimes = async () => {
    if (!selectedCinema) return;
    try {
      const res = await axios.get(`http://192.168.1.7:3000/api/admin/showtimes/list?cinemaId=${selectedCinema}&date=${selectedDate}`);
      setShowtimes(res.data);
    } catch (error) { console.error(error); }
  };

  useEffect(() => { fetchShowtimes(); }, [selectedCinema, selectedDate]);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (movieDropdownRef.current && !movieDropdownRef.current.contains(event.target as Node)) setShowMovieDropdown(false);
      if (cinemaDropdownRef.current && !cinemaDropdownRef.current.contains(event.target as Node)) {
        setShowCinemaDropdown(false);
        const currentCin = cinemas.find(c => c.id === selectedCinema);
        if (currentCin) setSearchCinemaTerm(currentCin.name || currentCin.Name);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [selectedCinema, cinemas]);

  const filteredRooms = rooms.filter(r => r.CinemaID === selectedCinema);
  const filteredCinemas = cinemas.filter(c => (c.name || c.Name).toLowerCase().includes(searchCinemaTerm.toLowerCase()));
  const filteredSearchMovies = movies.filter(m => m.title.toLowerCase().includes(searchMovieTerm.toLowerCase()));

  const getSafePosterUrl = (m: any) => {
    const path = m.poster_path || m.posterUrl;
    if (!path || String(path) === 'null' || String(path).trim() === '') {
      return 'https://via.placeholder.com/150x225?text=No+Poster';
    }
    const strPath = String(path);
    if (strPath.startsWith('http')) return strPath;
    if (strPath.startsWith('/uploads') || strPath.startsWith('/public')) return `http://192.168.1.7:3000${strPath}`;
    return `https://image.tmdb.org/t/p/w200${strPath.startsWith('/') ? strPath : '/' + strPath}`;
  };

  // KÉO DÀI TIMELINE ĐẾN 4H SÁNG HÔM SAU
  const START_HOUR = 8; 
  const TOTAL_HOURS = 20; 
  const TOTAL_MINUTES = TOTAL_HOURS * 60;

  const calculateLeftOffset = (timeStr: string) => {
    if(!timeStr) return 0;
    let [hours, minutes] = timeStr.split(':').map(Number);
    
    if (hours < 6) {
      hours += 24; 
    }

    const timeInMinutes = (hours * 60) + minutes;
    const startInMinutes = START_HOUR * 60;
    
    if (timeInMinutes < startInMinutes) return 0;
    return ((timeInMinutes - startInMinutes) / TOTAL_MINUTES) * 100;
  };

  const calculateWidth = (durationMinutes: number) => {
    if(!durationMinutes || isNaN(durationMinutes)) return 10;
    return (durationMinutes / TOTAL_MINUTES) * 100;
  };

  const timeMarkers = Array.from({ length: TOTAL_HOURS + 1 }, (_, i) => START_HOUR + i);

  const getSelectedDateObject = () => {
    const [y, m, d] = selectedDate.split('-').map(Number);
    return new Date(y, m - 1, d);
  };

  const handleDateChange = (date: Date | null) => {
    if (date) {
      const y = date.getFullYear();
      const m = String(date.getMonth() + 1).padStart(2, '0');
      const d = String(date.getDate()).padStart(2, '0');
      setSelectedDate(`${y}-${m}-${d}`);
    }
  };

  const openAddModal = () => {
    setEditingShowtimeId(null);
    setNewShowtime({ movieId: '', roomId: '', time: '09:00', format: '2D Phụ đề', price: 90000 });
    setSearchMovieTerm(''); 
    setIsModalOpen(true);
  };

  const openEditModal = (st: any) => {
    setEditingShowtimeId(st.id);
    setSearchMovieTerm(st.movie); 
    const matchedMovie = movies.find(m => m.title === st.movie);
    
    setNewShowtime({
      movieId: st.movieId?.toString() || (matchedMovie ? matchedMovie.id.toString() : ''),
      roomId: st.roomId?.toString() || '',
      time: st.startTime, 
      format: st.format || '2D Phụ đề',
      price: st.price || 90000 
    });
    setIsModalOpen(true);
  };

  const handleSaveShowtime = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newShowtime.movieId || !newShowtime.roomId) {
      Swal.fire('Thiếu thông tin', 'Vui lòng chọn phim và phòng chiếu!', 'warning');
      return;
    }
    try {
      const payload = { ...newShowtime, date: selectedDate };
      let res;
      if (editingShowtimeId) {
        res = await axios.put(`http://192.168.1.7:3000/api/admin/showtimes/${editingShowtimeId}`, payload);
      } else {
        res = await axios.post('http://192.168.1.7:3000/api/admin/showtimes', payload);
      }
      
      Toast.fire({ icon: 'success', title: res.data.message });
      setIsModalOpen(false);
      fetchShowtimes(); 
    } catch (error: any) {
      Swal.fire('Lỗi', error.response?.data?.error || "Lỗi lưu lịch chiếu!", 'error');
    }
  };

  const handleDeleteShowtime = async () => {
    if (!editingShowtimeId) return;
    Swal.fire({
      title: 'Xóa suất chiếu này?',
      text: "Bạn không thể hoàn tác hành động này!",
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#ef4444',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Đồng ý Xóa',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          const res = await axios.delete(`http://192.168.1.7:3000/api/admin/showtimes/${editingShowtimeId}`);
          Swal.fire('Đã xóa!', res.data.message, 'success');
          setIsModalOpen(false);
          fetchShowtimes(); 
        } catch (error: any) {
          Swal.fire('Lỗi', error.response?.data?.error || "Lỗi xóa lịch chiếu!", 'error');
        }
      }
    });
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] flex flex-col gap-6 animate-[fade-in_0.3s_ease-out] w-full min-w-0">
      
      <div className="bg-white rounded-2xl p-4 flex flex-col lg:flex-row justify-between items-start lg:items-center gap-4 border border-slate-200 shadow-sm relative z-20">
        
        <div className="flex flex-col sm:flex-row gap-4 w-full lg:w-auto">
          
          <div className="relative w-full sm:w-72" ref={cinemaDropdownRef}>
            <div className="flex items-center gap-3 bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 cursor-text focus-within:border-blue-500 focus-within:ring-2 focus-within:ring-blue-100 transition-all">
              <MapPin size={20} className="text-blue-500 shrink-0" />
              <input 
                type="text"
                placeholder="Tìm tên rạp..."
                value={searchCinemaTerm}
                onChange={(e) => {
                  setSearchCinemaTerm(e.target.value);
                  setShowCinemaDropdown(true);
                }}
                onFocus={(e) => {
                  e.target.select();
                  setShowCinemaDropdown(true);
                }}
                className="w-full bg-transparent border-none outline-none text-sm font-bold text-slate-800 placeholder-slate-400"
              />
              {searchCinemaTerm ? (
                <X 
                  size={16} 
                  className="text-slate-400 hover:text-red-500 cursor-pointer shrink-0 transition-colors" 
                  onClick={() => {
                    setSearchCinemaTerm('');
                    setShowCinemaDropdown(true);
                  }} 
                />
              ) : (
                <ChevronDown size={18} className="text-slate-400 shrink-0" />
              )}
            </div>

            {showCinemaDropdown && (
              <div className="absolute top-[110%] left-0 right-0 bg-white border border-slate-200 rounded-xl shadow-xl max-h-[300px] overflow-y-auto z-50 animate-[slide-in-down_0.2s_ease-out]">
                {filteredCinemas.length > 0 ? (
                  filteredCinemas.map(c => (
                    <div 
                      key={c.id}
                      onMouseDown={() => {
                        setSelectedCinema(c.id);
                        setSearchCinemaTerm(c.name || c.Name);
                        setShowCinemaDropdown(false);
                      }}
                      className="px-4 py-3 cursor-pointer border-b border-slate-50 hover:bg-blue-50 text-sm font-semibold text-slate-700 hover:text-blue-700 transition-colors"
                    >
                      {c.name || c.Name}
                    </div>
                  ))
                ) : (
                  <div className="p-4 text-center text-sm text-slate-400">Không tìm thấy rạp phù hợp</div>
                )}
              </div>
            )}
          </div>

          <div className="flex items-center gap-3 bg-blue-50 hover:bg-blue-100 px-4 py-2 rounded-xl border border-blue-200 w-full sm:w-auto transition-colors focus-within:ring-2 focus-within:ring-blue-200 group">
            <CalendarIcon size={18} className="text-blue-600 shrink-0" />
            <DatePicker
              selected={getSelectedDateObject()}
              onChange={handleDateChange}
              dateFormat="dd/MM/yyyy"
              locale="vi"
              onChangeRaw={(e: any) => e.preventDefault()}
              onKeyDown={(e: any) => e.preventDefault()}
              className="caret-transparent bg-transparent border-none outline-none font-bold text-sm text-blue-800 cursor-pointer w-[100px] text-center"
              
              renderCustomHeader={({
                date,
                changeYear,
                changeMonth,
                decreaseMonth,
                increaseMonth,
                prevMonthButtonDisabled,
                nextMonthButtonDisabled,
              }) => {
                const years = Array.from({ length: 20 }, (_, i) => new Date().getFullYear() - 10 + i);
                const months = ["Tháng 1", "Tháng 2", "Tháng 3", "Tháng 4", "Tháng 5", "Tháng 6", "Tháng 7", "Tháng 8", "Tháng 9", "Tháng 10", "Tháng 11", "Tháng 12"];

                return (
                  <div className="flex justify-between items-center px-3 py-2 bg-slate-50/80 backdrop-blur-sm border-b border-slate-200 rounded-t-[15px]">
                    
                    <button 
                      onClick={decreaseMonth} 
                      disabled={prevMonthButtonDisabled} 
                      className="p-1.5 rounded-lg text-slate-400 hover:bg-white hover:text-blue-600 hover:shadow-sm transition-all disabled:opacity-30 disabled:hover:bg-transparent flex items-center justify-center"
                      type="button"
                    >
                      <ChevronLeft size={18} />
                    </button>

                    <div className="flex gap-2">
                      <select
                        value={months[date.getMonth()]}
                        onChange={({ target: { value } }) => changeMonth(months.indexOf(value))}
                        className="bg-white border border-slate-200 text-slate-700 text-[13px] font-bold py-1 px-2 rounded-lg cursor-pointer outline-none hover:border-blue-400 hover:text-blue-600 transition-colors appearance-none text-center shadow-sm"
                        style={{ textAlignLast: 'center' }}
                      >
                        {months.map((option) => (
                          <option key={option} value={option}>{option}</option>
                        ))}
                      </select>

                      <select
                        value={date.getFullYear()}
                        onChange={({ target: { value } }) => changeYear(Number(value))}
                        className="bg-white border border-slate-200 text-slate-700 text-[13px] font-bold py-1 px-2 rounded-lg cursor-pointer outline-none hover:border-blue-400 hover:text-blue-600 transition-colors appearance-none text-center shadow-sm"
                        style={{ textAlignLast: 'center' }}
                      >
                        {years.map((option) => (
                          <option key={option} value={option}>{option}</option>
                        ))}
                      </select>
                    </div>

                    <button 
                      onClick={increaseMonth} 
                      disabled={nextMonthButtonDisabled} 
                      className="p-1.5 rounded-lg text-slate-400 hover:bg-white hover:text-blue-600 hover:shadow-sm transition-all disabled:opacity-30 disabled:hover:bg-transparent flex items-center justify-center"
                      type="button"
                    >
                      <ChevronRight size={18} />
                    </button>
                    
                  </div>
                );
              }}
            />
          </div>
        </div>

        <button 
          onClick={openAddModal} 
          className="w-full lg:w-auto flex items-center justify-center gap-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white px-6 py-2.5 rounded-xl font-bold text-sm shadow-md shadow-blue-500/30 hover:-translate-y-0.5 transition-all"
        >
          <Plus size={18} /> Thêm Suất Chiếu
        </button>
      </div>

      {/* BẢNG TIMELINE */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-md overflow-hidden z-10 animate-[slide-in-bottom_0.4s_ease-out] w-full min-w-0">
        <div className="overflow-x-auto custom-scrollbar">
          <div className="min-w-[1200px]">
            
            {/* 🚀 ĐÃ SỬA: CHÈN THÊM pr-10 VÀO ĐÂY ĐỂ TẠO KHOẢNG ĐỆM MÀU ĐEN CHO SỐ 04:00 */}
            <div className="flex border-b border-slate-200 bg-slate-800 text-white pr-10">
              <div className="w-[220px] p-4 font-bold text-slate-300 text-[12px] uppercase tracking-wider shrink-0 border-r border-slate-700 flex items-center gap-2 shadow-sm z-20 bg-slate-900">
                <MonitorPlay size={16} className="text-blue-400"/> Danh sách Phòng
              </div>
              <div className="flex-1 relative h-12">
                {timeMarkers.map(hour => {
                  const displayHour = hour >= 24 ? hour - 24 : hour;
                  const displayStr = `${displayHour.toString().padStart(2, '0')}:00`;

                  return (
                    <div 
                      key={hour} 
                      // 🚀 ĐÃ SỬA: TRẢ LẠI pl-2 ĐỂ CHỮ NẰM BÊN PHẢI VẠCH CHUẨN XÁC
                      className="absolute top-0 bottom-0 w-px border-l border-slate-600 pt-3 pl-2 text-slate-300 text-xs font-bold"
                      style={{ left: `${((hour - START_HOUR) / TOTAL_HOURS) * 100}%` }}
                    >
                      {displayStr}
                      {/* Vạch kẻ giữa giờ (30 phút) */}
                      {hour < START_HOUR + TOTAL_HOURS && <div className="absolute top-8 -left-[1px] w-px h-4 border-l border-slate-700" style={{ marginLeft: '50%' }}></div>}
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="bg-slate-50/50">
              {filteredRooms.length === 0 ? (
                 <div className="flex flex-col items-center justify-center p-16 text-slate-400">
                    <Film size={48} className="opacity-20 mb-4" />
                    <span className="font-medium">Rạp này chưa có phòng chiếu nào được thiết lập.</span>
                 </div>
              ) : (
                filteredRooms.map((room, index) => {
                  const roomShowtimes = showtimes.filter(st => st.roomId === room.RoomID);
                  const rowBg = index % 2 === 0 ? 'bg-white' : 'bg-slate-50/50';

                  return (
                    // 🚀 ĐÃ SỬA: CHÈN THÊM pr-10 VÀO DÒNG NÀY ĐỂ ĐỒNG BỘ ĐỘ DÀI VỚI HEADER MÀU ĐEN Ở TRÊN
                    <div key={room.RoomID} className={`flex border-b border-slate-200 min-h-[140px] hover:bg-blue-50/30 transition-colors pr-10 ${rowBg}`}>
                      
                      <div className="w-[220px] p-4 shrink-0 border-r border-slate-200 bg-white flex flex-col justify-center shadow-[4px_0_10px_rgba(0,0,0,0.02)] z-10">
                        <h3 className="m-0 text-[16px] font-black text-slate-800">{room.Name}</h3>
                        <div className="mt-2 space-y-1.5">
                          <span className="text-[12px] text-slate-600 font-medium bg-slate-100 px-2.5 py-1 rounded-md border border-slate-200 flex items-center gap-1.5 w-max">
                            <CheckCircle size={12} className="text-slate-400"/> Sức chứa: {room.TotalSeats} Ghế
                          </span>
                          <span className="text-[11px] text-amber-600 font-bold bg-amber-50 border border-amber-100 px-2 py-0.5 rounded-md flex items-center gap-1 w-max">
                            <Clock size={12}/> Dọn rạp: {room.BufferMinutes} phút
                          </span>
                        </div>
                      </div>

                      <div className="flex-1 relative overflow-hidden">
                        {timeMarkers.map(hour => (
                          <div key={hour} className="absolute top-0 bottom-0 w-px border-l border-dashed border-slate-200" style={{ left: `${((hour - START_HOUR) / TOTAL_HOURS) * 100}%` }} />
                        ))}

                        {roomShowtimes.map(st => {
                          const leftPos = calculateLeftOffset(st.startTime);
                          const width = calculateWidth(st.duration);

                          return (
                            <div 
                              key={st.id} 
                              onClick={() => openEditModal(st)}
                              className="absolute top-3 bottom-3 bg-gradient-to-br from-white to-blue-50 border border-blue-200 border-l-[4px] border-l-blue-500 rounded-xl p-2 shadow-sm flex flex-col z-10 cursor-pointer transition-all duration-300 hover:shadow-lg hover:shadow-blue-500/20 hover:scale-[1.02] hover:z-20 hover:border-blue-400 group overflow-hidden"
                              style={{ left: `${leftPos}%`, width: `${width}%`, minWidth: '64px' }}
                              title={`${st.movie} (${st.format})\nThời gian: ${st.startTime} - ${st.endTime}`}
                            >
                              <h4 className="m-0 text-[12px] font-black text-slate-800 line-clamp-2 leading-tight group-hover:text-blue-700 transition-colors break-words w-full">
                                {st.movie}
                              </h4>
                              
                              <div className="mt-auto pt-1 flex flex-col gap-1 items-start w-full overflow-hidden">
                                 <span className="text-[9px] font-bold bg-slate-800 text-white px-1.5 py-0.5 rounded shadow-sm whitespace-nowrap truncate max-w-full">
                                   {st.format}
                                 </span>
                                 <span className="text-[10px] font-bold text-blue-700 bg-blue-100 px-1.5 py-0.5 rounded border border-blue-200 whitespace-nowrap truncate max-w-full">
                                   {st.startTime} - {st.endTime}
                                 </span>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )
                })
              )}
            </div>
          </div>
        </div>
      </div>

      {/* POPUP MODAL */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4 animate-[fade-in_0.2s_ease-out]">
          <div className="bg-white p-6 sm:p-8 rounded-3xl w-[500px] max-w-full shadow-2xl animate-[slide-in-bottom_0.3s_ease-out]">
            
            <div className="flex justify-between items-center mb-6 border-b border-slate-100 pb-4">
              <h2 className="m-0 text-xl font-black text-slate-800 flex items-center gap-2">
                <Ticket className="text-blue-600" /> {editingShowtimeId ? 'Sửa Suất Chiếu' : 'Thêm Suất Chiếu Mới'}
              </h2>
              <button onClick={() => setIsModalOpen(false)} className="bg-slate-100 hover:bg-red-100 hover:text-red-500 text-slate-500 rounded-full w-8 h-8 flex items-center justify-center transition-colors"><X size={18} /></button>
            </div>

            <form onSubmit={handleSaveShowtime} className="flex flex-col gap-5">
              
              <div className="relative group" ref={movieDropdownRef}>
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Tìm & Chọn Phim *</label>
                <div className="flex items-center border border-slate-200 rounded-xl px-3 bg-slate-50 focus-within:bg-white focus-within:border-blue-500 focus-within:ring-4 focus-within:ring-blue-50 transition-all">
                  <Search size={18} className="text-slate-400 shrink-0" />
                  <input 
                    type="text" 
                    required={!newShowtime.movieId}
                    placeholder="Gõ tên phim để tìm..." 
                    value={searchMovieTerm} 
                    onChange={(e) => {
                      setSearchMovieTerm(e.target.value);
                      setShowMovieDropdown(true);
                      setNewShowtime({...newShowtime, movieId: ''}); 
                    }}
                    onFocus={(e) => {
                      e.target.select();
                      setShowMovieDropdown(true);
                    }}
                    className="w-full bg-transparent border-none outline-none py-3 px-3 text-sm font-medium" 
                  />
                  {searchMovieTerm && !newShowtime.movieId ? (
                    <X size={16} className="text-slate-400 hover:text-red-500 cursor-pointer shrink-0" onClick={() => { setSearchMovieTerm(''); setShowMovieDropdown(true); }} />
                  ) : newShowtime.movieId && (
                    <CheckCircle size={18} className="text-emerald-500 shrink-0" />
                  )}
                </div>

                {showMovieDropdown && searchMovieTerm && (
                  <div className="absolute top-[100%] left-0 right-0 bg-white border border-slate-200 rounded-xl mt-2 max-h-[250px] overflow-y-auto shadow-xl z-50 animate-[slide-in-down_0.2s_ease-out]">
                    {filteredSearchMovies.length > 0 ? filteredSearchMovies.map(m => (
                      <div 
                        key={m.id} 
                        onMouseDown={() => {
                          setNewShowtime({...newShowtime, movieId: m.id.toString()});
                          setSearchMovieTerm(m.title); 
                          setShowMovieDropdown(false); 
                        }}
                        className="p-3 cursor-pointer border-b border-slate-50 flex items-center gap-3 hover:bg-blue-50 transition-colors"
                      >
                        <img 
                          src={getSafePosterUrl(m)} 
                          alt="poster" 
                          className="w-8 h-12 object-cover rounded shadow-sm bg-slate-100 shrink-0"
                          onError={(e) => { e.currentTarget.src = 'https://via.placeholder.com/150x225?text=No+Poster'; }}
                        />
                        <div className="min-w-0 flex-1">
                          <div className="text-sm font-bold text-slate-800 truncate">{m.title}</div>
                          <div className="text-xs text-slate-500 font-medium">{m.duration || '?'} phút</div>
                        </div>
                      </div>
                    )) : (
                      <div className="p-4 text-center text-slate-500 text-sm">Không tìm thấy phim phù hợp</div>
                    )}
                  </div>
                )}
              </div>

              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Phòng Chiếu *</label>
                <div className="flex items-center border border-slate-200 rounded-xl px-3 bg-slate-50 focus-within:bg-white focus-within:border-blue-500 focus-within:ring-4 focus-within:ring-blue-50 transition-all">
                  <MonitorPlay size={18} className="text-slate-400 shrink-0" />
                  <select required value={newShowtime.roomId} onChange={(e) => setNewShowtime({...newShowtime, roomId: e.target.value})} className="w-full bg-transparent border-none outline-none py-3 px-3 text-sm font-medium cursor-pointer">
                    <option value="" disabled>-- Chọn phòng chiếu --</option>
                    {filteredRooms.map(r => <option key={r.RoomID} value={r.RoomID}>{r.Name} - {r.TotalSeats} Ghế</option>)}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="group">
                  <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Giờ Bắt Đầu *</label>
                  <div className="flex items-center border border-slate-200 rounded-xl px-3 bg-slate-50 focus-within:bg-white focus-within:border-blue-500 focus-within:ring-4 focus-within:ring-blue-50 transition-all">
                    <Clock size={18} className="text-slate-400 shrink-0" />
                    <input type="time" required value={newShowtime.time} onChange={(e) => setNewShowtime({...newShowtime, time: e.target.value})} className="w-full bg-transparent border-none outline-none py-3 px-3 text-sm font-medium cursor-pointer" />
                  </div>
                </div>
                
                <div className="group">
                  <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Định Dạng *</label>
                  <select value={newShowtime.format} onChange={(e) => setNewShowtime({...newShowtime, format: e.target.value})} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 py-3 px-4 rounded-xl text-sm font-medium cursor-pointer transition-all">
                    <option value="2D Phụ đề">2D Phụ đề</option>
                    <option value="2D Lồng Tiếng">2D Lồng Tiếng</option>
                    <option value="IMAX">IMAX</option>
                    <option value="4DX">4DX</option>
                    <option value="3D Phụ đề">3D Phụ đề</option>
                    <option value="2D Premium">2D Premium</option>
                  </select>
                </div>
              </div>

              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Giá Vé Cơ Bản (VNĐ) *</label>
                <div className="flex items-center border border-slate-200 rounded-xl px-3 bg-slate-50 focus-within:bg-white focus-within:border-blue-500 focus-within:ring-4 focus-within:ring-blue-50 transition-all">
                  <DollarSign size={18} className="text-slate-400 shrink-0" />
                  <input type="number" required value={newShowtime.price} onChange={(e) => setNewShowtime({...newShowtime, price: Number(e.target.value)})} className="w-full bg-transparent border-none outline-none py-3 px-3 text-sm font-medium" />
                </div>
              </div>

              <div className="flex justify-between items-center mt-4 pt-5 border-t border-slate-100">
                <div>
                  {editingShowtimeId && (
                    <button type="button" onClick={handleDeleteShowtime} className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-red-50 hover:bg-red-100 text-red-600 font-bold text-sm transition-colors shadow-sm">
                      <Trash2 size={16} /> Xóa
                    </button>
                  )}
                </div>

                <div className="flex gap-3">
                  <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 font-bold text-slate-600 text-sm transition-colors">Hủy bỏ</button>
                  <button type="submit" className="flex items-center gap-2 px-6 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-sm shadow-md shadow-blue-500/30 transition-all hover:-translate-y-0.5">
                    <Save size={16} /> {editingShowtimeId ? 'Lưu Thay Đổi' : 'Lưu Suất Chiếu'}
                  </button>
                </div>
              </div>
            </form>

          </div>
        </div>
      )}

      <style>{`
        @keyframes slide-in-down { from { opacity: 0; transform: translateY(-10px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes slide-in-bottom { from { opacity: 0; transform: translateY(20px) scale(0.98); } to { opacity: 1; transform: translateY(0) scale(1); } }
        @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
        
        .custom-scrollbar::-webkit-scrollbar { height: 10px; }
        .custom-scrollbar::-webkit-scrollbar-track { background: #f1f5f9; border-radius: 10px; }
        .custom-scrollbar::-webkit-scrollbar-thumb { background: #cbd5e1; border-radius: 10px; }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover { background: #94a3b8; }

        .react-datepicker {
          font-family: inherit !important;
          border: 1px solid #e2e8f0 !important;
          border-radius: 16px !important;
          box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 8px 10px -6px rgba(0, 0, 0, 0.1) !important;
          overflow: hidden;
        }
        
        .react-datepicker__navigation { display: none !important; }
        .react-datepicker__header { padding: 0 !important; border-bottom: none !important; background-color: #f8fafc !important; }
        .react-datepicker__day-names { margin-top: 8px; }

        .react-datepicker__day-name {
          color: #64748b !important;
          font-weight: bold !important;
        }
        .react-datepicker__day {
          color: #334155 !important;
          font-weight: 600 !important;
          border-radius: 8px !important;
          transition: all 0.2s;
        }
        .react-datepicker__day:hover {
          background-color: #dbeafe !important;
          color: #1d4ed8 !important;
        }
        .react-datepicker__day--selected, 
        .react-datepicker__day--keyboard-selected {
          background-color: #2563eb !important;
          color: white !important;
          font-weight: bold !important;
          box-shadow: 0 4px 6px -1px rgba(37, 99, 235, 0.3) !important;
        }
      `}</style>
    </div>
  );
};

export default Showtimes;