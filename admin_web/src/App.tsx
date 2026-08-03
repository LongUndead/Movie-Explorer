import { BrowserRouter as Router, Routes, Route, Navigate, Outlet } from 'react-router-dom';
import Sidebar from './components/Sidebar';
import Topbar from './components/Topbar'; 
import ScrollToTop from './components/ScrollToTop'
import Dashboard from './pages/Dashboard';
import Login from './pages/Login';
import Customers from './pages/Customers';
import Profile from './pages/Profile';
import Showtimes from './pages/Showtimes';
import Rooms from './pages/Rooms';

import Orders from './pages/Orders';
import Foods from './pages/Foods';
import Vouchers from './pages/Vouchers';
import Posts from './pages/Posts';
import Settings from './pages/Settings';
import Support from './pages/Support';

// 🚀 IMPORT TRANG BÁO CÁO DOANH THU MỚI TẠO
import RevenueReport from './pages/RevenueReport';

// =========================================================================
// 1. BỨC TƯỜNG LỬA BẢO VỆ (Sử dụng Outlet để chuyển hướng an toàn)
// =========================================================================
const ProtectedRoute = () => {
  const adminData = localStorage.getItem('admin_user');
  if (!adminData) {
    return <Navigate to="/login" replace />;
  }
  // Nếu đã đăng nhập, cho phép đi tiếp vào các Route con bên trong
  return <Outlet />; 
};

// =========================================================================
// 2. LAYOUT QUẢN TRỊ VIÊN (Sidebar Trái - Topbar & Content Phải)
// =========================================================================
const AdminLayout = () => {
  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden', backgroundColor: '#f1f5f9' }}>
      <Sidebar />
      
      {/* Khu vực bên phải */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        <Topbar />
        
        {/* CHỖ SỬA 2: THÊM id="main-content" VÀO THẺ NÀY */}
        <div id="main-content" style={{ flex: 1, overflowY: 'auto' }}>
          <Outlet /> 
        </div>
      </div>
    </div>
  );
};

// =========================================================================
// 3. ĐIỀU HƯỚNG CHÍNH (APP ROUTER)
// =========================================================================
function App() {
  return (
    <Router>
      <Routes>
        {/* Route không cần bảo vệ */}
        <Route path="/login" element={<Login />} />

        {/* Các Route cần bảo vệ: Phải đi qua ProtectedRoute -> AdminLayout */}
        <Route element={<ProtectedRoute />}>
          <Route element={<AdminLayout />}>
            <Route path="/" element={<Dashboard />} />
            <Route path="/customers" element={<Customers />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/showtimes" element={<Showtimes/>} />
            <Route path="/rooms" element={<Rooms />} />
            
            {/* ✅ 4 KHU VỰC ROUTE MỚI */}
            <Route path="/orders" element={<Orders />} />
            <Route path="/foods" element={<Foods />} />
            <Route path="/vouchers" element={<Vouchers />} />
            <Route path="/posts" element={<Posts />} />
            <Route path="/settings" element={<Settings />} />

            {/* 🚀 ĐÃ NỐI TRANG BÁO CÁO VÀO URL "/reports" */}
            <Route path="/reports" element={<RevenueReport />} />
            <Route path="/support" element={<Support />} />
          </Route>
        </Route>
      </Routes>
      <ScrollToTop />
    </Router>
  );
}

export default App;