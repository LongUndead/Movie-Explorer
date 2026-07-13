import { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { 
  Film, LayoutDashboard, Ticket, Users, FileText, 
  Settings, HelpCircle, Menu, MonitorPlay,
  ShoppingCart, Popcorn, Tag, MessageSquare 
} from 'lucide-react';

const Sidebar = () => {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const location = useLocation();
  const isActive = (path: string) => location.pathname === path;

  const sidebarWidth = isCollapsed ? '84px' : '260px';

  // 🚀 TỐI ƯU CLASS: THÊM HIỆU ỨNG GROUP-HOVER VÀ BÓNG ĐỔ MỊN HƠN
  const getLinkClass = (path: string) => {
    const active = isActive(path);
    return `group flex items-center gap-3 transition-all duration-300 font-bold text-[13px] whitespace-nowrap overflow-hidden
      ${isCollapsed ? 'justify-center p-3.5 rounded-2xl' : 'justify-start px-4 py-3.5 rounded-2xl'}
      ${active 
        ? 'bg-blue-600 text-white shadow-lg shadow-blue-600/30 transform scale-[1.02]' 
        : 'text-slate-500 hover:bg-slate-100 hover:text-blue-600'
      } mb-1.5`;
  };

  // Hàm helper để render Icon mượt mà
  const renderIcon = (IconComponent: any, path: string) => {
    return (
      <IconComponent 
        size={20} 
        className={`min-w-[20px] transition-transform duration-300 ${!isActive(path) && 'group-hover:scale-110'}`} 
      />
    );
  };

  return (
    <div 
      className="h-screen sticky top-0 flex flex-col bg-white border-r border-slate-200 transition-all duration-300 ease-in-out z-50 shadow-[4px_0_24px_rgba(0,0,0,0.02)]"
      style={{ width: sidebarWidth, padding: isCollapsed ? '24px 12px' : '24px 20px' }}
    >
      
      {/* 🚀 KHU VỰC 1: LOGO VÀ NÚT MENU */}
      <div className={`flex items-center ${isCollapsed ? 'justify-center' : 'justify-between'} mb-8`}>
        {!isCollapsed && (
          <h2 className="text-slate-800 flex items-center gap-3 text-xl font-black m-0 tracking-tight animate-[fade-in_0.3s_ease-out]">
            <div className="bg-blue-600 p-2.5 rounded-xl flex shadow-lg shadow-blue-600/30">
              <Film color="#fff" size={20} />
            </div>
            CineManage
          </h2>
        )}
        <button 
          onClick={() => setIsCollapsed(!isCollapsed)}
          className="p-2.5 rounded-xl text-slate-400 hover:bg-slate-100 hover:text-blue-600 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-100"
          title={isCollapsed ? "Mở rộng thanh bên" : "Thu gọn thanh bên"}
        >
          <Menu size={22} className={`transition-transform duration-300 ${isCollapsed ? 'rotate-180' : ''}`} />
        </button>
      </div>
      
      {/* 🚀 KHU VỰC 2: DANH SÁCH MENU CHÍNH (Ẩn thanh cuộn) */}
      <div 
        className="flex-1 flex flex-col gap-0.5 overflow-y-auto"
        style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }} // Ẩn thanh cuộn cho Firefox/IE
      >
        {/* Ẩn thanh cuộn cho Webkit (Chrome, Safari) */}
        <style>{`
          div::-webkit-scrollbar { display: none; }
        `}</style>

        <Link to="/" className={getLinkClass('/')} title={isCollapsed ? "Dashboard" : ""}>
          {renderIcon(LayoutDashboard, '/')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Tổng quan</span>}
        </Link>
        
        <Link to="/showtimes" className={getLinkClass('/showtimes')} title={isCollapsed ? "Quản lý suất chiếu" : ""}>
          {renderIcon(Ticket, '/showtimes')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Suất chiếu</span>}
        </Link>

        <Link to="/rooms" className={getLinkClass('/rooms')} title={isCollapsed ? "Phim và Rạp" : ""}>
          {renderIcon(MonitorPlay, '/rooms')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Phim và Rạp</span>}
        </Link>
        
        <Link to="/customers" className={getLinkClass('/customers')} title={isCollapsed ? "Khách hàng" : ""}>
          {renderIcon(Users, '/customers')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Khách hàng</span>}
        </Link>

        <Link to="/orders" className={getLinkClass('/orders')} title={isCollapsed ? "Quản lý đơn hàng" : ""}>
          {renderIcon(ShoppingCart, '/orders')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Quản lý đơn hàng</span>}
        </Link>

        <Link to="/foods" className={getLinkClass('/foods')} title={isCollapsed ? "Quản lý F&B" : ""}>
          {renderIcon(Popcorn, '/foods')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Quản lý đồ ăn kèm</span>}
        </Link>

        <Link to="/vouchers" className={getLinkClass('/vouchers')} title={isCollapsed ? "Mã khuyến mãi" : ""}>
          {renderIcon(Tag, '/vouchers')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Mã khuyến mãi</span>}
        </Link>

        <Link to="/posts" className={getLinkClass('/posts')} title={isCollapsed ? "Bài viết & Bình luận" : ""}>
          {renderIcon(MessageSquare, '/posts')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Quản lý bài viết/bình luận</span>}
        </Link>
        
        <Link to="/reports" className={getLinkClass('/reports')} title={isCollapsed ? "Báo cáo thống kê" : ""}>
          {renderIcon(FileText, '/reports')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Báo cáo</span>}
        </Link>
      </div>

      {/* 🚀 KHU VỰC 3: CÀI ĐẶT & HỖ TRỢ */}
      <div className="pt-4 border-t border-slate-100 mt-2">
        <Link to="/settings" className={getLinkClass('/settings')} title={isCollapsed ? "Cấu hình hệ thống" : ""}>
          {renderIcon(Settings, '/settings')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Cấu hình hệ thống</span>}
        </Link>
        
        <Link to="/support" className={getLinkClass('/support')} title={isCollapsed ? "Hỗ trợ" : ""}>
          {renderIcon(HelpCircle, '/support')}
          {!isCollapsed && <span className="animate-[fade-in_0.2s_ease-out]">Hỗ trợ</span>}
        </Link>
      </div>
      
    </div>
  );
};

export default Sidebar;