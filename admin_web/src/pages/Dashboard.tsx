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
  
  const [filterMode, setFilterMode] = useState('ALL_TIME'); 
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]);

  const [showTransactionModal, setShowTransactionModal] = useState(false);
  const [showNoteModal, setShowNoteModal] = useState(false);
  
  const [currentNoteId, setCurrentNoteId] = useState<string | null>(null);
  const [adminNote, setAdminNote] = useState('');

  useEffect(() => {
    const fetchCinemas = async () => {
      try {
        const response = await axios.get('http://192.168.1.7:3000/api/cinemas');
        setCinemas(response.data);
      } catch (error) {}
    };
    fetchCinemas();
  }, []);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const dateQuery = filterMode === 'ALL_TIME' ? '' : selectedDate;
        const response = await axios.get(`http://192.168.1.7:3000/api/admin/dashboard/summary?cinemaId=${selectedCinema}&date=${dateQuery}`);
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
      return `http://192.168.1.7:3000/${cleanPath}`;
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
        return `http://192.168.1.7:3000/public/uploads/${filename}`;
      } else {
        // Còn lại (VD: food-178...jpg) -> Nằm ở public/foods/
        return `http://192.168.1.7:3000/public/foods/${filename}`;
      }
    }

    // 3. Xử lý ảnh tĩnh mặc định trong thư mục assets (Giống y hệt Flutter)
    const folders: Record<number, string> = { 1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags', 7: 'dcine', 8: 'beta', 9: 'aeonbeta' };
    const folder = folders[brandId] || 'cgv';
    
    if (img.startsWith('/')) img = img.substring(1);
    if (img.startsWith('assets/')) return `http://192.168.1.7:3000/${img}`; 
    if (img.startsWith(`${folder}/`)) return `http://192.168.1.7:3000/assets/${img}`;
    
    return `http://192.168.1.7:3000/assets/${folder}/${img}`;
  };

  const openNoteModal = (showtimeId: string) => {
    setCurrentNoteId(showtimeId);
    const savedNote = localStorage.getItem(`note_showtime_${showtimeId}`);
    setAdminNote(savedNote || '');
    setShowNoteModal(true);
  };

  const handleSaveNote = () => {
    if (currentNoteId) {
      localStorage.setItem(`note_showtime_${currentNoteId}`, adminNote);
      Toast.fire({ icon: 'success', title: 'Đã lưu ghi chú giải pháp thành công!' }); // 🚀 ĐÃ SỬA SANG THÔNG BÁO XỊN
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

        {/* Bộ lọc Rạp */}
        <div className="relative w-full xl:w-64 group">
          <MapPin className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={18} />
          <select 
            value={selectedCinema} 
            onChange={(e) => setSelectedCinema(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 transition-all text-sm font-bold text-slate-700 cursor-pointer appearance-none"
          >
            <option value="ALL">Tất cả Rạp (Toàn quốc)</option>
            {cinemas.map(c => (
              <option key={c.id} value={c.id}>{c.Name || c.name}</option>
            ))}
          </select>
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
                        <button 
                          onClick={() => openNoteModal(showtime.id)}
                          className="inline-flex items-center justify-center gap-2 bg-white text-red-600 border border-red-200 hover:bg-red-50 hover:border-red-300 px-4 py-2 rounded-lg text-xs font-bold transition-all shadow-sm"
                        >
                          <PenTool size={14} /> Ghi chú giải pháp
                        </button>
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

      {/* 🚀 MODAL GHI CHÚ GIẢI PHÁP */}
      {showNoteModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[2000] p-4 animate-[fade-in_0.2s_ease-out]">
          <div className="bg-white rounded-2xl w-[500px] max-w-full p-6 shadow-2xl animate-[slide-in-bottom_0.3s_ease-out]">
            <div className="flex justify-between items-center mb-4 border-b border-slate-100 pb-4">
              <h2 className="m-0 text-lg text-slate-800 font-bold flex items-center gap-2"><PenTool size={20} className="text-red-500"/> Ghi chú khắc phục</h2>
              <button onClick={() => setShowNoteModal(false)} className="text-slate-400 hover:text-red-500 transition"><X size={20} /></button>
            </div>
            <p className="text-[13px] text-slate-500 mb-3">Đề xuất các biện pháp xử lý (khuyến mãi mồi, tặng kèm voucher, thông báo hủy...) cho suất chiếu này:</p>
            <textarea 
              value={adminNote} 
              onChange={(e) => setAdminNote(e.target.value)} 
              placeholder="Nhập ghi chú tại đây..." 
              className="w-full h-[150px] p-4 rounded-xl border border-slate-200 outline-none focus:border-blue-500 focus:ring-4 focus:ring-blue-50 resize-none text-sm bg-slate-50 hover:bg-white transition-colors" 
            />
            <div className="flex justify-end mt-4">
              <button onClick={handleSaveNote} className="flex items-center gap-2 bg-red-500 hover:bg-red-600 text-white px-5 py-2.5 rounded-xl font-bold text-sm shadow-sm shadow-red-200 transition-all hover:-translate-y-0.5">
                <Save size={16} /> Lưu Ghi Chú
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