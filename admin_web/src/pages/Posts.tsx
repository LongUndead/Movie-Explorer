import React, { useState, useEffect, useMemo } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2';
import { Search, Trash2, MessageCircle, Heart, Eye, X, ChevronLeft, ChevronRight, User, AlertTriangle, ShieldAlert, Flag, Image as ImageIcon, Star, Film } from 'lucide-react';

const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
});

// ==========================================
// INTERFACES
// ==========================================
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
  TopReactions?: string; // 🚀 Bổ sung để TS không gạch đỏ
}

interface PostComment {
  CommentID: number;
  PostID: number;
  UserID: number;
  UserName?: string; 
  Avatar?: string;   
  Content: string;
  CreatedAt: string;
  Rating: number;
}

// 🚀 ĐÃ BỔ SUNG: Interface cho Đánh giá phim
interface Review {
  CommentID: number;
  UserID: number;
  UserName: string;
  Avatar: string;
  MovieTitle: string;
  Rating: number;
  Content: string;
  Tags: string;
  ImageURL: string;
  CreatedAt: string;
  LikeCount: number;
  ReplyCount: number;
  TopReactions?: string; // 🚀 Bổ sung để TS không gạch đỏ
}

interface ReviewReply {
  CommentID: number;
  UserID: number;
  UserName: string;
  Avatar: string;
  Content: string;
  ImageURL: string;
  CreatedAt: string;
}

const Posts = () => {
  // 1. STATE BÀI ĐĂNG (POSTS)
  const [posts, setPosts] = useState<Post[]>([]);
  const [loadingPosts, setLoadingPosts] = useState(true);
  
  // 2. STATE ĐÁNH GIÁ (REVIEWS)
  const [reviews, setReviews] = useState<Review[]>([]);
  const [loadingReviews, setLoadingReviews] = useState(true);

  // 3. UI STATE CHUNG
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState<'REPORTED' | 'ALL' | 'REVIEWS'>('REPORTED'); 
  const [currentPage, setCurrentPage] = useState(1);
  const ITEMS_PER_PAGE = 9; 

  // 4. MODAL STATE CHO BÀI ĐĂNG
  const [selectedPost, setSelectedPost] = useState<Post | null>(null);
  const [postComments, setPostComments] = useState<PostComment[]>([]);
  const [loadingComments, setLoadingComments] = useState(false);

  // 5. MODAL STATE CHO ĐÁNH GIÁ PHIM
  const [selectedReview, setSelectedReview] = useState<Review | null>(null);
  const [reviewReplies, setReviewReplies] = useState<ReviewReply[]>([]);
  const [loadingReplies, setLoadingReplies] = useState(false);
  // 6. MODAL XEM ẢNH PHÓNG TO
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  // 🚀 7. MODAL DANH SÁCH CẢM XÚC
  const [showReactionModal, setShowReactionModal] = useState(false);
  const [reactionDetails, setReactionDetails] = useState<any[]>([]);
  const [loadingReactions, setLoadingReactions] = useState(false);

  const API_URL = 'http://10.173.120.41:3000/api/admin';

  useEffect(() => { 
    fetchPosts(); 
    fetchReviews();
  }, []);

  useEffect(() => { setCurrentPage(1); }, [searchTerm, activeTab]);

  // 🚀 1. HÀM DỊCH BIỂU TƯỢNG CẢM XÚC
  const getReactionIcon = (topReactionsStr: string | undefined) => {
    if (!topReactionsStr) return <Heart size={16} className="text-slate-400" />;
    const top = topReactionsStr.split(',')[0].trim().toLowerCase();
    switch (top) {
      case 'love': return <span className="text-sm">❤️</span>;
      case 'haha': return <span className="text-sm">😆</span>;
      case 'wow': return <span className="text-sm">😮</span>;
      case 'sad': return <span className="text-sm">😢</span>;
      case 'angry': return <span className="text-sm">😡</span>;
      case 'like': 
      default: return <Heart size={16} className="text-rose-500 fill-rose-500" />;
    }
  };

  // 🚀 2. HÀM BÓC TÁCH MẢNG JSON LẤY RA 5 ẢNH
  const getMediaUrlList = (pathData: any): string[] => {
    if (!pathData || pathData === 'null' || pathData === '') return [];
    let imageArray: string[] = [];
    try {
      if (typeof pathData === 'string' && (pathData.startsWith('[') || pathData.includes(','))) {
        try { imageArray = JSON.parse(pathData); } 
        catch { imageArray = pathData.replace(/[\[\]"]/g, '').split(','); }
      } else if (Array.isArray(pathData)) { imageArray = pathData; } 
      else { imageArray = [pathData.toString()]; }
    } catch (e) { imageArray = [pathData.toString()]; }

    return imageArray.filter(img => img && img.trim() !== '').map(img => {
      let cleanPath = img.trim();
      if (cleanPath.startsWith('http')) return cleanPath;
      cleanPath = cleanPath.startsWith('/') ? cleanPath.substring(1) : cleanPath;
      if (cleanPath.startsWith('public/')) cleanPath = cleanPath.replace('public/', '');
      if (!cleanPath.startsWith('uploads/') && !cleanPath.includes('/')) cleanPath = `uploads/${cleanPath}`;
      return `http://10.173.120.41:3000/${cleanPath}`;
    });
  };

  const getMediaUrl = (path: any) => getMediaUrlList(path)[0] || '';

  // 🚀 HÀM GỌI API LẤY DANH SÁCH NGƯỜI THẢ CẢM XÚC
  const openReactionDetails = async (id: number, type: 'post' | 'review') => {
    // Check xem có ai like không mới mở
    if (type === 'post') {
        const target = posts.find(p => p.PostID === id);
        if (!target || target.LikeCount === 0) return;
    } else {
        const target = reviews.find(r => r.CommentID === id);
        if (!target || target.LikeCount === 0) return;
    }

    setShowReactionModal(true);
    setLoadingReactions(true);
    try {
      const endpoint = type === 'post' ? 'posts' : 'reviews';
      const res = await axios.get(`${API_URL}/${endpoint}/${id}/reactions`);
      setReactionDetails(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Không thể tải danh sách cảm xúc!' });
      setShowReactionModal(false);
    } finally {
      setLoadingReactions(false);
    }
  };

  // ==========================================
  // API GỌI DỮ LIỆU CHÍNH
  // ==========================================
  const fetchPosts = async () => {
    setLoadingPosts(true);
    try {
      const res = await axios.get(`${API_URL}/posts`);
      setPosts(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Lỗi lấy dữ liệu cộng đồng!' });
    } finally {
      setLoadingPosts(false);
    }
  };

  const fetchReviews = async () => {
    setLoadingReviews(true);
    try {
      const res = await axios.get(`${API_URL}/reviews`);
      setReviews(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Lỗi lấy dữ liệu đánh giá!' });
    } finally {
      setLoadingReviews(false);
    }
  };

  // ==========================================
  // XỬ LÝ BÀI ĐĂNG (POSTS)
  // ==========================================
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

  const handleDeletePostComment = async (commentId: number) => {
    Swal.fire({
      title: 'Xóa bình luận?',
      text: "Bạn xác nhận xóa bình luận này?",
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
          fetchPosts(); 
        } catch (error) {
          Swal.fire('Thất bại', 'Không thể xóa bình luận.', 'error');
        }
      }
    });
  };

  const handleModeratePost = async (post: Post) => {
    const { value: formValues } = await Swal.fire({
      title: 'Xét duyệt báo cáo',
      html: `
        <div class="text-left text-sm mt-2">
          <p class="mb-3 text-slate-600">Bài viết của <b>${post.UserName || `User #${post.UserID}`}</b> đang bị báo cáo.</p>
          <select id="penalty-select" class="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-indigo-500 font-medium text-slate-700 mb-3">
            <option value="IGNORE">Bỏ qua báo cáo (Bài viết hợp lệ)</option>
            <option value="WARN">Chỉ gỡ bài (Nhắc nhở nhẹ)</option>
            <option value="MUTE_7">Khóa tài khoản 7 ngày (Cảnh cáo)</option>
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
        
        if (penalty !== 'IGNORE' && reason.length < 5) {
          Swal.showValidationMessage('⚠️ Vui lòng nhập lý do xử phạt (ít nhất 5 ký tự) để lưu hồ sơ hệ thống!');
          return false;
        }
        return { penalty, reason: reason.replace(/<[^>]*>?/gm, '') };
      }
    });

    if (formValues) {
      const { penalty, reason } = formValues;
      try {
        if (penalty === 'IGNORE') {
          await axios.put(`${API_URL}/posts/${post.PostID}/ignore-reports`);
          Toast.fire({ icon: 'success', title: 'Đã bỏ qua báo cáo. Bài viết an toàn!' });
        } else {
          await axios.delete(`${API_URL}/posts/${post.PostID}`, { 
            data: { penaltyType: penalty, userId: post.UserID, reason: reason } 
          });
          
          let msg = 'Đã gỡ bài và Nhắc nhở.';
          if (penalty === 'MUTE_7') msg = 'Đã gỡ bài & Cấm đăng 7 ngày.';
          if (penalty === 'BAN') msg = 'Đã gỡ bài & Khóa vĩnh viễn User.';
          Toast.fire({ icon: 'success', title: msg });
        }
        fetchPosts(); 
        if (selectedPost?.PostID === post.PostID) setSelectedPost(null); 
      } catch (error: any) {
        Swal.fire('Thất bại', error.response?.data?.error || 'Đã xảy ra lỗi khi xử lý hệ thống.', 'error');
      }
    }
  };

  // ==========================================
  // XỬ LÝ ĐÁNH GIÁ PHIM (REVIEWS)
  // ==========================================
  const openReviewDetails = async (review: Review) => {
    setSelectedReview(review);
    setLoadingReplies(true);
    try {
      const res = await axios.get(`${API_URL}/reviews/${review.CommentID}/replies`);
      setReviewReplies(res.data);
    } catch (error) {
      Toast.fire({ icon: 'error', title: 'Không thể tải phản hồi!' });
    } finally {
      setLoadingReplies(false);
    }
  };

  const handleModerateReview = async (review: Review) => {
    const { value: formValues } = await Swal.fire({
      title: 'Xét duyệt Đánh giá',
      html: `
        <div class="text-left text-sm mt-2">
          <p class="mb-3 text-slate-600">Đánh giá của <b>${review.UserName}</b>.</p>
          <select id="review-penalty" class="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-amber-500 font-medium text-slate-700 mb-3">
            <option value="IGNORE">Bỏ qua (Giữ lại đánh giá)</option>
            <option value="WARN">Gỡ đánh giá (Nhắc nhở)</option>
            <option value="MUTE_7">Khóa tài khoản 7 ngày</option>
            <option value="BAN">Khóa tài khoản vĩnh viễn (Ban)</option>
          </select>
          <label class="block text-xs font-bold text-slate-700 mb-1">Lý do xử lý (Bắt buộc nếu gỡ/phạt):</label>
          <textarea id="review-reason" rows="3" class="w-full p-3 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-red-500 text-sm resize-none transition-all placeholder:text-slate-400" placeholder="VD: Spam, ngôn từ thù ghét..."></textarea>
        </div>
      `,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#f59e0b', 
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Xác nhận xử lý',
      cancelButtonText: 'Hủy',
      preConfirm: () => {
        const penalty = (document.getElementById('review-penalty') as HTMLSelectElement).value;
        const reason = (document.getElementById('review-reason') as HTMLTextAreaElement).value.trim();
        if (penalty !== 'IGNORE' && reason.length < 5) {
          Swal.showValidationMessage('⚠️ Vui lòng nhập lý do (ít nhất 5 ký tự)!');
          return false;
        }
        return { penalty, reason };
      }
    });

    if (formValues) {
      const { penalty, reason } = formValues;
      try {
        if (penalty === 'IGNORE') {
          Toast.fire({ icon: 'success', title: 'Đã bỏ qua báo cáo!' });
        } else {
          // Gửi API xóa bình luận/đánh giá kèm theo thông tin xử phạt
          await axios.delete(`${API_URL}/comments/${review.CommentID}`, { 
            data: { penaltyType: penalty, userId: review.UserID, reason: reason } 
          });
          
          let msg = 'Đã gỡ Đánh giá và Nhắc nhở.';
          if (penalty === 'MUTE_7') msg = 'Đã gỡ Đánh giá & Cấm 7 ngày.';
          if (penalty === 'BAN') msg = 'Đã gỡ Đánh giá & Khóa vĩnh viễn.';
          Toast.fire({ icon: 'success', title: msg });
          
          // Cập nhật lại UI
          setReviews(reviews.filter(r => r.CommentID !== review.CommentID));
          if (selectedReview?.CommentID === review.CommentID) setSelectedReview(null);
        }
      } catch (error: any) {
        Swal.fire('Thất bại', error.response?.data?.error || 'Lỗi xử lý hệ thống.', 'error');
      }
    }
  };

  const handleDeleteReviewOrReply = async (commentId: number, isReply: boolean = false) => {
    Swal.fire({
      title: 'Xóa bình luận?',
      text: "Hành động này không thể hoàn tác!",
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#ef4444',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Xóa ngay',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          await axios.delete(`${API_URL}/comments/${commentId}`);
          Toast.fire({ icon: 'success', title: 'Đã xóa thành công!' });
          
          if (isReply) {
            setReviewReplies(reviewReplies.filter(r => r.CommentID !== commentId));
            fetchReviews(); 
          } else {
            setReviews(reviews.filter(r => r.CommentID !== commentId));
            if (selectedReview?.CommentID === commentId) setSelectedReview(null);
          }
        } catch (error) {
          Swal.fire('Thất bại', 'Lỗi hệ thống khi xóa.', 'error');
        }
      }
    });
  };

  // ==========================================
  // BỘ LỌC VÀ PHÂN TRANG CHUNG
  // ==========================================
  const filteredPosts = useMemo(() => {
    return posts.filter(post => {
      const matchesSearch = (post.Content || '').toLowerCase().includes(searchTerm.toLowerCase());
      const matchesTab = activeTab === 'ALL' ? true : (post.ReportCount > 0);
      return matchesSearch && matchesTab;
    });
  }, [posts, searchTerm, activeTab]);

  const filteredReviewsList = useMemo(() => {
    return reviews.filter(rev => 
      (rev.Content || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (rev.MovieTitle || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
      (rev.UserName || '').toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [reviews, searchTerm]);

  // Tính toán Item hiển thị dựa trên Tab đang chọn
  const isReviewTab = activeTab === 'REVIEWS';
  const totalItems = isReviewTab ? filteredReviewsList.length : filteredPosts.length;
  const totalPages = Math.ceil(totalItems / ITEMS_PER_PAGE);
  const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
  
  const currentPostItems = filteredPosts.slice(startIndex, startIndex + ITEMS_PER_PAGE);
  const currentReviewItems = filteredReviewsList.slice(startIndex, startIndex + ITEMS_PER_PAGE);

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
  const isLoadingGeneral = isReviewTab ? loadingReviews : loadingPosts;

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] flex flex-col gap-6 animate-[fade-in_0.3s_ease-out]">
      
      {/* 🚀 THANH BỘ LỌC VÀ 3 TABS */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col xl:flex-row justify-between items-center gap-4 z-20">
        
        <div className="flex bg-slate-100 p-1.5 rounded-xl w-full xl:w-auto overflow-x-auto no-scrollbar">
          <button
            onClick={() => setActiveTab('REPORTED')}
            className={`flex-1 xl:flex-none flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all ${
              activeTab === 'REPORTED' ? 'bg-white text-red-600 shadow-sm scale-105' : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            <Flag size={16} className={activeTab === 'REPORTED' ? "fill-red-100" : ""} /> 
            Bài đăng bị báo cáo 
            {totalReported > 0 && <span className="bg-red-500 text-white text-[10px] px-2 py-0.5 rounded-full">{totalReported}</span>}
          </button>
          
          <button
            onClick={() => setActiveTab('ALL')}
            className={`flex-1 xl:flex-none flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all ${
              activeTab === 'ALL' ? 'bg-white text-indigo-600 shadow-sm scale-105' : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            <MessageCircle size={16} /> Tất cả bài viết
          </button>

          <button
            onClick={() => setActiveTab('REVIEWS')}
            className={`flex-1 xl:flex-none flex items-center justify-center gap-2 px-4 py-2.5 rounded-lg font-bold text-sm whitespace-nowrap transition-all ${
              activeTab === 'REVIEWS' ? 'bg-white text-amber-600 shadow-sm scale-105' : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            <Star size={16} className={activeTab === 'REVIEWS' ? "fill-amber-100" : ""} /> Đánh giá phim
          </button>
        </div>

        <div className="relative flex-1 w-full xl:max-w-sm group">
          <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-indigo-500 transition-colors" size={18} />
          <input 
            type="text" placeholder="Tra cứu nội dung..." 
            value={searchTerm} onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-11 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-indigo-500 focus:bg-white focus:ring-4 focus:ring-indigo-50 text-sm font-medium transition-all"
          />
        </div>
      </div>

      {isLoadingGeneral ? (
        <div className="py-20 text-center text-slate-400 font-medium">Đang tải dữ liệu...</div>
      ) : totalItems === 0 ? (
        <div className="py-20 text-center text-slate-400 font-medium flex flex-col items-center">
          <ShieldAlert size={48} className="mb-4 opacity-20" /> 
          {activeTab === 'REPORTED' ? 'Tuyệt vời! Cộng đồng đang rất trong sạch.' : 'Chưa có dữ liệu.'}
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
          
          {/* ========================================== */}
          {/* RENDER BÀI ĐĂNG (TAB REPORTED VÀ ALL) */}
          {/* ========================================== */}
          {!isReviewTab && currentPostItems.map((post, index) => {
            // 🚀 Gọi hàm bóc tách mảng ảnh và gán vào biến parsedImages để xài
            const parsedImages = getMediaUrlList(post.Images);

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
                      {getMediaUrl(post.Avatar) ? <img src={getMediaUrl(post.Avatar)} alt="ava" className="w-full h-full object-cover" /> : <User size={20} className="m-auto mt-2 text-slate-400" />}
                    </div>
                    <div>
                      <h4 className="text-sm font-bold text-slate-800 leading-tight line-clamp-1">{post.UserName || `User #${post.UserID}`}</h4>
                      <p className="text-[11px] font-medium text-slate-400 mt-0.5">{new Date(post.CreatedAt).toLocaleString('vi-VN')}</p>
                    </div>
                  </div>
                  
                  <button onClick={() => handleModeratePost(post)} className="w-8 h-8 flex items-center justify-center text-slate-400 hover:text-red-500 hover:bg-red-50 rounded-full transition-colors mt-8 mr-1" title="Xét duyệt & Xử phạt">
                    <Trash2 size={18} />
                  </button>
                </div>

                <div 
                  className={`p-5 flex-1 flex flex-col gap-3 ${post.BgColor ? 'justify-center items-center' : ''}`}
                  style={post.BgColor ? { background: post.BgColor } : {}}
                >
                  <p className={`font-medium leading-relaxed line-clamp-4 ${post.BgColor ? 'text-white text-lg text-center drop-shadow-md p-4' : 'text-sm text-slate-700'}`}>
                    {post.Content || <span className={`italic ${post.BgColor ? 'opacity-80' : 'text-slate-400'}`}>(Không có văn bản)</span>}
                  </p>

                  {/* 🚀 ĐÃ FIX LỖI GẠCH ĐỎ VÀ THÊM HIỆU ỨNG BẤM PHÓNG TO */}
                  {parsedImages.length > 0 && (
                    <div className={`grid gap-1 mt-auto ${parsedImages.length === 1 ? 'grid-cols-1' : 'grid-cols-2'}`}>
                      {parsedImages.slice(0, 2).map((imgUrl, i) => (
                          <div key={i} className="relative aspect-video rounded-lg overflow-hidden bg-slate-100 border border-slate-200 cursor-pointer group" onClick={() => setPreviewImage(imgUrl)}>
                            <img src={imgUrl} className="w-full h-full object-cover group-hover:scale-105 transition-transform" alt="Post media" onError={(e) => {(e.target as HTMLImageElement).src = 'https://via.placeholder.com/400x200?text=Lỗi+tải+ảnh';}} />
                            
                            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors flex items-center justify-center">
                              <Eye size={24} className="text-white opacity-0 group-hover:opacity-100 drop-shadow-md"/>
                            </div>

                            {i === 1 && parsedImages.length > 2 && (
                              <div className="absolute inset-0 bg-slate-900/60 flex items-center justify-center text-white font-black text-lg">+{parsedImages.length - 2}</div>
                            )}
                          </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="p-4 bg-slate-50 border-t border-slate-100 flex justify-between items-center">
                  <div className="flex gap-4">
                    <div className="flex gap-4">
                    <div onClick={() => openReactionDetails(post.PostID, 'post')} className="flex items-center gap-1.5 font-bold text-sm cursor-pointer hover:bg-slate-100 p-1.5 -ml-1.5 rounded-lg transition-colors" title="Xem người thả cảm xúc">
                      {/* 🚀 ĐÃ FIX: Trả lại đúng biến post cho Bài Đăng */}
                      {getReactionIcon(post.TopReactions)} 
                      <span className={post.LikeCount > 0 ? 'text-slate-800' : 'text-slate-400'}>{post.LikeCount}</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-slate-500 font-bold text-sm">
                      <MessageCircle size={16} className={post.CommentCount > 0 ? 'text-indigo-500 fill-indigo-100' : ''}/> 
                      <span className={post.CommentCount > 0 ? 'text-slate-800' : ''}>{post.CommentCount}</span>
                    </div>
                  </div>
                  </div>
                  <button onClick={() => openPostDetails(post)} className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white border border-slate-200 text-xs font-bold text-slate-600 hover:text-indigo-600 hover:border-indigo-300 hover:bg-indigo-50 transition-all shadow-sm">
                    <Eye size={14} /> Chi tiết
                  </button>
                </div>
              </div>
            )
          })}

          {/* ========================================== */}
          {/* RENDER ĐÁNH GIÁ PHIM (TAB REVIEWS) */}
          {/* ========================================== */}
          {isReviewTab && currentReviewItems.map((review, index) => (
            <div key={review.CommentID} style={{ animationDelay: `${index * 30}ms` }} className="bg-white rounded-2xl border border-slate-200 shadow-sm hover:shadow-xl transition-all duration-300 flex flex-col overflow-hidden animate-[slide-in-bottom_0.4s_ease-out_backwards]">
              
              <div className="p-4 border-b border-slate-100 bg-slate-50/50 flex justify-between items-start">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-slate-200 overflow-hidden shrink-0 border border-slate-300">
                    {getMediaUrl(review.Avatar) ? <img src={getMediaUrl(review.Avatar)} alt="ava" className="w-full h-full object-cover" /> : <User size={20} className="m-auto mt-2 text-slate-400" />}
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-slate-800 leading-tight">{review.UserName || (review as any).Username || 'Khách'}</h4>
                    <p className="text-[11px] font-medium text-slate-400 mt-0.5">{new Date(review.CreatedAt).toLocaleString('vi-VN')}</p>
                  </div>
                </div>
                <button onClick={() => handleModerateReview(review)} className="text-slate-400 hover:text-red-500 hover:bg-red-50 p-1.5 rounded-lg transition-colors" title="Xét duyệt & Xử phạt"><Trash2 size={16} /></button>
              </div>

              <div className="p-5 flex-1 flex flex-col gap-3">
                <div>
                  <div className="text-xs font-bold text-indigo-600 uppercase mb-1 flex items-center gap-1.5"><Film size={12}/> {review.MovieTitle}</div>
                  <div className="flex items-center gap-1">
                    <Star size={18} className="text-amber-500 fill-amber-500"/>
                    <span className="font-black text-slate-800 text-lg">{review.Rating}<span className="text-sm text-slate-400">/10</span></span>
                  </div>
                </div>

                <p className="text-sm text-slate-700 leading-relaxed line-clamp-3 mt-1">{review.Content}</p>

                {review.Tags && (
                  <div className="flex flex-wrap gap-1.5 mt-1">
                    {review.Tags.split(',').map((tag, i) => (
                      <span key={i} className="bg-slate-100 text-slate-600 text-[10px] font-bold px-2 py-1 rounded-md">{tag.trim()}</span>
                    ))}
                  </div>
                )}

                {/* 🚀 ĐÃ FIX: MẢNG HÌNH ẢNH ĐÁNH GIÁ (LÊN ĐẾN 5 ẢNH) VÀ BẤM ĐỂ PHÓNG TO */}
                {getMediaUrlList(review.ImageURL).length > 0 && (
                  <div className={`grid gap-1 mt-3 ${getMediaUrlList(review.ImageURL).length === 1 ? 'grid-cols-1' : 'grid-cols-2'}`}>
                    {getMediaUrlList(review.ImageURL).slice(0, 2).map((imgUrl, i) => (
                        <div key={i} className="relative aspect-video rounded-lg overflow-hidden bg-slate-100 border border-slate-200 cursor-pointer group" onClick={() => setPreviewImage(imgUrl)}>
                          <img src={imgUrl} className="w-full h-full object-cover group-hover:scale-105 transition-transform" alt="review media" onError={(e) => {(e.target as HTMLImageElement).src = 'https://via.placeholder.com/400x200?text=Lỗi+tải+ảnh';}} />
                          
                          <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors flex items-center justify-center">
                            <Eye size={24} className="text-white opacity-0 group-hover:opacity-100 drop-shadow-md"/>
                          </div>

                          {i === 1 && getMediaUrlList(review.ImageURL).length > 2 && (
                            <div className="absolute inset-0 bg-slate-900/60 flex items-center justify-center text-white font-black text-lg">+{getMediaUrlList(review.ImageURL).length - 2}</div>
                          )}
                        </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="p-4 bg-slate-50 border-t border-slate-100 flex justify-between items-center">
                <div className="flex gap-4">
                  <div onClick={() => openReactionDetails(review.CommentID, 'review')} className="flex items-center gap-1.5 font-bold text-sm cursor-pointer hover:bg-slate-100 p-1.5 -ml-1.5 rounded-lg transition-colors" title="Xem người thả cảm xúc">
                    {/* 🚀 ĐÃ FIX: GỌI HÀM CẢM XÚC CHO TAB ĐÁNH GIÁ */}
                    {getReactionIcon(review.TopReactions)} 
                    <span className={review.LikeCount > 0 ? 'text-slate-800' : 'text-slate-400'}>{review.LikeCount}</span>
                  </div>
                  <div className="flex items-center gap-1.5 text-slate-500 font-bold text-sm">
                    <MessageCircle size={16} className={review.ReplyCount > 0 ? 'text-amber-500 fill-amber-100' : ''}/> 
                    <span className={review.ReplyCount > 0 ? 'text-slate-800' : ''}>{review.ReplyCount}</span>
                  </div>
                </div>
                <button onClick={() => openReviewDetails(review)} className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white border border-slate-200 text-xs font-bold text-slate-600 hover:text-amber-600 hover:border-amber-300 hover:bg-amber-50 transition-all shadow-sm">
                  <Eye size={14} /> Chi tiết
                </button>
              </div>
            </div>
          ))}

        </div>
      )}

      {/* CHUYỂN TRANG */}
      {totalPages > 1 && (
        <div className="relative flex flex-col sm:flex-row justify-center items-center mt-2 p-4 bg-white rounded-2xl border border-slate-200 shadow-sm min-h-[70px] gap-4 z-10">
          <div className="sm:absolute sm:left-5 text-sm text-slate-500">
            Hiển thị <span className="font-bold text-indigo-600">{startIndex + 1}</span> - <span className="font-bold text-indigo-600">{Math.min(startIndex + ITEMS_PER_PAGE, totalItems)}</span> / <span className="font-bold text-slate-800">{totalItems}</span> bài
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

      {/* ========================================== */}
      {/* 🚀 MODAL CHI TIẾT BÀI ĐĂNG (CỘNG ĐỒNG) */}
      {/* ========================================== */}
      {selectedPost && (() => {
        // 🚀 ĐÃ FIX: Dùng hàm xịn để bóc tách 5 ảnh cho Modal
        const parsedModalImages = getMediaUrlList(selectedPost.Images);

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
                <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm mb-6 relative">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="w-10 h-10 rounded-full bg-slate-200 overflow-hidden border border-slate-300">
                      {getMediaUrl(selectedPost.Avatar) ? <img src={getMediaUrl(selectedPost.Avatar)} alt="ava" className="w-full h-full object-cover" /> : <User size={20} className="m-auto mt-2 text-slate-400" />}
                    </div>
                    <div>
                      <h4 className="text-sm font-bold text-slate-800">{selectedPost.UserName || `User #${selectedPost.UserID}`}</h4>
                      <p className="text-xs font-medium text-slate-400">Ngày đăng: {new Date(selectedPost.CreatedAt).toLocaleString('vi-VN')}</p>
                    </div>
                  </div>
                  
                  <div className={`font-medium leading-relaxed p-6 rounded-xl border border-slate-100 mb-4 whitespace-pre-wrap min-h-[150px] flex ${selectedPost.BgColor ? 'text-white text-xl text-center items-center justify-center drop-shadow-md' : 'text-slate-800 text-[15px] bg-slate-50'}`} style={selectedPost.BgColor ? { background: selectedPost.BgColor } : {}}>
                    {selectedPost.Content}
                  </div>

                  {/* 🚀 ĐÃ FIX LỖI HIỂN THỊ ẢNH TRONG MODAL */}
                  {parsedModalImages.length > 0 && (
                    <div className={`grid gap-2 mb-4 ${parsedModalImages.length === 1 ? 'grid-cols-1' : 'grid-cols-2'}`}>
                      {parsedModalImages.map((finalUrl, i) => (
                          <div key={i} className="relative rounded-xl overflow-hidden bg-slate-100 border border-slate-200 flex justify-center items-center group cursor-pointer" onClick={() => setPreviewImage(finalUrl)}>
                            <img src={finalUrl} className="w-full max-h-[300px] object-contain group-hover:scale-105 transition-transform" alt="media" onError={(e) => {(e.target as HTMLImageElement).src = 'https://via.placeholder.com/400x200?text=Lỗi+tải+ảnh';}} />
                            <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors flex items-center justify-center"><Eye size={24} className="text-white opacity-0 group-hover:opacity-100 drop-shadow-md"/></div>
                          </div>
                      ))}
                    </div>
                  )}

                  <button onClick={() => handleModeratePost(selectedPost)} className="absolute top-5 right-5 flex items-center gap-2 bg-red-50 text-red-600 px-3 py-1.5 rounded-lg font-bold text-xs hover:bg-red-500 hover:text-white transition-colors shadow-sm">
                    <ShieldAlert size={14}/> Phạt User này
                  </button>
                </div>

                <div>
                  <h3 className="font-black text-slate-800 text-base mb-4 flex items-center gap-2">
                    <MessageCircle size={18}/> Danh sách Bình luận ({postComments.length})
                  </h3>

                  {loadingComments ? (
                    <div className="py-8 text-center text-slate-400 text-sm font-medium">Đang tải bình luận...</div>
                  ) : postComments.length === 0 ? (
                    <div className="py-10 bg-white rounded-2xl border border-slate-200 border-dashed text-center text-slate-400 text-sm font-medium">Chưa có bình luận nào.</div>
                  ) : (
                    <div className="flex flex-col gap-3">
                      {postComments.map((comment) => (
                        <div key={comment.CommentID} className="bg-white p-4 rounded-xl border border-slate-200 flex gap-4 hover:border-indigo-200 transition-colors">
                          <div className="w-8 h-8 rounded-full bg-slate-100 flex items-center justify-center shrink-0 overflow-hidden border border-slate-200">
                            {getMediaUrl(comment.Avatar) ? <img src={getMediaUrl(comment.Avatar)} alt="ava" className="w-full h-full object-cover" /> : <User size={14} className="text-slate-400" />}
                          </div>
                          <div className="flex-1">
                            <div className="flex justify-between items-start">
                              <div>
                                <span className="font-bold text-sm text-slate-800">{comment.UserName || `User #${comment.UserID}`}</span>
                                <span className="text-[11px] font-medium text-slate-400 ml-2">{new Date(comment.CreatedAt).toLocaleString('vi-VN')}</span>
                              </div>
                              <button onClick={() => handleDeletePostComment(comment.CommentID)} className="text-slate-300 hover:text-red-500 hover:bg-red-50 rounded-md transition-colors p-1"><Trash2 size={16} /></button>
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

      {/* ========================================== */}
      {/* 🚀 MODAL CHI TIẾT ĐÁNH GIÁ (REVIEWS) */}
      {/* ========================================== */}
      {selectedReview && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[1000] p-4">
          <div className="bg-white rounded-3xl w-[700px] max-h-[90vh] max-w-full flex flex-col shadow-2xl animate-[slide-in-bottom_0.3s_ease-out] overflow-hidden">
            
            <div className="px-6 py-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
              <h2 className="m-0 text-lg font-black text-slate-800 flex items-center gap-2">
                <Star className="text-amber-500 fill-amber-500" size={20} /> Chi Tiết Đánh Giá
              </h2>
              <button onClick={() => setSelectedReview(null)} className="bg-white border border-slate-200 hover:bg-red-50 hover:text-red-500 hover:border-red-200 text-slate-500 rounded-full w-8 h-8 flex items-center justify-center transition-all"><X size={18} /></button>
            </div>

            <div className="flex-1 overflow-y-auto p-6 bg-slate-100/50">
              <div className="bg-white p-6 rounded-2xl border border-amber-200 shadow-sm mb-6 relative">
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 rounded-full overflow-hidden border border-slate-200">
                      {getMediaUrl(selectedReview.Avatar) ? <img src={getMediaUrl(selectedReview.Avatar)} alt="ava" className="w-full h-full object-cover" /> : <User size={24} className="m-auto mt-2 text-slate-400" />}
                    </div>
                    <div>
                      <h4 className="text-base font-bold text-slate-800 m-0">{selectedReview.UserName || (selectedReview as any).Username || 'Khách'}</h4>
                      <p className="text-xs font-medium text-slate-400 m-0 mt-0.5">{new Date(selectedReview.CreatedAt).toLocaleString('vi-VN')}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs font-bold text-indigo-600 mb-1">{selectedReview.MovieTitle}</div>
                    <div className="inline-flex items-center gap-1 bg-amber-50 px-2 py-1 rounded-lg border border-amber-100">
                      <Star size={16} className="text-amber-500 fill-amber-500"/>
                      <span className="font-black text-amber-700">{selectedReview.Rating}/10</span>
                    </div>
                  </div>
                </div>

                <p className="text-[15px] text-slate-700 leading-relaxed mb-4">{selectedReview.Content}</p>

                {selectedReview.Tags && (
                  <div className="flex flex-wrap gap-2 mb-4">
                    {selectedReview.Tags.split(',').map((tag, i) => (
                      <span key={i} className="bg-slate-100 text-slate-600 text-xs font-bold px-2.5 py-1.5 rounded-lg border border-slate-200">{tag.trim()}</span>
                    ))}
                  </div>
                )}

                {/* 🚀 ĐÃ FIX: TRẢ ĐỦ TOÀN BỘ ẢNH TRONG MODAL CHI TIẾT ĐÁNH GIÁ */}
                {getMediaUrlList(selectedReview.ImageURL).length > 0 && (
                  <div className={`grid gap-2 mb-4 ${getMediaUrlList(selectedReview.ImageURL).length === 1 ? 'grid-cols-1' : 'grid-cols-2'}`}>
                    {getMediaUrlList(selectedReview.ImageURL).map((imgUrl, i) => (
                      <div key={i} className="relative rounded-xl overflow-hidden bg-slate-100 border border-slate-200 flex justify-center items-center group cursor-pointer" onClick={() => setPreviewImage(imgUrl)}>
                        <img src={imgUrl} className="w-full max-h-[300px] object-contain group-hover:scale-105 transition-transform" alt="review media" onError={(e) => {(e.target as HTMLImageElement).src = 'https://via.placeholder.com/400x200?text=Lỗi+tải+ảnh';}} />
                        <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors flex items-center justify-center"><Eye size={24} className="text-white opacity-0 group-hover:opacity-100 drop-shadow-md"/></div>
                      </div>
                    ))}
                  </div>
                )}
                
                <button onClick={() => handleModerateReview(selectedReview!)} className="absolute bottom-4 right-4 flex items-center gap-2 bg-red-50 text-red-600 px-3 py-1.5 rounded-lg font-bold text-xs hover:bg-red-500 hover:text-white transition-colors shadow-sm">
                  <ShieldAlert size={14}/> Phạt User này
                </button>
              </div>

              <div>
                <h3 className="font-black text-slate-800 text-base mb-4 flex items-center gap-2">
                  <MessageCircle size={18}/> Phản hồi của cộng đồng ({reviewReplies.length})
                </h3>

                {loadingReplies ? (
                  <div className="py-8 text-center text-slate-400 text-sm font-medium">Đang tải phản hồi...</div>
                ) : reviewReplies.length === 0 ? (
                  <div className="py-10 bg-white rounded-2xl border border-slate-200 border-dashed text-center text-slate-400 text-sm font-medium">
                    Chưa có ai phản hồi đánh giá này.
                  </div>
                ) : (
                  <div className="flex flex-col gap-3">
                    {reviewReplies.map((reply) => {
                      const replyImgs = getMediaUrlList(reply.ImageURL);
                      // 🚀 LỌC TÁC GIẢ BÌNH LUẬN TRONG BÀI CỦA MÌNH
                      const isAuthor = reply.UserID === selectedReview?.UserID;
                      
                      return (
                        <div key={reply.CommentID} className="bg-white p-4 rounded-xl border border-slate-200 flex gap-4 hover:border-amber-200 transition-colors">
                          <div className="w-8 h-8 rounded-full bg-slate-100 overflow-hidden border border-slate-200 shrink-0">
                            {getMediaUrl(reply.Avatar) ? <img src={getMediaUrl(reply.Avatar)} alt="ava" className="w-full h-full object-cover" /> : <User size={14} className="m-auto mt-1.5 text-slate-400" />}
                          </div>
                          <div className="flex-1">
                            <div className="flex justify-between items-start">
                              <div>
                                <span className="font-bold text-sm text-slate-800">{reply.UserName || (reply as any).Username || 'Khách'}</span>
                                {/* 🚀 ĐÁNH DẤU CHỮ TÁC GIẢ */}
                                {isAuthor && <span className="ml-2 bg-amber-100 text-amber-700 text-[10px] px-1.5 py-0.5 rounded font-black">TÁC GIẢ</span>}
                                <span className="text-[11px] font-medium text-slate-400 ml-2 block sm:inline">{new Date(reply.CreatedAt).toLocaleString('vi-VN')}</span>
                              </div>
                              <button onClick={() => handleDeleteReviewOrReply(reply.CommentID, true)} className="text-slate-300 hover:text-red-500 hover:bg-red-50 rounded-md transition-colors p-1" title="Xóa phản hồi"><Trash2 size={16} /></button>
                            </div>
                            <p className="text-sm text-slate-600 mt-1.5 leading-relaxed">{reply.Content}</p>
                            
                            {/* 🚀 ẢNH BÌNH LUẬN ĐÃ SỬA LỖI JSON VÀ BẤM PHÓNG TO */}
                            {replyImgs.length > 0 && (
                              <div className="mt-2 relative group cursor-pointer inline-block rounded-lg overflow-hidden border border-slate-200" onClick={() => setPreviewImage(replyImgs[0])}>
                                <img src={replyImgs[0]} className="max-h-32 object-contain group-hover:scale-105 transition-transform" alt="reply" />
                                <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 flex items-center justify-center"><Eye size={20} className="text-white opacity-0 group-hover:opacity-100"/></div>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

    {/* ========================================== */}
      {/* 🚀 MODAL XEM CHI TIẾT DANH SÁCH CẢM XÚC */}
      {/* ========================================== */}
      {showReactionModal && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center z-[1100] p-4" onClick={() => setShowReactionModal(false)}>
          <div className="bg-white rounded-3xl w-[400px] max-h-[70vh] flex flex-col shadow-2xl overflow-hidden animate-[slide-in-bottom_0.2s_ease-out]" onClick={e => e.stopPropagation()}>
            <div className="px-6 py-4 border-b border-slate-100 flex justify-between items-center bg-slate-50">
              <h2 className="m-0 text-base font-black text-slate-800 flex items-center gap-2">
                <Heart className="text-rose-500 fill-rose-500" size={18} /> Ai đã thả cảm xúc?
              </h2>
              <button onClick={() => setShowReactionModal(false)} className="bg-white border border-slate-200 hover:bg-red-50 hover:text-red-500 text-slate-500 rounded-full w-8 h-8 flex items-center justify-center transition-all"><X size={16} /></button>
            </div>
            
            <div className="flex-1 overflow-y-auto p-4">
              {loadingReactions ? (
                <div className="py-8 text-center text-slate-400 text-sm font-medium">Đang tải danh sách...</div>
              ) : reactionDetails.length === 0 ? (
                <div className="py-8 text-center text-slate-400 text-sm font-medium">Chưa có ai thả cảm xúc.</div>
              ) : (
                <div className="flex flex-col gap-3">
                  {reactionDetails.map((rx, idx) => (
                    <div key={idx} className="flex items-center gap-4 bg-slate-50 p-3 rounded-xl border border-slate-100 hover:border-indigo-200 transition-colors">
                      <div className="relative">
                        <div className="w-10 h-10 rounded-full bg-white overflow-hidden shrink-0 border border-slate-200">
                          {getMediaUrl(rx.Avatar) ? <img src={getMediaUrl(rx.Avatar)} alt="ava" className="w-full h-full object-cover" /> : <User size={20} className="m-auto mt-2 text-slate-400" />}
                        </div>
                        <div className="absolute -bottom-1 -right-2 bg-white rounded-full p-[2px] shadow-sm border border-slate-100 flex items-center justify-center w-6 h-6">
                          {getReactionIcon(rx.ReactionType)}
                        </div>
                      </div>
                      <span className="font-bold text-sm text-slate-800">{rx.Username || `Người dùng #${rx.UserID}`}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ========================================== */}
      {/* 🚀 MODAL XEM ẢNH PHÓNG TO */}
      {/* ========================================== */}
      {previewImage && (
        <div className="fixed inset-0 bg-slate-900/90 z-[9999] flex items-center justify-center p-4" onClick={() => setPreviewImage(null)}>
          <button onClick={() => setPreviewImage(null)} className="absolute top-6 right-6 text-white bg-white/20 hover:bg-red-500 rounded-full w-10 h-10 flex items-center justify-center transition-all">
            <X size={24} />
          </button>
          <img src={previewImage} alt="Preview" className="max-w-full max-h-full object-contain drop-shadow-2xl animate-[zoom-in_0.2s_ease-out]" onClick={(e) => e.stopPropagation()} />
        </div>
      )}

    </div>
  );
};

export default Posts;