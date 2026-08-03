import React, { useState, useEffect } from 'react';
import axios from 'axios';
import Swal from 'sweetalert2';
import { Search, Shield, User, Trash2, Mail, Phone, Calendar, Lock, Unlock, AlertTriangle, Gavel, CheckCircle, UserPlus, X, Eye, EyeOff } from 'lucide-react';

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

const Customers = () => {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [currentAdminId, setCurrentAdminId] = useState<number | null>(null);
  
  const [searchQuery, setSearchQuery] = useState('');
  const [activeTab, setActiveTab] = useState<'ALL' | 'ADMIN' | 'USER' | 'BLACKLISTED'>('ALL');

  const [isModalOpen, setIsModalOpen] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [formData, setFormData] = useState({ username: '', email: '', phone: '', password: '' });

  useEffect(() => {
    const adminData = localStorage.getItem('admin_user');
    if (adminData) {
      const admin = JSON.parse(adminData);
      setCurrentAdminId(admin.UserID);
    }
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await axios.get('http://192.168.1.7:3000/api/admin/users');
      setUsers(response.data);
    } catch (error) { 
      Toast.fire({ icon: 'error', title: 'Lỗi tải dữ liệu người dùng' });
    } finally { 
      setLoading(false); 
    }
  };

  const filteredUsers = users.filter(user => {
    const keyword = searchQuery.toLowerCase();
    const matchesSearch = 
      (user.Username || '').toLowerCase().includes(keyword) || 
      (user.Email || '').toLowerCase().includes(keyword) || 
      (user.Phone || '').toLowerCase().includes(keyword);
    
    let matchesTab = true;
    if (activeTab === 'ADMIN') matchesTab = (user.RoleName?.toLowerCase() === 'admin');
    if (activeTab === 'USER') matchesTab = (user.RoleName?.toLowerCase() !== 'admin');
    if (activeTab === 'BLACKLISTED') matchesTab = (user.IsLocked === 1);

    return matchesSearch && matchesTab;
  });

  // 🚀 HÀM MỚI: XỬ LÝ LINK AVATAR AN TOÀN
  const getSafeAvatarUrl = (avatarPath: string | null | undefined) => {
    if (!avatarPath || String(avatarPath).trim() === '' || String(avatarPath) === 'null') return null;
    const path = String(avatarPath);
    if (path.startsWith('http')) return path;
    return `http://192.168.1.7:3000${path.startsWith('/') ? '' : '/'}${path}`;
  };

  const handleChangeRole = async (userId: number, roleId: number, name: string) => {
    const roleName = roleId === 1 ? 'Admin (Quản trị)' : 'User (Khách hàng)';
    
    Swal.fire({
      title: 'Xác nhận phân quyền',
      html: `Chuyển <b>${name}</b> thành <b>${roleName}</b>?`,
      icon: 'question',
      showCancelButton: true,
      confirmButtonColor: '#10b981',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Xác nhận',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          await axios.put(`http://192.168.1.7:3000/api/admin/users/${userId}/change-role`, { roleId });
          Toast.fire({ icon: 'success', title: 'Cập nhật quyền thành công!' });
          fetchUsers();
        } catch (error) {
          Swal.fire('Thất bại!', 'Có lỗi xảy ra khi phân quyền.', 'error');
        }
      }
    });
  };

  const handleCreateAdmin = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const res = await axios.post('http://192.168.1.7:3000/api/admin/users/admin', formData);
      Swal.fire({
        title: 'Thành công!',
        text: res.data.message,
        icon: 'success',
        confirmButtonColor: '#10b981'
      });
      setIsModalOpen(false);
      setFormData({ username: '', email: '', phone: '', password: '' });
      fetchUsers();
    } catch (error: any) {
      Swal.fire('Lỗi tạo tài khoản', error.response?.data?.error || "Không thể tạo Admin mới", 'error');
    }
  };

  const handleApplyBlacklist = async (id: number, name: string) => {
    Swal.fire({
      title: 'Đưa vào danh sách đen?',
      text: `Khóa tài khoản "${name}" do vi phạm chính sách?`,
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#f59e0b',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Khóa tài khoản',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          const res = await axios.put(`http://192.168.1.7:3000/api/admin/users/${id}/apply-blacklist`);
          Toast.fire({ icon: 'success', title: res.data.message });
          fetchUsers(); 
        } catch (error: any) { 
          Toast.fire({ icon: 'error', title: error.response?.data?.error || 'Lỗi hệ thống' });
        }
      }
    });
  };

  const handleUnlock = async (id: number, name: string) => {
    Swal.fire({
      title: 'Mở khóa trước thời hạn?',
      text: `Bạn muốn khôi phục hoạt động cho "${name}"?`,
      icon: 'info',
      showCancelButton: true,
      confirmButtonColor: '#3b82f6',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Mở khóa',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          await axios.put(`http://192.168.1.7:3000/api/admin/users/${id}/unlock`);
          Toast.fire({ icon: 'success', title: `Đã khôi phục tài khoản ${name}!` });
          fetchUsers();
        } catch (error) { 
          Toast.fire({ icon: 'error', title: 'Lỗi mở khóa' });
        }
      }
    });
  };

  const handleDelete = async (id: number, name: string) => {
    Swal.fire({
      title: 'Hành động nguy hiểm!',
      html: `Bạn đang chuẩn bị <b>XÓA VĨNH VIỄN</b> tài khoản <b>${name}</b>.<br/>Dữ liệu không thể khôi phục!`,
      icon: 'error',
      showCancelButton: true,
      confirmButtonColor: '#ef4444',
      cancelButtonColor: '#cbd5e1',
      confirmButtonText: 'Vẫn Xóa',
      cancelButtonText: 'Hủy'
    }).then(async (result) => {
      if (result.isConfirmed) {
        try {
          await axios.delete(`http://192.168.1.7:3000/api/admin/users/${id}`);
          Swal.fire('Đã xóa!', 'Tài khoản đã bị loại bỏ khỏi hệ thống.', 'success');
          fetchUsers();
        } catch (error: any) { 
          Swal.fire('Lỗi', error.response?.data?.error || 'Không thể xóa', 'error');
        }
      }
    });
  };

  return (
    <div className="p-6 bg-slate-50 min-h-[calc(100vh-70px)] animate-[fade-in_0.3s_ease-out]">
      
      <div className="flex flex-col xl:flex-row gap-4 mb-6 justify-between items-start xl:items-center bg-white p-4 rounded-2xl shadow-sm border border-slate-200 hover:shadow-md transition-shadow duration-300">
        <div className="flex bg-slate-100 p-1.5 rounded-xl w-full xl:w-auto overflow-x-auto no-scrollbar">
          {[
            { id: 'ALL', label: 'Tất cả' },
            { id: 'USER', label: 'Khách hàng' },
            { id: 'ADMIN', label: 'Quản trị viên' },
            { id: 'BLACKLISTED', label: 'Danh sách đen', alert: users.filter(u => u.IsLocked === 1).length }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`px-4 py-2 rounded-lg font-bold text-sm whitespace-nowrap transition-all duration-300 flex items-center gap-2 ${
                activeTab === tab.id 
                  ? (tab.id === 'BLACKLISTED' ? 'bg-red-600 text-white shadow-md transform scale-105' : 'bg-white text-blue-700 shadow-sm transform scale-105') 
                  : 'text-slate-500 hover:text-slate-800 hover:bg-slate-200'
              }`}
            >
              {tab.id === 'BLACKLISTED' && <Shield size={14} className={activeTab === tab.id ? "text-white" : "text-slate-400"} />}
              {tab.label}
              {tab.alert ? <span className={`text-[10px] px-2 py-0.5 rounded-full shadow-sm transition-colors ${activeTab === tab.id ? 'bg-white text-red-600' : 'bg-red-500 text-white'}`}>{tab.alert}</span> : null}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap sm:flex-nowrap gap-3 w-full xl:w-auto">
          <div className="relative flex-1 sm:w-64 group">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-slate-400 group-focus-within:text-blue-500 transition-colors" size={16} />
            <input 
              type="text" 
              placeholder="Tìm tên, email, SĐT..." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-4 py-2.5 bg-slate-50 border border-slate-200 rounded-xl outline-none focus:border-blue-500 focus:bg-white focus:ring-4 focus:ring-blue-50 transition-all text-sm font-medium"
            />
          </div>
          
          <button 
            onClick={() => setIsModalOpen(true)} 
            className="bg-emerald-500 hover:bg-emerald-600 text-white px-5 py-2.5 rounded-xl font-bold text-sm flex items-center gap-2 transition-all duration-300 hover:shadow-lg hover:shadow-emerald-200 hover:-translate-y-0.5 active:translate-y-0 whitespace-nowrap"
          >
            <UserPlus size={18} /> Thêm Admin
          </button>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse min-w-[900px]">
            <thead className="bg-slate-800 text-white">
              <tr>
                <th className="p-4 text-xs font-bold uppercase tracking-wider">Khách Hàng</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider">Liên Hệ</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider text-center">Độ Uy Tín</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider">Quyền Hạn</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider">Ngày Tham Gia</th>
                <th className="p-4 text-xs font-bold uppercase tracking-wider text-center">Hành Động</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {loading ? (
                <tr><td colSpan={6} className="p-10 text-center text-slate-500 font-medium">Đang tải dữ liệu...</td></tr>
              ) : filteredUsers.length === 0 ? (
                <tr>
                   <td colSpan={6} className="p-10 text-center animate-[fade-in_0.5s_ease-out]">
                      <div className="flex flex-col items-center justify-center text-slate-400">
                         <Search size={40} className="mb-3 opacity-20" />
                         <span className="font-medium text-sm">Không tìm thấy tài khoản nào.</span>
                      </div>
                   </td>
                </tr>
              ) : (
                filteredUsers.map((user, index) => {
                  const isAdmin = user.RoleName?.toLowerCase() === 'admin';
                  const isLocked = user.IsLocked === 1;
                  const isMe = user.UserID === currentAdminId; 
                  const refundCount = user.RefundCount || 0;
                  
                  // Kiểm tra avatar an toàn
                  const avatarUrl = getSafeAvatarUrl(user.Avatar || user.avatar);
                  
                  let unlockText = "Vĩnh viễn";
                  if (user.UnlockTime) {
                    const uDate = new Date(user.UnlockTime);
                    unlockText = `Đến ${uDate.getDate()}/${uDate.getMonth() + 1} lúc ${uDate.getHours()}:${uDate.getMinutes().toString().padStart(2, '0')}`;
                  }

                  return (
                    <tr 
                      key={user.UserID} 
                      style={{ animationDelay: `${index * 50}ms` }}
                      className={`hover:bg-slate-50/80 transition-all duration-200 animate-[slide-in-top_0.4s_ease-out_backwards] ${isLocked ? 'bg-red-50/40' : ''}`}
                    >
                      <td className="p-4 align-top">
                        <div className="flex items-center gap-3">
                          
                          {/* 🚀 ĐÃ SỬA: BẮT LINK AVATAR VÀ FALLBACK LẠI CHỮ CÁI ĐẦU NẾU LỖI */}
                          {avatarUrl ? (
                            <img 
                              src={avatarUrl} 
                              alt={user.Username} 
                              className="w-10 h-10 rounded-full object-cover shadow-sm border border-slate-200 transition-transform duration-300 hover:scale-110"
                              onError={(e) => {
                                // Nếu ảnh lỗi (link chết), tự động thay bằng avatar tạo từ chữ cái đầu của UI-Avatars
                                e.currentTarget.src = `https://ui-avatars.com/api/?name=${encodeURIComponent(user.Username || 'U')}&background=random&color=fff`;
                              }}
                            />
                          ) : (
                            <div className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm shadow-sm transition-transform duration-300 hover:scale-110 ${isAdmin ? 'bg-gradient-to-br from-blue-100 to-blue-200 text-blue-700' : isLocked ? 'bg-gradient-to-br from-red-100 to-red-200 text-red-600' : 'bg-gradient-to-br from-slate-100 to-slate-200 text-slate-600'}`}>
                              {(user.Username || 'U').charAt(0).toUpperCase()}
                            </div>
                          )}

                          <div>
                            <h4 className="m-0 text-sm font-bold text-slate-800">
                              {user.Username} {isMe && <span className="text-[11px] text-emerald-500 font-medium ml-1 bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-100">(Bạn)</span>}
                            </h4>
                            <span className="text-xs text-slate-400 font-mono mt-0.5 block">ID: #{user.UserID}</span>
                          </div>
                        </div>
                      </td>

                      <td className="p-4 align-top">
                        <div className="flex items-center gap-2 mb-1.5 text-[13px] text-slate-600"><Mail size={14} className="text-slate-400" />{user.Email}</div>
                        <div className="flex items-center gap-2 text-[13px] text-slate-600"><Phone size={14} className="text-slate-400" />{user.Phone || 'Chưa cập nhật'}</div>
                      </td>

                      <td className="p-4 align-top text-center">
                        {refundCount === 0 ? (
                           <span className="text-emerald-600 font-bold text-xs bg-emerald-50 px-2.5 py-1 rounded-full border border-emerald-100 inline-flex items-center gap-1.5 shadow-sm"><CheckCircle size={12}/> Uy tín</span>
                        ) : (
                           <span className={`font-bold text-xs px-2.5 py-1 rounded-full border inline-flex items-center gap-1.5 shadow-sm ${refundCount >= 3 ? 'bg-red-50 text-red-600 border-red-100' : 'bg-amber-50 text-amber-600 border-amber-100'}`}>
                             <AlertTriangle size={12}/> Hoàn {refundCount} vé
                           </span>
                        )}
                      </td>

                      <td className="p-4 align-top">
                        {isLocked ? (
                          <span className="text-red-600 bg-red-50 border border-red-100 px-2 py-1 rounded text-xs font-bold inline-flex items-center gap-1 shadow-sm">
                            <Lock size={12} /> BỊ KHÓA ({unlockText})
                          </span>
                        ) : isMe ? (
                          <span className="bg-blue-50 border border-blue-100 text-blue-600 px-3 py-1.5 rounded-lg text-xs font-bold inline-flex items-center gap-1.5 shadow-sm">
                            <Shield size={14} /> Quản trị tối cao
                          </span>
                        ) : (
                          <select
                            value={isAdmin ? "1" : "2"}
                            onChange={(e) => handleChangeRole(user.UserID, Number(e.target.value), user.Username)}
                            className={`px-3 py-1.5 rounded-lg border text-xs font-bold cursor-pointer outline-none transition-all duration-300 hover:shadow-sm ${isAdmin ? 'bg-blue-50 border-blue-200 text-blue-700 focus:ring-2 focus:ring-blue-100' : 'bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100 focus:ring-2 focus:ring-slate-100'}`}
                          >
                            <option value="1">Admin (Quản trị)</option>
                            <option value="2">User (Khách hàng)</option>
                          </select>
                        )}
                      </td>

                      <td className="p-4 align-top text-slate-600 text-[13px] font-medium">
                        <div className="flex items-center gap-1.5">
                          <Calendar size={14} className="text-slate-400" />
                          {user.CreatedAt ? new Date(user.CreatedAt).toLocaleDateString('vi-VN') : 'Trống'}
                        </div>
                      </td>

                      <td className="p-4 align-top text-center">
                        {isLocked ? (
                          <button onClick={() => handleUnlock(user.UserID, user.Username)} className="p-1.5 text-emerald-500 hover:bg-emerald-100 hover:scale-110 rounded transition-all" title="Mở khóa trước thời hạn"><Unlock size={18} /></button>
                        ) : (
                          <button onClick={() => handleApplyBlacklist(user.UserID, user.Username)} disabled={isAdmin} className={`p-1.5 rounded transition-all mr-2 ${isAdmin ? 'text-slate-300 cursor-not-allowed' : 'text-amber-500 hover:bg-amber-100 hover:scale-110'}`} title="Đưa vào Blacklist"><Gavel size={18} /></button>
                        )}

                        <button onClick={() => handleDelete(user.UserID, user.Username)} disabled={isAdmin || isMe} className={`p-1.5 rounded transition-all ${isAdmin || isMe ? 'text-slate-300 cursor-not-allowed' : 'text-red-500 hover:bg-red-100 hover:scale-110'}`} title="Xóa tài khoản"><Trash2 size={18} /></button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {isModalOpen && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm flex items-center justify-center z-[2000] p-4 animate-[fade-in_0.2s_ease-out]">
          <div className="bg-white p-8 rounded-2xl w-[450px] max-w-full shadow-2xl animate-[slide-in-bottom_0.3s_ease-out]">
            
            <div className="flex justify-between items-center mb-6 border-b border-slate-100 pb-4">
              <h2 className="m-0 text-xl text-slate-800 font-bold flex items-center gap-2"><Shield className="text-emerald-500" /> Tạo Admin Mới</h2>
              <button onClick={() => setIsModalOpen(false)} className="text-slate-400 hover:text-red-500 hover:rotate-90 transition-all duration-300"><X size={24} /></button>
            </div>

            <form onSubmit={handleCreateAdmin} className="flex flex-col gap-4">
              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-emerald-600 transition-colors">Họ và tên</label>
                <input required type="text" value={formData.username} onChange={(e) => setFormData({...formData, username: e.target.value})} placeholder="Ví dụ: Nguyễn Văn A" className="w-full px-4 py-2.5 rounded-xl border border-slate-200 outline-none focus:border-emerald-500 focus:bg-white bg-slate-50 hover:bg-white focus:ring-4 focus:ring-emerald-50 transition-all text-sm" />
              </div>

              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-emerald-600 transition-colors">Email Quản trị</label>
                <input required type="email" value={formData.email} onChange={(e) => setFormData({...formData, email: e.target.value})} placeholder="admin_vna@gmail.com" className="w-full px-4 py-2.5 rounded-xl border border-slate-200 outline-none focus:border-emerald-500 focus:bg-white bg-slate-50 hover:bg-white focus:ring-4 focus:ring-emerald-50 transition-all text-sm" />
              </div>

              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-emerald-600 transition-colors">Số điện thoại</label>
                <input required type="text" value={formData.phone} onChange={(e) => setFormData({...formData, phone: e.target.value})} placeholder="0901234567" className="w-full px-4 py-2.5 rounded-xl border border-slate-200 outline-none focus:border-emerald-500 focus:bg-white bg-slate-50 hover:bg-white focus:ring-4 focus:ring-emerald-50 transition-all text-sm" />
              </div>

              <div className="group">
                <label className="block text-[13px] font-bold text-slate-700 mb-1.5 group-focus-within:text-emerald-600 transition-colors">Mật khẩu khởi tạo</label>
                <div className="relative">
                  <input required type={showPassword ? "text" : "password"} value={formData.password} onChange={(e) => setFormData({...formData, password: e.target.value})} placeholder="••••••••" className="w-full pl-4 pr-10 py-2.5 rounded-xl border border-slate-200 outline-none focus:border-emerald-500 focus:bg-white bg-slate-50 hover:bg-white focus:ring-4 focus:ring-emerald-50 transition-all text-sm" />
                  <button type="button" onClick={() => setShowPassword(!showPassword)} className="absolute right-3 top-1/2 transform -translate-y-1/2 text-slate-400 hover:text-slate-600 transition-colors">
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
              </div>

              <div className="flex justify-end gap-3 mt-4 pt-4 border-t border-slate-100">
                <button type="button" onClick={() => setIsModalOpen(false)} className="px-5 py-2.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 font-bold text-slate-600 text-sm transition-all hover:scale-105 active:scale-95">Hủy</button>
                <button type="submit" className="px-6 py-2.5 rounded-xl bg-emerald-500 hover:bg-emerald-600 text-white font-bold text-sm shadow-sm transition-all hover:shadow-emerald-200 hover:shadow-lg hover:-translate-y-0.5 active:translate-y-0 active:scale-95">Xác Nhận Tạo</button>
              </div>
            </form>

          </div>
        </div>
      )}

      <style>{`
        @keyframes fade-in { from { opacity: 0; } to { opacity: 1; } }
        @keyframes slide-in-top { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes slide-in-bottom { from { opacity: 0; transform: translateY(-20px) scale(0.95); } to { opacity: 1; transform: translateY(0) scale(1); } }
      `}</style>
    </div>
  );
};

export default Customers;