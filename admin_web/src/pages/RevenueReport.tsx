import React, { useState, useEffect } from 'react';
import axios from 'axios';
import * as XLSX from 'xlsx';
import Swal from 'sweetalert2';
import { Calendar, FileSpreadsheet, Film, Ticket, Popcorn, Search, CalendarDays, MapPin, ChevronDown } from 'lucide-react';
import { useRef } from 'react'; // Bổ sung thêm useRef

const RevenueReport = () => {
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  
  // 🚀 ĐÃ BỔ SUNG: State lưu danh sách rạp và rạp đang chọn
  const [cinemas, setCinemas] = useState<any[]>([]);
  const [selectedCinema, setSelectedCinema] = useState('ALL');
  
  // 🚀 ĐÃ BỔ SUNG: STATE CHO COMBOBOX TÌM KIẾM RẠP
  const [isCinemaDropdownOpen, setIsCinemaDropdownOpen] = useState(false);
  const [cinemaSearchQuery, setCinemaSearchQuery] = useState('');
  const cinemaDropdownRef = useRef<HTMLDivElement>(null);

  const [reportData, setReportData] = useState({ 
      movies: [], foods: [], ticketsByDay: [], foodsByDay: [], allTickets: [], allFoods: [] 
  });
  
  const [isLoading, setIsLoading] = useState(false);
  const [activeTab, setActiveTab] = useState('MOVIES');

  const formatMoney = (amount: number) => new Intl.NumberFormat('vi-VN').format(amount || 0) + ' đ';
  const today = new Date().toISOString().split('T')[0];

  // 🚀 ĐÃ BỔ SUNG: Gọi API lấy danh sách rạp khi vừa mở trang
  useEffect(() => {
    const fetchCinemas = async () => {
      try {
        const response = await axios.get('http://10.173.120.41:3000/api/cinemas');
        setCinemas(response.data);
      } catch (error) {
        console.error("Lỗi lấy danh sách rạp:", error);
      }
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
    if (selectedCinema === 'ALL') return 'Tất cả chi nhánh';
    const found = cinemas.find(c => c.id.toString() === selectedCinema.toString());
    return found ? (found.name || found.Name) : 'Tất cả chi nhánh';
  };

  const generateReport = async () => {
    if (!startDate || !endDate) {
      Swal.fire('Thiếu thông tin', 'Vui lòng chọn Từ ngày và Đến ngày!', 'warning');
      return;
    }
    
    const start = new Date(startDate);
    const end = new Date(endDate);

    if (start > end) {
      Swal.fire('Lỗi logic', 'Ngày bắt đầu không được lớn hơn ngày kết thúc!', 'error');
      return;
    }

    const diffTime = Math.abs(end.getTime() - start.getTime());
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    if (diffDays > 365) {
      Swal.fire({
        icon: 'warning',
        title: 'Khoảng thời gian quá dài!',
        text: 'Để tránh quá tải hệ thống, vui lòng thống kê doanh thu trong khoảng thời gian tối đa là 1 năm (365 ngày).',
        confirmButtonColor: '#4f46e5'
      });
      return;
    }

    setIsLoading(true);
    try {
      // 🚀 ĐÃ SỬA: Truyền thêm biến cinemaId vào đường dẫn API
      const response = await axios.get(`http://10.173.120.41:3000/api/admin/reports/revenue?startDate=${startDate}&endDate=${endDate}&cinemaId=${selectedCinema}`);
      setReportData(response.data);
      Swal.fire({ icon: 'success', title: 'Lập báo cáo thành công', toast: true, position: 'top-end', showConfirmButton: false, timer: 1500 });
    } catch (error) {
      Swal.fire('Lỗi truy xuất', 'Không thể lấy dữ liệu báo cáo từ máy chủ!', 'error');
    } finally {
      setIsLoading(false);
    }
  };

  const exportToExcel = () => {
    if (reportData.movies.length === 0 && reportData.foods.length === 0) {
      Swal.fire('Trống', 'Không có dữ liệu để xuất Excel!', 'info');
      return;
    }

    const wb = XLSX.utils.book_new();

    const wsMovies = XLSX.utils.json_to_sheet(reportData.movies.map((m: any, i: number) => ({ 'STT': i + 1, 'Tên Phim': m.movieName, 'Số Vé': m.ticketsSold, 'Doanh Thu': m.totalRevenue })));
    XLSX.utils.book_append_sheet(wb, wsMovies, "Doanh Thu Phim");

    const wsFoods = XLSX.utils.json_to_sheet(reportData.foods.map((f: any, i: number) => ({ 'STT': i + 1, 'Tên Món': f.foodName, 'Số Lượng': f.quantitySold, 'Doanh Thu': f.totalRevenue })));
    XLSX.utils.book_append_sheet(wb, wsFoods, "Doanh Thu Bắp Nước");

    const wsTicketsDay = XLSX.utils.json_to_sheet(reportData.ticketsByDay.map((t: any, i: number) => ({ 'STT': i + 1, 'Ngày': t.date, 'Tổng Vé': t.totalTickets, 'Doanh Thu': t.totalRevenue })));
    XLSX.utils.book_append_sheet(wb, wsTicketsDay, "Doanh Thu Vé Theo Ngày");

    const wsFoodsDay = XLSX.utils.json_to_sheet(reportData.foodsByDay.map((f: any, i: number) => ({ 'STT': i + 1, 'Ngày': f.date, 'Tổng SP': f.totalQuantity, 'Doanh Thu': f.totalRevenue })));
    XLSX.utils.book_append_sheet(wb, wsFoodsDay, "Doanh Thu Đồ Ăn Theo Ngày");

    const wsAllTickets = XLSX.utils.json_to_sheet(reportData.allTickets.map((t: any, i: number) => ({ 'STT': i + 1, 'Mã Hóa Đơn': t.bookingId, 'Thời Gian': t.time, 'Phim': t.movieName, 'Ghế': t.seat, 'Giá Tiền': t.price })));
    XLSX.utils.book_append_sheet(wb, wsAllTickets, "Chi Tiết Vé Đã Bán");

    const wsAllFoods = XLSX.utils.json_to_sheet(reportData.allFoods.map((f: any, i: number) => ({ 'STT': i + 1, 'Mã Hóa Đơn': f.bookingId, 'Thời Gian': f.time, 'Món': f.foodName, 'Số Lượng': f.quantity, 'Thành Tiền': f.total })));
    XLSX.utils.book_append_sheet(wb, wsAllFoods, "Chi Tiết Đồ Ăn Đã Bán");

    // 🚀 Lấy tên rạp để đặt tên file cho chuẩn xác
    const cinemaName = selectedCinema === 'ALL' ? 'Toàn_Hệ_Thống' : (cinemas.find(c => c.id.toString() === selectedCinema)?.name || 'Chi_Nhanh').replace(/[^a-zA-Z0-9]/g, '_');
    XLSX.writeFile(wb, `Bao_Cao_Doanh_Thu_${cinemaName}.xlsx`);
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] animate-[fade-in_0.3s_ease-out]">
      
      <div className="bg-white p-4 rounded-2xl shadow-sm border border-slate-200 mb-6 flex flex-col xl:flex-row justify-between items-start xl:items-end gap-4">
        
        <div className="flex flex-wrap items-end gap-4 w-full xl:w-auto">
          {/* 🚀 ĐÃ NÂNG CẤP: Ô CHỌN CHI NHÁNH DẠNG COMBOBOX (GÕ ĐỂ TÌM KIẾM) */}
          <div className="w-full sm:w-auto z-50" ref={cinemaDropdownRef}>
            <label className="block text-xs font-bold text-slate-500 mb-1">Cơ sở / Chi nhánh</label>
            <div className="relative w-full sm:w-64">
              {/* Nút bấm hiển thị */}
              <div 
                onClick={() => setIsCinemaDropdownOpen(!isCinemaDropdownOpen)}
                className={`w-full pl-9 pr-4 py-2 bg-slate-50 border rounded-lg outline-none transition-all text-sm font-bold text-slate-700 cursor-pointer flex items-center justify-between select-none ${isCinemaDropdownOpen ? 'border-indigo-500 bg-white ring-2 ring-indigo-50' : 'border-slate-200 hover:border-slate-300'}`}
              >
                <MapPin className={`absolute left-3 top-1/2 transform -translate-y-1/2 transition-colors ${isCinemaDropdownOpen ? 'text-indigo-500' : 'text-slate-400'}`} size={16} />
                <span className="truncate pr-2">{getSelectedCinemaName()}</span>
                <ChevronDown size={14} className={`text-slate-400 transition-transform duration-200 flex-shrink-0 ${isCinemaDropdownOpen ? 'rotate-180 text-indigo-500' : ''}`} />
              </div>

              {/* Menu sổ xuống và ô search */}
              {isCinemaDropdownOpen && (
                <div className="absolute top-[110%] left-0 w-full bg-white border border-slate-200 rounded-xl shadow-xl z-50 overflow-hidden animate-[fade-in_0.15s_ease-out]">
                  <div className="p-2 border-b border-slate-100 bg-slate-50/80">
                    <input 
                      type="text" 
                      placeholder="Nhập tên rạp để tìm..." 
                      value={cinemaSearchQuery}
                      onChange={(e) => setCinemaSearchQuery(e.target.value)}
                      className="w-full px-3 py-2 text-sm bg-white border border-slate-200 rounded-lg outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-50"
                      autoFocus 
                    />
                  </div>
                  
                  <div className="max-h-60 overflow-y-auto p-1">
                    <div 
                      onClick={() => { setSelectedCinema('ALL'); setIsCinemaDropdownOpen(false); setCinemaSearchQuery(''); }}
                      className={`px-3 py-2.5 rounded-lg text-sm cursor-pointer transition-colors ${selectedCinema === 'ALL' ? 'bg-indigo-50 text-indigo-700 font-bold' : 'text-slate-700 hover:bg-slate-100 font-medium'}`}
                    >
                      Tất cả chi nhánh
                    </div>
                    {cinemas
                      .filter(c => (c.name || c.Name).toLowerCase().includes(cinemaSearchQuery.toLowerCase()))
                      .map(c => (
                        <div 
                          key={c.id} 
                          onClick={() => { setSelectedCinema(c.id.toString()); setIsCinemaDropdownOpen(false); setCinemaSearchQuery(''); }}
                          className={`px-3 py-2.5 rounded-lg text-sm cursor-pointer transition-colors ${selectedCinema === c.id.toString() ? 'bg-indigo-50 text-indigo-700 font-bold' : 'text-slate-700 hover:bg-slate-100 font-medium'}`}
                        >
                          {c.name || c.Name}
                        </div>
                    ))}
                    {cinemas.filter(c => (c.name || c.Name).toLowerCase().includes(cinemaSearchQuery.toLowerCase())).length === 0 && (
                      <div className="px-3 py-4 text-center text-slate-400 text-sm italic">
                        Không tìm thấy rạp nào
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-500 mb-1">Từ ngày</label>
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400" size={16} />
              <input type="date" max={today} value={startDate} onChange={(e) => setStartDate(e.target.value)} className="pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg outline-none focus:border-blue-500 text-sm font-bold w-full sm:w-auto" />
            </div>
          </div>
          <div>
            <label className="block text-xs font-bold text-slate-500 mb-1">Đến ngày</label>
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400" size={16} />
              <input type="date" max={today} value={endDate} onChange={(e) => setEndDate(e.target.value)} className="pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg outline-none focus:border-blue-500 text-sm font-bold w-full sm:w-auto" />
            </div>
          </div>
          <button onClick={generateReport} disabled={isLoading} className="flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-bold transition-all h-[38px] mt-2 sm:mt-auto disabled:opacity-50 disabled:cursor-not-allowed w-full sm:w-auto">
            {isLoading ? <span className="animate-spin text-xl">↻</span> : <Search size={16} />} Lập Báo Cáo
          </button>
        </div>

        <button onClick={exportToExcel} className="flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white px-5 py-2 rounded-lg font-bold transition-all shadow-sm shadow-emerald-200 h-[38px] mt-auto w-full xl:w-auto">
          <FileSpreadsheet size={18} /> Xuất Excel
        </button>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="flex border-b border-slate-200 bg-slate-50/50 overflow-x-auto">
          <button onClick={() => setActiveTab('MOVIES')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'MOVIES' ? 'text-blue-600 border-b-2 border-blue-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><Film size={16} /> Doanh Thu Phim</button>
          <button onClick={() => setActiveTab('FOODS')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'FOODS' ? 'text-amber-600 border-b-2 border-amber-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><Popcorn size={16} /> Doanh Thu Đồ Ăn</button>
          <button onClick={() => setActiveTab('TICKETS_DAY')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'TICKETS_DAY' ? 'text-emerald-600 border-b-2 border-emerald-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><Ticket size={16} /> Vé (Theo Ngày)</button>
          <button onClick={() => setActiveTab('FOODS_DAY')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'FOODS_DAY' ? 'text-purple-600 border-b-2 border-purple-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><CalendarDays size={16} /> Đồ Ăn (Theo Ngày)</button>
        </div>

        <div className="p-0 overflow-x-auto">
          {activeTab === 'MOVIES' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Tên Phim</th><th className="p-4 text-center">Số Vé Bán</th><th className="p-4 text-right">Tổng Doanh Thu</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.movies.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.movies.map((m: any, idx) => <tr key={idx} className="hover:bg-slate-50"><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold text-slate-800">{m.movieName}</td><td className="p-4 text-center">{m.ticketsSold}</td><td className="p-4 text-right font-black text-blue-600">{formatMoney(m.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

          {activeTab === 'FOODS' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Tên Món</th><th className="p-4 text-center">Đã Bán</th><th className="p-4 text-right">Tổng Doanh Thu</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.foods.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.foods.map((f: any, idx) => <tr key={idx} className="hover:bg-slate-50"><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold text-slate-800">{f.foodName}</td><td className="p-4 text-center">{f.quantitySold}</td><td className="p-4 text-right font-black text-amber-600">{formatMoney(f.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

          {activeTab === 'TICKETS_DAY' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Ngày Giao Dịch</th><th className="p-4 text-center">Tổng Vé</th><th className="p-4 text-right">Doanh Thu Trong Ngày</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.ticketsByDay.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.ticketsByDay.map((t: any, idx) => <tr key={idx} className="hover:bg-slate-50"><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold text-slate-800">{t.date}</td><td className="p-4 text-center">{t.totalTickets}</td><td className="p-4 text-right font-black text-emerald-600">{formatMoney(t.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

          {activeTab === 'FOODS_DAY' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Ngày Giao Dịch</th><th className="p-4 text-center">Tổng Sản Phẩm Bán Ra</th><th className="p-4 text-right">Doanh Thu Trong Ngày</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.foodsByDay.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.foodsByDay.map((f: any, idx) => <tr key={idx} className="hover:bg-slate-50"><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold text-slate-800">{f.date}</td><td className="p-4 text-center">{f.totalQuantity}</td><td className="p-4 text-right font-black text-purple-600">{formatMoney(f.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

        </div>
      </div>
    </div>
  );
};

export default RevenueReport;