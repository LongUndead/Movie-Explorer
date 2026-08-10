import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2';
import { Search, Plus, Edit, Trash2, Ticket, Percent, CalendarClock, PackageOpen, X, Clock, ChevronLeft, ChevronRight, AlertCircle } from 'lucide-react';

const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
});

interface Voucher {
  VoucherID: number;
  Code: string;
  DiscountPercent: number;
  MinOrderValue: number;
  MaxDiscountAmount: number;
  ExpiredAt: string;
  Quantity: number;
}

const Vouchers = () => {
  const [vouchers, setVouchers] = useState<Voucher[]>([]);
  const [loading, setLoading] = useState(true);

  // States bộ lọc & Phân trang
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'ACTIVE' | 'EXPIRED' | 'EMPTY'>('ALL');
  const [currentPage, setCurrentPage] = useState(1);
  const ITEMS_PER_PAGE = 9;

  // States Modal Form
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);
  
  // 🚀 STATE ẢO: Thay đổi UI Form
  const [discountMode, setDiscountMode] = useState<'PERCENT' | 'FIXED'>('PERCENT');
  const [isVipMode, setIsVipMode] = useState(false); // Cờ nhận diện chế độ VIP

  const [formData, setFormData] = useState({
    Code: '',
    DiscountPercent: 10,
    MinOrderValue: 0,
    MaxDiscountAmount: 50000,
    ExpiredAt: '',
    Quantity: 100,
    PointsRequired: 0 // Dành riêng cho VIP
  });

  const API_URL = 'http://192.168.1.7:3000/api/admin/vouchers';

  useEffect(() => {
    fetchVouchers();
  }, []);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, filterStatus]);

  const fetchVouchers = async () => {
    setLoading(true);
    try {
      const res = await axios.get(API_URL);
      setVouchers(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Không thể tải danh sách khuyến mãi!' });
    } finally {
      setLoading(false);
    }
  };

  const getVoucherStatus = (item: Voucher) => {
    const isExpired = new Date(item.ExpiredAt) < new Date();
    if (isExpired) return 'EXPIRED';
    if (item.Quantity <= 0) return 'EMPTY';
    return 'ACTIVE';
  };

  const openAddModal = () => {
    setEditingId(null);
    setDiscountMode('PERCENT'); 
    setIsVipMode(false); // Mặc định mở lên là mã thường
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 7);
    const formattedDate = tomorrow.toISOString().slice(0, 16); 
    setFormData({ Code: '', DiscountPercent: 10, MinOrderValue: 0, MaxDiscountAmount: 50000, ExpiredAt: formattedDate, Quantity: 100, PointsRequired: 0 });
    setIsModalOpen(true);
  };

  const openEditModal = (item: Voucher) => {
    setEditingId(item.VoucherID);
    setDiscountMode(item.DiscountPercent === 100 ? 'FIXED' : 'PERCENT');
    
    // Kiểm tra xem mã này có phải mã VIP không (Chứa ký tự P_ ở đầu)
    const isVip = item.Code.startsWith('P') && item.Code.includes('_');
    setIsVipMode(isVip);

    let displayCode = item.Code;
    let points = 0;
    
    // Nếu là mã VIP, bóc tách lấy điểm và phần chữ đằng sau để hiện lên Form cho đẹp
    if (isVip) {
      const parts = item.Code.split('_');
      if (parts.length > 1) {
        points = parseInt(parts[0].replace('P', '')) || 0;
        displayCode = parts.slice(1).join('_'); // Lấy phần chữ phía sau dấu gạch dưới
      }
    }
    
    const dateObj = new Date(item.ExpiredAt);
    const localDate = new Date(dateObj.getTime() - dateObj.getTimezoneOffset() * 60000);
    
    setFormData({
      Code: displayCode, // Chỉ hiện tên mã, ẩn chữ P_ đi
      DiscountPercent: item.DiscountPercent,
      MinOrderValue: item.MinOrderValue,
      MaxDiscountAmount: item.MaxDiscountAmount,
      ExpiredAt: localDate.toISOString().slice(0, 16),
      Quantity: item.Quantity,
      PointsRequired: points
    });
    setIsModalOpen(true);
  };

  // ==========================================
  // 🚀 HÀM LƯU VOUCHER (ĐÃ BỌC THÉP RÀNG BUỘC)
  // ==========================================
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // 1. Dọn dẹp dữ liệu đầu vào
    let finalCode = formData.Code.trim().toUpperCase().replace(/\s/g, ''); 
    const discountPercent = Number(formData.DiscountPercent);
    const minOrderValue = Number(formData.MinOrderValue);
    const maxDiscountAmount = Number(formData.MaxDiscountAmount);
    const quantity = Number(formData.Quantity);
    const expiredAt = new Date(formData.ExpiredAt);
    const now = new Date();

    // Lớp bảo vệ cơ bản
    if (!finalCode || finalCode.length < 4) return Swal.fire('Cảnh báo', 'Mã khuyến mãi phải có ít nhất 4 ký tự!', 'warning');
    if (quantity <= 0 || isNaN(quantity)) return Swal.fire('Cảnh báo', 'Số lượng phát hành phải lớn hơn 0!', 'warning');
    if (minOrderValue < 0 || isNaN(minOrderValue)) return Swal.fire('Cảnh báo', 'Đơn tối thiểu không được là số âm!', 'warning');
    if (expiredAt <= now) return Swal.fire('Cảnh báo', 'Thời hạn sử dụng phải lớn hơn thời gian hiện tại!', 'warning');

    // 🚀 Lớp bảo vệ logic Kinh doanh (Tránh rạp bị lỗ)
    if (discountMode === 'FIXED' || discountPercent === 100) {
      if (maxDiscountAmount <= 0 || isNaN(maxDiscountAmount)) return Swal.fire('Cảnh báo', 'Số tiền giảm phải lớn hơn 0đ!', 'warning');
      if (minOrderValue > 0 && maxDiscountAmount >= minOrderValue) {
        return Swal.fire({ icon: 'warning', title: 'Cấu hình vô lý!', text: `Mã giảm ${maxDiscountAmount.toLocaleString('vi-VN')}đ nhưng đơn tối thiểu chỉ có ${minOrderValue.toLocaleString('vi-VN')}đ. Rạp sẽ bị âm tiền!`, confirmButtonColor: '#4f46e5' });
      }
    } else {
      if (discountPercent <= 0 || discountPercent > 100 || isNaN(discountPercent)) return Swal.fire('Cảnh báo', 'Phần trăm giảm giá phải từ 1% đến 100%!', 'warning');
      if (maxDiscountAmount <= 0 || isNaN(maxDiscountAmount)) return Swal.fire('Cảnh báo', 'Vui lòng nhập Mức Giảm Tối Đa hợp lý (> 0đ)!', 'warning');
    }

    // 🚀 LẬP LOGIC MÃ VIP (Ghép chuỗi tự động P..._Code)
    if (isVipMode) {
      if (formData.PointsRequired <= 0) {
        return Swal.fire('Cảnh báo', 'Vui lòng nhập số điểm hợp lệ (>0) để đổi mã VIP!', 'warning');
      }
      finalCode = `P${formData.PointsRequired}_${finalCode}`;
    } else {
      // Đảm bảo mã thường không được chứa cấu trúc ăn gian P_
      if (finalCode.startsWith('P') && finalCode.includes('_')) {
        return Swal.fire('Cảnh báo', 'Mã thường không được chứa cấu trúc P_ (Dành riêng cho vé VIP). Vui lòng đặt mã khác!', 'warning');
      }
    }

    // Lớp bảo vệ: Chống trùng mã Code (Tính luôn cả phần P_ nếu là VIP)
    const isDuplicate = vouchers.some(v => v.Code.toUpperCase() === finalCode && v.VoucherID !== editingId);
    if (isDuplicate) {
      return Swal.fire({ title: 'Trùng lặp Mã Code!', text: `Mã khuyến mãi "${finalCode}" đã tồn tại. Vui lòng chọn một mã khác!`, icon: 'error', confirmButtonColor: '#ef4444' });
    }

    // Gửi API
    setLoading(true);
    const payload = {
      ...formData,
      Code: finalCode,
      DiscountPercent: discountMode === 'FIXED' ? 100 : discountPercent,
      MinOrderValue: minOrderValue,
      MaxDiscountAmount: maxDiscountAmount,
      Quantity: quantity
    };

    try {
      if (editingId) {
        await axios.put(`${API_URL}/${editingId}`, payload);
        Toast.fire({ icon: 'success', title: 'Cập nhật Voucher thành công!' });
      } else {
        await axios.post(API_URL, payload);
        Toast.fire({ icon: 'success', title: 'Phát hành Voucher mới thành công!' });
      }
      setIsModalOpen(false);
      fetchVouchers();
    } catch (error: any) {
      Swal.fire('Lỗi máy chủ', error.response?.data?.error || 'Có lỗi xảy ra trong quá trình lưu dữ liệu!', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: number, code: string) => {
    Swal.fire({
      title: 'Hủy mã khuyến mãi?',
      html: `Bạn sắp gỡ bỏ mã <b>${code}</b>. Không thể hoàn tác.`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#ef4444',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Xác nhận xóa',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          await axios.delete(`${API_URL}/${id}`);
          Toast.fire({ icon: 'success', title: 'Đã xóa mã!' });
          fetchVouchers();
        } catch (error: any) {
          Swal.fire('Không thể xóa', error.response?.data?.error || 'Mã này đang nằm trong ví khách hàng!', 'error');
        }
      }
    });
  };

  const filteredVouchers = useMemo(() => {
    return vouchers.filter(item => {
      const matchesSearch = item.Code.toLowerCase().includes(searchTerm.toLowerCase());
      const status = getVoucherStatus(item);
      const matchesStatus = filterStatus === 'ALL' ? true : status === filterStatus;
      return matchesSearch && matchesStatus;
    });
  }, [vouchers, searchTerm, filterStatus]);

  // LOGIC PHÂN TRANG
  const totalPages = Math.ceil(filteredVouchers.length / ITEMS_PER_PAGE);
  const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
  const currentItems = filteredVouchers.slice(startIndex, startIndex + ITEMS_PER_PAGE);

  useEffect(() => {
    if (currentPage > totalPages && totalPages > 0) setCurrentPage(totalPages);
  }, [filteredVouchers.length, currentPage, totalPages]);

  const renderPageNumbers = useMemo(() => {
    const pages = [];
    if (totalPages <= 7) {
      for (let i = 1; i <= totalPages; i++) pages.push(i);
      return pages;
    }
    pages.push(1);
    let startPage = Math.max(2, currentPage - 1);
    let endPage = Math.min(totalPages - 1, currentPage + 1);
    if (currentPage <= 3) endPage = 4;
    else if (currentPage >= totalPages - 2) startPage = totalPages - 3;
    if (startPage > 2) pages.push('...left');
    for (let i = startPage; i <= endPage; i++) pages.push(i);
    if (endPage < totalPages - 1) pages.push('...right');
    pages.push(totalPages);
    return pages;
  }, [currentPage, totalPages]);

  const stats = {
    total: vouchers.length,
    active: vouchers.filter(v => getVoucherStatus(v) === 'ACTIVE').length,
    empty: vouchers.filter(v => getVoucherStatus(v) === 'EMPTY').length,
    expired: vouchers.filter(v => getVoucherStatus(v) === 'EXPIRED').length,
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] flex flex-col gap-6 animate-[fade-in_0.3s_ease-out]">

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div><p className="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-1">TỔNG MÃ</p><h3 className="text-3xl font-black text-slate-800">{stats.total}</h3></div>
          <div className="w-12 h-12 rounded-full bg-blue-50 flex items-center justify-center text-blue-600"><Ticket size={24}/></div>
        </div>
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div><p className="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-1">CÒN KHẢ DỤNG</p><h3 className="text-3xl font-black text-slate-800">{stats.active}</h3></div>
          <div className="w-12 h-12 rounded-full bg-emerald-50 flex items-center justify-center text-emerald-600"><Percent size={24}/></div>
        </div>
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div><p className="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-1">HẾT LƯỢT</p><h3 className="text-3xl font-black text-slate-800">{stats.empty}</h3></div>
          <div className="w-12 h-12 rounded-full bg-orange-50 flex items-center justify-center text-orange-600"><PackageOpen size={24}/></div>
        </div>
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm flex justify-between items-center">
          <div><p className="text-[11px] font-black text-slate-400 uppercase tracking-widest mb-1">QUÁ HẠN</p><h3 className="text-3xl font-black text-slate-800">{stats.expired}</h3></div>
          <div className="w-12 h-12 rounded-full bg-red-50 flex items-center justify-center text-red-600"><CalendarClock size={24}/></div>
        </div>
      </div>

      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col xl:flex-row justify-between items-center gap-4 z-20">
        <div className="flex bg-slate-100 p-1.5 rounded-xl w-full xl:w-auto overflow-x-auto no-scrollbar">
          {[
            { id: 'ALL', label: 'Tất cả mã' },
            { id: 'ACTIVE', label: 'Khả dụng' },
            { id: 'EMPTY', label: 'Hết lượt' },
            { id: 'EXPIRED', label: 'Đã hết hạn' }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setFilterStatus(tab.id as any)}
              className={`px-5 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all ${
                filterStatus === tab.id ? 'bg-white text-indigo-700 shadow-sm scale-105' : 'text-slate-500 hover:text-slate-800 hover:bg-slate-200'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap sm:flex-nowrap items-center gap-3 w-full xl:w-auto">
          <div className="relative flex-1 sm:w-64 group">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={16} />
            <input 
              type="text" placeholder="Tìm theo mã Code..." value={searchTerm} onChange={(e) => setSearchTerm(e.target.value.toUpperCase())}
              className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 text-sm font-bold uppercase transition-all placeholder:normal-case"
            />
          </div>
          <button onClick={openAddModal} className="w-full sm:w-auto flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2.5 rounded-xl font-bold text-sm shadow-md shadow-indigo-500/30 hover:-translate-y-0.5 transition-all">
            <Plus size={18} /> Phát Hành Mã
          </button>
        </div>
      </div>

      {loading ? (
        <div className="py-20 text-center text-slate-400 font-medium">Đang tải dữ liệu Vouchers...</div>
      ) : currentItems.length === 0 ? (
        <div className="py-20 text-center text-slate-400 font-medium flex flex-col items-center">
          <Ticket size={48} className="mb-4 opacity-20" /> Không tìm thấy mã khuyến mãi nào.
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {currentItems.map((item, index) => {
            const status = getVoucherStatus(item);
            let statusColor = "bg-emerald-500";
            let statusBadge = "CÒN HẠN";
            if (status === 'EMPTY') { statusColor = "bg-orange-500"; statusBadge = "HẾT LƯỢT"; }
            if (status === 'EXPIRED') { statusColor = "bg-red-500"; statusBadge = "QUÁ HẠN"; }
            
            const isFixed = item.DiscountPercent === 100;
            const isVip = item.Code.startsWith('P') && item.Code.includes('_');

            return (
              <div 
                key={item.VoucherID} style={{ animationDelay: `${index * 30}ms` }}
                className={`relative flex bg-white rounded-2xl shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all duration-300 border border-slate-200 overflow-hidden animate-[slide-in-bottom_0.4s_ease-out_backwards] ${status !== 'ACTIVE' ? 'opacity-80 grayscale-[20%]' : ''}`}
              >
                {/* Dải bên trái hiển thị % hoặc chữ */}
                <div className={`${isVip ? 'bg-amber-500' : statusColor} w-28 shrink-0 flex flex-col items-center justify-center text-white relative overflow-hidden`}>
                  <div className="absolute top-[-20px] left-[-20px] w-16 h-16 bg-white/20 rounded-full blur-xl"></div>
                  
                  {isFixed ? (
                    <>
                      <span className="text-3xl font-black">{item.MaxDiscountAmount / 1000}K</span>
                      <span className="text-[9px] font-bold tracking-widest mt-1 opacity-90 text-center px-1">GIẢM<br/>TRỰC TIẾP</span>
                    </>
                  ) : (
                    <>
                      <Percent size={28} className="mb-1 opacity-80" />
                      <span className="text-3xl font-black">{item.DiscountPercent}%</span>
                      <span className="text-[10px] font-bold tracking-widest mt-1 opacity-90">GIẢM GIÁ</span>
                    </>
                  )}

                  {isVip && (
                     <div className="absolute bottom-1 bg-white text-amber-600 px-2 py-0.5 rounded text-[8px] font-black uppercase shadow-sm">Thẻ VIP</div>
                  )}
                  
                  <div className="absolute top-0 right-[-6px] bottom-0 w-3 flex flex-col justify-between py-2">
                    {[...Array(8)].map((_, i) => <div key={i} className="w-3 h-3 bg-white rounded-full"></div>)}
                  </div>
                </div>

                <div className="flex-1 p-5 pl-7 flex flex-col justify-between">
                  <div>
                    <div className="flex justify-between items-start mb-1">
                      <h3 className={`font-black text-xl tracking-wider border-b-2 inline-block border-dashed ${isVip ? 'text-amber-600 border-amber-600' : 'text-slate-800 border-slate-800'}`}>
                        {item.Code}
                      </h3>
                      <span className={`text-[10px] font-black px-2 py-1 rounded-md text-white ${statusColor}`}>{statusBadge}</span>
                    </div>
                    
                    <ul className="mt-3 space-y-1.5">
                      <li className="flex justify-between text-xs font-medium text-slate-600">
                        <span className="text-slate-400">Đơn tối thiểu:</span> 
                        <b className="text-slate-800">{Number(item.MinOrderValue).toLocaleString('vi-VN')} đ</b>
                      </li>
                      <li className="flex justify-between text-xs font-medium text-slate-600">
                        <span className="text-slate-400">Giảm tối đa:</span> 
                        <b className="text-slate-800">{Number(item.MaxDiscountAmount).toLocaleString('vi-VN')} đ</b>
                      </li>
                      <li className="flex justify-between text-xs font-medium text-slate-600">
                        <span className="text-slate-400 flex items-center gap-1"><PackageOpen size={12}/> Còn lại:</span> 
                        <b className={item.Quantity <= 10 ? 'text-red-500' : 'text-slate-800'}>{item.Quantity} lượt</b>
                      </li>
                      <li className="flex justify-between text-xs font-medium text-slate-600">
                        <span className="text-slate-400 flex items-center gap-1"><Clock size={12}/> HSD:</span> 
                        <b className="text-slate-800">{new Date(item.ExpiredAt).toLocaleString('vi-VN', {hour: '2-digit', minute:'2-digit', day: '2-digit', month: '2-digit', year: 'numeric'})}</b>
                      </li>
                    </ul>
                  </div>

                  <div className="flex justify-end gap-2 mt-4 pt-3 border-t border-slate-100">
                    <button onClick={() => openEditModal(item)} className="p-2 text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"><Edit size={16}/></button>
                    <button onClick={() => handleDelete(item.VoucherID, item.Code)} className="p-2 text-red-500 hover:bg-red-50 rounded-lg transition-colors"><Trash2 size={16}/></button>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {totalPages > 1 && (
        <div className="relative flex flex-col sm:flex-row justify-center items-center mt-4 p-4 bg-white rounded-2xl border border-slate-200 shadow-sm min-h-[70px] gap-4 z-10">
          <div className="sm:absolute sm:left-5 text-sm text-slate-500">
            Hiển thị <span className="font-bold text-indigo-600">{startIndex + 1}</span> đến <span className="font-bold text-indigo-600">{Math.min(startIndex + ITEMS_PER_PAGE, filteredVouchers.length)}</span> trong tổng số <span className="font-bold text-slate-800">{filteredVouchers.length}</span> mã
          </div>
          
          <div className="flex items-center gap-1.5">
            <button onClick={() => setCurrentPage(p => Math.max(1, p - 1))} disabled={currentPage === 1} className="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 text-slate-400 hover:bg-slate-50 hover:text-indigo-600 disabled:opacity-40 transition-all"><ChevronLeft size={18} strokeWidth={3}/></button>
            <div className="flex items-center gap-1 px-2">
              {renderPageNumbers.map((page, index) => {
                if (typeof page === 'string') return <span key={`ell-${index}`} className="w-9 h-9 flex items-center justify-center text-slate-400 font-bold select-none">...</span>;
                const isActive = currentPage === page;
                return (
                  <button key={`pg-${page}`} onClick={() => setCurrentPage(page)} className={`w-9 h-9 flex items-center justify-center text-center leading-none rounded-xl text-sm font-bold transition-all ${isActive ? 'bg-indigo-600 text-white shadow-md shadow-indigo-500/30' : 'text-slate-600 hover:bg-slate-100 hover:text-indigo-600'}`}>{page}</button>
                )
              })}
            </div>
            <button onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))} disabled={currentPage === totalPages} className="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 text-slate-400 hover:bg-slate-50 hover:text-indigo-600 disabled:opacity-40 transition-all"><ChevronRight size={18} strokeWidth={3}/></button>
          </div>
        </div>
      )}

      {/* ========================================================= */}
      {/* 🚀 MODAL NHẬP LIỆU THÔNG MINH CHO ADMIN */}
      {/* ========================================================= */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4">
          <div className="bg-white rounded-2xl w-full max-w-lg overflow-hidden animate-[slide-in-bottom_0.3s_ease-out] shadow-2xl">
            <div className="flex justify-between items-center p-5 border-b bg-slate-50">
              <h3 className="m-0 text-lg font-black text-slate-800 flex items-center gap-2">
                <Ticket className="text-indigo-600" /> {editingId ? 'Cập Nhật Ưu Đãi' : 'Phát Hành Ưu Đãi'}
              </h3>
              <button onClick={() => setIsModalOpen(false)} className="bg-slate-100 hover:bg-red-100 hover:text-red-500 text-slate-500 rounded-full w-8 h-8 flex items-center justify-center transition-colors"><X size={18} /></button>
            </div>

            <form onSubmit={handleSubmit} className="p-6 flex flex-col gap-4 max-h-[75vh] overflow-y-auto custom-scrollbar">
              
              {/* CÔNG TẮC CHUYỂN CHẾ ĐỘ (MÃ THƯỜNG / VÉ VIP) */}
              {!editingId && (
                <div className="flex bg-slate-100 p-1.5 rounded-xl mb-2">
                  <button type="button" onClick={() => setIsVipMode(false)} className={`flex-1 py-2.5 rounded-lg text-sm font-bold transition-all ${!isVipMode ? 'bg-white text-indigo-600 shadow-sm' : 'text-slate-500 hover:bg-slate-200'}`}>Giảm Giá Thường</button>
                  <button type="button" onClick={() => setIsVipMode(true)} className={`flex-1 py-2.5 rounded-lg text-sm font-bold transition-all ${isVipMode ? 'bg-amber-400 text-white shadow-sm' : 'text-slate-500 hover:bg-slate-200'}`}>Vé VIP (Đổi điểm)</button>
                </div>
              )}

              {/* INPUT ĐIỂM VIP (Nếu ở chế độ VIP) */}
              {isVipMode && (
                <div className="bg-amber-50 p-4 rounded-xl border border-amber-200">
                  <label className="block text-xs font-black text-amber-900 mb-1.5 uppercase tracking-wide">Số Điểm Cần Đổi</label>
                  <input type="number" min="1" value={formData.PointsRequired} onChange={e => setFormData({...formData, PointsRequired: Number(e.target.value)})} className="w-full bg-white border-none rounded-lg p-2.5 outline-none ring-1 ring-amber-300 focus:ring-2 focus:ring-amber-500 font-black text-amber-700 text-lg" placeholder="VD: 150" required={isVipMode}/>
                  <p className="text-xs text-amber-700 mt-2 font-medium">Hệ thống sẽ tự động chèn <b>P{formData.PointsRequired || 'X'}_</b> vào trước mã Code.</p>
                </div>
              )}

              {/* Mã CODE */}
              <div className="group">
                <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide">Mã Code (Chữ in hoa) *</label>
                <input type="text" required value={formData.Code} onChange={e => setFormData({ ...formData, Code: e.target.value.toUpperCase().replace(/\s/g, '') })} placeholder="VD: SIEUSALE2025" className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 py-2.5 px-4 rounded-xl text-sm font-black uppercase tracking-wider transition-all" />
              </div>

              {/* LOẠI KHUYẾN MÃI */}
              <div className="group">
                <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide">Hình Thức Khuyến Mãi *</label>
                <select value={discountMode} onChange={e => { const mode = e.target.value as 'PERCENT' | 'FIXED'; setDiscountMode(mode); if (mode === 'FIXED') setFormData({...formData, DiscountPercent: 100}); else setFormData({...formData, DiscountPercent: 10}); }} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 py-2.5 px-4 rounded-xl text-sm font-bold text-slate-700 cursor-pointer">
                  <option value="PERCENT">Giảm theo Phần Trăm (%)</option>
                  <option value="FIXED">Giảm thẳng Tiền Mặt (VNĐ)</option>
                </select>
              </div>

              <div className="grid grid-cols-2 gap-4">
                {/* ẨN % NẾU LÀ TIỀN MẶT */}
                {discountMode === 'PERCENT' ? (
                  <div className="group animate-[fade-in_0.2s_ease-out]">
                    <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide">% Giảm giá *</label>
                    <div className="flex items-center border border-slate-200 bg-slate-50 focus-within:bg-white focus-within:border-indigo-500 focus-within:ring-4 focus-within:ring-indigo-50 rounded-xl px-3 transition-all">
                      <input type="number" required min="1" max="100" value={formData.DiscountPercent} onChange={e => setFormData({ ...formData, DiscountPercent: Number(e.target.value) })} className="w-full bg-transparent border-none outline-none py-2.5 px-2 text-sm font-bold text-slate-800" />
                      <Percent size={16} className="text-slate-400 shrink-0" />
                    </div>
                  </div>
                ) : (
                  <div className="group animate-[fade-in_0.2s_ease-out]">
                    <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide flex items-center gap-1"><AlertCircle size={12}/> Số Tiền Giảm (đ) *</label>
                    <input type="number" required min="1000" step="1000" value={formData.MaxDiscountAmount} onChange={e => setFormData({ ...formData, MaxDiscountAmount: Number(e.target.value) })} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 py-2.5 px-4 rounded-xl text-sm font-bold text-slate-800 transition-all" />
                  </div>
                )}
                
                <div className="group">
                  <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide">Số lượng phát hành *</label>
                  <div className="flex items-center border border-slate-200 bg-slate-50 focus-within:bg-white focus-within:border-indigo-500 focus-within:ring-4 focus-within:ring-indigo-50 rounded-xl px-3 transition-all">
                    <input type="number" required min="1" value={formData.Quantity} onChange={e => setFormData({ ...formData, Quantity: Number(e.target.value) })} className="w-full bg-transparent border-none outline-none py-2.5 px-2 text-sm font-bold text-slate-800" />
                    <span className="text-xs font-bold text-slate-400 shrink-0">Lượt</span>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="group">
                  <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide flex items-center gap-1"><AlertCircle size={12}/> Đơn Tối Thiểu (đ)</label>
                  <input type="number" required min="0" step="1000" value={formData.MinOrderValue} onChange={e => setFormData({ ...formData, MinOrderValue: Number(e.target.value) })} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 py-2.5 px-4 rounded-xl text-sm font-bold text-slate-800 transition-all" />
                </div>
                
                {/* ẨN MAX DISCOUNT NẾU ĐÃ CHỌN GIẢM TIỀN MẶT */}
                {discountMode === 'PERCENT' && (
                  <div className="group animate-[fade-in_0.2s_ease-out]">
                    <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide flex items-center gap-1"><AlertCircle size={12}/> Mức Giảm Tối Đa (đ)</label>
                    <input type="number" required min="0" step="1000" value={formData.MaxDiscountAmount} onChange={e => setFormData({ ...formData, MaxDiscountAmount: Number(e.target.value) })} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 py-2.5 px-4 rounded-xl text-sm font-bold text-slate-800 transition-all" />
                  </div>
                )}
              </div>

              <div className="group">
                <label className="block text-xs font-bold text-slate-700 mb-1.5 uppercase tracking-wide">Thời hạn sử dụng *</label>
                <input type="datetime-local" required value={formData.ExpiredAt} onChange={e => setFormData({ ...formData, ExpiredAt: e.target.value })} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 py-2.5 px-4 rounded-xl text-sm font-bold text-slate-800 transition-all cursor-pointer" />
              </div>

              <div className="flex justify-end gap-3 mt-4 pt-4 border-t border-slate-100">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 font-bold text-slate-600 text-sm transition-colors">Hủy</button>
                <button type="submit" disabled={loading} className={`px-6 py-2.5 rounded-xl text-white font-bold text-sm shadow-md transition-all hover:-translate-y-0.5 ${isVipMode ? 'bg-amber-500 hover:bg-amber-600 shadow-amber-500/30' : 'bg-indigo-600 hover:bg-indigo-700 shadow-indigo-500/30'}`}>
                  {loading ? 'Đang xử lý...' : (editingId ? 'Cập Nhật' : (isVipMode ? 'Phát Hành VIP' : 'Phát Hành Mã'))}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default Vouchers;