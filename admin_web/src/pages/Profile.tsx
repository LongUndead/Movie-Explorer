import { useState, useEffect, useRef } from 'react';
import axios from 'axios';
import { Camera, Save, Shield, User, Edit, X, KeyRound } from 'lucide-react';

const Profile = () => {
  const [adminId, setAdminId] = useState<number | null>(null);
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    phone: '',
    avatar: ''
  });
  
  const [passwordData, setPasswordData] = useState({ oldPassword: '', newPassword: '', confirmPassword: '' });

  const [isEditingProfile, setIsEditingProfile] = useState(false);
  const [isChangingPassword, setIsChangingPassword] = useState(false);
  
  // Tham chiếu đến ô input chọn file ẩn
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Lấy dữ liệu khi mới vào trang
  const loadUserData = () => {
    const userStr = localStorage.getItem('admin_user');
    if (userStr) {
      const user = JSON.parse(userStr);
      setAdminId(user.UserID);
      setFormData({
        username: user.Username || '',
        email: user.Email || '',
        phone: user.Phone || '',
        avatar: user.Avatar || ''
      });
    }
  };

  useEffect(() => { loadUserData(); }, []);

  // HÀM 1: CẬP NHẬT THÔNG TIN TEXT
  const handleUpdateProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!adminId) return;
    try {
      await axios.put(`http://192.168.1.7:3000/api/admin/profile/${adminId}`, {
        username: formData.username,
        phone: formData.phone
      });
      
      // Cập nhật lại LocalStorage để Topbar cũng đổi tên theo
      const userStr = localStorage.getItem('admin_user');
      if (userStr) {
        const user = JSON.parse(userStr);
        user.Username = formData.username;
        user.Phone = formData.phone;
        localStorage.setItem('admin_user', JSON.stringify(user));
      }
      
      alert('Cập nhật thông tin thành công!');
      setIsEditingProfile(false);
      window.location.reload(); // F5 nhẹ trang để Topbar cập nhật Tên mới
    } catch (error) {
      alert('Lỗi cập nhật thông tin!');
    }
  };

  // HÀM 2: UPLOAD ẢNH AVATAR
  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !adminId) return;

    // Đóng gói file thành dạng FormData để gửi đi
    const data = new FormData();
    data.append('avatar', file);

    try {
      const res = await axios.post(`http://192.168.1.7:3000/api/admin/profile/${adminId}/avatar`, data, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      
      // Cập nhật giao diện & LocalStorage ngay lập tức
      setFormData({ ...formData, avatar: res.data.avatarUrl });
      
      const userStr = localStorage.getItem('admin_user');
      if (userStr) {
        const user = JSON.parse(userStr);
        user.Avatar = res.data.avatarUrl;
        localStorage.setItem('admin_user', JSON.stringify(user));
      }
      
      alert('Đã thay đổi ảnh đại diện!');
      window.location.reload(); // F5 để Topbar ăn ảnh mới
    } catch (error) {
      alert('Lỗi khi tải ảnh lên!');
    }
  };

  const handleCancelEdit = () => {
    loadUserData();
    setIsEditingProfile(false);
  };

  return (
    <div style={{ padding: '24px', backgroundColor: '#f8fafc', minHeight: '100vh' }}>
      
      {/* KHAI BÁO INPUT FILE ẨN ĐỂ CHỌN ẢNH */}
      <input 
        type="file" 
        accept="image/*" 
        ref={fileInputRef} 
        onChange={handleFileChange} 
        style={{ display: 'none' }} 
      />

      <div style={{ marginBottom: '24px' }}>
        <h1 style={{ margin: '0 0 8px 0', fontSize: '24px', color: '#0f172a' }}>Hồ Sơ Quản Trị Viên</h1>
        <p style={{ margin: 0, color: '#64748b', fontSize: '14px' }}>Quản lý thông tin cá nhân và cài đặt bảo mật tài khoản.</p>
      </div>

      <div style={{ display: 'flex', gap: '24px', alignItems: 'flex-start' }}>
        
        {/* CỘT TRÁI: AVATAR & THÔNG TIN TÓM TẮT */}
        <div style={{ width: '300px', backgroundColor: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)', textAlign: 'center' }}>
          
          <div style={{ position: 'relative', width: '120px', height: '120px', margin: '0 auto 16px auto' }}>
            {formData.avatar ? (
              <img src={formData.avatar} alt="Avatar" style={{ width: '100%', height: '100%', borderRadius: '50%', objectFit: 'cover', border: '4px solid #f1f5f9' }} />
            ) : (
              <div style={{ width: '100%', height: '100%', borderRadius: '50%', backgroundColor: '#2563eb', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: '40px', fontWeight: 'bold', border: '4px solid #eff6ff' }}>
                {(formData.username || 'A').charAt(0).toUpperCase()}
              </div>
            )}
            
            <button 
              onClick={() => fileInputRef.current?.click()} // KÍCH HOẠT INPUT FILE KHI BẤM NÚT NÀY
              style={{ position: 'absolute', bottom: 0, right: '0px', backgroundColor: '#0f172a', color: '#fff', border: 'none', borderRadius: '50%', width: '36px', height: '36px', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', boxShadow: '0 2px 5px rgba(0,0,0,0.2)' }}
              title="Đổi ảnh đại diện"
            >
              <Camera size={16} />
            </button>
          </div>

          <h2 style={{ margin: '0 0 4px 0', fontSize: '18px', color: '#0f172a' }}>{formData.username}</h2>
          <p style={{ margin: '0 0 16px 0', fontSize: '13px', color: '#64748b', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px' }}>
            <Shield size={14} color="#2563eb" /> Quản trị viên tối cao
          </p>

          <div style={{ borderTop: '1px solid #e2e8f0', paddingTop: '16px' }}>
            <p style={{ margin: '0 0 8px 0', fontSize: '13px', color: '#475569', display: 'flex', justifyContent: 'space-between' }}><span>Đăng nhập cuối:</span> <strong>Vừa xong</strong></p>
            <p style={{ margin: 0, fontSize: '13px', color: '#475569', display: 'flex', justifyContent: 'space-between' }}><span>Trạng thái:</span> <strong style={{ color: '#10b981' }}>Hoạt động</strong></p>
          </div>
        </div>

        {/* CỘT PHẢI: CHI TIẾT & ĐỔI MẬT KHẨU */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          <div style={{ backgroundColor: '#fff', borderRadius: '12px', padding: '24px', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
            
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
              <h3 style={{ margin: 0, fontSize: '16px', color: '#0f172a', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <User size={18} color="#3b82f6" /> Thông Tin Cơ Bản
              </h3>
              
              {!isEditingProfile && (
                <button onClick={() => setIsEditingProfile(true)} style={{ display: 'flex', alignItems: 'center', gap: '6px', background: 'none', border: '1px solid #cbd5e1', color: '#475569', padding: '6px 12px', borderRadius: '6px', fontSize: '13px', fontWeight: 600, cursor: 'pointer', backgroundColor: '#f8fafc' }}>
                  <Edit size={14} /> Chỉnh sửa
                </button>
              )}
            </div>
            
            {!isEditingProfile ? (
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '24px' }}>
                <div>
                  <p style={{ margin: '0 0 4px 0', fontSize: '12px', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>Họ và tên</p>
                  <p style={{ margin: 0, fontSize: '15px', color: '#0f172a', fontWeight: 500 }}>{formData.username || 'Chưa cập nhật'}</p>
                </div>
                <div>
                  <p style={{ margin: '0 0 4px 0', fontSize: '12px', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>Số điện thoại</p>
                  <p style={{ margin: 0, fontSize: '15px', color: '#0f172a', fontWeight: 500 }}>{formData.phone || 'Chưa cập nhật'}</p>
                </div>
                <div style={{ gridColumn: 'span 2' }}>
                  <p style={{ margin: '0 0 4px 0', fontSize: '12px', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>Email đăng nhập (Không thể thay đổi)</p>
                  <p style={{ margin: 0, fontSize: '15px', color: '#0f172a', fontWeight: 500 }}>{formData.email}</p>
                </div>
              </div>
            ) : (
              <form onSubmit={handleUpdateProfile}>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginBottom: '20px' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '8px' }}>Họ và tên hiển thị</label>
                    <input type="text" required value={formData.username} onChange={e => setFormData({...formData, username: e.target.value})} style={{ width: '100%', padding: '10px 14px', borderRadius: '8px', border: '1px solid #3b82f6', outline: 'none', fontSize: '14px', boxSizing: 'border-box', backgroundColor: '#eff6ff' }} autoFocus />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '8px' }}>Số điện thoại</label>
                    <input type="text" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} style={{ width: '100%', padding: '10px 14px', borderRadius: '8px', border: '1px solid #3b82f6', outline: 'none', fontSize: '14px', boxSizing: 'border-box', backgroundColor: '#eff6ff' }} />
                  </div>
                </div>

                <div style={{ marginBottom: '24px' }}>
                  <label style={{ display: 'block', fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '8px' }}>Địa chỉ Email</label>
                  <input type="email" value={formData.email} disabled style={{ width: '100%', padding: '10px 14px', borderRadius: '8px', border: '1px solid #cbd5e1', outline: 'none', fontSize: '14px', backgroundColor: '#f1f5f9', color: '#94a3b8', boxSizing: 'border-box', cursor: 'not-allowed' }} />
                </div>

                <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px' }}>
                  <button type="button" onClick={handleCancelEdit} style={{ display: 'flex', alignItems: 'center', gap: '6px', backgroundColor: '#fff', color: '#64748b', border: '1px solid #cbd5e1', padding: '10px 16px', borderRadius: '8px', fontWeight: 600, cursor: 'pointer' }}>
                    <X size={16} /> Hủy bỏ
                  </button>
                  <button type="submit" style={{ display: 'flex', alignItems: 'center', gap: '6px', backgroundColor: '#3b82f6', color: '#fff', border: 'none', padding: '10px 20px', borderRadius: '8px', fontWeight: 'bold', cursor: 'pointer' }}>
                    <Save size={16} /> Lưu Thay Đổi
                  </button>
                </div>
              </form>
            )}
          </div>

        </div>
      </div>
    </div>
  );
};

export default Profile;