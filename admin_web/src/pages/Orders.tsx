import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2'; // 🚀 IMPORT THƯ VIỆN SAAS
import { Search, CheckCircle, XCircle, RotateCcw, Ticket, Popcorn, Filter, MapPin } from 'lucide-react';

// 🚀 CẤU HÌNH TOAST
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

interface Order {
  BookingID: number;
  TotalAmount: string;
  Status: string;
  OrderDate: string;
  Username: string;
  Email: string;
  MovieTitle: string;
  CinemaName: string;
  RoomName: string;
  Showtime: string;
  Seats: string;
  Foods: string;
  RefundReason?: string;
}

const Orders = () => {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  
  // 🚀 BỘ STATES CHO SMART FILTERS
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState<'ALL' | 'PAID' | 'REFUND_PENDING' | 'REFUNDED'>('ALL');
  const [selectedCinema, setSelectedCinema] = useState<string>('ALL');
  const [orderType, setOrderType] = useState<'ALL' | 'MOVIE' | 'FOOD_ONLY'>('ALL');

  const API_URL = 'http://192.168.1.7:3000/api/admin/orders';

  useEffect(() => {
    fetchOrders();
  }, []);

  const fetchOrders = async () => {
    setLoading(true);
    try {
      const res = await axios.get(API_URL);
      setOrders(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Lỗi tải danh sách đơn hàng!' });
    } finally {
      setLoading(false);
    }
  };

  // 🚀 HÀM MỚI: XỬ LÝ HOÀN TIỀN (XEM THÔNG TIN NGÂN HÀNG VÀ DUYỆT/TỪ CHỐI)
  const handleProcessRefund = (order: Order) => {
    // Tách Lý do và Thông tin ngân hàng (Giả sử Mobile app gửi lên theo định dạng: "Lý do hủy \n Ngân hàng: VCB...")
    // Nếu không có dấu phân cách rõ ràng, ta cứ hiển thị toàn bộ nội dung RefundReason
    const fullReason = order.RefundReason || 'Khách yêu cầu hủy';

    Swal.fire({
      title: `<h3 class="text-xl font-bold text-slate-800">Xử lý hoàn tiền #${order.BookingID}</h3>`,
      html: `
        <div class="text-left bg-slate-50 p-4 rounded-xl border border-slate-200 mt-2">
          <p class="text-sm text-slate-600 mb-2"><b>Khách hàng:</b> ${order.Username} (${order.Email})</p>
          <p class="text-sm text-slate-600 mb-2"><b>Số tiền cần hoàn:</b> <span class="text-red-500 font-bold text-lg">${formatCurrency(order.TotalAmount)}</span></p>
          <hr class="my-3 border-slate-200" />
          <p class="text-sm text-slate-800 font-bold mb-1">Lý do & Thông tin nhận tiền:</p>
          <div class="bg-white p-3 border border-slate-200 rounded-lg text-sm text-slate-700 whitespace-pre-wrap select-all">
            ${fullReason}
          </div>
          <p class="text-xs text-orange-600 mt-3 italic">* Vui lòng copy thông tin trên, thực hiện chuyển khoản thủ công, sau đó mới nhấn Duyệt.</p>
        </div>
      `,
      showDenyButton: true,
      showCancelButton: true,
      confirmButtonText: 'Đã CK & Duyệt',
      denyButtonText: 'Từ chối',
      cancelButtonText: 'Đóng',
      confirmButtonColor: '#10b981', // Màu xanh
      denyButtonColor: '#ef4444',    // Màu đỏ
      cancelButtonColor: '#94a3b8',
      width: '500px',
    }).then(async (result) => {
      if (result.isConfirmed) {
        // GỌI API DUYỆT
        processRefundApi(order.BookingID, 'approve');
      } else if (result.isDenied) {
        // GỌI API TỪ CHỐI
        processRefundApi(order.BookingID, 'reject');
      }
    });
  };

  // Hàm gọi API (Tách ra cho gọn code)
  const processRefundApi = async (bookingId: number, action: 'approve' | 'reject') => {
    try {
      const res = await axios.put(`${API_URL}/refund/${bookingId}`, { action });
      Toast.fire({ icon: 'success', title: res.data.message });
      fetchOrders(); 
    } catch (error: any) {
      Swal.fire('Lỗi', error.response?.data?.error || "Có lỗi xảy ra khi xử lý.", 'error');
    }
  };

  // Tự động trích xuất danh sách Rạp từ dữ liệu đơn hàng để làm Dropdown
  const uniqueCinemas = useMemo(() => {
    const cinemas = new Set(orders.map(o => o.CinemaName).filter(Boolean));
    return Array.from(cinemas);
  }, [orders]);

  // 🚀 THUẬT TOÁN LỌC THÔNG MINH ĐA ĐIỀU KIỆN
  const filteredOrders = orders.filter(order => {
    // 1. Lọc theo thanh tìm kiếm
    const searchLower = searchTerm.toLowerCase();
    const matchesSearch = 
      order.BookingID.toString().includes(searchTerm) || 
      order.Username.toLowerCase().includes(searchLower) ||
      order.Email.toLowerCase().includes(searchLower) ||
      (order.MovieTitle && order.MovieTitle.toLowerCase().includes(searchLower));
    
    // 2. Lọc theo trạng thái (Tabs)
    const matchesTab = 
      activeTab === 'ALL' ? true :
      activeTab === 'PAID' ? order.Status === 'Paid' :
      activeTab === 'REFUND_PENDING' ? order.Status === 'Refund Pending' :
      activeTab === 'REFUNDED' ? order.Status === 'Refunded' : true;

    // 3. Lọc theo Rạp
    const matchesCinema = selectedCinema === 'ALL' ? true : order.CinemaName === selectedCinema;

    // 4. Lọc theo Loại đơn (Vé phim hay Chỉ ăn uống)
    const matchesType = 
      orderType === 'ALL' ? true :
      orderType === 'MOVIE' ? !!order.MovieTitle :
      orderType === 'FOOD_ONLY' ? (!order.MovieTitle && !!order.Foods) : true;

    return matchesSearch && matchesTab && matchesCinema && matchesType;
  });

  // Render Badge trạng thái
  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'Paid': return <span className="px-3 py-1 bg-emerald-100 text-emerald-700 rounded-full text-xs font-bold flex items-center gap-1 w-max shadow-sm"><CheckCircle size={12}/> Thành công</span>;
      case 'Refund Pending': return <span className="px-3 py-1 bg-amber-100 text-amber-700 rounded-full text-xs font-bold flex items-center gap-1 w-max animate-pulse shadow-sm"><RotateCcw size={12}/> Chờ hoàn tiền</span>;
      case 'Refunded': return <span className="px-3 py-1 bg-slate-200 text-slate-600 rounded-full text-xs font-bold flex items-center gap-1 w-max shadow-sm"><RotateCcw size={12}/> Đã hoàn tiền</span>;
      case 'Cancelled': return <span className="px-3 py-1 bg-red-100 text-red-700 rounded-full text-xs font-bold flex items-center gap-1 w-max shadow-sm"><XCircle size={12}/> Đã hủy</span>;
      default: return <span className="px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-xs font-bold shadow-sm">{status}</span>;
    }
  };

  const formatCurrency = (amount: string | number) => {
    return Number(amount).toLocaleString('vi-VN') + ' đ';
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] animate-[fade-in_0.3s_ease-out]">
      
      {/* 🚀 THANH BỘ LỌC THÔNG MINH (SMART FILTERS BAR) */}
      <div className="flex flex-col xl:flex-row gap-4 mb-6 justify-between items-start xl:items-center bg-white p-4 rounded-2xl shadow-sm border border-slate-200">
        
        {/* Nhóm Tabs Trạng Thái */}
        <div className="flex bg-slate-100 p-1.5 rounded-xl w-full xl:w-auto overflow-x-auto no-scrollbar">
          {[
            { id: 'ALL', label: 'Tất cả' },
            { id: 'PAID', label: 'Thành công' },
            { id: 'REFUND_PENDING', label: 'Chờ hoàn', alert: orders.filter(o => o.Status === 'Refund Pending').length },
            { id: 'REFUNDED', label: 'Đã hoàn' }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`px-4 py-2 rounded-lg font-bold text-sm whitespace-nowrap transition-all flex items-center gap-2 ${
                activeTab === tab.id 
                  ? 'bg-white text-blue-700 shadow-sm transform scale-105' 
                  : 'text-slate-500 hover:text-slate-800 hover:bg-slate-200'
              }`}
            >
              {tab.label}
              {tab.alert ? <span className="bg-red-500 text-white text-[10px] px-2 py-0.5 rounded-full shadow-sm">{tab.alert}</span> : null}
            </button>
          ))}
        </div>

        {/* Nhóm Dropdown Lọc & Tìm Kiếm */}
        <div className="flex flex-wrap xl:flex-nowrap gap-3 w-full xl:w-auto">
          
          {/* Lọc theo Loại đơn */}
          <div className="relative flex-1 xl:flex-none xl:w-44 group">
            <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={16} />
            <select 
              value={orderType}
              onChange={(e) => setOrderType(e.target.value as any)}
              className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 text-sm font-semibold text-slate-700 cursor-pointer appearance-none transition-all"
            >
              <option value="ALL">Mọi loại đơn</option>
              <option value="MOVIE">Vé xem phim</option>
              <option value="FOOD_ONLY">Chỉ mua F&B tại quầy</option>
            </select>
          </div>

          {/* Lọc theo Rạp */}
          <div className="relative flex-1 xl:flex-none xl:w-48 group">
            <MapPin className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={16} />
            <select 
              value={selectedCinema}
              onChange={(e) => setSelectedCinema(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 text-sm font-semibold text-slate-700 cursor-pointer appearance-none transition-all"
            >
              <option value="ALL">Tất cả rạp chiếu</option>
              {uniqueCinemas.map((cinema, idx) => (
                <option key={idx} value={cinema}>{cinema}</option>
              ))}
            </select>
          </div>

          {/* Ô Tìm Kiếm */}
          <div className="relative w-full xl:w-64 group">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={16} />
            <input 
              type="text" 
              placeholder="Tìm mã đơn, KH, phim..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all"
            />
          </div>

        </div>
      </div>

      {/* BẢNG DỮ LIỆU ĐƠN HÀNG */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[900px]">
            <thead className="bg-slate-800 text-white">
              <tr>
                <th className="p-4 text-xs font-bold uppercase tracking-wider w-[12%]">Mã Đơn & Thời gian</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider w-[18%]">Khách hàng</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider w-[32%]">Chi tiết dịch vụ (Vé & F&B)</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider w-[13%]">Tổng tiền</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider text-center w-[12%]">Trạng thái</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider text-center w-[13%]">Xử lý hoàn tiền</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr><td colSpan={6} className="p-10 text-center text-slate-500 font-medium">Đang tải dữ liệu...</td></tr>
              ) : filteredOrders.length === 0 ? (
                <tr>
                   <td colSpan={6} className="p-10 text-center animate-[fade-in_0.5s_ease-out]">
                      <div className="flex flex-col items-center justify-center text-slate-400">
                         <Search size={40} className="mb-3 opacity-20" />
                         <span className="font-medium text-sm">Không tìm thấy đơn hàng nào phù hợp với bộ lọc.</span>
                      </div>
                   </td>
                </tr>
              ) : (
                filteredOrders.map((order, index) => (
                  <tr 
                    key={order.BookingID} 
                    style={{ animationDelay: `${index * 40}ms` }}
                    className="hover:bg-blue-50/50 transition-colors animate-[slide-in-top_0.4s_ease-out_backwards]"
                  >
                    <td className="p-4 align-top">
                      <div className="font-mono font-black text-blue-700 bg-blue-100/50 border border-blue-200 px-2 py-1 rounded inline-block shadow-sm">#{order.BookingID}</div>
                      <div className="text-[11px] text-slate-500 mt-2 font-semibold flex items-center gap-1"><span className="w-1.5 h-1.5 rounded-full bg-slate-300"></span> {order.OrderDate}</div>
                    </td>
                    <td className="p-4 align-top">
                      <div className="font-bold text-slate-800">{order.Username}</div>
                      <div className="text-xs text-slate-500 mt-1 font-medium">{order.Email}</div>
                    </td>
                    <td className="p-4 align-top">
                      {order.MovieTitle ? (
                        <div className="mb-2.5 border-b border-slate-100 pb-2.5">
                          <div className="font-bold text-slate-800 line-clamp-1 text-sm">{order.MovieTitle}</div>
                          <div className="text-[12px] text-slate-600 mt-1.5 flex items-center gap-1.5 font-medium"><Ticket size={13} className="text-blue-500"/> {order.CinemaName} - {order.RoomName}</div>
                          <div className="text-[11px] font-bold text-blue-600 mt-1.5 flex gap-2 items-center">
                            <span className="bg-blue-50 border border-blue-100 px-2 py-0.5 rounded shadow-sm">{order.Showtime}</span>
                            <span className="text-slate-500">•</span>
                            <span>Ghế: {order.Seats || 'Không có'}</span>
                          </div>
                        </div>
                      ) : (
                         <div className="mb-2 font-bold text-orange-600 bg-orange-50 px-2.5 py-1.5 rounded-lg inline-block text-xs border border-orange-200 shadow-sm">
                            🍿 Đơn hàng chỉ mua đồ ăn (Tại quầy)
                         </div>
                      )}

                      {order.Foods ? (
                         <div className="text-xs text-slate-700 font-bold flex items-start gap-1.5 leading-relaxed bg-slate-100/70 p-2.5 rounded-lg border border-slate-200 shadow-sm">
                           <Popcorn size={14} className="text-orange-500 shrink-0 mt-0.5" /> 
                           <span className="line-clamp-2">{order.Foods}</span>
                         </div>
                      ) : (
                         <div className="text-[11px] text-slate-400 italic font-medium">Không mua kèm bắp nước</div>
                      )}
                    </td>
                    <td className="p-4 align-top font-black text-slate-800 text-[15px]">
                      {formatCurrency(order.TotalAmount)}
                    </td>
                    <td className="p-4 align-top text-center">
                      <div className="flex justify-center">{getStatusBadge(order.Status)}</div>
                    </td>
                    <td className="p-4 align-top text-center">
                      {order.Status === 'Refund Pending' ? (
                        <div className="flex flex-col gap-2 w-max mx-auto">
                           <span className="text-[11px] text-red-600 font-medium max-w-[150px] line-clamp-2" title={order.RefundReason}>
                             {order.RefundReason}
                           </span>
                           <button 
                             onClick={() => handleProcessRefund(order)} 
                             className="px-3 py-2 bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold rounded-lg shadow-sm transition-transform hover:scale-105 flex items-center gap-1.5"
                           >
                             💳 Xử lý hoàn tiền
                           </button>
                        </div>
                      ) : (
                        <span className="text-xs text-slate-400 font-medium bg-slate-50 border border-slate-100 px-3 py-1.5 rounded-full inline-block mt-2">Không yêu cầu</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
      
      {/* 🚀 CSS ANIMATIONS */}
      <style>{`
        @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
        @keyframes slide-in-top { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
      `}</style>
    </div>
  );
};

export default Orders;