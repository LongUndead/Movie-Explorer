import React, { useState } from 'react';
import axios from 'axios';
import * as XLSX from 'xlsx';
import Swal from 'sweetalert2';
import { Calendar, FileSpreadsheet, Film, Ticket, Popcorn, Search, CalendarDays } from 'lucide-react';

const RevenueReport = () => {
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  
  const [reportData, setReportData] = useState({ 
      movies: [], foods: [], ticketsByDay: [], foodsByDay: [], allTickets: [], allFoods: [] 
  });
  
  const [isLoading, setIsLoading] = useState(false);
  const [activeTab, setActiveTab] = useState('MOVIES');

  const formatMoney = (amount: number) => new Intl.NumberFormat('vi-VN').format(amount || 0) + ' đ';

  // Lấy ngày hôm nay theo chuẩn YYYY-MM-DD để khóa lịch
  const today = new Date().toISOString().split('T')[0];

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

    // 🚀 CHỐT CHẶN: GIỚI HẠN KHOẢNG CÁCH TRUY VẤN TỐI ĐA 1 NĂM (365 NGÀY)
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
      const response = await axios.get(`http://192.168.1.7:3000/api/admin/reports/revenue?startDate=${startDate}&endDate=${endDate}`);
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

    XLSX.writeFile(wb, `Bao_Cao_Doanh_Thu_Full.xlsx`);
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] animate-[fade-in_0.3s_ease-out]">
      
      {/* 🚀 ĐÃ SỬA: GOM CỤM TÌM KIẾM VÀ XUẤT EXCEL LÊN THÀNH 1 THANH TOPBAR NHỎ */}
      <div className="bg-white p-4 rounded-2xl shadow-sm border border-slate-200 mb-6 flex flex-col md:flex-row justify-between items-start md:items-end gap-4">
        
        {/* Cụm lọc ngày tháng */}
        <div className="flex flex-wrap items-end gap-4">
          <div>
            <label className="block text-xs font-bold text-slate-500 mb-1">Từ ngày</label>
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400" size={16} />
              {/* 🚀 ĐÃ THÊM max={today} */}
              <input type="date" max={today} value={startDate} onChange={(e) => setStartDate(e.target.value)} className="pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg outline-none focus:border-blue-500 text-sm font-bold" />
            </div>
          </div>
          <div>
            <label className="block text-xs font-bold text-slate-500 mb-1">Đến ngày</label>
            <div className="relative">
              <Calendar className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400" size={16} />
              {/* 🚀 ĐÃ THÊM max={today} */}
              <input type="date" max={today} value={endDate} onChange={(e) => setEndDate(e.target.value)} className="pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-lg outline-none focus:border-blue-500 text-sm font-bold" />
            </div>
          </div>
          <button onClick={generateReport} disabled={isLoading} className="flex items-center gap-2 bg-blue-600 hover:bg-blue-700 text-white px-6 py-2 rounded-lg font-bold transition-all h-[38px] mt-auto disabled:opacity-50 disabled:cursor-not-allowed">
            {isLoading ? <span className="animate-spin text-xl">↻</span> : <Search size={16} />} Lập Báo Cáo
          </button>
        </div>

        {/* Nút xuất Excel đẩy sang phải */}
        <button onClick={exportToExcel} className="flex items-center gap-2 bg-emerald-600 hover:bg-emerald-700 text-white px-5 py-2 rounded-lg font-bold transition-all shadow-sm shadow-emerald-200 h-[38px] mt-auto">
          <FileSpreadsheet size={18} /> Xuất Excel
        </button>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        {/* MENU TAB ĐÃ ĐƯỢC GIỮ NGUYÊN (Gồm 4 Tab theo chuẩn) */}
        <div className="flex border-b border-slate-200 bg-slate-50/50 overflow-x-auto">
          <button onClick={() => setActiveTab('MOVIES')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'MOVIES' ? 'text-blue-600 border-b-2 border-blue-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><Film size={16} /> Doanh Thu Phim</button>
          <button onClick={() => setActiveTab('FOODS')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'FOODS' ? 'text-amber-600 border-b-2 border-amber-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><Popcorn size={16} /> Doanh Thu Đồ Ăn</button>
          <button onClick={() => setActiveTab('TICKETS_DAY')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'TICKETS_DAY' ? 'text-emerald-600 border-b-2 border-emerald-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><Ticket size={16} /> Vé (Theo Ngày)</button>
          <button onClick={() => setActiveTab('FOODS_DAY')} className={`px-4 py-4 font-bold text-[13px] flex items-center justify-center gap-2 whitespace-nowrap transition-colors ${activeTab === 'FOODS_DAY' ? 'text-purple-600 border-b-2 border-purple-600 bg-white' : 'text-slate-500 hover:bg-slate-100'}`}><CalendarDays size={16} /> Đồ Ăn (Theo Ngày)</button>
        </div>

        {/* NỘI DUNG TỪNG TAB */}
        <div className="p-0 overflow-x-auto">
          
          {activeTab === 'MOVIES' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Tên Phim</th><th className="p-4 text-center">Số Vé Bán</th><th className="p-4 text-right">Tổng Doanh Thu</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.movies.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.movies.map((m: any, idx) => <tr key={idx}><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold">{m.movieName}</td><td className="p-4 text-center">{m.ticketsSold}</td><td className="p-4 text-right font-black text-blue-600">{formatMoney(m.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

          {activeTab === 'FOODS' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Tên Món</th><th className="p-4 text-center">Đã Bán</th><th className="p-4 text-right">Tổng Doanh Thu</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.foods.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.foods.map((f: any, idx) => <tr key={idx}><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold">{f.foodName}</td><td className="p-4 text-center">{f.quantitySold}</td><td className="p-4 text-right font-black text-amber-600">{formatMoney(f.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

          {activeTab === 'TICKETS_DAY' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Ngày Giao Dịch</th><th className="p-4 text-center">Tổng Vé</th><th className="p-4 text-right">Doanh Thu Trong Ngày</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.ticketsByDay.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.ticketsByDay.map((t: any, idx) => <tr key={idx}><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold">{t.date}</td><td className="p-4 text-center">{t.totalTickets}</td><td className="p-4 text-right font-black text-emerald-600">{formatMoney(t.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

          {activeTab === 'FOODS_DAY' && (
            <table className="w-full text-left border-collapse min-w-[600px]"><thead className="bg-slate-50"><tr className="text-xs uppercase font-bold text-slate-500"><th className="p-4 w-16">STT</th><th className="p-4">Ngày Giao Dịch</th><th className="p-4 text-center">Tổng Sản Phẩm Bán Ra</th><th className="p-4 text-right">Doanh Thu Trong Ngày</th></tr></thead>
              <tbody className="divide-y divide-slate-100">{reportData.foodsByDay.length === 0 ? <tr><td colSpan={4} className="p-8 text-center text-slate-400">Chưa có dữ liệu</td></tr> : reportData.foodsByDay.map((f: any, idx) => <tr key={idx}><td className="p-4 text-slate-400">{idx + 1}</td><td className="p-4 font-bold">{f.date}</td><td className="p-4 text-center">{f.totalQuantity}</td><td className="p-4 text-right font-black text-purple-600">{formatMoney(f.totalRevenue)}</td></tr>)}</tbody>
            </table>
          )}

        </div>
      </div>
    </div>
  );
};

export default RevenueReport;