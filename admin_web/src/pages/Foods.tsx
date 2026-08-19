import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2';
import { Search, Plus, Edit, Trash2, Popcorn, CupSoda, Layers, DollarSign, UploadCloud, X, Filter, Tag, Store, Pizza, ChevronLeft, ChevronRight, } from 'lucide-react';

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

interface FoodItem {
  FoodID: number;
  Name: string;
  Price: number;
  description: string;
  ImageURL: string;
  Type: string; 
  brand_id: number; 
}

const Foods = () => {
  const [foods, setFoods] = useState<FoodItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [brandsList, setBrandsList] = useState<any[]>([]);

  // Bộ lọc
  const [searchTerm, setSearchTerm] = useState('');
  const [filterBrand, setFilterBrand] = useState<string>('ALL');
  const [activeTab, setActiveTab] = useState<'ALL' | 'COMBO' | 'SNACK' | 'DRINK'>('ALL'); 

  // PHÂN TRANG
  const [currentPage, setCurrentPage] = useState(1);
  const ITEMS_PER_PAGE = 12;

  // Modal States
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingFoodId, setEditingFoodId] = useState<number | null>(null);
  const [foodFile, setFoodFile] = useState<File | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    price: 60000,
    description: '',
    ImageURL: '',
    type: 'Combo', 
    brand_id: '1'
  });

  const API_URL = 'http://10.173.120.41:3000/api/admin/foods';

  useEffect(() => {
    fetchFoods();
    fetchBrands();
  }, []);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, filterBrand, activeTab]);

  const fetchBrands = async () => {
    try {
      const res = await axios.get('http://10.173.120.41:3000/api/admin/brands');
      setBrandsList(res.data);
    } catch (error) {
      console.error('Lỗi tải danh sách thương hiệu!');
    }
  };

  const fetchFoods = async () => {
    setLoading(true);
    try {
      const res = await axios.get(API_URL);
      setFoods(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Lỗi kết nối kho bắp nước!' });
    } finally {
      setLoading(false);
    }
  };

  const formatFoodType = (type: string) => {
    if (!type) return 'Khác';
    const cleanType = type.trim();
    if (cleanType.toLowerCase() === 'nước' || cleanType.toLowerCase() === 'nuoc') {
      return 'Drink';
    }
    return cleanType.charAt(0).toUpperCase() + cleanType.slice(1).toLowerCase();
  };

  const getFoodImagePath = (dbImage: string, brandId: number) => {
    let img = (dbImage || '').trim();
    if (!img) return 'https://placehold.co/400x400/e2e8f0/475569?text=No+Image';
    if (img.startsWith('http')) return img;
    
    if (img.includes('food-')) {
      const filename = img.split('/').pop(); 
      return `http://10.173.120.41:3000/public/foods/${filename}`;
    }

    if (img.startsWith('/public/foods/')) return `http://10.173.120.41:3000${img}`;
    const folders: Record<number, string> = { 1: 'cgv', 2: 'galaxy', 3: 'lotte', 4: 'bhd', 5: 'cinestar', 6: 'megags' };
    const folder = folders[brandId] || 'cgv';
    if (img.startsWith('/')) img = img.substring(1);
    if (img.startsWith('assets/')) return `http://10.173.120.41:3000/${img}`; 
    if (img.startsWith(`${folder}/`)) return `http://10.173.120.41:3000/assets/${img}`;
    return `http://10.173.120.41:3000/assets/${folder}/${img}`;
  };

  const openAddModal = () => {
    setEditingFoodId(null);
    setFoodFile(null);
    setFormData({ name: '', price: 60000, description: '', ImageURL: '', type: 'Combo', brand_id: '1' });
    setIsModalOpen(true);
  };

  const openEditModal = (item: FoodItem) => {
    setEditingFoodId(item.FoodID);
    setFoodFile(null);
    setFormData({
      name: item.Name,
      price: item.Price,
      description: item.description || '',
      ImageURL: item.ImageURL || '',
      type: formatFoodType(item.Type), 
      brand_id: item.brand_id?.toString() || '1'
    });
    setIsModalOpen(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    const trimmedName = formData.name.trim();
    const trimmedDesc = formData.description.trim();
    const priceValue = Number(formData.price);

    if (!trimmedName) return Swal.fire('Cảnh báo', 'Tên sản phẩm/combo không được để trống!', 'warning');
    if (isNaN(priceValue) || priceValue < 1000) return Swal.fire('Cảnh báo', 'Giá bán quá thấp hoặc không hợp lệ (Phải từ 1,000 VNĐ trở lên)!', 'warning');

    const isDuplicate = foods.some(
      (f) => 
        f.Name.toLowerCase() === trimmedName.toLowerCase() && 
        f.brand_id?.toString() === formData.brand_id && 
        f.FoodID !== editingFoodId
    );

    if (isDuplicate) {
      const brandName = brandsList.find(b => b.brand_id.toString() === formData.brand_id)?.brand_name || 'hệ thống';
      return Swal.fire({
        title: 'Trùng lặp dữ liệu!',
        text: `Món "${trimmedName}" đã tồn tại trong thực đơn của ${brandName}. Vui lòng kiểm tra lại!`,
        icon: 'warning',
        confirmButtonColor: '#3b82f6'
      });
    }

    setLoading(true);

    const data = new FormData();
    data.append('Name', trimmedName);
    data.append('Price', priceValue.toString());
    data.append('description', trimmedDesc);
    data.append('ImageURL', formData.ImageURL.trim());
    data.append('Type', formData.type); 
    data.append('brand_id', formData.brand_id);
    
    if (foodFile) data.append('food_file', foodFile);

    try {
      if (editingFoodId) {
        await axios.put(`${API_URL}/${editingFoodId}`, data, { headers: { 'Content-Type': 'multipart/form-data' } });
        Toast.fire({ icon: 'success', title: 'Cập nhật sản phẩm thành công!' });
      } else {
        await axios.post(API_URL, data, { headers: { 'Content-Type': 'multipart/form-data' } });
        Toast.fire({ icon: 'success', title: 'Thêm món mới vào kho thành công!' });
      }
      setIsModalOpen(false);
      fetchFoods();
    } catch (error: any) {
      Swal.fire('Lỗi xử lý', error.response?.data?.error || 'Không thể lưu sản phẩm lúc này!', 'error');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: number, name: string) => {
    Swal.fire({
      title: 'Xóa sản phẩm này?',
      html: `Bạn đang chuẩn bị gỡ bỏ <b>${name}</b> ra khỏi thực đơn.`,
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
          Swal.fire('Đã gỡ!', 'Sản phẩm đã biến mất khỏi thực đơn.', 'success');
          fetchFoods();
        } catch (error: any) {
          Swal.fire('Thất bại', 'Sản phẩm đang nằm trong lịch sử mua của khách, không thể xóa vĩnh viễn!', 'error');
        }
      }
    });
  };

  const filteredFoods = useMemo(() => {
    return foods.filter(item => {
      const matchesSearch = item.Name.toLowerCase().includes(searchTerm.toLowerCase()) || (item.description || '').toLowerCase().includes(searchTerm.toLowerCase());
      const matchesBrand = filterBrand === 'ALL' ? true : item.brand_id?.toString() === filterBrand;
      
      const itemType = formatFoodType(item.Type).toUpperCase();
      const matchesType = activeTab === 'ALL' ? true : itemType === activeTab;
      
      return matchesSearch && matchesBrand && matchesType;
    });
  }, [foods, searchTerm, filterBrand, activeTab]);

  const totalPages = Math.ceil(filteredFoods.length / ITEMS_PER_PAGE);
  const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
  const currentFoods = filteredFoods.slice(startIndex, startIndex + ITEMS_PER_PAGE);

  useEffect(() => {
    if (currentPage > totalPages && totalPages > 0) {
      setCurrentPage(totalPages);
    }
  }, [filteredFoods.length, currentPage, totalPages]);

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

  return (
    <div className="p-4 md:p-6 bg-slate-50 min-h-[calc(100vh-70px)] flex flex-col gap-6 animate-[fade-in_0.3s_ease-out] w-full min-w-0 overflow-x-hidden">
      
      {/* 🚀 ĐÃ SỬA LỖI UI: THANH BỘ LỌC CHÍNH ĐƯỢC RESPONSIVE LẠI ĐỂ KHÔNG BỊ TRỐNG TRÃI */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col xl:flex-row justify-between items-start xl:items-center gap-4 z-20 w-full">
        
        {/* Nhóm Tabs Pill Buttons */}
        <div className="flex bg-slate-100 p-1.5 rounded-xl w-full xl:w-auto overflow-x-auto no-scrollbar shrink-0">
          {[
            { id: 'ALL', label: 'Tất cả', icon: null },
            { id: 'COMBO', label: 'Gói Combos', icon: <Layers size={14}/> },
            { id: 'SNACK', label: 'Snacks & Bắp', icon: <Popcorn size={14}/> },
            { id: 'DRINK', label: 'Nước uống', icon: <CupSoda size={14}/> }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`flex items-center gap-1.5 px-5 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all ${
                activeTab === tab.id 
                  ? 'bg-white text-indigo-700 shadow-sm scale-105' 
                  : 'text-slate-500 hover:text-slate-800 hover:bg-slate-200'
              }`}
            >
              {tab.icon} {tab.label}
            </button>
          ))}
        </div>

        {/* 🚀 ĐÃ FIX: Nhóm Actions & Search (Chiếm full màn hình khi rớt dòng) */}
        <div className="flex flex-col sm:flex-row items-center gap-3 w-full xl:w-auto xl:flex-1 xl:justify-end">
          
          <div className="relative w-full sm:w-48 group shrink-0">
            <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={16} />
            <select 
              value={filterBrand}
              onChange={(e) => setFilterBrand(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 text-sm font-bold text-slate-700 cursor-pointer appearance-none transition-all"
            >
              <option value="ALL">Tất cả đối tác</option>
              {brandsList.map((brand) => <option key={brand.brand_id} value={brand.brand_id}>{brand.brand_name}</option>)}
            </select>
          </div>

          {/* 🚀 BÍ KÍP Ở ĐÂY: Dùng flex-1 để nó tự động giãn dài ra lấp đầy khoảng trắng */}
          <div className="relative w-full flex-1 xl:max-w-xs group">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={16} />
            <input 
              type="text" 
              placeholder="Tìm kiếm món ăn..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 text-sm font-medium transition-all"
            />
          </div>

          <button 
            onClick={openAddModal} 
            className="w-full sm:w-auto shrink-0 flex items-center justify-center gap-2 bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white px-5 py-2.5 rounded-xl font-bold text-sm shadow-md shadow-blue-500/30 hover:-translate-y-0.5 transition-all"
          >
            <Plus size={18} /> Thêm Mới
          </button>

        </div>
      </div>

      {/* LƯỚI SẢN PHẨM DẠNG CARD */}
      {loading ? (
        <div className="py-20 text-center text-slate-400 font-medium">Đang tải dữ liệu F&B...</div>
      ) : filteredFoods.length === 0 ? (
        <div className="py-20 text-center text-slate-400 font-medium flex flex-col items-center">
          <Pizza size={48} className="mb-4 opacity-20" />
          Không tìm thấy món nào khớp với bộ lọc.
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 2xl:grid-cols-5 gap-6">
            {currentFoods.map((item, index) => {
              const displayType = formatFoodType(item.Type);
              
              let badgeStyle = "bg-slate-100 text-slate-600 border-slate-200";
              if (displayType === 'Combo') badgeStyle = "bg-purple-50 text-purple-700 border-purple-200";
              if (displayType === 'Snack') badgeStyle = "bg-orange-50 text-orange-700 border-orange-200";
              if (displayType === 'Drink') badgeStyle = "bg-blue-50 text-blue-700 border-blue-200";

              return (
                <div 
                  key={item.FoodID} 
                  style={{ animationDelay: `${index * 30}ms` }}
                  className="bg-white rounded-2xl shadow-sm hover:shadow-xl hover:-translate-y-1.5 transition-all duration-300 border border-slate-200 flex flex-col overflow-hidden animate-[slide-in-bottom_0.4s_ease-out_backwards] group"
                >
                  <div className="relative aspect-square bg-slate-100 p-6 flex justify-center items-center overflow-hidden border-b border-slate-100">
                    <img 
                      src={getFoodImagePath(item.ImageURL, item.brand_id)} 
                      alt={item.Name} 
                      className="w-full h-full object-contain drop-shadow-xl group-hover:scale-110 transition-transform duration-500"
                      onError={(e) => { 
                        e.currentTarget.onerror = null; 
                        e.currentTarget.src = 'https://placehold.co/400x400/e2e8f0/475569?text=No+Image'; 
                      }}
                    />
                    <div className="absolute top-3 right-3">
                      <span className={`px-2.5 py-1 rounded-md text-[10px] font-black uppercase tracking-wider shadow-sm border ${badgeStyle}`}>
                        {displayType}
                      </span>
                    </div>
                  </div>

                  <div className="p-5 flex flex-col flex-1">
                    <h3 className="font-bold text-slate-800 text-base leading-tight line-clamp-2 mb-2">{item.Name}</h3>
                    
                    <div className="text-xl font-black text-indigo-600 mb-3">
                      {Number(item.Price).toLocaleString('vi-VN')} <span className="text-sm font-bold text-slate-500">VNĐ</span>
                    </div>

                    <div className="mb-4 mt-auto">
                       <p className="text-[10px] font-bold text-slate-400 uppercase mb-1 flex items-center gap-1"><Tag size={10}/> Thành phần chi tiết</p>
                       <p className="text-xs text-slate-600 font-medium line-clamp-2 leading-relaxed bg-slate-50 p-2 rounded-lg border border-slate-100 h-[48px]">
                         {item.description || 'Chưa có thông tin.'}
                       </p>
                    </div>

                    <div className="flex justify-between items-center pt-4 border-t border-slate-100">
                      <div className="flex gap-2">
                        <button 
                          onClick={() => openEditModal(item)} 
                          className="w-9 h-9 flex items-center justify-center bg-slate-100 text-slate-600 hover:bg-blue-600 hover:text-white rounded-lg transition-colors"
                          title="Chỉnh sửa"
                        ><Edit size={16}/></button>
                        <button 
                          onClick={() => handleDelete(item.FoodID, item.Name)} 
                          className="w-9 h-9 flex items-center justify-center bg-slate-100 text-slate-600 hover:bg-red-500 hover:text-white rounded-lg transition-colors"
                          title="Xóa"
                        ><Trash2 size={16}/></button>
                      </div>
                      
                      <div className="flex items-center gap-1.5 text-xs font-bold text-slate-500">
                         <Store size={14}/> {brandsList.find(b => b.brand_id.toString() === item.brand_id?.toString())?.brand_name || 'Hệ thống chung'}
                      </div>
                    </div>
                  </div>
                </div>
              )
            })}
          </div>

          {totalPages > 1 && (
            <div className="relative flex flex-col sm:flex-row justify-center items-center mt-4 p-4 bg-white rounded-2xl border border-slate-200 shadow-sm min-h-[70px] gap-4">
              
              <div className="sm:absolute sm:left-5 text-sm text-slate-500">
                Hiển thị <span className="font-bold text-indigo-600">{startIndex + 1}</span> đến <span className="font-bold text-indigo-600">{Math.min(startIndex + ITEMS_PER_PAGE, filteredFoods.length)}</span> trong tổng số <span className="font-bold text-slate-800">{filteredFoods.length}</span> món
              </div>
              
              <div className="flex items-center gap-1.5">
                <button 
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 text-slate-400 hover:bg-slate-50 hover:text-indigo-600 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
                >
                  <ChevronLeft size={18} strokeWidth={3}/>
                </button>
                
                <div className="flex items-center gap-1 px-2">
                  {renderPageNumbers.map((page, index) => {
                    if (typeof page === 'string') {
                      return (
                        <span key={`ellipsis-${index}`} className="w-9 h-9 flex items-center justify-center text-slate-400 font-bold select-none">
                          ...
                        </span>
                      );
                    }

                    const isActive = currentPage === page;
                    return (
                      <button
                        key={`page-${page}`}
                        onClick={() => setCurrentPage(page)}
                        className={`w-9 h-9 flex items-center justify-center text-center leading-none rounded-xl text-sm font-bold transition-all ${
                          isActive 
                            ? 'bg-indigo-600 text-white shadow-md shadow-indigo-500/30' 
                            : 'text-slate-600 hover:bg-slate-100 hover:text-indigo-600'
                        }`}
                      >
                        {page}
                      </button>
                    );
                  })}
                </div>

                <button 
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="w-9 h-9 flex items-center justify-center rounded-xl border border-slate-200 text-slate-400 hover:bg-slate-50 hover:text-indigo-600 disabled:opacity-40 disabled:cursor-not-allowed transition-all"
                >
                  <ChevronRight size={18} strokeWidth={3}/>
                </button>
              </div>
            </div>
          )}
        </>
      )}

      {/* MODAL POPUP THÊM / SỬA BẮP NƯỚC */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4 animate-[fade-in_0.2s_ease-out]">
          <div className="bg-white p-6 sm:p-8 rounded-3xl w-[520px] max-w-full shadow-2xl animate-[slide-in-bottom_0.3s_ease-out]">
            
            <div className="flex justify-between items-center mb-6 border-b border-slate-100 pb-4">
              <h2 className="m-0 text-xl font-black text-slate-800 flex items-center gap-2">
                <Popcorn className="text-blue-600" /> {editingFoodId ? 'Cập Nhật Mặt Hàng' : 'Thêm Mặt Hàng F&B Mới'}
              </h2>
              <button onClick={() => setIsModalOpen(false)} className="bg-slate-100 hover:bg-red-100 hover:text-red-500 text-slate-500 rounded-full w-8 h-8 flex items-center justify-center transition-colors"><X size={18} /></button>
            </div>

            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Tên sản phẩm / Tên gói Combo *</label>
                <input type="text" required value={formData.name} onChange={e => setFormData({ ...formData, name: e.target.value })} placeholder="Ví dụ: Combo Solo X - 1 Bắp Lớn + 1 Nước Ngọt" className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 py-2.5 px-4 rounded-xl text-sm font-medium transition-all" />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="group">
                  <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Giá bán niêm yết (đ) *</label>
                  <div className="flex items-center border border-slate-200 bg-slate-50 focus-within:bg-white focus-within:border-blue-500 focus-within:ring-4 focus-within:ring-blue-50 rounded-xl px-3 transition-all">
                    <DollarSign size={16} className="text-slate-400 shrink-0" />
                    <input type="number" required min="0" step="1000" value={formData.price} onChange={e => setFormData({ ...formData, price: Number(e.target.value) })} className="w-full bg-transparent border-none outline-none py-2.5 px-2 text-sm font-bold text-slate-800" />
                  </div>
                </div>

                <div className="group">
                  <label className="block text-[13px] font-bold text-slate-700 mb-1.5 transition-colors">Hệ thống áp dụng *</label>
                  <select value={formData.brand_id} onChange={e => setFormData({ ...formData, brand_id: e.target.value })} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 py-2.5 px-4 rounded-xl text-sm font-bold text-slate-700 cursor-pointer appearance-none transition-all">
                    {brandsList.map((brand) => <option key={brand.brand_id} value={brand.brand_id}>{brand.brand_name}</option>)}
                  </select>
                </div>
              </div>

              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 transition-colors">Phân loại cấu trúc *</label>
                <select value={formData.type} onChange={e => setFormData({ ...formData, type: e.target.value })} className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 py-2.5 px-4 rounded-xl text-sm font-bold text-slate-700 cursor-pointer appearance-none transition-all">
                  <option value="Combo">Gói Combo hỗn hợp</option>
                  <option value="Snack">Thức ăn nhẹ (Snack/Bắp)</option>
                  <option value="Drink">Nước uống (Drink)</option>
                </select>
              </div>

              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-blue-600 transition-colors">Mô tả sản phẩm / Thành phần Combo</label>
                <textarea rows={2} value={formData.description} onChange={e => setFormData({ ...formData, description: e.target.value })} placeholder="Nhập ghi chú chi tiết cho khách tiện theo dõi..." className="w-full bg-slate-50 border border-slate-200 outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 py-2.5 px-4 rounded-xl text-sm font-medium transition-all resize-none" />
              </div>

              <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200">
                <label className="block text-xs font-bold text-slate-500 mb-2 uppercase tracking-wider">Hình ảnh đại diện</label>
                <div className="flex flex-col gap-3">
                  <div className="flex flex-col gap-1">
                    <input type="text" value={formData.ImageURL} onChange={e => setFormData({ ...formData, ImageURL: e.target.value })} placeholder="Đường dẫn URL ảnh có sẵn..." className="w-full border border-slate-200 rounded-xl p-2 text-xs font-medium outline-none bg-white focus:border-blue-500" disabled={foodFile !== null} />
                  </div>
                  <div className="flex items-center gap-2">
                    <label className="flex-1 flex items-center justify-center gap-2 border border-dashed border-blue-300 bg-blue-50/50 text-blue-700 rounded-xl p-2.5 cursor-pointer hover:bg-blue-50 font-bold text-xs transition-all">
                      <UploadCloud size={16} /> {foodFile ? "Đã ghim tập tin ảnh mới" : "Tải ảnh lên từ máy tính..."}
                      <input type="file" accept="image/*" className="hidden" onChange={(e) => setFoodFile(e.target.files?.[0] || null)} />
                    </label>
                    {foodFile && <button type="button" onClick={() => setFoodFile(null)} className="p-2 text-red-500 hover:bg-red-50 rounded-xl border border-slate-200 bg-white"><X size={16}/></button>}
                  </div>
                </div>
              </div>

              <div className="flex justify-end gap-3 mt-2 pt-4 border-t border-slate-100">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 font-bold text-slate-600 text-sm transition-colors">Hủy bỏ</button>
                <button type="submit" className="px-6 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-bold text-sm shadow-md shadow-blue-500/20 transition-all hover:-translate-y-0.5">
                  {editingFoodId ? 'Cập Nhật' : 'Tạo Mặt Hàng'}
                </button>
              </div>

            </form>
          </div>
        </div>
      )}

      <style>{`
        @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
        @keyframes slide-in-top { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes slide-in-bottom { from { opacity: 0; transform: translateY(20px) scale(0.98); } to { opacity: 1; transform: translateY(0) scale(1); } }
      `}</style>
    </div>
  );
};

export default Foods;