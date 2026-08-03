import { useState } from 'react';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import Swal from 'sweetalert2';
import { Film, Lock, Mail, Eye, EyeOff, Loader2 } from 'lucide-react';

// 🚀 CẤU HÌNH TOAST CHO ĐĂNG NHẬP THÀNH CÔNG
const Toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 2000,
  timerProgressBar: true,
  didOpen: (toast) => {
    toast.addEventListener('mouseenter', Swal.stopTimer);
    toast.addEventListener('mouseleave', Swal.resumeTimer);
  }
});

const Login = () => {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  
  const navigate = useNavigate();

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    
    try {
      const response = await axios.post('http://192.168.1.7:3000/api/admin/login', { email, password });
      
      if (response.data.success) {
        localStorage.setItem('admin_user', JSON.stringify(response.data.user));
        Toast.fire({ icon: 'success', title: 'Đăng nhập thành công!' });
        
        // Trì hoãn nhẹ 1 giây để người dùng thấy thông báo thành công trước khi chuyển trang
        setTimeout(() => navigate('/'), 1000); 
      }
    } catch (err: any) {
      // 🚀 HIỂN THỊ LỖI BẰNG SWEETALERT2
      Swal.fire({
        icon: 'error',
        title: 'Đăng nhập thất bại',
        text: err.response?.data?.error || 'Tài khoản hoặc mật khẩu không chính xác.',
        confirmButtonColor: '#3b82f6',
        confirmButtonText: 'Thử lại'
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div 
      className="relative flex items-center justify-center min-h-screen w-full bg-slate-900 bg-cover bg-center bg-no-repeat overflow-hidden"
      style={{ backgroundImage: 'url(src/assets/background.png)' }}
    >
      {/* Lớp màng đen phủ lên ảnh nền để form đăng nhập nổi bật hơn */}
      <div className="absolute inset-0 bg-slate-900/40 backdrop-blur-[2px]"></div>
      
      {/* 🚀 BOX ĐĂNG NHẬP (DARK GLASSMORPHISM) */}
      <div className="relative z-10 w-full max-w-[420px] mx-4 p-8 sm:p-10 rounded-3xl bg-white/10 backdrop-blur-md border border-white/20 shadow-[0_25px_50px_-12px_rgba(0,0,0,0.5)] animate-[slide-in-bottom_0.6s_ease-out]">
        
        {/* Tiêu đề & Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center bg-blue-600 p-3.5 rounded-2xl mb-4 shadow-lg shadow-blue-500/30 animate-[pulse_3s_ease-in-out_infinite]">
            <Film className="text-white" size={32} />
          </div>
          <h1 className="m-0 text-2xl sm:text-3xl font-black text-white tracking-tight">CineManage</h1>
          <p className="mt-2 text-blue-100/80 text-sm font-medium">Hệ thống quản trị rạp chiếu phim</p>
        </div>

        <form onSubmit={handleLogin} className="flex flex-col gap-5">
          
          {/* Box Email */}
          <div>
            <label className="block text-[13px] font-bold text-blue-100/90 mb-2 tracking-wide uppercase">Email Quản trị</label>
            <div className="relative group">
              <Mail size={18} className="absolute left-4 top-1/2 transform -translate-y-1/2 text-white/50 group-focus-within:text-blue-400 transition-colors" />
              <input 
                type="email" 
                required 
                value={email} 
                onChange={e => setEmail(e.target.value)} 
                placeholder="admin@cinemanage.vn" 
                className="w-full pl-11 pr-4 py-3.5 rounded-xl bg-slate-900/40 border border-white/10 text-white placeholder-white/30 outline-none focus:border-blue-500 focus:bg-slate-900/60 focus:ring-4 focus:ring-blue-500/20 transition-all text-sm font-medium"
              />
            </div>
          </div>

          {/* Box Password */}
          <div>
            <label className="block text-[13px] font-bold text-blue-100/90 mb-2 tracking-wide uppercase">Mật khẩu</label>
            <div className="relative group">
              <Lock size={18} className="absolute left-4 top-1/2 transform -translate-y-1/2 text-white/50 group-focus-within:text-blue-400 transition-colors" />
              <input 
                type={showPassword ? "text" : "password"} 
                required 
                value={password} 
                onChange={e => setPassword(e.target.value)} 
                placeholder="••••••••" 
                style={{ letterSpacing: showPassword ? 'normal' : '3px' }}
                className="w-full pl-11 pr-12 py-3.5 rounded-xl bg-slate-900/40 border border-white/10 text-white placeholder-white/30 outline-none focus:border-blue-500 focus:bg-slate-900/60 focus:ring-4 focus:ring-blue-500/20 transition-all text-sm font-medium" 
              />
              <button 
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-white/40 hover:text-white transition-colors p-1"
              >
                {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          {/* Nút Đăng Nhập */}
          <button 
            type="submit" 
            disabled={isLoading}
            className="w-full mt-4 bg-blue-600 hover:bg-blue-500 text-white py-3.5 rounded-xl font-bold text-[15px] transition-all shadow-lg shadow-blue-600/30 hover:shadow-blue-500/40 hover:-translate-y-0.5 active:translate-y-0 active:scale-[0.98] flex items-center justify-center gap-2 disabled:opacity-70 disabled:cursor-not-allowed"
          >
            {isLoading ? (
              <>
                <Loader2 size={20} className="animate-spin" /> 
                Đang kết nối...
              </>
            ) : (
              'Đăng Nhập Hệ Thống'
            )}
          </button>
        </form>

      </div>

      {/* 🚀 ĐỊNH NGHĨA ANIMATION CHO TRANG ĐĂNG NHẬP */}
      <style>{`
        @keyframes slide-in-bottom { 
          from { opacity: 0; transform: translateY(30px) scale(0.95); } 
          to { opacity: 1; transform: translateY(0) scale(1); } 
        }
      `}</style>
    </div>
  );
};

export default Login;