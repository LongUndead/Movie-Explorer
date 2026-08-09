import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2';
import { Search, Trash2, MessageCircle, Heart, Eye, X, ChevronLeft, ChevronRight, User, AlertTriangle, ShieldAlert, Flag, Image as ImageIcon } from 'lucide-react';

const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
});

interface Post {
  PostID: number;
  UserID: number;
  UserName: string;
  Avatar: string;  
  Content: string;
  Type: string;
  CreatedAt: string;
  Status: number;
  BgColor: string;
  TaggedMovieID: number;
  Images: any;     
  LikeCount: number;
  CommentCount: number;
  ReportCount: number;
}

interface Comment {
  CommentID: number;
  PostID: number;
  UserID: number;
  UserName?: string; 
  Avatar?: string;   
  Content: string;
  CreatedAt: string;
  Rating: number;
}

const Posts = () => {
  const [posts, setPosts] = useState<Post[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  
  // Tab State: Chuyển đổi giữa Tất cả và Chờ duyệt báo cáo
  const [activeTab, setActiveTab] = useState<'REPORTED' | 'ALL'>('REPORTED'); 
  
  const [currentPage, setCurrentPage] = useState(1);
  const ITEMS_PER_PAGE = 9; 

  // 🚀 STATE MODAL QUẢN LÝ BÌNH LUẬN
  const [selectedPost, setSelectedPost] = useState<Post | null>(null);
  const [postComments, setPostComments] = useState<Comment[]>([]);
  const [loadingComments, setLoadingComments] = useState(false);

  const API_URL = 'http://192.168.1.7:3000/api/admin';

  useEffect(() => { fetchPosts(); }, []);
  useEffect(() => { setCurrentPage(1); }, [searchTerm, activeTab]);

  const getAvatarUrl = (avatarPath: string | undefined | null) => {
    if (!avatarPath || avatarPath === 'null') return '';
    if (avatarPath.startsWith('http')) return avatarPath;
    return `http://192.168.1.7:3000${avatarPath.startsWith('/') ? '' : '/'}${avatarPath}`;
  };

  const fetchPosts = async () => {
    setLoading(true);
    try {
      const res = await axios.get(`${API_URL}/posts`);
      setPosts(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Lỗi lấy dữ liệu cộng đồng!' });
    } finally {
      setLoading(false);
    }
  };

  // 🚀 HÀM MỞ MODAL XEM BÌNH LUẬN
  const openPostDetails = async (post: Post) => {
    setSelectedPost(post);
    setLoadingComments(true);
    try {
      const res = await axios.get(`${API_URL}/posts/${post.PostID}/comments`);
      setPostComments(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Không thể tải bình luận!' });
    } finally {
      setLoadingComments(false);
    }
  };

  // 🚀 HÀM XÓA BÌNH LUẬN VI PHẠM
  const handleDeleteComment = async (commentId: number) => {
    Swal.fire({
      title: 'Xóa bình luận?',
      text: "Bạn xác nhận xóa bình luận này khỏi hệ thống?",
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#ef4444',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Xóa',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          await axios.delete(`${API_URL}/comments/${commentId}`);
          Toast.fire({ icon: 'success', title: 'Đã xóa bình luận!' });
          setPostComments(postComments.filter(c => c.CommentID !== commentId));
          fetchPosts(); // Cập nhật lại số lượng comment ngoài bảng tin
        } catch (error) {
          Swal.fire('Thất bại', 'Không thể xóa bình luận.', 'error');
        }
      }
    });
  };

 // ==========================================
  // 🚀 LOGIC XÉT DUYỆT BÀI VIẾT VÀ XỬ PHẠT (ĐÃ BỌC THÉP RÀNG BUỘC)
  // ==========================================
  const handleModeratePost = async (post: Post) => {
    const { value: formValues } = await Swal.fire({
      title: 'Xét duyệt báo cáo',
      html: `
        <div class="text-left text-sm mt-2">
          <p class="mb-3 text-slate-600">Bài viết của <b>${post.UserName || `User #${post.UserID}`}</b> đang bị báo cáo. Hướng xử lý của bạn:</p>
          <select id="penalty-select" class="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-indigo-500 font-medium text-slate-700 mb-3">
            <option value="IGNORE">Bỏ qua báo cáo (Bài viết hợp lệ)</option>
            <option value="WARN">Chỉ gỡ bài (Nhắc nhở nhẹ)</option>
            <option value="MUTE_7">Cấm đăng bài 7 ngày (Cảnh cáo)</option>
            <option value="BAN">Khóa tài khoản vĩnh viễn (Ban)</option>
          </select>
          
          <label class="block text-xs font-bold text-slate-700 mb-1">Lý do xử lý (Bắt buộc nếu gỡ bài/phạt):</label>
          <textarea id="penalty-reason" rows="3" class="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-red-500 text-sm resize-none transition-all placeholder:text-slate-400" placeholder="VD: Sử dụng ngôn từ kích động, xúc phạm..."></textarea>
        </div>
      `,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#4f46e5', 
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Xác nhận',
      cancelButtonText: 'Hủy',
      preConfirm: () => {
        const penalty = (document.getElementById('penalty-select') as HTMLSelectElement).value;
        const reason = (document.getElementById('penalty-reason') as HTMLTextAreaElement).value.trim();
        
        // 🚀 LỚP KHIÊN 1: Nếu phạt thì BẮT BUỘC phải nhập lý do
        if (penalty !== 'IGNORE' && reason.length < 5) {
          Swal.showValidationMessage('⚠️ Vui lòng nhập lý do xử phạt (ít nhất 5 ký tự) để lưu hồ sơ hệ thống!');
          return false;
        }

        // 🚀 LỚP KHIÊN 2: Loại bỏ mã độc XSS nếu admin lỡ copy paste bậy bạ
        const sanitizedReason = reason.replace(/<[^>]*>?/gm, '');

        return { penalty, reason: sanitizedReason };
      }
    });

    if (formValues) {
      const { penalty, reason } = formValues;
      
      try {
        if (penalty === 'IGNORE') {
          // Bỏ qua báo cáo -> Gọi API xóa danh sách báo cáo của bài này
          await axios.put(`${API_URL}/posts/${post.PostID}/ignore-reports`);
          Toast.fire({ icon: 'success', title: 'Đã bỏ qua báo cáo. Bài viết an toàn!' });
        } else {
          // Xử phạt -> Gửi thêm REASON xuống Backend để lưu Log và thông báo cho User
          await axios.delete(`${API_URL}/posts/${post.PostID}`, { 
            data: { penaltyType: penalty, userId: post.UserID, reason: reason } 
          });
          
          let msg = 'Đã gỡ bài và Nhắc nhở.';
          if (penalty === 'MUTE_7') msg = 'Đã gỡ bài & Cấm đăng 7 ngày.';
          if (penalty === 'BAN') msg = 'Đã gỡ bài & Khóa vĩnh viễn User.';
          
          Toast.fire({ icon: 'success', title: msg });
        }

        fetchPosts(); // Load lại danh sách (Bài viết sẽ biến mất khỏi tab báo cáo)
        if (selectedPost?.PostID === post.PostID) setSelectedPost(null); // Đóng modal luôn nếu admin đang xem bài đó
      } catch (error: any) {
        Swal.fire('Thất bại', error.response?.data?.error || 'Đã xảy ra lỗi khi xử lý hệ thống.', 'error');
      }
    }
  };

  const filteredPosts = useMemo(() => {
    return posts.filter(post => {
      const matchesSearch = (post.Content || '').toLowerCase().includes(searchTerm.toLowerCase());
      const matchesTab = activeTab === 'ALL' ? true : (post.ReportCount > 0);
      return matchesSearch && matchesTab;
    });
  }, [posts, searchTerm, activeTab]);

  const totalPages = Math.ceil(filteredPosts.length / ITEMS_PER_PAGE);
  const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
  const currentItems = filteredPosts.slice(startIndex, startIndex + ITEMS_PER_PAGE);

  const renderPageNumbers = useMemo(() => {
    const pages = [];
    if (totalPages <= 7) { for (let i = 1; i <= totalPages; i++) pages.push(i); return pages; }
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

  const totalReported = posts.filter(p => p.ReportCount > 0).length;

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] flex flex-col gap-6 animate-[fade-in_0.3s_ease-out]">
      
      {/* THANH BỘ LỌC & TABS */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col xl:flex-row justify-between items-center gap-4 z-20">
        
        <div className="flex bg-slate-100 p-1.5 rounded-xl w-full xl:w-auto">
          <button
            onClick={() => setActiveTab('REPORTED')}
            className={`flex-1 xl:flex-none flex items-center justify-center gap-2 px-5 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all ${
              activeTab === 'REPORTED' ? 'bg-white text-red-600 shadow-sm scale-105' : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            <Flag size={16} className={activeTab === 'REPORTED' ? "fill-red-100" : ""} /> 
            Chờ xử lý vi phạm 
            {totalReported > 0 && <span className="bg-red-500 text-white text-[10px] px-2 py-0.5 rounded-full">{totalReported}</span>}
          </button>
          
          <button
            onClick={() => setActiveTab('ALL')}
            className={`flex-1 xl:flex-none flex items-center justify-center gap-2 px-5 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all ${
              activeTab === 'ALL' ? 'bg-white text-indigo-600 shadow-sm scale-105' : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            <MessageCircle size={16} /> Tất cả bài viết
          </button>
        </div>

        <div className="relative flex-1 w-full xl:max-w-md group">
          <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-indigo-500 transition-colors" size={18} />
          <input 
            type="text" placeholder="Tra cứu nội dung bài viết..." 
            value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-11 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 text-sm font-medium transition-all"
          />
        </div>
      </div>

      {loading ? (
        <div className="py-20 text-center text-slate-400 font-medium">Đang tải bảng tin...</div>
      ) : currentItems.length === 0 ? (
        <div className="py-20 text-center text-slate-400 font-medium flex flex-col items-center">
          <ShieldAlert size={48} className="mb-4 opacity-20" /> 
          {activeTab === 'REPORTED' ? 'Tuyệt vời! Cộng đồng đang rất trong sạch.' : 'Chưa có bài viết nào.'}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          {currentItems.map((post, index) => {
            
            let parsedImages: string[] = [];
            try {
               const rawImages = typeof post.Images === 'string' ? JSON.parse(post.Images) : post.Images;
               if (Array.isArray(rawImages)) parsedImages = rawImages.filter(img => img !== null);
            } catch (e) {}

            return (
              <div 
                key={post.PostID} style={{ animationDelay: `${index * 30}ms` }}
                className={`relative bg-white rounded-2xl border shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all duration-300 flex flex-col overflow-hidden animate-[slide-in-bottom_0.4s_ease-out_backwards] ${post.ReportCount > 0 ? 'border-red-200' : 'border-slate-200'}`}
              >
                {post.ReportCount > 0 && (
                  <div className="absolute top-3 right-3 bg-red-500 text-white px-2.5 py-1 rounded-md text-xs font-black flex items-center gap-1 shadow-md animate-pulse z-10">
                    <AlertTriangle size={12} /> BỊ BÁO CÁO ({post.ReportCount})
                  </div>
                )}

                <div className={`p-4 border-b flex justify-between items-start ${post.ReportCount > 0 ? 'bg-red-50/30 border-red-100' : 'bg-slate-50/50 border-slate-100'}`}>
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-full bg-slate-200 overflow-hidden shrink-0 border border-slate-300">
                      {/* 🚀 ĐÃ SỬA: Dùng hàm getAvatarUrl */}
                      {getAvatarUrl(post.Avatar) ? (
                        <img src={getAvatarUrl(post.Avatar)} alt="ava" className="w-full h-full object-cover" />
                      ) : (
                        <User size={20} className="m-auto mt-2 text-slate-400" />
                      )}
                    </div>
                    <div>
                      <h4 className="text-sm font-bold text-slate-800 leading-tight line-clamp-1">{post.UserName || `User #${post.UserID}`}</h4>
                      <p className="text-[11px] font-medium text-slate-400 mt-0.5">
                        {new Date(post.CreatedAt).toLocaleString('vi-VN', {hour: '2-digit', minute:'2-digit', day: '2-digit', month: '2-digit', year: 'numeric'})}
                      </p>
                    </div>
                  </div>
                  
                  {/* Nút Xử Phạt */}
                  <button onClick={() => handleModeratePost(post)} className="w-8 h-8 flex items-center justify-center text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-full transition-colors mt-8 mr-1" title="Xét duyệt & Xử phạt">
                    <Trash2 size={18} />
                  </button>
                </div>

                {/* 🚀 XỬ LÝ HIỂN THỊ MÀU NỀN (BgColor) */}
                <div 
                  className={`p-5 flex-1 flex flex-col gap-3 ${post.BgColor ? 'justify-center items-center' : ''}`}
                  style={post.BgColor ? { background: post.BgColor } : {}}
                >
                  <p className={`font-medium leading-relaxed line-clamp-4 ${post.BgColor ? 'text-white text-lg text-center drop-shadow-md p-4' : 'text-sm text-slate-700'}`}>
                    {post.Content || <span className={`italic ${post.BgColor ? 'opacity-80' : 'text-slate-400'}`}>(Không có văn bản)</span>}
                  </p>

                  {parsedImages.length > 0 && (
                    <div className={`grid gap-1 mt-auto ${parsedImages.length === 1 ? 'grid-cols-1' : 'grid-cols-2'}`}>
                      {parsedImages.slice(0, 2).map((imgUrl, i) => {
                        // 🚀 LOGIC ĐỒNG BỘ URL ẢNH VỚI THƯ MỤC UPLOADS CỦA MOBILE
                        // Xóa khoảng trắng thừa nếu có
                        const cleanUrl = imgUrl.trim(); 
                        
                        // Nếu chuỗi đã có sẵn http (VD: link Firebase, Cloudinary) thì xài luôn
                        // Nếu không, nối thêm domain và thư mục /uploads/
                        const finalImgUrl = cleanUrl.startsWith('http') 
                          ? cleanUrl 
                          : cleanUrl.startsWith('/uploads/') 
                            ? `http://192.168.1.7:3000${cleanUrl}` 
                            : `http://192.168.1.7:3000/uploads/${cleanUrl}`;

                        return (
                          <div key={i} className="relative aspect-video rounded-lg overflow-hidden bg-slate-100 border border-slate-200">
                            <img 
                              src={finalImgUrl} 
                              className="w-full h-full object-cover" 
                              alt="Post media" 
                              // 🚀 THÊM ERROR BUILDER ĐỂ NẾU LỖI ẢNH THÌ KHÔNG BỊ TRẮNG TRANG
                              onError={(e) => {
                                (e.target as HTMLImageElement).src = 'https://via.placeholder.com/400x200?text=Lỗi+tải+ảnh';
                              }}
                            />
                            {i === 1 && parsedImages.length > 2 && (
                              <div className="absolute inset-0 bg-slate-900/60 flex items-center justify-center text-white font-black text-lg">
                                +{parsedImages.length - 2}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>

                <div className="p-4 bg-slate-50 border-t border-slate-100 flex justify-between items-center">
                  <div className="flex gap-4">
                    <div className="flex items-center gap-1.5 text-slate-500 font-bold text-sm">
                      <Heart size={16} className={post.LikeCount > 0 ? 'text-rose-500 fill-rose-500' : ''}/> 
                      <span className={post.LikeCount > 0 ? 'text-slate-800' : ''}>{post.LikeCount}</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-slate-500 font-bold text-sm">
                      <MessageCircle size={16} className={post.CommentCount > 0 ? 'text-indigo-500 fill-indigo-100' : ''}/> 
                      <span className={post.CommentCount > 0 ? 'text-slate-800' : ''}>{post.CommentCount}</span>
                    </div>
                  </div>
                  {/* 🚀 NÚT XEM BÌNH LUẬN ĐÃ QUAY TRỞ LẠI */}
                  <button 
                    onClick={() => openPostDetails(post)} 
                    className="flex items-center gap-2 px-4 py-2 rounded-lg bg-white border border-slate-200 text-sm font-bold text-slate-600 hover:text-indigo-600 hover:border-indigo-300 hover:bg-indigo-50 transition-all shadow-sm"
                  >
                    <Eye size={16} /> Bình luận
                  </button>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {totalPages > 1 && (
        <div className="relative flex flex-col sm:flex-row justify-center items-center mt-2 p-4 bg-white rounded-2xl border border-slate-200 shadow-sm min-h-[70px] gap-4 z-10">
          <div className="sm:absolute sm:left-5 text-sm text-slate-500">
            Hiển thị <span className="font-bold text-indigo-600">{startIndex + 1}</span> - <span className="font-bold text-indigo-600">{Math.min(startIndex + ITEMS_PER_PAGE, filteredPosts.length)}</span> / <span className="font-bold text-slate-800">{filteredPosts.length}</span> bài
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

      {/* 🚀 MODAL CHI TIẾT BÀI VIẾT & QUẢN LÝ BÌNH LUẬN */}
      {selectedPost && (() => {
        // 🚀 BẮT LẠI MẢNG HÌNH ẢNH CHO MODAL
        let parsedModalImages: string[] = [];
        try {
           const rawImages = typeof selectedPost.Images === 'string' ? JSON.parse(selectedPost.Images) : selectedPost.Images;
           if (Array.isArray(rawImages)) parsedModalImages = rawImages.filter(img => img !== null);
        } catch (e) {}

        return (
          <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4">
            <div className="bg-white rounded-3xl w-[800px] max-h-[90vh] max-w-full flex flex-col shadow-2xl animate-[slide-in-bottom_0.3s_ease-out] overflow-hidden">
              
              <div className="px-6 py-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
                <h2 className="m-0 text-lg font-black text-slate-800 flex items-center gap-2">
                  <AlertTriangle className="text-indigo-600" size={20} /> Nội dung & Bình luận
                </h2>
                <button onClick={() => setSelectedPost(null)} className="bg-white border border-slate-200 hover:bg-red-50 hover:text-red-500 hover:border-red-200 text-slate-500 rounded-full w-8 h-8 flex items-center justify-center transition-all"><X size={18} /></button>
              </div>

              <div className="flex-1 overflow-y-auto p-6 bg-slate-100/50">
                
                {/* Box Bài Viết Gốc */}
                <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm mb-6 relative">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 rounded-full bg-slate-200 overflow-hidden border border-slate-300">
                      {/* 🚀 ĐÃ SỬA: Dùng hàm getAvatarUrl */}
                      {getAvatarUrl(selectedPost.Avatar) ? (
                        <img src={getAvatarUrl(selectedPost.Avatar)} alt="ava" className="w-full h-full object-cover" />
                      ) : (
                        <User size={20} className="m-auto mt-2 text-slate-400" />
                      )}
                    </div>
                    <div>
                      <h4 className="text-sm font-bold text-slate-800">{selectedPost.UserName || `User #${selectedPost.UserID}`}</h4>
                      <p className="text-xs font-medium text-slate-400">Ngày đăng: {new Date(selectedPost.CreatedAt).toLocaleString('vi-VN')}</p>
                    </div>
                  </div>
                  
                  {/* 🚀 MÀU NỀN TRONG CỬA SỔ MODAL (CHỮ TO, CĂN GIỮA NẾU CÓ MÀU) */}
                  <div 
                    className={`font-medium leading-relaxed p-6 rounded-xl border border-slate-100 mb-4 whitespace-pre-wrap min-h-[150px] flex ${
                      selectedPost.BgColor ? 'text-white text-xl text-center items-center justify-center drop-shadow-md' : 'text-slate-800 text-[15px] bg-slate-50'
                    }`}
                    style={selectedPost.BgColor ? { background: selectedPost.BgColor } : {}}
                  >
                    {selectedPost.Content}
                  </div>

                  {/* 🚀 HIỂN THỊ HÌNH ẢNH BÊN TRONG CỬA SỔ MODAL */}
                  {parsedModalImages.length > 0 && (
                    <div className={`grid gap-2 mb-4 ${parsedModalImages.length === 1 ? 'grid-cols-1' : 'grid-cols-2'}`}>
                      {parsedModalImages.map((imgUrl, i) => (
                        <div key={i} className="relative rounded-xl overflow-hidden bg-slate-100 border border-slate-200 flex justify-center items-center">
                          <img src={imgUrl.startsWith('http') ? imgUrl : `http://192.168.1.7:3000${imgUrl}`} className="w-full max-h-[300px] object-contain" alt="Post media" />
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Chỗ để phạt trực tiếp trong cửa sổ */}
                  <button 
                    onClick={() => handleModeratePost(selectedPost)}
                    className="absolute top-5 right-5 flex items-center gap-2 bg-red-50 text-red-600 px-3 py-1.5 rounded-lg font-bold text-xs hover:bg-red-500 hover:text-white transition-colors shadow-sm"
                  >
                    <ShieldAlert size={14}/> Phạt User này
                  </button>
                </div>

                {/* Khu vực Bình Luận */}
                <div>
                  <h3 className="font-black text-slate-800 text-base mb-4 flex items-center gap-2">
                    <MessageCircle size={18}/> Danh sách Bình luận ({postComments.length})
                  </h3>

                  {loadingComments ? (
                    <div className="py-8 text-center text-slate-400 text-sm font-medium">Đang tải bình luận...</div>
                  ) : postComments.length === 0 ? (
                    <div className="py-10 bg-white rounded-2xl border border-slate-200 border-dashed text-center text-slate-400 text-sm font-medium">
                      Chưa có bình luận nào cho bài viết này.
                    </div>
                  ) : (
                    <div className="flex flex-col gap-3">
                      {postComments.map((comment) => (
                        <div key={comment.CommentID} className="bg-white p-4 rounded-xl border border-slate-200 flex gap-4 hover:border-indigo-200 transition-colors group">
                          
                          {/* 🚀 ĐÃ SỬA: Avatar của người bình luận */}
                          <div className="w-8 h-8 rounded-full bg-slate-100 text-slate-500 flex items-center justify-center shrink-0 mt-1 overflow-hidden border border-slate-200">
                            {getAvatarUrl(comment.Avatar) ? (
                              <img src={getAvatarUrl(comment.Avatar)} alt="ava" className="w-full h-full object-cover" />
                            ) : (
                              <User size={14} />
                            )}
                          </div>

                          <div className="flex-1">
                            <div className="flex justify-between items-start">
                              <div>
                                {/* 🚀 ĐÃ SỬA: Tên người bình luận */}
                                <span className="font-bold text-sm text-slate-800">{comment.UserName || `Người dùng #${comment.UserID}`}</span>
                                <span className="text-[11px] font-medium text-slate-400 ml-2">{new Date(comment.CreatedAt).toLocaleString('vi-VN')}</span>
                              </div>
                              <button 
                                onClick={() => handleDeleteComment(comment.CommentID)}
                                className="text-slate-300 hover:text-red-500 hover:bg-red-50 rounded-md transition-colors p-1" title="Xóa bình luận vi phạm"
                              >
                                <Trash2 size={16} />
                              </button>
                            </div>
                            <p className="text-sm text-slate-600 mt-1.5 leading-relaxed">{comment.Content}</p>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

              </div>
            </div>
          </div>
        );
      })()}
    </div>
  );
};

export default Posts;