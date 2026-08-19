import React, { useState, useEffect } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2'; // 🚀 IMPORT SWEETALERT2
import { MapPin, Popcorn, Ticket, DollarSign, TrendingUp, X, Calendar as CalendarIcon, AlertTriangle, PenTool, Save, ChevronRight } from 'lucide-react';

// 🚀 CẤU HÌNH TOAST NOTIFICATION
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

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalRevenue: 0,
    ticketRevenue: 0,
    foodRevenue: 0,
    totalTickets: 0,
    topMovies: [] as any[],
    topFoods: [] as any[],
    recentBookings: [] as any[],
    warningShowtimes: [] as any[]
  });

  const [cinemas, setCinemas] = useState<any[]>([]);
  const [selectedCinema, setSelectedCinema] = useState('ALL');
  
  // 🚀 ĐÃ THÊM: STATE CHO COMBOBOX TÌM KIẾM RẠP
  const [isCinemaDropdownOpen, setIsCinemaDropdownOpen] = useState(false);
  const [cinemaSearchQuery, setCinemaSearchQuery] = useState('');
  const cinemaDropdownRef = React.useRef<HTMLDivElement>(null);

  const [filterMode, setFilterMode] = useState('ALL_TIME'); 
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);

  const [showTransactionModal, setShowTransactionModal] = useState(false);
  const [showNoteModal, setShowNoteModal] = useState(false);
  
  const [currentNoteId, setCurrentNoteId] = useState<string | null>(null);
  // 🚀 ĐÃ SỬA: Tách làm 2 biến Nguyên nhân và Giải pháp
  const [noteCause, setNoteCause] = useState('');
  const [noteSolution, setNoteSolution] = useState('');

  useEffect(() => {
    const fetchCinemas = async () => {
      try {
        const response = await axios.get('http://10.173.120.41:3000/api/cinemas');
        setCinemas(response.data);
      } catch (error) {}
    };
    fetchCinemas();

    // 🚀 Lắng nghe sự kiện click ra ngoài để đóng Combobox rạp
    const handleClickOutside = (event: MouseEvent) => {
      if (cinemaDropdownRef.current && !cinemaDropdownRef.current.contains(event.target as Node)) {
        setIsCinemaDropdownOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // 🚀 HÀM LẤY TÊN RẠP ĐANG CHỌN ĐỂ HIỂN THỊ
  const getSelectedCinemaName = () => {
    if (selectedCinema === 'ALL') return 'Tất cả Rạp (Toàn quốc)';
    const found = cinemas.find(c => c.id.toString() === selectedCinema.toString());
    return found ? (found.Name || found.name) : 'Tất cả Rạp (Toàn quốc)';
  };

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const dateQuery = filterMode === 'ALL_TIME' ? '' : selectedDate;
        const response = await axios.get(`http://10.173.120.41:3000/api/admin/dashboard/summary?cinemaId=${selectedCinema}&date=${dateQuery}`);
        setStats(response.data);
      } catch (error) {
        console.error("Lỗi lấy dữ liệu thống kê:", error);
      }
    };
    fetchStats();
  }, [selectedCinema, filterMode, selectedDate]);

  const formatMoney = (amount: number) => new Intl.NumberFormat('vi-VN').format(amount) + ' đ';

  const getImageUrl = (path: string) => {
    if (!path) return 'https://via.placeholder.com/50x75?text=No+Image';
    
    // Nếu là link web có sẵn (http/https)
    if (path.startsWith('http')) return path;
    
    // 🚀 ĐÃ BỔ SUNG: Xử lý ảnh phim mới được thêm bằng Admin (Nằm trong thư mục uploads)
    if (path.startsWith('/uploads/') || path.startsWith('uploads/')) {
      const cleanPath = path.startsWith('/') ? path.substring(1) : path;
      return `http://10.173.120.41:3000/${cleanPath}`;
    }

    // Nếu không thuộc 2 trường hợp trên -> Nó là ảnh gốc từ TMDB
    const cleanPath = path.startsWith('/') ? path : `/${path}`;
    return `https://image.tmdb.org/t/p/w200${cleanPath}`;
  };

 const getFoodImagePath = (dbImage: string, brandId: number) => {
    let img = (dbImage || '').trim();
    if (!img || img === 'null') return 'https://via.placeholder.com/40?text=Food';
    
    // Xóa lỗi dấu gạch chéo ngược của Windows
    img = img.replace(/\\/g, '/');

    // 1. Nếu là link web ngoài
    if (img.startsWith('http')) return img;

    // 2. 🚀 BÊ Y CHANG LOGIC TỪ FLUTTER SANG REACT
    if (img.includes('public/foods') || img.includes('public/uploads') || img.includes('food-') || img.includes('uploads/')) {
      // Cắt lấy đúng cái tên file cuối cùng (VD: tách "uploads/178.jpg" -> lấy "178.jpg")
      const filename = img.split('/').pop() || ''; 
      
      // Phân loại thư mục y như cây folder backend của ông
      if (/^\d+/.test(filename)) {
        // Nếu tên file bắt đầu bằng số (timestamp: 1781875...) -> Nằm ở public/uploads/
        return `http://10.173.120.41:3000/public/uploads/${filename}`;
      } else {
        // Còn lại (VD: food-178...jpg) -> Nằm ở public/foods/
        return `http://10.173.120.41:3000/public/foods/${filename}`;
      }
    }

    // 3. Xử lý ảnh tĩnh mặc định trong thư mục assets (Giống y hệt Flutter)
    const folders: Record<number, string> = { 1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags', 7: 'dcine', 8: 'beta', 9: 'aeonbeta' };
    const folder = folders[brandId] || 'cgv';
    
    if (img.startsWith('/')) img = img.substring(1);
    if (img.startsWith('assets/')) return `http://10.173.120.41:3000/${img}`; 
    if (img.startsWith(`${folder}/`)) return `http://10.173.120.41:3000/assets/${img}`;
    
    return `http://10.173.120.41:3000/assets/${folder}/${img}`;
  };

  const openNoteModal = (showtimeId: string) => {
    setCurrentNoteId(showtimeId);
    // 🚀 Lấy dữ liệu cũ ra (nếu đã từng viết)
    const savedData = localStorage.getItem(`note_showtime_${showtimeId}`);
    if (savedData) {
      try {
        const parsed = JSON.parse(savedData);
        setNoteCause(parsed.cause || '');
        setNoteSolution(parsed.solution || '');
      } catch (e) {
        setNoteCause(''); setNoteSolution(savedData);
      }
    } else {
      setNoteCause(''); setNoteSolution('');
    }
    setShowNoteModal(true);
  };

  const handleSaveNote = () => {
    if (currentNoteId) {
      // 🚀 Lưu cả Nguyên nhân và Giải pháp vào 1 cục JSON
      const dataToSave = JSON.stringify({ cause: noteCause, solution: noteSolution });
      localStorage.setItem(`note_showtime_${currentNoteId}`, dataToSave);
      Toast.fire({ icon: 'success', title: 'Đã lưu báo cáo đánh giá suất chiếu!' });
      setShowNoteModal(false);
    }
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] animate-[fade-in_0.3s_ease-out]">
      
      {/* 🚀 THANH CÔNG CỤ THÔNG MINH ĐỒNG BỘ */}
      <div className="flex flex-col xl:flex-row gap-4 mb-6 justify-between items-start xl:items-center bg-white p-4 rounded-2xl shadow-sm border border-slate-200">
        
        {/* Bộ lọc thời gian */}
        <div className="flex bg-slate-100 p-1.5 rounded-xl w-full xl:w-auto overflow-x-auto no-scrollbar">
          <button 
            onClick={() => setFilterMode('ALL_TIME')}
            className={`px-5 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all duration-300 flex items-center gap-2 ${filterMode === 'ALL_TIME' ? 'bg-blue-600 text-white shadow-md' : 'text-slate-500 hover:text-slate-800 hover:bg-slate-200'}`}
          >
            Tất cả thời gian
          </button>
          <div 
            onClick={() => setFilterMode('DATE')}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all duration-300 cursor-pointer ${filterMode === 'DATE' ? 'bg-blue-600 text-white shadow-md' : 'text-slate-500 hover:text-slate-800 hover:bg-slate-200'}`}
          >
            <CalendarIcon size={16} />
            {filterMode === 'DATE' ? (
              <input 
                type="date" 
                value={selectedDate} 
                onChange={(e) => setSelectedDate(e.target.value)} 
                className="bg-transparent border-none outline-none font-bold text-sm cursor-pointer [&::-webkit-calendar-picker-indicator]:filter-[invert(1)]" 
              />
            ) : (
              <span>Chọn ngày...</span>
            )}
          </div>
        </div>

        {/* 🚀 ĐÃ NÂNG CẤP: BỘ LỌC RẠP DẠNG COMBOBOX (TÌM KIẾM ĐƯỢC) */}
        <div className="relative w-full xl:w-64" ref={cinemaDropdownRef}>
          {/* Nút bấm hiển thị */}
          <div 
            onClick={() => setIsCinemaDropdownOpen(!isCinemaDropdownOpen)}
            className={`w-full pl-10 pr-4 py-2.5 bg-slate-50 border rounded-xl outline-none transition-all text-sm font-bold text-slate-700 cursor-pointer flex items-center justify-between select-none ${isCinemaDropdownOpen ? 'border-blue-500 bg-white ring-4 ring-blue-50' : 'border-slate-200 hover:border-slate-300'}`}
          >
            <MapPin className={`absolute left-3 top-1/2 transform -translate-y-1/2 transition-colors ${isCinemaDropdownOpen ? 'text-blue-500' : 'text-slate-400'}`} size={18} />
            <span className="truncate pr-2">{getSelectedCinemaName()}</span>
            <ChevronRight size={16} className={`text-slate-400 transition-transform duration-200 flex-shrink-0 ${isCinemaDropdownOpen ? 'rotate-90 text-blue-500' : ''}`} />
          </div>

          {/* Khung menu sổ xuống */}
          {isCinemaDropdownOpen && (
            <div className="absolute top-[110%] left-0 w-full bg-white border border-slate-200 rounded-xl shadow-xl z-50 overflow-hidden animate-[fade-in_0.15s_ease-out]">
              {/* Ô gõ từ khóa tìm kiếm */}
              <div className="p-2 border-b border-slate-100 bg-slate-50/80">
                <input 
                  type="text" 
                  placeholder="Nhập tên rạp để tìm..." 
                  value={cinemaSearchQuery}
                  onChange={(e) => setCinemaSearchQuery(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-white border border-slate-200 rounded-lg outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-50"
                  autoFocus // Tự động trỏ chuột vào ô này khi mở ra
                />
              </div>
              
              {/* Danh sách rạp */}
              <div className="max-h-60 overflow-y-auto p-1">
                {/* Luôn hiển thị option Tất cả Rạp */}
                <div 
                  onClick={() => { setSelectedCinema('ALL'); setIsCinemaDropdownOpen(false); setCinemaSearchQuery(''); }}
                  className={`px-3 py-2.5 rounded-lg text-sm cursor-pointer transition-colors ${selectedCinema === 'ALL' ? 'bg-blue-50 text-blue-700 font-bold' : 'text-slate-700 hover:bg-slate-100 font-medium'}`}
                >
                  Tất cả Rạp (Toàn quốc)
                </div>

                {/* Danh sách rạp đã được lọc theo từ khóa */}
                {cinemas
                  .filter(c => (c.Name || c.name).toLowerCase().includes(cinemaSearchQuery.toLowerCase()))
                  .map(c => (
                    <div 
                      key={c.id} 
                      onClick={() => { setSelectedCinema(c.id.toString()); setIsCinemaDropdownOpen(false); setCinemaSearchQuery(''); }}
                      className={`px-3 py-2.5 rounded-lg text-sm cursor-pointer transition-colors ${selectedCinema === c.id.toString() ? 'bg-blue-50 text-blue-700 font-bold' : 'text-slate-700 hover:bg-slate-100 font-medium'}`}
                    >
                      {c.Name || c.name}
                    </div>
                ))}

                {/* Nếu gõ tào lao không ra rạp nào */}
                {cinemas.filter(c => (c.Name || c.name).toLowerCase().includes(cinemaSearchQuery.toLowerCase())).length === 0 && (
                  <div className="px-3 py-4 text-center text-slate-400 text-sm italic">
                    Không tìm thấy rạp nào
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>
      
      {/* 🚀 4 KHỐI THỐNG KÊ CHI TIẾT */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6 mb-6">
        {[
          { title: 'TỔNG DOANH THU', value: formatMoney(stats.totalRevenue), icon: DollarSign, color: 'text-blue-600', bg: 'bg-blue-50' },
          { title: 'DOANH THU VÉ', value: formatMoney(stats.ticketRevenue), icon: Ticket, color: 'text-emerald-500', bg: 'bg-emerald-50' },
          { title: 'BẮP NƯỚC (F&B)', value: formatMoney(stats.foodRevenue), icon: Popcorn, color: 'text-amber-500', bg: 'bg-amber-50' },
          { title: 'TỔNG SỐ VÉ BÁN', value: `${stats.totalTickets.toLocaleString('vi-VN')} Vé`, icon: TrendingUp, color: 'text-purple-500', bg: 'bg-purple-50' },
        ].map((item, idx) => (
          <div key={idx} className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm hover:shadow-md transition-all duration-300 hover:-translate-y-1 animate-[slide-in-bottom_0.4s_ease-out_backwards]" style={{ animationDelay: `${idx * 100}ms` }}>
            <div className="flex items-center gap-3 mb-3">
              <div className={`p-2.5 rounded-xl ${item.bg}`}>
                <item.icon size={20} className={item.color} />
              </div>
              <h3 className="m-0 text-slate-500 text-[11px] font-bold tracking-wider">{item.title}</h3>
            </div>
            <h2 className="m-0 text-slate-800 text-2xl font-black tracking-tight">{item.value}</h2>
          </div>
        ))}
      </div>

      {/* 🚀 BẢNG CẢNH BÁO SUẤT CHIẾU TRỐNG GHẾ */}
      <div className="bg-white rounded-2xl border border-red-100 shadow-sm overflow-hidden mb-6 animate-[slide-in-bottom_0.5s_ease-out_backwards]" style={{ animationDelay: '300ms' }}>
        <div className="bg-red-50/50 p-5 border-b border-red-100 flex items-center gap-3">
          <div className="p-2 bg-red-100 rounded-full animate-pulse">
            <AlertTriangle size={20} className="text-red-600" />
          </div>
          <h3 className="m-0 text-red-900 text-lg font-bold">Cảnh Báo: Suất Chiếu Trống Ghế (Dưới 30%)</h3>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[800px]">
            <thead className="bg-slate-50/80 text-slate-600 border-b border-slate-200">
              <tr className="text-[11px] uppercase tracking-wider font-bold">
                <th className="p-4">Tên Phim</th>
                <th className="p-4">Phòng Chiếu</th>
                <th className="p-4">Giờ Chiếu</th>
                <th className="p-4">Tỷ Lệ Lấp Đầy</th>
                <th className="p-4 text-center">Hành Động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {stats.warningShowtimes && stats.warningShowtimes.length > 0 ? (
                stats.warningShowtimes.map((showtime, idx) => {
                  const percent = Math.round((showtime.bookedSeats / showtime.totalSeats) * 100);
                  return (
                    <tr key={idx} className="hover:bg-slate-50 transition-colors">
                      <td className="p-4 font-bold text-slate-800 text-sm">{showtime.movieName}</td>
                      <td className="p-4 text-slate-600 text-sm font-medium">{showtime.roomName}</td>
                      <td className="p-4 text-red-600 text-sm font-bold bg-red-50/50">{showtime.startTime}</td>
                      <td className="p-4">
                        <div className="flex items-center gap-3">
                          <div className="flex-1 height-2 bg-slate-100 rounded-full overflow-hidden h-2">
                            <div className="h-full bg-red-500 rounded-full" style={{ width: `${percent}%` }}></div>
                          </div>
                          <span className="text-xs font-bold text-red-600 bg-red-50 px-2 py-0.5 rounded border border-red-100">{showtime.bookedSeats}/{showtime.totalSeats} ({percent}%)</span>
                        </div>
                      </td>
                      <td className="p-4 text-center">
                        {(() => {
                          const hasNote = localStorage.getItem(`note_showtime_${showtime.id}`);
                          return (
                            <button 
                              onClick={() => openNoteModal(showtime.id)}
                              className={`inline-flex items-center justify-center gap-2 px-4 py-2 rounded-lg text-xs font-bold transition-all shadow-sm border ${
                                hasNote 
                                ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100' 
                                : 'bg-white text-red-600 border-red-200 hover:bg-red-50'
                              }`}
                            >
                              <PenTool size={14} /> {hasNote ? "Xem lại báo cáo" : "Ghi chú giải pháp"}
                            </button>
                          )
                        })()}
                      </td>
                    </tr>
                  )
                })
              ) : (
                <tr><td colSpan={5} className="text-center p-12 text-slate-400 font-medium">Hệ thống ổn định, không có suất chiếu nào ế khách. 🎉</td></tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* 🚀 GIAO DỊCH VÀ XẾP HẠNG */}
      <div className="flex flex-col lg:flex-row gap-6">
        
        {/* GIAO DỊCH GẦN ĐÂY */}
        <div className="flex-[2] bg-white rounded-2xl border border-slate-200 p-6 shadow-sm animate-[slide-in-bottom_0.6s_ease-out_backwards]" style={{ animationDelay: '400ms' }}>
          <div className="flex justify-between items-center mb-6">
            <h3 className="m-0 text-slate-800 text-lg font-bold">Giao Dịch Gần Đây</h3>
            <button onClick={() => setShowTransactionModal(true)} className="text-blue-600 hover:text-blue-700 bg-blue-50 hover:bg-blue-100 px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1">
              Xem tất cả <ChevronRight size={14} />
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse min-w-[500px]">
              <thead className="bg-slate-50 text-slate-500 border-y border-slate-200">
                <tr className="text-[11px] uppercase tracking-wider font-bold">
                  <th className="p-3">Tên Phim / Dịch vụ</th>
                  <th className="p-3">Thời gian</th>
                  <th className="p-3">Giá Tiền</th>
                  <th className="p-3 text-right">Trạng Thái</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {stats.recentBookings.slice(0, 5).map((b, idx) => (
                    <tr key={idx} className="hover:bg-slate-50 transition-colors">
                      <td className="p-3 font-bold text-slate-800 text-sm line-clamp-1">{b.movie || 'Đơn thức ăn tại quầy'}</td>
                      <td className="p-3 text-slate-500 text-xs"><div className="font-bold text-slate-700">{b.time}</div><div>{b.date}</div></td>
                      <td className="p-3 font-bold text-slate-800 text-sm">{formatMoney(b.price)}</td>
                      <td className="p-3 text-right">
                        {b.status === 'Paid' ? ( 
                          <span className="bg-emerald-50 text-emerald-600 border border-emerald-100 px-2.5 py-1 rounded-md text-[10px] font-bold">ĐÃ THANH TOÁN</span> 
                        ) : ( 
                          <span className="bg-amber-50 text-amber-600 border border-amber-100 px-2.5 py-1 rounded-md text-[10px] font-bold uppercase">{b.status}</span> 
                        )}
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>

          {/* 🚀 BỔ SUNG KHỐI NÀY ĐỂ LẤP CHỖ TRỐNG: BIỂU ĐỒ TỶ TRỌNG & CHỈ SỐ INSIGHTS */}
          <div className="mt-8 pt-6 border-t border-slate-100">
            <h4 className="m-0 text-slate-700 text-sm font-bold mb-5 flex items-center gap-2">
              <TrendingUp size={16} className="text-indigo-500"/> Phân tích & Chỉ số (Insights)
            </h4>
            
            {stats.totalRevenue > 0 ? (
              <div className="flex flex-col gap-6">
                
                {/* 1. THANH TỶ TRỌNG (LÀM TO HƠN, THÊM CHỮ BÊN TRONG) */}
                <div>
                  <div className="flex h-6 rounded-full overflow-hidden shadow-inner bg-slate-100">
                    <div className="bg-emerald-500 h-full flex items-center justify-center text-[10px] text-white font-black tracking-wider transition-all duration-1000" style={{ width: `${(stats.ticketRevenue / stats.totalRevenue) * 100}%` }}>
                      {Math.round((stats.ticketRevenue / stats.totalRevenue) * 100) > 15 ? 'DOANH THU VÉ' : ''}
                    </div>
                    <div className="bg-amber-400 h-full flex items-center justify-center text-[10px] text-white font-black tracking-wider transition-all duration-1000" style={{ width: `${(stats.foodRevenue / stats.totalRevenue) * 100}%` }}>
                      {Math.round((stats.foodRevenue / stats.totalRevenue) * 100) > 15 ? 'BẮP NƯỚC' : ''}
                    </div>
                  </div>
                  <div className="flex justify-between items-center text-xs font-bold mt-2.5">
                    <div className="flex items-center gap-1.5 text-emerald-600">
                      <span className="w-3 h-3 rounded-full bg-emerald-500 shadow-sm"></span> Vé: {Math.round((stats.ticketRevenue / stats.totalRevenue) * 100)}%
                    </div>
                    <div className="flex items-center gap-1.5 text-amber-600">
                      Bắp nước: {Math.round((stats.foodRevenue / stats.totalRevenue) * 100)}% <span className="w-3 h-3 rounded-full bg-amber-400 shadow-sm"></span>
                    </div>
                  </div>
                </div>

                {/* 2. HAI THẺ KPI MINI (TỰ ĐỘNG TÍNH TOÁN TỪ DATA CÓ SẴN) */}
                <div className="grid grid-cols-2 gap-4">
                   <div className="bg-indigo-50/50 p-4 rounded-xl border border-indigo-100 flex flex-col justify-center items-center text-center hover:bg-indigo-50 transition-colors">
                       <span className="text-indigo-500 mb-1.5 bg-white p-2 rounded-full shadow-sm"><Ticket size={18}/></span>
                       <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Giá vé trung bình</span>
                       <span className="text-lg font-black text-indigo-700">
                          {stats.totalTickets > 0 ? formatMoney(stats.ticketRevenue / stats.totalTickets) : '0 đ'}
                       </span>
                   </div>
                   <div className="bg-rose-50/50 p-4 rounded-xl border border-rose-100 flex flex-col justify-center items-center text-center hover:bg-rose-50 transition-colors">
                       <span className="text-rose-500 mb-1.5 bg-white p-2 rounded-full shadow-sm"><AlertTriangle size={18}/></span>
                       <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Tỷ lệ hủy/Hoàn vé</span>
                       <span className="text-lg font-black text-rose-700">
                          {/* Thuật toán tính nhẩm tỷ lệ hủy dựa trên danh sách giao dịch gần đây */}
                          {stats.recentBookings.length > 0
                            ? Math.round((stats.recentBookings.filter(b => b.status !== 'Paid').length / stats.recentBookings.length) * 100)
                            : 0}%
                       </span>
                   </div>
                </div>

                {/* 3. LỜI KHUYÊN QUẢN TRỊ (MẸO UX GIÚP LẤP ĐẦY TRANG CHUYÊN NGHIỆP) */}
                <div className="bg-slate-50 rounded-xl p-4 border border-dashed border-slate-300">
                   <h5 className="text-[13px] font-bold text-slate-700 flex items-center gap-1.5 mb-2.5">
                     <span className="text-xl">💡</span> Gợi ý dành cho Admin
                   </h5>
                   <ul className="text-xs text-slate-500 space-y-2 pl-5 list-disc leading-relaxed">
                       <li>Biên lợi nhuận của rạp chủ yếu đến từ F&B. Hãy cố gắng duy trì tỷ trọng Bắp Nước ở mức <strong>&gt; 35%</strong>.</li>
                       <li>Thường xuyên theo dõi <strong className="text-red-500">Cảnh báo trống ghế</strong> để có chiến lược tung Voucher kịp thời.</li>
                       <li>Tỷ lệ hoàn/hủy vé cao có thể do lỗi thanh toán từ cổng VNPay/MoMo/ZaloPay.</li>
                   </ul>
                </div>

              </div>
            ) : (
              <div className="text-center text-slate-400 text-xs italic bg-slate-50 p-8 rounded-xl border border-dashed border-slate-200">
                Chưa có dữ liệu giao dịch để phân tích.
              </div>
            )}
          </div>

        </div>

        {/* TOP PHIM VÀ BẮP NƯỚC */}
        <div className="flex-[1] bg-white rounded-2xl border border-slate-200 p-6 shadow-sm min-w-0 animate-[slide-in-bottom_0.6s_ease-out_backwards]" style={{ animationDelay: '500ms' }}>
          
          <div className="mb-8">
            <h4 className="m-0 text-slate-800 text-base font-bold mb-5 flex items-center gap-2">🎬 Top Phim Doanh Thu</h4>
            <div className="flex flex-col gap-4">
              {stats.topMovies.map((movie, index) => (
                <div key={index} className="flex gap-4 items-center group">
                  <div className="relative">
                    <div className="absolute -top-2 -left-2 bg-slate-800 text-white text-[10px] font-bold w-6 h-6 flex items-center justify-center rounded-md shadow-sm z-10">#{index + 1}</div>
                    <img src={getImageUrl(movie.poster_path)} alt={movie.title} className="w-14 h-20 rounded-lg object-cover shadow-sm group-hover:shadow-md transition-shadow" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <h4 className="m-0 text-slate-800 text-sm font-bold truncate" title={movie.title}>{movie.title}</h4>
                    <span className="text-emerald-600 bg-emerald-50 px-2 py-0.5 rounded text-[11px] font-bold mt-1.5 inline-block">{movie.tickets} Vé</span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <hr className="border-slate-100 mb-6" />

          <div>
            <h4 className="m-0 text-slate-800 text-base font-bold mb-5 flex items-center gap-2">🍿 Combo Bán Chạy</h4>
            <div className="flex flex-col gap-3">
              {stats.topFoods && stats.topFoods.length === 0 ? (
                <div className="text-center text-slate-400 p-4 text-sm bg-slate-50 rounded-xl border border-dashed border-slate-200">Chưa có dữ liệu F&B</div>
              ) : (
                stats.topFoods?.map((food, index) => {
                  const rankColor = index === 0 ? 'text-amber-500' : index === 1 ? 'text-slate-400' : index === 2 ? 'text-amber-700' : 'text-slate-300';
                  return (
                    <div key={index} className="flex items-center gap-3 bg-slate-50 hover:bg-slate-100 transition-colors p-2.5 rounded-xl border border-slate-100">
                      <div className={`text-base font-black w-6 text-center ${rankColor}`}>#{index + 1}</div>
                      <div className="w-10 h-10 bg-white rounded-lg shadow-sm overflow-hidden shrink-0 flex items-center justify-center p-1">
                        <img src={getFoodImagePath(food.image, food.brandId)} alt={food.name} className="w-full h-full object-contain" onError={(e) => { e.currentTarget.src = 'https://via.placeholder.com/50?text=Food'; }} />
                      </div>
                      <div className="flex-1 min-w-0">
                        <h4 className="m-0 text-slate-800 text-[13px] font-bold truncate leading-tight">{food.name}</h4>
                        <span className="text-slate-500 text-[11px]">Đã bán: <strong className="text-slate-700">{food.quantity}</strong></span>
                      </div>
                      <div className="font-bold text-amber-500 text-xs text-right whitespace-nowrap bg-amber-50 px-2 py-1 rounded-md">
                        {formatMoney(food.revenue)}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </div>
      </div>

      {/* 🚀 MODAL GHI CHÚ GIẢI PHÁP (ĐÃ NÂNG CẤP 2 Ô NHẬP LIỆU) */}
      {showNoteModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[2000] p-4 animate-[fade-in_0.2s_ease-out]">
          <div className="bg-white rounded-2xl w-[600px] max-w-full p-6 shadow-2xl animate-[slide-in-bottom_0.3s_ease-out]">
            <div className="flex justify-between items-center mb-6 border-b border-slate-100 pb-4">
              <h2 className="m-0 text-lg text-slate-800 font-bold flex items-center gap-2">
                <AlertTriangle size={20} className="text-amber-500"/> Báo Cáo Nguyên Nhân & Giải Pháp
              </h2>
              <button onClick={() => setShowNoteModal(false)} className="text-slate-400 hover:text-red-500 transition"><X size={20} /></button>
            </div>
            
            <div className="flex flex-col gap-5">
              {/* Ô 1: Nguyên nhân */}
              <div>
                <label className="block text-[13px] font-bold text-slate-700 mb-2 flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-red-500"></span> Xác định nguyên nhân ế khách:
                </label>
                <textarea 
                  value={noteCause} 
                  onChange={(e) => setNoteCause(e.target.value)} 
                  placeholder="VD: Giờ chiếu quá trễ, trùng với lịch thi đấu bóng đá, phim kén người xem..." 
                  className="w-full h-[80px] p-3 rounded-xl border border-slate-200 outline-none focus:border-red-400 focus:ring-4 focus:ring-red-50 resize-none text-sm bg-slate-50 hover:bg-white transition-colors" 
                />
              </div>

              {/* Ô 2: Giải pháp */}
              <div>
                <label className="block text-[13px] font-bold text-slate-700 mb-2 flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-emerald-500"></span> Đề xuất giải pháp cải thiện:
                </label>
                <textarea 
                  value={noteSolution} 
                  onChange={(e) => setNoteSolution(e.target.value)} 
                  placeholder="VD: Chuyển sang rạp nhỏ hơn, ghép suất, tặng kèm bắp nước cho khách đã đặt..." 
                  className="w-full h-[100px] p-3 rounded-xl border border-slate-200 outline-none focus:border-emerald-400 focus:ring-4 focus:ring-emerald-50 resize-none text-sm bg-slate-50 hover:bg-white transition-colors" 
                />
              </div>
            </div>

            <div className="flex justify-end gap-3 mt-6 pt-4 border-t border-slate-100">
              <button onClick={() => setShowNoteModal(false)} className="px-5 py-2.5 rounded-xl text-slate-600 font-bold text-sm hover:bg-slate-100 transition-colors">Đóng</button>
              <button onClick={handleSaveNote} className="flex items-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-6 py-2.5 rounded-xl font-bold text-sm shadow-md transition-all hover:-translate-y-0.5">
                <Save size={16} /> Lưu Báo Cáo
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 🚀 MODAL XEM TẤT CẢ GIAO DỊCH */}
      {showTransactionModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[2000] p-4 animate-[fade-in_0.2s_ease-out]">
          <div className="bg-white rounded-2xl w-[900px] max-w-full max-h-[85vh] flex flex-col shadow-2xl animate-[slide-in-bottom_0.3s_ease-out]">
            <div className="p-5 border-b border-slate-200 flex justify-between items-center bg-slate-50 rounded-t-2xl">
              <h2 className="m-0 text-lg text-slate-800 font-bold">Lịch Sử Toàn Bộ Giao Dịch</h2>
              <button onClick={() => setShowTransactionModal(false)} className="bg-slate-200 hover:bg-red-100 hover:text-red-600 text-slate-500 rounded-full w-8 h-8 flex items-center justify-center transition-colors"><X size={18} /></button>
            </div>
            <div className="overflow-y-auto p-6">
              <table className="w-full text-left border-collapse">
                 <thead className="bg-slate-100 text-slate-600">
                  <tr className="text-[11px] uppercase tracking-wider font-bold">
                    <th className="p-3 rounded-tl-lg">Tên Phim / Dịch Vụ</th>
                    <th className="p-3">Suất Chiếu</th>
                    <th className="p-3">Ghế</th>
                    <th className="p-3">Giá Tiền</th>
                    <th className="p-3 rounded-tr-lg">Trạng Thái</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {stats.recentBookings.map((b, idx) => (
                    <tr key={idx} className="hover:bg-slate-50 transition-colors">
                      <td className="p-3 font-bold text-slate-800 text-sm">{b.movie || 'Đơn thức ăn tại quầy'}</td>
                      <td className="p-3 text-slate-500 text-xs"><div className="font-bold text-slate-700">{b.time}</div><div>{b.date}</div></td>
                      <td className="p-3 text-slate-600 text-sm font-medium">{b.seats || 'Không có'}</td>
                      <td className="p-3 font-bold text-slate-800 text-sm">{formatMoney(b.price)}</td>
                      <td className="p-3">
                        {b.status === 'Paid' ? ( <span className="bg-emerald-50 text-emerald-600 border border-emerald-100 px-2.5 py-1 rounded-md text-[10px] font-bold">ĐÃ THANH TOÁN</span> ) : ( <span className="bg-amber-50 text-amber-600 border border-amber-100 px-2.5 py-1 rounded-md text-[10px] font-bold uppercase">{b.status}</span> )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* 🚀 KEYFRAMES TÙY CHỈNH CHO ANIMATION */}
      <style>{`
        @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
        @keyframes slide-in-bottom { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
      `}</style>
    </div>
  );
};

export default Dashboard;