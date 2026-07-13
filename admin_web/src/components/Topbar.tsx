import { useState, useEffect, useRef } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import Swal from 'sweetalert2'; // 🚀 IMPORT SWEETALERT2
import { Bell, ChevronDown, LogOut, Settings, User } from 'lucide-react'; 

const Topbar = () => {
  const navigate = useNavigate();
  const location = useLocation(); 
  
  const [adminName, setAdminName] = useState('Admin');
  const [adminAvatar, setAdminAvatar] = useState(''); 
  const [isProfileOpen, setIsProfileOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const userStr = localStorage.getItem('admin_user');
    if (userStr) {
      const user = JSON.parse(userStr);
      setAdminName(user.Username || 'Admin');
      if (user.Avatar) setAdminAvatar(user.Avatar);
    }
    
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsProfileOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // 🚀 ĐĂNG XUẤT VỚI SWEETALERT2
  const handleLogout = () => {
    setIsProfileOpen(false); // Đóng menu trước khi hiện popup
    Swal.fire({
      title: 'Đăng xuất?',
      text: "Bạn có chắc chắn muốn thoát khỏi phiên làm việc này?",
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#ef4444',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Đăng xuất',
      cancelButtonText: 'Hủy',
      reverseButtons: true
    }).then((result) => {
      if (result.isConfirmed) {
        localStorage.removeItem('admin_user');
        navigate('/login');
      }
    });
  };

  const getPageInfo = () => {
    switch (location.pathname) {
      case '/': return { title: 'Tổng Quan Hệ Thống', desc: 'Theo dõi doanh thu và phát hiện các suất chiếu trống ghế.' };
      case '/customers': return { title: 'Quản Lý Người Dùng', desc: 'Quản trị thông tin khách hàng, phân quyền và danh sách đen.' };
      case '/showtimes': return { title: 'Quản Lý Lịch Chiếu', desc: 'Sắp xếp thời gian và phòng chiếu phim.' };
      case '/rooms': return { title: 'Quản Lý Phim & Rạp', desc: 'Quản lý phim, rạp chiếu, phòng chiếu và sơ đồ ghế, diễn viên và thể loại phim.' };
      
      case '/orders': return { title: 'Quản Lý Đơn Hàng', desc: 'Kiểm soát, theo dõi và xử lý các giao dịch đặt vé, mua đồ ăn.' };
      case '/foods': return { title: 'Quản Lý Đồ Ăn Kèm', desc: 'Thiết lập danh sách bắp, nước và các combo sản phẩm.' };
      case '/vouchers': return { title: 'Quản Lý Mã Khuyến Mãi', desc: 'Tạo, theo dõi và quản lý các chiến dịch mã giảm giá.' };
      case '/posts': return { title: 'Quản Lý Bài Viết & Bình Luận', desc: 'Kiểm duyệt bài đăng cộng đồng, nhượng vé và bình luận đánh giá phim.' };
      case '/settings': return { title: 'Cấu Hình Hệ Thống', desc: 'Quản lý các cài đặt chung và tham số của ứng dụng.' };

      case '/profile': return { title: 'Hồ Sơ Quản Trị', desc: 'Cập nhật thông tin cá nhân và bảo mật tài khoản.' };
      default: return { title: 'Bảng Điều Khiển Admin', desc: 'Hệ thống quản trị rạp chiếu phim' };
    }
  };

  const pageInfo = getPageInfo();

  return (
    // 🚀 CHUYỂN TOÀN BỘ CSS SANG TAILWIND KÈM HIỆU ỨNG GLASSMORPHISM
    <div className="sticky top-0 z-40 flex justify-between items-center px-8 py-4 bg-white/80 backdrop-blur-md border-b border-slate-200 shadow-sm shadow-slate-100/50 transition-all duration-300">
        
      {/* KHU VỰC TIÊU ĐỀ TRANG */}
      <div className="animate-[fade-in_0.3s_ease-out]">
        <h1 className="m-0 text-[22px] font-black text-slate-800 tracking-tight leading-tight">{pageInfo.title}</h1>
        <p className="m-0 mt-1 text-[13px] font-medium text-slate-500">{pageInfo.desc}</p>
      </div>

      {/* KHU VỰC ACTION (CHUÔNG & PROFILE) */}
      <div className="flex items-center gap-5">
        
        {/* Chuông thông báo (Có chấm đỏ "active") */}
        <div className="relative cursor-pointer p-2 rounded-full hover:bg-slate-100 transition-colors group">
          <Bell size={22} className="text-slate-400 group-hover:text-blue-600 transition-colors" />
          <span className="absolute top-1.5 right-2 w-2 h-2 bg-red-500 border-2 border-white rounded-full"></span>
        </div>
        
        {/* Nút thả xuống Profile */}
        <div className="relative" ref={dropdownRef}>
            <button 
                onClick={() => setIsProfileOpen(!isProfileOpen)}
                className={`flex items-center gap-3 bg-transparent border-none cursor-pointer p-1.5 pr-2 rounded-2xl transition-all duration-200 hover:bg-slate-100 outline-none ${isProfileOpen ? 'bg-slate-100 ring-2 ring-blue-100' : ''}`}
            >
                <div className="text-right hidden sm:block">
                    <p className="m-0 text-[13px] font-bold text-slate-800">{adminName}</p>
                    <p className="m-0 text-[11px] font-semibold text-blue-600">Quản trị viên</p>
                </div>
                
                {adminAvatar ? (
                  <div className="w-10 h-10 rounded-full overflow-hidden border border-slate-200 shadow-sm">
                    <img src={adminAvatar} alt="Avatar" className="w-full h-full object-cover" />
                  </div>
                ) : (
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-600 to-blue-800 flex items-center justify-center text-white font-bold text-lg shadow-sm shadow-blue-500/30">
                      {adminName.charAt(0).toUpperCase()}
                  </div>
                )}
                
                <ChevronDown size={16} className={`text-slate-400 transition-transform duration-300 ${isProfileOpen ? 'rotate-180 text-blue-600' : ''}`} />
            </button>

            {/* Menu thả xuống */}
            {isProfileOpen && (
                <div className="absolute top-[120%] right-0 w-56 bg-white rounded-2xl shadow-[0_10px_40px_-10px_rgba(0,0,0,0.15)] border border-slate-100 p-2 flex flex-col gap-1 origin-top-right animate-[slide-in-down_0.2s_ease-out]">
                    <Link 
                      to="/profile" 
                      onClick={() => setIsProfileOpen(false)} 
                      className="flex items-center gap-3 px-4 py-3 rounded-xl text-slate-600 text-sm font-bold transition-all duration-200 hover:bg-blue-50 hover:text-blue-700"
                    >
                        <User size={18} /> Thông tin cá nhân
                    </Link>
                    <Link 
                      to="/settings" 
                      onClick={() => setIsProfileOpen(false)} 
                      className="flex items-center gap-3 px-4 py-3 rounded-xl text-slate-600 text-sm font-bold transition-all duration-200 hover:bg-blue-50 hover:text-blue-700"
                    >
                        <Settings size={18} /> Cài đặt hệ thống
                    </Link>
                    
                    <div className="h-[1px] bg-slate-100 my-1 mx-2"></div>
                    
                    <button 
                      onClick={handleLogout} 
                      className="flex items-center gap-3 px-4 py-3 rounded-xl text-red-500 text-sm font-bold transition-all duration-200 hover:bg-red-50 hover:text-red-600 w-full text-left"
                    >
                        <LogOut size={18} /> Đăng xuất an toàn
                    </button>
                </div>
            )}
        </div>
      </div>

      {/* 🚀 ĐỊNH NGHĨA ANIMATION */}
      <style>{`
        @keyframes slide-in-down {
          from { opacity: 0; transform: translateY(-10px) scale(0.95); }
          to { opacity: 1; transform: translateY(0) scale(1); }
        }
        @keyframes fade-in {
          from { opacity: 0; }
          to { opacity: 1; }
        }
      `}</style>
    </div>
  );
};

export default Topbar;